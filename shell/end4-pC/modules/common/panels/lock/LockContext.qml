// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 desktop-ui contributors
//
// Authentication controller implemented against the Quickshell 0.2.1 PAM API:
// https://quickshell.org/docs/v0.2.1/types/Quickshell.Services.Pam/PamContext/

import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Scope {
    id: root

    enum ActionEnum { Unlock, Poweroff, Reboot }

    signal shouldReFocus()
    signal unlocked(targetAction: var)
    signal failed()

    property alias currentText: state.password
    property alias unlockInProgress: state.passwordBusy
    property alias showFailure: state.showFailure
    property alias fingerprintsConfigured: state.fingerprintsConfigured
    property alias targetAction: state.targetAction
    property alias alsoInhibitIdle: state.alsoInhibitIdle

    QtObject {
        id: state

        property string password: ""
        property bool passwordBusy: false
        property bool showFailure: false
        property bool fingerprintsConfigured: false
        property var targetAction: LockContext.ActionEnum.Unlock
        property bool alsoInhibitIdle: false
        property int authEpoch: 0
    }

    function resetTargetAction() {
        state.targetAction = LockContext.ActionEnum.Unlock
    }

    function clearText() {
        state.password = ""
    }

    function resetClearTimer() {
        passwordExpiry.restart()
    }

    function stopFingerPam() {
        if (fingerprintAuth.active)
            fingerprintAuth.abort()
    }

    function reset() {
        state.authEpoch += 1
        if (passwordAuth.active)
            passwordAuth.abort()
        root.stopFingerPam()
        fingerprintRetry.stop()
        passwordExpiry.stop()
        state.password = ""
        state.passwordBusy = false
        state.showFailure = false
        state.alsoInhibitIdle = false
        root.resetTargetAction()
        GlobalStates.screenLockContainsCharacters = false
        GlobalStates.screenUnlockFailed = false
    }

    function tryUnlock(alsoInhibitIdle = false) {
        if (passwordAuth.active)
            return
        state.authEpoch += 1
        passwordAuth.requestEpoch = state.authEpoch
        root.stopFingerPam()
        fingerprintRetry.stop()
        state.alsoInhibitIdle = alsoInhibitIdle
        state.passwordBusy = passwordAuth.start()
        if (!state.passwordBusy)
            root.rejectAuthentication()
    }

    function tryFingerUnlock() {
        if (state.fingerprintsConfigured
                && !passwordAuth.active
                && !fingerprintAuth.active) {
            fingerprintAuth.requestEpoch = state.authEpoch
            fingerprintAuth.start()
        }
    }

    function acceptAuthentication() {
        state.passwordBusy = false
        passwordExpiry.stop()
        root.stopFingerPam()
        root.unlocked(state.targetAction)
    }

    function rejectAuthentication() {
        passwordExpiry.stop()
        state.password = ""
        state.passwordBusy = false
        state.showFailure = true
        GlobalStates.screenUnlockFailed = true
        root.failed()
    }

    onCurrentTextChanged: {
        const containsCharacters = state.password.length > 0
        GlobalStates.screenLockContainsCharacters = containsCharacters
        if (containsCharacters) {
            state.showFailure = false
            GlobalStates.screenUnlockFailed = false
            passwordExpiry.restart()
        }
    }

    Timer {
        id: passwordExpiry
        interval: 10000
        repeat: false
        onTriggered: root.reset()
    }

    Process {
        id: fingerprintProbe
        running: true
        command: ["fprintd-list", Quickshell.env("USER")]

        stdout: StdioCollector {
            onStreamFinished: {
                state.fingerprintsConfigured = text.includes("Fingerprints for user")
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                state.fingerprintsConfigured = false
        }
    }

    PamContext {
        id: passwordAuth
        property int requestEpoch: -1

        onPamMessage: {
            if (responseRequired)
                respond(state.password)
        }

        onCompleted: result => {
            if (requestEpoch !== state.authEpoch)
                return
            if (result === PamResult.Success)
                root.acceptAuthentication()
            else
                root.rejectAuthentication()
        }
    }

    PamContext {
        id: fingerprintAuth
        property int requestEpoch: -1
        configDirectory: "pam"
        config: "fprintd.conf"

        onCompleted: result => {
            if (requestEpoch !== state.authEpoch)
                return
            if (result === PamResult.Success) {
                root.acceptAuthentication()
            } else if (result === PamResult.Error
                    && GlobalStates.screenLocked
                    && state.fingerprintsConfigured) {
                fingerprintRetry.restart()
            }
        }
    }

    // Avoid recursively starting PAM from its own completion callback.
    Timer {
        id: fingerprintRetry
        interval: 250
        repeat: false
        onTriggered: root.tryFingerUnlock()
    }
}
