#!/usr/bin/env python3
"""Pure mock tests for same-eval compositor topology fencing."""

from __future__ import annotations

import os
from pathlib import Path
import re
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


class InsertedConnectorEval:
    """Model a connector appearing after Python's final JSON recheck."""

    def __init__(self, live_roles: dict[str, int | None]) -> None:
        self.live_roles = live_roles
        self.codes: list[str] = []
        self.dispatches = 0

    def __call__(self, code: str, quiet: bool = False) -> bool:
        del quiet
        self.codes.append(code)
        assignments = {
            connector: int(role)
            for connector, role in re.findall(
                r'expected_monitor_roles\["([A-Za-z0-9_.:-]+)"\] = ([0-9]+)',
                code,
            )
        }
        guard_position = code.find("local topology_monitors = hl.get_monitors()")
        dispatch_position = code.find("hl.dispatch(")
        if guard_position < 0 or (
            dispatch_position >= 0 and guard_position > dispatch_position
        ):
            raise AssertionError("topology guard must precede every dispatcher")

        topology_matches = len(assignments) == len(self.live_roles) and all(
            connector in assignments and assignments[connector] == role
            for connector, role in self.live_roles.items()
        )
        if not topology_matches:
            return False
        self.dispatches += code.count("hl.dispatch(")
        return True


class CompositorTopologyGuardTests(unittest.TestCase):
    def setUp(self) -> None:
        self.module = load_session_state({0: "eDP-1", 1: "HDMI-A-1"})
        self.expected = [
            {"name": "eDP-1", "id": 0, "disabled": False},
            {"name": "HDMI-A-1", "id": 1, "disabled": False},
        ]
        self.inserted = InsertedConnectorEval(
            {"eDP-1": 0, "HDMI-A-1": 1, "DP-9": None}
        )
        function_globals = self.module[
            "commit_inactive_workspace_routes"
        ].__globals__
        function_globals["eval_lua"] = self.inserted
        function_globals["hypr_option_bool"] = lambda _name: True

    def test_inactive_route_has_zero_dispatch_after_connector_insert(self) -> None:
        commit = self.module["commit_inactive_workspace_routes"]

        committed = commit(
            [
                {
                    "workspace": "2",
                    "from_monitor": "HDMI-A-1",
                    "to_monitor": "eDP-1",
                }
            ],
            self.expected,
            quiet=True,
        )

        self.assertEqual(committed, 0)
        self.assertEqual(self.inserted.dispatches, 0)
        self.assertEqual(len(self.inserted.codes), 1)

    def test_dynamic_hotplug_and_recovery_both_fence_inserted_connector(self) -> None:
        commit = self.module["commit_dynamic_hotplug_workspace_transaction"]

        committed = commit(
            [
                {
                    "kind": "route-source",
                    "source": 11,
                    "source_connector": "HDMI-A-1",
                    "activate_source": True,
                    "activation_guard": 1,
                }
            ],
            [
                {
                    **self.expected[0],
                    "focused": True,
                    "activeWorkspace": {"id": 1, "name": "1"},
                },
                self.expected[1],
            ],
            {},
            quiet=True,
        )

        self.assertEqual(committed, 0)
        self.assertEqual(self.inserted.dispatches, 0)
        self.assertEqual(len(self.inserted.codes), 2)

    def test_repair_guarded_transaction_fences_inserted_connector(self) -> None:
        commit = self.module["commit_guarded_workspace_transaction"]

        committed = commit(
            [
                'hl.dsp.window.move({ workspace = "1", follow = false, '
                'window = "address:0x1" })'
            ],
            [{"workspace": "2"}],
            quiet=True,
            expected_monitors=self.expected,
        )

        self.assertEqual(committed, 0)
        self.assertEqual(self.inserted.dispatches, 0)
        self.assertEqual(len(self.inserted.codes), 1)

    def test_unknown_planned_connector_is_rejected_before_eval(self) -> None:
        commit = self.module["commit_inactive_workspace_routes"]

        committed = commit(
            [{"workspace": "2", "to_monitor": "eDP-1"}],
            [{"name": "DP-9", "id": 2, "disabled": False}],
            quiet=True,
        )

        self.assertEqual(committed, 0)
        self.assertEqual(self.inserted.codes, [])
        self.assertEqual(self.inserted.dispatches, 0)


if __name__ == "__main__":
    unittest.main()
