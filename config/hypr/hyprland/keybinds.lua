require("hyprland.lib")
require("hyprland.variables")
if is_file_exists(HOME .. "/.config/hypr/custom/variables.lua") then
    require("custom.variables")
end

-- Workspace ownership and compaction must share the router's invariant.
-- A legacy custom variable may still exist for unrelated UI code, but it
-- cannot redefine transaction boundaries underneath the semantic router.
local workspaceGroupSize = desktop_ui_workspace_group_size()
assert(workspaceGroupSize == 10, "unsupported desktop workspace group size")

local qsScripts = "$HOME/.config/quickshell/$qsConfig/scripts"
local hyprScripts = "$HOME/.config/hypr/hyprland/scripts"
local qsIpcCall = "qs -c $qsConfig ipc call"
local qsIsAlive = qsIpcCall .. " TEST_ALIVE"

hl.bind("SUPER + SUPER_L", hl.dsp.global("quickshell:searchToggleRelease"), { description = "Shell: Toggle search" })
hl.bind("SUPER + SUPER_R", hl.dsp.global("quickshell:searchToggleRelease"))

hl.bind("SUPER_L", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true })
hl.bind("SUPER_R", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true })
hl.bind("SUPER_L", hl.dsp.global("quickshell:workspaceNumber"),
    { ignore_mods = true, transparent = true, release = true })
hl.bind("SUPER_R", hl.dsp.global("quickshell:workspaceNumber"),
    { ignore_mods = true, transparent = true, release = true })
hl.bind("SUPER + Tab", hl.dsp.global("quickshell:overviewWorkspacesToggle"), { description = "Shell: Toggle overview" })
hl.bind("SUPER + V", hl.dsp.global("quickshell:overviewClipboardToggle"))
hl.bind("SUPER + Period", hl.dsp.global("quickshell:overviewEmojiToggle"))
hl.bind("SUPER + A", hl.dsp.global("quickshell:sidebarLeftToggle"), { description = "Shell: Toggle left sidebar" })
hl.bind("SUPER + ALT + A", hl.dsp.global("quickshell:sidebarLeftToggleDetach"))
hl.bind("SUPER + B", hl.dsp.global("quickshell:sidebarLeftToggle"))
hl.bind("SUPER + O", hl.dsp.global("quickshell:sidebarLeftToggle"))
hl.bind("SUPER + N", hl.dsp.global("quickshell:sidebarRightToggle"), { description = "Shell: Toggle right sidebar" })
-- Non-consuming: closes shell-owned overlays while Escape still reaches the app.
hl.bind("ESCAPE", hl.dsp.global("quickshell:shellUiClose"),
    { non_consuming = true, description = "Shell: Close transient UI" })
hl.bind("SUPER + Slash", hl.dsp.global("quickshell:cheatsheetToggle"), { description = "Shell: Toggle cheatsheet" })
hl.bind("SUPER + K", hl.dsp.global("quickshell:oskToggle"), { description = "Shell: Toggle on-screen keyboard" })
hl.bind("SUPER + M", hl.dsp.global("quickshell:mediaControlsToggle"), { description = "Shell: Toggle media controls" })
hl.bind("SUPER + G", hl.dsp.global("quickshell:overlayToggle"), { description = "Shell: Toggle widget overlay" })
hl.bind("CTRL + ALT + Delete", hl.dsp.global("quickshell:sessionToggle"), { description = "Shell: Toggle session menu" })
hl.bind("SUPER + J", hl.dsp.global("quickshell:barToggle"), { description = "Shell: Toggle bar" })
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd(qsIsAlive .. " || pkill wlogout || wlogout -p layer-shell"))
hl.bind("SHIFT + SUPER + ALT + Slash", hl.dsp.exec_cmd("qs -p $HOME/.config/quickshell/$qsConfig/welcome.qml"))

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(qsIpcCall .. " brightness increment || sg video -c 'brightnessctl --class=backlight set 5%+'"),
    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(qsIpcCall .. " brightness decrement || sg video -c 'brightnessctl --class=backlight set 5%-'"),
    { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+ -l 1.5"),
    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-"),
    { locked = true, repeating = true })

hl.bind("CTRL + SUPER + T", hl.dsp.global("quickshell:wallpaperSelectorToggle"),
    { description = "Shell: Change wallpaper" })
hl.bind("CTRL + SUPER + ALT + T", hl.dsp.global("quickshell:wallpaperSelectorRandom"),
    { description = "Shell: Random wallpaper" })
hl.bind("CTRL + SUPER + SHIFT + D", hl.dsp.global("quickshell:toggleLightDark"),
    { description = "Shell: Toggle light/dark mode" })
hl.bind("CTRL + SUPER + T", hl.dsp.exec_cmd(qsIsAlive .. " || " .. qsScripts .. "/colors/switchwall.sh"))
hl.bind("CTRL + SUPER + R", hl.dsp.exec_cmd("systemctl --user restart --no-block quickshell-ui.service"),
    { description = "Shell: Restart widgets" })
hl.bind("CTRL + SUPER + P", hl.dsp.global("quickshell:panelFamilyCycle"), { description = "Shell: Cycle panel family" })

--##! Utilities
--# Screenshot, Record, OCR, Color picker, Clipboard history
hl.bind("SUPER + V", hl.dsp.exec_cmd(
        qsIsAlive .. " || pkill fuzzel || cliphist list | fuzzel --match-mode fzf --dmenu | cliphist decode | wl-copy"),
    { description = "Utilities: Clipboard history >> clipboard" })
hl.bind("SUPER + Period", hl.dsp.exec_cmd(
        qsIsAlive .. " || pkill fuzzel || " .. hyprScripts .. "/fuzzel-emoji.sh copy"),
    { description = "Utilities: Emoji >> clipboard" })
hl.bind("SUPER + SHIFT + S", hl.dsp.global("quickshell:regionScreenshot"), { description = "Utilities: Screen snip" })
hl.bind("SUPER + SHIFT + S",
    hl.dsp.exec_cmd(qsIsAlive .. " || pidof slurp || grim -g \"$(slurp)\" - | wl-copy"))
hl.bind("SUPER + SHIFT + A", hl.dsp.global("quickshell:regionSearch"), { description = "Utilities: Google Lens" })
hl.bind("SUPER + SHIFT + A", hl.dsp.exec_cmd(qsIsAlive .. " || pidof slurp || " .. hyprScripts .. "/snip_to_search.sh"))
--# OCR
hl.bind("SUPER + SHIFT + X", hl.dsp.global("quickshell:regionOcr"),
    { description = "Utilities: Character recognition >> clipboard" })
hl.bind("SUPER + SHIFT + T", hl.dsp.global("quickshell:screenTranslate"),
    { description = "Utilities: Translate screen content" })
hl.bind("SUPER + SHIFT + X", hl.dsp.exec_cmd(
    qsIsAlive ..
    " || pidof slurp || grim -g \"$(slurp $SLURP_ARGS)\" \"/tmp/ocr_image.png\" && tesseract \"/tmp/ocr_image.png\" stdout -l $(tesseract --list-langs | awk 'NR>1{print $1}' | tr '\\\\n' '+' | sed 's/\\\\+$/\\\\n/') | wl-copy && rm \"/tmp/ocr_image.png\""
))
--# Color picker
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"),
    { description = "Utilities: Pick color #RRGGBB >> clipboard" })
--# Recording stuff
hl.bind("SUPER + SHIFT + R", hl.dsp.global("quickshell:regionRecord"),
    { locked = true, description = "Utilities: Record region (no sound)" })
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd(qsIsAlive .. " || " .. qsScripts .. "/videos/record.sh"), { locked = true })
hl.bind("SUPER + ALT + R", hl.dsp.global("quickshell:regionRecord"), { locked = true })
hl.bind("SUPER + ALT + R", hl.dsp.exec_cmd(qsIsAlive .. " || " .. qsScripts .. "/videos/record.sh"), { locked = true })
hl.bind("CTRL + ALT + R", hl.dsp.exec_cmd(qsScripts .. "/videos/record.sh --fullscreen"), { locked = true })
hl.bind("SUPER + SHIFT + ALT + R", hl.dsp.exec_cmd(qsScripts .. "/videos/record.sh --fullscreen --sound"),
    { locked = true, description = "Utilities: Record screen (with sound)" })
--# Fullscreen screenshot
local grimhyprctl = "grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\""
hl.bind("Print", hl.dsp.exec_cmd(grimhyprctl .. " - | wl-copy"),
    { locked = true, description = "Utilities: Screenshot >> clipboard" })
hl.bind("CTRL + Print", hl.dsp.exec_cmd(
    "mkdir -p $(xdg-user-dir PICTURES)/Screenshots && " ..
    grimhyprctl .. " $(xdg-user-dir PICTURES)/Screenshots/Screenshot_\"$(date '+%Y-%m-%d_%H.%M.%S')\".png"
), { locked = true, non_consuming = true, description = "Utilities: Screenshot >> clipboard & file" })
hl.bind("CTRL + Print", hl.dsp.exec_cmd(grimhyprctl .. " - | wl-copy"), { locked = true, non_consuming = true })
--##! Screen
-- Desktop magnification is intentionally disabled. It was easy to trigger
-- accidentally while using Super shortcuts; zoom_factor stays at 1.

