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


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--preflight", action="store_true")
    mode.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    if not args.preflight and not args.execute:
        emit("guard", "READY_NO_MUTATION", planned_rpc_mutations=4)
        return 0
    if args.execute and MANIFEST.exists():
        emit("guard", "REFUSED_EXISTING_MANIFEST")
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

        section_id = str(uuid.uuid4())
        item_id = str(uuid.uuid4())
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
                    "id": section_id,
                    "title": "Imagem",
                    "description": None,
                    "position": 0,
                    "items": [{
                        "id": item_id,
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
        draft_version = require_version(draft.get("management_version"), "draft")
        manifest: dict[str, Any] = {
            "schema_version": 1,
            "preserved": True,
            "institution_id": INSTITUTION_ID,
            "qa_person_id": QA_PERSON_ID,
            "form_id": form_id,
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
        published_version = require_version(published.get("management_version"), "published")
        manifest.update({"publish_http": publish_status, "published_management_version": published_version})
        save_manifest(manifest)
        emit("publish", "PASS", http=publish_status)

        application_status, application = rpc("form_save_application", {
            "p_request_id": str(uuid.uuid4()),
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
        application_id = require_uuid(application.get("id"), "application")
        manifest.update({"application_id": application_id, "application_http": application_status})
        save_manifest(manifest)
        emit("save_application", "PASS", http=application_status, application_id=application_id)

        starts_at = (dt.datetime.now().astimezone() - dt.timedelta(minutes=1)).replace(
            second=0, microsecond=0, tzinfo=None
        ).isoformat()
        schedule_status, scheduled = rpc("form_save_schedule", {
            "p_request_id": str(uuid.uuid4()),
            "p_expected_version": 0,
            "p_payload": {
                "schedule_id": None,
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
        schedules = scheduled.get("schedules")
        if not isinstance(schedules, list) or len(schedules) != 1 or not isinstance(schedules[0], dict):
            raise FixtureFailure("save_schedule:invalid_projection")
        schedule_id = require_uuid(schedules[0].get("id"), "schedule")
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
            f"{base}/auth/v1/logout",
            body={},
            headers=headers,
        )
        emit("logout", "PASS" if logout_status in {200, 204} else "FAILED", http=logout_status)


if __name__ == "__main__":
    sys.exit(main())
