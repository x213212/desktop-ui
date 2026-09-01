#!/usr/bin/env python3
"""Compliance and safety regressions for public online wallpaper providers."""

from __future__ import annotations

import io
from pathlib import Path
import runpy
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HELPER = (
    ROOT
    / "shell"
    / "end4-pC"
    / "scripts"
    / "wallpapers"
    / "download-online-wallpaper.py"
)
GRID = ROOT / "shell/end4-pC/modules/ii/wallpaperSelector/OnlineWallpaperGrid.qml"
SELECTOR = ROOT / "shell/end4-pC/modules/ii/wallpaperSelector/WallpaperSelectorContent.qml"
SERVICE = ROOT / "shell/end4-pC/services/OnlineWallpapers.qml"
LAUNCHER = ROOT / "shell/end4-pC/services/LauncherSearch.qml"


class FakeResponse(io.BytesIO):
    def __init__(
        self,
        body: bytes,
        url: str,
        *,
        content_type: str,
        status: int = 200,
    ) -> None:
        super().__init__(body)
        self.status = status
        self._url = url
        self.headers = {
            "Content-Type": content_type,
            "Content-Length": str(len(body)),
        }

    def __enter__(self) -> "FakeResponse":
        return self

    def __exit__(self, *_args: object) -> None:
        self.close()

    def geturl(self) -> str:
        return self._url


class OnlineWallpaperHelperTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.module = runpy.run_path(str(HELPER))
        cls.download = staticmethod(cls.module["download_wallpaper"])
        cls.download_error = cls.module["DownloadError"]

    def test_unsplash_tracks_before_downloading_with_client_id(self) -> None:
        tracking_url = "https://api.unsplash.com/photos/photo-id/download"
        image_url = "https://images.unsplash.com/photo-id?w=1920"
        requests: list[object] = []

        def opener(request: object, **_kwargs: object) -> FakeResponse:
            requests.append(request)
            if len(requests) == 1:
                return FakeResponse(
                    b'{"url":"https://images.unsplash.com/photo-id?force=true"}',
                    tracking_url,
                    content_type="application/json",
                )
            return FakeResponse(
                b"jpeg-image-bytes",
                image_url,
                content_type="image/jpeg",
            )

        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "Wallpapers" / "unsplash-photo-id.jpg"
            self.download(
                "unsplash",
                image_url,
                output,
                download_location=tracking_url,
                client_id="test-client-id",
                opener=opener,
            )

            self.assertEqual(output.read_bytes(), b"jpeg-image-bytes")

        self.assertEqual(len(requests), 2)
        self.assertEqual(requests[0].full_url, tracking_url)
        self.assertEqual(
            requests[0].get_header("Authorization"),
            "Client-ID test-client-id",
        )
        self.assertEqual(requests[1].full_url, image_url)

    def test_unsplash_tracking_failure_prevents_image_request(self) -> None:
        tracking_url = "https://api.unsplash.com/photos/photo-id/download"
        requests: list[object] = []

        def opener(request: object, **_kwargs: object) -> FakeResponse:
            requests.append(request)
            return FakeResponse(
                b"denied",
                tracking_url,
                content_type="application/json",
                status=403,
            )

        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "unsplash.jpg"
            with self.assertRaises(self.download_error):
                self.download(
                    "unsplash",
                    "https://images.unsplash.com/photo-id",
                    output,
                    download_location=tracking_url,
                    client_id="test-client-id",
                    opener=opener,
                )
            self.assertFalse(output.exists())

        self.assertEqual(len(requests), 1)

    def test_wallhaven_download_does_not_require_unsplash_tracking(self) -> None:
        image_url = "https://w.wallhaven.cc/full/ab/wallhaven-ab1234.jpg"
        requests: list[object] = []

        def opener(request: object, **_kwargs: object) -> FakeResponse:
            requests.append(request)
            return FakeResponse(b"wallhaven-image", image_url, content_type="image/jpeg")

        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "wallhaven.jpg"
            self.download("wallhaven", image_url, output, opener=opener)
            self.assertEqual(output.read_bytes(), b"wallhaven-image")

        self.assertEqual(len(requests), 1)

    def test_untrusted_image_host_is_rejected_before_network_access(self) -> None:
        calls = 0

        def opener(_request: object, **_kwargs: object) -> FakeResponse:
            nonlocal calls
            calls += 1
            raise AssertionError("network must not be reached")

        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(self.download_error):
                self.download(
                    "wallhaven",
                    "https://example.invalid/wallpaper.jpg",
                    Path(temporary) / "wallpaper.jpg",
                    opener=opener,
                )

        self.assertEqual(calls, 0)

    def test_non_image_response_is_not_installed(self) -> None:
        image_url = "https://w.wallhaven.cc/full/ab/wallhaven-ab1234.jpg"

        def opener(_request: object, **_kwargs: object) -> FakeResponse:
            return FakeResponse(b"not an image", image_url, content_type="text/html")

        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "wallpaper.jpg"
            with self.assertRaises(self.download_error):
                self.download("wallhaven", image_url, output, opener=opener)
            self.assertFalse(output.exists())


class OnlineWallpaperStaticContractTests(unittest.TestCase):
    def test_public_ui_has_no_pexels_provider_or_key_command(self) -> None:
        for path in (GRID, SELECTOR, SERVICE, LAUNCHER):
            with self.subTest(path=path.name):
                self.assertNotIn("pexels", path.read_text(encoding="utf-8").lower())

    def test_grid_uses_safe_helper_and_clickable_attribution(self) -> None:
        source = GRID.read_text(encoding="utf-8")
        self.assertNotIn('["bash", "-c"', source)
        self.assertIn("download-online-wallpaper.py", source)
        self.assertIn('command.push("--download-location", downloadLocation)', source)
        self.assertIn("UIOS_UNSPLASH_CLIENT_ID", source)
        self.assertIn('Translation.tr("Photo by %1")', source)
        self.assertIn('Translation.tr("on Unsplash")', source)
        self.assertIn('Translation.tr("on Wallhaven")', source)
        self.assertIn("Qt.openUrlExternally", source)

    def test_service_preserves_provider_links_and_uses_headers_for_keys(self) -> None:
        source = SERVICE.read_text(encoding="utf-8")
        self.assertIn("X-API-Key", source)
        self.assertIn("Authorization: Client-ID", source)
        self.assertNotIn("&apikey=", source)
        self.assertNotIn("&client_id=", source)
        self.assertIn('"--proto", "=https"', source)
        self.assertIn('"--connect-timeout", "8", "--max-time", "20"', source)
        self.assertIn('"--max-filesize", "2097152"', source)
        self.assertIn("item.url ?? item.short_url", source)
        self.assertIn("uploader:         item.uploader ?? null", source)
        self.assertIn("downloadLocation: item.links?.download_location", source)
        self.assertIn("utm_source=desktop-ui&utm_medium=referral", source)


if __name__ == "__main__":
    unittest.main()
