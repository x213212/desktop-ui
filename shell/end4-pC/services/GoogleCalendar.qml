pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var events: []
    property string account: ""
    property string error: ""
    property string fetchedAt: ""
    property string rangeStart: ""
    property string rangeEnd: ""
    property bool loading: false
    property bool initialized: false
    property double lastAttemptMs: 0
    property double lastSuccessMs: 0
    property var firedReminderKeys: ({})
    property int retryDelayMs: 2000
    property bool refreshQueued: false
    property bool queuedForceRefresh: false
    property int startupWaitCount: 0

    readonly property int minimumRefreshGapMs: 5 * 60 * 1000
    readonly property int reminderGraceMs: 10 * 60 * 1000
    readonly property int maximumTimerIntervalMs: 24 * 60 * 60 * 1000
    readonly property bool hasEvents: events.length > 0
    readonly property var eventsByDate: {
        const index = {}
        for (const event of root.events) {
            for (const key of (event.dateKeys ?? [event.dateKey])) {
                if (!key) continue
                if (!index[key]) index[key] = []
                index[key].push(event)
            }
        }
        return index
    }

    // Lets shell.qml explicitly instantiate this singleton during startup.
    function load() {}

    function eventsForDate(dateKey) {
        return root.eventsByDate[dateKey] ?? []
    }

    function refresh(force) {
        const forceRefresh = force === undefined ? true : Boolean(force)
        const now = Date.now()
        if (calendarProc.running) {
            root.refreshQueued = true
            root.queuedForceRefresh = root.queuedForceRefresh || forceRefresh
            return
        }
        if (!forceRefresh && root.lastAttemptMs > 0 &&
                now - root.lastAttemptMs < root.minimumRefreshGapMs)
            return

        root.loading = true
        root.error = ""
        root.lastAttemptMs = now
        calendarProc.resultApplied = false
        calendarProc.succeeded = false
        calendarProc.running = true
        syncDeadline.restart()
    }

    function scheduleRetry() {
        if (retryTimer.running) return
        retryTimer.interval = root.retryDelayMs
        // The regular five-minute poll is already a recovery path.  Cap the
        // retry cadence there so a permanent auth error cannot spin forever.
        root.retryDelayMs = Math.min(root.retryDelayMs * 2, 5 * 60 * 1000)
        retryTimer.restart()
    }

    function applyResult(result, fromCache) {
        root.initialized = true
        if (!result?.ok) {
            root.error = result?.error ?? "無法讀取 Google Calendar"
            if (result?.account)
                root.account = result.account
            return false
        }

        root.events = Array.isArray(result.events) ? result.events : []
        root.account = result.account ?? ""
        root.fetchedAt = result.fetchedAt ?? ""
        root.rangeStart = result.rangeStart ?? ""
        root.rangeEnd = result.rangeEnd ?? ""
        root.error = ""
        if (fromCache) {
            root.lastSuccessMs = Number(result.cachedAt) || 0
        } else {
            root.lastSuccessMs = Date.now()
            root.retryDelayMs = 2000
            retryTimer.stop()
            calendarCacheView.setText(JSON.stringify({
                ok: true,
                account: root.account,
                fetchedAt: root.fetchedAt,
                rangeStart: root.rangeStart,
                rangeEnd: root.rangeEnd,
                events: root.events,
                cachedAt: root.lastSuccessMs
            }))
        }
        root.scheduleNearestReminder()
        return true
    }

    function reminderEntries() {
        const entries = []
        for (const event of root.events) {
            for (const reminder of (event.reminders ?? [])) {
                const triggerMs = Number(reminder.triggerMs)
                if (!Number.isFinite(triggerMs) || !reminder.key)
                    continue
                entries.push({ event, reminder, triggerMs })
            }
        }
        entries.sort((left, right) => left.triggerMs - right.triggerMs)
        return entries
    }

    function stableSyncHint(value) {
        let hash = 2166136261
        const text = String(value)
        for (let index = 0; index < text.length; ++index) {
            hash ^= text.charCodeAt(index)
            hash = Math.imul(hash, 16777619)
        }
        return `uios-google-calendar-${(hash >>> 0).toString(16)}`
    }

    function escapedMarkup(value) {
        return String(value ?? "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
    }

    function reminderLeadText(minutes) {
        if (minutes <= 0)
            return "現在開始"
        if (minutes % (24 * 60) === 0)
            return `${minutes / (24 * 60)} 天後開始`
        if (minutes % 60 === 0)
            return `${minutes / 60} 小時後開始`
        return `${minutes} 分鐘後開始`
    }

    function sendReminder(entry) {
        const event = entry.event
        const reminder = entry.reminder
        const key = String(reminder.key)
        if (root.firedReminderKeys[key])
            return
        root.firedReminderKeys[key] = true

        let body = `${root.reminderLeadText(Number(reminder.minutes) || 0)} · ${event.timeLabel ?? ""}`
        if (event.location)
            body += `\n${event.location}`
        Quickshell.execDetached([
            "notify-send",
            "-u", "normal",
            "-a", "Google Calendar",
            "-i", "x-office-calendar",
            "-c", "appointment",
            "-h", `string:x-canonical-private-synchronous:${root.stableSyncHint(key)}`,
            root.escapedMarkup(event.title || "Google Calendar 行程"),
            root.escapedMarkup(body)
        ])
    }

    function scheduleNearestReminder() {
        reminderTimer.stop()
        const now = Date.now()
        let nearestFutureMs = -1

        for (const entry of root.reminderEntries()) {
            const key = String(entry.reminder.key)
            if (root.firedReminderKeys[key])
                continue
            if (entry.triggerMs < now - root.reminderGraceMs)
                continue
            if (entry.triggerMs <= now) {
                root.sendReminder(entry)
                continue
            }
            nearestFutureMs = entry.triggerMs
            break
        }

        if (nearestFutureMs < 0)
            return
        reminderTimer.interval = Math.max(50, Math.min(
            nearestFutureMs - Date.now(), root.maximumTimerIntervalMs))
        reminderTimer.restart()
    }

    Component.onCompleted: startupTimer.restart()

    Connections {
        target: GlobalStates

        function onSidebarRightOpenChanged() {
            if (GlobalStates.sidebarRightOpen)
                root.refresh(false)
        }
    }

    Process {
        id: calendarProc
        property bool resultApplied: false
        property bool succeeded: false

        command: ["python3", `${Directories.scriptPath}/google-calendar.py`]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return
                try {
                    const result = JSON.parse(text)
                    calendarProc.resultApplied = true
                    calendarProc.succeeded = root.applyResult(result, false)
                } catch (parseError) {
                    root.initialized = true
                    root.error = "Google Calendar 回傳格式錯誤"
                }
            }
        }
        onExited: {
            syncDeadline.stop()
            root.loading = false
            if (!calendarProc.resultApplied && !root.error) {
                root.initialized = true
                root.error = "Google Calendar 同步程序沒有回傳資料"
            }
            if (!calendarProc.succeeded)
                root.scheduleRetry()
            if (root.refreshQueued) {
                const force = root.queuedForceRefresh
                root.refreshQueued = false
                root.queuedForceRefresh = false
                Qt.callLater(() => root.refresh(force))
            }
        }
    }

    Timer {
        id: startupTimer
        // Gmail starts at 750 ms.  The small stagger makes it deterministic
        // which service owns the first GOA handshake after login.
        interval: 900
        repeat: false
        onTriggered: {
            // Gmail owns the first GOA/IMAP handshake.  Wait a bounded amount
            // so login never launches all Google network jobs at once.
            if (Gmail.loading && root.startupWaitCount < 12) {
                root.startupWaitCount++
                startupTimer.interval = 400
                startupTimer.restart()
                return
            }
            root.refresh(true)
        }
    }

    Timer {
        id: syncDeadline
        interval: 12 * 1000
        repeat: false
        onTriggered: {
            if (!calendarProc.running) return
            root.error = root.events.length > 0
                ? "Google 日曆網路尚未就緒，顯示上次同步內容"
                : "Google 日曆網路尚未就緒，正在背景重試"
            calendarProc.running = false
        }
    }

    Timer {
        id: retryTimer
        repeat: false
        onTriggered: root.refresh(true)
    }

    FileView {
        id: calendarCacheView
        path: Qt.resolvedUrl(Directories.googleCalendarCachePath)
        onLoaded: {
            if (root.lastSuccessMs > 0) return
            try {
                const cached = JSON.parse(calendarCacheView.text())
                if (cached?.ok && Array.isArray(cached.events))
                    root.applyResult(cached, true)
            } catch (error) {
                console.warn("[GoogleCalendar] Ignoring invalid cache")
            }
        }
    }

    IpcHandler {
        target: "googleCalendar"
        function refresh(): void { root.refresh(true) }
    }

    // Calendar has no push channel here; five minutes is frequent enough for
    // an agenda while avoiding a permanently busy OAuth/network poller.
    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refresh(false)
    }

    // Exactly one deadline timer. Long waits are bounded to one wake-up per
    // day so Qt's signed millisecond interval cannot overflow for day-30 data.
    Timer {
        id: reminderTimer
        repeat: false
        onTriggered: root.scheduleNearestReminder()
    }
}
