-- Authorized child-safety read models. Filtering and aggregation stay server-side.

create or replace function app_private.assert_child_safety_platform(p_permission text)
returns uuid language plpgsql stable security definer set search_path=''
as $$ declare actor uuid:=app_private.current_person_id(); begin
  if actor is null or p_permission not in ('child_safety.read','child_safety.manage','child_safety.export')
     or not app_private.has_platform_permission(p_permission) then
    raise insufficient_privilege using message='child safety capability required';
  end if;
  if not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message='MFA AAL2 required';
  end if;
  return actor;
end $$;
revoke all on function app_private.assert_child_safety_platform(text) from public,anon,authenticated;

create or replace function app_private.superadmin_child_safety_directory(
  p_search text,p_institution_ids uuid[],p_unit_ids uuid[],p_segment text,
  p_limit integer,p_offset integer
) returns jsonb language plpgsql stable security definer set search_path=''
as $$ declare result jsonb; begin
  perform app_private.assert_child_safety_platform('child_safety.read');
  if char_length(coalesce(p_search,''))>120 or p_segment not in ('all','pending','approved','rejected','inactive')
     or p_limit not in (8,20,50,100) or p_offset<0 then
    raise invalid_parameter_value using message='invalid child safety directory filters';
  end if;
  if exists (
    select 1 from public.units unit_record
    where unit_record.id=any(coalesce(p_unit_ids,'{}'::uuid[]))
      and cardinality(coalesce(p_institution_ids,'{}'::uuid[]))>0
      and not unit_record.institution_id=any(p_institution_ids)
  ) then raise invalid_parameter_value using message='invalid child safety hierarchy'; end if;

  with scoped as (
    select child_context.id child_context_id,child.id child_id,child.display_name child_name,
      coalesce(child_context.local_identifier,'') internal_id,
      institution.id institution_id,institution.public_name institution_name,
      unit_record.id unit_id,unit_record.name unit_name,
      count(authorization.id) authorization_count,
      count(*) filter(where authorization.decision_status='pending' and authorization.status='active') pending_count,
      count(*) filter(where authorization.decision_status='approved' and authorization.status='active') approved_count,
      count(*) filter(where authorization.decision_status='rejected') rejected_count,
      count(*) filter(where authorization.status<>'active') inactive_count,
      max(authorization.updated_at) last_safety_change
    from public.child_contexts child_context
    join public.people child on child.id=child_context.child_person_id and child.person_type='child'
    join public.institutions institution on institution.id=child_context.institution_id
    join public.child_unit_links child_unit on child_unit.child_context_id=child_context.id
      and child_unit.status in ('active','awaiting_allocation')
    join public.units unit_record on unit_record.id=child_unit.unit_id
    left join public.authorized_person_authorizations authorization
      on authorization.child_context_id=child_context.id and authorization.unit_id=unit_record.id
    where child_context.status='active'
      and (cardinality(coalesce(p_institution_ids,'{}'::uuid[]))=0 or institution.id=any(p_institution_ids))
      and (cardinality(coalesce(p_unit_ids,'{}'::uuid[]))=0 or unit_record.id=any(p_unit_ids))
      and (nullif(btrim(p_search),'') is null or lower(child.display_name) like '%'||lower(btrim(p_search))||'%'
        or lower(coalesce(child_context.local_identifier,'')) like '%'||lower(btrim(p_search))||'%')
    group by child_context.id,child.id,child.display_name,child_context.local_identifier,
      institution.id,institution.public_name,unit_record.id,unit_record.name
  ), filtered as (
    select * from scoped where p_segment='all'
      or (p_segment='pending' and pending_count>0)
      or (p_segment='approved' and approved_count>0)
      or (p_segment='rejected' and rejected_count>0)
      or (p_segment='inactive' and inactive_count>0)
  ), page_rows as (
    select * from filtered order by child_name,child_context_id limit p_limit offset p_offset
  )
  select jsonb_build_object(
    'items',coalesce((select jsonb_agg(jsonb_build_object(
      'child_id',child_id,'child_context_id',child_context_id,'child_name',child_name,
      'internal_id',internal_id,'institution_id',institution_id,'institution_name',institution_name,
      'unit_id',unit_id,'unit_name',unit_name,'authorization_count',authorization_count,
      'pending_count',pending_count,'approved_count',approved_count,'rejected_count',rejected_count,
      'inactive_count',inactive_count,'last_safety_change',last_safety_change
    ) order by child_name,child_context_id) from page_rows),'[]'::jsonb),
    'total_count',(select count(*) from filtered),
    'segment_counts',jsonb_build_object(
      'all',(select count(*) from scoped),'pending',(select count(*) from scoped where pending_count>0),
      'approved',(select count(*) from scoped where approved_count>0),
      'rejected',(select count(*) from scoped where rejected_count>0),
      'inactive',(select count(*) from scoped where inactive_count>0)),
    'can_create',app_private.has_platform_permission('child_safety.manage')
  ) into result;
  return result;
