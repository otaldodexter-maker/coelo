"""Historical R08 retry: final author-denial oracle is WRONG; see moments-api-proof.md.
Do not rerun: retained publication is already withdrawn.
"""
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
    for name in ("config", "qa-env", "source-manifest", "manifest"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    source = json.loads(Path(args.source_manifest).read_text(encoding="utf-8"))
    output = Path(args.manifest)
    if output.exists():
        raise SystemExit("Retry manifest exists; inspect it before another attempt.")
    cfg, qa = configuration(args.config), configuration(args.qa_env)
    base = cfg["COELO_SUPABASE_URL"].rstrip("/")
    headers = {"apikey": cfg["COELO_SUPABASE_PUBLISHABLE_KEY"], "Content-Type": "application/json"}
    opener = urllib.request.build_opener(NoRedirect())
    publication_id = source["resources"]["publication_id"]
    asset_id = source["resources"]["asset_id"]
    manifest = {"source": args.source_manifest, "ui_e2e": False, "environment": "production", "started_at": datetime.now(timezone.utc).isoformat(), "publication_id": publication_id, "asset_id": asset_id, "request_id": str(uuid.uuid4()), "checks": [], "status": "running"}
    token = None

    def save():
        output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    def check(name, passed, status=None):
        manifest["checks"].append({"name": name, "passed": bool(passed), "http_status": status})
        save()
        if not passed:
            raise RuntimeError(name)

    def request(path, payload):
        try:
            with opener.open(urllib.request.Request(base + path, headers=headers, data=json.dumps(payload).encode(), method="POST"), timeout=30) as response:
                status, body = response.status, response.read()
        except urllib.error.HTTPError as error:
            status, body = error.code, error.read()
        try:
            return status, json.loads(body)
        except (ValueError, UnicodeDecodeError):
            return status, None

    def rpc(name, payload):
        status, result = request("/rest/v1/rpc/" + name, payload)
        if status != 200 and isinstance(result, dict):
            code = result.get("code")
            if isinstance(code, str) and code.isalnum() and len(code) <= 16:
                manifest["backend_error_code"] = code
        check(name, status == 200, status)
        return result

    try:
        save()
        status, login = request("/auth/v1/token?grant_type=password", {"email": qa["QA_EMAIL"], "password": qa["QA_PASSWORD"]})
        check("qa_login", status == 200, status)
        token = login["access_token"]
        headers["Authorization"] = "Bearer " + token
        scope = {"p_institution_id": source["institution_id"], "p_unit_id": source["unit_id"], "p_group_id": source["group_id"], "p_limit": 50, "p_cursor": None}
        rows = rpc("list_visible_moments", scope)
        retained = next((row for row in rows if row.get("publication_id") == publication_id), None)
        check("same_retained_publication_visible", retained is not None)
        check("withdrawal_projected_authorized", retained.get("can_withdraw") is True)
        result = rpc("withdraw_moment", {"p_request_id": manifest["request_id"], "p_publication_id": publication_id, "p_expected_version": None, "p_reason": "R08 G4 retained synthetic proof withdrawal after permission correction"})
        check("withdrawal_timestamp_returned", result.get("id") == publication_id and bool(result.get("withdrawn_at")))
        rows = rpc("list_visible_moments", scope)
        check("fresh_reload_absent", not any(row.get("publication_id") == publication_id for row in rows))
        status, _ = request("/functions/v1/moments-media", {"action": "read", "asset_id": asset_id})
        check("withdrawn_asset_read_denied", status == 403, status)
        manifest["status"] = "passed"
        manifest["retention"] = "soft withdrawal only; publication, asset and R2 master preserved"
    except Exception as error:
        manifest["status"] = "failed"
        manifest["failure_type"] = type(error).__name__
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
