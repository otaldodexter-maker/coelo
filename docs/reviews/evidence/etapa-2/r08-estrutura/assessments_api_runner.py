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
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--ack-file")
    parser.add_argument("--assignment-id")
    args = parser.parse_args()
    output = Path(args.manifest)
    if args.resume and not args.execute:
        raise SystemExit("resume_requires_execute")
    prior_manifest: dict[str, object] | None = None
    if output.exists() and not args.resume:
        raise SystemExit("manifest_exists_do_not_overwrite")
    if args.resume:
        try:
            loaded = json.loads(output.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise SystemExit("resume_manifest_invalid") from error
        if not isinstance(loaded, dict):
            raise SystemExit("resume_manifest_invalid")
        prior_manifest = loaded
    if args.execute and (not args.ack_file or not args.assignment_id or not Path(args.ack_file).is_file()):
        raise SystemExit("execution_requires_G5_C0_ack_file")
    qa, app = env(Path(args.qa_env)), env(Path(args.app_env))
    base, key = app.get("COELO_SUPABASE_URL", "").rstrip("/"), app.get("COELO_SUPABASE_PUBLISHABLE_KEY", "")
    if not base or not key or not qa.get("QA_EMAIL") or not qa.get("QA_PASSWORD"):
        raise SystemExit("private_environment_incomplete")
    headers = {"apikey": key, "Content-Type": "application/json"}
    manifest: dict[str, object] = prior_manifest or {
        "mode": "dry-run", "mutations": False, "measured_at": datetime.now(timezone.utc).isoformat(),
        "request_ids": {name: str(uuid.uuid4()) for name in ("save_configuration", "activate_configuration", "save_gradebook", "submit", "review", "return")},
    }
    if args.resume:
        manifest["resumed_at"] = datetime.now(timezone.utc).isoformat()
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
                ack = json.loads(Path(args.ack_file).read_text(encoding="utf-8"))
                if ack.get("approved") is not True or ack.get("assignment_id") != args.assignment_id:
                    raise RuntimeError("ack_invalid_for_assignment")
                if args.resume:
                    executor = manifest.get("executor")
                    request_ids = manifest.get("request_ids")
                    if (manifest.get("mode") != "execute" or manifest.get("mutations") is not True
                        or not isinstance(executor, dict) or executor.get("enabled") is not True
                        or executor.get("state") == "complete" or not isinstance(executor.get("plan"), dict)
                        or not isinstance(request_ids, dict)
                        or any(not _is_uuid(request_ids.get(name)) for name in ("save_configuration", "activate_configuration", "save_gradebook"))):
                        raise RuntimeError("resume_plan_invalid")
                    plan = executor["plan"]
                    if plan != _execution_plan(assignment, request_ids):
                        raise RuntimeError("resume_plan_mismatch")
                    save_payload = plan.get("save_configuration") if isinstance(plan, dict) else None
                    target = save_payload.get("payload") if isinstance(save_payload, dict) else None
                    if (not isinstance(target, dict) or target.get("activity_id") != assignment["activity_id"]
                        or target.get("institution_id") != assignment["institution_id"]
                        or target.get("unit_id") != assignment["unit_id"]):
                        raise RuntimeError("resume_target_mismatch")
                else:
                    prior = data(_rpc(base, headers, "superadmin_assessment_configuration_read", {"target_activity": assignment["activity_id"], "target_unit": assignment["unit_id"]}))
                    if prior is not None:
                        raise RuntimeError("configuration_already_exists")
                    plan = _execution_plan(assignment, manifest["request_ids"])
                    manifest["mode"] = "execute"
                    manifest["mutations"] = True
                    manifest["executor"] = {"enabled": True, "ack_file": args.ack_file, "plan": plan, "state": "planned"}
                output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
                saved_configuration = manifest["executor"].get("save")
                if isinstance(saved_configuration, dict):
                    configuration = saved_configuration
                    resumed = data(_rpc(base, headers, "superadmin_assessment_configuration_read", {"target_activity": assignment["activity_id"], "target_unit": assignment["unit_id"]}))
                    if not isinstance(resumed, dict) or resumed.get("configuration", {}).get("id") != configuration.get("id"):
                        raise RuntimeError("resume_configuration_missing")
                else:
                    saved = _rpc(base, headers, "superadmin_assessment_save_configuration", plan["save_configuration"])
                    configuration = data(saved)
                    manifest["executor"]["save"] = configuration
                    manifest["executor"]["state"] = "configuration_saved"
                    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
                replay = data(_rpc(base, headers, "superadmin_assessment_save_configuration", plan["save_configuration"]))
                if (not isinstance(configuration, dict) or not isinstance(replay, dict)
                    or replay.get("id") != configuration.get("id")
                    or replay.get("version") != configuration.get("version")
                    or replay.get("status") != "draft" or replay.get("replayed") is not True):
                    raise RuntimeError("configuration_replay_invalid")
                read = data(_rpc(base, headers, "superadmin_assessment_configuration_read", {"target_activity": assignment["activity_id"], "target_unit": assignment["unit_id"]}))
                if not isinstance(read, dict) or read.get("configuration", {}).get("id") != configuration.get("id"):
                    raise RuntimeError("configuration_reload_invalid")
                activated = manifest["executor"].get("activate")
                if not isinstance(activated, dict):
                    activated = data(_rpc(base, headers, "superadmin_assessment_activate_configuration", {"request_id": plan["activate_request_id"], "configuration_id": configuration["id"], "expected_version": configuration["version"]}))
                if activated.get("status") != "active":
                    raise RuntimeError("activation_invalid")
                manifest["executor"]["activate"] = activated
                manifest["executor"]["state"] = "activated"
                output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
                opened = data(_rpc(base, headers, "superadmin_assessment_context_options", {}))
                periods = opened.get("periods", []) if isinstance(opened, dict) else []
                active_read = data(_rpc(base, headers, "superadmin_assessment_configuration_read", {"target_activity": assignment["activity_id"], "target_unit": assignment["unit_id"]}))
                active = active_read.get("configuration", {}) if isinstance(active_read, dict) else {}
                period = next((item for item in active_read.get("periods", []) if item.get("status") == "open"), None)
                if active.get("id") != configuration["id"] or active.get("status") != "active" or active.get("management_version") != activated.get("version"):
                    raise RuntimeError("activation_reload_invalid")
                if not isinstance(period, dict):
                    raise RuntimeError("open_period_missing")
                visible = [item for item in periods if item.get("id") == period.get("id") and item.get("institution_id") == assignment["institution_id"] and item.get("unit_id") == assignment["unit_id"] and item.get("status") == "open"]
                if len(visible) != 1:
                    raise RuntimeError("context_period_projection_invalid")
                gradebook = manifest["executor"].get("gradebook")
                if not isinstance(gradebook, dict):
                    gradebook = {"request_id": plan["gradebook_request_id"], "gradebook_id": None, "expected_version": 0, "payload": {"activity_group_link_id": assignment["activity_group_link_id"], "period_id": period["id"], "configuration_id": configuration["id"], "students": []}, "reason": None}
                    manifest["executor"]["gradebook"] = gradebook
                    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
                book = manifest["executor"].get("gradebook_result")
                if not isinstance(book, dict):
                    book = data(_rpc(base, headers, "superadmin_assessment_save_gradebook", gradebook))
                    manifest["executor"]["gradebook_result"] = book
                    manifest["executor"]["state"] = "gradebook_saved"
                    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
                reread = data(_rpc(base, headers, "superadmin_assessment_gradebook_read", {"target_gradebook": book["id"]}))
                loaded = reread.get("gradebook", {}) if isinstance(reread, dict) else {}
                if (not isinstance(loaded, dict) or loaded.get("id") != book["id"]
                    or loaded.get("activity_group_link_id") != assignment["activity_group_link_id"]
                    or loaded.get("period_id") != period["id"] or loaded.get("configuration_id") != configuration["id"]
                    or loaded.get("status") != "draft" or not isinstance(reread.get("students"), list)
                    or loaded.get("management_version") != book.get("version")):
                    raise RuntimeError("gradebook_reload_invalid")
        finally:
            manifest["logout_http_status"] = call(base, headers, "/auth/v1/logout?scope=local", {})[0]
    if not args.execute:
        manifest["executor"] = {"enabled": False, "ack_required": "G5_C0", "sequence": ["save_configuration", "activate_configuration", "save_gradebook"], "payload_keys": {"save_configuration": ["activity_id", "institution_id", "unit_id", "periods", "instruments"], "save_gradebook": ["activity_group_link_id", "period_id", "configuration_id", "students"]}}
    elif isinstance(manifest.get("executor"), dict):
        manifest["executor"]["state"] = "complete"
    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"mode": manifest["mode"], "mutations": manifest["mutations"], "manifest": str(output)}))
    return 0 if status == 200 and manifest.get("context_options", {}).get("strict_projection") is True else 1


