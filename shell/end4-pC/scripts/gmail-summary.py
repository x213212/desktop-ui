#!/usr/bin/env python3
"""Read a small Gmail inbox summary through the user's GOA OAuth token.

The token is requested on demand from gnome-online-accounts and is never
written to disk or included in the JSON output.
"""

import email
import imaplib
import json
import re
import sys
from email.header import decode_header, make_header
from email.policy import default
from email.utils import parseaddr, parsedate_to_datetime

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib


DBUS_TIMEOUT_MS = 5000
IMAP_TIMEOUT_SECONDS = 8


def dbus_objects(connection):
    result = connection.call_sync(
        "org.gnome.OnlineAccounts",
        "/org/gnome/OnlineAccounts",
        "org.freedesktop.DBus.ObjectManager",
        "GetManagedObjects",
        None,
        GLib.VariantType.new("(a{oa{sa{sv}}})"),
        Gio.DBusCallFlags.NONE,
        DBUS_TIMEOUT_MS,
        None,
    )
    return result.unpack()[0]


def google_mail_account(connection):
    for path, interfaces in dbus_objects(connection).items():
        account = interfaces.get("org.gnome.OnlineAccounts.Account", {})
        if account.get("ProviderType") != "google":
            continue
        if account.get("MailDisabled", False):
            continue
        mail = interfaces.get("org.gnome.OnlineAccounts.Mail", {})
        identity = mail.get("EmailAddress") or account.get("Identity", "")
        if identity:
            return path, identity
    raise RuntimeError("尚未啟用 Google Mail 帳號")


def access_token(connection, account_path):
    result = connection.call_sync(
        "org.gnome.OnlineAccounts",
        account_path,
        "org.gnome.OnlineAccounts.OAuth2Based",
        "GetAccessToken",
        None,
        # GOA 3.50 exposes the expiry value as a signed 32-bit integer.
        GLib.VariantType.new("(si)"),
        Gio.DBusCallFlags.NONE,
        DBUS_TIMEOUT_MS,
        None,
    )
    return result.unpack()[0]


def decoded(value):
    try:
        return str(make_header(decode_header(value or ""))).strip()
    except Exception:
        return (value or "").strip()


def local_date(value):
    try:
        parsed = parsedate_to_datetime(value)
        if parsed is None:
            return ""
        return parsed.astimezone().strftime("%m/%d %H:%M")
    except Exception:
        return ""


def inbox_summary(address, token, limit=10):
    client = imaplib.IMAP4_SSL(
        "imap.gmail.com", 993, timeout=IMAP_TIMEOUT_SECONDS
    )
    try:
        auth = f"user={address}\x01auth=Bearer {token}\x01\x01".encode()
        client.authenticate("XOAUTH2", lambda _challenge: auth)
        status, selected = client.select("INBOX", readonly=True)
        if status != "OK":
            raise RuntimeError("無法開啟 Gmail 收件匣")

        try:
            message_count = int(selected[0])
        except (IndexError, TypeError, ValueError):
            raise RuntimeError("Gmail 回傳無效的郵件數量")
        if message_count <= 0:
            return []

        # SELECT already returned the mailbox size. Fetch only the final ten
        # sequence slots and request their stable UIDs in the same round-trip;
        # UID SEARCH ALL downloaded the entire mailbox index on every refresh.
        first_sequence = max(1, message_count - limit + 1)
        status, fetched = client.fetch(
            f"{first_sequence}:*",
            "(UID BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE MESSAGE-ID)] FLAGS)",
        )
        if status != "OK":
            raise RuntimeError("無法讀取 Gmail 郵件摘要")

        messages = []
        for part in fetched:
            if not isinstance(part, tuple):
                continue
            metadata = part[0].decode(errors="replace")
            raw_header = part[1]
            if not raw_header:
                continue

            sequence_match = re.match(r"\s*(\d+)", metadata)
            uid_match = re.search(r"\bUID\s+(\d+)", metadata)
            if not sequence_match or not uid_match:
                continue

            parsed = email.message_from_bytes(raw_header, policy=default)
            from_name, from_address = parseaddr(decoded(parsed.get("From", "")))
            sender = from_name or from_address or "未知寄件者"
            messages.append(
                {
                    "_sequence": int(sequence_match.group(1)),
                    "id": uid_match.group(1),
                    "sender": sender,
                    "address": from_address,
                    "subject": decoded(parsed.get("Subject", "")) or "（無主旨）",
                    "date": local_date(parsed.get("Date", "")),
                    "unread": "\\Seen" not in metadata,
                }
            )

        messages.sort(key=lambda message: message["_sequence"], reverse=True)
        for message in messages:
            del message["_sequence"]
        return messages[:limit]
    finally:
        try:
            client.logout()
        except Exception:
            pass


def main():
    token = ""
    try:
        connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        account_path, address = google_mail_account(connection)
        token = access_token(connection, account_path)
        messages = inbox_summary(address, token)
        print(json.dumps({"ok": True, "account": address, "messages": messages}, ensure_ascii=False))
    except Exception as error:
        message = str(error)
        if token:
            message = message.replace(token, "[token]")
        print(json.dumps({"ok": False, "error": message[:240], "messages": []}, ensure_ascii=False))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
