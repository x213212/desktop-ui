import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

MouseArea {
    id: root

    property var targetScreen: root.QsWindow.window?.screen
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: root.vertical ? 32 : 34
    implicitHeight: root.vertical ? 34 : Appearance.sizes.barHeight
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onPressed: mouse => {
        if (mouse.button !== Qt.LeftButton)
            return
        Persistent.states.sidebar.bottomGroup.tab = 0
        Persistent.states.sidebar.bottomGroup.collapsed = false
        GlobalStates.openRightSidebarForScreen(root.targetScreen)
        calendarPopup.close()
    }

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            Quickshell.execDetached(["xdg-open", "https://calendar.google.com/calendar/u/0/r"])
    }

    Rectangle {
        anchors.centerIn: parent
        width: 30
        height: 30
        radius: Appearance.rounding.full
        color: root.containsMouse ? Appearance.colors.colLayer1Hover : "transparent"

        Behavior on color {
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "calendar_month"
            iconSize: Appearance.font.pixelSize.larger + 2
            color: root.isMaterial
                ? Appearance.colors.colPrimary
                : Appearance.colors.colOnLayer1
        }
    }

    Rectangle {
        visible: GoogleCalendar.events.some(event => {
            const endMs = Number(event.endMs)
            return Number.isFinite(endMs) && endMs >= Date.now()
        })
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 0
        anchors.topMargin: 4
        implicitWidth: Math.max(13, eventCount.implicitWidth + 5)
        implicitHeight: 13
        radius: 7
        color: Appearance.colors.colPrimary

        StyledText {
            id: eventCount
            anchors.centerIn: parent
            text: Math.min(99, GoogleCalendar.events.filter(event => {
                const endMs = Number(event.endMs)
                return Number.isFinite(endMs) && endMs >= Date.now()
            }).length)
            font.pixelSize: Appearance.font.pixelSize.smallest - 2
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnPrimary
        }
    }

    CalendarPopup {
        id: calendarPopup
        hoverTarget: root
    }
}
