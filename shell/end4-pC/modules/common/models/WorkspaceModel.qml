pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common as C
import qs.modules.common.functions

NestableObject {
    id: root

    required property var screen
    readonly property string monitorName: screen?.name ?? ""

    // Resolve this model from its owning bar's QScreen. Never allow an empty
    // screen to make monitorFor() fall back to the globally focused monitor.
    // The name lookup is also reactive across monitor hotplug/re-enumeration.
    readonly property var hyprMonitor: {
        if (WM.compositor !== "hyprland" || !root.screen || !root.monitorName)
            return null
        const byName = Hyprland.monitors.values.find(m => m.name === root.monitorName)
        if (byName)
            return byName
        const byScreen = Hyprland.monitorFor(root.screen)
        return byScreen?.name === root.monitorName ? byScreen : null
    }
    readonly property var liveMonitorData: WM.compositor === "hyprland"
        ? HyprlandData.monitors.find(m => m.name === root.monitorName)
        : null

    readonly property int requestedShownCount: Math.max(1, C.Config.options.bar.workspaces.shown)
    readonly property int shownCount: WM.compositor === "hyprland"
        ? (root.ownerGroup >= 0
            ? Math.min(WorkspaceGroups.groupSize, root.requestedShownCount) : 0)
        : root.requestedShownCount
    readonly property int activeMonitorCount: WM.compositor === "hyprland"
        ? Hyprland.monitors.values.filter(m => !!m?.name).length
        : 1
    readonly property int ownerGroup: WorkspaceGroups.ownerGroup(
        root.monitorName,
        root.hyprMonitor?.id
    )
    readonly property int reportedActiveNumber: root.hyprMonitor?.activeWorkspace?.id
        ?? WorkspaceGroups.firstWorkspaceId(root.ownerGroup)
    // Only additions get an optimistic owner preview. During removal the
    // internal panel may legitimately be presenting group 11..20, so forcing
    // owner group 0 there would paint the wrong workspace.
    readonly property bool addedConnectorPreview: WM.compositor === "hyprland"
        && GlobalStates.hotplugVisualActive
        && GlobalStates.hotplugVisualKind === "added"
        && GlobalStates.hotplugVisualConnector === root.monitorName
        && WorkspaceGroups.hasStableOwner(root.monitorName)
    readonly property int monitorGroup: {
        if (WM.compositor !== "hyprland")
            return Math.max(0, Math.floor((root.activeNumber - 1) / root.shownCount))
        return WorkspaceGroups.presentationGroup(
            root.monitorName,
            root.hyprMonitor?.id,
            root.reportedActiveNumber,
            root.activeMonitorCount
        )
    }

    readonly property int liveActiveNumber: {
        if (WM.compositor === "hyprland") {
            const first = WorkspaceGroups.firstWorkspaceId(root.monitorGroup)
            return WorkspaceGroups.containsWorkspace(
                root.monitorGroup,
                root.reportedActiveNumber
            ) ? root.reportedActiveNumber : first
        }
        const ws = WM.workspaces.find(w => w.output === root.monitorName && w.is_active)
        return ws?.idx ?? 1
    }
    property int heldActiveNumber: 1
    readonly property bool workspaceStateHeld: GlobalStates.sessionRestoreActive
        || WorkspaceDragState.compactionActive
    readonly property int previewActiveNumber: WorkspaceGroups.containsWorkspace(
        root.ownerGroup,
        root.reportedActiveNumber
    ) ? root.reportedActiveNumber : WorkspaceGroups.firstWorkspaceId(root.ownerGroup)
    readonly property int activeNumber: root.addedConnectorPreview
        ? root.previewActiveNumber
        : (root.workspaceStateHeld ? heldActiveNumber : liveActiveNumber)

    readonly property bool liveCurrentWorkspaceNotFake: WM.compositor === "hyprland"
        ? HyprlandData.windowList.some(w => w.workspace?.id === root.liveActiveNumber)
        : true
    property bool heldCurrentWorkspaceNotFake: true
    readonly property bool currentWorkspaceNotFake: root.workspaceStateHeld
        ? heldCurrentWorkspaceNotFake : liveCurrentWorkspaceNotFake
    readonly property int fakeWorkspace: currentWorkspaceNotFake ? -9999 : activeNumber

    // Connector ownership is stable, while the live presentation group may
    // follow an actually active merged/deferred workspace during hotplug.
    // Hold it with the active ID during restore so the bar cannot expose the
    // compositor's intermediate routing steps.
    property int heldGroup: 0
    readonly property int group: root.addedConnectorPreview
        ? root.ownerGroup
        : (root.workspaceStateHeld ? root.heldGroup : root.monitorGroup)

    readonly property var specialWorkspace: WM.compositor === "hyprland" ? liveMonitorData?.specialWorkspace : null
    readonly property string specialWorkspaceName: specialWorkspace?.name.replace("special:", "") ?? "special"
    readonly property bool specialWorkspaceActive: WM.compositor === "hyprland" && specialWorkspaceName !== ""

    property list<bool> occupied: []
    readonly property bool appIconsEnabled: C.Config.options?.bar.workspaces.showAppIcons ?? false
    property list<var> biggestWindow: root.appIconsEnabled ? occupied.map((_, index) => {
        const number = getWorkspaceIdAt(index)
        return root.biggestWindowForNumber(number)
    }) : []

    function getWorkspaceId(group, index) {
        if (WM.compositor === "hyprland") {
            if (group < 0 || index < 0)
                return -1
            return WorkspaceGroups.firstWorkspaceId(group) + index
        }
        return group * root.shownCount + index + 1
    }
    function getWorkspaceIdAt(index) {
        return root.getWorkspaceId(root.group, index)
    }

    function getRelativeWorkspaceId(offset) {
        if (root.shownCount <= 0)
            return -1
        const first = root.getWorkspaceIdAt(0)
        const current = root.activeNumber - first
        const safeIndex = current >= 0 && current < root.shownCount ? current : 0
        const nextIndex = (safeIndex + offset + root.shownCount) % root.shownCount
        return first + nextIndex
    }

    function _niriRealId(number) {
        const ws = WM.workspaces.find(w => w.output === root.monitorName && w.idx === number)
        return ws?.id ?? null
    }

    function biggestWindowForNumber(number) {
        if (WM.compositor === "hyprland")
            return HyprlandData.biggestWindowForWorkspace(number)

        const realId = root._niriRealId(number)
        if (realId === null) return null
        const winsInWs = WM.windowList.filter(w => w.workspaceId === realId)
        if (winsInWs.length === 0) return null
        const win = winsInWs.find(w => w.focused) ?? winsInWs[0]
        return { class: win.appId, title: win.title, id: win.id }
    }

    function updateWorkspaceOccupied(preferNative) {
        if (WM.compositor === "hyprland") {
            // Native events are already in memory and paint their result in
            // the first frame. The debounced hyprctl snapshot remains the
            // authoritative fallback/reconciliation path for change_id,
            // whose native valuesChanged signal is not always emitted.
            const workspaceIdSet = new Set()
            if (preferNative || HyprlandData.workspaceIds.length === 0) {
                for (const workspace of Hyprland.workspaces.values)
                    workspaceIdSet.add(Number(workspace.id))
            } else {
                for (const id of HyprlandData.workspaceIds)
                    workspaceIdSet.add(Number(id))
            }
            const nextOccupied = Array.from({ length: root.shownCount }, (_, i) => {
                const thisWorkspaceId = getWorkspaceId(root.group, i)
                return workspaceIdSet.has(thisWorkspaceId)
            })
            if (nextOccupied.length === root.occupied.length
                    && nextOccupied.every((value, index) => value === root.occupied[index]))
                return
            root.occupied = nextOccupied
        } else {
            root.occupied = Array.from({ length: root.shownCount }, (_, i) => {
                const number = getWorkspaceId(root.group, i)
                const realId = root._niriRealId(number)
                if (realId === null) return false
                return WM.windowList.some(w => w.workspaceId === realId)
            })
        }
    }

    Component.onCompleted: {
        root.heldGroup = root.monitorGroup
        root.heldActiveNumber = root.liveActiveNumber
        root.heldCurrentWorkspaceNotFake = root.liveCurrentWorkspaceNotFake
        updateWorkspaceOccupied()
    }

    onLiveActiveNumberChanged: {
        if (!root.workspaceStateHeld)
            root.heldActiveNumber = root.liveActiveNumber
    }

    Connections {
        target: GlobalStates
        function onSessionRestoreActiveChanged() {
            if (GlobalStates.sessionRestoreActive) {
                root.heldGroup = root.monitorGroup
                root.heldActiveNumber = root.liveActiveNumber
                root.heldCurrentWorkspaceNotFake = root.liveCurrentWorkspaceNotFake
            }
        }
        function onSessionRestoreCommit() {
            root.heldGroup = root.monitorGroup
            root.heldActiveNumber = root.liveActiveNumber
            root.heldCurrentWorkspaceNotFake = root.liveCurrentWorkspaceNotFake
            root.updateWorkspaceOccupied(true)
        }
    }

    Connections {
        target: WorkspaceDragState
        function onCompactionActiveChanged() {
            if (WorkspaceDragState.compactionActive) {
                root.heldGroup = root.monitorGroup
                root.heldActiveNumber = root.liveActiveNumber
                root.heldCurrentWorkspaceNotFake = root.liveCurrentWorkspaceNotFake
            } else if (!GlobalStates.sessionRestoreActive) {
                root.heldGroup = root.monitorGroup
                root.heldActiveNumber = root.liveActiveNumber
                root.heldCurrentWorkspaceNotFake = root.liveCurrentWorkspaceNotFake
                root.updateWorkspaceOccupied(true)
            }
        }
    }

    // Hyprland
    Connections {
        target: Hyprland.workspaces
        enabled: WM.compositor === "hyprland"
        function onValuesChanged() {
            if (!root.workspaceStateHeld)
                root.updateWorkspaceOccupied(true)
        }
    }
    Connections {
        target: HyprlandData
        enabled: WM.compositor === "hyprland"
        function onWorkspaceIdsChanged() {
            if (!root.workspaceStateHeld)
                root.updateWorkspaceOccupied()
        }
    }

    // Niri
    Connections {
        target: WM
        enabled: WM.compositor !== "hyprland"
        function onWorkspacesChanged() {
            root.updateWorkspaceOccupied()
        }
        function onWindowListChanged() {
            root.updateWorkspaceOccupied()
        }
    }

    onGroupChanged: {
        updateWorkspaceOccupied(true)
    }
}
