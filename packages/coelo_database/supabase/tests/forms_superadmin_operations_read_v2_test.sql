-- C02 I010. Synthetic rollback-only tests; requires the nominal I005 profile.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
create function pg_temp.op_id(n integer) returns uuid language sql immutable as $$
  select ('8c024000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
insert into public.institution_types(id,code,name,status)
values(pg_temp.op_id(1),'c02-operations-test','Synthetic operations type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status)
select pg_temp.op_id(n),pg_temp.op_id(1),'Synthetic operations '||n,'c02-operations-'||n,'active'
from unnest(array[10,20]) n;
insert into public.people(id,person_type,first_name,last_name,display_name,status)
select pg_temp.op_id(n),'adult','Synthetic','Responder','Synthetic responder '||n,'active'
from generate_series(1000,1003) n;
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select pg_temp.op_id(n),'authenticated','authenticated','c02-operations-'||n||'@invalid.test',now(),now(),now(),'{}','{}'
from unnest(array[101,102]) n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
select pg_temp.op_id(n+100),pg_temp.op_id(n),now(),now(),'aal2',now()+interval '1 hour'
from unnest(array[101,102]) n;
insert into app_private.superadmin_internal_identities(id) select pg_temp.op_id(n) from unnest(array[301,302]) n;
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
select pg_temp.op_id(n+300),pg_temp.op_id(n+200),pg_temp.op_id(n) from unnest(array[101,102]) n;
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select pg_temp.op_id(n+400),pg_temp.op_id(n+200),r.id,'institution',pg_temp.op_id(10)
from unnest(array[101,102]) n cross join public.platform_roles r where r.code='operations';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r cross join public.platform_permissions p
where r.code='operations' and p.code in ('forms.monitor','forms.responses.read','forms.responses.export')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_person_id,updated_by_person_id)
select pg_temp.op_id(n),pg_temp.op_id(case when n=230 then 20 else 10 end),'form',
  case when n=220 then 'anonymous' else 'identified' end,'person','Synthetic form '||n,pg_temp.op_id(1000),pg_temp.op_id(1000)
from unnest(array[210,220,230,240]) n;
insert into public.form_versions(id,form_id,version_number,created_by_person_id)
select pg_temp.op_id(n+1000),pg_temp.op_id(n),1,pg_temp.op_id(1000) from unnest(array[210,220,230,240]) n;
insert into public.form_sections(id,form_version_id,title,position)
select pg_temp.op_id(n+2000),pg_temp.op_id(n+1000),'Original section',0 from unnest(array[210,220,230,240]) n;
insert into public.form_items(id,form_version_id,section_id,kind,label,position)
select pg_temp.op_id(n+3000),pg_temp.op_id(n+1000),pg_temp.op_id(n+2000),'short_text','Original question',0
from unnest(array[210,220,230,240]) n;
insert into public.form_applications(id,form_id,institution_id,name,created_by_person_id)
select pg_temp.op_id(n+4000),pg_temp.op_id(n),pg_temp.op_id(case when n=230 then 20 else 10 end),
  'Synthetic application',pg_temp.op_id(1000) from unnest(array[210,220,230,240]) n;
insert into public.form_schedules(id,application_id,time_zone,starts_at_local,recurrence_kind)
select pg_temp.op_id(n+5000),pg_temp.op_id(n+4000),'UTC','2026-09-08 00:00:00','once' from unnest(array[210,220,230,240]) n;
insert into public.form_occurrences(id,application_id,schedule_id,institution_id,form_id,form_version_id,scheduled_local,time_zone,opens_at,closes_at)
select pg_temp.op_id(n+6000),pg_temp.op_id(n+4000),pg_temp.op_id(n+5000),pg_temp.op_id(case when n=230 then 20 else 10 end),
  pg_temp.op_id(n),pg_temp.op_id(n+1000),'2026-09-08 00:00:00','UTC',now()-interval '1 day',now()+interval '1 day'
from unnest(array[210,220,230,240]) n;
insert into public.form_responses(id,occurrence_id,institution_id,form_id,form_version_id,identity_mode,respondent_person_id,
  anonymous_edit_secret_hash,status,submitted_at)
select pg_temp.op_id(n+7000+offset_n),pg_temp.op_id(n+6000),pg_temp.op_id(case when n=230 then 20 else 10 end),
  pg_temp.op_id(n),pg_temp.op_id(n+1000),case when n=220 then 'anonymous' else 'identified' end,
  case when n<>220 then pg_temp.op_id(1000+offset_n) else null end,
  case when n=220 then 'synthetic-no-real-secret' else null end,'submitted',
  now()-make_interval(mins=>case offset_n when 0 then 1 when 1 then 3 else 2 end)
from unnest(array[210,220,230,240]) n cross join generate_series(0,2) offset_n;
insert into public.form_answers(id,response_id,form_version_id,item_id,answer_kind,text_value)
select pg_temp.op_id(n+17000+offset_n),pg_temp.op_id(n+7000+offset_n),pg_temp.op_id(n+1000),pg_temp.op_id(n+3000),
  'short_text','Synthetic answer '||n||'-'||offset_n from unnest(array[210,220,230,240]) n cross join generate_series(0,2) offset_n;
insert into public.form_occurrence_metrics(occurrence_id,institution_id,eligible_count,responded_count,pending_count)
values(pg_temp.op_id(6210),pg_temp.op_id(10),8,3,5),(pg_temp.op_id(6220),pg_temp.op_id(10),5,3,2);
insert into public.form_scope_metrics(occurrence_id,institution_id,scope_kind,scope_id,eligible_count,responded_count,pending_count)
values(pg_temp.op_id(6210),pg_temp.op_id(10),'institution',pg_temp.op_id(10),8,3,5);
-- A new working graph must not replace the original submitted graph.
update public.form_versions set state='published',published_at=now()
where id=pg_temp.op_id(1210);
update public.forms set published_version_id=pg_temp.op_id(1210),first_published_at=now() where id=pg_temp.op_id(210);
insert into public.form_versions(id,form_id,version_number,created_by_person_id)
values(pg_temp.op_id(9000),pg_temp.op_id(210),2,pg_temp.op_id(1000));
insert into public.form_sections(id,form_version_id,title,position) values(pg_temp.op_id(9001),pg_temp.op_id(9000),'New section',0);
insert into public.form_items(id,form_version_id,section_id,kind,label,position)
values(pg_temp.op_id(9002),pg_temp.op_id(9000),pg_temp.op_id(9001),'short_text','New question must not replace history',0);
update public.forms set working_version_id=pg_temp.op_id(9000) where id=pg_temp.op_id(210);

create temporary table op_results(label text primary key,body jsonb);
grant insert,select on op_results to authenticated,service_role;
create function pg_temp.op_claims(actor integer) returns void language sql as $$
  select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.op_id(actor),'session_id',pg_temp.op_id(actor+100),
    'aal','aal2','role','authenticated')::text,true);
