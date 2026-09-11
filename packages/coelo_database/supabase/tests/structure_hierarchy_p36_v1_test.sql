-- P36: instituicao -> unidade -> turma -> atividade no servidor.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into public.institution_types(id,code,name,status) values
 ('9f070000-0000-4000-8000-000000000001','p36-test','P36','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9f070000-0000-4000-8000-000000000010','P36 A','p36-a','active','9f070000-0000-4000-8000-000000000001'),
 ('9f070000-0000-4000-8000-000000000020','P36 B','p36-b','active','9f070000-0000-4000-8000-000000000001');
insert into public.unit_types(id,code,name,status) values
 ('9f070000-0000-4000-8000-000000000002','p36-unit','Unidade P36','active');
insert into public.units(id,institution_id,unit_type_id,name,slug,status,handle) values
 ('9f070000-0000-4000-8000-000000000011','9f070000-0000-4000-8000-000000000010','9f070000-0000-4000-8000-000000000002','Unidade A1','p36-a1','active','u.p36a1'),
 ('9f070000-0000-4000-8000-000000000012','9f070000-0000-4000-8000-000000000010','9f070000-0000-4000-8000-000000000002','Unidade A2','p36-a2','active','u.p36a2'),
 ('9f070000-0000-4000-8000-000000000021','9f070000-0000-4000-8000-000000000020','9f070000-0000-4000-8000-000000000002','Unidade B1','p36-b1','active','u.p36b1');
insert into public.groups(id,institution_id,unit_id,name,status) values
 ('9f070000-0000-4000-8000-000000000013','9f070000-0000-4000-8000-000000000010','9f070000-0000-4000-8000-000000000011','Turma A1-1','active'),
 ('9f070000-0000-4000-8000-000000000014','9f070000-0000-4000-8000-000000000010','9f070000-0000-4000-8000-000000000011','Turma A1-2','active');

-- 1. estrutura ja garantida pela baseline
select throws_like($$insert into public.units(institution_id,unit_type_id,name,slug,status,handle)
  values (null,'9f070000-0000-4000-8000-000000000002','Sem inst','p36-x','active','u.p36x')$$,
  '%null value in column "institution_id"%','unidade sem instituicao e rejeitada (NOT NULL)');
select throws_like($$insert into public.groups(institution_id,unit_id,name,status)
  values ('9f070000-0000-4000-8000-000000000010',null,'Sem unidade','active')$$,
  '%null value in column "unit_id"%','turma sem unidade e rejeitada (NOT NULL)');
select throws_like($$insert into public.groups(institution_id,unit_id,name,status)
  values ('9f070000-0000-4000-8000-000000000010','9f070000-0000-4000-8000-000000000021','Unidade de B','active')$$,
  '%violates foreign key constraint%','turma em unidade de outra instituicao e rejeitada (FK composta)');

-- identidade interna genuina para o marcador de atividades
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9f070000-0000-4000-8000-000000000101','authenticated','authenticated','p36-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9f070000-0000-4000-8000-000000000201','9f070000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values ('9f070000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9f070000-0000-4000-8000-000000000401','9f070000-0000-4000-8000-000000000301','9f070000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '9f070000-0000-4000-8000-000000000501','9f070000-0000-4000-8000-000000000301',r.id,'platform' from public.platform_roles r where r.code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r cross join public.platform_permissions p
where r.code='owner' and p.code in ('activities.manage','activities.link_units','activities.link_groups')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
select set_config('request.jwt.claims',jsonb_build_object('sub','9f070000-0000-4000-8000-000000000101','session_id','9f070000-0000-4000-8000-000000000201','aal','aal1','role','authenticated')::text,true);
create function pg_temp.marker(p_perm text, p_action text) returns void language sql as $$
  select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
    'internal_identity_id','9f070000-0000-4000-8000-000000000301','internal_auth_link_id','9f070000-0000-4000-8000-000000000401',
    'internal_membership_id','9f070000-0000-4000-8000-000000000501','auth_user_id','9f070000-0000-4000-8000-000000000101',
    'session_id','9f070000-0000-4000-8000-000000000201','permission_code',p_perm,'action_code',p_action,'correlation_id',gen_random_uuid())::text,true)
$$;

