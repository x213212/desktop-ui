import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold
    property bool hasEvents: false
    property bool selected: false
    property string eventSummary: ""

    Layout.fillWidth: true
    Layout.fillHeight: false
    Layout.preferredWidth: 1
    implicitWidth: 36
    implicitHeight: 34

    toggled: isToday === 1 || selected
    buttonRadius: Appearance.rounding.small
    
    contentItem: Item {
        anchors.fill: parent

        StyledText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: button.hasEvents ? -2 : 0
            text: button.day
            horizontalAlignment: Text.AlignHCenter
            font.weight: button.bold ? Font.DemiBold : Font.Normal
            color: (button.isToday === 1 || button.selected) ? Appearance.m3colors.m3onPrimary :
                (button.isToday == 0) ? Appearance.colors.colOnLayer1 :
                Appearance.colors.colOutlineVariant

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }

        Rectangle {
            visible: button.hasEvents
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            width: 4
            height: 4
            radius: 2
            color: button.isToday === 1 || button.selected
                ? Appearance.m3colors.m3onPrimary
                : Appearance.colors.colPrimary
        }
    }

    StyledToolTip {
        text: button.eventSummary
        extraVisibleCondition: button.eventSummary.length > 0
    }
}
