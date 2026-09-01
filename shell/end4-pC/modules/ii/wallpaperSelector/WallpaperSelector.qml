import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool reallyOpen: false

    Connections {
        target: GlobalStates
        function onWallpaperSelectorOpenChanged() {
            if (GlobalStates.wallpaperSelectorOpen) {
                closeAnimTimer.stop();
                root.reallyOpen = true;
            } else {
                closeAnimTimer.restart();
            }
        }
    }

    Timer {
        id: closeAnimTimer
        interval: Appearance.animation.sidebarSlideExit.duration
        onTriggered: root.reallyOpen = false
    }

    CachedLoader {
        id: wallpaperSelectorLoader
        requested: root.reallyOpen
        cacheDuration: 20000

        sourceComponent: PanelWindow {
            id: panelWindow
            property bool constructionComplete: false
            property bool slideInStarted: false
            visible: root.reallyOpen
            readonly property var monitor: WM.monitorFor(panelWindow.screen)
            property bool monitorIsFocused: WM.compositor === "hyprland"
                ? (Hyprland.focusedMonitor?.name == monitor?.name)
                : (WM.focusedMonitor?.name == monitor?.name)

            function syncPresentation() {
                const shouldPresent = panelWindow.visible
                    && GlobalStates.wallpaperSelectorOpen;
                GlobalFocusGrab.removeDismissable(panelWindow);

                if (shouldPresent) {
                    GlobalFocusGrab.addDismissable(panelWindow);
                    if (panelWindow.constructionComplete
                            && !panelWindow.slideInStarted) {
                        panelWindow.slideInStarted = true;
                        content.slideIn();
                    }
                } else {
                    panelWindow.slideInStarted = false;
                    if (panelWindow.constructionComplete)
                        content.cancelSlideIn();
                }
            }

            Component.onCompleted: {
                panelWindow.constructionComplete = true;
                panelWindow.syncPresentation();
            }
            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:wallpaperSelector"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors.top: true
            margins {
                top: Config?.options.bar.vertical ? Appearance.sizes.hyprlandGapsOut : Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut
            }

            mask: Region {
                item: content
            }

            implicitHeight: Appearance.sizes.wallpaperSelectorHeight
            implicitWidth: Appearance.sizes.wallpaperSelectorWidth

            onVisibleChanged: panelWindow.syncPresentation()
            Connections {
                target: GlobalStates
                function onWallpaperSelectorOpenChanged() {
                    panelWindow.syncPresentation();
                }
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.wallpaperSelectorOpen = false;
                }
            }

            WallpaperSelectorContent {
                id: content
                width: parent.width
                height: parent.height
                x: 0
                y: 0
                property int slideEpoch: 0

                function revealIfCurrent(epoch) {
                    if (epoch !== content.slideEpoch
                            || !panelWindow.visible
                            || !GlobalStates.wallpaperSelectorOpen)
                        return;
                    content.y = 0;
                }

                function slideIn() {
                    content.slideEpoch += 1;
                    content.y = -content.height;
                    slideInTimer.restart();
                }

                function cancelSlideIn() {
                    content.slideEpoch += 1;
                    slideInTimer.stop();
                    slideInSecondTimer.stop();
                    content.y = -content.height;
                }

                Timer {
                    id: slideInTimer
                    interval: 0
                    repeat: false
                    onTriggered: {
                        if (WM.compositor === "niri")
                            slideInSecondTimer.restart();
                        else
                            content.revealIfCurrent(content.slideEpoch);
                    }
                }

                Timer {
                    id: slideInSecondTimer
                    interval: 0
                    repeat: false
                    onTriggered: content.revealIfCurrent(content.slideEpoch)
                }

                Connections {
                    target: GlobalStates
                    function onWallpaperSelectorOpenChanged() {
                        if (!GlobalStates.wallpaperSelectorOpen)
                            content.cancelSlideIn();
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: WM.compositor === "niri"
                            ? Appearance.animation.sidebarSlideEnter.duration
                            : Appearance.animation.sidebarSlideExit.duration
                        easing.type: GlobalStates.wallpaperSelectorOpen
                            ? Appearance.animation.sidebarSlideEnter.type
                            : Appearance.animation.sidebarSlideExit.type
                        easing.bezierCurve: GlobalStates.wallpaperSelectorOpen
                            ? Appearance.animation.sidebarSlideEnter.bezierCurve
                            : Appearance.animation.sidebarSlideExit.bezierCurve
                    }
                }
            }
        }
    }

    function toggleWallpaperSelector() {
        if (Config.options.wallpaperSelector.useSystemFileDialog) {
            Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode);
            return;
        }
        GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen
    }

    IpcHandler {
        target: "wallpaperSelector"

        function toggle(): void {
            root.toggleWallpaperSelector();
        }

        function open(): void {
            if (Config.options.wallpaperSelector.useSystemFileDialog) {
                Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode);
                return;
            }
            GlobalStates.wallpaperSelectorOpen = true;
        }

        function close(): void {
            GlobalStates.wallpaperSelectorOpen = false;
        }

        function random(): void {
            Wallpapers.randomFromCurrentFolder();
        }
    }

    CompositorGlobalShortcut {
        name: "wallpaperSelectorToggle"
        description: "Toggle wallpaper selector"
        onPressed: {
            root.toggleWallpaperSelector();
        }
    }

    CompositorGlobalShortcut {
        name: "wallpaperSelectorRandom"
        description: "Select random wallpaper in current folder"
        onPressed: {
            Wallpapers.randomFromCurrentFolder();
        }
    }
}
