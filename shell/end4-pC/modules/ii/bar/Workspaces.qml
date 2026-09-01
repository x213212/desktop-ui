pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

ButtonMouseArea {
    id: root

    // BarContent replaces this fallback with an explicit binding to the
    // owning PanelWindow's screen after the dynamic widget is loaded.
    property var targetScreen: root.QsWindow.window?.screen
    property string stableTargetScreenName: ""

    WorkspaceModel {
        id: wsModel
        screen: root.targetScreen
    }

    property bool vertical: Config.options.bar.vertical
    property bool superPressAndHeld: false // Relevant modifications at bottom of file
    readonly property int dragTargetIndex: WorkspaceDragState.targetScreenName
        === root.stableTargetScreenName
        ? WorkspaceDragState.targetIndex : -1
    readonly property bool workspaceAnimationsEnabled: !GlobalStates.sessionRestoreActive
        && !WorkspaceDragState.compactionActive
    readonly property bool appIconsEnabled: Config.options?.bar.workspaces.showAppIcons ?? false
    readonly property bool barBottom: Config.options.bar.bottom
    readonly property real barWindowWidth: root.QsWindow.window?.width ?? root.width
    readonly property real barWindowHeight: root.QsWindow.window?.height ?? root.height
    readonly property real targetScreenWidth: root.targetScreen?.width ?? root.barWindowWidth
    readonly property real targetScreenHeight: root.targetScreen?.height ?? root.barWindowHeight

    property real workspaceButtonWidth: Config.options.bar.cornerStyle === 3 ? 30 : 26
    property real activeWorkspaceMargin: 2
    property real activeWorkspaceSize: workspaceButtonWidth - activeWorkspaceMargin * 2
    property real workspaceIconSize: workspaceButtonWidth * 0.69
    property real workspaceIconSizeShrinked: workspaceButtonWidth * 0.55
    property real workspaceIconOpacityShrinked: 1
    property real workspaceIconMarginShrinked: -4
    property int workspaceIndexInGroup: Math.max(0, Math.min(
        wsModel.shownCount - 1,
        wsModel.activeNumber - wsModel.getWorkspaceIdAt(0)
    ))
    property real specialTextSize: workspaceButtonWidth * 0.5

    Layout.alignment: vertical ? Qt.AlignHCenter : Qt.AlignVCenter
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical
    readonly property real barThickness: vertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight
    implicitWidth: vertical ? barThickness : occupiedIndicators.implicitWidth
    implicitHeight: vertical ? occupiedIndicators.implicitHeight : barThickness

    function publishWorkspaceDragGeometry() {
        const screenName = root.stableTargetScreenName
        if (!screenName)
            return
        if (wsModel.shownCount <= 0 || root.width <= 0 || root.height <= 0) {
            WorkspaceDragState.removeBarRegion(screenName)
            return
        }

        const scenePosition = root.mapToItem(null, 0, 0)
        const screenX = root.vertical && root.barBottom
            ? root.targetScreenWidth - root.barWindowWidth + scenePosition.x
            : scenePosition.x
        const screenY = root.barBottom
            ? (root.vertical ? scenePosition.y
                : root.targetScreenHeight - root.barWindowHeight + scenePosition.y)
            : scenePosition.y
        const workspaceIds = []
        for (let index = 0; index < wsModel.shownCount; index++)
            workspaceIds.push(wsModel.getWorkspaceIdAt(index))

        WorkspaceDragState.setBarRegion(
            screenName,
            screenX,
            screenY,
            root.width,
            root.height,
            root.workspaceButtonWidth,
            wsModel.shownCount,
            root.vertical,
            workspaceIds
        )
    }

    function scheduleWorkspaceDragGeometryPublish() {
        geometryPublishTimer.restart()
    }

    Timer {
        id: geometryPublishTimer
        interval: 0
        repeat: false
        onTriggered: root.publishWorkspaceDragGeometry()
    }

    Component.onCompleted: {
        root.stableTargetScreenName = root.targetScreen?.name ?? ""
        root.scheduleWorkspaceDragGeometryPublish()
    }
    Component.onDestruction: {
        geometryPublishTimer.stop()
        WorkspaceDragState.removeBarRegion(root.stableTargetScreenName)
    }
    onXChanged: root.scheduleWorkspaceDragGeometryPublish()
    onYChanged: root.scheduleWorkspaceDragGeometryPublish()
    onWidthChanged: root.scheduleWorkspaceDragGeometryPublish()
    onHeightChanged: root.scheduleWorkspaceDragGeometryPublish()
    onTargetScreenChanged: {
        const nextName = root.targetScreen?.name ?? ""
        if (root.stableTargetScreenName
                && root.stableTargetScreenName !== nextName)
            WorkspaceDragState.removeBarRegion(root.stableTargetScreenName)
        root.stableTargetScreenName = nextName
        root.scheduleWorkspaceDragGeometryPublish()
    }
    onVerticalChanged: root.scheduleWorkspaceDragGeometryPublish()
    onWorkspaceButtonWidthChanged: root.scheduleWorkspaceDragGeometryPublish()
    onBarBottomChanged: root.scheduleWorkspaceDragGeometryPublish()
    onBarWindowWidthChanged: root.scheduleWorkspaceDragGeometryPublish()
    onBarWindowHeightChanged: root.scheduleWorkspaceDragGeometryPublish()
    onTargetScreenWidthChanged: root.scheduleWorkspaceDragGeometryPublish()
    onTargetScreenHeightChanged: root.scheduleWorkspaceDragGeometryPublish()

    Connections {
        target: wsModel

        function onGroupChanged() {
            root.scheduleWorkspaceDragGeometryPublish()
        }

        function onShownCountChanged() {
            root.scheduleWorkspaceDragGeometryPublish()
        }
    }

    property real specialBlur: (wsModel.specialWorkspaceActive && !containsMouse) ? 1 : 0
    Behavior on specialBlur {
        enabled: root.workspaceAnimationsEnabled
        animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
    }

    // Interactions
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    property int hoverIndex: {
        const position = root.vertical ? mouseY : mouseX;
        return Math.floor(position / root.workspaceButtonWidth);
    }

    function switchWorkspaceToHovered() {
        if (hoverIndex < 0 || hoverIndex >= wsModel.shownCount)
            return
        const target = wsModel.getWorkspaceIdAt(hoverIndex)
        if (target < 1)
            return
        WM.switchWorkspaceSlot(
            hoverIndex + 1,
            target,
            root.stableTargetScreenName
        );
    }
    onPressed: mouse => {
        if (mouse.button == Qt.LeftButton)
            switchWorkspaceToHovered();
        else if (mouse.button == Qt.RightButton)
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
    }
    onWheel: event => {
        const offset = event.angleDelta.y < 0 ? 1
            : (event.angleDelta.y > 0 ? -1 : 0)
        if (offset === 0 || wsModel.shownCount <= 0)
            return
        const target = wsModel.getRelativeWorkspaceId(offset)
        const first = wsModel.getWorkspaceIdAt(0)
        if (target < first)
            return
        // The bar wraps across the number of buttons it actually displays;
        // keyboard relative navigation intentionally retains all ten slots.
        WM.switchWorkspaceSlot(
            target - first + 1,
            target,
            root.stableTargetScreenName
        )
    }

    // Indications
    Item {
        id: regularWorkspaces
        anchors.fill: parent

        scale: 1 - 0.08 * root.specialBlur
        opacity: 1 - 0.12 * root.specialBlur

        /////////////////// Occupied indicators ///////////////////
        WorkspaceLayout {
            id: occupiedIndicators
            z: 1
            anchors.centerIn: parent

            Repeater {
                model: wsModel.shownCount
                delegate: Item {
                    id: wsBg
                    required property int index
                    readonly property int wsId: wsModel.getWorkspaceIdAt(index)
                    property bool currentOccupied: wsModel.occupied[index] && wsId != wsModel.fakeWorkspace
                    property bool previousOccupied: index > 0 && wsModel.occupied[index - 1] && (wsId - 1) != wsModel.fakeWorkspace
                    property bool nextOccupied: index < wsModel.shownCount - 1 && wsModel.occupied[index + 1] && (wsId + 1) != wsModel.fakeWorkspace
                    implicitWidth: root.workspaceButtonWidth
                    implicitHeight: root.workspaceButtonWidth
                    // Adjacent pills deliberately extend by half a cell to
                    // form one connected capsule. Clip each delegate at its
                    // cell boundary so their translucent fills never stack.
                    clip: true

                    // Over-stretch toward occupied neighbours; the per-cell
                    // clip above preserves round outer ends and flat joins.
                    Pill {
                        property real undirectionalWidth: root.workspaceButtonWidth * wsBg.currentOccupied
                        property real undirectionalLength: root.workspaceButtonWidth * (1 + 0.5 * wsBg.previousOccupied + 0.5 * wsBg.nextOccupied) * currentOccupied
                        property real undirectionalOffset: (!wsBg.currentOccupied ? 0.5 : -0.5 * wsBg.previousOccupied) * root.workspaceButtonWidth
                        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
                        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
                        x: root.vertical ? 0 : undirectionalOffset
                        y: root.vertical ? undirectionalOffset : 0
                        implicitWidth: root.vertical ? undirectionalWidth : undirectionalLength
                        implicitHeight: root.vertical ? undirectionalLength : undirectionalWidth
                        color: ColorUtils.transparentize(
                            Appearance.m3colors.m3secondaryContainer, 0.4)
                        visible: wsBg.currentOccupied

                        Behavior on undirectionalWidth {
                            enabled: root.workspaceAnimationsEnabled
                            animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
                        }
                        Behavior on undirectionalLength {
                            enabled: root.workspaceAnimationsEnabled
                            animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
                        }
                        Behavior on undirectionalOffset {
                            enabled: root.workspaceAnimationsEnabled
                            animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
                        }
                    }
                }
            }
        }

        /////////////////// Active indicator ///////////////////
        TrailingIndicator {
            id: activeIndicator
            anchors.fill: parent
            z: 2

            index: root.workspaceIndexInGroup
            animated: false
            // Immediate cable acknowledgement: routing remains safely fenced,
            // but the active pill becomes a topology status light in the same
            // raw monitor event turn.
            color: GlobalStates.hotplugVisualActive
                ? Appearance.colors.colTertiary : Appearance.colors.colPrimary
        }

        /////////////////// Hover ///////////////////
        TrailingIndicator {
            id: interactionIndicator
            z: 3
            index: root.containsMouse ? root.hoverIndex : root.workspaceIndexInGroup
            // A non-hovered state layer belongs directly on the active cell.
            // Animating it after every workspace switch left a visible ghost
            // between the old and new indicators and kept rendering for 150ms.
            animated: root.containsMouse
            color: "transparent"
            StateOverlay {
                id: hoverOverlay
                anchors.fill: interactionIndicator.indicatorRectangle
                radius: root.activeWorkspaceSize / 2
                hover: root.containsMouse
                press: root.containsPress
                drag: true // There are too many layers so we need to force this to be a lil more opaque
                contentColor: Appearance.colors.colPrimary
            }
        }

        // No trailing animation here: the old cell must stop glowing the
        // instant the drag leaves it.
        TrailingIndicator {
            id: workspaceDropIndicator
            z: 3.5
            visible: root.dragTargetIndex >= 0
            index: Math.max(0, root.dragTargetIndex)
            animated: false
            color: Appearance.colors.colTertiary
        }

        /////////////////// Numbers ///////////////////
        WorkspaceLayout {
            id: numbersGrid
            z: 4

            Repeater {
                model: wsModel.shownCount
                delegate: NumberWorkspaceItem {}
            }
        }

        /////////////////// App icons ///////////////////
        WorkspaceLayout {
            id: appsGrid
            z: 6

            Repeater {
                // Do not build ten hidden AppIcon/effect subtrees when the
                // feature is disabled (the default on this UI).
                model: root.appIconsEnabled ? wsModel.shownCount : 0
                delegate: WorkspaceItem {
                    id: wsApp
                    property var biggestWindow: wsModel.biggestWindow[index]
                    readonly property bool appIconEnabled: Config.options?.bar.workspaces.showAppIcons && !!biggestWindow
                    property var mainAppIconSource: appIconEnabled
                        ? Quickshell.iconPath(AppSearch.guessIcon(biggestWindow?.class), "image-missing")
                        : ""

                    AppIcon {
                        id: appIcon
                        property real cornerMargin: (!root.superPressAndHeld && Config.options?.bar.workspaces.showAppIcons && wsApp.biggestWindow) ? (root.workspaceButtonWidth - root.workspaceIconSize) / 2 : root.workspaceIconMarginShrinked
                        anchors {
                            bottom: parent.bottom
                            right: parent.right
                            bottomMargin: (parent.implicitHeight - root.workspaceButtonWidth) / 2 + cornerMargin
                            rightMargin: (parent.implicitWidth - root.workspaceButtonWidth) / 2 + cornerMargin
                        }

                        animated: !wsApp.biggestWindow // Prevent the "image-missing" icon
                        visible: false // Prevent dupe: the colorizer already copies the icon

                        source: wsApp.mainAppIconSource
                        implicitSize: NumberUtils.roundToEven(root.workspaceIconSize)

                        Behavior on opacity {
                            enabled: root.workspaceAnimationsEnabled
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Behavior on cornerMargin {
                            enabled: root.workspaceAnimationsEnabled
                            animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
                        }
                    }

                    Circle {
                        id: iconMask
                        visible: false
                        layer.enabled: wsApp.appIconEnabled
                        diameter: appIcon.implicitSize
                    }

                    Loader { // Somehow putting this multieffect in a loader prevents it from not showing up
                        id: colorizer
                        // Colorizer is a texture/effect subtree. Do not keep one
                        // per workspace alive when app icons are disabled or the
                        // workspace has no source window.
                        active: wsApp.appIconEnabled
                        anchors.fill: appIcon
                        sourceComponent: Colorizer {
                            implicitWidth: appIcon.implicitWidth
                            implicitHeight: appIcon.implicitHeight
                            colorizationColor: Appearance.m3colors.darkmode ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary
                            colorization: Config.options.bar.workspaces.monochromeIcons ? 0.8 : 0.5
                            brightness: 0
                            source: appIcon

                            opacity: !Config.options?.bar.workspaces.showAppIcons ? 0 : (wsApp.biggestWindow && !root.superPressAndHeld && Config.options?.bar.workspaces.showAppIcons) ? 1 : wsApp.biggestWindow ? root.workspaceIconOpacityShrinked : 0
                            visible: opacity > 0
                            scale: ((!root.superPressAndHeld && Config.options?.bar.workspaces.showAppIcons) ? root.workspaceIconSize : root.workspaceIconSizeShrinked) / root.workspaceIconSize

                            Behavior on opacity {
                                enabled: root.workspaceAnimationsEnabled
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }
                            Behavior on scale {
                                enabled: root.workspaceAnimationsEnabled
                                animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
                            }

                            maskEnabled: true
                            maskSource: iconMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }
                    }
                }
            }
        }

    }

    FadeLoader {
        anchors.centerIn: parent
        shown: wsModel.specialWorkspaceActive
        scale: 0.8 + 0.2 * root.specialBlur

        opacity: root.specialBlur
        Behavior on opacity {} // Don't animate, as specialBlur is already animated

        sourceComponent: Pill {
            anchors.centerIn: parent
            property real undirectionalWidth: root.activeWorkspaceSize
            property real undirectionalLength: {
                const base = root.workspaceButtonWidth * Math.min(1.35, wsModel.shownCount); // Who tf only configures only 2 workspaces shown anyway?
                if (root.vertical)
                    return base;
                return specialWsText.implicitWidth + undirectionalWidth;
            }
            color: Appearance.colors.colPrimary

            implicitWidth: root.vertical ? undirectionalWidth : undirectionalLength
            implicitHeight: root.vertical ? undirectionalLength : undirectionalWidth

            StyledText {
                id: specialWsText
                anchors.centerIn: parent
                text: (!root.vertical ? wsModel.specialWorkspaceName : "S")
                color: Appearance.colors.colOnPrimary
                font.pixelSize: root.specialTextSize
            }

            Behavior on undirectionalLength {
                enabled: root.workspaceAnimationsEnabled
                animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
            }
        }
    }

    /////////////////// Super key press handling ///////////////////
    Timer {
        id: superPressAndHeldTimer
        interval: (Config?.options.bar.autoHide.showWhenPressingSuper.delay ?? 100)
        repeat: false
        onTriggered: {
            root.superPressAndHeld = true;
        }
    }
    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (!GlobalStates.overviewOpen)
                WorkspaceDragState.clearTarget("", -1)
        }
        function onSuperDownChanged() {
            if (!Config?.options.bar.autoHide.showWhenPressingSuper.enable)
                return;
            if (GlobalStates.superDown)
                superPressAndHeldTimer.restart();
            else {
                superPressAndHeldTimer.stop();
                root.superPressAndHeld = false;
            }
        }
        function onSuperReleaseMightTriggerChanged() {
            superPressAndHeldTimer.stop();
        }
    }

    component WorkspaceLayout: Box {
        anchors {
            top: !root.vertical ? parent.top : undefined
            bottom: !root.vertical ? parent.bottom : undefined
            left: root.vertical ? parent.left : undefined
            right: root.vertical ? parent.right : undefined
        }

        rowSpacing: 0
        columnSpacing: 0
        vertical: root.vertical
    }

    component WorkspaceItem: Item {
        required property int index
        readonly property int wsId: wsModel.getWorkspaceIdAt(index)
        implicitWidth: root.vertical ? root.barThickness : root.workspaceButtonWidth
        implicitHeight: root.vertical ? root.workspaceButtonWidth : root.barThickness
    }

    component NumberWorkspaceItem: WorkspaceItem {
        id: wsNum
        property bool hasBiggestWindow: !!wsModel.biggestWindow[index]
        property int wsId: wsModel.getWorkspaceIdAt(index)
        property color contentColor: root.dragTargetIndex === wsNum.index
            ? Appearance.colors.colOnTertiary
            : (root.workspaceIndexInGroup === wsNum.index
                ? Appearance.colors.colOnPrimary
            : ((wsModel.occupied[wsNum.index] && wsId !== wsModel.fakeWorkspace)
                ? Appearance.colors.colOnSecondaryContainer
                : Appearance.colors.colOnLayer1Inactive))
        property bool showingNumbers: {
            if (root.dragTargetIndex === wsNum.index)
                return true;
            if (root.superPressAndHeld)
                return true;
            if (GlobalStates.screenLocked)
                return false;
            if (Config.options?.bar.workspaces.alwaysShowNumbers && (!Config.options?.bar.workspaces.showAppIcons || !wsNum.hasBiggestWindow))
                return true;
            return false;
        }

        FadeLoader {
            shown: !wsNum.showingNumbers
            anchors.centerIn: parent
            Loader {
                anchors.centerIn: parent
                sourceComponent: (Config.options?.bar.workspaces.indicatorStyle ?? "dot") === "icon" ? iconComponent : dotComponent

                Component {
                    id: dotComponent
                    Circle {
                        anchors.centerIn: parent
                        diameter: root.workspaceButtonWidth * 0.18
                        color: wsNum.contentColor
                    }
                }

                Component {
                    id: iconComponent
                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: root.workspaceButtonWidth * 0.50
                        color: wsNum.contentColor
                        text: {
                            switch (wsNum.wsId) {
                                case 1:  return "code"
                                case 2:  return "public"
                                case 3:  return "music_note"
                                case 4:  return "edit_square"
                                case 5:  return "image"
                                case 6:  return "forum"
                                case 7:  return "browser_updated"
                                case 8:  return "finance_mode"
                                case 9:  return "monitor"
                                case 10: return "analytics"
                                default: return "circle"
                            }
                        }
                    }
                }
            }
        }
        FadeLoader {
            shown: wsNum.showingNumbers
            anchors.centerIn: parent
            StyledText {
                anchors.centerIn: parent
                font {
                    pixelSize: Appearance.font.pixelSize.small - ((text.length - 1) * (text !== "10") * 2)
                    family: Config.options?.bar.workspaces.useNerdFont ? Appearance.font.family.iconNerd : defaultFont
                }
                color: wsNum.contentColor
                text: Config.options?.bar.workspaces.numberMap[wsNum.wsId - 1] || wsNum.wsId
            }
        }
    }

    component TrailingIndicator: Item {
        id: trailingIndicator
        anchors.fill: parent
        required property int index
        property bool animated: root.workspaceAnimationsEnabled
        property alias indicatorRectangle: indicatorRect
        property alias color: indicatorRect.color

        property var indexPair: AnimatedTabIndexPair {
            id: idxPair
            index: trailingIndicator.index
            // Paint the new target within the next 60 Hz frame, then let only
            // the old edge close smoothly. A slow leading edge made the bar
            // look one state behind even though the native event was timely.
            idx1Duration: 16
            idx2Duration: 150
            animated: trailingIndicator.animated
        }

        StyledRectangle {
            id: indicatorRect

            anchors {
                verticalCenter: root.vertical ? undefined : parent.verticalCenter
                horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
            }

            property real indicatorPosition: Math.min(idxPair.idx1, idxPair.idx2) * root.workspaceButtonWidth + root.activeWorkspaceMargin
            property real indicatorLength: Math.abs(idxPair.idx1 - idxPair.idx2) * root.workspaceButtonWidth + root.activeWorkspaceSize
            property real indicatorThickness: root.activeWorkspaceSize

            contentLayer: StyledRectangle.ContentLayer.Group
            radius: indicatorThickness / 2
            color: Appearance.colors.colPrimary

            x: root.vertical ? null : indicatorPosition
            y: root.vertical ? indicatorPosition : null
            implicitWidth: root.vertical ? indicatorThickness : indicatorLength
            implicitHeight: root.vertical ? indicatorLength : indicatorThickness
        }
    }
}
