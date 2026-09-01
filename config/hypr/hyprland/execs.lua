-- put former exec-once commands inside the func and former exec commands outside
hl.on("hyprland.start", function ()

    -- Import this compositor's environment first, then restore the desktop.
    -- Session-bound background services start only after the restore has
    -- committed, so they cannot compete with application launch or fail
    -- before WAYLAND_DISPLAY exists.
    local importSessionEnvironment = "dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XAUTHORITY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE PATH GTK_IM_MODULE QT_IM_MODULE XMODIFIERS SDL_IM_MODULE"
    hl.exec_cmd(importSessionEnvironment .. " && systemctl --user restart secure-lock-before-sleep.service")
    hl.exec_cmd(importSessionEnvironment .. " && systemctl --user restart fcitx5.service")
    hl.exec_cmd(importSessionEnvironment .. " && systemctl --user start --no-block quickshell-ui.service")
    hl.exec_cmd(importSessionEnvironment .. " && (nice -n 10 $HOME/.local/bin/hypr-session-state login --quiet; systemctl --user restart hypridle.service; systemctl --user start --no-block uios-restore-report.service)")

    -- Bar, wallpaper
    hl.exec_cmd("$HOME/.config/hypr/hyprland/scripts/start_geoclue_agent.sh")
    hl.exec_cmd("bash $HOME/.config/hypr/custom/scripts/__restore_video_wallpaper.sh")

    -- Core components (authentication, lock screen, notification daemon)
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("nm-applet --indicator")
    -- Clipboard: history
    --hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("wl-paste --type text --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")
    hl.exec_cmd("wl-paste --type image --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
end)
