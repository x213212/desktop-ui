pragma Singleton
import Quickshell
import qs.services
import qs.modules.common

Singleton {
    id: root

    readonly property string sessionAction: Quickshell.env("HOME") + "/.local/bin/uios-session-action"
    readonly property string secureScreenLock: Quickshell.env("HOME") + "/.local/bin/secure-screen-lock"

    function runSessionAction(action) {
        Quickshell.execDetached([root.sessionAction, action]);
    }

    function changePassword() {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.changePassword}`]);
    }

    function lock() {
        if (WM.compositor === "niri") {
            Quickshell.execDetached(["qs", "-c", "end4-pC", "ipc", "call", "lock", "activate"]);
        } else {
            Quickshell.execDetached([root.secureScreenLock, "--mark-session"]);
        }
    }

    function suspend() {
        runSessionAction("suspend");
    }

    function logout() {
        if (WM.compositor === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "quit"]);
        } else {
            runSessionAction("logout");
        }
    }

    function launchTaskManager() {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.taskManager}`]);
    }

    function hibernate() {
        runSessionAction("hibernate");
    }

    function poweroff() {
        runSessionAction("poweroff");
    }

    function reboot() {
        runSessionAction("reboot");
    }

    function rebootToFirmware() {
        runSessionAction("firmware");
    }
}
