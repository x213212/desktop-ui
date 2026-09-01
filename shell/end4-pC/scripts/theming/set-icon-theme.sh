#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 desktop-ui contributors

# Apply an icon theme to GSettings, GTK, and XSettings consumers.
set -euo pipefail

usage() {
    printf 'Usage: %s ICON_THEME\n' "${0##*/}" >&2
}

if (( $# != 1 )) || [[ -z $1 ]]; then
    usage
    exit 64
fi

theme=$1
if [[ $theme =~ [[:cntrl:]] ]]; then
    printf '%s: theme names cannot contain control characters\n' "${0##*/}" >&2
    exit 64
fi

acquire_theme_lock() {
    command -v flock >/dev/null 2>&1 || return 0
    local lock_root=${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}
    local previous_umask
    mkdir -p -- "$lock_root"
    previous_umask=$(umask)
    umask 077
    exec 9>"$lock_root/desktop-ui-theming-${UID}.lock"
    umask "$previous_umask"
    flock 9
}

resolve_config_target() {
    local path=$1
    if [[ -L $path ]] && command -v realpath >/dev/null 2>&1; then
        realpath -m -- "$path"
    else
        printf '%s\n' "$path"
    fi
}

update_settings_ini() {
    local destination
    destination=$(resolve_config_target "$1")
    local key=$2
    local value=$3
    local directory=${destination%/*}
    local temporary
    local line
    local in_settings=0
    local found_settings=0
    local wrote_key=0

    mkdir -p -- "$directory"
    temporary=$(mktemp "${destination}.tmp.XXXXXX")

    if [[ -f $destination ]]; then
        while IFS= read -r line || [[ -n $line ]]; do
            if [[ $line =~ ^[[:space:]]*\[Settings\][[:space:]]*$ ]]; then
                in_settings=1
                found_settings=1
                printf '%s\n' "$line" >>"$temporary"
                continue
            fi

            if (( in_settings )) && [[ $line =~ ^[[:space:]]*\[.*\][[:space:]]*$ ]]; then
                if (( ! wrote_key )); then
                    printf '%s=%s\n' "$key" "$value" >>"$temporary"
                    wrote_key=1
                fi
                in_settings=0
            fi

            if (( in_settings )) && [[ $line =~ ^[[:space:]]*${key}[[:space:]]*= ]]; then
                if (( ! wrote_key )); then
                    printf '%s=%s\n' "$key" "$value" >>"$temporary"
                    wrote_key=1
                fi
                continue
            fi
            printf '%s\n' "$line" >>"$temporary"
        done <"$destination"
    fi

    if (( ! found_settings )); then
        [[ ! -s $temporary ]] || printf '\n' >>"$temporary"
        printf '[Settings]\n%s=%s\n' "$key" "$value" >>"$temporary"
    elif (( in_settings && ! wrote_key )); then
        printf '%s=%s\n' "$key" "$value" >>"$temporary"
    fi

    if [[ -e $destination ]]; then
        chmod --reference="$destination" "$temporary" 2>/dev/null || true
    else
        chmod 0644 "$temporary"
    fi
    mv -f -- "$temporary" "$destination"
}

update_line_setting() {
    local destination
    destination=$(resolve_config_target "$1")
    local key=$2
    local rendered=$3
    local directory=${destination%/*}
    local temporary
    local line
    local wrote_key=0

    mkdir -p -- "$directory"
    temporary=$(mktemp "${destination}.tmp.XXXXXX")

    if [[ -f $destination ]]; then
        while IFS= read -r line || [[ -n $line ]]; do
            if [[ $line =~ ^[[:space:]]*${key}([[:space:]]|=) ]]; then
                if (( ! wrote_key )); then
                    printf '%s\n' "$rendered" >>"$temporary"
                    wrote_key=1
                fi
            else
                printf '%s\n' "$line" >>"$temporary"
            fi
        done <"$destination"
    fi

    if (( ! wrote_key )); then
        printf '%s\n' "$rendered" >>"$temporary"
    fi

    if [[ -e $destination ]]; then
        chmod --reference="$destination" "$temporary" 2>/dev/null || true
    else
        chmod 0644 "$temporary"
    fi
    mv -f -- "$temporary" "$destination"
}

try_gsettings() {
    local schema=$1
    local key=$2
    local value=$3
    command -v gsettings >/dev/null 2>&1 || return 0
    if [[ $(gsettings writable "$schema" "$key" 2>/dev/null || true) == true ]]; then
        gsettings set "$schema" "$key" "$value" 2>/dev/null || true
    fi
}

acquire_theme_lock

try_gsettings org.gnome.desktop.interface icon-theme "$theme"
update_settings_ini "$HOME/.config/gtk-3.0/settings.ini" gtk-icon-theme-name "$theme"
update_settings_ini "$HOME/.config/gtk-4.0/settings.ini" gtk-icon-theme-name "$theme"

quoted_theme=${theme//\\/\\\\}
quoted_theme=${quoted_theme//\"/\\\"}
update_line_setting "$HOME/.gtkrc-2.0" gtk-icon-theme-name \
    "gtk-icon-theme-name=\"$quoted_theme\""
update_line_setting "$HOME/.config/xsettingsd/xsettingsd.conf" Net/IconThemeName \
    "Net/IconThemeName \"$quoted_theme\""

if command -v pgrep >/dev/null 2>&1 \
        && pgrep -u "$(id -u)" -x xsettingsd >/dev/null 2>&1; then
    pkill -HUP -u "$(id -u)" -x xsettingsd 2>/dev/null || true
fi
