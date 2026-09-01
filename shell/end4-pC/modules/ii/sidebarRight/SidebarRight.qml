pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property int preferredSidebarWidth: Appearance.sizes.sidebarWidth
    readonly property bool centerOnly: Config.options.bar.layouts.leftLayout.length === 0 && Config.options.bar.layouts.rightLayout.length === 0 && !Config.options.bar.vertical

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panelWindow
            required property var modelData
            screen: panelWindow.modelData
            readonly property int sidebarWidth: Math.min(
                root.preferredSidebarWidth,
                Math.max(1, (panelWindow.modelData?.width ?? root.preferredSidebarWidth) - 16)
            )
            // Only the bar's target screen owns a mapped surface and content.
            // Keeping every output resident multiplies the sidebar object tree
            // and causes global dialog requests to fan out to every monitor.
            // Mirror the old `find(...) ?? screens[0]` fallback: before any bell
            // click there is no remembered name, and without this no screen
            // would consider itself the target and the panel never appears.
            readonly property bool isTargetScreen: {
                const wanted = GlobalStates.barTargetScreenName;
                const mine = panelWindow.modelData?.name ?? "";
                if (wanted && Quickshell.screens.some(s => s.name === wanted))
                    return mine === wanted;
                return mine === (Quickshell.screens[0]?.name ?? "");
            }

            readonly property bool animatedEntrance: WM.compositor !== "hyprland"
            property bool reallyVisible: false
            property bool focusGrabDestroying: false
            readonly property bool presented: GlobalStates.sidebarRightOpen
                && panelWindow.isTargetScreen

            // Keep exactly the target surface mapped. Closed input remains an
            // empty region below, while non-target outputs own no mapped buffer.
            visible: panelWindow.isTargetScreen

            function syncPresentation() {
                if (!panelWindow.isTargetScreen) {
                    closeAnimTimer.stop()
                    panelWindow.reallyVisible = false
                    return
                }
                if (panelWindow.presented) {
                    closeAnimTimer.stop()
                    panelWindow.reallyVisible = true
                } else if (panelWindow.animatedEntrance && panelWindow.reallyVisible) {
                    closeAnimTimer.restart()
                } else {
                    panelWindow.reallyVisible = false
                }
            }

            function syncFocusGrab() {
                focusGrabTimer.stop();

                // Removing first makes screen retargeting atomic from the
                // focus manager's point of view. Restarting the owned timer
                // invalidates any queued registration for the previous target.
                GlobalFocusGrab.removeDismissable(panelWindow);
                if (panelWindow.focusGrabDestroying
                        || !panelWindow.presented
                        || !panelWindow.reallyVisible
                        || !panelWindow.isTargetScreen)
                    return;

                focusGrabTimer.restart();
            }

            Timer {
                id: focusGrabTimer
                interval: 0
                repeat: false
                onTriggered: {
                    if (panelWindow.focusGrabDestroying
                            || !panelWindow.presented
                            || !panelWindow.reallyVisible
                            || !panelWindow.isTargetScreen)
                        return;
                    GlobalFocusGrab.addDismissable(panelWindow);
                }
            }

            Component.onCompleted: panelWindow.syncPresentation()
            Component.onDestruction: {
                panelWindow.focusGrabDestroying = true;
                focusGrabTimer.stop();
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
            onIsTargetScreenChanged: {
                panelWindow.syncFocusGrab();
                panelWindow.syncPresentation();
            }
            onScreenChanged: panelWindow.syncFocusGrab()

            Connections {
                target: GlobalStates
                function onSidebarRightOpenChanged() {
                    panelWindow.syncFocusGrab()
                    panelWindow.syncPresentation()
                }
            }

            Timer {
                id: closeAnimTimer
                interval: 150
                onTriggered: panelWindow.reallyVisible = false
            }

            function hide() {
                GlobalStates.sidebarRightOpen = false;
            }

            onReallyVisibleChanged: panelWindow.syncFocusGrab()

            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    panelWindow.hide();
                }
            }

            exclusiveZone: 0
            implicitWidth: panelWindow.sidebarWidth
            WlrLayershell.namespace: "quickshell:sidebarRight"
            WlrLayershell.keyboardFocus: panelWindow.presented
                ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            color: "transparent"

            mask: Region {
                item: panelWindow.reallyVisible ? entranceWrapper : null
            }

            anchors {
                top: true
                right: true
                bottom: true
                // The entrance wrapper can slide within the sidebar-width
                // surface; a full-output transparent buffer is unnecessary.
                left: false
            }

            margins {
                top: {
                    if (Config.options.bar.bottom) return 0;
                    if (Config?.options.bar.autoHide.enable) return 0;
                    if (!centerOnly) return 0;
                    switch (Config.options.bar.cornerStyle) {
                    case 0: return -Appearance.sizes.barHeight;
                    case 1: return -Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut;
                    case 2: return -Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut;
                    case 3: return -Appearance.sizes.barHeight - Appearance.sizes.hyprlandGapsOut;
                    default: return 0;
                    }
                }
                bottom: {
                    if (!Config.options.bar.bottom) return 0;
                    if (Config?.options.bar.autoHide.enable) return 0;
                    if (!centerOnly) return 0;
                    switch (Config.options.bar.cornerStyle) {
                    case 0: return -Appearance.sizes.barHeight;
                    case 1: return -Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut;
                    case 2: return -Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut;
                    case 3: return -Appearance.sizes.barHeight - Appearance.sizes.hyprlandGapsOut;
                    default: return 0;
                    }
                }
            }

            Item {
                anchors.fill: parent

                MouseArea {
                    id: outsideClickArea
                    anchors.fill: parent
                    enabled: panelWindow.animatedEntrance
                    visible: panelWindow.animatedEntrance
                    onClicked: panelWindow.hide()
                }

                Item {
                    id: entranceWrapper
                    visible: panelWindow.reallyVisible
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: panelWindow.sidebarWidth
                    clip: true

                    readonly property bool open: panelWindow.presented
                    property real cachedParentWidth: panelWindow.sidebarWidth
                    readonly property real restX: cachedParentWidth - width
                    x: panelWindow.animatedEntrance ? (open ? restX : cachedParentWidth) : restX

                    Connections {
                        target: entranceWrapper.parent
                        function onWidthChanged() {
                            if (entranceWrapper.parent.width > 0)
                                entranceWrapper.cachedParentWidth = entranceWrapper.parent.width;
                        }
                    }

                    Behavior on x {
                        enabled: panelWindow.animatedEntrance
                        NumberAnimation {
                            duration: entranceWrapper.open
                                ? Appearance.animation.sidebarSlideEnter.duration
                                : Appearance.animation.sidebarSlideExit.duration
                            easing.type: entranceWrapper.open
                                ? Appearance.animation.sidebarSlideEnter.type
                                : Appearance.animation.sidebarSlideExit.type
                            easing.bezierCurve: entranceWrapper.open
                                ? Appearance.animation.sidebarSlideEnter.bezierCurve
                                : Appearance.animation.sidebarSlideExit.bezierCurve
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: (mouse) => { mouse.accepted = true }
                        z: -1
                    }

                    CachedLoader {
                        id: sidebarContentLoader
                        // Re-targeting across monitors must never synchronously
                        // rebuild this large tree. Keep the previous monitor hot
                        // briefly for back-and-forth use, then release it.
                        requested: panelWindow.isTargetScreen
                            && (panelWindow.reallyVisible
                                || Config.options.sidebar.keepRightSidebarLoaded)
                        cacheDuration: 30000
                        anchors {
                            fill: parent
                            margins: Appearance.sizes.hyprlandGapsOut
                            leftMargin: Appearance.sizes.elevationMargin
                        }
                        width: panelWindow.sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
                        height: parent.height - Appearance.sizes.hyprlandGapsOut * 2

                        focus: panelWindow.presented
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                panelWindow.hide();
                            }
                        }

                        sourceComponent: SidebarRightContent {
                            presented: panelWindow.presented
                        }
                    }
                }
            }

        }
    }

        IpcHandler {
            target: "sidebarRight"

            function toggle(): void {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }

            function close(): void {
                GlobalStates.sidebarRightOpen = false;
            }

            function open(): void {
                GlobalStates.sidebarRightOpen = true;
            }
        }

        CompositorGlobalShortcut {
            name: "sidebarRightToggle"
            description: "Toggles right sidebar on press"

            onPressed: {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }
        }
        CompositorGlobalShortcut {
            name: "sidebarRightOpen"
            description: "Opens right sidebar on press"

            onPressed: {
                GlobalStates.sidebarRightOpen = true;
            }
        }
        CompositorGlobalShortcut {
            name: "sidebarRightClose"
            description: "Closes right sidebar on press"

            onPressed: {
                GlobalStates.sidebarRightOpen = false;
            }
        }
}
