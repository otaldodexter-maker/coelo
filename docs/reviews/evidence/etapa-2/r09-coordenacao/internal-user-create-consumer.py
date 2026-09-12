"""Read the UI-created and suspended R09 synthetic; no successful writes."""
import importlib.util
import json
from pathlib import Path
from datetime import datetime, timezone
spec = importlib.util.spec_from_file_location('helper', Path(__file__).with_name('people-handle-negative.py'))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
transport = helper.transport

def main():
    output = Path(__file__).with_suffix('.json')
    assert not output.exists()
    app = transport.env(Path('C:/Users/adrie/Documents/Coelo.worktrees/e2-r09-ambiente-runtime-20260912-1542/apps/superadmin/.env.local'))
    qa = transport.env(Path('C:/Users/adrie/Documents/Coelo-backups/qa-r06-estrutura.env'))
    base = app['COELO_SUPABASE_URL'].rstrip('/')
    headers = {'apikey': app['COELO_SUPABASE_PUBLISHABLE_KEY'], 'Content-Type': 'application/json'}
    target = '3429b381-6e3e-414f-ab12-be3326144ac4'
    report = {'at': datetime.now(timezone.utc).isoformat(), 'target': target, 'checks': []}
    def check(name, passed, **safe):
        row = {'step': name, 'pass': bool(passed), **safe}
        report['checks'].append(row)
        print(json.dumps(row), flush=True)
        assert passed, name
    def rpc(name, payload):
        return transport.call(base, headers, '/rest/v1/rpc/'+name, payload)
    authenticated = False
    try:
        status, body = rpc('superadmin_internal_user_create_authorize_v1', {'p_draft': {}})
        check('anonymous_create_denied', status in (401,403) and body.get('code') == '42501', http=status)
        status, body = rpc('superadmin_internal_user_detail', {'p_internal_identity_id': target})
        check('anonymous_detail_denied', status in (401,403) and body.get('code') == '42501', http=status)
        status, session = transport.call(base, headers, '/auth/v1/token?grant_type=password', {'email': qa['QA_EMAIL'], 'password': qa['QA_PASSWORD']})
        authenticated = status == 200 and bool(session.get('access_token'))
        if authenticated:
            headers['Authorization'] = 'Bearer ' + session['access_token']
        check('normal_operator_auth', authenticated, http=status)
        status, body = rpc('superadmin_internal_user_detail', {'p_internal_identity_id': target})
        membership = body.get('memberships',[{}])[0]
        check('ui_suspension_persisted', status == 200 and body.get('version') == 2 and membership.get('status') == 'suspended' and body.get('credential',{}).get('status') == 'blocked', http=status)
        check('support_limited_scope_preserved', membership.get('profile',{}).get('code') == 'support' and membership.get('scope') == 'limited' and membership.get('scope_ids') == ['d0c40000-0000-4000-8000-000000000001'])
    finally:
        if authenticated:
            status, _ = transport.call(base, headers, '/auth/v1/logout?scope=local', {})
            check('own_session_logout', status == 204, http=status)
        output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')

if __name__ == '__main__':
    main()
