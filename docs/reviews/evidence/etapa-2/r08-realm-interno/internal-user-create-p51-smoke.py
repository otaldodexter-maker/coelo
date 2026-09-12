"""P51 production smoke with strictly sanitized output.

Secrets and the password setup URL stay in process memory. The script creates
at most the single fixed R08 synthetic user and never opens the recovery link.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path


QA_ENV = Path("C:/Users/adrie/Documents/Coelo-backups/qa-r06-acessos.env")
APP_ENV = Path(
    "C:/Users/adrie/Documents/Coelo.worktrees/"
    "e2-r08-ambiente-runtime/apps/superadmin/.env.local"
)
TARGET_EMAIL = "qa-r08-g5-internal@coelo.me"
TARGET_CPF = "12092026851"
ORIGIN = "http://127.0.0.1:3014"
REDIRECT = "https://superadmin.coelo.me/reset-password"


def load_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[key.strip()] = value
    return values


def request_json(
    method: str,
    url: str,
    headers: dict[str, str],
    payload: object | None = None,
) -> tuple[int, dict[str, str], object]:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
            parsed = json.loads(raw) if raw else None
            return response.status, dict(response.headers.items()), parsed
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            parsed = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            parsed = None
        return error.code, dict(error.headers.items()), parsed


def rpc(
    base_url: str,
    key: str,
    token: str,
    name: str,
    payload: object,
) -> tuple[int, object]:
    status, _, body = request_json(
        "POST",
        f"{base_url}/rest/v1/rpc/{name}",
        {
            "apikey": key,
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        payload,
    )
    return status, body


def fail(stage: str, status: int | None = None, code: object = None) -> None:
    print(json.dumps({"ok": False, "stage": stage, "status": status, "code": code}))
    raise SystemExit(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--verify-existing-id")
    args = parser.parse_args()
    if not QA_ENV.is_file() or not APP_ENV.is_file():
        fail("private_environment_missing")
    qa = load_env(QA_ENV)
    app = load_env(APP_ENV)
    required = {
        "email": qa.get("QA_EMAIL"),
        "password": qa.get("QA_PASSWORD"),
        "url": app.get("COELO_SUPABASE_URL"),
        "key": app.get("COELO_SUPABASE_PUBLISHABLE_KEY"),
    }
    if not all(required.values()):
        fail("private_environment_incomplete")
    if args.dry_run:
        print(json.dumps({"ok": True, "mode": "dry-run", "mutation": False}))
        return

    base_url = str(required["url"]).rstrip("/")
    key = str(required["key"])
    status, _, login = request_json(
        "POST",
        f"{base_url}/auth/v1/token?grant_type=password",
        {"apikey": key, "Content-Type": "application/json"},
        {"email": required["email"], "password": required["password"]},
    )
    if status != 200 or not isinstance(login, dict) or not login.get("access_token"):
        fail("login", status)
    token = str(login["access_token"])
    created_id: str | None = None
    summary: dict[str, object] = {}
    try:
        status, profiles = rpc(base_url, key, token, "superadmin_internal_user_profiles", {})
        items = profiles.get("items", []) if isinstance(profiles, dict) else []
        candidates = [
            item for item in items
            if isinstance(item, dict) and item.get("active") is True
            and item.get("allows_global") is True and item.get("code") != "owner"
        ]
        if status != 200 or not candidates:
            fail("profiles", status)
        candidates.sort(key=lambda item: (len(item.get("permissions", [])), str(item.get("code"))))
        profile = candidates[0]
        profile_id = str(profile["id"])

        list_payload = {
            "p_search": TARGET_EMAIL,
            "p_profile_ids": None,
            "p_statuses": None,
            "p_scopes": None,
            "p_page": 1,
            "p_page_size": 11,
        }
        status, existing = rpc(base_url, key, token, "superadmin_internal_users_list", list_payload)
        if status != 200:
            fail("duplicate_preflight", status)
        # A listagem mascara o e-mail, mas o filtro é aplicado ao valor bruto no
        # servidor. Com a busca pelo endereço completo, qualquer hit bloqueia a
        # criação para evitar duplicidade após uma tentativa anterior incerta.
        existing_count = existing.get("total", 0) if isinstance(existing, dict) else 0
        if args.verify_existing_id:
            status, detail = rpc(
                base_url, key, token, "superadmin_internal_user_detail",
                {"p_internal_identity_id": args.verify_existing_id},
            )
            memberships = detail.get("memberships", []) if isinstance(detail, dict) else []
            identity_detail = detail.get("identity", {}) if isinstance(detail, dict) else {}
            detail_ok = (
                status == 200 and isinstance(detail, dict)
                and detail.get("id") == args.verify_existing_id
                and isinstance(identity_detail, dict)
                and identity_detail.get("professional_email") == TARGET_EMAIL
                and detail.get("credential", {}).get("status") == "active"
                and isinstance(memberships, list) and len(memberships) == 1
                and memberships[0].get("status") == "active"
                and memberships[0].get("scope") == "platform"
                and memberships[0].get("profile", {}).get("id") == profile_id
            )
            if existing_count != 1 or not detail_ok:
                fail("existing_reread", status)
            summary = {
                "ok": True,
                "created": False,
                "existing_count": existing_count,
                "internal_identity_id": args.verify_existing_id,
                "profile_code": profile.get("code"),
                "profile_permission_count": len(profile.get("permissions", [])),
                "scope": "platform",
                "detail_reread": True,
                "list_reread": True,
                "synthetic_preserved": True,
            }
            return
        if existing_count:
            print(json.dumps({"ok": False, "stage": "duplicate_preflight", "count": existing_count}))
            raise SystemExit(3)

        identity = {
            "first_name": "QA",
            "last_name": "R08 G5",
            "display_name": "QA R08 G5 Interno",
            "birth_date": "1990-09-12",
            "cpf": TARGET_CPF,
            "professional_email": TARGET_EMAIL,
            "mobile": "",
            "additional_phone": "",
            "job_title": "QA sintético",
            "department": "Qualidade",
            "internal_function": "Prova P51 R08",
            "professional_notes": "Sintético; preservar até o fim formal da Etapa 2.",
            "postal_code": "",
            "street": "",
            "number": "",
            "complement": "",
            "neighborhood": "",
            "city": "",
            "state": "",
            "country": "Brasil",
        }
        draft = {
            "identity": identity,
            "profile_id": profile_id,
            "scope": "platform",
            "scope_ids": [],
        }
        status, authorized = rpc(
            base_url, key, token,
            "superadmin_internal_user_create_authorize_v1",
            {"p_draft": draft},
        )
        if status != 200 or not isinstance(authorized, dict) or authorized.get("ok") is not True:
            error = authorized.get("error", {}) if isinstance(authorized, dict) else {}
            fail("authorization", status, error.get("code") if isinstance(error, dict) else None)

        status, response_headers, created = request_json(
            "POST",
            f"{base_url}/functions/v1/internal-user-create",
            {
                "apikey": key,
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
                "Origin": ORIGIN,
                "x-client-info": "coelo-r08-g5-p51-smoke",
            },
            {"request_id": str(uuid.uuid4()), "draft": draft},
        )
        data = created.get("data", {}) if isinstance(created, dict) else {}
        if status != 200 or not isinstance(created, dict) or created.get("ok") is not True or not isinstance(data, dict):
            code = created.get("error") if isinstance(created, dict) else None
            fail("create", status, code)
        created_id = data.get("id") if isinstance(data.get("id"), str) else None
        setup_link = data.pop("password_setup_link", None)
        if not created_id or not isinstance(setup_link, str):
            fail("create_envelope", status)
        summary = {"created": True, "internal_identity_id": created_id}

        parsed = urllib.parse.urlparse(setup_link)
        expected = urllib.parse.urlparse(base_url)
        query = urllib.parse.parse_qs(parsed.query, keep_blank_values=True)
        normalized_headers = {key.lower(): value for key, value in response_headers.items()}
        link_checks = {
            "provided": True,
            "https": parsed.scheme == "https",
            "host": parsed.hostname == expected.hostname,
            "path": parsed.path == "/auth/v1/verify",
            "no_authority_credentials": parsed.username is None and parsed.password is None,
            "redirect_exact": query.get("redirect_to") == [REDIRECT],
            "no_store": normalized_headers.get("cache-control", "").lower() == "no-store",
            "cors_origin_exact": normalized_headers.get("access-control-allow-origin") == ORIGIN,
        }
        setup_link = ""
        if not all(link_checks.values()):
            fail("password_setup_link_contract", status)

        status, detail = rpc(
            base_url, key, token, "superadmin_internal_user_detail",
            {"p_internal_identity_id": created_id},
        )
        if status != 200 or not isinstance(detail, dict) or detail.get("id") != created_id:
            fail("detail_reread", status)
        memberships = detail.get("memberships", [])
        identity_detail = detail.get("identity", {})
        detail_ok = (
            isinstance(identity_detail, dict)
            and identity_detail.get("professional_email") == TARGET_EMAIL
            and detail.get("credential", {}).get("status") == "active"
            and isinstance(memberships, list) and len(memberships) == 1
            and memberships[0].get("status") == "active"
            and memberships[0].get("scope") == "platform"
            and memberships[0].get("profile", {}).get("id") == profile_id
        )
        if not detail_ok:
            fail("detail_contract", status)

        status, reread = rpc(base_url, key, token, "superadmin_internal_users_list", list_payload)
        reread_items = reread.get("items", []) if isinstance(reread, dict) else []
        exact_reread = [
            item for item in reread_items
            if isinstance(item, dict) and item.get("id") == created_id
        ]
        if status != 200 or len(exact_reread) != 1:
            fail("list_reread", status)
        summary = {
            "ok": True,
            "created": True,
            "internal_identity_id": created_id,
            "profile_code": profile.get("code"),
            "profile_permission_count": len(profile.get("permissions", [])),
            "scope": "platform",
            "authorization": True,
            "password_setup_link": link_checks,
            "detail_reread": True,
            "list_reread": True,
            "synthetic_preserved": True,
        }
    finally:
        logout_status, _, _ = request_json(
            "POST",
            f"{base_url}/auth/v1/logout?scope=local",
            {"apikey": key, "Authorization": f"Bearer {token}"},
        )
        if summary:
            summary["logout_local_status"] = logout_status
            summary["logout_local"] = logout_status in (200, 204)
            print(json.dumps(summary, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
