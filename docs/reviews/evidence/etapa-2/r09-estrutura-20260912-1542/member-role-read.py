"""Read only the retained G1 group; reuse R08 transport, never its executor."""
import importlib.util
import json
import urllib.request
import urllib.error
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
    output = here / "member-role-read.json"
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
        path="/rest/v1/institution_roles?select=id,code,institution_id,max_scope_kind&status=eq.active&or=(institution_id.is.null,institution_id.eq.190dd028-3125-452d-8502-612bfa1029de)"
        request=urllib.request.Request(base+path,headers=headers,method="GET")
        try:
            with urllib.request.urlopen(request,timeout=30) as response:
                status=response.status;body=json.loads(response.read())
        except urllib.error.HTTPError as error:
            status=error.code;body=json.loads(error.read())
        result["readHttp"]=status
        result["checks"]["readable"]=status==200
        result["visibleRoles"]=body if status==200 else []
        result["limitation"]="RLS filtered read; absence is not proof of global absence"
    finally:
        result["logoutLocalHttp"] = transport.call(base, headers, "/auth/v1/logout?scope=local", {})[0]
        headers.pop("Authorization", None)
        login.clear()
        qa.clear()
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return 0 if all(result["checks"].values()) and result["logoutLocalHttp"] == 204 else 1


if __name__ == "__main__":
    raise SystemExit(main())
