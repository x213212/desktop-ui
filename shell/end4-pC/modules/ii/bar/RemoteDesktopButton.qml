import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.widgets

MouseArea {
    id: root

    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: vertical ? 38 : 54
    implicitHeight: vertical ? 36 : Appearance.sizes.barHeight
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: Quickshell.execDetached([
        Quickshell.env("HOME") + "/.local/bin/open-remmina"
    ])

    Rectangle {
        anchors.centerIn: parent
        width: root.vertical ? 34 : 50
        height: 30
        radius: Appearance.rounding.full
        color: root.containsMouse
            ? Appearance.colors.colPrimaryContainer
            : Appearance.colors.colLayer1

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 3

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: "desktop_windows"
                iconSize: Appearance.font.pixelSize.larger + 2
                color: Appearance.colors.colPrimary
            }

            StyledText {
                visible: !root.vertical
                anchors.verticalCenter: parent.verticalCenter
                text: "RDP"
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
            }
        }
    }

    PopupToolTip {
        text: "遠端桌面"
        extraVisibleCondition: root.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!Config.options.bar.bottom && !root.vertical)
            ? Edges.Bottom
            : Edges.Top
    }
}
