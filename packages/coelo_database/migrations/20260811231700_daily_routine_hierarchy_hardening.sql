-- Close cross-scope and typed-value gaps in the daily routine aggregate.

create or replace function app_private.validate_routine_model_hierarchy()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.origin_scope_kind = 'unit' and not exists (
    select 1 from public.units u
    where u.id = new.origin_unit_id and u.institution_id = new.institution_id
  ) then
    raise check_violation using message = 'routine model hierarchy mismatch';
  end if;
  return new;
end $$;

create trigger routine_models_validate_hierarchy
before insert or update on public.routine_models
for each row execute function app_private.validate_routine_model_hierarchy();

create or replace function app_private.validate_routine_application_hierarchy()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  unit_institution uuid;
  group_unit uuid;
  group_institution uuid;
  parent_row public.routine_applications;
  model_row public.routine_models;
begin
  if new.unit_id is not null then
    select institution_id into unit_institution from public.units where id = new.unit_id;
  end if;
  if new.group_id is not null then
    select unit_id, institution_id into group_unit, group_institution
    from public.groups where id = new.group_id;
  end if;
  if unit_institution is distinct from new.institution_id
     or (new.group_id is not null and
       (group_unit is distinct from new.unit_id or group_institution is distinct from new.institution_id)) then
    raise check_violation using message = 'routine application hierarchy mismatch';
  end if;

  select m.* into model_row
  from public.routine_model_versions v
  join public.routine_models m on m.id = v.model_id
  where v.id = new.source_model_version_id;
  if model_row.id is null
     or (model_row.origin_scope_kind = 'institution' and model_row.institution_id <> new.institution_id)
     or (model_row.origin_scope_kind = 'unit' and
       (model_row.institution_id <> new.institution_id or model_row.origin_unit_id is distinct from new.unit_id)) then
    raise check_violation using message = 'routine model application hierarchy mismatch';
  end if;

  if new.parent_application_id is not null then
    select * into parent_row from public.routine_applications where id = new.parent_application_id;
    if parent_row.id is null or parent_row.institution_id <> new.institution_id
       or (new.scope_kind = 'unit' and parent_row.scope_kind <> 'institution')
       or (new.scope_kind = 'group' and parent_row.scope_kind not in ('institution', 'unit'))
       or (new.scope_kind = 'group' and parent_row.scope_kind = 'unit'
         and parent_row.unit_id is distinct from new.unit_id) then
      raise check_violation using message = 'routine application hierarchy mismatch';
    end if;
  end if;
  return new;
end $$;

create or replace function app_private.validate_routine_launch_hierarchy()
returns trigger language plpgsql security definer set search_path='' as $$
declare actor uuid;
begin
  actor := app_private.current_person_id();
  if not exists (
      select 1 from public.units u
      where u.id = new.unit_id and u.institution_id = new.institution_id
    ) or not exists (
      select 1 from public.groups g
      where g.id = new.group_id and g.unit_id = new.unit_id and g.institution_id = new.institution_id
    ) or not exists (
      select 1 from public.routine_applications a
      where a.id = new.application_id and a.institution_id = new.institution_id
        and (a.unit_id is null or a.unit_id = new.unit_id)
        and (a.group_id is null or a.group_id = new.group_id)
    ) then
    raise check_violation using message = 'routine launch hierarchy mismatch';
  end if;
  if (tg_op = 'INSERT' or new.author_membership_id is distinct from old.author_membership_id)
     and not exists (
       select 1 from public.institution_memberships m
       where m.id = new.author_membership_id and m.institution_id = new.institution_id
         and m.person_id = actor and m.status = 'active' and m.revoked_at is null
     ) then
    raise check_violation using message = 'routine launch author mismatch';
  end if;
  return new;
end $$;

create or replace function app_private.validate_routine_answer()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  field_row public.routine_fields;
  launch_status text;
  invalid_item boolean;
