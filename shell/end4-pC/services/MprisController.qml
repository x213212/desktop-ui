// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 desktop-ui contributors
//
// Implemented for desktop-ui using the Quickshell 0.2.1 MPRIS API:
// https://quickshell.org/docs/v0.2.1/types/Quickshell.Services.Mpris/Mpris/
// https://quickshell.org/docs/v0.2.1/types/Quickshell.Services.Mpris/MprisPlayer/

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

Singleton {
    id: root

    // Present a useful default while avoiding the duplicate proxy players that
    // some desktop and browser integrations publish on the session bus.
    readonly property list<MprisPlayer> players: {
        const discovered = Mpris.players.values
        if (!Config.options.media.filterDuplicatePlayers)
            return discovered

        const plasmaOwnsBrowserMedia = discovered.some(candidate =>
            String(candidate.dbusName ?? "").startsWith(
                "org.mpris.MediaPlayer2.plasma-browser-integration"
            )
        )

        return discovered.filter(candidate => {
            const service = String(candidate.dbusName ?? "")
            if (service.startsWith("org.mpris.MediaPlayer2.playerctld"))
                return false
            if (service.endsWith(".mpd")
                    && !service.endsWith("MediaPlayer2.mpd")) {
                return false
            }
            if (plasmaOwnsBrowserMedia
                    && (service.startsWith("org.mpris.MediaPlayer2.firefox")
                        || service.startsWith("org.mpris.MediaPlayer2.chromium"))) {
                return false
            }
            return true
        })
    }

    // Playback state is the only selection policy: prefer the first player
    // that is actually playing, then fall back to the first visible player.
    readonly property MprisPlayer activePlayer: {
        for (const candidate of root.players) {
            if (candidate.playbackState === MprisPlaybackState.Playing)
                return candidate
        }
        return root.players.length > 0 ? root.players[0] : null
    }

    QtObject {
        id: positionDemand

        property int subscribers: 0

        function add() {
            subscribers += 1
        }

        function remove() {
            if (subscribers > 0)
                subscribers -= 1
        }
    }

    readonly property bool positionRefreshNeeded: {
        if (positionDemand.subscribers === 0)
            return false
        return Mpris.players.values.some(candidate =>
            candidate.playbackState === MprisPlaybackState.Playing
        )
    }

    // Quickshell exposes positionChanged() as the supported way to sample an
    // advancing MPRIS position. One clock services every visible consumer.
    Timer {
        interval: Math.max(100, Config.options.resources.updateInterval)
        repeat: true
        running: root.positionRefreshNeeded

        onTriggered: {
            for (const candidate of Mpris.players.values) {
                if (candidate.playbackState === MprisPlaybackState.Playing)
                    candidate.positionChanged()
            }
        }
    }

    function acquirePositionUpdates() {
        positionDemand.add()
    }

    function releasePositionUpdates() {
        positionDemand.remove()
    }

    function controlActive(action: string) {
        const candidate = root.activePlayer
        if (!candidate)
            return

        if (action === "toggle" && candidate.canTogglePlaying)
            candidate.togglePlaying()
        else if (action === "previous" && candidate.canGoPrevious)
            candidate.previous()
        else if (action === "next" && candidate.canGoNext)
            candidate.next()
    }

    function pauseEveryPlayer() {
        for (const candidate of Mpris.players.values) {
            if (candidate.canPause)
                candidate.pause()
        }
    }

    IpcHandler {
        target: "mpris"

        function playPause(): void {
            root.controlActive("toggle")
        }

        function previous(): void {
            root.controlActive("previous")
        }

        function next(): void {
            root.controlActive("next")
        }

        function pauseAll(): void {
            root.pauseEveryPlayer()
        }
    }
}