-- 2. rascunho so com unidade e permitido
select pg_temp.marker('activities.manage','manage');
insert into public.activity_definitions(id,institution_id,name,handle_stem,origin_scope_kind,distribution_scope,created_by_person_id,status,management_version)
values ('9f070000-0000-4000-8000-000000000701','9f070000-0000-4000-8000-000000000010','Atividade P36','atividade-p36','institution','institution_standard',null,'draft',1);
select pg_temp.marker('activities.link_units','link_units');
insert into public.activity_unit_links(id,activity_id,institution_id,unit_id,linked_by_person_id)
values ('9f070000-0000-4000-8000-000000000711','9f070000-0000-4000-8000-000000000701','9f070000-0000-4000-8000-000000000010','9f070000-0000-4000-8000-000000000011',null);
select lives_ok($$set constraints all immediate$$,'rascunho de atividade com unidade e sem turma e aceito');
set constraints all deferred;

-- 3. ativar sem turma e recusado
select pg_temp.marker('activities.manage','manage');
update public.activity_definitions set status='active' where id='9f070000-0000-4000-8000-000000000701';
select throws_like($$set constraints all immediate$$,'%activity must retain at least one active group link%','atividade ativa sem turma e recusada (P36)');
-- o throws_like envolve so o set constraints num savepoint; a linha continua alterada: desfazer explicitamente
select pg_temp.marker('activities.manage','manage');
update public.activity_definitions set status='draft' where id='9f070000-0000-4000-8000-000000000701';
select lives_ok($$set constraints all immediate$$,'de volta a draft, a fila de restricoes passa');
set constraints all deferred;

-- 4. turma de outra unidade e recusada (FK composta); turma certa e aceita e a ativacao passa
select pg_temp.marker('activities.link_groups','link_groups');
select throws_like($$insert into public.activity_group_links(id,activity_id,institution_id,unit_id,group_id,linked_by_person_id,participation_mode)
  values ('9f070000-0000-4000-8000-000000000712','9f070000-0000-4000-8000-000000000701','9f070000-0000-4000-8000-000000000010','9f070000-0000-4000-8000-000000000012','9f070000-0000-4000-8000-000000000013',null,'all')$$,
  '%violates foreign key constraint%','turma de outra unidade nao vincula a atividade (FK composta)');
select pg_temp.marker('activities.link_groups','link_groups');
insert into public.activity_group_links(id,activity_id,institution_id,unit_id,group_id,linked_by_person_id,participation_mode)
values ('9f070000-0000-4000-8000-000000000713','9f070000-0000-4000-8000-000000000701','9f070000-0000-4000-8000-000000000010','9f070000-0000-4000-8000-000000000011','9f070000-0000-4000-8000-000000000013',null,'all');
select pg_temp.marker('activities.manage','manage');
update public.activity_definitions set status='active' where id='9f070000-0000-4000-8000-000000000701';
select lives_ok($$set constraints all immediate$$,'atividade ativa com turma e aceita');
set constraints all deferred;

-- 5. o ultimo vinculo de turma de uma atividade ativa nao pode ser encerrado
select pg_temp.marker('activities.link_groups','link_groups');
update public.activity_group_links set status='inactive' where id='9f070000-0000-4000-8000-000000000713';
select throws_like($$set constraints all immediate$$,'%activity must retain at least one active group link%','encerrar a ultima turma de atividade ativa e recusado');
select pg_temp.marker('activities.link_groups','link_groups');
update public.activity_group_links set status='active' where id='9f070000-0000-4000-8000-000000000713';
select lives_ok($$set constraints all immediate$$,'vinculo reativado, a fila passa');
set constraints all deferred;

-- 6. com uma segunda turma, encerrar a primeira e permitido; arquivar a atividade libera tudo
select pg_temp.marker('activities.link_groups','link_groups');
insert into public.activity_group_links(id,activity_id,institution_id,unit_id,group_id,linked_by_person_id,participation_mode)
values ('9f070000-0000-4000-8000-000000000714','9f070000-0000-4000-8000-000000000701','9f070000-0000-4000-8000-000000000010','9f070000-0000-4000-8000-000000000011','9f070000-0000-4000-8000-000000000014',null,'all');
update public.activity_group_links set status='inactive' where id='9f070000-0000-4000-8000-000000000713';
select lives_ok($$set constraints all immediate$$,'com outra turma ativa, encerrar a primeira e aceito');
set constraints all deferred;
select pg_temp.marker('activities.manage','manage');
update public.activity_definitions set status='archived', archived_at=now() where id='9f070000-0000-4000-8000-000000000701';
update public.activity_group_links set status='inactive' where id='9f070000-0000-4000-8000-000000000714';
select lives_ok($$set constraints all immediate$$,'atividade arquivada nao exige turma');

select ok(exists (select 1 from pg_trigger where tgname='activity_definition_requires_group' and tgdeferrable)
  and exists (select 1 from pg_trigger where tgname='activity_group_links_retain_one' and tgdeferrable),
  'gatilhos P36 existem e sao diferidos');

select * from finish();
rollback;
