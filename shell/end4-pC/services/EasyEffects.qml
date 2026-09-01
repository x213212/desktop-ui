import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
pragma Singleton
pragma ComponentBehavior: Bound

/**
 * Handles EasyEffects active state and presets.
 */
Singleton {
    id: root

    property bool available: false
    property bool active: false

    function fetchAvailability() {
        fetchAvailabilityProc.running = true
    }

    function fetchActiveState() {
        fetchActiveStateProc.running = true
    }

    function disable() {
        root.active = false
        controlProc.requestedActive = false
        controlProc.running = true
    }

    function enable() {
        root.active = true
        controlProc.requestedActive = true
        controlProc.running = true
    }

    function toggle() {
        if (root.active) {
            root.disable()
        } else {
            root.enable()
        }
    }

    Process {
        id: fetchAvailabilityProc
        running: true
        command: ["flatpak", "info", "com.github.wwmm.easyeffects"]
        onExited: (exitCode, exitStatus) => {
            root.available = exitCode === 0
        }
    }

    Process {
        id: fetchActiveStateProc
        running: true
        command: ["systemctl", "--user", "is-active", "--quiet", "easyeffects-flatpak.service"]
        onExited: (exitCode, exitStatus) => {
            root.active = exitCode === 0
        }
    }

    Process {
        id: controlProc
        property bool requestedActive: false
        command: [
            "systemctl", "--user",
            requestedActive ? "start" : "stop",
            "easyeffects-flatpak.service"
        ]
        onExited: (exitCode, exitStatus) => root.fetchActiveState()
    }

    IpcHandler {
        target: "easyEffects"
        function refresh(): void { root.fetchActiveState() }
    }
}
