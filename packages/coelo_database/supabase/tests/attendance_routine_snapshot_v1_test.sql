-- Prova pgTAP da migration 20260916183000_attendance_routine_snapshot_v1
-- (R14 Sessao 10, ADR 0041 B3 / owner.r12-06): snapshot hibrido da rotina na chamada.
-- Fixture sintetica com rollback total; RPCs publicas executadas como authenticated.
-- Cobre: esquema/grants, rotina vigente (mais especifica), chamada aberta segue a
-- vigente, concluir grava o snapshot, nova revisao nao muda o snapshot, reabrir +
-- concluir preserva, legado sem snapshot mostra "rotina atual", chamada sem rotina
-- concluida marca "none", historico projeta a mesma regra, versao defasada -> PT409.
begin;
create extension if not exists pgtap with schema extensions;
select plan(43);

create function pg_temp.rs_id(n integer) returns uuid language sql immutable as $$
  select ('8f1b0000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.rs_id(integer) to authenticated, anon;

-- ---------------------------------------------------------------------------
-- Esquema e grants
-- ---------------------------------------------------------------------------
select has_column('public','attendance_sessions','routine_snapshot_application_id','snapshot application column exists');
select has_column('public','attendance_sessions','routine_snapshot_revision_no','snapshot revision column exists');
select has_column('public','attendance_sessions','routine_snapshot_name','snapshot name column exists');
select has_column('public','attendance_sessions','routine_snapshot_at','snapshot timestamp column exists');
select has_function('app_private','attendance_effective_routine',array['uuid','uuid','uuid','uuid','date'],'effective routine helper exists');
select ok(not has_function_privilege('authenticated','app_private.attendance_effective_routine(uuid,uuid,uuid,uuid,date)','execute')
  and not has_function_privilege('anon','app_private.attendance_effective_routine(uuid,uuid,uuid,uuid,date)','execute'),
  'effective routine helper has no client grant');
select ok(has_function_privilege('authenticated','public.superadmin_attendance_complete_call(uuid,bigint,uuid)','execute')
  and not has_function_privilege('authenticated','app_private.superadmin_attendance_complete_call(uuid,bigint,uuid)','execute'),
  'complete_call keeps the wrapper-only grant');
select ok((select bool_and(p.prosecdef and coalesce(array_to_string(p.proconfig,','),'')='search_path=""')
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='app_private' and p.proname in ('attendance_effective_routine','attendance_call_payload',
    'superadmin_attendance_complete_call','attendance_require_call','superadmin_attendance_undo_bulk',
    'superadmin_attendance_call_history_v1')),
  'replaced functions keep security definer and empty search_path');
select ok((select prosrc not like '%40001%' from pg_proc where oid='app_private.attendance_require_call(uuid,bigint,boolean)'::regprocedure)
  and (select prosrc not like '%40001%' from pg_proc where oid='app_private.superadmin_attendance_undo_bulk(uuid,uuid,bigint)'::regprocedure),
  'no attendance function raises 40001 anymore (OQ-047)');

-- ---------------------------------------------------------------------------
-- Catalogos minimos + fixture (instituicao A com rotina; instituicao B sem rotina)
-- ---------------------------------------------------------------------------
insert into public.institution_types(id,code,name,status) values (pg_temp.rs_id(1),'rs-type','RS type','active');
insert into public.unit_types(id,code,name,status) values (pg_temp.rs_id(2),'rs-unit','RS unit','active');
insert into public.platform_roles(id,code,name,status,is_system) values (pg_temp.rs_id(3),'rs_owner','RS owner','active',true)
on conflict do nothing;
insert into public.platform_permissions(code,module_code,module_label,screen_code,screen_label,action_code,action_label,description,risk_level,requires_mfa) values
 ('attendance.read','attendance','Assiduidade','attendance_calls','Chamadas','read','Ver','Visualizar chamadas.','high',false),
 ('attendance.manage','attendance','Assiduidade','attendance_calls','Chamadas','manage','Gerenciar','Gerir chamadas.','high',false)
on conflict (code) do nothing;
insert into public.people(id,person_type,first_name,last_name,display_name)
select 'c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema'
where not exists (select 1 from public.people where id='c0e10000-0000-4000-8000-000000000001');

insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 (pg_temp.rs_id(10),pg_temp.rs_id(1),'RS A','rs-a','active'),
 (pg_temp.rs_id(20),pg_temp.rs_id(1),'RS B','rs-b','active');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status) values
 (pg_temp.rs_id(11),pg_temp.rs_id(10),'Unidade A1','rs-unidade-a1','rsunidade.a1',pg_temp.rs_id(2),'active'),
 (pg_temp.rs_id(21),pg_temp.rs_id(20),'Unidade B1','rs-unidade-b1','rsunidade.b1',pg_temp.rs_id(2),'active');
