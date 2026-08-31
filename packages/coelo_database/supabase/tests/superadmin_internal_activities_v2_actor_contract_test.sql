begin;
create extension if not exists pgtap with schema extensions;

select plan(26);

select has_column('public','activity_definitions','created_by_actor_kind','definition actor kind');
select has_column('public','activity_unit_links','linked_by_actor_kind','unit link actor kind');
select has_column('public','activity_group_links','linked_by_actor_kind','group link actor kind');
select has_column('public','activity_group_participants','added_by_actor_kind','participant actor kind');
select has_column('public','activity_group_assignments','assigned_by_actor_kind','group assignment actor kind');
select has_column('public','activity_admin_assignments','assigned_by_actor_kind','admin assignment actor kind');
select has_column('public','activity_assignment_capability_actions','changed_by_actor_kind','assignment action actor kind');
select has_column('public','activity_capability_policies','changed_by_actor_kind','policy actor kind');
select has_column('public','activity_group_capability_settings','changed_by_actor_kind','group setting actor kind');
select ok(not exists(select 1 from information_schema.columns
  where table_schema='public' and column_name like '%internal_identity_id'),
  'public Activity tables do not expose internal identity ids');
select results_eq($$select count(*)::bigint from information_schema.columns
 where table_schema='public' and column_name like '%_by_actor_kind'
   and is_generated='ALWAYS'$$, array[9::bigint], 'nine generated actor kinds');
select results_eq($$select count(*)::bigint from information_schema.columns
 where table_schema='public' and (table_name,column_name) in
 (('activity_definitions','created_by_person_id'),
  ('activity_unit_links','linked_by_person_id'),
  ('activity_group_links','linked_by_person_id'),
  ('activity_group_participants','added_by_person_id'),
  ('activity_group_assignments','assigned_by_person_id'),
  ('activity_admin_assignments','assigned_by_person_id'),
  ('activity_assignment_capability_actions','changed_by_person_id'),
  ('activity_capability_policies','changed_by_person_id'),
  ('activity_group_capability_settings','changed_by_person_id'))
   and is_nullable='YES'$$,
 array[9::bigint], 'nine actor fields accept the internal path');
select has_function('app_private','guard_activity_v2_actor_provenance',array[]::text[]);
select has_function('app_private','require_activity_v2_internal_marker',array[]::text[]);
select results_eq($$select count(*)::bigint from pg_trigger t join pg_proc p on p.oid=t.tgfoid
 where not t.tgisinternal and p.proname='guard_activity_v2_actor_provenance'$$,
 array[9::bigint], 'guard attached to every dual actor table');
select has_index('public','activity_assignment_capability_actions',
 'activity_assignment_capability_actions_changed_by_person_idx','assignment action people index');
select has_index('public','activity_admin_assignments',
 'activity_admin_assignments_assigned_by_person_idx','admin assignment people index');
select function_owner_is('app_private','guard_activity_v2_actor_provenance',array[]::text[],'postgres');
select function_owner_is('app_private','require_activity_v2_internal_marker',array[]::text[],'postgres');
select ok(pg_get_functiondef('app_private.guard_activity_v2_actor_provenance()'::regprocedure)
 like '%require_activity_v2_internal_marker%', 'null person requires validated marker');
select ok(pg_get_functiondef('app_private.require_activity_v2_internal_marker()'::regprocedure)
 like '%auth.sessions%', 'marker revalidates the live Auth session');
select ok(not has_function_privilege('authenticated',
 'app_private.guard_activity_v2_actor_provenance()','EXECUTE'),'guard is private');
select ok(not has_function_privilege('service_role',
 'app_private.require_activity_v2_internal_marker()','EXECUTE'),'marker helper is private');
select ok(pg_get_functiondef('app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
 like '%current_person_id%' and pg_get_functiondef(
 'app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
 not like '%superadmin_internal%', 'legacy aggregate stays people-based');
select ok(not exists(select 1 from public.activity_group_assignments
 where assignment_role='activity_admin' and created_at >= transaction_timestamp()),
 'v2 never creates group-scoped activity admins');
select ok(not exists(select 1 from public.activity_definitions
 where created_by_person_id is not null and created_by_actor_kind<>'person'),
 'legacy rows derive person provenance');

-- These behavioral fixtures deliberately use no additional TAP assertions: the
-- fixed 26-assertion public contract above remains exact, while each DO block
-- raises if the trigger stops enforcing its actor branch. The surrounding
-- rollback restores the private helper replacements and all synthetic rows.
insert into public.people(id,person_type,first_name,last_name,display_name)
values
 ('7a100000-0000-4000-8000-000000000001','adult','Actor','People','Actor People'),
 ('7a100000-0000-4000-8000-000000000002','adult','Other','People','Other People');
insert into public.institutions(id,public_name,slug)
values ('7a100000-0000-4000-8000-000000000003','Actor contract','actor-contract-v2');

create or replace function app_private.current_person_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select current_setting('test.activity_v2_person_id',true)::uuid
$$;
select set_config('test.activity_v2_person_id','7a100000-0000-4000-8000-000000000001',true);

-- A people writer remains valid when its row actor is the resolved person.
insert into public.activity_definitions(
 id,institution_id,name,handle_stem,origin_scope_kind,created_by_person_id
) values (
 '7a100000-0000-4000-8000-000000000010',
 '7a100000-0000-4000-8000-000000000003','People provenance','people-provenance','institution',
 '7a100000-0000-4000-8000-000000000001'
);

-- An internal command reaches the NULL branch only through the private marker.
create or replace function app_private.require_activity_v2_internal_marker()
returns void language plpgsql security definer set search_path = '' as $$ begin end $$;
insert into public.activity_definitions(
 id,institution_id,name,handle_stem,origin_scope_kind,created_by_person_id
) values (
 '7a100000-0000-4000-8000-000000000011',
 '7a100000-0000-4000-8000-000000000003','Internal provenance','internal-provenance','institution',null
);

-- A forged NULL path and an impersonated people actor must both fail closed.
create or replace function app_private.require_activity_v2_internal_marker()
returns void language plpgsql security definer set search_path = '' as $$
begin
  raise insufficient_privilege using message='forged activity internal marker';
end $$;
do $$
begin
  begin
    insert into public.activity_definitions(
      id,institution_id,name,handle_stem,origin_scope_kind,created_by_person_id
    ) values (
      '7a100000-0000-4000-8000-000000000012',
      '7a100000-0000-4000-8000-000000000003','Forged null actor','forged-null-actor','institution',null
    );
    raise exception 'forged NULL activity actor was accepted';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.activity_definitions(
      id,institution_id,name,handle_stem,origin_scope_kind,created_by_person_id
    ) values (
      '7a100000-0000-4000-8000-000000000013',
      '7a100000-0000-4000-8000-000000000003','Mismatched people actor','mismatched-people-actor','institution',
      '7a100000-0000-4000-8000-000000000002'
    );
    raise exception 'mismatched activity person actor was accepted';
  exception when insufficient_privilege then null;
  end;
end $$;

select * from finish();
rollback;
