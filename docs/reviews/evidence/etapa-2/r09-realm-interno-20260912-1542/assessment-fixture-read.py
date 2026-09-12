"""Read-only diagnosis of the retained assessment's participant chain."""
import argparse
import importlib.util
import json
from datetime import datetime, timezone
from pathlib import Path

spec = importlib.util.spec_from_file_location('probe', Path(__file__).with_name('assessment-read-probe.py'))
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


def main():
    parser = argparse.ArgumentParser()
    for key in ('qa-env', 'app-env', 'output'):
        parser.add_argument('--' + key, required=True)
    args = parser.parse_args()
    output = Path(args.output)
    assert not output.exists()
    app, qa = probe.runner.env(Path(args.app_env)), probe.runner.env(Path(args.qa_env))
    base = app['COELO_SUPABASE_URL'].rstrip('/')
    assert base == 'https://evvbomzejfijozbtgvpt.supabase.co'
    headers = {'apikey': app['COELO_SUPABASE_PUBLISHABLE_KEY'], 'Content-Type': 'application/json'}
    fixture = json.loads((probe.SOURCE / 'assessments-api-execution-20260912.json').read_text())['executor']
    payload = fixture['plan']['save_configuration']['payload']
    report = {'round': 'E2-R09-20260912-1542', 'measuredAt': datetime.now(timezone.utc).isoformat(),
              'businessMutations': False, 'checks': []}
    authenticated = False

    def rpc(name, params):
        http, body = probe.runner.call(base, headers, '/rest/v1/rpc/' + name, params)
        ok = http == 200 and isinstance(body, dict) and body.get('ok') is True and isinstance(body.get('data'), dict)
        error_code = body.get('error', {}).get('code') if isinstance(body, dict) and isinstance(body.get('error'), dict) else None
        report['checks'].append({'step': name, 'pass': ok, 'http': http, 'errorCode': error_code})
        assert ok
        return body['data']

    try:
        http, session = probe.runner.call(base, headers, '/auth/v1/token?grant_type=password',
                                         {'email': qa['QA_EMAIL'], 'password': qa['QA_PASSWORD']})
        authenticated = http == 200 and isinstance(session, dict) and bool(session.get('access_token'))
        if authenticated:
            headers['Authorization'] = 'Bearer ' + session['access_token']
        report['checks'].append({'step': 'auth', 'pass': authenticated, 'http': http})
        assert authenticated
        context = rpc('superadmin_assessment_context_options', {})
        assignments = [a for a in context['assignments'] if a['activity_group_link_id'] == fixture['assignment_id']]
        assert len(assignments) == 1
        target = assignments[0]
        assert target['activity_id'] == payload['activity_id'] and target['institution_id'] == payload['institution_id']
        detail = rpc('superadmin_activity_detail_v2', {'p_activity_id': payload['activity_id'], 'p_sections': ['participants']})
        report['retainedActivityParticipantCount'] = len(detail['participants'])
        report['retainedGroupParticipantCount'] = len([p for p in detail['participants'] if p['group_id'] == target['group_id']])
        options = rpc('superadmin_activity_form_options_v2', {'p_institution_id': payload['institution_id'], 'p_sections': ['participants'], 'p_limit': 100})
        rows = options['participants']
        assert isinstance(rows, list)
        report['eligibleOptionCount'] = len(rows)
        report['eligibleRetainedGroupOptionCount'] = len([r for r in rows if r['group_id'] == target['group_id']])
        report['limit'] = 100
        report['mayBeTruncated'] = len(rows) >= 100
    except Exception as error:
        report['failureType'] = type(error).__name__
    finally:
        if authenticated:
            http, _ = probe.runner.call(base, headers, '/auth/v1/logout?scope=local', {})
            report['checks'].append({'step': 'logout_local', 'pass': http == 204, 'http': http})
        report['pass'] = 'failureType' not in report and all(c['pass'] for c in report['checks'])
        output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(report))
    return 0 if report['pass'] else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as error:
        print(json.dumps({'failureType': type(error).__name__}))
        raise SystemExit(1)
