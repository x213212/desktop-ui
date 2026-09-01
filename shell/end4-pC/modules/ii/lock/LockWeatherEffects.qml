pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Lock-only weather artwork. Weather owns the single data source; this item
// creates no poller or timer. Each scene is mutually exclusive and animations
// stop as soon as its scene is hidden.
Item {
    id: root

    readonly property int weatherCode: Number(Weather.data?.wCode ?? 119)
    readonly property int isDay: Number(Weather.data?.isDay ?? -1)
    readonly property bool weatherFresh: Weather.data?.fresh === true
    readonly property bool rainActive: weatherFresh && Weather.data?.rainingNow === true
    readonly property bool sunActive: weatherFresh && !rainActive
        && weatherCode === 113 && isDay === 1
    readonly property bool moonActive: weatherFresh && !rainActive
        && weatherCode === 113 && isDay === 0
    readonly property bool cloudActive: !rainActive && !sunActive && !moonActive

    // Keep density responsive without scaling particle count without a bound on
    // ultrawide/external displays. Both copies make each sheet loop seamlessly.
    readonly property int farRainCount: Math.max(30, Math.min(52, Math.round(width / 22)))
    readonly property int nearRainCount: Math.max(16, Math.min(30, Math.round(width / 38)))
    readonly property real sceneExtent: Math.max(1, Math.min(width, height))

    clip: true

    component RainPattern: Item {
        id: pattern

        required property int dropCount
        required property int seed
        required property real minDropWidth
        required property real maxDropWidth
        required property real minDropLength
        required property real maxDropLength
        required property color dropColor
        required property real dropOpacity

        Repeater {
            model: pattern.dropCount

            delegate: Rectangle {
                required property int index

                readonly property real widthFactor: ((index * 17 + pattern.seed * 7) % 11) / 10
                readonly property real lengthFactor: ((index * 29 + pattern.seed * 13) % 13) / 12

                x: ((index * 47 + pattern.seed * 31) % 101) / 100 * Math.max(1, pattern.width - width)
                y: ((index * 83 + pattern.seed * 19) % 103) / 102 * Math.max(1, pattern.height - height)
                width: pattern.minDropWidth + (pattern.maxDropWidth - pattern.minDropWidth) * widthFactor
                height: pattern.minDropLength + (pattern.maxDropLength - pattern.minDropLength) * lengthFactor
                radius: width / 2
                rotation: 10
                color: pattern.dropColor
                opacity: pattern.dropOpacity * (0.72 + ((index * 11 + pattern.seed) % 5) * 0.07)
            }
        }
    }

    // Two moving sheets replace per-drop animations. This gives fine rain over
    // the whole screen while only two properties are animated per frame.
    Item {
        id: rainFar
        anchors.fill: parent
        visible: root.rainActive

        Item {
            id: rainFarTrack
            width: parent.width
            height: parent.height * 2
            y: -rainFar.height

            RainPattern {
                width: rainFar.width
                height: rainFar.height
                dropCount: root.rainActive ? root.farRainCount : 0
                seed: 17
                minDropWidth: 0.7
                maxDropWidth: 1.15
                minDropLength: 7
                maxDropLength: 14
                dropColor: "#D9EEFF"
                dropOpacity: 0.18
            }

            RainPattern {
                y: rainFar.height
                width: rainFar.width
                height: rainFar.height
                dropCount: root.rainActive ? root.farRainCount : 0
                seed: 17
                minDropWidth: 0.7
                maxDropWidth: 1.15
                minDropLength: 7
                maxDropLength: 14
                dropColor: "#D9EEFF"
                dropOpacity: 0.18
            }

            YAnimator on y {
                running: root.rainActive && root.visible && rainFar.height > 0
                from: -rainFar.height
                to: 0
                duration: 2350
                loops: Animation.Infinite
                easing.type: Easing.Linear
            }
        }
    }

    Item {
        id: rainNear
        anchors.fill: parent
        visible: root.rainActive

        Item {
            id: rainNearTrack
            width: parent.width
            height: parent.height * 2
            y: -rainNear.height

            RainPattern {
                width: rainNear.width
                height: rainNear.height
                dropCount: root.rainActive ? root.nearRainCount : 0
                seed: 43
                minDropWidth: 1.05
                maxDropWidth: 1.65
                minDropLength: 11
                maxDropLength: 21
                dropColor: "#EAF6FF"
                dropOpacity: 0.28
            }

            RainPattern {
                y: rainNear.height
                width: rainNear.width
                height: rainNear.height
                dropCount: root.rainActive ? root.nearRainCount : 0
                seed: 43
                minDropWidth: 1.05
                maxDropWidth: 1.65
                minDropLength: 11
                maxDropLength: 21
                dropColor: "#EAF6FF"
                dropOpacity: 0.28
            }

            YAnimator on y {
                running: root.rainActive && root.visible && rainNear.height > 0
                from: -rainNear.height
                to: 0
                duration: 1480
                loops: Animation.Infinite
                easing.type: Easing.Linear
            }
        }
    }

    // A large, clipped sun creates the requested close-up. Only the ray glyph
    // rotates; the halo breathes slowly and uses no blur/shader pass.
    Item {
        id: sunScene
        readonly property real sceneSize: Math.max(320, Math.min(620, root.sceneExtent * 0.88))

        visible: root.sunActive
        width: sceneSize
        height: sceneSize
        x: root.width - width * 0.72
        y: -height * 0.26

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.92
            height: width
            radius: width / 2
            color: "#FFD36A"
            opacity: 0.065

            SequentialAnimation on scale {
                running: root.sunActive && root.visible
                loops: Animation.Infinite
                ScaleAnimator { from: 0.94; to: 1.04; duration: 3000; easing.type: Easing.InOutSine }
                ScaleAnimator { from: 1.04; to: 0.94; duration: 3000; easing.type: Easing.InOutSine }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.64
            height: width
            radius: width / 2
            color: "#FFE69B"
            opacity: 0.1
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "sunny"
            iconSize: sunScene.width * 0.82
            fill: 1
            color: "#FFD36A"
            opacity: 0.32

            RotationAnimator on rotation {
                running: root.sunActive && root.visible
                from: 0
                to: 360
                duration: 32000
                loops: Animation.Infinite
                easing.type: Easing.Linear
            }
        }
    }

    // Clear night stays distinct from cloudy weather.
    MaterialSymbol {
        id: moon
        visible: root.moonActive
        text: "clear_night"
        iconSize: Math.max(190, Math.min(300, root.sceneExtent * 0.42))
        fill: 1
        color: Appearance.colors.colPrimary
        opacity: 0.3
        x: root.width * 0.78 - width / 2
        y: root.height * 0.28 - height / 2

        SequentialAnimation on y {
            running: root.moonActive && root.visible
            loops: Animation.Infinite
            NumberAnimation { from: root.height * 0.28 - moon.height / 2 - 8; to: root.height * 0.28 - moon.height / 2 + 8; duration: 2800; easing.type: Easing.InOutSine }
            NumberAnimation { from: root.height * 0.28 - moon.height / 2 + 8; to: root.height * 0.28 - moon.height / 2 - 8; duration: 2800; easing.type: Easing.InOutSine }
        }
    }

    // Cloud cover stays in place and trembles gently instead of traversing the
    // whole display. That reads as a dark cloud while avoiding giant repaint
    // regions caused by full-width travel animations.
    Rectangle {
        anchors.fill: parent
        visible: root.cloudActive
        color: "#111A27"
        opacity: 0.075
    }

    Item {
        id: cloudScene
        readonly property real sceneSize: Math.max(330, Math.min(650, root.sceneExtent * 0.94))

        visible: root.cloudActive
        width: sceneSize
        height: sceneSize * 0.58
        x: root.width - width * 0.78
        y: root.height * 0.14

        Item {
            id: cloudMotion
            width: parent.width
            height: parent.height

            MaterialSymbol {
                text: "cloud"
                iconSize: cloudScene.width * 0.72
                fill: 1
                color: "#B7C2D2"
                opacity: 0.18
                anchors {
                    right: parent.right
                    top: parent.top
                }
            }

            MaterialSymbol {
                text: "cloud"
                iconSize: cloudScene.width * 0.56
                fill: 1
                color: "#D3DAE5"
                opacity: 0.27
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                }
            }

            SequentialAnimation on x {
                running: root.cloudActive && root.visible
                loops: Animation.Infinite
                NumberAnimation { from: -9; to: 9; duration: 1700; easing.type: Easing.InOutSine }
                NumberAnimation { from: 9; to: -9; duration: 1700; easing.type: Easing.InOutSine }
            }

            SequentialAnimation on y {
                running: root.cloudActive && root.visible
                loops: Animation.Infinite
                NumberAnimation { from: -3; to: 4; duration: 1250; easing.type: Easing.InOutSine }
                NumberAnimation { from: 4; to: -3; duration: 1250; easing.type: Easing.InOutSine }
            }

            SequentialAnimation on rotation {
                running: root.cloudActive && root.visible
                loops: Animation.Infinite
                NumberAnimation { from: -0.7; to: 0.7; duration: 2100; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.7; to: -0.7; duration: 2100; easing.type: Easing.InOutSine }
            }
        }
    }
}
