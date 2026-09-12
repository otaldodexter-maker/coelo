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


if __name__ == "__main__":
    unittest.main()
