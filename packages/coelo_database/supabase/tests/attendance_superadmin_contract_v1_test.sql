-- Prova pgTAP do pacote 20260911220100_attendance_superadmin_contract_v1:
-- as catorze RPCs que o cliente Flutter de Assiduidade chama. Fixture
-- sintetica com rollback total; RPCs publicas executadas como authenticated.
-- Cobre: grants minimos, ator com attendance.manage, negativa cross-tenant,
-- anon e sem sessao, criar chamada -> marcar -> lote -> desfazer -> concluir ->
-- corrigir -> reabrir -> confirmar aviso, idempotencia por chave reservada,
-- conflito de versao, dashboard e exportacao adiada.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.at_id(n integer) returns uuid language sql immutable as $$
  select ('8f190000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.at_id(integer) to authenticated, anon;

-- ---------------------------------------------------------------------------
-- Estrutura e grants
-- ---------------------------------------------------------------------------
select has_function('public','superadmin_attendance_directory',array['date'],'directory exists');
select has_function('public','superadmin_attendance_call_detail',array['uuid'],'call_detail exists');
select has_function('public','superadmin_attendance_create_call',array['uuid','uuid','uuid','uuid','date','uuid'],'create_call exists');
select has_function('public','superadmin_attendance_set_participant',array['uuid','uuid','uuid','text','bigint'],'set_participant exists');
select has_function('public','superadmin_attendance_correct_participant',array['uuid','uuid','text','text','bigint'],'correct_participant exists');
select has_function('public','superadmin_attendance_complete_call',array['uuid','bigint','uuid'],'complete_call exists');
select has_function('public','superadmin_attendance_reopen_call',array['uuid','bigint','text'],'reopen_call exists');
select has_function('public','superadmin_attendance_mark_remaining_present',array['uuid','bigint','uuid'],'mark_remaining_present exists');
select has_function('public','superadmin_attendance_clear_presence_marks',array['uuid','bigint','uuid'],'clear_presence_marks exists');
select has_function('public','superadmin_attendance_undo_bulk',array['uuid','uuid','bigint'],'undo_bulk exists');
select has_function('public','superadmin_attendance_confirm_notice',array['uuid','bigint'],'confirm_notice exists');
select has_function('public','attendance_dashboard_read',array['date','date','text','uuid','uuid','uuid','uuid','uuid','text','text[]','uuid','text','boolean','integer','integer','text'],'dashboard_read exists');
select has_function('public','attendance_dashboard_ranking_page',array['date','date','uuid','uuid','uuid','uuid','uuid','text','text','integer','integer'],'ranking_page exists');
select has_function('public','attendance_dashboard_request_export',array['uuid','text','text','jsonb'],'request_export exists');
select has_column('public','attendance_sessions','version','attendance_sessions.version exists');
select has_table('app_private','attendance_bulk_operations','bulk operations receipt table exists');

select ok((
  select bool_and(has_function_privilege('authenticated',p.oid,'execute')
    and not has_function_privilege('anon',p.oid,'execute')
    and not has_function_privilege('service_role',p.oid,'execute'))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and (p.proname like 'superadmin\_attendance\_%' or p.proname like 'attendance\_dashboard\_%')
    and p.proname not in ('attendance_dashboard_access','superadmin_attendance_context_options')
), 'public wrappers: authenticated only, no anon/service_role');
select ok((
  select bool_and(not has_function_privilege('authenticated',p.oid,'execute')
    and not has_function_privilege('anon',p.oid,'execute')
    and not has_function_privilege('service_role',p.oid,'execute'))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='app_private' and (p.proname like 'superadmin\_attendance\_%' or p.proname like 'attendance\_%')
    and p.proname not in ('attendance_reserve_idempotency_key','attendance_intent_digest')
), 'app_private attendance logic has no client grant');
select ok((
  select bool_and(p.prosecdef and coalesce(array_to_string(p.proconfig,','),'') like '%search_path=%')
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','app_private') and (p.proname like 'superadmin\_attendance\_%' or p.proname like 'attendance\_dashboard\_%')
    and p.proname not in ('attendance_dashboard_access','superadmin_attendance_context_options')
), 'all new functions are security definer with fixed search_path');
select ok(not has_table_privilege('authenticated','app_private.attendance_bulk_operations','select'),'bulk receipts are never readable by the browser');
select ok((select p.prosecdef from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='attendance_reserve_idempotency_key'),'reserve wrapper is security definer (production drift fixed)');
select ok(has_function_privilege('authenticated','public.attendance_reserve_idempotency_key(text,uuid,bigint,jsonb)','execute') and not has_function_privilege('anon','public.attendance_reserve_idempotency_key(text,uuid,bigint,jsonb)','execute'),'reserve wrapper: authenticated only');

-- ---------------------------------------------------------------------------
-- Fixture
-- ---------------------------------------------------------------------------
insert into public.institution_types(id,code,name,status) values (pg_temp.at_id(1),'at5-type','AT5 type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 (pg_temp.at_id(10),pg_temp.at_id(1),'AT5 A','at5-a','active'),
 (pg_temp.at_id(20),pg_temp.at_id(1),'AT5 B','at5-b','active');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status)
select pg_temp.at_id(11),pg_temp.at_id(10),'Unidade A1','at5-unidade-a1','at5unidade.a1',t.id,'active' from public.unit_types t where t.code='sede';
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status)
select pg_temp.at_id(21),pg_temp.at_id(20),'Unidade B1','at5-unidade-b1','at5unidade.b1',t.id,'active' from public.unit_types t where t.code='sede';
insert into public.groups(id,institution_id,unit_id,name,status) values
 (pg_temp.at_id(12),pg_temp.at_id(10),pg_temp.at_id(11),'Turma A1','active'),
 (pg_temp.at_id(22),pg_temp.at_id(20),pg_temp.at_id(21),'Turma B1','active');

