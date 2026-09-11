-- pgTAP da raiz da ponte de ator (candidato 20260912210000_internal_actor_scope_root_v1).
--
-- Prova por familia: uma identidade interna ESCOPADA na instituicao A nao pode
-- receber capacidade de plataforma (has_platform_permission de um argumento)
-- nem membership de instituicao fora de A. Os 12 helpers people-based que
-- decidem por has_platform_permission(text) negam a identidade escopada e
-- aceitam a identidade interna de plataforma (controle).
begin;
create extension if not exists pgtap with schema extensions;
select plan(46);

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9c600000-0000-4000-8000-000000000101','authenticated','authenticated','scope-root-platform@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c600000-0000-4000-8000-000000000102','authenticated','authenticated','scope-root-scoped@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9c600000-0000-4000-8000-000000000201','9c600000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour'),
 ('9c600000-0000-4000-8000-000000000202','9c600000-0000-4000-8000-000000000102',now(),now(),'aal1',now()+interval '1 hour');

insert into public.institution_types(id,code,name,status) values
 ('9c600000-0000-4000-8000-000000000001','scope-root-test','Scope root test','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9c600000-0000-4000-8000-00000000000a','Instituição A','scope-root-a','active','9c600000-0000-4000-8000-000000000001'),
 ('9c600000-0000-4000-8000-00000000000b','Instituição B','scope-root-b','active','9c600000-0000-4000-8000-000000000001');

-- Identidade 301: owner de PLATAFORMA (controle). Identidade 302: owner ESCOPADA em A.
insert into app_private.superadmin_internal_identities(id) values
 ('9c600000-0000-4000-8000-000000000301'),('9c600000-0000-4000-8000-000000000302');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9c600000-0000-4000-8000-000000000401','9c600000-0000-4000-8000-000000000301','9c600000-0000-4000-8000-000000000101'),
 ('9c600000-0000-4000-8000-000000000402','9c600000-0000-4000-8000-000000000302','9c600000-0000-4000-8000-000000000102');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select f.id,f.identity_id,r.id,f.scope_kind::app_private.superadmin_internal_scope_kind,f.institution_id
from (values
 ('9c600000-0000-4000-8000-000000000501'::uuid,'9c600000-0000-4000-8000-000000000301'::uuid,'platform',null::uuid),
 ('9c600000-0000-4000-8000-000000000502'::uuid,'9c600000-0000-4000-8000-000000000302'::uuid,'institution','9c600000-0000-4000-8000-00000000000a'::uuid)
) f(id,identity_id,scope_kind,institution_id)
join public.platform_roles r on r.code='owner';

-- ---------------------------------------------------------------------------
-- Espelhos criados pelas pontes (220400: pessoa de servico + platform_membership;
-- 130000: institution_memberships)
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int from app_private.superadmin_internal_actor_people
    where internal_identity_id in ('9c600000-0000-4000-8000-000000000301','9c600000-0000-4000-8000-000000000302')),
  2,'as duas identidades ganharam pessoa de servico');
select is(
  (select pm.scope_kind||':'||coalesce(pm.scope_institution_id::text,'-')
     from app_private.superadmin_internal_actor_people a
     join public.platform_memberships pm on pm.id=a.platform_membership_id
    where a.internal_identity_id='9c600000-0000-4000-8000-000000000302'),
  'institution:9c600000-0000-4000-8000-00000000000a','espelho da escopada carrega o escopo de A');

-- R1: sincronizador do 130000 respeita o escopo
select is(
  (select string_agg(m.institution_id::text,',' order by m.institution_id)
     from public.institution_memberships m
     join app_private.superadmin_internal_actor_people a on a.person_id=m.person_id
    where a.internal_identity_id='9c600000-0000-4000-8000-000000000302'
      and m.status='active' and m.revoked_at is null),
  '9c600000-0000-4000-8000-00000000000a','identidade escopada em A so tem membership ativa em A (nao em B)');
select is(
  (select count(*)::int from public.institution_memberships m
     join app_private.superadmin_internal_actor_people a on a.person_id=m.person_id
    where a.internal_identity_id='9c600000-0000-4000-8000-000000000301'
      and m.institution_id in ('9c600000-0000-4000-8000-00000000000a','9c600000-0000-4000-8000-00000000000b')
      and m.status='active' and m.revoked_at is null),
  2,'identidade de plataforma tem membership em A e B (Superadmin ve tudo, P35)');

