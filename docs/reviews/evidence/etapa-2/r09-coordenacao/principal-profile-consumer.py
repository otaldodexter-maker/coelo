"""Read authorized Principal contexts with normal Auth; retain no credentials."""
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
    report = {'at': datetime.now(timezone.utc).isoformat(), 'checks': []}
    def check(name, passed, **safe):
        row = {'step': name, 'pass': bool(passed), **safe}
        report['checks'].append(row)
        print(json.dumps(row), flush=True)
        assert passed, name
    authenticated = False
    try:
        status, body = transport.call(base, headers, '/rest/v1/rpc/list_my_principal_contexts', {})
        check('anonymous_contexts_denied', status in (401,403), http=status)
        status, session = transport.call(base, headers, '/auth/v1/token?grant_type=password', {'email': qa['QA_EMAIL'], 'password': qa['QA_PASSWORD']})
        authenticated = status == 200 and bool(session.get('access_token'))
        if authenticated:
            headers['Authorization'] = 'Bearer ' + session['access_token']
        check('normal_auth', authenticated, http=status)
        status, contexts = transport.call(base, headers, '/rest/v1/rpc/list_my_principal_contexts', {})
        safe = [{k: c.get(k) for k in ('institution_id','institution_handle','scope_kind','role_code','unit_id','group_id')} for c in contexts] if isinstance(contexts,list) else []
        check('ui_contexts_resolved_by_server', status == 200 and {'qa-r04-cuidado-sintetico','qa-r04-chat'}.issubset({c.get('institution_handle') for c in safe}), http=status, contexts=safe)
        for handle in ('qa-r04-cuidado-sintetico','qa-r04-chat'):
            subject = next(c['institution_id'] for c in contexts if c.get('institution_handle') == handle)
            status, body = transport.call(base, headers, '/rest/v1/rpc/get_profile_about', {'p_subject_type':'institution','p_subject_id':subject})
            check('about_empty_matches_ui_'+handle, status == 200 and body is None, http=status, subject_id=subject)
        status, again = transport.call(base, headers, '/rest/v1/rpc/list_my_principal_contexts', {})
        check('context_records_stable_on_reload', status == 200 and again == contexts, http=status)
    finally:
        if authenticated:
            status, _ = transport.call(base, headers, '/auth/v1/logout?scope=local', {})
            check('own_session_logout', status == 204, http=status)
        output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')

if __name__ == '__main__':
    main()
