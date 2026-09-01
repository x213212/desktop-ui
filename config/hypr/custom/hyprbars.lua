-- Native-looking server-side controls for clients which do not draw their own.
hl.config({
    plugin = {
        hyprbars = {
            enabled = true,
            bar_color = "rgb(202124)",
            bar_height = 34,
            -- A titlebar exists on every legacy/SSD window; never allocate a
            -- per-window blur pass for it when many windows are tiled.
            bar_blur = false,
            bar_title_enabled = true,
            bar_text_size = 13,
            bar_text_weight = "medium",
            bar_text_font = "Sans",
            bar_text_align = "center",
            bar_buttons_alignment = "right",
            bar_part_of_window = true,
            bar_precedence_over_border = true,
            bar_padding = 8,
            bar_button_padding = 8,
            -- Keep the controls visible: this is important for legacy clients
            -- such as Nemo which otherwise have no discoverable window actions.
            icon_on_hover = false,
            on_double_click = "hyprctl dispatch 'hl.dsp.window.fullscreen({mode=\"maximized\", action=\"toggle\"})'",
        },
    },
})

-- Buttons are declared right-to-left: close, maximize, minimize.
hl.plugin.hyprbars.add_button({
    bg_color = "rgb(e23b2e)",
    fg_color = "rgb(ffffff)",
    size = 14,
    icon = "×",
    action = "hyprctl dispatch 'hl.dsp.window.close()'",
})

-- Do not draw a second titlebar on clients which already provide native CSD.
-- Legacy/SSD clients (Nemo, LibreOffice, XWayland utilities, etc.) still get
-- the compositor titlebar and all three controls.
hl.window_rule({
    name = "hyprbars-native-csd",
    match = {
        class = "^(gnome-terminal-server|firefox|cinnamon-settings\\.py|org\\.gnome\\..*|org\\.gtk\\..*|org\\.cinnamon\\..*|org\\.remmina\\.Remmina|pavucontrol|org\\.pulseaudio\\.pavucontrol|nm-connection-editor|blueman-manager|code|Code|codium|VSCodium|google-chrome.*|chromium.*|brave-browser.*|steam|Spotify|discord|obsidian)$",
    },
    ["hyprbars:no_bar"] = true,
})

hl.plugin.hyprbars.add_button({
    bg_color = "rgb(3a9b59)",
    fg_color = "rgb(ffffff)",
    size = 14,
    icon = "□",
    action = "hyprctl dispatch 'hl.dsp.window.fullscreen({mode=\"maximized\", action=\"toggle\"})'",
})

hl.plugin.hyprbars.add_button({
    bg_color = "rgb(777777)",
    fg_color = "rgb(ffffff)",
    size = 14,
    icon = "—",
    action = "hyprctl dispatch 'hl.dsp.window.move({workspace=\"special:special\", follow=false})'",
})
