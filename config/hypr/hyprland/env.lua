local home_dir = os.getenv("HOME")

-- Hyprland sources this file again on every reload.  Merge colon-separated
-- search paths once, preserving custom entries without multiplying them on
-- each reload.
local function unique_paths(...)
    local result = {}
    local seen = {}
    for _, value in ipairs({ ... }) do
        for path in string.gmatch(value or "", "[^:]+") do
            if path ~= "" and not seen[path] then
                seen[path] = true
                table.insert(result, path)
            end
        end
    end
    return table.concat(result, ":")
end

-- User-local programs installed for end4-pC (quickshell, matugen, etc.)
local path_old = os.getenv("PATH") or "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
hl.env("PATH", unique_paths(home_dir .. "/.local/bin", path_old))

-- Wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Traditional Chinese input (Fcitx5 + Chewing)
hl.env("GTK_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")

-- Applications
local xdg_data_dirs_old = os.getenv("XDG_DATA_DIRS") or ""
hl.env("XDG_DATA_DIRS", unique_paths(
    home_dir .. "/.local/share",
    home_dir .. "/.local/share/flatpak/exports/share",
    "/var/lib/flatpak/exports/share",
    "/usr/local/share",
    "/usr/share",
    xdg_data_dirs_old
))

-- Themes
hl.env("GTK_THEME", "Mint-Y-Dark-Aqua")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
-- Follow the system GTK dark preference in Qt 5/6 applications too.
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("XDG_MENU_PREFIX", "plasma-")

-- Virtual environment
hl.env("ILLOGICAL_IMPULSE_VIRTUAL_ENV", home_dir .. "/.local/state/quickshell/.venv")
