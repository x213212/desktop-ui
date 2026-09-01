#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 desktop-ui contributors

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd -P)"
shader_dir="$repo_root/shell/end4-pC/modules/ii/background/shaders"
mode=plan

usage() {
    cat <<'EOF'
Usage: build-shaders.sh [--apply | --check] [--qsb PATH]

Compile the repository's GPL shader sources with the pinned Qt Shader Baker.
The default is a read-only plan. --apply replaces only the generated .qsb
artifacts; --check rebuilds into a temporary directory and compares bytes.
EOF
}

qsb_bin=${QSB_BIN-}
while (($#)); do
    case "$1" in
        --apply) mode=apply ;;
        --check) mode=check ;;
        --qsb)
            (($# >= 2)) || { printf 'error: --qsb requires a path\n' >&2; exit 2; }
            qsb_bin=$2
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'error: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

# shellcheck disable=SC1091
source "$repo_root/manifests/versions.env"

if [[ -z "$qsb_bin" ]]; then
    qsb_bin=$(command -v qsb || true)
fi
if [[ -z "$qsb_bin" ]]; then
    candidate="$HOME/.local/opt/Qt/$QT_VERSION/gcc_64/bin/qsb"
    [[ -x "$candidate" ]] && qsb_bin=$candidate
fi

[[ -n "$qsb_bin" && -x "$qsb_bin" ]] || {
    printf 'error: qsb not found; pass --qsb PATH or install Qt %s\n' "$QT_VERSION" >&2
    exit 1
}

qsb_version=$($qsb_bin --version 2>&1)
[[ "$qsb_version" == *"$QT_VERSION"* ]] || {
    printf 'error: qsb version mismatch: expected Qt %s, got %s\n' \
        "$QT_VERSION" "$qsb_version" >&2
    exit 1
}

mapfile -d '' sources < <(find "$shader_dir" -maxdepth 1 -type f -name '*.frag' -print0 | sort -z)
((${#sources[@]} > 0)) || { printf 'error: no shader sources found\n' >&2; exit 1; }

printf 'Shader build mode: %s\n' "$mode"
printf 'qsb:               %s\n' "$qsb_bin"
printf 'source directory:  %s\n' "$shader_dir"
printf 'shader count:      %d\n' "${#sources[@]}"

if [[ "$mode" == plan ]]; then
    printf 'No files changed. Re-run with --apply or --check.\n'
    exit 0
fi

build_dir=$(mktemp -d)
trap 'rm -rf -- "$build_dir"' EXIT

for source in "${sources[@]}"; do
    name=${source##*/}
    output="$build_dir/$name.qsb"
    "$qsb_bin" --qt6 -o "$output" "$source"

    if [[ "$mode" == check ]]; then
        cmp --silent -- "$output" "$source.qsb" || {
            printf 'error: generated shader differs: %s.qsb\n' "$name" >&2
            exit 1
        }
    else
        install -m 0644 -- "$output" "$source.qsb"
    fi
done

if [[ "$mode" == check ]]; then
    printf 'All generated shader artifacts match their sources.\n'
else
    printf 'Generated %d shader artifacts.\n' "${#sources[@]}"
fi
