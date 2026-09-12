"""Re-read UI model edits and copy with normal Auth; no mutations."""
import importlib.util
import json
from pathlib import Path
from datetime import datetime, timezone

spec = importlib.util.spec_from_file_location('transport_helper', Path(__file__).with_name('people-handle-negative.py'))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
transport = helper.transport

def main():
    output = Path(__file__).with_suffix('.json')
    assert not output.exists(), 'proof already exists'
    app = transport.env(Path('C:/Users/adrie/Documents/Coelo.worktrees/e2-r09-ambiente-runtime-20260912-1542/apps/superadmin/.env.local'))
    qa = transport.env(Path('C:/Users/adrie/Documents/Coelo-backups/qa-r06-estrutura.env'))
    base = app['COELO_SUPABASE_URL'].rstrip('/')
    assert base == 'https://evvbomzejfijozbtgvpt.supabase.co'
    headers = {'apikey': app['COELO_SUPABASE_PUBLISHABLE_KEY'], 'Content-Type': 'application/json'}
    source = 'cc322488-bb7d-4490-9418-ac941db7e6ae'
    copy = '5e1b5e75-814a-43cf-8031-d38ee3d4f830'
    report = {'at': datetime.now(timezone.utc).isoformat(), 'source': source, 'copy': copy, 'checks': []}
    def check(name, passed, **safe):
        row = {'step': name, 'pass': bool(passed), **safe}
        report['checks'].append(row)
        print(json.dumps(row), flush=True)
        assert passed, name
    def detail(model):
        return transport.call(base, headers, '/rest/v1/rpc/superadmin_access_profile_model_detail', {'p_model_id': model})
    authenticated = False
    try:
        status, body = detail(source)
        check('anonymous_denied', status in (401,403) and body.get('code') == '42501', http=status)
        status, session = transport.call(base, headers, '/auth/v1/token?grant_type=password', {'email': qa['QA_EMAIL'], 'password': qa['QA_PASSWORD']})
        authenticated = status == 200 and bool(session.get('access_token'))
        if authenticated:
            headers['Authorization'] = 'Bearer ' + session['access_token']
        check('normal_auth', authenticated, http=status)
        status, body = detail(source)
        source_data = body.get('data') or {}
        check('edited_description_persisted', status == 200 and source_data.get('description') == 'Modelo sintetico da Rodada 4; descricao revisada pela UI na R09 1542.' and source_data.get('version') == 3, http=status)
        status, body = detail(copy)
        copy_data = body.get('data') or {}
        check('inactive_independent_copy_persisted', status == 200 and copy_data.get('name') == 'QA R09 Copia modelo 1542' and copy_data.get('status') == 'inactive' and copy_data.get('version') == 1, http=status)
        check('copied_capabilities_match_source', bool(source_data.get('capabilities')) and copy_data.get('capabilities') == source_data.get('capabilities'))
    finally:
        if authenticated:
            status, _ = transport.call(base, headers, '/auth/v1/logout?scope=local', {})
            check('own_session_logout', status == 204, http=status)
        output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')

if __name__ == '__main__':
    main()
