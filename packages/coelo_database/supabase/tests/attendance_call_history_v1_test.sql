-- Prova pgTAP da migration 20260916180000_attendance_call_history_v1
-- (R14 Sessao 10, ADR 0041 B2 / owner.r12-04): leitor do Historico de chamadas.
-- Fixture sintetica com rollback total; RPC publica executada como authenticated.
-- Cobre: grants/ACL, escopo de plataforma, escopo de instituicao (cross-tenant),
-- escopo de unidade, filtros (turma, instituicao, situacao, periodo), contagens
-- agregadas sem dado de crianca, cursor keyset sem duplicatas, negativas
-- (sem permissao, responsavel familiar, anon) e entradas invalidas.
begin;
create extension if not exists pgtap with schema extensions;
select plan(44);

create function pg_temp.ah_id(n integer) returns uuid language sql immutable as $$
  select ('8f1a0000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.ah_id(integer) to authenticated, anon;

-- ---------------------------------------------------------------------------
-- Estrutura e grants
-- ---------------------------------------------------------------------------
select has_function('public','superadmin_attendance_call_history_v1',
  array['uuid','uuid','uuid','uuid','date','date','text','text','integer'],'public wrapper exists');
select has_function('app_private','superadmin_attendance_call_history_v1',
  array['uuid','uuid','uuid','uuid','date','date','text','text','integer'],'private reader exists');
select ok(has_function_privilege('authenticated','public.superadmin_attendance_call_history_v1(uuid,uuid,uuid,uuid,date,date,text,text,integer)','execute'),
  'authenticated executes the public wrapper');
select ok(not has_function_privilege('anon','public.superadmin_attendance_call_history_v1(uuid,uuid,uuid,uuid,date,date,text,text,integer)','execute')
  and not has_function_privilege('service_role','public.superadmin_attendance_call_history_v1(uuid,uuid,uuid,uuid,date,date,text,text,integer)','execute'),
  'anon and service_role cannot execute the wrapper');
select ok(not has_function_privilege('authenticated','app_private.superadmin_attendance_call_history_v1(uuid,uuid,uuid,uuid,date,date,text,text,integer)','execute')
  and not has_function_privilege('anon','app_private.superadmin_attendance_call_history_v1(uuid,uuid,uuid,uuid,date,date,text,text,integer)','execute'),
  'private reader has no client grant');
select ok((select bool_and(p.prosecdef and coalesce(array_to_string(p.proconfig,','),'')='search_path=""')
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in('public','app_private') and p.proname='superadmin_attendance_call_history_v1'),
  'both functions are security definer with empty search_path');

-- ---------------------------------------------------------------------------
-- Catalogos minimos (espelho restaurado so com schema)
-- ---------------------------------------------------------------------------
insert into public.institution_types(id,code,name,status) values (pg_temp.ah_id(1),'ah-type','AH type','active');
insert into public.unit_types(id,code,name,status) values (pg_temp.ah_id(2),'ah-unit','AH unit','active');
insert into public.platform_roles(id,code,name,status,is_system) values (pg_temp.ah_id(3),'ah_owner','AH owner','active',true)
on conflict do nothing;
insert into public.platform_permissions(code,module_code,module_label,screen_code,screen_label,action_code,action_label,description,risk_level,requires_mfa) values
 ('attendance.read','attendance','Assiduidade','attendance_calls','Chamadas','read','Ver','Visualizar chamadas.','high',false),
 ('attendance.manage','attendance','Assiduidade','attendance_calls','Chamadas','manage','Gerenciar','Gerir chamadas.','high',false)
on conflict (code) do nothing;
insert into public.institution_permissions(code,module_code,module_label,screen_code,screen_label,action_code,action_label,description,risk_level,requires_mfa) values
 ('attendance.read','attendance','Assiduidade','attendance_calls','Chamadas','read','Ver','Visualizar chamadas.','high',false),
 ('attendance.manage','attendance','Assiduidade','attendance_calls','Chamadas','manage','Gerenciar','Gerir chamadas.','high',false)
on conflict (code) do nothing;
insert into public.guardian_permission_capabilities(code,name) values ('manage_attendance_notices','Avisos de assiduidade')
on conflict (code) do nothing;
insert into public.family_relationship_types(code,name) values ('mother','Mae') on conflict (code) do nothing;
insert into public.people(id,person_type,first_name,last_name,display_name)
select 'c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema'
where not exists (select 1 from public.people where id='c0e10000-0000-4000-8000-000000000001');

-- ---------------------------------------------------------------------------
-- Fixture: instituicao A (unidades A1/A2, turmas 12/15) e B (unidade B1, turma 22)
-- ---------------------------------------------------------------------------
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 (pg_temp.ah_id(10),pg_temp.ah_id(1),'AH A','ah-a','active'),
 (pg_temp.ah_id(20),pg_temp.ah_id(1),'AH B','ah-b','active');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status) values
 (pg_temp.ah_id(11),pg_temp.ah_id(10),'Unidade A1','ah-unidade-a1','ahunidade.a1',pg_temp.ah_id(2),'active'),
 (pg_temp.ah_id(14),pg_temp.ah_id(10),'Unidade A2','ah-unidade-a2','ahunidade.a2',pg_temp.ah_id(2),'active'),
 (pg_temp.ah_id(21),pg_temp.ah_id(20),'Unidade B1','ah-unidade-b1','ahunidade.b1',pg_temp.ah_id(2),'active');
