pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    required property var screen
    readonly property string monitorName: root.screen?.name ?? ""
    readonly property HyprlandMonitor monitor: {
        if (!root.screen || !root.monitorName)
            return null
        const byName = Hyprland.monitors.values.find(m => m.name === root.monitorName)
        if (byName)
            return byName
        const byScreen = Hyprland.monitorFor(root.screen)
        return byScreen?.name === root.monitorName ? byScreen : null
    }
    readonly property var toplevels: ToplevelManager.toplevels
    readonly property int activeMonitorCount: Hyprland.monitors.values.filter(m => !!m?.name).length
    readonly property int ownerGroup: WorkspaceGroups.ownerGroup(root.monitorName, root.monitor?.id)
    readonly property int reportedActiveWorkspaceId: root.monitor?.activeWorkspace?.id
        ?? WorkspaceGroups.firstWorkspaceId(root.ownerGroup)
    readonly property int workspacesShown:
        WM.compositor === "hyprland" && root.ownerGroup < 0
        ? 0
        : Math.max(1, Math.min(
            WorkspaceGroups.groupSize,
            Config.options.overview.rows * Config.options.overview.columns
        ))
    readonly property int workspaceGroup: WorkspaceGroups.presentationGroup(
        root.monitorName,
        root.monitor?.id,
        root.reportedActiveWorkspaceId,
        root.activeMonitorCount
    )
    readonly property int firstWorkspaceId: WorkspaceGroups.firstWorkspaceId(root.workspaceGroup)
    readonly property int effectiveActiveWorkspaceId:
        root.reportedActiveWorkspaceId >= root.firstWorkspaceId
            && root.reportedActiveWorkspaceId
                < root.firstWorkspaceId + root.workspacesShown
        ? root.reportedActiveWorkspaceId : root.firstWorkspaceId
    enabled: root.workspacesShown > 0
    property bool monitorIsFocused: (Hyprland.focusedMonitor?.name == root.monitor?.name)
    property var windows: HyprlandData.windowList
    property var windowByAddress: HyprlandData.windowByAddress
    property var windowAddresses: HyprlandData.addresses
    // One live ScreencopyView owns at least one DMA buffer. Do not let a
    // pathological workspace with dozens of windows exhaust GBM and fall
    // back to per-frame SHM retries. Extra previews remain fully draggable
    // icon cards and become live while hovered.
    readonly property int livePreviewThreshold: 16
    readonly property bool highWindowPressure:
        root.windowAddresses.length > root.livePreviewThreshold
    property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)
    property real scale: Config.options.overview.scale
    property color activeBorderColor: Appearance.colors.colSecondary

    property real workspaceImplicitWidth: {
        const monitorWidth = root.monitor?.width ?? root.screen?.width ?? 1
        const monitorHeight = root.monitor?.height ?? root.screen?.height ?? 1
        const monitorScale = root.monitor?.scale ?? 1
        const reserved = root.monitorData?.reserved ?? [0, 0, 0, 0]
        const transformed = (root.monitorData?.transform ?? 0) % 2 === 1
        const length = transformed ? monitorHeight : monitorWidth
        return Math.max(1, (length - reserved[0] - reserved[2])
            * root.scale / monitorScale)
    }
    property real workspaceImplicitHeight: {
        const monitorWidth = root.monitor?.width ?? root.screen?.width ?? 1
        const monitorHeight = root.monitor?.height ?? root.screen?.height ?? 1
        const monitorScale = root.monitor?.scale ?? 1
        const reserved = root.monitorData?.reserved ?? [0, 0, 0, 0]
        const transformed = (root.monitorData?.transform ?? 0) % 2 === 1
        const length = transformed ? monitorWidth : monitorHeight
        return Math.max(1, (length - reserved[1] - reserved[3])
            * root.scale / monitorScale)
    }
    property real largeWorkspaceRadius: Appearance.rounding.large
    property real smallWorkspaceRadius: Appearance.rounding.verysmall

    property real workspaceNumberMargin: 80
    property real workspaceNumberSize: 250 * (root.monitor?.scale ?? 1)
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: 5

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    implicitWidth: overviewBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: overviewBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

    property Component windowComponent: OverviewWindow {}
    property list<OverviewWindow> windowWidgets: []
    
    function getWsRow(ws) {
        // 1-indexed workspace, 0-indexed row
        const offset = Math.max(0, Number(ws) - root.firstWorkspaceId)
        var normalRow = Math.floor(offset / Config.options.overview.columns) % Config.options.overview.rows;
        return (Config.options.overview.orderBottomUp ? Config.options.overview.rows - normalRow - 1 : normalRow);
    }
    function getWsColumn(ws) {
        // 1-indexed workspace, 0-indexed column
        const offset = Math.max(0, Number(ws) - root.firstWorkspaceId)
        var normalCol = offset % Config.options.overview.columns;
        return (Config.options.overview.orderRightLeft ? Config.options.overview.columns - normalCol - 1 : normalCol);
    }
    function getWsInCell(ri, ci) {
        // 1-indexed workspace, 0-indexed row and column index
        return (Config.options.overview.orderBottomUp ? Config.options.overview.rows - ri - 1 : ri) * Config.options.overview.columns + (Config.options.overview.orderRightLeft ? Config.options.overview.columns - ci - 1 : ci) + 1
    }

    StyledRectangularShadow {
        target: overviewBackground
    }
    Rectangle { // Background
        id: overviewBackground
        property real padding: 10
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin

        implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
        radius: root.largeWorkspaceRadius + padding
        color: Appearance.colors.colBackgroundSurfaceContainer

        Column { // Workspaces
            id: workspaceColumnLayout

            z: root.workspaceZ
            anchors.centerIn: parent
            spacing: workspaceSpacing
            
            Repeater {
                model: Config.options.overview.rows
                delegate: Row {
                    id: row
                    required property int index
                    spacing: workspaceSpacing

                    Repeater { // Workspace repeater
                        model: Config.options.overview.columns
                        Rectangle { // Workspace
                            id: workspace
                            required property int index
                            property int colIndex: index
                            readonly property int workspaceSlot: getWsInCell(row.index, colIndex)
                            readonly property bool validWorkspace:
                                workspaceSlot <= root.workspacesShown
                            property int workspaceValue: root.firstWorkspaceId + workspaceSlot - 1
                            property color defaultWorkspaceColor: Appearance.colors.colSurfaceContainerLow
                            property color hoveredWorkspaceColor: ColorUtils.mix(defaultWorkspaceColor, Appearance.colors.colLayer1Hover, 0.1)
                            property color hoveredBorderColor: Appearance.colors.colLayer2Hover
                            property bool hoveredWhileDragging: false

                            visible: validWorkspace
                            enabled: validWorkspace
                            implicitWidth: validWorkspace ? root.workspaceImplicitWidth : 0
                            implicitHeight: validWorkspace ? root.workspaceImplicitHeight : 0
                            color: hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor
                            property bool workspaceAtLeft: colIndex === 0
                            property bool workspaceAtRight: colIndex === Config.options.overview.columns - 1
                            property bool workspaceAtTop: row.index === 0
                            property bool workspaceAtBottom: row.index === Config.options.overview.rows - 1
                            topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            topRightRadius: (workspaceAtRight && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            border.width: 2
                            border.color: hoveredWhileDragging ? hoveredBorderColor : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: workspace.workspaceValue
                                font {
                                    pixelSize: root.workspaceNumberSize * root.scale
                                    weight: Font.DemiBold
                                    family: Appearance.font.family.expressive
                                }
                                color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: workspaceArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onPressed: {
                                    if (root.draggingTargetWorkspace === -1) {
                                        GlobalStates.overviewOpen = false
                                        WM.switchWorkspaceSlot(
                                            workspace.workspaceValue
                                                - root.firstWorkspaceId + 1,
                                            workspace.workspaceValue,
                                            root.monitorName
                                        )
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    root.draggingTargetWorkspace = workspace.workspaceValue
                                    if (root.draggingFromWorkspace == root.draggingTargetWorkspace) return;
                                    hoveredWhileDragging = true
                                }
                                onExited: {
                                    hoveredWhileDragging = false
                                    if (root.draggingTargetWorkspace == workspace.workspaceValue) root.draggingTargetWorkspace = -1
                                }
                            }

                        }
                    }
                }
            }
        }

        Item { // Windows & focused workspace indicator
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            Repeater { // Window repeater
                model: ScriptModel {
                    values: {
                        // console.log(JSON.stringify(ToplevelManager.toplevels.values.map(t => t), null, 2))
                        return ToplevelManager.toplevels.values.filter((toplevel) => {
                            const address = `0x${toplevel.HyprlandToplevel?.address}`
                            var win = windowByAddress[address]
                            const workspaceId = Number(win?.workspace?.id ?? -1)
                            return workspaceId >= root.firstWorkspaceId
                                && workspaceId < root.firstWorkspaceId
                                    + root.workspacesShown
                        })
                    }
                }
                delegate: OverviewWindow {
                    id: window
                    required property var modelData
                    // Set by the top-left workspace bar only while this
                    // preview is physically inside one of its drop cells.
                    readonly property int barDropTargetWorkspace:
                        WorkspaceDragState.targetWorkspace
                    readonly property string barDropTargetScreen:
                        WorkspaceDragState.targetScreenName
                    property int monitorId: windowData?.monitor
                    property var monitor: HyprlandData.monitors.find(m => m.id == monitorId)
                    property var address: `0x${modelData.HyprlandToplevel.address}`
                    toplevel: modelData
                    monitorData: this.monitor
                    scale: root.scale
                    widgetMonitor: HyprlandData.monitors.find(
                        m => m.id == root.monitor?.id)
                    windowData: windowByAddress[address]
                    capturePreferred: !root.highWindowPressure
                    liveCaptureEnabled: !root.highWindowPressure
                    geometryAnimationsEnabled: !root.highWindowPressure
                        && !WorkspaceDragState.compactionActive
                        && GlobalStates.overviewOpen

                    property bool atInitPosition: (initX == x && initY == y)

                    // Offset on the canvas
                    property int workspaceColIndex: getWsColumn(windowData?.workspace.id)
                    property int workspaceRowIndex: getWsRow(windowData?.workspace.id)
                    xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex
                    yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * workspaceRowIndex
                    property real xWithinWorkspaceWidget: Math.max(
                        (windowData?.at[0] - (monitor?.x ?? 0)
                            - (monitorData?.reserved?.[0] ?? 0)) * root.scale, 0)
                    property real yWithinWorkspaceWidget: Math.max(
                        (windowData?.at[1] - (monitor?.y ?? 0)
                            - (monitorData?.reserved?.[1] ?? 0)) * root.scale, 0)

                    // Radius
                    property real minRadius: Appearance.rounding.small
                    property bool workspaceAtLeft: workspaceColIndex === 0
                    property bool workspaceAtRight: workspaceColIndex === Config.options.overview.columns - 1
                    property bool workspaceAtTop: workspaceRowIndex === 0
                    property bool workspaceAtBottom: workspaceRowIndex === Config.options.overview.rows - 1
                    property bool workspaceAtTopLeft: (workspaceAtLeft && workspaceAtTop) 
                    property bool workspaceAtTopRight: (workspaceAtRight && workspaceAtTop) 
                    property bool workspaceAtBottomLeft: (workspaceAtLeft && workspaceAtBottom) 
                    property bool workspaceAtBottomRight: (workspaceAtRight && workspaceAtBottom) 
                    property real distanceFromLeftEdge: xWithinWorkspaceWidget
                    property real distanceFromRightEdge: root.workspaceImplicitWidth - (xWithinWorkspaceWidget + targetWindowWidth)
                    property real distanceFromTopEdge: yWithinWorkspaceWidget
                    property real distanceFromBottomEdge: root.workspaceImplicitHeight - (yWithinWorkspaceWidget + targetWindowHeight)
                    property real distanceFromTopLeftCorner: Math.max(distanceFromLeftEdge, distanceFromTopEdge)
                    property real distanceFromTopRightCorner: Math.max(distanceFromRightEdge, distanceFromTopEdge)
                    property real distanceFromBottomLeftCorner: Math.max(distanceFromLeftEdge, distanceFromBottomEdge)
                    property real distanceFromBottomRightCorner: Math.max(distanceFromRightEdge, distanceFromBottomEdge)
                    topLeftRadius: Math.max((workspaceAtTopLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromTopLeftCorner, minRadius)
                    topRightRadius: Math.max((workspaceAtTopRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromTopRightCorner, minRadius)
                    bottomLeftRadius: Math.max((workspaceAtBottomLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromBottomLeftCorner, minRadius)
                    bottomRightRadius: Math.max((workspaceAtBottomRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromBottomRightCorner, minRadius)

                    Timer {
                        id: updateWindowPosition
                        interval: Config.options.hacks.arbitraryRaceConditionDelay
                        repeat: false
                        running: false
                        onTriggered: {
                            window.x = Math.round(xWithinWorkspaceWidget + xOffset)
                            window.y = Math.round(yWithinWorkspaceWidget + yOffset)
                        }
                    }

                    z: Drag.active ? root.windowDraggingZ : (root.windowZ + windowData?.floating + windowData?.fullscreen * 2)
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: hovered = true // For hover color change
                        onExited: hovered = false // For hover color change
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent
                        onPressed: (mouse) => {
                            root.draggingFromWorkspace = windowData?.workspace.id
                            window.pressed = true
                            window.Drag.active = true
                            window.Drag.source = window
                            window.Drag.hotSpot.x = mouse.x
                            window.Drag.hotSpot.y = mouse.y
                            // console.log(`[OverviewWindow] Dragging window ${windowData?.address} from position (${window.x}, ${window.y})`)
                        }
                        onReleased: {
                            const targetWorkspace = window.barDropTargetWorkspace !== -1
                                ? window.barDropTargetWorkspace
                                : root.draggingTargetWorkspace
                            const targetMonitor = window.barDropTargetWorkspace !== -1
                                ? window.barDropTargetScreen
                                : root.monitorName
                            WorkspaceDragState.clearTarget("", -1)
                            window.pressed = false
                            window.Drag.active = false
                            root.draggingFromWorkspace = -1
                            root.draggingTargetWorkspace = -1
                            if (targetWorkspace !== -1) {
                                if (targetWorkspace !== windowData?.workspace.id) {
                                    WM.moveWindowToWorkspaceAndCompact(
                                        window.windowData?.address,
                                        targetWorkspace,
                                        targetMonitor
                                    )
                                } else {
                                    updateWindowPosition.restart()
                                }
                            }
                            else {
                                if (!window.windowData.floating) {
                                    updateWindowPosition.restart()
                                    return
                                }
                                const percentageX = (window.x - xOffset) / root.workspaceImplicitWidth
                                const percentageY = (window.y - yOffset) / root.workspaceImplicitHeight
                                Hyprland.dispatch(`hl.dsp.window.move({ x = "${percentageX * root.screen.width}", y = "${percentageY * root.screen.height}", window = "address:${window.windowData?.address}" })`)
                            }
                        }
                        onClicked: (event) => {
                            if (!windowData) return;

                            if (event.button === Qt.LeftButton) {
                                GlobalStates.overviewOpen = false
                                Hyprland.dispatch(`hl.dsp.focus({ window = "address:${windowData.address}" })`)
                                event.accepted = true
                            } else if (event.button === Qt.MiddleButton) {
                                Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${windowData.address}" })`)
                                event.accepted = true
                            }
                        }

                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: dragArea.containsMouse && !window.Drag.active
                            text: `${windowData?.title}\n[${windowData?.class}] ${windowData?.xwayland ? "[XWayland] " : ""}`
                        }
                    }
                }
            }

            Rectangle { // Focused workspace indicator
                id: focusedWorkspaceIndicator
                property int rowIndex: getWsRow(root.effectiveActiveWorkspaceId)
                property int colIndex: getWsColumn(root.effectiveActiveWorkspaceId)
                x: (root.workspaceImplicitWidth + workspaceSpacing) * colIndex
                y: (root.workspaceImplicitHeight + workspaceSpacing) * rowIndex
                z: root.windowZ
                width: root.workspaceImplicitWidth
                height: root.workspaceImplicitHeight
                color: "transparent"
                property bool workspaceAtLeft: colIndex === 0
                property bool workspaceAtRight: colIndex === Config.options.overview.columns - 1
                property bool workspaceAtTop: rowIndex === 0
                property bool workspaceAtBottom: rowIndex === Config.options.overview.rows - 1
                topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                topRightRadius: (workspaceAtRight && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                border.width: 2
                border.color: root.activeBorderColor
                Behavior on x {
                    enabled: GlobalStates.overviewOpen
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on y {
                    enabled: GlobalStates.overviewOpen
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on topLeftRadius {
                    enabled: GlobalStates.overviewOpen
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on topRightRadius {
                    enabled: GlobalStates.overviewOpen
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on bottomLeftRadius {
                    enabled: GlobalStates.overviewOpen
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on bottomRightRadius {
                    enabled: GlobalStates.overviewOpen
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
            }
        }
    }
}
