-- Transactional aggregate save for activities, participants and professionals.
begin;

alter table public.activity_group_assignments
 add constraint activity_group_assignments_role_check
 check(assignment_role in ('instructor','activity_admin')) not valid;

create or replace function app_private.superadmin_upsert_activity(
 p_payload jsonb,p_idempotency_key uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare actor uuid:=app_private.current_person_id(); request_hash bytea;
 receipt app_private.activity_management_command_receipts%rowtype;
 before_record public.activity_definitions%rowtype; saved public.activity_definitions%rowtype;
 target_activity_id uuid; target_institution_id uuid; target_taxonomy_id uuid;
 selected_unit_ids uuid[]; selected_group_ids uuid[]; expected_version bigint;
 is_create boolean; result jsonb; item jsonb; target_group_link_id uuid;
 target_assignment_id uuid; target_membership public.institution_memberships%rowtype;
 capability_record record; action_value text; professional_person_id uuid;
 admin_group record; revoked_instructors integer:=0; revoked_admins integer:=0;
 source_template public.activity_templates%rowtype; template_defaults jsonb;
begin
 if (select auth.uid()) is null or actor is null then
  raise insufficient_privilege using message='authentication required';
 end if;
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or p_idempotency_key is null
    or p_payload-array[
      'id','expected_version','institution_id','name','description','handle_stem',
      'origin_scope_kind','origin_unit_id','governance_kind','status','taxonomy_id',
      'taxonomy_other_description','identity_mode','identity_storage_bucket',
      'identity_storage_path','identity_initials','identity_color','identity_icon',
      'unit_ids','group_ids','participants','professional_assignments','template_id'
    ]<>'{}'::jsonb then
  raise invalid_parameter_value using message='invalid activity payload';
 end if;
 target_activity_id:=coalesce(nullif(p_payload->>'id','')::uuid,gen_random_uuid());
 select * into before_record from public.activity_definitions
  where id=target_activity_id for update;
 is_create:=before_record.id is null;
 if is_create then
  if not app_private.has_platform_permission('activities.create') then
   raise insufficient_privilege using message='activities.create required';
  end if;
 else
  if not app_private.has_platform_permission('activities.manage') then
   raise insufficient_privilege using message='activities.manage required';
  end if;
  expected_version:=nullif(p_payload->>'expected_version','')::bigint;
  if expected_version is null or expected_version<>before_record.management_version then
   raise serialization_failure using message='activity version conflict';
  end if;
 end if;
 if not app_private.has_mfa_aal2() then
  raise insufficient_privilege using message='MFA AAL2 required';
 end if;
 if is_create and nullif(p_payload->>'template_id','') is not null then
  select * into source_template from public.activity_templates template_record
  where template_record.id=(p_payload->>'template_id')::uuid
   and template_record.status='active'
   and (template_record.scope_kind='platform'
    or template_record.institution_id=nullif(p_payload->>'institution_id','')::uuid);
  if source_template.id is null then
   raise no_data_found using message='template not found';
  end if;
  select coalesce(jsonb_object_agg(entry.key,entry.value),'{}'::jsonb)
  into template_defaults
  from jsonb_each(source_template.template_payload) entry
  where entry.key in (
   'description','governance_kind','identity_mode',
   'identity_initials','identity_color','identity_icon'
  );
  p_payload:=template_defaults||jsonb_build_object(
   'name',source_template.name,
   'description',coalesce(
    template_defaults->>'description',source_template.description,''),
   'governance_kind',coalesce(
    template_defaults->>'governance_kind',source_template.governance_kind),
   'taxonomy_id',source_template.taxonomy_id,
   'identity_mode',coalesce(template_defaults->>'identity_mode','initials'),
   'identity_initials',coalesce(template_defaults->>'identity_initials',
    upper(left(regexp_replace(source_template.name,'[^[:alnum:]]','','g'),2))),
   'identity_color',coalesce(template_defaults->>'identity_color','#D63C00')
  )||p_payload;
 elsif not is_create and p_payload?'template_id'
    and nullif(p_payload->>'template_id','')::uuid
      is distinct from before_record.template_id then
  raise invalid_parameter_value using message='activity template origin cannot change';
 end if;
 if p_payload?'unit_ids'
    and not app_private.has_platform_permission('activities.link_units') then
  raise insufficient_privilege using message='activities.link_units required';
 end if;
 if p_payload?'group_ids'
    and not app_private.has_platform_permission('activities.link_groups') then
  raise insufficient_privilege using message='activities.link_groups required';
 end if;
 if (p_payload?'participants' or p_payload?'professional_assignments')
    and not app_private.has_platform_permission('activities.assign_people') then
  raise insufficient_privilege using message='activities.assign_people required';
 end if;
 if p_payload?'professional_assignments'
    and not app_private.has_platform_permission('activities.manage_permissions') then
  raise insufficient_privilege using message='activities.manage_permissions required';
 end if;
 request_hash:=extensions.digest(convert_to(p_payload::text,'UTF8'),'sha256');
 perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key::text,0));
 select * into receipt from app_private.activity_management_command_receipts
  where request_id=p_idempotency_key;
 if receipt.request_id is not null then
  if receipt.actor_person_id<>actor then
   raise insufficient_privilege using message='idempotency receipt actor mismatch';
  end if;
  if receipt.command_kind<>'upsert' or receipt.request_hash<>request_hash then
   raise invalid_parameter_value using message='idempotency key reused';
  end if;
  return receipt.result_json;
 end if;

 target_institution_id:=nullif(p_payload->>'institution_id','')::uuid;
 target_taxonomy_id:=nullif(p_payload->>'taxonomy_id','')::uuid;
 if target_institution_id is null or nullif(btrim(p_payload->>'name'),'') is null
    or length(btrim(p_payload->>'name'))>160 or target_taxonomy_id is null
    or coalesce(p_payload->>'origin_scope_kind','institution') not in ('institution','unit')
    or (coalesce(p_payload->>'governance_kind','optional') not in ('optional','mandatory')
     and not(not is_create and before_record.governance_kind='fixed'
      and p_payload->>'governance_kind'='fixed'))
    or coalesce(p_payload->>'status','draft') not in (
      'draft','active','inactive','suspended','archived')
    or coalesce(p_payload->>'identity_mode','initials') not in ('photo','initials','icon') then
  raise invalid_parameter_value using message='invalid activity fields';
 end if;
 if not exists(select 1 from public.institutions institution
   where institution.id=target_institution_id) then
  raise foreign_key_violation using message='institution not found';
 end if;
 if not exists(select 1 from public.activity_taxonomies taxonomy
   where taxonomy.id=target_taxonomy_id and taxonomy.status='active') then
  raise foreign_key_violation using message='taxonomy not found';
 end if;
 if exists(select 1 from public.activity_taxonomies taxonomy
    where taxonomy.id=target_taxonomy_id and taxonomy.code='outros')
    and nullif(btrim(p_payload->>'taxonomy_other_description'),'') is null then
  raise invalid_parameter_value using message='other taxonomy description required';
 end if;
 if coalesce(p_payload->>'origin_scope_kind','institution')='unit'
    and not exists(select 1 from public.units unit
      where unit.id=nullif(p_payload->>'origin_unit_id','')::uuid
       and unit.institution_id=target_institution_id) then
  raise foreign_key_violation using message='origin unit outside institution';
 end if;
 if not is_create and before_record.institution_id<>target_institution_id then
  raise insufficient_privilege using message='activity institution cannot change';
 end if;

 if is_create then
  insert into public.activity_definitions(
   id,institution_id,name,description,handle_stem,origin_scope_kind,origin_unit_id,
   governance_kind,status,taxonomy_id,taxonomy_other_description,identity_mode,
   identity_storage_bucket,identity_storage_path,identity_initials,identity_color,
   identity_icon,template_id,created_by_person_id
  ) values(
   target_activity_id,target_institution_id,btrim(p_payload->>'name'),
   nullif(btrim(p_payload->>'description'),''),
   coalesce(nullif(app_private.activity_slugify(coalesce(
    nullif(p_payload->>'handle_stem',''),p_payload->>'name')),''),
    'atividade-'||left(target_activity_id::text,6)),
   coalesce(p_payload->>'origin_scope_kind','institution')::public.activity_origin_scope,
   nullif(p_payload->>'origin_unit_id','')::uuid,
   coalesce(p_payload->>'governance_kind','optional'),
   coalesce(p_payload->>'status','draft')::public.record_status,target_taxonomy_id,
   nullif(btrim(p_payload->>'taxonomy_other_description'),''),
   coalesce(p_payload->>'identity_mode','initials'),
   nullif(p_payload->>'identity_storage_bucket',''),
   nullif(p_payload->>'identity_storage_path',''),
   nullif(upper(btrim(p_payload->>'identity_initials')),''),
   coalesce(nullif(p_payload->>'identity_color',''),'#D63C00'),
   nullif(p_payload->>'identity_icon',''),
   nullif(p_payload->>'template_id','')::uuid,actor
  ) returning * into saved;
 else
  update public.activity_definitions set
   name=btrim(p_payload->>'name'),
   description=nullif(btrim(p_payload->>'description'),''),
   handle_stem=coalesce(nullif(app_private.activity_slugify(coalesce(
    nullif(p_payload->>'handle_stem',''),p_payload->>'name')),''),
    'atividade-'||left(target_activity_id::text,6)),
   origin_scope_kind=coalesce(
    p_payload->>'origin_scope_kind',origin_scope_kind::text)::public.activity_origin_scope,
   origin_unit_id=nullif(p_payload->>'origin_unit_id','')::uuid,
   governance_kind=coalesce(p_payload->>'governance_kind',governance_kind),
   status=coalesce(p_payload->>'status',status::text)::public.record_status,
   taxonomy_id=target_taxonomy_id,
   taxonomy_other_description=nullif(btrim(p_payload->>'taxonomy_other_description'),''),
   identity_mode=coalesce(p_payload->>'identity_mode',identity_mode),
   identity_storage_bucket=case when p_payload?'identity_storage_bucket'
     then nullif(p_payload->>'identity_storage_bucket','') else identity_storage_bucket end,
   identity_storage_path=case when p_payload?'identity_storage_path'
     then nullif(p_payload->>'identity_storage_path','') else identity_storage_path end,
   identity_initials=case when p_payload?'identity_initials'
     then nullif(upper(btrim(p_payload->>'identity_initials')),'') else identity_initials end,
   identity_color=case when p_payload?'identity_color'
     then nullif(p_payload->>'identity_color','') else identity_color end,
   identity_icon=case when p_payload?'identity_icon'
     then nullif(p_payload->>'identity_icon','') else identity_icon end,
   management_version=management_version+1,updated_at=now(),
   archived_at=case when p_payload->>'status'='archived'
     then coalesce(archived_at,now()) else null end
  where id=target_activity_id returning * into saved;
 end if;

 if p_payload?'unit_ids' then
  if jsonb_typeof(p_payload->'unit_ids')<>'array' then
   raise invalid_parameter_value using message='unit_ids must be an array';
  end if;
  select coalesce(array_agg(distinct value::uuid),'{}'::uuid[]) into selected_unit_ids
   from jsonb_array_elements_text(p_payload->'unit_ids');
  if (select count(*) from public.units unit
       where unit.id=any(selected_unit_ids)
        and unit.institution_id=target_institution_id)<>cardinality(selected_unit_ids) then
   raise foreign_key_violation using message='unit outside institution';
  end if;
  update public.activity_group_links group_link
   set status='inactive',ends_at=coalesce(group_link.ends_at,now()),updated_at=now()
   where group_link.activity_id=target_activity_id and group_link.status='active'
    and not(group_link.unit_id=any(selected_unit_ids));
  update public.activity_unit_links unit_link
   set status='inactive',ends_at=coalesce(unit_link.ends_at,now()),updated_at=now()
   where unit_link.activity_id=target_activity_id and unit_link.status='active'
    and not(unit_link.unit_id=any(selected_unit_ids));
  insert into public.activity_unit_links(
   activity_id,institution_id,unit_id,linked_by_person_id,status,starts_at,ends_at
  ) select target_activity_id,target_institution_id,selected_unit_id,actor,'active',now(),null
    from unnest(selected_unit_ids) selected_unit_id
  on conflict(activity_id,unit_id) do update set status='active',ends_at=null,
   linked_by_person_id=excluded.linked_by_person_id,updated_at=now();
 end if;

 if p_payload?'group_ids' then
  if jsonb_typeof(p_payload->'group_ids')<>'array' then
   raise invalid_parameter_value using message='group_ids must be an array';
  end if;
  select coalesce(array_agg(distinct value::uuid),'{}'::uuid[]) into selected_group_ids
   from jsonb_array_elements_text(p_payload->'group_ids');
  if (select count(*) from public.groups group_record
      join public.activity_unit_links unit_link
       on unit_link.unit_id=group_record.unit_id
       and unit_link.activity_id=target_activity_id and unit_link.status='active'
      where group_record.id=any(selected_group_ids)
       and group_record.institution_id=target_institution_id)
       <>cardinality(selected_group_ids) then
   raise foreign_key_violation using message='group outside selected activity units';
  end if;
  update public.activity_group_links group_link
   set status='inactive',ends_at=coalesce(group_link.ends_at,now()),updated_at=now()
   where group_link.activity_id=target_activity_id and group_link.status='active'
    and not(group_link.group_id=any(selected_group_ids));
  insert into public.activity_group_links(
   activity_id,institution_id,unit_id,group_id,linked_by_person_id,status,starts_at,ends_at
  ) select target_activity_id,target_institution_id,group_record.unit_id,group_record.id,
    actor,'active',now(),null from public.groups group_record
    where group_record.id=any(selected_group_ids)
  on conflict(activity_id,group_id) do update set status='active',ends_at=null,
   unit_id=excluded.unit_id,linked_by_person_id=excluded.linked_by_person_id,updated_at=now();
 end if;

 if p_payload?'participants' then
  if not app_private.has_platform_permission('activities.assign_people') then
   raise insufficient_privilege using message='activities.assign_people required';
  end if;
  if jsonb_typeof(p_payload->'participants')<>'array' then
   raise invalid_parameter_value using message='participants must be an array';
  end if;
  for item in select value from jsonb_array_elements(p_payload->'participants') loop
   if item-array['group_id','child_group_link_id','belongs']<>'{}'::jsonb then
    raise invalid_parameter_value using message='invalid participant payload';
   end if;
   select link.id into target_group_link_id from public.activity_group_links link
    where link.activity_id=target_activity_id and link.group_id=(item->>'group_id')::uuid
     and link.status='active';
   if target_group_link_id is null then
    raise foreign_key_violation using message='activity group not found';
   end if;
   if coalesce((item->>'belongs')::boolean,false) then
    insert into public.activity_group_participants(
     activity_group_link_id,child_group_link_id,status,added_by_person_id
    ) values(target_group_link_id,(item->>'child_group_link_id')::uuid,'active',actor)
    on conflict(activity_group_link_id,child_group_link_id)
      where status='active' and removed_at is null do update set updated_at=now();
   else
    update public.activity_group_participants participant
     set status='inactive',removed_at=now(),updated_at=now()
     where participant.activity_group_link_id=target_group_link_id
      and participant.child_group_link_id=(item->>'child_group_link_id')::uuid
      and participant.status='active' and participant.removed_at is null;
   end if;
  end loop;
 end if;

 if p_payload?'professional_assignments' then
  if not app_private.has_platform_permission('activities.assign_people')
     or not app_private.has_platform_permission('activities.manage_permissions') then
   raise insufficient_privilege using message='activity people permissions required';
  end if;
  if jsonb_typeof(p_payload->'professional_assignments')<>'array' then
   raise invalid_parameter_value using message='professional_assignments must be an array';
  end if;
  update public.activity_group_assignments assignment
   set status='inactive',revoked_at=coalesce(assignment.revoked_at,now()),updated_at=now()
   from public.activity_group_links link
   where assignment.activity_group_link_id=link.id
    and link.activity_id=target_activity_id
    and assignment.assignment_role='instructor'
    and assignment.status='active'
    and not exists(
     select 1 from jsonb_array_elements(p_payload->'professional_assignments') submitted
      where submitted->>'role'='instructor'
       and nullif(submitted->>'group_id','')::uuid=link.group_id
       and nullif(submitted->>'membership_id','')::uuid=assignment.membership_id
    );
  get diagnostics revoked_instructors=row_count;
  update public.activity_admin_assignments assignment
   set status='inactive',revoked_at=coalesce(assignment.revoked_at,now()),updated_at=now()
   where assignment.activity_id=target_activity_id and assignment.status='active'
    and not exists(
     select 1 from jsonb_array_elements(p_payload->'professional_assignments') submitted
      where submitted->>'role'='activity_admin'
       and nullif(submitted->>'membership_id','')::uuid=assignment.membership_id
    );
  get diagnostics revoked_admins=row_count;
  for item in select value from jsonb_array_elements(p_payload->'professional_assignments') loop
   if item-array['group_id','person_id','membership_id','role','capabilities']<>'{}'::jsonb
      or item->>'role' not in ('instructor','activity_admin')
      or jsonb_typeof(item->'capabilities')<>'object' then
    raise invalid_parameter_value using message='invalid professional assignment';
   end if;
   select * into target_membership from public.institution_memberships membership
    where membership.id=(item->>'membership_id')::uuid
     and membership.institution_id=target_institution_id
     and membership.status='active' and membership.revoked_at is null;
   if target_membership.id is null then
    raise foreign_key_violation using message='membership outside institution';
   end if;
   professional_person_id:=target_membership.person_id;
   if nullif(item->>'person_id','') is not null
      and (item->>'person_id')::uuid<>professional_person_id then
    raise insufficient_privilege using message='person does not match membership';
   end if;

   if item->>'role'='activity_admin' then
    insert into public.activity_admin_assignments(
     activity_id,institution_id,person_id,membership_id,assignment_role,
     status,assigned_by_person_id
    ) values(target_activity_id,target_institution_id,professional_person_id,
      target_membership.id,'activity_admin','active',actor)
    on conflict(activity_id,person_id) where status='active' and revoked_at is null
    do update set membership_id=excluded.membership_id,
     assigned_by_person_id=excluded.assigned_by_person_id,updated_at=now();
    continue;
   end if;
   target_group_link_id:=null;
   select link.id into target_group_link_id from public.activity_group_links link
    where link.activity_id=target_activity_id and link.status='active'
     and link.group_id=nullif(item->>'group_id','')::uuid;
   if target_group_link_id is null then
    raise foreign_key_violation using message='professional assignment group not found';
   end if;
   target_assignment_id:=null;
   select assignment.id into target_assignment_id
    from public.activity_group_assignments assignment
    where assignment.activity_group_link_id=target_group_link_id
     and assignment.person_id=professional_person_id
     and assignment.assignment_role='instructor'
    order by assignment.created_at limit 1 for update;
   if target_assignment_id is null then
    insert into public.activity_group_assignments(
     activity_group_link_id,institution_id,person_id,membership_id,assignment_role,
     status,assigned_by_person_id
    ) values(target_group_link_id,target_institution_id,professional_person_id,
      target_membership.id,'instructor','active',actor)
    returning id into target_assignment_id;
   else
    update public.activity_group_assignments assignment set status='active',revoked_at=null,
     membership_id=target_membership.id,assigned_by_person_id=actor,updated_at=now()
    where assignment.id=target_assignment_id;
   end if;
   for capability_record in
    select capability.id,capability.code from public.activity_capabilities capability
     where capability.code in ('chat','now','happens','moments','attendance')
   loop
    action_value:=coalesce(item->'capabilities'->>capability_record.code,'both');
    if action_value not in ('none','view','edit','both') then
     raise invalid_parameter_value using message='invalid capability action';
    end if;
    insert into public.activity_assignment_capability_actions(
     assignment_id,capability_id,can_view,can_edit,changed_by_person_id
    ) values(target_assignment_id,capability_record.id,
      action_value in ('view','both'),action_value in ('edit','both'),actor)
    on conflict(assignment_id,capability_id) do update set
     can_view=excluded.can_view,can_edit=excluded.can_edit,
     changed_by_person_id=excluded.changed_by_person_id,updated_at=now();
   end loop;
  end loop;
  if revoked_instructors+revoked_admins>0 then
   insert into audit.audit_logs(
    actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,
    outcome,after_json
   ) values(actor,auth.jwt()->>'aal','activity.assignments.snapshot',
    'activity_definition',target_activity_id,target_institution_id,'success',
    jsonb_build_object('revoked_instructors',revoked_instructors,
     'revoked_admins',revoked_admins));
  end if;
 end if;

 if exists(select 1 from public.activity_taxonomies taxonomy
    where taxonomy.id=target_taxonomy_id and taxonomy.code='outros') then
  insert into public.activity_taxonomy_requests(
   institution_id,requested_name,requested_description,created_by_person_id
  ) values(target_institution_id,btrim(p_payload->>'name'),
    btrim(p_payload->>'taxonomy_other_description'),actor);
 end if;

 result:=app_private.activity_management_payload(target_activity_id);
 insert into app_private.activity_management_command_receipts(
  request_id,command_kind,request_hash,actor_person_id,activity_id,result_json
 ) values(p_idempotency_key,'upsert',request_hash,actor,target_activity_id,result);
 insert into audit.audit_logs(
  actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,
  outcome,before_json,after_json
 ) values(actor,auth.jwt()->>'aal',
  case when is_create then 'activity.create' else 'activity.update' end,
  'activity_definition',target_activity_id,target_institution_id,'success',
  case when is_create then null else to_jsonb(before_record) end,to_jsonb(saved));
 return result;
