import QtQuick

QtObject {
    // Textual info
    required property string name
    property string statusText
    property string tooltipText: ""
    property string icon: "close"

    // State
    property bool hasStatusText: true
    property bool available: true
    property bool toggled: false

    // Interactions
    required property var mainAction
    // Safe, reversible state toggles may run on pointer-down. Actions that
    // launch selectors, cycle modes, reload, or otherwise require release keep
    // the default false value.
    property bool activateOnPress: false
    property bool hasMenu: false
    property var altAction: null

    // Allow stuff like Processes to be declared freely
    default property list<QtObject> data
}
