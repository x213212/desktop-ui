import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

StyledPopup {
    id: root
    popupId: "mail"
    openOnHover: true
    preferredPopupWidth: 720

    ColumnLayout {
        width: Math.min(root.preferredPopupWidth, root.availableContentWidth)
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 2

            MaterialSymbol {
                text: "mail"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colPrimary
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: -3
                StyledText {
                    text: "近期 10 封信"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurface
                }
                StyledText {
                    text: (Gmail.account || "Gmail") + (Gmail.pushConnected ? " · 即時同步" : " · 重新連線中")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Gmail.pushConnected ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                }
            }
            RippleButton {
                implicitWidth: 30
                implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                onClicked: Gmail.refresh()
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: Gmail.loading ? "sync" : "refresh"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
            RippleButton {
                implicitWidth: 30
                implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                onClicked: root.close()
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        StyledText {
            visible: Gmail.loading && Gmail.messages.length === 0
            Layout.fillWidth: true
            Layout.margins: 12
            text: "正在同步 Gmail…"
            color: Appearance.colors.colOnSurfaceVariant
        }

        StyledText {
            visible: Gmail.error.length > 0
            Layout.fillWidth: true
            Layout.margins: 12
            wrapMode: Text.Wrap
            text: Gmail.error
            color: Appearance.colors.colError
        }

        Repeater {
            model: Gmail.messages
            delegate: Rectangle {
                id: messageRow
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: 58
                radius: Appearance.rounding.small
                color: rowMouse.containsMouse
                    ? Appearance.colors.colLayer2Hover
                    : modelData.unread
                        ? Appearance.colors.colPrimaryContainer
                        : Appearance.colors.colLayer2

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["xdg-open", "https://mail.google.com/"])
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: messageRow.modelData.unread
                            ? Appearance.colors.colPrimary
                            : "transparent"
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: -2
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: messageRow.modelData.sender
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: messageRow.modelData.unread ? Font.DemiBold : Font.Normal
                                color: Appearance.colors.colOnSurface
                            }
                            StyledText {
                                text: messageRow.modelData.date
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: messageRow.modelData.subject
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }
                }
            }
        }
    }
}