insert into public.groups(id,institution_id,unit_id,name,status) values
 (pg_temp.rs_id(12),pg_temp.rs_id(10),pg_temp.rs_id(11),'Turma A1','active'),
 (pg_temp.rs_id(13),pg_temp.rs_id(10),pg_temp.rs_id(11),'Turma A2','active'),
 (pg_temp.rs_id(22),pg_temp.rs_id(20),pg_temp.rs_id(21),'Turma B1','active');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 (pg_temp.rs_id(121),'authenticated','authenticated','rs-121@invalid.test',now(),now(),now(),'{}','{}');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.rs_id(221),'adult','RS','Owner','RS owner','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values (pg_temp.rs_id(221),pg_temp.rs_id(121),'active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
values (pg_temp.rs_id(221),pg_temp.rs_id(3),'active','platform',false);
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select pg_temp.rs_id(3),p.id,'allow'::public.permission_effect,'active' from public.platform_permissions p
where p.code in('attendance.read','attendance.manage')
on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null;

-- Criancas 301..302 na turma A1; 304 na turma B1.
insert into public.people(id,person_type,first_name,last_name,display_name,status,date_of_birth)
select pg_temp.rs_id(n),'child','Crianca','RS','Crianca '||n,'active',date '2020-01-01' from unnest(array[301,302,304]) n;
insert into public.child_contexts(id,child_person_id,institution_id,status) values
 (pg_temp.rs_id(311),pg_temp.rs_id(301),pg_temp.rs_id(10),'active'),
 (pg_temp.rs_id(312),pg_temp.rs_id(302),pg_temp.rs_id(10),'active'),
 (pg_temp.rs_id(314),pg_temp.rs_id(304),pg_temp.rs_id(20),'active');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
 (pg_temp.rs_id(321),pg_temp.rs_id(311),pg_temp.rs_id(11),'active',pg_temp.rs_id(221),now()),
 (pg_temp.rs_id(322),pg_temp.rs_id(312),pg_temp.rs_id(11),'active',pg_temp.rs_id(221),now()),
 (pg_temp.rs_id(324),pg_temp.rs_id(314),pg_temp.rs_id(21),'active',pg_temp.rs_id(221),now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status) values
 (pg_temp.rs_id(331),pg_temp.rs_id(321),pg_temp.rs_id(12),'active'),
 (pg_temp.rs_id(332),pg_temp.rs_id(322),pg_temp.rs_id(12),'active'),
 (pg_temp.rs_id(334),pg_temp.rs_id(324),pg_temp.rs_id(22),'active');

-- Rotinas da instituicao A: modelo "Rotina Bercario" (versao 1); aplicacao 601 na
-- instituicao (revisao 1) e aplicacao 602 na turma A1 (revisoes 1 e 2). A turma A2 so
-- herda a da instituicao.
insert into public.routine_models(id,institution_id,origin_scope,name,status,created_by_person_id) values
 (pg_temp.rs_id(500),pg_temp.rs_id(10),'institution','Rotina Bercario','active',pg_temp.rs_id(221));
insert into public.routine_model_versions(id,model_id,version,created_by_person_id,published_at) values
 (pg_temp.rs_id(501),pg_temp.rs_id(500),1,pg_temp.rs_id(221),now());
update public.routine_models set current_version_id=pg_temp.rs_id(501) where id=pg_temp.rs_id(500);
insert into public.routine_applications(id,institution_id,unit_id,group_id,scope_kind,source_model_version_id,status,created_by_person_id) values
 (pg_temp.rs_id(601),pg_temp.rs_id(10),null,null,'institution',pg_temp.rs_id(501),'active',pg_temp.rs_id(221)),
 (pg_temp.rs_id(602),pg_temp.rs_id(10),pg_temp.rs_id(11),pg_temp.rs_id(12),'group',pg_temp.rs_id(501),'active',pg_temp.rs_id(221));
