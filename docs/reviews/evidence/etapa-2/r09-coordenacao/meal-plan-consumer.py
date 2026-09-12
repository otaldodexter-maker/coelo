"""Read the UI-published synthetic plan through normal auth; no writes."""
import json
import importlib.util
from datetime import datetime, timezone
from pathlib import Path
spec = importlib.util.spec_from_file_location('handle_probe', Path(__file__).with_name('people-handle-negative.py'))
handle_probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handle_probe)
transport = handle_probe.transport

def main():
    output = Path(__file__).with_suffix('.json')
    if output.exists():
        raise RuntimeError('proof_already_exists')
    app = transport.env(Path('C:/Users/adrie/Documents/Coelo.worktrees/e2-r09-ambiente-runtime-20260912-1542/apps/superadmin/.env.local'))
    qa = transport.env(Path('C:/Users/adrie/Documents/Coelo-backups/qa-r06-estrutura.env'))
    base = app['COELO_SUPABASE_URL'].rstrip('/')
    assert base == 'https://evvbomzejfijozbtgvpt.supabase.co'
    headers = {'apikey': app['COELO_SUPABASE_PUBLISHABLE_KEY'], 'Content-Type': 'application/json'}
    plan = '57ab05c3-32c6-44ae-b1d4-45180fbc9124'
    report = {'at': datetime.now(timezone.utc).isoformat(), 'plan_id': plan, 'checks': []}
    def check(name, passed, **safe):
        row = {'step': name, 'pass': bool(passed), **safe}
        report['checks'].append(row)
        print(json.dumps(row), flush=True)
        assert passed, name
    def rpc(name, payload):
        return transport.call(base, headers, '/rest/v1/rpc/' + name, payload)
    authenticated = False
    try:
        status, body = rpc('meal_plan_get', {'p_meal_plan_id': plan})
        check('anonymous_denied', status in (401,403) and body.get('code') == '42501', http=status)
        status, session = transport.call(base, headers, '/auth/v1/token?grant_type=password', {'email': qa['QA_EMAIL'], 'password': qa['QA_PASSWORD']})
        authenticated = status == 200 and bool(session.get('access_token'))
        if authenticated:
            headers['Authorization'] = 'Bearer ' + session['access_token']
        check('normal_auth', authenticated, http=status)
        status, body = rpc('meal_plan_get', {'p_meal_plan_id': plan})
        check('published_edit_persisted', status == 200 and body.get('id') == plan and body.get('name') == 'QA R09 Cardapio sintetico 1542 editado' and body.get('status') == 'published' and body.get('revision') == 4, http=status)
        check('edited_meal_content_persisted', 'Almoco sintetico QA R09 editado' in json.dumps(body.get('menu')), http=status)
        status, body = rpc('meal_plan_list', {'p_query': {'search': 'QA R09 Cardapio sintetico 1542', 'page': 0, 'pageSize': 11}})
        check('productive_list_contains_plan', status == 200 and any(x.get('id') == plan and x.get('status') == 'published' for x in body.get('items', [])), http=status)
    finally:
        if authenticated:
            status, _ = transport.call(base, headers, '/auth/v1/logout?scope=local', {})
            check('own_session_logout', status == 204, http=status)
        output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')

if __name__ == '__main__':
    main()
