#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 desktop-ui contributors

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd -P)"
source_svg="$repo_root/shell/end4-pC/assets/images/default_wallpaper.svg"
output_png="$repo_root/shell/end4-pC/assets/images/default_wallpaper.png"
mode=plan

usage() {
    cat <<'EOF'
Usage: build-default-wallpaper.sh [--apply | --check] [--firefox PATH] [--convert PATH]

Render the project's GPL vector wallpaper to its 3840x2160 PNG artifact.
The default is a read-only plan. --check renders to a temporary file and
compares decoded pixels, avoiding PNG metadata differences between encoders.
EOF
}

convert_bin=${CONVERT_BIN-}
firefox_bin=${FIREFOX_BIN-}
while (($#)); do
    case "$1" in
        --apply) mode=apply ;;
        --check) mode=check ;;
        --convert)
            (($# >= 2)) || { printf 'error: --convert requires a path\n' >&2; exit 2; }
            convert_bin=$2
            shift
            ;;
        --firefox)
            (($# >= 2)) || { printf 'error: --firefox requires a path\n' >&2; exit 2; }
            firefox_bin=$2
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'error: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [[ -z "$convert_bin" ]]; then
    convert_bin=$(command -v magick || command -v convert || true)
fi
[[ -n "$convert_bin" && -x "$convert_bin" ]] || {
    printf 'error: ImageMagick convert command not found\n' >&2
    exit 1
}
if [[ -z "$firefox_bin" ]]; then
    firefox_bin=$(command -v firefox || true)
fi
[[ -n "$firefox_bin" && -x "$firefox_bin" ]] || {
    printf 'error: Firefox not found; pass --firefox PATH\n' >&2
    exit 1
}

printf 'Wallpaper build mode: %s\n' "$mode"
printf 'renderer:             %s\n' "$convert_bin"
printf 'SVG engine:           %s\n' "$firefox_bin"
printf 'source:               %s\n' "$source_svg"
printf 'output:               %s\n' "$output_png"

if [[ "$mode" == plan ]]; then
    printf 'No files changed. Re-run with --apply or --check.\n'
    exit 0
fi

build_dir=$(mktemp -d)
trap 'rm -rf -- "$build_dir"' EXIT
rendered="$build_dir/default_wallpaper.png"
raw_render="$build_dir/default_wallpaper.raw.png"
profile_dir="$build_dir/firefox-profile"
mkdir -p "$profile_dir"

MOZ_HEADLESS=1 "$firefox_bin" --headless --no-remote --profile "$profile_dir" \
    --screenshot "$raw_render" --window-size 3840,2160 "file://$source_svg" \
    >/dev/null 2>&1
"$convert_bin" "$raw_render" -alpha off -colorspace sRGB -strip -depth 8 \
    "PNG24:$rendered"

if [[ "$mode" == apply ]]; then
    install -m 0644 -- "$rendered" "$output_png"
    printf 'Generated default wallpaper.\n'
    exit 0
fi

current_signature=$("$convert_bin" "$output_png" -alpha off -depth 8 rgba:- | sha256sum | cut -d' ' -f1)
rendered_signature=$("$convert_bin" "$rendered" -alpha off -depth 8 rgba:- | sha256sum | cut -d' ' -f1)
[[ "$current_signature" == "$rendered_signature" ]] || {
    printf 'error: generated wallpaper pixels differ from the committed PNG\n' >&2
    exit 1
}
printf 'Generated wallpaper pixels match the SVG source.\n'
