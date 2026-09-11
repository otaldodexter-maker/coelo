-- Prova do pacote 20260910240400: Criar grupo (P8) pelo realm interno.
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

select has_function('public','superadmin_chat_create_group_v2',
 array['uuid','uuid','text','uuid[]','uuid','uuid','uuid']);
select has_function('public','superadmin_chat_group_members_v2',array['uuid']);
select ok(has_function_privilege('authenticated','public.superadmin_chat_create_group_v2(uuid,uuid,text,uuid[],uuid,uuid,uuid)','execute')
 and not has_function_privilege('anon','public.superadmin_chat_create_group_v2(uuid,uuid,text,uuid[],uuid,uuid,uuid)','execute')
 and not has_function_privilege('public','public.superadmin_chat_group_members_v2(uuid)','execute')
 and not has_table_privilege('authenticated','app_private.superadmin_internal_chat_group_receipts','select'),
 'only authenticated can create groups; idempotency state has no client path');

-- Fixture: instituicoes A e B; Marina (profissional em A), Paulo (responsavel
-- de Lia, crianca ativa em A), Rita (sem vinculo).
insert into public.institution_types(id,code,name,status) values
 ('9c120000-0000-4000-8000-000000000001','internal-chat-group','Internal chat group','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9c120000-0000-4000-8000-000000000010','Colégio Horizonte','chat-group-a','active','9c120000-0000-4000-8000-000000000001'),
 ('9c120000-0000-4000-8000-000000000020','Escola Aurora','chat-group-b','active','9c120000-0000-4000-8000-000000000001');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9c120000-0000-4000-8000-000000000061','adult','Marina','Souza','Marina Souza','active'),
 ('9c120000-0000-4000-8000-000000000062','adult','Paulo','Lima','Paulo Lima','active'),
 ('9c120000-0000-4000-8000-000000000063','adult','Rita','Nunes','Rita Nunes','active'),
 ('9c120000-0000-4000-8000-000000000064','child','Lia','Lima','Lia Lima','active');
insert into public.institution_memberships(person_id,institution_id,role_code) values
 ('9c120000-0000-4000-8000-000000000061','9c120000-0000-4000-8000-000000000010','teacher');
insert into public.family_relationship_types(id,code,name) values
 ('9c120000-0000-4000-8000-000000000090','pai_teste','Pai (teste)');
insert into public.guardian_links(guardian_person_id,child_person_id,relation_type,relationship_type_id) values
 ('9c120000-0000-4000-8000-000000000062','9c120000-0000-4000-8000-000000000064','pai','9c120000-0000-4000-8000-000000000090');
insert into public.child_contexts(child_person_id,institution_id) values
 ('9c120000-0000-4000-8000-000000000064','9c120000-0000-4000-8000-000000000010');
-- Unidade e turma em A para os escopos unit e group.
insert into public.units(id,institution_id,name,slug,unit_type_id,unit_type_other_description,handle) values
 ('9c120000-0000-4000-8000-000000000011','9c120000-0000-4000-8000-000000000010','Unidade Centro','qa-unidade-centro',
  (select id from public.unit_types where code='other'),'Unidade de teste','qa.unidade.centro');
