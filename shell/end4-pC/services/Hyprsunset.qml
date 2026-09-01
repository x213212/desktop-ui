pragma Singleton

import QtQuick
import qs.modules.common
import qs.services
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    signal gammaChangeAttempt()

    readonly property real gammaLowerLimit: 25
    readonly property bool isNiri: WM.compositor === "niri"

    property string from: Config.options?.light?.night?.from ?? "19:00"
    property string to: Config.options?.light?.night?.to ?? "06:30"
    property bool automatic: (Config.options?.light?.night?.automatic ?? false) && (Config?.ready ?? true)
    property int colorTemperature: Config.options?.light?.night?.colorTemperature ?? 5000
    property int gamma: 100
    property bool shouldBeOn
    property bool stateKnown: false
    property bool temperatureActive: false
    property bool applyFailed: false

    property int fromHour: Number(from.split(":")[0])
    property int fromMinute: Number(from.split(":")[1])
    property int toHour: Number(to.split(":")[0])
    property int toMinute: Number(to.split(":")[1])

    property int clockHour: DateTime.clock.hours
    property int clockMinute: DateTime.clock.minutes

    property var manualActive
    property int manualActiveHour
    property int manualActiveMinute

    onClockMinuteChanged: reEvaluate()
    onAutomaticChanged: {
        root.manualActive = undefined;
        root.reEvaluate(true);
    }
    onFromChanged: root.reEvaluate(true)
    onToChanged: root.reEvaluate(true)

    function inBetween(t, from, to) {
        if (from < to) {
            return (t >= from && t <= to);
        } else {
            return (t >= from || t <= to);
        }
    }

    function reEvaluate(force = false) {
        const t = clockHour * 60 + clockMinute;
        const from = fromHour * 60 + fromMinute;
        const to = toHour * 60 + toMinute;
        const manualActive = manualActiveHour * 60 + manualActiveMinute;

        if (root.manualActive !== undefined && (inBetween(from, manualActive, t) || inBetween(to, manualActive, t))) {
            root.manualActive = undefined;
        }
        const desired = inBetween(t, from, to);
        const changed = desired !== root.shouldBeOn;
        root.shouldBeOn = desired;
        if (force || changed)
            root.ensureState();
    }

    function ensureState() {
        if (!root.stateKnown || root.applyFailed || !root.automatic || root.manualActive !== undefined)
            return;
        if (root.shouldBeOn && !root.temperatureActive) {
            root.enableTemperature();
        } else if (!root.shouldBeOn && root.temperatureActive) {
            root.disableTemperature();
        }
    }

    function startHyprsunset() {
        if (root.isNiri) return;
        Quickshell.execDetached(["bash", "-c", `pidof hyprsunset || hyprsunset`]);
    }

    function load() {
        // Probe once, then only apply changes at a schedule boundary or user
        // action. Stable daytime/nighttime state spawns no subprocesses.
        root.fetchState();
    }

    function enableTemperature() {
        if (root.isNiri) {
            root.startNiriSunset(root.colorTemperature);
        } else {
            if (applyTemperatureProc.running) return;
            root.applyFailed = false;
            applyTemperatureProc.command = ["bash", "-c",
                `if ! pidof hyprsunset >/dev/null; then hyprsunset >/dev/null 2>&1 & fi; `
                + `for attempt in 1 2 3 4 5; do hyprctl hyprsunset temperature ${root.colorTemperature} && exit 0; sleep 0.1; done; exit 1`
            ];
            applyTemperatureProc.running = true;
        }
        if (root.isNiri)
            root.temperatureActive = true;
    }

    function disableTemperature() {
        if (root.isNiri) {
            root.stopNiriSunset();
        } else {
            Quickshell.execDetached(["hyprctl", "hyprsunset", "identity"]);
        }
        root.temperatureActive = false;
    }

    function setGamma(gamma) {
        root.gamma = Math.max(root.gammaLowerLimit, Math.min(100, gamma));
        root.gammaChangeAttempt();

        if (root.isNiri) {
            return;
        }
        root.startHyprsunset();
        Quickshell.execDetached(["bash", "-c", `hyprctl hyprsunset gamma ${root.gamma}`]);
    }

    function startNiriSunset(temp) {
        const low = temp;
        const high = temp + 50;
        Quickshell.execDetached(["bash", "-c",
            `pkill -x wlsunset; sleep 0.05; wlsunset -T ${high} -t ${low} -S 23:59 -s 00:00 -d 1 & disown`]);
    }

    function stopNiriSunset() {
        Quickshell.execDetached(["bash", "-c", "pkill -x wlsunset"]);
    }

    function fetchState() {
        if (root.isNiri) {
            niriFetchProc.running = true;
        } else {
            if (!fetchProc.running)
                fetchProc.running = true;
        }
    }

    Process {
        id: fetchProc
        running: false
        command: ["hyprctl", "hyprsunset", "identity", "get"]
        stdout: StdioCollector {
            id: stateCollector
            onStreamFinished: {
                const output = stateCollector.text.trim();
                if (output !== "true" && output !== "false") {
                    root.temperatureActive = false;
                    // A missing daemon is a known inactive state. This lets a
                    // scheduled night transition start it exactly once.
                    root.stateKnown = true;
                    root.reEvaluate(true);
                    return;
                }
                root.temperatureActive = (output === "false");
                root.stateKnown = true;
                root.applyFailed = false;
                root.reEvaluate(true);
            }
        }
    }

    Process {
        id: applyTemperatureProc
        running: false
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.fetchState();
            } else {
                // Do not turn a missing daemon/IPC endpoint into an unbounded
                // process-spawn loop. The next explicit setting change retries.
                root.temperatureActive = false;
                root.stateKnown = false;
                root.applyFailed = true;
                console.warn(`[Hyprsunset] apply failed with status ${exitCode}`);
            }
        }
    }

    Process {
        id: niriFetchProc
        running: false
        command: ["pgrep", "-x", "wlsunset"]
        stdout: StdioCollector {
            id: niriStateCollector
            onStreamFinished: {
                root.temperatureActive = niriStateCollector.text.trim().length > 0;
                root.stateKnown = true;
                root.reEvaluate(true);
            }
        }
    }

    function toggleTemperature(active = undefined) {
        root.stateKnown = true;
        if (root.manualActive === undefined) {
            root.manualActive = root.temperatureActive;
            root.manualActiveHour = root.clockHour;
            root.manualActiveMinute = root.clockMinute;
        }

        root.manualActive = active !== undefined ? active : !root.manualActive;
        if (root.manualActive) {
            root.enableTemperature();
        } else {
            root.disableTemperature();
        }
    }

    Connections {
        target: Config.options.light.night
        function onColorTemperatureChanged() {
            if (!root.temperatureActive) return;
            if (root.isNiri) {
                root.startNiriSunset(Config.options.light.night.colorTemperature);
            } else {
                Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", `${Config.options.light.night.colorTemperature}`]);
            }
        }
    }
}
