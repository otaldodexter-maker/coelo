"""Read only existing nominal QA About subjects; persist shape, never content."""
import argparse
import json
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from happens_api_smoke import configuration, NoRedirect


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("config", "qa-env", "manifest"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    output = Path(args.manifest)
    if output.exists():
        raise SystemExit("Existing manifest; do not overwrite prior proof.")
    cfg, qa = configuration(args.config), configuration(args.qa_env)
    base = cfg["COELO_SUPABASE_URL"].rstrip("/")
    headers = {"apikey": cfg["COELO_SUPABASE_PUBLISHABLE_KEY"], "Content-Type": "application/json"}
    opener = urllib.request.build_opener(NoRedirect())
    manifest = {"source": "get_profile_about normal authenticated read; existing nominal QA hierarchy", "measured_at": datetime.now(timezone.utc).isoformat(), "ui_e2e": False, "mutations": False, "subjects": []}
    token = None

    def call(path, payload):
        try:
            with opener.open(urllib.request.Request(base + path, headers=headers, data=json.dumps(payload).encode(), method="POST"), timeout=30) as response:
                status, body = response.status, response.read()
        except urllib.error.HTTPError as error:
            status, body = error.code, error.read()
        return status, json.loads(body) if body else None

    try:
        status, login = call("/auth/v1/token?grant_type=password", {"email": qa["QA_EMAIL"], "password": qa["QA_PASSWORD"]})
        manifest["login_http_status"] = status
        if status != 200:
            raise RuntimeError("login_denied")
        token = login["access_token"]
        headers["Authorization"] = "Bearer " + token
        for kind, subject_id in [
            ("institution", "d0c40000-0000-4000-8000-000000000001"),
            ("unit", "d0c40000-0000-4000-8000-000000000002"),
            ("group", "368a5cea-2bcf-4fa4-ad1f-18da58694551"),
        ]:
            status, result = call("/rest/v1/rpc/get_profile_about", {"p_subject_type": kind, "p_subject_id": subject_id})
            entry = {"type": kind, "subject_id": subject_id, "http_status": status, "is_null": result is None}
            if status == 200 and isinstance(result, dict):
                entry.update(root_keys=sorted(result.keys()), page_id=result.get("id"), version=result.get("version"), state=result.get("state"), returned_subject_matches=result.get("subject_id") == subject_id,
                             field_count=len(result.get("fields", [])), section_count=len(result.get("sections", [])),
                             field_keys=sorted({key for item in result.get("fields", []) for key in item}), section_keys=sorted({key for item in result.get("sections", []) for key in item}))
            manifest["subjects"].append(entry)
    except Exception as error:
        manifest["failure_type"] = type(error).__name__
    finally:
        if token:
            status, _ = call("/auth/v1/logout?scope=local", {})
            manifest["logout_http_status"] = status
        output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    success = "failure_type" not in manifest and all(s["http_status"] == 200 for s in manifest["subjects"]) and manifest.get("logout_http_status") == 204
    print(json.dumps({"completed": success, "subjects": len(manifest["subjects"]), "manifest": str(output)}))
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())
