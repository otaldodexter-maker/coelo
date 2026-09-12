"""G5/C0 rev97: retained assessment reads only; credentials stay in memory."""
import argparse
import importlib.util
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
SOURCE = ROOT / 'docs/reviews/evidence/etapa-2/r08-estrutura'
spec = importlib.util.spec_from_file_location('assessment_runner', SOURCE / 'assessments_api_runner.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


def denied(http, body):
    return (http in (401, 403) and isinstance(body, dict)
            and body.get('code') == '42501' and not body.get('data'))


def hidden(http, body):
    return (http == 200 and isinstance(body, dict)
            and body.get('ok') is True and 'data' in body and body['data'] is None)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--qa-env')
    parser.add_argument('--app-env')
    parser.add_argument('--output')
    args = parser.parse_args()
    if not args.execute:
        assert denied(401, {'code': '42501'})
        assert not denied(401, {'code': 'bad_jwt'})
        assert not denied(200, {'ok': True, 'data': {'id': 'leaked'}})
        assert hidden(200, {'ok': True, 'data': None})
        assert not hidden(200, {'ok': True})
        assert not hidden(200, {'ok': True, 'data': {'id': 'leaked'}})
        print('PASS: negative oracles reject false denial and leaked data; no network')
        return 0
    if not all((args.qa_env, args.app_env, args.output)):
        raise ValueError('private_paths_required')
    output = Path(args.output)
    if output.exists():
        raise ValueError('evidence_exists')
    app, qa = runner.env(Path(args.app_env)), runner.env(Path(args.qa_env))
    base = app['COELO_SUPABASE_URL'].rstrip('/')
    assert base == 'https://evvbomzejfijozbtgvpt.supabase.co'
    headers = {'apikey': app['COELO_SUPABASE_PUBLISHABLE_KEY'], 'Content-Type': 'application/json'}
    fixture = json.loads((SOURCE / 'assessments-api-execution-20260912.json').read_text())['executor']
    payload = fixture['plan']['save_configuration']['payload']
    unknown = '00000000-0000-4000-8000-000000000000'
    config = ('superadmin_assessment_configuration_read', {'target_activity': payload['activity_id'], 'target_unit': payload['unit_id']})
    book = ('superadmin_assessment_gradebook_read', {'target_gradebook': fixture['gradebook_result']['id']})
    report = {'round': 'E2-R09-20260912-1542', 'coordenacaoRevision': 97,
              'measuredAt': datetime.now(timezone.utc).isoformat(), 'businessMutations': False,
              'realCrossTenantSession': False, 'checks': []}

    def check(step, ok, **safe):
        report['checks'].append({'step': step, 'pass': bool(ok), **safe})
        print(json.dumps(report['checks'][-1]), flush=True)
        if not ok:
            raise AssertionError(step)

    def rpc(name, params):
        return runner.call(base, headers, '/rest/v1/rpc/' + name, params)

    authenticated = False
    try:
        for name, params in (config, book):
            http, body = rpc(name, params)
            check('anon_' + name, denied(http, body), http=http)
        http, session = runner.call(base, headers, '/auth/v1/token?grant_type=password',
                                   {'email': qa['QA_EMAIL'], 'password': qa['QA_PASSWORD']})
        authenticated = http == 200 and isinstance(session, dict) and bool(session.get('access_token'))
        if authenticated:
            headers['Authorization'] = 'Bearer ' + session['access_token']
        check('auth', authenticated, http=http)
        for name, params, expected, aggregate in (
                (*config, fixture['save']['id'], 'configuration'),
                (*book, fixture['gradebook_result']['id'], 'gradebook')):
            http, body = rpc(name, params)
            value = body.get('data') if isinstance(body, dict) and body.get('ok') is True else None
            record = value.get(aggregate) if isinstance(value, dict) else None
            check('authorized_' + aggregate, http == 200 and isinstance(record, dict) and record.get('id') == expected,
                  http=http, studentCount=len(value.get('students', [])) if isinstance(value, dict) and aggregate == 'gradebook' else None)
        for step, name, params in (
                ('unknown_activity', config[0], {'target_activity': unknown, 'target_unit': payload['unit_id']}),
                ('unit_outside_activity', config[0], {'target_activity': payload['activity_id'], 'target_unit': unknown}),
                ('unknown_gradebook', book[0], {'target_gradebook': unknown})):
            http, body = rpc(name, params)
            check(step, hidden(http, body), http=http, dataAbsent=hidden(http, body))
    except Exception as error:
        report['failureType'] = type(error).__name__
    finally:
        if authenticated:
            http, _ = runner.call(base, headers, '/auth/v1/logout?scope=local', {})
            report['checks'].append({'step': 'logout_local', 'pass': http == 204, 'http': http})
        report['pass'] = 'failureType' not in report and all(c['pass'] for c in report['checks'])
        output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    return 0 if report['pass'] else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as error:
        print(json.dumps({'failureType': type(error).__name__}))
        raise SystemExit(1)
