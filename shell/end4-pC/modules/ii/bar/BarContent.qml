import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    implicitHeight: Appearance.sizes.barHeight
    width: parent.width
    readonly property real barPadding: 0
    readonly property bool isMaterial: Config.options.bar.cornerStyle === 3
    readonly property real centerPillX: centerPill.x
    readonly property real centerPillWidth: centerPill.width
    // Stable responsive breakpoint based on logical bar width. It changes
    // only when the output geometry/scale changes, not while widgets update.
    readonly property bool compactMode: width < 2300
    readonly property real safeSideWidth: Math.max(
        0, (width - absoluteCenter.width) / 2 - 14
    )

    readonly property bool trayHasItems: SystemTray.items.values.length > 0

    // A newly attached output must paint its workspace strip in the first
    // frame.  Building every clock/tray/weather/resource popup subtree in the
    // same incubation turn used to make the new PanelWindow look late even
    // though the monitor event was already available.  Keep the workspace and
    // anything before it synchronous so its final x position is stable, then
    // asynchronously incubate the rest after one 60 Hz frame.
    property bool secondaryWidgetsReady: false

    function isFirstFrameWidget(layout, name, idx) {
        const workspaceIndex = layout.indexOf("workspaces")
        return workspaceIndex >= 0 && idx <= workspaceIndex
    }

    function shouldLoadWidget(layout, name, idx) {
        return root.secondaryWidgetsReady || root.isFirstFrameWidget(layout, name, idx)
    }

    function shouldLoadAsynchronously(layout, name, idx) {
        return root.secondaryWidgetsReady && !root.isFirstFrameWidget(layout, name, idx)
    }

    Timer {
        interval: 16
        running: true
        repeat: false
        onTriggered: root.secondaryWidgetsReady = true
    }

    function filterLayout(layout) {
        if (trayHasItems) return layout
        return layout.filter(name => name !== "sysTray")
    }

    readonly property var effectiveLeftLayout:   filterLayout(Config.options.bar.layouts.leftLayout)
    readonly property var effectiveMiddleLayout: filterLayout(Config.options.bar.layouts.middleLayout)
    readonly property var effectiveRightLayout:  filterLayout(Config.options.bar.layouts.rightLayout)

    function getWidgetUrl(name) {
        if (!name) return "";
        let formattedName = name.charAt(0).toUpperCase() + name.slice(1);
        return Qt.resolvedUrl("./" + formattedName + ".qml");
    }

    function getMirroredForIndex(layout, idx) {
        const prevCount = layout.slice(0, idx).filter(w => w === "visualizer").length
        return prevCount % 2 === 1
    }

    function configureWidget(layout, name, item, idx) {
        if (!item) return
        if ("targetScreen" in item)
            item.targetScreen = Qt.binding(() => root.screen)
        if ("compact" in item)
            item.compact = Qt.binding(() => root.compactMode)
        if (name === "visualizer")
            item.mirrored = root.getMirroredForIndex(layout, idx)
    }

    function shouldPaintMaterialPill(name) {
        if (Config.options.bar.cornerStyle !== 3) return false;
        const blacklist = ["workspaces", "divisor", "powerButton", "docktoPanel", "leftSidebarButton", "activeWindow"];
        if (blacklist.includes(name)) {
            return false;
        }
        return true;
    }

    function getMaterialPillColor(name) {
        if (Config.options.bar.cornerStyle !== 3) return Appearance.colors.colPrimaryContainer;
        switch(name) {
            case "media":
            case "sysTray":
                return Appearance.colors.colSecondaryContainer;
            case "resources":
                return Appearance.colors.colTertiaryContainer;
            case "systemIcons":
                return Appearance.colors.colPrimary; 
            default:
                return Appearance.colors.colPrimaryContainer;
        }
    }

    property var screen: root.QsWindow.window?.screen
    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0


    Rectangle {
        id: barBackground
        anchors.fill: parent
        anchors.margins: Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0
        color: (!centerOnly && Config.options.bar.showBackground && Config.options.bar.cornerStyle !== 2 && !root.isMaterial)
            ? (Config.options.bar.followFrameColor
                ? Appearance.getColorFromName(Config.options.bar.frameColor)
                : Appearance.colors.colLayer0)
            : "transparent"
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: (!centerOnly && Config.options.bar.cornerStyle === 1) ? 1 : 0
        border.color: Config.options.bar.cornerStyle === 1 && !Config.options.bar.showBackground ? "transparent" : Appearance.colors.colLayer0Border
    }

    // center-only
    readonly property bool centerOnly: !root.isMaterial
        && root.effectiveLeftLayout.length === 0
        && root.effectiveRightLayout.length === 0

    Rectangle {
        id: centerPill
        visible: centerOnly && Config.options.bar.showBackground && Config.options.bar.cornerStyle !== 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: middleRow.implicitWidth + 10
        height: parent.height - (Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut * 2 : 0)
        color: Config.options.bar.followFrameColor
            ? Appearance.getColorFromName(Config.options.bar.frameColor)
            : Appearance.colors.colLayer0
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: Config.options.bar.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border

        bottomLeftRadius:  Config.options.bar.cornerStyle === 0 && !Config.options.bar.bottom ? Appearance.rounding.screenRounding : radius
        bottomRightRadius: Config.options.bar.cornerStyle === 0 && !Config.options.bar.bottom ? Appearance.rounding.screenRounding : radius
        topLeftRadius:     Config.options.bar.cornerStyle === 0 && Config.options.bar.bottom  ? Appearance.rounding.screenRounding : radius
        topRightRadius:    Config.options.bar.cornerStyle === 0 && Config.options.bar.bottom  ? Appearance.rounding.screenRounding : radius
    }

    Item {
        id: contentContainer
        anchors.fill: barBackground
        anchors.margins: root.barPadding

        // Left
        Item {
            id: leftContainer
            anchors.left: parent.left
            anchors.leftMargin: root.isMaterial ? (Config.options.hyprland.general.gapsOut || 5) : (Config.options.bar.cornerStyle === 1 ? 4 : 10)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.min(
                root.isMaterial ? leftMaterialPill.implicitWidth : leftRow.implicitWidth,
                root.safeSideWidth
            )
            clip: true

            // Material pill wrapper
            Rectangle {
                id: leftMaterialPill
                visible: root.isMaterial
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: leftMaterialRow.implicitWidth + 10
                implicitHeight: leftMaterialRow.implicitHeight
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer0

                RowLayout {
                    id: leftMaterialRow
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: root.isMaterial ? root.effectiveLeftLayout : []
                        delegate: leftMaterialGroupDelegate
                    }

                    Component {
                        id: leftMaterialGroupDelegate
                        BarGroup {
                            Layout.fillHeight: true
                            currentIndex: index
                            totalCount: root.effectiveLeftLayout.length
                            paintMaterialPill: root.shouldPaintMaterialPill(modelData)
                            bgColor: root.getMaterialPillColor(modelData)
                            Loader {
                                Layout.fillHeight: true
                                active: root.shouldLoadWidget(root.effectiveLeftLayout, modelData, index)
                                asynchronous: root.shouldLoadAsynchronously(root.effectiveLeftLayout, modelData, index)
                                source: root.getWidgetUrl(modelData)
                                onLoaded: root.configureWidget(root.effectiveLeftLayout, modelData, item, index)
                            }
                        }
                    }
                }
            }

            // Non-material layout
            RowLayout {
                id: leftRow
                visible: !root.isMaterial
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: implicitWidth
                spacing: Config.options.bar.borderless === "transparent" ? -7 : Config.options?.bar.borderless === "segmented" ? -1 : 2

                Repeater {
                    model: !root.isMaterial ? root.effectiveLeftLayout : []
                    delegate: leftBarGroupDelegate
                }

                Component {
                    id: leftBarGroupDelegate
                    BarGroup {
                        Layout.fillHeight: true
                        currentIndex: index
                        totalCount: root.effectiveLeftLayout.length
                        Loader {
                            Layout.fillHeight: true
                            active: root.shouldLoadWidget(root.effectiveLeftLayout, modelData, index)
                            asynchronous: root.shouldLoadAsynchronously(root.effectiveLeftLayout, modelData, index)
                            source: root.getWidgetUrl(modelData)
                            onLoaded: root.configureWidget(root.effectiveLeftLayout, modelData, item, index)
                        }
                    }
                }

                Component {
                    id: leftNoGroupDelegate
                    Loader {
                        Layout.fillHeight: false
                        Layout.topMargin: Config.options.bar.bottom ? -5 : 3
                        Layout.alignment: Qt.AlignVCenter
                        source: root.getWidgetUrl(modelData)
                        onLoaded: root.configureWidget(root.effectiveLeftLayout, modelData, item, index)
                    }
                }
            }
        }

        // Center
        Item {
            id: absoluteCenter
            anchors.centerIn: parent
            width: root.isMaterial ? centerMaterialPill.implicitWidth : middleRow.implicitWidth
            height: parent.height

            // Material pill wrapper
            Rectangle {
                id: centerMaterialPill
                visible: root.isMaterial
                anchors.centerIn: parent
                implicitWidth: centerMaterialRow.implicitWidth + 10
                implicitHeight: centerMaterialRow.implicitHeight 
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer0

                RowLayout {
                    id: centerMaterialRow
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: root.isMaterial ? root.effectiveMiddleLayout : []
                        delegate: middleMaterialGroupDelegate
                    }

                    Component {
                        id: middleMaterialGroupDelegate
                        BarGroup {
                            Layout.fillHeight: true
                            currentIndex: index
                            totalCount: root.effectiveMiddleLayout.length
                            paintMaterialPill: root.shouldPaintMaterialPill(modelData)
                            bgColor: root.getMaterialPillColor(modelData)
                            Loader {
                                Layout.fillHeight: true
                                active: root.shouldLoadWidget(root.effectiveMiddleLayout, modelData, index)
                                asynchronous: root.shouldLoadAsynchronously(root.effectiveMiddleLayout, modelData, index)
                                source: root.getWidgetUrl(modelData)
                                onLoaded: root.configureWidget(root.effectiveMiddleLayout, modelData, item, index)
                            }
                        }
                    }
                }
            }

            // Non-material layout
            RowLayout {
                id: middleRow
                visible: !root.isMaterial
                anchors.fill: parent
                spacing: Config.options.bar.borderless === "transparent" ? -7 : Config.options?.bar.borderless === "segmented" ? -1 : 2

                Repeater {
                    model: !root.isMaterial ? root.effectiveMiddleLayout : []
                    delegate: middleBarGroupDelegate
                }

                Component {
                    id: middleBarGroupDelegate
                    BarGroup {
                        Layout.fillHeight: true
                        currentIndex: index
                        totalCount: root.effectiveMiddleLayout.length
                        Loader {
                            Layout.fillHeight: true
                            active: root.shouldLoadWidget(root.effectiveMiddleLayout, modelData, index)
                            asynchronous: root.shouldLoadAsynchronously(root.effectiveMiddleLayout, modelData, index)
                            source: root.getWidgetUrl(modelData)
                            onLoaded: root.configureWidget(root.effectiveMiddleLayout, modelData, item, index)
                        }
                    }
                }

                Component {
                    id: middleNoGroupDelegate
                    Loader {
                        Layout.fillHeight: false
                        Layout.topMargin: Config.options.bar.bottom ? -5 : 3
                        source: root.getWidgetUrl(modelData)
                        onLoaded: root.configureWidget(root.effectiveMiddleLayout, modelData, item, index)
                    }
                }
            }
        }

        // Right
        Item {
            id: rightContainer
            anchors.right: parent.right
            anchors.rightMargin: root.isMaterial ? (Config.options.hyprland.general.gapsOut || 5) : (Config.options.bar.cornerStyle === 1 ? 4 : 10)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.min(
                root.isMaterial ? rightMaterialPill.implicitWidth : rightRow.implicitWidth,
                root.safeSideWidth
            )
            clip: true

            // Material pill wrapper
            Rectangle {
                id: rightMaterialPill
                visible: root.isMaterial
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: rightMaterialRow.implicitWidth + 10
                implicitHeight: rightMaterialRow.implicitHeight 
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer0

                RowLayout {
                    id: rightMaterialRow
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: root.isMaterial ? root.effectiveRightLayout : []
                        delegate: rightMaterialGroupDelegate
                    }

                    Component {
                        id: rightMaterialGroupDelegate
                        BarGroup {
                            Layout.fillHeight: true
                            currentIndex: index
                            totalCount: root.effectiveRightLayout.length
                            paintMaterialPill: root.shouldPaintMaterialPill(modelData)
                            bgColor: root.getMaterialPillColor(modelData)
                            Loader {
                                Layout.fillHeight: true
                                active: root.shouldLoadWidget(root.effectiveRightLayout, modelData, index)
                                asynchronous: root.shouldLoadAsynchronously(root.effectiveRightLayout, modelData, index)
                                source: root.getWidgetUrl(modelData)
                                onLoaded: root.configureWidget(root.effectiveRightLayout, modelData, item, index)
                            }
                        }
                    }
                }
            }

            // Non-material layout
            RowLayout {
                id: rightRow
                visible: !root.isMaterial
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: implicitWidth
                spacing: Config.options.bar.borderless === "transparent" ? -7 : Config.options?.bar.borderless === "segmented" ? -1 : 2

                Repeater {
                    model: !root.isMaterial ? root.effectiveRightLayout : []
                    delegate: rightBarGroupDelegate
                }

                Component {
                    id: rightBarGroupDelegate
                    BarGroup {
                        Layout.fillHeight: true
                        currentIndex: index
                        totalCount: root.effectiveRightLayout.length
                        Loader {
                            Layout.fillHeight: true
                            active: root.shouldLoadWidget(root.effectiveRightLayout, modelData, index)
                            asynchronous: root.shouldLoadAsynchronously(root.effectiveRightLayout, modelData, index)
                            source: root.getWidgetUrl(modelData)
                            onLoaded: root.configureWidget(root.effectiveRightLayout, modelData, item, index)
                        }
                    }
                }

                Component {
                    id: rightNoGroupDelegate
                    Loader {
                        Layout.fillHeight: false
                        Layout.topMargin: Config.options.bar.bottom ? -5 : 3
                        source: root.getWidgetUrl(modelData)
                        onLoaded: root.configureWidget(root.effectiveRightLayout, modelData, item, index)
                    }
                }
            }
        }
    }
}