-- Reconciliacao: uma membership fora do escopo que ja existisse e desativada pelo sync
insert into public.institution_memberships(person_id,institution_id,role_code,status,scope_kind)
select a.person_id,'9c600000-0000-4000-8000-00000000000b','owner','active','institution'
from app_private.superadmin_internal_actor_people a where a.internal_identity_id='9c600000-0000-4000-8000-000000000302'
  and not exists (select 1 from public.institution_memberships m where m.person_id=a.person_id
    and m.institution_id='9c600000-0000-4000-8000-00000000000b' and m.status='active' and m.revoked_at is null);
select ok(app_private.superadmin_internal_actor_institution_access_sync() >= 1,'sync reconcilia membership fora do escopo');
select is(
  (select m.status::text||':'||(m.revoked_at is not null)::text from public.institution_memberships m
     join app_private.superadmin_internal_actor_people a on a.person_id=m.person_id
    where a.internal_identity_id='9c600000-0000-4000-8000-000000000302'
      and m.institution_id='9c600000-0000-4000-8000-00000000000b'),
  'inactive:true','membership fora do escopo fica inactive + revoked_at');

-- Instituicao em rascunho (lote 27 / P42): membership previa do espelho de PLATAFORMA e preservada
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9c600000-0000-4000-8000-00000000000c','Instituição C (rascunho)','scope-root-c','draft','9c600000-0000-4000-8000-000000000001');
insert into public.institution_memberships(person_id,institution_id,role_code,status,scope_kind)
select a.person_id,'9c600000-0000-4000-8000-00000000000c','owner','active','institution'
from app_private.superadmin_internal_actor_people a where a.internal_identity_id='9c600000-0000-4000-8000-000000000301';
select app_private.superadmin_internal_actor_institution_access_sync();
select is(
  (select m.status::text from public.institution_memberships m
     join app_private.superadmin_internal_actor_people a on a.person_id=m.person_id
    where a.internal_identity_id='9c600000-0000-4000-8000-000000000301'
      and m.institution_id='9c600000-0000-4000-8000-00000000000c'),
  'active','membership do espelho de plataforma numa instituicao em rascunho e preservada pelo sync');
select is(
  (select count(*)::int from public.institution_memberships m
     join app_private.superadmin_internal_actor_people a on a.person_id=m.person_id
    where a.internal_identity_id='9c600000-0000-4000-8000-000000000302'
      and m.institution_id='9c600000-0000-4000-8000-00000000000c'),
  0,'sync nao cria membership em instituicao fora do escopo nem em rascunho para a escopada');

-- ---------------------------------------------------------------------------
-- R2: has_platform_permission para a identidade escopada
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9c600000-0000-4000-8000-000000000102','session_id','9c600000-0000-4000-8000-000000000202',
 'aal','aal1','role','authenticated')::text,true);
select is(app_private.has_platform_permission('people.read'),false,'escopada: um argumento nega (sem capacidade de plataforma)');
select is(app_private.has_platform_permission('people.read','9c600000-0000-4000-8000-00000000000a'),true,'escopada: dois argumentos com A concede');
select is(app_private.has_platform_permission('people.read','9c600000-0000-4000-8000-00000000000b'),false,'escopada: dois argumentos com B nega');
select is(app_private.agenda_has_permission('agenda.read'),false,'escopada: Agenda (211200) continua negando');

create temporary table helper_probe(label text primary key, outcome text not null);
create or replace function pg_temp.probe(p_label text, p_sql text) returns void language plpgsql as $$
begin
  execute p_sql;
  insert into helper_probe values (p_label,'ok');
exception when others then
  insert into helper_probe values (p_label, sqlstate);
end $$;

create or replace function pg_temp.run_helpers(p_prefix text) returns void language plpgsql as $$
declare actor uuid := app_private.current_person_id();
begin
  perform pg_temp.probe(p_prefix||'require_routine_actor', $q$select app_private.require_routine_actor('routine.read')$q$);
  perform pg_temp.probe(p_prefix||'require_health_care_actor', $q$select app_private.require_health_care_actor('health_care.read')$q$);
  perform pg_temp.probe(p_prefix||'assert_people_permission', $q$select app_private.assert_people_permission('people.read')$q$);
  perform pg_temp.probe(p_prefix||'assert_child_safety_platform', $q$select app_private.assert_child_safety_platform('child_safety.read')$q$);
  perform pg_temp.probe(p_prefix||'require_forms_actor', $q$select app_private.require_forms_actor('forms.read')$q$);
  perform pg_temp.probe(p_prefix||'form_require_owner', format($q$select app_private.form_require_owner(%L,'forms.manage')$q$, actor));
  perform pg_temp.probe(p_prefix||'assert_support_permission', $q$select app_private.assert_support_permission()$q$);
  perform pg_temp.probe(p_prefix||'assert_account_actor', $q$select app_private.assert_account_actor()$q$);
  perform pg_temp.probe(p_prefix||'access_profile_require_mutation', $q$select app_private.access_profile_require_mutation('platform')$q$);
  perform pg_temp.probe(p_prefix||'assert_institution_file_access', $q$select app_private.assert_institution_file_access('institutions.export')$q$);
  perform pg_temp.probe(p_prefix||'assert_institution_identity_access', $q$select app_private.assert_institution_identity_access('9c600000-0000-4000-8000-00000000000b')$q$);
  perform pg_temp.probe(p_prefix||'require_profile_authority', $q$select app_private.require_profile_authority('platform')$q$);
