pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtPositioning

import qs.modules.common

Singleton {
    id: root

    // Optional private fallback comes from ~/.config/desktop-ui/weather.env.
    // Without it, wait for GeoClue instead of sending a repository-bundled
    // location to the network.
    readonly property string fallbackLatText: Quickshell.env("UIOS_WEATHER_LATITUDE") || ""
    readonly property string fallbackLonText: Quickshell.env("UIOS_WEATHER_LONGITUDE") || ""
    readonly property real fallbackLat: Number(fallbackLatText)
    readonly property real fallbackLon: Number(fallbackLonText)
    readonly property bool hasFallbackLocation: fallbackLatText.length > 0
        && fallbackLonText.length > 0 && isFinite(fallbackLat) && isFinite(fallbackLon)
        && fallbackLat >= -90 && fallbackLat <= 90
        && fallbackLon >= -180 && fallbackLon <= 180
    readonly property int fetchInterval: Math.max(5, Config.options.bar.weather.fetchInterval) * 60 * 1000
    readonly property string fallbackCity: Quickshell.env("UIOS_WEATHER_CITY")
        || Config.options.bar.weather.city || "目前位置"
    readonly property bool useUSCS: Config.options.bar.weather.useUSCS
    readonly property int rainIntervalSeconds: 15 * 60
    readonly property int rainForecastSeconds: 60 * 60
    readonly property int weatherStaleMs: Math.max(20 * 60 * 1000,
        root.fetchInterval + 5 * 60 * 1000)
    property bool gpsActive: Config.options.bar.weather.enableGPS
    property bool usingLiveLocation: false
    property double lastRainNotificationMs: 0
    property double lastSuccessfulFetchMs: 0
    property double lastFetchAttemptMs: 0
    property bool refreshQueued: false
    property double requestLatitude: 0
    property double requestLongitude: 0
    property bool requestUseUSCS: false

    // Explicit eager-load hook used by shell.qml. Fetching is deferred until
    // this singleton and its Process child are fully constructed.
    function load() {}

    onUseUSCSChanged: root.getData()
    onGpsActiveChanged: {
        if (root.gpsActive) {
            positionSource.start()
        } else {
            positionSource.stop()
            root.usingLiveLocation = false
            root.location = {
                valid: root.hasFallbackLocation,
                lat: root.hasFallbackLocation ? root.fallbackLat : 0,
                lon: root.hasFallbackLocation ? root.fallbackLon : 0
            }
            root.getData()
        }
    }

    property var location: ({
        valid: hasFallbackLocation,
        lat: hasFallbackLocation ? fallbackLat : 0,
        lon: hasFallbackLocation ? fallbackLon : 0
    })
    property var data: ({
        humidity: "--", sunrise: "--", sunset: "--", windDir: 0,
        wCode: 113, city: fallbackCity, description: "讀取中", wind: "--",
        precip: "--", rainProbability: -1, nextRainTime: "", rainingNow: false, isDay: -1, fresh: false, visib: "--",
        press: "--", temp: "--°", tempFeelsLike: "--°", lastRefresh: ""
    })

    function displayCity(lat, lon) {
        return root.usingLiveLocation ? "目前精確位置" : root.fallbackCity
    }

    function weatherDescription(code) {
        if (code === 0) return "晴朗"
        if (code <= 2) return "局部多雲"
        if (code === 3) return "陰天"
        if (code === 45 || code === 48) return "有霧"
        if (code >= 51 && code <= 57) return "毛毛雨"
        if (code >= 61 && code <= 67) return "下雨"
        if (code >= 71 && code <= 77) return "降雪"
        if (code >= 80 && code <= 82) return "陣雨"
        if (code >= 85 && code <= 86) return "陣雪"
        if (code >= 95) return "雷雨"
        return "天氣不明"
    }

    // Translate WMO codes into the icon codes already used by this shell.
    function iconCode(code) {
        if (code === 0) return 113
        if (code <= 2) return 116
        if (code === 3) return 119
        if (code === 45 || code === 48) return 143
        if (code >= 51 && code <= 57) return 266
        if (code >= 61 && code <= 67) return code >= 65 ? 308 : 296
        if (code >= 71 && code <= 77) return code >= 75 ? 338 : 326
        if (code >= 80 && code <= 82) return code === 82 ? 359 : 353
        if (code >= 85 && code <= 86) return 371
        if (code >= 95) return 389
        return 119
    }

    function shortTime(isoTime) {
        if (!isoTime) return ""
        const parts = isoTime.split("T")
        return parts.length > 1 ? parts[1] : isoTime
    }

    function isRainCode(value) {
        const code = Number(value ?? 0)
        return (code >= 51 && code <= 57)
            || (code >= 61 && code <= 67)
            || (code >= 80 && code <= 82)
            || (code >= 95 && code <= 99)
    }

    function toMillimetres(value, sourceUsesInches) {
        const amount = Math.max(0, Number(value ?? 0))
        return sourceUsesInches ? amount * 25.4 : amount
    }

    function apiTimeSeconds(value) {
        const text = String(value ?? "")
        if (!text) return NaN
        // API timestamps are local wall time without an offset. Parsing them
        // as UTC gives a stable numeric local timeline for any forecast zone.
        return Date.parse(text + "Z") / 1000
    }

    function clockTime(seconds) {
        if (!isFinite(seconds)) return ""
        const value = new Date(seconds * 1000)
        const hours = String(value.getUTCHours()).padStart(2, "0")
        const minutes = String(value.getUTCMinutes()).padStart(2, "0")
        return `${hours}:${minutes}`
    }

    // Precipitation values belong to the preceding 15-minute interval. Use
    // overlap with the next rolling hour, including partial first/last slots.
    function forecastSamples(times, response) {
        const offset = Number(response?.utc_offset_seconds ?? 0)
        const nowLocal = Date.now() / 1000 + offset
        const horizonEnd = nowLocal + root.rainForecastSeconds
        const samples = []
        for (let i = 0; i < times.length; ++i) {
            const intervalEnd = apiTimeSeconds(times[i])
            if (!isFinite(intervalEnd)) continue
            const intervalStart = intervalEnd - root.rainIntervalSeconds
            const overlapStart = Math.max(nowLocal, intervalStart)
            const overlapEnd = Math.min(horizonEnd, intervalEnd)
            if (overlapEnd > overlapStart) {
                samples.push({
                    index: i,
                    fraction: (overlapEnd - overlapStart) / root.rainIntervalSeconds,
                    start: overlapStart
                })
            }
        }
        return samples
    }

    function requestMatchesCurrent() {
        return root.requestUseUSCS === root.useUSCS
            && Math.abs(root.requestLatitude - Number(root.location.lat)) < 0.000001
            && Math.abs(root.requestLongitude - Number(root.location.lon)) < 0.000001
    }

    function maybeNotifyRain(probability, amountMm, when, rainingNow, forecastRain) {
        // Ensemble probability by itself is too coarse for a local alert. It
        // must agree with the deterministic rain/showers forecast.
        const likelySoon = forecastRain && (probability >= 40 || amountMm >= 0.2)
        const risk = rainingNow || likelySoon
        const now = Date.now()
        const cooldownMs = 3 * 60 * 60 * 1000
        if (risk && (!root.lastRainNotificationMs
                || now - root.lastRainNotificationMs >= cooldownMs)) {
            const place = root.displayCity(root.location.lat, root.location.lon)
            const timeText = shortTime(when) || "一小時內"
            const title = rainingNow ? `${place} 預報顯示目前有雨` : `${place} 短時可能有雨`
            const body = rainingNow
                ? `模型顯示目前有雨；短時降水機率 ${probability}%，外出記得帶傘。\nWeather data: https://open-meteo.com/`
                : `${timeText} 前後可能有雨，短時降水機率 ${probability}%（約 ${amountMm.toFixed(1)} mm），外出記得帶傘。\nWeather data: https://open-meteo.com/`
            Quickshell.execDetached([
                "notify-send", "-u", "normal", "-i", "weather-showers",
                title, body, "-a", "天氣預報"
            ])
            root.lastRainNotificationMs = now
        }
    }

    function refineData(response) {
        const current = response?.current ?? {}
        const minutely = response?.minutely_15 ?? {}
        const daily = response?.daily ?? {}
        const rains = minutely.rain ?? []
        const showers = minutely.showers ?? []
        const minuteCodes = minutely.weather_code ?? []
        const minuteTimes = minutely.time ?? []
        const minuteProbabilities = minutely.precipitation_probability ?? []
        const samples = forecastSamples(minuteTimes, response)

        let nextHourAmountMm = 0
        let shortTermProbability = 0
        let rainTime = ""
        let firstPositiveTime = ""
        let forecastRain = false
        for (const sample of samples) {
            const index = sample.index
            const rawRain = Number(rains[index] ?? 0) + Number(showers[index] ?? 0)
            const amountMm = toMillimetres(rawRain, root.requestUseUSCS) * sample.fraction
            const code = Number(minuteCodes[index] ?? 0)
            const intervalRain = amountMm >= 0.1 || (isRainCode(code) && amountMm >= 0.05)
            nextHourAmountMm += amountMm
            shortTermProbability = Math.max(shortTermProbability,
                Number(minuteProbabilities[index] ?? 0))
            if (!firstPositiveTime && amountMm > 0)
                firstPositiveTime = clockTime(sample.start)
            if (intervalRain) {
                forecastRain = true
                if (!rainTime)
                    rainTime = clockTime(sample.start)
            }
        }
        if (!forecastRain && nextHourAmountMm >= 0.2) {
            forecastRain = true
            rainTime = firstPositiveTime
        }
        shortTermProbability = Math.max(0, Math.min(100, Math.round(shortTermProbability)))

        const tempUnit = root.requestUseUSCS ? "°F" : "°C"
        const windUnit = root.requestUseUSCS ? " mph" : " m/s"
        const precipUnit = root.requestUseUSCS ? " in" : " mm"
        const visibilityUnit = root.requestUseUSCS ? " mi" : " km"
        const rawVisibility = Number(current.visibility ?? 0)
        const wmoCode = Number(current.weather_code ?? 0)
        const currentRain = Math.max(0, Number(current.rain ?? 0))
            + Math.max(0, Number(current.showers ?? 0))
        // rain/showers is the preceding 15-minute sum; only the instant WMO
        // condition may drive the "currently raining" artwork and alert.
        const rainingNow = isRainCode(wmoCode)

        root.data = {
            humidity: Math.round(Number(current.relative_humidity_2m ?? 0)) + "%",
            sunrise: shortTime(daily.sunrise?.[0] ?? ""),
            sunset: shortTime(daily.sunset?.[0] ?? ""),
            windDir: Number(current.wind_direction_10m ?? 0),
            wCode: iconCode(wmoCode),
            city: displayCity(root.location.lat, root.location.lon),
            description: weatherDescription(wmoCode),
            wind: Number(current.wind_speed_10m ?? 0).toFixed(1) + windUnit,
            precip: currentRain.toFixed(root.requestUseUSCS ? 2 : 1) + precipUnit,
            rainProbability: shortTermProbability,
            nextRainTime: shortTime(rainTime),
            rainingNow: rainingNow,
            isDay: Number(current.is_day ?? -1),
            fresh: true,
            visib: (rawVisibility / (root.requestUseUSCS ? 1609.344 : 1000)).toFixed(1) + visibilityUnit,
            press: Math.round(Number(current.surface_pressure ?? 0)) + " hPa",
            temp: Math.round(Number(current.temperature_2m ?? 0)) + tempUnit,
            tempFeelsLike: Math.round(Number(current.apparent_temperature ?? 0)) + tempUnit,
            lastRefresh: DateTime.time + " • " + DateTime.date
        }
        root.lastSuccessfulFetchMs = Date.now()

        const rainText = rainingNow
            ? ` · 模型顯示目前有雨 · 短時降水 ${shortTermProbability}%`
            : rainTime
                ? ` · ${shortTime(rainTime)} 前後可能有雨 ${shortTermProbability}%`
                : ` · 短時降水機率 ${shortTermProbability}%`
        const detailLine = `體感 ${root.data.tempFeelsLike} · 濕度 ${root.data.humidity} · 風速 ${root.data.wind} · 近 15 分鐘雨量 ${root.data.precip}`
        const contextLine = `能見度 ${root.data.visib} · 氣壓 ${root.data.press} · 日出 ${root.data.sunrise} · 日落 ${root.data.sunset} · 更新 ${root.data.lastRefresh}`
        lockWeatherFile.setText(`${root.data.city} · ${root.data.temp} · ${root.data.description}${rainText}\n${detailLine}\n${contextLine}`)
        maybeNotifyRain(shortTermProbability, nextHourAmountMm, rainTime, rainingNow, forecastRain)
    }

    function getData() {
        if (!root.location.valid) return
        if (fetcher.running) {
            root.refreshQueued = true
            return
        }
        root.requestLatitude = Number(root.location.lat)
        root.requestLongitude = Number(root.location.lon)
        root.requestUseUSCS = root.useUSCS
        root.refreshQueued = false
        root.lastFetchAttemptMs = Date.now()
        const units = root.useUSCS
            ? "&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch"
            : "&wind_speed_unit=ms"
        const currentFields = "temperature_2m,apparent_temperature,relative_humidity_2m,rain,showers,weather_code,cloud_cover,surface_pressure,wind_speed_10m,wind_direction_10m,is_day,visibility"
        const url = `https://api.open-meteo.com/v1/forecast?latitude=${root.location.lat}&longitude=${root.location.lon}`
            + `&current=${currentFields}`
            + "&minutely_15=rain,showers,weather_code,precipitation_probability&forecast_minutely_15=7"
            + `&daily=sunrise,sunset&timezone=auto${units}`
        fetcher.command = ["/usr/bin/curl", "-fsS", "--max-time", "12", url]
        fetcher.running = true
    }

    Component.onCompleted: {
        if (root.gpsActive) positionSource.start()
        Qt.callLater(root.getData)
    }

    Process {
        id: fetcher
        command: ["true"]
        onExited: (exitCode, exitStatus) => {
            const rerun = root.refreshQueued || !root.requestMatchesCurrent()
            root.refreshQueued = false
            if (rerun) {
                Qt.callLater(root.getData)
            } else if (exitCode !== 0) {
                console.warn(`[WeatherService] fetch failed with status ${exitCode}`)
                weatherRetry.restart()
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return
                if (!root.requestMatchesCurrent()) {
                    root.refreshQueued = true
                    return
                }
                try {
                    root.refineData(JSON.parse(text))
                } catch (error) {
                    console.error("[WeatherService] JSON parse error:", error.message)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    console.warn(`[WeatherService] ${text.trim()}`)
            }
        }
    }

    Timer {
        id: weatherRetry
        interval: 30000
        repeat: false
        onTriggered: root.getData()
    }

    Timer {
        running: true
        repeat: true
        interval: 60 * 1000
        onTriggered: {
            const now = Date.now()
            const successfulAge = root.lastSuccessfulFetchMs > 0
                ? now - root.lastSuccessfulFetchMs : Number.POSITIVE_INFINITY
            if (root.data?.fresh === true && successfulAge > root.weatherStaleMs) {
                root.data = Object.assign({}, root.data, {
                    fresh: false,
                    rainingNow: false,
                    isDay: -1,
                    wCode: 119,
                    description: "資料已過期",
                    precip: "--",
                    rainProbability: -1,
                    nextRainTime: ""
                })
                lockWeatherFile.setText(`${root.data.city} · 天氣資料已過期\n體感 -- · 濕度 -- · 風速 -- · 近 15 分鐘雨量 --\n能見度 -- · 氣壓 -- · 日出 -- · 日落 -- · 更新失敗`)
            }
            // Qt's repeating timers use a monotonic clock and can retain their
            // remaining delay across suspend. Wall-clock age catches resume,
            // clock corrections, and missed main-timer events within a minute.
            const refreshOverdue = root.location.valid
                && successfulAge > root.fetchInterval + 60 * 1000
            const attemptDue = root.lastFetchAttemptMs <= 0
                || now - root.lastFetchAttemptMs > Math.max(60 * 1000, root.fetchInterval)
            if (refreshOverdue && attemptDue)
                root.getData()
        }
    }

    PositionSource {
        id: positionSource
        updateInterval: root.fetchInterval
        onPositionChanged: {
            if (!position.latitudeValid || !position.longitudeValid) return
            root.location = {
                valid: true,
                lat: position.coordinate.latitude,
                lon: position.coordinate.longitude
            }
            root.usingLiveLocation = true
            root.getData()
        }
        onValidityChanged: {
            if (!positionSource.valid) {
                positionSource.stop()
                root.usingLiveLocation = false
                root.location = {
                    valid: root.hasFallbackLocation,
                    lat: root.hasFallbackLocation ? root.fallbackLat : 0,
                    lon: root.hasFallbackLocation ? root.fallbackLon : 0
                }
                console.warn(root.hasFallbackLocation
                    ? "[WeatherService] GPS unavailable; using private fallback."
                    : "[WeatherService] GPS unavailable; weather waits for a private fallback.")
                root.getData()
            }
        }
    }

    FileView {
        id: lockWeatherFile
        path: Qt.resolvedUrl(`${Directories.cache}/weather-lock.txt`)
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound)
                lockWeatherFile.setText("目前位置 · 天氣資料讀取中\n體感 -- · 濕度 -- · 風速 -- · 近 15 分鐘雨量 --\n能見度 -- · 氣壓 -- · 日出 -- · 日落 -- · 更新 --")
        }
    }

    IpcHandler {
        target: "weather"

        readonly property bool fetching: fetcher.running
        readonly property string summary: JSON.stringify(root.data)

        function refresh(): void {
            root.getData()
        }
    }

    Timer {
        running: Config.options.bar.weather.enable
        repeat: true
        interval: root.fetchInterval
        triggeredOnStart: true
        onTriggered: root.getData()
    }
}
