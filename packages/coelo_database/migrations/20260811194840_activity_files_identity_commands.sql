-- Activity locations, audited file jobs and private identity upload intents.
begin;

create table app_private.activity_identity_upload_intents(
 request_id uuid primary key,
 activity_id uuid not null references public.activity_definitions(id) on delete cascade,
 actor_person_id uuid not null references public.people(id) on delete restrict,
 storage_path text not null unique,
 mime_type text not null check(mime_type in ('image/jpeg','image/png','image/webp')),
 size_bytes bigint not null check(size_bytes between 1 and 2097152),
 expires_at timestamptz not null,
 consumed_at timestamptz,
 checksum_sha256 text check(checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$'),
 created_at timestamptz not null default now(),
 check(storage_path like 'activities/'||activity_id::text||'/%'),
 check(expires_at>created_at)
);
create index activity_identity_upload_intents_activity_expiry_idx
 on app_private.activity_identity_upload_intents(activity_id,expires_at);
revoke all on app_private.activity_identity_upload_intents from public,anon,authenticated;

drop policy if exists activity_identity_insert on storage.objects;
create policy activity_identity_insert on storage.objects for insert to authenticated
with check(bucket_id='coelo-identities' and exists(
 select 1 from app_private.activity_identity_upload_intents intent
 where intent.storage_path=name and intent.activity_id=app_private.storage_activity_id(name)
  and intent.actor_person_id=app_private.current_person_id()
  and intent.expires_at>now() and intent.consumed_at is null
));
drop policy if exists activity_identity_update on storage.objects;
create policy activity_identity_update on storage.objects for update to authenticated
using(bucket_id='coelo-identities' and exists(
 select 1 from app_private.activity_identity_upload_intents intent
 where intent.storage_path=name and intent.actor_person_id=app_private.current_person_id()
  and intent.expires_at>now() and intent.consumed_at is null
))
with check(bucket_id='coelo-identities' and exists(
 select 1 from app_private.activity_identity_upload_intents intent
 where intent.storage_path=name and intent.actor_person_id=app_private.current_person_id()
  and intent.expires_at>now() and intent.consumed_at is null
));

create or replace function app_private.superadmin_create_activity_locations(
 p_institution_id uuid,p_unit_ids uuid[],p_name text,p_idempotency_key uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare actor uuid:=app_private.current_person_id(); request_hash bytea;
 receipt app_private.activity_management_command_receipts%rowtype;
 current_unit_id uuid; result jsonb;
begin
 if (select auth.uid()) is null or actor is null
    or not app_private.has_platform_permission('activities.link_units')
    or not app_private.has_platform_permission('activities.manage') then
  raise insufficient_privilege using message='activity location management required';
 end if;
 if not app_private.has_mfa_aal2() then
  raise insufficient_privilege using message='MFA AAL2 required';
 end if;
 if p_idempotency_key is null or p_institution_id is null
    or cardinality(coalesce(p_unit_ids,'{}'))<1
    or nullif(btrim(p_name),'') is null or length(btrim(p_name))>120 then
  raise invalid_parameter_value using message='invalid location payload';
 end if;
 request_hash:=extensions.digest(convert_to(jsonb_build_object(
  'institution_id',p_institution_id,'unit_ids',p_unit_ids,'name',btrim(p_name))::text,'UTF8'),'sha256');
 perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key::text,0));
 select * into receipt from app_private.activity_management_command_receipts
  where request_id=p_idempotency_key;
 if receipt.request_id is not null then
  if receipt.actor_person_id<>actor then
   raise insufficient_privilege using message='idempotency receipt actor mismatch';
  end if;
  if receipt.command_kind<>'locations' or receipt.request_hash<>request_hash then
   raise invalid_parameter_value using message='idempotency key reused';
  end if;
  return receipt.result_json;
 end if;
 if (select count(*) from public.units unit
   where unit.id=any(p_unit_ids) and unit.institution_id=p_institution_id)
   <>cardinality(p_unit_ids) then
  raise foreign_key_violation using message='unit outside institution';
 end if;
 foreach current_unit_id in array p_unit_ids loop
  if not exists(select 1 from public.activity_locations location
    where location.unit_id=current_unit_id
      and lower(location.name)=lower(btrim(p_name)) and location.status<>'archived') then
   insert into public.activity_locations(
    institution_id,unit_id,name,created_by_person_id
   ) values(p_institution_id,current_unit_id,btrim(p_name),actor);
  end if;
 end loop;
 select coalesce(jsonb_agg(to_jsonb(location) order by location.name),'[]'::jsonb)
 into result from public.activity_locations location
 where location.unit_id=any(p_unit_ids)
  and lower(location.name)=lower(btrim(p_name)) and location.status<>'archived';
 insert into app_private.activity_management_command_receipts(
  request_id,command_kind,request_hash,actor_person_id,result_json
 ) values(p_idempotency_key,'locations',request_hash,actor,result);
 insert into audit.audit_logs(
  actor_person_id,mfa_aal,action_code,object_type,institution_id,outcome,after_json
 ) values(actor,auth.jwt()->>'aal','activity.locations.create','activity_location',
  p_institution_id,'success',result);
 return result;