insert into public.routine_application_revisions(application_id,revision_no,source_model_version_id,created_by_person_id) values
 (pg_temp.rs_id(601),1,pg_temp.rs_id(501),pg_temp.rs_id(221)),
 (pg_temp.rs_id(602),1,pg_temp.rs_id(501),pg_temp.rs_id(221)),
 (pg_temp.rs_id(602),2,pg_temp.rs_id(501),pg_temp.rs_id(221));

-- Legado: chamada concluida ANTES do snapshot existir (turma A1, ontem).
insert into public.attendance_sessions(id,institution_id,unit_id,group_id,session_kind,session_date,status,created_by_person_id,closed_by_person_id,closed_at) values
 (pg_temp.rs_id(701),pg_temp.rs_id(10),pg_temp.rs_id(11),pg_temp.rs_id(12),'group',current_date-1,'closed',pg_temp.rs_id(221),pg_temp.rs_id(221),now()-interval '1 day');

-- ---------------------------------------------------------------------------
-- Rotina vigente (helper privado, como postgres)
-- ---------------------------------------------------------------------------
select is((select (app_private.attendance_effective_routine(pg_temp.rs_id(10),pg_temp.rs_id(11),pg_temp.rs_id(12),null,current_date))->>'application_id'),
  pg_temp.rs_id(602)::text,'group routine wins over the institution routine');
select is((select (app_private.attendance_effective_routine(pg_temp.rs_id(10),pg_temp.rs_id(11),pg_temp.rs_id(12),null,current_date))->>'revision_no'),
  '2','effective revision is the latest application revision');
select is((select (app_private.attendance_effective_routine(pg_temp.rs_id(10),pg_temp.rs_id(11),pg_temp.rs_id(12),null,current_date))->>'name'),
  'Rotina Bercario','routine name comes from the source model');
select is((select (app_private.attendance_effective_routine(pg_temp.rs_id(10),pg_temp.rs_id(11),pg_temp.rs_id(13),null,current_date))->>'application_id'),
  pg_temp.rs_id(601)::text,'a group without its own routine inherits the institution routine');
select is((select app_private.attendance_effective_routine(pg_temp.rs_id(20),pg_temp.rs_id(21),pg_temp.rs_id(22),null,current_date)),
  null,'institution without routine has no effective routine');

create temporary table rs(key text primary key,value jsonb);
grant select,insert,update on rs to authenticated;
create function pg_temp.rs_get(k text) returns jsonb language sql stable as $$ select value from rs where key=k $$;
grant execute on function pg_temp.rs_get(text) to authenticated;
create function pg_temp.rs_uuid(k text, path text) returns uuid language sql stable as $$ select (value #>> string_to_array(path,'.'))::uuid from rs where key=k $$;
grant execute on function pg_temp.rs_uuid(text,text) to authenticated;
create function pg_temp.rs_int(k text, path text) returns bigint language sql stable as $$ select (value #>> string_to_array(path,'.'))::bigint from rs where key=k $$;
grant execute on function pg_temp.rs_int(text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- Fluxo: criar -> (aberta segue a vigente) -> marcar -> concluir (snapshot)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"8f1b0000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into rs values('k_create',to_jsonb(public.attendance_reserve_idempotency_key('create_call',null,null,
  jsonb_build_object('institution_id',pg_temp.rs_id(10),'unit_id',pg_temp.rs_id(11),'group_id',pg_temp.rs_id(12),'activity_id',null,'session_date',current_date))));
