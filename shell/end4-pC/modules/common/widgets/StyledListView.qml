import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls

/**
 * A ListView with animations.
 */
ListView {
    id: root
    spacing: 5
    property real removeOvershoot: 20 // Account for gaps and bouncy animations
    property int dragIndex: -1
    property real dragDistance: 0
    property bool popin: true
    property bool animateAppearance: true
    property bool animateMovement: false
    property bool forceFastWheel: false
    property bool animateWheelScroll: true
    // Accumulated scroll destination so wheel deltas stack while animating
    property real scrollTargetY: 0

    property real touchpadScrollFactor: Config?.options.interactions.scrolling.touchpadScrollFactor ?? 100
    property real mouseScrollFactor: Config?.options.interactions.scrolling.mouseScrollFactor ?? 50
    property real mouseScrollDeltaThreshold: Config?.options.interactions.scrolling.mouseScrollDeltaThreshold ?? 120

    function resetDrag() {
        root.dragIndex = -1
        root.dragDistance = 0
    }

    maximumFlickVelocity: 3500
    boundsBehavior: Flickable.DragOverBounds
    ScrollBar.vertical: StyledScrollBar {}

    MouseArea {
        visible: root.forceFastWheel || Config?.options.interactions.scrolling.fasterTouchpadScroll
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function(wheelEvent) {
            const delta = wheelEvent.angleDelta.y / root.mouseScrollDeltaThreshold;
            // The angleDelta.y of a touchpad is usually small and continuous,
            // while that of a mouse wheel is typically in multiples of ±120.
            var scrollFactor = Math.abs(wheelEvent.angleDelta.y) >= root.mouseScrollDeltaThreshold ? root.mouseScrollFactor : root.touchpadScrollFactor;

            // ListView.originY can move after delegate insertion/removal.  A
            // hard-coded zero lets content escape the real viewport bounds.
            const minY = root.originY;
            const maxY = Math.max(minY, minY + root.contentHeight - root.height);
            const base = scrollAnim.running ? root.scrollTargetY : root.contentY;
            var targetY = Math.max(minY, Math.min(base - delta * scrollFactor, maxY));

            root.scrollTargetY = targetY;
            root.contentY = targetY;
            wheelEvent.accepted = true;
        }
    }

    Behavior on contentY {
        enabled: root.animateWheelScroll
        NumberAnimation {
            id: scrollAnim
            alwaysRunToEnd: true
            duration: Appearance.animation.scroll.duration
            easing.type: Appearance.animation.scroll.type
            easing.bezierCurve: Appearance.animation.scroll.bezierCurve
        }
    }

    // Keep target synced when not animating (e.g., drag/flick or programmatic changes)
    onContentYChanged: {
        if (!scrollAnim.running) {
            root.scrollTargetY = root.contentY;
        }
    }

    function clampToViewport() {
        if (root.boundsBehavior !== Flickable.StopAtBounds) return;
        const minY = root.originY;
        const maxY = Math.max(minY, minY + root.contentHeight - root.height);
        const boundedY = Math.max(minY, Math.min(root.contentY, maxY));
        if (Math.abs(root.contentY - boundedY) > 0.5) {
            root.scrollTargetY = boundedY;
            root.contentY = boundedY;
        }
    }

    onContentHeightChanged: Qt.callLater(root.clampToViewport)
    onHeightChanged: Qt.callLater(root.clampToViewport)

    add: Transition {
        animations: animateAppearance ? [
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                properties: popin ? "opacity,scale" : "opacity",
                from: 0,
                to: 1,
            }),
        ] : []
    }

    addDisplaced: Transition {
        animations: animateAppearance ? [
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                property: "y",
            }),
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                properties: popin ? "opacity,scale" : "opacity",
                to: 1,
            }),
        ] : []
    }
    
    displaced: Transition {
        animations: root.animateMovement ? [
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                property: "y",
            }),
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                properties: "opacity,scale",
                to: 1,
            }),
        ] : []
    }

    move: Transition {
        animations: root.animateMovement ? [
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                property: "y",
            }),
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                properties: "opacity,scale",
                to: 1,
            }),
        ] : []
    }
    moveDisplaced: Transition {
        animations: root.animateMovement ? [
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                property: "y",
            }),
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                properties: "opacity,scale",
                to: 1,
            }),
        ] : []
    }

    remove: Transition {
        animations: animateAppearance ? [
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                property: "x",
                to: root.width + root.removeOvershoot,
            }),
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                property: "opacity",
                to: 0,
            })
        ] : []
    }

    // This is movement when something is removed, not removing animation!
    removeDisplaced: Transition { 
        animations: animateAppearance ? [
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                property: "y",
            }),
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                properties: "opacity,scale",
                to: 1,
            }),
        ] : []
    }
}
