-- C02 / I005 LOCAL WIP. Rollback-only synthetic catalog/job tests.
-- Worker/capture/reconciliation tests follow when those reserved RPCs exist.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
create function pg_temp.xlsx_id(n integer) returns uuid language sql immutable as $$
  select ('8c021000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
insert into public.institution_types(id,code,name,status)
values(pg_temp.xlsx_id(1),'c02-xlsx-test','Synthetic XLSX type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status)
select pg_temp.xlsx_id(n),pg_temp.xlsx_id(1),'Synthetic XLSX '||n,'c02-xlsx-'||n,'active'
from unnest(array[10,20]) n;
insert into public.people(id,person_type,first_name,last_name,display_name,status)
values(pg_temp.xlsx_id(1000),'adult','Synthetic','Legacy','Synthetic legacy form author','active');
insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_person_id,updated_by_person_id)
select pg_temp.xlsx_id(n),pg_temp.xlsx_id(case when n=220 then 20 else 10 end),
  'form','identified','person','Synthetic form '||n,pg_temp.xlsx_id(1000),pg_temp.xlsx_id(1000)
from unnest(array[210,220]) n;
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select pg_temp.xlsx_id(n),'authenticated','authenticated','c02-xlsx-'||n||'@invalid.test',now(),now(),now(),'{}','{}'
from unnest(array[101,102]) n;
insert into app_private.superadmin_internal_identities(id) select pg_temp.xlsx_id(n) from unnest(array[301,302]) n;
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
select pg_temp.xlsx_id(n+300),pg_temp.xlsx_id(n+200),pg_temp.xlsx_id(n) from unnest(array[101,102]) n;
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select pg_temp.xlsx_id(n+400),pg_temp.xlsx_id(n+200),r.id,'institution',pg_temp.xlsx_id(10)
from unnest(array[101,102]) n cross join public.platform_roles r where r.code='operations';

create function pg_temp.xlsx_job(n integer,patch jsonb default '{}'::jsonb) returns void language plpgsql as $$
declare j public.form_file_jobs;
begin
  j:=jsonb_populate_record(null::public.form_file_jobs,jsonb_build_object(
    'id',pg_temp.xlsx_id(n),'form_id',pg_temp.xlsx_id(210),'institution_id',pg_temp.xlsx_id(10),
    'request_id',pg_temp.xlsx_id(n+10000),'export_kind','xlsx','state','pending','artifact_provider','r2',
    'requested_by_internal_identity_id',pg_temp.xlsx_id(301),'requested_auth_link_id',pg_temp.xlsx_id(401),
    'requested_membership_id',pg_temp.xlsx_id(501),'requested_auth_session_id',pg_temp.xlsx_id(201),
    'requested_scope_kind','institution','requested_scope_institution_id',pg_temp.xlsx_id(10),
    'requested_management_version',1,'request_payload_sha256',repeat('a',64),
    'snapshot_format_version',1,'snapshot_row_count',0,'snapshot_ready',false)||patch);
  insert into public.form_file_jobs(id,form_id,institution_id,requested_by_person_id,request_id,export_kind,state,
    artifact_provider,requested_by_internal_identity_id,requested_auth_link_id,requested_membership_id,
    requested_auth_session_id,requested_scope_kind,requested_scope_institution_id,requested_management_version,
    request_payload_sha256,snapshot_format_version,snapshot_row_count,snapshot_ready)
  values(j.id,j.form_id,j.institution_id,j.requested_by_person_id,j.request_id,j.export_kind,j.state,
    j.artifact_provider,j.requested_by_internal_identity_id,j.requested_auth_link_id,j.requested_membership_id,
    j.requested_auth_session_id,j.requested_scope_kind,j.requested_scope_institution_id,j.requested_management_version,
    j.request_payload_sha256,j.snapshot_format_version,j.snapshot_row_count,j.snapshot_ready);
end;
$$;
create function pg_temp.xlsx_asset(n integer,job_number integer,patch jsonb default '{}'::jsonb)
returns void language plpgsql as $$
declare a public.media_assets; j public.form_file_jobs; data jsonb;
begin
  select * into j from public.form_file_jobs where id=pg_temp.xlsx_id(job_number);
  data:=jsonb_build_object('id',pg_temp.xlsx_id(n),'institution_id',j.institution_id,'form_id',j.form_id,
    'owner_internal_identity_id',j.requested_by_internal_identity_id,'upload_request_id','synthetic-'||n,
    'catalog_kind','form-xlsx','media_purpose','forms-responses-export','export_file_job_id',j.id,
    'storage_provider','r2','bucket_id','coelo-transient-prod','original_name','',
    'mime_type','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','status','pending',
    'expires_at',j.expires_at,'object_key','tenants/'||j.institution_id::text||'/exports/forms/'
      ||j.id::text||'/'||pg_temp.xlsx_id(n)::text||'/responses.xlsx')||patch;
  a:=jsonb_populate_record(null::public.media_assets,data);
  insert into public.media_assets(id,institution_id,form_id,owner_person_id,owner_internal_identity_id,
    upload_request_id,catalog_kind,media_purpose,export_file_job_id,storage_provider,bucket_id,original_name,
    mime_type,status,expires_at,object_key,byte_size,checksum_sha256,pixel_width,pixel_height)
  values(a.id,a.institution_id,a.form_id,a.owner_person_id,a.owner_internal_identity_id,
    a.upload_request_id,a.catalog_kind,a.media_purpose,a.export_file_job_id,a.storage_provider,a.bucket_id,a.original_name,
    a.mime_type,a.status,a.expires_at,a.object_key,a.byte_size,a.checksum_sha256,a.pixel_width,a.pixel_height);
  update public.form_file_jobs set artifact_media_asset_id=a.id,state='processing' where id=j.id;
  set constraints all immediate;
  set constraints all deferred;
end;
$$;
create function pg_temp.xlsx_close_snapshot(n integer,expected_count bigint) returns void language plpgsql as $$
begin
  update public.form_file_jobs set snapshot_ready=true,snapshot_row_count=expected_count where id=pg_temp.xlsx_id(n);
  set constraints all immediate;
  set constraints all deferred;
end;
$$;
create function pg_temp.xlsx_complete(n integer,actual_bytes bigint) returns void language plpgsql as $$
begin
  update public.media_assets set status='ready',byte_size=100,checksum_sha256=repeat('b',64),finalized_at=clock_timestamp()
    where id=(select artifact_media_asset_id from public.form_file_jobs where id=pg_temp.xlsx_id(n));
  update public.form_file_jobs set state='succeeded',snapshot_ready=true,artifact_byte_length=actual_bytes,
    completed_at=clock_timestamp(),progress=1 where id=pg_temp.xlsx_id(n);
  set constraints all immediate;
  set constraints all deferred;
end;
$$;

select lives_ok($$select pg_temp.xlsx_job(700)$$,'internal XLSX job needs no People surrogate');
select is((select requested_by_person_id from public.form_file_jobs where id=pg_temp.xlsx_id(700)),null::uuid,'internal job has no person owner');
select throws_ok($$select pg_temp.xlsx_job(701,jsonb_build_object('requested_by_person_id',pg_temp.xlsx_id(1000)))$$,'23514',null,'mixed actor realms rejected');
select throws_ok($$select pg_temp.xlsx_job(701,'{"requested_by_internal_identity_id":null}')$$,'23514',null,'ownerless internal job rejected');
select throws_ok($$select pg_temp.xlsx_job(701,jsonb_build_object('requested_auth_link_id',pg_temp.xlsx_id(402)))$$,'23514','forms_xlsx_job_actor_mismatch','another identity auth link rejected');
select throws_ok($$select pg_temp.xlsx_job(701,jsonb_build_object('requested_membership_id',pg_temp.xlsx_id(502)))$$,'23514','forms_xlsx_job_actor_mismatch','another identity membership rejected');
select throws_ok($$select pg_temp.xlsx_job(701,'{"requested_auth_session_id":null}')$$,'23514',null,'session provenance required');
select throws_ok($$select pg_temp.xlsx_job(701,'{"export_kind":"csv"}')$$,'23514',null,'new R2 path refuses CSV');
select throws_ok($$select pg_temp.xlsx_job(701,jsonb_build_object('form_id',pg_temp.xlsx_id(220)))$$,'23514',null,'form in another tenant rejected');
select throws_ok($$select pg_temp.xlsx_job(701,jsonb_build_object('request_id',pg_temp.xlsx_id(10700)))$$,'23505',null,'internal request ID is unique');
select throws_ok($$update public.form_file_jobs set artifact_provider='supabase_mvp' where id=pg_temp.xlsx_id(700)$$,'23514','forms_xlsx_job_origin_immutable','provider cannot change realms');
select throws_ok($$update public.form_file_jobs set expires_at=expires_at+interval '1 day' where id=pg_temp.xlsx_id(700)$$,'23514','forms_xlsx_job_identity_immutable','expiry cannot be silently extended');

select lives_ok($$select pg_temp.xlsx_asset(800,700)$$,'pending original is bound to the actual internal form job');
select throws_ok($$select pg_temp.xlsx_asset(801,700)$$,'23505',null,'second live attempt cannot overwrite first');
select lives_ok($$select pg_temp.xlsx_job(710)$$,'second job for scope negatives');
select throws_ok($$select pg_temp.xlsx_asset(810,710,jsonb_build_object('institution_id',pg_temp.xlsx_id(20)))$$,'23514',null,'asset tenant cannot differ from job');
select throws_ok($$select pg_temp.xlsx_asset(810,710,jsonb_build_object('owner_internal_identity_id',pg_temp.xlsx_id(302)))$$,'23514','forms_xlsx_asset_scope_invalid','asset owner must be job owner');
select throws_ok($$select pg_temp.xlsx_asset(810,710,'{"bucket_id":"public"}')$$,'23514',null,'public bucket rejected');
select throws_ok($$select pg_temp.xlsx_asset(810,710,'{"mime_type":"text/csv"}')$$,'23514',null,'MIME is the XLSX original only');
select throws_ok($$select pg_temp.xlsx_asset(810,710,'{"byte_size":100}')$$,'23514',null,'pending bytes cannot masquerade as measurement');
select throws_ok($$select pg_temp.xlsx_asset(810,710,jsonb_build_object('expires_at',now()+interval '1 hour'))$$,'23514','forms_xlsx_asset_scope_invalid','asset expiry is the job expiry');
select throws_ok($$select pg_temp.xlsx_asset(810,710,jsonb_build_object('object_key','tenants/'||pg_temp.xlsx_id(10)::text||'/exports/forms/'||pg_temp.xlsx_id(710)::text||'/responses.xlsx'))$$,'23514',null,'unversioned attempt key rejected');
select throws_ok($$select pg_temp.xlsx_complete(700,101)$$,'23514','forms_xlsx_original_required','job bytes must match catalog measurement');
select lives_ok($$select pg_temp.xlsx_complete(700,100)$$,'ready original and succeeded job commit together');
select throws_ok($$update public.media_assets set byte_size=99 where id=pg_temp.xlsx_id(800)$$,'23514','media_catalog_identity_immutable','final content metadata is immutable');
select throws_ok($$update public.form_file_jobs set state='processing' where id=pg_temp.xlsx_id(700)$$,'23514','forms_xlsx_job_identity_immutable','completed artifact cannot be retried over winner');

select lives_ok($$insert into app_private.form_xlsx_snapshot_rows values(pg_temp.xlsx_id(710),1,pg_temp.xlsx_id(910),jsonb_build_object('responseId',pg_temp.xlsx_id(910),'metadata',jsonb_build_object('form_id',pg_temp.xlsx_id(210))))$$,'snapshot binds opaque response to form job');
select throws_ok($$select pg_temp.xlsx_close_snapshot(710,2)$$,'23514','forms_xlsx_snapshot_count_invalid','snapshot cannot seal a partial capture');
select lives_ok($$select pg_temp.xlsx_close_snapshot(710,1)$$,'snapshot seals with exact captured row count');
select throws_ok($$update app_private.form_xlsx_snapshot_rows set submission_jsonb='{}' where file_job_id=pg_temp.xlsx_id(710)$$,'23514','forms_xlsx_snapshot_immutable','captured row is immutable');
select throws_ok($$delete from app_private.form_xlsx_snapshot_rows where file_job_id=pg_temp.xlsx_id(710)$$,'23514','forms_xlsx_snapshot_immutable','active snapshot is not silently truncated');
select throws_ok($$insert into app_private.form_xlsx_snapshot_rows values(pg_temp.xlsx_id(710),2,pg_temp.xlsx_id(911),jsonb_build_object('responseId',pg_temp.xlsx_id(911),'metadata',jsonb_build_object('form_id',pg_temp.xlsx_id(210))))$$,'23514','forms_xlsx_snapshot_scope_invalid','sealed snapshot cannot append new answers');
select lives_ok($$insert into public.form_file_jobs(id,institution_id,form_id,requested_by_person_id,request_id,export_kind) values(pg_temp.xlsx_id(720),pg_temp.xlsx_id(10),pg_temp.xlsx_id(210),pg_temp.xlsx_id(1000),pg_temp.xlsx_id(10720),'xlsx')$$,'legacy file-job shape remains valid without new internal fields');
select ok(not has_table_privilege('authenticated','app_private.form_xlsx_snapshot_rows','select'),'snapshot content is not directly readable by client');
select ok(not has_table_privilege('service_role','app_private.form_xlsx_snapshot_rows','select'),'worker uses nominal RPC instead of direct snapshot grants');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='app_private.form_xlsx_snapshot_rows'::regclass),'snapshot table has forced deny-by-default RLS');
select ok(not has_function_privilege('authenticated','app_private.forms_xlsx_complete_guard_v1()','execute'),'client cannot call private guard');

