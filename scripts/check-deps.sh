#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)"
MANIFEST_DIR="$REPO_ROOT/manifests"

MODE=all
PYTHON_BIN=""
STRICT_VERSIONS=0
required_missing=0
optional_missing=0
version_warnings=0

usage() {
    cat <<'EOF'
Usage: check-deps.sh [--all|--required|--optional] [--python PATH]
                     [--strict-versions]

Read-only dependency audit. Missing optional features never make the command
fail. Missing required commands/imports/fonts do. Version drift is a warning
unless --strict-versions is supplied.
EOF
}

while (($#)); do
    case "$1" in
        --all) MODE=all ;;
        --required) MODE=required ;;
        --optional) MODE=optional ;;
        --python)
            (($# >= 2)) || { printf 'error: --python needs a path\n' >&2; exit 2; }
            PYTHON_BIN=$2
            shift
            ;;
        --strict-versions) STRICT_VERSIONS=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'error: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [[ -z "$PYTHON_BIN" ]]; then
    state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
    if [[ -x "$state_home/quickshell/.venv/bin/python" ]]; then
        PYTHON_BIN="$state_home/quickshell/.venv/bin/python"
    else
        PYTHON_BIN=$(command -v python3 || true)
    fi
fi

section() {
    printf '\n== %s ==\n' "$1"
}

check_command_manifest() {
    local level=$1 file=$2 spec reason candidate found
    local -a alternatives=()

    while IFS=$'\t' read -r spec reason _; do
        [[ -n "$spec" && ${spec:0:1} != '#' ]] || continue
        found=""
        IFS='|' read -r -a alternatives <<< "$spec"
        for candidate in "${alternatives[@]}"; do
            if command -v "$candidate" >/dev/null 2>&1; then
                found=$(command -v "$candidate")
                break
            fi
        done
        if [[ -n "$found" ]]; then
            printf 'ok    %-34s %s\n' "$spec" "$found"
        else
            printf 'MISS  %-34s %s\n' "$spec" "$reason"
            if [[ "$level" == required ]]; then
                ((required_missing += 1))
            else
                ((optional_missing += 1))
            fi
        fi
    done < "$file"
}

check_python_manifest() {
    local level=$1 file=$2 module hint

    if [[ -z "$PYTHON_BIN" || ! -x "$PYTHON_BIN" ]]; then
        printf 'MISS  python interpreter                 cannot test imports\n'
        if [[ "$level" == required ]]; then
            ((required_missing += 1))
        else
            ((optional_missing += 1))
        fi
        return
    fi

    while IFS=$'\t' read -r module hint _; do
        [[ -n "$module" && ${module:0:1} != '#' ]] || continue
        if "$PYTHON_BIN" - "$module" >/dev/null 2>&1 <<'PY'
import importlib.util
import sys
raise SystemExit(0 if importlib.util.find_spec(sys.argv[1]) else 1)
PY
        then
            printf 'ok    python:%-27s %s\n' "$module" "$PYTHON_BIN"
        else
            printf 'MISS  python:%-27s %s\n' "$module" "$hint"
            if [[ "$level" == required ]]; then
                ((required_missing += 1))
            else
                ((optional_missing += 1))
            fi
        fi
    done < "$file"
}

check_fonts() {
    local family families
    if ! command -v fc-list >/dev/null 2>&1; then
        printf 'MISS  fc-list                            fontconfig is required to audit fonts\n'
        ((required_missing += 1))
        return
    fi
    families=$(fc-list : family 2>/dev/null || true)
    while IFS= read -r family; do
        [[ -n "$family" && ${family:0:1} != '#' ]] || continue
        if grep -Fqi -- "$family" <<< "$families"; then
            printf 'ok    font:%s\n' "$family"
        else
            printf 'MISS  font:%-29s required UI family\n' "$family"
            ((required_missing += 1))
        fi
    done < "$MANIFEST_DIR/required-fonts.txt"
}

check_flatpaks() {
    local app reference purpose installed
    if ! command -v flatpak >/dev/null 2>&1; then
        printf 'MISS  flatpak                            all Flatpak integrations unavailable\n'
        ((optional_missing += 1))
        return
    fi
    while IFS=$'\t' read -r app reference purpose _; do
        [[ -n "$app" && ${app:0:1} != '#' ]] || continue
        if flatpak info "$app" >/dev/null 2>&1; then
            installed=$(LC_ALL=C flatpak info "$app" 2>/dev/null | sed -n 's/^[[:space:]]*Version:[[:space:]]*//p' | head -n 1)
            [[ -n "$installed" ]] || installed=unknown
            printf 'ok    flatpak:%-26s installed=%s reference=%s\n' "$app" "$installed" "$reference"
        else
            printf 'MISS  flatpak:%-26s %s\n' "$app" "$purpose"
            ((optional_missing += 1))
        fi
    done < "$MANIFEST_DIR/optional-flatpaks.tsv"
}

version_result() {
    local label=$1 expected=$2 actual=$3 critical=${4:-0}
    if [[ "$actual" == "$expected" ]]; then
        printf 'ok    %-34s %s\n' "$label" "$actual"
        return
    fi
    printf 'DRIFT %-34s installed=%s expected=%s\n' "$label" "${actual:-missing}" "$expected"
    ((version_warnings += 1))
    if ((STRICT_VERSIONS || critical)); then
        ((required_missing += 1))
    fi
}

check_versions() {
    # versions.env is repository-owned declarative data; verify.sh validates its
    # grammar before deployment.
    # shellcheck disable=SC1091
    source "$MANIFEST_DIR/versions.env"

    local actual output qs_bin
    if command -v dpkg-query >/dev/null 2>&1; then
        actual=$(dpkg-query -W -f='${Version}' hyprland 2>/dev/null || true)
        version_result hyprland-package "$HYPRLAND_PACKAGE_VERSION" "$actual" 1
        actual=$(dpkg-query -W -f='${Version}' hypridle 2>/dev/null || true)
        version_result hypridle-package "$HYPRIDLE_PACKAGE_VERSION" "$actual"
        actual=$(dpkg-query -W -f='${Version}' hyprlock 2>/dev/null || true)
        version_result hyprlock-package "$HYPRLOCK_PACKAGE_VERSION" "$actual"
        actual=$(dpkg-query -W -f='${Version}' hyprsunset 2>/dev/null || true)
        version_result hyprsunset-package "$HYPRSUNSET_PACKAGE_VERSION" "$actual"
        actual=$(dpkg-query -W -f='${Version}' xdg-desktop-portal-hyprland 2>/dev/null || true)
        version_result xdg-desktop-portal-hyprland "$XDPH_PACKAGE_VERSION" "$actual"
    else
        printf 'WARN  dpkg-query                         package-version checks skipped\n'
        ((version_warnings += 1))
    fi

    qs_bin=$(command -v qs || command -v quickshell || true)
    if [[ -n "$qs_bin" ]]; then
        output=$($qs_bin --version 2>&1 || true)
        if [[ "$output" == *"Quickshell $QUICKSHELL_VERSION"* && "$output" == *"$QUICKSHELL_COMMIT"* ]]; then
            printf 'ok    %-34s %s @ %s\n' Quickshell "$QUICKSHELL_VERSION" "$QUICKSHELL_COMMIT"
        else
            printf 'DRIFT %-34s %s\n' Quickshell "${output:-version unavailable}"
            ((version_warnings += 1))
            if ((STRICT_VERSIONS)); then
                ((required_missing += 1))
            fi
        fi
    fi

    if command -v matugen >/dev/null 2>&1; then
        output=$(matugen --version 2>&1 || true)
        actual=${output##* }
        version_result Matugen "$MATUGEN_VERSION" "$actual"
    fi
}

for file in required-commands.tsv optional-commands.tsv required-python-imports.tsv optional-python-imports.tsv required-fonts.txt optional-flatpaks.tsv versions.env; do
    [[ -r "$MANIFEST_DIR/$file" ]] || { printf 'error: missing manifest: %s\n' "$MANIFEST_DIR/$file" >&2; exit 2; }
done

if [[ "$MODE" != optional ]]; then
    section 'Required commands'
    check_command_manifest required "$MANIFEST_DIR/required-commands.tsv"
    section "Required Python imports ($PYTHON_BIN)"
    check_python_manifest required "$MANIFEST_DIR/required-python-imports.tsv"
    section 'Required fonts'
    check_fonts
    section 'Pinned versions'
    check_versions
fi

if [[ "$MODE" != required ]]; then
    section 'Optional commands'
    check_command_manifest optional "$MANIFEST_DIR/optional-commands.tsv"
    section "Optional Python imports ($PYTHON_BIN)"
    check_python_manifest optional "$MANIFEST_DIR/optional-python-imports.tsv"
    section 'Optional Flatpaks'
    check_flatpaks
fi

section 'Summary'
printf 'required missing/drift: %d\n' "$required_missing"
printf 'optional unavailable:   %d\n' "$optional_missing"
printf 'version warnings:       %d\n' "$version_warnings"
if ((required_missing)); then
    printf 'Package-name hints: %s\n' "$MANIFEST_DIR/required-packages-ubuntu-noble.tsv"
    printf 'Python bootstrap:   bash %s/bootstrap-python.sh\n' "$SCRIPT_DIR"
    exit 1
fi
