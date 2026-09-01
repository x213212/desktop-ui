pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "calendar_layout.js" as CalendarLayout
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int monthShift: 0
    property string selectedDateKey: ""
    property bool wheelMonthReady: true
    readonly property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    readonly property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)
    readonly property var upcomingEvents: (GoogleCalendar.events ?? []).filter(event => {
        const endMs = Number(event.endMs)
        return Number.isFinite(endMs) && endMs >= Date.now()
    }).slice(0, 2)
    readonly property int maximumMonthShift: {
        if (!GoogleCalendar.rangeEnd) return 0
        const end = new Date(`${GoogleCalendar.rangeEnd}T12:00:00`)
        const now = new Date()
        return Math.max(0, (end.getFullYear() - now.getFullYear()) * 12
            + end.getMonth() - now.getMonth())
    }
    readonly property var displayedEvents: {
        if (!root.selectedDateKey)
            return root.upcomingEvents
        return (GoogleCalendar.events ?? []).filter(event =>
            event.dateKey === root.selectedDateKey).slice(0, 2)
    }

    implicitHeight: 390
    implicitWidth: 330

    function hasEvent(dateKey) {
        return GoogleCalendar.eventsForDate(dateKey).length > 0
    }

    function eventsForDate(dateKey) {
        return GoogleCalendar.eventsForDate(dateKey)
    }

    function dateInQueryRange(dateKey) {
        return GoogleCalendar.rangeStart.length > 0
            && GoogleCalendar.rangeEnd.length > 0
            && dateKey >= GoogleCalendar.rangeStart
            && dateKey <= GoogleCalendar.rangeEnd
    }

    function eventSummary(dateKey) {
        const events = root.eventsForDate(dateKey)
        const lines = events.slice(0, 5).map(event => {
            const title = String(event.title || "（無標題）")
            const shortTitle = title.length > 48 ? `${title.slice(0, 47)}…` : title
            return `${event.timeLabel || "全天"}　${shortTitle}`
        })
        if (events.length > 5)
            lines.push(`另有 ${events.length - 5} 筆行程`)
        return lines.join("\n")
    }

    function selectDate(dateKey) {
        if (!root.dateInQueryRange(dateKey)) return
        root.selectedDateKey = root.selectedDateKey === dateKey ? "" : dateKey
    }

    function changeMonth(delta) {
        root.monthShift = Math.max(0, Math.min(
            root.maximumMonthShift, root.monthShift + delta))
    }

    onMonthShiftChanged: root.selectedDateKey = ""

    Keys.onPressed: event => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)
            && event.modifiers === Qt.NoModifier) {
            root.changeMonth(event.key === Qt.Key_PageDown ? 1 : -1)
            event.accepted = true
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (event.angleDelta.y === 0 || !root.wheelMonthReady) return
            root.wheelMonthReady = false
            root.changeMonth(event.angleDelta.y > 0 ? -1 : 1)
            wheelMonthReset.restart()
        }
    }

    Timer {
        id: wheelMonthReset
        interval: 420
        repeat: false
        onTriggered: root.wheelMonthReady = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            CalendarHeaderButton {
                clip: true
                buttonText: `${root.monthShift !== 0 ? "• " : ""}${root.viewingDate.getFullYear()} 年 ${root.viewingDate.getMonth() + 1} 月`
                tooltipText: root.monthShift === 0 ? "" : "回到本月"
                downAction: () => {
                    root.monthShift = 0
                    root.selectedDateKey = ""
                }
            }

            Item { Layout.fillWidth: true }

            CalendarHeaderButton {
                forceCircle: true
                enabled: root.monthShift > 0
                downAction: () => { root.changeMonth(-1) }
                contentItem: MaterialSymbol {
                    text: "chevron_left"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }

            CalendarHeaderButton {
                forceCircle: true
                enabled: root.monthShift < root.maximumMonthShift
                downAction: () => { root.changeMonth(1) }
                contentItem: MaterialSymbol {
                    text: "chevron_right"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 3

            Repeater {
                model: CalendarLayout.weekDays
                delegate: CalendarDayButton {
                    required property var modelData
                    day: modelData.day
                    isToday: modelData.today
                    bold: true
                    enabled: false
                    implicitHeight: 28
                }
            }
        }

        Repeater {
            model: 6
            delegate: RowLayout {
                id: weekRow
                required property int index
                readonly property int weekIndex: index
                Layout.fillWidth: true
                Layout.fillHeight: false
                spacing: 3

                Repeater {
                    model: 7
                    delegate: CalendarDayButton {
                        required property int index
                        readonly property var cell: root.calendarLayout[weekRow.weekIndex][index]
                        day: cell.day.toString()
                        isToday: cell.today
                        hasEvents: root.hasEvent(cell.dateKey)
                        selected: root.selectedDateKey === cell.dateKey
                        eventSummary: root.eventSummary(cell.dateKey)
                        enabled: root.dateInQueryRange(cell.dateKey)
                        downAction: () => { root.selectDate(cell.dateKey) }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 3
            implicitHeight: 1
            color: Appearance.colors.colOutlineVariant
            opacity: 0.45
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 7

            MaterialSymbol {
                text: GoogleCalendar.error ? "event_busy" : "event_available"
                iconSize: Appearance.font.pixelSize.large
                color: GoogleCalendar.error
                    ? Appearance.colors.colError
                    : Appearance.colors.colPrimary
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    if (GoogleCalendar.loading) return "Google 日曆同步中…"
                    if (GoogleCalendar.error) return `Google 日曆 · ${GoogleCalendar.error}`
                    if (root.selectedDateKey)
                        return `Google 日曆 · ${root.selectedDateKey} · ${root.eventsForDate(root.selectedDateKey).length} 筆`
                    return GoogleCalendar.account ? `Google 日曆 · ${GoogleCalendar.account}` : "Google 日曆"
                }
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: GoogleCalendar.error
                    ? Appearance.colors.colError
                    : Appearance.colors.colOnLayer1
            }

            CalendarHeaderButton {
                forceCircle: true
                enabled: !GoogleCalendar.loading
                tooltipText: "立即同步"
                downAction: () => { GoogleCalendar.refresh() }
                contentItem: MaterialSymbol {
                    text: "sync"
                    iconSize: Appearance.font.pixelSize.large
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 3

            Repeater {
                model: root.displayedEvents
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Appearance.rounding.small
                    color: eventMouse.containsMouse
                        ? Appearance.colors.colLayer2Hover
                        : Appearance.colors.colLayer2

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        StyledText {
                            Layout.preferredWidth: 78
                            text: modelData.timeLabel || "全天"
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colPrimary
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.title || "（無標題）"
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                        }
                    }

                    MouseArea {
                        id: eventMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: modelData.htmlLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (modelData.htmlLink)
                                Quickshell.execDetached(["xdg-open", modelData.htmlLink])
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !GoogleCalendar.loading && !GoogleCalendar.error && root.displayedEvents.length === 0
                text: root.selectedDateKey ? "這一天沒有行程" : "未來 30 天沒有行程"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                opacity: 0.65
            }
        }
    }
}
