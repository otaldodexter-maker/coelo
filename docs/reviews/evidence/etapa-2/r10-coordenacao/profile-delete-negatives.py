"""Read-only consumer checks after the normal UI deleted the R10 profile."""
import importlib.util
import json
import uuid
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[5]
spec = importlib.util.spec_from_file_location('transport', ROOT / 'docs/reviews/evidence/etapa-2/r08-estrutura/assessments_api_runner.py')
t = importlib.util.module_from_spec(spec)
spec.loader.exec_module(t)
out = Path(__file__).with_suffix('.json')
assert not out.exists()
app = t.env(ROOT / 'apps/superadmin/.env.local')
qa = t.env(Path('C:/Users/adrie/Documents/Coelo-backups/qa-r06-estrutura.env'))
base = app['COELO_SUPABASE_URL'].rstrip('/')
assert base == 'https://evvbomzejfijozbtgvpt.supabase.co'
h = {'apikey': app['COELO_SUPABASE_PUBLISHABLE_KEY'], 'Content-Type': 'application/json'}
target = '424d4d15-009f-4e32-911c-9ae37c056bd1'
report = {'at': datetime.now(timezone.utc).isoformat(), 'profile': target, 'domain': 'platform', 'crossTenantSession': False, 'checks': []}
authenticated = False

def check(name, passed, **safe):
    row = {'name': name, 'pass': bool(passed), **safe}
    report['checks'].append(row)
    print(json.dumps(row), flush=True)
    assert passed, name

try:
    code, body = t.call(base, h, '/rest/v1/rpc/superadmin_access_profile_delete_and_reassign', {
        'p_request_id': str(uuid.uuid4()), 'p_domain': 'platform', 'p_profile_id': target,
        'p_expected_version': 1, 'p_replacement_profile_id': None, 'p_reason': 'R10 anonymous denial after UI deletion',
    })
    check('anonymous_delete_denied', code in (401, 403), http=code)
    code, body = t.call(base, h, '/auth/v1/token?grant_type=password', {'email': qa['QA_EMAIL'], 'password': qa['QA_PASSWORD']})
    authenticated = code == 200 and bool(body.get('access_token'))
    check('normal_auth', authenticated, http=code)
    h['Authorization'] = 'Bearer ' + body['access_token']
    code, body = t.call(base, h, '/rest/v1/rpc/superadmin_access_profile_detail', {'p_domain': 'platform', 'p_profile_id': target})
    check('deleted_profile_unavailable', code >= 400 and body.get('code') == 'P0002', http=code, error_code=body.get('code'))
except Exception as error:
    report['failure'] = type(error).__name__
finally:
    if authenticated:
        code, _ = t.call(base, h, '/auth/v1/logout?scope=local', {})
        report['checks'].append({'name': 'own_session_logout', 'pass': code == 204, 'http': code})
    report['pass'] = 'failure' not in report and all(row['pass'] for row in report['checks'])
    out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
raise SystemExit(0 if report['pass'] else 1)
