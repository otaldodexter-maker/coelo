"""Prepare the closed disposable Safety replay; never connect to a database."""
import hashlib
import json
import re
import shutil
from pathlib import Path

from pglast import parse_sql

out = Path(__file__).resolve().parent
root = next(parent for parent in out.parents if (parent / 'AGENTS.md').is_file())
db = root / 'packages/coelo_database'
candidate = db / 'migrations/20260909193000_d04_child_safety_internal_reads.sql'
manifest_file = db / 'replay/foundation-migrations.sha256'

def normalized_hash(path):
    return hashlib.sha256(path.read_text(encoding='utf-8-sig').replace('\r\n', '\n').replace('\r', '\n').replace('\n', '\r\n').encode()).hexdigest()

assert normalized_hash(manifest_file) == '4279e67c9651f4049329591b6e8aad82e3a9052506c1a4e16ba8bbb693249d59'
base = []
for line in manifest_file.read_text().splitlines():
    if not line or line.startswith('#'):
        continue
    name, digest = line.split('|')
    if name[:14] <= '20260812001975' or name[:14] in ('20260827214000', '20260827233000', '20260901124500', '20260901200206'):
        path = db / 'migrations' / name
        assert normalized_hash(path) == digest, name
        base.append(path)
assert len(base) == 45
historical = [db / 'migrations' / name for name in (
    '20260812002000_child_safety_schema.sql',
    '20260812002100_child_safety_read_models.sql',
    '20260812002200_child_safety_security_closure.sql',
    '20260825193116_final_review_child_safety_lint_hardening.sql',
)]
preflights = [db / 'replay' / name for name in (
    '20260811151253_assert_function_execute_preflight.sql',
    '20260811215452_access_profile_labels_replay_bridge.sql',
)]
bridge = db / 'replay/profiles/ChildDirectoryEnvelope/20260908051499_child_directory_error_envelope_bridge.sql'
assert normalized_hash(bridge) == '6f9342ccad9ce145158e1667a84c5bd58e4577af022204194280b4d8cfaad17a'
sources = sorted(base + historical + preflights + [bridge, candidate], key=lambda p: p.name)
assert len(sources) == 53 and len({p.name[:14] for p in sources}) == 53
fixture = out / 'fixture'
fixture.mkdir(exist_ok=True)
for source in sources:
    shutil.copyfile(source, fixture / source.name)

# Exercise the actual migration DO block. The negative control restores the
# exact historical envelope within a rollback-only pgTAP transaction.
text = candidate.read_text(encoding='utf-8-sig')
preflight = re.search(r'do \$preflight\$.*?\$preflight\$;', text, re.S).group()
auth = (db / 'migrations/20260827233000_superadmin_internal_auth_context.sql').read_text(encoding='utf-8-sig')
old_envelope = re.search(r'create function app_private.superadmin_internal_error_envelope\(.*?\$\$;', auth, re.S).group().replace('create function ', 'create or replace function ', 1)
phase = 'after' if 'D04 dependency requires SAI_INVALID_ARGUMENT envelope' in preflight else 'before'
test = f"""-- LOCAL ONLY. Generated from actual Safety candidate preflight; rollback restores envelope.
begin;
create extension if not exists pgtap with schema extensions;
select plan(2);
select lives_ok($d04${preflight}$d04$, 'reviewed envelope satisfies candidate preflight');
{old_envelope}
select throws_ok($d04${preflight}$d04$, 'P0001',
  'D04 dependency requires SAI_INVALID_ARGUMENT envelope',
  'Auth45 envelope is rejected before installing Safety wrappers');
select * from finish();
rollback;
"""
test_path = out / f'preflight-{phase}-test.sql'
test_path.write_text(test, encoding='utf-8')
if phase == 'after':
    (db / 'supabase/tests/ap_safety_internal_preflight_test.sql').write_text(
        test, encoding='utf-8', newline='\n')
checks = [candidate, db / 'supabase/tests/d04_child_safety_internal_reads_test.sql', db / 'supabase/tests/child_safety_production_test.sql', test_path]
report = {
    'status': 'prepared-not-executed-local-only',
    'base': 'Auth45', 'counts': {'canonical': 50, 'preflight': 2, 'bridge': 1, 'total': 53},
    'phase': phase,
    'ordered_sources': [{'path': str(p.relative_to(root)).replace('\\', '/'), 'sha256_crlf_utf8': normalized_hash(p), 'sha256_bytes': hashlib.sha256(p.read_bytes()).hexdigest()} for p in sources],
    'static_parse': [{'path': str(p.relative_to(root)).replace('\\', '/'), 'statements': len(parse_sql(p.read_text(encoding='utf-8-sig'))), 'sha256_bytes': hashlib.sha256(p.read_bytes()).hexdigest()} for p in checks],
    'runtime': {'preflight': {'P': 0, 'F': 0, 'B': 0, 'S': 0, 'U': 2}, 'safety_internal': {'P': 0, 'F': 0, 'B': 0, 'S': 0, 'U': 43}, 'safety_legacy': {'P': 0, 'F': 0, 'B': 0, 'S': 0, 'U': 63}},
}
(out / f'manifest-{phase}.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'phase': phase, 'fixture_count': len(sources), 'parse': report['static_parse']}, indent=2))
