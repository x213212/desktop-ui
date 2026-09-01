#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Safely download a wallpaper from a supported public provider."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import tempfile
from typing import BinaryIO, Callable
import urllib.error
import urllib.parse
import urllib.request


UNSPLASH_CLIENT_ID_ENV = "UIOS_UNSPLASH_CLIENT_ID"
USER_AGENT = "desktop-ui-online-wallpaper/1"
REQUEST_TIMEOUT_SECONDS = 20
MAX_TRACKING_RESPONSE_BYTES = 64 * 1024
MAX_IMAGE_BYTES = 80 * 1024 * 1024
IMAGE_HOSTS = {
    "unsplash": frozenset({"images.unsplash.com", "plus.unsplash.com"}),
    "wallhaven": frozenset({"w.wallhaven.cc"}),
}


class DownloadError(RuntimeError):
    """A provider response failed a compliance or safety check."""


def validated_https_url(value: str, hosts: frozenset[str], purpose: str) -> str:
    """Return a trusted HTTPS URL without credentials or a non-standard port."""
    try:
        parsed = urllib.parse.urlsplit(value)
        port = parsed.port
    except ValueError as error:
        raise DownloadError(f"invalid {purpose} URL") from error
    if (
        parsed.scheme != "https"
        or parsed.hostname not in hosts
        or parsed.username is not None
        or parsed.password is not None
        or port not in (None, 443)
    ):
        raise DownloadError(f"untrusted {purpose} URL")
    return value


def ensure_success(response: BinaryIO, purpose: str) -> None:
    status = getattr(response, "status", 200) or 200
    if not 200 <= int(status) < 300:
        raise DownloadError(f"{purpose} request returned HTTP {status}")


def track_unsplash_download(
    download_location: str,
    client_id: str,
    opener: Callable[..., BinaryIO],
) -> None:
    """Trigger Unsplash's download endpoint before fetching image bytes."""
    if not client_id:
        raise DownloadError("Unsplash Client-ID is missing")
    location = validated_https_url(
        download_location,
        frozenset({"api.unsplash.com"}),
        "Unsplash tracking",
    )
    parsed = urllib.parse.urlsplit(location)
    if not parsed.path.startswith("/photos/") or not parsed.path.endswith("/download"):
        raise DownloadError("invalid Unsplash tracking endpoint")

    request = urllib.request.Request(
        location,
        method="GET",
        headers={
            "Authorization": f"Client-ID {client_id}",
            "User-Agent": USER_AGENT,
            "Accept": "application/json",
        },
    )
    with opener(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
        ensure_success(response, "Unsplash tracking")
        final_url = getattr(response, "geturl", lambda: location)()
        validated_https_url(
            final_url,
            frozenset({"api.unsplash.com"}),
            "Unsplash tracking response",
        )
        body = response.read(MAX_TRACKING_RESPONSE_BYTES + 1)
    if len(body) > MAX_TRACKING_RESPONSE_BYTES:
        raise DownloadError("Unsplash tracking response is too large")
    try:
        tracked = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise DownloadError("invalid Unsplash tracking response") from error
    if not isinstance(tracked, dict) or not isinstance(tracked.get("url"), str):
        raise DownloadError("Unsplash tracking response has no download URL")
    validated_https_url(
        tracked["url"],
        IMAGE_HOSTS["unsplash"],
        "Unsplash tracked download",
    )


def copy_image_response(response: BinaryIO, handle: BinaryIO) -> None:
    ensure_success(response, "wallpaper download")
    headers = getattr(response, "headers", {})
    content_type = str(headers.get("Content-Type", "")).split(";", 1)[0].strip().lower()
    if not content_type.startswith("image/"):
        raise DownloadError("wallpaper response is not an image")
    content_length = headers.get("Content-Length")
    if content_length:
        try:
            if int(content_length) > MAX_IMAGE_BYTES:
                raise DownloadError("wallpaper exceeds the download size limit")
        except ValueError as error:
            raise DownloadError("invalid wallpaper content length") from error

    copied = 0
    while True:
        chunk = response.read(128 * 1024)
        if not chunk:
            break
        copied += len(chunk)
        if copied > MAX_IMAGE_BYTES:
            raise DownloadError("wallpaper exceeds the download size limit")
        handle.write(chunk)
    if copied == 0:
        raise DownloadError("wallpaper response was empty")


def download_wallpaper(
    provider: str,
    image_url: str,
    output: Path,
    *,
    download_location: str = "",
    client_id: str = "",
    opener: Callable[..., BinaryIO] = urllib.request.urlopen,
) -> None:
    """Track when required, then atomically download one trusted image."""
    if provider not in IMAGE_HOSTS:
        raise DownloadError("unsupported wallpaper provider")
    trusted_image_url = validated_https_url(
        image_url,
        IMAGE_HOSTS[provider],
        f"{provider} image",
    )
    if not output.is_absolute():
        raise DownloadError("wallpaper output path must be absolute")

    # Unsplash requires this request for every user-initiated download. Fail
    # closed so image bytes are never fetched when tracking was not accepted.
    if provider == "unsplash":
        track_unsplash_download(download_location, client_id, opener)

    output.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    request = urllib.request.Request(
        trusted_image_url,
        method="GET",
        headers={"User-Agent": USER_AGENT, "Accept": "image/*"},
    )
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=".online-wallpaper.",
        dir=output.parent,
    )
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "wb") as handle:
            with opener(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
                final_url = getattr(response, "geturl", lambda: trusted_image_url)()
                validated_https_url(
                    final_url,
                    IMAGE_HOSTS[provider],
                    f"{provider} image response",
                )
                copy_image_response(response, handle)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, output)
    finally:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", required=True, choices=sorted(IMAGE_HOSTS))
    parser.add_argument("--url", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--download-location", default="")
    args = parser.parse_args()

    try:
        download_wallpaper(
            args.provider,
            args.url,
            args.output,
            download_location=args.download_location,
            client_id=os.environ.get(UNSPLASH_CLIENT_ID_ENV, ""),
        )
    except (DownloadError, OSError, urllib.error.URLError) as error:
        print(f"download-online-wallpaper: {error}", file=os.sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
