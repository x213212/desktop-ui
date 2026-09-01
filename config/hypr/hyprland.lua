-- This file sources other files in `hyprland` and `custom` folders
-- You wanna add your stuff in files in `custom`

-- Internal stuff --
require("hyprland.lib")
require("hyprland.services")

-- Load the compositor-side titlebar used only by clients which do not draw
-- their own native window controls (for example Nemo).  Plugin loading from a
-- Lua config is two-phase: Hyprland loads it after the first parse and then
-- automatically reloads the config.  Guarding the custom module keeps that
-- first parse clean.
local hyprbarsPlugin = HOME .. "/.local/lib/hyprland-plugins/hyprbars.so"
hl.plugin.load(hyprbarsPlugin)

local function isPluginLoaded(name)
    for _, plugin in ipairs(hl.get_loaded_plugins()) do
        if plugin.name == name then
            return true
        end
    end
    return false
end

-- Environment variables --
require("hyprland.env")
if is_file_exists(HOME .. "/.config/hypr/custom/env.lua") then
    require("custom.env")
end

-- Default configurations --
require("hyprland.execs")
require("hyprland.general")
require("hyprland.rules")
require("hyprland.colors")
require("hyprland.keybinds")

-- Custom configurations --
if is_file_exists(HOME .. "/.config/hypr/custom/general.lua") then
    require("custom.general")
end
if is_file_exists(HOME .. "/.config/hypr/custom/rules.lua") then
    require("custom.rules")
end
if isPluginLoaded("hyprbars") and is_file_exists(HOME .. "/.config/hypr/custom/hyprbars.lua") then
    require("custom.hyprbars")
end
if is_file_exists(HOME .. "/.config/hypr/custom/keybinds.lua") then
    require("custom.keybinds")
end

-- nwg-displays support --
if is_file_exists(HOME .. "/.config/hypr/workspaces.lua") then
    require("workspaces")
end
if is_file_exists(HOME .. "/.config/hypr/monitors.lua") then
    require("monitors")
end

-- Shell overrides --
require("hyprland.shellOverrides.main")
