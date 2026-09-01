#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)"

APPLY=0
FORCE=0
INCLUDE_INTEGRATIONS=0
INSTALL_FONTS=0
ENABLE_CORE_UNITS=0
conflicts=0
changes=0
unit_changes=0

usage() {
    cat <<'EOF'
Usage: install.sh [--apply] [--force] [--include-integrations]
                  [--install-fonts] [--enable-core-units]

Without --apply, print a deployment plan only. Existing targets are never
overwritten unless --force is explicit; forced targets are moved to an XDG
state backup. PAM/LightDM/system files and credentials are never installed.
EOF
}

while (($#)); do
    case "$1" in
        --apply) APPLY=1 ;;
        --force) FORCE=1 ;;
        --include-integrations) INCLUDE_INTEGRATIONS=1 ;;
        --install-fonts) INSTALL_FONTS=1 ;;
        --enable-core-units) ENABLE_CORE_UNITS=1 ;;
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
STATE_HOME=${XDG_STATE_HOME:-"$HOME/.local/state"}
BIN_HOME="$HOME/.local/bin"
UNIT_HOME="$CONFIG_HOME/systemd/user"
BACKUP_ROOT="$STATE_HOME/desktop-ui/backups/$(date -u +%Y%m%dT%H%M%SZ)"
VIDEOS_HOME=""
if command -v xdg-user-dir >/dev/null 2>&1; then
    VIDEOS_HOME=$(xdg-user-dir VIDEOS 2>/dev/null || true)
fi
[[ -n "$VIDEOS_HOME" && "$VIDEOS_HOME" != "$HOME" ]] || VIDEOS_HOME="$HOME/Videos"

mode_word=DRY-RUN
((APPLY)) && mode_word=APPLY
printf 'desktop-ui installer (%s)\n' "$mode_word"
printf 'repository: %s\n' "$REPO_ROOT"
printf 'config:     %s\n' "$CONFIG_HOME"
printf 'data:       %s\n' "$DATA_HOME"
printf 'state:      %s\n' "$STATE_HOME"

print_cmd() {
    printf '       '
    printf '%q ' "$@"
    printf '\n'
}

run() {
    print_cmd "$@"
    if ((APPLY)); then
        "$@"
    fi
    return 0
}

