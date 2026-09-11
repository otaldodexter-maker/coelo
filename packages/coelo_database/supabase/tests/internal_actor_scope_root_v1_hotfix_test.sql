-- pgTAP do hotfix 20260912210100: reativa memberships de espelho de plataforma desativadas
-- pela reconciliacao da versao anterior (instituicao em rascunho) e nao reativa fora do escopo.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9c800000-0000-4000-8000-000000000101','authenticated','authenticated','hotfix-platform@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c800000-0000-4000-8000-000000000102','authenticated','authenticated','hotfix-scoped@invalid.test',now(),now(),now(),'{}','{}');
insert into public.institution_types(id,code,name,status) values
 ('9c800000-0000-4000-8000-000000000001','hotfix-test','Hotfix test','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9c800000-0000-4000-8000-00000000000a','Ativa A','hotfix-a','active','9c800000-0000-4000-8000-000000000001'),
 ('9c800000-0000-4000-8000-00000000000c','Rascunho C','hotfix-c','draft','9c800000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_identities(id) values
 ('9c800000-0000-4000-8000-000000000301'),('9c800000-0000-4000-8000-000000000302');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9c800000-0000-4000-8000-000000000401','9c800000-0000-4000-8000-000000000301','9c800000-0000-4000-8000-000000000101'),
 ('9c800000-0000-4000-8000-000000000402','9c800000-0000-4000-8000-000000000302','9c800000-0000-4000-8000-000000000102');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select f.id,f.identity_id,r.id,f.scope_kind::app_private.superadmin_internal_scope_kind,f.institution_id
from (values
 ('9c800000-0000-4000-8000-000000000501'::uuid,'9c800000-0000-4000-8000-000000000301'::uuid,'platform',null::uuid),
 ('9c800000-0000-4000-8000-000000000502'::uuid,'9c800000-0000-4000-8000-000000000302'::uuid,'institution','9c800000-0000-4000-8000-00000000000a'::uuid)
) f(id,identity_id,scope_kind,institution_id)
join public.platform_roles r on r.code='owner';

-- Simula o dano da versao anterior: membership de plataforma em C (rascunho) desativada ha 1 h;
-- e uma membership da escopada em C (fora do escopo) tambem desativada: essa NAO volta.
insert into public.institution_memberships(person_id,institution_id,role_code,status,scope_kind,revoked_at)
select a.person_id,'9c800000-0000-4000-8000-00000000000c','owner','inactive','institution',now()-interval '1 hour'
from app_private.superadmin_internal_actor_people a
where a.internal_identity_id in ('9c800000-0000-4000-8000-000000000301','9c800000-0000-4000-8000-000000000302');

select is(app_private.superadmin_internal_actor_scope_reactivate_v1(),1,'reativa exatamente a membership de plataforma em C');
select is((select m.status::text||':'||(m.revoked_at is null)::text from public.institution_memberships m
  join app_private.superadmin_internal_actor_people a on a.person_id=m.person_id
  where a.internal_identity_id='9c800000-0000-4000-8000-000000000301' and m.institution_id='9c800000-0000-4000-8000-00000000000c'),
  'active:true','membership de plataforma em rascunho volta a active sem revoked_at');
select is((select m.status::text from public.institution_memberships m
  join app_private.superadmin_internal_actor_people a on a.person_id=m.person_id
  where a.internal_identity_id='9c800000-0000-4000-8000-000000000302' and m.institution_id='9c800000-0000-4000-8000-00000000000c'),
  'inactive','membership da escopada fora do escopo continua inactive');
select is(app_private.superadmin_internal_actor_scope_reactivate_v1(),0,'segunda execucao nao reativa nada (idempotente)');

select * from finish();
rollback;
