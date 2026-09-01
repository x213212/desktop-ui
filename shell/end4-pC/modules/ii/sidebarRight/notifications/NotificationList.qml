import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    NotificationListView { // Scrollable window
        id: listview
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: statusRow.top
        anchors.bottomMargin: 5

        // A full-list OpacityMask forces an off-screen texture redraw while
        // scrolling. Normal clipping is enough inside the sidebar.
        clip: true

        popup: false
    }

    // Placeholder when list is empty
    PagePlaceholder {
        shown: Notifications.list.length === 0
        icon: "notifications_active"
        description: Translation.tr("Nothing")
        shape: MaterialShape.Shape.Ghostish
        descriptionHorizontalAlignment: Text.AlignHCenter
    }

    ColumnLayout {
        id: statusRow
        spacing: 4
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        ButtonGroup {
            Layout.fillWidth: true

            NotificationStatusButton {
                Layout.fillWidth: true
                buttonIcon: "notifications_active"
                buttonText: "普通模式"
                toggled: !Notifications.silent
                onClicked: () => {
                    Notifications.silent = false;
                }
            }
            NotificationStatusButton {
                Layout.fillWidth: true
                buttonIcon: "notifications_paused"
                buttonText: "勿擾模式"
                toggled: Notifications.silent
                onClicked: () => {
                    Notifications.silent = true;
                }
            }
        }

        ButtonGroup {
            Layout.fillWidth: true

            NotificationStatusButton {
                enabled: false
                Layout.fillWidth: true
                buttonText: Translation.tr("%1 notifications").arg(Notifications.list.length)
            }
            NotificationStatusButton {
                Layout.fillWidth: false
                buttonIcon: "delete_sweep"
                buttonText: "清除全部"
                enabled: Notifications.list.length > 0
                onClicked: () => {
                    Notifications.discardAllNotifications()
                }
            }
        }
    }
}
