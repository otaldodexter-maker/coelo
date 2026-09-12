"""Offline fault-injection proof against a fixed Git version of the G1 runner.

No private env files, remote requests, Flutter, SQL, or G1 file writes.
This models command receipts to test client recovery, not backend correctness.
"""
from __future__ import annotations

import argparse
import contextlib
import copy
import io
import json
import subprocess
import sys
import tempfile
import types
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

RUNNER = "docs/reviews/evidence/etapa-2/r08-estrutura/assessments_api_runner.py"
ASSIGNMENT = {"activity_group_link_id": "link-a", "activity_id": "activity-a",
              "institution_id": "institution-a", "unit_id": "unit-a", "group_id": "group-a"}
OTHER = {**ASSIGNMENT, "activity_group_link_id": "link-b", "group_id": "group-b"}


class Backend:
    def __init__(self, *, lose_save=False, two_assignments=False):
        self.lose_save = lose_save
        self.assignments = [ASSIGNMENT, OTHER] if two_assignments else [ASSIGNMENT]
        self.login = (200, {"access_token": "synthetic-offline-token"})
        self.receipts = {}
        self.mutations = Counter()
        self.calls = Counter()
        self.active = False
        self.book_payload = None

    def receipt(self, kind, payload, result):
        key = (kind, payload["request_id"])
        if key in self.receipts:
            original, saved = self.receipts[key]
            assert original == payload, "same receipt key received a different payload"
            return {**saved, "replayed": True}
        self.receipts[key] = (copy.deepcopy(payload), copy.deepcopy(result))
        self.mutations[kind] += 1
        return {**result, "replayed": False}

    def call(self, base, headers, path, payload):
        assert base == "https://offline.invalid", "unexpected service base"
        self.calls[path] += 1
        if path.startswith("/auth/v1/token"):
            return copy.deepcopy(self.login)
        if path.startswith("/auth/v1/logout"):
            return 204, {}
        name = path.rsplit("/", 1)[-1].removeprefix("superadmin_assessment_")
        period = {"id": "period-a", "institution_id": "institution-a",
                  "unit_id": "unit-a", "status": "open"}
        if name == "context_options":
            value = {"assignments": self.assignments, "periods": [period] if self.active else []}
        elif name == "closing_queue":
            value = {}
        elif name == "configuration_read":
            value = None if not self.mutations["save"] else {
                "configuration": {"id": "configuration-a", "status": "active" if self.active else "draft",
                                  "management_version": 2 if self.active else 1},
                "periods": [period] if self.active else [],
            }
        elif name == "save_configuration":
            value = self.receipt("save", payload, {"id": "configuration-a", "version": 1, "status": "draft"})
            if self.lose_save:
                self.lose_save = False
                return 0, None  # Server receipt persisted; client lost the response.
        elif name == "activate_configuration":
            value = self.receipt("activate", payload, {"id": "configuration-a", "version": 2, "status": "active"})
            self.active = True
        elif name == "save_gradebook":
            value = self.receipt("gradebook", payload, {"id": "gradebook-a", "version": 1, "status": "draft"})
            self.book_payload = copy.deepcopy(payload["payload"])
        elif name == "gradebook_read":
            assert payload == {"target_gradebook": "gradebook-a"}
            value = {"gradebook": {**self.book_payload, "id": "gradebook-a", "status": "draft", "management_version": 1}, "students": []}
        else:
            raise AssertionError("unexpected RPC: " + name)
        return 200, {"ok": True, "data": copy.deepcopy(value)}


def invoke(module, backend, directory, *, resume=False, assignment="link-a"):
    ack = directory / "ack.json"
    ack.write_text(json.dumps({"approved": True, "assignment_id": assignment}), encoding="utf-8")
    arguments = ["offline-runner", "--qa-env", "offline-qa", "--app-env", "offline-app",
                 "--manifest", str(directory / "manifest.json"), "--execute",
                 "--ack-file", str(ack), "--assignment-id", assignment]
    if resume:
        arguments.append("--resume")
    def fake_env(path):
        if str(path) == "offline-qa":
            return {"QA_EMAIL": "offline@example.invalid", "QA_PASSWORD": "synthetic"}
        return {"COELO_SUPABASE_URL": "https://offline.invalid", "COELO_SUPABASE_PUBLISHABLE_KEY": "synthetic"}
    with patch.object(sys, "argv", arguments), patch.object(module, "env", fake_env), \
         patch.object(module, "call", backend.call), \
         patch("urllib.request.urlopen", side_effect=AssertionError("network forbidden")), \
         contextlib.redirect_stdout(io.StringIO()):
        return module.main()


