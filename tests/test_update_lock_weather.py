#!/usr/bin/env python3
"""Regression tests for lock-screen rain detection and forecast alignment."""

from __future__ import annotations

import contextlib
from datetime import datetime, timezone
import io
import json
import os
from pathlib import Path
import runpy
import sys
import tempfile
import time
import unittest
from unittest import mock
import urllib.parse
import urllib.request


SCRIPT = Path(__file__).resolve().parents[1] / "bin" / "update-lock-weather"
REPO_ROOT = SCRIPT.parents[1]


def load_weather() -> dict[str, object]:
    return runpy.run_path(str(SCRIPT))


def payload(
    *,
    current_code: int = 3,
    current_rain: float = 0,
    current_showers: float = 0,
    minute_rain: list[float] | None = None,
    minute_showers: list[float] | None = None,
    minute_codes: list[int] | None = None,
    probabilities: list[int] | None = None,
    current_time: str = "2026-08-31T10:00",
) -> dict[str, object]:
    minute_times = [
        "2026-08-31T10:00",
        "2026-08-31T10:15",
        "2026-08-31T10:30",
        "2026-08-31T10:45",
        "2026-08-31T11:00",
        "2026-08-31T11:15",
    ]
    count = len(minute_times)
    return {
        "utc_offset_seconds": 8 * 60 * 60,
        "current": {
            "time": current_time,
            "temperature_2m": 27,
            "apparent_temperature": 29,
            "relative_humidity_2m": 75,
            "rain": current_rain,
            "showers": current_showers,
            "precipitation": 0,
            "weather_code": current_code,
            "surface_pressure": 1008,
            "wind_speed_10m": 2,
            "visibility": 10000,
            "is_day": 1,
        },
        "minutely_15": {
            "time": minute_times,
            "rain": minute_rain if minute_rain is not None else [0] * count,
            "showers": minute_showers if minute_showers is not None else [0] * count,
            "weather_code": minute_codes if minute_codes is not None else [0] * count,
            "precipitation_probability": (
                probabilities if probabilities is not None else [0] * count
            ),
            # Deliberately present: total precipitation must not affect rain state.
            "precipitation": [0] * count,
        },
        "daily": {
            "sunrise": ["2026-08-31T05:35"],
            "sunset": ["2026-08-31T18:15"],
        },
    }


def weather_mode(rendered: str) -> str:
    return rendered.strip().splitlines()[-1]


class LockWeatherRainTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.module = load_weather()
        cls.render = staticmethod(cls.module["render"])

    def render_at(self, data: dict[str, object], now: datetime | None = None) -> str:
        return self.render(
            data,
            "測試地點",
            now or datetime(2026, 8, 31, 10, 0),
        )

    def test_snow_and_total_precipitation_are_not_rain(self) -> None:
        data = payload(
            current_code=71,
            minute_codes=[71] * 6,
            minute_rain=[0] * 6,
        )
        data["current"]["precipitation"] = 3.0
        data["minutely_15"]["precipitation"] = [3.0] * 6

        rendered = self.render_at(data)

        self.assertIn("降雪", rendered)
        self.assertIn("近 15 分鐘雨量 0.0 mm", rendered)
        self.assertNotIn("可能有雨", rendered)
        self.assertEqual(weather_mode(rendered), "cloud")

    def test_probability_alone_does_not_enable_rain_mode(self) -> None:
        rendered = self.render_at(
            payload(probabilities=[99, 95, 80, 70, 60, 50]),
        )

        self.assertIn("短時降水機率 95%", rendered)
        self.assertEqual(weather_mode(rendered), "cloud")

    def test_interpolated_trace_amount_is_ignored(self) -> None:
        rendered = self.render_at(
            payload(minute_rain=[0, 0.02, 0.02, 0.02, 0.02, 1.0]),
        )

        self.assertNotIn("可能有雨", rendered)
        self.assertEqual(weather_mode(rendered), "cloud")

    def test_showers_count_as_liquid_rain(self) -> None:
        rendered = self.render_at(
            payload(minute_showers=[0, 0.15, 0, 0, 0, 0]),
        )

        self.assertIn("10:00 前後可能有雨", rendered)
        self.assertEqual(weather_mode(rendered), "cloud")

    def test_current_showers_enable_rain_mode(self) -> None:
        rendered = self.render_at(payload(current_showers=0.2, current_code=80))

        self.assertIn("模型顯示目前有雨", rendered)
        self.assertEqual(weather_mode(rendered), "rain")

    def test_recent_rain_amount_does_not_claim_it_is_still_raining(self) -> None:
        rendered = self.render_at(payload(current_rain=1.0, current_code=3))

        self.assertIn("近 15 分鐘雨量 1.0 mm", rendered)
        self.assertNotIn("模型顯示目前有雨", rendered)
        self.assertEqual(weather_mode(rendered), "cloud")

    def test_finished_intervals_are_skipped_and_probability_is_aligned(self) -> None:
        rendered = self.render_at(
            payload(
                minute_rain=[1.0, 0, 0, 0.2, 0, 0],
                minute_codes=[61, 0, 0, 61, 0, 0],
                probabilities=[99, 10, 20, 35, 5, 0],
            ),
        )

        self.assertIn("10:30 前後可能有雨 35%", rendered)
        self.assertNotIn("09:45 前後可能有雨", rendered)

    def test_rolling_hour_includes_partial_fifth_interval(self) -> None:
        rendered = self.render_at(
            payload(
                minute_rain=[0, 0, 0, 0, 0, 0.2],
                probabilities=[1, 2, 3, 4, 5, 88],
            ),
            datetime(2026, 8, 31, 10, 14),
        )

        self.assertIn("11:00 前後可能有雨 88%", rendered)

    def test_aware_utc_now_is_converted_to_the_forecast_timezone(self) -> None:
        data = payload(
            minute_rain=[0, 0, 0, 0, 0, 0.2],
            probabilities=[1, 2, 3, 4, 5, 88],
        )

        state = self.module["rain_state"](
            data,
            datetime(2026, 8, 31, 2, 14, tzinfo=timezone.utc),
        )

        self.assertEqual(state["next_rain"], "11:00")
        self.assertEqual(state["probability"], 88)

    def test_hour_total_triggers_without_trace_interval_false_positive(self) -> None:
        rendered = self.render_at(payload(minute_rain=[0, 0.06, 0.06, 0.06, 0.06, 0]))

        self.assertIn("10:00 前後可能有雨", rendered)
        self.assertEqual(weather_mode(rendered), "cloud")

    def test_rain_code_without_liquid_amount_does_not_trigger_forecast(self) -> None:
        rendered = self.render_at(payload(minute_codes=[0, 61, 61, 61, 61, 0]))

        self.assertNotIn("可能有雨", rendered)

    def test_fetch_requests_future_slots_and_only_liquid_components(self) -> None:
        response = mock.MagicMock()
        response.__enter__.return_value = response
        with (
            mock.patch.object(
                urllib.request, "urlopen", return_value=response
            ) as open_url,
            mock.patch.object(json, "load", return_value={}),
        ):
            self.module["fetch"](12.3456, -23.4567)

        request = open_url.call_args.args[0]
        query = urllib.parse.parse_qs(urllib.parse.urlsplit(request.full_url).query)
        self.assertEqual(
            query["minutely_15"],
            ["rain,showers,weather_code,precipitation_probability"],
        )
        self.assertIn("rain", query["current"][0].split(","))
        self.assertIn("showers", query["current"][0].split(","))
        self.assertNotIn("precipitation", query["current"][0].split(","))
        self.assertGreaterEqual(int(query["forecast_minutely_15"][0]), 7)
        self.assertNotIn("hourly", query)

    def run_failed_refresh(self, cache_age: float) -> tuple[int, str]:
        module = load_weather()
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary) / "hyprlock/weather.txt"
            cache.parent.mkdir(parents=True)
            old_text = "old forecast\nold details\nold update\nrain\n"
            cache.write_text(old_text, encoding="utf-8")
            timestamp = time.time() - cache_age
            os.utime(cache, (timestamp, timestamp))
            script_globals = module["main"].__globals__
            script_globals["CACHE"] = cache
            script_globals["fetch"] = mock.Mock(side_effect=OSError("offline"))
            environment = {
                "UIOS_WEATHER_LATITUDE": "12.3456",
                "UIOS_WEATHER_LONGITUDE": "-23.4567",
                "UIOS_WEATHER_CITY": "Synthetic Fixture",
            }
            with (
                mock.patch.dict(os.environ, environment, clear=False),
                mock.patch.object(sys, "argv", [str(SCRIPT), "--force"]),
                contextlib.redirect_stderr(io.StringIO()),
            ):
                result = module["main"]()
            return result, cache.read_text(encoding="utf-8")

    def test_stale_failed_refresh_disables_old_rain_mode(self) -> None:
        result, cached = self.run_failed_refresh(cache_age=21 * 60)

        self.assertEqual(result, 1)
        self.assertIn("Synthetic Fixture · 天氣資料暫時無法更新", cached)
        self.assertEqual(weather_mode(cached), "cloud")

    def test_transient_failed_refresh_preserves_fresh_cache(self) -> None:
        result, cached = self.run_failed_refresh(cache_age=5 * 60)

        self.assertEqual(result, 1)
        self.assertEqual(cached, "old forecast\nold details\nold update\nrain\n")

    def test_placeholder_cache_is_never_treated_as_fresh_forecast(self) -> None:
        module = load_weather()
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary) / "weather.txt"
            script_globals = module["cache_is_fresh"].__globals__
            script_globals["CACHE"] = cache

            cache.write_text(module["UNCONFIGURED_TEXT"], encoding="utf-8")
            self.assertFalse(module["cache_is_fresh"]())

            cache.write_text(
                module["unavailable_text"]("Synthetic Fixture"), encoding="utf-8"
            )
            self.assertFalse(module["cache_is_fresh"]())


