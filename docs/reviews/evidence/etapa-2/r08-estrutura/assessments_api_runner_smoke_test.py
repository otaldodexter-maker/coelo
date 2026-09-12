"""Offline guard for resume manifest preservation; never calls a remote API."""
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


RUNNER = Path(__file__).with_name("assessments_api_runner.py")
SPEC = importlib.util.spec_from_file_location("assessments_api_runner", RUNNER)
assert SPEC and SPEC.loader
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class ResumeSafetyTest(unittest.TestCase):
    def test_login_failure_preserves_partial_resume_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            qa, app, ack, manifest = (root / name for name in ("qa.env", "app.env", "ack.json", "manifest.json"))
            qa.write_text("QA_EMAIL=qa@example.test\nQA_PASSWORD=not-a-secret\n", encoding="utf-8")
            app.write_text("COELO_SUPABASE_URL=https://example.test\nCOELO_SUPABASE_PUBLISHABLE_KEY=not-a-secret\n", encoding="utf-8")
            ack.write_text('{"approved": true, "assignment_id": "target"}\n', encoding="utf-8")
            manifest.write_text(json.dumps({"mode": "execute", "mutations": True, "request_ids": {}, "executor": {"enabled": True, "state": "planned", "plan": {}}}), encoding="utf-8")
            arguments = ["runner", "--qa-env", str(qa), "--app-env", str(app), "--manifest", str(manifest), "--execute", "--resume", "--ack-file", str(ack), "--assignment-id", "target"]
            with patch.object(sys, "argv", arguments), patch.object(runner, "call", return_value=(401, {})):
                self.assertEqual(runner.main(), 1)
            self.assertEqual(json.loads(manifest.read_text(encoding="utf-8"))["executor"]["state"], "planned")

    def test_login_without_token_preserves_partial_resume_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            qa, app, ack, manifest = (root / name for name in ("qa.env", "app.env", "ack.json", "manifest.json"))
            qa.write_text("QA_EMAIL=qa@example.test\nQA_PASSWORD=not-a-secret\n", encoding="utf-8")
            app.write_text("COELO_SUPABASE_URL=https://example.test\nCOELO_SUPABASE_PUBLISHABLE_KEY=not-a-secret\n", encoding="utf-8")
            ack.write_text('{"approved": true, "assignment_id": "target"}\n', encoding="utf-8")
            manifest.write_text(json.dumps({"mode": "execute", "mutations": True, "request_ids": {}, "executor": {"enabled": True, "state": "planned", "plan": {}}}), encoding="utf-8")
            arguments = ["runner", "--qa-env", str(qa), "--app-env", str(app), "--manifest", str(manifest), "--execute", "--resume", "--ack-file", str(ack), "--assignment-id", "target"]
            with patch.object(sys, "argv", arguments), patch.object(runner, "call", return_value=(200, {})):
                self.assertEqual(runner.main(), 1)
            self.assertEqual(json.loads(manifest.read_text(encoding="utf-8"))["executor"]["state"], "planned")

    def test_resume_rejects_another_group_link_before_mutation(self) -> None:
        assignment = {"activity_group_link_id": "target", "activity_id": "activity", "institution_id": "institution", "unit_id": "unit", "group_id": "group"}
        request_ids = {"save_configuration": "00000000-0000-4000-8000-000000000001", "activate_configuration": "00000000-0000-4000-8000-000000000002", "save_gradebook": "00000000-0000-4000-8000-000000000003"}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            qa, app, ack, manifest = (root / name for name in ("qa.env", "app.env", "ack.json", "manifest.json"))
            qa.write_text("QA_EMAIL=qa@example.test\nQA_PASSWORD=not-a-secret\n", encoding="utf-8")
            app.write_text("COELO_SUPABASE_URL=https://example.test\nCOELO_SUPABASE_PUBLISHABLE_KEY=not-a-secret\n", encoding="utf-8")
            ack.write_text('{"approved": true, "assignment_id": "target"}\n', encoding="utf-8")
            manifest.write_text(json.dumps({"mode": "execute", "mutations": True, "request_ids": request_ids, "executor": {"enabled": True, "assignment_id": "other-link", "state": "planned", "plan": runner._execution_plan(assignment, request_ids)}}), encoding="utf-8")
            paths: list[str] = []
            def fake_call(_base: str, _headers: dict[str, str], path: str, _payload: object) -> tuple[int, object]:
                paths.append(path)
                if path.startswith("/auth/v1/token"):
                    return 200, {"access_token": "fake"}
                if path.endswith("context_options"):
                    return 200, {"ok": True, "data": {"assignments": [assignment], "periods": []}}
                if path.endswith("closing_queue"):
                    return 200, {"ok": True, "data": {}}
                if path.startswith("/auth/v1/logout"):
                    return 204, {}
                self.fail("unexpected_rpc:" + path)
                return 0, None
            arguments = ["runner", "--qa-env", str(qa), "--app-env", str(app), "--manifest", str(manifest), "--execute", "--resume", "--ack-file", str(ack), "--assignment-id", "target"]
            with patch.object(sys, "argv", arguments), patch.object(runner, "call", side_effect=fake_call):
                with self.assertRaisesRegex(RuntimeError, "resume_plan_invalid"):
                    runner.main()
            self.assertFalse(any("configuration_read" in path or "save_" in path for path in paths))

    def test_resume_rejects_changed_gradebook_payload_before_save(self) -> None:
        assignment = {"activity_group_link_id": "target", "activity_id": "activity", "institution_id": "institution", "unit_id": "unit", "group_id": "group"}
        request_ids = {"save_configuration": "00000000-0000-4000-8000-000000000001", "activate_configuration": "00000000-0000-4000-8000-000000000002", "save_gradebook": "00000000-0000-4000-8000-000000000003"}
        configuration = {"id": "configuration", "version": 1, "status": "draft"}
        active = {"id": "configuration", "status": "active", "management_version": 2}
        period = {"id": "period", "institution_id": "institution", "unit_id": "unit", "status": "open"}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            qa, app, ack, manifest = (root / name for name in ("qa.env", "app.env", "ack.json", "manifest.json"))
            qa.write_text("QA_EMAIL=qa@example.test\nQA_PASSWORD=not-a-secret\n", encoding="utf-8")
            app.write_text("COELO_SUPABASE_URL=https://example.test\nCOELO_SUPABASE_PUBLISHABLE_KEY=not-a-secret\n", encoding="utf-8")
            ack.write_text('{"approved": true, "assignment_id": "target"}\n', encoding="utf-8")
            plan = runner._execution_plan(assignment, request_ids)
            manifest.write_text(json.dumps({"mode": "execute", "mutations": True, "request_ids": request_ids, "executor": {"enabled": True, "assignment_id": "target", "state": "activated", "plan": plan, "save": configuration, "activate": {"status": "active", "version": 2}, "gradebook": {"request_id": request_ids["save_gradebook"], "gradebook_id": None, "expected_version": 0, "payload": {"activity_group_link_id": "wrong", "period_id": "period", "configuration_id": "configuration", "students": []}, "reason": None}}}), encoding="utf-8")
            paths: list[str] = []
            def fake_call(_base: str, _headers: dict[str, str], path: str, _payload: object) -> tuple[int, object]:
                paths.append(path)
                if path.startswith("/auth/v1/token"):
                    return 200, {"access_token": "fake"}
                if path.endswith("context_options"):
                    return 200, {"ok": True, "data": {"assignments": [assignment], "periods": [period]}}
                if path.endswith("closing_queue"):
                    return 200, {"ok": True, "data": {}}
                if path.endswith("configuration_read"):
                    return 200, {"ok": True, "data": {"configuration": active, "periods": [period]}}
                if path.endswith("save_configuration"):
                    return 200, {"ok": True, "data": {**configuration, "replayed": True}}
                if path.startswith("/auth/v1/logout"):
                    return 204, {}
                self.fail("unexpected_rpc:" + path)
                return 0, None
            arguments = ["runner", "--qa-env", str(qa), "--app-env", str(app), "--manifest", str(manifest), "--execute", "--resume", "--ack-file", str(ack), "--assignment-id", "target"]
            with patch.object(sys, "argv", arguments), patch.object(runner, "call", side_effect=fake_call):
                with self.assertRaisesRegex(RuntimeError, "resume_gradebook_plan_mismatch"):
                    runner.main()
            self.assertFalse(any("save_gradebook" in path for path in paths))

    def test_execute_succeeds_with_two_visible_assignments_when_target_is_unique(self) -> None:
        assignment = {"activity_group_link_id": "target", "activity_id": "activity", "institution_id": "institution", "unit_id": "unit", "group_id": "group"}
        other = {"activity_group_link_id": "other", "activity_id": "other-activity", "institution_id": "institution", "unit_id": "unit", "group_id": "other-group"}
        configuration = {"id": "configuration", "version": 1, "status": "draft"}
        period = {"id": "period", "institution_id": "institution", "unit_id": "unit", "status": "open"}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            qa, app, ack, manifest = (root / name for name in ("qa.env", "app.env", "ack.json", "manifest.json"))
            qa.write_text("QA_EMAIL=qa@example.test\nQA_PASSWORD=not-a-secret\n", encoding="utf-8")
            app.write_text("COELO_SUPABASE_URL=https://example.test\nCOELO_SUPABASE_PUBLISHABLE_KEY=not-a-secret\n", encoding="utf-8")
            ack.write_text('{"approved": true, "assignment_id": "target"}\n', encoding="utf-8")
            context_calls, read_calls = 0, 0
            def fake_call(_base: str, _headers: dict[str, str], path: str, _payload: object) -> tuple[int, object]:
                nonlocal context_calls, read_calls
                if path.startswith("/auth/v1/token"):
                    return 200, {"access_token": "fake"}
                if path.endswith("context_options"):
                    context_calls += 1
                    return 200, {"ok": True, "data": {"assignments": [assignment, other], "periods": [period] if context_calls == 3 else []}}
                if path.endswith("closing_queue"):
                    return 200, {"ok": True, "data": {}}
                if path.endswith("configuration_read"):
                    read_calls += 1
                    value = None if read_calls == 1 else {"configuration": {**configuration, "status": "active", "management_version": 2} if read_calls == 3 else configuration, "periods": [period]}
                    return 200, {"ok": True, "data": value}
                if path.endswith("save_configuration"):
                    return 200, {"ok": True, "data": {**configuration, "replayed": True} if read_calls == 1 else configuration}
                if path.endswith("activate_configuration"):
                    return 200, {"ok": True, "data": {"status": "active", "version": 2}}
                if path.endswith("save_gradebook"):
                    return 200, {"ok": True, "data": {"id": "book", "version": 1}}
                if path.endswith("gradebook_read"):
                    return 200, {"ok": True, "data": {"gradebook": {"id": "book", "activity_group_link_id": "target", "period_id": "period", "configuration_id": "configuration", "status": "draft", "management_version": 1}, "students": []}}
                if path.startswith("/auth/v1/logout"):
                    return 204, {}
                self.fail("unexpected_rpc:" + path)
                return 0, None
            arguments = ["runner", "--qa-env", str(qa), "--app-env", str(app), "--manifest", str(manifest), "--execute", "--ack-file", str(ack), "--assignment-id", "target"]
            with patch.object(sys, "argv", arguments), patch.object(runner, "call", side_effect=fake_call):
                self.assertEqual(runner.main(), 0)
            self.assertEqual(json.loads(manifest.read_text(encoding="utf-8"))["executor"]["state"], "complete")


if __name__ == "__main__":
    unittest.main()