--##! Media
local mediaNextCommand =
"playerctl next || playerctl position `bc <<< \"100 * $(playerctl metadata mpris:length) / 1000000 / 100\"`"
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd(mediaNextCommand), { locked = true, description = "Media: Next track" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(mediaNextCommand), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("SUPER + SHIFT + ALT + mouse:275", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("SUPER + SHIFT + ALT + mouse:276", hl.dsp.exec_cmd(mediaNextCommand))
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("playerctl previous"),
    { locked = true, description = "Media: Previous track" })
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("playerctl play-pause"),
    { locked = true, description = "Media: Play/pause media" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"), { locked = true })
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"),
    { locked = true, description = "Media: Toggle mute" })
hl.bind("ALT + XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })
hl.bind("SUPER + ALT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"),
    { locked = true, description = "Media: Toggle mic" })

--#!
--##! Window
--# Focusing
-- QuickShell publishes the exact workspace-button geometry for every output.
-- While a real compositor window is being dragged, hit-test the cursor against
-- that data so each monitor can expose its own workspace group (for example,
-- eDP-1 = 1..10 and HDMI-A-1 = 11..20) without hard-coding those ranges here.
local workspaceDropRuntimeDir = os.getenv("XDG_RUNTIME_DIR")
if not workspaceDropRuntimeDir or workspaceDropRuntimeDir == "" then
    workspaceDropRuntimeDir = "/tmp"
end

local workspaceDropRegionPath = workspaceDropRuntimeDir .. "/end4-pc-workspace-bars.tsv"
local workspaceDrop = {
    active = false,
    button = nil,
    window = nil,
    regions = {},
    targetScreen = "",
    targetIndex = -1,
    targetWorkspace = -1,
    targetMonitorName = "",
    confirmed = false,
    initialWindowX = nil,
    initialWindowY = nil,
    timer = nil,
}

-- Keep one-shot timers alive until their callbacks finish.  A drop can need
-- two compositor frames: one to move the window, then one to retire the now
-- empty active source workspace before its occupied successors are renumbered.
-- The epoch file also fences callbacks from an older Lua state after config
-- reload; a process-global Lua variable cannot do that because Hyprland gives
-- the new config a fresh environment.
local workspaceCompactionEpochPath = workspaceDropRuntimeDir
    .. "/end4-pc-workspace-compaction.epoch"
local workspaceCompactionGeneration = table.concat({
    tostring(os.time()), tostring(os.clock()), tostring({}),
}, ":")
_G.end4WorkspaceCompactionGeneration = workspaceCompactionGeneration
local workspaceCompactionEpochWritten = false
local workspaceCompactionEpochFile = io.open(workspaceCompactionEpochPath, "w")
if workspaceCompactionEpochFile then
    workspaceCompactionEpochFile:write(workspaceCompactionGeneration, "\n")
    workspaceCompactionEpochFile:close()
    workspaceCompactionEpochWritten = true
end
local workspaceCompactionTimers = {}
local workspaceCompactionTimerId = 0
local workspaceCompactionGateDepth = 0
local emergencyWorkspaceMoveCleanup
local workspaceHotplugIntentPath = HOME
    .. "/.local/state/hypr-session/.hotplug-workspace-mutation-active.json"
local workspaceMutationOwner = nil

local function isHotplugWorkspaceMutationOwner(owner)
    return type(owner) == "string"
        and string.sub(owner, 1, 8) == "hotplug:"
end

-- Python hotplug routing and Lua compaction arbitrate in Hyprland's single
-- event loop. Python publishes a durable intent file before acquiring this
-- logical lock, so a config reload cannot erase the exclusion guarantee.
_G.end4_workspace_mutation_lock = function(action, owner)
    return function()
        owner = tostring(owner or "")
        if owner == "" then
            error("workspace mutation owner is empty")
        end
        if action == "acquire" then
            if workspaceMutationOwner and workspaceMutationOwner ~= owner then
                -- Python serializes hotplug routes with StateLock. If an old
                -- process died before releasing its compositor-side token,
                -- the next StateLock holder is the only process allowed to
                -- replace that stale hotplug owner.
                if not (isHotplugWorkspaceMutationOwner(workspaceMutationOwner)
                    and isHotplugWorkspaceMutationOwner(owner)) then
                    error("workspace mutation lock is busy")
                end
            end
            workspaceMutationOwner = owner
            return
        end
        if action == "release" then
            if workspaceMutationOwner and workspaceMutationOwner ~= owner then
                error("workspace mutation lock owner mismatch")
            end
            workspaceMutationOwner = nil
            return
        end
        error("unknown workspace mutation lock action")
    end
end

local function acquireWorkspaceMutationLock(context)
    local owner = "compaction:" .. tostring(context.txid or "")
    if workspaceMutationOwner and workspaceMutationOwner ~= owner then
        -- A missing durable intent proves a prior Python owner can no longer
        -- mutate workspace IDs. Recover instead of wedging compaction until a
        -- full compositor restart.
        if isHotplugWorkspaceMutationOwner(workspaceMutationOwner)
            and not is_file_exists(workspaceHotplugIntentPath) then
            workspaceMutationOwner = nil
        else
            return false
        end
    end
    workspaceMutationOwner = owner
    context.mutationLockOwner = owner
    return true
end

local function releaseWorkspaceMutationLock(context)
    local owner = context and context.mutationLockOwner or nil
    if not owner then
        return true
    end
    if workspaceMutationOwner and workspaceMutationOwner ~= owner then
        return false
    end
    workspaceMutationOwner = nil
    context.mutationLockOwner = nil
    return true
end

local function workspaceCompactionEpochCurrent()
    if not workspaceCompactionEpochWritten then
        return false
    end
    local file = io.open(workspaceCompactionEpochPath, "r")
    if not file then
        return false
    end
    local value = file:read("*l") or ""
    file:close()
    return value == workspaceCompactionGeneration
end

local function scheduleWorkspaceCompactionTask(timeout, callback)
    workspaceCompactionTimerId = workspaceCompactionTimerId + 1
    local timerId = workspaceCompactionTimerId
    local generation = workspaceCompactionGeneration
    local timer
    timer = hl.timer(function()
        if generation ~= workspaceCompactionGeneration
            or not workspaceCompactionEpochCurrent() then
            workspaceCompactionTimers[timerId] = nil
            return
        end
        local ok, callbackError = pcall(callback)
        workspaceCompactionTimers[timerId] = nil
        if not ok then
            workspaceCompactionGateDepth = 0
            hl.dispatch(hl.dsp.event("workspace-drag|compact-finish"))
            if emergencyWorkspaceMoveCleanup then
                pcall(emergencyWorkspaceMoveCleanup)
            end
            error(callbackError)
        end
    end, { timeout = timeout, type = "oneshot" })
    workspaceCompactionTimers[timerId] = timer
    return timer ~= nil
end

local function readWorkspaceDropRegions()
    local regions = {}
    local file = io.open(workspaceDropRegionPath, "r")
    if not file then
        return regions
    end

    for line in file:lines() do
        local fields = {}
        for field in string.gmatch(line, "[^\t]+") do
            fields[#fields + 1] = field
        end

        if #fields >= 9 then
            local workspaceIds = {}
            for id in string.gmatch(fields[9], "[^,]+") do
                local workspaceId = tonumber(id)
                if workspaceId then
                    workspaceIds[#workspaceIds + 1] = math.floor(workspaceId)
                end
            end

            local cellSize = tonumber(fields[6]) or 0
            local shownCount = math.min(
                math.floor(tonumber(fields[7]) or #workspaceIds),
                #workspaceIds
            )
            if fields[1] ~= "" and cellSize > 0 and shownCount > 0 then
                regions[fields[1]] = {
                    x = tonumber(fields[2]) or 0,
                    y = tonumber(fields[3]) or 0,
                    width = tonumber(fields[4]) or 0,
                    height = tonumber(fields[5]) or 0,
                    cellSize = cellSize,
                    shownCount = shownCount,
                    vertical = fields[8] == "1",
                    workspaceIds = workspaceIds,
                }
            end
        end
    end

    file:close()
    return regions
end

local function emitWorkspaceDropClear()
    hl.dispatch(hl.dsp.event("workspace-drag|clear"))
end

local function beginWorkspaceCompactionGate(context)
    if context.compactionGateOpen then
        return
    end
    context.compactionGateOpen = true
    workspaceCompactionGateDepth = workspaceCompactionGateDepth + 1
    if workspaceCompactionGateDepth == 1 then
        hl.dispatch(hl.dsp.event("workspace-drag|compact-start"))
    end
end

local function endWorkspaceCompactionGate(context)
    if not context.compactionGateOpen then
        return
    end
    context.compactionGateOpen = false
    workspaceCompactionGateDepth = math.max(0, workspaceCompactionGateDepth - 1)
    if workspaceCompactionGateDepth == 0 then
        hl.dispatch(hl.dsp.event("workspace-drag|compact-finish"))
    end
end

-- Clear a stale visual gate if the config was reloaded while an old timer was
-- between the focus and rename phases.  The generation check above prevents
-- that old timer from mutating the newly loaded configuration.
hl.dispatch(hl.dsp.event("workspace-drag|compact-finish"))

local function captureWorkspaceDropWindow()
    local activeWindow = hl.get_active_window()
    if not activeWindow then
        return
    end

    local position = activeWindow.at
    if workspaceDrop.window ~= activeWindow then
        workspaceDrop.window = activeWindow
        workspaceDrop.initialWindowX = position and position.x or nil
        workspaceDrop.initialWindowY = position and position.y or nil
        return
    end

    if not position or workspaceDrop.initialWindowX == nil
        or workspaceDrop.initialWindowY == nil then
        workspaceDrop.initialWindowX = position and position.x or nil
        workspaceDrop.initialWindowY = position and position.y or nil
        return
    end

    -- A normal click also arms the non-consuming mouse bind. Only treat it as
    -- a title-bar window drag after the actual window geometry starts moving.
    if math.abs(position.x - workspaceDrop.initialWindowX) >= 2
        or math.abs(position.y - workspaceDrop.initialWindowY) >= 2 then
        workspaceDrop.confirmed = true
    end
end

local function updateWorkspaceDropTarget()
    if not workspaceDrop.active or not workspaceCompactionEpochCurrent() then
        return
    end

    if not workspaceDrop.confirmed then
        captureWorkspaceDropWindow()
        if not workspaceDrop.confirmed then
            return
        end
    end

    local cursor = hl.get_cursor_pos()
    local monitor = cursor and hl.get_monitor_at(cursor) or nil
    local region = monitor and workspaceDrop.regions[monitor.name] or nil
    local targetScreen = ""
    local targetIndex = -1
    local targetWorkspace = -1
    local targetMonitorName = ""

    if cursor and monitor and region then
        local localX = cursor.x - monitor.x
        local localY = cursor.y - monitor.y
        local inside = localX >= region.x
            and localX < region.x + region.width
            and localY >= region.y
            and localY < region.y + region.height

        if inside then
            local offset = region.vertical
                and (localY - region.y)
                or (localX - region.x)
            local index = math.floor(offset / region.cellSize)
            local workspaceId = region.workspaceIds[index + 1]
            if index >= 0 and index < region.shownCount
                and workspaceId and workspaceId > 0 then
                targetScreen = monitor.name
                targetIndex = index
                targetWorkspace = workspaceId
                targetMonitorName = monitor.name
            end
        end
    end

    if targetScreen == workspaceDrop.targetScreen
        and targetIndex == workspaceDrop.targetIndex
        and targetWorkspace == workspaceDrop.targetWorkspace then
        return
    end

    workspaceDrop.targetScreen = targetScreen
    workspaceDrop.targetIndex = targetIndex
    workspaceDrop.targetWorkspace = targetWorkspace
    workspaceDrop.targetMonitorName = targetMonitorName

    if targetWorkspace > 0 then
        hl.dispatch(hl.dsp.event(
            "workspace-drag|hover|" .. targetScreen
                .. "|" .. targetIndex
                .. "|" .. targetWorkspace
        ))
    else
        emitWorkspaceDropClear()
    end
end

local function beginWorkspaceDrop(button, confirmed)
    local window = hl.get_active_window()
    if confirmed and not window then
        return
    end

    local position = window and window.at or nil

    workspaceDrop.active = true
    workspaceDrop.button = button
    workspaceDrop.window = window
    workspaceDrop.regions = readWorkspaceDropRegions()
    workspaceDrop.targetScreen = ""
    workspaceDrop.targetIndex = -1
    workspaceDrop.targetWorkspace = -1
    workspaceDrop.targetMonitorName = ""
    workspaceDrop.confirmed = confirmed == true
    workspaceDrop.initialWindowX = position and position.x or nil
    workspaceDrop.initialWindowY = position and position.y or nil
    emitWorkspaceDropClear()
    updateWorkspaceDropTarget()

    if workspaceDrop.timer then
        workspaceDrop.timer:set_enabled(true)
    else
        workspaceDrop.timer = hl.timer(function()
            updateWorkspaceDropTarget()
        end, { timeout = 16, type = "repeat" })
    end
end

local function clearWindowFullscreen(window)
    if not window then
        return
    end

    local internalMode = tonumber(window.fullscreen) or 0
    local clientMode = tonumber(window.fullscreen_client) or 0
    if internalMode == 0 and clientMode == 0 then
        return
    end

    hl.dispatch(hl.dsp.window.fullscreen_state({
        internal = 0,
        client = 0,
        action = "set",
        window = window,
    }))
end

local function workspaceGroupForCompaction(workspaceId)
    local id = math.floor(tonumber(workspaceId) or 0)
    -- Normal UI groups are 1..10 through 91..100.  Exclude special/named IDs
    -- and the 1001+ parking identities used by the HDMI hotplug transaction.
    if id < 1 or id > workspaceGroupSize * 10 then
        return nil
    end
    return math.floor((id - 1) / workspaceGroupSize)
end

local function workspaceMatchesMonitorGroup(workspaceId, monitorName)
    local id = math.floor(tonumber(workspaceId) or 0)
    local monitor = type(monitorName) == "string"
        and hl.get_monitor(monitorName) or nil
    local first = monitor and desktop_ui_workspace_for_monitor_slot(
        monitor, 1, true) or nil
    return first ~= nil and id >= first
        and id < first + workspaceGroupSize
end

local function workspaceObjectMatchesMonitorGroup(workspace, monitorName)
    local id = math.floor(tonumber(workspace and workspace.id) or 0)
    local actualMonitorName = workspace and workspace.monitor
        and workspace.monitor.name or ""
    return actualMonitorName ~= ""
        and actualMonitorName == monitorName
        and workspaceMatchesMonitorGroup(id, monitorName)
end

local function workspaceMonitorGroupStatus(workspaceId, monitorName)
    local group = workspaceGroupForCompaction(workspaceId)
    if group == nil or type(monitorName) ~= "string"
        or monitorName == "" then
        return "invalid"
    end
    if not hl.get_monitor(monitorName) then
        -- A configured connector can disappear for a compositor frame during
        -- hotplug. Keep its stable-role WAL recoverable, but never grant this
        -- exception to an unconfigured managed connector.
        local stableRole = desktop_ui_monitor_role(monitorName, nil)
        return stableRole == group and "retry" or "invalid"
    end
    return workspaceMatchesMonitorGroup(workspaceId, monitorName)
        and "ok" or "invalid"
end

local function workspaceGroupOwnershipStatus(group, monitorName)
    group = math.floor(tonumber(group) or -1)
    local first = group * workspaceGroupSize + 1
    if group < 0 or group > 9 then
        return "invalid"
    end
    local monitorStatus = workspaceMonitorGroupStatus(first, monitorName)
    if monitorStatus ~= "ok" then
        return monitorStatus
    end

    local workspaces = hl.get_workspaces()
    if type(workspaces) ~= "table" then
        return "retry"
    end
    for _, workspace in ipairs(workspaces) do
        local id = math.floor(tonumber(workspace and workspace.id) or 0)
        if workspaceGroupForCompaction(id) == group
            and not workspaceObjectMatchesMonitorGroup(
                workspace, monitorName) then
            return "invalid"
        end
    end
    return "ok"
end

local function workspaceMoveContextOwnershipStatus(context)
    if type(context) ~= "table" then
        return "invalid"
    end
    local sourceWorkspace = math.floor(
        tonumber(context.sourceWorkspace) or 0)
    local targetWorkspace = math.floor(
        tonumber(context.targetWorkspace) or 0)
    local hole = math.floor(tonumber(context.compactionHole) or 0)
    local group = math.floor(tonumber(context.group) or -1)
    if workspaceGroupForCompaction(sourceWorkspace) ~= group
        or workspaceGroupForCompaction(hole) ~= group
        or workspaceGroupForCompaction(targetWorkspace) == nil then
        return "invalid"
    end
    local sourceStatus = workspaceMonitorGroupStatus(
        sourceWorkspace, context.sourceMonitorName)
    local targetStatus = workspaceMonitorGroupStatus(
        targetWorkspace, context.targetMonitorName)
    if sourceStatus == "invalid" or targetStatus == "invalid" then
        return "invalid"
    end
    if sourceStatus == "retry" or targetStatus == "retry" then
        return "retry"
    end
    return workspaceGroupOwnershipStatus(group, context.sourceMonitorName)
end

local function workspaceCompactionBlocked()
    if is_file_exists(HOME .. "/.local/state/hypr-session/.restore-active") then
        return true
    end
    if is_file_exists(workspaceHotplugIntentPath) then
        return true
    end

    local journal = io.open(
        HOME .. "/.local/state/hypr-session/hotplug-workspaces.json", "r")
    if not journal then
        -- The hotplug journal is the durable identity fence between the HDMI
        -- router and workspace compaction.  If it cannot be inspected, moving
        -- workspaces would be guessing whether a live mapping exists.
        return true
    end
    local contents = journal:read("*a") or ""
    journal:close()

    -- This WAL is written with sorted keys.  Accept only its exact idle shape;
    -- malformed JSON, extra keys, or a live mapping all fail closed.
    local compact = string.gsub(contents, "%s", "")
    return not string.match(
        compact,
        '^%{"generation":%d+,"mappings":%[%],"schema":1%}$'
    )
end

local function workspaceWindows(workspaceId)
    local windows = hl.get_workspace_windows(workspaceId)
    if type(windows) ~= "table" then
        return nil
    end
    return windows
end

local function occupiedWorkspacesInGroup(group, minimumId)
    local occupied = {}
    for _, workspace in ipairs(hl.get_workspaces() or {}) do
        local id = math.floor(tonumber(workspace.id) or 0)
        if workspaceGroupForCompaction(id) == group then
            -- Persistent identities are deliberate holes/reservations; never
            -- silently renumber across one.
            if workspace.is_persistent then
                return nil
            end
            local windows = workspaceWindows(id)
            if not windows then
                return nil
            end
            if next(windows) ~= nil
                and (minimumId == nil or id >= minimumId) then
                occupied[#occupied + 1] = workspace
            end
        end
    end
    table.sort(occupied, function(left, right)
        return left.id < right.id
    end)
    return occupied
end

local function dispatchSucceeded(result)
    return result and result.ok
end

local function windowFromSelector(windowOrSelector)
    if type(windowOrSelector) == "string" then
        return hl.get_window(windowOrSelector)
    end
    return windowOrSelector
end

local function selectorForWindow(window)
    if window and window.address and window.address ~= "" then
        return "address:" .. window.address
    end
    return window
end

local workspaceMovePendingPath = workspaceDropRuntimeDir
    .. "/end4-pc-workspace-move.pending.tsv"
local workspaceMoveTransactionActive = false
local workspaceMoveActiveContext = nil
local workspaceMoveQueue = {}
local processNextWorkspaceMove
local resumeWorkspaceMove
local workspaceMoveNonceCounter = 0
local workspaceMoveRecoveryNeedsKick = false
local automaticWorkspaceCompactionRequested = false
local automaticWorkspaceCompactionTimer = nil
local automaticWorkspaceCompactionDebounceMs = 250
local requestAutomaticWorkspaceCompaction

local function rebaseQueuedWorkspaceTargets(fromId, toId, group)
    for _, request in ipairs(workspaceMoveQueue) do
        if not request.invalid and request.targetGroup == group
            and not request.targetWorkspaceObject then
            if request.targetWorkspace == fromId
                or request.targetWorkspace == toId then
                -- Empty targets have numeric slot semantics. Once a rename
                -- consumes either side of that slot, there is no identity to
                -- follow safely, so cancel instead of guessing.
                request.invalid = true
            end
        end
    end
end

local function validPendingField(value)
    return type(value) == "string"
        and not string.find(value, "\t", 1, true)
        and not string.find(value, "\n", 1, true)
        and not string.find(value, "\r", 1, true)
end

local function nextWorkspaceMoveTxid()
    workspaceMoveNonceCounter = workspaceMoveNonceCounter + 1
    return table.concat({
        tostring(os.time()),
        tostring(math.floor(os.clock() * 1000000)),
        tostring(workspaceMoveNonceCounter),
    }, "-")
end

local function readPendingWorkspaceMoveLine()
    local file = io.open(workspaceMovePendingPath, "r")
    if not file then
        -- io.open() alone cannot distinguish ENOENT from an existing WAL that
        -- became unreadable.  A self-rename is a no-op for an existing path
        -- and exposes the POSIX errno for a missing one.  Only proven ENOENT
        -- is idle; every other path/open failure must keep compaction fenced.
        local exists, _, errorCode = os.rename(
            workspaceMovePendingPath, workspaceMovePendingPath)
        if not exists and tonumber(errorCode) == 2 then
            return ""
        end
        return "\0invalid"
    end
    local contents = file:read("*a")
    file:close()
    if contents == "" then
        return ""
    end
    if contents == nil then
        return "\0invalid"
    end

    -- The WAL writer always emits exactly one LF-terminated record.  Reading
    -- only the first line would accept a valid-looking prefix followed by torn
    -- or injected data, while accepting a record without the final LF would
    -- mistake an interrupted write for a committed transaction.
    local line = string.match(contents, "^([^\r\n]+)\n$")
    if not line then
        return "\0invalid"
    end
    return line
end

local function pendingWorkspaceMoveTxid(line)
    line = line or readPendingWorkspaceMoveLine()
    return string.match(line, "^2\t([^\t]+)\t")
end

local function replacePendingWorkspaceMove(contents, token)
    local safeToken = string.gsub(tostring(token or "stale"), "[^%w_.-]", "_")
    local temporaryPath = workspaceMovePendingPath .. "." .. safeToken .. ".tmp"
    local file = io.open(temporaryPath, "w")
    if not file then
        return false
    end
    local wrote = file:write(contents)
    local flushed = file:flush()
    local closed = file:close()
    if not wrote or not flushed or not closed then
        os.remove(temporaryPath)
        return false
    end
    local renamed = os.rename(temporaryPath, workspaceMovePendingPath)
    if not renamed then
        os.remove(temporaryPath)
        return false
    end
    return true
end

local function persistPendingWorkspaceMove(context)
    local fields = {
        "2",
        tostring(context.txid or ""),
        tostring(context.ownerEpoch or ""),
        tostring(context.phase or "prepared"),
        tostring(context.windowSelector or ""),
        tostring(context.sourceWorkspace or 0),
        tostring(context.group or -1),
        tostring(context.sourceMonitorName or ""),
        tostring(context.targetWorkspace or 0),
        tostring(context.targetMonitorName or ""),
        tostring(context.originalFocusMonitorName or ""),
        tostring(context.originalFocusWorkspace or 0),
        tostring(context.originalFocusWindowAddress or ""),
        tostring(context.compactionHole or context.sourceWorkspace or 0),
        tostring(context.stepFrom or 0),
        tostring(context.stepTo or 0),
    }
    for _, value in ipairs(fields) do
        if not validPendingField(value) then
            return false
        end
    end

    local currentLine = readPendingWorkspaceMoveLine()
    if context.pendingPersisted then
        if pendingWorkspaceMoveTxid(currentLine) ~= context.txid then
            return false
        end
    elseif currentLine ~= "" then
        return false
    end

    if not replacePendingWorkspaceMove(
        table.concat(fields, "\t") .. "\n", context.txid) then
        return false
    end
    context.pendingPersisted = true
    return true
end

local function clearPendingWorkspaceMove(context)
    if context and not context.pendingPersisted then
        return true
    end
    if not context or not context.txid then
        return false
    end

    local currentLine = readPendingWorkspaceMoveLine()
    if currentLine == "" then
        context.pendingPersisted = false
        return true
    end
    if pendingWorkspaceMoveTxid(currentLine) ~= context.txid then
        return false
    end
    if not replacePendingWorkspaceMove("", context.txid .. "-clear") then
        return false
    end
    context.pendingPersisted = false
    return true
end

local function updatePendingWorkspaceMove(context, updates)
    local previous = {}
    for key, value in pairs(updates) do
        previous[key] = context[key]
        context[key] = value
    end
    if persistPendingWorkspaceMove(context) then
        return true
    end
    for key, value in pairs(previous) do
        context[key] = value
    end
    return false
end

local function readPendingWorkspaceMove()
    local line = readPendingWorkspaceMoveLine()
    if line == "" then
        return nil
    end

    local fields = {}
    for field in string.gmatch(line .. "\t", "(.-)\t") do
        fields[#fields + 1] = field
    end
    if #fields ~= 16 or fields[1] ~= "2" then
        return nil
    end

    local txid = fields[2]
    local ownerEpoch = fields[3]
    local phase = fields[4]
    local sourceWorkspace = math.floor(tonumber(fields[6]) or 0)
    local storedGroup = math.floor(tonumber(fields[7]) or -1)
    local targetWorkspace = math.floor(tonumber(fields[9]) or 0)
    local compactionHole = math.floor(tonumber(fields[14]) or 0)
    local stepFrom = math.floor(tonumber(fields[15]) or 0)
    local stepTo = math.floor(tonumber(fields[16]) or 0)
    local group = workspaceGroupForCompaction(sourceWorkspace)
    local validPhase = phase == "prepared" or phase == "moved"
        or phase == "compacting" or phase == "rename_prepared"
    if txid == "" or ownerEpoch == "" or not validPhase
        or fields[5] == "" or fields[8] == "" or fields[10] == ""
        or group == nil or storedGroup ~= group
        or workspaceGroupForCompaction(targetWorkspace) == nil then
        return nil
    end
    if workspaceGroupForCompaction(compactionHole) ~= group then
        return nil
    end
    if phase == "rename_prepared" then
        if workspaceGroupForCompaction(stepFrom) ~= group
            or workspaceGroupForCompaction(stepTo) ~= group
            or stepTo ~= compactionHole or stepFrom <= stepTo then
            return nil
        end
    end

    return {
        txid = txid,
        ownerEpoch = ownerEpoch,
        phase = phase,
        windowSelector = fields[5],
        sourceWorkspace = sourceWorkspace,
        sourceMonitorName = fields[8],
        targetWorkspace = targetWorkspace,
        targetMonitorName = fields[10],
        group = group,
        originalFocusMonitorName = fields[11],
        originalFocusWorkspace = tonumber(fields[12]) ~= 0
            and tonumber(fields[12]) or nil,
        originalFocusWindowAddress = fields[13],
        compactionHole = compactionHole,
        stepFrom = stepFrom,
        stepTo = stepTo,
        borrowedFocus = false,
        compactionGateOpen = false,
        pendingPersisted = true,
        ownsMoveLock = true,
        finished = false,
    }
end

local function ensureWorkspaceOnMonitor(workspaceId, monitorName)
    local monitor = hl.get_monitor(monitorName)
    local workspace = hl.get_workspace(workspaceId)
    if not monitor or not workspace then
        return false
    end
    if workspace.monitor and workspace.monitor.name == monitor.name then
        return true
    end
    local result = hl.dispatch(hl.dsp.workspace.move({
        workspace = workspace,
        monitor = monitor,
    }))
    if not dispatchSucceeded(result) then
        return false
    end
    workspace = hl.get_workspace(workspaceId)
    return workspace and workspace.monitor
        and workspace.monitor.name == monitor.name
end

local function restoreCompactionFocus(context)
    if context.skipFocusRestore or not context.borrowedFocus then
        return
    end

    -- Do not override a focus change the user made while the 24 ms retry was
    -- pending.  Restore only while focus is still on the monitor we borrowed.
    local activeMonitor = hl.get_active_monitor()
    if not activeMonitor or activeMonitor.name ~= context.sourceMonitorName then
        return
    end

    local originalMonitor = hl.get_monitor(context.originalFocusMonitorName)
    if not originalMonitor
        or desktop_ui_monitor_role(
            originalMonitor.name, originalMonitor.id) == nil
        or (context.originalFocusWorkspace
            and not workspaceMatchesMonitorGroup(
                context.originalFocusWorkspace, originalMonitor.name)) then
        return
    end

    if context.originalFocusWindowAddress
        and context.originalFocusWindowAddress ~= "" then
        local originalWindow = hl.get_window(
            "address:" .. context.originalFocusWindowAddress)
        if originalWindow and workspaceObjectMatchesMonitorGroup(
            originalWindow.workspace, originalMonitor.name) then
            hl.dispatch(hl.dsp.focus({ window = originalWindow }))
            return
        end
    end

    local monitorResult = hl.dispatch(hl.dsp.focus({ monitor = originalMonitor }))
    if dispatchSucceeded(monitorResult) and context.originalFocusWorkspace then
        hl.dispatch(hl.dsp.focus({
            workspace = context.originalFocusWorkspace,
            on_current_monitor = true,
        }))
    end
end

local function workspaceMoveContextCurrent(context)
    return context ~= nil
        and not context.finished
        and workspaceMoveTransactionActive
        and workspaceMoveActiveContext == context
        and workspaceMoveActiveContext.txid == context.txid
        and workspaceCompactionEpochCurrent()
end

local function refreshWorkspaceCompactionGate(context)
    if not context.compactionGateOpen then
        beginWorkspaceCompactionGate(context)
        return
    end
    -- QML has its own two-second dead-man timer. Refresh it immediately before
    -- a delayed mutation so a long hotplug/restore wait cannot expose an
    -- intermediate workspace identity.
    hl.dispatch(hl.dsp.event("workspace-drag|compact-start"))
end

local function scheduleWorkspaceMoveResume(context, timeout)
    local ok, armed = pcall(function()
        return scheduleWorkspaceCompactionTask(timeout, function()
            if workspaceMoveContextCurrent(context) and resumeWorkspaceMove then
                resumeWorkspaceMove(context)
            end
        end)
    end)
    if ok and armed then
        workspaceMoveRecoveryNeedsKick = false
        return true
    end
    workspaceMoveRecoveryNeedsKick = true
    return false
end

local function finishCompactionTransaction(context)
    if context.finished or context.finishing then
        return
    end
    context.finishing = true
    local cleanupError = nil
    local function cleanupStep(callback)
        local ok, stepError = pcall(callback)
        if not ok and not cleanupError then
            cleanupError = stepError
        end
    end

    cleanupStep(function() restoreCompactionFocus(context) end)
    cleanupStep(function() endWorkspaceCompactionGate(context) end)
    cleanupStep(function() clearPendingWorkspaceMove(context) end)
    cleanupStep(function() releaseWorkspaceMutationLock(context) end)

    local ownsCurrentLock = context.ownsMoveLock
        and workspaceMoveActiveContext == context
        and workspaceMoveActiveContext.txid == context.txid
    if ownsCurrentLock then
        context.ownsMoveLock = false
        workspaceMoveTransactionActive = false
        workspaceMoveActiveContext = nil
        workspaceMoveRecoveryNeedsKick = false
        if processNextWorkspaceMove then
            cleanupStep(function()
                scheduleWorkspaceCompactionTask(1, processNextWorkspaceMove)
            end)
        end
        if requestAutomaticWorkspaceCompaction then
            cleanupStep(function()
                requestAutomaticWorkspaceCompaction(24)
            end)
        end
    end

    context.finished = true
    context.finishing = false
    if cleanupError then
        error(cleanupError)
    end
end

emergencyWorkspaceMoveCleanup = function()
    local context = workspaceMoveActiveContext
    if context and workspaceMoveContextCurrent(context) then
        -- A timer exception after the compositor move must never erase the
        -- only recovery record. Close the visual/focus borrow, retain WAL
        -- ownership, and retry the state machine from its durable phase.
        pcall(restoreCompactionFocus, context)
        pcall(endWorkspaceCompactionGate, context)
        if not scheduleWorkspaceMoveResume(context, 250) then
            workspaceMoveRecoveryNeedsKick = true
        end
        return
    end
    if not workspaceMoveActiveContext then
        workspaceMoveTransactionActive = false
        workspaceMoveRecoveryNeedsKick = false
    end
    if processNextWorkspaceMove then
        pcall(processNextWorkspaceMove)
    end
end

local function focusCompactionReplacement(context, workspaceId)
    local replacement = hl.get_workspace(workspaceId)
    if not replacement or not replacement.monitor
        or replacement.monitor.name ~= context.sourceMonitorName then
        return false
    end

    context.borrowedFocus = context.originalFocusMonitorName ~= ""
        and context.originalFocusMonitorName ~= context.sourceMonitorName
    local monitorResult = hl.dispatch(hl.dsp.focus({
        monitor = context.sourceMonitorName,
    }))
    if not dispatchSucceeded(monitorResult) then
        return false
    end
    local workspaceResult = hl.dispatch(hl.dsp.focus({
        workspace = workspaceId,
        on_current_monitor = true,
    }))
    return dispatchSucceeded(workspaceResult)
end

local function workspaceStateForMove(workspaceId)
    local workspace = hl.get_workspace(workspaceId)
    if not workspace then
        return "absent", nil
    end
    if workspace.is_persistent then
        return "persistent", workspace
    end
    local windows = workspaceWindows(workspaceId)
    if not windows then
        return "unknown", workspace
    end
    if next(windows) ~= nil then
        return "occupied", workspace
    end
    return "empty", workspace
end

local function occupiedWorkspaceListForMove(group)
    local workspaces = hl.get_workspaces()
    if type(workspaces) ~= "table" then
        return nil
    end
    local occupied = {}
    for _, workspace in ipairs(workspaces) do
        local id = math.floor(tonumber(workspace.id) or 0)
        if workspaceGroupForCompaction(id) == group then
            local windows = workspaceWindows(id)
            if not windows then
                return nil
            end
            if next(windows) ~= nil then
                occupied[#occupied + 1] = workspace
            end
        end
    end
    table.sort(occupied, function(left, right)
        return left.id < right.id
    end)
    return occupied
end

local function nextOccupiedWorkspaceAfter(group, hole)
    local workspaces = hl.get_workspaces()
    if type(workspaces) ~= "table" then
        return nil, "retry"
    end
    local candidate = nil
    local persistentBoundary = nil
    for _, workspace in ipairs(workspaces) do
        local id = math.floor(tonumber(workspace.id) or 0)
        if workspaceGroupForCompaction(id) == group and id > hole then
            if workspace.is_persistent then
                if not persistentBoundary or id < persistentBoundary then
                    persistentBoundary = id
                end
            else
                local windows = workspaceWindows(id)
                if not windows then
                    return nil, "retry"
                end
                if next(windows) ~= nil
                    and (not candidate or id < candidate.id) then
                    candidate = workspace
                end
            end
        end
    end
    if persistentBoundary
        and (not candidate or persistentBoundary < candidate.id) then
        return nil, "persistent"
    end
    return candidate, "ok"
end

local function retryWorkspaceMove(context, timeout)
    if workspaceMoveContextCurrent(context) then
        if not scheduleWorkspaceMoveResume(context, timeout or 24) then
            emergencyWorkspaceMoveCleanup()
        end
    end
end

local function workspaceMoveOwnershipReady(context)
    local status = workspaceMoveContextOwnershipStatus(context)
    if status == "ok" then
        return true
    end
    if status == "retry" then
        retryWorkspaceMove(context, 250)
        return false
    end

    -- No compositor mutation is needed to retire an ownership-invalid WAL.
    -- In rename_prepared, either the successor still occupies stepFrom or the
    -- idempotent rename already put it in stepTo; a later authorised automatic
    -- scan can observe either state and continue without losing any window.
    context.skipFocusRestore = true
    finishCompactionTransaction(context)
    return false
end

local function focusAwayFromEmptyCompactionHole(
    context, workspaceId, workspace)
    if not workspace or not workspace.active then
        return true, false
    end

    local occupied = occupiedWorkspaceListForMove(context.group)
    if not occupied then
        return false, false
    end
    local replacement = nil
    for _, candidate in ipairs(occupied) do
        if candidate.id > workspaceId then
            replacement = candidate
            break
        end
    end
    if not replacement then
        for index = #occupied, 1, -1 do
            if occupied[index].id < workspaceId then
                replacement = occupied[index]
                break
            end
        end
    end

    refreshWorkspaceCompactionGate(context)
    if replacement then
        return focusCompactionReplacement(context, replacement.id), false
    end

    local firstWorkspace = context.group * workspaceGroupSize + 1
    if workspaceId == firstWorkspace then
        return true, true
    end
    context.borrowedFocus = context.originalFocusMonitorName ~= ""
        and context.originalFocusMonitorName ~= context.sourceMonitorName
    local monitorResult = hl.dispatch(hl.dsp.focus({
        monitor = context.sourceMonitorName,
    }))
    local workspaceResult = dispatchSucceeded(monitorResult)
        and hl.dispatch(hl.dsp.focus({
            workspace = firstWorkspace,
            on_current_monitor = true,
        })) or nil
    return dispatchSucceeded(workspaceResult), false
end

local function resumeRenamePrepared(context)
    if workspaceCompactionBlocked() then
        refreshWorkspaceCompactionGate(context)
        retryWorkspaceMove(context, 250)
        return
    end
    if not workspaceMoveOwnershipReady(context) then
        return
    end

    local hole = math.floor(tonumber(context.stepTo) or 0)
    local source = math.floor(tonumber(context.stepFrom) or 0)
    if context.phase ~= "rename_prepared"
        or hole ~= context.compactionHole or source <= hole
        or workspaceGroupForCompaction(hole) ~= context.group
        or workspaceGroupForCompaction(source) ~= context.group then
        finishCompactionTransaction(context)
        return
    end

    local holeState, holeWorkspace = workspaceStateForMove(hole)
    local sourceState, sourceWorkspace = workspaceStateForMove(source)
    if holeState == "unknown" or sourceState == "unknown" then
        retryWorkspaceMove(context, 24)
        return
    end
    if holeState == "persistent" or sourceState == "persistent" then
        finishCompactionTransaction(context)
        return
    end
    if holeState == "empty" then
        local focused, terminal = focusAwayFromEmptyCompactionHole(
            context, hole, holeWorkspace)
        if terminal then
            finishCompactionTransaction(context)
        else
            retryWorkspaceMove(context, focused and 24 or 50)
        end
        return
    end

    local holeOccupied = holeState == "occupied"
    local sourceOccupied = sourceState == "occupied"
    if holeOccupied and sourceOccupied then
        -- The pending hole was filled externally. Both workspaces now contain
        -- windows, so there is no safe rename left for this transaction.
        finishCompactionTransaction(context)
        return
    end

    if holeOccupied and not sourceOccupied then
        -- change_id committed before a reload/error but the next phase did not.
        rebaseQueuedWorkspaceTargets(source, hole, context.group)
        if updatePendingWorkspaceMove(context, {
            phase = "compacting",
            compactionHole = source,
            stepFrom = 0,
            stepTo = 0,
        }) then
            retryWorkspaceMove(context, 1)
        else
            retryWorkspaceMove(context, 24)
        end
        return
    end

    if not holeOccupied and not sourceOccupied then
        -- The source workspace disappeared before it could be renamed. Keep
        -- the same hole and rescan for the next live successor.
        if updatePendingWorkspaceMove(context, {
            phase = "compacting",
            compactionHole = hole,
            stepFrom = 0,
            stepTo = 0,
        }) then
            retryWorkspaceMove(context, 1)
        else
            retryWorkspaceMove(context, 24)
        end
        return
    end

    -- An empty workspace object can survive for a compositor frame. Never
    -- dispatch change_id until the destination identity itself is gone.
    if holeState ~= "absent" or not sourceWorkspace then
        retryWorkspaceMove(context, 24)
        return
    end
    if not workspaceMatchesMonitorGroup(hole, context.sourceMonitorName)
        or not workspaceObjectMatchesMonitorGroup(
            sourceWorkspace, context.sourceMonitorName) then
        context.skipFocusRestore = true
        finishCompactionTransaction(context)
        return
    end

    refreshWorkspaceCompactionGate(context)
    local result = hl.dispatch(hl.dsp.workspace.change_id({
        workspace = sourceWorkspace,
        id = hole,
    }))
    -- The durable phase remains rename_prepared until live state proves which
    -- side of the dispatch completed, making this retry idempotent.
    retryWorkspaceMove(context, dispatchSucceeded(result) and 1 or 24)
end

local function resumeCompacting(context)
    if workspaceCompactionBlocked() then
        refreshWorkspaceCompactionGate(context)
        retryWorkspaceMove(context, 250)
        return
    end
    if not workspaceMoveOwnershipReady(context) then
        return
    end

    local hole = math.floor(tonumber(context.compactionHole) or 0)
    if workspaceGroupForCompaction(hole) ~= context.group then
        finishCompactionTransaction(context)
        return
    end

    local holeState, holeWorkspace = workspaceStateForMove(hole)
    if holeState == "unknown" then
        retryWorkspaceMove(context, 24)
        return
    end
    if holeState == "persistent" or holeState == "occupied" then
        -- A deliberate reservation or an external window resolved the hole.
        finishCompactionTransaction(context)
        return
    end
    if holeState == "empty" then
        local focused, terminal = focusAwayFromEmptyCompactionHole(
            context, hole, holeWorkspace)
        if terminal then
            finishCompactionTransaction(context)
        else
            retryWorkspaceMove(context, focused and 24 or 50)
        end
        return
    end

    local successor, status = nextOccupiedWorkspaceAfter(context.group, hole)
    if status == "retry" then
        retryWorkspaceMove(context, 24)
        return
    end
    if status == "persistent" or not successor then
        -- The hole has reached the trailing edge (or a deliberate persistent
        -- boundary), so no visible workspace gap remains to fill.
        finishCompactionTransaction(context)
        return
    end

    local successorId = math.floor(tonumber(successor.id) or 0)
    if not updatePendingWorkspaceMove(context, {
        phase = "rename_prepared",
        compactionHole = hole,
        stepFrom = successorId,
        stepTo = hole,
    }) then
        retryWorkspaceMove(context, 24)
        return
    end
    resumeRenamePrepared(context)
end

local function resumeMovedWorkspace(context)
    if workspaceCompactionBlocked() then
        refreshWorkspaceCompactionGate(context)
        retryWorkspaceMove(context, 250)
        return
    end
    if not workspaceMoveOwnershipReady(context) then
        return
    end

    -- The original target ID is only a routing hint before compaction begins.
    -- Once IDs start changing it is never used as the moved window's identity.
    local movedWindow = windowFromSelector(context.windowSelector)
    local movedWorkspace = movedWindow and movedWindow.workspace or nil
    if movedWorkspace
        and tonumber(movedWorkspace.id) == context.targetWorkspace
        and hl.get_monitor(context.targetMonitorName)
        and not ensureWorkspaceOnMonitor(
            context.targetWorkspace, context.targetMonitorName) then
        retryWorkspaceMove(context, 24)
        return
    end

    local sourceState, sourceWorkspace = workspaceStateForMove(
        context.sourceWorkspace)
    if sourceState == "unknown" then
        retryWorkspaceMove(context, 24)
        return
    end
    if sourceState == "persistent" or sourceState == "occupied" then
        -- The dragged window was not the last one, or another window entered
        -- the source. There is no transaction-created hole to compact.
        finishCompactionTransaction(context)
        return
    end

    -- An empty workspace can remain active on a non-focused monitor. Borrow
    -- that monitor just long enough to activate the nearest survivor.
    if sourceState == "empty" and sourceWorkspace.active then
        local occupied = occupiedWorkspaceListForMove(context.group)
        if not occupied then
            retryWorkspaceMove(context, 24)
            return
        end
        local replacement = nil
        for _, workspace in ipairs(occupied) do
            if workspace.id > context.sourceWorkspace then
                replacement = workspace
                break
            end
        end
        if not replacement then
            for index = #occupied, 1, -1 do
                if occupied[index].id < context.sourceWorkspace then
                    replacement = occupied[index]
                    break
                end
            end
        end

        refreshWorkspaceCompactionGate(context)
        if replacement then
            if not focusCompactionReplacement(context, replacement.id) then
                retryWorkspaceMove(context, 24)
                return
            end
        else
            local firstWorkspace = context.group * workspaceGroupSize + 1
            if context.sourceWorkspace == firstWorkspace then
                finishCompactionTransaction(context)
                return
            end
            context.borrowedFocus = context.originalFocusMonitorName ~= ""
                and context.originalFocusMonitorName ~= context.sourceMonitorName
            local monitorResult = hl.dispatch(hl.dsp.focus({
                monitor = context.sourceMonitorName,
            }))
            local workspaceResult = dispatchSucceeded(monitorResult)
                and hl.dispatch(hl.dsp.focus({
                    workspace = firstWorkspace,
                    on_current_monitor = true,
                })) or nil
            if not dispatchSucceeded(workspaceResult) then
                retryWorkspaceMove(context, 24)
                return
            end
        end
        retryWorkspaceMove(context, 24)
        return
    end

    if sourceState == "empty" then
        retryWorkspaceMove(context, 24)
        return
    end

    if not updatePendingWorkspaceMove(context, {
        phase = "compacting",
        compactionHole = context.sourceWorkspace,
        stepFrom = 0,
        stepTo = 0,
    }) then
        retryWorkspaceMove(context, 24)
        return
    end
    resumeCompacting(context)
end

local function resumePreparedWorkspaceMove(context)
    local sourceState = workspaceStateForMove(context.sourceWorkspace)
    if sourceState == "unknown" then
        retryWorkspaceMove(context, 24)
        return
    end

    local movedWindow = windowFromSelector(context.windowSelector)
    local movedWorkspace = movedWindow and movedWindow.workspace or nil
    if movedWorkspace
        and tonumber(movedWorkspace.id) == context.sourceWorkspace then
        -- The pre-move WAL survived, but the compositor move did not commit.
        finishCompactionTransaction(context)
        return
    end
    if sourceState == "persistent" or sourceState == "occupied" then
        -- Other windows still occupy the source, so no compaction is needed.
        finishCompactionTransaction(context)
        return
    end

    -- A missing/closed/moved selector is not grounds to discard the WAL: an
    -- absent or empty source proves the mutation created a recoverable hole.
    if not updatePendingWorkspaceMove(context, {
        phase = "moved",
        compactionHole = context.sourceWorkspace,
        stepFrom = 0,
        stepTo = 0,
    }) then
        retryWorkspaceMove(context, 24)
        return
    end
    resumeMovedWorkspace(context)
end

resumeWorkspaceMove = function(context)
    if not workspaceMoveContextCurrent(context) then
        return
    end
    if not acquireWorkspaceMutationLock(context) then
        retryWorkspaceMove(context, 250)
        return
    end
    if workspaceCompactionBlocked() then
        refreshWorkspaceCompactionGate(context)
        releaseWorkspaceMutationLock(context)
        retryWorkspaceMove(context, 250)
        return
    end
    if not workspaceMoveOwnershipReady(context) then
        return
    end
    if workspaceGroupForCompaction(context.sourceWorkspace) ~= context.group
        or workspaceGroupForCompaction(context.compactionHole) ~= context.group then
        finishCompactionTransaction(context)
        return
    end

    if context.phase == "prepared" then
        resumePreparedWorkspaceMove(context)
    elseif context.phase == "moved" then
        resumeMovedWorkspace(context)
    elseif context.phase == "compacting" then
        resumeCompacting(context)
    elseif context.phase == "rename_prepared" then
        resumeRenamePrepared(context)
    else
        finishCompactionTransaction(context)
    end
end

local function kickWorkspaceMoveRecovery()
    if not workspaceMoveRecoveryNeedsKick then
        return
    end
    local context = workspaceMoveActiveContext
    if not context then
        workspaceMoveRecoveryNeedsKick = false
        workspaceMoveTransactionActive = false
        return
    end
    if not workspaceMoveContextCurrent(context) or not resumeWorkspaceMove then
        return
    end

    -- Last-resort event-driven fallback: if hl.timer construction failed twice,
    -- the next drag/queue pass resumes directly instead of leaving WAL ownership
    -- and queued requests permanently stranded.
    workspaceMoveRecoveryNeedsKick = false
    local ok = pcall(resumeWorkspaceMove, context)
    if not ok then
        workspaceMoveRecoveryNeedsKick = true
        emergencyWorkspaceMoveCleanup()
    end
end

local function performWindowMoveAndCompact(
    windowOrSelector, targetWorkspace, targetMonitorName)
    if not workspaceCompactionEpochCurrent() then
        return false
    end

    targetWorkspace = math.floor(tonumber(targetWorkspace) or 0)
    if workspaceGroupForCompaction(targetWorkspace) == nil
        or type(targetMonitorName) ~= "string"
        or targetMonitorName == ""
        or not workspaceMatchesMonitorGroup(
            targetWorkspace, targetMonitorName) then
        return false
    end

    local existingTarget = hl.get_workspace(targetWorkspace)
    if existingTarget and (not existingTarget.monitor
        or existingTarget.monitor.name ~= targetMonitorName) then
        return false
    end

    local window = windowFromSelector(windowOrSelector)
    local currentWorkspace = window and window.workspace or nil
    if not window or not currentWorkspace then
        return false
    end

    if tonumber(currentWorkspace.id) == targetWorkspace then
        return currentWorkspace.monitor
            and currentWorkspace.monitor.name == targetMonitorName
    end

    local sourceWorkspace = math.floor(tonumber(currentWorkspace.id) or 0)
    local sourceMonitorName = currentWorkspace.monitor
        and currentWorkspace.monitor.name or ""
    local sourceGroup = workspaceGroupForCompaction(sourceWorkspace)
    local sourceMonitor = sourceMonitorName ~= ""
        and hl.get_monitor(sourceMonitorName) or nil
    if not sourceMonitor
        or desktop_ui_monitor_role(
            sourceMonitor.name, sourceMonitor.id) == nil then
        return false
    end
    if sourceGroup ~= nil and workspaceGroupOwnershipStatus(
        sourceGroup, sourceMonitorName) ~= "ok" then
        return false
    end
    local focusedMonitor = hl.get_active_monitor()
    local focusedWorkspace = focusedMonitor and focusedMonitor.active_workspace or nil
    local focusedWindow = hl.get_active_window()
    local context = nil

    if sourceGroup ~= nil and sourceMonitorName ~= "" then
        context = {
            txid = nextWorkspaceMoveTxid(),
            ownerEpoch = workspaceCompactionGeneration,
            phase = "prepared",
            windowSelector = selectorForWindow(window),
            sourceWorkspace = sourceWorkspace,
            sourceMonitorName = sourceMonitorName,
            targetWorkspace = targetWorkspace,
            targetMonitorName = targetMonitorName,
            group = sourceGroup,
            originalFocusMonitorName = focusedMonitor and focusedMonitor.name or "",
            originalFocusWorkspace = focusedWorkspace
                and tonumber(focusedWorkspace.id) or nil,
            originalFocusWindowAddress = focusedWindow
                and focusedWindow.address or "",
            compactionHole = sourceWorkspace,
            stepFrom = 0,
            stepTo = 0,
            borrowedFocus = false,
            compactionGateOpen = false,
            pendingPersisted = false,
            ownsMoveLock = true,
            finished = false,
            finishing = false,
            mutationLockOwner = nil,
        }
        if not acquireWorkspaceMutationLock(context)
            or workspaceCompactionBlocked() then
            releaseWorkspaceMutationLock(context)
            return false
        end
        if not persistPendingWorkspaceMove(context) then
            releaseWorkspaceMutationLock(context)
            return false
        end
        workspaceMoveTransactionActive = true
        workspaceMoveActiveContext = context
    end

    local function commitWindowMove()
        if context then
            -- Freeze the bar before movewindow/destroyworkspace native events
            -- can paint an intermediate source-empty frame.
            beginWorkspaceCompactionGate(context)
        end

        if not context and workspaceCompactionBlocked() then
            return false
        end

        local target = hl.get_workspace(targetWorkspace)
        local fullscreenWindow = target and target.fullscreen_window or nil
        if fullscreenWindow and fullscreenWindow ~= window then
            clearWindowFullscreen(fullscreenWindow)
        end
        clearWindowFullscreen(window)

        local moveResult = hl.dispatch(hl.dsp.window.move({
            workspace = targetWorkspace,
            follow = false,
            window = window,
        }))
        if not dispatchSucceeded(moveResult) then
            if context then
                local liveWindow = windowFromSelector(context.windowSelector)
                local liveWorkspace = liveWindow and liveWindow.workspace or nil
                if liveWorkspace
                    and tonumber(liveWorkspace.id)
                        ~= context.sourceWorkspace then
                    updatePendingWorkspaceMove(context, { phase = "moved" })
                    if not scheduleWorkspaceMoveResume(context, 24) then
                        error("failed to arm workspace move recovery")
                    end
                    return true
                end
                finishCompactionTransaction(context)
            end
            return false
        end

        if context then
            -- The compositor mutation is now durable. If this phase write ever
            -- fails, prepared recovery infers commit from source occupancy.
            updatePendingWorkspaceMove(context, { phase = "moved" })
            if not scheduleWorkspaceMoveResume(context, 24) then
                error("failed to arm workspace move recovery")
            end
        end
        return true
    end

    -- The entire claimed direct-entry path is protected. Any exception before
    -- the main timer exists leaves the WAL owner intact and schedules recovery;
    -- prepared recovery safely clears if the compositor move never committed.
    local ok, moved = pcall(commitWindowMove)
    if not ok then
        if context then
            emergencyWorkspaceMoveCleanup()
        end
        return false
    end
    return moved
end

local function enqueueWorkspaceMove(
    windowOrSelector, targetWorkspace, targetMonitorName)
    local activeContext = workspaceMoveActiveContext
    if not workspaceCompactionEpochCurrent()
        or workspaceCompactionBlocked()
        or #workspaceMoveQueue >= 32
        or not activeContext
        -- Once any change_id is prepared or confirmed, a visually frozen bar
        -- may carry old numeric IDs (and its safety timer can later show live
        -- IDs). Reject that tiny late-drop window instead of translating an
        -- ambiguous ID and ever sending a window to the wrong workspace.
        or activeContext.phase == "rename_prepared"
        or activeContext.compactionHole ~= activeContext.sourceWorkspace then
        return false
    end
    local selector = type(windowOrSelector) == "string"
        and windowOrSelector or selectorForWindow(windowOrSelector)
    targetWorkspace = math.floor(tonumber(targetWorkspace) or 0)
    local targetGroup = workspaceGroupForCompaction(targetWorkspace)
    if type(selector) ~= "string"
        or targetGroup == nil
        or type(targetMonitorName) ~= "string"
        or targetMonitorName == ""
        or not workspaceMatchesMonitorGroup(
            targetWorkspace, targetMonitorName) then
        return false
    end

    local targetData = hl.get_workspace(targetWorkspace)
    if targetData and targetData.monitor
        and targetData.monitor.name ~= targetMonitorName then
        return false
    end
    local targetWasOccupied = false
    local targetWorkspaceObject = nil
    if targetData then
        local targetWindows = workspaceWindows(targetWorkspace)
        if not targetWindows then
            return false
        end
        targetWasOccupied = next(targetWindows) ~= nil
        if targetWasOccupied then
            -- Workspace userdata is the stable in-process identity: it keeps
            -- following change_id, and unlike one anchor window it does not
            -- jump away when an earlier queued request moves that window.
            targetWorkspaceObject = targetData
        end
    end

    workspaceMoveQueue[#workspaceMoveQueue + 1] = {
        windowSelector = selector,
        targetWorkspace = targetWorkspace,
        targetMonitorName = targetMonitorName,
        targetGroup = targetGroup,
        targetWorkspaceObject = targetWorkspaceObject,
        targetWasOccupied = targetWasOccupied,
        invalid = false,
    }
    return true
end

local function resolveQueuedWorkspaceTarget(request)
    if request.invalid
        or not workspaceMatchesMonitorGroup(
            request.targetWorkspace, request.targetMonitorName) then
        return nil
    end

    if request.targetWorkspaceObject then
        local ok, targetId, targetMonitor = pcall(function()
            local workspace = request.targetWorkspaceObject
            return math.floor(tonumber(workspace.id) or 0),
                workspace.monitor and workspace.monitor.name or ""
        end)
        if not ok
            or workspaceGroupForCompaction(targetId) ~= request.targetGroup
            or targetMonitor ~= request.targetMonitorName then
            return nil
        end
        return targetId
    end

    if request.targetWasOccupied then
        return nil
    end
    local targetId = math.floor(tonumber(request.targetWorkspace) or 0)
    if workspaceGroupForCompaction(targetId) ~= request.targetGroup then
        return nil
    end
    local state, workspace = workspaceStateForMove(targetId)
    if state == "unknown" or state == "occupied" then
        return nil
    end
    if workspace and workspace.monitor
        and workspace.monitor.name ~= request.targetMonitorName then
        return nil
    end
    return targetId
end

local function claimPendingWorkspaceMove(context)
    if workspaceMoveTransactionActive or workspaceMoveActiveContext then
        return false
    end

    local ownershipStatus = workspaceMoveContextOwnershipStatus(context)
    if ownershipStatus == "invalid" then
        -- Quarantine malformed topology by retiring only this txid-owned WAL.
        -- A failed clear leaves the non-empty file as a durable fail-closed
        -- fence; it is deliberately not converted into a polling loop.
        context.skipFocusRestore = true
        clearPendingWorkspaceMove(context)
        return false
    end

    -- Claim ownership synchronously, before the first recovery timer exists.
    -- A new drop from this point can only enter the FIFO queue.
    workspaceMoveTransactionActive = true
    workspaceMoveActiveContext = context
    context.ownsMoveLock = true
    context.finished = false
    context.finishing = false
    local activeMonitor = hl.get_active_monitor()
    context.borrowedFocus = context.originalFocusMonitorName ~= ""
        and context.originalFocusMonitorName ~= context.sourceMonitorName
        and activeMonitor
        and activeMonitor.name == context.sourceMonitorName
    beginWorkspaceCompactionGate(context)

    updatePendingWorkspaceMove(context, {
        ownerEpoch = workspaceCompactionGeneration,
    })
    if not scheduleWorkspaceMoveResume(context, 1) then
        emergencyWorkspaceMoveCleanup()
    end
    return true
end

local function moveWindowToWorkspaceAndCompact(
    windowOrSelector, targetWorkspace, targetMonitorName)
    kickWorkspaceMoveRecovery()
    if not workspaceMoveTransactionActive then
        local pending = readPendingWorkspaceMove()
        if pending then
            claimPendingWorkspaceMove(pending)
        end
    end
    if not workspaceMoveTransactionActive
        and readPendingWorkspaceMoveLine() ~= "" then
        return false
    end
    if workspaceMoveTransactionActive then
        return enqueueWorkspaceMove(
            windowOrSelector, targetWorkspace, targetMonitorName)
    end
    return performWindowMoveAndCompact(
        windowOrSelector, targetWorkspace, targetMonitorName)
end

processNextWorkspaceMove = function()
    kickWorkspaceMoveRecovery()
    if not workspaceMoveTransactionActive then
        local pending = readPendingWorkspaceMove()
        if pending then
            if claimPendingWorkspaceMove(pending) then
                return
            end
        end
        if readPendingWorkspaceMoveLine() ~= "" then
            return
        end
    end
    while not workspaceMoveTransactionActive and #workspaceMoveQueue > 0 do
        local request = table.remove(workspaceMoveQueue, 1)
        local resolvedTarget = resolveQueuedWorkspaceTarget(request)
        if resolvedTarget then
            performWindowMoveAndCompact(
                request.windowSelector,
                resolvedTarget,
                request.targetMonitorName
            )
        end
    end
end

local function firstAutomaticWorkspaceHole()
    local workspaces = hl.get_workspaces()
    if type(workspaces) ~= "table" then
        return nil, "retry"
    end

    -- Snapshot the mapped windows once. Calling get_workspace_windows() for
    -- every workspace makes a compaction scan scale with workspaces * windows,
    -- which is exactly the expensive case after closing one of many windows.
    local windows = hl.get_windows()
    if type(windows) ~= "table" then
        return nil, "retry"
    end
    local occupiedWorkspaceIds = {}
    for _, window in ipairs(windows) do
        local workspace = window and window.workspace or nil
        local id = math.floor(tonumber(workspace and workspace.id) or 0)
        if workspaceGroupForCompaction(id) ~= nil then
            occupiedWorkspaceIds[id] = true
        end
    end

    local entries = {}
    local groupEligible = {}
    for group = 0, 9 do
        entries[group] = {}
        groupEligible[group] = true
    end
    for _, workspace in ipairs(workspaces) do
        local id = math.floor(tonumber(workspace.id) or 0)
        local group = workspaceGroupForCompaction(id)
        if group ~= nil then
            entries[group][id] = {
                workspace = workspace,
                occupied = occupiedWorkspaceIds[id] == true,
            }
            if not workspaceObjectMatchesMonitorGroup(
                workspace, workspace.monitor and workspace.monitor.name or "") then
                groupEligible[group] = false
            end
        end
    end

    for group = 0, 9 do
        if groupEligible[group] then
            local groupStart = group * workspaceGroupSize + 1
            local groupEnd = groupStart + workspaceGroupSize - 1
            local expected = groupStart
            for id = groupStart, groupEnd do
                local entry = entries[group][id]
                if entry and entry.workspace.is_persistent then
                    -- A persistent workspace is a hard segment boundary. Gaps
                    -- on its left never pull windows across that reservation.
                    expected = id + 1
                elseif entry and entry.occupied then
                    if id > expected then
                        local successorMonitor = entry.workspace.monitor
                            and entry.workspace.monitor.name or ""
                        local holeEntry = entries[group][expected]
                        local holeMonitor = holeEntry
                            and holeEntry.workspace.monitor
                            and holeEntry.workspace.monitor.name
                            or successorMonitor
                        if successorMonitor == "" or holeMonitor == ""
                            or successorMonitor ~= holeMonitor
                            or not workspaceMatchesMonitorGroup(
                                expected, successorMonitor) then
                            -- A permanent ownership mismatch is not a transient
                            -- 80 ms retry. Skip this group and await topology or
                            -- workspace events that make it authoritative again.
                            break
                        end
                        return {
                            hole = expected,
                            group = group,
                            monitorName = successorMonitor,
                        }, "ok"
                    end
                    expected = id + 1
                end
            end
        end
    end
    return nil, "none"
end

local function startAutomaticWorkspaceCompaction(candidate)
    if workspaceMoveTransactionActive or workspaceMoveActiveContext
        or readPendingWorkspaceMoveLine() ~= ""
        or workspaceCompactionBlocked()
        or not workspaceCompactionEpochCurrent() then
        return false, "retry"
    end

    local hole = math.floor(tonumber(candidate and candidate.hole) or 0)
    local group = workspaceGroupForCompaction(hole)
    local monitorName = candidate and candidate.monitorName or ""
    if group == nil or group ~= candidate.group or monitorName == "" then
        return false, "invalid"
    end
    local ownershipStatus = workspaceGroupOwnershipStatus(group, monitorName)
    if ownershipStatus ~= "ok" then
        return false, ownershipStatus
    end

    local focusedMonitor = hl.get_active_monitor()
    local focusedWorkspace = focusedMonitor
        and focusedMonitor.active_workspace or nil
    local focusedWindow = hl.get_active_window()
    local context = {
        txid = nextWorkspaceMoveTxid(),
        ownerEpoch = workspaceCompactionGeneration,
        phase = "compacting",
        -- Compaction-only WAL records use a deliberately non-window selector.
        -- The compacting/rename_prepared recovery phases never dereference it.
        windowSelector = "auto-hole:" .. tostring(hole),
        sourceWorkspace = hole,
        sourceMonitorName = monitorName,
        targetWorkspace = hole,
        targetMonitorName = monitorName,
        group = group,
        originalFocusMonitorName = focusedMonitor and focusedMonitor.name or "",
        originalFocusWorkspace = focusedWorkspace
            and tonumber(focusedWorkspace.id) or nil,
        originalFocusWindowAddress = focusedWindow
            and focusedWindow.address or "",
        compactionHole = hole,
        stepFrom = 0,
        stepTo = 0,
        borrowedFocus = false,
        compactionGateOpen = false,
        pendingPersisted = false,
        ownsMoveLock = true,
        finished = false,
        finishing = false,
        mutationLockOwner = nil,
    }
    if not acquireWorkspaceMutationLock(context)
        or workspaceCompactionBlocked() then
        releaseWorkspaceMutationLock(context)
        return false, "retry"
    end
    if not persistPendingWorkspaceMove(context) then
        releaseWorkspaceMutationLock(context)
        return false, "retry"
    end

    workspaceMoveTransactionActive = true
    workspaceMoveActiveContext = context
    beginWorkspaceCompactionGate(context)
    if not scheduleWorkspaceMoveResume(context, 1) then
        emergencyWorkspaceMoveCleanup()
    end
    return true, "ok"
end

local runAutomaticWorkspaceCompactionScan
requestAutomaticWorkspaceCompaction = function(timeout)
    automaticWorkspaceCompactionRequested = true
    if automaticWorkspaceCompactionTimer then
        return
    end
    automaticWorkspaceCompactionTimer = true
    local ok, armed = pcall(function()
        return scheduleWorkspaceCompactionTask(
            timeout or automaticWorkspaceCompactionDebounceMs, function()
            automaticWorkspaceCompactionTimer = nil
            if runAutomaticWorkspaceCompactionScan then
                runAutomaticWorkspaceCompactionScan()
            end
        end)
    end)
    if not ok or not armed then
        automaticWorkspaceCompactionTimer = nil
    end
end

runAutomaticWorkspaceCompactionScan = function()
    if not automaticWorkspaceCompactionRequested
        or not workspaceCompactionEpochCurrent() then
        return
    end
    if workspaceMoveTransactionActive or workspaceMoveActiveContext then
        -- The transaction state machine schedules its own recovery and always
        -- requests a fresh scan when it finishes.
        automaticWorkspaceCompactionRequested = false
        return
    end
    if readPendingWorkspaceMoveLine() ~= "" then
        -- An unclaimed, malformed, or ownership-invalid WAL is a durable fence,
        -- not a reason to poll forever. A later workspace/topology event will
        -- request a new scan after the WAL becomes recoverable or is removed.
        automaticWorkspaceCompactionRequested = false
        return
    end
    if workspaceCompactionBlocked() then
        requestAutomaticWorkspaceCompaction(250)
        return
    end

    local candidate, status = firstAutomaticWorkspaceHole()
    if status == "retry" then
        requestAutomaticWorkspaceCompaction(80)
        return
    end
    if not candidate then
        automaticWorkspaceCompactionRequested = false
        return
    end

    automaticWorkspaceCompactionRequested = false
    local started, startStatus = startAutomaticWorkspaceCompaction(candidate)
    if not started and startStatus == "retry" then
        requestAutomaticWorkspaceCompaction(80)
    end
end

-- Keep ordered workspace groups dense no matter how the hole was created:
-- close/destroy, a normal keybind move, overview drag, or application launch.
for _, eventName in ipairs({
    "window.open",
    "window.close",
    "window.destroy",
    "window.move_to_workspace",
    "workspace.created",
    "workspace.removed",
    "monitor.layout_changed",
}) do
    hl.on(eventName, function()
        -- Keep compaction off the window-open/close animation hot path. Further
        -- events coalesce into this one quiet-period scan.
        requestAutomaticWorkspaceCompaction(
            automaticWorkspaceCompactionDebounceMs)
    end)
end

-- QML overview previews and real compositor window drags share this exact
-- mutation path.  The global name is intentionally narrow and replaced on
-- every config reload; old timer closures are fenced by the generation token.
-- Quickshell's Hyprland.dispatch wraps this expression in hl.dispatch(...),
-- so expose a dispatcher callback rather than executing during argument
-- evaluation and returning a boolean to the outer dispatch.
_G.end4_workspace_bar_move = function(
    windowSelector, targetWorkspace, targetMonitorName)
    return function()
        return moveWindowToWorkspaceAndCompact(
            windowSelector, targetWorkspace, targetMonitorName)
    end
end

local pendingWorkspaceMove = readPendingWorkspaceMove()
if pendingWorkspaceMove then
    -- A config reload destroys old Lua timers. The WAL owner is claimed now,
    -- not inside the 1 ms callback, so no drop can overwrite it in between.
    claimPendingWorkspaceMove(pendingWorkspaceMove)
end

-- Also repair a pre-existing hole on reload/startup, such as one left by a
-- window that was closed before this config version was loaded.
requestAutomaticWorkspaceCompaction(120)

local function finishWorkspaceDrop(button)
    if not workspaceDrop.active or workspaceDrop.button ~= button then
        return
    end

    -- Re-read the live bar map and sample once more on release.  This closes
    -- both the fast-final-movement race and an HDMI hot-unplug during drag.
    workspaceDrop.regions = readWorkspaceDropRegions()
    updateWorkspaceDropTarget()

    local window = workspaceDrop.window
    local targetWorkspace = workspaceDrop.targetWorkspace
    local targetMonitorName = workspaceDrop.targetMonitorName

    workspaceDrop.active = false
    workspaceDrop.button = nil
    workspaceDrop.window = nil
    workspaceDrop.regions = {}
    workspaceDrop.targetScreen = ""
    workspaceDrop.targetIndex = -1
    workspaceDrop.targetWorkspace = -1
    workspaceDrop.targetMonitorName = ""
    workspaceDrop.confirmed = false
    workspaceDrop.initialWindowX = nil
    workspaceDrop.initialWindowY = nil
    if workspaceDrop.timer then
        workspaceDrop.timer:set_enabled(false)
    end
    emitWorkspaceDropClear()

    if window and targetWorkspace > 0 and targetMonitorName ~= ""
        and hl.get_monitor(targetMonitorName) then
        moveWindowToWorkspaceAndCompact(
            window, targetWorkspace, targetMonitorName)
    end
end

-- Register the compositor drag first. Matching Lua binds run in declaration
-- order, so the tracker captures the actual window selected under the cursor.
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: Move" })
hl.bind("SUPER + mouse:272", function() beginWorkspaceDrop(272, true) end,
    { mouse = true, transparent = true })
hl.bind("SUPER + mouse:272", function() finishWorkspaceDrop(272) end,
    { release = true, transparent = true })
hl.bind("SUPER + mouse:274", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:274", function() beginWorkspaceDrop(274, true) end,
    { mouse = true, transparent = true })
hl.bind("SUPER + mouse:274", function() finishWorkspaceDrop(274) end,
    { release = true, transparent = true })

-- Client-side title bars request their drag only after receiving the click.
-- These non-consuming binds observe that ordinary LMB press/release without
-- stealing it from the application; geometry movement confirms it is really
-- a window drag before any workspace target can light or accept the drop.
hl.bind("mouse:272", function() beginWorkspaceDrop(272, false) end,
    { mouse = true, non_consuming = true, transparent = true })
hl.bind("mouse:272", function() finishWorkspaceDrop(272) end,
    { release = true, non_consuming = true, transparent = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Window: Resize" })
--#/# bind = SUPER + ←/↑/→/↓,, -- Focus in direction
for i = 1, 4 do
    local arrowkey = { "Left", "Right", "Up", "Down" }
    local focusdir = { "l", "r", "u", "d" }
    hl.bind("SUPER + " .. arrowkey[i], hl.dsp.focus({ direction = focusdir[i] }),
        { description = "Window: Focus " .. arrowkey[i] })
end
for i = 1, 2 do
    local arrowkey = { "BracketLeft", "BracketRight" }
    local focusdir = { "l", "r" }
    hl.bind("SUPER + " .. arrowkey[i], hl.dsp.focus({ direction = focusdir[i] }))
end
--#/# bind = SUPER + SHIFT, ←/↑/→/↓,, -- Move in direction
for i = 1, 4 do
    local arrowkey = { "Left", "Right", "Up", "Down" }
    local focusdir = { "l", "r", "u", "d" }
    hl.bind("SUPER + SHIFT + " .. arrowkey[i], hl.dsp.window.move({ direction = focusdir[i] }),
        { description = "Window: Move " .. arrowkey[i] })
end

hl.bind("ALT + F4", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("SUPER + SHIFT + ALT + Q", hl.dsp.exec_cmd("hyprctl kill"), { description = "Window: Forcefully zap a window" })
hl.bind("ALT + F9", hl.dsp.window.move({ workspace = "special:special", follow = false }),
    { description = "Window: Minimize (restore with Super+S)" })

local function cycleWindow(nextWindow)
    hl.dispatch(hl.dsp.window.cycle_next({ next = nextWindow }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end
hl.bind("ALT + Tab", function() cycleWindow(true) end, { description = "Window: Focus next" })
hl.bind("ALT + SHIFT + Tab", function() cycleWindow(false) end, { description = "Window: Focus previous" })

--# Window split ratio
--#/# binde = SUPER, ;/',, -- Adjust split ratio
hl.bind("SUPER + Semicolon", hl.dsp.layout("splitratio -0.1"), { repeating = true })
hl.bind("SUPER + Apostrophe", hl.dsp.layout("splitratio +0.1"), { repeating = true })
--# Positioning mode
hl.bind("SUPER + ALT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Float/Tile" })
hl.bind("SUPER + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),
    { description = "Window: Maximize" })
hl.bind("ALT + F10", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),
    { description = "Window: Maximize" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
    { description = "Window: Fullscreen" })
hl.bind("SUPER + ALT + F", hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }),
    { description = "Window: Fullscreen spoof" })
hl.bind("SUPER + P", hl.dsp.window.pin(), { description = "Window: Pin" })

-- Every workspace action resolves through the same monitor-local 10-slot
-- router. Hyprland's native +/- and r+/- selectors may cross a fixed group at
-- its 10/11 boundary, so they are deliberately not used below.
local function workspaceGroupBounds(monitor)
    local first = desktop_ui_workspace_for_monitor_slot(monitor, 1, true)
    if not first then
        return nil, nil
    end
    return first, first + workspaceGroupSize - 1
end

local function workspaceBelongsToMonitor(workspaceId, monitor)
    local workspace = hl.get_workspace(workspaceId)
    return not workspace or (workspace.monitor and workspace.monitor.name == monitor.name)
end

local function workspaceTargetForOffset(monitor, delta)
    local first, last = workspaceGroupBounds(monitor)
    if not first then
        return nil
    end
    local current = math.floor(tonumber(
        monitor.active_workspace and monitor.active_workspace.id) or 0)
    if current < first or current > last then
        -- A returned output can briefly report a workspace borrowed during
        -- the single-monitor merge. Treat its owner group's first slot as the
        -- presentation baseline so one wheel/key action can leave that
        -- deferred state without ever advancing into another monitor's group.
        current = first
    end
    local slot = (current - first + math.floor(tonumber(delta) or 0))
        % workspaceGroupSize
    return first + slot
end

local function focusWorkspaceOnMonitor(workspaceId, monitor)
    workspaceId = math.floor(tonumber(workspaceId) or 0)
    if not monitor or workspaceId < 1
        or not workspaceBelongsToMonitor(workspaceId, monitor) then
        return false
    end
    local activeMonitor = hl.get_active_monitor()
    if not activeMonitor or activeMonitor.name ~= monitor.name then
        local monitorResult = hl.dispatch(hl.dsp.focus({ monitor = monitor }))
        if not dispatchSucceeded(monitorResult) then
            return false
        end
    end
    local workspaceResult = hl.dispatch(hl.dsp.focus({
        workspace = workspaceId,
        on_current_monitor = true,
    }))
    if not dispatchSucceeded(workspaceResult) then
        return false
    end
    local refreshed = hl.get_monitor(monitor.name)
    local active = refreshed and refreshed.active_workspace
    return active and math.floor(tonumber(active.id) or 0) == workspaceId
end

local function focusWorkspaceSlot(slot)
    local monitor = hl.get_active_monitor()
    local workspaceId = desktop_ui_workspace_for_monitor_slot(
        monitor, slot, true)
    return focusWorkspaceOnMonitor(workspaceId, monitor)
end

local function focusWorkspaceOffset(delta)
    local monitor = hl.get_active_monitor()
    return focusWorkspaceOnMonitor(
        workspaceTargetForOffset(monitor, delta), monitor)
end

local function focusOccupiedWorkspaceOffset(delta)
    local monitor = hl.get_active_monitor()
    local first, last = workspaceGroupBounds(monitor)
    if not monitor or not first then
        return false
    end
    local candidates = {}
    for _, workspace in ipairs(hl.get_workspaces() or {}) do
        local id = math.floor(tonumber(workspace and workspace.id) or 0)
        if id >= first and id <= last and workspace.monitor
            and workspace.monitor.name == monitor.name then
            candidates[#candidates + 1] = id
        end
    end
    table.sort(candidates)
    if #candidates == 0 then
        return false
    end
    local current = math.floor(tonumber(
        monitor.active_workspace and monitor.active_workspace.id) or 0)
    local index = 1
    for candidateIndex, id in ipairs(candidates) do
        if id == current then
            index = candidateIndex
            break
        end
    end
    local step = math.floor(tonumber(delta) or 0)
    local targetIndex = ((index - 1 + step) % #candidates) + 1
    return focusWorkspaceOnMonitor(candidates[targetIndex], monitor)
end

local function moveActiveWindowToWorkspace(workspaceId)
    local monitor = hl.get_active_monitor()
    local window = hl.get_active_window()
    workspaceId = math.floor(tonumber(workspaceId) or 0)
    if not monitor or not window or workspaceId < 1
        or not workspaceBelongsToMonitor(workspaceId, monitor) then
        return false
    end
    return moveWindowToWorkspaceAndCompact(
        window, workspaceId, monitor.name)
end

local function moveActiveWindowToWorkspaceSlot(slot)
    local monitor = hl.get_active_monitor()
    return moveActiveWindowToWorkspace(
        desktop_ui_workspace_for_monitor_slot(monitor, slot, true))
end

local function moveActiveWindowToWorkspaceOffset(delta)
    local monitor = hl.get_active_monitor()
    return moveActiveWindowToWorkspace(
        workspaceTargetForOffset(monitor, delta))
end

-- Semantic compositor endpoints. QML sends connector + slot/offset and an
-- observed value only as a stale-state fence; numeric workspace ownership is
-- always recomputed here at dispatch time.
_G.end4_workspace_focus_slot = function(slot, targetMonitorName, observedTarget)
    return function()
        local monitor = hl.get_monitor(tostring(targetMonitorName or ""))
        local workspaceId = desktop_ui_workspace_for_monitor_slot(
            monitor, slot, true)
        local observed = math.floor(tonumber(observedTarget) or 0)
        if not monitor or not workspaceId
            or (observed > 0 and observed ~= workspaceId) then
            return false
        end
        return focusWorkspaceOnMonitor(workspaceId, monitor)
    end
end

_G.end4_workspace_focus_offset = function(delta, targetMonitorName, observedActive)
    return function()
        local monitor = hl.get_monitor(tostring(targetMonitorName or ""))
        local active = monitor and monitor.active_workspace or nil
        local activeId = math.floor(tonumber(active and active.id) or 0)
        local observed = math.floor(tonumber(observedActive) or 0)
        if not monitor or (observed > 0 and observed ~= activeId) then
            return false
        end
        return focusWorkspaceOnMonitor(
            workspaceTargetForOffset(monitor, delta), monitor)
    end
end

--#/# bind = SUPER+ALT, Hash,, -- Send to workspace -- (1, 2, 3,...)
for i = 1, 10 do
    hl.bind("SUPER + ALT + " .. (i % 10), function()
        moveActiveWindowToWorkspaceSlot(i)
    end, { description = "Window: Send to workspace " .. i })
end
--# We also use raw keycodes because some keyboard layouts register number keys as different chars. The codes can be verified with `wev`
-- for i = 1, 10 do
--     local numberkey = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }
--     hl.bind("SUPER + ALT + code:" .. numberkey[i], function()
--         hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = false }))
--     end)
-- end
--# keypad numbers
for i = 1, 10 do
    local numpadkey = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }
    hl.bind("SUPER + ALT + code:" .. numpadkey[i], function()
        moveActiveWindowToWorkspaceSlot(i)
    end)
end

--# #/# bind = SUPER+SHIFT, Scroll ↑/↓,, -- Send to workspace left/right
for i = 1, 4 do
    local key = { "SUPER + SHIFT + mouse_", "SUPER + ALT + mouse_" }
    local keycombos = { key[1] .. "down", key[1] .. "up", key[2] .. "down", key[2] .. "up" }
    local delta = { -1, 1, -1, 1 }
    hl.bind(keycombos[i], function()
        moveActiveWindowToWorkspaceOffset(delta[i])
    end)
end

--#/# bind = SUPER+SHIFT, Page_↑/↓,, -- Send to workspace left/right
for i = 1, 2 do
    local keydirs = { "Up", "Down" }
    local delta = { -1, 1 }
    local descdir = { "left", "right" }
    hl.bind("SUPER + SHIFT + Page_" .. keydirs[i], function()
        moveActiveWindowToWorkspaceOffset(delta[i])
    end, {description = "Window: Send to workspace " .. descdir[i]})
end
for i = 1, 4 do
    local key = { "SUPER + ALT + Page_", "CTRL + SUPER + SHIFT + " }
    local keycombos = { key[1] .. "down", key[1] .. "up", key[2] .. "Right", key[2] .. "Left" }
    local delta = { 1, -1, 1, -1 }
    hl.bind(keycombos[i], function()
        moveActiveWindowToWorkspaceOffset(delta[i])
    end) -- # [hidden]
end

hl.bind("SUPER + ALT + S",
    hl.dsp.window.move({ workspace = "special:special", follow = false }), { description = "Window: Send to scratchpad" })
hl.bind("CTRL + SUPER + S", hl.dsp.workspace.toggle_special("special"))

--##! Workspace
--# Switching
-- A layer-shell click does not make its output the compositor's active monitor.
-- Validate both the connector's group and any existing workspace owner before
-- focusing. Foreign workspaces are never moved by an ordinary UI action;
-- ownership changes belong exclusively to the hotplug transaction.
_G.end4_workspace_bar_focus = function(targetWorkspace, targetMonitorName)
    return function()
        local workspaceId = math.floor(tonumber(targetWorkspace) or 0)
        local monitorName = tostring(targetMonitorName or "")
        local monitor = hl.get_monitor(monitorName)
        local first, last = workspaceGroupBounds(monitor)
        if workspaceId < 1 or not monitor or not first
            or workspaceId < first or workspaceId > last then
            return false
        end
        local slot = workspaceId - first + 1
        return end4_workspace_focus_slot(
            slot, monitorName, workspaceId)()
    end
end

-- Use one number-row binding. Keeping both keysym and physical-keycode
-- bindings makes Hyprland dispatch the same workspace action twice. The
-- configured XKB layout stays `us`; the Chinese IME does not change it.
for i = 1, 10 do
    hl.bind("SUPER + " .. (i % 10), function()
        focusWorkspaceSlot(i)
    end, { description = "Workspace: Focus " .. i })
end
--# keypad numbers
for i = 1, 10 do
    local numpadkey = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }
    hl.bind("SUPER + code:" .. numpadkey[i], function()
        focusWorkspaceSlot(i)
    end)
end

--#/# bind = CTRL+SUPER, ←/→,, -- Focus left/right
--#/# bind = CTRL+SUPER+ALT, ←/→,, -- # [hidden] Focus busy left/right
for i = 1, 2 do
    local keys = { "Left", "Right" }
    local delta = { -1, 1 }
    local descdir = { "left", "right" }
    hl.bind("CTRL + SUPER + " .. keys[i], function()
        focusWorkspaceOffset(delta[i])
    end, {description = "Workspace: Focus " .. descdir[i]})
end
for i = 1, 2 do
    local keys = { "Left", "Right" }
    local delta = { -1, 1 }
    hl.bind("CTRL + SUPER + ALT + " .. keys[i], function()
        focusOccupiedWorkspaceOffset(delta[i])
    end)
end
--#/# bind = SUPER, Page_↑/↓,, -- Focus left/right
for i = 1, 4 do
    local key = { "SUPER + Page_Down", "SUPER + Page_Up" }
    local keycombos = { key[1], key[2], "CTRL + " .. key[1], "CTRL + " .. key[2] }
    local delta = { 1, -1, 1, -1 }
    hl.bind(keycombos[i], function()
        focusWorkspaceOffset(delta[i])
    end)
end
--#/# bind = SUPER, Scroll ↑/↓,, -- Focus left/right
for i = 1, 4 do
    local key = { "SUPER + mouse_up", "SUPER + mouse_down" }
    local keycombos = { key[1], key[2], "CTRL + " .. key[1], "CTRL + " .. key[2] }
    local delta = { 1, -1, 1, -1 }
    hl.bind(keycombos[i], function()
        focusWorkspaceOffset(delta[i])
    end)
end
--## Special
-- Super+S intentionally has no action; the old scratchpad/AI-like panel entry
-- is not exposed in the user-facing keymap.
for i = 1, 4 do
    local key = { "BracketLeft", "BracketRight", "Up", "Down" }
    local delta = { -1, 1, -5, 5 }
    hl.bind("CTRL + SUPER + " .. key[i], function()
        focusWorkspaceOffset(delta[i])
    end)
end

--##! Virtual machines
hl.define_submap("virtual-machine", function()
    hl.bind("SUPER + ALT + F1", function()
        local currentsubmap = hl.get_current_submap()
        if currentsubmap == "virtual-machine" then
            hl.dispatch(hl.dsp.exec_cmd(
                "notify-send 'Exited Virtual Machine submap' 'Keybinds re-enabled' -a 'Hyprland'"))
            hl.dispatch(hl.dsp.submap("reset"))
        elseif currentsubmap == "" then
            hl.dispatch(hl.dsp.exec_cmd(
                "notify-send 'Entered Virtual Machine submap' 'Keybinds disabled. hit SUPER+ALT+F1 to escape' -a 'Hyprland'"))
            hl.dispatch(hl.dsp.submap("virtual-machine"))
        end
    end, { submap_universal = true })
end)


--#!
--# Testing
hl.bind("SUPER + ALT + F11",
    hl.dsp.exec_cmd(
        "bash -c 'RANDOM_IMAGE=$(find ~/Pictures -type f | shuf -n 1); ACTION=$(notify-send \"Test notification with body image\" \"This notification should contain your user account <b>image</b> and <a href=\\\"https://discord.com/app\\\">Discord</a> <b>icon</b>. Oh and here is a random image in your Pictures folder: <img src=\\\"$RANDOM_IMAGE\\\" alt=\\\"Testing image\\\"/>\" -a \"Hyprland\" -p -h \"string:image-path:/var/lib/AccountsService/icons/$USER\" -t 6000 -i \"discord\" -A \"openImage=Profile image\" -A \"action2=Open the random image\" -A \"action3=Useless button\"); [[ $ACTION == *openImage ]] && xdg-open \"/var/lib/AccountsService/icons/$USER\"; [[ $ACTION == *action2 ]] && xdg-open \"$RANDOM_IMAGE\"'")
) -- # [hidden]
hl.bind("SUPER + ALT + F12",
    hl.dsp.exec_cmd(
        "bash -c 'RANDOM_IMAGE=$(find ~/Pictures -type f | shuf -n 1); ACTION=$(notify-send \"Test notification\" \"This notification should contain a random image in your <b>Pictures</b> folder and <a href=\\\"https://discord.com/app\\\">Discord</a> <b>icon</b>.\n<i>Flick right to dismiss!</i>\" -a \"Discord (fake)\" -p -h \"string:image-path:$RANDOM_IMAGE\" -t 6000 -i \"discord\" -A \"openImage=Profile image\" -A \"action2=Useless button\"); [[ $ACTION == *openImage ]] && xdg-open \"/var/lib/AccountsService/icons/$USER\"'")
)                                                                                                        -- # [hidden]
hl.bind("SUPER + ALT + Equal",
    hl.dsp.exec_cmd("notify-send 'Urgent notification' 'Ah hell no' -u critical -a 'Hyprland keybind'")) -- # [hidden]

--##! Session
hl.bind("SUPER + L", hl.dsp.exec_cmd("$HOME/.local/bin/secure-screen-lock --mark-session"), { description = "Session: Lock" })
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd("$HOME/.local/bin/uios-session-action suspend"),
    { locked = true, description = "Session: Sleep" }) -- Sleep
-- hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"), {locked = true} ) -- # [hidden] Suspend when laptop lid is closed, uncomment if for whatever reason it's not the default behavior

hl.bind("CTRL + SHIFT + ALT + SUPER + Delete", hl.dsp.exec_cmd("$HOME/.local/bin/uios-session-action poweroff"),
    { description = "Session: Shut down" }) -- # [hidden] Power off


--##! Apps
hl.bind("SUPER + Return", hl.dsp.exec_cmd(terminal), { description = "App: Terminal" })
hl.bind("SUPER + T", hl.dsp.exec_cmd(terminal))
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd(terminal))
hl.bind("SUPER + E", hl.dsp.exec_cmd(fileManager), { description = "App: File manager" })
hl.bind("SUPER + W", hl.dsp.exec_cmd(browser), { description = "App: Browser" })
hl.bind("SUPER + C", hl.dsp.exec_cmd(codeEditor), { description = "App: Code editor" })
hl.bind("CTRL + SUPER + SHIFT + ALT + W", hl.dsp.exec_cmd(officeSoftware), { description = "App: Office software" })
hl.bind("SUPER + X", hl.dsp.exec_cmd(textEditor), { description = "App: Text editor" })
hl.bind("CTRL + SUPER + V", hl.dsp.exec_cmd(volumeMixer), { description = "App: Volume mixer" })
hl.bind("SUPER + I", hl.dsp.exec_cmd(settingsApp), { description = "App: Settings app" })
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(taskManager), { description = "App: Task manager" })

--# Cursed stuff
--## Make window not amogus large
hl.bind("CTRL + SUPER + Backslash", hl.dsp.window.resize({ x = 640, y = 480, "exact" }))