-- Adultos: 221 owner de plataforma (usuario 121); 222 sem permissao (122);
-- 223 gestor contextual da instituicao B (123); 224 responsavel familiar.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select pg_temp.at_id(n),'authenticated','authenticated','at5-'||n||'@invalid.test',now(),now(),now(),'{}','{}' from unnest(array[121,122,123]) n;
insert into public.people(id,person_type,first_name,last_name,display_name,status)
select pg_temp.at_id(n),'adult','AT5','Adulto','AT5 adulto '||n,'active' from unnest(array[221,222,223,224]) n;
insert into public.person_auth_links(person_id,auth_user_id,status) values
 (pg_temp.at_id(221),pg_temp.at_id(121),'active'),(pg_temp.at_id(222),pg_temp.at_id(122),'active'),
 (pg_temp.at_id(223),pg_temp.at_id(123),'active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select pg_temp.at_id(221),r.id,'active','platform',false from public.platform_roles r where r.code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow'::public.permission_effect,'active' from public.platform_roles r cross join public.platform_permissions p
where r.code='owner' and p.code in('attendance.read','attendance.manage')
on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null;

-- Gestor contextual de B com attendance.manage no escopo da instituicao.
insert into public.institution_roles(id,institution_id,code,name,status,max_scope_kind) values
 (pg_temp.at_id(40),pg_temp.at_id(20),'at5_manager','AT5 gestor','active','institution');
insert into public.institution_role_permissions(role_id,permission_id,effect,status)
select pg_temp.at_id(40),p.id,'allow','active' from public.institution_permissions p where p.code in('attendance.read','attendance.manage');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status) values
 (pg_temp.at_id(41),pg_temp.at_id(223),pg_temp.at_id(20),'at5_manager','active');
insert into public.institution_role_assignments(membership_id,role_id,scope_kind,status) values
 (pg_temp.at_id(41),pg_temp.at_id(40),'institution','active');

-- Criancas: 301..303 na turma A1; 304 na turma B1.
insert into public.people(id,person_type,first_name,last_name,display_name,status,date_of_birth)
select pg_temp.at_id(n),'child','Crianca','AT5','Crianca '||chr(64+n-300),'active',date '2020-01-01' from unnest(array[301,302,303,304]) n;
insert into public.child_contexts(id,child_person_id,institution_id,status) values
 (pg_temp.at_id(311),pg_temp.at_id(301),pg_temp.at_id(10),'active'),
 (pg_temp.at_id(312),pg_temp.at_id(302),pg_temp.at_id(10),'active'),
 (pg_temp.at_id(313),pg_temp.at_id(303),pg_temp.at_id(10),'active'),
 (pg_temp.at_id(314),pg_temp.at_id(304),pg_temp.at_id(20),'active');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
 (pg_temp.at_id(321),pg_temp.at_id(311),pg_temp.at_id(11),'active',pg_temp.at_id(221),now()),
 (pg_temp.at_id(322),pg_temp.at_id(312),pg_temp.at_id(11),'active',pg_temp.at_id(221),now()),
 (pg_temp.at_id(323),pg_temp.at_id(313),pg_temp.at_id(11),'active',pg_temp.at_id(221),now()),
 (pg_temp.at_id(324),pg_temp.at_id(314),pg_temp.at_id(21),'active',pg_temp.at_id(221),now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status) values
 (pg_temp.at_id(331),pg_temp.at_id(321),pg_temp.at_id(12),'active'),
 (pg_temp.at_id(332),pg_temp.at_id(322),pg_temp.at_id(12),'active'),
 (pg_temp.at_id(333),pg_temp.at_id(323),pg_temp.at_id(12),'active'),
 (pg_temp.at_id(334),pg_temp.at_id(324),pg_temp.at_id(22),'active');
insert into public.guardian_links(id,guardian_person_id,child_person_id,relation_type,relationship_type_id,status)
select pg_temp.at_id(341),pg_temp.at_id(224),pg_temp.at_id(301),'mother',t.id,'active' from public.family_relationship_types t where t.code='mother';
insert into public.attendance_notices(id,institution_id,unit_id,group_id,child_context_id,child_group_link_id,guardian_link_id,notice_type,starts_at,reason_detail,created_by_person_id)
values (pg_temp.at_id(351),pg_temp.at_id(10),pg_temp.at_id(11),pg_temp.at_id(12),pg_temp.at_id(311),pg_temp.at_id(331),pg_temp.at_id(341),'absence',date_trunc('day',now()),'Consulta médica',pg_temp.at_id(224));

