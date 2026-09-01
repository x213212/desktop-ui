import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool vertical: false
    property bool borderless: Config.options.bar.borderless
    property bool isMaterial: Config.options.bar.cornerStyle === 3
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100
    readonly property string displayText: `${Math.round(root.percentage * 100)}%`
    // Clear battery state at a glance: normal >= 50%, warning 25-49%,
    // critical < 25%.  Charging remains green unless the reported value is
    // genuinely critical.
    readonly property color statusColor: root.percentage < 0.25
        ? Appearance.m3colors.m3error
        : root.percentage < 0.50
            ? "#FFB74D"
            : "#81C995"

    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : batteryRow.implicitWidth + 10
    implicitHeight: vertical ? batteryRow.implicitWidth + 8 : Appearance.sizes.barHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    RowLayout {
        id: batteryRow
        anchors.centerIn: parent
        rotation: root.vertical ? -90 : 0
        spacing: 3

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            fill: 1
            text: root.percentage >= 0.9 ? "battery_full"
                : root.percentage >= 0.5 ? "battery_5_bar"
                : root.percentage >= 0.2 ? "battery_3_bar" : "battery_alert"
            iconSize: Appearance.font.pixelSize.larger + 2
            color: root.statusColor
        }

        MaterialSymbol {
            visible: root.isPluggedIn
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: -4
            text: "bolt"
            fill: 1
            iconSize: Appearance.font.pixelSize.large + 2
            color: "#FFD54F"
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            font.pixelSize: Appearance.font.pixelSize.small + 2
            font.weight: Font.DemiBold
            text: root.displayText
            color: root.statusColor
        }
    }

    BatteryPopup {
        id: batteryPopup
        hoverTarget: root
    }
}
