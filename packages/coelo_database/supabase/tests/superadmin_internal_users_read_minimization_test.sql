-- Separate nominal RED package; does not modify the Users45 fixture.
-- Requires Auth foundation + MVP policy + 20260901210000; Eng1-only replay.
begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data) values
  ('e1000000-0000-4000-8000-000000000001','authenticated','authenticated',
   'read-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('e2000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000001',
   now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
  ('e3000000-0000-4000-8000-000000000001'),
  ('e3000000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
  ('e4000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001',
   'e1000000-0000-4000-8000-000000000001');
-- The second identity intentionally has a profile and membership but no
-- auth-link: it is not an invented invitation or a global-person backfill.
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind) values
  ('e5000000-0000-4000-8000-000000000001','e3000000-0000-4000-8000-000000000001',
   (select id from public.platform_roles where code='owner'),'platform'),
  ('e5000000-0000-4000-8000-000000000002','e3000000-0000-4000-8000-000000000002',
   (select id from public.platform_roles where code='operations'),'platform');
insert into app_private.superadmin_internal_profiles(
  internal_identity_id,first_name,last_name,cpf,professional_email,job_title) values
  ('e3000000-0000-4000-8000-000000000001','Owner','Sintético','52998224725','read-owner@invalid.test','Owner'),
  ('e3000000-0000-4000-8000-000000000002','Parcial','Sintético','11144477735','partial@invalid.test','Parcial');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','e1000000-0000-4000-8000-000000000001',
  'session_id','e2000000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.internal_users_read_payload',
  public.superadmin_internal_users_list(null,null,null,null,1,11)::text,true);
select set_config('test.internal_users_read_actor',current_user,true);
reset role;
select ok(
  current_setting('test.internal_users_read_actor')='authenticated'
  and current_setting('test.internal_users_read_payload')::jsonb ? 'items'
  and not (current_setting('test.internal_users_read_payload')::jsonb ? 'error'),
  'nominal internal Owner is authorized before testing payload minimization');
select ok(
  not exists(select 1 from jsonb_array_elements(
    current_setting('test.internal_users_read_payload')::jsonb->'items') item
    where item='null'::jsonb)
  and (current_setting('test.internal_users_read_payload')::jsonb->>'total')::integer=1
  and jsonb_array_length(current_setting('test.internal_users_read_payload')::jsonb->'items')=1,
  'list items, total and pagination exclude incomplete identities without auth-link');
select ok(
  position('read-owner@invalid.test' in current_setting('test.internal_users_read_payload'))=0
  and position('r***@invalid.test' in current_setting('test.internal_users_read_payload'))>0,
  'list masks professional email in every payload branch, including invitation');
select * from finish();
rollback;