create temporary table at5(key text primary key,value jsonb);
grant select,insert,update on at5 to authenticated;
create function pg_temp.at5_get(k text) returns jsonb language sql stable as $$ select value from at5 where key=k $$;
grant execute on function pg_temp.at5_get(text) to authenticated;
create function pg_temp.at5_uuid(k text, path text) returns uuid language sql stable as $$ select (value #>> string_to_array(path,'.'))::uuid from at5 where key=k $$;
grant execute on function pg_temp.at5_uuid(text,text) to authenticated, anon;
grant select on at5 to anon;
create function pg_temp.at5_int(k text, path text) returns bigint language sql stable as $$ select (value #>> string_to_array(path,'.'))::bigint from at5 where key=k $$;
grant execute on function pg_temp.at5_int(text,text) to authenticated;
create function pg_temp.at5_state(k text, child uuid) returns text language sql stable as $$
  select p->>'state' from at5, jsonb_array_elements(value->'participants') p where key=k and p->>'participant_id'=child::text $$;
grant execute on function pg_temp.at5_state(text,uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Owner de plataforma: fluxo completo
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"8f190000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;

insert into at5 values('dir0',public.superadmin_attendance_directory(current_date));
insert into at5 values('k_create',to_jsonb(public.attendance_reserve_idempotency_key('create_call',null,null,
  jsonb_build_object('institution_id',pg_temp.at_id(10),'unit_id',pg_temp.at_id(11),'group_id',pg_temp.at_id(12),'activity_id',null,'session_date',current_date))));
insert into at5 values('create',public.superadmin_attendance_create_call(pg_temp.at_id(10),pg_temp.at_id(11),pg_temp.at_id(12),null,current_date,(pg_temp.at5_get('k_create')#>>'{}')::uuid));
insert into at5 values('create_replay',public.superadmin_attendance_create_call(pg_temp.at_id(10),pg_temp.at_id(11),pg_temp.at_id(12),null,current_date,(pg_temp.at5_get('k_create')#>>'{}')::uuid));
insert into at5 values('k_create2',to_jsonb(public.attendance_reserve_idempotency_key('create_call',null,null,
  jsonb_build_object('institution_id',pg_temp.at_id(10),'unit_id',pg_temp.at_id(11),'group_id',pg_temp.at_id(12),'activity_id',null,'session_date',current_date))));
insert into at5 values('detail',public.superadmin_attendance_call_detail(pg_temp.at5_uuid('create','id')));
insert into at5 values('dir1',public.superadmin_attendance_directory(current_date));
reset role;

select ok((select jsonb_typeof(value->'calls')='array' and jsonb_array_length(value->'calls')=0 from at5 where key='dir0'),'directory starts empty for the day');
select ok((select (select array_agg(k order by k) from jsonb_object_keys(value) k)=array['calls','metrics','notices'] from at5 where key='dir0'),'directory payload has calls, notices, metrics');
select ok((select (select array_agg(k order by k) from jsonb_object_keys(value->'metrics') k)
  =array['early_departures','justified_absences','late','presence_percent','unjustified_absences'] from at5 where key='dir0'),'metrics has the five keys the client reads');
select ok((select value ?& array['id','institution_id','institution_name','unit_id','unit_name','group_id','group_name','activity_id','activity_name','session_date','status','participants','responsible','can_manage','updated_at','version','revisions'] from at5 where key='create'),'call payload has every key _call reads');
select is((select value->>'status' from at5 where key='create'),'open','new call is open');
select is((select value->>'version' from at5 where key='create'),'1','new call starts at version 1');
select is((select value->>'institution_id' from at5 where key='create'),pg_temp.at_id(10)::text,'institution derived from the group');
select is((select value->>'unit_id' from at5 where key='create'),pg_temp.at_id(11)::text,'unit derived from the group');
select is((select value->>'group_name' from at5 where key='create'),'Turma A1','group name resolved');
select is((select value->>'can_manage' from at5 where key='create'),'true','owner can manage the call');
select is((select value->>'responsible' from at5 where key='create'),'AT5 adulto 221','responsible is the creator display name');
select is((select jsonb_array_length(value->'participants') from at5 where key='create'),3,'three expected participants from the active group links');
select ok((select bool_and(p ?& array['id','participant_id','name','state','note','justification','notice']) from at5, jsonb_array_elements(value->'participants') p where key='create'),'participant payload has every key _participant reads');
select ok((select bool_and(p->>'state'='unmarked') from at5, jsonb_array_elements(value->'participants') p where key='create'),'participants start unmarked');
select is((select value->>'id' from at5 where key='create_replay'),(select value->>'id' from at5 where key='create'),'same reserved key returns the same call (idempotent receipt)');
select is((select value from at5 where key='create_replay'),(select value from at5 where key='create'),'replay returns the stored receipt verbatim');
select is((select value->>'id' from at5 where key='detail'),(select value->>'id' from at5 where key='create'),'call_detail returns the created call');
select is((select jsonb_array_length(value->'calls') from at5 where key='dir1'),1,'directory lists the call on its day');
select is((select jsonb_array_length(value->'notices') from at5 where key='dir1'),1,'directory lists the pending family notice for the group');
select ok((select value->'notices'->0 ?& array['id','call_id','participant_id','participant_name','intent','reason','start_date','end_date','note','pending'] from at5 where key='dir1'),'notice payload has every key _notice reads');
select is((select value->'notices'->0->>'call_id' from at5 where key='dir1'),(select value->>'id' from at5 where key='create'),'notice resolves to the call of its group and day');
select is((select pg_temp.at5_state('create',pg_temp.at_id(311))),'unmarked','child A unmarked before marking');
select is((select p->>'justification' from at5, jsonb_array_elements(value->'participants') p where key='create' and p->>'participant_id'=pg_temp.at_id(311)::text),'pending','child A carries the pending notice as justification');
select is((select count(*) from app_private.attendance_idempotency_reservations where idempotency_key=(pg_temp.at5_get('k_create')#>>'{}')::uuid and consumed_at is not null and response is not null),1::bigint,'create receipt stored on the reservation');
select is((select count(*) from audit.audit_logs where action_code='attendance.call.create' and object_id=pg_temp.at5_uuid('create','id')),1::bigint,'create audited once (replay did not audit again)');

-- Chamada duplicada com chave nova devolve a existente em vez de criar outra.
select set_config('request.jwt.claims','{"sub":"8f190000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into at5 values('create_dup',public.superadmin_attendance_create_call(pg_temp.at_id(10),pg_temp.at_id(11),pg_temp.at_id(12),null,current_date,(pg_temp.at5_get('k_create2')#>>'{}')::uuid));
reset role;
select is((select value->>'id' from at5 where key='create_dup'),(select value->>'id' from at5 where key='create'),'duplicate context and day returns the existing call');
select is((select count(*) from public.attendance_sessions where group_id=pg_temp.at_id(12)),1::bigint,'only one session exists for the group and day');
select is((select value->>'id' from at5 where key='k_create'),(select value->>'id' from at5 where key='k_create2'),'same intent reserves the same key');

-- Payload divergente: instituicao do payload diferente da turma -> 42501.
select set_config('request.jwt.claims','{"sub":"8f190000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select throws_ok(format('select public.superadmin_attendance_create_call(%L,%L,%L,null,current_date,public.attendance_reserve_idempotency_key(''create_call'',null,null,%L))',
  pg_temp.at_id(20),pg_temp.at_id(11),pg_temp.at_id(12),jsonb_build_object('institution_id',pg_temp.at_id(20),'group_id',pg_temp.at_id(12),'session_date',current_date)),
  '42501',null,'payload institution that disagrees with the group is refused');
select throws_ok(format('select public.superadmin_attendance_create_call(%L,%L,%L,null,current_date,%L)',
  pg_temp.at_id(10),pg_temp.at_id(11),pg_temp.at_id(12),gen_random_uuid()),
  '22023',null,'unreserved idempotency key is refused');

-- Marcar participante (v1 -> v2) e repetir com a mesma chave.
insert into at5 values('k_set1',to_jsonb(public.attendance_reserve_idempotency_key('set_participant',pg_temp.at5_uuid('create','id'),1,null)));
insert into at5 values('set1',public.superadmin_attendance_set_participant((pg_temp.at5_get('k_set1')#>>'{}')::uuid,pg_temp.at5_uuid('create','id'),pg_temp.at_id(311),'present',1));
insert into at5 values('set1_replay',public.superadmin_attendance_set_participant((pg_temp.at5_get('k_set1')#>>'{}')::uuid,pg_temp.at5_uuid('create','id'),pg_temp.at_id(311),'present',1));
reset role;
select is((select value->>'version' from at5 where key='set1'),'2','set_participant bumps version to 2');
select is((select pg_temp.at5_state('set1',pg_temp.at_id(311))),'present','child A is present');
select is((select value from at5 where key='set1_replay'),(select value from at5 where key='set1'),'replaying set_participant with the same key returns the same receipt');
select is((select count(*) from public.attendance_records where attendance_session_id=pg_temp.at5_uuid('create','id') and status='active'),1::bigint,'replay wrote no second record');
select is((select version from public.attendance_sessions where id=pg_temp.at5_uuid('create','id')),2::bigint,'replay did not bump the version again');

-- Versao obsoleta -> 40001.
select set_config('request.jwt.claims','{"sub":"8f190000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
-- Reservar de novo a mesma intencao (mesma versao esperada) devolve a mesma
-- chave, ja consumida: o comando responde o recibo e nao reexecuta.
select is(public.attendance_reserve_idempotency_key('set_participant',pg_temp.at5_uuid('create','id'),1,null),(pg_temp.at5_get('k_set1')#>>'{}')::uuid,'same intent reserves the same consumed key');
select throws_ok(format('select public.superadmin_attendance_correct_participant(%L,%L,''absent'',''teste'',1)',
  pg_temp.at5_uuid('create','id'),pg_temp.at_id(312)),
  '40001',null,'stale expected_version is a version conflict');
select throws_ok(format('select public.superadmin_attendance_reopen_call(%L,1,''teste'')',pg_temp.at5_uuid('create','id')),
  '40001',null,'stale expected_version on reopen is a version conflict');
select throws_ok(format('select public.superadmin_attendance_set_participant(public.attendance_reserve_idempotency_key(''set_participant'',%L,2,null),%L,%L,''sleeping'',2)',
  pg_temp.at5_uuid('create','id'),pg_temp.at5_uuid('create','id'),pg_temp.at_id(312)),
  '22023',null,'unknown presence state is refused');
select throws_ok(format('select public.superadmin_attendance_set_participant(public.attendance_reserve_idempotency_key(''set_participant'',%L,2,null),%L,%L,''present'',2)',
  pg_temp.at5_uuid('create','id'),pg_temp.at5_uuid('create','id'),pg_temp.at_id(314)),
  '22023',null,'child from another institution is not a participant of this call');

-- Lote: marcar restantes (v2 -> v3), desfazer (v3 -> v4), limpar (v4 -> v5).
insert into at5 values('k_bulk1',to_jsonb(public.attendance_reserve_idempotency_key('mark_remaining_present',pg_temp.at5_uuid('create','id'),2,null)));
insert into at5 values('bulk1',public.superadmin_attendance_mark_remaining_present(pg_temp.at5_uuid('create','id'),2,(pg_temp.at5_get('k_bulk1')#>>'{}')::uuid));
insert into at5 values('bulk1_replay',public.superadmin_attendance_mark_remaining_present(pg_temp.at5_uuid('create','id'),2,(pg_temp.at5_get('k_bulk1')#>>'{}')::uuid));
insert into at5 values('undo1',public.superadmin_attendance_undo_bulk(pg_temp.at5_uuid('bulk1','receipt.operation_id'),pg_temp.at5_uuid('create','id'),pg_temp.at5_int('bulk1','receipt.current_version')));
insert into at5 values('k_bulk2',to_jsonb(public.attendance_reserve_idempotency_key('clear_presence_marks',pg_temp.at5_uuid('create','id'),4,null)));
insert into at5 values('bulk2',public.superadmin_attendance_clear_presence_marks(pg_temp.at5_uuid('create','id'),4,(pg_temp.at5_get('k_bulk2')#>>'{}')::uuid));
reset role;
select ok((select value ?& array['call','receipt'] and value->'receipt' ?& array['operation_id','call_id','affected_participant_ids','previous_version','current_version'] from at5 where key='bulk1'),'bulk payload has call and receipt as _bulk reads');
select is((select jsonb_array_length(value->'receipt'->'affected_participant_ids') from at5 where key='bulk1'),2,'mark_remaining_present affected the two unmarked children');
select is((select value->'receipt'->>'previous_version' from at5 where key='bulk1'),'2','receipt previous_version');
select is((select value->'receipt'->>'current_version' from at5 where key='bulk1'),'3','receipt current_version');
select ok((select bool_and(p->>'state'='present') from at5, jsonb_array_elements(value->'call'->'participants') p where key='bulk1'),'everyone present after the bulk mark');
select is((select value from at5 where key='bulk1_replay'),(select value from at5 where key='bulk1'),'bulk replay returns the same receipt');
select is((select count(*) from app_private.attendance_bulk_operations where attendance_session_id=pg_temp.at5_uuid('create','id')),2::bigint,'two bulk operations recorded (replay recorded none)');
select is((select value->>'version' from at5 where key='undo1'),'4','undo bumps version to 4');
select is((select pg_temp.at5_state('undo1',pg_temp.at_id(312))),'unmarked','undo restored child B to unmarked');
select is((select pg_temp.at5_state('undo1',pg_temp.at_id(311))),'present','undo kept child A present (not affected by the bulk)');
select is((select jsonb_array_length(value->'receipt'->'affected_participant_ids') from at5 where key='bulk2'),1,'clear affected the single marked child');
select ok((select bool_and(p->>'state'='unmarked') from at5, jsonb_array_elements(value->'call'->'participants') p where key='bulk2'),'everyone unmarked after clear');
select is((select value->'call'->>'version' from at5 where key='bulk2'),'5','clear bumps version to 5');

-- Desfazer operacao antiga (nao e a ultima) -> conflito de versao.
select set_config('request.jwt.claims','{"sub":"8f190000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into at5 values('undo1_again',public.superadmin_attendance_undo_bulk(pg_temp.at5_uuid('bulk1','receipt.operation_id'),pg_temp.at5_uuid('create','id'),5));

-- Marcar A ausente (v5 -> v6), B atrasado (v6 -> v7), concluir (v7 -> v8).
insert into at5 values('set2',public.superadmin_attendance_set_participant(public.attendance_reserve_idempotency_key('set_participant',pg_temp.at5_uuid('create','id'),5,null),pg_temp.at5_uuid('create','id'),pg_temp.at_id(311),'absent',5));
insert into at5 values('set3',public.superadmin_attendance_set_participant(public.attendance_reserve_idempotency_key('set_participant',pg_temp.at5_uuid('create','id'),6,null),pg_temp.at5_uuid('create','id'),pg_temp.at_id(312),'late_arrival',6));
select throws_ok(format('select public.superadmin_attendance_undo_bulk(%L,%L,7)',pg_temp.at5_uuid('bulk2','receipt.operation_id'),pg_temp.at5_uuid('create','id')),
  '40001',null,'an operation that is no longer the last cannot be undone');
insert into at5 values('k_complete',to_jsonb(public.attendance_reserve_idempotency_key('complete_call',pg_temp.at5_uuid('create','id'),7,null)));
insert into at5 values('complete',public.superadmin_attendance_complete_call(pg_temp.at5_uuid('create','id'),7,(pg_temp.at5_get('k_complete')#>>'{}')::uuid));
insert into at5 values('complete_replay',public.superadmin_attendance_complete_call(pg_temp.at5_uuid('create','id'),7,(pg_temp.at5_get('k_complete')#>>'{}')::uuid));
reset role;
select is((select value->>'version' from at5 where key='undo1_again'),'5','undoing an already undone operation is a no-op');
select is((select value->>'status' from at5 where key='complete'),'closed','complete closes the call');
select is((select value->>'version' from at5 where key='complete'),'8','complete bumps version to 8');
select is((select value from at5 where key='complete_replay'),(select value from at5 where key='complete'),'complete replay returns the same receipt');
select is((select closed_by_person_id from public.attendance_sessions where id=pg_temp.at5_uuid('create','id')),pg_temp.at_id(221),'closed_by recorded');

select set_config('request.jwt.claims','{"sub":"8f190000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select throws_ok(format('select public.superadmin_attendance_set_participant(public.attendance_reserve_idempotency_key(''set_participant'',%L,8,null),%L,%L,''present'',8)',
  pg_temp.at5_uuid('create','id'),pg_temp.at5_uuid('create','id'),pg_temp.at_id(313)),
  '55000',null,'a closed call does not accept plain marking');
select throws_ok(format('select public.superadmin_attendance_correct_participant(%L,%L,''present'','' '',8)',pg_temp.at5_uuid('create','id'),pg_temp.at_id(311)),
  '22023',null,'correction requires a reason');

-- Corrigir depois de concluida (v8 -> v9) e reabrir (v9 -> v10).
insert into at5 values('correct',public.superadmin_attendance_correct_participant(pg_temp.at5_uuid('create','id'),pg_temp.at_id(311),'present','Chegou depois da chamada',8));
insert into at5 values('reopen',public.superadmin_attendance_reopen_call(pg_temp.at5_uuid('create','id'),9,'Faltou registrar a atividade'));
reset role;
select is((select value->>'status' from at5 where key='correct'),'corrected','correcting a closed call marks it corrected');
select is((select value->>'version' from at5 where key='correct'),'9','correction bumps version to 9');
select is((select pg_temp.at5_state('correct',pg_temp.at_id(311))),'present','child A corrected to present');
select is((select jsonb_array_length(value->'revisions') from at5 where key='correct'),(select count(*)::integer from public.attendance_record_revisions r join public.attendance_records rec on rec.id=r.attendance_record_id where rec.attendance_session_id=pg_temp.at5_uuid('create','id') and r.action_code in ('corrected','reverted')),'revisions list every correction and reversal of the call');
select ok((select bool_and(r ?& array['participant_id','previous','current','reason','author','changed_at']) from at5, jsonb_array_elements(value->'revisions') r where key='correct'),'revision payload has every key _revision reads');
select ok((select exists(select 1 from jsonb_array_elements(value->'revisions') r where r->>'participant_id'=pg_temp.at_id(311)::text and r->>'previous'='absent' and r->>'current'='present' and r->>'reason'='Chegou depois da chamada' and r->>'author'='AT5 adulto 221') from at5 where key='correct'),'the correction revision carries previous, current, reason and author');
select is((select value->>'status' from at5 where key='reopen'),'reopened','reopen sets status reopened');
select is((select value->>'version' from at5 where key='reopen'),'10','reopen bumps version to 10');
select is((select reopen_reason from public.attendance_sessions where id=pg_temp.at5_uuid('create','id')),'Faltou registrar a atividade','reopen reason stored on the session');
select is((select reopened_by_person_id from public.attendance_sessions where id=pg_temp.at5_uuid('create','id')),pg_temp.at_id(221),'reopened_by recorded');
select is((select after_json->>'version' from audit.audit_logs where action_code='attendance.call.reopen' and object_id=pg_temp.at5_uuid('create','id')),'10','reopen audited with the resulting version (free text is masked by the audit guard)');

-- Confirmar aviso familiar (v10 -> v11).
select set_config('request.jwt.claims','{"sub":"8f190000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into at5 values('notice',public.superadmin_attendance_confirm_notice(pg_temp.at_id(351),10));
reset role;
select is((select value->>'id' from at5 where key='notice'),(select value->>'id' from at5 where key='create'),'confirm_notice returns the call of the notice');
select is((select value->>'version' from at5 where key='notice'),'11','confirm_notice bumps version to 11');
select is((select pg_temp.at5_state('notice',pg_temp.at_id(311))),'absent','absence notice confirmed sets the child absent');
select is((select p->>'justification' from at5, jsonb_array_elements(value->'participants') p where key='notice' and p->>'participant_id'=pg_temp.at_id(311)::text),'accepted','justification accepted after confirmation');
select is((select p->'notice'->>'pending' from at5, jsonb_array_elements(value->'participants') p where key='notice' and p->>'participant_id'=pg_temp.at_id(311)::text),'false','notice no longer pending');
select is((select review_status from public.attendance_notices where id=pg_temp.at_id(351)),'confirmed','notice row confirmed');
select is((select source_notice_id from public.attendance_records where attendance_session_id=pg_temp.at5_uuid('create','id') and child_context_id=pg_temp.at_id(311) and status='active'),pg_temp.at_id(351),'record links the notice as source');

-- Diretorio com metricas do dia e dashboard.
select set_config('request.jwt.claims','{"sub":"8f190000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into at5 values('dir2',public.superadmin_attendance_directory(current_date));
insert into at5 values('dash',public.attendance_dashboard_read(current_date-7,current_date,'daily',null,null,null,null,null,'',null,null,'date',true,1,20,'highest'));
insert into at5 values('dash_inst',public.attendance_dashboard_read(current_date-7,current_date,'weekly',pg_temp.at_id(10),null,null,null,null,'',array['pending','completed'],null,'presence',false,1,10,'lowest'));
insert into at5 values('rank',public.attendance_dashboard_ranking_page(current_date-7,current_date,null,null,null,null,null,'groups','highest',1,10));
insert into at5 values('export',public.attendance_dashboard_request_export(pg_temp.at_id(900),'table','xlsx',jsonb_build_object('period_start',current_date-7,'period_end',current_date,'granularity','daily')));
reset role;
select is((select value->'metrics'->>'justified_absences' from at5 where key='dir2'),'1','one justified absence (child A with confirmed notice)');
select is((select value->'metrics'->>'late' from at5 where key='dir2'),'1','one late arrival (child B)');
select is((select value->'metrics'->>'presence_percent' from at5 where key='dir2'),'50.00','presence 50% over the two official records');
select is((select jsonb_array_length(value->'notices') from at5 where key='dir2'),0,'confirmed notice left the pending list');
select ok((select value ?& array['access','context_label','kpis','attention','rankings','series','calls'] from at5 where key='dash'),'dashboard payload has every key _dashboardSnapshot reads');
select is((select value->'access'->>'scope' from at5 where key='dash'),'platform','dashboard access scope platform');
select is((select value->'calls'->>'total_items' from at5 where key='dash'),'1','dashboard lists the call');
select is((select value->'calls'->'items'->0->>'status' from at5 where key='dash'),'pending','reopened call is pending in the dashboard');
select ok((select value->'calls'->'items'->0 ?& array['id','context','date','responsible','present','absent','late','official_records','presence_percent','status','can_open'] from at5 where key='dash'),'dashboard call row has every key _dashboardCallRow reads');
select is((select jsonb_array_length(value->'rankings') from at5 where key='dash'),6,'platform scope gets six rankings');
select is((select value->>'context_label' from at5 where key='dash_inst'),'AT5 A','institution filter labels the context');
select is((select value->>'kind' from at5 where key='rank'),'groups','ranking page kind echoes the request');
select ok((select value ?& array['kind','direction','total','items'] from at5 where key='rank'),'ranking payload has every key _dashboardRanking reads');
select is((select value->>'state' from at5 where key='export'),'failed','export answers honest unavailability');
select is((select value->>'error_code' from at5 where key='export'),'EXPORT_UNAVAILABLE','export error code');
select is((select value->>'id' from at5 where key='export'),pg_temp.at_id(900)::text,'export echoes the request id the client reads');
select is((select count(*) from public.import_jobs where request_id=pg_temp.at_id(900)),0::bigint,'no export job was created');
select ok((select count(*)>=10 from audit.audit_logs where action_code like 'attendance.%' and institution_id=pg_temp.at_id(10)),'every command left an audit entry');

-- ---------------------------------------------------------------------------
-- Cross-tenant: gestor de B nao alcanca a chamada de A
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"8f190000-0000-4000-8000-000000000123","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into at5 values('b_access',public.attendance_dashboard_access());
insert into at5 values('b_dir',public.superadmin_attendance_directory(current_date));
insert into at5 values('b_detail',coalesce(public.superadmin_attendance_call_detail(pg_temp.at5_uuid('create','id')),'null'::jsonb));
select throws_ok(format('select public.superadmin_attendance_set_participant(public.attendance_reserve_idempotency_key(''set_participant'',%L,11,null),%L,%L,''present'',11)',
  pg_temp.at5_uuid('create','id'),pg_temp.at5_uuid('create','id'),pg_temp.at_id(311)),
  '42501',null,'cross-tenant manager cannot mark a call of another institution');
select throws_ok(format('select public.superadmin_attendance_reopen_call(%L,11,''tentativa'')',pg_temp.at5_uuid('create','id')),
  '42501',null,'cross-tenant manager cannot reopen a call of another institution');
select throws_ok(format('select public.superadmin_attendance_correct_participant(%L,%L,''present'',''tentativa'',11)',pg_temp.at5_uuid('create','id'),pg_temp.at_id(311)),
  '42501',null,'cross-tenant manager cannot correct a call of another institution');
select throws_ok(format('select public.superadmin_attendance_confirm_notice(%L,11)',pg_temp.at_id(351)),
  '42501',null,'cross-tenant manager cannot confirm a notice of another institution');
select throws_ok(format('select public.superadmin_attendance_create_call(%L,%L,%L,null,current_date,public.attendance_reserve_idempotency_key(''create_call'',null,null,%L))',
  pg_temp.at_id(10),pg_temp.at_id(11),pg_temp.at_id(12),jsonb_build_object('institution_id',pg_temp.at_id(10),'group_id',pg_temp.at_id(12),'session_date',current_date)),
  '42501',null,'cross-tenant manager cannot open a call in another institution');
insert into at5 values('b_create',public.superadmin_attendance_create_call(pg_temp.at_id(20),pg_temp.at_id(21),pg_temp.at_id(22),null,current_date,
  public.attendance_reserve_idempotency_key('create_call',null,null,jsonb_build_object('institution_id',pg_temp.at_id(20),'group_id',pg_temp.at_id(22),'session_date',current_date))));
insert into at5 values('b_dash',public.attendance_dashboard_read(current_date-7,current_date,'daily',pg_temp.at_id(20),null,null,null,null,'',null,null,'date',true,1,20,'highest'));
select throws_ok(format('select public.attendance_dashboard_ranking_page(current_date-7,current_date,%L,null,null,null,null,''institutions'',''highest'',1,10)',pg_temp.at_id(20)),
  '42501',null,'institution scope cannot rank institutions');
reset role;
select is((select value->>'scope' from at5 where key='b_access'),'institution','manager of B resolves to institution scope');
select is((select jsonb_array_length(value->'calls') from at5 where key='b_dir'),0,'directory of B does not list the call of A');
select is((select value from at5 where key='b_detail'),'null'::jsonb,'call_detail of A is null for the manager of B');
select is((select value->>'institution_id' from at5 where key='b_create'),pg_temp.at_id(20)::text,'manager of B opens a call in B');
select is((select jsonb_array_length(value->'participants') from at5 where key='b_create'),1,'call in B has its single child');
select is((select value->'calls'->>'total_items' from at5 where key='b_dash'),'1','dashboard of B counts only the call of B');
select is((select jsonb_array_length(value->'rankings') from at5 where key='b_dash'),5,'institution scope gets five rankings');

-- ---------------------------------------------------------------------------
-- Sem permissao, sem sessao e anon
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"8f190000-0000-4000-8000-000000000122","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select throws_ok('select public.superadmin_attendance_directory(current_date)','42501',null,'person without attendance permission is denied the directory');
select is(public.superadmin_attendance_call_detail(pg_temp.at5_uuid('create','id')),null,'person without attendance permission sees no call');
select throws_ok(format('select public.superadmin_attendance_reopen_call(%L,11,''tentativa'')',pg_temp.at5_uuid('create','id')),'42501',null,'person without permission cannot reopen');
select throws_ok('select public.attendance_dashboard_read(current_date-7,current_date,''daily'')','42501',null,'person without permission has no dashboard');
reset role;

select set_config('request.jwt.claims','{}',true);
set local role authenticated;
select throws_ok('select public.superadmin_attendance_directory(current_date)','42501',null,'no session is denied');
select throws_ok(format('select public.superadmin_attendance_complete_call(%L,11,%L)',pg_temp.at5_uuid('create','id'),gen_random_uuid()),'42501',null,'no session cannot complete');
reset role;

set local role anon;
select throws_ok('select public.superadmin_attendance_directory(current_date)','42501',null,'anon cannot execute the directory');
select throws_ok(format('select public.superadmin_attendance_call_detail(%L)',pg_temp.at5_uuid('create','id')),'42501',null,'anon cannot execute call_detail');
select throws_ok('select public.attendance_dashboard_read(current_date-7,current_date,''daily'')','42501',null,'anon cannot execute the dashboard');
reset role;

select * from finish();
rollback;