end $$;

create or replace function app_private.superadmin_request_activity_export(
 p_format text,p_filters jsonb,p_idempotency_key uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare actor uuid:=app_private.current_person_id(); request_hash bytea;
 job public.import_jobs%rowtype;
begin
 if (select auth.uid()) is null or actor is null
    or not app_private.has_platform_permission('activities.export') then
  raise insufficient_privilege using message='activities.export required';
 end if;
 if not app_private.has_mfa_aal2() then
  raise insufficient_privilege using message='MFA AAL2 required';
 end if;
 if p_format not in ('csv','xlsx') or p_idempotency_key is null
    or jsonb_typeof(coalesce(p_filters,'{}'::jsonb))<>'object'
    or coalesce(p_filters,'{}'::jsonb)-array[
      'search','institution_ids','unit_ids','group_ids','statuses','origins'
    ]<>'{}'::jsonb then
  raise invalid_parameter_value using message='invalid export request';
 end if;
 request_hash:=extensions.digest(convert_to(jsonb_build_object(
  'format',p_format,'filters',coalesce(p_filters,'{}'))::text,'UTF8'),'sha256');
 perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key::text,0));
 select * into job from public.import_jobs job_record
  where job_record.request_id=p_idempotency_key;
 if job.id is not null then
  if job.created_by<>actor then
   raise insufficient_privilege using message='idempotency job actor mismatch';
  end if;
  if job.request_hash<>request_hash or job.target_domain<>'activities'
     or job.summary->>'operation'<>'export' then
   raise invalid_parameter_value using message='idempotency key reused';
  end if;
  return jsonb_build_object('job_id',job.id,'state',job.processing_state,'summary',job.summary);
 end if;
 insert into public.import_jobs(
  request_id,request_hash,target_domain,target_table,source_format,source_locale,
  target_locale,status,processing_state,summary,created_by
 ) values(p_idempotency_key,request_hash,'activities','activity_definitions',
  p_format,'pt-BR','pt-BR','draft','PENDENTE',
  jsonb_build_object('operation','export','filters',coalesce(p_filters,'{}'),
   'template_version','activities-v1','progress',0),actor)
 returning * into job;
 insert into public.import_results(import_job_id) values(job.id);
 insert into app_private.import_processing_queue(import_job_id) values(job.id);
 insert into audit.audit_logs(
  actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,after_json
 ) values(actor,auth.jwt()->>'aal','activity.export.request','import_job',job.id,
  'success',jsonb_build_object('format',p_format,'state','PENDENTE'));
 return jsonb_build_object('job_id',job.id,'state',job.processing_state,'summary',job.summary);
end $$;