begin
  select f, l.status into field_row, launch_status
  from public.routine_child_entries e
  join public.routine_launches l on l.id = e.launch_id
  join public.routine_application_revisions r on r.id = l.application_revision_id
  join public.routine_fields f on f.model_version_id = r.source_model_version_id
  where e.id = new.child_entry_id and f.id = new.field_id;
  if field_row.id is null then
    raise check_violation using message = 'routine answer field mismatch';
  end if;
  if new.value_json is null then return new; end if;

  if (field_row.field_kind in ('short_text', 'long_text') and jsonb_typeof(new.value_json) <> 'string')
     or (field_row.field_kind = 'number' and jsonb_typeof(new.value_json) <> 'number')
     or (field_row.field_kind = 'boolean' and jsonb_typeof(new.value_json) <> 'boolean')
     or (field_row.field_kind = 'single_choice' and jsonb_typeof(new.value_json) <> 'string')
     or (field_row.field_kind = 'multiple_choice' and jsonb_typeof(new.value_json) <> 'array') then
    raise check_violation using message = 'routine answer type mismatch';
  end if;
  if field_row.field_kind = 'short_text' and char_length(new.value_json #>> '{}') > 240 then
    raise check_violation using message = 'routine answer exceeds maximum length';
  end if;
  if field_row.field_kind = 'long_text' and char_length(new.value_json #>> '{}') > 4000 then
    raise check_violation using message = 'routine answer exceeds maximum length';
  end if;
  if field_row.field_kind = 'number' and
     ((field_row.min_value is not null and (new.value_json #>> '{}')::numeric < field_row.min_value)
       or (field_row.max_value is not null and (new.value_json #>> '{}')::numeric > field_row.max_value)) then
    raise check_violation using message = 'routine answer outside numeric limits';
  end if;
  if field_row.field_kind = 'single_choice' and not exists (
    select 1 from public.routine_field_options o
    where o.field_id = field_row.id and o.value_code = new.value_json #>> '{}'
  ) then
    raise check_violation using message = 'routine answer option mismatch';
  end if;
  if field_row.field_kind = 'multiple_choice' then
    select exists (
      select 1 from jsonb_array_elements(new.value_json) item
      where jsonb_typeof(item) <> 'string' or not exists (
        select 1 from public.routine_field_options o
        where o.field_id = field_row.id and o.value_code = item #>> '{}'
      )
    ) into invalid_item;
    if invalid_item or jsonb_array_length(new.value_json) <>
      (select count(distinct item #>> '{}') from jsonb_array_elements(new.value_json) item) then
      raise check_violation using message = 'routine answer option mismatch';
    end if;
  end if;
  if exists (
      select 1 from public.routine_field_conditions c where c.target_field_id = field_row.id
    ) and not exists (
      select 1
      from public.routine_field_conditions c
      join public.routine_answers parent_answer
        on parent_answer.child_entry_id = new.child_entry_id
       and parent_answer.field_id = c.source_field_id
      left join public.routine_field_options option_row on option_row.id = c.source_option_id
      where c.target_field_id = field_row.id and (
        (c.boolean_value is not null and parent_answer.value_json = to_jsonb(c.boolean_value))
        or (c.source_option_id is not null and (
          (jsonb_typeof(parent_answer.value_json) = 'string'
            and parent_answer.value_json #>> '{}' = option_row.value_code)
          or (jsonb_typeof(parent_answer.value_json) = 'array'
            and parent_answer.value_json ? option_row.value_code)
        ))
      )
    ) then
    raise check_violation using message = 'routine answer hidden by condition';
  end if;
  return new;
end $$;

create trigger routine_answers_validate
before insert or update on public.routine_answers
for each row execute function app_private.validate_routine_answer();

create or replace function app_private.superadmin_routine_revert_application(uuid, uuid, bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  actor uuid;
  app_row public.routine_applications;
  parent_row public.routine_applications;
  response jsonb;
  revision_no integer;
begin
  actor := app_private.require_routine_actor('routine.manage_applications', false);
  perform pg_advisory_xact_lock(hashtextextended($2::text, 0));
  response := app_private.routine_receipt($1, actor, 'revert_application');
  if response is not null then return response; end if;
  select * into app_row from public.routine_applications where id = $2 for update;
  if app_row.id is null then raise no_data_found; end if;
  if app_row.management_version <> $3 or app_row.parent_application_id is null then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  select * into parent_row from public.routine_applications where id = app_row.parent_application_id;
  update public.routine_applications
  set source_model_version_id = parent_row.source_model_version_id,
      inheritance_mode = 'inherited', management_version = management_version + 1, updated_at = now()
  where id = $2 returning * into app_row;
  select coalesce(max(r.revision_no), 0) + 1 into revision_no
  from public.routine_application_revisions r where r.application_id = $2;
  insert into public.routine_application_revisions(
    application_id, revision_no, source_model_version_id, origin_application_id,
    effective_definition, created_by_person_id
  ) values (
    $2, revision_no, app_row.source_model_version_id, parent_row.id,
    app_private.routine_definition_json(app_row.source_model_version_id), actor
  );
  response := jsonb_build_object('id', $2, 'management_version', app_row.management_version,
    'inherited', true, 'revision', revision_no);
  insert into app_private.routine_command_receipts
  values ($1, actor, 'revert_application', $2, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id, outcome, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'routine.application.revert', 'routine_application', $2,
    app_row.institution_id, 'success', response
  );
  return response;
end $$;

create or replace function public.superadmin_routine_correct_launch(uuid, uuid, bigint, text, jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare supplied integer;
begin
  if jsonb_typeof($5) <> 'array' or jsonb_array_length($5) not between 1 and 500 then
    raise invalid_parameter_value using message = 'invalid routine correction payload';
  end if;
  supplied := jsonb_array_length($5);
  if supplied <> (
      select count(distinct item->>'answer_id')
      from jsonb_array_elements($5) item
      where item ? 'answer_id'
    ) or supplied <> (
      select count(*)
      from public.routine_answers a
      join public.routine_child_entries e on e.id = a.child_entry_id
      where e.launch_id = $2 and a.id in (
        select (item->>'answer_id')::uuid from jsonb_array_elements($5) item
      )
    ) then
    raise check_violation using message = 'routine correction answer mismatch';
  end if;
  return app_private.superadmin_routine_correct_launch($1, $2, $3, $4, $5);
end $$;

revoke all on function app_private.validate_routine_model_hierarchy() from public, anon, authenticated;
revoke all on function app_private.validate_routine_application_hierarchy() from public, anon, authenticated;
revoke all on function app_private.validate_routine_launch_hierarchy() from public, anon, authenticated;
revoke all on function app_private.validate_routine_answer() from public, anon, authenticated;
revoke all on function app_private.superadmin_routine_revert_application(uuid,uuid,bigint) from public,anon,authenticated;
revoke all on function public.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb) from public, anon;
grant execute on function public.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb) to authenticated;

-- Production authorization and attendance command closure.
insert into public.platform_permissions(
 code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status
) values
 ('attendance.read','attendance','attendance','read','Read attendance in authorized scopes.','high',false,'active'),
 ('attendance.manage','attendance','attendance','manage','Manage attendance in authorized scopes.','critical',false,'active')
on conflict(code) do update set status='active';

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r
join public.platform_permissions p on p.code in('attendance.read','attendance.manage')
where r.code='owner'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

insert into public.institution_permissions(code,module_code,screen_code,action_code,description,risk_level,status)
values
 ('routine.read','routine','daily_routine','read','Read routine data in the assigned context.','high','active'),
 ('routine.manage_models','routine','daily_routine','manage_models','Manage routine models in the assigned context.','critical','active'),
 ('routine.manage_applications','routine','daily_routine','manage_applications','Manage routine applications in the assigned context.','critical','active'),
 ('routine.record','routine','daily_routine','record','Record routine entries in the assigned context.','high','active'),
 ('routine.publish','routine','daily_routine','publish','Publish routine entries in the assigned context.','critical','active'),
 ('routine.correct','routine','daily_routine','correct','Correct routine entries in the assigned context.','critical','active')
on conflict(code) do update set status='active',updated_at=now();

delete from public.platform_role_permissions rp using public.platform_permissions p,public.platform_roles r
where rp.permission_id=p.id and rp.role_id=r.id and p.code like 'routine.%' and r.code<>'owner';

create or replace function app_private.routine_scope_allowed(
 p_capability text,p_institution_id uuid,p_unit_id uuid default null,p_group_id uuid default null
) returns boolean language sql stable security definer set search_path='' as $$
 select case when p_institution_id is null
  then app_private.has_platform_permission(p_capability)
  else app_private.has_platform_permission(p_capability)
   or app_private.has_context_permission(
    p_institution_id,p_capability,p_unit_id,p_group_id,null,null,false
   )
 end
$$;

create or replace function app_private.require_routine_scope(
 p_capability text,p_institution_id uuid,p_unit_id uuid default null,p_group_id uuid default null,
 p_aal2 boolean default false
) returns uuid language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=app_private.current_person_id();
begin
 if actor is null then raise insufficient_privilege using message='authentication required';end if;
 if not app_private.routine_scope_allowed(p_capability,p_institution_id,p_unit_id,p_group_id) then
  raise insufficient_privilege using message=p_capability||' required';
 end if;
 if p_aal2 and not app_private.has_mfa_aal2() then
  raise insufficient_privilege using message='MFA AAL2 required';
 end if;
 return actor;
end $$;

create or replace function app_private.superadmin_routine_directory(
 p_kind text,p_search text,p_status text,p_institution_id uuid,p_unit_id uuid,p_group_id uuid,
 p_limit integer,p_offset integer
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=app_private.current_person_id();result jsonb;
begin
 if actor is null then raise insufficient_privilege using message='authentication required';end if;
 if p_kind not in('model','application','launch')or p_limit not between 1 and 100 or p_offset<0 then
  raise invalid_parameter_value using message='invalid routine directory query';
 end if;
 with entries as(
  select m.id,'model'::text kind,m.name,m.status,m.current_version::bigint version,
   m.institution_id,m.origin_unit_id unit_id,null::uuid group_id,m.origin_scope_kind origin_label,
   null::text effective_label
  from public.routine_models m
  union all
  select a.id,'application',m.name,a.status,a.management_version,a.institution_id,a.unit_id,a.group_id,
   'model v'||v.version_no::text,case a.inheritance_mode when'inherited'then'Herdada'else'Personalizada'end
  from public.routine_applications a join public.routine_model_versions v on v.id=a.source_model_version_id
  join public.routine_models m on m.id=v.model_id
  union all
  select l.id,'launch',m.name||' - '||l.service_date::text,l.status,l.management_version,
   l.institution_id,l.unit_id,l.group_id,'application '||l.application_id::text,l.service_date::text
  from public.routine_launches l join public.routine_application_revisions ar on ar.id=l.application_revision_id
  join public.routine_model_versions v on v.id=ar.source_model_version_id
  join public.routine_models m on m.id=v.model_id
 ),filtered as(
  select * from entries e where e.kind=p_kind
   and app_private.routine_scope_allowed('routine.read',e.institution_id,e.unit_id,e.group_id)
   and(btrim(coalesce(p_search,''))=''or e.name ilike'%'||p_search||'%')
   and(p_status is null or e.status=p_status)
   and(p_institution_id is null or e.institution_id=p_institution_id)
   and(p_unit_id is null or e.unit_id=p_unit_id)
   and(p_group_id is null or e.group_id=p_group_id)
 )
 select jsonb_build_object(
  'items',coalesce(jsonb_agg(to_jsonb(page_row)order by lower(name),id),'[]'::jsonb),
  'total_count',(select count(*)from filtered),
  'can_manage',case p_kind when'model'then app_private.has_platform_permission('routine.manage_models')
   else exists(select 1 from filtered e where app_private.routine_scope_allowed(
    case p_kind when'application'then'routine.manage_applications'else'routine.record'end,e.institution_id,e.unit_id,e.group_id))end
 )into result from(select*from filtered order by lower(name),id limit p_limit offset p_offset)page_row;
 return result;
end $$;

drop policy if exists routine_models_select on public.routine_models;
create policy routine_models_select on public.routine_models for select to authenticated
using(app_private.routine_scope_allowed('routine.read',institution_id,origin_unit_id,null));
drop policy if exists routine_applications_select on public.routine_applications;
create policy routine_applications_select on public.routine_applications for select to authenticated
using(app_private.routine_scope_allowed('routine.read',institution_id,unit_id,group_id));
drop policy if exists routine_launches_select on public.routine_launches;
create policy routine_launches_select on public.routine_launches for select to authenticated
using(app_private.routine_scope_allowed('routine.read',institution_id,unit_id,group_id));

alter table public.attendance_sessions drop constraint if exists attendance_sessions_status_check;
alter table public.attendance_sessions add constraint attendance_sessions_status_check
 check(status in('draft','open','closed','cancelled'));
alter table public.attendance_sessions add column if not exists routine_launch_id uuid
 references public.routine_launches(id)on delete restrict;
alter table app_private.attendance_bulk_operations
 add column if not exists affected_records jsonb not null default'[]'::jsonb
 check(jsonb_typeof(affected_records)='array');

create or replace function app_private.attendance_command_replay(
 p_key uuid,p_actor uuid,p_command text,p_request_hash text
)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare receipt app_private.attendance_command_receipts%rowtype;
begin
 if p_key is null then return null;end if;
 perform pg_advisory_xact_lock(hashtextextended(p_key::text,0));
 select*into receipt from app_private.attendance_command_receipts where idempotency_key=p_key for update;
 if receipt.idempotency_key is null then return null;end if;
 if receipt.actor_person_id<>p_actor then raise insufficient_privilege using message='idempotency receipt actor mismatch';end if;
 if receipt.command_name<>p_command or receipt.request_hash<>p_request_hash then
  raise invalid_parameter_value using message='attendance command replay mismatch';
 end if;
 return receipt.result_json;
end $$;

create or replace function app_private.attendance_command_store(
 p_key uuid,p_actor uuid,p_command text,p_aggregate uuid,p_request_hash text,p_result jsonb
)returns void language sql volatile security definer set search_path=''as $$
 insert into app_private.attendance_command_receipts(
  idempotency_key,actor_person_id,command_name,aggregate_id,request_hash,result_json
 )values(p_key,p_actor,p_command,p_aggregate,p_request_hash,p_result)
$$;

create or replace function app_private.superadmin_attendance_context_options(p_date date)
returns jsonb language plpgsql stable security definer set search_path=''as $$
declare actor uuid:=app_private.current_person_id();result jsonb;
begin
 if actor is null then raise insufficient_privilege using message='authentication required';end if;
 if p_date is null then raise invalid_parameter_value using message='attendance date required';end if;
 with authorized_groups as(
  select g.id,g.name,g.institution_id,g.unit_id,
   app_private.can_access_attendance_child(g.institution_id,g.unit_id,g.id,null,null,true)can_manage
  from public.groups g where g.status='active'
   and app_private.can_access_attendance_child(g.institution_id,g.unit_id,g.id,null,null,false)
 ),authorized_units as(
  select distinct u.id,u.name,u.institution_id,
   exists(select 1 from authorized_groups g where g.unit_id=u.id and g.can_manage)can_manage
  from public.units u join authorized_groups g on g.unit_id=u.id where u.status='active'
 ),authorized_institutions as(
  select distinct i.id,i.public_name name,
   exists(select 1 from authorized_groups g where g.institution_id=i.id and g.can_manage)can_manage
  from public.institutions i join authorized_groups g on g.institution_id=i.id where i.status='active'
 ),authorized_activities as(
  select distinct a.id,a.name,al.institution_id,al.unit_id,al.group_id,
   app_private.can_access_attendance_child(al.institution_id,al.unit_id,al.group_id,a.id,null,true)can_manage
  from public.activity_group_links al join public.activity_definitions a on a.id=al.activity_id
  join authorized_groups g on g.id=al.group_id
  where al.status='active'and(al.ends_at is null or al.ends_at>now())and a.status='active'
   and app_private.can_access_attendance_child(al.institution_id,al.unit_id,al.group_id,a.id,null,false)
 )
 select jsonb_build_object(
  'institutions',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'attendance_required',true,'can_manage',can_manage)order by name,id)from authorized_institutions),'[]'::jsonb),
  'units',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'institution_id',institution_id,'attendance_required',true,'can_manage',can_manage)order by name,id)from authorized_units),'[]'::jsonb),
  'groups',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'institution_id',institution_id,'unit_id',unit_id,'attendance_required',true,'can_manage',can_manage)order by name,id)from authorized_groups),'[]'::jsonb),
  'activities',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'institution_id',institution_id,'unit_id',unit_id,'group_id',group_id,'attendance_required',true,'can_manage',can_manage)order by name,id)from authorized_activities),'[]'::jsonb)
 )into result;
 return result;
