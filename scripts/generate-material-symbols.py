#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 desktop-ui contributors
"""Generate search metadata from the pinned Material Symbols codepoints list."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile


REPOSITORY_ROOT = Path(__file__).resolve().parent.parent
ASSET_DIRECTORY = REPOSITORY_ROOT / "shell/end4-pC/assets"
DEFAULT_SOURCE = ASSET_DIRECTORY / "material_symbols_rounded.codepoints"
DEFAULT_OUTPUT = ASSET_DIRECTORY / "material_symbols_rounded.json"
EXPECTED_SOURCE_SHA256 = (
    "a949567431829ed6f382911f3e6d3158627a4a5027d7e6f3d89a85a55c027279"
)
LINE_PATTERN = re.compile(r"^([a-z0-9_]+) ([0-9a-f]+)$")


def source_entries(source: Path) -> list[dict[str, object]]:
    payload = source.read_bytes()
    actual_hash = hashlib.sha256(payload).hexdigest()
    if actual_hash != EXPECTED_SOURCE_SHA256:
        raise ValueError(
            f"source checksum mismatch: expected {EXPECTED_SOURCE_SHA256}, "
            f"got {actual_hash}"
        )

    entries: list[dict[str, object]] = []
    previous_names: set[str] = set()
    for line_number, raw_line in enumerate(payload.decode("utf-8").splitlines(), 1):
        match = LINE_PATTERN.fullmatch(raw_line)
        if match is None:
            raise ValueError(f"invalid codepoints line {line_number}: {raw_line!r}")

        name = match.group(1)
        if name in previous_names:
            raise ValueError(f"duplicate symbol name at line {line_number}: {name}")
        previous_names.add(name)

        readable_name = name.replace("_", " ")
        tags = [] if readable_name == name else [readable_name]
        entries.append({"name": name, "tags": tags, "categories": []})

    if not entries:
        raise ValueError("the codepoints source is empty")
    return entries


def rendered_json(source: Path) -> bytes:
    document = json.dumps(
        source_entries(source),
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=False,
    )
    return (document + "\n").encode("utf-8")


def atomic_write(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary_name, 0o644)
        os.replace(temporary_name, path)
    except BaseException:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true", help="replace the JSON output")
    mode.add_argument("--check", action="store_true", help="compare output without writing")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        payload = rendered_json(arguments.source)
    except (OSError, UnicodeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    digest = hashlib.sha256(payload).hexdigest()
    count = len(json.loads(payload))
    print(f"source:  {arguments.source}")
    print(f"output:  {arguments.output}")
    print(f"symbols: {count}")
    print(f"sha256:  {digest}")

    if arguments.check:
        try:
            current = arguments.output.read_bytes()
        except OSError as error:
            print(f"error: {error}", file=sys.stderr)
            return 1
        if current != payload:
            print("error: generated metadata is out of date", file=sys.stderr)
            return 1
        print("Generated metadata matches the pinned source.")
        return 0

    if arguments.apply:
        atomic_write(arguments.output, payload)
        print("Generated metadata updated.")
        return 0

    print("No files changed. Re-run with --apply or --check.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
