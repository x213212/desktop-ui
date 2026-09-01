#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)"
APPLY=0
PYTHON_BIN=${PYTHON_BIN:-python3}
STATE_HOME=${XDG_STATE_HOME:-"$HOME/.local/state"}
VENV_PATH="$STATE_HOME/quickshell/.venv"

usage() {
    cat <<'EOF'
Usage: bootstrap-python.sh [--apply] [--python PATH] [--venv PATH]

Create/update the Quickshell helper venv from exact direct pins. Default is a
read-only plan. The venv inherits distro PyGObject/GnomeDesktop packages via
--system-site-packages. No account, token, keyring or application state is read.
EOF
}

while (($#)); do
    case "$1" in
        --apply) APPLY=1 ;;
        --python)
            (($# >= 2)) || { printf 'error: --python needs a path\n' >&2; exit 2; }
            PYTHON_BIN=$2
            shift
            ;;
        --venv)
            (($# >= 2)) || { printf 'error: --venv needs a path\n' >&2; exit 2; }
            VENV_PATH=$2
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'error: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if ((APPLY && EUID == 0)); then
    printf 'error: run as the target desktop user, not root\n' >&2
    exit 2
fi
command -v "$PYTHON_BIN" >/dev/null 2>&1 || { printf 'error: Python not found: %s\n' "$PYTHON_BIN" >&2; exit 2; }
[[ -f "$REPO_ROOT/manifests/python-requirements.lock" ]] || { printf 'error: requirements lock missing\n' >&2; exit 2; }

run() {
    printf '       '
    printf '%q ' "$@"
    printf '\n'
    if ((APPLY)); then
        "$@"
    fi
    return 0
}

printf 'Quickshell Python environment (%s)\n' "$([[ $APPLY == 1 ]] && printf APPLY || printf DRY-RUN)"
printf 'venv: %s\n' "$VENV_PATH"

if [[ -e "$VENV_PATH" && ! -f "$VENV_PATH/pyvenv.cfg" ]]; then
    printf 'error: refusing non-venv target: %s\n' "$VENV_PATH" >&2
    exit 2
fi

if [[ ! -f "$VENV_PATH/pyvenv.cfg" ]]; then
    run mkdir -p -- "$(dirname -- "$VENV_PATH")"
    run "$PYTHON_BIN" -m venv --system-site-packages "$VENV_PATH"
else
    printf 'KEEP     existing venv\n'
fi

run "$VENV_PATH/bin/python" -m pip install --requirement "$REPO_ROOT/manifests/python-requirements.lock"

if ((APPLY)); then
    bash "$SCRIPT_DIR/check-deps.sh" --required --python "$VENV_PATH/bin/python"
else
    printf 'No files changed. Add --apply to create/update the venv.\n'
fi