end $$;

create or replace function app_private.attendance_call_payload(p_id uuid)returns jsonb
language sql stable security definer set search_path=''as $$
select jsonb_build_object(
 'id',s.id,'institution_id',s.institution_id,'institution_name',i.public_name,
 'unit_id',s.unit_id,'unit_name',u.name,'group_id',s.group_id,'group_name',g.name,
 'activity_id',s.activity_id,'activity_name',a.name,'session_date',s.session_date,
 'status',s.status,'responsible',p.display_name,'updated_at',s.updated_at,
 'version',s.management_version,
 'can_manage',app_private.can_access_attendance_child(s.institution_id,s.unit_id,s.group_id,s.activity_id,null,true),
 'participants',coalesce((select jsonb_agg(jsonb_build_object(
  'id',ep.child_context_id,'name',cp.display_name,'state',coalesce(r.outcome,'unmarked'),
  'note',coalesce(r.note,''))order by cp.display_name)
  from public.attendance_expected_participants ep
  join public.child_contexts cc on cc.id=ep.child_context_id join public.people cp on cp.id=cc.child_person_id
  left join public.attendance_records r on r.attendance_session_id=s.id
   and r.child_context_id=ep.child_context_id and r.status='active'
  where ep.attendance_session_id=s.id and ep.status='active'),'[]'::jsonb),
 'revisions','[]'::jsonb
)from public.attendance_sessions s join public.institutions i on i.id=s.institution_id
join public.units u on u.id=s.unit_id join public.groups g on g.id=s.group_id
left join public.activity_definitions a on a.id=s.activity_id join public.people p on p.id=s.created_by_person_id
where s.id=p_id and app_private.can_access_attendance_child(s.institution_id,s.unit_id,s.group_id,s.activity_id,null,false)
$$;

