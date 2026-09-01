import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property bool barOpen: true
    property bool crosshairOpen: false
    property bool sidebarLeftOpen: false
    property bool sidebarRightOpen: false
    // Screen ownership for UI opened from a per-monitor bar. Store the stable
    // output name instead of a ShellScreen object so hotplug can re-resolve it.
    property string barTargetScreenName: ""
    signal openWifiDialogRequested()
    signal openBluetoothDialogRequested()
    property bool mediaControlsOpen: false
    property bool osdBrightnessOpen: false
    property bool settingsOpen: false
    property bool osdVolumeOpen: false
    property bool oskOpen: false
    property bool overlayOpen: false
    property bool overviewOpen: false
    property bool regionSelectorOpen: false
    property bool searchOpen: false
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool screenTranslatorOpen: false
    property bool sessionOpen: false
    property bool superDown: false
    property bool superReleaseMightTrigger: true
    property bool wallpaperSelectorOpen: false
    property bool workspaceShowNumbers: false
    property string settingsPage: ""
    property Item currentPageInstance: null
    property list<real> visualizerPoints: []
    property bool desktopWidgetKeyboardFocus: false
    property bool desktopMenuOpen: false
    property var desktopMenuScreen: null
    property real desktopMenuX: 0
    property real desktopMenuY: 0
    property string wallpaperSelectorTarget: "wallpaper"
    property bool dropShelfOpen: false
    property real dropShelfX: 0
    property real dropShelfY: 0

    function rememberBarTargetScreen(screen) {
        const name = screen?.name ?? ""
        if (name)
            root.barTargetScreenName = name
    }

    function openRightSidebarForScreen(screen) {
        root.rememberBarTargetScreen(screen)
        root.sidebarRightOpen = true
    }

    function toggleRightSidebarForScreen(screen) {
        root.rememberBarTargetScreen(screen)
        root.sidebarRightOpen = !root.sidebarRightOpen
    }

    // Freeze workspace presentation while the session restorer performs its
    // compositor transaction. Commit the final workspace exactly once before
    // normal user-driven animations resume.
    // Idle by default.  A real restore explicitly acquires this presentation
    // gate through the sessionRestore.start IPC.  Starting frozen made a
    // missed/early IPC permanently pin every bar to its construction-time
    // workspace group after login.
    property bool sessionRestoreActive: false
    property bool sessionRestoreOwnerActive: false
    property bool hotplugPresentationActive: false
    // Physical topology feedback is independent from the compositor routing
    // fence. Quickshell sees monitoradded/removed directly, so the bar can
    // acknowledge the cable in the same event turn while the router keeps its
    // short settle window. The event details also let a newly-created HDMI bar
    // preview its stable workspace group without guessing during removal.
    property string hotplugVisualKind: ""
    property string hotplugVisualConnector: ""
    readonly property bool hotplugVisualActive: root.hotplugVisualKind !== ""
        && (hotplugVisualMinimumTimer.running || root.hotplugPresentationActive)
    property int presentationGeneration: 0
    signal sessionRestoreCommit()

    function hotplugConnectorFromEvent(eventName, eventData) {
        const parts = String(eventData ?? "").split(",")
        // v2 is monitor-id,name,description; legacy is just name.
        const value = eventName.endsWith("v2") && parts.length > 1
            ? parts[1] : parts[0]
        return String(value ?? "").trim()
    }

    function noteHotplugTopologyEvent(eventName, eventData) {
        const added = eventName === "monitoradded" || eventName === "monitoraddedv2"
        const removed = eventName === "monitorremoved" || eventName === "monitorremovedv2"
        if (!added && !removed)
            return
        root.hotplugVisualKind = added ? "added" : "removed"
        root.hotplugVisualConnector = root.hotplugConnectorFromEvent(eventName, eventData)
        hotplugVisualMinimumTimer.restart()
    }

    function clearHotplugVisualIfIdle() {
        if (root.hotplugPresentationActive || hotplugVisualMinimumTimer.running)
            return
        root.hotplugVisualKind = ""
        root.hotplugVisualConnector = ""
    }

    function holdWorkspacePresentation() {
        root.presentationGeneration++
        root.sessionRestoreActive = true
    }

    function activateSessionRestore() {
        root.sessionRestoreOwnerActive = true
        root.holdWorkspacePresentation()
        restoreSafetyTimer.restart()
    }

    function releaseSessionRestore() {
        restoreSafetyTimer.stop()
        if (!root.sessionRestoreOwnerActive)
            return
        root.sessionRestoreOwnerActive = false
        root.releaseWorkspacePresentationIfIdle()
    }

    function activateHotplugPresentation() {
        root.hotplugPresentationActive = true
        root.holdWorkspacePresentation()
        hotplugSafetyTimer.restart()
    }

    function releaseHotplugPresentation() {
        hotplugSafetyTimer.stop()
        if (!root.hotplugPresentationActive)
            return
        root.hotplugPresentationActive = false
        root.clearHotplugVisualIfIdle()
        root.releaseWorkspacePresentationIfIdle()
    }

    function commitHotplugPresentation() {
        if (!root.hotplugPresentationActive)
            return
        // Publish the post-route snapshot now, but keep animations fenced until
        // the daemon's quiet verification pass. callLater covers native model
        // notifications queued alongside the synchronous compositor dispatch.
        root.sessionRestoreCommit()
        Qt.callLater(() => {
            if (root.hotplugPresentationActive)
                root.sessionRestoreCommit()
        })
    }

    function releaseWorkspacePresentationIfIdle() {
        if (root.sessionRestoreOwnerActive || root.hotplugPresentationActive)
            return
        const generation = ++root.presentationGeneration
        root.sessionRestoreCommit()
        Qt.callLater(() => {
            // A newer restore/hotplug owner may start in this event-loop
            // turn. An older finish must never release that newer gate.
            if (root.presentationGeneration === generation
                    && !root.sessionRestoreOwnerActive
                    && !root.hotplugPresentationActive)
                root.sessionRestoreActive = false
        })
    }

    Timer {
        id: restoreSafetyTimer
        // The compositor's 65 s watchdog restores every monitor first.  This
        // UI-only fallback runs afterwards, so it can never reveal a stale
        // workspace indicator ahead of compositor rollback.
        interval: 70000
        repeat: false
        onTriggered: {
            root.sessionRestoreOwnerActive = false
            root.releaseWorkspacePresentationIfIdle()
        }
    }

    Timer {
        id: hotplugSafetyTimer
        interval: 70000
        repeat: false
        onTriggered: {
            root.hotplugPresentationActive = false
            root.clearHotplugVisualIfIdle()
            root.releaseWorkspacePresentationIfIdle()
        }
    }

    Timer {
        id: hotplugVisualMinimumTimer
        // Long enough to perceive at 60 Hz, without delaying routing or the
        // final workspace state. The presentation gate keeps it lit if a safe
        // retry takes longer.
        interval: 220
        repeat: false
        onTriggered: root.clearHotplugVisualIfIdle()
    }

    Timer {
        id: restoreStartupProbeTimer
        // The login helper intentionally waits for Hyprland's event socket
        // before publishing its restore lease.  Probing in the first QML event
        // turn can therefore release the presentation gate too early and show
        // the workspace staging transaction.  Keep the gate closed across
        // that short startup hand-off; explicit IPC start/finish still wins.
        interval: 2500
        repeat: false
        onTriggered: restoreFlagProbe.running = true
    }

    Process {
        id: restoreFlagProbe
        command: ["/usr/bin/test", "-e", FileUtils.trimFileProtocol(`${Directories.state}/hypr-session/.restore-active`)]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.activateSessionRestore()
            else
                root.releaseSessionRestore()
        }
    }

    Component.onCompleted: {
        // A shell start/reload is a new UI session. Never carry a transient
        // panel or popup into it; users can still open everything explicitly.
        root.closeTransientUi()
        restoreSafetyTimer.start()
        restoreStartupProbeTimer.start()
    }

    readonly property var hotCornerOptions: [
        { displayName: Translation.tr("None"),                  value: "none" },
        { displayName: Translation.tr("Left Sidebar"),           value: "sidebarLeftOpen" },
        { displayName: Translation.tr("Right Sidebar"),          value: "sidebarRightOpen" },
        { displayName: Translation.tr("Overview Launcher"),               value: "overviewOpen" },
        { displayName: Translation.tr("Wallpaper Selector"),     value: "wallpaperSelectorOpen" },
        { displayName: Translation.tr("Media Controls"),         value: "mediaControlsOpen" },
        { displayName: Translation.tr("Overlay"),                value: "overlayOpen" },
        { displayName: Translation.tr("ScreenShot Region"),        value: "regionSelectorOpen" },
        { displayName: Translation.tr("Screen Translator"),      value: "screenTranslatorOpen" },
        { displayName: Translation.tr("On-screen Keyboard"),     value: "oskOpen" },
        { displayName: Translation.tr("Session Menu"),           value: "sessionOpen" }
    ]

    function toggleState(name) {
        if (!name || name === "none") return;
        root[name] = !root[name];
    }

    // One Escape path for shell-owned transient UI. Keeping this here avoids
    // separate panels racing to handle the same key or leaving another panel
    // behind. The Hyprland binding is transparent, so applications still
    // receive Escape after the shell has released its overlays.
    function closeTransientUi() {
        BarPopups.close()
        root.crosshairOpen = false
        root.overviewOpen = false
        root.workspaceShowNumbers = false
        root.sidebarLeftOpen = false
        root.sidebarRightOpen = false
        root.searchOpen = false
        root.mediaControlsOpen = false
        root.osdBrightnessOpen = false
        root.osdVolumeOpen = false
        root.oskOpen = false
        root.settingsOpen = false
        root.overlayOpen = false
        root.regionSelectorOpen = false
        root.screenTranslatorOpen = false
        root.sessionOpen = false
        root.wallpaperSelectorOpen = false
        root.desktopWidgetKeyboardFocus = false
        root.desktopMenuOpen = false
        root.dropShelfOpen = false
    }

    Timer {
        id: barRefreshTimer
        interval: 200
        repeat: false
        onTriggered: {
            root.barOpen = true
        }
    }

    function refreshBar() {
        if (!root.barOpen) return;
        root.barOpen = false
        barRefreshTimer.restart()
    }

    CompositorGlobalShortcut {
        name: "workspaceNumber"
        description: "Hold to show workspace numbers, release to show icons"
        onPressed: { root.superDown = true }
        onReleased: { root.superDown = false }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            // A workspace switch means Super was used as a modifier, not as
            // the launcher key. Handle this after Hyprland has already begun
            // its animation instead of blocking the keybinding hot path.
            if (root.superDown)
                root.superReleaseMightTrigger = false
        }
        function onRawEvent(event) {
            root.noteHotplugTopologyEvent(event.name, event.data)
        }
    }

    CompositorGlobalShortcut {
        name: "shellUiClose"
        description: "Close shell popups, panels and workspace overview"
        onPressed: root.closeTransientUi()
    }

    IpcHandler {
        target: "background"
        function toggleCenteredWallpaper(): void {
            Config.options.background.centeredWallpaper = !Config.options.background.centeredWallpaper
        }
    }

    IpcHandler {
        target: "sessionRestore"
        function start(): void { root.activateSessionRestore() }
        function finish(): void { root.releaseSessionRestore() }
        function hotplugStart(): void { root.activateHotplugPresentation() }
        function hotplugCommit(): void { root.commitHotplugPresentation() }
        function hotplugFinish(): void { root.releaseHotplugPresentation() }
    }

     CompositorGlobalShortcut {
        name: "centeredWallpaperToggle"
        description: "Toggles centered wallpaper"
        onPressed: {
            Config.options.background.centeredWallpaper = !Config.options.background.centeredWallpaper
        }
    }
}
