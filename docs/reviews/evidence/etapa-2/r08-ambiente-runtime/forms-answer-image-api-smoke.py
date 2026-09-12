"""Smoke autenticado de answer-image em Formulários, sem cleanup.

Por padrão não acessa a rede. A execução remota exige --execute e uma
occurrence explícita. Segredos, JWTs e URLs assinadas ficam somente em memória.
"""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import json
import os
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path
from typing import Any


WORKTREE = Path(r"C:\Users\adrie\Documents\Coelo.worktrees\e2-r08-ambiente-runtime")
APP_ENV = WORKTREE / "apps" / "superadmin" / ".env.local"
QA_ENV = Path(r"C:\Users\adrie\Documents\Coelo-backups\qa-r06-principal.env")
PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
)
MIME = "image/png"
ANSWER_KEYS = {
    "item_id",
    "kind",
    "text_value",
    "integer_value",
    "decimal_value",
    "money_minor_units",
    "date_value",
    "yes_no_value",
    "option_ids",
    "scale_value",
    "asset_ids",
}


class SmokeFailure(RuntimeError):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req: Any, fp: Any, code: int, msg: str, headers: Any, newurl: str) -> None:
        return None


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
    url: str,
    *,
    method: str = "POST",
    body: object | None = None,
    headers: dict[str, str] | None = None,
) -> tuple[int, Any]:
    payload = None if body is None else json.dumps(body).encode("utf-8")
    request = urllib.request.Request(url, data=payload, method=method, headers=headers or {})
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
        raise SmokeFailure(f"{label}:invalid_uuid")
    try:
        return str(uuid.UUID(value))
    except ValueError as error:
        raise SmokeFailure(f"{label}:invalid_uuid") from error


def photo_items(definition: Any) -> list[dict[str, Any]]:
    if not isinstance(definition, dict):
        return []
    found: list[dict[str, Any]] = []
    for section in definition.get("sections", []):
        if not isinstance(section, dict):
            continue
        for item in section.get("items", []):
            if isinstance(item, dict) and item.get("kind") in {"photo", "gallery"}:
                found.append(item)
    return found


