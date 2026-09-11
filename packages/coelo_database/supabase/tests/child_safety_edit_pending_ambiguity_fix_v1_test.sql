-- Somente replay LOCAL descartavel. Fixtures sinteticas com rollback. Nenhuma conta real.
-- Prova do candidato 20260910172100_child_safety_edit_pending_ambiguity_fix_v1 (fixtures reaproveitadas do teste do 171800).
-- (P32, opcao b): ator de plataforma com child_safety.manage decide e muda ciclo de vida;
-- revisor exato da unidade continua decidindo; quem nao tem nenhuma das duas recebe P0002.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

-- Catalogos sinteticos na forma canonica de producao.
insert into public.institution_types(id,code,name,status) values
('c5320000-0000-4000-8000-000000000001','p32-safety-type','P32 safety type','active');
insert into public.unit_types(id,code,name,status) values
('c5320000-0000-4000-8000-000000000002','p32-safety-unit','P32 safety unit','active');
insert into public.institutions(id,public_name,slug,institution_type_id) values
('c5321000-0000-4000-8000-000000000001','P32 synthetic A','p32-safety-a','c5320000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,unit_type_id,name,slug,handle) values
('c5322000-0000-4000-8000-000000000001','c5321000-0000-4000-8000-000000000001','c5320000-0000-4000-8000-000000000002','P32 unit A1','a1','p32unita1'),
('c5322000-0000-4000-8000-000000000002','c5321000-0000-4000-8000-000000000001','c5320000-0000-4000-8000-000000000002','P32 unit A2','a2','p32unita2');
insert into public.people(id,person_type,first_name,last_name,display_name) values
('c5323000-0000-4000-8000-000000000001','child','P32','Synthetic','P32 synthetic child'),
('c5323000-0000-4000-8000-000000000002','adult','P32','Synthetic','P32 synthetic guardian'),
('c5323000-0000-4000-8000-000000000003','adult','P32','Synthetic','P32 synthetic authorized adult'),
('c5323000-0000-4000-8000-000000000004','adult','P32','Synthetic','P32 synthetic unit reviewer');
insert into public.child_contexts(id,child_person_id,institution_id) values
('c5324000-0000-4000-8000-000000000001','c5323000-0000-4000-8000-000000000001','c5321000-0000-4000-8000-000000000001');
insert into public.child_unit_links(child_context_id,unit_id,status,accepted_by,accepted_at) values
('c5324000-0000-4000-8000-000000000001','c5322000-0000-4000-8000-000000000001','active','c5323000-0000-4000-8000-000000000002',now());
insert into public.family_relationship_types(id,code,name) values
('c5325000-0000-4000-8000-000000000001','p32_uncle','P32 uncle');
insert into public.authorized_people(id,institution_id,display_name,person_id,owner_guardian_person_id) values
('c5326000-0000-4000-8000-000000000001','c5321000-0000-4000-8000-000000000001','P32 synthetic authorized adult',
 'c5323000-0000-4000-8000-000000000003','c5323000-0000-4000-8000-000000000002');
-- Tres pedidos pendentes: 1 plataforma decide + ciclo de vida; 2 versao obsoleta + revisor;
-- 3 plataforma sem child_safety.manage.
insert into public.authorized_person_authorizations(id,authorized_person_id,institution_id,child_context_id,unit_id,
  relationship_type_id,created_by_person_id,status,decision_status,request_reason)
select ('c5327000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'c5326000-0000-4000-8000-000000000001',
  'c5321000-0000-4000-8000-000000000001','c5324000-0000-4000-8000-000000000001','c5322000-0000-4000-8000-000000000001',
  'c5325000-0000-4000-8000-000000000001','c5323000-0000-4000-8000-000000000002','inactive','pending','P32 synthetic request'
from generate_series(1,3) n;
insert into public.authorized_person_authorization_capabilities(authorization_id,capability_code)
select ('c5327000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'pickup' from generate_series(1,3) n;

-- Ator de plataforma COM child_safety.manage (Owner), via ponte de ator interno.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
('c5328000-0000-4000-8000-000000000001','authenticated','authenticated','p32-owner@invalid.test',now(),now(),now(),'{}','{}'),
('c5328000-0000-4000-8000-000000000002','authenticated','authenticated','p32-reader@invalid.test',now(),now(),now(),'{}','{}'),
('c5328000-0000-4000-8000-000000000003','authenticated','authenticated','p32-reviewer@invalid.test',now(),now(),now(),'{}','{}');
insert into app_private.superadmin_internal_identities(id) values
('c5329000-0000-4000-8000-000000000001'),('c5329000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
('c532a000-0000-4000-8000-000000000001','c5329000-0000-4000-8000-000000000001','c5328000-0000-4000-8000-000000000001'),
('c532a000-0000-4000-8000-000000000002','c5329000-0000-4000-8000-000000000002','c5328000-0000-4000-8000-000000000002');
-- Ator de plataforma SEM child_safety.manage: papel sintetico so com child_safety.read.
insert into public.platform_roles(id,code,name,max_scope_kind) values
('c532b000-0000-4000-8000-000000000001','p32_safety_reader','P32 synthetic reader','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect)
select 'c532b000-0000-4000-8000-000000000001',id,'allow' from public.platform_permissions where code='child_safety.read';
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select 'c532c000-0000-4000-8000-000000000001','c5329000-0000-4000-8000-000000000001',id,'platform'
from public.platform_roles where code='owner';
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind) values
('c532c000-0000-4000-8000-000000000002','c5329000-0000-4000-8000-000000000002','c532b000-0000-4000-8000-000000000001','platform');

select ok(exists(select 1 from app_private.superadmin_internal_actor_people ap
  join public.platform_memberships pm on pm.id=ap.platform_membership_id and pm.status='active'
  where ap.internal_identity_id='c5329000-0000-4000-8000-000000000001'),
  'ponte de ator espelhou pessoa de servico e membership de plataforma do Owner');

-- Revisor exato da unidade A1.
insert into public.person_auth_links(person_id,auth_user_id) values
('c5323000-0000-4000-8000-000000000004','c5328000-0000-4000-8000-000000000003');
insert into public.institution_memberships(id,person_id,institution_id,role_code) values
('c532d000-0000-4000-8000-000000000001','c5323000-0000-4000-8000-000000000004','c5321000-0000-4000-8000-000000000001','p32_reviewer');
insert into public.institution_roles(id,institution_id,code,name,max_scope_kind) values
('c532e000-0000-4000-8000-000000000001','c5321000-0000-4000-8000-000000000001','p32_unit_reviewer','P32 unit reviewer','unit');
insert into public.institution_role_permissions(role_id,permission_id)
select 'c532e000-0000-4000-8000-000000000001',id from public.institution_permissions where code='authorized_people.manage';
insert into public.institution_role_assignments(membership_id,role_id,scope_kind,scope_unit_id) values
('c532d000-0000-4000-8000-000000000001','c532e000-0000-4000-8000-000000000001','unit','c5322000-0000-4000-8000-000000000001');

-- Edicao do pedido pendente 1 pelo ator de plataforma (child_safety.manage): com a correcao, persiste.
select set_config('request.jwt.claims',jsonb_build_object('sub','c5328000-0000-4000-8000-000000000001',
  'session_id','c532f000-0000-4000-8000-000000000001','aal','aal2','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.p_edit',public.child_safety_edit_pending_authorization(
  'c532f000-0000-4000-8000-0000000000e1','c5327000-0000-4000-8000-000000000001',1,
  jsonb_build_object('child_id','c5323000-0000-4000-8000-000000000001','child_context_id','c5324000-0000-4000-8000-000000000001',
    'unit_id','c5322000-0000-4000-8000-000000000001','person_id','c5326000-0000-4000-8000-000000000001','relationship_code','p32_uncle',
    'capability_codes',jsonb_build_array('pickup','transport'),'request_reason','P32 edicao sintetica do pedido pendente'))::text,true);
reset role;
select ok((current_setting('test.p_edit')::jsonb->>'version')::int >= 2, 'edicao pendente devolve versao incrementada');
select is((select request_reason from public.authorized_person_authorizations where id='c5327000-0000-4000-8000-000000000001'),
  'P32 edicao sintetica do pedido pendente', 'motivo editado persiste (sem 42702)');
select ok(not has_function_privilege('anon','public.child_safety_edit_pending_authorization(uuid,uuid,bigint,jsonb)','execute'),
  'anon sem execute na publica');

select * from finish();
rollback;