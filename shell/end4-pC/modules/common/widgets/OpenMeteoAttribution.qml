import QtQuick
import qs
import qs.modules.common

StyledText {
    id: root

    property bool interactive: !GlobalStates.screenLocked
    property bool compact: false

    text: root.compact
        ? "Weather: Open-Meteo.com"
        : "Weather data by Open-Meteo.com"
    font.pixelSize: Appearance.font.pixelSize.smallest
    font.underline: root.interactive && attributionMouse.containsMouse
    opacity: 0.72

    MouseArea {
        id: attributionMouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: Qt.openUrlExternally("https://open-meteo.com/")
    }
}
