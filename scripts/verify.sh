#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)"
DEPLOYED=0
failures=0
warnings=0
passes=0

usage() {
    cat <<'EOF'
Usage: verify.sh [--deployed]

Read-only repository validation. With --deployed, also check expected XDG
targets. The script never reads credential stores or runtime-state contents.
EOF
}

while (($#)); do
    case "$1" in
        --deployed) DEPLOYED=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'error: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

pass() { printf 'ok    %s\n' "$*"; ((passes += 1)); }
warn() { printf 'WARN  %s\n' "$*"; ((warnings += 1)); }
fail() { printf 'FAIL  %s\n' "$*"; ((failures += 1)); }
section() { printf '\n== %s ==\n' "$1"; }

check_required_paths() {
    local rel
    local -a required=(
        README.md
        CONTRIBUTING.md
        SECURITY.md
        LICENSE
        THIRD_PARTY_NOTICES.md
        LICENSES/GPL-3.0-only.txt
        LICENSES/GPL-3.0-or-later.txt
        LICENSES/Apache-2.0.txt
        LICENSES/MIT.txt
        LICENSES/CC-BY-4.0.txt
        .gitignore
        manifests/versions.env
        manifests/checksums.sha256
        manifests/required-commands.tsv
        manifests/optional-commands.tsv
        manifests/python-requirements.lock
        shell/end4-pC/shell.qml
        shell/end4-pC/WorkspaceDragState.qml
        config/fcitx5/config
        config/fcitx5/profile
        config/hypr/hyprland.lua
        config/hypr/hypridle.conf
        config/hypr/hyprlock.conf
        config/illogical-impulse/config.json
        private.example/weather.env
        private.example/host.env
        private.example/hypr/general.lua
        private.example/waynergy/README.md
        .github/workflows/ci.yml
        assets/wallpapers/uíos-landscape.jpg
        assets/showcase/README.md
        assets/showcase/desktop.webp
        assets/showcase/lock-screen.webp
        assets/showcase/notifications.webp
        shell/end4-pC/assets/fonts/MaterialSymbolsRounded.ttf
        shell/end4-pC/assets/material_symbols_rounded.codepoints
        shell/end4-pC/assets/material_symbols_rounded.json
        shell/end4-pC/assets/icons/README.md
        shell/end4-pC/assets/images/default_wallpaper.svg
        shell/end4-pC/assets/images/default_wallpaper.png
        scripts/build-default-wallpaper.sh
        scripts/build-shaders.sh
        scripts/generate-material-symbols.py
        shell/end4-pC/scripts/wallpapers/download-online-wallpaper.py
        bin/hypr-session-state
        bin/secure-screen-lock
        bin/secure-lock-before-sleep
        bin/uios-session-action
        bin/uios-restore-report
        bin/p14s-lid-debounce
        bin/update-lock-weather
        bin/hyprlock-weather-motion
        bin/open-remmina
        bin/unstick-keys
        bin/magick
        systemd/user/core/quickshell-ui.service
        systemd/user/core/fcitx5.service
        systemd/user/core/hypr-session-autosave.service
        systemd/user/core/secure-lock-before-sleep.service
        systemd/user/core/uios-restore-report.service
        systemd/user/core/update-lock-weather.service
        systemd/user/core/update-lock-weather.timer
        systemd/user/integrations/p14s-lid-debounce.service
    )
    for rel in "${required[@]}"; do
        if [[ -e "$REPO_ROOT/$rel" || -L "$REPO_ROOT/$rel" ]]; then
            pass "$rel present"
        else
            fail "$rel missing"
        fi
    done
}

check_provenance() {
    local file rel notice_hits legacy_hits qsb_bin source_count artifact_count
    local shader_dir="$REPO_ROOT/shell/end4-pC/modules/ii/background/shaders"
    local notice="$REPO_ROOT/THIRD_PARTY_NOTICES.md"
    local failures_before=$failures

    if cmp --silent -- "$REPO_ROOT/LICENSE" "$REPO_ROOT/LICENSES/GPL-3.0-only.txt" \
        && cmp --silent -- "$REPO_ROOT/LICENSE" "$REPO_ROOT/shell/end4-pC/LICENSE"; then
        pass 'GPL-3.0-only texts are identical'
    else
        fail 'root, SPDX, and vendored-shell GPL texts differ'
    fi

    local marker_failures_before=$failures
    local -a notice_terms=(
        'pctrade/end4-pC'
        'end-4/dots-hyprland'
        'caelestia-dots/shell'
        'farzher/fuzzysort'
        'lemire/FastPriorityQueue.js'
        'difference-engine/thumbnail-generator-ubuntu'
        'Knugel/rounded-polygon-ts'
        'google/material-design-icons'
        'koeqaife/hyprland-material-you'
        'NyarchAssistant'
        'dln/wofi-emoji'
        'muan/emojilib'
        'Natural Earth'
        'cYrMQA7a3Wc'
        'Open-Meteo.com'
        'open-meteo.com/en/licence'
        'CC BY 4.0'
        'non-commercial'
        'latitude and longitude'
        'Wallhaven'
        'Unsplash'
        'download endpoint'
    )
    if [[ ! -f "$notice" ]]; then
        fail 'THIRD_PARTY_NOTICES.md is unavailable for marker validation'
    else
        for notice_hits in "${notice_terms[@]}"; do
            if rg -Fq -- "$notice_hits" "$notice"; then
                ((passes += 1))
            else
                fail "third-party notice missing provenance marker: $notice_hits"
            fi
        done
    fi
    if ((failures == marker_failures_before)); then
        pass 'required third-party provenance markers are present'
    fi

    local -a weather_attribution_paths=(
        shell/end4-pC/modules/common/widgets/OpenMeteoAttribution.qml
        shell/end4-pC/modules/ii/bar/WeatherPopup.qml
        shell/end4-pC/modules/ii/background/widgets/weather/WeatherWidget.qml
        shell/end4-pC/modules/ii/background/widgets/usercard/UserCardWidget.qml
        shell/end4-pC/modules/ii/lock/LockSurface.qml
        config/hypr/hyprlock.conf
    )
    for rel in "${weather_attribution_paths[@]}"; do
        if rg -Fq -- 'OpenMeteoAttribution' "$REPO_ROOT/$rel" \
            || rg -Fq -- 'Open-Meteo.com' "$REPO_ROOT/$rel"; then
            ((passes += 1))
        else
            fail "weather view lacks Open-Meteo attribution: $rel"
        fi
    done
    if rg -Fq -- 'https://open-meteo.com/' \
        "$REPO_ROOT/shell/end4-pC/modules/common/widgets/OpenMeteoAttribution.qml"; then
        pass 'interactive weather attribution links to Open-Meteo'
    else
        fail 'interactive weather attribution lacks the Open-Meteo link'
    fi

    # shellcheck disable=SC1091
    source "$REPO_ROOT/manifests/versions.env"
    source_count=$(find "$shader_dir" -maxdepth 1 -type f -name '*.frag' | wc -l)
    artifact_count=$(find "$shader_dir" -maxdepth 1 -type f -name '*.frag.qsb' | wc -l)
    [[ "$source_count" == "$TRANSITION_SHADER_COUNT" ]] \
        && pass "$source_count transition shader sources present" \
        || fail "transition shader sources=$source_count expected=$TRANSITION_SHADER_COUNT"
    [[ "$artifact_count" == "$TRANSITION_SHADER_COUNT" ]] \
        && pass "$artifact_count transition shader artifacts present" \
        || fail "transition shader artifacts=$artifact_count expected=$TRANSITION_SHADER_COUNT"

    while IFS= read -r -d '' file; do
        rel=${file#"$REPO_ROOT/"}
        [[ -f "${file%.qsb}" ]] \
            || fail "generated shader has no corresponding source: $rel"
    done < <(find "$shader_dir" -maxdepth 1 -type f -name '*.frag.qsb' -print0)

    while IFS= read -r -d '' file; do
        rel=${file#"$REPO_ROOT/"}
        [[ -s "$file.qsb" ]] \
            || fail "shader source has no generated artifact: $rel"
        rg -q '^// SPDX-License-Identifier: GPL-3\.0-only$' "$file" \
            || fail "shader source lacks GPL SPDX header: $rel"
    done < <(find "$shader_dir" -maxdepth 1 -type f -name '*.frag' -print0)

    qsb_bin=$(command -v qsb || true)
    if [[ -z "$qsb_bin" ]]; then
        [[ -x "$HOME/.local/opt/Qt/$QT_VERSION/gcc_64/bin/qsb" ]] \
            && qsb_bin="$HOME/.local/opt/Qt/$QT_VERSION/gcc_64/bin/qsb"
    fi
    if [[ -n "$qsb_bin" ]]; then
        if "$REPO_ROOT/scripts/build-shaders.sh" --check --qsb "$qsb_bin"; then
            pass 'generated shaders reproduce byte-for-byte'
        else
            fail 'generated shaders do not match their GPL sources'
        fi
    else
        warn 'qsb missing; shader source/artifact pairing checked but rebuild comparison skipped'
    fi

    legacy_hits=$(rg --with-filename -n \
        --glob '!verify.sh' \
        '(git\.outfoxxed\.me/outfoxxed/nixnew|quickshell-mirror/quickshell-examples|unix\.stackexchange\.com/a/602935)' \
        "$REPO_ROOT/shell" "$REPO_ROOT/config" "$REPO_ROOT/bin" \
        "$REPO_ROOT/scripts" 2>/dev/null || true)
    if [[ -n "$legacy_hits" ]]; then
        fail 'active source tree still references a prohibited no-license or legacy source:'
        printf '%s\n' "$legacy_hits"
    else
        pass 'active source tree excludes replaced no-license and legacy-source references'
    fi

    while IFS= read -r -d '' file; do
        fail "compiled QML cache checked into worktree: ${file#"$REPO_ROOT/"}"
    done < <(find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o \
        -type f -name '*.qmlc' -print0)

    if ((failures == failures_before)); then
        pass 'licensing and corresponding-source checks completed'
    fi
}

check_lock_grammar() {
    local line key value line_no=0 failures_before=$failures
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_no += 1))
        [[ -n "$line" && ${line:0:1} != '#' ]] || continue
        if [[ "$line" != *=* ]]; then
            fail "manifests/versions.env:$line_no is not KEY=VALUE"
            continue
        fi
        key=${line%%=*}
        value=${line#*=}
        [[ "$key" =~ ^[A-Z][A-Z0-9_]*$ ]] || fail "manifests/versions.env:$line_no invalid key"
        if [[ -z "$value" || "$value" =~ [[:space:]] || "$value" == *\$* || "$value" == *\`* || "$value" == *\;* || "$value" == *\&* || "$value" == *\|* || "$value" == *\(* || "$value" == *\)* ]]; then
            fail "manifests/versions.env:$line_no unsafe value"
        fi
    done < "$REPO_ROOT/manifests/versions.env"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/manifests/versions.env"
    [[ "$LOCK_FORMAT_VERSION" == 1 ]] || fail 'unsupported LOCK_FORMAT_VERSION'
    [[ "$END4_PC_BASE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || fail 'invalid END4_PC_BASE_COMMIT'
    [[ "$QUICKSHELL_COMMIT" =~ ^[0-9a-f]{40}$ ]] || fail 'invalid QUICKSHELL_COMMIT'
    [[ "$MATERIAL_SYMBOLS_COMMIT" =~ ^[0-9a-f]{40}$ ]] || fail 'invalid MATERIAL_SYMBOLS_COMMIT'
    [[ "$HYPRLAND_PLUGINS_COMMIT" =~ ^[0-9a-f]{40}$ ]] || fail 'invalid HYPRLAND_PLUGINS_COMMIT'
    [[ "$WALLPAPER_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail 'invalid WALLPAPER_SHA256'
    [[ "$MATERIAL_SYMBOLS_TTF_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail 'invalid MATERIAL_SYMBOLS_TTF_SHA256'
    [[ "$MATERIAL_SYMBOLS_CODEPOINTS_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail 'invalid MATERIAL_SYMBOLS_CODEPOINTS_SHA256'
    [[ "$MATERIAL_SYMBOLS_METADATA_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail 'invalid MATERIAL_SYMBOLS_METADATA_SHA256'
    [[ "$DEFAULT_WALLPAPER_SOURCE_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail 'invalid DEFAULT_WALLPAPER_SOURCE_SHA256'
    [[ "$DEFAULT_WALLPAPER_PNG_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail 'invalid DEFAULT_WALLPAPER_PNG_SHA256'
    [[ "$MATERIAL_SYMBOLS_COUNT" =~ ^[1-9][0-9]*$ ]] || fail 'invalid MATERIAL_SYMBOLS_COUNT'
    [[ "$TRANSITION_SHADER_COUNT" =~ ^[1-9][0-9]*$ ]] || fail 'invalid TRANSITION_SHADER_COUNT'
    [[ "$UI_ICON_MASTER_COUNT" =~ ^[1-9][0-9]*$ ]] || fail 'invalid UI_ICON_MASTER_COUNT'
    [[ "$UI_ICON_ALIAS_COUNT" =~ ^[1-9][0-9]*$ ]] || fail 'invalid UI_ICON_ALIAS_COUNT'
    if ((failures == failures_before)); then
        pass 'versions.env grammar and commit/checksum widths'
    fi
    return 0
}

check_repository_hygiene() {
    local item
    while IFS= read -r -d '' item; do
        fail "nested Git metadata: ${item#"$REPO_ROOT/"}"
    done < <(find "$REPO_ROOT" -mindepth 2 -type d -name .git -print0)

    while IFS= read -r -d '' item; do
        fail "broken symlink: ${item#"$REPO_ROOT/"} -> $(readlink -- "$item")"
    done < <(find "$REPO_ROOT" -xtype l -print0)

    local link_target resolved
    while IFS= read -r -d '' item; do
        link_target=$(readlink -- "$item")
        resolved=$(realpath -m -- "$item")
        if [[ "$link_target" == /* ]]; then
            fail "absolute repository symlink: ${item#"$REPO_ROOT/"} -> $link_target"
        elif [[ "$resolved" != "$REPO_ROOT/"* ]]; then
            fail "repository symlink escapes checkout: ${item#"$REPO_ROOT/"} -> $link_target"
        fi
    done < <(find "$REPO_ROOT" -type l -print0)

    while IFS= read -r -d '' item; do
        fail "backup/cache artifact: ${item#"$REPO_ROOT/"}"
    done < <(find "$REPO_ROOT" -mindepth 1 \( -type f -o -type d \) \( \
        -name '*.bak' -o -name '*.bak-*' -o -name '*.backup' -o \
        -name '__pycache__' -o -name '*.pyc' -o -name '.cache' \) -print0)

    while IFS= read -r -d '' item; do
        fail "credential/private artifact: ${item#"$REPO_ROOT/"}"
    done < <(find "$REPO_ROOT" -type f \( \
        -name accounts.conf -o -name '*.keyring' -o -name '*.keystore' -o \
        -name '*.remmina' -o -name '*.pem' -o -name '*.key' -o \
        -name '*.p12' -o -name '*.pfx' -o -name credentials.json -o \
        -name 'client_secret*.json' -o -name .netrc -o -name .npmrc -o \
        -name .pypirc -o -name id_rsa -o -name id_ed25519 \) -print0)

    local secret_hits
    if ! command -v rg >/dev/null 2>&1; then
        fail 'rg (ripgrep) missing; credential and portability scans cannot run'
    else
        secret_hits=$(rg --with-filename -n --hidden --glob '!**/.git/**' \
            '(-----BEGIN (OPENSSH|RSA|EC|DSA|PRIVATE) PRIVATE KEY-----|AIza[0-9A-Za-z_-]{30,}|gh[pousr]_[0-9A-Za-z]{30,}|github_pat_[0-9A-Za-z_]{30,}|xox[baprs]-[0-9A-Za-z-]{20,}|sk-[A-Za-z0-9_-]{20,}|A(KIA|SIA)[A-Z0-9]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,})' \
            "$REPO_ROOT" 2>/dev/null || true)
        if [[ -n "$secret_hits" ]]; then
            fail 'probable embedded credential detected:'
            printf '%s\n' "$secret_hits"
        else
            pass 'no private-key or common token signature detected'
        fi
    fi

    local portability_hits
    local -a scan_roots=()
    for item in shell config bin systemd system; do
        [[ -e "$REPO_ROOT/$item" ]] && scan_roots+=("$REPO_ROOT/$item")
    done
    if command -v rg >/dev/null 2>&1; then
        portability_hits=$(rg --with-filename -n --hidden --glob '!*.bak*' --glob '!**/.git/**' \
            '(/home/[[:alnum:]_.-]+|/run/user/[0-9]+)' "${scan_roots[@]}" 2>/dev/null \
            | rg -v 'placeholderText:.*(/home/(user|youruser|username))' || true)
        if [[ -n "$portability_hits" ]]; then
            fail 'hard-coded user home/runtime UID detected (use $HOME, %h, %t or XDG APIs):'
            printf '%s\n' "$portability_hits"
        else
            pass 'no hard-coded /home/<user> or /run/user/<uid> path'
        fi
    fi

    local private_value_hits
    private_value_hits=$(rg --with-filename -n \
        '^(UIOS_WEATHER_(LATITUDE|LONGITUDE|CITY)|UIOS_MONITOR_ROLE_[0-9])=.+$' \
        "$REPO_ROOT/private.example" 2>/dev/null || true)
    if [[ -n "$private_value_hits" ]]; then
        fail 'private.example values must stay empty:'
        printf '%s\n' "$private_value_hits"
    else
        pass 'private weather and host examples contain no machine-specific values'
    fi

    if command -v jq >/dev/null 2>&1; then
        local seed_city
        seed_city=$(jq -r '.bar.weather.city // ""' \
            "$REPO_ROOT/config/illogical-impulse/config.json")
        [[ -z "$seed_city" ]] \
            && pass 'UI seed contains no weather city' \
            || fail 'UI seed must not contain a weather city'
        if jq -e '(.bar.weather | has("enableGPS"))
                and (.bar.weather.enableGPS == false)' \
            "$REPO_ROOT/config/illogical-impulse/config.json" >/dev/null; then
            pass 'UI seed requires explicit GPS weather opt-in'
        else
            fail 'UI seed must explicitly disable GPS weather location by default'
        fi
    fi
    rg -q 'property bool enableGPS: false' \
        "$REPO_ROOT/shell/end4-pC/modules/common/Config.qml" \
        && pass 'QML fallback requires explicit GPS weather opt-in' \
        || fail 'QML fallback must disable GPS weather location by default'
}

check_formats() {
    local file first_line
    if command -v jq >/dev/null 2>&1; then
        while IFS= read -r -d '' file; do
            if jq empty "$file" >/dev/null 2>&1; then
                ((passes += 1))
            else
                fail "invalid JSON: ${file#"$REPO_ROOT/"}"
            fi
        done < <(find "$REPO_ROOT" -type f -name '*.json' -print0)
        pass 'JSON documents parse'
    else
        warn 'jq missing; JSON validation skipped'
    fi

    while IFS= read -r -d '' file; do
        if bash -n "$file"; then
            ((passes += 1))
        else
            fail "bash syntax: ${file#"$REPO_ROOT/"}"
        fi
        [[ -x "$file" ]] || warn "script is not executable: ${file#"$REPO_ROOT/"}"
    done < <(find "$REPO_ROOT/scripts" -type f -name '*.sh' -print0)

    while IFS= read -r -d '' file; do
        IFS= read -r first_line < "$file" || true
        [[ "$first_line" == '#!'* ]] || fail "non-script has executable mode: ${file#"$REPO_ROOT/"}"
    done < <(find "$REPO_ROOT" -type f -perm /111 -print0)

    if [[ -d "$REPO_ROOT/bin" ]]; then
        while IFS= read -r -d '' file; do
            IFS= read -r first_line < "$file" || true
            if [[ "$first_line" == '#!'*bash* ]]; then
                bash -n "$file" || fail "bash syntax: ${file#"$REPO_ROOT/"}"
            elif [[ "$first_line" == '#!'*python* ]] && command -v python3 >/dev/null 2>&1; then
                python3 - "$file" <<'PY' || fail "Python syntax: ${file#"$REPO_ROOT/"}"
from pathlib import Path
import sys

path = Path(sys.argv[1])
compile(path.read_bytes(), str(path), "exec")
PY
            fi
            [[ -x "$file" ]] || fail "helper is not executable: ${file#"$REPO_ROOT/"}"
        done < <(find "$REPO_ROOT/bin" -maxdepth 1 -type f -print0)
    fi
    pass 'shell/helper syntax checks completed'
}

check_assets() {
    if (cd "$REPO_ROOT" && sha256sum --check --strict manifests/checksums.sha256); then
        pass 'immutable asset checksums'
    else
        fail 'asset checksum mismatch or missing asset'
    fi

    # shellcheck disable=SC1091
    source "$REPO_ROOT/manifests/versions.env"
    local wallpaper="$REPO_ROOT/assets/wallpapers/$WALLPAPER_NAME"
    if [[ -f "$wallpaper" ]]; then
        local bytes dimensions
        bytes=$(stat -c '%s' "$wallpaper")
        [[ "$bytes" == "$WALLPAPER_BYTES" ]] && pass 'wallpaper byte size' || fail "wallpaper bytes=$bytes expected=$WALLPAPER_BYTES"
        if command -v identify >/dev/null 2>&1; then
            dimensions=$(identify -format '%wx%h' "$wallpaper" 2>/dev/null || true)
            [[ "$dimensions" == "${WALLPAPER_WIDTH}x${WALLPAPER_HEIGHT}" ]] && pass 'wallpaper dimensions' || fail "wallpaper dimensions=$dimensions expected=${WALLPAPER_WIDTH}x${WALLPAPER_HEIGHT}"
        else
            warn 'identify missing; wallpaper dimensions skipped'
        fi
    fi

    local material_dir="$REPO_ROOT/shell/end4-pC/assets"
    local font="$material_dir/fonts/MaterialSymbolsRounded.ttf"
    local codepoints="$material_dir/material_symbols_rounded.codepoints"
    local metadata="$material_dir/material_symbols_rounded.json"
    local default_image_dir="$material_dir/images"
    local icon_dir="$material_dir/icons"
    local actual_hash symbol_count master_count alias_count default_dimensions

    actual_hash=$(sha256sum -- "$font" 2>/dev/null | cut -d' ' -f1 || true)
    [[ "$actual_hash" == "$MATERIAL_SYMBOLS_TTF_SHA256" ]] \
        && pass 'Material Symbols font matches pinned source' \
        || fail "Material Symbols font checksum=$actual_hash expected=$MATERIAL_SYMBOLS_TTF_SHA256"
    actual_hash=$(sha256sum -- "$codepoints" 2>/dev/null | cut -d' ' -f1 || true)
    [[ "$actual_hash" == "$MATERIAL_SYMBOLS_CODEPOINTS_SHA256" ]] \
        && pass 'Material Symbols codepoints match pinned source' \
        || fail "Material Symbols codepoint checksum=$actual_hash expected=$MATERIAL_SYMBOLS_CODEPOINTS_SHA256"
    actual_hash=$(sha256sum -- "$metadata" 2>/dev/null | cut -d' ' -f1 || true)
    [[ "$actual_hash" == "$MATERIAL_SYMBOLS_METADATA_SHA256" ]] \
        && pass 'Material Symbols metadata matches pinned output' \
        || fail "Material Symbols metadata checksum=$actual_hash expected=$MATERIAL_SYMBOLS_METADATA_SHA256"

    if command -v python3 >/dev/null 2>&1 \
        && "$REPO_ROOT/scripts/generate-material-symbols.py" --check; then
        pass 'Material Symbols metadata reproduces from codepoints'
    else
        fail 'Material Symbols metadata reproduction failed or Python is missing'
    fi
    if command -v jq >/dev/null 2>&1; then
        symbol_count=$(jq 'length' "$metadata" 2>/dev/null || true)
        [[ "$symbol_count" == "$MATERIAL_SYMBOLS_COUNT" ]] \
            && pass "$symbol_count Material Symbols entries present" \
            || fail "Material Symbols entries=$symbol_count expected=$MATERIAL_SYMBOLS_COUNT"
    fi

    actual_hash=$(sha256sum -- "$default_image_dir/default_wallpaper.svg" 2>/dev/null | cut -d' ' -f1 || true)
    [[ "$actual_hash" == "$DEFAULT_WALLPAPER_SOURCE_SHA256" ]] \
        && pass 'default wallpaper SVG matches pinned source' \
        || fail "default wallpaper SVG checksum=$actual_hash expected=$DEFAULT_WALLPAPER_SOURCE_SHA256"
    actual_hash=$(sha256sum -- "$default_image_dir/default_wallpaper.png" 2>/dev/null | cut -d' ' -f1 || true)
    [[ "$actual_hash" == "$DEFAULT_WALLPAPER_PNG_SHA256" ]] \
        && pass 'default wallpaper PNG matches pinned artifact' \
        || fail "default wallpaper PNG checksum=$actual_hash expected=$DEFAULT_WALLPAPER_PNG_SHA256"
    if command -v identify >/dev/null 2>&1; then
        default_dimensions=$(identify -format '%wx%h' \
            "$default_image_dir/default_wallpaper.png" 2>/dev/null || true)
        [[ "$default_dimensions" == "${DEFAULT_WALLPAPER_WIDTH}x${DEFAULT_WALLPAPER_HEIGHT}" ]] \
            && pass 'default wallpaper dimensions' \
            || fail "default wallpaper dimensions=$default_dimensions expected=${DEFAULT_WALLPAPER_WIDTH}x${DEFAULT_WALLPAPER_HEIGHT}"
    fi
    if command -v firefox >/dev/null 2>&1 \
        && { command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; }; then
        if "$REPO_ROOT/scripts/build-default-wallpaper.sh" --check; then
            pass 'default wallpaper reproduces pixel-for-pixel from SVG'
        else
            fail 'default wallpaper does not reproduce from SVG'
        fi
    else
        warn 'Firefox or ImageMagick missing; default wallpaper rebuild comparison skipped'
    fi

    master_count=$(find "$icon_dir" -maxdepth 1 -type f -name '*.svg' | wc -l)
    alias_count=$(find "$icon_dir" -maxdepth 1 -type l -name '*.svg' | wc -l)
    [[ "$master_count" == "$UI_ICON_MASTER_COUNT" ]] \
        && pass "$master_count original SVG icon masters present" \
        || fail "SVG icon masters=$master_count expected=$UI_ICON_MASTER_COUNT"
    [[ "$alias_count" == "$UI_ICON_ALIAS_COUNT" ]] \
        && pass "$alias_count local SVG compatibility aliases present" \
        || fail "SVG icon aliases=$alias_count expected=$UI_ICON_ALIAS_COUNT"
    if command -v python3 >/dev/null 2>&1 && python3 - "$icon_dir" <<'PY'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

directory = Path(sys.argv[1])
for path in sorted(directory.glob("*.svg")):
    root = ET.parse(path).getroot()
    if root.attrib.get("viewBox") != "0 0 24 24":
        raise SystemExit(f"invalid SVG viewBox: {path}")
PY
    then
        pass 'all SVG icon paths parse with the canonical view box'
    else
        fail 'SVG icon parsing or canonical view-box validation failed'
    fi
}

check_regression_tests() {
    local output test_count
    if ! command -v python3 >/dev/null 2>&1; then
        warn 'Python missing; topology regression tests skipped'
        return
    fi
    if output=$(cd "$REPO_ROOT" \
        && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v 2>&1); then
        test_count=$(sed -n 's/^Ran \([0-9][0-9]*\) tests\{0,1\}.*/\1/p' <<<"$output" | tail -1)
        pass "${test_count:-unknown number of} topology and restore regression tests"
    else
        fail 'topology and restore regression tests failed:'
        printf '%s\n' "$output"
    fi
}

check_systemd_units() {
    local file output
    local -a units=()
    if ! command -v systemd-analyze >/dev/null 2>&1; then
        warn 'systemd-analyze missing; unit-file verification skipped'
        return
    fi
    while IFS= read -r -d '' file; do
        units+=("$file")
    done < <(find "$REPO_ROOT/systemd/user" -type f \( -name '*.service' -o -name '*.timer' \) -print0)
    if ((${#units[@]} == 0)); then
        fail 'no user unit files found'
        return
    fi
    if output=$(systemd-analyze verify "${units[@]}" 2>&1); then
        pass 'systemd user units parse'
        [[ -z "$output" ]] || warn "systemd-analyze notes: $output"
    else
        fail 'systemd user unit validation failed:'
        printf '%s\n' "$output"
    fi
}

check_link() {
    local source=$1 target=$2 label=$3 expected actual
    if [[ ! -L "$target" ]]; then
        fail "$label is not a symlink: $target"
        return
    fi
    expected=$(realpath -m -- "$source")
    actual=$(realpath -m -- "$target")
    [[ "$actual" == "$expected" ]] && pass "$label deployed" || fail "$label points to $actual, expected $expected"
}

check_deployed() {
    local config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
    local data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
    local file name

    check_link "$REPO_ROOT/shell/end4-pC" "$config_home/quickshell/end4-pC" 'end4-pC'
    for file in "$REPO_ROOT/config/hypr"/*; do
        [[ -e "$file" ]] || continue
        name=${file##*/}
        [[ "$name" == custom || "$name" == hyprland || "$name" == hyprlock || "$name" == hyprlock.conf ]] && continue
        check_link "$file" "$config_home/hypr/$name" "Hyprland/$name"
    done
    for file in "$REPO_ROOT/config/hypr/hyprland"/*; do
        [[ -e "$file" ]] || continue
        name=${file##*/}
        [[ "$name" == shellOverrides ]] && continue
        check_link "$file" "$config_home/hypr/hyprland/$name" "Hyprland/hyprland/$name"
    done
    for file in "$REPO_ROOT/config/hypr/hyprlock"/*; do
        [[ -e "$file" ]] || continue
        name=${file##*/}
        [[ "$name" == colors.conf ]] && continue
        check_link "$file" "$config_home/hypr/hyprlock/$name" "Hyprland/hyprlock/$name"
    done
    [[ -d "$config_home/hypr/custom" && ! -L "$config_home/hypr/custom" ]] \
        && pass 'mutable Hyprland custom directory exists' \
        || fail 'mutable Hyprland custom directory missing or incorrectly symlinked'
    [[ -d "$config_home/hypr/hyprland/shellOverrides" && ! -L "$config_home/hypr/hyprland/shellOverrides" ]] \
        && pass 'mutable shellOverrides directory exists' \
        || fail 'mutable shellOverrides directory missing or incorrectly symlinked'
    [[ -f "$config_home/hypr/hyprlock.conf" && ! -L "$config_home/hypr/hyprlock.conf" ]] \
        && pass 'mutable hyprlock.conf exists' \
        || fail 'mutable hyprlock.conf missing or incorrectly symlinked'
    [[ -f "$config_home/hypr/hyprlock/colors.conf" && ! -L "$config_home/hypr/hyprlock/colors.conf" ]] \
        && pass 'mutable hyprlock colors exist' \
        || fail 'mutable hyprlock colors missing or incorrectly symlinked'

    if [[ -f "$config_home/illogical-impulse/config.json" && ! -L "$config_home/illogical-impulse/config.json" ]]; then
        pass 'mutable illogical-impulse config seed exists as a regular file'
    else
        fail 'mutable illogical-impulse config.json missing or incorrectly symlinked'
    fi
    for file in "$REPO_ROOT/config/illogical-impulse"/*; do
        [[ -e "$file" ]] || continue
        name=${file##*/}
        [[ "$name" == config.json || "$name" == translations ]] && continue
        check_link "$file" "$config_home/illogical-impulse/$name" "illogical-impulse/$name"
    done
    [[ -d "$config_home/illogical-impulse/translations" && ! -L "$config_home/illogical-impulse/translations" ]] \
        && pass 'mutable generated translations directory exists' \
        || fail 'mutable generated translations directory missing or incorrectly symlinked'

    [[ -f "$config_home/fcitx5/config" && ! -L "$config_home/fcitx5/config" ]] \
        && pass 'mutable Fcitx config seed exists as a regular file' \
        || fail 'mutable Fcitx config seed missing or incorrectly symlinked'
    [[ -f "$config_home/fcitx5/profile" && ! -L "$config_home/fcitx5/profile" ]] \
        && pass 'mutable Fcitx profile seed exists as a regular file' \
        || fail 'mutable Fcitx profile seed missing or incorrectly symlinked'

    for file in "$REPO_ROOT/bin"/*; do
        [[ -f "$file" ]] || continue
        name=${file##*/}
        check_link "$file" "$HOME/.local/bin/$name" "bin/$name"
    done
    for file in "$REPO_ROOT/systemd/user/core"/*; do
        [[ -f "$file" ]] || continue
        name=${file##*/}
        check_link "$file" "$config_home/systemd/user/$name" "core unit $name"
    done
    for file in "$REPO_ROOT/assets/wallpapers"/*; do
        [[ -f "$file" ]] || continue
        name=${file##*/}
        check_link "$file" "$data_home/backgrounds/$name" "wallpaper $name"
    done
}

section 'Required repository paths'
check_required_paths
section 'Version-lock grammar'
check_lock_grammar
section 'Repository hygiene and portability'
check_repository_hygiene
section 'Licensing and corresponding source'
check_provenance
section 'Formats and executable helpers'
check_formats
section 'Systemd unit files'
check_systemd_units
section 'Topology regression tests'
check_regression_tests
section 'Immutable assets'
check_assets
if ((DEPLOYED)); then
    section 'Deployed XDG targets'
    check_deployed
fi

section 'Summary'
printf 'passes:   %d\n' "$passes"
printf 'warnings: %d\n' "$warnings"
printf 'failures: %d\n' "$failures"
((failures == 0))
