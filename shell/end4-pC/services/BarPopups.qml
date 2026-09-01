pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell

// Single source of truth for information popups on the top bar.
Singleton {
    id: root

    property var current: null
    property bool pinned: false

    function show(popup, pin = false) {
        if (!popup) return
        root.current = popup
        root.pinned = pin
    }

    function showHover(popup) {
        if (!popup) return
        if (root.current !== popup) {
            root.current = popup
            root.pinned = false
        }
    }

    function toggle(popup) {
        if (root.current === popup && root.pinned) {
            root.close(popup)
            return
        }
        root.show(popup, true)
    }

    function close(popup = null) {
        if (popup && root.current !== popup) return
        root.current = null
        root.pinned = false
    }

}
