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
            return response.status, json.loads(response.read() or b"null")
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b"null")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--qa-env", required=True)
    parser.add_argument("--app-env", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    output = Path(args.manifest)
    if output.exists():
        raise SystemExit("manifest_exists_do_not_overwrite")
    if args.execute:
        raise SystemExit("execution_requires_G5_C0_review_and_exact_ids")
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
        for name, payload in (("context_options", {}), ("closing_queue", {})):
            http, body = call(base, headers, f"/rest/v1/rpc/superadmin_assessment_{name}", payload)
            entry: dict[str, object] = {"http_status": http, "kind": type(body).__name__}
            if isinstance(body, dict):
                entry["keys"] = sorted(body.keys())
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
        manifest["logout_http_status"] = call(base, headers, "/auth/v1/logout?scope=local", {})[0]
    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"mode": "dry-run", "mutations": False, "manifest": str(output)}))
    return 0 if status == 200 else 1


if __name__ == "__main__":
    raise SystemExit(main())
