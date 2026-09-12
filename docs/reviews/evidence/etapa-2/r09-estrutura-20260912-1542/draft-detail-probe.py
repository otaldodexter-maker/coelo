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
    output = here / "draft-detail-proof.json"
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
        group_id = "1043c165-7f24-44fe-a868-5bfc6fb0b50f"
        for label, rpc, params in [
            ("group", "superadmin_group_get", {"p_group_id": group_id}),
            ("location", "superadmin_group_location_selection_v2", {"p_group_id": group_id}),
            ("person", "superadmin_person_detail_v2", {"p_person_id": "ec2a15a2-76bc-4e71-8419-94413d0c5c98"})]:
            status, body = transport.call(base, headers, "/rest/v1/rpc/" + rpc, params)
            result[label + "Http"] = status
            result["checks"][label + "Readable"] = status == 200 and isinstance(body, dict) and body.get("ok", True) is True
            row = body.get("data", body) if isinstance(body, dict) else {}
            result[label] = {k: row.get(k) for k in ("id", "group_id", "institution_id", "unit_id", "status", "management_version") if k in row}
            if label == "group": result["memberCount"] = len(row.get("effective_access", []))
            if label == "location": result["location"]["selection"] = row.get("location")
            if label == "person":
                for k,v in row.items():
                    if isinstance(v, dict): result["person"][k] = {x:v[x] for x in ("id", "status") if x in v}
    finally:
        result["logoutLocalHttp"] = transport.call(base, headers, "/auth/v1/logout?scope=local", {})[0]
        headers.pop("Authorization", None)
        login.clear()
        qa.clear()
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return 0 if all(result["checks"].values()) and result["logoutLocalHttp"] == 204 else 1


if __name__ == "__main__":
    raise SystemExit(main())