create or replace function app_private.superadmin_attendance_create_call(
 p_institution_id uuid,p_unit_id uuid,p_group_id uuid,p_activity_id uuid,p_session_date date,
 p_idempotency_key uuid default null
)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid:=app_private.current_person_id();key uuid:=coalesce(p_idempotency_key,gen_random_uuid());
 s public.attendance_sessions%rowtype;unit_timezone text;prior jsonb;result jsonb;
 request_hash text:=encode(extensions.digest(convert_to(jsonb_build_array(
  p_institution_id,p_unit_id,p_group_id,p_activity_id,p_session_date)::text,'UTF8'),'sha256'),'hex');
begin
 if actor is null then raise insufficient_privilege using message='authentication required';end if;
 prior:=app_private.attendance_command_replay(key,actor,'create_call',request_hash);
 if prior is not null then return prior;end if;
 perform pg_advisory_xact_lock(hashtextextended(p_group_id::text||coalesce(p_activity_id::text,'group')||p_session_date::text,0));
 if not app_private.can_access_attendance_child(p_institution_id,p_unit_id,p_group_id,p_activity_id,null,true)then
  raise insufficient_privilege using message='attendance.manage required';
 end if;
 select u.timezone into unit_timezone from public.units u
 where u.id=p_unit_id and u.institution_id=p_institution_id and u.status='active';
 if unit_timezone is null or not exists(select 1 from public.groups g where g.id=p_group_id
  and g.institution_id=p_institution_id and g.unit_id=p_unit_id and g.status='active')then
  raise invalid_parameter_value using message='attendance context mismatch';
 end if;
 if p_session_date>(now()at time zone unit_timezone)::date then
  raise invalid_parameter_value using message='attendance date cannot be in the future';
 end if;
 if p_activity_id is not null and not exists(select 1 from public.activity_group_links al
  where al.activity_id=p_activity_id and al.group_id=p_group_id and al.institution_id=p_institution_id
   and al.unit_id=p_unit_id and al.status='active'and(al.ends_at is null or al.ends_at>now()))then
  raise invalid_parameter_value using message='attendance context mismatch';
 end if;
 select*into s from public.attendance_sessions where group_id=p_group_id
  and activity_id is not distinct from p_activity_id and session_date=p_session_date and status<>'cancelled'for update;
 if s.id is null then
  insert into public.attendance_sessions(institution_id,unit_id,group_id,activity_id,session_kind,
   session_date,status,created_by_person_id,opened_by_person_id,opened_at,timezone)
  values(p_institution_id,p_unit_id,p_group_id,p_activity_id,case when p_activity_id is null then'group'else'activity'end,
   p_session_date,'open',actor,actor,now(),unit_timezone)returning*into s;
  insert into public.attendance_expected_participants(
   attendance_session_id,child_context_id,child_group_link_id,activity_group_participant_id
  )select s.id,cu.child_context_id,cg.id,ap.id from public.child_group_links cg
  join public.child_unit_links cu on cu.id=cg.child_unit_link_id
  left join public.activity_group_links al on p_activity_id is not null and al.activity_id=p_activity_id
   and al.group_id=p_group_id and al.status='active'and(al.ends_at is null or al.ends_at>now())
  left join public.activity_group_participants ap on ap.activity_group_link_id=al.id
   and ap.child_group_link_id=cg.id and ap.status='active'and ap.removed_at is null
  where cg.group_id=p_group_id and cg.status='active'and cu.status in('active','awaiting_allocation')
   and(p_activity_id is null or ap.id is not null);
  insert into public.attendance_session_revisions(attendance_session_id,action_code,after_json,changed_by_person_id)
  values(s.id,'created',to_jsonb(s),actor);
 end if;
 result:=app_private.attendance_call_payload(s.id);
 perform app_private.attendance_command_store(key,actor,'create_call',s.id,request_hash,result);
 return result;