end $$;

select pg_temp.run_helpers('scoped:');

-- Controle: identidade interna de plataforma passa nos 12 helpers
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9c600000-0000-4000-8000-000000000101','session_id','9c600000-0000-4000-8000-000000000201',
 'aal','aal1','role','authenticated')::text,true);
select is(app_private.has_platform_permission('people.read'),true,'plataforma: um argumento concede');
select pg_temp.run_helpers('platform:');

-- Rotina e Cuidado aceitam a escopada SO pela membership de contexto na propria
-- instituicao (has_context_permission em A); a plataforma nao concede.
select is((select outcome from helper_probe where label='scoped:'||h),'ok',h||' aceita a escopada pelo contexto da propria instituicao')
from unnest(array['require_routine_actor','require_health_care_actor']) h;
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9c600000-0000-4000-8000-000000000102','session_id','9c600000-0000-4000-8000-000000000202',
 'aal','aal1','role','authenticated')::text,true);
select is(app_private.has_context_permission('9c600000-0000-4000-8000-00000000000a','routine.read',null,null,null,null,false),true,
  'escopada: contexto de A concede routine.read');
select is(app_private.has_context_permission('9c600000-0000-4000-8000-00000000000b','routine.read',null,null,null,null,false),false,
  'escopada: contexto de B nega routine.read (membership em B desativada)');
select is((select outcome from helper_probe where label='scoped:'||h),'42501',h||' nega a identidade escopada (42501)')
from unnest(array['assert_people_permission','assert_child_safety_platform',
  'require_forms_actor','form_require_owner','assert_support_permission','assert_account_actor','access_profile_require_mutation',
  'assert_institution_file_access','assert_institution_identity_access','require_profile_authority']) h;
select is((select outcome from helper_probe where label='platform:'||h),'ok',h||' aceita a identidade de plataforma')
from unnest(array['require_routine_actor','require_health_care_actor','assert_people_permission','assert_child_safety_platform',
  'require_forms_actor','form_require_owner','assert_support_permission','assert_account_actor','access_profile_require_mutation',
  'assert_institution_file_access','assert_institution_identity_access','require_profile_authority']) h;

-- Pessoa do realm people-based com membership de instituicao continua valendo pela regra P7
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9c600000-0000-4000-8000-000000000601','adult','Pessoa','Escopada','Pessoa Escopada','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9c600000-0000-4000-8000-000000000103','authenticated','authenticated','scope-root-people@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9c600000-0000-4000-8000-000000000203','9c600000-0000-4000-8000-000000000103',now(),now(),'aal1',now()+interval '1 hour');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('9c600000-0000-4000-8000-000000000601','9c600000-0000-4000-8000-000000000103','active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,scope_institution_id,mfa_required)
select '9c600000-0000-4000-8000-000000000601',r.id,'active','institution','9c600000-0000-4000-8000-00000000000a',false
from public.platform_roles r where r.code='owner';
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9c600000-0000-4000-8000-000000000103','session_id','9c600000-0000-4000-8000-000000000203',
 'aal','aal1','role','authenticated')::text,true);
select is(app_private.has_platform_permission('people.read'),true,'pessoa people-based escopada: P7 mantido (um argumento concede)');
select is(app_private.has_platform_permission('people.read','9c600000-0000-4000-8000-00000000000b'),false,'pessoa people-based escopada: outra instituicao nega');

-- Sem sessao
select set_config('request.jwt.claims','',true);
select is(app_private.has_platform_permission('people.read'),false,'sem sessao nega');

-- ACL preservada
select is(has_function_privilege('anon','app_private.has_platform_permission(text,uuid)','execute'),false,'anon nao executa has_platform_permission');
select is(has_function_privilege('authenticated','app_private.has_platform_permission(text,uuid)','execute'),true,'authenticated executa (policies)');
select is(has_function_privilege('anon','app_private.superadmin_internal_actor_institution_access_sync()','execute'),false,'anon nao executa o sync');
select is(has_function_privilege('authenticated','app_private.superadmin_internal_actor_institution_access_sync()','execute'),false,'authenticated nao executa o sync');

select * from finish();
rollback;
