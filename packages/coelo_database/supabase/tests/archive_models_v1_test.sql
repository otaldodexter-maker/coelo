-- Somente replay LOCAL descartavel. Fixtures sinteticas com rollback. Nenhuma conta real.
-- Prova da migration 20260916193000_archive_models_v1 (R14 Sessao 9, ADR 0041 B1,
-- owner.r12-02; specs/054-archive-activity-routine-models.md): Arquivar/Restaurar
-- modelos de Atividade (activity_templates, contexto interno) e de Rotina
-- (routine_models, ator people-based) como inativacao reversivel com expected_version
-- (PT409), estado (55000), escopo (P0002), recibo idempotente, auditoria; diretorio de
-- Rotina exclui arquivados por padrao e devolve com p_status='archived'; diretorio v1 de
-- modelos de Atividade lista todos os status com management_version.
begin;
create extension if not exists pgtap with schema extensions;
select plan(63);

create function pg_temp.am_id(n integer) returns uuid language sql immutable as $$
  select ('a9c00000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.am_id(integer) to authenticated, anon;

-- ---------------------------------------------------------------------------
-- Estrutura
-- ---------------------------------------------------------------------------
select has_column('public','activity_templates','management_version','activity_templates ganha management_version');
select col_not_null('public','activity_templates','management_version','management_version nao nulo');
select has_table('app_private','superadmin_internal_activity_template_lifecycle_receipts','recibos privados de ciclo de vida');
select ok((select c.relrowsecurity and c.relforcerowsecurity from pg_class c
  where c.oid='app_private.superadmin_internal_activity_template_lifecycle_receipts'::regclass),'RLS forcada nos recibos');
select table_privs_are('app_private','superadmin_internal_activity_template_lifecycle_receipts','authenticated',array[]::text[],'authenticated sem privilegio nos recibos');
select has_table('app_private','routine_model_lifecycle','status anterior do modelo de rotina e privado');
select ok((select c.relrowsecurity and c.relforcerowsecurity from pg_class c
  where c.oid='app_private.routine_model_lifecycle'::regclass),'RLS forcada em routine_model_lifecycle');
select table_privs_are('app_private','routine_model_lifecycle','authenticated',array[]::text[],'authenticated sem privilegio em routine_model_lifecycle');
select function_privs_are('public','superadmin_activity_template_archive_v1',array['uuid','bigint','uuid'],'authenticated',array['EXECUTE'],'authenticated executa archive de modelo de atividade');
select function_privs_are('public','superadmin_activity_template_restore_v1',array['uuid','bigint','uuid'],'authenticated',array['EXECUTE'],'authenticated executa restore de modelo de atividade');
select function_privs_are('public','superadmin_activity_template_directory_v1',array['uuid'],'authenticated',array['EXECUTE'],'authenticated executa o diretorio v1');
select function_privs_are('public','superadmin_activity_template_archive_v1',array['uuid','bigint','uuid'],'anon',array[]::text[],'anon nao executa archive de atividade');
select function_privs_are('app_private','superadmin_activity_template_lifecycle_v1',array['text','uuid','bigint','uuid'],'authenticated',array[]::text[],'funcao privada de atividade sem grant a authenticated');
select function_privs_are('public','superadmin_routine_model_archive_v1',array['uuid','uuid','bigint'],'authenticated',array['EXECUTE'],'authenticated executa archive de modelo de rotina');
select function_privs_are('public','superadmin_routine_model_restore_v1',array['uuid','uuid','bigint'],'authenticated',array['EXECUTE'],'authenticated executa restore de modelo de rotina');
select function_privs_are('public','superadmin_routine_model_archive_v1',array['uuid','uuid','bigint'],'anon',array[]::text[],'anon nao executa archive de rotina');
select function_privs_are('app_private','superadmin_routine_model_lifecycle_v1',array['text','uuid','uuid','bigint'],'authenticated',array[]::text[],'funcao privada de rotina sem grant a authenticated');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='app_private' and p.proname in ('superadmin_activity_template_lifecycle_v1','superadmin_routine_model_lifecycle_v1')
    and p.prosrc like '%serialization_failure%'),0,'nenhum comando novo usa serialization_failure (OQ-047)');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='app_private' and p.proname in ('superadmin_activity_template_lifecycle_v1','superadmin_routine_model_lifecycle_v1')
    and p.prosrc like $$%errcode='PT409'%$$),2,'os dois comandos sinalizam versao defasada com PT409');
