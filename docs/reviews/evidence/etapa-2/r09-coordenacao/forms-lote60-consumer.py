"""Reprove the retained real download after the authorizer changed; reuse prior TTL proof."""
import hashlib
import importlib.util
import json
import urllib.request
import uuid
from pathlib import Path

spec = importlib.util.spec_from_file_location('probe', Path(__file__).with_name('forms-download-access-probe.py'))
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
smoke = probe.smoke

def main():
    app, qa = smoke.read_env(smoke.APP_ENV), smoke.read_env(smoke.QA_ENV)
    fixture = json.loads((probe.SOURCE / 'forms-answer-image-response-resume-manifest.json').read_text())
    base = app['COELO_SUPABASE_URL'].rstrip('/')
    assert base == 'https://evvbomzejfijozbtgvpt.supabase.co'
    headers = {'apikey': app['COELO_SUPABASE_PUBLISHABLE_KEY'], 'content-type': 'application/json'}
    status, session = smoke.request_json(base + '/auth/v1/token?grant_type=password', body={'email': qa['QA_EMAIL'], 'password': qa['QA_PASSWORD']}, headers=headers)
    assert status == 200 and session.get('access_token')
    probe.emit('auth', 'PASS', http=status)
    headers['authorization'] = 'Bearer ' + session['access_token']
    try:
        status, result = smoke.request_json(base + '/functions/v1/form-media', body={
            'action': 'download', 'request_id': str(uuid.uuid4()), 'expected_version': 0,
            'payload': {'asset_id': fixture['asset_id']}}, headers=headers)
        assert status == 200 and result.get('expires_in') == 60
        opener = urllib.request.build_opener(smoke.NoRedirect())
        with opener.open(result['signed_url'], timeout=30) as response:
            received = response.read(1024)
            assert response.status == 200 and received == smoke.PNG
        probe.emit('real_download_after_lote60', 'PASS', bytes=len(received), sha256=hashlib.sha256(received).hexdigest(), asset_id=fixture['asset_id'])
    finally:
        status, _ = smoke.request_json(base + '/auth/v1/logout?scope=local', headers=headers)
        probe.emit('logout_local', 'PASS' if status == 204 else 'FAIL', http=status)
        assert status == 204

if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        probe.emit('result', 'FAIL', error_type=type(error).__name__)
        raise SystemExit(1)
