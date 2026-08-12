create or replace function app_private.require_routine_actor(p_capability text,p_aal2 boolean default false)
returns uuid language plpgsql stable security definer set search_path='' as $$
declare actor uuid;
begin
 actor:=app_private.current_person_id();
 if actor is null then raise insufficient_privilege using message='authentication required'; end if;
 if not app_private.has_platform_permission(p_capability) then
  raise insufficient_privilege using message=p_capability||' required'; end if;
 if p_aal2 and not app_private.has_mfa_aal2() then
  raise insufficient_privilege using message='MFA AAL2 required'; end if;
 return actor;
end $$;

create or replace function app_private.validate_routine_definition(p_version_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare has_cycle boolean; max_depth integer;
begin
 if exists(select 1 from public.routine_fields f where f.model_version_id=p_version_id
  and f.initial_value is not null and not(
   (f.field_kind in ('short_text','long_text','single_choice') and jsonb_typeof(f.initial_value)='string')
   or (f.field_kind='multiple_choice' and jsonb_typeof(f.initial_value)='array')
   or (f.field_kind='number' and jsonb_typeof(f.initial_value)='number')
   or (f.field_kind='boolean' and jsonb_typeof(f.initial_value)='boolean'))) then
  raise check_violation using message='initial value does not match field type'; end if;
 if exists(select 1 from public.routine_fields f where f.model_version_id=p_version_id
  and f.field_kind in ('single_choice','multiple_choice')
  and not exists(select 1 from public.routine_field_options o where o.field_id=f.id)) then
  raise check_violation using message='choice fields require options'; end if;
 if exists(select 1 from public.routine_fields f where f.model_version_id=p_version_id
  and f.field_kind='single_choice' and f.initial_value is not null
  and not exists(select 1 from public.routine_field_options o where o.field_id=f.id
   and o.value_code=f.initial_value#>>'{}')) then
  raise check_violation using message='single choice initial value must be an option'; end if;
 if exists(select 1 from public.routine_fields f where f.model_version_id=p_version_id
  and f.field_kind='multiple_choice' and f.initial_value is not null and exists(
   select 1 from jsonb_array_elements(f.initial_value) item where jsonb_typeof(item)<>'string'
    or not exists(select 1 from public.routine_field_options o where o.field_id=f.id
      and o.value_code=item#>>'{}'))) then
  raise check_violation using message='multiple choice initial values must be options'; end if;
 if exists(select 1 from public.routine_fields f where f.model_version_id=p_version_id
  and f.field_kind='number' and f.initial_value is not null and (
   (f.min_value is not null and (f.initial_value#>>'{}')::numeric<f.min_value)
   or (f.max_value is not null and (f.initial_value#>>'{}')::numeric>f.max_value))) then
  raise check_violation using message='number initial value outside limits'; end if;
 if exists(select 1 from public.routine_field_conditions c
  join public.routine_fields f on f.id=c.source_field_id where c.model_version_id=p_version_id and (
   (c.boolean_value is not null and f.field_kind<>'boolean')
   or (c.source_option_id is not null and f.field_kind not in ('single_choice','multiple_choice')))) then
  raise check_violation using message='condition trigger does not match parent field type'; end if;
 with recursive walk(current,path,depth,cycle) as(
  select c.target_field_id,array[c.source_field_id,c.target_field_id],1,c.target_field_id=c.source_field_id
  from public.routine_field_conditions c where c.model_version_id=p_version_id
  union all
  select c.target_field_id,w.path||c.target_field_id,w.depth+1,c.target_field_id=any(w.path)
  from walk w join public.routine_field_conditions c on c.source_field_id=w.current
  where c.model_version_id=p_version_id and not w.cycle and w.depth<=4)
 select coalesce(bool_or(cycle),false),coalesce(max(depth),0) into has_cycle,max_depth from walk;
 if has_cycle then raise check_violation using message='conditional cycle'; end if;
 if max_depth>4 then raise check_violation using message='maximum conditional depth is 4'; end if;
end $$;

create or replace function app_private.validate_routine_application_hierarchy()
returns trigger language plpgsql security definer set search_path='' as $$
declare unit_institution uuid; group_unit uuid; group_institution uuid; parent_row public.routine_applications;
begin
 if new.unit_id is not null then select institution_id into unit_institution from public.units where id=new.unit_id; end if;
 if new.group_id is not null then select unit_id,institution_id into group_unit,group_institution from public.groups where id=new.group_id; end if;
 if unit_institution is distinct from new.institution_id or (new.group_id is not null and
  (group_unit is distinct from new.unit_id or group_institution is distinct from new.institution_id)) then
  raise check_violation using message='routine application hierarchy mismatch'; end if;
 if new.parent_application_id is not null then
  select * into parent_row from public.routine_applications where id=new.parent_application_id;
  if parent_row.id is null or parent_row.institution_id<>new.institution_id
   or (new.scope_kind='unit' and parent_row.scope_kind<>'institution')
   or (new.scope_kind='group' and parent_row.scope_kind not in ('institution','unit')) then
   raise check_violation using message='routine application hierarchy mismatch'; end if;
 end if; return new;
end $$;
create trigger routine_applications_validate before insert or update on public.routine_applications
for each row execute function app_private.validate_routine_application_hierarchy();

create or replace function app_private.validate_routine_assignee()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.routine_applications a where a.id=new.application_id and a.institution_id=new.institution_id)
  or not exists(select 1 from public.institution_memberships m where m.id=new.membership_id
   and m.institution_id=new.institution_id and m.status='active' and m.revoked_at is null) then
  raise check_violation using message='routine assignee hierarchy mismatch'; end if; return new;
end $$;
create trigger routine_application_assignees_validate before insert or update
on public.routine_application_assignees for each row execute function app_private.validate_routine_assignee();

create or replace function app_private.validate_routine_launch_hierarchy()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.units u where u.id=new.unit_id and u.institution_id=new.institution_id)
  or not exists(select 1 from public.groups g where g.id=new.group_id and g.unit_id=new.unit_id and g.institution_id=new.institution_id)
  or not exists(select 1 from public.institution_memberships m where m.id=new.author_membership_id
   and m.institution_id=new.institution_id and m.status='active' and m.revoked_at is null) then
  raise check_violation using message='routine launch hierarchy mismatch'; end if; return new;
end $$;
create trigger routine_launches_validate before insert or update on public.routine_launches
for each row execute function app_private.validate_routine_launch_hierarchy();

create or replace function app_private.validate_routine_child_entry()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.routine_launches l
  join public.child_group_links cgl on cgl.id=new.child_group_link_id
  join public.child_contexts cc on cc.id=new.child_context_id
  where l.id=new.launch_id and cgl.group_id=l.group_id and cgl.child_context_id=new.child_context_id
   and cc.institution_id=l.institution_id) then
  raise check_violation using message='routine child hierarchy mismatch'; end if; return new;
end $$;
create trigger routine_child_entries_validate before insert or update on public.routine_child_entries
for each row execute function app_private.validate_routine_child_entry();

create or replace function app_private.routine_definition_json(p_version_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object('version_id',v.id,'model_id',v.model_id,'version',v.version_no,
 'governance',v.governance_kind,'sections',coalesce((select jsonb_agg(jsonb_build_object(
  'id',s.id,'name',s.name,'order',s.sort_order,'fields',coalesce((select jsonb_agg(jsonb_build_object(
   'id',f.id,'label',f.label,'kind',f.field_kind,'required',f.is_required,'initial_value',f.initial_value,
   'min_value',f.min_value,'max_value',f.max_value,
   'order',f.sort_order,'options',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,
    'label',o.label,'value',o.value_code,'order',o.sort_order) order by o.sort_order)
    from public.routine_field_options o where o.field_id=f.id),'[]'::jsonb)) order by f.sort_order)
   from public.routine_fields f where f.section_id=s.id),'[]'::jsonb)) order by s.sort_order)
  from public.routine_sections s where s.model_version_id=v.id),'[]'::jsonb),
 'conditions',coalesce((select jsonb_agg(jsonb_build_object('source_field_id',c.source_field_id,
  'source_option_id',c.source_option_id,'boolean_value',c.boolean_value,'target_field_id',c.target_field_id))
  from public.routine_field_conditions c where c.model_version_id=v.id),'[]'::jsonb))
from public.routine_model_versions v where v.id=p_version_id
$$;

create or replace function app_private.routine_receipt(p_request uuid,p_actor uuid,p_command text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare response jsonb;
begin
 select response_json into response from app_private.routine_command_receipts
 where request_id=p_request and actor_person_id=p_actor and command_name=p_command;
 if response is null and exists(select 1 from app_private.routine_command_receipts where request_id=p_request) then
  raise unique_violation using message='routine command replay mismatch'; end if; return response;
end $$;

create or replace function app_private.superadmin_routine_directory(
 p_kind text,p_search text,p_status text,p_institution_id uuid,p_unit_id uuid,p_group_id uuid,
 p_limit integer,p_offset integer)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid; result jsonb;
begin
 actor:=app_private.require_routine_actor('routine.read',false);
 if p_kind not in ('model','application','launch') or p_limit not between 1 and 100 or p_offset<0 then
  raise invalid_parameter_value using message='invalid routine directory query'; end if;
 with entries as(
  select m.id,'model'::text kind,m.name,m.status,m.current_version::bigint version,
   m.institution_id,m.origin_unit_id unit_id,null::uuid group_id,m.origin_scope_kind origin_label,null::text effective_label
  from public.routine_models m
  union all
  select a.id,'application',m.name,a.status,a.management_version,a.institution_id,a.unit_id,a.group_id,
   'model v'||v.version_no::text,case a.inheritance_mode when 'inherited' then 'Herdada' else 'Personalizada' end
  from public.routine_applications a join public.routine_model_versions v on v.id=a.source_model_version_id
  join public.routine_models m on m.id=v.model_id
  union all
  select l.id,'launch',m.name||' - '||l.service_date::text,l.status,l.management_version,l.institution_id,l.unit_id,l.group_id,
   'application '||l.application_id::text,l.service_date::text
  from public.routine_launches l join public.routine_application_revisions ar on ar.id=l.application_revision_id
  join public.routine_model_versions v on v.id=ar.source_model_version_id join public.routine_models m on m.id=v.model_id
 ),filtered as(select * from entries e where e.kind=p_kind
  and (btrim(coalesce(p_search,''))='' or e.name ilike '%'||p_search||'%')
  and (p_status is null or e.status=p_status)
  and (p_institution_id is null or e.institution_id=p_institution_id)
  and (p_unit_id is null or e.unit_id=p_unit_id)
  and (p_group_id is null or e.group_id=p_group_id))
 select jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(page_row) order by lower(name),id),'[]'::jsonb),
  'total_count',(select count(*) from filtered)) into result
 from(select * from filtered order by lower(name),id limit p_limit offset p_offset) page_row; return result;
end $$;

create or replace function app_private.superadmin_routine_model_detail(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid; result jsonb;
begin actor:=app_private.require_routine_actor('routine.read',false);
 select to_jsonb(m)||jsonb_build_object('definition',app_private.routine_definition_json(v.id)) into result
 from public.routine_models m left join public.routine_model_versions v on v.model_id=m.id and v.version_no=m.current_version
 where m.id=p_id; return result; end $$;

create or replace function app_private.superadmin_routine_application_detail(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid; result jsonb;
begin actor:=app_private.require_routine_actor('routine.read',false);
 select to_jsonb(a)||jsonb_build_object('revision',to_jsonb(r),'assignees',coalesce((select jsonb_agg(to_jsonb(x))
  from public.routine_application_assignees x where x.application_id=a.id),'[]'::jsonb)) into result
 from public.routine_applications a left join lateral(select * from public.routine_application_revisions x
  where x.application_id=a.id order by x.revision_no desc limit 1) r on true where a.id=p_id; return result; end $$;

create or replace function app_private.superadmin_routine_launch_detail(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid; result jsonb;
begin actor:=app_private.require_routine_actor('routine.read',false);
 select to_jsonb(l)||jsonb_build_object('children',coalesce((select jsonb_agg(to_jsonb(e)||jsonb_build_object(
  'answers',coalesce((select jsonb_agg(to_jsonb(a)) from public.routine_answers a where a.child_entry_id=e.id),'[]'::jsonb)))
  from public.routine_child_entries e where e.launch_id=l.id),'[]'::jsonb)) into result
 from public.routine_launches l where l.id=p_id; return result; end $$;

create or replace function app_private.superadmin_routine_save_model(
 p_request_id uuid,p_model_id uuid,p_expected_version bigint,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; aggregate_id uuid:=coalesce(p_model_id,gen_random_uuid()); model_row public.routine_models;
 version_id uuid; next_version integer; response jsonb; section jsonb; field jsonb; option_row jsonb;
 condition_row jsonb; section_id uuid; field_id uuid;
begin
 actor:=app_private.require_routine_actor('routine.manage_models',false);
 perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text,0));
 response:=app_private.routine_receipt(p_request_id,actor,'save_model'); if response is not null then return response; end if;
 select * into model_row from public.routine_models where id=aggregate_id for update;
 if model_row.id is null then
  if p_expected_version<>0 then raise serialization_failure using message='expected_version mismatch'; end if;
  insert into public.routine_models(id,institution_id,origin_scope_kind,origin_unit_id,name,description,status,created_by_person_id)
  values(aggregate_id,(p_payload->>'institution_id')::uuid,coalesce(p_payload->>'origin_scope_kind','institution'),
   (p_payload->>'origin_unit_id')::uuid,btrim(p_payload->>'name'),coalesce(p_payload->>'description',''),
   coalesce(p_payload->>'status','draft'),actor) returning * into model_row;
 else
  if model_row.management_version<>p_expected_version then raise serialization_failure using message='expected_version mismatch'; end if;
  if model_row.is_system then raise insufficient_privilege using message='system routine model is immutable'; end if;
  update public.routine_models set name=btrim(p_payload->>'name'),description=coalesce(p_payload->>'description',''),
   status=coalesce(p_payload->>'status',status),management_version=management_version+1,updated_at=now()
  where id=aggregate_id returning * into model_row;
 end if;
 next_version:=model_row.current_version+1;
 insert into public.routine_model_versions(model_id,version_no,governance_kind,status,valid_from,valid_until,
  created_by_person_id,published_at) values(aggregate_id,next_version,coalesce(p_payload->>'governance_kind','optional'),
  case when p_payload->>'status'='active' then 'published' else 'draft' end,
  (p_payload->>'valid_from')::date,(p_payload->>'valid_until')::date,actor,
  case when p_payload->>'status'='active' then now() end) returning id into version_id;
 for section in select value from jsonb_array_elements(coalesce(p_payload->'sections','[]')) loop
  section_id:=coalesce((section->>'id')::uuid,gen_random_uuid());
  insert into public.routine_sections values(section_id,version_id,btrim(section->>'name'),coalesce((section->>'order')::integer,0),now());
  for field in select value from jsonb_array_elements(coalesce(section->'fields','[]')) loop
   field_id:=coalesce((field->>'id')::uuid,gen_random_uuid());
   insert into public.routine_fields(id,model_version_id,section_id,label,field_kind,is_required,initial_value,
    min_value,max_value,sort_order) values(field_id,version_id,section_id,btrim(field->>'label'),
    field->>'kind',coalesce((field->>'required')::boolean,false),field->'initial_value',(field->>'min_value')::numeric,
    (field->>'max_value')::numeric,coalesce((field->>'order')::integer,0));
   for option_row in select value from jsonb_array_elements(coalesce(field->'options','[]')) loop
    insert into public.routine_field_options values(coalesce((option_row->>'id')::uuid,gen_random_uuid()),version_id,
     field_id,btrim(option_row->>'label'),option_row->>'value',coalesce((option_row->>'order')::integer,0));
   end loop;
  end loop;
 end loop;
 for condition_row in select value from jsonb_array_elements(coalesce(p_payload->'conditions','[]')) loop
  insert into public.routine_field_conditions(model_version_id,source_field_id,source_option_id,boolean_value,target_field_id)
  values(version_id,(condition_row->>'source_field_id')::uuid,nullif(condition_row->>'source_option_id','')::uuid,
   (condition_row->>'boolean_value')::boolean,(condition_row->>'target_field_id')::uuid);
 end loop;
 perform app_private.validate_routine_definition(version_id);
 update public.routine_models set current_version=next_version where id=aggregate_id returning * into model_row;
 response:=jsonb_build_object('id',aggregate_id,'management_version',model_row.management_version,
  'model_version_id',version_id,'version',next_version);
 insert into app_private.routine_command_receipts values(p_request_id,actor,'save_model',aggregate_id,response,now());
 insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
 values(actor,auth.jwt()->>'aal','routine.model.save','routine_model',aggregate_id,model_row.institution_id,'success',response);
 return response;
end $$;

create or replace function app_private.superadmin_routine_save_application(
 p_request_id uuid,p_application_id uuid,p_expected_version bigint,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; aggregate_id uuid:=coalesce(p_application_id,gen_random_uuid()); app_row public.routine_applications;
 response jsonb; revision_id uuid; revision_no integer;
begin
 actor:=app_private.require_routine_actor('routine.manage_applications',false);
 perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text,0));
 response:=app_private.routine_receipt(p_request_id,actor,'save_application'); if response is not null then return response; end if;
 select * into app_row from public.routine_applications where id=aggregate_id for update;
 if app_row.id is null then
  if p_expected_version<>0 then raise serialization_failure using message='expected_version mismatch'; end if;
  insert into public.routine_applications(id,institution_id,unit_id,group_id,activity_id,scope_kind,
   source_model_version_id,parent_application_id,inheritance_mode,visibility,valid_from,valid_until,
   starts_at,ends_at,status,created_by_person_id) values(aggregate_id,(p_payload->>'institution_id')::uuid,
   (p_payload->>'unit_id')::uuid,(p_payload->>'group_id')::uuid,(p_payload->>'activity_id')::uuid,p_payload->>'scope_kind',
   (p_payload->>'source_model_version_id')::uuid,(p_payload->>'parent_application_id')::uuid,
   coalesce(p_payload->>'inheritance_mode','inherited'),coalesce(p_payload->>'visibility','authorized_guardians'),
   (p_payload->>'valid_from')::date,(p_payload->>'valid_until')::date,(p_payload->>'starts_at')::time,
   (p_payload->>'ends_at')::time,coalesce(p_payload->>'status','draft'),actor) returning * into app_row;
 else
  if app_row.management_version<>p_expected_version then raise serialization_failure using message='expected_version mismatch'; end if;
  update public.routine_applications set source_model_version_id=(p_payload->>'source_model_version_id')::uuid,
   parent_application_id=(p_payload->>'parent_application_id')::uuid,
   inheritance_mode=coalesce(p_payload->>'inheritance_mode',inheritance_mode),visibility=coalesce(p_payload->>'visibility',visibility),
   valid_from=(p_payload->>'valid_from')::date,valid_until=(p_payload->>'valid_until')::date,
   starts_at=(p_payload->>'starts_at')::time,ends_at=(p_payload->>'ends_at')::time,status=coalesce(p_payload->>'status',status),
   management_version=management_version+1,updated_at=now() where id=aggregate_id returning * into app_row;
 end if;
 select coalesce(max(revision_no),0)+1 into revision_no from public.routine_application_revisions where application_id=aggregate_id;
 insert into public.routine_application_revisions(application_id,revision_no,source_model_version_id,
  origin_application_id,effective_definition,created_by_person_id) values(aggregate_id,revision_no,app_row.source_model_version_id,
  coalesce(app_row.parent_application_id,aggregate_id),app_private.routine_definition_json(app_row.source_model_version_id),actor)
 returning id into revision_id;
 delete from public.routine_application_assignees where application_id=aggregate_id;
 insert into public.routine_application_assignees(application_id,institution_id,membership_id,responsibility)
 select aggregate_id,app_row.institution_id,(x->>'membership_id')::uuid,coalesce(x->>'responsibility','record')
 from jsonb_array_elements(coalesce(p_payload->'assignees','[]')) x;
 response:=jsonb_build_object('id',aggregate_id,'management_version',app_row.management_version,
  'revision_id',revision_id,'revision',revision_no);
 insert into app_private.routine_command_receipts values(p_request_id,actor,'save_application',aggregate_id,response,now());
 insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
 values(actor,auth.jwt()->>'aal','routine.application.save','routine_application',aggregate_id,app_row.institution_id,'success',response);
 return response;
end $$;

create or replace function app_private.superadmin_routine_revert_application(uuid,uuid,bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; app_row public.routine_applications; response jsonb;
begin actor:=app_private.require_routine_actor('routine.manage_applications',false);
 perform pg_advisory_xact_lock(hashtextextended($2::text,0));
 response:=app_private.routine_receipt($1,actor,'revert_application'); if response is not null then return response; end if;
 select * into app_row from public.routine_applications where id=$2 for update;
 if app_row.id is null then raise no_data_found; end if;
 if app_row.management_version<>$3 or app_row.parent_application_id is null then
  raise serialization_failure using message='expected_version mismatch'; end if;
 update public.routine_applications child set source_model_version_id=parent.source_model_version_id,
  inheritance_mode='inherited',management_version=child.management_version+1,updated_at=now()
 from public.routine_applications parent where child.id=$2 and parent.id=child.parent_application_id returning child.* into app_row;
 response:=jsonb_build_object('id',$2,'management_version',app_row.management_version,'inherited',true);
 insert into app_private.routine_command_receipts values($1,actor,'revert_application',$2,response,now()); return response;
end $$;

create or replace function app_private.superadmin_routine_save_launch_draft(uuid,uuid,bigint,jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; aggregate_id uuid:=coalesce($2,gen_random_uuid()); launch_row public.routine_launches;
 response jsonb; child_row jsonb; answer_row jsonb; entry_id uuid;
begin actor:=app_private.require_routine_actor('routine.record',false);
 perform pg_advisory_xact_lock(hashtextextended(aggregate_id::text,0));
 response:=app_private.routine_receipt($1,actor,'save_launch_draft'); if response is not null then return response; end if;
 select * into launch_row from public.routine_launches where id=aggregate_id for update;
 if launch_row.id is null then
  if $3<>0 then raise serialization_failure using message='expected_version mismatch'; end if;
  insert into public.routine_launches(id,institution_id,unit_id,group_id,activity_id,application_id,
   application_revision_id,service_date,author_membership_id) values(aggregate_id,($4->>'institution_id')::uuid,
   ($4->>'unit_id')::uuid,($4->>'group_id')::uuid,($4->>'activity_id')::uuid,($4->>'application_id')::uuid,
   ($4->>'application_revision_id')::uuid,($4->>'service_date')::date,($4->>'author_membership_id')::uuid)
   returning * into launch_row;
 else
  if launch_row.management_version<>$3 or launch_row.status<>'draft' then
   raise serialization_failure using message='expected_version mismatch'; end if;
  update public.routine_launches set management_version=management_version+1,updated_at=now()
   where id=aggregate_id returning * into launch_row;
 end if;
 for child_row in select value from jsonb_array_elements(coalesce($4->'children','[]')) loop
  entry_id:=coalesce((child_row->>'entry_id')::uuid,gen_random_uuid());
  insert into public.routine_child_entries(id,launch_id,child_context_id,child_group_link_id,status)
  values(entry_id,aggregate_id,(child_row->>'child_context_id')::uuid,(child_row->>'child_group_link_id')::uuid,
   coalesce(child_row->>'status','draft')) on conflict(launch_id,child_context_id)
  do update set status=excluded.status,updated_at=now() returning id into entry_id;
  for answer_row in select value from jsonb_array_elements(coalesce(child_row->'answers','[]')) loop
   insert into public.routine_answers(child_entry_id,field_id,value_json,answered_by_person_id)
   values(entry_id,(answer_row->>'field_id')::uuid,answer_row->'value',actor)
   on conflict(child_entry_id,field_id) do update set value_json=excluded.value_json,
    answered_by_person_id=excluded.answered_by_person_id,answered_at=now();
  end loop;
 end loop;
 response:=jsonb_build_object('id',aggregate_id,'management_version',launch_row.management_version,'status',launch_row.status);
 insert into app_private.routine_command_receipts values($1,actor,'save_launch_draft',aggregate_id,response,now()); return response;
end $$;

create or replace function app_private.superadmin_routine_publish_launch(uuid,uuid,bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; launch_row public.routine_launches; response jsonb;
begin actor:=app_private.require_routine_actor('routine.publish',true); -- routine.publish required; MFA AAL2 required
 perform pg_advisory_xact_lock(hashtextextended($2::text,0));
 response:=app_private.routine_receipt($1,actor,'publish_launch'); if response is not null then return response; end if;
 select * into launch_row from public.routine_launches where id=$2 for update;
 if launch_row.id is null then raise no_data_found; end if;
 if launch_row.management_version<>$3 or launch_row.status<>'draft' then raise serialization_failure using message='expected_version mismatch'; end if;
 if exists(select 1 from public.routine_child_entries e join public.routine_launches l on l.id=e.launch_id
  join public.routine_application_revisions ar on ar.id=l.application_revision_id
  join public.routine_fields f on f.model_version_id=ar.source_model_version_id and f.is_required
  where e.launch_id=$2 and not exists(select 1 from public.routine_answers a
   where a.child_entry_id=e.id and a.field_id=f.id and a.value_json is not null)) then
  raise check_violation using message='required routine answers missing'; end if;
 update public.routine_launches set status='published',published_at=now(),updated_at=now(),management_version=management_version+1
 where id=$2 returning * into launch_row;
 update public.routine_child_entries set status='published',updated_at=now() where launch_id=$2;
 response:=jsonb_build_object('id',$2,'management_version',launch_row.management_version,'status','published');
 insert into app_private.routine_command_receipts values($1,actor,'publish_launch',$2,response,now());
 insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
 values(actor,auth.jwt()->>'aal','routine.launch.publish','routine_launch',$2,launch_row.institution_id,'success',response); return response;
end $$;

create or replace function app_private.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; launch_row public.routine_launches; before_state jsonb; after_state jsonb;
 response jsonb; item jsonb; next_revision integer;
begin actor:=app_private.require_routine_actor('routine.correct',true); -- routine.correct required; MFA AAL2 required
 if btrim(coalesce($4,''))='' then raise check_violation using message='correction reason required'; end if;
 perform pg_advisory_xact_lock(hashtextextended($2::text,0));
 response:=app_private.routine_receipt($1,actor,'correct_launch'); if response is not null then return response; end if;
 select * into launch_row from public.routine_launches where id=$2 for update;
 if launch_row.id is null then raise no_data_found; end if;
 if launch_row.management_version<>$3 or launch_row.status not in ('published','corrected') then
  raise serialization_failure using message='expected_version mismatch'; end if;
 select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]') into before_state from public.routine_answers a
 join public.routine_child_entries e on e.id=a.child_entry_id where e.launch_id=$2;
 for item in select value from jsonb_array_elements(coalesce($5,'[]')) loop
  update public.routine_answers a set value_json=item->'value',answered_by_person_id=actor,answered_at=now()
  from public.routine_child_entries e where a.id=(item->>'answer_id')::uuid and e.id=a.child_entry_id and e.launch_id=$2;
 end loop;
 select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]') into after_state from public.routine_answers a
 join public.routine_child_entries e on e.id=a.child_entry_id where e.launch_id=$2;
 select coalesce(max(revision_no),0)+1 into next_revision from public.routine_launch_revisions where launch_id=$2;
 insert into public.routine_launch_revisions(launch_id,revision_no,reason,before_json,after_json,changed_by_person_id)
 values($2,next_revision,btrim($4),before_state,after_state,actor);
 update public.routine_launches set status='corrected',corrected_at=now(),updated_at=now(),management_version=management_version+1
 where id=$2 returning * into launch_row;
 response:=jsonb_build_object('id',$2,'management_version',launch_row.management_version,'status','corrected','revision',next_revision);
 insert into app_private.routine_command_receipts values($1,actor,'correct_launch',$2,response,now());
 insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,reason,before_json,after_json)
 values(actor,auth.jwt()->>'aal','routine.launch.correct','routine_launch',$2,launch_row.institution_id,'success',btrim($4),before_state,after_state);
 return response;
end $$;

create view public.daily_routine_effective_applications with(security_invoker=true) as
select a.*,r.id effective_revision_id,r.revision_no,r.effective_definition,
 coalesce(a.parent_application_id,a.id) origin_application_id,(a.inheritance_mode='inherited') inherited
from public.routine_applications a join lateral(select x.* from public.routine_application_revisions x
 where x.application_id=a.id order by x.revision_no desc limit 1) r on true;

create or replace function public.superadmin_routine_directory(p_kind text,p_search text,p_status text,p_institution_id uuid,p_unit_id uuid,p_group_id uuid,p_limit integer,p_offset integer)
returns jsonb language sql stable security definer set search_path='' as $$select app_private.superadmin_routine_directory(p_kind,p_search,p_status,p_institution_id,p_unit_id,p_group_id,p_limit,p_offset)$$;
create or replace function public.superadmin_routine_model_detail(p_model_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$select app_private.superadmin_routine_model_detail($1)$$;
create or replace function public.superadmin_routine_application_detail(p_application_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$select app_private.superadmin_routine_application_detail($1)$$;
create or replace function public.superadmin_routine_launch_detail(p_launch_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$select app_private.superadmin_routine_launch_detail($1)$$;
create or replace function public.superadmin_routine_save_model(p_request_id uuid,p_model_id uuid,p_expected_version bigint,p_payload jsonb)
returns jsonb language sql security definer set search_path='' as $$select app_private.superadmin_routine_save_model($1,$2,$3,$4)$$;
create or replace function public.superadmin_routine_save_application(p_request_id uuid,p_application_id uuid,p_expected_version bigint,p_payload jsonb)
returns jsonb language sql security definer set search_path='' as $$select app_private.superadmin_routine_save_application($1,$2,$3,$4)$$;
create or replace function public.superadmin_routine_revert_application(p_request_id uuid,p_application_id uuid,p_expected_version bigint)
returns jsonb language sql security definer set search_path='' as $$select app_private.superadmin_routine_revert_application($1,$2,$3)$$;
create or replace function public.superadmin_routine_save_launch_draft(p_request_id uuid,p_launch_id uuid,p_expected_version bigint,p_payload jsonb)
returns jsonb language sql security definer set search_path='' as $$select app_private.superadmin_routine_save_launch_draft($1,$2,$3,$4)$$;
create or replace function public.superadmin_routine_publish_launch(p_request_id uuid,p_launch_id uuid,p_expected_version bigint)
returns jsonb language sql security definer set search_path='' as $$select app_private.superadmin_routine_publish_launch($1,$2,$3)$$;
create or replace function public.superadmin_routine_correct_launch(p_request_id uuid,p_launch_id uuid,p_expected_version bigint,p_reason text,p_payload jsonb)
returns jsonb language sql security definer set search_path='' as $$select app_private.superadmin_routine_correct_launch($1,$2,$3,$4,$5)$$;

revoke all on public.daily_routine_effective_applications from public,anon,authenticated;
grant select on public.daily_routine_effective_applications to authenticated;

do $$ declare signature text; begin
 foreach signature in array array[
  'public.superadmin_routine_directory(text,text,text,uuid,uuid,uuid,integer,integer)',
  'public.superadmin_routine_model_detail(uuid)','public.superadmin_routine_application_detail(uuid)',
  'public.superadmin_routine_launch_detail(uuid)','public.superadmin_routine_save_model(uuid,uuid,bigint,jsonb)',
  'public.superadmin_routine_save_application(uuid,uuid,bigint,jsonb)','public.superadmin_routine_revert_application(uuid,uuid,bigint)',
  'public.superadmin_routine_save_launch_draft(uuid,uuid,bigint,jsonb)','public.superadmin_routine_publish_launch(uuid,uuid,bigint)',
  'public.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb)'] loop
  execute format('revoke all on function %s from public,anon,authenticated',signature);
  execute format('grant execute on function %s to authenticated',signature);
 end loop;
end $$;

revoke all on function app_private.require_routine_actor(text,boolean) from public,anon,authenticated;
revoke all on function app_private.validate_routine_definition(uuid) from public,anon,authenticated;
revoke all on function app_private.routine_definition_json(uuid) from public,anon,authenticated;
revoke all on function app_private.routine_receipt(uuid,uuid,text) from public,anon,authenticated;
revoke all on function app_private.superadmin_routine_directory(text,text,text,uuid,uuid,uuid,integer,integer) from public,anon,authenticated;
revoke all on function app_private.superadmin_routine_model_detail(uuid) from public,anon,authenticated;
revoke all on function app_private.superadmin_routine_application_detail(uuid) from public,anon,authenticated;
revoke all on function app_private.superadmin_routine_launch_detail(uuid) from public,anon,authenticated;
revoke all on function app_private.superadmin_routine_save_model(uuid,uuid,bigint,jsonb) from public,anon,authenticated;
revoke all on function app_private.superadmin_routine_save_application(uuid,uuid,bigint,jsonb) from public,anon,authenticated;
revoke all on function app_private.superadmin_routine_revert_application(uuid,uuid,bigint) from public,anon,authenticated;
revoke all on function app_private.superadmin_routine_save_launch_draft(uuid,uuid,bigint,jsonb) from public,anon,authenticated;
revoke all on function app_private.superadmin_routine_publish_launch(uuid,uuid,bigint) from public,anon,authenticated;
revoke all on function app_private.superadmin_routine_correct_launch(uuid,uuid,bigint,text,jsonb) from public,anon,authenticated;