class QuickshellWeatherContractTests(unittest.TestCase):
    def test_quickshell_uses_the_aligned_liquid_rain_feed(self) -> None:
        source = (REPO_ROOT / "shell/end4-pC/services/Weather.qml").read_text(
            encoding="utf-8"
        )

        self.assertIn(
            "minutely_15=rain,showers,weather_code,precipitation_probability",
            source,
        )
        self.assertIn("forecast_minutely_15=7", source)
        self.assertIn("utc_offset_seconds", source)
        self.assertIn("onGpsActiveChanged", source)
        self.assertIn("weatherStaleMs", source)
        self.assertIn("refreshOverdue", source)
        self.assertIn("lastFetchAttemptMs", source)
        self.assertIn("Weather data: https://open-meteo.com/", source)
        self.assertNotIn("minutely_15=precipitation", source)
        self.assertNotIn("probability >= 50 ||", source)

    def test_weather_views_have_no_placeholder_probability_or_legacy_field(
        self,
    ) -> None:
        view_paths = (
            "shell/end4-pC/modules/ii/bar/WeatherPopup.qml",
            "shell/end4-pC/modules/ii/background/widgets/weather/WeatherWidget.qml",
            "shell/end4-pC/modules/ii/lock/LockWeatherEffects.qml",
        )
        source = "\n".join(
            (REPO_ROOT / relative).read_text(encoding="utf-8")
            for relative in view_paths
        )

        self.assertNotIn("Weather.data?.cr", source)
        self.assertNotIn('"24%"', source)
        self.assertNotIn("rainProbability >= 50", source)
        self.assertIn("Weather.data?.rainingNow", source)

    def test_weather_views_attribute_open_meteo_without_lock_actions(self) -> None:
        attribution = (
            REPO_ROOT
            / "shell/end4-pC/modules/common/widgets/OpenMeteoAttribution.qml"
        ).read_text(encoding="utf-8")
        popup = (
            REPO_ROOT / "shell/end4-pC/modules/ii/bar/WeatherPopup.qml"
        ).read_text(encoding="utf-8")
        widget = (
            REPO_ROOT
            / "shell/end4-pC/modules/ii/background/widgets/weather/WeatherWidget.qml"
        ).read_text(encoding="utf-8")
        user_card = (
            REPO_ROOT
            / "shell/end4-pC/modules/ii/background/widgets/usercard/UserCardWidget.qml"
        ).read_text(encoding="utf-8")
        lock = (
            REPO_ROOT / "shell/end4-pC/modules/ii/lock/LockSurface.qml"
        ).read_text(encoding="utf-8")
        hyprlock = (REPO_ROOT / "config/hypr/hyprlock.conf").read_text(
            encoding="utf-8"
        )

        self.assertIn('Qt.openUrlExternally("https://open-meteo.com/")', attribution)
        self.assertIn("property bool interactive: !GlobalStates.screenLocked", attribution)
        self.assertIn("OpenMeteoAttribution", popup)
        self.assertIn("OpenMeteoAttribution", widget)
        self.assertIn("OpenMeteoAttribution", user_card)
        self.assertIn("interactive: !GlobalStates.screenLocked", widget)
        self.assertIn("interactive: !GlobalStates.screenLocked", user_card)
        self.assertIn("interactive: false", lock)
        self.assertIn("Weather data by Open-Meteo.com", hyprlock)
        self.assertNotIn("openUrlExternally", lock)

    def test_repository_seed_requires_explicit_gps_opt_in(self) -> None:
        seed = json.loads(
            (REPO_ROOT / "config/illogical-impulse/config.json").read_text(
                encoding="utf-8"
            )
        )
        config_source = (
            REPO_ROOT / "shell/end4-pC/modules/common/Config.qml"
        ).read_text(encoding="utf-8")

        self.assertFalse(seed["bar"]["weather"]["enableGPS"])
        self.assertIn("property bool enableGPS: false", config_source)

    def test_lock_weather_timer_uses_resume_safe_wall_clock_schedule(self) -> None:
        source = (REPO_ROOT / "systemd/user/core/update-lock-weather.timer").read_text(
            encoding="utf-8"
        )

        self.assertIn("OnCalendar=*:0/10", source)
        self.assertIn("Persistent=true", source)
        self.assertNotIn("OnUnitActiveSec", source)


if __name__ == "__main__":
    unittest.main()
