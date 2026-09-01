// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 desktop-ui contributors

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions

/**
 * Discovers desktop themes, applies the selected themes, and manages the
 * shell-generated Matugen configuration.
 *
 * Theme application is delegated to small scripts so that GTK, GSettings,
 * and legacy desktop configuration files remain consistent. The Matugen
 * source file is config.toml.orig; config.toml is generated from the enabled
 * template blocks.
 */
Singleton {
    id: root

    readonly property string scriptDir: FileUtils.trimFileProtocol(`${Directories.scriptPath}/theming`)
    readonly property string matugenConfigPath: FileUtils.trimFileProtocol(`${Directories.config}/matugen/config.toml`)

    property list<string> iconThemes: []
    property list<string> gtkThemes: []
    property list<string> cursorThemes: []
    property string currentIconTheme: ""
    property string currentGtkTheme: ""
    property string currentCursorTheme: ""
    property int currentCursorSize: 24

    // Text before the first [templates.*] table in config.toml.orig.
    property string matugenPreamble: ""
    // Public entries have the shape { name: string, block: string }.
    property list<var> matugenTemplates: []

    property string _pendingIconTheme: ""
    property bool _iconApplyPending: false
    property string _pendingGtkTheme: ""
    property bool _gtkApplyPending: false
    property string _pendingCursorTheme: ""
    property int _pendingCursorSize: 24
    property bool _cursorApplyPending: false
    property bool _scanRefreshPending: false

    function themeArgument(value, allowEmpty) {
        if (value === undefined || value === null)
            return allowEmpty ? "" : null

        const theme = String(value)
        if (theme.length === 0)
            return allowEmpty ? "" : null
        if (/[\u0000-\u001f\u007f]/.test(theme))
            return null
        return theme
    }

    function normalizedCursorSize(value) {
        const numericSize = Number(value)
        if (!Number.isFinite(numericSize))
            return 24
        return Math.max(1, Math.min(512, Math.round(numericSize)))
    }

    function templateEnabled(name) {
        return Config.options.appearance.matugenDisabled.indexOf(name) === -1
    }

    function setTemplateEnabled(name, enabled) {
        const disabled = Config.options.appearance.matugenDisabled
        const isEnabled = !disabled.includes(name)
        if (enabled === isEnabled)
            return

        Config.options.appearance.matugenDisabled = enabled
            ? disabled.filter(entry => entry !== name)
            : disabled.concat([name])
        root.regenerateMatugenConfig()
    }

    function refresh() {
        if (scanProcess.running) {
            root._scanRefreshPending = true
            return
        }
        scanRestartTimer.restart()
    }

    function startIconApply() {
        if (iconApplyProcess.running || !root._iconApplyPending)
            return
        iconApplyProcess.command = ["bash", `${root.scriptDir}/set-icon-theme.sh`, root._pendingIconTheme]
        root._iconApplyPending = false
        iconApplyProcess.running = true
    }

    function startGtkApply() {
        if (gtkApplyProcess.running || !root._gtkApplyPending)
            return
        gtkApplyProcess.command = ["bash", `${root.scriptDir}/set-gtk-theme.sh`, root._pendingGtkTheme]
        root._gtkApplyPending = false
        gtkApplyProcess.running = true
    }

    function startCursorApply() {
        if (cursorApplyProcess.running || !root._cursorApplyPending)
            return
        cursorApplyProcess.command = [
            "bash",
            `${root.scriptDir}/set-cursor-theme.sh`,
            root._pendingCursorTheme,
            String(root._pendingCursorSize)
        ]
        root._cursorApplyPending = false
        cursorApplyProcess.running = true
    }

    function applyIconTheme(value) {
        const theme = root.themeArgument(value, false)
        if (theme === null)
            return

        root.currentIconTheme = theme
        root._pendingIconTheme = theme
        root._iconApplyPending = true
        iconApplyTimer.restart()
    }

    function applyGtkTheme(value) {
        const theme = root.themeArgument(value, false)
        if (theme === null)
            return

        root.currentGtkTheme = theme
        root._pendingGtkTheme = theme
        root._gtkApplyPending = true
        gtkApplyTimer.restart()
    }

    function applyCursorTheme(value, requestedSize) {
        const theme = root.themeArgument(value, true)
        if (theme === null)
            return

        const size = root.normalizedCursorSize(requestedSize)
        root.currentCursorTheme = theme
        root.currentCursorSize = size
        NiriConfig.options.cursor.theme = theme
        NiriConfig.options.cursor.size = size

        // An empty theme means that the compositor should use its default.
        if (theme.length > 0) {
            root._pendingCursorTheme = theme
            root._pendingCursorSize = size
            root._cursorApplyPending = true
            cursorApplyTimer.restart()
        }
    }

    function regenerateMatugenConfig() {
        // Never replace a user file when no template source was discovered.
        if (root.matugenTemplates.length === 0)
            return

        let output = "# AUTO-GENERATED by desktop-ui; changes will be overwritten.\n"
        output += "# Edit config.toml.orig or use the Interface settings page.\n\n"
        output += root.matugenPreamble.trim() + "\n\n"

        for (const template of root.matugenTemplates) {
            if (root.templateEnabled(template.name))
                output += template.block.trim() + "\n\n"
        }
        matugenConfigFile.setText(output)
    }

    function regenerateColors() {
        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch"])
    }

    FileView {
        id: matugenConfigFile
        path: root.matugenConfigPath
    }

    Timer {
        id: iconApplyTimer
        interval: 0
        repeat: false
        onTriggered: root.startIconApply()
    }

    Timer {
        id: gtkApplyTimer
        interval: 0
        repeat: false
        onTriggered: root.startGtkApply()
    }

    Timer {
        id: cursorApplyTimer
        interval: 0
        repeat: false
        onTriggered: root.startCursorApply()
    }

    Process {
        id: iconApplyProcess
        onExited: {
            if (root._iconApplyPending)
                iconApplyTimer.restart()
        }
    }

    Process {
        id: gtkApplyProcess
        onExited: {
            if (root._gtkApplyPending)
                gtkApplyTimer.restart()
        }
    }

    Process {
        id: cursorApplyProcess
        onExited: {
            if (root._cursorApplyPending)
                cursorApplyTimer.restart()
        }
    }

    Process {
        id: matugenSourceProcess
        running: true
        command: [
            "bash",
            "-c",
            `
set -eu
config_path=$1
source_path="$config_path.orig"

if [ -f "$config_path" ] && [ ! -e "$source_path" ]; then
    cp -- "$config_path" "$source_path"
fi

if [ -f "$source_path" ]; then
    cat -- "$source_path"
fi
`,
            "desktop-ui-matugen-source",
            root.matugenConfigPath
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const templates = []
                const preamble = []
                let currentTemplate = null

                for (const line of text.split("\n")) {
                    const header = line.match(/^\s*\[templates\.([^\]]+)\]\s*(?:#.*)?$/)
                    if (header !== null) {
                        let name = header[1].trim()
                        if ((name.startsWith("\"") && name.endsWith("\""))
                                || (name.startsWith("'") && name.endsWith("'")))
                            name = name.slice(1, -1)

                        currentTemplate = { name: name, lines: [line] }
                        templates.push(currentTemplate)
                    } else if (/^\s*\[[^\]]+\]/.test(line)) {
                        currentTemplate = null
                        preamble.push(line)
                    } else if (currentTemplate !== null) {
                        currentTemplate.lines.push(line)
                    } else {
                        preamble.push(line)
                    }
                }

                root.matugenPreamble = preamble.join("\n")
                root.matugenTemplates = templates.map(template => ({
                    name: template.name,
                    block: template.lines.join("\n")
                }))
            }
        }
    }

    Timer {
        id: scanRestartTimer
        interval: 0
        repeat: false
        onTriggered: scanProcess.running = true
    }

    Process {
        id: scanProcess
        running: true
        command: [
            "bash",
            "-c",
            `
set -u
export LC_ALL=C

emit_child_directories() {
    record_type=$1
    shift
    for parent in "$@"; do
        [ -d "$parent" ] || continue
        find "$parent" -mindepth 1 -maxdepth 1 -type d -printf '%f\\0' 2>/dev/null |
            while IFS= read -r -d '' theme_name; do
                case "$theme_name" in
                    *$'\\t'*|*$'\\n'*|*$'\\r'*) continue ;;
                esac
                printf '%s\\t%s\\n' "$record_type" "$theme_name"
            done
    done
}

emit_cursor_directories() {
    for parent in "$@"; do
        [ -d "$parent" ] || continue
        find "$parent" -mindepth 2 -maxdepth 2 -type d -name cursors -printf '%h\\0' 2>/dev/null |
            while IFS= read -r -d '' theme_path; do
                theme_name=$(basename -- "$theme_path")
                case "$theme_name" in
                    *$'\\t'*|*$'\\n'*|*$'\\r'*) continue ;;
                esac
                printf 'C\\t%s\\n' "$theme_name"
            done
    done
}

read_gsetting() {
    schema=$1
    key=$2
    value=
    if command -v gsettings >/dev/null 2>&1; then
        value=$(gsettings get "$schema" "$key" 2>/dev/null | sed "s/^'//; s/'$//" || true)
    fi
    printf '%s\\n' "$value"
}

emit_child_directories I /usr/share/icons "$HOME/.local/share/icons" "$HOME/.icons" |
    grep -Ev $'^I\\t(default|hicolor)$' | sort -u || true
emit_child_directories G /usr/share/themes "$HOME/.local/share/themes" "$HOME/.themes" |
    sort -u
emit_cursor_directories /usr/share/icons "$HOME/.local/share/icons" "$HOME/.icons" |
    sort -u

printf 'V\\ticon\\t%s\\n' "$(read_gsetting org.gnome.desktop.interface icon-theme)"
printf 'V\\tgtk\\t%s\\n' "$(read_gsetting org.gnome.desktop.interface gtk-theme)"
printf 'V\\tcursor\\t%s\\n' "$(read_gsetting org.gnome.desktop.interface cursor-theme)"
printf 'V\\tsize\\t%s\\n' "$(read_gsetting org.gnome.desktop.interface cursor-size)"
`,
            "desktop-ui-theme-scan"
        ]
        onExited: {
            if (root._scanRefreshPending) {
                root._scanRefreshPending = false
                scanRestartTimer.restart()
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const discovered = { I: [], G: [], C: [] }
                const selected = { icon: "", gtk: "", cursor: "", size: "24" }

                for (const record of text.split("\n")) {
                    const fields = record.split("\t")
                    const recordType = fields.shift()
                    if (recordType in discovered && fields.length === 1 && fields[0].length > 0) {
                        discovered[recordType].push(fields[0])
                    } else if (recordType === "V" && fields.length === 2 && fields[0] in selected) {
                        selected[fields[0]] = fields[1]
                    }
                }

                root.iconThemes = discovered.I
                root.gtkThemes = discovered.G
                root.cursorThemes = discovered.C
                root.currentIconTheme = selected.icon
                root.currentGtkTheme = selected.gtk
                root.currentCursorTheme = selected.cursor
                root.currentCursorSize = root.normalizedCursorSize(selected.size)
            }
        }
    }
}
