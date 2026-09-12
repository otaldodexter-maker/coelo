"""Smoke autenticado de Formulários + question-image, com limpeza nominal.

Por padrão não acessa a rede. A execução remota exige --execute e o contexto
institucional explícito. Credenciais, JWTs, tickets e URLs assinadas ficam só
em memória e nunca são impressos.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
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
PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
)
MIME = "image/png"


class SmokeFailure(RuntimeError):
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


def error_code(value: Any) -> str:
    if isinstance(value, dict):
        error = value.get("error")
        if isinstance(error, dict) and isinstance(error.get("code"), str):
            return error["code"]
        for key in ("code", "error", "message"):
            if isinstance(value.get(key), str):
                return value[key][:80]
    return "opaque_error"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--institution-id", required=False)
    args = parser.parse_args()
    if not args.execute:
        emit("guard", "READY_NO_MUTATION")
        return 0
    try:
        institution_id = str(uuid.UUID(args.institution_id or ""))
    except ValueError:
        emit("guard", "INVALID_INSTITUTION")
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

    form_id = str(uuid.uuid4())
    source_section_id = str(uuid.uuid4())
    source_item_id = str(uuid.uuid4())
    asset_id: str | None = None
    form_created = False
    form_version = 1
    failed = False
    try:
        save_request = str(uuid.uuid4())
        draft = {
            "id": form_id,
            "institution_id": institution_id,
            "kind": "form",
            "identity_mode": "identified",
            "response_unit": "person",
            "title": "QA R08 question-image synthetic",
            "description": "Fixture temporária; remover ao fim do smoke.",
            "sections": [{
                "id": source_section_id,
                "title": "Seção QA",
                "description": None,
                "position": 0,
                "items": [{
                    "id": source_item_id,
                    "kind": "short_text",
                    "label": "Pergunta QA com imagem",
                    "help_text": None,
                    "position": 0,
                    "is_required": False,
                    "config": {},
                    "options": [],
                    "conditions": [],
                }],
            }],
        }
        status, saved = rpc("form_save_draft", {
            "p_request_id": save_request,
            "p_expected_version": 0,
            "p_payload": draft,
        })
        if status != 200 or not isinstance(saved, dict) or saved.get("id") != form_id:
            raise SmokeFailure(f"save:{status}:{error_code(saved)}")
        form_created = True
        form_version = int(saved.get("management_version", 1))
        emit("save_identified_draft", "PASS", http=status, form_id=form_id, version=form_version)

        status, editor = rpc("form_get_editor", {"p_form_id": form_id})
        if status != 200 or not isinstance(editor, dict):
            raise SmokeFailure(f"editor_before:{status}:{error_code(editor)}")
        context = editor.get("media_context")
        sections = editor.get("definition", {}).get("sections", [])
        item_id = sections[0]["items"][0]["id"]
        version_id = context["form_version_id"]
        if context.get("question_images") != []:
            raise SmokeFailure("editor_before:unexpected_media")
        emit("editor_before", "PASS", http=status, item_id=item_id, form_version_id=version_id)

        checksum = hashlib.sha256(PNG).hexdigest()
        status, prepared = edge({
            "action": "prepare",
            "request_id": str(uuid.uuid4()),
            "expected_version": form_version,
            "payload": {
                "purpose": "question-image",
                "form_id": form_id,
                "form_version_id": version_id,
                "item_id": item_id,
                "mime_type": MIME,
                "byte_size": len(PNG),
                "sha256": checksum,
            },
        })
        if status != 200 or not isinstance(prepared, dict):
            raise SmokeFailure(f"prepare:{status}:{error_code(prepared)}")
        asset_id = prepared.get("asset_id")
        upload_url = prepared.get("signed_upload_url") or prepared.get("upload_url")
        required_headers = prepared.get("required_headers") or {}
        if not isinstance(asset_id, str) or not isinstance(upload_url, str) or not isinstance(required_headers, dict):
            raise SmokeFailure("prepare:invalid_receipt")
        emit("prepare", "PASS", http=status, asset_id=asset_id, replayed=prepared.get("replayed") is True)

        put_headers = {str(k): str(v) for k, v in required_headers.items()}
        put_headers.setdefault("content-type", MIME)
        put_request = urllib.request.Request(upload_url, data=PNG, method="PUT", headers=put_headers)
        try:
            with urllib.request.urlopen(put_request, timeout=30) as response:
                put_status = response.status
        except urllib.error.HTTPError as error:
            put_status = error.code
        if put_status < 200 or put_status >= 300:
            raise SmokeFailure(f"put:{put_status}")
        emit("signed_put", "PASS", http=put_status, bytes=len(PNG), sha256=checksum)

        status, finalized = edge({
            "action": "finalize",
            "payload": {"purpose": "question-image", "asset_id": asset_id},
        })
        if status != 200 or not isinstance(finalized, dict) or finalized.get("status") != "ready":
            raise SmokeFailure(f"finalize:{status}:{error_code(finalized)}")
        emit(
            "finalize",
            "PASS",
            http=status,
            asset_id=asset_id,
            media_status=finalized.get("status"),
            width=finalized.get("pixel_width"),
            height=finalized.get("pixel_height"),
        )

        status, resolved = edge({
            "action": "resolve",
            "payload": {"purpose": "question-image", "asset_id": asset_id},
        })
        signed_get = resolved.get("signed_url") if isinstance(resolved, dict) else None
        if status != 200 or not isinstance(signed_get, str):
            raise SmokeFailure(f"resolve:{status}:{error_code(resolved)}")
        with urllib.request.urlopen(signed_get, timeout=30) as response:
            downloaded = response.read()
            get_status = response.status
        if get_status != 200 or hashlib.sha256(downloaded).hexdigest() != checksum:
            raise SmokeFailure(f"signed_get:{get_status}:content_mismatch")
        emit("authorized_read", "PASS", http=get_status, bytes=len(downloaded), sha256=checksum)

        status, reloaded = rpc("form_get_editor", {"p_form_id": form_id})
        images = reloaded.get("media_context", {}).get("question_images", []) if isinstance(reloaded, dict) else []
        match = [item for item in images if item.get("asset_id") == asset_id]
        if status != 200 or len(match) != 1 or match[0].get("status") != "ready":
            raise SmokeFailure(f"editor_reload:{status}:binding_missing")
        emit("editor_reload", "PASS", http=status, asset_id=asset_id, media_status="ready")
    except (SmokeFailure, KeyError, IndexError, TypeError, ValueError, urllib.error.URLError) as error:
        failed = True
        emit("smoke", "FAILED", reason=str(error)[:160], form_id=form_id, asset_id=asset_id)
    finally:
        cleanup_ok = True
        if asset_id is not None:
            status, deleted = edge({
                "action": "delete",
                "request_id": str(uuid.uuid4()),
                "payload": {"purpose": "question-image", "asset_id": asset_id},
            })
            cleanup_ok &= status == 200 and isinstance(deleted, dict) and deleted.get("status") == "deleted"
            emit("cleanup_media", "PASS" if cleanup_ok else "FAILED", http=status, asset_id=asset_id)
        if form_created:
            status, deleted_form = rpc("form_archive_or_delete", {
                "p_request_id": str(uuid.uuid4()),
                "p_expected_version": form_version,
                "p_payload": {"form_id": form_id, "action": "delete"},
            })
            form_cleanup_ok = status == 200
            cleanup_ok &= form_cleanup_ok
            emit("cleanup_form", "PASS" if form_cleanup_ok else "FAILED", http=status, form_id=form_id, code=None if form_cleanup_ok else error_code(deleted_form))
        if not cleanup_ok:
            failed = True
    emit("result", "FAIL" if failed else "PASS")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
