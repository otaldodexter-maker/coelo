begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create temporary table expected_platform_notice_tables(
  schema_name text not null,
  table_name text not null,
  policy_name text not null,
  primary key(schema_name,table_name)
) on commit drop;
insert into expected_platform_notice_tables values
  ('public','platform_notices','platform_notices_platform_read'),
  ('public','notice_rules','notice_rules_platform_read'),
  ('public','notice_media','notice_media_platform_read'),
  ('public','notice_receipts','notice_receipts_platform_read'),
  ('analytics','notice_events','notice_events_dashboard_read');

select ok(to_regclass(format('%I.%I',schema_name,table_name)) is not null,
  'platform Notice table exists: '||schema_name||'.'||table_name)
from expected_platform_notice_tables;

select ok(
  (select relation_record.relowner='postgres'::regrole
      and relation_record.relrowsecurity
      and relation_record.relforcerowsecurity
   from pg_class relation_record
   where relation_record.oid=to_regclass(format('%I.%I',schema_name,table_name))),
  'platform Notice table is postgres-owned with forced RLS: '||schema_name||'.'||table_name)
from expected_platform_notice_tables;

with relations as(
  select schema_name,table_name,
    to_regclass(format('%I.%I',schema_name,table_name))::oid relation_oid
  from expected_platform_notice_tables
)
select ok(not exists(
    select 1
    from pg_class relation_record,
      lateral aclexplode(coalesce(relation_record.relacl,
        acldefault('r',relation_record.relowner))) acl
    where relation_record.oid=relations.relation_oid
      and acl.grantee in (
        0,
        'anon'::regrole::oid,
        'authenticated'::regrole::oid
      )
  ),'PUBLIC/anon/authenticated have no table privilege: '||schema_name||'.'||table_name)
from relations;

select ok(
  not exists(
    select 1 from unnest(array[
      'SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'
    ]) privilege_name
    where not has_table_privilege('service_role',
      format('%I.%I',schema_name,table_name),privilege_name)
  ),
  'service_role compatibility is preserved: '||schema_name||'.'||table_name)
from expected_platform_notice_tables;

select ok(
  not exists(
    select 1
    from unnest(array['anon','authenticated']) role_name,
      unnest(array[
        'SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'
      ]) privilege_name
    where has_table_privilege(role_name,
      format('%I.%I',schema_name,table_name),privilege_name)
  ),
  'client roles have no effective table privilege: '||schema_name||'.'||table_name)
from expected_platform_notice_tables;

select ok(exists(
    select 1 from pg_policies policy_record
    where policy_record.schemaname=schema_name
      and policy_record.tablename=table_name
      and policy_record.policyname=policy_name
      and policy_record.cmd='SELECT'
      and policy_record.permissive='PERMISSIVE'
      and policy_record.roles='{authenticated}'::name[]
  ),'existing read policy is preserved but dormant: '||policy_name)
from expected_platform_notice_tables;

select is(
  (select array_agg(enum_record.enumlabel::text order by enum_record.enumsortorder)
   from pg_enum enum_record
   where enum_record.enumtypid='public.notice_status'::regtype),
  array['draft','scheduled','published','expired','archived']::text[],
  'the ACL hardening does not activate or expand the Notice status contract');

set local role anon;
select throws_ok('select * from public.platform_notices','42501',null,
  'anon cannot read platform Notices directly');
select throws_ok('truncate table public.platform_notices','42501',null,
  'anon cannot truncate platform Notices');
reset role;

set local role authenticated;
select throws_ok('select * from public.notice_receipts','42501',null,
  'authenticated cannot read Notice receipts directly');
select throws_ok('truncate table public.notice_receipts','42501',null,
  'authenticated cannot truncate Notice receipts');
reset role;

select * from finish();
rollback;
