#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)"
APPLY=0
INCLUDE_INTEGRATIONS=0
DISABLE_CORE_UNITS=0
removed=0
skipped=0
unit_changes=0

usage() {
    cat <<'EOF'
Usage: uninstall.sh [--apply] [--include-integrations] [--disable-core-units]

Without --apply, print a removal plan. Only exact symlinks owned by this
repository are unlinked. Mutable config copies, backups, credentials, runtime
state and system files are always retained.
EOF
}

while (($#)); do
    case "$1" in
        --apply) APPLY=1 ;;
        --include-integrations) INCLUDE_INTEGRATIONS=1 ;;
        --disable-core-units) DISABLE_CORE_UNITS=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'error: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if ((APPLY && EUID == 0)); then
    printf 'error: run as the target desktop user, not root\n' >&2
    exit 2
fi

CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}
BIN_HOME="$HOME/.local/bin"
UNIT_HOME="$CONFIG_HOME/systemd/user"

run() {
    printf '       '
    printf '%q ' "$@"
    printf '\n'
    if ((APPLY)); then
        "$@"
    fi
    return 0
}

remove_owned_link() {
    local source=$1 target=$2 expected actual
    expected=$(realpath -m -- "$source")
    if [[ ! -L "$target" ]]; then
        if [[ -e "$target" ]]; then
            printf 'KEEP     %s (not a symlink)\n' "$target"
        else
            printf 'ABSENT   %s\n' "$target"
        fi
        ((skipped += 1))
        return
    fi
    actual=$(realpath -m -- "$target")
    if [[ "$actual" != "$expected" ]]; then
        printf 'KEEP     %s -> %s (not owned by this checkout)\n' "$target" "$actual"
        ((skipped += 1))
        return
    fi
    printf 'UNLINK   %s\n' "$target"
    run unlink -- "$target"
    ((removed += 1))
}

remove_entries() {
    local source_dir=$1 target_dir=$2 file name skip_name skip
    shift 2
    [[ -d "$source_dir" ]] || return
    while IFS= read -r -d '' file; do
        name=${file##*/}
        skip=0
        for skip_name in "$@"; do
            [[ "$name" == "$skip_name" ]] && skip=1
        done
        ((skip)) && continue
        remove_owned_link "$file" "$target_dir/$name"
    done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -print0 | sort -z)
}

printf 'desktop-ui uninstaller (%s)\n' "$([[ $APPLY == 1 ]] && printf APPLY || printf DRY-RUN)"

if ((DISABLE_CORE_UNITS)); then
    printf '\nExplicit core unit disablement\n'
    while IFS= read -r unit; do
        [[ -n "$unit" && ${unit:0:1} != '#' ]] || continue
        run systemctl --user disable --now "$unit"
    done < "$REPO_ROOT/manifests/core-autostart-units.txt"
fi

printf '\nCore configuration\n'
remove_owned_link "$REPO_ROOT/shell/end4-pC" "$CONFIG_HOME/quickshell/end4-pC"
remove_entries "$REPO_ROOT/config/hypr" "$CONFIG_HOME/hypr" custom hyprland hyprlock hyprlock.conf
remove_entries "$REPO_ROOT/config/hypr/hyprland" "$CONFIG_HOME/hypr/hyprland" shellOverrides
remove_entries "$REPO_ROOT/config/hypr/hyprlock" "$CONFIG_HOME/hypr/hyprlock" colors.conf
printf 'KEEP     %s (mutable Hyprland custom directory)\n' "$CONFIG_HOME/hypr/custom"
printf 'KEEP     %s (shell-managed Hyprland overrides)\n' "$CONFIG_HOME/hypr/hyprland/shellOverrides"
printf 'KEEP     %s and %s (mutable lock-screen files)\n' "$CONFIG_HOME/hypr/hyprlock.conf" "$CONFIG_HOME/hypr/hyprlock/colors.conf"
remove_entries "$REPO_ROOT/config/illogical-impulse" "$CONFIG_HOME/illogical-impulse" config.json translations
printf 'KEEP     %s (mutable seed/runtime config)\n' "$CONFIG_HOME/illogical-impulse/config.json"
printf 'KEEP     %s (mutable generated translations)\n' "$CONFIG_HOME/illogical-impulse/translations"

printf '\nUser helpers and units\n'
remove_entries "$REPO_ROOT/bin" "$BIN_HOME"
remove_entries "$REPO_ROOT/systemd/user/core" "$UNIT_HOME"
unit_changes=1
if ((INCLUDE_INTEGRATIONS)); then
    remove_entries "$REPO_ROOT/systemd/user/integrations" "$UNIT_HOME"
else
    printf 'SKIP     integration units (use --include-integrations)\n'
fi

printf '\nAssets\n'
remove_entries "$REPO_ROOT/assets/wallpapers" "$DATA_HOME/backgrounds"
remove_entries "$REPO_ROOT/assets/fonts" "$DATA_HOME/fonts/desktop-ui"

if ((APPLY && unit_changes)) && command -v systemctl >/dev/null 2>&1; then
    run systemctl --user daemon-reload
fi

printf '\nSummary: owned links=%d kept/absent=%d mode=%s\n' \
    "$removed" "$skipped" "$([[ $APPLY == 1 ]] && printf APPLY || printf DRY-RUN)"
printf 'Retained: mutable UI/Hyprland seeds, backups, credentials, runtime/session state and all system files.\n'
