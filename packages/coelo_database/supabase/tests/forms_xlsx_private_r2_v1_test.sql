-- C02 / I005 LOCAL WIP. Rollback-only synthetic catalog/job tests.
-- Authorization, worker and token scenarios follow when the reserved RPCs exist.
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
set constraints all immediate;
select * from finish();
rollback;
