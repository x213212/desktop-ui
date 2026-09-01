pragma Singleton

import qs.modules.common
import Quickshell

Singleton {
    id: root
    // Ubuntu 24.04 ships ydotool 0.1.8.  Its `key` command accepts
    // human-readable chords (for example ctrl+v), not the newer raw
    // keycode:state protocol this OSK was written for.  Passing `0:0` through
    // `248:0` makes that version literally type 0, 1, 2, ... at login.
    // Keep the service as a harmless compatibility stub until the OSK is
    // migrated to a supported virtual-keyboard API.
    readonly property bool available: false
    property int shiftMode: 0 // 0: off, 1: on, 2: lock
    property list<int> shiftKeys: [42, 54] // Keycodes for Shift keys (left and right)
    property list<int> altKeys: [56, 100] // Keycodes for Alt keys (left and right) 
    property list<int> ctrlKeys: [29, 97] // Keycodes for Ctrl keys (left and right)

    function releaseAllKeys() {
        root.shiftMode = 0;
    }

    function releaseShiftKeys() {
        root.shiftMode = 0;
    }

    function press(keycode) {
        // Intentionally disabled: raw keycodes are unsafe with ydotool 0.1.8.
    }

    function release(keycode) {
        // Intentionally disabled: raw keycodes are unsafe with ydotool 0.1.8.
    }
}
