"""Check retained synthetic handle through normal auth; no successful write expected."""
import importlib.util
import json
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
spec = importlib.util.spec_from_file_location('transport', ROOT / 'docs/reviews/evidence/etapa-2/r08-estrutura/assessments_api_runner.py')
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)

def main():
    output = Path(__file__).with_suffix('.json')
    if output.exists():
        raise RuntimeError('proof_already_exists')
    app = transport.env(Path('C:/Users/adrie/Documents/Coelo.worktrees/e2-r09-ambiente-runtime-20260912-1542/apps/superadmin/.env.local'))
    qa = transport.env(Path('C:/Users/adrie/Documents/Coelo-backups/qa-r06-estrutura.env'))
    base = app['COELO_SUPABASE_URL'].rstrip('/')
    assert base == 'https://evvbomzejfijozbtgvpt.supabase.co'
    headers = {'apikey': app['COELO_SUPABASE_PUBLISHABLE_KEY'], 'Content-Type': 'application/json'}
    person = 'cb989d45-6ab2-419c-9373-104bd2a01684'
    report = {'at': datetime.now(timezone.utc).isoformat(), 'person_id': person, 'checks': [], 'realCrossTenantSession': False}
    def check(name, passed, **safe):
        row = {'step': name, 'pass': bool(passed), **safe}
        report['checks'].append(row)
        print(json.dumps(row), flush=True)
        assert passed, name
    def rpc(name, payload):
        return transport.call(base, headers, '/rest/v1/rpc/' + name, payload)
    authenticated = False
    try:
        status, body = rpc('superadmin_person_handle_get', {'p_person_id': person})
        check('anonymous_denied', status in (401, 403) and body.get('code') == '42501', http=status)
        status, session = transport.call(base, headers, '/auth/v1/token?grant_type=password', {'email': qa['QA_EMAIL'], 'password': qa['QA_PASSWORD']})
        authenticated = status == 200 and bool(session.get('access_token'))
        if authenticated:
            headers['Authorization'] = 'Bearer ' + session['access_token']
        check('normal_auth', authenticated, http=status)
        status, body = rpc('superadmin_person_handle_get', {'p_person_id': person})
        data = body.get('data') or {}
        check('ui_handle_persisted', status == 200 and data.get('handle') == 'qar09.pessoa1542' and bool(data.get('last_changed_at')), http=status)
        status, body = rpc('superadmin_person_handle_set', {'p_request_id': str(uuid.uuid4()), 'p_person_id': person, 'p_handle': 'qar09.negativa1542', 'p_reason': 'QA R09: tentativa negativa durante cooldown.'})
        check('server_cooldown_denies_second_change', status == 400 and body.get('code') == '22023' and body.get('details') == 'cooldown', http=status)
        status, body = rpc('superadmin_person_handle_get', {'p_person_id': person})
        check('negative_preserves_handle', status == 200 and body.get('data', {}).get('handle') == 'qar09.pessoa1542', http=status)
    finally:
        if authenticated:
            status, _ = transport.call(base, headers, '/auth/v1/logout?scope=local', {})
            check('own_session_logout', status == 204, http=status)
        output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')

if __name__ == '__main__':
    main()
