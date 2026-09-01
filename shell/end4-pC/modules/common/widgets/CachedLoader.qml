import QtQuick

// Frame-friendly lazy construction with a bounded post-close cache. Heavy UI
// stays hot while it is being reused, then releases its object tree so hidden
// models, images and animations cannot tax a long-running session.
Loader {
    id: root

    property bool requested: false
    property int cacheDuration: 15000
    property bool retained: false

    active: root.requested || root.retained
    asynchronous: true

    function release() {
        cacheTimer.stop()
        if (!root.requested)
            root.retained = false
    }

    onRequestedChanged: {
        if (root.requested) {
            root.retained = true
            cacheTimer.stop()
        } else if (root.retained) {
            // Do not finish incubating a cold tree after its requester has
            // already closed. Only a fully constructed item earns the TTL.
            if (!root.item) {
                cacheTimer.stop()
                root.retained = false
            } else if (root.cacheDuration > 0)
                cacheTimer.restart()
            else
                root.retained = false
        }
    }

    Component.onCompleted: {
        if (root.requested)
            root.retained = true
    }

    Timer {
        id: cacheTimer
        interval: Math.max(1, root.cacheDuration)
        repeat: false
        onTriggered: root.release()
    }
}
