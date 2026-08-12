begin;

alter table public.activity_definitions
 add column if not exists template_id uuid
 references public.activity_templates(id) on delete set null;
create index if not exists activity_definitions_template_idx
 on public.activity_definitions(template_id) where template_id is not null;

create table app_private.activity_template_command_receipts(
 request_id uuid primary key,
 command_kind text not null check(command_kind in ('create_activity','copy_template')),
 request_hash bytea not null,
 actor_person_id uuid not null references public.people(id) on delete restrict,
 source_template_id uuid not null references public.activity_templates(id) on delete restrict,
 result_activity_id uuid references public.activity_definitions(id) on delete cascade,
 result_template_id uuid references public.activity_templates(id) on delete cascade,
 result_json jsonb not null,
 created_at timestamptz not null default now(),
 check((command_kind='create_activity' and result_activity_id is not null
   and result_template_id is null)
  or (command_kind='copy_template' and result_template_id is not null
   and result_activity_id is null))
);
revoke all on app_private.activity_template_command_receipts
 from public,anon,authenticated;
grant all on app_private.activity_template_command_receipts to service_role;

create or replace function app_private.activity_request_uuid(
 p_namespace text,p_request_id uuid
) returns uuid language sql immutable set search_path=''
as $$
 select (
  substr(hash,1,8)||'-'||substr(hash,9,4)||'-'||substr(hash,13,4)||'-'||
  substr(hash,17,4)||'-'||substr(hash,21,12)
 )::uuid
 from (select md5(p_namespace||':'||p_request_id::text) hash) generated
$$;
revoke all on function app_private.activity_request_uuid(text,uuid)
 from public,anon,authenticated;

create or replace function app_private.superadmin_duplicate_activity_template(
 p_template_id uuid,p_institution_id uuid,p_idempotency_key uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
 actor uuid:=app_private.current_person_id();
 template public.activity_templates%rowtype;
 receipt app_private.activity_template_command_receipts%rowtype;
 request_hash bytea; payload jsonb; result jsonb;
 activity_id uuid; upsert_request_id uuid; template_defaults jsonb;
begin
 if (select auth.uid()) is null or actor is null then
  raise insufficient_privilege using message='authentication required';
 end if;
 if not app_private.has_platform_permission('activities.create') then
  raise insufficient_privilege using message='activities.create required';
 end if;
 if not app_private.has_mfa_aal2() then
  raise insufficient_privilege using message='MFA AAL2 required';
 end if;
 if p_template_id is null or p_institution_id is null or p_idempotency_key is null
    or not exists(select 1 from public.institutions institution
      where institution.id=p_institution_id) then
  raise invalid_parameter_value using message='invalid template activity request';
 end if;
 select * into template from public.activity_templates template_record
 where template_record.id=p_template_id and template_record.status='active'
  and (template_record.scope_kind='platform'
   or template_record.institution_id=p_institution_id);
 if template.id is null then
  raise no_data_found using message='template not found';
 end if;
 request_hash:=extensions.digest(convert_to(jsonb_build_object(
  'template_id',p_template_id,'institution_id',p_institution_id)::text,
  'UTF8'),'sha256');
 perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key::text,0));
 select * into receipt from app_private.activity_template_command_receipts
  where request_id=p_idempotency_key;
 if receipt.request_id is not null then
  if receipt.actor_person_id<>actor then
   raise insufficient_privilege using message='template receipt actor mismatch';
  end if;
  if receipt.command_kind<>'create_activity'
     or receipt.request_hash<>request_hash
     or receipt.source_template_id<>p_template_id then
   raise invalid_parameter_value using message='idempotency key reused';
  end if;
  return receipt.result_json;
 end if;
 activity_id:=app_private.activity_request_uuid(
  'activity-from-template',p_idempotency_key);
 upsert_request_id:=app_private.activity_request_uuid(
  'activity-from-template-upsert',p_idempotency_key);
 select coalesce(jsonb_object_agg(entry.key,entry.value),'{}'::jsonb)
 into template_defaults
 from jsonb_each(template.template_payload) entry
 where entry.key in (
  'description','governance_kind','identity_mode',
  'identity_initials','identity_color','identity_icon'
 );
 payload:=template_defaults||jsonb_build_object(
  'id',activity_id,'expected_version',0,
  'institution_id',p_institution_id,
  'name',template.name,
  'description',coalesce(template_defaults->>'description',template.description,''),
  'origin_scope_kind','institution',
  'governance_kind',coalesce(
   template_defaults->>'governance_kind',template.governance_kind),
  'status','draft','taxonomy_id',template.taxonomy_id,
  'identity_mode',coalesce(template_defaults->>'identity_mode','initials'),
  'identity_initials',coalesce(template_defaults->>'identity_initials',
   upper(left(regexp_replace(template.name,'[^[:alnum:]]','','g'),2))),
  'identity_color',coalesce(template_defaults->>'identity_color','#D63C00')
 );
 result:=app_private.superadmin_upsert_activity(payload,upsert_request_id);
 update public.activity_definitions
 set template_id=template.id,updated_at=now()
 where id=activity_id;
 result:=app_private.activity_management_payload(activity_id);
 insert into app_private.activity_template_command_receipts(
  request_id,command_kind,request_hash,actor_person_id,source_template_id,
  result_activity_id,result_json
 ) values(p_idempotency_key,'create_activity',request_hash,actor,template.id,
  activity_id,result);
 insert into audit.audit_logs(
  actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,
  outcome,after_json
 ) values(actor,auth.jwt()->>'aal','activity.template.instantiate',
  'activity_definition',activity_id,p_institution_id,'success',
  jsonb_build_object('template_id',template.id,'status','draft'));
 return result;