create or replace function app_private.superadmin_create_activity_import_job(
 p_file_name text,p_mime_type text,p_source_format text,p_idempotency_key uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare actor uuid:=app_private.current_person_id(); request_hash bytea;
 job public.import_jobs%rowtype;
begin
 if (select auth.uid()) is null or actor is null
    or not app_private.has_platform_permission('activities.import') then
  raise insufficient_privilege using message='activities.import required';
 end if;
 if not app_private.has_mfa_aal2() then
  raise insufficient_privilege using message='MFA AAL2 required';
 end if;
 if p_idempotency_key is null or nullif(btrim(p_file_name),'') is null
    or length(p_file_name)>180 or p_source_format not in ('csv','xlsx')
    or p_mime_type not in (
      'text/csv','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') then
  raise invalid_parameter_value using message='invalid import request';
 end if;
 request_hash:=extensions.digest(convert_to(jsonb_build_object(
  'file_name',p_file_name,'mime_type',p_mime_type,'format',p_source_format)::text,'UTF8'),'sha256');
 perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key::text,0));
 select * into job from public.import_jobs job_record
  where job_record.request_id=p_idempotency_key;
 if job.id is not null then
  if job.created_by<>actor then
   raise insufficient_privilege using message='idempotency job actor mismatch';
  end if;
  if job.request_hash<>request_hash or job.target_domain<>'activities' then
   raise invalid_parameter_value using message='idempotency key reused';
  end if;
  return jsonb_build_object('job_id',job.id,'state',job.processing_state,
   'bucket','coelo-operations','upload_path',
   'imports/'||job.id::text||'/'||p_idempotency_key::text);
 end if;
 insert into public.import_jobs(
  request_id,request_hash,target_domain,target_table,source_format,source_locale,
  target_locale,status,processing_state,summary,created_by
 ) values(p_idempotency_key,request_hash,'activities','activity_definitions',
  p_source_format,'pt-BR','pt-BR','draft','PENDENTE',
  jsonb_build_object('operation','import','file_name',p_file_name,
   'mime_type',p_mime_type,'template_version','activities-v1','progress',0),actor)
 returning * into job;
 insert into public.import_results(import_job_id) values(job.id);
 insert into app_private.import_processing_queue(import_job_id) values(job.id);
 return jsonb_build_object('job_id',job.id,'state',job.processing_state,
  'bucket','coelo-operations',
  'upload_path','imports/'||job.id::text||'/'||p_idempotency_key::text);
end $$;

create or replace function app_private.superadmin_prepare_activity_identity_upload(
 p_activity_id uuid,p_file_name text,p_mime_type text,p_size_bytes bigint,p_idempotency_key uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare actor uuid:=app_private.current_person_id(); extension text; request_hash bytea;
 receipt app_private.activity_management_command_receipts%rowtype; result jsonb; path text;
begin
 if (select auth.uid()) is null or actor is null
    or not app_private.has_platform_permission('activities.manage') then
  raise insufficient_privilege using message='activities.manage required';
 end if;
 if not app_private.has_mfa_aal2() then
  raise insufficient_privilege using message='MFA AAL2 required';
 end if;
 if not exists(select 1 from public.activity_definitions activity where activity.id=p_activity_id)
    or p_idempotency_key is null or nullif(btrim(p_file_name),'') is null
    or length(p_file_name)>180 or p_size_bytes not between 1 and 2097152
    or p_mime_type not in ('image/jpeg','image/png','image/webp') then
  raise invalid_parameter_value using message='invalid identity upload';
 end if;
 extension:=case p_mime_type when 'image/jpeg' then 'jpg'
  when 'image/png' then 'png' else 'webp' end;
 path:='activities/'||p_activity_id::text||'/'||p_idempotency_key::text||'.'||extension;
 request_hash:=extensions.digest(convert_to(jsonb_build_object(
  'activity_id',p_activity_id,'file_name',p_file_name,'mime_type',p_mime_type,
  'size_bytes',p_size_bytes)::text,'UTF8'),'sha256');
 perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key::text,0));
 select * into receipt from app_private.activity_management_command_receipts
  where request_id=p_idempotency_key;
 if receipt.request_id is not null then
  if receipt.actor_person_id<>actor then
   raise insufficient_privilege using message='idempotency receipt actor mismatch';
  end if;
  if receipt.command_kind<>'identity_prepare' or receipt.request_hash<>request_hash then
   raise invalid_parameter_value using message='idempotency key reused';
  end if;
  return receipt.result_json;
 end if;
 insert into app_private.activity_identity_upload_intents(
  request_id,activity_id,actor_person_id,storage_path,mime_type,size_bytes,expires_at
 ) values(p_idempotency_key,p_activity_id,actor,path,p_mime_type,p_size_bytes,
   now()+interval '10 minutes');
 result:=jsonb_build_object('bucket','coelo-identities','path',path,
  'mime_type',p_mime_type,'size_limit',2097152,'expires_at',now()+interval '10 minutes');
 insert into app_private.activity_management_command_receipts(
  request_id,command_kind,request_hash,actor_person_id,activity_id,result_json
 ) values(p_idempotency_key,'identity_prepare',request_hash,actor,p_activity_id,result);
 return result;
