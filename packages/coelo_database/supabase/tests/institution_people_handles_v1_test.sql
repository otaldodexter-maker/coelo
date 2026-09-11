-- Decisao 16: @ das pessoas da instituicao no detalhe (representatives/administrators).
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into public.institutions(id,public_name,slug,status,timezone,locale) values
  ('9f090000-0000-4000-8000-000000000001','Inst handles','handles-a','draft','UTC','pt-BR');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
  ('9f090000-0000-4000-8000-000000000011','authenticated','authenticated','handles-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('9f090000-0000-4000-8000-000000000021','9f090000-0000-4000-8000-000000000011',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values ('9f090000-0000-4000-8000-000000000031');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
  ('9f090000-0000-4000-8000-000000000041','9f090000-0000-4000-8000-000000000031','9f090000-0000-4000-8000-000000000011');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '9f090000-0000-4000-8000-000000000051','9f090000-0000-4000-8000-000000000031',r.id,'platform' from public.platform_roles r where r.code='owner';
create temporary table h(label text primary key, body jsonb not null);
grant select,insert on h to authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub','9f090000-0000-4000-8000-000000000011',
  'session_id','9f090000-0000-4000-8000-000000000021','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into h values('write',public.superadmin_institution_contacts_edit_v1('9f090000-0000-4000-8000-000000000061','9f090000-0000-4000-8000-000000000001',1,
  $j${"representatives":[{"first_name":"Maria","last_name":"Silva","date_of_birth":"1985-02-02","is_primary":true}],
      "administrators":[{"first_name":"Joao","last_name":"Souza","level":"admin_master"}]}$j$));
insert into h values('detail',public.superadmin_institution_detail_v2('9f090000-0000-4000-8000-000000000001'));
reset role;
select is((select body->>'ok' from h where label='write'),'true','pessoas criadas');
select ok((select r->>'handle' ~ '^[a-z0-9._-]+$' from h, jsonb_array_elements(body->'data'->'representatives') r where label='detail' limit 1),
  'representante nasce com @ e o detalhe devolve');
select ok((select a->>'handle' ~ '^[a-z0-9._-]+$' from h, jsonb_array_elements(body->'data'->'administrators') a where label='detail' limit 1),
  'administrador nasce com @ e o detalhe devolve');
select ok((select a->>'handle' = (select ph.normalized_handle from public.person_handles ph where ph.person_id=(a->>'person_id')::uuid and ph.status='active')
  from h, jsonb_array_elements(body->'data'->'administrators') a where label='detail' limit 1),'o @ devolvido e o ativo em person_handles');

select * from finish();
rollback;
