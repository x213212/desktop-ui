import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    property var targetScreen: root.QsWindow.window?.screen
    property bool borderless: Config.options.bar.borderless
    property bool showDate: Config.options.bar.verbose
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: root.vertical ? 32 : flow.implicitWidth + 4
    implicitHeight: root.vertical ? flow.implicitHeight + 4 : 38

    MouseArea {
        anchors.fill: parent
        onPressed: {
            GlobalStates.toggleRightSidebarForScreen(root.targetScreen);
        }
    }

    Flow {
        id: flow
        anchors.centerIn: parent
        flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: isMaterial ? 2 : root.vertical ? 6 : 10

        Revealer {
            reveal: true
            MaterialSymbol {
                text: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                iconSize: Appearance.font.pixelSize.larger + 3
                color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
            }
        }
        Revealer {
            reveal: Audio.source?.audio?.muted ?? false
            MaterialSymbol {
                text: "mic_off"
                iconSize: Appearance.font.pixelSize.larger + 3
                color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
            }
        }
        Loader {
            source: "HyprlandXkbIndicator.qml"
            onLoaded: item.color = root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
        }
        MouseArea {
            implicitWidth: networkIcon.implicitWidth
            implicitHeight: networkIcon.implicitHeight
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                GlobalStates.openRightSidebarForScreen(root.targetScreen);
                GlobalStates.openWifiDialogRequested();
            }

            MaterialSymbol {
                id: networkIcon
                anchors.centerIn: parent
                text: Network.materialSymbol
                iconSize: Appearance.font.pixelSize.larger + 3
                color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
            }
        }
        MouseArea {
            visible: Network.vpnAvailable
            implicitWidth: vpnIcon.implicitWidth
            implicitHeight: vpnIcon.implicitHeight
            cursorShape: Qt.PointingHandCursor
            onPressed: Network.toggleVpn()

            MaterialSymbol {
                id: vpnIcon
                anchors.centerIn: parent
                text: Network.vpnActive ? "vpn_lock" : "vpn_key_off"
                iconSize: Appearance.font.pixelSize.larger + 3
                color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                opacity: Network.vpnActive ? 1.0 : 0.45
            }
        }
        MouseArea {
            visible: BluetoothStatus.available
            implicitWidth: bluetoothIcon.implicitWidth
            implicitHeight: bluetoothIcon.implicitHeight
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                GlobalStates.openRightSidebarForScreen(root.targetScreen);
                GlobalStates.openBluetoothDialogRequested();
            }

            MaterialSymbol {
                id: bluetoothIcon
                anchors.centerIn: parent
                text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                iconSize: Appearance.font.pixelSize.larger + 3
                color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
            }
        }
        MouseArea {
            width: Appearance.font.pixelSize.larger + 3
            height: Appearance.font.pixelSize.larger + 3
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                const opening = !GlobalStates.sidebarRightOpen
                GlobalStates.toggleRightSidebarForScreen(root.targetScreen)
                if (opening)
                    notificationHousekeeping.restart()
            }

            Loader {
                id: notifLoader
                anchors.fill: parent
                // Keep the bell available even after all notifications are read.
                // Only its unread badge should disappear.
                active: true
                visible: true
                source: "NotificationUnreadCount.qml"
            }
        }
    }

    Timer {
        id: notificationHousekeeping
        // Guarantee that a visible frame wins over rebuilding popup models.
        interval: 80
        repeat: false
        onTriggered: {
            Notifications.markAllRead()
            Notifications.timeoutAll()
        }
    }
}
