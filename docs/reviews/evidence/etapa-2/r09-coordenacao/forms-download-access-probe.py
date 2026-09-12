"""Prova focal de download/TTL; nao cria nem altera formulario, resposta ou asset."""
import hashlib
import importlib.util
import json
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
SOURCE = ROOT / "docs/reviews/evidence/etapa-2/r08-ambiente-runtime"
spec = importlib.util.spec_from_file_location("existing_smoke", SOURCE / "forms-answer-image-api-smoke.py")
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)


def emit(step, status, **safe):
    print(json.dumps({"step": step, "status": status, **safe}), flush=True)


def main():
    app = smoke.read_env(smoke.APP_ENV)
    qa = smoke.read_env(smoke.QA_ENV)
    fixture = json.loads((SOURCE / "forms-answer-image-response-resume-manifest.json").read_text())
    base = app["COELO_SUPABASE_URL"].rstrip("/")
    assert base == "https://evvbomzejfijozbtgvpt.supabase.co"
    headers = {"apikey": app["COELO_SUPABASE_PUBLISHABLE_KEY"], "content-type": "application/json"}
    edge = base + "/functions/v1/form-media"

    def body(asset):
        return {"action": "download", "request_id": str(uuid.uuid4()), "expected_version": 0,
                "payload": {"asset_id": asset}}

    status, result = smoke.request_json(edge, body=body(fixture["asset_id"]), headers=headers)
    assert status == 401 and not (isinstance(result, dict) and "signed_url" in result)
    emit("unauthenticated_download", "PASS", http=status)
    status, session = smoke.request_json(base + "/auth/v1/token?grant_type=password",
        body={"email": qa["QA_EMAIL"], "password": qa["QA_PASSWORD"]}, headers=headers)
    emit("auth", "PASS" if status == 200 else "FAIL", http=status,
         error_code=session.get("error_code", session.get("code")) if isinstance(session, dict) else None)
    assert status == 200 and isinstance(session, dict) and session.get("access_token")
    headers["authorization"] = "Bearer " + session["access_token"]
    try:
        status, result = smoke.request_json(edge, body=body("00000000-0000-4000-8000-000000000000"), headers=headers)
        assert status == 400 and result == {"error": "media_request_failed"}
        emit("unknown_asset_download", "PASS", http=status, signed_url_absent=True)
        status, result = smoke.request_json(edge, body=body(fixture["asset_id"]), headers=headers)
        assert status == 200 and result.get("expires_in") == 60
        signed_url = result["signed_url"]
        opener = urllib.request.build_opener(smoke.NoRedirect())
        with opener.open(signed_url, timeout=30) as response:
            received = response.read(1024)
            assert response.status == 200 and received == smoke.PNG
        emit("authorized_download", "PASS", bytes=len(received), sha256=hashlib.sha256(received).hexdigest(), ttl_seconds=60)
        # Espera exclusivamente para provar o TTL real do mesmo link, sem emitir outro.
        time.sleep(65)
        try:
            with opener.open(signed_url, timeout=30) as response:
                expired_status = response.status
        except urllib.error.HTTPError as error:
            expired_status = error.code
        assert expired_status == 403
        emit("expired_signed_url", "PASS", http=expired_status)
    finally:
        status, _ = smoke.request_json(base + "/auth/v1/logout?scope=local", headers=headers)
        emit("logout_local", "PASS" if status == 204 else "FAIL", http=status)
        assert status == 204
    emit("result", "PASS", preserved=True, cross_tenant_proven=False, ui_proven=False)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        # Excecoes urllib podem conter a URL assinada: nunca imprimir mensagem/traceback.
        emit("result", "FAIL", error_type=type(error).__name__)
        raise SystemExit(1)