end $$;

create or replace function public.superadmin_child_safety_directory(
  p_search text default '',p_institution_ids uuid[] default '{}',p_unit_ids uuid[] default '{}',
  p_segment text default 'all',p_limit integer default 8,p_offset integer default 0
) returns jsonb language sql stable security invoker set search_path=''
as $$ select app_private.superadmin_child_safety_directory($1,$2,$3,$4,$5,$6) $$;

create or replace function app_private.superadmin_child_safety_search_children(p_search text,p_limit integer)
returns jsonb language plpgsql stable security definer set search_path=''
as $$ begin
  perform app_private.assert_child_safety_platform('child_safety.read');
  if char_length(btrim(coalesce(p_search,'')))<2 or char_length(p_search)>120 or p_limit not between 1 and 20 then
    raise invalid_parameter_value using message='invalid child search';
  end if;
  return coalesce((
    select jsonb_agg(item order by item->>'display_name') from (
      select jsonb_build_object(
        'id',child.id,'display_name',child.display_name,'internal_id',coalesce(child_context.local_identifier,''),
        'contexts',jsonb_agg(jsonb_build_object(
          'child_context_id',child_context.id,'institution_id',institution.id,
          'institution_name',institution.public_name,'unit_id',unit_record.id,'unit_name',unit_record.name
        ) order by institution.public_name,unit_record.name)
      ) item
      from public.people child
      join public.child_contexts child_context on child_context.child_person_id=child.id and child_context.status='active'
      join public.institutions institution on institution.id=child_context.institution_id
      join public.child_unit_links child_unit on child_unit.child_context_id=child_context.id
        and child_unit.status in ('active','awaiting_allocation')
      join public.units unit_record on unit_record.id=child_unit.unit_id
      where child.person_type='child' and child.status='active'
        and (lower(child.display_name) like '%'||lower(btrim(p_search))||'%'
          or lower(coalesce(child_context.local_identifier,'')) like '%'||lower(btrim(p_search))||'%')
      group by child.id,child.display_name,child_context.local_identifier
      order by child.display_name,child.id limit p_limit
    ) rows
  ),'[]'::jsonb);
end $$;
create or replace function public.superadmin_child_safety_search_children(p_search text,p_limit integer default 12)
returns jsonb language sql stable security invoker set search_path=''
as $$ select app_private.superadmin_child_safety_search_children($1,$2) $$;

