import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Gmail starts syncing when the shell starts. This button opens the cached
// summary and requests an additional immediate refresh.
MouseArea {
    id: root

    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: root.vertical ? 32 : 34
    implicitHeight: root.vertical ? 34 : Appearance.sizes.barHeight
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            Quickshell.execDetached(["gnome-online-accounts-gtk"])
        } else if (!Gmail.initialized && !Gmail.loading) {
            // Normally the popup is cache-first and refreshes in background.
            // Only recover manually if startup synchronization never began.
            Gmail.refresh()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 30
        height: 30
        radius: Appearance.rounding.full
        color: root.containsMouse
            ? Appearance.colors.colLayer1Hover
            : "transparent"

        Behavior on color {
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "mail"
            iconSize: Appearance.font.pixelSize.larger + 2
            color: root.isMaterial
                ? Appearance.colors.colPrimary
                : Appearance.colors.colOnLayer1
        }
    }

    Rectangle {
        visible: Gmail.unreadCount > 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 2
        anchors.topMargin: 7
        width: 8
        height: 8
        radius: 4
        color: Appearance.m3colors.m3error
    }

    MailPopup {
        id: mailPopup
        hoverTarget: root
    }
}