backup_path_for() {
    local target=$1 relative
    if [[ "$target" == "$HOME/"* ]]; then
        relative=${target#"$HOME/"}
    else
        relative="absolute/${target#/}"
    fi
    printf '%s/%s' "$BACKUP_ROOT" "$relative"
}

prepare_conflict() {
    local target=$1 backup
    if ((!FORCE)); then
        printf 'CONFLICT %s (kept; use --force to back it up)\n' "$target"
        ((conflicts += 1))
        return 1
    fi
    backup=$(backup_path_for "$target")
    if [[ -e "$backup" || -L "$backup" ]]; then
        printf 'error: backup target already exists: %s\n' "$backup" >&2
        exit 2
    fi
    printf 'BACKUP   %s -> %s\n' "$target" "$backup"
    run mkdir -p -- "$(dirname -- "$backup")"
    run mv -- "$target" "$backup"
}

install_link() {
    local source=$1 target=$2 expected actual
    if [[ ! -e "$source" && ! -L "$source" ]]; then
        printf 'error: deployment source missing: %s\n' "$source" >&2
        exit 2
    fi
    expected=$(realpath -m -- "$source")
    if [[ -L "$target" ]]; then
        actual=$(realpath -m -- "$target")
        if [[ "$actual" == "$expected" ]]; then
            printf 'KEEP     %s -> %s\n' "$target" "$expected"
            return
        fi
    fi
    if [[ -e "$target" || -L "$target" ]]; then
        prepare_conflict "$target" || return 0
    fi
    printf 'LINK     %s -> %s\n' "$target" "$expected"
    run mkdir -p -- "$(dirname -- "$target")"
    run ln -s -- "$expected" "$target"
    ((changes += 1))
}

install_seed_once() {
    local source=$1 target=$2
    if [[ ! -f "$source" ]]; then
        printf 'error: mutable seed missing: %s\n' "$source" >&2
        exit 2
    fi
    if [[ -f "$target" && ! -L "$target" ]]; then
        printf 'KEEP     %s (mutable local state is never overwritten)\n' "$target"
        return
    fi
    if [[ -e "$target" || -L "$target" ]]; then
        prepare_conflict "$target" || return 0
    fi
    printf 'SEED     %s <- %s\n' "$target" "$source"
    run mkdir -p -- "$(dirname -- "$target")"
    run cp -p -- "$source" "$target"
    ((changes += 1))
}

install_seed_directory_once() {
    local source=$1 target=$2
    if [[ ! -d "$source" ]]; then
        printf 'error: mutable seed directory missing: %s\n' "$source" >&2
        exit 2
    fi
    if [[ -d "$target" && ! -L "$target" ]]; then
        printf 'KEEP     %s (mutable local directory is never overwritten)\n' "$target"
        return
    fi
    if [[ -e "$target" || -L "$target" ]]; then
        prepare_conflict "$target" || return 0
    fi
    printf 'SEED     %s <- %s\n' "$target" "$source"
    run mkdir -p -- "$(dirname -- "$target")"
    run cp -a -- "$source" "$target"
    ((changes += 1))
}

install_config_seed_once() {
    local source=$1 target=$2
    if [[ ! -f "$source" ]]; then
        printf 'error: mutable config seed missing: %s\n' "$source" >&2
        exit 2
    fi
    if [[ -f "$target" && ! -L "$target" ]]; then
        printf 'KEEP     %s (mutable local state is never overwritten)\n' "$target"
        return
    fi
    if [[ -e "$target" || -L "$target" ]]; then
        prepare_conflict "$target" || return 0
    fi
    printf 'SEED     %s <- %s (expand XDG paths)\n' "$target" "$source"
    if ((APPLY)); then
        mkdir -p -- "$(dirname -- "$target")"
        python3 - "$source" "$target" "$DATA_HOME" "$VIDEOS_HOME" <<'PY'
import json
import os
from pathlib import Path
import sys
import tempfile

source, target, data_home, videos_home = map(Path, sys.argv[1:])
text = source.read_text(encoding="utf-8")
text = text.replace("@DATA_HOME@", str(data_home)).replace("@VIDEOS_HOME@", str(videos_home))
if "@DATA_HOME@" in text or "@VIDEOS_HOME@" in text:
    raise SystemExit("unexpanded path token in config seed")
json.loads(text)
target.parent.mkdir(parents=True, exist_ok=True)
descriptor, temporary = tempfile.mkstemp(prefix=".config.json.", dir=target.parent)
try:
    os.fchmod(descriptor, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        handle.write(text)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, target)
finally:
    try:
        os.unlink(temporary)
    except FileNotFoundError:
        pass
PY
    fi
    ((changes += 1))
}

install_directory_entries() {
    local source_dir=$1 target_dir=$2 file name skip_name skip found=0
    shift 2
    while IFS= read -r -d '' file; do
        found=1
        name=${file##*/}
        skip=0
        for skip_name in "$@"; do
            [[ "$name" == "$skip_name" ]] && skip=1
        done
        ((skip)) && continue
        install_link "$file" "$target_dir/$name"
    done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -print0 | sort -z)
    ((found)) || printf 'NOTE     no deployable entries in %s\n' "$source_dir"
}

for path in \
    shell/end4-pC \
    config/fcitx5 \
    config/hypr \
    config/illogical-impulse \
    bin \
    systemd/user/core \
    assets/wallpapers; do
    [[ -d "$REPO_ROOT/$path" ]] || { printf 'error: required source directory missing: %s\n' "$path" >&2; exit 2; }
done

if ((APPLY)); then
    printf '\nPreflight repository verification\n'
    bash "$SCRIPT_DIR/verify.sh"
fi

printf '\nCore configuration\n'
install_link "$REPO_ROOT/shell/end4-pC" "$CONFIG_HOME/quickshell/end4-pC"
install_seed_once "$REPO_ROOT/config/fcitx5/config" "$CONFIG_HOME/fcitx5/config"
install_seed_once "$REPO_ROOT/config/fcitx5/profile" "$CONFIG_HOME/fcitx5/profile"
install_directory_entries "$REPO_ROOT/config/hypr" "$CONFIG_HOME/hypr" custom hyprland hyprlock hyprlock.conf
install_seed_directory_once "$REPO_ROOT/config/hypr/custom" "$CONFIG_HOME/hypr/custom"
install_directory_entries "$REPO_ROOT/config/hypr/hyprland" "$CONFIG_HOME/hypr/hyprland" shellOverrides
install_seed_directory_once "$REPO_ROOT/config/hypr/hyprland/shellOverrides" "$CONFIG_HOME/hypr/hyprland/shellOverrides"
install_directory_entries "$REPO_ROOT/config/hypr/hyprlock" "$CONFIG_HOME/hypr/hyprlock" colors.conf
install_seed_once "$REPO_ROOT/config/hypr/hyprlock/colors.conf" "$CONFIG_HOME/hypr/hyprlock/colors.conf"
install_seed_once "$REPO_ROOT/config/hypr/hyprlock.conf" "$CONFIG_HOME/hypr/hyprlock.conf"
install_directory_entries "$REPO_ROOT/config/illogical-impulse" "$CONFIG_HOME/illogical-impulse" config.json translations
install_seed_directory_once "$REPO_ROOT/config/illogical-impulse/translations" "$CONFIG_HOME/illogical-impulse/translations"
install_config_seed_once "$REPO_ROOT/config/illogical-impulse/config.json" "$CONFIG_HOME/illogical-impulse/config.json"

printf '\nUser helpers\n'
install_directory_entries "$REPO_ROOT/bin" "$BIN_HOME"

printf '\nCore user units\n'
install_directory_entries "$REPO_ROOT/systemd/user/core" "$UNIT_HOME"
unit_changes=1

if ((INCLUDE_INTEGRATIONS)); then
    [[ -d "$REPO_ROOT/systemd/user/integrations" ]] || { printf 'error: integration unit directory missing\n' >&2; exit 2; }
    printf '\nOptional integration units (installed, never enabled automatically)\n'
    install_directory_entries "$REPO_ROOT/systemd/user/integrations" "$UNIT_HOME"
    unit_changes=1
else
    printf '\nSKIP     integration units (use --include-integrations)\n'
fi

printf '\nWallpapers\n'
install_directory_entries "$REPO_ROOT/assets/wallpapers" "$DATA_HOME/backgrounds"

if ((INSTALL_FONTS)); then
    [[ -d "$REPO_ROOT/assets/fonts" ]] || { printf 'error: font asset directory missing\n' >&2; exit 2; }
    printf '\nOptional repository fonts\n'
    install_directory_entries "$REPO_ROOT/assets/fonts" "$DATA_HOME/fonts/desktop-ui"
    if command -v fc-cache >/dev/null 2>&1; then
        run fc-cache -f "$DATA_HOME/fonts/desktop-ui"
    fi
else
    printf '\nSKIP     repository fonts (use --install-fonts)\n'
fi

if ((APPLY && unit_changes)); then
    run systemctl --user daemon-reload
fi

if ((ENABLE_CORE_UNITS)); then
    printf '\nExplicit core unit enablement\n'
    while IFS= read -r unit; do
        [[ -n "$unit" && ${unit:0:1} != '#' ]] || continue
        [[ -e "$UNIT_HOME/$unit" || -L "$UNIT_HOME/$unit" ]] || {
            printf 'error: unit selected for enablement is not installed: %s\n' "$unit" >&2
            exit 2
        }
        run systemctl --user enable --now "$unit"
    done < "$REPO_ROOT/manifests/core-autostart-units.txt"
fi

printf '\nSummary: changes=%d conflicts=%d mode=%s\n' "$changes" "$conflicts" "$mode_word"
if ((FORCE && conflicts == 0)); then
    printf 'Backups, if any: %s\n' "$BACKUP_ROOT"
fi
printf 'Not touched: /etc, system/, credentials, caches, Quickshell user state, session state.\n'
((conflicts == 0))