end $$;

create or replace function app_private.superadmin_attendance_set_participant(
 p_call_id uuid,p_participant_id uuid,p_state text,p_expected_version bigint,p_idempotency_key uuid default null
)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid:=app_private.current_person_id();key uuid:=coalesce(p_idempotency_key,gen_random_uuid());
 prior jsonb;result jsonb;request_hash text:=encode(extensions.digest(convert_to(
  jsonb_build_array(p_call_id,p_participant_id,p_state,p_expected_version)::text,'UTF8'),'sha256'),'hex');
begin
 if actor is null then raise insufficient_privilege using message='authentication required';end if;
 prior:=app_private.attendance_command_replay(key,actor,'set_participant',request_hash);
 if prior is not null then return prior;end if;
 result:=app_private.attendance_set_core(p_call_id,p_participant_id,p_state,p_expected_version,actor);
 perform app_private.attendance_command_store(key,actor,'set_participant',p_call_id,request_hash,result);
 return result;
end $$;

create or replace function app_private.superadmin_attendance_complete_call(
 p_call_id uuid,p_expected_version bigint,p_idempotency_key uuid default null
)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid:=app_private.current_person_id();key uuid:=coalesce(p_idempotency_key,gen_random_uuid());
 s public.attendance_sessions%rowtype;before_state jsonb;prior jsonb;result jsonb;
 request_hash text:=encode(extensions.digest(convert_to(jsonb_build_array(p_call_id,p_expected_version)::text,'UTF8'),'sha256'),'hex');