end $$;

create or replace function app_private.superadmin_finalize_activity_identity_upload(
 p_activity_id uuid,p_storage_path text,p_mime_type text,p_size_bytes bigint,
 p_checksum_sha256 text,p_idempotency_key uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare actor uuid:=app_private.current_person_id(); request_hash bytea;
 receipt app_private.activity_management_command_receipts%rowtype;
 before_record public.activity_definitions%rowtype; result jsonb;
 intent app_private.activity_identity_upload_intents%rowtype; object_metadata jsonb;
begin
 if (select auth.uid()) is null or actor is null
    or not app_private.has_platform_permission('activities.manage') then
  raise insufficient_privilege using message='activities.manage required';
 end if;
 if not app_private.has_mfa_aal2() then
  raise insufficient_privilege using message='MFA AAL2 required';
 end if;
 if p_idempotency_key is null or p_mime_type not in ('image/jpeg','image/png','image/webp')
    or p_size_bytes not between 1 and 2097152
    or p_checksum_sha256 !~ '^[0-9a-f]{64}$' then
  raise invalid_parameter_value using message='invalid identity result';
 end if;
 request_hash:=extensions.digest(convert_to(jsonb_build_object(
  'activity_id',p_activity_id,'path',p_storage_path,'mime_type',p_mime_type,
  'size_bytes',p_size_bytes,'checksum',p_checksum_sha256)::text,'UTF8'),'sha256');
 perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key::text,0));
 select * into receipt from app_private.activity_management_command_receipts
  where request_id=p_idempotency_key;
 if receipt.request_id is not null then
  if receipt.actor_person_id<>actor then
   raise insufficient_privilege using message='idempotency receipt actor mismatch';
  end if;
  if receipt.command_kind<>'identity_finalize' or receipt.request_hash<>request_hash then
   raise invalid_parameter_value using message='idempotency key reused';
  end if;
  return receipt.result_json;
 end if;
 select * into intent from app_private.activity_identity_upload_intents intent_record
  where intent_record.activity_id=p_activity_id and intent_record.storage_path=p_storage_path
   and intent_record.actor_person_id=actor and intent_record.expires_at>now()
   and intent_record.consumed_at is null for update;
 if intent.request_id is null or intent.mime_type<>p_mime_type
    or intent.size_bytes<>p_size_bytes then
  raise insufficient_privilege using message='identity upload intent invalid';
 end if;
 select object_record.metadata into object_metadata from storage.objects object_record
  where object_record.bucket_id='coelo-identities' and object_record.name=p_storage_path;
 if object_metadata is null
    or coalesce((object_metadata->>'size')::bigint,-1)<>p_size_bytes
    or coalesce(object_metadata->>'mimetype','')<>p_mime_type then
  raise invalid_parameter_value using message='uploaded object metadata mismatch';
 end if;
 select * into before_record from public.activity_definitions activity
  where activity.id=p_activity_id for update;
 if before_record.id is null then raise no_data_found using message='activity not found'; end if;
 update public.activity_definitions set identity_mode='photo',
  identity_storage_bucket='coelo-identities',identity_storage_path=p_storage_path,
  identity_checksum_sha256=p_checksum_sha256,management_version=management_version+1,
  updated_at=now() where id=p_activity_id;
 update app_private.activity_identity_upload_intents set
  consumed_at=now(),checksum_sha256=p_checksum_sha256 where request_id=intent.request_id;
 result:=app_private.activity_management_payload(p_activity_id);
 insert into app_private.activity_management_command_receipts(
  request_id,command_kind,request_hash,actor_person_id,activity_id,result_json
 ) values(p_idempotency_key,'identity_finalize',request_hash,actor,p_activity_id,result);
 insert into audit.audit_logs(
  actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,
  outcome,before_json,after_json
 ) values(actor,auth.jwt()->>'aal','activity.identity.update','activity_definition',
  p_activity_id,before_record.institution_id,'success',to_jsonb(before_record),
  jsonb_build_object('bucket','coelo-identities','path',p_storage_path,
   'checksum_sha256',p_checksum_sha256));
 return result;
