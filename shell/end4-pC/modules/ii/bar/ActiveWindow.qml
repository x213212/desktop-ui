import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

Item {
    id: root
    property bool vertical: false
    property var targetScreen: root.QsWindow.window?.screen
    readonly property string monitorName: root.targetScreen?.name ?? ""
    readonly property var monitor: {
        if (!root.targetScreen || !root.monitorName)
            return null
        const byName = Hyprland.monitors.values.find(m => m.name === root.monitorName)
        if (byName)
            return byName
        const byScreen = Hyprland.monitorFor(root.targetScreen)
        return byScreen?.name === root.monitorName ? byScreen : null
    }
    readonly property int activeMonitorCount: Hyprland.monitors.values.filter(m => !!m?.name).length
    readonly property int ownerGroup: WorkspaceGroups.ownerGroup(root.monitorName, root.monitor?.id)
    readonly property int reportedWorkspaceId: root.monitor?.activeWorkspace?.id
        ?? WorkspaceGroups.firstWorkspaceId(root.ownerGroup)
    readonly property int workspaceGroup: WorkspaceGroups.presentationGroup(
        root.monitorName,
        root.monitor?.id,
        root.reportedWorkspaceId,
        root.activeMonitorCount
    )
    readonly property int firstWorkspaceId: WorkspaceGroups.firstWorkspaceId(root.workspaceGroup)
    readonly property int activeWorkspaceId: WorkspaceGroups.containsWorkspace(
        root.workspaceGroup,
        root.reportedWorkspaceId
    ) ? root.reportedWorkspaceId : root.firstWorkspaceId
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    property string activeWindowAddress: activeWindow?.HyprlandToplevel?.address ? `0x${activeWindow.HyprlandToplevel.address}` : ""
    readonly property string liveWindowTitle: root.activeWindow?.title ?? ""
    property string displayedWindowTitle: ""
    property string pendingFocusAddress: ""
    readonly property var activeClient: HyprlandData.clientForToplevel(root.activeWindow)
    property bool focusingThisMonitor: !!root.activeWindow?.activated
        && root.activeClient?.monitor === root.monitor?.id
        && root.activeClient?.workspace?.id === root.activeWorkspaceId
    property var biggestWindow: WM.biggestWindowForWorkspace(root.activeWorkspaceId)

    property string activeAppClass: {
        if (!root.focusingThisMonitor || !root.activeWindow?.activated)
            return root.biggestWindow?.class ?? ""
        return root.activeWindow?.appId ?? root.biggestWindow?.class ?? ""
    }

    property var mainAppIconSource: {
        if (!root.activeAppClass || root.activeAppClass === "")
            return Quickshell.iconPath("user-desktop", "image-missing")
        return Quickshell.iconPath(AppSearch.guessIcon(root.activeAppClass), 
            Quickshell.iconPath("user-desktop", "image-missing"))     // ← fallback Desktop
    }

    // Terminal spinners and progress tools can change the native title ten or
    // more times per second. Commit at most four bar text updates per second,
    // while a real focus change remains immediate.
    Timer {
        id: titleCommitTimer
        interval: 250
        repeat: false
        onTriggered: root.displayedWindowTitle = root.liveWindowTitle
    }
    Timer {
        id: focusCommitTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (root.activeWindowAddress !== root.pendingFocusAddress)
                return;
            titleCommitTimer.stop();
            root.displayedWindowTitle = root.activeWindow?.title ?? "";
        }
    }
    function commitFocusedWindowTitle() {
        root.pendingFocusAddress = root.activeWindowAddress
        // Toplevel address and title bindings can notify in either order.
        // A zero-delay owned timer provides the same event-loop barrier as
        // Qt.callLater, but is destroyed with this delegate during hotplug.
        focusCommitTimer.restart()
    }
    Component.onCompleted: root.commitFocusedWindowTitle()
    onLiveWindowTitleChanged: {
        if (root.focusingThisMonitor && !titleCommitTimer.running)
            titleCommitTimer.start()
    }
    onActiveWindowAddressChanged: root.commitFocusedWindowTitle()
    onFocusingThisMonitorChanged: {
        if (root.focusingThisMonitor)
            root.commitFocusedWindowTitle()
    }

    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : Math.min(colLayout.implicitWidth + 6, 280)
    implicitHeight: vertical ? iconItem.implicitHeight : Appearance.sizes.barHeight

    // Vertical
    Item {
        id: iconItem
        visible: root.vertical
        anchors.centerIn: parent
        implicitWidth: 22
        implicitHeight: 22

        IconImage {
            anchors.centerIn: parent
            source: root.mainAppIconSource
            implicitSize: 18
            visible: root.mainAppIconSource !== ""
        }
    }

    // Horizontal
    ColumnLayout {
        id: colLayout
        visible: !root.vertical
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 3
        spacing: -4

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            elide: Text.ElideRight
            text: root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow ?
                root.activeWindow?.appId :
                (root.biggestWindow?.class) ?? Translation.tr("Desktop")
        }
        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
            text: root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow ?
                root.displayedWindowTitle :
                (root.biggestWindow?.title) ?? `${Translation.tr("Workspace")} ${root.activeWorkspaceId}`
        }
    }
}
