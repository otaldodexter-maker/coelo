"""Read the retained R08 synthetic after normal UI edit. Never print identity fields."""
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
    target = '0ddeebc0-ee10-4565-96e0-ef11cacfc734'
    report = {'at': datetime.now(timezone.utc).isoformat(), 'target': target, 'checks': []}
    def check(name, passed, **safe):
        row = {'step': name, 'pass': bool(passed), **safe}
        report['checks'].append(row)
        print(json.dumps(row), flush=True)
        assert passed, name
    def detail():
        return transport.call(base, headers, '/rest/v1/rpc/superadmin_internal_user_detail', {'p_internal_identity_id': target})
    authenticated = False
    try:
        status, body = detail()
        check('anonymous_denied', status in (401,403) and body.get('code') == '42501', http=status)
        status, session = transport.call(base, headers, '/auth/v1/token?grant_type=password', {'email': qa['QA_EMAIL'], 'password': qa['QA_PASSWORD']})
        authenticated = status == 200 and bool(session.get('access_token'))
        if authenticated:
            headers['Authorization'] = 'Bearer ' + session['access_token']
        check('normal_auth', authenticated, http=status)
        status, body = detail()
        check('ui_edit_persisted', status == 200 and body.get('identity',{}).get('job_title') == 'QA sintetico revisado R09', http=status, version=body.get('version'))
        check('synthetic_cpf_corrected', body.get('identity',{}).get('cpf') == '12092026895')
        membership = body.get('memberships',[{}])[0]
        check('support_scope_and_credential_preserved', membership.get('profile',{}).get('code') == 'support' and membership.get('scope') == 'platform' and membership.get('status') == 'active' and body.get('credential',{}).get('status') == 'active')
    finally:
        if authenticated:
            status, _ = transport.call(base, headers, '/auth/v1/logout?scope=local', {})
            check('own_session_logout', status == 204, http=status)
        output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')

if __name__ == '__main__':
    main()