end $$;

create or replace function public.superadmin_create_activity_locations(
 p_institution_id uuid,p_unit_ids uuid[],p_name text,p_idempotency_key uuid)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_create_activity_locations(
 p_institution_id,p_unit_ids,p_name,p_idempotency_key)$$;
create or replace function public.superadmin_request_activity_export(
 p_format text,p_filters jsonb,p_idempotency_key uuid)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_request_activity_export(
 p_format,p_filters,p_idempotency_key)$$;
create or replace function public.superadmin_create_activity_import_job(
 p_file_name text,p_mime_type text,p_source_format text,p_idempotency_key uuid)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_create_activity_import_job(
 p_file_name,p_mime_type,p_source_format,p_idempotency_key)$$;
create or replace function public.superadmin_prepare_activity_identity_upload(
 p_activity_id uuid,p_file_name text,p_mime_type text,p_size_bytes bigint,p_idempotency_key uuid)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_prepare_activity_identity_upload(
 p_activity_id,p_file_name,p_mime_type,p_size_bytes,p_idempotency_key)$$;
create or replace function public.superadmin_finalize_activity_identity_upload(
 p_activity_id uuid,p_storage_path text,p_mime_type text,p_size_bytes bigint,
 p_checksum_sha256 text,p_idempotency_key uuid)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_finalize_activity_identity_upload(
 p_activity_id,p_storage_path,p_mime_type,p_size_bytes,p_checksum_sha256,p_idempotency_key)$$;

do $$
declare signature text;
begin
 foreach signature in array array[
  'app_private.superadmin_create_activity_locations(uuid,uuid[],text,uuid)',
  'app_private.superadmin_request_activity_export(text,jsonb,uuid)',
  'app_private.superadmin_create_activity_import_job(text,text,text,uuid)',
  'app_private.superadmin_prepare_activity_identity_upload(uuid,text,text,bigint,uuid)',
  'app_private.superadmin_finalize_activity_identity_upload(uuid,text,text,bigint,text,uuid)',
  'public.superadmin_create_activity_locations(uuid,uuid[],text,uuid)',
  'public.superadmin_request_activity_export(text,jsonb,uuid)',
  'public.superadmin_create_activity_import_job(text,text,text,uuid)',
  'public.superadmin_prepare_activity_identity_upload(uuid,text,text,bigint,uuid)',
  'public.superadmin_finalize_activity_identity_upload(uuid,text,text,bigint,text,uuid)'
 ] loop execute format(
   'revoke all on function %s from public,anon,authenticated,service_role',signature);
 end loop;
end $$;
grant execute on function public.superadmin_create_activity_locations(
 uuid,uuid[],text,uuid) to authenticated;
grant execute on function public.superadmin_request_activity_export(text,jsonb,uuid)
 to authenticated;
grant execute on function public.superadmin_create_activity_import_job(text,text,text,uuid)
 to authenticated;
grant execute on function public.superadmin_prepare_activity_identity_upload(
 uuid,text,text,bigint,uuid) to authenticated;
grant execute on function public.superadmin_finalize_activity_identity_upload(
 uuid,text,text,bigint,text,uuid) to authenticated;
commit;
