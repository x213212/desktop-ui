import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false

    PanelWindow {
        id: panelWindow
        property string searchingText: ""
        readonly property string monitorName: panelWindow.screen?.name ?? ""
        readonly property HyprlandMonitor monitor:
            Hyprland.monitors.values.find(candidate =>
                candidate?.name === panelWindow.monitorName) ?? null
        readonly property int activeMonitorCount:
            Hyprland.monitors.values.filter(candidate => !!candidate?.name).length
        property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
        visible: GlobalStates.overviewOpen

        WlrLayershell.namespace: "quickshell:overview"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        readonly property bool overviewWindowDragging:
            (overviewLoader.item?.draggingFromWorkspace ?? -1) !== -1
        readonly property var workspaceBarRegion:
            WorkspaceDragState.regionFor(panelWindow.screen?.name ?? "")

        onOverviewWindowDraggingChanged: {
            if (!panelWindow.overviewWindowDragging)
                WorkspaceDragState.clearTarget("", -1)
        }

        mask: Region {
            // During a preview drag, keep input in this QML scene all the way
            // to the bar. Internal Qt drag events cannot cross PanelWindows.
            item: GlobalStates.overviewOpen
                ? (panelWindow.overviewWindowDragging
                    ? dragInputRegion : columnLayout)
                : null
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Item {
            id: dragInputRegion
            anchors.fill: parent
            z: 1000000
            visible: panelWindow.overviewWindowDragging

            Repeater {
                model: panelWindow.workspaceBarRegion?.shownCount ?? 0

                delegate: DropArea {
                    id: overviewBarDropTarget
                    required property int index
                    readonly property var region: panelWindow.workspaceBarRegion
                    readonly property int workspaceId:
                        region?.workspaceIds?.[index] ?? -1

                    x: region?.vertical
                        ? (region?.x ?? 0)
                        : (region?.x ?? 0) + index * (region?.cellSize ?? 0)
                    y: region?.vertical
                        ? (region?.y ?? 0) + index * (region?.cellSize ?? 0)
                        : (region?.y ?? 0)
                    width: region?.vertical
                        ? (region?.width ?? 0) : (region?.cellSize ?? 0)
                    height: region?.vertical
                        ? (region?.cellSize ?? 0) : (region?.height ?? 0)

                    function acceptsOverviewWindow(drag) {
                        return workspaceId >= 1
                            && String(drag?.source?.windowData?.address ?? "")
                                .startsWith("0x")
                    }

                    onEntered: drag => {
                        if (!acceptsOverviewWindow(drag))
                            return
                        WorkspaceDragState.setTarget(
                            panelWindow.screen?.name ?? "", index, workspaceId)
                    }
                    onPositionChanged: drag => {
                        if (!acceptsOverviewWindow(drag))
                            return
                        WorkspaceDragState.setTarget(
                            panelWindow.screen?.name ?? "", index, workspaceId)
                    }
                    onExited: {
                        WorkspaceDragState.clearTarget(
                            panelWindow.screen?.name ?? "", index)
                    }
                }
            }
        }

        Connections {
            target: GlobalStates
            function onOverviewOpenChanged() {
                if (!GlobalStates.overviewOpen) {
                    WorkspaceDragState.clearTarget("", -1)
                    searchWidget.disableExpandAnimation();
                    // A hidden overview must not retain search result delegates
                    // or leave calculator work running until the next open.
                    searchWidget.cancelSearch();
                    overviewScope.dontAutoCancelSearch = false;
                    GlobalFocusGrab.dismiss();
                } else {
                    if (!overviewScope.dontAutoCancelSearch) {
                        searchWidget.cancelSearch();
                    }
                    GlobalFocusGrab.addDismissable(panelWindow);
                }
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                GlobalStates.overviewOpen = false;
            }
        }
        implicitWidth: columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight

        function setSearchingText(text) {
            searchWidget.setSearchingText(text);
            searchWidget.focusFirstItem();
        }

        function switchWorkspaceByOffset(offset) {
            const delta = Math.trunc(Number(offset))
            if (delta === 0)
                return
            if (WM.compositor !== "hyprland") {
                WM.switchWorkspaceRelative(delta > 0 ? "next" : "previous")
                return
            }
            const observed = Number(panelWindow.monitor?.activeWorkspace?.id ?? -1)
            const group = WorkspaceGroups.presentationGroup(
                panelWindow.monitorName,
                panelWindow.monitor?.id,
                observed,
                panelWindow.activeMonitorCount
            )
            const first = WorkspaceGroups.firstWorkspaceId(group)
            if (!panelWindow.monitorName || first < 1 || observed < 1)
                return
            const current = WorkspaceGroups.containsWorkspace(group, observed)
                ? observed : first
            const normalized = ((current - first + delta)
                % WorkspaceGroups.groupSize + WorkspaceGroups.groupSize)
                % WorkspaceGroups.groupSize
            WM.switchWorkspaceOffset(
                delta,
                observed,
                panelWindow.monitorName,
                first + normalized
            )
        }

        Column {
            id: columnLayout
            visible: GlobalStates.overviewOpen
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
            }
            spacing: -8

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.overviewOpen = false;
                } else if (event.key === Qt.Key_Left) {
                    if (!panelWindow.searchingText)
                        panelWindow.switchWorkspaceByOffset(-1);
                } else if (event.key === Qt.Key_Right) {
                    if (!panelWindow.searchingText)
                        panelWindow.switchWorkspaceByOffset(1);
                }
            }

            SearchWidget {
                id: searchWidget
                anchors.horizontalCenter: parent.horizontalCenter
                Synchronizer on searchingText {
                    property alias source: panelWindow.searchingText
                }
            }

            CachedLoader {
                id: overviewLoader
                requested: GlobalStates.overviewOpen
                    && (Config?.options.overview.enable ?? true)
                cacheDuration: 15000
                sourceComponent: (Config?.options.overview.style ?? "default") === "niri" ? niriComponent : defaultComponent

                Component {
                    id: defaultComponent
                    OverviewWidget {
                        screen: panelWindow.screen
                        visible: (panelWindow.searchingText == "")
                    }
                }

                Component {
                    id: niriComponent
                    NiriOverview {
                        screen: panelWindow.screen
                        panelWindow: panelWindow
                        visible: (panelWindow.searchingText == "")
                    }
                }
            }
        }
    }

    function toggleClipboard() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.clipboard);
        GlobalStates.overviewOpen = true;
    }

    function toggleEmojis() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.emojis);
        GlobalStates.overviewOpen = true;
    }

    function toggleSymbols() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.symbols);
        GlobalStates.overviewOpen = true;
    }

    IpcHandler {
        target: "search"

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function workspacesToggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle() {
            overviewScope.toggleClipboard();
        }
    }

    CompositorGlobalShortcut {
        name: "searchToggle"
        description: "Toggles search on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    CompositorGlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"

        onPressed: {
            GlobalStates.overviewOpen = false;
        }
    }
    CompositorGlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    CompositorGlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles search on release"

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    CompositorGlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of search being toggled on release. " + "This is necessary because GlobalShortcut.onReleased in quickshell triggers whether or not you press something else while holding the key. " + "To make sure this works consistently, use binditn = MODKEYS, catchall in an automatically triggered submap that includes everything."

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
        }
    }
    CompositorGlobalShortcut {
        name: "overviewClipboardToggle"
        description: "Toggle clipboard query on overview widget"

        onPressed: {
            overviewScope.toggleClipboard();
        }
    }

    CompositorGlobalShortcut {
        name: "overviewEmojiToggle"
        description: "Toggle emoji query on overview widget"

        onPressed: {
            overviewScope.toggleEmojis();
        }
    }

    CompositorGlobalShortcut {
        name: "overviewSymbolsToggle"
        description: "Toggle material symbols search on overview widget"

        onPressed: {
            overviewScope.toggleSymbols();
        }
    }
}
