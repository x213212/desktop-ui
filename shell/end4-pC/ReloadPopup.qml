// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 desktop-ui contributors
// Original project implementation built against the public Quickshell QML API.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    // Kept public for compatibility with the original shell integration.
    property bool failed: false
    property string errorString: ""

    QtObject {
        id: state

        readonly property int successTimeout: 1000
        readonly property int failureTimeout: 10000
        property int serial: 0

        function publish(isFailure, details) {
            root.failed = isFailure
            root.errorString = isFailure ? String(details || "") : ""
            serial += 1

            if (!popupLoader.active) {
                // Construct this uncommon UI between frames.
                popupLoader.loading = true
            }
        }

        function dismiss(presentedSerial) {
            if (presentedSerial === serial)
                popupLoader.active = false
        }
    }

    Connections {
        target: Quickshell

        function onReloadCompleted() {
            state.publish(false, "")
        }

        function onReloadFailed(error) {
            state.publish(true, error)
        }
    }

    LazyLoader {
        id: popupLoader

        PanelWindow {
            id: popup

            property bool ready: false
            property int presentedSerial: -1

            readonly property int requestedSerial: state.serial
            readonly property int outerPadding: 10
            readonly property int horizontalInset: 16
            readonly property int maximumCardWidth: {
                const outputWidth = screen ? screen.width : 752
                return Math.max(240, Math.min(720, outputWidth - 32))
            }
            readonly property int maximumTextWidth: Math.max(208, maximumCardWidth
                                                             - horizontalInset * 2)
            readonly property string visibleError: {
                const limit = 16384
                if (root.errorString.length <= limit)
                    return root.errorString
                return root.errorString.slice(0, limit) + "\n…"
            }

            function present(serial) {
                presentedSerial = serial
                lifetime.remainingFraction = 1
                expiry.restart()
            }

            onRequestedSerialChanged: {
                if (ready)
                    present(requestedSerial)
            }

            anchors.top: true
            exclusiveZone: 0
            focusable: false
            color: "transparent"
            implicitWidth: card.width + outerPadding * 2
            implicitHeight: card.height + outerPadding * 2

            WlrLayershell.namespace: "desktop-ui:reload-status"

            QtObject {
                id: lifetime

                property real remainingFraction: 1
            }

            Rectangle {
                id: shadowPlate

                x: card.x
                y: card.y + 3
                width: card.width
                height: card.height
                radius: card.radius
                color: "#33000000"
            }

            Rectangle {
                id: card

                anchors.centerIn: parent
                width: Math.min(popup.maximumCardWidth, Math.max(280, statusLayout.implicitWidth
                                                                 + popup.horizontalInset * 2))
                height: statusLayout.implicitHeight + 42
                radius: 12
                color: root.failed ? "#ffe99195" : "#ffd1e8d5"

                ColumnLayout {
                    id: statusLayout

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: 13
                        leftMargin: popup.horizontalInset
                        rightMargin: popup.horizontalInset
                    }
                    spacing: 8

                    Text {
                        Layout.maximumWidth: popup.maximumTextWidth
                        Layout.alignment: Qt.AlignHCenter
                        text: root.failed ? "Quickshell: Reload failed" : "Quickshell reloaded"
                        textFormat: Text.PlainText
                        renderType: Text.QtRendering
                        color: root.failed ? "#ff93000a" : "#ff0c1f13"
                        font.family: "Google Sans Flex"
                        font.pointSize: 14
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.maximumWidth: popup.maximumTextWidth
                        visible: root.failed && popup.visibleError.length > 0
                        text: popup.visibleError
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 14
                        elide: Text.ElideRight
                        renderType: Text.QtRendering
                        color: "#ff93000a"
                        font.family: "JetBrains Mono NF"
                        font.pointSize: 11
                    }
                }

                Rectangle {
                    id: progressTrack

                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        margins: 10
                    }
                    height: 5
                    radius: height / 2
                    color: root.failed ? "#30af1b25" : "#4027643e"

                    Rectangle {
                        width: parent.width * lifetime.remainingFraction
                        height: parent.height
                        radius: parent.radius
                        color: root.failed ? "#ff93000a" : "#ff0c1f13"
                    }
                }

                MouseArea {
                    id: interactionArea

                    anchors.fill: parent
                    hoverEnabled: true
                    onPressed: state.dismiss(popup.presentedSerial)
                }
            }

            NumberAnimation {
                id: expiry

                target: lifetime
                property: "remainingFraction"
                from: 1
                to: 0
                duration: root.failed ? state.failureTimeout : state.successTimeout
                paused: interactionArea.containsMouse
                onFinished: state.dismiss(popup.presentedSerial)
            }

            Component.onCompleted: {
                ready = true
                present(requestedSerial)
            }
        }
    }
}
