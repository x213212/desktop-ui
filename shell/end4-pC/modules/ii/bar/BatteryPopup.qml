import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

StyledPopup {
    id: root
    popupId: "battery"

    readonly property color healthColor: Battery.health <= 0
        ? Appearance.colors.colOnSurfaceVariant
        : Battery.health < 25
            ? Appearance.m3colors.m3error
            : Battery.health < 50
                ? "#FFB74D"
                : "#81C995"

    function formatTime(seconds) {
        var h = Math.floor(seconds / 3600)
        var m = Math.floor((seconds % 3600) / 60)
        if (h > 0) return `${h} 小時 ${m} 分`
        return `${m} 分鐘`
    }

    readonly property bool showTime: !(Battery.chargeState == 4
        || (Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty) <= 0
        || Battery.energyRate <= 0.01)

    ColumnLayout {
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 3
            spacing: 7

            MaterialShapeWrappedMaterialSymbol {
                shape: MaterialShape.Shape.ClamShell
                text: "battery_android_full"
                iconSize: Appearance.font.pixelSize.large
                implicitSize: 36
                color: Appearance.colors.colPrimaryContainer
                colSymbol: Appearance.colors.colPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -3

                StyledText {
                    text: Translation.tr("Battery")
                    font {
                        weight: Font.Medium
                        pixelSize: Appearance.font.pixelSize.normal
                    }
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                    opacity: 0.6
                    text: {
                        if (Battery.chargeState == 4 || Battery.percentage >= 0.999)
                            return "已充滿"
                        if (Battery.isCharging)
                            return "充電中" + (root.showTime ? " · 距離充滿 " + formatTime(Battery.timeToFull) : "")
                        return root.showTime ? "預估可用 " + formatTime(Battery.timeToEmpty) : "正在計算剩餘時間"
                    }
                }
            }

            Item { Layout.fillWidth: true }

            StyledText {
                Layout.rightMargin: 8
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.Bold
                color: Appearance.colors.colPrimary
                text: `${Math.round(Battery.percentage * 100)}`
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            ResourceCard {
                label: Translation.tr("Health")
                iconText: "heart_check"
                iconShape: MaterialShape.Shape.Clover4Leaf
                value: Battery.health / 100
                highValueIsWarning: false
                valueColor: root.healthColor
                sublabel: Battery.health > 0
                    ? `${Battery.health.toFixed(0)}%` + (Battery.chargeCycles > 0 ? ` · ${Battery.chargeCycles} 次循環` : "")
                    : Battery.chargeCycles > 0
                    ? `${Battery.chargeCycles} ${Translation.tr("cycles")}`
                    : Translation.tr("N/A")
                sublabelColor: root.healthColor
                cardWidth: 160
            }

            ResourceCard {
                label: Battery.isCharging
                    ? Translation.tr("Charging")
                    : Translation.tr("Draw")
                iconText: "bolt"
                iconShape: MaterialShape.Shape.Pentagon
                value: Math.min(Battery.energyRate / 60, 1.0)
                sublabel: Battery.chargeState == 4
                    ? Translation.tr("Full")
                    : `${Battery.energyRate.toFixed(2)}W`
                sublabelColor: Appearance.colors.colOnSurfaceVariant
                cardWidth: 160
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            StyledText {
                text: "電源模式"
                font.weight: Font.Medium
                color: Appearance.colors.colOnSurfaceVariant
            }

            ButtonGroup {
                Layout.fillWidth: true
                uniformCellSizes: true
                spacing: 5

                SelectionGroupButton {
                    buttonIcon: "energy_savings_leaf"
                    buttonText: "省電"
                    leftmost: true
                    toggled: PowerProfiles.profile === PowerProfile.PowerSaver
                    onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
                }
                SelectionGroupButton {
                    buttonIcon: "airwave"
                    buttonText: "平衡"
                    toggled: PowerProfiles.profile === PowerProfile.Balanced
                    onClicked: PowerProfiles.profile = PowerProfile.Balanced
                }
                SelectionGroupButton {
                    visible: PowerProfiles.hasPerformanceProfile
                    buttonIcon: "local_fire_department"
                    buttonText: "效能"
                    rightmost: true
                    toggled: PowerProfiles.profile === PowerProfile.Performance
                    onClicked: PowerProfiles.profile = PowerProfile.Performance
                }
            }
        }
    }
}
