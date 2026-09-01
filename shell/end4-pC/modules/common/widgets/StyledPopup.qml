import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Centrally coordinated top-bar popup. The lightweight controller remains
// attached to the bar so hover and pin state are always available. The heavy
// content is incubated asynchronously on demand and kept warm briefly after a
// close; the layer window itself only exists while the popup is visible.
LazyLoader {
    id: root

    property Item hoverTarget
    property string popupId: "popup"
    property bool managed: true
    property bool openOnHover: true
    property bool pinOnClick: true
    property bool closePinnedOnLeave: false
    property bool popupHovered: false
    property real preferredPopupWidth: 0
    property int cacheDuration: 15000
    // Unmanaged users (currently the tray overflow) drive this instead of
    // BarPopups. Managed popups continue to use isCurrent below.
    property bool requested: false
    default property Component contentComponent
    property real popupBackgroundMargin: 0
    // This object remains parented to the bar widget even while its temporary
    // PanelWindow exists, so its attached window is the owning bar window.
    readonly property var targetScreen: root.QsWindow.window?.screen
    readonly property real availableContentWidth: {
        const screenWidth = root.targetScreen?.width ?? 0
        if (screenWidth <= 0)
            return Math.max(160, root.preferredPopupWidth)
        const chrome = Appearance.sizes.elevationMargin * 2
            + root.popupBackgroundMargin + 20 + 16
        return Math.max(1, screenWidth - chrome)
    }

    readonly property bool targetHovered: hoverTarget
        ? !!(hoverTarget.containsMouse || hoverTarget.hovered)
        : false
    readonly property bool isCurrent: managed && BarPopups.current === root
    readonly property bool pinned: isCurrent && BarPopups.pinned
    readonly property var popupWindow: root.item
    property bool hoverInitialized: false
    property bool hoverArmed: false
    property bool destroying: false

    // Keep the Loader rather than the loaded subtree alive. While closed it is
    // parked under the bar item, invisible, so destroying the temporary
    // PanelWindow cannot destroy a still-hot cached item.
    property CachedLoader contentLoader: CachedLoader {
        requested: false
        cacheDuration: root.cacheDuration
        sourceComponent: root.contentComponent
        parent: root.hoverTarget
        visible: false
    }

    onTargetHoveredChanged: {
        if (!managed || !hoverInitialized) return
        // If the pointer was already over a bar item while the shell started,
        // do not treat that inherited position as an opening gesture. Leaving
        // the item arms normal hover behavior for subsequent entries.
        if (!hoverArmed) {
            if (!targetHovered) hoverArmed = true
            return
        }
        if (targetHovered) {
            GlobalStates.rememberBarTargetScreen(root.targetScreen)
            root.closeDelay.stop()
            if (openOnHover) BarPopups.showHover(root)
        } else {
            scheduleClose()
        }
    }

    // Only the current popup owns a layer surface. Keeping every popup window
    // alive creates one scene-graph/OpenGL context per widget and retains its
    // textures even while hidden.
    active: false

    function parkContent() {
        if (!root.hoverTarget) return
        root.contentLoader.anchors.centerIn = undefined
        root.contentLoader.visible = false
        // hoverTarget is a QQuickItem and safely owns the content while its
        // temporary PanelWindow is gone. This preserves it across reopenings.
        root.contentLoader.parent = root.hoverTarget
        root.popupHovered = false
    }

    function syncOpenState() {
        const shouldOpen = root.managed ? root.isCurrent : root.requested
        if (shouldOpen) {
            // Start asynchronous incubation before creating the surface. A
            // warm cache is attached immediately when the PanelWindow appears.
            root.contentLoader.requested = true
            root.active = true
        } else {
            // Reparent before deactivating LazyLoader: its PanelWindow and
            // popupBackground are destroyed synchronously.
            root.parkContent()
            root.active = false
            root.contentLoader.requested = false
            // A popup merely crossed during pointer travel must not finish a
            // stale incubation behind the newly selected popup. Completed
            // content still receives the normal bounded warm-cache TTL.
            if (!root.contentLoader.item)
                root.contentLoader.release()
        }
    }

    onIsCurrentChanged: {
        if (managed && !destroying) root.syncOpenState()
    }
    onRequestedChanged: {
        if (!managed && !destroying) root.syncOpenState()
    }

    Component.onCompleted: root.syncOpenState()
    Component.onDestruction: {
        root.destroying = true
        if (root.managed && BarPopups.current === root)
            BarPopups.close(root)
    }

    function close() {
        if (managed) BarPopups.close(root)
    }

    function togglePinned() {
        if (managed) BarPopups.toggle(root)
    }

    function scheduleClose() {
        if (!managed || targetHovered || popupHovered) return
        if (pinned && !closePinnedOnLeave) return
        root.closeDelay.restart()
    }

    property Connections clickConnection: Connections {
        target: root.managed ? root.hoverTarget : null

        function onClicked(mouse) {
            if (root.pinOnClick && (!mouse || mouse.button === Qt.LeftButton))
                root.togglePinned()
        }
    }

    property Timer closeDelay: Timer {
        interval: 260
        repeat: false
        onTriggered: {
            if (!root.targetHovered && !root.popupHovered
                    && (!root.pinned || root.closePinnedOnLeave))
                root.close()
        }
    }

    property Timer startupHoverGuard: Timer {
        interval: 250
        repeat: false
        running: true
        onTriggered: {
            root.hoverInitialized = true
            root.hoverArmed = !root.targetHovered
        }
    }

    readonly property bool barVertical: Config.options.bar.vertical
    readonly property string barEdge: {
        if (!barVertical) return Config.options.bar.bottom ? "bottom" : "top"
        return Config.options.bar.bottom ? "right" : "left"
    }
    readonly property real barThickness: barVertical
        ? Appearance.sizes.verticalBarWidth
        : Appearance.sizes.barHeight

    component: PanelWindow {
        id: popupWindow

        property Item innerContent: root.contentLoader
        screen: root.targetScreen

        visible: root.managed ? root.isCurrent : true
        color: "transparent"

        HoverHandler {
            onHoveredChanged: {
                root.popupHovered = hovered
                if (hovered) root.closeDelay.stop()
                else root.scheduleClose()
            }
        }

        anchors.left: root.barEdge !== "right"
        anchors.right: root.barEdge === "right"
        anchors.top: root.barEdge !== "bottom"
        anchors.bottom: root.barEdge === "bottom"

        implicitWidth: popupBackground.implicitWidth
            + Appearance.sizes.elevationMargin * 2
            + root.popupBackgroundMargin
        implicitHeight: popupBackground.implicitHeight
            + Appearance.sizes.elevationMargin * 2
            + root.popupBackgroundMargin

        readonly property real centerOffsetX: {
            const base = root.QsWindow?.mapFromItem(
                root.hoverTarget,
                (root.hoverTarget.width - popupBackground.implicitWidth) / 2,
                0
            ).x ?? 0
            const margin = Appearance.sizes.elevationMargin
            const desiredWindowLeft = base - margin
            const maxLeft = (popupWindow.screen?.width ?? popupWindow.implicitWidth)
                - popupWindow.implicitWidth
            return Math.max(0, Math.min(desiredWindowLeft, maxLeft))
        }
        readonly property real centerOffsetY: {
            const base = root.QsWindow?.mapFromItem(
                root.hoverTarget,
                0,
                (root.hoverTarget.height - popupBackground.implicitHeight) / 2
            ).y ?? 0
            const margin = Appearance.sizes.elevationMargin
            const desiredWindowTop = base - margin
            const maxTop = (popupWindow.screen?.height ?? popupWindow.implicitHeight)
                - popupWindow.implicitHeight
            return Math.max(0, Math.min(desiredWindowTop, maxTop))
        }

        mask: Region { item: popupBackground }
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        margins {
            left: {
                if (root.barEdge === "right") return 0
                if (root.barEdge === "left") return root.barThickness
                return popupWindow.centerOffsetX
            }
            top: {
                if (root.barEdge === "bottom") return 0
                if (root.barEdge === "top") return root.barThickness
                return popupWindow.centerOffsetY
            }
            right: root.barEdge === "right" ? root.barThickness : 0
            bottom: root.barEdge === "bottom" ? root.barThickness : 0
        }

        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        StyledRectangularShadow { target: popupBackground }

        Rectangle {
            id: popupBackground
            readonly property real margin: 8

            anchors {
                fill: parent
                leftMargin: Appearance.sizes.elevationMargin
                    + root.popupBackgroundMargin * (!popupWindow.anchors.left)
                rightMargin: Appearance.sizes.elevationMargin
                    + root.popupBackgroundMargin * (!popupWindow.anchors.right)
                topMargin: Appearance.sizes.elevationMargin
                    + root.popupBackgroundMargin * (!popupWindow.anchors.top)
                bottomMargin: Appearance.sizes.elevationMargin
                    + root.popupBackgroundMargin * (!popupWindow.anchors.bottom)
            }

            implicitWidth: Math.min(
                Math.max(
                    popupWindow.innerContent?.implicitWidth ?? 0,
                    root.preferredPopupWidth
                ),
                root.availableContentWidth
            ) + margin * 2
            implicitHeight: (popupWindow.innerContent?.implicitHeight ?? 0)
                + margin * 2

            color: Appearance.colors.colLayer1Base
            radius: Appearance.rounding.normal + 4
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            Component.onCompleted: {
                if (popupWindow.innerContent) {
                    popupWindow.innerContent.parent = popupBackground
                    popupWindow.innerContent.anchors.centerIn = popupBackground
                    popupWindow.innerContent.visible = true
                }
            }
        }
    }
}
