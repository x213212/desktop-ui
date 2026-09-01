import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope { // Scope
    id: root
    property bool pinned: Config.options?.osk.pinnedOnStartup ?? false

    component OskControlButton: GroupButton { // Pin button
        baseWidth: 40
        baseHeight: 40
        clickedWidth: baseWidth
        clickedHeight: baseHeight + 10
        buttonRadius: Appearance.rounding.normal
    }

    CachedLoader {
        id: oskLoader
        // Do not instantiate a keyboard whose raw-key backend is incompatible.
        // A short cache makes repeated show/hide instant without leaving the
        // keyboard object tree resident for the rest of the session.
        requested: GlobalStates.oskOpen && Ydotool.available
        cacheDuration: 10000

        Connections {
            target: oskLoader
            function onRequestedChanged() {
                if (!oskLoader.requested) {
                    // Reset local modifier state only. Never emit a boot-time
                    // sweep of raw keycodes: ydotool 0.1.8 types them as digits.
                    Ydotool.shiftMode = 0
                }
            }
        }
        
        sourceComponent: PanelWindow { // Window
            id: oskRoot
            property bool focusGrabRegistered: false
            visible: oskLoader.requested && !GlobalStates.screenLocked

            function syncFocusGrab() {
                if (oskRoot.visible && !oskRoot.focusGrabRegistered) {
                    GlobalFocusGrab.addPersistent(oskRoot)
                    oskRoot.focusGrabRegistered = true
                } else if (!oskRoot.visible && oskRoot.focusGrabRegistered) {
                    GlobalFocusGrab.removePersistent(oskRoot)
                    oskRoot.focusGrabRegistered = false
                }
            }

            anchors {
                bottom: true
                left: true
                right: true
            }

            function hide() {
                GlobalStates.oskOpen = false
            }
            exclusiveZone: root.pinned ? implicitHeight - Appearance.sizes.hyprlandGapsOut : 0
            implicitWidth: oskBackground.width + Appearance.sizes.elevationMargin * 2
            implicitHeight: oskBackground.height + Appearance.sizes.elevationMargin * 2
            WlrLayershell.namespace: "quickshell:osk"
            WlrLayershell.layer: WlrLayer.Overlay
            // Hyprland 0.49: Focus is always exclusive and setting this breaks mouse focus grab
            // WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            mask: Region {
                item: oskBackground
            }

            // Make it usable with other panels
            Component.onCompleted: oskRoot.syncFocusGrab()
            onVisibleChanged: oskRoot.syncFocusGrab()
            Component.onDestruction: {
                if (oskRoot.focusGrabRegistered)
                    GlobalFocusGrab.removePersistent(oskRoot)
            }

            // Background
            StyledRectangularShadow {
                target: oskBackground
            }
            Rectangle {
                id: oskBackground
                anchors.centerIn: parent
                color: Appearance.colors.colLayer0
                radius: Appearance.rounding.windowRounding
                property real padding: 10
                implicitWidth: oskRowLayout.implicitWidth + padding * 2
                implicitHeight: oskRowLayout.implicitHeight + padding * 2

                Keys.onPressed: (event) => { // Esc to close
                    if (event.key === Qt.Key_Escape) {
                        oskRoot.hide()
                    }
                }

                RowLayout {
                    id: oskRowLayout
                    anchors.centerIn: parent
                    spacing: 5
                    VerticalButtonGroup {
                        OskControlButton { // Pin button
                            toggled: root.pinned
                            downAction: () => root.pinned = !root.pinned
                            contentItem: MaterialSymbol {
                                text: "keep"
                                horizontalAlignment: Text.AlignHCenter
                                iconSize: Appearance.font.pixelSize.larger
                                color: root.pinned ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
                            }
                        }
                        OskControlButton {
                            onClicked: () => {
                                oskRoot.hide()
                            }
                            contentItem: MaterialSymbol {
                                horizontalAlignment: Text.AlignHCenter
                                text: "keyboard_hide"
                                iconSize: Appearance.font.pixelSize.larger
                            }
                        }
                    }
                    Rectangle {
                        Layout.topMargin: 20
                        Layout.bottomMargin: 20
                        Layout.fillHeight: true
                        implicitWidth: 1
                        color: Appearance.colors.colOutlineVariant
                    }
                    OskContent {
                        id: oskContent
                        Layout.fillWidth: true
                    }
                }
            }

        }
    }

    IpcHandler {
        target: "osk"

        function toggle(): void {
            GlobalStates.oskOpen = Ydotool.available && !GlobalStates.oskOpen;
        }

        function close(): void {
            GlobalStates.oskOpen = false
        }

        function open(): void {
            GlobalStates.oskOpen = Ydotool.available
        }
    }

    CompositorGlobalShortcut {
        name: "oskToggle"
        description: "Toggles on screen keyboard on press"

        onPressed: {
            GlobalStates.oskOpen = Ydotool.available && !GlobalStates.oskOpen;
        }
    }

    CompositorGlobalShortcut {
        name: "oskOpen"
        description: "Opens on screen keyboard on press"

        onPressed: {
            GlobalStates.oskOpen = Ydotool.available
        }
    }

    CompositorGlobalShortcut {
        name: "oskClose"
        description: "Closes on screen keyboard on press"

        onPressed: {
            GlobalStates.oskOpen = false
        }
    }

}
