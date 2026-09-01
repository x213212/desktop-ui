#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 desktop-ui contributors

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if "$script_dir/is_unlocked.sh" >/dev/null 2>&1; then
    exit 0
fi

password=${UNLOCK_PASSWORD-}
if [[ -z "$password" ]]; then
    [[ -t 0 ]] || { printf 'error: no keyring password supplied\n' >&2; exit 2; }
    IFS= read -r -s -p 'Login password: ' password
    printf '\n' >&2
fi

# The daemon reads the login password from standard input. Its environment
# assignments are intentionally discarded: this helper cannot export values
# back into the already-running shell, and evaluating daemon output is unsafe.
killall -q -u "$(id -un)" gnome-keyring-daemon 2>/dev/null || true
printf '%s' "$password" | gnome-keyring-daemon --daemonize --login >/dev/null

password=
unset UNLOCK_PASSWORD
