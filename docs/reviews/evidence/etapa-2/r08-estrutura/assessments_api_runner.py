"""Assessment API runner. Default dry-run is read-only and writes a redacted manifest once."""
from __future__ import annotations

import argparse
import json
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path


def env(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            result[key.strip()] = value.strip().strip("\"'")
    return result


def call(base: str, headers: dict[str, str], path: str, payload: object) -> tuple[int, object]:
    request = urllib.request.Request(
        base + path, data=json.dumps(payload).encode(), headers=headers, method="POST"
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
            try: return response.status, json.loads(raw or b"null")
            except json.JSONDecodeError: return response.status, None
    except urllib.error.HTTPError as error:
        try: return error.code, json.loads(error.read() or b"null")
        except json.JSONDecodeError: return error.code, None
    except urllib.error.URLError:
        return 0, None


def data(body: object) -> object:
    if not isinstance(body, dict) or body.get("ok") is not True or "data" not in body:
        raise RuntimeError("rpc_envelope_invalid")
    return body["data"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--qa-env", required=True)
    parser.add_argument("--app-env", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--ack-file")
    parser.add_argument("--assignment-id")
    args = parser.parse_args()
    output = Path(args.manifest)
    if output.exists():
        raise SystemExit("manifest_exists_do_not_overwrite")
    if args.execute and (not args.ack_file or not args.assignment_id):
        raise SystemExit("execution_requires_G5_C0_ack_file")
    qa, app = env(Path(args.qa_env)), env(Path(args.app_env))
    base, key = app.get("COELO_SUPABASE_URL", "").rstrip("/"), app.get("COELO_SUPABASE_PUBLISHABLE_KEY", "")
    if not base or not key or not qa.get("QA_EMAIL") or not qa.get("QA_PASSWORD"):
        raise SystemExit("private_environment_incomplete")
    headers = {"apikey": key, "Content-Type": "application/json"}
    manifest: dict[str, object] = {
        "mode": "dry-run", "mutations": False, "measured_at": datetime.now(timezone.utc).isoformat(),
        "request_ids": {name: str(uuid.uuid4()) for name in ("save_configuration", "activate_configuration", "save_gradebook", "submit", "review", "return")},
    }
    status, login = call(base, headers, "/auth/v1/token?grant_type=password", {"email": qa["QA_EMAIL"], "password": qa["QA_PASSWORD"]})
    manifest["login_http_status"] = status
    if status == 200 and isinstance(login, dict) and isinstance(login.get("access_token"), str):
        headers["Authorization"] = "Bearer " + login["access_token"]
        try:
            for name, payload in (("context_options", {}), ("closing_queue", {})):
                http, body = call(base, headers, f"/rest/v1/rpc/superadmin_assessment_{name}", payload)
                entry: dict[str, object] = {"http_status": http}
                value = data(body) if http == 200 else None
                if isinstance(value, dict):
                    entry["keys"] = sorted(value.keys())
                    body = value
                if name == "context_options":
                    entry["assignment_count"] = len(body.get("assignments", []))
                    entry["period_count"] = len(body.get("periods", []))
                    assignments = body.get("assignments", [])
                    entry["strict_projection"] = (
                        isinstance(assignments, list) and len(assignments) == 1
                        and isinstance(assignments[0], dict)
                        and all(key in assignments[0] for key in ("activity_group_link_id", "activity_id", "institution_id", "unit_id", "group_id"))
                    )
                manifest[name] = entry
            if not args.execute and (
                manifest["context_options"].get("http_status") != 200
                or manifest["context_options"].get("strict_projection") is not True
            ):
                raise RuntimeError("dry_run_projection_invalid")
            if args.execute:
                assignments = data(call(base, headers, "/rest/v1/rpc/superadmin_assessment_context_options", {})[1])["assignments"]
                matches = [item for item in assignments if isinstance(item, dict) and item.get("activity_group_link_id") == args.assignment_id]
                if len(matches) != 1:
                    raise RuntimeError("assignment_target_not_unique")
                assignment = matches[0]
                prior = data(_rpc(base, headers, "superadmin_assessment_configuration_read", {"target_activity": assignment["activity_id"], "target_unit": assignment["unit_id"]}))
                if prior is not None:
                    raise RuntimeError("configuration_already_exists")
                plan = _execution_plan(assignment, manifest["request_ids"])
                manifest["executor"] = {"enabled": True, "ack_file": args.ack_file, "plan": plan}
                output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
                saved = _rpc(base, headers, "superadmin_assessment_save_configuration", plan["save_configuration"])
                configuration = data(saved)
                replay = data(_rpc(base, headers, "superadmin_assessment_save_configuration", plan["save_configuration"]))
                if (not isinstance(configuration, dict) or not isinstance(replay, dict)
                    or replay.get("id") != configuration.get("id")
                    or replay.get("version") != configuration.get("version")
                    or replay.get("status") != "draft" or replay.get("replayed") is not True):
                    raise RuntimeError("configuration_replay_invalid")
                read = data(_rpc(base, headers, "superadmin_assessment_configuration_read", {"target_activity": assignment["activity_id"], "target_unit": assignment["unit_id"]}))
                if not isinstance(read, dict) or read.get("configuration", {}).get("id") != configuration.get("id"):
                    raise RuntimeError("configuration_reload_invalid")
                activated = data(_rpc(base, headers, "superadmin_assessment_activate_configuration", {"request_id": plan["activate_request_id"], "configuration_id": configuration["id"], "expected_version": configuration["version"]}))
                if activated.get("status") != "active":
                    raise RuntimeError("activation_invalid")
                opened = data(_rpc(base, headers, "superadmin_assessment_context_options", {}))
                periods = opened.get("periods", []) if isinstance(opened, dict) else []
                period = next((item for item in periods if item.get("status") == "open" and item.get("unit_id") == assignment["unit_id"]), None)
                if not isinstance(period, dict):
                    raise RuntimeError("open_period_missing")
                gradebook = {"request_id": plan["gradebook_request_id"], "gradebook_id": None, "expected_version": 0, "payload": {"activity_group_link_id": assignment["activity_group_link_id"], "period_id": period["id"], "configuration_id": configuration["id"], "students": []}, "reason": None}
                manifest["executor"]["gradebook"] = gradebook
                output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
                book = data(_rpc(base, headers, "superadmin_assessment_save_gradebook", gradebook))
                reread = data(_rpc(base, headers, "superadmin_assessment_gradebook_read", {"target_gradebook": book["id"]}))
                if not isinstance(reread, dict) or reread.get("gradebook", {}).get("id") != book["id"]:
                    raise RuntimeError("gradebook_reload_invalid")
        finally:
            manifest["logout_http_status"] = call(base, headers, "/auth/v1/logout?scope=local", {})[0]
    manifest["executor"] = {"enabled": False, "ack_required": "G5_C0", "sequence": ["save_configuration", "activate_configuration", "save_gradebook"], "payload_keys": {"save_configuration": ["activity_id", "institution_id", "unit_id", "periods", "instruments"], "save_gradebook": ["activity_group_link_id", "period_id", "configuration_id", "students"]}}
    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"mode": "dry-run", "mutations": False, "manifest": str(output)}))
    return 0 if status == 200 and manifest.get("context_options", {}).get("strict_projection") is True else 1


def _rpc(base: str, headers: dict[str, str], name: str, payload: object) -> object:
    status, body = call(base, headers, "/rest/v1/rpc/" + name, payload)
    if status != 200:
        raise RuntimeError(name + "_http_" + str(status))
    return body


def _execution_plan(assignment: dict[str, object], request_ids: dict[str, str]) -> dict[str, object]:
    now = datetime.now(timezone.utc)
    period = {"name": "R08 sintético", "ordinal": 1, "year": now.year, "starts_at": now.isoformat(), "ends_at": now.replace(month=12, day=31).isoformat(), "entry_closes_at": now.replace(month=12, day=31).isoformat(), "family_release_at": now.replace(month=12, day=31).isoformat(), "time_zone": "America/Sao_Paulo"}
    payload = {"activity_id": assignment["activity_id"], "institution_id": assignment["institution_id"], "unit_id": assignment["unit_id"], "periodicity": "annual", "result_scale_kind": "numeric_0_10", "scale_options": {"step": 0.5}, "concepts": [], "periods": [period], "allow_final_override": False, "instruments": [{"name": "Instrumento R08", "weight": 100, "sort_order": 0}], "categories": []}
    return {"save_configuration": {"request_id": request_ids["save_configuration"], "configuration_id": None, "expected_version": 0, "payload": payload}, "activate_request_id": request_ids["activate_configuration"], "gradebook_request_id": request_ids["save_gradebook"]}


if __name__ == "__main__":
    raise SystemExit(main())