-- Real SQL privilege/context boundaries, using synthetic Supabase Auth rows.
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
select pg_temp.xlsx_id(n+100),pg_temp.xlsx_id(n),now(),now(),'aal2',now()+interval '1 hour'
from unnest(array[101,102]) n;
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r cross join public.platform_permissions p
where r.code='operations' and p.code='forms.responses.export'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
create temporary table xlsx_download_results(label text primary key,body jsonb);
grant select,insert on xlsx_download_results to authenticated,service_role;
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.xlsx_id(101),'session_id',pg_temp.xlsx_id(201),'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into xlsx_download_results values('grant1',public.superadmin_form_authorize_xlsx_download_v2('8c021000-0000-4000-8000-000000000700'));
insert into xlsx_download_results values('grant2',public.superadmin_form_authorize_xlsx_download_v2('8c021000-0000-4000-8000-000000000700'));
reset role;
select is((select body->>'ok' from xlsx_download_results where label='grant1'),'true','current owner gets opaque one-use grant');
select is((select body#>>'{data,job_id}' from xlsx_download_results where label='grant2'),pg_temp.xlsx_id(700)::text,'grant correlates requested job');
select ok(not exists(select 1 from app_private.form_file_download_tokens where token_hash=(select body#>>'{data,download_token}' from xlsx_download_results where label='grant2')),'raw token is never stored');
select is((select count(*) from app_private.form_file_download_tokens where file_job_id=pg_temp.xlsx_id(700) and actor_internal_identity_id=pg_temp.xlsx_id(301) and consumed_at is null),1::bigint,'only latest grant stays active');

select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
insert into xlsx_download_results select 'superseded',public.form_redeem_xlsx_download_r2_v1((body#>>'{data,download_token}')::uuid) from xlsx_download_results where label='grant1';
insert into xlsx_download_results select 'redeemed',public.form_redeem_xlsx_download_r2_v1((body#>>'{data,download_token}')::uuid) from xlsx_download_results where label='grant2';
insert into xlsx_download_results select 'replayed',public.form_redeem_xlsx_download_r2_v1((body#>>'{data,download_token}')::uuid) from xlsx_download_results where label='grant2';
reset role;
select is((select body from xlsx_download_results where label='superseded'),null::jsonb,'previous grant cannot be redeemed');
select is((select body->>'asset_id' from xlsx_download_results where label='redeemed'),pg_temp.xlsx_id(800)::text,'redeem returns current artifact attempt');
select is((select body->>'provider' from xlsx_download_results where label='redeemed'),'r2','redeem emits R2 catalog contract');
select is((select body->>'object_key' from xlsx_download_results where label='redeemed'),'tenants/'||pg_temp.xlsx_id(10)::text||'/exports/forms/'||pg_temp.xlsx_id(700)::text||'/'||pg_temp.xlsx_id(800)::text||'/responses.xlsx','redeem key is opaque and bound to attempt');
select is((select body from xlsx_download_results where label='replayed'),null::jsonb,'token replay fails closed');
select is(current_setting('request.jwt.claims')::jsonb,'{"role":"service_role"}'::jsonb,'successful reauthorization restores worker JWT claims');
select is(nullif(current_setting('request.jwt.claim.sub',true),''),null::text,'successful reauthorization clears temporary subject');

select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.xlsx_id(102),'session_id',pg_temp.xlsx_id(202),'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into xlsx_download_results values('other_owner',public.superadmin_form_authorize_xlsx_download_v2('8c021000-0000-4000-8000-000000000700'));
reset role;
select is((select body#>>'{error,code}' from xlsx_download_results where label='other_owner'),'SAI_PERMISSION_DENIED','same tenant capability cannot take another owner export');

select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.xlsx_id(101),'session_id',pg_temp.xlsx_id(201),'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into xlsx_download_results values('before_revoke',public.superadmin_form_authorize_xlsx_download_v2('8c021000-0000-4000-8000-000000000700'));
reset role;
update app_private.superadmin_internal_memberships set status='suspended',suspended_at=clock_timestamp(),version=version+1 where id=pg_temp.xlsx_id(501);
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
insert into xlsx_download_results select 'after_revoke',public.form_redeem_xlsx_download_r2_v1((body#>>'{data,download_token}')::uuid) from xlsx_download_results where label='before_revoke';
reset role;
select is((select body from xlsx_download_results where label='after_revoke'),null::jsonb,'revoked membership between issue and redeem blocks metadata');
select is(current_setting('request.jwt.claims')::jsonb,'{"role":"service_role"}'::jsonb,'denied reauthorization restores worker JWT claims');
select is(nullif(current_setting('request.jwt.claim.sub',true),''),null::text,'denied reauthorization clears temporary subject');
select ok((select consumed_at is not null from app_private.form_file_download_tokens where token_hash=encode(extensions.digest(convert_to((select body#>>'{data,download_token}' from xlsx_download_results where label='before_revoke'),'UTF8'),'sha256'),'hex')),'denied token is consumed exactly once');
update app_private.superadmin_internal_memberships set status='active',suspended_at=null,version=version+1 where id=pg_temp.xlsx_id(501);

select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.xlsx_id(101),'session_id',pg_temp.xlsx_id(201),'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into xlsx_download_results values('before_logout',public.superadmin_form_authorize_xlsx_download_v2('8c021000-0000-4000-8000-000000000700'));
reset role;
delete from auth.sessions where id=pg_temp.xlsx_id(201);
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
insert into xlsx_download_results select 'after_logout',public.form_redeem_xlsx_download_r2_v1((body#>>'{data,download_token}')::uuid) from xlsx_download_results where label='before_logout';
reset role;
select is((select body from xlsx_download_results where label='after_logout'),null::jsonb,'deleted session invalidates issued grant without blocking logout');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values(pg_temp.xlsx_id(203),pg_temp.xlsx_id(101),now(),now(),'aal2',now()+interval '1 hour');
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.xlsx_id(101),'session_id',pg_temp.xlsx_id(203),'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into xlsx_download_results values('new_session',public.superadmin_form_authorize_xlsx_download_v2('8c021000-0000-4000-8000-000000000700'));
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
insert into xlsx_download_results select 'new_session_redeemed',public.form_redeem_xlsx_download_r2_v1((body#>>'{data,download_token}')::uuid) from xlsx_download_results where label='new_session';
reset role;
select is((select body->>'job_id' from xlsx_download_results where label='new_session_redeemed'),pg_temp.xlsx_id(700)::text,'owner can reauthorize completed job from a new valid session');

update app_private.superadmin_internal_memberships set scope_institution_id=pg_temp.xlsx_id(20),version=version+1 where id=pg_temp.xlsx_id(501);
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.xlsx_id(101),'session_id',pg_temp.xlsx_id(203),'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into xlsx_download_results values('wrong_tenant',public.superadmin_form_authorize_xlsx_download_v2('8c021000-0000-4000-8000-000000000700'));
reset role;
select is((select body#>>'{error,code}' from xlsx_download_results where label='wrong_tenant'),'SAI_PERMISSION_DENIED','new institution scope cannot download old tenant export');
select ok(exists(select 1 from audit.audit_logs where action_code='superadmin.forms.export.download.redeem' and outcome='success' and object_id=pg_temp.xlsx_id(700) and actor_internal_identity_id=pg_temp.xlsx_id(301)),'successful delivery authorization is audited against real internal identity and job');
select ok(exists(select 1 from audit.audit_logs where action_code='superadmin.forms.export.download.redeem' and outcome='denied' and object_id=pg_temp.xlsx_id(700)),'revoked delivery is audited without raw token');
select ok(has_function_privilege('authenticated','public.superadmin_form_authorize_xlsx_download_v2(uuid)','execute'),'user may request grant');
select ok(not has_function_privilege('service_role','public.superadmin_form_authorize_xlsx_download_v2(uuid)','execute'),'service key is not an internal user');
select ok(not has_function_privilege('anon','public.superadmin_form_authorize_xlsx_download_v2(uuid)','execute'),'anonymous cannot request grant');
select ok(has_function_privilege('service_role','public.form_redeem_xlsx_download_r2_v1(uuid)','execute'),'only worker boundary redeems grant');
select ok(not has_function_privilege('authenticated','public.form_redeem_xlsx_download_r2_v1(uuid)','execute'),'client cannot redeem catalog locator directly');
select ok(not has_function_privilege('service_role','app_private.forms_xlsx_context_from_session_v1(uuid,uuid,uuid,uuid,text,uuid)','execute'),'worker cannot select an arbitrary internal session context');

-- Request/capture is atomic and realm-specific. Synthetic data only.
update app_private.superadmin_internal_memberships set scope_institution_id=pg_temp.xlsx_id(10),version=version+1 where id=pg_temp.xlsx_id(501);
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.xlsx_id(101),'session_id',pg_temp.xlsx_id(203),'aal','aal2','role','authenticated')::text,true);
create temporary table xlsx_request_results(label text primary key,body jsonb);
grant insert,select on xlsx_request_results to authenticated;
create function pg_temp.xlsx_request(n integer,form_number integer,version_number bigint,extra jsonb default '{}'::jsonb)
returns jsonb language sql security invoker as $$
  select public.superadmin_form_request_xlsx_v2(pg_temp.xlsx_id(n),version_number,
    jsonb_build_object('form_id',pg_temp.xlsx_id(form_number))||extra);
$$;
grant execute on function pg_temp.xlsx_id(integer),pg_temp.xlsx_request(integer,integer,bigint,jsonb) to authenticated;
set local role authenticated;
insert into xlsx_request_results values('empty',pg_temp.xlsx_request(12000,210,1));
insert into xlsx_request_results values('repeat',pg_temp.xlsx_request(12000,210,1));
insert into xlsx_request_results values('csv',pg_temp.xlsx_request(12001,210,1,'{"kind":"csv"}'));
insert into xlsx_request_results values('response',pg_temp.xlsx_request(12002,210,1,'{"response_id":"8c021000-0000-4000-8000-000000000910"}'));
insert into xlsx_request_results values('tenant',pg_temp.xlsx_request(12003,220,1));
insert into xlsx_request_results values('version',pg_temp.xlsx_request(12004,210,999));
insert into xlsx_request_results values('changed_request',pg_temp.xlsx_request(12000,210,2));
reset role;
select is((select body->>'ok' from xlsx_request_results where label='empty'),'true','authorized internal identity requests an XLSX');
select is((select body#>>'{data,id}' from xlsx_request_results where label='repeat'),(select body#>>'{data,id}' from xlsx_request_results where label='empty'),'same request replays exact job');
select is((select count(*) from app_private.form_worker_jobs where job_kind='export_xlsx_r2_v1' and aggregate_id=(select (body#>>'{data,id}')::uuid from xlsx_request_results where label='empty')),1::bigint,'retry queues only one R2 job');
select ok((select snapshot_ready and snapshot_row_count=0 and requested_by_person_id is null and requested_auth_session_id=pg_temp.xlsx_id(203) from public.form_file_jobs where id=(select (body#>>'{data,id}')::uuid from xlsx_request_results where label='empty')),'empty capture sealed with actual internal session provenance');
select is((select body#>>'{error,code}' from xlsx_request_results where label='csv'),'SAI_INVALID_ARGUMENT','CSV cannot be selected');
select is((select body#>>'{error,code}' from xlsx_request_results where label='response'),'SAI_INVALID_ARGUMENT','per-response export cannot be selected');
select is((select body#>>'{error,code}' from xlsx_request_results where label='tenant'),'SAI_PERMISSION_DENIED','request cannot cross institution');
select is((select body#>>'{error,code}' from xlsx_request_results where label='version'),'SAI_CONCURRENT_CHANGE','stale version returns existing concurrency envelope');
select is((select body#>>'{error,code}' from xlsx_request_results where label='changed_request'),'SAI_INVALID_ARGUMENT','request ID cannot change its payload');
select is((select count(*) from public.form_file_jobs where request_id in(select pg_temp.xlsx_id(n) from generate_series(12001,12004) n)),0::bigint,'denied requests leave no jobs');

insert into public.form_versions(id,form_id,version_number,created_by_person_id)
values(pg_temp.xlsx_id(13000),pg_temp.xlsx_id(210),1,pg_temp.xlsx_id(1000));
insert into public.form_sections(id,form_version_id,title,position)
values(pg_temp.xlsx_id(13001),pg_temp.xlsx_id(13000),'Synthetic capture',0);
insert into public.form_items(id,form_version_id,section_id,kind,label,position)
values(pg_temp.xlsx_id(13002),pg_temp.xlsx_id(13000),pg_temp.xlsx_id(13001),'short_text','Synthetic answer',0);
insert into public.form_applications(id,form_id,institution_id,name,created_by_person_id)
values(pg_temp.xlsx_id(13003),pg_temp.xlsx_id(210),pg_temp.xlsx_id(10),'Synthetic application',pg_temp.xlsx_id(1000));
insert into public.form_schedules(id,application_id,time_zone,starts_at_local,recurrence_kind)
values(pg_temp.xlsx_id(13004),pg_temp.xlsx_id(13003),'UTC','2026-09-08 00:00:00','once');
insert into public.form_occurrences(id,application_id,schedule_id,institution_id,form_id,form_version_id,scheduled_local,time_zone,opens_at,closes_at)
values(pg_temp.xlsx_id(13005),pg_temp.xlsx_id(13003),pg_temp.xlsx_id(13004),pg_temp.xlsx_id(10),pg_temp.xlsx_id(210),pg_temp.xlsx_id(13000),'2026-09-08 00:00:00','UTC',now()-interval '1 day',now()+interval '1 day');
insert into public.form_responses(id,occurrence_id,institution_id,form_id,form_version_id,identity_mode,respondent_person_id,status,submitted_at)
values(pg_temp.xlsx_id(13010),pg_temp.xlsx_id(13005),pg_temp.xlsx_id(10),pg_temp.xlsx_id(210),pg_temp.xlsx_id(13000),'identified',pg_temp.xlsx_id(1000),'submitted',now());
insert into public.form_responses(id,occurrence_id,institution_id,form_id,form_version_id,identity_mode,anonymous_edit_secret_hash,status,submitted_at)
select pg_temp.xlsx_id(n),pg_temp.xlsx_id(13005),pg_temp.xlsx_id(10),pg_temp.xlsx_id(210),pg_temp.xlsx_id(13000),'anonymous','synthetic-not-a-real-secret',
  case when n=13011 then 'submitted' else 'draft' end,case when n=13011 then now() else null end from unnest(array[13011,13012]) n;
insert into public.form_answers(id,response_id,form_version_id,item_id,answer_kind,text_value)
select pg_temp.xlsx_id(n+10),pg_temp.xlsx_id(n),pg_temp.xlsx_id(13000),pg_temp.xlsx_id(13002),'short_text','captured-'||n from unnest(array[13010,13011,13012]) n;
set local role authenticated;
insert into xlsx_request_results values('captured',pg_temp.xlsx_request(12005,210,1));
reset role;
select is((select body->>'ok' from xlsx_request_results where label='captured'),'true','request captures submitted answers');
select is((select snapshot_row_count from public.form_file_jobs where id=(select (body#>>'{data,id}')::uuid from xlsx_request_results where label='captured')),2::bigint,'draft answer is excluded from export');
select is((select submission_jsonb#>>'{answers,0,values,0}' from app_private.form_xlsx_snapshot_rows where response_id=pg_temp.xlsx_id(13010) and file_job_id=(select (body#>>'{data,id}')::uuid from xlsx_request_results where label='captured')),'captured-13010','typed answer projection captured');
select is((select submission_jsonb#>>'{metadata,respondent}' from app_private.form_xlsx_snapshot_rows where response_id=pg_temp.xlsx_id(13011)),'','anonymous snapshot contains no respondent');
select is((select submission_jsonb#>>'{metadata,submitted_at}' from app_private.form_xlsx_snapshot_rows where response_id=pg_temp.xlsx_id(13011)),'','anonymous snapshot omits exact submission timestamp');
select ok(not exists(select 1 from app_private.form_xlsx_snapshot_rows where submission_jsonb::text like '%synthetic-not-a-real-secret%'),'anonymous edit secret never enters snapshot');
update public.form_answers set text_value='changed-after-capture' where id=pg_temp.xlsx_id(13020);
update public.forms set management_version=management_version+1 where id=pg_temp.xlsx_id(210);
set local role authenticated;
insert into xlsx_request_results values('after_change',pg_temp.xlsx_request(12005,210,1));
reset role;
select is((select body#>>'{data,id}' from xlsx_request_results where label='after_change'),(select body#>>'{data,id}' from xlsx_request_results where label='captured'),'idempotency survives later form management change');
select is((select submission_jsonb#>>'{answers,0,values,0}' from app_private.form_xlsx_snapshot_rows where response_id=pg_temp.xlsx_id(13010)),'captured-13010','later answer edits do not change sealed export');
update app_private.superadmin_internal_memberships set status='suspended',suspended_at=clock_timestamp(),version=version+1 where id=pg_temp.xlsx_id(501);
set local role authenticated;
insert into xlsx_request_results values('revoked_replay',pg_temp.xlsx_request(12005,210,1));
reset role;
select is((select body->>'ok' from xlsx_request_results where label='revoked_replay'),'false','idempotent replay still requires current permission');
select ok(exists(select 1 from audit.audit_logs where action_code='superadmin.forms.export.request' and outcome='success' and actor_internal_identity_id=pg_temp.xlsx_id(301)),'request audits actual internal actor');
select ok(not has_function_privilege('service_role','public.superadmin_form_request_xlsx_v2(uuid,bigint,jsonb)','execute'),'service worker cannot request as user');
select ok(not has_function_privilege('anon','public.superadmin_form_request_xlsx_v2(uuid,bigint,jsonb)','execute'),'anonymous cannot enqueue export');


-- Begin/paging with a real queue lease and service-only public boundary.
update app_private.superadmin_internal_memberships set status='active',suspended_at=null,version=version+1 where id=pg_temp.xlsx_id(501);
create temporary table xlsx_worker_fixture as
select w.id worker_job_id,j.id file_job_id from public.form_file_jobs j join app_private.form_worker_jobs w on w.aggregate_id=j.id
where j.id=(select (body#>>'{data,id}')::uuid from xlsx_request_results where label='captured');
grant select on xlsx_worker_fixture to service_role;
create temporary table xlsx_worker_results(label text primary key,body jsonb);
grant select,insert on xlsx_worker_results to service_role;
update app_private.form_worker_jobs set state='processing',attempts=1,lease_owner='c02-xlsx-1',lease_expires_at=clock_timestamp()+interval '5 minutes'
where id=(select worker_job_id from xlsx_worker_fixture);
create function pg_temp.xlsx_begin(owner_name text) returns jsonb language sql security invoker as $$
 select public.form_worker_begin_xlsx_r2_v1(worker_job_id,owner_name,file_job_id) from xlsx_worker_fixture;
$$;
create function pg_temp.xlsx_page(owner_name text,asset uuid,after_sequence bigint,page_limit integer default 1)
returns jsonb language sql security invoker as $$
 select public.form_worker_xlsx_snapshot_r2_v1(worker_job_id,owner_name,file_job_id,asset,after_sequence,page_limit) from xlsx_worker_fixture;
$$;
grant execute on function pg_temp.xlsx_begin(text),pg_temp.xlsx_page(text,uuid,bigint,integer) to service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
insert into xlsx_worker_results values('begin1',pg_temp.xlsx_begin('c02-xlsx-1'));
insert into xlsx_worker_results values('begin_repeat',pg_temp.xlsx_begin('c02-xlsx-1'));
insert into xlsx_worker_results select 'page1',pg_temp.xlsx_page('c02-xlsx-1',(body->>'asset_id')::uuid,0) from xlsx_worker_results where label='begin1';
insert into xlsx_worker_results select 'page2',pg_temp.xlsx_page('c02-xlsx-1',(body->>'asset_id')::uuid,1) from xlsx_worker_results where label='begin1';
insert into xlsx_worker_results select 'page_end',pg_temp.xlsx_page('c02-xlsx-1',(body->>'asset_id')::uuid,2) from xlsx_worker_results where label='begin1';
select throws_ok($$select pg_temp.xlsx_begin('other-worker')$$,'40001','forms_xlsx_lease_unavailable','wrong worker cannot begin an existing lease');
select throws_ok($$select pg_temp.xlsx_page('c02-xlsx-1','8c021000-0000-4000-8000-000000000800',0)$$,'40001','forms_xlsx_attempt_unavailable','asset ID from another job cannot page this snapshot');
select throws_ok($$select pg_temp.xlsx_page('c02-xlsx-1',(body->>'asset_id')::uuid,3) from xlsx_worker_results where label='begin1'$$,'22023','forms_xlsx_cursor_invalid','cursor past sealed capture is rejected');
select throws_ok($$select pg_temp.xlsx_page('c02-xlsx-1',(body->>'asset_id')::uuid,0,501) from xlsx_worker_results where label='begin1'$$,'22023','forms_xlsx_page_invalid','page size is server bounded');
reset role;
select is((select body->>'asset_id' from xlsx_worker_results where label='begin_repeat'),(select body->>'asset_id' from xlsx_worker_results where label='begin1'),'begin retry reuses the same current attempt');
select is((select body#>>'{submissions,0,answers,0,values,0}' from xlsx_worker_results where label='page1'),'captured-13010','worker reads immutable captured value after source edit');
select is((select body->>'next_cursor' from xlsx_worker_results where label='page1'),'1','page cursor uses sealed sequence');
select is((select body->>'has_more' from xlsx_worker_results where label='page1'),'true','first bounded page has more');
select is((select body->>'has_more' from xlsx_worker_results where label='page2'),'false','last nonempty page terminates');
select is((select body->'submissions' from xlsx_worker_results where label='page_end'),'[]'::jsonb,'cursor at row count returns empty terminal page');
select is(current_setting('request.jwt.claims')::jsonb,'{"role":"service_role"}'::jsonb,'worker restores original claims after paging');
select throws_ok($$update public.media_assets set upload_request_id='forged-attempt' where id=(select (body->>'asset_id')::uuid from xlsx_worker_results where label='begin1')$$,'23514','forms_xlsx_asset_binding_immutable','attempt binding cannot be rewritten');
update app_private.superadmin_internal_memberships set status='suspended',suspended_at=clock_timestamp(),version=version+1 where id=pg_temp.xlsx_id(501);
set local role service_role;
select throws_ok($$select pg_temp.xlsx_page('c02-xlsx-1',(body->>'asset_id')::uuid,0) from xlsx_worker_results where label='begin1'$$,'42501',null,'revoked requester cannot keep reading worker pages');
reset role;
update app_private.superadmin_internal_memberships set status='active',suspended_at=null,version=version+1 where id=pg_temp.xlsx_id(501);
update app_private.form_worker_jobs set lease_expires_at=clock_timestamp()-interval '1 second' where id=(select worker_job_id from xlsx_worker_fixture);
set local role service_role;
select throws_ok($$select pg_temp.xlsx_begin('c02-xlsx-1')$$,'40001','forms_xlsx_lease_unavailable','expired lease cannot reserve another asset');
reset role;
update app_private.form_worker_jobs set attempts=2,lease_owner='c02-xlsx-2',lease_expires_at=clock_timestamp()+interval '5 minutes' where id=(select worker_job_id from xlsx_worker_fixture);
set local role service_role;
insert into xlsx_worker_results values('begin2',pg_temp.xlsx_begin('c02-xlsx-2'));
select throws_ok($$select pg_temp.xlsx_page('c02-xlsx-1',(body->>'asset_id')::uuid,0) from xlsx_worker_results where label='begin1'$$,'40001','forms_xlsx_lease_unavailable','late old worker cannot read after lease takeover');
select throws_ok($$select pg_temp.xlsx_page('c02-xlsx-2',(body->>'asset_id')::uuid,0) from xlsx_worker_results where label='begin1'$$,'40001','forms_xlsx_attempt_unavailable','new worker cannot revive an abandoned attempt');
reset role;
select isnt((select body->>'asset_id' from xlsx_worker_results where label='begin2'),(select body->>'asset_id' from xlsx_worker_results where label='begin1'),'new lease creates another opaque asset');
select is((select status::text from public.media_assets where id=(select (body->>'asset_id')::uuid from xlsx_worker_results where label='begin1')),'quarantined','previous attempt is retained in quarantine for cleanup');
select throws_ok($$update public.media_assets set status='ready' where id=(select (body->>'asset_id')::uuid from xlsx_worker_results where label='begin1')$$,'23514','forms_xlsx_asset_revocation_final','quarantined attempt cannot become downloadable');
select ok(not has_function_privilege('authenticated','public.form_worker_begin_xlsx_r2_v1(uuid,text,uuid)','execute'),'client cannot reserve a worker attempt');
select ok(not has_function_privilege('authenticated','public.form_worker_xlsx_snapshot_r2_v1(uuid,text,uuid,uuid,bigint,integer)','execute'),'client cannot read worker snapshot');


create function pg_temp.xlsx_finish(owner_name text,asset uuid,actual_bytes bigint,checksum text) returns jsonb language sql security invoker as $$
 select public.form_worker_complete_xlsx_r2_v1(worker_job_id,owner_name,file_job_id,asset,actual_bytes,checksum) from xlsx_worker_fixture;
$$;
create function pg_temp.xlsx_reconcile(asset uuid) returns jsonb language sql security invoker as $$
 select public.form_worker_reconcile_xlsx_r2_v1(worker_job_id,file_job_id,asset) from xlsx_worker_fixture;
$$;
grant execute on function pg_temp.xlsx_finish(text,uuid,bigint,text),pg_temp.xlsx_reconcile(uuid) to service_role;
set local role service_role;
insert into xlsx_worker_results select 'pending_reconcile',pg_temp.xlsx_reconcile((body->>'asset_id')::uuid) from xlsx_worker_results where label='begin2';
insert into xlsx_worker_results select 'abandoned_reconcile',pg_temp.xlsx_reconcile((body->>'asset_id')::uuid) from xlsx_worker_results where label='begin1';
select throws_ok($$select pg_temp.xlsx_finish('c02-xlsx-2',(body->>'asset_id')::uuid,0,repeat('c',64)) from xlsx_worker_results where label='begin2'$$,'22023','forms_xlsx_measurement_invalid','unmeasured empty artifact cannot complete');
select throws_ok($$select pg_temp.xlsx_finish('c02-xlsx-2',(body->>'asset_id')::uuid,100,'not-a-checksum') from xlsx_worker_results where label='begin2'$$,'22023','forms_xlsx_measurement_invalid','malformed checksum cannot complete');
select throws_ok($$select pg_temp.xlsx_finish('c02-xlsx-1',(body->>'asset_id')::uuid,100,repeat('c',64)) from xlsx_worker_results where label='begin1'$$,'40001','forms_xlsx_lease_unavailable','stale worker cannot publish its abandoned upload');
reset role;
select is((select body->>'state' from xlsx_worker_results where label='pending_reconcile'),'pending','ambiguous pending result does not imply failure or deletion');
select is((select body->>'state' from xlsx_worker_results where label='abandoned_reconcile'),'abandoned','old attempt is distinguishable from winner without granting deletion');
select ok(not exists(select 1 from xlsx_worker_results where label in('pending_reconcile','abandoned_reconcile') and (body?'object_key' or body?'url' or body?'delete_allowed')),'reconciliation exposes no URL or deletion grant');
update app_private.superadmin_internal_memberships set status='suspended',suspended_at=clock_timestamp(),version=version+1 where id=pg_temp.xlsx_id(501);
set local role service_role;
select throws_ok($$select pg_temp.xlsx_finish('c02-xlsx-2',(body->>'asset_id')::uuid,100,repeat('c',64)) from xlsx_worker_results where label='begin2'$$,'42501',null,'revocation before finalize denies publication');
reset role;
select is((select status::text from public.media_assets where id=(select (body->>'asset_id')::uuid from xlsx_worker_results where label='begin2')),'pending','denied finalize cannot leave asset ready');
update app_private.superadmin_internal_memberships set status='active',suspended_at=null,version=version+1 where id=pg_temp.xlsx_id(501);
set local role service_role;
insert into xlsx_worker_results select 'completed',pg_temp.xlsx_finish('c02-xlsx-2',(body->>'asset_id')::uuid,100,repeat('c',64)) from xlsx_worker_results where label='begin2';
insert into xlsx_worker_results select 'committed_reconcile',pg_temp.xlsx_reconcile((body->>'asset_id')::uuid) from xlsx_worker_results where label='begin2';
insert into xlsx_worker_results select 'committed_repeat',pg_temp.xlsx_reconcile((body->>'asset_id')::uuid) from xlsx_worker_results where label='begin2';
select throws_ok($$select pg_temp.xlsx_finish('c02-xlsx-2',(body->>'asset_id')::uuid,101,repeat('d',64)) from xlsx_worker_results where label='begin2'$$,'40001','forms_xlsx_lease_unavailable','completed lease cannot rewrite winner with another body');
reset role;
select is((select state from public.form_file_jobs where id=(select file_job_id from xlsx_worker_fixture)),'succeeded','job succeeds with original');
select is((select status::text from public.media_assets where id=(select (body->>'asset_id')::uuid from xlsx_worker_results where label='begin2')),'ready','original becomes ready in same transaction');
select is((select state from app_private.form_worker_jobs where id=(select worker_job_id from xlsx_worker_fixture)),'succeeded','queue lease completes with file job');
select is((select body->>'state' from xlsx_worker_results where label='committed_reconcile'),'committed','lost finalize response reconciles persisted winner');
select is((select body->>'checksum_sha256' from xlsx_worker_results where label='committed_reconcile'),repeat('c',64),'reconcile correlates stored measured bytes');
select is((select body from xlsx_worker_results where label='committed_repeat'),(select body from xlsx_worker_results where label='committed_reconcile'),'reconciliation is repeatable');
select ok(exists(select 1 from audit.audit_logs where action_code='superadmin.forms.export.complete' and outcome='success' and object_id=(select file_job_id from xlsx_worker_fixture)),'successful finalize is audited against job');
delete from auth.sessions where id=pg_temp.xlsx_id(203);
set local role service_role;
insert into xlsx_worker_results select 'committed_after_logout',pg_temp.xlsx_reconcile((body->>'asset_id')::uuid) from xlsx_worker_results where label='begin2';
reset role;
select is((select body->>'state' from xlsx_worker_results where label='committed_after_logout'),'committed','service can preserve committed winner after requester logout without delivery authorization');
select ok(not has_function_privilege('authenticated','public.form_worker_complete_xlsx_r2_v1(uuid,text,uuid,uuid,bigint,text)','execute'),'user cannot attest measured artifact');
select ok(not has_function_privilege('authenticated','public.form_worker_reconcile_xlsx_r2_v1(uuid,uuid,uuid)','execute'),'reconciliation metadata is service-only');

set constraints all immediate;
select * from finish();
rollback;
