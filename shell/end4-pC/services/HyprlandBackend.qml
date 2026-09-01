pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common.functions

Scope {
    id: root
    property var windowList: []
    property var workspaces: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var focusedMonitor: Hyprland.focusedMonitor

    function monitorNameForWorkspace(id) {
        const group = WorkspaceGroups.groupForWorkspaceId(id)
        if (group < 0)
            return ""
        const monitor = Hyprland.monitors.values.find(candidate =>
            WorkspaceGroups.ownerGroup(candidate?.name, candidate?.id) === group)
        return monitor?.name ?? ""
    }
    function switchWorkspaceRelative(direction) {
        const monitor = Hyprland.focusedMonitor
        const observed = Number(monitor?.activeWorkspace?.id ?? -1)
        if (!monitor?.name || observed < 1)
            return
        root.switchWorkspaceOffset(
            direction === "next" ? 1 : -1,
            monitor.name,
            observed
        )
    }
    function normalizeWindow(w) {
        return {
            id: w.address,
            address: w.address,
            title: w.title,
            appId: w.class,
            workspaceId: w.workspace?.id ?? -1,
            focused: w.address === HyprlandData.activeWorkspace?.lastwindow
        };
    }

    function focusWindow(id) {
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${id}" })`);
    }
    function closeWindow(id) {
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${id}" })`);
    }
    function switchWorkspace(id) {
        root.switchWorkspaceOnMonitor(id, root.monitorNameForWorkspace(id));
    }
    function switchWorkspaceOnMonitor(id, monitorName) {
        const workspace = Math.trunc(Number(id));
        const monitor = JSON.stringify(String(monitorName ?? ""));
        if (!Number.isFinite(workspace) || workspace < 1 || monitor === '""')
            return;
        Hyprland.dispatch(`end4_workspace_bar_focus(${workspace}, ${monitor})`);
    }
    function switchWorkspaceSlot(slot, monitorName, observedTarget) {
        const targetSlot = Math.trunc(Number(slot));
        const observed = Math.trunc(Number(observedTarget));
        const monitor = JSON.stringify(String(monitorName ?? ""));
        if (!Number.isFinite(targetSlot) || targetSlot < 1 || targetSlot > 10
                || !Number.isFinite(observed) || monitor === '""')
            return;
        Hyprland.dispatch(`end4_workspace_focus_slot(${targetSlot}, ${monitor}, ${observed})`);
    }
    function switchWorkspaceOffset(offset, monitorName, observedActive) {
        const delta = Math.trunc(Number(offset));
        const observed = Math.trunc(Number(observedActive));
        const monitor = JSON.stringify(String(monitorName ?? ""));
        if (!Number.isFinite(delta) || delta === 0
                || !Number.isFinite(observed) || monitor === '""')
            return;
        Hyprland.dispatch(`end4_workspace_focus_offset(${delta}, ${monitor}, ${observed})`);
    }
    function moveWindowToWorkspace(id, wsId) {
        root.moveWindowToWorkspaceAndCompact(
            id, wsId, root.monitorNameForWorkspace(wsId));
    }
    function moveWindowToWorkspaceAndCompact(id, wsId, monitorName) {
        const selector = JSON.stringify(`address:${String(id ?? "")}`)
        const monitor = JSON.stringify(String(monitorName ?? ""))
        const workspace = Math.trunc(Number(wsId))
        if (!String(id ?? "").startsWith("0x")
                || !Number.isFinite(workspace) || workspace < 1
                || monitor === '""')
            return
        Hyprland.dispatch(`end4_workspace_bar_move(${selector}, ${workspace}, ${monitor})`)
    }

    function monitorFor(screen) {
        return Hyprland.monitorFor(screen);
    }

    function activeWorkspaceForMonitor(monitorName) {
        const m = Hyprland.monitors.values.find(mm => mm.name === monitorName);
        return m?.activeWorkspace ? { id: m.activeWorkspace.id } : null;
    }

    function biggestWindowForWorkspace(wsId) {
        return HyprlandData.biggestWindowForWorkspace(wsId);
    }

    function fullscreenOnMonitor(monitorName) {
        const wsList = Hyprland.workspaces.values.filter(ws => ws.monitor && ws.monitor.name === monitorName);
        return wsList.some(ws => ws.active && ws.toplevels.values.some(w => w.wayland?.fullscreen));
    }

    function monitorGeometry(screen) {
        const m = Hyprland.monitorFor(screen);
        if (!m) return { x: 0, y: 0, scale: 1 };
        return { x: m.x, y: m.y, scale: m.scale };
    }

    Component.onCompleted: refreshAll()

    function refreshWindowList() {
        windowList = HyprlandData.windowList.map(normalizeWindow);
    }

    function refreshWorkspaces() {
        workspaces = HyprlandData.workspaces;
        workspaceById = HyprlandData.workspaceById;
    }

    function refreshActiveWorkspace() {
        activeWorkspace = HyprlandData.activeWorkspace;
    }

    function refreshMonitors() {
        monitors = HyprlandData.monitors;
    }

    function refreshAll() {
        refreshWindowList();
        refreshWorkspaces();
        refreshActiveWorkspace();
        refreshMonitors();
    }

    Connections {
        target: HyprlandData
        function onWindowListChanged() { root.refreshWindowList() }
        function onWorkspacesChanged() { root.workspaces = HyprlandData.workspaces }
        function onWorkspaceByIdChanged() { root.workspaceById = HyprlandData.workspaceById }
        function onActiveWorkspaceChanged() { root.refreshActiveWorkspace() }
        function onMonitorsChanged() { root.refreshMonitors() }
    }
}
