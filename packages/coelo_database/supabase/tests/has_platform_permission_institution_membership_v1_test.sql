-- Prova do candidato 20260910171000_has_platform_permission_institution_membership_v1
-- (P7, ADR 0034 Decisao 12). Projeto descartavel LOCAL: fixtures sinteticas
-- em transacao com rollback; nenhuma conta real.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

-- Catalogo sintetico: tipo, duas instituicoes (X e Y), dois papeis.
insert into public.institution_types(id,code,name,status)
values('a7000000-0000-4000-8000-000000000001','p7-type','P7 type','active');
insert into public.institutions(id,public_name,slug,institution_type_id) values
('a7000000-0000-4000-8000-000000000011','P7 instituicao X','p7-x','a7000000-0000-4000-8000-000000000001'),
('a7000000-0000-4000-8000-000000000012','P7 instituicao Y','p7-y','a7000000-0000-4000-8000-000000000001');
insert into public.platform_roles(id,code,name,max_scope_kind) values
('a7000000-0000-4000-8000-000000000021','p7_inst_reader','P7 leitor por instituicao','institution'),
('a7000000-0000-4000-8000-000000000022','p7_platform_writer','P7 escritor de plataforma','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect)
select 'a7000000-0000-4000-8000-000000000021',id,'allow'
from public.platform_permissions where code='people.read';
insert into public.platform_role_permissions(role_id,permission_id,effect)
select 'a7000000-0000-4000-8000-000000000022',id,'allow'
from public.platform_permissions where code in('people.read','people.create');

-- Pessoas A (membership por instituicao X), B (suspensa), E (plataforma com
-- deny em people.create) e F (sem membership), cada uma com auth user.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select ('a7000000-0000-4000-8000-0000000000'||n)::uuid,'authenticated','authenticated','p7-'||n||'@invalid.test',now(),now(),now(),'{}','{}'
from unnest(array['31','32','33','34']) n;
insert into public.people(id,person_type,first_name,last_name,display_name)
select ('a7000000-0000-4000-8000-0000000000'||n)::uuid,'adult','P7','Pessoa '||n,'P7 pessoa '||n
from unnest(array['41','42','43','44']) n;
insert into public.person_auth_links(person_id,auth_user_id) values
('a7000000-0000-4000-8000-000000000041','a7000000-0000-4000-8000-000000000031'),
('a7000000-0000-4000-8000-000000000042','a7000000-0000-4000-8000-000000000032'),
('a7000000-0000-4000-8000-000000000043','a7000000-0000-4000-8000-000000000033'),
('a7000000-0000-4000-8000-000000000044','a7000000-0000-4000-8000-000000000034');
insert into public.platform_memberships(id,person_id,role_id,status,scope_kind,scope_institution_id) values
('a7000000-0000-4000-8000-000000000051','a7000000-0000-4000-8000-000000000041','a7000000-0000-4000-8000-000000000021','active','institution','a7000000-0000-4000-8000-000000000011'),
('a7000000-0000-4000-8000-000000000052','a7000000-0000-4000-8000-000000000042','a7000000-0000-4000-8000-000000000022','suspended','platform',null),
('a7000000-0000-4000-8000-000000000053','a7000000-0000-4000-8000-000000000043','a7000000-0000-4000-8000-000000000022','active','platform',null);
insert into public.platform_member_permission_overrides(membership_id,permission_id,effect)
select 'a7000000-0000-4000-8000-000000000053',id,'deny'
from public.platform_permissions where code='people.create';

create function pg_temp.p7_session(auth_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    case when auth_user is null then ''
      else jsonb_build_object('sub',auth_user,'role','authenticated','aal','aal1')::text end, true)
$$;

-- 1-2 deny-by-default
select pg_temp.p7_session(null);
select is(app_private.has_platform_permission('people.read'),false,'sem sessao nega');
select pg_temp.p7_session('a7000000-0000-4000-8000-000000000034');
select is(app_private.has_platform_permission('people.read'),false,'pessoa sem membership nega');

-- 3-8 membership por instituicao (P7) e negativa cross-tenant
select pg_temp.p7_session('a7000000-0000-4000-8000-000000000031');
select is(app_private.has_platform_permission('people.read'),true,
  'membership por instituicao concede a permissao do papel (P7)');
select is(app_private.has_platform_permission('people.read','a7000000-0000-4000-8000-000000000011'),true,
  'membership por instituicao vale para a propria instituicao');
select is(app_private.has_platform_permission('people.read','a7000000-0000-4000-8000-000000000012'),false,
  'membership por instituicao NAO vale para outra instituicao (cross-tenant)');
select is(app_private.has_platform_permission('people.create'),false,
  'permissao nao concedida pelo papel continua negada');
select lives_ok($$select app_private.assert_people_permission('people.read')$$,
  'portao de Pessoas aceita leitura por membership de instituicao');
select throws_ok($$select app_private.assert_people_permission('people.create')$$,'42501',
  'people permission denied','portao de Pessoas continua negando escrita nao concedida');

-- 9 membership suspensa
select pg_temp.p7_session('a7000000-0000-4000-8000-000000000032');
select is(app_private.has_platform_permission('people.read'),false,'membership suspensa nega');

-- 10-13 membership de plataforma: vale em qualquer instituicao; deny vence allow
select pg_temp.p7_session('a7000000-0000-4000-8000-000000000033');
select is(app_private.has_platform_permission('people.read'),true,'membership de plataforma concede');
select is(app_private.has_platform_permission('people.read','a7000000-0000-4000-8000-000000000012'),true,
  'membership de plataforma vale para qualquer instituicao');
select is(app_private.has_platform_permission('people.create'),false,'override deny vence o allow do papel');
select is(app_private.has_platform_permission('people.synthetic_missing'),false,'codigo inexistente nega');

-- 14 membership revogada
update public.platform_memberships set status='revoked', revoked_at=now()
where id='a7000000-0000-4000-8000-000000000051';
select pg_temp.p7_session('a7000000-0000-4000-8000-000000000031');
select is(app_private.has_platform_permission('people.read'),false,'membership revogada nega');

-- 15-20 ACL e metadados das duas formas
select ok(not has_function_privilege('anon','app_private.has_platform_permission(text)','execute'),'anon sem execute na forma (text)');
select ok(not has_function_privilege('anon','app_private.has_platform_permission(text,uuid)','execute'),'anon sem execute na forma (text,uuid)');
select ok(has_function_privilege('authenticated','app_private.has_platform_permission(text)','execute'),'authenticated executa a forma (text), como na baseline');
select ok(has_function_privilege('authenticated','app_private.has_platform_permission(text,uuid)','execute'),'authenticated executa a forma (text,uuid)');
select ok((select prosecdef and provolatile='s' and pg_get_userbyid(proowner)='postgres'
  from pg_proc where oid='app_private.has_platform_permission(text)'::regprocedure),
  'forma (text): security definer, stable, dono postgres');
select ok((select prosecdef and provolatile='s' and pg_get_userbyid(proowner)='postgres'
  from pg_proc where oid='app_private.has_platform_permission(text,uuid)'::regprocedure),
  'forma (text,uuid): security definer, stable, dono postgres');

select * from finish();
rollback;