insert into public.groups(id,institution_id,unit_id,name,status) values
 (pg_temp.ah_id(12),pg_temp.ah_id(10),pg_temp.ah_id(11),'Turma A1','active'),
 (pg_temp.ah_id(15),pg_temp.ah_id(10),pg_temp.ah_id(14),'Turma A2','active'),
 (pg_temp.ah_id(22),pg_temp.ah_id(20),pg_temp.ah_id(21),'Turma B1','active');

-- Adultos: 221 owner de plataforma (121); 222 sem permissao (122); 223 gestor de B (123);
-- 224 responsavel familiar (124); 225 gestor da unidade A2 (125).
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select pg_temp.ah_id(n),'authenticated','authenticated','ah-'||n||'@invalid.test',now(),now(),now(),'{}','{}' from unnest(array[121,122,123,124,125]) n;
insert into public.people(id,person_type,first_name,last_name,display_name,status)
select pg_temp.ah_id(n),'adult','AH','Adulto','AH adulto '||n,'active' from unnest(array[221,222,223,224,225]) n;
insert into public.person_auth_links(person_id,auth_user_id,status)
select pg_temp.ah_id(n+100),pg_temp.ah_id(n),'active' from unnest(array[121,122,123,124,125]) n;
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
values (pg_temp.ah_id(221),pg_temp.ah_id(3),'active','platform',false);
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select pg_temp.ah_id(3),p.id,'allow'::public.permission_effect,'active' from public.platform_permissions p
where p.code in('attendance.read','attendance.manage')
on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null;

insert into public.institution_roles(id,institution_id,code,name,status,max_scope_kind) values
 (pg_temp.ah_id(40),pg_temp.ah_id(20),'ah_manager_b','AH gestor B','active','institution'),
 (pg_temp.ah_id(42),pg_temp.ah_id(10),'ah_manager_a','AH gestor A','active','institution');
insert into public.institution_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.institution_permissions p cross join (values (pg_temp.ah_id(40)),(pg_temp.ah_id(42))) r(id)
where p.code in('attendance.read','attendance.manage');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status) values
 (pg_temp.ah_id(41),pg_temp.ah_id(223),pg_temp.ah_id(20),'ah_manager_b','active'),
 (pg_temp.ah_id(43),pg_temp.ah_id(225),pg_temp.ah_id(10),'ah_manager_a','active');
insert into public.institution_role_assignments(membership_id,role_id,scope_kind,scope_unit_id,status) values
 (pg_temp.ah_id(41),pg_temp.ah_id(40),'institution',null,'active'),
 (pg_temp.ah_id(43),pg_temp.ah_id(42),'unit',pg_temp.ah_id(14),'active');

