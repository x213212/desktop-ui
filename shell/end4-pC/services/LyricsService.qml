pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer

    property var lyricsLines: []
    property int activeIndex: -1
    property string status: "idle"
    property var slots: ["", "", "", "", "", "", ""]
    property int consumerCount: 0
    readonly property bool active: consumerCount > 0

    readonly property int before: 3
    readonly property int after:  3
    readonly property int total:  7

    function buildSlots(idx) {
        let result = []
        for (let i = 0; i < root.total; i++) {
            let lineIdx = idx - root.before + i
            if (lineIdx >= 0 && lineIdx < root.lyricsLines.length)
                result.push(root.lyricsLines[lineIdx].text || "♪")
            else
                result.push("")
        }
        return result
    }

    Timer {
        id: syncTimer
        interval: 300
        repeat: true
        running: root.active && root.status === "ok" && root.lyricsLines.length > 0
        onTriggered: {
            const pos = root.activePlayer?.position ?? 0
            let idx = -1
            for (let i = 0; i < root.lyricsLines.length; i++) {
                if (root.lyricsLines[i].time <= pos) idx = i
                else break
            }
            if (idx !== root.activeIndex) {
                root.activeIndex = idx
                root.slots = root.buildSlots(idx)
            }
        }
    }

    // A player commonly publishes player/title/artist changes as a short
    // burst. Coalesce them so one track change launches one lyrics process.
    Timer {
        id: metadataRestartDebounce
        interval: 120
        repeat: false
        onTriggered: root.restartLyrics()
    }

    Process {
        id: lyricsProc
        running: false
        stdout: SplitParser {
            onRead: data => {
                const trimmed = data.trim()
                if (trimmed === "not_found") { root.status = "not_found"; return }
                if (trimmed === "no_info")   { root.status = "no_info";   return }

                const parts = trimmed.split("§")
                if (parts.length < 3) return
                if (parts[parts.length - 1].trim() !== "ok") return

                let lines = []
                for (let i = 0; i < parts.length - 1; i += 2) {
                    const t = parseFloat(parts[i])
                    const txt = parts[i + 1] || ""
                    if (!isNaN(t)) lines.push({ time: t, text: txt })
                }

                if (lines.length === 0) { root.status = "not_found"; return }

                root.lyricsLines = lines
                root.activeIndex = -1
                root.slots = root.buildSlots(-1)
                root.status = "ok"
            }
        }
    }

    function restartLyrics() {
        // An explicit/manual refresh owns this restart; cancel any queued
        // metadata burst so it cannot launch the same request again.
        metadataRestartDebounce.stop()
        lyricsProc.running = false
        root.lyricsLines = []
        root.activeIndex = -1
        root.slots = ["", "", "", "", "", "", ""]
        root.status = root.active ? "loading" : "idle"

        if (!root.active) return

        const title    = root.activePlayer?.trackTitle  ?? ""
        const artist   = root.activePlayer?.trackArtist ?? ""
        const duration = root.activePlayer?.length       ?? 0

        if (!title || !artist) { root.status = "no_info"; return }

        lyricsProc.command = [
            "python3",
            `${Directories.scriptPath}/lyrics/lyrics.py`,
            title, artist, String(Math.floor(duration))
        ]
        lyricsProc.running = true
    }

    function scheduleLyricsRestart() {
        if (!root.active) return
        metadataRestartDebounce.restart()
    }

    function acquire() {
        root.consumerCount += 1
        if (root.consumerCount === 1) {
            MprisController.acquirePositionUpdates()
            root.restartLyrics()
        }
    }

    function release() {
        if (root.consumerCount === 0) return
        root.consumerCount -= 1
        if (root.consumerCount !== 0) return
        MprisController.releasePositionUpdates()
        metadataRestartDebounce.stop()
        lyricsProc.running = false
        root.lyricsLines = []
        root.activeIndex = -1
        root.slots = ["", "", "", "", "", "", ""]
        root.status = "idle"
    }

    onActivePlayerChanged: {
        root.scheduleLyricsRestart()
    }

    Connections {
        target: root.activePlayer
        function onTrackTitleChanged() { root.scheduleLyricsRestart() }
        function onTrackArtistChanged() { root.scheduleLyricsRestart() }
    }
}
