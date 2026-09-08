-- F-AUTHOR01: synthetic rollback-only RED contract. Eng1 alone executes SQL.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_function('public','superadmin_forms_editor_v2',array['uuid'],'nominal editor exists');
select has_function('public','superadmin_forms_save_draft_v2',array['uuid','bigint','jsonb'],'nominal save exists');
select ok(has_function_privilege('authenticated','public.superadmin_forms_save_draft_v2(uuid,bigint,jsonb)','execute'),'authenticated invokes public save');
select ok(not has_function_privilege('anon','public.superadmin_forms_save_draft_v2(uuid,bigint,jsonb)','execute'),'anonymous cannot invoke save');
select ok(not has_function_privilege('service_role','public.superadmin_forms_save_draft_v2(uuid,bigint,jsonb)','execute'),'service role is not authoring client');
select ok(not has_function_privilege('authenticated','app_private.superadmin_forms_save_draft_v2(uuid,bigint,jsonb)','execute'),'private save is inaccessible');
select ok(has_function_privilege('authenticated','public.superadmin_forms_editor_v2(uuid)','execute'),'authenticated invokes public reader');
select ok(not has_function_privilege('anon','public.superadmin_forms_editor_v2(uuid)','execute'),'anonymous cannot invoke reader');
select ok(not has_function_privilege('service_role','public.superadmin_forms_editor_v2(uuid)','execute'),'service role is not an editor client');
select ok(not has_function_privilege('authenticated','app_private.superadmin_forms_editor_v2(uuid)','execute'),'private reader is inaccessible');
select ok(not has_table_privilege('authenticated','app_private.superadmin_internal_form_draft_receipts','select'),'receipts are private');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='app_private.superadmin_internal_form_draft_receipts'::regclass),'receipt RLS is enabled and forced');

