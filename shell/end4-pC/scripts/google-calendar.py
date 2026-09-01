#!/usr/bin/env python3
"""Read upcoming Google Calendar events through GNOME Online Accounts.

The OAuth token is requested from GOA for this process only.  It is sent in an
HTTP Authorization header, never written to disk, and never included in JSON or
error output.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import date, datetime, timedelta, timezone
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlparse
from urllib.request import Request, urlopen

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib


API_ENDPOINT = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
CALENDAR_LIST_ENDPOINT = "https://www.googleapis.com/calendar/v3/users/me/calendarList/primary"
MAX_EVENTS = 250
MAX_RESPONSE_BYTES = 2_000_000
MAX_REMINDER_MINUTES = 4 * 7 * 24 * 60
DBUS_TIMEOUT_MS = 5000
HTTP_TIMEOUT_SECONDS = 8


def dbus_objects(connection: Gio.DBusConnection) -> dict:
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


def google_calendar_account(connection: Gio.DBusConnection) -> tuple[str, str]:
    for path, interfaces in dbus_objects(connection).items():
        account = interfaces.get("org.gnome.OnlineAccounts.Account", {})
        if account.get("ProviderType") != "google":
            continue
        if account.get("CalendarDisabled", False):
            continue
        if "org.gnome.OnlineAccounts.Calendar" not in interfaces:
            continue
        if "org.gnome.OnlineAccounts.OAuth2Based" not in interfaces:
            continue

        identity = (
            account.get("PresentationIdentity")
            or account.get("Identity")
            or "Google"
        )
        return path, clean_text(identity, 160)
    raise RuntimeError("尚未在 GNOME Online Accounts 啟用 Google 日曆")


def access_token(connection: Gio.DBusConnection, account_path: str) -> str:
    result = connection.call_sync(
        "org.gnome.OnlineAccounts",
        account_path,
        "org.gnome.OnlineAccounts.OAuth2Based",
        "GetAccessToken",
        None,
        # GOA 3.50 exposes the expiry as a signed 32-bit integer.
        GLib.VariantType.new("(si)"),
        Gio.DBusCallFlags.NONE,
        DBUS_TIMEOUT_MS,
        None,
    )
    token = result.unpack()[0]
    if not token:
        raise RuntimeError("Google 日曆授權沒有回傳權杖")
    return token


def clean_text(value: object, limit: int) -> str:
    """Collapse control/spacing characters and cap untrusted event fields."""

    text = re.sub(r"\s+", " ", str(value or "")).strip()
    text = "".join(char for char in text if char.isprintable())
    return text[:limit]


def safe_event_link(value: object) -> str:
    link = clean_text(value, 2_000)
    try:
        parsed = urlparse(link)
    except ValueError:
        return ""
    host = (parsed.hostname or "").lower()
    if parsed.scheme != "https":
        return ""
    if host != "google.com" and not host.endswith(".google.com"):
        return ""
    return link


def local_date_key(value: str, all_day: bool) -> str:
    if all_day:
        return value[:10]
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone().date().isoformat()
    except (TypeError, ValueError):
        return ""


def local_time_label(value: str, all_day: bool) -> str:
    try:
        if all_day:
            parsed_date = datetime.fromisoformat(value).date()
            return f"{parsed_date.month}/{parsed_date.day} 全天"
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        local = parsed.astimezone()
        return f"{local.month}/{local.day} {local:%H:%M}"
    except (TypeError, ValueError):
        return "全天" if all_day else ""


def popup_reminder_minutes(reminders: object) -> list[int]:
    if not isinstance(reminders, list):
        return []

    minutes = set()
    for reminder in reminders:
        if not isinstance(reminder, dict) or reminder.get("method") != "popup":
            continue
        value = reminder.get("minutes")
        if isinstance(value, bool):
            continue
        try:
            value = int(value)
        except (TypeError, ValueError):
            continue
        if 0 <= value <= MAX_REMINDER_MINUTES:
            minutes.add(value)
    return sorted(minutes, reverse=True)


def event_start_utc(value: str, all_day: bool) -> datetime | None:
    try:
        if all_day:
            # Google all-day events have a date but no offset.  Treat midnight
            # in the machine's local timezone as the event start.
            local_midnight = datetime.fromisoformat(value).astimezone()
            return local_midnight.astimezone(timezone.utc)

        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.astimezone()
        return parsed.astimezone(timezone.utc)
    except (TypeError, ValueError):
        return None


def event_time_ms(value: str, all_day: bool) -> int:
    parsed = event_start_utc(value, all_day)
    return int(parsed.timestamp() * 1000) if parsed is not None else 0


def event_date_keys(start: str, end: str, all_day: bool) -> list[str]:
    """Return every local calendar date touched by an event.

    Google's all-day end date is exclusive. Timed event end timestamps are
    also exclusive, so an event ending exactly at midnight does not mark the
    following day.
    """

    try:
        if all_day:
            first = date.fromisoformat(start)
            exclusive_end = date.fromisoformat(end) if end else first + timedelta(days=1)
            last = max(first, exclusive_end - timedelta(days=1))
        else:
            first_dt = datetime.fromisoformat(start.replace("Z", "+00:00"))
            if first_dt.tzinfo is None:
                first_dt = first_dt.replace(tzinfo=timezone.utc)
            first_dt = first_dt.astimezone()
            end_dt = datetime.fromisoformat((end or start).replace("Z", "+00:00"))
            if end_dt.tzinfo is None:
                end_dt = end_dt.replace(tzinfo=timezone.utc)
            end_dt = end_dt.astimezone()
            final_dt = end_dt - timedelta(microseconds=1) if end_dt > first_dt else first_dt
            first = first_dt.date()
            last = max(first, final_dt.date())

        span = min(31, (last - first).days + 1)
        return [(first + timedelta(days=offset)).isoformat() for offset in range(span)]
    except (TypeError, ValueError):
        fallback = local_date_key(start, all_day)
        return [fallback] if fallback else []


def event_reminders(
    item: dict, event_id: str, start: str, all_day: bool, defaults: list[int]
) -> list[dict]:
    reminder_data = item.get("reminders") or {}
    if not isinstance(reminder_data, dict):
        reminder_data = {}

    if reminder_data.get("useDefault") is True:
        minutes_list = defaults
    else:
        minutes_list = popup_reminder_minutes(reminder_data.get("overrides"))

    start_utc = event_start_utc(start, all_day)
    if start_utc is None:
        return []

    reminders = []
    for minutes in minutes_list:
        trigger = start_utc - timedelta(minutes=minutes)
        trigger_iso = trigger.isoformat().replace("+00:00", "Z")
        trigger_ms = int(trigger.timestamp() * 1000)
        reminders.append(
            {
                "key": clean_text(f"{event_id}:{start}:{minutes}:{trigger_ms}", 2_000),
                "minutes": minutes,
                "triggerAt": trigger_iso,
                "triggerMs": trigger_ms,
            }
        )
    return reminders


def normalized_event(item: object, default_reminders: list[int]) -> dict | None:
    if not isinstance(item, dict) or item.get("status") == "cancelled":
        return None

    start_payload = item.get("start") or {}
    end_payload = item.get("end") or {}
    if not isinstance(start_payload, dict) or not isinstance(end_payload, dict):
        return None

    all_day = bool(start_payload.get("date") and not start_payload.get("dateTime"))
    start = clean_text(start_payload.get("date") if all_day else start_payload.get("dateTime"), 80)
    end = clean_text(end_payload.get("date") if all_day else end_payload.get("dateTime"), 80)
    if not start:
        return None

    event_id = clean_text(item.get("id"), 1_024)
    date_keys = event_date_keys(start, end, all_day)
    return {
        "id": event_id,
        "title": clean_text(item.get("summary") or "（無標題）", 300),
        "start": start,
        "end": end,
        "allDay": all_day,
        "dateKey": date_keys[0] if date_keys else local_date_key(start, all_day),
        "dateKeys": date_keys,
        "startMs": event_time_ms(start, all_day),
        "endMs": event_time_ms(end or start, all_day),
        "timeLabel": local_time_label(start, all_day),
        "location": clean_text(item.get("location"), 300),
        "htmlLink": safe_event_link(item.get("htmlLink")),
        "reminders": event_reminders(
            item, event_id, start, all_day, default_reminders
        ),
    }


def read_json(request: Request) -> dict:
    with urlopen(request, timeout=HTTP_TIMEOUT_SECONDS) as response:
        raw = response.read(MAX_RESPONSE_BYTES + 1)
    if len(raw) > MAX_RESPONSE_BYTES:
        raise RuntimeError("Google 日曆回傳資料過大")

    try:
        payload = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise RuntimeError("Google 日曆回傳格式錯誤") from error
    if not isinstance(payload, dict):
        raise RuntimeError("Google 日曆回傳格式錯誤")
    return payload


def api_request(url: str, token: str) -> dict:
    request = Request(
        url,
        headers={
            "Accept": "application/json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "UIOS-GoogleCalendar/1.0",
        },
        method="GET",
    )
    return read_json(request)


def default_popup_reminders(token: str) -> list[int]:
    query = urlencode({"fields": "defaultReminders"})
    payload = api_request(f"{CALENDAR_LIST_ENDPOINT}?{query}", token)
    return popup_reminder_minutes(payload.get("defaultReminders"))


def upcoming_events(
    token: str, default_reminders: list[int]
) -> tuple[list[dict], str, str, str]:
    now = datetime.now(timezone.utc).replace(microsecond=0)
    local_day_start = now.astimezone().replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    time_min = local_day_start.astimezone(timezone.utc)
    time_max = time_min + timedelta(days=30)
    query = urlencode(
        {
            # Keep events from earlier today so the month grid's date marker
            # does not disappear after an event has started or ended.
            "timeMin": time_min.isoformat().replace("+00:00", "Z"),
            "timeMax": time_max.isoformat().replace("+00:00", "Z"),
            "maxResults": str(MAX_EVENTS),
            "singleEvents": "true",
            "orderBy": "startTime",
            "showDeleted": "false",
            # Avoid downloading descriptions, attendees and conference blobs
            # that this compact UI never renders.
            "fields": "items(id,status,summary,start,end,location,htmlLink,reminders)",
        }
    )
    payload = api_request(f"{API_ENDPOINT}?{query}", token)

    events = []
    for item in payload.get("items") or []:
        event = normalized_event(item, default_reminders)
        if event is not None:
            events.append(event)
    # timeMax is exclusive. Expose the inclusive local date range so the UI
    # never labels an unqueried day as having no events.
    range_start = local_day_start.date().isoformat()
    range_end = (local_day_start + timedelta(days=29)).date().isoformat()
    return (
        events[:MAX_EVENTS],
        now.isoformat().replace("+00:00", "Z"),
        range_start,
        range_end,
    )


def safe_error(error: Exception, token: str) -> str:
    if isinstance(error, HTTPError):
        if error.code == 401:
            return "Google 日曆授權已失效，請重新登入 Google 帳號"
        if error.code == 403:
            return "Google 帳號尚未授予 Calendar 權限，請在 Online Accounts 重新啟用日曆"
        return f"Google Calendar API 無法連線（HTTP {error.code}）"
    if isinstance(error, URLError):
        return "目前無法連線 Google Calendar"

    message = str(error).replace(token, "[token]") if token else str(error)
    return clean_text(message, 240) or "無法讀取 Google Calendar"


def emit(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))


def main() -> int:
    token = ""
    account = ""
    try:
        connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        account_path, account = google_calendar_account(connection)
        token = access_token(connection, account_path)
        default_reminders = default_popup_reminders(token)
        events, fetched_at, range_start, range_end = upcoming_events(
            token, default_reminders
        )
        emit(
            {
                "ok": True,
                "account": account,
                "fetchedAt": fetched_at,
                "rangeStart": range_start,
                "rangeEnd": range_end,
                "defaultPopupReminderMinutes": default_reminders,
                "events": events,
            }
        )
        return 0
    except Exception as error:
        emit(
            {
                "ok": False,
                "account": account,
                "error": safe_error(error, token),
                "events": [],
            }
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