def read(directory):
    return json.loads((directory / "manifest.json").read_text(encoding="utf-8"))


def lost_response_recovery(module, directory):
    backend = Backend(lose_save=True)
    try:
        invoke(module, backend, directory)
    except RuntimeError as error:
        assert str(error) == "superadmin_assessment_save_configuration_http_0"
    else:
        raise AssertionError("response loss must stop the attempt")
    partial = read(directory)
    assert partial["executor"]["state"] == "planned"
    assert backend.mutations == {"save": 1}
    ids = copy.deepcopy(partial["request_ids"])
    plan = copy.deepcopy(partial["executor"]["plan"])
    receipts = copy.deepcopy(backend.receipts)
    for login in [(401, {}), (200, {})]:
        backend.login = login
        assert invoke(module, backend, directory, resume=True) == 1, "failed authentication returned success"
        preserved = read(directory)
        assert preserved["executor"] == partial["executor"], "failed login changed a partial executor"
        assert preserved["request_ids"] == ids
        assert backend.receipts == receipts
    # An accidental different assignment is rejected before any command replay.
    backend.login = (200, {"access_token": "synthetic-offline-token"})
    backend.assignments = [ASSIGNMENT, OTHER]
    command_calls = sum(backend.calls[p] for p in backend.calls if "save_" in p or "activate_" in p)
    try:
        invoke(module, backend, directory, resume=True, assignment="link-b")
    except RuntimeError as error:
        assert str(error) == "resume_plan_invalid"
    else:
        raise AssertionError("changed assignment must be refused")
    assert command_calls == sum(backend.calls[p] for p in backend.calls if "save_" in p or "activate_" in p)
    assert backend.receipts == receipts
    backend.assignments = [ASSIGNMENT]
    assert invoke(module, backend, directory, resume=True) == 0
    complete = read(directory)
    assert complete["executor"]["state"] == "complete"
    assert complete["request_ids"] == ids and complete["executor"]["plan"] == plan
    assert backend.mutations == {"save": 1, "activate": 1, "gradebook": 1}
    assert complete["executor"]["save"]["status"] == "draft"  # Historical receipt.
    assert complete["executor"]["activate"]["status"] == "active"
    assert complete["logout_http_status"] == 204
    return {"actual_mutations": dict(backend.mutations), "receipt_count": len(backend.receipts),
            "request_ids_preserved": True, "failed_auth_preserved": True, "changed_assignment_rejected": True}


def two_assignments(module, directory):
    backend = Backend(two_assignments=True)
    code = invoke(module, backend, directory)
    manifest = read(directory)
    assert manifest["executor"]["state"] == "complete"
    assert code == 0, "valid unique target completed but exit was nonzero"
    assert backend.mutations == {"save": 1, "activate": 1, "gradebook": 1}
    assert backend.book_payload["activity_group_link_id"] == "link-a"
    return {"visible_assignments": 2, "selected_target_only": True, "exit_code": code}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    source = subprocess.run(["rtk", "proxy", "git", "show", f"{args.source_sha}:{RUNNER}"], check=True, capture_output=True, text=True, encoding="utf-8").stdout
    module = types.ModuleType("g1_offline_fixed_sha")
    exec(compile(source, f"{args.source_sha}:{RUNNER}", "exec"), module.__dict__)
    results = []
    for case in (lost_response_recovery, two_assignments):
        with tempfile.TemporaryDirectory(prefix="coelo-g4-offline-") as directory:
            try:
                details = case(module, Path(directory))
                results.append({"case": case.__name__, "status": "PASS", **details})
            except Exception as error:
                results.append({"case": case.__name__, "status": "FAIL", "error": type(error).__name__ + ": " + str(error)})
    result = {"source_sha": args.source_sha, "measured_at": datetime.now(timezone.utc).isoformat(),
              "environment": "local synthetic transport; urlopen blocked", "network_requests": 0,
              "results": results, "pass": sum(x["status"] == "PASS" for x in results),
              "fail": sum(x["status"] == "FAIL" for x in results)}
    Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))
    return 1 if result["fail"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
