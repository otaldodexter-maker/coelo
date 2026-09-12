"""One nominal R08 meal plan using an existing QA model and lote55 contract."""
import argparse
import json
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path

from happens_api_smoke import configuration, NoRedirect


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("config", "qa-env", "institution", "unit", "group", "template", "start", "end", "manifest"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    output = Path(args.manifest)
    if output.exists():
        raise SystemExit("Manifest exists; inspect it instead of duplicating the fixture.")
    cfg = configuration(args.config)
    qa = configuration(args.qa_env)
    base = cfg["COELO_SUPABASE_URL"].rstrip("/")
    headers = {"apikey": cfg["COELO_SUPABASE_PUBLISHABLE_KEY"], "Content-Type": "application/json"}
    opener = urllib.request.build_opener(NoRedirect())
    manifest = {"source": "R08 G4 meal plan API smoke, lote55 scopeRules object", "ui_e2e": False, "environment": "production", "started_at": datetime.now(timezone.utc).isoformat(), "institution_id": args.institution, "unit_id": args.unit, "group_id": args.group, "template_id": args.template, "start_date": args.start, "end_date": args.end, "audience": "staff", "checks": [], "states": [], "status": "running", "cross_tenant": "not executed; no scoped negative QA actor available"}
    token = None

    def save():
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    def check(name, passed, status=None):
        manifest["checks"].append({"name": name, "passed": bool(passed), "http_status": status})
        save()
        if not passed:
            raise RuntimeError(name)

    def request(path, payload=None, method="POST"):
        raw = None if payload is None else json.dumps(payload).encode()
        try:
            with opener.open(urllib.request.Request(base + path, headers=headers, data=raw, method=method), timeout=30) as response:
                status, body = response.status, response.read()
        except urllib.error.HTTPError as error:
            status, body = error.code, error.read()
        try:
            return status, json.loads(body)
        except (ValueError, UnicodeDecodeError):
            return status, None

    def rpc(name, payload, stage=None):
        status, result = request("/rest/v1/rpc/" + name, payload)
        if status != 200 and isinstance(result, dict):
            code = result.get("code")
            if isinstance(code, str) and code.isalnum() and len(code) <= 16:
                manifest["backend_error_code"] = code
        check(stage or name, status == 200, status)
        return result

    def state(label, plan):
        manifest["states"].append({"stage": label, "id": plan["id"], "status": plan["status"], "revision": plan["revision"]})
        save()

    try:
        save()
        status, login = request("/auth/v1/token?grant_type=password", {"email": qa["QA_EMAIL"], "password": qa["QA_PASSWORD"]})
        check("qa_login", status == 200, status)
        token = login["access_token"]
        headers["Authorization"] = "Bearer " + token
        status, groups = request("/rest/v1/groups?select=id,institution_id,unit_id&id=eq." + args.group, method="GET")
        check("current_group_hierarchy", status == 200 and len(groups) == 1 and groups[0]["institution_id"] == args.institution and groups[0]["unit_id"] == args.unit, status)
        template = rpc("meal_plan_template_get", {"p_template_id": args.template})
        check("existing_published_model_same_tenant", template["id"] == args.template and template["status"] == "published" and template["tenantId"] == args.institution)
        manifest["template_version"] = template["version"]
        menu = template["payload"]["menu"]
        check("model_has_menu_without_media", bool(menu) and not any(item.get("image") for item in menu))
        recurrence = {"kind": "singleWeek", "singleWeekStart": args.start, "singleWeekEnd": args.end, "weekdays": [1, 2, 3, 4, 5], "specificDates": [], "excludedDates": []}
        conflicts = rpc("meal_plan_conflicts_check", {"p_scope_level": "classLevel", "p_scope_id": args.group, "p_start_date": args.start, "p_end_date": args.end, "p_recurrence": recurrence, "p_menu": menu})
        check("no_existing_schedule_conflict", not conflicts.get("conflicts"))
        rules = {"institutionIds": [], "unitIds": [], "groupIds": [args.group], "activityIds": [], "includedPersonIds": [], "excludedPersonIds": [], "dynamicFutureMembership": True, "historyPolicy": "from_membership_start"}
        payload = {"tenantId": args.institution, "institutionId": args.institution, "unitId": args.unit, "classId": args.group, "personId": None, "name": "R08 G4 Cardapio sintetico lote55", "sourceType": "institution", "scopeLevel": "classLevel", "scopeId": args.group, "startDate": args.start, "endDate": args.end, "recurrence": recurrence, "menu": menu, "allergens": [], "alerts": [], "attachments": [], "priority": 0, "expectedRevision": 0, "planVariant": "complete", "audienceSegment": "staff", "visibilityMode": "immediate", "visibleFrom": None, "sourceTemplateId": args.template, "sourceTemplateVersion": template["version"], "scopeRules": rules, "simpleImage": None, "saveAsTemplate": False}
        created = rpc("meal_plan_create_or_update_draft", {"p_request_id": str(uuid.uuid4()), "p_payload": payload, "p_meal_plan_id": None, "p_expected_revision": 0}, "create_lote55_object_scope")
        manifest["meal_plan_id"] = created["id"]
        state("created", created)
        loaded = rpc("meal_plan_get", {"p_meal_plan_id": created["id"]}, "reload_created")
        check("scopeRules_object_persisted", loaded.get("scopeRules") == rules)
        payload["name"] += " editado"
        payload["expectedRevision"] = loaded["revision"]
        edited = rpc("meal_plan_create_or_update_draft", {"p_request_id": str(uuid.uuid4()), "p_payload": payload, "p_meal_plan_id": created["id"], "p_expected_revision": loaded["revision"]}, "edit_same_draft")
        state("edited", edited)
        loaded = rpc("meal_plan_get", {"p_meal_plan_id": created["id"]}, "reload_edited")
        check("edited_name_persisted", loaded["name"] == payload["name"])
        submitted = rpc("meal_plan_submit_for_review", {"p_request_id": str(uuid.uuid4()), "p_meal_plan_id": created["id"], "p_expected_revision": loaded["revision"]})
        state("submitted", submitted)
        published = rpc("meal_plan_publish", {"p_request_id": str(uuid.uuid4()), "p_meal_plan_id": created["id"], "p_expected_revision": submitted["revision"]})
        state("published", published)
        loaded = rpc("meal_plan_get", {"p_meal_plan_id": created["id"]}, "reload_published")
        check("published_status_and_scope_persisted", loaded["status"] == "published" and loaded.get("scopeRules") == rules)
        listing = rpc("meal_plan_list", {"p_query": {"institutionId": args.institution, "search": "R08 G4 Cardapio sintetico lote55", "page": 0, "pageSize": 100}})
        check("directory_contains_same_plan", any(item["id"] == created["id"] for item in listing["items"]))
        archived = rpc("meal_plan_archive", {"p_request_id": str(uuid.uuid4()), "p_meal_plan_id": created["id"], "p_expected_revision": loaded["revision"]})
        state("archived", archived)
        loaded = rpc("meal_plan_get", {"p_meal_plan_id": created["id"]}, "reload_archived")
        check("soft_archive_preserves_record", loaded["id"] == created["id"] and loaded["status"] == "archived")
        model_after = rpc("meal_plan_template_get", {"p_template_id": args.template}, "model_unchanged")
        check("existing_model_version_preserved", model_after["version"] == template["version"] and model_after["payload"] == template["payload"])
        manifest["status"] = "passed"
        manifest["retention"] = "soft archived synthetic plan and existing model preserved; no DELETE"
    except Exception as error:
        manifest["status"] = "failed"
        manifest["failure_type"] = type(error).__name__
        manifest["retention"] = "any created synthetic record retained for inspection; no cleanup bypass"
    finally:
        if token:
            status, _ = request("/auth/v1/logout?scope=local", {})
            manifest["logout_status"] = status
        manifest["finished_at"] = datetime.now(timezone.utc).isoformat()
        save()
    print(json.dumps({"status": manifest["status"], "checks": len(manifest["checks"]), "manifest": str(output)}))
    return 0 if manifest["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
