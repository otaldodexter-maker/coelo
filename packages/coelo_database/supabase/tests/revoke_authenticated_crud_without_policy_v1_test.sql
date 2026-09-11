begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

-- 1. varredura: nenhum grant CRUD de authenticated sem policy em tabela com RLS
create temporary table tab_b as
with grants as (
  select g.table_schema s, g.table_name t, g.privilege_type cmd
  from information_schema.role_table_grants g
  where g.grantee='authenticated' and g.table_schema in ('public','app_private','audit','analytics')
    and g.privilege_type in ('SELECT','INSERT','UPDATE','DELETE')),
policies as (select schemaname s, tablename t, cmd, roles from pg_policies
  where schemaname in ('public','app_private','audit','analytics')),
meta as (select n.nspname s, c.relname t, c.relkind, c.relrowsecurity rls from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname in ('public','app_private','audit','analytics') and c.relkind in ('r','p','v','m'))
select m.s, m.t, m.relkind, m.rls, grants.cmd from grants join meta m on m.s=grants.s and m.t=grants.t
where not exists (select 1 from policies p where p.s=grants.s and p.t=grants.t
  and (p.cmd=grants.cmd or p.cmd='ALL') and ('authenticated'=any(p.roles) or p.roles='{public}'::name[]));

select is((select count(*) from tab_b where relkind in ('r','p') and rls),0::bigint,
  'nenhuma tabela com RLS concede a authenticated um comando sem policy');
select is((select count(*) from tab_b where relkind in ('v','m') and cmd in ('INSERT','UPDATE','DELETE')),0::bigint,
  'views sem INSERT/UPDATE/DELETE para authenticated');
select ok((select bool_and(has_table_privilege('authenticated','public.'||v,'select'))
  from unnest(array['attendance_pending_notices','attendance_summary','institution_directory','person_directory']) v),
  'views security_invoker mantem SELECT');
select ok(not has_table_privilege('authenticated','public.people','insert')
  and not has_table_privilege('authenticated','public.people','update')
  and not has_table_privilege('authenticated','public.people','delete')
  and has_table_privilege('authenticated','public.people','select'),
  'people: escrita revogada, SELECT (policy self_read) mantido');
select ok(not has_table_privilege('authenticated','public.platform_permissions','insert')
  and not has_table_privilege('authenticated','public.messages','delete')
  and not has_table_privilege('authenticated','public.attendance_records','insert')
  and not has_table_privilege('authenticated','public.person_auth_links','update'),
  'catalogo, chat, presenca e vinculo de login sem escrita direta');
select ok(exists (select 1 from pg_policies where schemaname='public' and tablename='person_auth_links'
  and policyname='person_auth_links_self_read' and cmd='SELECT'),
  'person_auth_links tem policy self_read');
select is((select count(*) from information_schema.role_table_grants where grantee in ('anon','PUBLIC')
  and table_schema in ('public','app_private','audit','analytics')),0::bigint,'anon/PUBLIC continuam sem grants');

-- 2. self_read de person_auth_links
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('91000000-0000-4000-8000-000000000001','adult','Eu','Mesmo','Eu Mesmo','active'),
  ('91000000-0000-4000-8000-000000000002','adult','Outra','Pessoa','Outra Pessoa','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
  ('92000000-0000-4000-8000-000000000001','authenticated','authenticated','eu@invalid.test',now(),now(),now(),'{}','{}'),
  ('92000000-0000-4000-8000-000000000002','authenticated','authenticated','outra@invalid.test',now(),now(),now(),'{}','{}');
insert into public.person_auth_links(person_id,auth_user_id,status) values
  ('91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','active'),
  ('91000000-0000-4000-8000-000000000002','92000000-0000-4000-8000-000000000002','active');
select set_config('request.jwt.claims',jsonb_build_object('sub','92000000-0000-4000-8000-000000000001','role','authenticated')::text,true);
set local role authenticated;
select is((select count(*) from public.person_auth_links),1::bigint,'sessao autenticada ve so o proprio vinculo de login');
select is((select person_id from public.person_auth_links),'91000000-0000-4000-8000-000000000001'::uuid,'e o vinculo e o dela');
select throws_like($$insert into public.people(person_type,first_name,last_name,display_name) values ('adult','X','Y','X Y')$$,
  '%permission denied%','escrita direta em people e negada no privilegio');
select throws_like($$delete from public.messages$$,'%permission denied%','delete direto em messages e negado no privilegio');
reset role;

-- 3. RPC security definer continua escrevendo (people, memberships, person_contacts)
insert into public.institutions(id,public_name,slug,status,timezone,locale) values
  ('93000000-0000-4000-8000-000000000001','Inst revoke','revoke-a','draft','UTC','pt-BR');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
  ('93000000-0000-4000-8000-000000000011','authenticated','authenticated','revoke-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('93000000-0000-4000-8000-000000000021','93000000-0000-4000-8000-000000000011',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values ('93000000-0000-4000-8000-000000000031');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
  ('93000000-0000-4000-8000-000000000041','93000000-0000-4000-8000-000000000031','93000000-0000-4000-8000-000000000011');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '93000000-0000-4000-8000-000000000051','93000000-0000-4000-8000-000000000031',r.id,'platform' from public.platform_roles r where r.code='owner';
select set_config('request.jwt.claims',jsonb_build_object('sub','93000000-0000-4000-8000-000000000011',
  'session_id','93000000-0000-4000-8000-000000000021','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select is((public.superadmin_institution_contacts_edit_v1('93000000-0000-4000-8000-000000000061','93000000-0000-4000-8000-000000000001',1,
  $j${"administrators":[{"first_name":"Rpc","last_name":"Escreve","email":"rpc@exemplo.com","level":"admin_master"}]}$j$))->>'ok','true',
  'RPC security definer segue escrevendo em people, institution_memberships e person_contacts');
reset role;

select * from finish();
rollback;
