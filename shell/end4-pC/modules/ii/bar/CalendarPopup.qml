pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

StyledPopup {
    id: root
    popupId: "calendar"
    openOnHover: true
    pinOnClick: false
    preferredPopupWidth: 620
    readonly property var upcomingEvents: (GoogleCalendar.events ?? []).filter(event => {
        const endMs = Number(event.endMs)
        return Number.isFinite(endMs) && endMs >= Date.now()
    })

    ColumnLayout {
        width: Math.min(root.preferredPopupWidth, root.availableContentWidth)
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 2

            MaterialSymbol {
                text: "calendar_month"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -3

                StyledText {
                    text: `未來 30 天 · ${root.upcomingEvents.length} 筆行程`
                    textFormat: Text.PlainText
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurface
                }

                StyledText {
                    text: GoogleCalendar.loading
                        ? "Google 日曆同步中…"
                        : (GoogleCalendar.account || "Google Calendar")
                    textFormat: Text.PlainText
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: GoogleCalendar.error
                        ? Appearance.colors.colError
                        : Appearance.colors.colOnSurfaceVariant
                }
            }

            RippleButton {
                implicitWidth: 30
                implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                enabled: !GoogleCalendar.loading
                onClicked: GoogleCalendar.refresh(true)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: GoogleCalendar.loading ? "sync" : "refresh"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        StyledText {
            visible: GoogleCalendar.error.length > 0
            Layout.fillWidth: true
            Layout.margins: 10
            wrapMode: Text.Wrap
            text: GoogleCalendar.error
            textFormat: Text.PlainText
            color: Appearance.colors.colError
        }

        StyledText {
            visible: !GoogleCalendar.loading
                && GoogleCalendar.error.length === 0
                && root.upcomingEvents.length === 0
            Layout.fillWidth: true
            Layout.margins: 14
            horizontalAlignment: Text.AlignHCenter
            text: "未來 30 天沒有行程"
            color: Appearance.colors.colOnSurfaceVariant
        }

        Repeater {
            model: root.upcomingEvents.slice(0, 10)

            delegate: Rectangle {
                id: eventRow
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 50
                radius: Appearance.rounding.small
                color: rowMouse.containsMouse
                    ? Appearance.colors.colLayer2Hover
                    : Appearance.colors.colLayer2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    StyledText {
                        Layout.preferredWidth: 82
                        text: eventRow.modelData.timeLabel || "全天"
                        textFormat: Text.PlainText
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: -2

                        StyledText {
                            Layout.fillWidth: true
                            text: eventRow.modelData.title || "（無標題）"
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurface
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: eventRow.modelData.location || ""
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }

                    MaterialSymbol {
                        visible: eventRow.modelData.htmlLink?.length > 0
                        text: "open_in_new"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: eventRow.modelData.htmlLink?.length > 0
                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (eventRow.modelData.htmlLink?.length > 0)
                            Quickshell.execDetached(["xdg-open", eventRow.modelData.htmlLink])
                    }
                }
            }
        }
    }
}
