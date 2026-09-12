"""Prepara uma unica fixture identificada para o smoke answer-image da R08.

Por padrao nao acessa a rede. ``--preflight`` e somente leitura; ``--execute``
executa quatro RPCs normais e preserva todos os sinteticos. Nao ha cleanup,
SQL direto, criacao de usuario ou persistencia de credenciais.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path
from typing import Any


WORKTREE = Path(r"C:\Users\adrie\Documents\Coelo.worktrees\e2-r08-ambiente-runtime")
APP_ENV = WORKTREE / "apps" / "superadmin" / ".env.local"
QA_ENV = Path(r"C:\Users\adrie\Documents\Coelo-backups\qa-r06-principal.env")
MANIFEST = (
    WORKTREE
    / "docs"
    / "reviews"
    / "evidence"
    / "etapa-2"
    / "r08-ambiente-runtime"
    / "forms-answer-image-fixture-manifest.json"
)
INSTITUTION_ID = "d0c40000-0000-4000-8000-000000000001"
QA_PERSON_ID = "007a4ca5-31bd-4a77-956f-ce879695042e"
MARKER = "[R08-G0-QA] Answer image identified"


class FixtureFailure(RuntimeError):
    pass


def read_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def emit(step: str, status: str, **safe: Any) -> None:
    print(json.dumps({"step": step, "status": status, **safe}, sort_keys=True))


def request_json(
    url: str, *, body: object, headers: dict[str, str]
) -> tuple[int, Any]:
    request = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        method="POST",
        headers=headers,
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            parsed = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            parsed = None
        return error.code, parsed
    except urllib.error.URLError:
        return 0, {"error": "network_error"}


def error_code(value: Any) -> str:
    if isinstance(value, dict):
        error = value.get("error")
        if isinstance(error, dict) and isinstance(error.get("code"), str):
            return error["code"]
        for key in ("code", "error", "message"):
            if isinstance(value.get(key), str):
                return value[key][:80]
    return "opaque_error"


def require_uuid(value: Any, label: str) -> str:
    if not isinstance(value, str):
        raise FixtureFailure(f"{label}:invalid_uuid")
    try:
        return str(uuid.UUID(value))
    except ValueError as error:
        raise FixtureFailure(f"{label}:invalid_uuid") from error


def require_version(value: Any, label: str) -> int:
    if not isinstance(value, int) or value < 1:
        raise FixtureFailure(f"{label}:invalid_version")
    return value


def save_manifest(value: dict[str, Any]) -> None:
    MANIFEST.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def require_definition_projection(
    value: dict[str, Any], form_id: str, expected_status: str
) -> tuple[str, str]:
    if (
        value.get("id") != form_id
        or value.get("institution_id") != INSTITUTION_ID
        or value.get("title") != MARKER
        or value.get("status") != expected_status
        or value.get("identity_mode") != "identified"
        or value.get("response_unit") != "person"
    ):
        raise FixtureFailure("publish:projection_context_mismatch")
    sections = value.get("sections")
    if not isinstance(sections, list) or len(sections) != 1 or not isinstance(sections[0], dict):
        raise FixtureFailure("publish:projection_sections_mismatch")
    items = sections[0].get("items")
    if (
        not isinstance(items, list)
        or len(items) != 1
        or not isinstance(items[0], dict)
        or items[0].get("kind") != "photo"
        or items[0].get("config") != {"allow_camera": True, "min_images": 1, "max_images": 1}
    ):
        raise FixtureFailure("definition:projection_item_mismatch")
    return (
        require_uuid(sections[0].get("id"), "projection_section"),
        require_uuid(items[0].get("id"), "projection_item"),
    )


def require_application_projection(value: dict[str, Any], form_id: str) -> None:
    rules = value.get("audience_rules")
    if (
        value.get("form_id") != form_id
        or value.get("institution_id") != INSTITUTION_ID
        or value.get("status") != "active"
        or value.get("opens_for_days") != 1
        or not isinstance(rules, list)
        or len(rules) != 1
        or not isinstance(rules[0], dict)
        or rules[0].get("kind") != "person"
        or rules[0].get("mode") != "include"
        or rules[0].get("target_id") != QA_PERSON_ID
    ):
        raise FixtureFailure("application:projection_mismatch")


def require_schedule_projection(value: dict[str, Any], application_id: str, form_id: str) -> str:
    require_application_projection(value, form_id)
    if value.get("id") != application_id:
        raise FixtureFailure("schedule:application_changed")
    schedules = value.get("schedules")
    if not isinstance(schedules, list) or len(schedules) != 1 or not isinstance(schedules[0], dict):
        raise FixtureFailure("schedule:projection_cardinality_mismatch")
    schedule = schedules[0]
    recurrence = schedule.get("recurrence")
    end = schedule.get("end")
    if (
        schedule.get("status") != "active"
        or schedule.get("time_zone") != "America/Sao_Paulo"
        or not isinstance(recurrence, dict)
        or recurrence.get("kind") != "once"
        or recurrence.get("interval") != 1
        or not isinstance(end, dict)
        or end.get("kind") != "count"
        or end.get("count") != 1
        or schedule.get("reminders") != []
    ):
        raise FixtureFailure("schedule:projection_contract_mismatch")
    return require_uuid(schedule.get("id"), "schedule")


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--preflight", action="store_true")
    mode.add_argument("--execute", action="store_true")
    mode.add_argument("--resume", action="store_true")
    args = parser.parse_args()
    if not args.preflight and not args.execute and not args.resume:
        emit("guard", "READY_NO_MUTATION", planned_rpc_mutations=4)
        return 0
    if args.execute and MANIFEST.exists():
        emit("guard", "REFUSED_EXISTING_MANIFEST")
        return 2
    if args.resume and not MANIFEST.exists():
        emit("guard", "REFUSED_MISSING_MANIFEST")
        return 2

    app = read_env(APP_ENV)
    qa = read_env(QA_ENV)
    base = app["COELO_SUPABASE_URL"].rstrip("/")
    key = app["COELO_SUPABASE_PUBLISHABLE_KEY"]
    auth_status, auth = request_json(
        f"{base}/auth/v1/token?grant_type=password",
        body={"email": qa["QA_EMAIL"], "password": qa["QA_PASSWORD"]},
        headers={"apikey": key, "content-type": "application/json"},
    )
    if auth_status != 200 or not isinstance(auth, dict) or not isinstance(auth.get("access_token"), str):
        emit("auth", "FAILED", http=auth_status, code=error_code(auth))
        return 1
    token = auth["access_token"]
    headers = {
        "apikey": key,
        "authorization": f"Bearer {token}",
        "content-type": "application/json",
    }
    emit("auth", "PASS", http=auth_status)

    def rpc(name: str, body: dict[str, Any]) -> tuple[int, Any]:
        return request_json(f"{base}/rest/v1/rpc/{name}", body=body, headers=headers)

    try:
        if args.resume:
            manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
            form_id = require_uuid(manifest.get("form_id"), "resume_form")
            if (
                form_id != "afa8f922-b27d-4258-9322-8b3f96ee7df9"
                or manifest.get("institution_id") != INSTITUTION_ID
                or manifest.get("qa_person_id") != QA_PERSON_ID
                or manifest.get("application_id") is not None
                or manifest.get("schedule_id") is not None
            ):
                raise FixtureFailure("resume:manifest_scope_mismatch")
            editor_status, editor = rpc("form_get_editor", {"p_form_id": form_id})
            definition = editor.get("definition") if isinstance(editor, dict) else None
            if editor_status != 200 or not isinstance(definition, dict):
                raise FixtureFailure(f"resume_editor:{editor_status}:{error_code(editor)}")
            if editor.get("application") is not None:
                raise FixtureFailure("resume:editor_application_exists")
            section_id, item_id = require_definition_projection(definition, form_id, "published")
            manifest.update({
                "input_section_id": manifest.get("section_id"),
                "input_item_id": manifest.get("item_id"),
                "section_id": section_id,
                "item_id": item_id,
                "publish_http": 200,
                "published_management_version": require_version(
                    definition.get("management_version"), "resume_published"
                ),
            })
            save_manifest(manifest)
            emit("resume_editor", "PASS", http=editor_status, form_id=form_id, item_id=item_id)
        else:
            manifest = {}
        candidate_status, candidates = rpc("form_list_audience_candidates", {"p_query": {
            "institution_id": INSTITUTION_ID,
            "kind": "person",
            "search": None,
            "cursor_label": None,
            "cursor_id": None,
            "limit": 100,
        }})
        candidate_items = candidates.get("items") if isinstance(candidates, dict) else None
        candidate_ids = {
            item.get("id") for item in candidate_items or [] if isinstance(item, dict)
        }
        if candidate_status != 200 or QA_PERSON_ID not in candidate_ids:
            raise FixtureFailure(f"audience:{candidate_status}:{error_code(candidates)}")
        emit("audience", "PASS", http=candidate_status, target_present=True)

        if not args.resume:
            list_status, directory = rpc("form_list", {"p_query": {
            "institution_id": INSTITUTION_ID,
            "search": MARKER,
            "statuses": ["draft", "published", "archived"],
            "operational_statuses": [],
            "kinds": ["form"],
            "starts_on_or_after": None,
            "ends_on_or_before": None,
            "cursor_updated_at": None,
            "cursor_id": None,
            "limit": 100,
            }})
            items = directory.get("items") if isinstance(directory, dict) else None
            if list_status != 200 or not isinstance(items, list):
                raise FixtureFailure(f"duplicate_preflight:{list_status}:{error_code(directory)}")
            exact = [item for item in items if isinstance(item, dict) and item.get("title") == MARKER]
            if exact:
                raise FixtureFailure("duplicate_preflight:existing_fixture")
            emit("duplicate_preflight", "PASS", http=list_status, exact_matches=0)
            if args.preflight:
                emit("preflight", "PASS_READ_ONLY", planned_rpc_mutations=4)
                return 0

            input_section_id = str(uuid.uuid4())
            input_item_id = str(uuid.uuid4())
            draft_status, draft = rpc("form_save_draft", {
            "p_request_id": str(uuid.uuid4()),
            "p_expected_version": 0,
            "p_payload": {
                "id": None,
                "institution_id": INSTITUTION_ID,
                "kind": "form",
                "identity_mode": "identified",
                "response_unit": "person",
                "title": MARKER,
                "description": "Fixture sintetica preservada para QA R08 de resposta com imagem.",
                "sections": [{
                    "id": input_section_id,
                    "title": "Imagem",
                    "description": None,
                    "position": 0,
                    "items": [{
                        "id": input_item_id,
                        "kind": "photo",
                        "label": "Foto QA",
                        "help_text": None,
                        "position": 0,
                        "is_required": True,
                        "config": {"allow_camera": True, "min_images": 1, "max_images": 1},
                        "options": [],
                        "conditions": [],
                    }],
                }],
            },
            })
            if draft_status != 200 or not isinstance(draft, dict):
                raise FixtureFailure(f"save_draft:{draft_status}:{error_code(draft)}")
            form_id = require_uuid(draft.get("id"), "form")
            section_id, item_id = require_definition_projection(draft, form_id, "draft")
            draft_version = require_version(draft.get("management_version"), "draft")
            manifest = {
            "schema_version": 1,
            "preserved": True,
            "institution_id": INSTITUTION_ID,
            "qa_person_id": QA_PERSON_ID,
            "form_id": form_id,
            "input_section_id": input_section_id,
            "input_item_id": input_item_id,
            "section_id": section_id,
            "item_id": item_id,
            "draft_http": draft_status,
            "draft_management_version": draft_version,
            }
            save_manifest(manifest)
            emit("save_draft", "PASS", http=draft_status, form_id=form_id, item_id=item_id)

            publish_status, published = rpc("form_publish", {
            "p_request_id": str(uuid.uuid4()),
            "p_expected_version": draft_version,
            "p_payload": {"form_id": form_id},
            })
            if publish_status != 200 or not isinstance(published, dict):
                raise FixtureFailure(f"publish:{publish_status}:{error_code(published)}")
            published_section_id, published_item_id = require_definition_projection(
                published, form_id, "published"
            )
            if (published_section_id, published_item_id) != (section_id, item_id):
                raise FixtureFailure("publish:server_ids_changed")
            published_version = require_version(published.get("management_version"), "published")
            manifest.update({"publish_http": publish_status, "published_management_version": published_version})
            save_manifest(manifest)
            emit("publish", "PASS", http=publish_status)

        application_request_id = (
            require_uuid(manifest.get("application_request_id"), "application_request")
            if manifest.get("application_request_id") is not None
            else str(uuid.uuid4())
        )
        manifest["application_request_id"] = application_request_id
        save_manifest(manifest)
        application_status, application = rpc("form_save_application", {
            "p_request_id": application_request_id,
            "p_expected_version": 0,
            "p_payload": {
                "id": None,
                "form_id": form_id,
                "institution_id": INSTITUTION_ID,
                "name": "R08 G0 QA answer image",
                "status": "active",
                "opens_for_days": 1,
                "rules": [{
                    "kind": "person",
                    "mode": "include",
                    "target_id": QA_PERSON_ID,
                    "filter": {},
                    "position": 0,
                }],
            },
        })
        if application_status != 200 or not isinstance(application, dict):
            raise FixtureFailure(f"save_application:{application_status}:{error_code(application)}")
        require_application_projection(application, form_id)
        application_id = require_uuid(application.get("id"), "application")
        manifest.update({"application_id": application_id, "application_http": application_status})
        save_manifest(manifest)
        emit("save_application", "PASS", http=application_status, application_id=application_id)

        starts_at = manifest.get("starts_at_local")
        if starts_at is None:
            starts_at = (dt.datetime.now().astimezone() - dt.timedelta(minutes=1)).replace(
                second=0, microsecond=0, tzinfo=None
            ).isoformat()
        if not isinstance(starts_at, str):
            raise FixtureFailure("schedule:invalid_persisted_start")
        schedule_request_id = (
            require_uuid(manifest.get("schedule_request_id"), "schedule_request")
            if manifest.get("schedule_request_id") is not None
            else str(uuid.uuid4())
        )
        requested_schedule_id = (
            require_uuid(manifest.get("requested_schedule_id"), "requested_schedule")
            if manifest.get("requested_schedule_id") is not None
            else str(uuid.uuid4())
        )
        manifest.update({
            "schedule_request_id": schedule_request_id,
            "requested_schedule_id": requested_schedule_id,
            "starts_at_local": starts_at,
        })
        save_manifest(manifest)
        schedule_status, scheduled = rpc("form_save_schedule", {
            "p_request_id": schedule_request_id,
            "p_expected_version": 0,
            "p_payload": {
                "schedule_id": requested_schedule_id,
                "application_id": application_id,
                "time_zone": "America/Sao_Paulo",
                "starts_at_local": starts_at,
                "recurrence_kind": "once",
                "interval": 1,
                "weekdays": [],
                "monthly_day": None,
                "monthly_last_day": False,
                "end_kind": "count",
                "ends_on": None,
                "occurrence_count": 1,
                "reminders": [],
            },
        })
        if schedule_status != 200 or not isinstance(scheduled, dict):
            raise FixtureFailure(f"save_schedule:{schedule_status}:{error_code(scheduled)}")
        schedule_id = require_schedule_projection(scheduled, application_id, form_id)
        if schedule_id != requested_schedule_id:
            raise FixtureFailure("schedule:server_id_mismatch")
        manifest.update({
            "schedule_id": schedule_id,
            "schedule_http": schedule_status,
            "starts_at_local": starts_at,
            "occurrence_id": None,
            "participation_id": None,
        })
        save_manifest(manifest)
        emit(
            "save_schedule",
            "PASS_NEEDS_SERVER_OCCURRENCE_LOOKUP",
            http=schedule_status,
            form_id=form_id,
            application_id=application_id,
            schedule_id=schedule_id,
            item_id=item_id,
        )
        return 0
    except FixtureFailure as error:
        emit("fixture", "FAILED", code=str(error))
        return 1
    finally:
        logout_status, _ = request_json(
            f"{base}/auth/v1/logout?scope=local",
            body={},
            headers=headers,
        )
        emit("logout", "PASS" if logout_status in {200, 204} else "FAILED", http=logout_status)


if __name__ == "__main__":
    sys.exit(main())