begin
 if actor is null then raise insufficient_privilege using message='authentication required';end if;
 prior:=app_private.attendance_command_replay(key,actor,'complete_call',request_hash);
 if prior is not null then return prior;end if;
 s:=app_private.attendance_assert_session_manage(p_call_id,p_expected_version);before_state:=to_jsonb(s);
 if s.status<>'open'then raise check_violation using message='only open attendance can be closed';end if;
 if exists(select 1 from public.attendance_expected_participants ep left join public.attendance_records r
  on r.attendance_session_id=p_call_id and r.child_context_id=ep.child_context_id and r.status='active'
  where ep.attendance_session_id=p_call_id and ep.status='active'and r.id is null)then
  raise check_violation using message='unmarked attendance participants';
 end if;
 if s.routine_launch_id is not null and not exists(select 1 from public.routine_launches l
  where l.id=s.routine_launch_id and l.institution_id=s.institution_id and l.unit_id=s.unit_id
   and l.group_id=s.group_id and l.service_date=s.session_date and l.status in('published','corrected'))then
  raise check_violation using message='linked routine must be published';
 end if;
 update public.attendance_sessions set status='closed',closed_by_person_id=actor,closed_at=now(),
  management_version=management_version+1,updated_at=now()where id=p_call_id returning*into s;
 insert into public.attendance_session_revisions(attendance_session_id,action_code,before_json,after_json,changed_by_person_id)
 values(p_call_id,'closed',before_state,to_jsonb(s),actor);
 result:=app_private.attendance_call_payload(p_call_id);
 perform app_private.attendance_command_store(key,actor,'complete_call',p_call_id,request_hash,result);
 return result;
end $$;

create or replace function app_private.superadmin_attendance_reopen_call(
 p_call_id uuid,p_expected_version bigint,p_reason text
)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid:=app_private.current_person_id();s public.attendance_sessions%rowtype;before_state jsonb;
begin
 if actor is null then raise insufficient_privilege using message='authentication required';end if;
 if nullif(btrim(p_reason),'')is null then raise invalid_parameter_value using message='reopen reason required';end if;
 s:=app_private.attendance_assert_session_manage(p_call_id,p_expected_version);before_state:=to_jsonb(s);
 if s.status<>'closed'then raise check_violation using message='only closed attendance can be reopened';end if;
 update public.attendance_sessions set status='open',reopened_at=now(),reopened_by_person_id=actor,
  closed_at=null,closed_by_person_id=null,management_version=management_version+1,updated_at=now()
 where id=p_call_id returning*into s;
 insert into public.attendance_session_revisions(attendance_session_id,action_code,before_json,after_json,reason,changed_by_person_id)
 values(p_call_id,'reopened',before_state,to_jsonb(s),btrim(p_reason),actor);
 return app_private.attendance_call_payload(p_call_id);
end $$;

create or replace function app_private.superadmin_attendance_correct_participant(
 p_call_id uuid,p_participant_id uuid,p_state text,p_reason text,p_expected_version bigint,p_notice_id uuid default null
)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid:=app_private.current_person_id();s public.attendance_sessions%rowtype;before_state jsonb;current_version bigint;
begin
 if actor is null then raise insufficient_privilege using message='authentication required';end if;
 if nullif(btrim(p_reason),'')is null then raise invalid_parameter_value using message='correction reason required';end if;
 s:=app_private.attendance_assert_session_manage(p_call_id,p_expected_version);before_state:=to_jsonb(s);
 if s.status<>'closed'then raise check_violation using message='attendance correction requires closed call';end if;
 update public.attendance_sessions set status='open',closed_at=null,closed_by_person_id=null where id=p_call_id;
 perform app_private.attendance_set_core(p_call_id,p_participant_id,p_state,p_expected_version,actor,p_notice_id,btrim(p_reason));
 select management_version into current_version from public.attendance_sessions where id=p_call_id;
 update public.attendance_sessions set status='closed',closed_at=now(),closed_by_person_id=actor,
  management_version=management_version+1,updated_at=now()where id=p_call_id returning*into s;
 insert into public.attendance_session_revisions(attendance_session_id,action_code,before_json,after_json,reason,changed_by_person_id)
 values(p_call_id,'corrected',before_state,to_jsonb(s),btrim(p_reason),actor);
 return app_private.attendance_call_payload(p_call_id);
end $$;

create or replace function public.superadmin_attendance_context_options(p_date date)
returns jsonb language sql stable security definer set search_path=''as $$
 select app_private.superadmin_attendance_context_options(p_date)
$$;

revoke all on function public.superadmin_attendance_context_options(date)from public,anon;
grant execute on function public.superadmin_attendance_context_options(date)to authenticated,service_role;
revoke all on function app_private.superadmin_attendance_context_options(date)from public,anon,authenticated;
revoke all on function app_private.attendance_command_replay(uuid,uuid,text,text)from public,anon,authenticated;
revoke all on function app_private.attendance_command_store(uuid,uuid,text,uuid,text,jsonb)from public,anon,authenticated;
revoke all on function app_private.routine_scope_allowed(text,uuid,uuid,uuid)from public,anon,authenticated;
revoke all on function app_private.require_routine_scope(text,uuid,uuid,uuid,boolean)from public,anon,authenticated;
grant execute on function app_private.superadmin_attendance_context_options(date)to service_role;
grant execute on function app_private.attendance_command_replay(uuid,uuid,text,text)to service_role;
grant execute on function app_private.attendance_command_store(uuid,uuid,text,uuid,text,jsonb)to service_role;
grant execute on function app_private.routine_scope_allowed(text,uuid,uuid,uuid)to service_role;
grant execute on function app_private.require_routine_scope(text,uuid,uuid,uuid,boolean)to service_role;


create or replace function app_private.superadmin_attendance_mark_remaining_present(
 p_call_id uuid,p_expected_version bigint,p_idempotency_key uuid default null
)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid:=app_private.current_person_id();s public.attendance_sessions%rowtype;
 operation_id uuid:=coalesce(p_idempotency_key,gen_random_uuid());participant_ids uuid[];records jsonb;
 prior jsonb;result jsonb;request_hash text:=encode(extensions.digest(convert_to(
  jsonb_build_array(p_call_id,p_expected_version)::text,'UTF8'),'sha256'),'hex');