end $$;

create or replace function app_private.superadmin_duplicate_activity_template(
 p_template_id uuid,p_institution_id uuid,p_idempotency_key uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare template public.activity_templates%rowtype; payload jsonb;
begin
 select * into template from public.activity_templates template_record
  where template_record.id=p_template_id and template_record.status='active'
   and (template_record.scope_kind='platform'
     or template_record.institution_id=p_institution_id);
 if template.id is null then raise no_data_found using message='template not found'; end if;
 payload:=jsonb_build_object(
  'id',gen_random_uuid(),'institution_id',p_institution_id,
  'name',template.name,'description',template.description,
  'handle_stem',template.code||'-'||left(p_idempotency_key::text,6),
  'origin_scope_kind','institution','governance_kind',template.governance_kind,
  'status','draft','taxonomy_id',template.taxonomy_id,
  'identity_mode','initials','identity_initials',
    upper(left(regexp_replace(template.name,'[^[:alnum:]]','','g'),2)),
  'identity_color','#D63C00','unit_ids',jsonb_build_array(),
  'group_ids',jsonb_build_array());
 return app_private.superadmin_upsert_activity(payload,p_idempotency_key);
end $$;

create or replace function public.superadmin_upsert_activity(
 p_payload jsonb,p_idempotency_key uuid)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_upsert_activity(p_payload,p_idempotency_key)$$;
create or replace function public.superadmin_duplicate_activity_template(
 p_template_id uuid,p_institution_id uuid,p_idempotency_key uuid)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_duplicate_activity_template(
 p_template_id,p_institution_id,p_idempotency_key)$$;

revoke all on function app_private.superadmin_upsert_activity(jsonb,uuid)
 from public,anon,authenticated,service_role;
revoke all on function app_private.superadmin_duplicate_activity_template(uuid,uuid,uuid)
 from public,anon,authenticated,service_role;
revoke all on function public.superadmin_upsert_activity(jsonb,uuid)
 from public,anon,authenticated,service_role;
revoke all on function public.superadmin_duplicate_activity_template(uuid,uuid,uuid)
 from public,anon,authenticated,service_role;
grant execute on function public.superadmin_upsert_activity(jsonb,uuid) to authenticated;
grant execute on function public.superadmin_duplicate_activity_template(uuid,uuid,uuid)
 to authenticated;
commit;
