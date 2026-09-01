#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)"
# shellcheck disable=SC1091
source "$REPO_ROOT/manifests/versions.env"

APPLY=0
JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '2')
CACHE_HOME=${XDG_CACHE_HOME:-"$HOME/.cache"}
QT_PREFIX="$HOME/.local/opt/Qt/$QT_VERSION/gcc_64"
SOURCE_DIR="$CACHE_HOME/desktop-ui/sources/quickshell-$QUICKSHELL_COMMIT"
BUILD_DIR="$CACHE_HOME/desktop-ui/build/quickshell-$QUICKSHELL_COMMIT-qt$QT_VERSION"
QT_ABI=${QT_VERSION%.*}
QT_ABI=${QT_ABI//./}
INSTALL_PREFIX="$HOME/.local/opt/quickshell-qt$QT_ABI"

usage() {
    cat <<'EOF'
Usage: build-quickshell.sh [--apply] [--qt-prefix PATH] [--source-dir PATH]
                           [--build-dir PATH] [--install-prefix PATH] [--jobs N]

Fetch and build the exact Quickshell commit in manifests/versions.env. Default
is a non-mutating plan. Existing source directories must already be clean and
at the pinned commit; the script never reset/clean them destructively.
EOF
}

while (($#)); do
    case "$1" in
        --apply) APPLY=1 ;;
        --qt-prefix)
            (($# >= 2)) || { printf 'error: --qt-prefix needs a path\n' >&2; exit 2; }
            QT_PREFIX=$2; shift ;;
        --source-dir)
            (($# >= 2)) || { printf 'error: --source-dir needs a path\n' >&2; exit 2; }
            SOURCE_DIR=$2; shift ;;
        --build-dir)
            (($# >= 2)) || { printf 'error: --build-dir needs a path\n' >&2; exit 2; }
            BUILD_DIR=$2; shift ;;
        --install-prefix)
            (($# >= 2)) || { printf 'error: --install-prefix needs a path\n' >&2; exit 2; }
            INSTALL_PREFIX=$2; shift ;;
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

printf 'Quickshell pinned build (%s)\n' "$([[ $APPLY == 1 ]] && printf APPLY || printf DRY-RUN)"
printf 'source:  %s @ %s\n' "$QUICKSHELL_UPSTREAM" "$QUICKSHELL_COMMIT"
printf 'Qt:      %s (%s)\n' "$QT_PREFIX" "$QT_VERSION"
printf 'build:   %s\n' "$BUILD_DIR"
printf 'install: %s\n' "$INSTALL_PREFIX"

for command_name in git cmake ninja; do
    command -v "$command_name" >/dev/null 2>&1 || { printf 'error: missing build command: %s\n' "$command_name" >&2; exit 2; }
done
if ((APPLY)) && [[ ! -d "$QT_PREFIX" ]]; then
    printf 'error: Qt prefix does not exist: %s\n' "$QT_PREFIX" >&2
    exit 2
fi

if [[ ! -e "$SOURCE_DIR" ]]; then
    run mkdir -p -- "$(dirname -- "$SOURCE_DIR")"
    run git clone --filter=blob:none --no-checkout -- "$QUICKSHELL_UPSTREAM" "$SOURCE_DIR"
    run git -C "$SOURCE_DIR" fetch --depth=1 origin "$QUICKSHELL_COMMIT"
    run git -C "$SOURCE_DIR" checkout --detach "$QUICKSHELL_COMMIT"
elif [[ ! -d "$SOURCE_DIR/.git" ]]; then
    printf 'error: source exists but is not a Git checkout: %s\n' "$SOURCE_DIR" >&2
    exit 2
else
    actual_commit=$(git -C "$SOURCE_DIR" rev-parse HEAD)
    [[ "$actual_commit" == "$QUICKSHELL_COMMIT" ]] || {
        printf 'error: existing source is at %s, expected %s; choose another --source-dir\n' "$actual_commit" "$QUICKSHELL_COMMIT" >&2
        exit 2
    }
    [[ -z "$(git -C "$SOURCE_DIR" status --porcelain)" ]] || {
        printf 'error: existing source has local changes; refusing to build it\n' >&2
        exit 2
    }
    printf 'KEEP     clean pinned source checkout\n'
fi

run cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja \
    "-DCMAKE_BUILD_TYPE=Release" \
    "-DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX" \
    "-DCMAKE_PREFIX_PATH=$QT_PREFIX" \
    "-DBUILD_TESTING=OFF" \
    "-DDISTRIBUTOR=$QUICKSHELL_DISTRIBUTOR"
run cmake --build "$BUILD_DIR" --parallel "$JOBS"
run cmake --install "$BUILD_DIR"

if ((APPLY)); then
    output=$("$INSTALL_PREFIX/bin/qs" --version 2>&1 || true)
    [[ "$output" == *"Quickshell $QUICKSHELL_VERSION"* && "$output" == *"$QUICKSHELL_COMMIT"* ]] || {
        printf 'error: installed binary did not report the locked version: %s\n' "$output" >&2
        exit 1
    }
    printf 'Verified: %s\n' "$output"
    printf 'Add %s/bin to PATH or link qs explicitly; no current binary was overwritten.\n' "$INSTALL_PREFIX"
else
    printf 'No files changed. Add --apply after reviewing this build plan.\n'
fi