begin
 if actor is null then raise insufficient_privilege using message='authentication required';end if;
 prior:=app_private.attendance_command_replay(operation_id,actor,'mark_remaining_present',request_hash);
 if prior is not null then return prior;end if;
 s:=app_private.attendance_assert_session_manage(p_call_id,p_expected_version);
 if s.status<>'open'then raise check_violation using message='attendance call is not open';end if;
 with inserted as(
  insert into public.attendance_records(attendance_session_id,child_context_id,outcome,confirmed_by_person_id)
  select p_call_id,ep.child_context_id,'present',actor
  from public.attendance_expected_participants ep
  left join public.attendance_records r on r.attendance_session_id=p_call_id
   and r.child_context_id=ep.child_context_id and r.status='active'
  where ep.attendance_session_id=p_call_id and ep.status='active'and r.id is null
  returning id,child_context_id,management_version
 )select coalesce(array_agg(child_context_id),'{}'::uuid[]),
   coalesce(jsonb_agg(jsonb_build_object('id',id,'management_version',management_version)),'[]'::jsonb)
 into participant_ids,records from inserted;
 insert into app_private.attendance_bulk_operations(
  operation_id,attendance_session_id,actor_person_id,operation_kind,before_json,
  affected_participant_ids,affected_records
 )values(operation_id,p_call_id,actor,'mark_remaining','[]',participant_ids,records);
 update public.attendance_sessions set management_version=management_version+1,updated_at=now()
 where id=p_call_id returning*into s;
 result:=jsonb_build_object('call',app_private.attendance_call_payload(p_call_id),'receipt',
  jsonb_build_object('operation_id',operation_id,'call_id',p_call_id,
   'affected_participant_ids',participant_ids,'previous_version',p_expected_version,
   'current_version',s.management_version));
 perform app_private.attendance_command_store(
  operation_id,actor,'mark_remaining_present',p_call_id,request_hash,result
 );
 return result;
end $$;

create or replace function app_private.superadmin_attendance_clear_presence_marks(
 p_call_id uuid,p_expected_version bigint,p_idempotency_key uuid default null
)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid:=app_private.current_person_id();s public.attendance_sessions%rowtype;
 operation_id uuid:=coalesce(p_idempotency_key,gen_random_uuid());participant_ids uuid[];
 snapshot jsonb;records jsonb;prior jsonb;result jsonb;
 request_hash text:=encode(extensions.digest(convert_to(
  jsonb_build_array(p_call_id,p_expected_version)::text,'UTF8'),'sha256'),'hex');
begin
 if actor is null then raise insufficient_privilege using message='authentication required';end if;
 prior:=app_private.attendance_command_replay(operation_id,actor,'clear_presence_marks',request_hash);
 if prior is not null then return prior;end if;
 s:=app_private.attendance_assert_session_manage(p_call_id,p_expected_version);
 if s.status<>'open'then raise check_violation using message='attendance call is not open';end if;
 select coalesce(array_agg(r.child_context_id),'{}'::uuid[]),coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb),
  coalesce(jsonb_agg(jsonb_build_object('id',r.id,'management_version',r.management_version)),'[]'::jsonb)
 into participant_ids,snapshot,records from public.attendance_records r
 where r.attendance_session_id=p_call_id and r.status='active';
 insert into app_private.attendance_bulk_operations(
  operation_id,attendance_session_id,actor_person_id,operation_kind,before_json,
  affected_participant_ids,affected_records
 )values(operation_id,p_call_id,actor,'clear_presence_marks',snapshot,participant_ids,records);
 update public.attendance_records r set status='inactive',reverted_by_person_id=actor,reverted_at=now(),
  revert_reason='bulk clear',management_version=management_version+1,updated_at=now()
 where r.attendance_session_id=p_call_id and r.status='active'
  and exists(select 1 from jsonb_array_elements(records)x where(x->>'id')::uuid=r.id
   and(x->>'management_version')::bigint=r.management_version);
 update public.attendance_sessions set management_version=management_version+1,updated_at=now()
 where id=p_call_id returning*into s;
 result:=jsonb_build_object('call',app_private.attendance_call_payload(p_call_id),'receipt',
  jsonb_build_object('operation_id',operation_id,'call_id',p_call_id,
   'affected_participant_ids',participant_ids,'previous_version',p_expected_version,
   'current_version',s.management_version));
 perform app_private.attendance_command_store(
  operation_id,actor,'clear_presence_marks',p_call_id,request_hash,result
 );
 return result;
end $$;

create or replace function app_private.superadmin_attendance_undo_bulk(
 p_operation_id uuid,p_call_id uuid,p_expected_version bigint
)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid:=app_private.current_person_id();s public.attendance_sessions%rowtype;
 operation app_private.attendance_bulk_operations%rowtype;affected_count integer;expected_count integer;
