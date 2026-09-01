pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Options toolbar
Toolbar {
    id: root

    // Use a synchronizer on these
    property var action
    property var selectionMode
    // Signals
    signal dismiss()

    ToolbarTabBar {
        id: tabBar
        property bool selectionSyncReady: false
        tabButtonList: [
            {"icon": "activity_zone", "name": Translation.tr("Rect")},
            {"icon": "gesture", "name": Translation.tr("Circle")}
        ]

        // TabBar owns currentIndex internally, so binding that property back
        // to selectionMode while also updating selectionMode from its change
        // handler forms a two-way binding loop during delegate creation.
        // Synchronize external mode changes imperatively instead.
        function syncFromSelectionMode() {
            if (root.selectionMode !== RegionSelection.SelectionMode.RectCorners
                    && root.selectionMode !== RegionSelection.SelectionMode.Circle)
                return;

            const targetIndex = root.selectionMode === RegionSelection.SelectionMode.RectCorners ? 0 : 1;
            if (tabBar.currentIndex !== targetIndex)
                tabBar.setCurrentIndex(targetIndex);
        }

        Component.onCompleted: {
            tabBar.syncFromSelectionMode();
            tabBar.selectionSyncReady = true;
        }

        Connections {
            target: root
            function onSelectionModeChanged() {
                tabBar.syncFromSelectionMode();
            }
        }

        onCurrentIndexChanged: {
            // TabBar briefly uses -1 and may choose its first item while its
            // delegates are being created.  Those are setup transitions, not
            // user input, and must not overwrite the requested mode.
            if (!tabBar.selectionSyncReady || currentIndex < 0 || currentIndex > 1)
                return;

            const newMode = currentIndex === 0 ? RegionSelection.SelectionMode.RectCorners : RegionSelection.SelectionMode.Circle;
            if (root.selectionMode !== newMode)
                root.selectionMode = newMode;
        }
    }
}