select ok((select bool_and(prosecdef and coalesce(array_to_string(proconfig,','),'')='search_path=""') from pg_proc
  where oid in ('app_private.superadmin_activity_template_lifecycle_v1(text,uuid,bigint,uuid)'::regprocedure,
    'app_private.superadmin_routine_model_lifecycle_v1(text,uuid,uuid,bigint)'::regprocedure,
    'app_private.superadmin_activity_template_directory_v1(uuid)'::regprocedure,
    'app_private.superadmin_routine_directory(text,text,text,uuid,uuid,uuid,integer,integer)'::regprocedure)),
  'security definer + search_path vazio nas funcoes tocadas');
select ok(pg_get_functiondef('app_private.superadmin_activity_template_options(uuid)'::regprocedure) like $$%template.status='active'%$$,
  'o leitor de opcoes do formulario continua devolvendo so modelos ativos');

-- ---------------------------------------------------------------------------
-- Fixtures: catalogo minimo, duas instituicoes, ator interno platform (Owner) e
-- ator interno restrito a instituicao A; pessoa gestora de rotina (people-based).
-- ---------------------------------------------------------------------------
insert into public.institution_types(id,code,name,status) values (pg_temp.am_id(1),'am-type','AM type','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 (pg_temp.am_id(10),'AM Tenant A','am-tenant-a','active',pg_temp.am_id(1)),
 (pg_temp.am_id(20),'AM Tenant B','am-tenant-b','active',pg_temp.am_id(1));
insert into public.unit_types(id,code,name,status) values (pg_temp.am_id(2),'am-unit-type','AM unit type','active');
insert into public.units(id,institution_id,unit_type_id,name,slug,status,handle) values
 (pg_temp.am_id(11),pg_temp.am_id(10),pg_temp.am_id(2),'AM Unidade A','am-unit-a','active','u.am00000000011');
insert into public.people(id,person_type,first_name,last_name,display_name)
values ('c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema')
on conflict (id) do nothing;

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 (pg_temp.am_id(101),'authenticated','authenticated','am-owner@invalid.test',now(),now(),now(),'{}','{}'),
 (pg_temp.am_id(102),'authenticated','authenticated','am-scoped-a@invalid.test',now(),now(),now(),'{}','{}'),
 (pg_temp.am_id(103),'authenticated','authenticated','am-routine-manager@invalid.test',now(),now(),now(),'{}','{}'),
 (pg_temp.am_id(104),'authenticated','authenticated','am-routine-reader@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 (pg_temp.am_id(201),pg_temp.am_id(101),now(),now(),'aal2',now()+interval '1 hour'),
 (pg_temp.am_id(202),pg_temp.am_id(102),now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values (pg_temp.am_id(301)),(pg_temp.am_id(302));
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 (pg_temp.am_id(401),pg_temp.am_id(301),pg_temp.am_id(101)),
 (pg_temp.am_id(402),pg_temp.am_id(302),pg_temp.am_id(102));
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,role_record.id,fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 (pg_temp.am_id(501),pg_temp.am_id(301),'owner','platform',null::uuid),
 (pg_temp.am_id(502),pg_temp.am_id(302),'owner','institution',pg_temp.am_id(10))
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='owner' and permission_record.code in('activities.read','activities.templates.manage')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

-- Modelos de atividade: A (institution), B (institution de outro tenant), P (platform).
insert into public.activity_templates(id,scope_kind,institution_id,unit_id,code,name,taxonomy_id,governance_kind,template_payload,status) values
 (pg_temp.am_id(601),'institution',pg_temp.am_id(10),null,'am-template-a','AM modelo A',
  (select id from public.activity_taxonomies where taxonomy_kind='subtype' and status='active' order by code limit 1),'optional','{}','active'),
 (pg_temp.am_id(602),'institution',pg_temp.am_id(20),null,'am-template-b','AM modelo B',
  (select id from public.activity_taxonomies where taxonomy_kind='subtype' and status='active' order by code limit 1),'optional','{}','active'),
 (pg_temp.am_id(603),'platform',null,null,'am-template-p','AM modelo Coelo',
  (select id from public.activity_taxonomies where taxonomy_kind='subtype' and status='active' order by code limit 1),'optional','{}','active');

-- Rotina: permissoes (podem faltar no catalogo de referencia), papel temporario e pessoas.
insert into public.platform_permissions(code,module_code,module_label,screen_code,screen_label,action_code,action_label,description,risk_level,requires_mfa) values
 ('routine.read','routine','Rotina diaria','daily_routine','Rotina diaria','read','Ver','AM fixture','normal',false),
 ('routine.manage_models','routine','Rotina diaria','daily_routine','Rotina diaria','manage_models','Gerenciar','AM fixture','high',false)
on conflict (code) do nothing;
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.am_id(701),'adult','AM','Gestor','AM gestor de rotina','active'),
 (pg_temp.am_id(702),'adult','AM','Leitor','AM leitor de rotina','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 (pg_temp.am_id(701),pg_temp.am_id(103),'active'),(pg_temp.am_id(702),pg_temp.am_id(104),'active');
insert into public.platform_roles(id,code,name,status,max_scope_kind) values
 (pg_temp.am_id(40),'am_routine_manager','AM gestor de rotina','active','platform'),
 (pg_temp.am_id(41),'am_routine_reader','AM leitor de rotina','active','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select pg_temp.am_id(40),p.id,'allow'::public.permission_effect,'active' from public.platform_permissions p where p.code in('routine.read','routine.manage_models');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select pg_temp.am_id(41),p.id,'allow'::public.permission_effect,'active' from public.platform_permissions p where p.code='routine.read';
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required) values
 (pg_temp.am_id(701),pg_temp.am_id(40),'active','platform',false),
 (pg_temp.am_id(702),pg_temp.am_id(41),'active','platform',false);
insert into public.routine_models(id,institution_id,origin_scope,name,status,management_version,created_by_person_id) values
 (pg_temp.am_id(801),pg_temp.am_id(10),'institution','AM rotina ativa','active',3,pg_temp.am_id(701)),
 (pg_temp.am_id(802),pg_temp.am_id(10),'institution','AM rotina rascunho','draft',0,pg_temp.am_id(701)),
 (pg_temp.am_id(803),pg_temp.am_id(10),'institution','AM rotina ja arquivada','archived',1,pg_temp.am_id(701));

create temporary table am(key text primary key,value jsonb);
grant select,insert on am to authenticated;

-- ---------------------------------------------------------------------------
-- Atividade: Owner platform arquiva A com versao correta
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.am_id(101),'session_id',pg_temp.am_id(201),
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into am values('a_archive',public.superadmin_activity_template_archive_v1(pg_temp.am_id(601),0,pg_temp.am_id(901)));
insert into am values('a_archive_replay',public.superadmin_activity_template_archive_v1(pg_temp.am_id(601),0,pg_temp.am_id(901)));
insert into am values('a_directory',public.superadmin_activity_template_directory_v1(pg_temp.am_id(10)));
insert into am values('a_options',public.superadmin_activity_template_options(pg_temp.am_id(10)));
reset role;
select is((select value->>'status' from am where key='a_archive'),'archived','archive devolve status archived');
select is((select (value->>'management_version')::int from am where key='a_archive'),1,'archive incrementa management_version');
select is((select value from am where key='a_archive_replay'),(select value from am where key='a_archive'),'replay da mesma chave devolve o mesmo resultado');
select is((select status::text from public.activity_templates where id=pg_temp.am_id(601)),'archived','linha do modelo arquivada');
select is((select template_payload#>>'{lifecycle,archived_from}' from public.activity_templates where id=pg_temp.am_id(601)),'active','status anterior guardado no payload');
select is((select count(*)::int from app_private.superadmin_internal_activity_template_lifecycle_receipts where template_id=pg_temp.am_id(601)),1,'um recibo por chave (replay nao duplica)');
select ok((select audit_record.actor_kind='superadmin_internal' and audit_record.actor_internal_identity_id=pg_temp.am_id(301)
  and audit_record.object_id=pg_temp.am_id(601) and audit_record.institution_id=pg_temp.am_id(10)
  from audit.audit_logs audit_record where audit_record.action_code='activity.template.archive' and audit_record.object_id=pg_temp.am_id(601)),
  'auditoria interna do archive com ator, objeto e instituicao');
select ok((select bool_or(item->>'id'=pg_temp.am_id(601)::text and item->>'status'='archived' and (item->>'management_version')::int=1)
  from am, jsonb_array_elements(value->'templates') item where key='a_directory'),'diretorio v1 lista o modelo arquivado com management_version');
select ok((select bool_and(item->>'id'<>pg_temp.am_id(601)::text) from am, jsonb_array_elements(value->'templates') item where key='a_options'),
  'opcoes do formulario nao devolvem o modelo arquivado');

-- Estado invalido (ja arquivado) e versao defasada.
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.am_id(101),'session_id',pg_temp.am_id(201),
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
select throws_ok(format($$select public.superadmin_activity_template_archive_v1(%L,1,%L)$$,pg_temp.am_id(601),pg_temp.am_id(902)),
  '55000',null,'arquivar de novo responde 55000');
select throws_ok(format($$select public.superadmin_activity_template_restore_v1(%L,0,%L)$$,pg_temp.am_id(601),pg_temp.am_id(903)),
  'PT409','stale activity template version','restore com versao defasada responde PT409');
select throws_ok(format($$select public.superadmin_activity_template_restore_v1(%L,0,%L)$$,pg_temp.am_id(603),pg_temp.am_id(904)),
  '55000',null,'restore de modelo nao arquivado responde 55000');
select throws_ok(format($$select public.superadmin_activity_template_archive_v1(%L,1,%L)$$,pg_temp.am_id(601),pg_temp.am_id(901)),
  '22023',null,'reuso da chave com outro pedido responde 22023');
-- Restore com versao correta volta ao status anterior.
insert into am values('a_restore',public.superadmin_activity_template_restore_v1(pg_temp.am_id(601),1,pg_temp.am_id(905)));
reset role;
select is((select value->>'status' from am where key='a_restore'),'active','restore devolve o status anterior');
select is((select (value->>'management_version')::int from am where key='a_restore'),2,'restore incrementa management_version');
select ok((select template_payload ? 'lifecycle' is false from public.activity_templates where id=pg_temp.am_id(601)),'restore limpa o lifecycle do payload');
select is((select status::text from public.activity_templates where id=pg_temp.am_id(601)),'active','linha do modelo ativa novamente');

-- Escopo: ator restrito a A nao alcanca B nem o modelo Coelo (P0002, sem enumerar).
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.am_id(102),'session_id',pg_temp.am_id(202),
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
select throws_ok(format($$select public.superadmin_activity_template_archive_v1(%L,0,%L)$$,pg_temp.am_id(602),pg_temp.am_id(906)),
  'P0002',null,'ator de A nao arquiva modelo de B');
select throws_ok(format($$select public.superadmin_activity_template_archive_v1(%L,0,%L)$$,pg_temp.am_id(603),pg_temp.am_id(907)),
  'P0002',null,'ator de A nao arquiva modelo Coelo (platform)');
insert into am values('a_scoped_archive',public.superadmin_activity_template_archive_v1(pg_temp.am_id(601),2,pg_temp.am_id(908)));
reset role;
select is((select value->>'status' from am where key='a_scoped_archive'),'archived','ator restrito a A arquiva o modelo de A');
select is((select status::text from public.activity_templates where id=pg_temp.am_id(602)),'active','modelo de B intocado');
select is((select status::text from public.activity_templates where id=pg_temp.am_id(603)),'active','modelo Coelo intocado');
-- Sem sessao / anon.
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
select throws_ok(format($$select public.superadmin_activity_template_archive_v1(%L,0,%L)$$,pg_temp.am_id(602),pg_temp.am_id(909)),
  '42501',null,'sem sessao interna e negado');
reset role;

-- ---------------------------------------------------------------------------
-- Rotina: gestor arquiva/restaura; leitor nao; diretorio exclui arquivados
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.am_id(103),'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into am values('r_default_before',public.superadmin_routine_directory('model','',null,pg_temp.am_id(10),null,null,20,0));
insert into am values('r_archive',public.superadmin_routine_model_archive_v1(pg_temp.am_id(911),pg_temp.am_id(802),0));
insert into am values('r_archive_replay',public.superadmin_routine_model_archive_v1(pg_temp.am_id(911),pg_temp.am_id(802),0));
insert into am values('r_default_after',public.superadmin_routine_directory('model','',null,pg_temp.am_id(10),null,null,20,0));
insert into am values('r_archived_list',public.superadmin_routine_directory('model','','archived',pg_temp.am_id(10),null,null,20,0));
insert into am values('r_active_list',public.superadmin_routine_directory('model','','active',pg_temp.am_id(10),null,null,20,0));
reset role;
select is((select (value->>'total')::int from am where key='r_default_before'),2,'lista padrao antes: 2 (ativa + rascunho; a ja arquivada fica fora)');
select is((select value->>'status' from am where key='r_archive'),'archived','archive de rotina devolve archived');
select is((select (value->>'management_version')::int from am where key='r_archive'),1,'archive de rotina incrementa management_version');
select is((select value from am where key='r_archive_replay'),(select value from am where key='r_archive'),'replay por request_id devolve a mesma resposta');
select is((select (value->>'total')::int from am where key='r_default_after'),1,'lista padrao depois: so a ativa');
select is((select (value->>'total')::int from am where key='r_archived_list'),2,'p_status=archived devolve os dois arquivados');
select is((select (value->>'total')::int from am where key='r_active_list'),1,'p_status=active continua filtrando');
select is((select archived_from from app_private.routine_model_lifecycle where model_id=pg_temp.am_id(802)),'draft','status anterior (draft) guardado');
select is((select count(*)::int from app_private.routine_command_receipts where request_id=pg_temp.am_id(911)),1,'recibo unico do archive');
select ok((select before_json->>'status'='draft' and after_json->>'status'='archived' and actor_person_id=pg_temp.am_id(701)
  from audit.audit_logs where action_code='routine.model.archive' and object_id=pg_temp.am_id(802)),'auditoria do archive de rotina com before/after');

select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.am_id(103),'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_ok(format($$select public.superadmin_routine_model_archive_v1(%L,%L,0)$$,pg_temp.am_id(912),pg_temp.am_id(801)),
  'PT409','stale routine model version','archive de rotina com versao defasada responde PT409');
select throws_ok(format($$select public.superadmin_routine_model_archive_v1(%L,%L,1)$$,pg_temp.am_id(913),pg_temp.am_id(802)),
  '55000',null,'arquivar rotina ja arquivada responde 55000');
select throws_ok(format($$select public.superadmin_routine_model_restore_v1(%L,%L,3)$$,pg_temp.am_id(914),pg_temp.am_id(801)),
  '55000',null,'restaurar rotina nao arquivada responde 55000');
insert into am values('r_restore',public.superadmin_routine_model_restore_v1(pg_temp.am_id(915),pg_temp.am_id(802),1));
insert into am values('r_restore_legacy',public.superadmin_routine_model_restore_v1(pg_temp.am_id(916),pg_temp.am_id(803),1));
reset role;
select is((select value->>'status' from am where key='r_restore'),'draft','restore devolve o status anterior (draft)');
select is((select value->>'status' from am where key='r_restore_legacy'),'active','modelo arquivado pelo save antigo restaura como active');
select is((select count(*)::int from app_private.routine_model_lifecycle where model_id=pg_temp.am_id(802)),0,'restore remove o registro de ciclo de vida');
select is((select status from public.routine_models where id=pg_temp.am_id(801)),'active','modelo com versao defasada nao mudou');

-- Leitor de rotina: 42501; sem sessao: 42501.
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.am_id(104),'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_ok(format($$select public.superadmin_routine_model_archive_v1(%L,%L,3)$$,pg_temp.am_id(917),pg_temp.am_id(801)),
  '42501',null,'leitor de rotina nao arquiva');
reset role;
select is((select status from public.routine_models where id=pg_temp.am_id(801)),'active','negativa do leitor nao muta');

select * from finish();
rollback;