create or replace function app_private.superadmin_child_safety_get(p_child_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$ declare result jsonb; begin
  perform app_private.assert_child_safety_platform('child_safety.read');
  select jsonb_build_object(
    'child_id',child.id,'child_name',child.display_name,
    'contexts',coalesce((select jsonb_agg(jsonb_build_object(
      'child_context_id',context_record.id,'internal_id',coalesce(context_record.local_identifier,''),
      'institution_id',institution.id,'institution_name',institution.public_name,
      'unit_id',unit_record.id,'unit_name',unit_record.name
    ) order by institution.public_name,unit_record.name)
    from public.child_contexts context_record
    join public.institutions institution on institution.id=context_record.institution_id
    join public.child_unit_links child_unit on child_unit.child_context_id=context_record.id
      and child_unit.status in ('active','awaiting_allocation')
    join public.units unit_record on unit_record.id=child_unit.unit_id
    where context_record.child_person_id=child.id and context_record.status='active'),'[]'::jsonb),
    'authorizations',coalesce((select jsonb_agg(jsonb_build_object(
      'id',authorization.id,'child_context_id',authorization.child_context_id,'unit_id',authorization.unit_id,
      'person_id',authorized_person.person_id,'name',authorized_person.display_name,
      'relationship_code',relationship.code,'relationship_detail',authorization.relationship_detail,
      'capability_codes',(select coalesce(jsonb_agg(capability.capability_code order by capability.capability_code),'[]'::jsonb)
        from public.authorized_person_authorization_capabilities capability where capability.authorization_id=authorization.id),
      'decision_status',authorization.decision_status,'lifecycle_status',authorization.status,
      'valid_from',authorization.valid_from,'valid_until',authorization.valid_until,'version',authorization.version,
      'request_reason',authorization.request_reason,'decision_reason',authorization.decision_reason
    ) order by authorization.created_at desc)
    from public.authorized_person_authorizations authorization
    join public.authorized_people authorized_person on authorized_person.id=authorization.authorized_person_id
    join public.family_relationship_types relationship on relationship.id=authorization.relationship_type_id
    join public.child_contexts context_record on context_record.id=authorization.child_context_id
    where context_record.child_person_id=child.id),'[]'::jsonb),
    'restrictions',coalesce((select jsonb_agg(to_jsonb(restriction)-'created_by_person_id'-'updated_by_person_id')
      from public.child_safety_restrictions restriction
      join public.child_contexts context_record on context_record.id=restriction.child_context_id
      where context_record.child_person_id=child.id),'[]'::jsonb),
    'alerts',coalesce((select jsonb_agg(to_jsonb(alert_record)-'acknowledged_by_person_id')
      from public.child_safety_alerts alert_record
      join public.child_contexts context_record on context_record.id=alert_record.child_context_id
      where context_record.child_person_id=child.id),'[]'::jsonb)
  ) into result from public.people child where child.id=p_child_id and child.person_type='child';
  if result is null then raise no_data_found using message='child safety record not found'; end if;
  return result;
end $$;
create or replace function public.superadmin_child_safety_get(p_child_id uuid)
returns jsonb language sql stable security invoker set search_path=''
as $$ select app_private.superadmin_child_safety_get($1) $$;

-- Compatibility aliases kept narrow while callers converge on the canonical names above.
create or replace function public.superadmin_child_safety_child_search(p_search text,p_limit integer)
returns jsonb language sql stable security invoker set search_path=''
as $$ select app_private.superadmin_child_safety_search_children($1,$2) $$;
create or replace function public.superadmin_child_safety_detail(p_child_id uuid)
returns jsonb language sql stable security invoker set search_path=''
as $$ select app_private.superadmin_child_safety_get($1) $$;
create or replace function public.superadmin_child_safety_directory(
  p_search text,p_decision_statuses text[],p_lifecycle_statuses text[],p_institution_ids uuid[],
  p_unit_ids uuid[],p_before_created_at timestamptz,p_before_child_context_id uuid,p_limit integer
) returns jsonb language sql stable security invoker set search_path=''
as $$ select app_private.superadmin_child_safety_directory(
  $1,$4,$5,case when cardinality($2)=1 then $2[1]
    when cardinality($3)>0 then 'inactive' else 'all' end,$8,0) $$;

revoke all on function app_private.superadmin_child_safety_directory(text,uuid[],uuid[],text,integer,integer)
  from public,anon,authenticated;
revoke all on function app_private.superadmin_child_safety_search_children(text,integer)
  from public,anon,authenticated;
revoke all on function app_private.superadmin_child_safety_get(uuid) from public,anon,authenticated;

revoke all on function public.superadmin_child_safety_directory(text,uuid[],uuid[],text,integer,integer)
  from public,anon;
grant execute on function public.superadmin_child_safety_directory(text,uuid[],uuid[],text,integer,integer)
  to authenticated;
revoke all on function public.superadmin_child_safety_search_children(text,integer) from public,anon;
grant execute on function public.superadmin_child_safety_search_children(text,integer) to authenticated;
revoke all on function public.superadmin_child_safety_get(uuid) from public,anon;
grant execute on function public.superadmin_child_safety_get(uuid) to authenticated;
revoke all on function public.superadmin_child_safety_child_search(text,integer) from public,anon;
grant execute on function public.superadmin_child_safety_child_search(text,integer) to authenticated;
revoke all on function public.superadmin_child_safety_detail(uuid) from public,anon;
grant execute on function public.superadmin_child_safety_detail(uuid) to authenticated;
revoke all on function public.superadmin_child_safety_directory(text,text[],text[],uuid[],uuid[],timestamptz,uuid,integer)
  from public,anon;
grant execute on function public.superadmin_child_safety_directory(text,text[],text[],uuid[],uuid[],timestamptz,uuid,integer)
  to authenticated;
