"""Read only the retained G1 group; reuse R08 transport, never its executor."""
import importlib.util
import json
from datetime import datetime, timezone
from pathlib import Path


def main():
    here = Path(__file__).resolve().parent
    spec = importlib.util.spec_from_file_location(
        "r08_transport", here.parent / "r08-estrutura" / "assessments_api_runner.py"
    )
    transport = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(transport)
    qa = transport.env(Path("C:/Users/adrie/Documents/Coelo-backups/qa-r06-estrutura.env"))
    app = transport.env(Path("C:/Users/adrie/Documents/Coelo.worktrees/e2-r09-ambiente-runtime-20260912-1542/apps/superadmin/.env.local"))
    base = app.get("COELO_SUPABASE_URL", "").rstrip("/")
    key = app.get("COELO_SUPABASE_PUBLISHABLE_KEY", "")
    if not base or not key or not qa.get("QA_EMAIL") or not qa.get("QA_PASSWORD"):
        raise SystemExit("private_environment_incomplete")
    headers = {"apikey": key, "Content-Type": "application/json"}
    output = here / "group-read-proof.json"
    if output.exists():
        raise SystemExit("proof_exists_do_not_repeat")
    result = {"round": "E2-R09-20260912-1542", "measuredAt": datetime.now(timezone.utc).isoformat(),
              "businessMutations": False, "actor": "qa-r06-estrutura", "checks": {}}
    status, login = transport.call(base, headers, "/auth/v1/token?grant_type=password",
        {"email": qa["QA_EMAIL"], "password": qa["QA_PASSWORD"]})
    result["loginHttp"] = status
    if status != 200 or not isinstance(login, dict) or not isinstance(login.get("access_token"), str):
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        return 1
    headers["Authorization"] = "Bearer " + login["access_token"]
    try:
        group_id = "4214106c-46a2-4bf4-84ba-9c6a619bd486"
        status, body = transport.call(base, headers, "/rest/v1/rpc/superadmin_group_get", {"p_group_id": group_id})
        result["readHttp"] = status
        row = body if status == 200 and isinstance(body, dict) else {}
        result["checks"] = {
            "retainedGroup": row.get("id") == group_id,
            "retainedInstitution": row.get("institution_id") == "190dd028-3125-452d-8502-612bfa1029de",
            "retainedUnit": row.get("unit_id") == "f5284f2f-b487-4100-bc0b-ffbcbb7d3db3",
            "accessIsList": isinstance(row.get("effective_access"), list),
        }
        access = row.get("effective_access", [])
        if isinstance(access, list):
            result["accessCount"] = len(access)
            result["localAccessCount"] = sum(item.get("inherited") is False for item in access)
            result["profileCodes"] = sorted({item.get("profile_code", "") for item in access})
            result["checks"]["flatRoleContract"] = bool(access) and all(
                all(key in item for key in ("profile_id", "profile_code", "profile_name")) for item in access
            )
    finally:
        result["logoutLocalHttp"] = transport.call(base, headers, "/auth/v1/logout?scope=local", {})[0]
        headers.pop("Authorization", None)
        login.clear()
        qa.clear()
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return 0 if all(result["checks"].values()) and result["logoutLocalHttp"] == 204 else 1


if __name__ == "__main__":
    raise SystemExit(main())
