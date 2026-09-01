import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property Component regionComponent: Component {
        Region {}
    }
    
    CachedLoader {
        id: overlayLoader
        requested: GlobalStates.overlayOpen || OverlayContext.hasPinnedWidgets
        cacheDuration: 10000
        sourceComponent: PanelWindow {
            id: overlayWindow
            property var clickableRegions: []

            function rebuildClickableRegions() {
                for (const region of overlayWindow.clickableRegions)
                    region.destroy()
                overlayWindow.clickableRegions = OverlayContext.clickableWidgets.map(widget =>
                    regionComponent.createObject(overlayWindow, { "item": widget }))
            }

            function syncFocusGrab() {
                if (GlobalStates.overlayOpen) {
                    delayedGrabTimer.restart()
                } else {
                    delayedGrabTimer.stop()
                    grab.active = false
                }
            }

            Component.onCompleted: {
                overlayWindow.rebuildClickableRegions()
                // Async construction can complete after the open signal. Sync
                // from current state so a cold first open still owns focus.
                overlayWindow.syncFocusGrab()
            }
            Component.onDestruction: {
                for (const region of overlayWindow.clickableRegions)
                    region.destroy()
                overlayWindow.clickableRegions = []
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:overlay"
            WlrLayershell.layer: WlrLayer.Overlay
            // Use OnDemand for pinned widgets to allow focus switching with mouse clicks
            WlrLayershell.keyboardFocus: GlobalStates.overlayOpen ? WlrKeyboardFocus.Exclusive : (OverlayContext.clickableWidgets.length > 0 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)
            visible: GlobalStates.overlayOpen || OverlayContext.hasPinnedWidgets
            color: "transparent"

            mask: Region {
                item: GlobalStates.overlayOpen ? overlayContent : null
                regions: overlayWindow.clickableRegions
            }

            Connections {
                target: OverlayContext
                function onClickableWidgetsChanged() {
                    overlayWindow.rebuildClickableRegions()
                }
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            HyprlandFocusGrab {
                id: grab
                windows: [overlayWindow]
                active: false
                onCleared: () => {
                    if (!active) GlobalStates.overlayOpen = false;
                }
            }

            Connections {
                target: GlobalStates
                function onOverlayOpenChanged() {
                    overlayWindow.syncFocusGrab()
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: Appearance.animation.elementMoveFast.duration
                onTriggered: {
                    grab.active = GlobalStates.overlayOpen;
                }
            }

            OverlayContent {
                id: overlayContent
                anchors.fill: parent
            }
        }
    }

    IpcHandler {
        target: "overlay"

        function toggle(): void {
            GlobalStates.overlayOpen = !GlobalStates.overlayOpen;
        }
        function open(): void {
            GlobalStates.overlayOpen = true;
        }
        function close(): void {
            GlobalStates.overlayOpen = false;
        }
    }

    CompositorGlobalShortcut {
        name: "overlayToggle"
        description: "Toggles overlay on press"

        onPressed: {
            GlobalStates.overlayOpen = !GlobalStates.overlayOpen;
        }
    }
}