-- Criancas 301..303 na turma A1 (contextos 311..313); 304 na turma B1.
insert into public.people(id,person_type,first_name,last_name,display_name,status,date_of_birth)
select pg_temp.ah_id(n),'child','Crianca','AH','Crianca '||chr(64+n-300),'active',date '2020-01-01' from unnest(array[301,302,303,304]) n;
insert into public.child_contexts(id,child_person_id,institution_id,status) values
 (pg_temp.ah_id(311),pg_temp.ah_id(301),pg_temp.ah_id(10),'active'),
 (pg_temp.ah_id(312),pg_temp.ah_id(302),pg_temp.ah_id(10),'active'),
 (pg_temp.ah_id(313),pg_temp.ah_id(303),pg_temp.ah_id(10),'active'),
 (pg_temp.ah_id(314),pg_temp.ah_id(304),pg_temp.ah_id(20),'active');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
 (pg_temp.ah_id(321),pg_temp.ah_id(311),pg_temp.ah_id(11),'active',pg_temp.ah_id(221),now()),
 (pg_temp.ah_id(322),pg_temp.ah_id(312),pg_temp.ah_id(11),'active',pg_temp.ah_id(221),now()),
 (pg_temp.ah_id(323),pg_temp.ah_id(313),pg_temp.ah_id(11),'active',pg_temp.ah_id(221),now()),
 (pg_temp.ah_id(324),pg_temp.ah_id(314),pg_temp.ah_id(21),'active',pg_temp.ah_id(221),now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status) values
 (pg_temp.ah_id(331),pg_temp.ah_id(321),pg_temp.ah_id(12),'active'),
 (pg_temp.ah_id(332),pg_temp.ah_id(322),pg_temp.ah_id(12),'active'),
 (pg_temp.ah_id(333),pg_temp.ah_id(323),pg_temp.ah_id(12),'active'),
 (pg_temp.ah_id(334),pg_temp.ah_id(324),pg_temp.ah_id(22),'active');
insert into public.guardian_links(id,guardian_person_id,child_person_id,relation_type,relationship_type_id,status)
select pg_temp.ah_id(341),pg_temp.ah_id(224),pg_temp.ah_id(301),'mother',t.id,'active' from public.family_relationship_types t where t.code='mother';

-- Chamadas (inseridas direto; a criacao pela RPC ja e provada no contrato v1):
-- 501 A1 hoje (closed, com registros), 502 A1 ontem (open), 503 A1 ha 10 dias (corrected),
-- 504 A2 hoje (open), 505 B1 hoje (closed), 506 A1 hoje cancelada, 507 A1 ha 60 dias (closed).
insert into public.attendance_sessions(id,institution_id,unit_id,group_id,activity_id,session_kind,session_date,status,created_by_person_id,created_at) values
 (pg_temp.ah_id(501),pg_temp.ah_id(10),pg_temp.ah_id(11),pg_temp.ah_id(12),null,'group',current_date,'closed',pg_temp.ah_id(221),now()-interval '3 hours'),
 (pg_temp.ah_id(502),pg_temp.ah_id(10),pg_temp.ah_id(11),pg_temp.ah_id(12),null,'group',current_date-1,'open',pg_temp.ah_id(221),now()-interval '1 day'),
 (pg_temp.ah_id(503),pg_temp.ah_id(10),pg_temp.ah_id(11),pg_temp.ah_id(12),null,'group',current_date-10,'corrected',pg_temp.ah_id(221),now()-interval '10 days'),
 (pg_temp.ah_id(504),pg_temp.ah_id(10),pg_temp.ah_id(14),pg_temp.ah_id(15),null,'group',current_date,'open',pg_temp.ah_id(225),now()-interval '2 hours'),
 (pg_temp.ah_id(505),pg_temp.ah_id(20),pg_temp.ah_id(21),pg_temp.ah_id(22),null,'group',current_date,'closed',pg_temp.ah_id(223),now()-interval '1 hour'),
 (pg_temp.ah_id(506),pg_temp.ah_id(10),pg_temp.ah_id(11),pg_temp.ah_id(12),null,'group',current_date,'cancelled',pg_temp.ah_id(221),now()-interval '4 hours'),
 (pg_temp.ah_id(507),pg_temp.ah_id(10),pg_temp.ah_id(11),pg_temp.ah_id(12),null,'group',current_date-60,'closed',pg_temp.ah_id(221),now()-interval '60 days');
insert into public.attendance_expected_participants(attendance_session_id,child_context_id,child_group_link_id,status) values
 (pg_temp.ah_id(501),pg_temp.ah_id(311),pg_temp.ah_id(331),'active'),
 (pg_temp.ah_id(501),pg_temp.ah_id(312),pg_temp.ah_id(332),'active'),
 (pg_temp.ah_id(501),pg_temp.ah_id(313),pg_temp.ah_id(333),'active');
