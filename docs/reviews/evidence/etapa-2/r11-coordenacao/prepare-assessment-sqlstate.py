"""Reproduce the original failure inside a rolled-back local fixture only."""
from pathlib import Path

root = Path(__file__).resolve().parents[5]
source = (root / 'packages/coelo_database/migrations/20260910180350_superadmin_assessments_internal_v2.sql').read_text(encoding='utf-8-sig')
start = source.index('create or replace function app_private.assessment_v2_save_configuration(')
end = source.index('\nend $$;', start) + len('\nend $$;')
original = source[start:end]
fixture = (root / 'packages/coelo_database/candidatos/r11-estrutura/assessment-update-isolation-test.sql').read_text(encoding='utf-8')
fixture = fixture[:fixture.index('create temporary table r11_updated')]
fixture = fixture.replace('select plan(8);', 'select plan(4);')
probe = """
create function pg_temp.r11_original_error() returns text language plpgsql as $$
declare v_state text; v_constraint text;
begin
  perform app_private.assessment_v2_save_configuration(gen_random_uuid(),
    (select (body#>>'{data,id}')::uuid from r11_draft),1,
    (select value from r11_payload));
  return 'UNEXPECTED_SUCCESS';
exception when others then
  get stacked diagnostics v_state = returned_sqlstate, v_constraint = constraint_name;
  return v_state || ':' || coalesce(v_constraint,'');
end $$;
select alike(pg_temp.r11_original_error(), '23503:%', 'original update fails on a foreign key of another configuration');
select pg_temp.r11_original_error() as sanitized_local_sqlstate;
select * from finish(); rollback;
"""
target = Path(__file__).with_name('assessment-sqlstate-local.sql')
target.write_text(fixture + '\n' + original + '\n' + probe, encoding='utf-8')
print(target.relative_to(root))