insert into public.institution_types(id,code,name,status) values
 ('8f020000-0000-4000-8000-000000000001','fauthor01-type','F-AUTHOR01 type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 ('8f020000-0000-4000-8000-000000000010','8f020000-0000-4000-8000-000000000001','F-AUTHOR01 A','fauthor01-a','active'),
 ('8f020000-0000-4000-8000-000000000020','8f020000-0000-4000-8000-000000000001','F-AUTHOR01 B','fauthor01-b','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select ('8f020000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'authenticated','authenticated','fauthor01-'||n||'@invalid.test',now(),now(),now(),'{}','{}'
from generate_series(101,105) n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
select ('8f020000-0000-4000-8000-'||lpad((n+100)::text,12,'0'))::uuid,
 ('8f020000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 now(),now(),'aal2',now()+interval '1 hour' from generate_series(101,105) n;
insert into app_private.superadmin_internal_identities(id)
select ('8f020000-0000-4000-8000-'||lpad((n+200)::text,12,'0'))::uuid from unnest(array[101,102,104,105]) n;
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
select ('8f020000-0000-4000-8000-'||lpad((n+300)::text,12,'0'))::uuid,
 ('8f020000-0000-4000-8000-'||lpad((n+200)::text,12,'0'))::uuid,
 ('8f020000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid from unnest(array[101,102,104,105]) n;
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,r.id,fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 ('8f020000-0000-4000-8000-000000000501'::uuid,'8f020000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('8f020000-0000-4000-8000-000000000502'::uuid,'8f020000-0000-4000-8000-000000000302'::uuid,'operations','institution','8f020000-0000-4000-8000-000000000010'::uuid),
 ('8f020000-0000-4000-8000-000000000504'::uuid,'8f020000-0000-4000-8000-000000000304'::uuid,'content','platform',null::uuid),
 ('8f020000-0000-4000-8000-000000000505'::uuid,'8f020000-0000-4000-8000-000000000305'::uuid,'owner','platform',null::uuid)
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles r on r.code=fixture.role_code;
-- 102 is manage-only, 104 read-only; 105 is the second real internal Owner so
-- revocation tests preserve last-owner protection instead of disabling it.
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,case
 when r.code='operations' and p.code='forms.read' then 'deny'::public.permission_effect
 when r.code='content' and p.code='forms.manage' then 'deny'::public.permission_effect
 else 'allow'::public.permission_effect end,'active'
from public.platform_roles r cross join public.platform_permissions p
where r.code in('owner','operations','content') and p.code in('forms.read','forms.manage')
on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null;
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('8f020000-0000-4000-8000-000000000603','adult','Legacy','Author','Legacy synthetic author','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('8f020000-0000-4000-8000-000000000603','8f020000-0000-4000-8000-000000000103','active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select '8f020000-0000-4000-8000-000000000603',id,'active','platform',false from public.platform_roles where code='owner';

create temporary table fauthor_cases(label text primary key,request_id uuid,payload jsonb);
insert into fauthor_cases
select 'incomplete_'||n,('8f020000-0000-4000-8000-'||lpad((n+800)::text,12,'0'))::uuid,
 jsonb_build_object(
 'id',('8f020000-0000-4000-8000-'||lpad((n+700)::text,12,'0')),
 'institution_id','8f020000-0000-4000-8000-000000000010',
 'kind','quick_poll','identity_mode','identified','response_unit','person','title','Incomplete '||n,
 'description',case n when 1 then null when 2 then '   ' when 3 then repeat('x',281) else 'Intent' end,
 'sections',jsonb_build_array(jsonb_build_object('id','section-local','title','Section','position',0,'items',
 case when n=4 then '[]'::jsonb when n=6 then
 '[{"id":"q1","kind":"short_text","label":"First","position":0},{"id":"q2","kind":"short_text","label":"Second","position":1}]'::jsonb
 when n=5 then '[{"id":"q1","kind":"information","label":"Info","position":0}]'::jsonb
 else '[{"id":"q1","kind":"short_text","label":"Question","position":0}]'::jsonb end)))
from generate_series(1,6) n;
create temporary table fauthor_results(label text primary key,body jsonb,sqlstate text,executed_as text);
-- Test-only correlation binding. No RPC or TAP is executed by these triggers.
-- BEFORE INSERT on the result binds each call's newly emitted success audit,
-- so missing and duplicated audits cannot cancel out in an aggregate count.
create temporary table fauthor_audit_capture(correlation_id uuid primary key,operation_label text);
create function pg_temp.fauthor_capture_audit() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.action_code in ('superadmin.forms.editor','superadmin.forms.draft.save') and new.outcome='success' then
  insert into pg_temp.fauthor_audit_capture values (new.correlation_id,null);
 end if;
 return new;
end$$;
create function pg_temp.fauthor_bind_success() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.body->>'ok'='true' then
  update pg_temp.fauthor_audit_capture set operation_label=new.label where operation_label is null;
 end if;
 return new;
end$$;
revoke all on function pg_temp.fauthor_capture_audit() from public,anon,authenticated,service_role;
revoke all on function pg_temp.fauthor_bind_success() from public,anon,authenticated,service_role;
create trigger fauthor_capture_success after insert on audit.audit_logs for each row execute function pg_temp.fauthor_capture_audit();
create trigger fauthor_bind_success before insert on fauthor_results for each row execute function pg_temp.fauthor_bind_success();
grant select on fauthor_cases to authenticated;
grant select,insert on fauthor_results to authenticated;

select set_config('request.jwt.claims','{"sub":"8f020000-0000-4000-8000-000000000101","session_id":"8f020000-0000-4000-8000-000000000201","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into fauthor_results
select label,public.superadmin_forms_save_draft_v2(request_id,0,payload),null,current_user from fauthor_cases;
insert into fauthor_results values ('read_created',public.superadmin_forms_editor_v2('8f020000-0000-4000-8000-000000000701'),null,current_user);
insert into fauthor_results select 'replay',public.superadmin_forms_save_draft_v2(request_id,0,payload),null,current_user from fauthor_cases where label='incomplete_1';
insert into fauthor_results select 'update',public.superadmin_forms_save_draft_v2('8f020000-0000-4000-8000-000000000900',1,payload||'{"title":"Changed"}'),null,current_user from fauthor_cases where label='incomplete_1';
insert into fauthor_results select 'replay_after_update',public.superadmin_forms_save_draft_v2(request_id,0,payload),null,current_user from fauthor_cases where label='incomplete_1';
insert into fauthor_results select 'stale',public.superadmin_forms_save_draft_v2('8f020000-0000-4000-8000-000000000901',1,payload),null,current_user from fauthor_cases where label='incomplete_1';
insert into fauthor_results select 'replay_mismatch',public.superadmin_forms_save_draft_v2(request_id,0,payload||'{"title":"Forged replay"}'),null,current_user from fauthor_cases where label='incomplete_1';
reset role;

select is(body->>'ok','true',label||' saved as draft') from fauthor_results where label like 'incomplete_%' order by label;
select is((select body#>>'{data,definition,title}' from fauthor_results where label='read_created'),'Incomplete 1','reader returns authorized definition');
select is((select body->'data' from fauthor_results where label='replay'),(select body->'data' from fauthor_results where label='incomplete_1'),'identical replay returns exact original snapshot');
select is((select body->'data' from fauthor_results where label='replay_after_update'),(select body->'data' from fauthor_results where label='incomplete_1'),'replay does not substitute later definition');
select is((select body#>>'{data,management_version}' from fauthor_results where label='update'),'2','update advances management version exactly once');
select is((select body#>>'{error,code}' from fauthor_results where label='stale'),'SAI_CONCURRENT_CHANGE','stale version rejected');
select is((select body#>>'{error,code}' from fauthor_results where label='replay_mismatch'),'SAI_INVALID_ARGUMENT','changed replay rejected');
select is((select count(*) from public.forms where created_by_internal_identity_id='8f020000-0000-4000-8000-000000000301'),6::bigint,'six forms persist with real internal creator');
select ok(not exists(select 1 from public.forms where created_by_internal_identity_id='8f020000-0000-4000-8000-000000000301' and (created_by_person_id is not null or updated_by_person_id is not null)),'no fabricated People author');
select ok(not exists(select 1 from public.form_versions v join public.forms f on f.id=v.form_id where f.created_by_internal_identity_id='8f020000-0000-4000-8000-000000000301' and (v.created_by_internal_identity_id is distinct from f.created_by_internal_identity_id or v.created_by_person_id is not null)),'version creator remains internal');
select ok(not exists(select 1 from public.forms where created_by_internal_identity_id='8f020000-0000-4000-8000-000000000301' and (first_published_at is not null or published_version_id is not null or status<>'draft')),'incomplete quick polls were never published');

-- Capability alternatives and institution isolation.
select set_config('request.jwt.claims','{"sub":"8f020000-0000-4000-8000-000000000102","session_id":"8f020000-0000-4000-8000-000000000202","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into fauthor_results values ('manage_only_read',public.superadmin_forms_editor_v2('8f020000-0000-4000-8000-000000000701'),null,current_user);
insert into fauthor_results select 'cross_institution',public.superadmin_forms_save_draft_v2('8f020000-0000-4000-8000-000000000902',0,payload||'{"id":"8f020000-0000-4000-8000-000000000799","institution_id":"8f020000-0000-4000-8000-000000000020"}'),null,current_user from fauthor_cases where label='incomplete_1';
insert into fauthor_results select 'other_actor_replay',public.superadmin_forms_save_draft_v2(request_id,0,payload),null,current_user from fauthor_cases where label='incomplete_1';
reset role;
select set_config('request.jwt.claims','{"sub":"8f020000-0000-4000-8000-000000000104","session_id":"8f020000-0000-4000-8000-000000000204","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into fauthor_results values ('read_only_read',public.superadmin_forms_editor_v2('8f020000-0000-4000-8000-000000000701'),null,current_user);
insert into fauthor_results select 'read_only_save',public.superadmin_forms_save_draft_v2('8f020000-0000-4000-8000-000000000903',2,payload),null,current_user from fauthor_cases where label='incomplete_1';
reset role;
select is((select body->>'ok' from fauthor_results where label='manage_only_read'),'true','manage-only can open editor without implicit read grant');
select is((select body->>'ok' from fauthor_results where label='read_only_read'),'true','read-only can open editor');
select is((select body#>>'{error,code}' from fauthor_results where label='read_only_save'),'SAI_PERMISSION_DENIED','read-only cannot save');
select is((select body#>>'{error,code}' from fauthor_results where label='cross_institution'),'SAI_PERMISSION_DENIED','institution A cannot create B');
select is((select body#>>'{error,code}' from fauthor_results where label='other_actor_replay'),'SAI_INVALID_ARGUMENT','another internal actor cannot replay snapshot');
select ok(not exists(select 1 from public.forms where id='8f020000-0000-4000-8000-000000000799'),'denied creation has no effect');

-- Valid People owner still cannot enter the nominal internal boundary.
select set_config('request.jwt.claims','{"sub":"8f020000-0000-4000-8000-000000000103","session_id":"8f020000-0000-4000-8000-000000000203","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into fauthor_results values ('people_only',public.superadmin_forms_editor_v2('8f020000-0000-4000-8000-000000000701'),null,current_user);
reset role;
select is((select body#>>'{error,code}' from fauthor_results where label='people_only'),'SAI_INTERNAL_CONTEXT_DENIED','People owner is not internal identity');
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
insert into fauthor_results values ('no_auth_bad_payload',public.superadmin_forms_save_draft_v2(null,-1,'[]'),null,current_user);
reset role;
select is((select body#>>'{error,code}' from fauthor_results where label='no_auth_bad_payload'),'SAI_AUTH_REQUIRED','authorization precedes untrusted payload validation');

-- Strict invalid inputs and relational graph failures cannot leave partial rows.
create temporary table fauthor_invalid(label text primary key,request_id uuid default gen_random_uuid(),payload jsonb);
insert into fauthor_invalid(label,payload) values ('null',null),('array','[]'),('missing','{}');
insert into fauthor_invalid(label,payload)
select x.label,(c.payload||'{"id":null,"kind":"form"}')||x.patch
from fauthor_cases c cross join (values
 ('title_type','{"title":7}'::jsonb),('empty_title','{"title":"  "}'::jsonb),
 ('bad_id','{"id":"bad"}'::jsonb),('bad_institution','{"institution_id":"bad"}'::jsonb),
 ('unknown','{"actor_internal_identity_id":"forged"}'::jsonb),('null_sections','{"sections":null}'::jsonb),
 ('long_title',jsonb_build_object('title',repeat('x',201))),('long_description',jsonb_build_object('description',repeat('x',4001)))
) x(label,patch) where c.label='incomplete_1';
insert into fauthor_invalid(label,payload)
select x.label,jsonb_set(c.payload||'{"id":null,"kind":"form"}','{sections,0,items}',x.items)
from fauthor_cases c cross join (values
 ('duplicate_id','[{"id":"q1","kind":"short_text","label":"One","position":0},{"id":"q1","kind":"short_text","label":"Two","position":1}]'::jsonb),
 ('position_gap','[{"id":"q1","kind":"short_text","label":"One","position":2}]'::jsonb),
 ('required_type','[{"id":"q1","kind":"short_text","label":"One","position":0,"is_required":"true"}]'::jsonb),
 ('choice_empty','[{"id":"q1","kind":"single_choice","label":"One","position":0,"options":[]}]'::jsonb),
 ('bad_config','[{"id":"q1","kind":"short_text","label":"One","position":0,"config":{"allow_camera":true}}]'::jsonb),
 ('missing_source','[{"id":"q1","kind":"short_text","label":"One","position":0,"conditions":[{"kind":"yes_no","source_item_id":"missing","expected_yes_no":true}]}]'::jsonb),
 ('bad_expected','[{"id":"q1","kind":"yes_no","label":"One","position":0},{"id":"q2","kind":"short_text","label":"Two","position":1,"conditions":[{"kind":"yes_no","source_item_id":"q1","expected_yes_no":"true"}]}]'::jsonb),
 ('cycle','[{"id":"q1","kind":"yes_no","label":"One","position":0,"conditions":[{"kind":"yes_no","source_item_id":"q2","expected_yes_no":true}]},{"id":"q2","kind":"yes_no","label":"Two","position":1,"conditions":[{"kind":"yes_no","source_item_id":"q1","expected_yes_no":true}]}]'::jsonb),
 ('wrong_option_owner','[{"id":"q1","kind":"single_choice","label":"One","position":0,"options":[{"id":"a","label":"A","position":0},{"id":"b","label":"B","position":1}]},{"id":"q2","kind":"single_choice","label":"Two","position":1,"options":[{"id":"c","label":"C","position":0},{"id":"d","label":"D","position":1}]},{"id":"q3","kind":"short_text","label":"Three","position":2,"conditions":[{"kind":"choice","source_item_id":"q1","option_ids":["c"]}]}]'::jsonb)
) x(label,items) where c.label='incomplete_1';
insert into fauthor_invalid(label,payload)
select 'depth_five',jsonb_set(c.payload||'{"id":null,"kind":"form"}','{sections,0,items}',
 (select jsonb_agg(jsonb_build_object('id','q'||n,'kind','yes_no','label','Question '||n,'position',n-1,
 'conditions',case when n=1 then '[]'::jsonb else jsonb_build_array(jsonb_build_object('kind','yes_no','source_item_id','q'||(n-1),'expected_yes_no',true)) end) order by n) from generate_series(1,6) n))
from fauthor_cases c where c.label='incomplete_1';
grant select on fauthor_invalid to authenticated;
select set_config('request.jwt.claims','{"sub":"8f020000-0000-4000-8000-000000000101","session_id":"8f020000-0000-4000-8000-000000000201","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into fauthor_results select 'invalid_'||label,public.superadmin_forms_save_draft_v2(request_id,0,payload),null,current_user from fauthor_invalid;
reset role;
select is(body#>>'{error,code}','SAI_INVALID_ARGUMENT',label||' rejected') from fauthor_results where label like 'invalid_%' order by label;
select is((select count(*) from public.forms where created_by_internal_identity_id='8f020000-0000-4000-8000-000000000301'),6::bigint,'invalid graphs roll back all new forms');
select ok(not exists(select 1 from app_private.superadmin_internal_form_draft_receipts r join fauthor_invalid i using(request_id)),'invalid payloads leave no receipt');

-- AuthLink and membership revocation must reauthorize before receipt retrieval.
update app_private.superadmin_internal_auth_links set status='revoked',revoked_at=now() where id='8f020000-0000-4000-8000-000000000401';
set local role authenticated;
insert into fauthor_results select 'revoked_link_replay',public.superadmin_forms_save_draft_v2(request_id,0,payload),null,current_user from fauthor_cases where label='incomplete_1';
reset role;
update app_private.superadmin_internal_auth_links set status='active',revoked_at=null where id='8f020000-0000-4000-8000-000000000401';
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now() where id='8f020000-0000-4000-8000-000000000501';
set local role authenticated;
insert into fauthor_results select 'revoked_membership_replay',public.superadmin_forms_save_draft_v2(request_id,0,payload),null,current_user from fauthor_cases where label='incomplete_1';
reset role;
update app_private.superadmin_internal_memberships set status='active',revoked_at=null where id='8f020000-0000-4000-8000-000000000501';
select is((select body#>>'{error,code}' from fauthor_results where label='revoked_link_replay'),'SAI_INTERNAL_CONTEXT_DENIED','revoked link cannot replay');
select is((select body#>>'{error,code}' from fauthor_results where label='revoked_membership_replay'),'SAI_MEMBERSHIP_REVOKED','revoked membership cannot replay');

-- Legacy success receipts are deliberately seeded: the new boundary must run
-- before replay, not merely before a write. No internal actor gets a People ID.
create temporary table fauthor_legacy(label text primary key,command text,request_id uuid default gen_random_uuid(),payload jsonb);
insert into fauthor_legacy(label,command,payload) values
 ('publish','form_publish','{"form_id":"8f020000-0000-4000-8000-000000000701"}'),
 ('duplicate','form_duplicate','{"form_id":"8f020000-0000-4000-8000-000000000701"}'),
 ('copy','form_copy_or_move','{"form_id":"8f020000-0000-4000-8000-000000000701","target_institution_id":"8f020000-0000-4000-8000-000000000010","mode":"copy"}'),
 ('archive','form_archive_or_delete','{"form_id":"8f020000-0000-4000-8000-000000000701","action":"archive"}'),
 ('export','form_request_export','{"form_id":"8f020000-0000-4000-8000-000000000701","kind":"xlsx"}'),
 ('anonymous_export','form_request_anonymous_participation_export','{"form_id":"8f020000-0000-4000-8000-000000000701","justification":"Synthetic justified request"}'),
 ('application','form_save_application','{"form_id":"8f020000-0000-4000-8000-000000000701","institution_id":"8f020000-0000-4000-8000-000000000010","name":"Must not create","rules":[]}');
insert into fauthor_legacy(label,command,payload) select 'save','form_save_draft',payload from fauthor_cases where label='incomplete_1';
-- Unexpected dependency is a fixture, not a supported route into internal data.
insert into public.form_applications(id,form_id,institution_id,name,created_by_person_id) values
 ('8f020000-0000-4000-8000-000000000760','8f020000-0000-4000-8000-000000000706','8f020000-0000-4000-8000-000000000010','Unexpected synthetic dependency','8f020000-0000-4000-8000-000000000603');
insert into public.form_schedules(id,application_id,time_zone,starts_at_local,recurrence_kind) values
 ('8f020000-0000-4000-8000-000000000761','8f020000-0000-4000-8000-000000000760','UTC',now() at time zone 'UTC','once');
insert into fauthor_legacy(label,command,payload) values
 ('schedule','form_save_schedule','{"schedule_id":"8f020000-0000-4000-8000-000000000761","application_id":"8f020000-0000-4000-8000-000000000760","time_zone":"UTC","starts_at_local":"2026-09-08T10:00:00","recurrence_kind":"once"}'),
 ('remove_schedule','form_remove_schedule','{"schedule_id":"8f020000-0000-4000-8000-000000000761"}');
insert into app_private.form_command_receipts(request_id,actor_person_id,command_name,request_hash,expected_version,result_jsonb,completed_at)
select request_id,'8f020000-0000-4000-8000-000000000603',command,
 extensions.digest(convert_to(command||':2:'||payload::text,'UTF8'),'sha256'),2,'{"probe":"must-not-replay"}',now()
from fauthor_legacy;
grant select on fauthor_legacy to authenticated;
select set_config('request.jwt.claims','{"sub":"8f020000-0000-4000-8000-000000000103","session_id":"8f020000-0000-4000-8000-000000000203","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
do $$declare c record; result jsonb; fault text; begin
 for c in select * from fauthor_legacy loop
  begin
   execute format('select public.%I($1,$2,$3)',c.command) into result using c.request_id,2::bigint,c.payload;
   insert into fauthor_results values ('legacy_'||c.label,result,'NO_EXCEPTION',current_user);
  exception when others then
   get stacked diagnostics fault=returned_sqlstate;
   insert into fauthor_results values ('legacy_'||c.label,null,fault,current_user);
  end;
 end loop;
end$$;
insert into fauthor_results values ('legacy_list',public.form_list('{"institution_id":"8f020000-0000-4000-8000-000000000010","limit":1}'),null,current_user);
do $$declare command text; result jsonb; fault text; begin
 foreach command in array array['form_get_editor','form_get_overview','form_get_monitor','form_list_monitor_hierarchy','form_list_monitor_people','form_anonymous_participation_lookup'] loop
  begin
   if command in ('form_get_editor','form_get_overview') then
    execute format('select public.%I($1)',command) into result using '8f020000-0000-4000-8000-000000000701'::uuid;
   else
    execute format('select public.%I($1)',command) into result using '{"form_id":"8f020000-0000-4000-8000-000000000701","justification":"Synthetic justified request"}'::jsonb - case when command='form_anonymous_participation_lookup' then 'unused' else 'justification' end;
   end if;
   insert into fauthor_results values ('legacy_read_'||command,result,'NO_EXCEPTION',current_user);
  exception when others then
   get stacked diagnostics fault=returned_sqlstate;
   insert into fauthor_results values ('legacy_read_'||command,null,fault,current_user);
  end;
 end loop;
end$$;
reset role;
select is(r.sqlstate,case when c.label='application' then '22023' else 'P0002' end,'legacy entry blocked before seeded successful receipt: '||c.label)
from fauthor_legacy c join fauthor_results r on r.label='legacy_'||c.label;
select is(sqlstate,'P0002','legacy reader denies protected form: '||label) from fauthor_results where label like 'legacy_read_%';
select is((select body->'items' from fauthor_results where label='legacy_list'),'[]'::jsonb,'legacy list excludes protected drafts before limit');
select is((select body->>'has_more' from fauthor_results where label='legacy_list'),'false','pagination does not count protected drafts');
select ok(not exists(select 1 from fauthor_results where label like 'legacy_%' and body::text like '%must-not-replay%'),'no seeded receipt bypassed resource guard');
select ok(not exists(select 1 from public.form_file_jobs where institution_id='8f020000-0000-4000-8000-000000000010'),'legacy requests created no file jobs');
select ok(not exists(select 1 from public.form_occurrences where institution_id='8f020000-0000-4000-8000-000000000010'),'legacy requests created no occurrences');
select is((select count(*) from public.form_applications where institution_id='8f020000-0000-4000-8000-000000000010'),1::bigint,'only deliberate application fixture exists');

-- Existing delete-and-replay remains valid even after the resource disappears.
insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_person_id,updated_by_person_id) values
 ('8f020000-0000-4000-8000-000000000750','8f020000-0000-4000-8000-000000000010','form','identified','person','Legacy removable','8f020000-0000-4000-8000-000000000603','8f020000-0000-4000-8000-000000000603');
create temporary table fauthor_legacy_controls(label text,command text,request_id uuid default gen_random_uuid(),payload jsonb);
insert into fauthor_legacy_controls(label,command,payload)
select label,command,payload||jsonb_build_object(case when command='form_save_draft' then 'id' else 'form_id' end,'8f020000-0000-4000-8000-000000000750')
from fauthor_legacy where label not in ('application','schedule','remove_schedule');
insert into app_private.form_command_receipts(request_id,actor_person_id,command_name,request_hash,expected_version,result_jsonb,completed_at)
select request_id,'8f020000-0000-4000-8000-000000000603',command,
 extensions.digest(convert_to(command||':2:'||payload::text,'UTF8'),'sha256'),2,'{"probe":"legacy-replay-preserved"}',now()
from fauthor_legacy_controls;
grant select on fauthor_legacy_controls to authenticated;
set local role authenticated;
do $$declare c record; result jsonb; begin
 for c in select * from fauthor_legacy_controls loop
  execute format('select public.%I($1,$2,$3)',c.command) into result using c.request_id,2::bigint,c.payload;
  insert into fauthor_results values ('legacy_control_'||c.label,result,null,current_user);
 end loop;
end$$;
reset role;
select is(body->>'probe','legacy-replay-preserved','existing legacy receipt semantics preserved: '||label)
from fauthor_results where label like 'legacy_control_%';
set local role authenticated;
insert into fauthor_results values
 ('legacy_delete_control',public.form_archive_or_delete('8f020000-0000-4000-8000-000000000950',1,'{"form_id":"8f020000-0000-4000-8000-000000000750","action":"delete"}'),null,current_user),
 ('legacy_delete_replay',public.form_archive_or_delete('8f020000-0000-4000-8000-000000000950',1,'{"form_id":"8f020000-0000-4000-8000-000000000750","action":"delete"}'),null,current_user);
reset role;
select is((select body from fauthor_results where label='legacy_delete_replay'),(select body from fauthor_results where label='legacy_delete_control'),'missing resource does not invalidate historical delete replay');
select ok(not exists(select 1 from public.forms where id='8f020000-0000-4000-8000-000000000750'),'legacy control really was deleted');

-- Five choice questions, four logical edges, fifty option rows per edge.
-- A path-enumerating validator would amplify this to millions of rows.
create temporary table fauthor_fanout(payload jsonb);
insert into fauthor_fanout
select jsonb_set(c.payload||'{"id":null,"kind":"form","title":"Bounded fanout"}','{sections,0,items}',
 (select jsonb_agg(jsonb_build_object('id','q'||n,'kind','single_choice','label','Question '||n,'position',n-1,
 'options',(select jsonb_agg(jsonb_build_object('id','q'||n||'-o'||v,'label','Option '||v,'position',v-1) order by v) from generate_series(1,50) v),
 'conditions',case when n=1 then '[]'::jsonb else jsonb_build_array(jsonb_build_object('kind','choice','source_item_id','q'||(n-1),
 'option_ids',(select jsonb_agg('q'||(n-1)||'-o'||v order by v) from generate_series(1,50) v))) end) order by n)
 from generate_series(1,5) n)) from fauthor_cases c where c.label='incomplete_1';
grant select on fauthor_fanout to authenticated;
select set_config('request.jwt.claims','{"sub":"8f020000-0000-4000-8000-000000000101","session_id":"8f020000-0000-4000-8000-000000000201","aal":"aal2","role":"authenticated"}',true);
set local statement_timeout='5s';
set local role authenticated;
do $$declare result jsonb; fault text; begin
 begin
  select public.superadmin_forms_save_draft_v2('8f020000-0000-4000-8000-000000000970',0,payload) into result from fauthor_fanout;
  insert into fauthor_results values ('bounded_fanout',result,null,current_user);
 exception when query_canceled then
  get stacked diagnostics fault=returned_sqlstate;
  insert into fauthor_results values ('bounded_fanout',null,fault,current_user);
 end;
end$$;
reset role;
set local statement_timeout=0;
select is((select body->>'ok' from fauthor_results where label='bounded_fanout'),'true','option fanout stays bounded and a valid four-level graph saves');

-- Dense DAGs also deduplicate states, not only option-row edges.
create temporary table fauthor_dense(label text,request_id uuid,payload jsonb);
insert into fauthor_dense
select 'dense_'||layers,('8f020000-0000-4000-8000-'||lpad((980+layers)::text,12,'0'))::uuid,
 jsonb_set(c.payload||'{"id":null,"kind":"form","title":"Dense bounded graph"}','{sections,0,items}',
 (select jsonb_agg(jsonb_build_object('id','q'||n,'kind','yes_no','label','Question '||n,'position',n-1,
 'conditions',case when n<=20 then '[]'::jsonb else
 (select jsonb_agg(jsonb_build_object('kind','yes_no','source_item_id','q'||v,'expected_yes_no',true) order by v)
 from generate_series(((n-1)/20-1)*20+1,((n-1)/20)*20) v) end) order by n)
 from generate_series(1,layers*20) n))
from fauthor_cases c cross join generate_series(5,6) layers where c.label='incomplete_1';
grant select on fauthor_dense to authenticated;
set local statement_timeout='5s';
set local role authenticated;
do $$declare c record; result jsonb; fault text; begin
 for c in select * from fauthor_dense where label='dense_5' loop
  begin
   result:=public.superadmin_forms_save_draft_v2(c.request_id,0,c.payload);
   insert into fauthor_results values (c.label,result,null,current_user);
  exception when query_canceled then
   get stacked diagnostics fault=returned_sqlstate;
   insert into fauthor_results values (c.label,null,fault,current_user);
  end;
 end loop;
end$$;
do $$declare c record; result jsonb; fault text; begin
 for c in select * from fauthor_dense where label='dense_6' loop
  begin
   result:=public.superadmin_forms_save_draft_v2(c.request_id,0,c.payload);
   insert into fauthor_results values (c.label,result,null,current_user);
  exception when query_canceled then
   get stacked diagnostics fault=returned_sqlstate;
   insert into fauthor_results values (c.label,null,fault,current_user);
  end;
 end loop;
end$$;
reset role;
set local statement_timeout=0;
select is((select body->>'ok' from fauthor_results where label='dense_5'),'true','dense valid four-edge DAG remains bounded');
select is((select body#>>'{error,code}' from fauthor_results where label='dense_6'),'SAI_INVALID_ARGUMENT','dense five-edge DAG is rejected within the bound');
select ok(not exists(select 1 from app_private.superadmin_internal_form_draft_receipts where request_id='8f020000-0000-4000-8000-000000000986'),'rejected dense graph leaves no receipt');

-- A real B resource must not be read or relabeled as A by its identifier.
set local role authenticated;
insert into fauthor_results select 'owner_create_b',public.superadmin_forms_save_draft_v2('8f020000-0000-4000-8000-000000000971',0,
 payload||'{"id":"8f020000-0000-4000-8000-000000000799","institution_id":"8f020000-0000-4000-8000-000000000020","title":"B private title"}'),null,current_user
from fauthor_cases where label='incomplete_1';
reset role;
select set_config('request.jwt.claims','{"sub":"8f020000-0000-4000-8000-000000000102","session_id":"8f020000-0000-4000-8000-000000000202","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into fauthor_results values ('a_read_b',public.superadmin_forms_editor_v2('8f020000-0000-4000-8000-000000000799'),null,current_user);
insert into fauthor_results select 'a_relabel_b',public.superadmin_forms_save_draft_v2('8f020000-0000-4000-8000-000000000972',1,
 payload||'{"id":"8f020000-0000-4000-8000-000000000799"}'),null,current_user from fauthor_cases where label='incomplete_1';
reset role;
select is((select body->>'ok' from fauthor_results where label='owner_create_b'),'true','B fixture created through authorized nominal API');
select is((select body#>>'{error,code}' from fauthor_results where label='a_read_b'),'SAI_PERMISSION_DENIED','A cannot read B by ID');
select is((select body#>>'{error,code}' from fauthor_results where label='a_relabel_b'),'SAI_PERMISSION_DENIED','A cannot relabel existing B by forged institution');
select ok(not exists(select 1 from fauthor_results where label in('a_read_b','a_relabel_b') and body::text like '%B private title%'),'cross-tenant denial contains no B data');
select set_config('request.jwt.claims','{"sub":"8f020000-0000-4000-8000-000000000101","session_id":"8f020000-0000-4000-8000-000000000201","aal":"aal2","role":"authenticated"}',true);

-- Audit is mandatory for success, replay and identified denials, with no graph.
-- Soft-deleted institutions cannot expose a draft snapshot, including receipts.
-- These are sequential RED contracts, not proof of the two-connection races.
update public.institutions set deleted_at=now() where id='8f020000-0000-4000-8000-000000000010';
set local role authenticated;
insert into fauthor_results values ('deleted_institution_read',public.superadmin_forms_editor_v2('8f020000-0000-4000-8000-000000000701'),null,current_user);
insert into fauthor_results select 'deleted_institution_replay',public.superadmin_forms_save_draft_v2(request_id,0,payload),null,current_user from fauthor_cases where label='incomplete_1';
insert into fauthor_results select 'deleted_institution_edit',public.superadmin_forms_save_draft_v2('8f020000-0000-4000-8000-000000000987',2,payload||'{"title":"Deleted target must not change"}'),null,current_user from fauthor_cases where label='incomplete_1';
insert into fauthor_results select 'deleted_institution_create',public.superadmin_forms_save_draft_v2('8f020000-0000-4000-8000-000000000988',0,payload||'{"id":"8f020000-0000-4000-8000-000000000797"}'),null,current_user from fauthor_cases where label='incomplete_1';
reset role;
select is(body#>>'{error,code}','SAI_PERMISSION_DENIED',label||' denied') from fauthor_results where label like 'deleted_institution_%';
select ok(not exists(select 1 from fauthor_results where label like 'deleted_institution_%' and body->'data' is distinct from 'null'::jsonb),'deleted institution exposes no snapshot');
select is((select title from public.forms where id='8f020000-0000-4000-8000-000000000701'),'Changed','deleted institution leaves existing draft unchanged');
select ok(not exists(select 1 from public.forms where id='8f020000-0000-4000-8000-000000000797'),'deleted institution create has no effect');
select ok(not exists(select 1 from app_private.superadmin_internal_form_draft_receipts where request_id in('8f020000-0000-4000-8000-000000000987','8f020000-0000-4000-8000-000000000988')),'deleted institution creates no receipt');
update public.institutions set deleted_at=null,status='inactive' where id='8f020000-0000-4000-8000-000000000010';
set local role authenticated;
insert into fauthor_results values ('inactive_institution_read',public.superadmin_forms_editor_v2('8f020000-0000-4000-8000-000000000701'),null,current_user);
reset role;
select is((select body->>'ok' from fauthor_results where label='inactive_institution_read'),'true','inactive is not silently treated as soft-deleted for draft reading');
update public.institutions set status='active' where id='8f020000-0000-4000-8000-000000000010';

select is((select count(*) from audit.audit_logs where action_code in('superadmin.forms.editor','superadmin.forms.draft.save') and outcome='success'),
 (select count(*) from fauthor_results where body->>'ok'='true'),'one audit for each successful nominal operation including replay');
select is((select count(*) from fauthor_audit_capture c where c.operation_label=r.label),1::bigint,'exactly one correlated success audit for '||r.label)
from fauthor_results r where r.body->>'ok'='true';
select ok(not exists(select 1 from fauthor_audit_capture where operation_label is null),'no unbound nominal success audit remains');
select ok(not exists(select 1 from fauthor_results r where r.label like 'invalid_%' and
 (select count(*) from audit.audit_logs a where a.correlation_id=(r.body#>>'{error,correlation_id}')::uuid and a.outcome='denied' and a.reason_code='SAI_INVALID_ARGUMENT')<>1),'every invalid payload denial has one correlated audit');
select ok(exists(select 1 from audit.audit_logs a join fauthor_results r on a.correlation_id=(r.body#>>'{error,correlation_id}')::uuid
 where r.label='people_only' and a.actor_kind='auth_session' and a.hash_version=3 and a.actor_internal_identity_id is null and a.actor_person_id is null),'People-only valid session is audited as minimized session, not fake actor');
select ok(not exists(select 1 from audit.audit_logs a where a.action_code in('superadmin.forms.editor','superadmin.forms.draft.save')
 and (a.before_json is not null or a.after_json is not null or a.actor_person_id is not null
 or to_jsonb(a)::text like '%Incomplete%' or to_jsonb(a)::text like '%@invalid.test%' or to_jsonb(a)::text like '%section-local%')),'audit contains no question graph, PII or legacy author');
select ok(exists(select 1 from audit.audit_logs a where a.action_code='superadmin.forms.editor' and a.outcome='success'
 and a.actor_internal_identity_id='8f020000-0000-4000-8000-000000000304' and a.permission_code='forms.read'),'read-only fallback audits its actual permission');
select ok((select bool_and(app_private.audit_verify_entry(id)) from audit.audit_logs where action_code in('superadmin.forms.editor','superadmin.forms.draft.save')),'nominal audit digest chain verifies');

create function pg_temp.fauthor_reject_audit() returns trigger language plpgsql as $$begin
 if new.action_code in ('superadmin.forms.editor','superadmin.forms.draft.save') then
  raise exception using errcode='P0001',message='forced FAUTHOR audit failure';
 end if;
 return new;
end$$;
create trigger fauthor_audit_forced_failure before insert on audit.audit_logs for each row execute function pg_temp.fauthor_reject_audit();
set local role authenticated;
do $$declare fault text; msg text; payload jsonb; begin
 select c.payload||'{"id":"8f020000-0000-4000-8000-000000000798"}' into payload from fauthor_cases c where c.label='incomplete_1';
 begin
  perform public.superadmin_forms_save_draft_v2('8f020000-0000-4000-8000-000000000978',0,payload);
  insert into fauthor_results values ('audit_create',null,'NO_EXCEPTION',current_user);
 exception when others then
  get stacked diagnostics fault=returned_sqlstate,msg=message_text;
  insert into fauthor_results values ('audit_create',jsonb_build_object('message',msg),fault,current_user);
 end;
 begin
  perform public.superadmin_forms_save_draft_v2('8f020000-0000-4000-8000-000000000979',0,'{}');
  insert into fauthor_results values ('audit_denial',null,'NO_EXCEPTION',current_user);
 exception when others then
  get stacked diagnostics fault=returned_sqlstate,msg=message_text;
  insert into fauthor_results values ('audit_denial',jsonb_build_object('message',msg),fault,current_user);
 end;
 begin
  perform public.superadmin_forms_editor_v2('8f020000-0000-4000-8000-000000000701');
  insert into fauthor_results values ('audit_reader',null,'NO_EXCEPTION',current_user);
 exception when others then
  get stacked diagnostics fault=returned_sqlstate,msg=message_text;
  insert into fauthor_results values ('audit_reader',jsonb_build_object('message',msg),fault,current_user);
 end;
end$$;
reset role;
drop trigger fauthor_audit_forced_failure on audit.audit_logs;
drop trigger fauthor_capture_success on audit.audit_logs;
select is(sqlstate,'P0001','audit failure escapes business envelope: '||label) from fauthor_results where label like 'audit_%';
select is(body->>'message','forced FAUTHOR audit failure','original audit failure preserved: '||label) from fauthor_results where label like 'audit_%';
select ok(not exists(select 1 from public.forms where id='8f020000-0000-4000-8000-000000000798'),'audit failure rolls back inserted form');
select ok(not exists(select 1 from app_private.superadmin_internal_form_draft_receipts where request_id='8f020000-0000-4000-8000-000000000978'),'audit failure rolls back command receipt');
select ok((select bool_and(executed_as='authenticated') from fauthor_results),'all application RPCs executed as authenticated, never postgres');
select * from finish();
rollback;
