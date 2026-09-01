#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)"
# shellcheck disable=SC1091
source "$REPO_ROOT/manifests/versions.env"

APPLY=0
JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '2')
CACHE_HOME=${XDG_CACHE_HOME:-"$HOME/.cache"}
SOURCE_DIR="$CACHE_HOME/desktop-ui/sources/hyprland-plugins-$HYPRLAND_PLUGINS_COMMIT"
BUILD_DIR="$CACHE_HOME/desktop-ui/build/hyprbars-$HYPRLAND_PLUGINS_COMMIT"
INSTALL_DIR="$HOME/.local/lib/hyprland-plugins"

usage() {
    cat <<'EOF'
Usage: build-hyprbars.sh [--apply] [--source-dir PATH] [--build-dir PATH]
                         [--install-dir PATH] [--jobs N]

Build the pinned hyprbars plugin only when the installed Hyprland package
matches its ABI lock. Default is a plan. This never loads the plugin, changes
Hyprland config, or restarts the compositor.
EOF
}

while (($#)); do
    case "$1" in
        --apply) APPLY=1 ;;
        --source-dir)
            (($# >= 2)) || { printf 'error: --source-dir needs a path\n' >&2; exit 2; }
            SOURCE_DIR=$2; shift ;;
        --build-dir)
            (($# >= 2)) || { printf 'error: --build-dir needs a path\n' >&2; exit 2; }
            BUILD_DIR=$2; shift ;;
        --install-dir)
            (($# >= 2)) || { printf 'error: --install-dir needs a path\n' >&2; exit 2; }
            INSTALL_DIR=$2; shift ;;
        --jobs)
            (($# >= 2)) || { printf 'error: --jobs needs a number\n' >&2; exit 2; }
            JOBS=$2; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'error: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { printf 'error: --jobs must be a positive integer\n' >&2; exit 2; }
if ((APPLY && EUID == 0)); then
    printf 'error: run as the target desktop user, not root\n' >&2
    exit 2
fi

run() {
    printf '       '
    printf '%q ' "$@"
    printf '\n'
    if ((APPLY)); then
        "$@"
    fi
    return 0
}

for command_name in git make pkg-config install; do
    command -v "$command_name" >/dev/null 2>&1 || { printf 'error: missing build command: %s\n' "$command_name" >&2; exit 2; }
done

if command -v dpkg-query >/dev/null 2>&1; then
    installed_hyprland=$(dpkg-query -W -f='${Version}' hyprland 2>/dev/null || true)
    if [[ "$installed_hyprland" != "$HYPRLAND_PACKAGE_VERSION" ]]; then
        printf 'error: Hyprland ABI mismatch: installed=%s expected=%s\n' \
            "${installed_hyprland:-missing}" "$HYPRLAND_PACKAGE_VERSION" >&2
        exit 2
    fi
else
    printf 'error: cannot prove the Hyprland ABI without dpkg-query; do not build blindly\n' >&2
    exit 2
fi

printf 'hyprbars pinned build (%s)\n' "$([[ $APPLY == 1 ]] && printf APPLY || printf DRY-RUN)"
printf 'Hyprland: %s\n' "$installed_hyprland"
printf 'source:    %s @ %s\n' "$HYPRLAND_PLUGINS_UPSTREAM" "$HYPRLAND_PLUGINS_COMMIT"
printf 'build:     %s\n' "$BUILD_DIR"
printf 'install:   %s/%s\n' "$INSTALL_DIR" "$HYPRBARS_INSTALL_NAME"

if [[ ! -e "$SOURCE_DIR" ]]; then
    run mkdir -p -- "$(dirname -- "$SOURCE_DIR")"
    run git clone --filter=blob:none --no-checkout -- "$HYPRLAND_PLUGINS_UPSTREAM" "$SOURCE_DIR"
    run git -C "$SOURCE_DIR" fetch --depth=1 origin "$HYPRLAND_PLUGINS_COMMIT"
    run git -C "$SOURCE_DIR" checkout --detach "$HYPRLAND_PLUGINS_COMMIT"
elif [[ ! -d "$SOURCE_DIR/.git" ]]; then
    printf 'error: source exists but is not a Git checkout: %s\n' "$SOURCE_DIR" >&2
    exit 2
else
    actual_commit=$(git -C "$SOURCE_DIR" rev-parse HEAD)
    [[ "$actual_commit" == "$HYPRLAND_PLUGINS_COMMIT" ]] || {
        printf 'error: existing source is at %s, expected %s; choose another --source-dir\n' "$actual_commit" "$HYPRLAND_PLUGINS_COMMIT" >&2
        exit 2
    }
    [[ -z "$(git -C "$SOURCE_DIR" status --porcelain)" ]] || {
        printf 'error: existing source has local changes; refusing to build it\n' >&2
        exit 2
    }
    printf 'KEEP     clean pinned source checkout\n'
fi

run mkdir -p -- "$BUILD_DIR"
run cp -a -- "$SOURCE_DIR/hyprbars/." "$BUILD_DIR/"
run make -C "$BUILD_DIR" -j "$JOBS"
run mkdir -p -- "$INSTALL_DIR"
run install -m 0755 -- "$BUILD_DIR/$HYPRBARS_INSTALL_NAME" "$INSTALL_DIR/$HYPRBARS_INSTALL_NAME"

if ((APPLY)); then
    [[ -s "$INSTALL_DIR/$HYPRBARS_INSTALL_NAME" ]] || { printf 'error: installed plugin is empty/missing\n' >&2; exit 1; }
    printf 'Installed plugin verified. It was not loaded and Hyprland was not restarted.\n'
else
    printf 'No files changed. Add --apply after reviewing this ABI-locked build plan.\n'
fi
