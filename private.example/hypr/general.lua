-- Copy the blocks you need into ~/.config/hypr/custom/general.lua, then use
-- `hyprctl devices` to replace these placeholder device names.
hl.device({
    name = "your-touchpad-device-name",
    sensitivity = 0.25,
    accel_profile = "adaptive",
    disable_while_typing = false,
    scroll_factor = 0.8
})

hl.device({
    name = "your-pointing-stick-device-name",
    sensitivity = 0.0,
    accel_profile = "adaptive",
    middle_button_emulation = false,
    scroll_method = "on_button_down",
    scroll_button = 274,
    scroll_button_lock = false
})
