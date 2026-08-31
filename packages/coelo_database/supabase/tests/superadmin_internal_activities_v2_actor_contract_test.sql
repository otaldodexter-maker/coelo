begin;
create extension if not exists pgtap with schema extensions;

select plan(31);

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

insert into public.people(id,person_type,first_name,last_name,display_name)
values
 ('7a100000-0000-4000-8000-000000000001','adult','Actor','People','Actor People'),
 ('7a100000-0000-4000-8000-000000000002','adult','Other','People','Other People');
insert into public.institutions(id,public_name,slug)
values ('7a100000-0000-4000-8000-000000000003','Actor contract','actor-contract-v2');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data)
values
 ('7a100000-0000-4000-8000-000000000021','authenticated','authenticated','actor-a@invalid.test',now(),now(),now(),'{}','{}'),
 ('7a100000-0000-4000-8000-000000000022','authenticated','authenticated','actor-b@invalid.test',now(),now(),now(),'{}','{}'),
 ('7a100000-0000-4000-8000-000000000023','authenticated','authenticated','internal@invalid.test',now(),now(),now(),'{}','{}');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('7a100000-0000-4000-8000-000000000001','7a100000-0000-4000-8000-000000000021','active'),
 ('7a100000-0000-4000-8000-000000000002','7a100000-0000-4000-8000-000000000022','active');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values('7a100000-0000-4000-8000-000000000024','7a100000-0000-4000-8000-000000000023',now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id)
values('7a100000-0000-4000-8000-000000000025');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
values('7a100000-0000-4000-8000-000000000026','7a100000-0000-4000-8000-000000000025','7a100000-0000-4000-8000-000000000023');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '7a100000-0000-4000-8000-000000000027','7a100000-0000-4000-8000-000000000025',id,'platform'
from public.platform_roles where code='owner';

select set_config('request.jwt.claims',jsonb_build_object('sub','7a100000-0000-4000-8000-000000000021','aal','aal2','role','authenticated')::text,true);
insert into public.activity_definitions(
 id,institution_id,name,handle_stem,origin_scope_kind,created_by_person_id
) values (
 '7a100000-0000-4000-8000-000000000010',
 '7a100000-0000-4000-8000-000000000003','People provenance','people-provenance','institution',
 '7a100000-0000-4000-8000-000000000001'
);

select set_config('request.jwt.claims',jsonb_build_object('sub','7a100000-0000-4000-8000-000000000023','session_id','7a100000-0000-4000-8000-000000000024','aal','aal2','role','authenticated')::text,true);
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','7a100000-0000-4000-8000-000000000025','internal_auth_link_id','7a100000-0000-4000-8000-000000000026',
 'internal_membership_id','7a100000-0000-4000-8000-000000000027','auth_user_id','7a100000-0000-4000-8000-000000000023',
 'session_id','7a100000-0000-4000-8000-000000000024','permission_code','activities.manage','action_code','manage')::text,true);
select lives_ok($$insert into public.activity_definitions(id,institution_id,name,handle_stem,origin_scope_kind,created_by_person_id)
 values('7a100000-0000-4000-8000-000000000011','7a100000-0000-4000-8000-000000000003','Internal provenance','internal-provenance','institution',null)$$,
 'real internal marker accepts an allowlisted action');
select lives_ok($$update public.activity_definitions set description='internal edit' where id='7a100000-0000-4000-8000-000000000010'$$,
 'internal actor updates legacy people provenance without rewriting it');
select set_config('request.jwt.claims',jsonb_build_object('sub','7a100000-0000-4000-8000-000000000022','aal','aal2','role','authenticated')::text,true);
select lives_ok($$update public.activity_definitions set description='admin edit' where id='7a100000-0000-4000-8000-000000000010'$$,
 'different Admin updates a row without reattributing history');
select throws_ok($$update public.activity_definitions set created_by_person_id='7a100000-0000-4000-8000-000000000002' where id='7a100000-0000-4000-8000-000000000010'$$,
 '42501','activity actor provenance immutable','rewriting historical authorship is denied');
select set_config('request.jwt.claims',jsonb_build_object('sub','7a100000-0000-4000-8000-000000000023','session_id','7a100000-0000-4000-8000-000000000024','aal','aal2','role','authenticated')::text,true);
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','7a100000-0000-4000-8000-000000000025','internal_auth_link_id','7a100000-0000-4000-8000-000000000026',
 'internal_membership_id','7a100000-0000-4000-8000-000000000027','auth_user_id','7a100000-0000-4000-8000-000000000023',
 'session_id','7a100000-0000-4000-8000-000000000024','permission_code','platform.read','action_code','manage')::text,true);
select throws_ok($$insert into public.activity_definitions(id,institution_id,name,handle_stem,origin_scope_kind,created_by_person_id)
 values('7a100000-0000-4000-8000-000000000012','7a100000-0000-4000-8000-000000000003','Forged marker','forged-marker','institution',null)$$,
 '42501','activity internal marker denied','forged marker permission is denied');

select * from finish();
rollback;
