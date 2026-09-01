pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property var messages: []
    property string account: ""
    property string error: ""
    property bool loading: false
    property bool initialized: false
    property bool pushConnected: false
    property string newestId: ""
    property double lastSuccessMs: 0
    property int retryDelayMs: 1500
    property bool refreshQueued: false
    readonly property int unreadCount: messages.filter(message => message.unread).length

    Component.onCompleted: startupTimer.restart()

    function refresh() {
        if (gmailProc.running) {
            root.refreshQueued = true
            return
        }
        root.loading = true
        root.error = ""
        gmailProc.resultApplied = false
        gmailProc.succeeded = false
        gmailProc.running = true
        syncDeadline.restart()
    }

    function scheduleRetry() {
        if (retryTimer.running) return
        retryTimer.interval = root.retryDelayMs
        // A missing account or long network outage must not leave a process
        // waking once per minute forever.
        root.retryDelayMs = Math.min(root.retryDelayMs * 2, 15 * 60 * 1000)
        retryTimer.restart()
    }

    function ensureWatcher() {
        if (!gmailWatchProc.running && !watchRestartTimer.running)
            gmailWatchProc.running = true
    }

    function applyResult(result, fromCache) {
        if (!result?.ok) {
            root.error = result?.error ?? "無法讀取 Gmail"
            root.initialized = true
            return false
        }

        const incoming = result.messages ?? []
        const previousNewest = root.newestId
        root.messages = incoming
        root.account = result.account ?? ""
        root.newestId = incoming.length > 0 ? incoming[0].id : ""

        if (root.initialized && previousNewest && root.newestId !== previousNewest) {
            const fresh = []
            for (const message of incoming) {
                if (message.id === previousNewest) break
                if (message.unread) fresh.push(message)
            }
            if (fresh.length > 0) {
                for (const message of fresh.slice(0, 10)) {
                    Quickshell.execDetached([
                        "notify-send", "-u", "normal", "-a", "Gmail", "-i", "mail-unread",
                        `Gmail · ${message.sender}`,
                        message.subject
                    ])
                }
            }
        }
        root.initialized = true
        root.error = ""

        if (fromCache) {
            root.lastSuccessMs = Number(result.cachedAt) || 0
        } else {
            root.lastSuccessMs = Date.now()
            root.retryDelayMs = 1500
            retryTimer.stop()
            gmailCacheView.setText(JSON.stringify({
                ok: true,
                account: root.account,
                messages: root.messages,
                cachedAt: root.lastSuccessMs
            }))
        }
        return true
    }

    Process {
        id: gmailProc
        property bool resultApplied: false
        property bool succeeded: false

        command: ["python3", `${Directories.scriptPath}/gmail-summary.py`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    gmailProc.resultApplied = true
                    gmailProc.succeeded = root.applyResult(result, false)
                } catch (error) {
                    root.error = "Gmail 回傳格式錯誤"
                }
            }
        }
        onExited: {
            syncDeadline.stop()
            root.loading = false
            if (!gmailProc.resultApplied && !root.error)
                root.error = "Gmail 同步程序沒有回傳資料"
            if (!gmailProc.succeeded)
                root.scheduleRetry()
            else
                root.ensureWatcher()
            if (root.refreshQueued) {
                root.refreshQueued = false
                Qt.callLater(root.refresh)
            }
        }
    }

    Process {
        id: gmailWatchProc
        command: ["python3", `${Directories.scriptPath}/gmail-watch.py`]
        // Start only after the first summary attempt.  At login this avoids
        // racing two OAuth/IMAP handshakes against a GOA daemon still starting.
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line.trim()) return
                try {
                    const event = JSON.parse(line)
                    if (event.event === "ready") {
                        root.pushConnected = true
                    } else if (event.event === "changed") {
                        watchRefreshDebounce.restart()
                    } else if (event.event === "error") {
                        root.pushConnected = false
                    }
                } catch (error) {
                    root.pushConnected = false
                }
            }
        }
        onExited: {
            root.pushConnected = false
            watchRestartTimer.restart()
        }
    }

    Timer {
        id: watchRefreshDebounce
        interval: 750
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: watchRestartTimer
        interval: 5000
        repeat: false
        onTriggered: gmailWatchProc.running = true
    }

    Timer {
        id: startupTimer
        interval: 750
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: syncDeadline
        interval: 12 * 1000
        repeat: false
        onTriggered: {
            if (!gmailProc.running) return
            root.error = root.messages.length > 0
                ? "Gmail 網路尚未就緒，顯示上次同步內容"
                : "Gmail 網路尚未就緒，正在背景重試"
            gmailProc.running = false
        }
    }

    Timer {
        id: retryTimer
        repeat: false
        onTriggered: root.refresh()
    }

    FileView {
        id: gmailCacheView
        path: Qt.resolvedUrl(Directories.gmailCachePath)
        onLoaded: {
            // Never let a late disk callback overwrite a newer network result.
            if (root.lastSuccessMs > 0) return
            try {
                const cached = JSON.parse(gmailCacheView.text())
                if (cached?.ok && Array.isArray(cached.messages))
                    root.applyResult(cached, true)
            } catch (error) {
                console.warn("[Gmail] Ignoring invalid cache")
            }
        }
    }

    IpcHandler {
        target: "gmail"
        function refresh(): void { root.refresh() }
    }

    // Low-frequency fallback for a suspended machine or missed IDLE event.
    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
}
