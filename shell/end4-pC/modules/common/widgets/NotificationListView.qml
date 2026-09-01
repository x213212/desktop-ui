pragma ComponentBehavior: Bound

import qs.modules.common.widgets
import qs.services
import QtQuick

StyledListView { // Scrollable window
    id: root
    property bool popup: false

    // Notification lists are often long.  Do not animate every scrollbar or
    // wheel delta: that queues motion behind the pointer and feels sluggish.
    forceFastWheel: !popup
    animateWheelScroll: false
    // Notifications need a predictable, bounded viewport.  The old touchpad
    // multiplier could traverse the entire history in one gesture.
    mouseScrollFactor: 120
    touchpadScrollFactor: 180
    maximumFlickVelocity: 3500
    flickDeceleration: 5000
    boundsBehavior: Flickable.StopAtBounds

    spacing: 3

    model: root.popup ? Notifications.popupAppNameModel : Notifications.appNameModel
    delegate: NotificationGroup {
        required property int index
        required property var modelData
        popup: root.popup
        width: ListView.view.width // https://doc.qt.io/qt-6/qml-qtquick-listview.html
        notificationGroup: popup ? 
            Notifications.popupGroupsByAppName[modelData] :
            Notifications.groupsByAppName[modelData]
    }
}