insert into public.attendance_records(attendance_session_id,child_context_id,outcome,status,confirmed_by_person_id) values
 (pg_temp.ah_id(501),pg_temp.ah_id(311),'present','active',pg_temp.ah_id(221)),
 (pg_temp.ah_id(501),pg_temp.ah_id(312),'absent','active',pg_temp.ah_id(221)),
 (pg_temp.ah_id(501),pg_temp.ah_id(313),'late_arrival','active',pg_temp.ah_id(221));

create temporary table ah(key text primary key,value jsonb);
grant select,insert,update on ah to authenticated;
create function pg_temp.ah_ids(k text) returns text[] language sql stable as $$
  select coalesce(array_agg(item.value->>'id' order by item.ordinality),'{}') from ah, jsonb_array_elements(ah.value->'items') with ordinality item where ah.key=k $$;
grant execute on function pg_temp.ah_ids(text) to authenticated;
create function pg_temp.ah_count(k text) returns integer language sql stable as $$
  select jsonb_array_length(value->'items') from ah where key=k $$;
grant execute on function pg_temp.ah_count(text) to authenticated;
create function pg_temp.ah_item(k text, id uuid) returns jsonb language sql stable as $$
  select item from ah, jsonb_array_elements(value->'items') item where key=k and item->>'id'=id::text $$;