$$;
create function pg_temp.op_read(kind text,n integer,extra jsonb default '{}'::jsonb) returns jsonb
language sql security invoker as $$
  select case kind
    when 'monitor' then public.superadmin_forms_monitor_v2(jsonb_build_object('form_id',pg_temp.op_id(n))||extra)
    when 'responses' then public.superadmin_forms_responses_v2(jsonb_build_object('form_id',pg_temp.op_id(n))||extra)
    when 'detail' then public.superadmin_forms_response_detail_v2(jsonb_build_object('response_id',pg_temp.op_id(n))||extra)
    when 'jobs' then public.superadmin_forms_file_jobs_v2(jsonb_build_object('form_id',pg_temp.op_id(n))||extra) end;
$$;
grant execute on function pg_temp.op_id(integer),pg_temp.op_claims(integer),pg_temp.op_read(text,integer,jsonb) to authenticated,service_role;
select pg_temp.op_claims(101);
set local role authenticated;
insert into op_results values('monitor',pg_temp.op_read('monitor',210));
insert into op_results values('identified_page1',pg_temp.op_read('responses',210,'{"limit":1}'));
insert into op_results select 'identified_page2',pg_temp.op_read('responses',210,jsonb_build_object('limit',1,
  'cursor_id',body#>'{data,next_cursor,id}','cursor_submitted_at',body#>'{data,next_cursor,submitted_at}'))
  from op_results where label='identified_page1';
insert into op_results values('anonymous_page1',pg_temp.op_read('responses',220,'{"limit":1}'));
insert into op_results select 'anonymous_page2',pg_temp.op_read('responses',220,jsonb_build_object('limit',1,
  'cursor_id',body#>'{data,next_cursor,id}')) from op_results where label='anonymous_page1';
insert into op_results values('detail',pg_temp.op_read('detail',7210));
insert into op_results values('anonymous_detail',pg_temp.op_read('detail',7220));
select is(pg_temp.op_read('responses',230)#>>'{error,code}','SAI_PERMISSION_DENIED','institution context cannot read another tenant');
select is(pg_temp.op_read('detail',7230)#>>'{error,code}','SAI_PERMISSION_DENIED','detail ID cannot cross tenant');
select is(pg_temp.op_read('detail',7210,jsonb_build_object('form_id',pg_temp.op_id(240)))#>>'{error,code}','SAI_PERMISSION_DENIED','detail route cannot pair another form');
select is(pg_temp.op_read('responses',210,jsonb_build_object('occurrence_id',pg_temp.op_id(6240)))#>>'{error,code}','SAI_PERMISSION_DENIED','occurrence in same tenant but another form denied');
select is(pg_temp.op_read('monitor',210,jsonb_build_object('application_id',pg_temp.op_id(4240)))#>>'{error,code}','SAI_PERMISSION_DENIED','application in same tenant but another form denied');
select is(pg_temp.op_read('monitor',210,jsonb_build_object('scope_id',pg_temp.op_id(20)))#>>'{error,code}','SAI_PERMISSION_DENIED','unmaterialized scope cannot be guessed');
select is(pg_temp.op_read('monitor',210,'{"starts_on_or_after":"2026-10-01","ends_on_or_before":"2026-09-01"}')#>>'{error,code}','SAI_INVALID_ARGUMENT','inverted date range rejected');
select is(pg_temp.op_read('responses',210,'{"limit":1.5}')#>>'{error,code}','SAI_INVALID_ARGUMENT','fractional page size rejected');
select is(pg_temp.op_read('responses',210,'{"limit":101}')#>>'{error,code}','SAI_INVALID_ARGUMENT','excessive page size rejected');
select is(pg_temp.op_read('responses',210,'{"extra":true}')#>>'{error,code}','SAI_INVALID_ARGUMENT','unknown query key rejected');
select is(pg_temp.op_read('responses',210,jsonb_build_object('cursor_id',pg_temp.op_id(7210)))#>>'{error,code}','SAI_INVALID_ARGUMENT','identified cursor requires timestamp pair');
select is(pg_temp.op_read('responses',220,jsonb_build_object('cursor_id',pg_temp.op_id(7220),'cursor_submitted_at',now()))#>>'{error,code}','SAI_INVALID_ARGUMENT','anonymous cursor never accepts submission time');
select is(pg_temp.op_read('responses',210,'{"cursor_id":"bad-id","cursor_submitted_at":"infinity"}')#>>'{error,code}','SAI_INVALID_ARGUMENT','invalid cursor fails validation');
reset role;
select is((select body#>>'{data,eligible_count}' from op_results where label='monitor'),'8','monitor has real eligible aggregate');
select is((select body#>>'{data,responded_count}' from op_results where label='monitor'),'3','monitor has real responded aggregate');
select is((select body#>>'{data,pending_count}' from op_results where label='monitor'),'5','monitor has real pending aggregate');
select is((select body#>>'{data,items,0,id}' from op_results where label='identified_page1'),pg_temp.op_id(7210)::text,'identified first page follows submitted time');
select is((select body#>>'{data,items,0,id}' from op_results where label='identified_page2'),pg_temp.op_id(7212)::text,'identified cursor advances without repeating first row');
select is((select body#>>'{data,items,0,id}' from op_results where label='anonymous_page1'),pg_temp.op_id(7222)::text,'anonymous page follows UUID order independently of timestamps');
select is((select body#>>'{data,items,0,id}' from op_results where label='anonymous_page2'),pg_temp.op_id(7221)::text,'anonymous cursor advances by UUID only');
select is((select body#>'{data,next_cursor}' from op_results where label='anonymous_page1'),jsonb_build_object('id',pg_temp.op_id(7222)),'anonymous cursor exposes only response ID');
select is((select body#>>'{data,items,0,respondent_label}' from op_results where label='anonymous_page1'),null::text,'anonymous list has no respondent label');
select is((select body#>>'{data,items,0,submitted_at}' from op_results where label='anonymous_page1'),null::text,'anonymous list has no individual time');
select ok(not exists(select 1 from op_results where label in ('anonymous_page1','anonymous_page2','anonymous_detail')
  and body::text~'(Synthetic responder|synthetic-no-real-secret|participation_id|respondent_person_id|created_at|updated_at)'),
  'anonymous response payloads contain no identity keys or secret anywhere');
select is((select body#>>'{data,definition,sections,0,items,0,label}' from op_results where label='detail'),'Original question','detail uses submitted version graph');
select is((select body#>>'{data,form_version_number}' from op_results where label='detail'),'1','original version number is returned without a guessed client value');
select is((select body#>>'{data,form_version_state}' from op_results where label='detail'),'published','original publication state is explicit');
select is((select body#>>'{data,form_id}' from op_results where label='detail'),pg_temp.op_id(210)::text,'original graph is correlated to its form');
select is((select body#>>'{data,answers,0,text_value}' from op_results where label='detail'),'Synthetic answer 210-0','detail returns authorized typed content');
select ok(not exists(select 1 from op_results where label='detail' and body::text like '%New question must not replace history%'),'working graph never replaces historical response');
select ok(exists(select 1 from audit.audit_logs where action_code='superadmin.forms.responses' and outcome='success'
  and actor_internal_identity_id=pg_temp.op_id(301) and object_id=pg_temp.op_id(210)),'responses success is audited by internal identity');
select ok(not exists(select 1 from public.person_auth_links where auth_user_id in (pg_temp.op_id(101),pg_temp.op_id(102))),
  'internal reads do not need a global person surrogate');

-- Existing single-column foreign keys do not authorize cross-resource links.
-- These inserts keep all constraints/triggers enabled. The immutable trigger
-- checks the row's declared working version, not the referenced section/item.
select lives_ok($$insert into public.form_items(id,form_version_id,section_id,kind,label,position)
  values(pg_temp.op_id(9300),pg_temp.op_id(1230),pg_temp.op_id(2210),'short_text','Foreign unanswered secret',99)$$,
  'effective constraints permit a foreign working item under a published section');
set local role authenticated;
insert into op_results values('graph_foreign_item',pg_temp.op_read('detail',7210));
reset role;
select is((select body->>'ok' from op_results where label='graph_foreign_item'),'false','unanswered foreign item invalidates the complete projected graph');
select is((select body->'data' from op_results where label='graph_foreign_item'),'null'::jsonb,'foreign unanswered graph returns no content');
delete from public.form_items where id=pg_temp.op_id(9300);

insert into public.form_items(id,form_version_id,section_id,kind,label,position)
values(pg_temp.op_id(9301),pg_temp.op_id(1220),pg_temp.op_id(2240),'short_text','Misplaced local item',99);
set local role authenticated;
insert into op_results values('graph_foreign_section',pg_temp.op_read('detail',7220));
reset role;
select is((select body->>'ok' from op_results where label='graph_foreign_section'),'false','local version item cannot disappear into a foreign section');
select is((select body->'data' from op_results where label='graph_foreign_section'),'null'::jsonb,'foreign section denial returns no partial graph');
delete from public.form_items where id=pg_temp.op_id(9301);

insert into public.form_items(id,form_version_id,section_id,kind,label,position) values
  (pg_temp.op_id(3221),pg_temp.op_id(1220),pg_temp.op_id(2220),'yes_no','Unanswered yes/no source',1),
  (pg_temp.op_id(3222),pg_temp.op_id(1220),pg_temp.op_id(2220),'single_choice','Unanswered choice source',2),
  (pg_temp.op_id(3223),pg_temp.op_id(1220),pg_temp.op_id(2220),'single_choice','Other question',3),
  (pg_temp.op_id(3241),pg_temp.op_id(1240),pg_temp.op_id(2240),'yes_no','Foreign yes/no source',1);
insert into public.form_question_options(id,form_version_id,item_id,label,position) values
  (pg_temp.op_id(9322),pg_temp.op_id(1220),pg_temp.op_id(3222),'Correct source option',0),
  (pg_temp.op_id(9324),pg_temp.op_id(1220),pg_temp.op_id(3222),'Second source option',1),
  (pg_temp.op_id(9323),pg_temp.op_id(1220),pg_temp.op_id(3223),'Wrong question option',0),
  (pg_temp.op_id(9325),pg_temp.op_id(1220),pg_temp.op_id(3223),'Second other option',1),
  (pg_temp.op_id(9302),pg_temp.op_id(1240),pg_temp.op_id(3222),'Foreign version option',99);
set local role authenticated;
insert into op_results values('graph_foreign_option',pg_temp.op_read('detail',7220));
reset role;
select is((select body->>'ok' from op_results where label='graph_foreign_option'),'false','unanswered question cannot project an option declared in another version');
select is((select body->'data' from op_results where label='graph_foreign_option'),'null'::jsonb,'foreign option in definition returns no content');
delete from public.form_question_options where id=pg_temp.op_id(9302);

insert into public.form_question_conditions(id,form_version_id,target_item_id,source_item_id,condition_kind,expected_yes_no)
values(pg_temp.op_id(9303),pg_temp.op_id(1240),pg_temp.op_id(3220),pg_temp.op_id(3221),'yes_no',true);
set local role authenticated;
insert into op_results values('graph_foreign_condition',pg_temp.op_read('detail',7220));
reset role;
select is((select body->>'ok' from op_results where label='graph_foreign_condition'),'false','condition attached by target ID must declare the projected version');
select is((select body->'data' from op_results where label='graph_foreign_condition'),'null'::jsonb,'foreign condition returns no graph');
delete from public.form_question_conditions where id=pg_temp.op_id(9303);

insert into public.form_question_conditions(id,form_version_id,target_item_id,source_item_id,condition_kind,expected_yes_no)
values(pg_temp.op_id(9304),pg_temp.op_id(1220),pg_temp.op_id(3220),pg_temp.op_id(3241),'yes_no',true);
set local role authenticated;
insert into op_results values('graph_foreign_source',pg_temp.op_read('detail',7220));
reset role;
select is((select body->>'ok' from op_results where label='graph_foreign_source'),'false','condition source must belong to the projected version');
select is((select body->'data' from op_results where label='graph_foreign_source'),'null'::jsonb,'foreign source denial returns no graph');
delete from public.form_question_conditions where id=pg_temp.op_id(9304);

insert into public.form_question_conditions(id,form_version_id,target_item_id,source_item_id,condition_kind,source_option_id)
values(pg_temp.op_id(9305),pg_temp.op_id(1220),pg_temp.op_id(3220),pg_temp.op_id(3222),'choice',pg_temp.op_id(9323));
set local role authenticated;
insert into op_results values('graph_wrong_source_option',pg_temp.op_read('detail',7220));
reset role;
select is((select body->>'ok' from op_results where label='graph_wrong_source_option'),'false','same-version source option must belong to the actual source question');
select is((select body->'data' from op_results where label='graph_wrong_source_option'),'null'::jsonb,'wrong source question option returns no graph');
update public.form_question_conditions set source_option_id=pg_temp.op_id(9322) where id=pg_temp.op_id(9305);
insert into public.form_question_conditions(id,form_version_id,target_item_id,source_item_id,condition_kind,expected_yes_no)
values(pg_temp.op_id(9306),pg_temp.op_id(1220),pg_temp.op_id(3220),pg_temp.op_id(3221),'yes_no',true);
set local role authenticated;
insert into op_results values('graph_valid_unanswered',pg_temp.op_read('detail',7220));
reset role;
select is((select body->>'ok' from op_results where label='graph_valid_unanswered'),'true','complete valid graph preserves unanswered source questions and conditions');
select is((select jsonb_array_length(body#>'{data,definition,sections,0,items,0,conditions}') from op_results where label='graph_valid_unanswered'),2,
  'valid yes/no and choice conditions remain projected');

insert into public.form_question_options(id,form_version_id,item_id,label,position)
values(pg_temp.op_id(9100),pg_temp.op_id(1240),pg_temp.op_id(3240),'Foreign option',0);
insert into public.form_answer_options(answer_id,option_id,position)
values(pg_temp.op_id(17210),pg_temp.op_id(9100),0);
set local role authenticated;
insert into op_results values('foreign_option',pg_temp.op_read('detail',7210));
reset role;
select is((select body->>'ok' from op_results where label='foreign_option'),'false','option from another question cannot be silently projected');
select is((select body->'data' from op_results where label='foreign_option'),'null'::jsonb,'foreign option denial contains no response data');
delete from public.form_answer_options where answer_id=pg_temp.op_id(17210);
insert into public.form_assets(id,institution_id,occurrence_id,item_id,prepared_by_person_id,storage_path,
  mime_type,expected_byte_length,expected_checksum_sha256)
values(pg_temp.op_id(9200),pg_temp.op_id(10),pg_temp.op_id(6240),pg_temp.op_id(3240),pg_temp.op_id(1000),
  '8c/'||pg_temp.op_id(9200),'image/jpeg',128,repeat('a',64));
insert into public.form_answer_assets(answer_id,asset_id,position) values(pg_temp.op_id(17210),pg_temp.op_id(9200),0);
set local role authenticated;
insert into op_results values('foreign_asset',pg_temp.op_read('detail',7210));
reset role;
select is((select body->>'ok' from op_results where label='foreign_asset'),'false','asset in another form occurrence cannot be projected through answer ID');
select is((select body->'data' from op_results where label='foreign_asset'),'null'::jsonb,'foreign asset denial contains no response data');
delete from public.form_answer_assets where answer_id=pg_temp.op_id(17210);
-- Draft form metadata can still change; legacy submitted rows must not leak.
update public.forms set identity_mode='identified' where id=pg_temp.op_id(220);
set local role authenticated;
insert into op_results values('identity_mismatch',pg_temp.op_read('detail',7220));
reset role;
select is((select body->>'ok' from op_results where label='identity_mismatch'),'false','detail denies a response whose identity mode diverges from its form');
update public.forms set identity_mode='anonymous' where id=pg_temp.op_id(220);

-- XLSX listing owns jobs by identity, across valid sessions, without locator.
set local role authenticated;
insert into op_results values('job1',public.superadmin_form_request_xlsx_v2(pg_temp.op_id(8001),1,jsonb_build_object('form_id',pg_temp.op_id(210))));
select pg_temp.op_claims(102);
insert into op_results values('job2',public.superadmin_form_request_xlsx_v2(pg_temp.op_id(8002),1,jsonb_build_object('form_id',pg_temp.op_id(210))));
select pg_temp.op_claims(101);
insert into op_results values('jobs',pg_temp.op_read('jobs',210));
reset role;
select is((select jsonb_array_length(body#>'{data,items}') from op_results where label='jobs'),1,'same tenant export capability lists only own job');
select is((select body#>>'{data,items,0,id}' from op_results where label='jobs'),(select body#>>'{data,id}' from op_results where label='job1'),'own job is correlated');
select is((select body#>>'{data,items,0,download_available}' from op_results where label='jobs'),'false','pending job has no download');
select ok(not exists(select 1 from op_results where label='jobs' and body::text~'(object_key|artifact_path|download_path|download_token|https://)'),'job list exposes no private locator');

-- Authorization must precede casts, and current clock must beat transaction now.
update app_private.superadmin_internal_memberships set status='suspended',suspended_at=clock_timestamp(),version=version+1 where id=pg_temp.op_id(501);
set local role authenticated;
insert into op_results values('denied_malformed',public.superadmin_forms_responses_v2('{"form_id":"bad-id","limit":1.5}'));
reset role;
select isnt((select body#>>'{error,code}' from op_results where label='denied_malformed'),'SAI_INVALID_ARGUMENT','denied actor is handled before malformed payload');
select is((select body->>'ok' from op_results where label='denied_malformed'),'false','suspended actor receives no success');
select is((select body->'data' from op_results where label='denied_malformed'),'null'::jsonb,'denied envelope has no projection');
update app_private.superadmin_internal_memberships set status='active',suspended_at=null,version=version+1 where id=pg_temp.op_id(501);
update auth.sessions set not_after=clock_timestamp()+interval '1 millisecond' where id=pg_temp.op_id(201);
select pg_sleep(0.01);
set local role authenticated;
insert into op_results values('clock_expired',pg_temp.op_read('responses',210));
reset role;
select is((select body->>'ok' from op_results where label='clock_expired'),'false','session expired on wall clock cannot return a response even while transaction now is earlier');
update auth.sessions set not_after=clock_timestamp()+interval '1 hour' where id=pg_temp.op_id(201);
update public.platform_role_permissions set effect='deny' where role_id=(select id from public.platform_roles where code='operations')
  and permission_id=(select id from public.platform_permissions where code='forms.responses.read');
set local role authenticated;
select is(pg_temp.op_read('responses',210)#>>'{error,code}','SAI_PERMISSION_DENIED','capability revoked independently of forms access blocks answers');
reset role;
update public.platform_role_permissions set effect='allow' where role_id=(select id from public.platform_roles where code='operations')
  and permission_id=(select id from public.platform_permissions where code='forms.responses.read');
create function pg_temp.op_audit_failure() returns trigger language plpgsql as $$
begin
  if new.action_code='superadmin.forms.responses' and new.outcome='success' then raise exception 'synthetic audit failure'; end if;
  return new;
end;
$$;
create trigger c02_operations_audit_failure before insert on audit.audit_logs for each row execute function pg_temp.op_audit_failure();
set local role authenticated;
select throws_ok($$select pg_temp.op_read('responses',210)$$,'P0001','synthetic audit failure','audit failure escapes instead of returning successful data');
reset role;
drop trigger c02_operations_audit_failure on audit.audit_logs;
select ok(not has_function_privilege('authenticated','app_private.superadmin_forms_operations_read_v2(text,jsonb)','execute'),'client cannot select private operation dispatcher');
select ok(not has_function_privilege('anon','public.superadmin_forms_responses_v2(jsonb)','execute'),'anonymous role cannot use internal response reader');
select ok(not has_function_privilege('service_role','public.superadmin_forms_responses_v2(jsonb)','execute'),'service key is not internal identity reader');
set constraints all immediate;
select * from finish();
rollback;
