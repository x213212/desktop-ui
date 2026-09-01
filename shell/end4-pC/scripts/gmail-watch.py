#!/usr/bin/env python3
"""Wait for Gmail mailbox changes using IMAP IDLE.

This process emits small JSON events on stdout. It does not download mail and
stores neither the GOA OAuth token nor message contents. The UI starts the
short-lived summary reader only after an event arrives.
"""

import importlib.util
import json
import select
import sys
import time
from pathlib import Path

import imaplib
from gi.repository import Gio


def load_summary_module():
    path = Path(__file__).with_name("gmail-summary.py")
    spec = importlib.util.spec_from_file_location("gmail_summary", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


SUMMARY = load_summary_module()


def emit(event, **values):
    print(json.dumps({"event": event, **values}, ensure_ascii=False), flush=True)


def idle_once():
    connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    account_path, address = SUMMARY.google_mail_account(connection)
    token = SUMMARY.access_token(connection, account_path)

    client = imaplib.IMAP4_SSL("imap.gmail.com", 993, timeout=15)
    try:
        auth = f"user={address}\x01auth=Bearer {token}\x01\x01".encode()
        client.authenticate("XOAUTH2", lambda _challenge: auth)
        status, _ = client.select("INBOX", readonly=True)
        if status != "OK":
            raise RuntimeError("無法監看 Gmail 收件匣")

        # Python 3.12 has no public IMAP IDLE helper. This is the small wire
        # sequence defined by RFC 2177: enter IDLE, wait for untagged mailbox
        # changes, then reconnect before Gmail's timeout.
        client.sock.settimeout(None)
        tag = client._new_tag()
        client.send(tag + b" IDLE\r\n")
        continuation = client.readline()
        if not continuation.startswith(b"+"):
            raise RuntimeError("Gmail 不接受即時同步")

        emit("ready", account=address)
        deadline = time.monotonic() + 24 * 60
        while time.monotonic() < deadline:
            timeout = min(60, max(0, deadline - time.monotonic()))
            readable, _, _ = select.select([client.sock], [], [], timeout)
            if not readable:
                continue
            line = client.readline()
            if not line:
                raise ConnectionError("Gmail 即時連線已中斷")
            upper = line.upper()
            if b" EXISTS" in upper or b" RECENT" in upper or b" EXPUNGE" in upper:
                emit("changed")
                return
    finally:
        try:
            client.shutdown()
        except Exception:
            pass


def main():
    backoff = 3
    last_error = ""
    while True:
        try:
            idle_once()
            backoff = 3
            last_error = ""
        except KeyboardInterrupt:
            return 0
        except Exception as error:
            message = str(error)[:160]
            if message != last_error:
                emit("error", error=message)
                last_error = message
            time.sleep(backoff)
            backoff = min(backoff * 2, 300)
    return 0


if __name__ == "__main__":
    sys.exit(main())
