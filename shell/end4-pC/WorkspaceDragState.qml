pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Bridges geometry and hover state between the bar and the full-screen
// overview. Qt's internal QML drag events stay inside one scene, so the
// overview owns the actual DropAreas while the bar paints their feedback.
Singleton {
    id: root

    property var barRegions: ({})
    property string targetScreenName: ""
    property int targetIndex: -1
    property int targetWorkspace: -1
    property bool compactionActive: false
    readonly property string barRegionPath:
        `${Quickshell.env("XDG_RUNTIME_DIR")}/end4-pc-workspace-bars.tsv`

    FileView {
        id: barRegionFile
        path: root.barRegionPath
    }

    Timer {
        id: compactionSafetyTimer
        interval: 2000
        repeat: false
        onTriggered: root.compactionActive = false
    }

    onCompactionActiveChanged: {
        if (root.compactionActive)
            compactionSafetyTimer.restart()
        else
            compactionSafetyTimer.stop()
    }

    function persistBarRegions() {
        const lines = []
        for (const screenName of Object.keys(root.barRegions)) {
            const region = root.barRegions[screenName]
            lines.push([
                screenName,
                region.x,
                region.y,
                region.width,
                region.height,
                region.cellSize,
                region.shownCount,
                region.vertical ? 1 : 0,
                (region.workspaceIds ?? []).join(",")
            ].join("\t"))
        }
        barRegionFile.setText(lines.join("\n") + (lines.length ? "\n" : ""))
    }

    function setBarRegion(screenName, x, y, width, height, cellSize,
                          shownCount, vertical, workspaceIds) {
        if (!screenName || width <= 0 || height <= 0 || cellSize <= 0)
            return

        // Active-workspace changes do not move the bar. Geometry signals can
        // also arrive in small bursts during layout. Avoid cloning the region
        // map and waking every overview binding when the payload is identical.
        const current = root.barRegions[screenName]
        const currentIds = current?.workspaceIds ?? []
        const nextIds = workspaceIds ?? []
        let sameIds = currentIds.length === nextIds.length
        for (let i = 0; sameIds && i < nextIds.length; ++i)
            sameIds = currentIds[i] === nextIds[i]
        if (current
                && current.x === x
                && current.y === y
                && current.width === width
                && current.height === height
                && current.cellSize === cellSize
                && current.shownCount === shownCount
                && current.vertical === vertical
                && sameIds)
            return

        const nextRegions = Object.assign({}, root.barRegions)
        nextRegions[screenName] = {
            "x": x,
            "y": y,
            "width": width,
            "height": height,
            "cellSize": cellSize,
            "shownCount": shownCount,
            "vertical": vertical,
            "workspaceIds": workspaceIds
        }
        root.barRegions = nextRegions
        root.persistBarRegions()
    }

    function removeBarRegion(screenName) {
        if (!screenName || root.barRegions[screenName] === undefined)
            return
        const nextRegions = Object.assign({}, root.barRegions)
        delete nextRegions[screenName]
        root.barRegions = nextRegions
        root.persistBarRegions()
        root.clearTarget(screenName, -1)
    }

    function regionFor(screenName) {
        return root.barRegions[screenName] ?? null
    }

    function setTarget(screenName, index, workspaceId) {
        root.targetScreenName = screenName
        root.targetIndex = index
        root.targetWorkspace = workspaceId
    }

    function clearTarget(screenName, index) {
        if (screenName && root.targetScreenName !== screenName)
            return
        if (index >= 0 && root.targetIndex !== index)
            return
        root.targetScreenName = ""
        root.targetIndex = -1
        root.targetWorkspace = -1
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "custom")
                return
            const fields = String(event.data ?? "").split("|")
            if (fields[0] !== "workspace-drag")
                return

            if (fields[1] === "hover" && fields.length >= 5) {
                root.setTarget(fields[2], Number(fields[3]), Number(fields[4]))
            } else if (fields[1] === "clear") {
                root.clearTarget("", -1)
            } else if (fields[1] === "compact-start") {
                root.compactionActive = true
                compactionSafetyTimer.restart()
            } else if (fields[1] === "compact-finish") {
                root.compactionActive = false
            }
        }
    }
}
