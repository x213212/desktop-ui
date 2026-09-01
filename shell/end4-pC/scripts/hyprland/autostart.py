#!/usr/bin/env python3
"""Launch configured apps only after a monitor-local workspace focus succeeds."""

import fcntl
import json
import os
from pathlib import Path
import subprocess
import time


def host_settings() -> dict[str, str]:
    settings: dict[str, str] = {}
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    path = config_home / "desktop-ui" / "host.env"
    try:
        for raw_line in path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip().strip("'\"")
            if key.startswith("UIOS_MONITOR_ROLE_") and value:
                settings[key] = value
    except FileNotFoundError:
        pass
    for role in range(10):
        key = f"UIOS_MONITOR_ROLE_{role}"
        value = os.environ.get(key, "").strip()
        if value:
            settings[key] = value
    return settings


def query_monitors() -> list[dict]:
    try:
        result = subprocess.run(
            ["hyprctl", "monitors", "-j"],
            check=True,
            capture_output=True,
            text=True,
            timeout=2,
        )
        monitors = json.loads(result.stdout)
        return monitors if isinstance(monitors, list) else []
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return []


def role_connectors(monitors: list[dict], settings: dict[str, str]) -> dict[int, str]:
    """Mirror desktop_ui_monitor_role(), including managed fail-closed mode."""
    configured: dict[int, str] = {}
    seen: set[str] = set()
    for role in range(10):
        connector = settings.get(f"UIOS_MONITOR_ROLE_{role}", "").strip()
        if connector and connector not in seen:
            configured[role] = connector
            seen.add(connector)
    if configured:
        return configured

    def monitor_sort_key(monitor: dict) -> tuple[int, str]:
        try:
            monitor_id = int(monitor.get("id", 9999))
        except (TypeError, ValueError):
            monitor_id = 9999
        return monitor_id, str(monitor.get("name", ""))

    assigned: dict[int, str] = {}
    used: set[int] = set()
    ordered = sorted(monitors, key=monitor_sort_key)
    for monitor in ordered:
        connector = str(monitor.get("name", ""))
        if not connector:
            continue
        try:
            preferred = int(monitor.get("id", -1))
        except (TypeError, ValueError):
            preferred = -1
        role = preferred if 0 <= preferred <= 9 and preferred not in used else None
        if role is None:
            role = next((candidate for candidate in range(10) if candidate not in used), None)
        if role is not None:
            assigned[role] = connector
            used.add(role)
    return assigned


def focus_workspace(workspace: int, settings: dict[str, str]) -> bool:
    if not 1 <= workspace <= 100:
        return False
    monitors = query_monitors()
    role = (workspace - 1) // 10
    slot = (workspace - 1) % 10 + 1
    connector = role_connectors(monitors, settings).get(role)
    active_connectors = {str(monitor.get("name", "")) for monitor in monitors}
    if not connector or connector not in active_connectors:
        return False

    expression = (
        f"end4_workspace_focus_slot({slot},"
        f"{json.dumps(connector)},{workspace})"
    )
    try:
        subprocess.run(
            ["hyprctl", "dispatch", expression],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=2,
        )
    except (OSError, subprocess.SubprocessError):
        return False

    # A disappearing output or a single-output merged group can reject the
    # semantic endpoint. Never launch onto whichever workspace happens to be
    # focused after that rejection.
    for monitor in query_monitors():
        if str(monitor.get("name", "")) != connector:
            continue
        active = monitor.get("activeWorkspace") or {}
        try:
            return int(active.get("id", 0)) == workspace
        except (TypeError, ValueError):
            return False
    return False


runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
runtime_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
lock = (runtime_dir / "desktop-ui-autostart.lock").open("a+", encoding="utf-8")
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    raise SystemExit(0)

config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
try:
    data = json.loads(
        (config_home / "illogical-impulse" / "config.json").read_text(encoding="utf-8")
    )
except (OSError, json.JSONDecodeError):
    raise SystemExit(0)

autostart = data.get("hyprland", {}).get("autostartApps", {})
if not autostart.get("enable", False):
    raise SystemExit(0)

settings = host_settings()
for app in autostart.get("apps", []):
    command = str(app.get("cmd", "")).strip()
    try:
        workspace = int(app.get("workspace", 1))
        delay = max(0.0, float(app.get("delay", 0)))
    except (TypeError, ValueError):
        continue
    if not command or not focus_workspace(workspace, settings):
        continue

    subprocess.Popen(
        ["bash", "-lc", os.path.expanduser(command)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True,
        start_new_session=True,
    )
    time.sleep(delay)