grant execute on function pg_temp.ah_item(text,uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Owner de plataforma
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"8f1a0000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into ah values('all',public.superadmin_attendance_call_history_v1());
insert into ah values('group_a1',public.superadmin_attendance_call_history_v1(p_group_id=>pg_temp.ah_id(12)));
insert into ah values('inst_b',public.superadmin_attendance_call_history_v1(p_institution_id=>pg_temp.ah_id(20)));
insert into ah values('completed',public.superadmin_attendance_call_history_v1(p_status=>'completed'));
insert into ah values('pending',public.superadmin_attendance_call_history_v1(p_status=>'pending'));
insert into ah values('today',public.superadmin_attendance_call_history_v1(p_start=>current_date,p_end=>current_date));
insert into ah values('year',public.superadmin_attendance_call_history_v1(p_start=>current_date-365,p_end=>current_date));
insert into ah values('page1',public.superadmin_attendance_call_history_v1(p_page_size=>2));
insert into ah values('page2',public.superadmin_attendance_call_history_v1(p_page_size=>2,p_cursor=>(select value->>'next_cursor' from ah where key='page1')));
insert into ah values('page3',public.superadmin_attendance_call_history_v1(p_page_size=>2,p_cursor=>(select value->>'next_cursor' from ah where key='page2')));
reset role;

select ok((select value ?& array['items','has_more','next_cursor','page_size','period_start','period_end','scope'] from ah where key='all'),
  'payload has items, has_more, next_cursor, page_size, period and scope');
select is((select value->>'scope' from ah where key='all'),'platform','owner reads in platform scope');
select is(pg_temp.ah_count('all'),5,'default period (30 days) lists the five non-cancelled calls');
select is(pg_temp.ah_ids('all'),array[pg_temp.ah_id(505)::text,pg_temp.ah_id(504)::text,pg_temp.ah_id(501)::text,pg_temp.ah_id(502)::text,pg_temp.ah_id(503)::text],
  'ordered by date desc then created_at desc');
select ok((select bool_and(item ?& array['id','session_date','institution_id','institution_name','unit_id','unit_name','group_id','group_name',
  'activity_id','activity_name','context','responsible','status','expected','official_records','present','absent','late','early_departures',
  'created_at','updated_at','version','can_open','routine']) from ah, jsonb_array_elements(value->'items') item where key='all'),
  'every item has the keys the client reads');
select ok((select not bool_or(item ? 'participants' or item ? 'children' or item::text ilike '%Crianca%')
  from ah, jsonb_array_elements(value->'items') item where key='all'),
  'items carry only aggregates, never child names or participant lists');
select is((select (pg_temp.ah_item('all',pg_temp.ah_id(501))->>'expected')::int),3,'expected participants counted');
select is((select (pg_temp.ah_item('all',pg_temp.ah_id(501))->>'present')::int),2,'present counts present + late arrival');
select is((select (pg_temp.ah_item('all',pg_temp.ah_id(501))->>'absent')::int),1,'absent counted');
select is((select (pg_temp.ah_item('all',pg_temp.ah_id(501))->>'late')::int),1,'late counted');
select is((select pg_temp.ah_item('all',pg_temp.ah_id(501))->>'responsible'),'AH adulto 221','responsible is the creator display name');
select is((select pg_temp.ah_item('all',pg_temp.ah_id(501))->>'context'),'AH A · Unidade A1 · Turma A1','context concatenates institution, unit and group');
select is((select pg_temp.ah_item('all',pg_temp.ah_id(501))->>'status'),'closed','raw status is exposed');
select is((select pg_temp.ah_item('all',pg_temp.ah_id(504))->>'expected')::int,0,'call without expected participants counts zero');
select is(pg_temp.ah_count('group_a1'),3,'group filter narrows to the group calls');
select is(pg_temp.ah_count('inst_b'),1,'institution filter narrows to institution B');
select is(pg_temp.ah_count('completed'),3,'completed = closed + corrected');
select is(pg_temp.ah_count('pending'),2,'pending = open/reopened/draft');
select is(pg_temp.ah_count('today'),3,'period filter keeps only today');
select is(pg_temp.ah_count('year'),6,'wider period reaches the 60-day-old call');
select is(pg_temp.ah_count('page1'),2,'cursor page 1 has page_size items');
select is((select value->>'has_more' from ah where key='page1'),'true','page 1 signals more');
select ok((select value->>'next_cursor' is not null from ah where key='page1'),'page 1 returns a cursor');
select is(pg_temp.ah_count('page2'),2,'cursor page 2 has two items');
select is(pg_temp.ah_count('page3'),1,'cursor page 3 has the last item');
select is((select value->>'has_more' from ah where key='page3'),'false','last page signals no more');
select is((select value->>'next_cursor' from ah where key='page3'),null,'last page has no cursor');
select is((select array_agg(x order by x) from unnest(pg_temp.ah_ids('page1')||pg_temp.ah_ids('page2')||pg_temp.ah_ids('page3')) x),
  (select array_agg(x order by x) from unnest(pg_temp.ah_ids('all')) x),'cursor pages cover all items exactly once');

-- ---------------------------------------------------------------------------
-- Escopo de instituicao (gestor de B) e de unidade (gestor de A2)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"8f1a0000-0000-4000-8000-000000000123","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into ah values('b_all',public.superadmin_attendance_call_history_v1());
insert into ah values('b_filter_a',public.superadmin_attendance_call_history_v1(p_institution_id=>pg_temp.ah_id(10)));
reset role;
select is(pg_temp.ah_ids('b_all'),array[pg_temp.ah_id(505)::text],'institution manager sees only institution B calls');
select is(pg_temp.ah_count('b_filter_a'),0,'filtering by another institution never widens the scope (cross-tenant negative)');

select set_config('request.jwt.claims','{"sub":"8f1a0000-0000-4000-8000-000000000125","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into ah values('a2_all',public.superadmin_attendance_call_history_v1());
reset role;
select is(pg_temp.ah_ids('a2_all'),array[pg_temp.ah_id(504)::text],'unit manager sees only the calls of the assigned unit');

-- ---------------------------------------------------------------------------
-- Negativas e entradas invalidas
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"8f1a0000-0000-4000-8000-000000000122","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select throws_ok('select public.superadmin_attendance_call_history_v1()','42501','attendance.read required','person without attendance permission is denied');
reset role;
select set_config('request.jwt.claims','{"sub":"8f1a0000-0000-4000-8000-000000000124","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select throws_ok('select public.superadmin_attendance_call_history_v1()','42501','attendance.read required','family guardian is denied (no aggregates for guardians)');
reset role;
select set_config('request.jwt.claims','{"role":"anon"}',true);
set local role anon;
select throws_ok('select public.superadmin_attendance_call_history_v1()','42501',null,'anon cannot execute the wrapper');
reset role;
select set_config('request.jwt.claims','{"sub":"8f1a0000-0000-4000-8000-000000000121","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select throws_ok('select public.superadmin_attendance_call_history_v1(p_page_size=>0)','22023','invalid page size','page_size 0 is rejected');
select throws_ok('select public.superadmin_attendance_call_history_v1(p_status=>''weird'')','22023','invalid attendance status','unknown status is rejected');
select throws_ok('select public.superadmin_attendance_call_history_v1(p_cursor=>''nope'')','22023','invalid attendance history cursor','malformed cursor is rejected');
select throws_ok('select public.superadmin_attendance_call_history_v1(p_start=>current_date-400,p_end=>current_date)','22023','invalid attendance period','period over 366 days is rejected');
reset role;

select * from finish();
rollback;
