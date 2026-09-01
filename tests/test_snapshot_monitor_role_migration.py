#!/usr/bin/env python3
"""Regression tests for connector-backed legacy snapshot monitor migration."""

from __future__ import annotations

import os
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "bin" / "hypr-session-state"


def load_session_state(roles: dict[int, str]) -> dict[str, object]:
    with tempfile.TemporaryDirectory() as temporary:
        environment = {
            "HOME": temporary,
            "XDG_CONFIG_HOME": str(Path(temporary) / "config"),
            "XDG_RUNTIME_DIR": str(Path(temporary) / "runtime"),
            **{
                f"UIOS_MONITOR_ROLE_{role}": connector
                for role, connector in roles.items()
            },
        }
        with mock.patch.dict(os.environ, environment, clear=True):
            return runpy.run_path(str(SCRIPT))


def legacy_snapshot(
    *,
    role: int,
    connector: str,
    runtime_id: int,
    include_monitor_id: bool = True,
) -> dict[str, object]:
    workspace_number = role * 10 + 1
    monitor_row: dict[str, object] = {
        "monitor": connector,
        "focused": True,
        "workspace": str(workspace_number),
    }
    if include_monitor_id:
        monitor_row["monitor_id"] = runtime_id
    return {
        "schema": 1,
        "workspaces": [
            {
                "id": workspace_number,
                "name": str(workspace_number),
                "monitor": connector,
                "monitor_id": runtime_id,
                "persistent": False,
                "tiled_layout": "dwindle",
            }
        ],
        "windows": [
            {
                "id": "w0001",
                "monitor": runtime_id,
                "workspace": {"id": workspace_number, "name": str(workspace_number)},
            }
        ],
        "monitor_workspaces": [monitor_row],
        "focus": {"window_id": "w0001", "workspace": str(workspace_number)},
    }


class SnapshotMonitorRoleMigrationTests(unittest.TestCase):
    def test_transient_id_is_remapped_by_connector_for_roles_two_through_nine(self) -> None:
        for role, connector, runtime_id in ((2, "DP-2", 5), (9, "DP-9", 3)):
            with self.subTest(role=role):
                module = load_session_state({role: connector})
                normalize = module["normalize_snapshot_workspaces"]
                result = normalize(
                    legacy_snapshot(
                        role=role,
                        connector=connector,
                        runtime_id=runtime_id,
                    )
                )

                self.assertEqual(result["windows"][0]["monitor"], role)
                self.assertEqual(
                    result["windows"][0]["workspace"],
                    {"id": role * 10 + 1, "name": str(role * 10 + 1)},
                )

    def test_missing_monitor_row_id_omits_incompatible_window(self) -> None:
        module = load_session_state({2: "DP-2"})
        normalize = module["normalize_snapshot_workspaces"]
        snapshot = legacy_snapshot(
            role=2,
            connector="DP-2",
            runtime_id=5,
            include_monitor_id=False,
        )
        result = normalize(snapshot)

        self.assertEqual(result["windows"], [])
        self.assertIsNone(result["focus"]["window_id"])

    def test_ambiguous_runtime_id_omits_incompatible_window(self) -> None:
        module = load_session_state({2: "DP-2", 9: "DP-9"})
        normalize = module["normalize_snapshot_workspaces"]
        snapshot = legacy_snapshot(role=2, connector="DP-2", runtime_id=5)
        snapshot["monitor_workspaces"].append(
            {
                "monitor": "DP-9",
                "monitor_id": 5,
                "focused": False,
                "workspace": "91",
            }
        )

        result = normalize(snapshot)

        self.assertEqual(result["windows"], [])
        self.assertIsNone(result["focus"]["window_id"])

    def test_unmapped_invalid_workspace_is_omitted_instead_of_retargeted(self) -> None:
        module = load_session_state({2: "DP-2"})
        normalize = module["normalize_snapshot_workspaces"]
        snapshot = legacy_snapshot(
            role=2,
            connector="DP-2",
            runtime_id=5,
            include_monitor_id=False,
        )
        snapshot["windows"][0]["workspace"] = {"id": 999, "name": "21"}

        result = normalize(snapshot)

        self.assertEqual(result["windows"], [])
        self.assertIsNone(result["focus"]["window_id"])

    def test_unknown_managed_connector_cannot_create_ownerless_workspace(self) -> None:
        module = load_session_state({0: "eDP-1", 1: "HDMI-A-1"})
        normalize = module["normalize_snapshot_workspaces"]
        snapshot = legacy_snapshot(role=2, connector="DP-9", runtime_id=2)

        result = normalize(snapshot)

        self.assertEqual(result["windows"], [])
        self.assertEqual(result["workspaces"], [])
        self.assertEqual(result["monitor_workspaces"], [])
        self.assertIsNone(result["focus"]["window_id"])
        self.assertEqual(result["focus"]["workspace"], "1")


if __name__ == "__main__":
    unittest.main()