begin
 if actor is null then raise insufficient_privilege using message='authentication required';end if;
 s:=app_private.attendance_assert_session_manage(p_call_id,p_expected_version);
 if s.status<>'open'then raise check_violation using message='attendance call is not open';end if;
 select*into operation from app_private.attendance_bulk_operations
 where operation_id=p_operation_id and attendance_session_id=p_call_id for update;
 if operation.operation_id is null or operation.undone_at is not null then
  raise invalid_parameter_value using message='bulk operation unavailable';
 end if;
 expected_count:=jsonb_array_length(operation.affected_records);
 if operation.operation_kind='mark_remaining'then
  select count(*)into affected_count from public.attendance_records r
  where r.attendance_session_id=p_call_id and r.status='active'
   and exists(select 1 from jsonb_array_elements(operation.affected_records)x
    where(x->>'id')::uuid=r.id and(x->>'management_version')::bigint=r.management_version);
  if affected_count<>expected_count then
   raise serialization_failure using message='bulk records changed after operation';
  end if;
  update public.attendance_records r set status='inactive',reverted_by_person_id=actor,reverted_at=now(),
   revert_reason='bulk undo',management_version=management_version+1,updated_at=now()
  where r.attendance_session_id=p_call_id and r.status='active'
   and exists(select 1 from jsonb_array_elements(operation.affected_records)x
    where(x->>'id')::uuid=r.id and(x->>'management_version')::bigint=r.management_version);
 elsif operation.operation_kind='clear_presence_marks'then
  select count(*)into affected_count from public.attendance_records r
  where r.attendance_session_id=p_call_id and r.status='inactive'
   and exists(select 1 from jsonb_array_elements(operation.affected_records)x
    where(x->>'id')::uuid=r.id and(x->>'management_version')::bigint+1=r.management_version);
  if affected_count<>expected_count then
   raise serialization_failure using message='bulk records changed after operation';
  end if;
  update public.attendance_records r set status='active',reverted_by_person_id=null,reverted_at=null,
   revert_reason=null,management_version=management_version+1,updated_at=now()
  where r.attendance_session_id=p_call_id and r.status='inactive'
   and exists(select 1 from jsonb_array_elements(operation.affected_records)x
    where(x->>'id')::uuid=r.id and(x->>'management_version')::bigint+1=r.management_version);
 else raise invalid_parameter_value using message='bulk operation unavailable';end if;
 update app_private.attendance_bulk_operations set undone_at=now(),undone_by_person_id=actor
 where operation_id=p_operation_id;
 update public.attendance_sessions set management_version=management_version+1,updated_at=now()
 where id=p_call_id;
 return app_private.attendance_call_payload(p_call_id);
end $$;

create or replace function app_private.superadmin_routine_model_detail(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''as $$
declare result jsonb;model_row public.routine_models%rowtype;
begin
 if app_private.current_person_id()is null then raise insufficient_privilege using message='authentication required';end if;
 select*into model_row from public.routine_models where id=p_id;
 if model_row.id is null or not app_private.routine_scope_allowed(
  'routine.read',model_row.institution_id,model_row.origin_unit_id,null)then raise no_data_found;end if;
 select to_jsonb(model_row)||jsonb_build_object(
  'definition',app_private.routine_definition_json(v.id),
  'can_manage',app_private.routine_scope_allowed(
   'routine.manage_models',model_row.institution_id,model_row.origin_unit_id,null)
 )into result from public.routine_model_versions v
 where v.model_id=model_row.id and v.version_no=model_row.current_version;
 return result;
end $$;

create or replace function app_private.superadmin_routine_application_detail(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''as $$
declare result jsonb;application_row public.routine_applications%rowtype;
begin
 if app_private.current_person_id()is null then raise insufficient_privilege using message='authentication required';end if;
 select*into application_row from public.routine_applications where id=p_id;
 if application_row.id is null or not app_private.routine_scope_allowed(
  'routine.read',application_row.institution_id,application_row.unit_id,application_row.group_id)then raise no_data_found;end if;
 select to_jsonb(application_row)||jsonb_build_object('revision',to_jsonb(r),
  'assignees',coalesce((select jsonb_agg(to_jsonb(x))from public.routine_application_assignees x
   where x.application_id=application_row.id),'[]'::jsonb),
  'can_manage',app_private.routine_scope_allowed('routine.manage_applications',
   application_row.institution_id,application_row.unit_id,application_row.group_id)
 )into result from lateral(select*from public.routine_application_revisions x
  where x.application_id=application_row.id order by x.revision_no desc limit 1)r;
 return result;
end $$;

create or replace function app_private.superadmin_routine_launch_detail(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''as $$
declare result jsonb;launch_row public.routine_launches%rowtype;
begin
 if app_private.current_person_id()is null then raise insufficient_privilege using message='authentication required';end if;
 select*into launch_row from public.routine_launches where id=p_id;
 if launch_row.id is null or not app_private.routine_scope_allowed(
  'routine.read',launch_row.institution_id,launch_row.unit_id,launch_row.group_id)then raise no_data_found;end if;
 select to_jsonb(launch_row)||jsonb_build_object('children',coalesce((select jsonb_agg(
  to_jsonb(e)||jsonb_build_object('answers',coalesce((select jsonb_agg(to_jsonb(a))
   from public.routine_answers a where a.child_entry_id=e.id),'[]'::jsonb)))
  from public.routine_child_entries e where e.launch_id=launch_row.id),'[]'::jsonb),
  'can_manage',app_private.routine_scope_allowed('routine.record',
   launch_row.institution_id,launch_row.unit_id,launch_row.group_id)
 )into result;
 return result;
end $$;

revoke all on function app_private.superadmin_attendance_mark_remaining_present(uuid,bigint,uuid)from public,anon,authenticated;
revoke all on function app_private.superadmin_attendance_clear_presence_marks(uuid,bigint,uuid)from public,anon,authenticated;
revoke all on function app_private.superadmin_attendance_undo_bulk(uuid,uuid,bigint)from public,anon,authenticated;
grant execute on function app_private.superadmin_attendance_mark_remaining_present(uuid,bigint,uuid)to service_role;
grant execute on function app_private.superadmin_attendance_clear_presence_marks(uuid,bigint,uuid)to service_role;
grant execute on function app_private.superadmin_attendance_undo_bulk(uuid,uuid,bigint)to service_role;
