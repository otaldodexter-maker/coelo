"""Real RPC hierarchy denial on retained synthetic contexts; no successful create expected."""
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
    group = '1043c165-7f24-44fe-a868-5bfc6fb0b50f'
    location = 'd5461295-9273-4caa-9197-8f9d8c05c4f8'
    request_id = str(uuid.uuid4())
    report = {'round': 'E2-R09-20260912-1542', 'measuredAt': datetime.now(timezone.utc).isoformat(), 'request_id': request_id,
              'group_id': group, 'location_id': location, 'checks': [], 'realCrossTenantSession': False}
    def check(name, passed, **safe):
        row = {'step': name, 'pass': bool(passed), **safe}
        report['checks'].append(row)
        print(json.dumps(row), flush=True)
        assert passed, name
    def rpc(name, payload):
        return transport.call(base, headers, '/rest/v1/rpc/' + name, payload)
    authenticated = False
    try:
        http, body = rpc('superadmin_group_location_selection_v2', {'p_group_id': group})
        check('anonymous_read_denied', http in (401,403) and isinstance(body,dict) and body.get('code') == '42501', http=http)
        http, session = transport.call(base, headers, '/auth/v1/token?grant_type=password', {'email': qa['QA_EMAIL'], 'password': qa['QA_PASSWORD']})
        authenticated = http == 200 and bool(session.get('access_token'))
        if authenticated:
            headers['Authorization'] = 'Bearer ' + session['access_token']
        check('normal_auth', authenticated, http=http)
        http, body = rpc('superadmin_group_location_selection_v2', {'p_group_id': group})
        data = body.get('data') or {}
        check('retained_location_read', http == 200 and body.get('ok') is True and (data.get('location') or {}).get('id') == location, http=http)
        http, body = rpc('superadmin_group_location_create_v2', {
            'p_request_id': request_id, 'p_location_id': location, 'p_reservation': None,
            'p_group_payload': {'institution_id': 'd0c40000-0000-4000-8000-000000000001',
                                'unit_id': 'd0c40000-0000-4000-8000-000000000002',
                                'name': 'QA R09 negative location 1655', 'group_type': 'class', 'group_type_other_text': None}})
        code = (body.get('error') or {}).get('code') if isinstance(body,dict) else None
        check('foreign_institution_location_denied', http == 200 and body.get('ok') is False and code == 'SAI_PERMISSION_DENIED' and not body.get('data'), http=http, code=code)
    except Exception as error:
        report['failureType'] = type(error).__name__
    finally:
        if authenticated:
            http, _ = transport.call(base, headers, '/auth/v1/logout?scope=local', {})
            report['checks'].append({'step': 'logout_local', 'pass': http == 204, 'http': http})
        report['pass'] = 'failureType' not in report and all(x['pass'] for x in report['checks'])
        output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    return 0 if report['pass'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
