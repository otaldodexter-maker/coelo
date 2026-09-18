"""Generate a local late-abort proof from the exact candidate; no DB access."""
from pathlib import Path
import hashlib
import json

here = Path(__file__).resolve().parent
root = next(p for p in here.parents if (p / "AGENTS.md").is_file())
payload = (here / "package.sql").read_text(encoding="utf-8")
manifest = json.loads((here / "manifest.json").read_text(encoding="utf-8"))
assert hashlib.sha256(payload.encode()).hexdigest() == manifest["package_sha256"]
# pgTAP throws_ok runs its argument in a subtransaction. Remove only the
# candidate's outer transaction so a late exception rolls back all its work.
assert payload.count("\nbegin;\n") == 1
assert payload.endswith("\ncommit;\n")
body = payload.replace("\nbegin;\n", "\n", 1).removesuffix("commit;\n")
assert "$rollback_candidate$" not in body
fixture = "-- LOCAL ONLY: never run on a remote project.\n"
for table in ("platform_permissions", "institution_permissions"):
    for label in ("module_label", "screen_label", "action_label"):
        fixture += f"alter table public.{table} alter column {label} drop default;\n"
fixture += (here / "remote-cursor-local-fixture.sql").read_text(encoding="utf-8")
test = fixture + """
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);
create temp table models_before_abort as
select p.oid, pg_get_functiondef(p.oid) definition, p.proacl, p.proowner
from pg_proc p where p.oid in (
 'public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)'::regprocedure,
 'app_private.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)'::regprocedure,
 'app_private.require_superadmin_internal_context(text)'::regprocedure);
select throws_ok($rollback_candidate$
""" + body + """
do $late_abort$ begin
 raise exception using errcode='P0001',message='AP_MODELS_LATE_ABORT';
end $late_abort$;
$rollback_candidate$, 'P0001', 'AP_MODELS_LATE_ABORT',
 'late failure reaches end of exact package then rolls it all back');
select ok(to_regclass('app_private.access_profile_model_command_receipts') is null,
 'receipt table creation rolls back');
select ok(to_regprocedure('app_private.access_profile_require_model_action(text,text,boolean)') is null,
 'authorization helper creation rolls back');
select is((select count(*) from public.platform_permissions where code like '%.role_models.%'),
 0::bigint, 'new permissions roll back');
select ok(not exists(select 1 from models_before_abort b left join pg_proc p on p.oid=b.oid
 where p.oid is null or pg_get_functiondef(p.oid) is distinct from b.definition
 or p.proacl is distinct from b.proacl or p.proowner is distinct from b.proowner),
 'legacy bodies signatures defaults owners and grants survive late abort');
select is((select count(*) from pg_attribute a where a.attrelid in (
 'public.platform_permissions'::regclass,'public.institution_permissions'::regclass)
 and a.attname in ('module_label','screen_label','action_label') and a.attnotnull
 and not a.attisdropped and not a.atthasdef),6::bigint,
 'real label constraints survive late abort');
select * from finish();
rollback;
"""
target = root / "packages/coelo_database/supabase/tests/ap_models_nominal_rollback_test.sql"
target.write_text(test, encoding="utf-8", newline="\n")
print(json.dumps({"package_sha256": manifest["package_sha256"],
                  "test_sha256": hashlib.sha256(test.encode()).hexdigest(),
                  "cases": 6, "runtime": "unexecuted"}))
