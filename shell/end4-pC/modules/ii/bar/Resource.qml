import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property string iconName
    required property double percentage
    property string suffix: "%"
    property string label: ""
    property bool vertical: false
    property int warningThreshold: 100
    property bool shown: true
    clip: !vertical
    visible: vertical ? true : width > 0 && height > 0
    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : (resourceRowLayout.x < 0 ? 0 : resourceRowLayout.implicitWidth)
    implicitHeight: vertical ? resourceProgress.implicitHeight : Appearance.sizes.barHeight
    property bool warning: percentage * 100 >= warningThreshold

    Component {
        id: outlineStyle
        ClippedOutlineCircularProgress {
            lineWidth: Appearance.rounding.unsharpen
            value: root.percentage
            implicitSize: 24
            colPrimary: root.warning ? Appearance.colors.colError : Appearance.colors.colOnSecondaryContainer
            enableAnimation: false
            Item {
                anchors.centerIn: parent
                width: 24
                height: 24
                MaterialSymbol {
                    anchors.centerIn: parent
                    font.weight: Font.DemiBold
                    fill: 1
                    text: root.iconName
                    iconSize: Appearance.font.pixelSize.normal + 2
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }
        }
    }

    Component {
        id: filledStyle
        ClippedFilledCircularProgress {
            lineWidth: Appearance.rounding.unsharpen
            value: root.percentage
            implicitSize: 24
            colPrimary: root.warning ? Appearance.colors.colError : Appearance.colors.colOnSecondaryContainer
            accountForLightBleeding: !root.warning
            enableAnimation: false
            Item {
                anchors.centerIn: parent
                width: 24
                height: 24
                MaterialSymbol {
                    anchors.centerIn: parent
                    font.weight: vertical ? Font.Medium : Font.DemiBold
                    fill: 1
                    text: root.iconName
                    iconSize: Appearance.font.pixelSize.normal + 2
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
        }
    }

    // Vertical
    Loader {
        id: resourceProgress
        active: root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: Config.options.bar.resources.style === "filled" ? filledStyle : outlineStyle
    }

    // Horizontal
    RowLayout {
        id: resourceRowLayout
        visible: !root.vertical
        spacing: 2
        x: shown ? 0 : -resourceRowLayout.width
        anchors.verticalCenter: parent.verticalCenter

        MaterialSymbol {
            visible: root.label.length === 0
            Layout.alignment: Qt.AlignVCenter
            fill: 1
            text: root.iconName
            iconSize: Appearance.font.pixelSize.normal + 2
            color: root.warning ? Appearance.colors.colError : Appearance.colors.colOnLayer1
        }

        StyledText {
            visible: root.label.length > 0
            Layout.alignment: Qt.AlignVCenter
            text: root.label
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.small + 2
            font.weight: Font.DemiBold
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            visible: Config.options.bar.resources.showValue
            implicitWidth: visible ? fullPercentageTextMetrics.width : 0
            implicitHeight: percentageText.implicitHeight
            TextMetrics {
                id: fullPercentageTextMetrics
                text: "100" + root.suffix
                font.pixelSize: Appearance.font.pixelSize.small + 2
            }
            StyledText {
                id: percentageText
                anchors.centerIn: parent
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small + 2
                text: `${Math.round(root.percentage * 100).toString()}${root.suffix}`
            }
        }

        Behavior on x {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
    }

    Behavior on implicitWidth {
        enabled: false
    }
}