end $$;

create or replace function app_private.superadmin_copy_activity_template(
 p_template_id uuid,p_institution_id uuid,p_idempotency_key uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
 actor uuid:=app_private.current_person_id();
 source_template public.activity_templates%rowtype;
 copied_template public.activity_templates%rowtype;
 receipt app_private.activity_template_command_receipts%rowtype;
 request_hash bytea; result jsonb; copied_id uuid;
begin
 if (select auth.uid()) is null or actor is null then
  raise insufficient_privilege using message='authentication required';
 end if;
 if not app_private.has_platform_permission('activities.templates.manage') then
  raise insufficient_privilege using message='activities.templates.manage required';
 end if;
 if not app_private.has_mfa_aal2() then
  raise insufficient_privilege using message='MFA AAL2 required';
 end if;
 if p_template_id is null or p_institution_id is null or p_idempotency_key is null
    or not exists(select 1 from public.institutions institution
      where institution.id=p_institution_id) then
  raise invalid_parameter_value using message='invalid template copy request';
 end if;
 select * into source_template from public.activity_templates template_record
 where template_record.id=p_template_id and template_record.status='active'
  and (template_record.scope_kind='platform'
   or template_record.institution_id=p_institution_id);
 if source_template.id is null then
  raise no_data_found using message='template not found';
 end if;
 request_hash:=extensions.digest(convert_to(jsonb_build_object(
  'template_id',p_template_id,'institution_id',p_institution_id)::text,
  'UTF8'),'sha256');
 perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key::text,0));
 select * into receipt from app_private.activity_template_command_receipts
  where request_id=p_idempotency_key;
 if receipt.request_id is not null then
  if receipt.actor_person_id<>actor then
   raise insufficient_privilege using message='template receipt actor mismatch';
  end if;
  if receipt.command_kind<>'copy_template'
     or receipt.request_hash<>request_hash
     or receipt.source_template_id<>p_template_id then
   raise invalid_parameter_value using message='idempotency key reused';
  end if;
  return receipt.result_json;
 end if;
 copied_id:=app_private.activity_request_uuid(
  'activity-template-copy',p_idempotency_key);
 insert into public.activity_templates(
  id,scope_kind,institution_id,code,name,description,taxonomy_id,
  governance_kind,template_payload,status,created_by_person_id
 ) values(
  copied_id,'institution',p_institution_id,
  left(source_template.code,48)||'-'||left(replace(p_idempotency_key::text,'-',''),8),
  left('Cópia de '||source_template.name,120),
  source_template.description,source_template.taxonomy_id,
  source_template.governance_kind,source_template.template_payload,
  'active',actor
 ) returning * into copied_template;
 result:=to_jsonb(copied_template);
 insert into app_private.activity_template_command_receipts(
  request_id,command_kind,request_hash,actor_person_id,source_template_id,
  result_template_id,result_json
 ) values(p_idempotency_key,'copy_template',request_hash,actor,
  source_template.id,copied_template.id,result);
 insert into audit.audit_logs(
  actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,
  outcome,before_json,after_json
 ) values(actor,auth.jwt()->>'aal','activity.template.copy',
  'activity_template',copied_template.id,p_institution_id,'success',
  to_jsonb(source_template),result);
 return result;
end $$;

create or replace function public.superadmin_duplicate_activity_template(
 p_template_id uuid,p_institution_id uuid,p_idempotency_key uuid
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_duplicate_activity_template(
 p_template_id,p_institution_id,p_idempotency_key)$$;
create or replace function public.superadmin_copy_activity_template(
 p_template_id uuid,p_institution_id uuid,p_idempotency_key uuid
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_copy_activity_template(
 p_template_id,p_institution_id,p_idempotency_key)$$;

revoke all on function app_private.superadmin_duplicate_activity_template(uuid,uuid,uuid)
 from public,anon,authenticated,service_role;
revoke all on function app_private.superadmin_copy_activity_template(uuid,uuid,uuid)
 from public,anon,authenticated,service_role;
revoke all on function public.superadmin_duplicate_activity_template(uuid,uuid,uuid)
 from public,anon,authenticated,service_role;
revoke all on function public.superadmin_copy_activity_template(uuid,uuid,uuid)
 from public,anon,authenticated,service_role;
grant execute on function public.superadmin_duplicate_activity_template(uuid,uuid,uuid)
 to authenticated;
grant execute on function public.superadmin_copy_activity_template(uuid,uuid,uuid)
 to authenticated;

commit;