insert into rs values('create',public.superadmin_attendance_create_call(pg_temp.rs_id(10),pg_temp.rs_id(11),pg_temp.rs_id(12),null,current_date,(pg_temp.rs_get('k_create')#>>'{}')::uuid));
insert into rs values('k_mark',to_jsonb(public.attendance_reserve_idempotency_key('mark_remaining_present',pg_temp.rs_uuid('create','id'),pg_temp.rs_int('create','version'),null)));
insert into rs values('mark',public.superadmin_attendance_mark_remaining_present(pg_temp.rs_uuid('create','id'),pg_temp.rs_int('create','version'),(pg_temp.rs_get('k_mark')#>>'{}')::uuid));
insert into rs values('k_complete',to_jsonb(public.attendance_reserve_idempotency_key('complete_call',pg_temp.rs_uuid('create','id'),pg_temp.rs_int('mark','call.version'),null)));
insert into rs values('complete',public.superadmin_attendance_complete_call(pg_temp.rs_uuid('create','id'),pg_temp.rs_int('mark','call.version'),(pg_temp.rs_get('k_complete')#>>'{}')::uuid));
reset role;

select ok((select value ?& array['routine_snapshot','routine_current','routine_source'] from rs where key='create'),'call payload exposes the three routine keys');
select is((select value->>'routine_source' from rs where key='create'),'current','open call follows the effective routine');
select is((select value->'routine_current'->>'revision_no' from rs where key='create'),'2','open call reports the effective revision');
select is((select value->'routine_snapshot' from rs where key='create'),'null'::jsonb,'open call has no snapshot yet');
select is((select value->>'status' from rs where key='complete'),'closed','call completed');
select is((select value->>'routine_source' from rs where key='complete'),'snapshot','completed call reports the snapshot');
select is((select value->'routine_snapshot'->>'application_id' from rs where key='complete'),pg_temp.rs_id(602)::text,'snapshot keeps the group routine id');
select is((select value->'routine_snapshot'->>'revision_no' from rs where key='complete'),'2','snapshot keeps the revision at completion');
select is((select value->'routine_snapshot'->>'name' from rs where key='complete'),'Rotina Bercario','snapshot keeps the routine name');
select ok((select value->'routine_snapshot'->>'recorded_at' is not null from rs where key='complete'),'snapshot records when it was taken');
select ok((select exists(select 1 from audit.audit_logs where action_code='attendance.call.complete'
  and after_json->>'scope_id'=pg_temp.rs_id(602)::text and after_json->>'management_version'='2')),
  'completion audit carries the snapshot routine id and revision (allowlisted keys)');

-- A rotina evolui (revisao 3) depois da conclusao: o snapshot nao muda; a vigente sim.
insert into public.routine_application_revisions(application_id,revision_no,source_model_version_id,created_by_person_id) values
 (pg_temp.rs_id(602),3,pg_temp.rs_id(501),pg_temp.rs_id(221));

select set_config('request.jwt.claims','{"sub":"8f1b0000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into rs values('detail_after_rev',public.superadmin_attendance_call_detail(pg_temp.rs_uuid('create','id')));
-- Reabrir para corrigir presenca e concluir de novo: snapshot preservado.
insert into rs values('reopen',public.superadmin_attendance_reopen_call(pg_temp.rs_uuid('create','id'),pg_temp.rs_int('complete','version'),'Corrigir presença'));
insert into rs values('correct',public.superadmin_attendance_correct_participant(pg_temp.rs_uuid('create','id'),pg_temp.rs_id(311),'absent','Faltou de fato',pg_temp.rs_int('reopen','version')));
insert into rs values('k_complete2',to_jsonb(public.attendance_reserve_idempotency_key('complete_call',pg_temp.rs_uuid('create','id'),pg_temp.rs_int('correct','version'),null)));
insert into rs values('complete2',public.superadmin_attendance_complete_call(pg_temp.rs_uuid('create','id'),pg_temp.rs_int('correct','version'),(pg_temp.rs_get('k_complete2')#>>'{}')::uuid));
-- Legado e chamada sem rotina (instituicao B).
insert into rs values('legacy',public.superadmin_attendance_call_detail(pg_temp.rs_id(701)));
insert into rs values('k_create_b',to_jsonb(public.attendance_reserve_idempotency_key('create_call',null,null,
  jsonb_build_object('institution_id',pg_temp.rs_id(20),'unit_id',pg_temp.rs_id(21),'group_id',pg_temp.rs_id(22),'activity_id',null,'session_date',current_date))));
insert into rs values('create_b',public.superadmin_attendance_create_call(pg_temp.rs_id(20),pg_temp.rs_id(21),pg_temp.rs_id(22),null,current_date,(pg_temp.rs_get('k_create_b')#>>'{}')::uuid));
insert into rs values('k_mark_b',to_jsonb(public.attendance_reserve_idempotency_key('mark_remaining_present',pg_temp.rs_uuid('create_b','id'),pg_temp.rs_int('create_b','version'),null)));
insert into rs values('mark_b',public.superadmin_attendance_mark_remaining_present(pg_temp.rs_uuid('create_b','id'),pg_temp.rs_int('create_b','version'),(pg_temp.rs_get('k_mark_b')#>>'{}')::uuid));
insert into rs values('k_complete_b',to_jsonb(public.attendance_reserve_idempotency_key('complete_call',pg_temp.rs_uuid('create_b','id'),pg_temp.rs_int('mark_b','call.version'),null)));
insert into rs values('complete_b',public.superadmin_attendance_complete_call(pg_temp.rs_uuid('create_b','id'),pg_temp.rs_int('mark_b','call.version'),(pg_temp.rs_get('k_complete_b')#>>'{}')::uuid));
insert into rs values('history',public.superadmin_attendance_call_history_v1());
reset role;

select is((select value->'routine_snapshot'->>'revision_no' from rs where key='detail_after_rev'),'2','a newer routine revision does not rewrite the snapshot');
select is((select value->'routine_current'->>'revision_no' from rs where key='detail_after_rev'),'3','the current routine reports the newer revision');
select is((select value->>'routine_source' from rs where key='detail_after_rev'),'snapshot','detail keeps showing the snapshot');
select is((select value->>'status' from rs where key='reopen'),'reopened','call reopened');
select is((select value->'routine_snapshot'->>'revision_no' from rs where key='reopen'),'2','reopening preserves the snapshot');
select is((select value->>'routine_source' from rs where key='reopen'),'snapshot','reopened call still reports the snapshot, not the current routine');
select is((select value->>'status' from rs where key='complete2'),'closed','call completed again');
select is((select value->'routine_snapshot'->>'revision_no' from rs where key='complete2'),'2','completing again after reopen preserves the snapshot revision');
select is((select value->'routine_snapshot'->>'recorded_at' from rs where key='complete2'),(select value->'routine_snapshot'->>'recorded_at' from rs where key='complete'),
  'completing again preserves the original snapshot timestamp');
select is((select value->>'routine_source' from rs where key='legacy'),'current','legacy completed call without snapshot shows the current routine');
select is((select value->'routine_current'->>'revision_no' from rs where key='legacy'),'3','legacy call reports the current revision');
select is((select value->>'routine_source' from rs where key='complete_b'),'none','completed call without any routine reports none');
select ok((select routine_snapshot_at is not null and routine_snapshot_application_id is null from public.attendance_sessions where id=pg_temp.rs_uuid('create_b','id')),
  'call without routine still records the snapshot moment (distinct from legacy)');
select is((select item->'routine'->>'source' from rs, jsonb_array_elements(value->'items') item where key='history' and item->>'id'=pg_temp.rs_uuid('create','id')::text),
  'snapshot','history projects the snapshot for the completed call');
select is((select item->'routine'->>'revision_no' from rs, jsonb_array_elements(value->'items') item where key='history' and item->>'id'=pg_temp.rs_uuid('create','id')::text),
  '2','history keeps the snapshot revision');
select is((select item->'routine'->>'source' from rs, jsonb_array_elements(value->'items') item where key='history' and item->>'id'=pg_temp.rs_id(701)::text),
  'current','history projects the current routine for the legacy call');
select is((select item->'routine'->>'source' from rs, jsonb_array_elements(value->'items') item where key='history' and item->>'id'=pg_temp.rs_uuid('create_b','id')::text),
  'none','history projects none for the call without routine');

-- ---------------------------------------------------------------------------
-- Versao defasada -> PT409 (nunca 40001)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"8f1b0000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select throws_ok(format('select public.superadmin_attendance_reopen_call(%L,%s,%L)',pg_temp.rs_uuid('create','id'),1,'Versão velha'),
  'PT409','attendance call version conflict','stale expected version answers PT409, not 40001');
reset role;

select * from finish();
rollback;
