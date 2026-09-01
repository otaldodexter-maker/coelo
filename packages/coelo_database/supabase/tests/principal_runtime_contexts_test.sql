begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

select has_function(
  'public', 'list_my_principal_contexts', array[]::text[],
  'authenticated Principal context resolver exists without client scope parameters'
);
select ok(
  has_function_privilege(
    'authenticated', 'public.list_my_principal_contexts()', 'execute'
  ),
  'authenticated callers can resolve their own contexts'
);
select ok(
  not has_function_privilege('anon', 'public.list_my_principal_contexts()', 'execute'),
  'anonymous callers cannot execute the context resolver'
);
select ok(
  not has_function_privilege('public', 'public.list_my_principal_contexts()', 'execute'),
  'PUBLIC has no implicit execute grant'
);
select ok(
  pg_get_function_result('public.list_my_principal_contexts()'::regprocedure) =
    'TABLE(membership_id uuid, person_id uuid, institution_id uuid, institution_name text, role_code text, scope_kind text, unit_id uuid, unit_name text, group_id uuid, group_name text)',
  'resolver exposes only the minimum runtime-context projection'
);
select ok(
  position('auth.uid()' in pg_get_functiondef(
    'public.list_my_principal_contexts()'::regprocedure
  )) > 0,
  'resolver derives identity from the authenticated JWT'
);

insert into auth.users(id,aud,role,email,created_at,updated_at) values
  ('a1000000-0000-4000-8000-000000000001','authenticated','authenticated','principal-a@test.invalid',now(),now()),
  ('b1000000-0000-4000-8000-000000000001','authenticated','authenticated','principal-b@test.invalid',now(),now());
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('a2000000-0000-4000-8000-000000000001','adult','Principal','A','Principal A','active'),
  ('b2000000-0000-4000-8000-000000000001','adult','Principal','B','Principal B','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
  ('a2000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','active'),
  ('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000001','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('a3000000-0000-4000-8000-000000000001','Instituição A','Instituição A','principal-a','active'),
  ('b3000000-0000-4000-8000-000000000001','Instituição B','Instituição B','principal-b','active');
insert into public.units(
  id,institution_id,name,slug,unit_type_id,unit_type_other_description,handle,status
) values (
  'a4000000-0000-4000-8000-000000000001',
  'a3000000-0000-4000-8000-000000000001',
  'Unidade A','unidade-a',
  (select id from public.unit_types where status='active' order by id limit 1),
  'Unidade de teste','principal.a.unit','active'
);
insert into public.groups(id,institution_id,unit_id,name,group_type,status) values (
  'a5000000-0000-4000-8000-000000000001',
  'a3000000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000001',
  'Turma A','class','active'
);
insert into public.institution_memberships(
  id,person_id,institution_id,role_code,status,scope_kind,scope_unit_id,scope_group_id,revoked_at
) values
  ('a6000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','guardian','active','group','a4000000-0000-4000-8000-000000000001','a5000000-0000-4000-8000-000000000001',null),
  ('a6000000-0000-4000-8000-000000000002','a2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','guardian','inactive','institution',null,null,now()),
  ('b6000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001','b3000000-0000-4000-8000-000000000001','guardian','active','institution',null,null,null);

set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
select throws_ok(
  $$select public.list_my_principal_contexts()$$,
  '42501','authentication_required',
  'resolver rejects requests without an authenticated actor'
);

select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
select set_config(
  'request.jwt.claims',
  '{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
select is(
  (select count(*)::integer from public.list_my_principal_contexts()),
  1,
  'actor A receives only one active coherent context'
);
select is(
  (select institution_id from public.list_my_principal_contexts()),
  'a3000000-0000-4000-8000-000000000001'::uuid,
  'actor A cannot discover tenant B by an inactive membership'
);
select is(
  (select unit_id from public.list_my_principal_contexts()),
  'a4000000-0000-4000-8000-000000000001'::uuid,
  'unit scope is derived from the active membership hierarchy'
);
select is(
  (select group_id from public.list_my_principal_contexts()),
  'a5000000-0000-4000-8000-000000000001'::uuid,
  'group scope is derived from the active membership hierarchy'
);

select set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
select set_config(
  'request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
select is(
  (select institution_id from public.list_my_principal_contexts()),
  'b3000000-0000-4000-8000-000000000001'::uuid,
  'actor B receives only tenant B'
);
select is(
  (select count(*)::integer from public.list_my_principal_contexts()
    where institution_id='a3000000-0000-4000-8000-000000000001'),
  0,
  'actor B cannot enumerate tenant A'
);
reset role;

select * from finish();
rollback;
