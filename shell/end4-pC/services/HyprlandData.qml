pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

/**
 * Provides access to some Hyprland data not available in Quickshell.Hyprland.
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var layers: ({})
    // Latest titles received while a clients snapshot is in flight. Merge
    // them into that snapshot so an older process result cannot roll back a
    // newer compositor event.
    property var pendingWindowTitles: ({})

    // Each snapshot process is single-flight. If another refresh becomes
    // necessary while it is running, remember that fact and run once more
    // after exit instead of restarting the process or dropping the event.
    property bool clientsDirty: false
    property bool monitorsDirty: false
    property bool layersDirty: false
    property bool workspaceListDirty: false
    property bool activeWorkspaceDirty: false

    // Convenient stuff

    function toplevelsForWorkspace(workspace) {
        return ToplevelManager.toplevels.values.filter(toplevel => {
            const address = `0x${toplevel.HyprlandToplevel?.address}`;
            var win = HyprlandData.windowByAddress[address];
            return win?.workspace?.id === workspace;
        })
    }

    function hyprlandClientsForWorkspace(workspace) {
        return root.windowList.filter(win => win.workspace.id === workspace);
    }

    function clientForToplevel(toplevel) {
        if (!toplevel || !toplevel.HyprlandToplevel) {
            return null;
        }
        const address = `0x${toplevel?.HyprlandToplevel?.address}`;
        return root.windowByAddress[address];
    }

    // Internals

    function updateWindowList() {
        if (WM.compositor !== "hyprland") return;
        if (getClients.running) {
            root.clientsDirty = true;
            return;
        }
        root.clientsDirty = false;
        getClients.running = true;
    }

    function updateLayers() {
        if (WM.compositor !== "hyprland") return;
        if (getLayers.running) {
            root.layersDirty = true;
            return;
        }
        root.layersDirty = false;
        getLayers.running = true;
    }

    function updateMonitors() {
        if (WM.compositor !== "hyprland") return;
        if (getMonitors.running) {
            root.monitorsDirty = true;
            return;
        }
        root.monitorsDirty = false;
        getMonitors.running = true;
    }

    function updateWorkspaceList() {
        if (WM.compositor !== "hyprland") return;
        if (getWorkspaces.running) {
            root.workspaceListDirty = true;
            return;
        }
        root.workspaceListDirty = false;
        getWorkspaces.running = true;
    }

    function updateActiveWorkspace() {
        if (WM.compositor !== "hyprland") return;
        if (getActiveWorkspace.running) {
            root.activeWorkspaceDirty = true;
            return;
        }
        root.activeWorkspaceDirty = false;
        getActiveWorkspace.running = true;
    }

    function normalizeWindowAddress(value) {
        const text = String(value ?? "").trim();
        const rawAddress = text.startsWith("0x") ? text.slice(2) : text;
        if (!/^[0-9a-fA-F]+$/.test(rawAddress)) return "";
        return `0x${rawAddress.toLowerCase()}`;
    }

    function applyWindowTitleEvent(data) {
        const text = String(data ?? "");
        const separator = text.indexOf(",");
        if (separator <= 0) return false;

        const address = root.normalizeWindowAddress(text.slice(0, separator));
        const title = text.slice(separator + 1);
        if (!address) return false;

        if (getClients.running) {
            const pending = Object.assign({}, root.pendingWindowTitles);
            pending[address] = title;
            root.pendingWindowTitles = pending;
        }

        const current = root.windowByAddress[address];
        if (!current) return false;
        if (current.title === title) return true;

        const updated = Object.assign({}, current, { title: title });
        root.windowList = root.windowList.map(window =>
            window.address === address ? updated : window);
        const updatedByAddress = Object.assign({}, root.windowByAddress);
        updatedByAddress[address] = updated;
        root.windowByAddress = updatedByAddress;
        return true;
    }

    function updateWorkspaces() {
        updateWorkspaceList();
        updateActiveWorkspace();
    }

    function updateAll() {
        if (WM.compositor !== "hyprland") return;
        updateWindowList();
        updateMonitors();
        updateLayers();
        updateWorkspaces();
    }

    // Coalesce bursts of compositor events. Previously every raw event spawned
    // five hyprctl processes, including data unrelated to that event.
    Timer { id: clientsDebounce; interval: 160; onTriggered: root.updateWindowList() }
    Timer { id: monitorsDebounce; interval: 120; onTriggered: root.updateMonitors() }
    Timer { id: layersDebounce; interval: 80; onTriggered: root.updateLayers() }
    // Native Quickshell models drive the visible workspace indicator. Keep
    // this compatibility snapshot off the compositor's ~100 ms switch hot
    // path so process startup cannot steal one of the first rendered frames.
    Timer { id: activeWorkspaceDebounce; interval: 260; onTriggered: root.updateActiveWorkspace() }
    Timer { id: workspaceListDebounce; interval: 180; onTriggered: root.updateWorkspaceList() }
    // Legacy or malformed/early title events may not identify a client.
    // Native Toplevel titles remain authoritative; this only refreshes the
    // compatibility snapshot at most once every five seconds.
    Timer { id: titleFallbackTimer; interval: 5000; onTriggered: root.scheduleClients() }

    function scheduleClients() { clientsDebounce.restart(); }
    function scheduleMonitors() { monitorsDebounce.restart(); }
    function scheduleLayers() { layersDebounce.restart(); }
    function scheduleActiveWorkspace() { activeWorkspaceDebounce.restart(); }
    function scheduleWorkspaceList() { workspaceListDebounce.restart(); }
    function scheduleTitleFallback() {
        if (!titleFallbackTimer.running) titleFallbackTimer.start();
    }

    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }

    Component.onCompleted: {
        updateAll();
    }

    Connections {
        target: Hyprland
        enabled: WM.compositor === "hyprland"

        function onRawEvent(event) {
            const name = event.name;
            if (["openwindow", "closewindow", "movewindow", "movewindowv2",
                 "changefloatingmode", "fullscreen", "pin", "minimize",
                 "togglegroup", "moveintogroup", "moveoutofgroup",
                 "moveworkspace", "moveworkspacev2",
                 "renameworkspace", "renameworkspacev2", "changeworkspaceid",
                 "changeworkspaceidv2"].includes(name))
                root.scheduleClients();

            // Active clients such as terminals can publish animated titles at
            // 10 Hz. The bar reads the native Toplevel title, so cloning the
            // entire legacy client list for every title is pure hot-path work.
            if (name === "windowtitlev2") {
                if (!GlobalStates.overviewOpen) {
                    // Non-focused monitor labels still use the compatibility
                    // snapshot. Reconcile them at only 0.2 Hz under a title
                    // spinner instead of leaving them stale indefinitely.
                    root.scheduleTitleFallback();
                } else if (root.applyWindowTitleEvent(event.data)) {
                    titleFallbackTimer.stop();
                } else {
                    root.scheduleTitleFallback();
                }
            }

            // Visible workspace state is native. Keep this legacy snapshot for
            // monitor/special compatibility without forking hyprctl after
            // every ordinary workspace switch.
            if (["activespecial", "focusedmon"].includes(name))
                root.scheduleActiveWorkspace();

            if (["createworkspace", "createworkspacev2", "destroyworkspace",
                 "destroyworkspacev2", "moveworkspace", "moveworkspacev2",
                 "renameworkspace", "renameworkspacev2", "changeworkspaceid",
                 "changeworkspaceidv2", "openwindow", "closewindow",
                 "movewindow", "movewindowv2", "fullscreen"].includes(name))
                root.scheduleWorkspaceList();

            if (["monitoradded", "monitoraddedv2", "monitorremoved", "focusedmon"].includes(name))
                root.scheduleMonitors();

            if (["openlayer", "closelayer"].includes(name))
                root.scheduleLayers();

            if (name === "configreloaded") {
                root.scheduleClients();
                root.scheduleMonitors();
                root.scheduleLayers();
                root.scheduleWorkspaceList();
            }
        }
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            // Refresh once when the legacy overview actually needs geometry
            // and tooltip metadata; keep title churn out of the closed state.
            if (GlobalStates.overviewOpen)
                root.scheduleClients();
            else
                titleFallbackTimer.stop();
        }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        onRunningChanged: {
            if (!getClients.running && root.clientsDirty) {
                root.clientsDirty = false;
                clientsDebounce.restart();
            }
        }
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                const pendingTitles = root.pendingWindowTitles;
                root.pendingWindowTitles = ({});
                const nextWindowList = JSON.parse(clientsCollector.text).map(window => {
                    const address = root.normalizeWindowAddress(window.address);
                    const pendingTitle = pendingTitles[address];
                    return pendingTitle === undefined || window.title === pendingTitle
                        ? window : Object.assign({}, window, { title: pendingTitle });
                });
                root.windowList = nextWindowList;
                let tempWinByAddress = {};
                for (var i = 0; i < root.windowList.length; ++i) {
                    var win = root.windowList[i];
                    tempWinByAddress[win.address] = win;
                }
                root.windowByAddress = tempWinByAddress;
                root.addresses = root.windowList.map(win => win.address);
            }
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        onRunningChanged: {
            if (!getMonitors.running && root.monitorsDirty) {
                root.monitorsDirty = false;
                monitorsDebounce.restart();
            }
        }
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                root.monitors = JSON.parse(monitorsCollector.text);
            }
        }
    }

    Process {
        id: getLayers
        command: ["hyprctl", "layers", "-j"]
        onRunningChanged: {
            if (!getLayers.running && root.layersDirty) {
                root.layersDirty = false;
                layersDebounce.restart();
            }
        }
        stdout: StdioCollector {
            id: layersCollector
            onStreamFinished: {
                root.layers = JSON.parse(layersCollector.text);
            }
        }
    }

    Process {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        onRunningChanged: {
            if (!getWorkspaces.running && root.workspaceListDirty) {
                root.workspaceListDirty = false;
                workspaceListDebounce.restart();
            }
        }
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                var rawWorkspaces = JSON.parse(workspacesCollector.text);
                root.workspaces = rawWorkspaces.filter(ws => ws.id >= 1 && ws.id <= 100);
                let tempWorkspaceById = {};
                for (var i = 0; i < root.workspaces.length; ++i) {
                    var ws = root.workspaces[i];
                    tempWorkspaceById[ws.id] = ws;
                }
                root.workspaceById = tempWorkspaceById;
                root.workspaceIds = root.workspaces.map(ws => ws.id);
            }
        }
    }

    Process {
        id: getActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        onRunningChanged: {
            if (!getActiveWorkspace.running && root.activeWorkspaceDirty) {
                root.activeWorkspaceDirty = false;
                activeWorkspaceDebounce.restart();
            }
        }
        stdout: StdioCollector {
            id: activeWorkspaceCollector
            onStreamFinished: {
                root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text);
            }
        }
    }
}
