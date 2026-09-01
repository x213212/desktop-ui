// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 desktop-ui contributors
//
// Session-lock controller implemented against the Quickshell 0.2.1 Wayland API:
// https://quickshell.org/docs/v0.2.1/types/Quickshell.Wayland/WlSessionLock/

pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    required property Component lockSurface
    property alias context: authentication

    function prepareLockedSession() {
        authentication.reset()
        authentication.tryFingerUnlock()
    }

    function unlockKeyring(password: string) {
        keyringUnlock.exec({
            environment: ({ "UNLOCK_PASSWORD": password }),
            command: ["bash", Quickshell.shellPath("scripts/keyring/unlock.sh")]
        })
    }

    function finishAuthentication(action) {
        if (action === LockContext.ActionEnum.Poweroff) {
            Session.poweroff()
            return
        }
        if (action === LockContext.ActionEnum.Reboot) {
            Session.reboot()
            return
        }

        const password = authentication.currentText
        const inhibitAfterUnlock = authentication.alsoInhibitIdle
        if (Config.options.lock.security.unlockKeyring)
            root.unlockKeyring(password)

        // Release the compositor lock before resetting or reloading UI state.
        GlobalStates.screenLocked = false
        authentication.reset()
        if (inhibitAfterUnlock)
            Idle.toggleInhibit(true)
    }

    function requestLock() {
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.local/bin/secure-screen-lock",
            "--mark-session"
        ])
    }

    function initializeWhenReady() {
        if (!Config.ready || !Persistent.ready)
            return
        if (Config.options.lock.launchOnStartup && Persistent.isNewHyprlandInstance)
            root.requestLock()
        else
            KeyringStorage.fetchKeyringData()
    }

    LockContext {
        id: authentication
        onUnlocked: action => root.finishAuthentication(action)
    }

    Connections {
        target: GlobalStates

        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked)
                root.prepareLockedSession()
        }
    }

    Process {
        id: keyringUnlock
        onExited: (exitCode, exitStatus) => KeyringStorage.fetchKeyringData()
    }

    WlSessionLock {
        id: sessionLock
        locked: GlobalStates.screenLocked

        WlSessionLockSurface {
            color: "transparent"

            Loader {
                anchors.fill: parent
                active: sessionLock.locked
                opacity: active ? 1 : 0
                sourceComponent: root.lockSurface

                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }
        }
    }

    IpcHandler {
        target: "lock"
        function activate(): void { root.requestLock() }
        function focus(): void { authentication.shouldReFocus() }
    }

    CompositorGlobalShortcut {
        name: "lock"
        description: "Locks the screen"
        onPressed: root.requestLock()
    }

    CompositorGlobalShortcut {
        name: "lockFocus"
        description: "Re-focus the lock surface after compositor wakeup"
        onPressed: authentication.shouldReFocus()
    }

    Connections {
        target: Config
        function onReadyChanged() { root.initializeWhenReady() }
    }

    Connections {
        target: Persistent
        function onReadyChanged() { root.initializeWhenReady() }
    }
}