def normalized_answers(raw: Any, item_id: str, item_kind: str, asset_id: str) -> list[dict[str, Any]]:
    if not isinstance(raw, list):
        raise SmokeFailure("draft:invalid_answers")
    answers: list[dict[str, Any]] = []
    for answer in raw:
        if not isinstance(answer, dict) or set(answer) != ANSWER_KEYS:
            raise SmokeFailure("draft:invalid_answer_contract")
        if answer.get("item_id") != item_id:
            answers.append(answer)
    answers.append({
        "item_id": item_id,
        "kind": item_kind,
        "text_value": None,
        "integer_value": None,
        "decimal_value": None,
        "money_minor_units": None,
        "date_value": None,
        "yes_no_value": None,
        "option_ids": [],
        "scale_value": None,
        "asset_ids": [asset_id],
    })
    return answers


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--occurrence-id")
    parser.add_argument("--item-id")
    parser.add_argument(
        "--edit-secret-env",
        help="Nome da variável que contém o edit_secret anônimo; o valor nunca é impresso.",
    )
    args = parser.parse_args()
    if not args.execute:
        emit("guard", "READY_NO_MUTATION")
        return 0
    try:
        occurrence_id = str(uuid.UUID(args.occurrence_id or ""))
        requested_item_id = str(uuid.UUID(args.item_id)) if args.item_id else None
    except ValueError:
        emit("guard", "INVALID_RUNTIME_FIXTURE")
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
    api_headers = {
        "apikey": key,
        "authorization": f"Bearer {token}",
        "content-type": "application/json",
    }
    emit("auth", "PASS", http=auth_status)

    def rpc(name: str, body: dict[str, Any]) -> tuple[int, Any]:
        return request_json(f"{base}/rest/v1/rpc/{name}", body=body, headers=api_headers)

    def edge(body: dict[str, Any]) -> tuple[int, Any]:
        return request_json(f"{base}/functions/v1/form-media", body=body, headers=api_headers)

    asset_id: str | None = None
    response_id: str | None = None
    failed = False
    try:
        status, occurrence = rpc(
            "form_get_occurrence_for_response", {"p_occurrence_id": occurrence_id}
        )
        if status != 200 or not isinstance(occurrence, dict):
            raise SmokeFailure(f"occurrence:{status}:{error_code(occurrence)}")
        occurrence_data = occurrence.get("occurrence")
        definition = occurrence.get("definition")
        if not isinstance(occurrence_data, dict) or not isinstance(definition, dict):
            raise SmokeFailure("occurrence:invalid_projection")
        if occurrence_data.get("id") != occurrence_id or occurrence.get("can_edit") is not True:
            raise SmokeFailure("occurrence:not_open_or_mismatched")
        participation_id = require_uuid(occurrence.get("participation_id"), "participation")
        identity_mode = definition.get("identity_mode")
        if identity_mode not in {"identified", "anonymous"}:
            raise SmokeFailure("occurrence:invalid_identity")
        candidates = photo_items(definition)
        if requested_item_id:
            candidates = [item for item in candidates if item.get("id") == requested_item_id]
        if len(candidates) != 1:
            raise SmokeFailure(f"occurrence:photo_item_count:{len(candidates)}")
        item = candidates[0]
        item_id = require_uuid(item.get("id"), "photo_item")
        item_kind = str(item.get("kind"))
        edit_secret = None
        if identity_mode == "anonymous":
            if not args.edit_secret_env:
                raise SmokeFailure("anonymous:edit_secret_env_required")
            edit_secret = os.environ.get(args.edit_secret_env)
            if not edit_secret or len(edit_secret) < 43:
                raise SmokeFailure("anonymous:edit_secret_unavailable")
        emit(
            "occurrence_preflight",
            "PASS",
            http=status,
            occurrence_id=occurrence_id,
            participation_id=participation_id,
            item_id=item_id,
            item_kind=item_kind,
            identity_mode=identity_mode,
        )

        open_payload: dict[str, Any] = {
            "occurrence_id": occurrence_id,
            "participation_id": participation_id,
            "identity_mode": identity_mode,
            "edit_secret": edit_secret,
        }
        status, draft = rpc("form_open_response_draft", {
            "p_request_id": str(uuid.uuid4()),
            "p_expected_version": 0,
            "p_payload": open_payload,
        })
        if status != 200 or not isinstance(draft, dict):
            raise SmokeFailure(f"open_draft:{status}:{error_code(draft)}")
        response_id = require_uuid(draft.get("id"), "response")
        if draft.get("occurrence_id") != occurrence_id or draft.get("status") != "draft":
            raise SmokeFailure("open_draft:not_editable_draft")
        response_version = draft.get("management_version")
        if not isinstance(response_version, int) or response_version < 1:
            raise SmokeFailure("open_draft:invalid_version")
        emit("open_or_reuse_draft", "PASS", http=status, response_id=response_id)

        checksum = hashlib.sha256(PNG).hexdigest()
        prepare_request_id = str(uuid.uuid4())
        prepare_payload = {
            "occurrence_id": occurrence_id,
            "item_id": item_id,
            "mime_type": MIME,
            "byte_length": len(PNG),
            "checksum": checksum,
            **({"edit_secret": edit_secret} if edit_secret else {}),
        }
        status, prepared = edge({
            "action": "prepare",
            "request_id": prepare_request_id,
            "expected_version": 0,
            "payload": prepare_payload,
        })
        if status != 200 or not isinstance(prepared, dict):
            raise SmokeFailure(f"prepare:{status}:{error_code(prepared)}")
        if "purpose" in prepared:
            raise SmokeFailure("prepare:question_image_envelope")
        asset_id = require_uuid(prepared.get("asset_id"), "asset")
        upload_url = prepared.get("upload_url")
        required_headers = prepared.get("required_headers")
        expires_at = prepared.get("expires_at")
        if (
            not isinstance(upload_url, str)
            or not isinstance(required_headers, dict)
            or not isinstance(expires_at, str)
        ):
            raise SmokeFailure("prepare:invalid_ticket")
        safe_headers = {str(k): str(v) for k, v in required_headers.items()}
        lowered = {name.lower() for name in safe_headers}
        if len(lowered) != len(safe_headers) or not lowered.issubset(
            {"content-type", "x-amz-checksum-sha256"}
        ):
            raise SmokeFailure("prepare:unsafe_headers")
        content_type = next(
            (value for name, value in safe_headers.items() if name.lower() == "content-type"), None
        )
        try:
            expiry = dt.datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
        except ValueError as error:
            raise SmokeFailure("prepare:invalid_expiry") from error
        remaining = expiry - dt.datetime.now(dt.timezone.utc)
        if content_type != MIME or remaining <= dt.timedelta(0) or remaining > dt.timedelta(minutes=5):
            raise SmokeFailure("prepare:unsafe_ticket")
        emit("prepare_answer_image", "PASS", http=status, asset_id=asset_id)

        put_request = urllib.request.Request(upload_url, data=PNG, method="PUT", headers=safe_headers)
        try:
            with urllib.request.build_opener(NoRedirect).open(put_request, timeout=30) as response:
                put_status = response.status
        except urllib.error.HTTPError as error:
            put_status = error.code
        if not 200 <= put_status < 300:
            raise SmokeFailure(f"put:{put_status}")
        emit("signed_put", "PASS", http=put_status, bytes=len(PNG), sha256=checksum)

        finalize_request_id = str(uuid.uuid4())
        access_payload = {
            "asset_id": asset_id,
            **({"edit_secret": edit_secret} if edit_secret else {}),
        }
        finalize_envelope = {
            "action": "finalize",
            "request_id": finalize_request_id,
            "expected_version": 0,
            "payload": access_payload,
        }
        for step in ("finalize", "finalize_replay"):
            status, finalized = edge(finalize_envelope)
            if (
                status != 200
                or not isinstance(finalized, dict)
                or finalized.get("id") != asset_id
                or finalized.get("item_id") != item_id
                or finalized.get("mime_type") != MIME
                or finalized.get("byte_length") != len(PNG)
                or finalized.get("asset_id") != asset_id
                or finalized.get("state") != "finalized"
            ):
                raise SmokeFailure(f"{step}:{status}:{error_code(finalized)}")
            emit(step, "PASS", http=status, asset_id=asset_id)

        answers = normalized_answers(draft.get("answers"), item_id, item_kind, asset_id)
        save_payload = {
            "response_id": response_id,
            "participation_id": participation_id,
            "edit_secret": edit_secret,
            "answers": answers,
        }
        status, saved = rpc("form_save_response_draft", {
            "p_request_id": str(uuid.uuid4()),
            "p_expected_version": response_version,
            "p_payload": save_payload,
        })
        if status != 200 or not isinstance(saved, dict) or saved.get("id") != response_id:
            raise SmokeFailure(f"save_response:{status}:{error_code(saved)}")
        saved_answers = saved.get("answers")
        if not isinstance(saved_answers, list) or not any(
            isinstance(answer, dict)
            and answer.get("item_id") == item_id
            and answer.get("asset_ids") == [asset_id]
            for answer in saved_answers
        ):
            raise SmokeFailure("save_response:asset_not_bound")
        emit("save_response_draft", "PASS", http=status, response_id=response_id)

        status, downloaded = edge({
            "action": "download",
            "request_id": str(uuid.uuid4()),
            "expected_version": 0,
            "payload": access_payload,
        })
        if status != 200 or not isinstance(downloaded, dict) or not isinstance(
            downloaded.get("signed_url"), str
        ):
            raise SmokeFailure(f"download_authorize:{status}:{error_code(downloaded)}")
        get_request = urllib.request.Request(downloaded["signed_url"], method="GET")
        try:
            with urllib.request.urlopen(get_request, timeout=30) as response:
                get_status = response.status
                received = response.read()
        except urllib.error.HTTPError as error:
            get_status = error.code
            received = b""
        if get_status != 200 or received != PNG:
            raise SmokeFailure(f"download_get:{get_status}:content_mismatch")
        emit("authorized_download", "PASS", http=get_status, bytes=len(received), sha256=checksum)

        # A segunda abertura é o reload autorizado consumido pela tela normal.
        status, reloaded = rpc("form_open_response_draft", {
            "p_request_id": str(uuid.uuid4()),
            "p_expected_version": 0,
            "p_payload": open_payload,
        })
        if status != 200 or not isinstance(reloaded, dict) or reloaded.get("id") != response_id:
            raise SmokeFailure(f"reload:{status}:{error_code(reloaded)}")
        reloaded_answers = reloaded.get("answers")
        if not isinstance(reloaded_answers, list) or not any(
            isinstance(answer, dict)
            and answer.get("item_id") == item_id
            and answer.get("asset_ids") == [asset_id]
            for answer in reloaded_answers
        ):
            raise SmokeFailure("reload:asset_not_persisted")
        emit("reload_response", "PASS", http=status, response_id=response_id, asset_id=asset_id)
    except SmokeFailure as error:
        failed = True
        emit(
            "smoke",
            "FAILED",
            code=str(error),
            occurrence_id=occurrence_id,
            response_id=response_id,
            asset_id=asset_id,
            preserved=True,
        )
    finally:
        logout_status, _ = request_json(
            f"{base}/auth/v1/logout?scope=local",
            headers=api_headers,
        )
        emit("logout_local", "PASS" if logout_status == 204 else "FAILED", http=logout_status)
    if not failed:
        emit(
            "smoke",
            "PASS",
            occurrence_id=occurrence_id,
            response_id=response_id,
            asset_id=asset_id,
            preserved=True,
        )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
