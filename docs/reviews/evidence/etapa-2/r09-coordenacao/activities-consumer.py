"""Read the same activity directory through normal Auth; no mutations."""
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
    institution = '190dd028-3125-452d-8502-612bfa1029de'
    unit = 'f5284f2f-b487-4100-bc0b-ffbcbb7d3db3'
    report = {'at': datetime.now(timezone.utc).isoformat(), 'checks': []}
    def check(name, passed, **safe):
        row = {'step': name, 'pass': bool(passed), **safe}
        report['checks'].append(row)
        print(json.dumps(row), flush=True)
        assert passed, name
    def directory(institution_id):
        return transport.call(base, headers, '/rest/v1/rpc/superadmin_activity_directory_v2', {'p_filters': {'institution_ids': [institution_id], 'unit_ids': [unit]}, 'p_limit': 11, 'p_offset': 0, 'p_sort': 'name', 'p_sort_ascending': True})
    authenticated = False
    try:
        status, body = directory(institution)
        check('anonymous_directory_denied', status in (401,403) and body.get('code') == '42501', http=status)
        status, session = transport.call(base, headers, '/auth/v1/token?grant_type=password', {'email': qa['QA_EMAIL'], 'password': qa['QA_PASSWORD']})
        authenticated = status == 200 and bool(session.get('access_token'))
        if authenticated:
            headers['Authorization'] = 'Bearer ' + session['access_token']
        check('normal_auth', authenticated, http=status)
        status, body = directory(institution)
        data = body.get('data') or {}
        ids = [x.get('activity_id') for x in data.get('items',[])]
        check('ui_directory_records_persisted', status == 200 and body.get('ok') is True and data.get('total') == 3 and '95b98978-19e2-43ba-aa0c-70ae81557e08' in ids, http=status, activity_ids=ids)
        status, body = directory('d0c40000-0000-4000-8000-000000000001')
        data = body.get('data') or {}
        check('foreign_institution_unit_combination_does_not_leak', not data.get('items') and (body.get('ok') is False or data.get('total') == 0), http=status, error=(body.get('error') or {}).get('code'))
    finally:
        if authenticated:
            status, _ = transport.call(base, headers, '/auth/v1/logout?scope=local', {})
            check('own_session_logout', status == 204, http=status)
        output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')

if __name__ == '__main__':
    main()