def _rpc(base: str, headers: dict[str, str], name: str, payload: object) -> object:
    status, body = call(base, headers, "/rest/v1/rpc/" + name, payload)
    if status != 200:
        raise RuntimeError(name + "_http_" + str(status))
    return body


def _execution_plan(assignment: dict[str, object], request_ids: dict[str, str]) -> dict[str, object]:
    period = {"name": "R08 sintético", "ordinal": 1, "academic_year": 2026, "starts_on": "2026-09-12", "ends_on": "2026-12-31", "entry_closes_at": "2026-12-31T20:00:00-03:00", "family_release_at": "2026-12-31T20:00:00-03:00", "timezone": "America/Sao_Paulo"}
    payload = {"activity_id": assignment["activity_id"], "institution_id": assignment["institution_id"], "unit_id": assignment["unit_id"], "periodicity": "annual", "result_scale_kind": "numeric_0_10", "scale_options": {}, "concepts": [], "periods": [period], "allow_final_override": False, "instruments": [{"name": "Instrumento R08", "weight": 100, "sort_order": 0}], "categories": []}
    return {"save_configuration": {"request_id": request_ids["save_configuration"], "configuration_id": None, "expected_version": 0, "payload": payload}, "activate_request_id": request_ids["activate_configuration"], "gradebook_request_id": request_ids["save_gradebook"]}


def _is_uuid(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        uuid.UUID(value)
    except ValueError:
        return False
    return True


if __name__ == "__main__":
    raise SystemExit(main())