insert into public.groups(id,institution_id,unit_id,name) values
 ('9c120000-0000-4000-8000-000000000012','9c120000-0000-4000-8000-000000000010','9c120000-0000-4000-8000-000000000011','Turma 1');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9c120000-0000-4000-8000-000000000101','authenticated','authenticated','group-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c120000-0000-4000-8000-000000000102','authenticated','authenticated','group-operations@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c120000-0000-4000-8000-000000000106','authenticated','authenticated','group-owner-b@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9c120000-0000-4000-8000-000000000201','9c120000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour'),
 ('9c120000-0000-4000-8000-000000000202','9c120000-0000-4000-8000-000000000102',now(),now(),'aal1',now()+interval '1 hour'),
 ('9c120000-0000-4000-8000-000000000206','9c120000-0000-4000-8000-000000000106',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('9c120000-0000-4000-8000-000000000301'),('9c120000-0000-4000-8000-000000000302'),
 ('9c120000-0000-4000-8000-000000000306');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9c120000-0000-4000-8000-000000000401','9c120000-0000-4000-8000-000000000301','9c120000-0000-4000-8000-000000000101'),
 ('9c120000-0000-4000-8000-000000000402','9c120000-0000-4000-8000-000000000302','9c120000-0000-4000-8000-000000000102'),
 ('9c120000-0000-4000-8000-000000000406','9c120000-0000-4000-8000-000000000306','9c120000-0000-4000-8000-000000000106');
insert into app_private.superadmin_internal_memberships(
 id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,role_record.id,
 fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from(values
 ('9c120000-0000-4000-8000-000000000501'::uuid,'9c120000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('9c120000-0000-4000-8000-000000000502'::uuid,'9c120000-0000-4000-8000-000000000302'::uuid,'operations','institution','9c120000-0000-4000-8000-000000000010'::uuid),
 ('9c120000-0000-4000-8000-000000000506'::uuid,'9c120000-0000-4000-8000-000000000306'::uuid,'owner','institution','9c120000-0000-4000-8000-000000000020'::uuid)
)fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;

create temporary table group_results(label text primary key,body jsonb not null);

-- Owner de plataforma cria, repete, diverge, erra membro e erra titulo.
select set_config('request.jwt.claims',jsonb_build_object('sub','9c120000-0000-4000-8000-000000000101','session_id','9c120000-0000-4000-8000-000000000201','aal','aal1','role','authenticated')::text,true);
insert into group_results values
 ('create',public.superadmin_chat_create_group_v2('9c120000-0000-4000-8000-000000000901',
   '9c120000-0000-4000-8000-000000000010','Equipe do Horizonte',
   array['9c120000-0000-4000-8000-000000000061','9c120000-0000-4000-8000-000000000062']::uuid[])),
 ('replay',public.superadmin_chat_create_group_v2('9c120000-0000-4000-8000-000000000901',
   '9c120000-0000-4000-8000-000000000010','Equipe do Horizonte',
   array['9c120000-0000-4000-8000-000000000062','9c120000-0000-4000-8000-000000000061']::uuid[])),
 ('mismatch',public.superadmin_chat_create_group_v2('9c120000-0000-4000-8000-000000000901',
   '9c120000-0000-4000-8000-000000000010','Outro titulo',
   array['9c120000-0000-4000-8000-000000000061']::uuid[])),
 ('member_invalid',public.superadmin_chat_create_group_v2('9c120000-0000-4000-8000-000000000902',
   '9c120000-0000-4000-8000-000000000010','Com intrusa',
   array['9c120000-0000-4000-8000-000000000061','9c120000-0000-4000-8000-000000000063']::uuid[])),
 ('title_invalid',public.superadmin_chat_create_group_v2('9c120000-0000-4000-8000-000000000903',
   '9c120000-0000-4000-8000-000000000010','   ',
   array['9c120000-0000-4000-8000-000000000061']::uuid[])),
 ('unit_invalid',public.superadmin_chat_create_group_v2('9c120000-0000-4000-8000-000000000904',
   '9c120000-0000-4000-8000-000000000010','Unidade inexistente',
   array['9c120000-0000-4000-8000-000000000061']::uuid[],'9c120000-0000-4000-8000-0000000000ff')),
 ('unit_scope',public.superadmin_chat_create_group_v2('9c120000-0000-4000-8000-000000000907',
   '9c120000-0000-4000-8000-000000000010','Equipe da unidade',
   array['9c120000-0000-4000-8000-000000000061']::uuid[],'9c120000-0000-4000-8000-000000000011')),
 ('group_scope',public.superadmin_chat_create_group_v2('9c120000-0000-4000-8000-000000000908',
   '9c120000-0000-4000-8000-000000000010','Equipe da turma',
   array['9c120000-0000-4000-8000-000000000062']::uuid[],'9c120000-0000-4000-8000-000000000011','9c120000-0000-4000-8000-000000000012')),
 ('group_without_unit',public.superadmin_chat_create_group_v2('9c120000-0000-4000-8000-000000000909',
   '9c120000-0000-4000-8000-000000000010','Turma sem unidade',
   array['9c120000-0000-4000-8000-000000000061']::uuid[],null,'9c120000-0000-4000-8000-000000000012')),
 ('inbox',public.superadmin_chat_inbox_v2(null,null,30,'Equipe do Horizonte',false));
insert into group_results values
 ('members',public.superadmin_chat_group_members_v2(
   (select (body#>>'{data,conversation_id}')::uuid from group_results where label='create')));

-- Operations (sem chat.internal.manage) e owner escopado a B (outro tenant).
select set_config('request.jwt.claims',jsonb_build_object('sub','9c120000-0000-4000-8000-000000000102','session_id','9c120000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
insert into group_results values
 ('operations_denied',public.superadmin_chat_create_group_v2('9c120000-0000-4000-8000-000000000905',
   '9c120000-0000-4000-8000-000000000010','Sem capacidade',
   array['9c120000-0000-4000-8000-000000000061']::uuid[]));
select set_config('request.jwt.claims',jsonb_build_object('sub','9c120000-0000-4000-8000-000000000106','session_id','9c120000-0000-4000-8000-000000000206','aal','aal1','role','authenticated')::text,true);
insert into group_results values
 ('cross_tenant',public.superadmin_chat_create_group_v2('9c120000-0000-4000-8000-000000000906',
   '9c120000-0000-4000-8000-000000000010','Fora do escopo',
   array['9c120000-0000-4000-8000-000000000061']::uuid[])),
 ('cross_tenant_members',public.superadmin_chat_group_members_v2(
   (select (body#>>'{data,conversation_id}')::uuid from group_results where label='create')));

select ok((select body#>>'{ok}'='true' and body#>>'{data,conversation_type}'='group'
   and body#>>'{data,scope_kind}'='institution' and body#>>'{data,member_count}'='2'
   and body#>>'{data,replayed}'='false' from group_results where label='create'),
 'owner creates an institution group with two members');
select ok((select created_by is null and status='active' and title='Equipe do Horizonte'
   and institution_id='9c120000-0000-4000-8000-000000000010'
  from public.conversations where id=(select (body#>>'{data,conversation_id}')::uuid from group_results where label='create')),
 'the group is a conversation of the institution without a people-realm creator');
select ok((select count(*)=2 and bool_and((person_id='9c120000-0000-4000-8000-000000000061' and experience_kind='professional' and role_snapshot='teacher')
   or (person_id='9c120000-0000-4000-8000-000000000062' and experience_kind='family' and role_snapshot='responsavel'))
  from public.conversation_participants
  where conversation_id=(select (body#>>'{data,conversation_id}')::uuid from group_results where label='create')),
 'participants carry the real institutional experience and role snapshot');
select is((select body#>>'{data,conversation_id}' from group_results where label='replay'),
 (select body#>>'{data,conversation_id}' from group_results where label='create'),
 'same request id with the same members (any order) replays the same group');
select ok((select body#>>'{data,replayed}'='true' from group_results where label='replay'),
 'replay is flagged');
select is((select body#>>'{error,code}' from group_results where label='mismatch'),
 'CHAT_REPLAY_MISMATCH','same request id with other data is rejected');
select is((select body#>>'{error,code}' from group_results where label='member_invalid'),
 'CHAT_MEMBER_INVALID','a person without a link to the institution cannot be a member');
select is((select body#>>'{error,code}' from group_results where label='title_invalid'),
 'CHAT_INVALID_INPUT','a blank title is refused');
select is((select body#>>'{error,code}' from group_results where label='unit_invalid'),
 'CHAT_INVALID_INPUT','a unit outside the institution is refused');
select ok((select body#>>'{ok}'='true' and body#>>'{data,scope_kind}'='unit'
   and body#>>'{data,unit_id}'='9c120000-0000-4000-8000-000000000011'
  from group_results where label='unit_scope'),'a unit-scoped group is created inside the institution');
select ok((select body#>>'{ok}'='true' and body#>>'{data,scope_kind}'='group'
   and body#>>'{data,group_id}'='9c120000-0000-4000-8000-000000000012'
  from group_results where label='group_scope'),'a class-scoped group carries unit and group');
select is((select body#>>'{error,code}' from group_results where label='group_without_unit'),
 'CHAT_INVALID_INPUT','a class without its unit is refused');
select is((select count(*) from public.conversations where conversation_type='group'
   and institution_id='9c120000-0000-4000-8000-000000000010'),3::bigint,
 'refused attempts create no conversation (only the three accepted groups exist)');
select ok((select body#>>'{data,total}'='1' and body#>>'{data,items,0,conversation_type}'='group'
  from group_results where label='inbox'),'the group appears in the internal inbox');
select ok((select body#>>'{data,total}'='2' and body#>>'{data,items,0,display_name}'='Marina Souza'
   and body#>>'{data,items,1,display_name}'='Paulo Lima' from group_results where label='members'),
 'members reader lists the participants with display names');
select is((select body#>>'{error,code}' from group_results where label='operations_denied'),
 'SAI_PERMISSION_DENIED','a role without chat.internal.manage cannot create groups');
select is((select body#>>'{error,code}' from group_results where label='cross_tenant'),
 'CHAT_NOT_FOUND','an institution-scoped owner cannot create a group in another tenant');
select is((select body#>>'{error,code}' from group_results where label='cross_tenant_members'),
 'CHAT_NOT_FOUND','an institution-scoped owner cannot list members of another tenant group');
select ok((select exists(select 1 from audit.audit_logs where actor_kind='superadmin_internal'
   and action_code='chat.group.create' and outcome='success'
   and actor_internal_identity_id='9c120000-0000-4000-8000-000000000301')),
 'group creation is audited for the internal actor');

select * from finish();
rollback;
