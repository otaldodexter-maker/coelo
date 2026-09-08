begin;

-- AG-READ01: nominal Auth039 READs only. No command, role grant or data rewrite.
-- Requires the reviewed base53, including audit14 from 20260831211945.
do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'agenda read migration requires postgres';
  end if;
  if to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or to_regprocedure('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid,jsonb)') is null
    or to_regprocedure('app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)') is null then
    raise exception using message = 'nominal agenda read foundation is missing';
  end if;
end
$preflight$;

create function app_private.agenda_read_v2_context_valid(
  p_institution_id uuid, p_kind text, p_context_id uuid
) returns boolean language sql stable security invoker set search_path = '' as $$
  select case p_kind
    when 'institution' then p_context_id = p_institution_id
    when 'unit' then exists(select 1 from public.units u
      where u.id = p_context_id and u.institution_id = p_institution_id)
    when 'group' then exists(select 1 from public.groups g join public.units u
      on u.id = g.unit_id and u.institution_id = g.institution_id
      where g.id = p_context_id and g.institution_id = p_institution_id)
    when 'activity' then exists(select 1 from public.activity_definitions a
      where a.id = p_context_id and a.institution_id = p_institution_id
        and (a.origin_unit_id is null or exists(select 1 from public.units u
          where u.id = a.origin_unit_id and u.institution_id = a.institution_id)))
    else false end
$$;

create function app_private.agenda_read_v2_item(
  p_event public.agenda_events, p_include_history boolean
) returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare
  result jsonb;
  recurrence jsonb;
  questions jsonb := '[]'::jsonb;
  reminders jsonb := '[]'::jsonb;
  member jsonb;
  key text;
  raw_array jsonb;
  projected jsonb;
  audience jsonb := jsonb_build_object('institutionId',p_event.institution_id,
    'individual_details_available',false);
begin
  -- Rebuild references from real same-institution relationships. Embedded IDs
  -- are selectors, never evidence of authorization. Personal audience is omitted.
  foreach key in array array['unitIds','groupIds','activityIds'] loop
    raw_array := coalesce(p_event.audience->key,'[]'::jsonb);
    if jsonb_typeof(raw_array) <> 'array' then
      raise exception using detail = 'SAI_INTERNAL_ERROR', message = 'invalid stored agenda shape';
    end if;
    if key = 'unitIds' then
      select coalesce(jsonb_agg(u.id order by u.id),'[]'::jsonb) into projected
      from public.units u where u.institution_id = p_event.institution_id
        and u.status = 'active' and raw_array ? u.id::text;
    elsif key = 'groupIds' then
      select coalesce(jsonb_agg(g.id order by g.id),'[]'::jsonb) into projected
      from public.groups g join public.units u
        on u.id = g.unit_id and u.institution_id = g.institution_id and u.status = 'active'
      where g.institution_id = p_event.institution_id and g.status = 'active'
        and raw_array ? g.id::text;
    else
      select coalesce(jsonb_agg(a.id order by a.id),'[]'::jsonb) into projected
      from public.activity_definitions a
      where a.institution_id = p_event.institution_id and a.status = 'active'
        and raw_array ? a.id::text
        and (a.origin_unit_id is null or exists(select 1 from public.units u
          where u.id = a.origin_unit_id and u.institution_id = a.institution_id
            and u.status = 'active'));
    end if;
    audience := audience || jsonb_build_object(key,projected);
  end loop;

  if p_event.recurrence is not null then
    if jsonb_typeof(p_event.recurrence->'frequency') is distinct from 'string'
      or p_event.recurrence->>'frequency' not in ('daily','weekly','monthly') then
      raise exception using detail = 'SAI_INTERNAL_ERROR', message = 'invalid stored agenda shape';
    end if;
    recurrence := jsonb_build_object('frequency',p_event.recurrence->'frequency');
    if p_event.recurrence ? 'interval' then
      if jsonb_typeof(p_event.recurrence->'interval') is distinct from 'number'
        or p_event.recurrence->>'interval' !~ '^[1-9][0-9]*$' then
        raise exception using detail = 'SAI_INTERNAL_ERROR', message = 'invalid stored agenda shape';
      end if;
      recurrence := recurrence || jsonb_build_object('interval',p_event.recurrence->'interval');
    end if;
    if (coalesce(p_event.recurrence->'until','null'::jsonb) = 'null'::jsonb)
      = (coalesce(p_event.recurrence->'occurrenceCount','null'::jsonb) = 'null'::jsonb) then
      raise exception using detail = 'SAI_INTERNAL_ERROR', message = 'invalid stored agenda shape';
    end if;
    if coalesce(p_event.recurrence->'until','null'::jsonb) <> 'null'::jsonb then
      if jsonb_typeof(p_event.recurrence->'until') <> 'string'
        or p_event.recurrence->>'until' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then
        raise exception using detail = 'SAI_INTERNAL_ERROR', message = 'invalid stored agenda shape';
      end if;
      recurrence := recurrence || jsonb_build_object('until',
        (p_event.recurrence->>'until')::timestamptz);
    else
      if jsonb_typeof(p_event.recurrence->'occurrenceCount') <> 'number'
        or p_event.recurrence->>'occurrenceCount' !~ '^[1-9][0-9]*$' then
        raise exception using detail = 'SAI_INTERNAL_ERROR', message = 'invalid stored agenda shape';
      end if;
      recurrence := recurrence || jsonb_build_object('occurrenceCount',p_event.recurrence->'occurrenceCount');
    end if;
    raw_array := coalesce(p_event.recurrence->'exceptions','[]'::jsonb);
    if jsonb_typeof(raw_array) <> 'array' then
      raise exception using detail = 'SAI_INTERNAL_ERROR', message = 'invalid stored agenda shape';
    end if;
    projected := '[]'::jsonb;
    for member in select value from jsonb_array_elements(raw_array) loop
      if jsonb_typeof(member) <> 'string' or member#>>'{}' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then
        raise exception using detail = 'SAI_INTERNAL_ERROR', message = 'invalid stored agenda shape';
      end if;
      projected := projected || jsonb_build_array((member#>>'{}')::timestamptz);
    end loop;
    recurrence := recurrence || jsonb_build_object('exceptions',projected);
  end if;

  for member in select value from jsonb_array_elements(p_event.questions) loop
    if jsonb_typeof(member) <> 'object'
      or jsonb_typeof(member->'id') is distinct from 'string'
      or coalesce(length(member->>'id'),0) = 0
      or jsonb_typeof(member->'title') is distinct from 'string'
      or coalesce(length(member->>'title'),0) not between 1 and 240
      or jsonb_typeof(member->'type') is distinct from 'string'
      or member->>'type' not in ('shortText','yesNo') then
      raise exception using detail = 'SAI_INTERNAL_ERROR', message = 'invalid stored agenda shape';
    end if;
    questions := questions || jsonb_build_array(jsonb_build_object(
      'id',member->'id','title',member->'title','type',member->'type'));
  end loop;
  for member in select value from jsonb_array_elements(p_event.reminders) loop
    if jsonb_typeof(member) <> 'string' then
      raise exception using detail = 'SAI_INTERNAL_ERROR', message = 'invalid stored agenda shape';
    end if;
    reminders := reminders || jsonb_build_array(member);
  end loop;
  result := jsonb_build_object(
    'id',p_event.id,'institution_id',p_event.institution_id,
    'context_kind',p_event.context_kind,'context_id',p_event.context_id,'title',p_event.title,
    'item_type',p_event.item_type,'priority',p_event.priority,'status',p_event.status,
    'origin',p_event.origin,'starts_at',p_event.starts_at,'ends_at',p_event.ends_at,
    'all_day',p_event.all_day,'time_zone_id',p_event.time_zone_id,'location',p_event.location,
    'description',p_event.description,'response_mode',p_event.response_mode,
    'guardian_response_policy',p_event.guardian_response_policy,
    'recurrence',recurrence,'audience',audience,'reminders',reminders,
    'questions',questions,'revision',p_event.revision);
  if p_include_history then
    select coalesce(jsonb_agg(jsonb_build_object('action',h.action,'occurred_at',h.occurred_at,
      'reason',h.reason,'previous_revision',h.previous_revision,'next_revision',h.next_revision)
      order by h.occurred_at,h.id),'[]'::jsonb) into projected
    from public.agenda_history_receipts h
    where h.event_id = p_event.id and h.institution_id = p_event.institution_id;
    result := result || jsonb_build_object('history',projected);
  end if;
  return result;
end $$;

create function app_private.agenda_read_v2_denied(
  p_action text, p_code text, p_correlation uuid, p_scope_institution uuid
) returns jsonb language plpgsql volatile security invoker set search_path = '' as $$
declare code text;
begin
  code := case when p_code in ('AGENDA_INVALID_ARGUMENT','AGENDA_NOT_FOUND',
    'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
    'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
    'SAI_MFA_REQUIRED','SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE')
    then p_code else 'SAI_INTERNAL_ERROR' end;
  -- Only a resolved institution scope may be supplied, never client filters.
  perform app_private.audit_superadmin_internal_denial_if_identified(
    'agenda.read',p_action,code,p_correlation,p_scope_institution);
  if code in ('AGENDA_INVALID_ARGUMENT','AGENDA_NOT_FOUND') then
    return jsonb_build_object('ok',false,'data',null,'error',jsonb_build_object(
      'code',code,'message',case when code = 'AGENDA_NOT_FOUND' then 'Item não encontrado.'
        else 'Parâmetros de Agenda inválidos.' end,
      'http_status',case when code = 'AGENDA_NOT_FOUND' then 404 else 400 end,
      'correlation_id',p_correlation));
  end if;
  return app_private.superadmin_internal_error_envelope(code,p_correlation);
end $$;

create function public.superadmin_agenda_list_v2(
  p_from timestamptz, p_to timestamptz, p_institution_id uuid default null,
  p_search text default '', p_limit integer default 100, p_offset integer default 0
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid := gen_random_uuid();
  result jsonb;
  code text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('agenda.read');
    if p_from is null or p_to is null or not isfinite(p_from) or not isfinite(p_to)
      or p_to <= p_from or p_to - p_from > interval '400 days'
      or p_limit is null or p_limit not between 1 and 200
      or p_offset is null or p_offset < 0 or length(coalesce(p_search,'')) > 120 then
      raise invalid_parameter_value using detail = 'AGENDA_INVALID_ARGUMENT';
    end if;
    with filtered as materialized (
      select e.* from public.agenda_events e
      where (ctx.scope_kind = 'platform' or
        (ctx.scope_kind = 'institution' and e.institution_id = ctx.scope_institution_id))
        and (p_institution_id is null or e.institution_id = p_institution_id)
        and e.starts_at < p_to and e.ends_at > p_from
        and (coalesce(btrim(p_search),'') = ''
          or strpos(lower(e.title),lower(btrim(p_search))) > 0
          or strpos(lower(e.description),lower(btrim(p_search))) > 0)
        and app_private.agenda_read_v2_context_valid(e.institution_id,e.context_kind,e.context_id)
    ), page as (
      select f.* from filtered f order by f.starts_at,f.id limit p_limit offset p_offset
    )
    select jsonb_build_object('items',coalesce(jsonb_agg(
      app_private.agenda_read_v2_item(p::public.agenda_events,false) order by p.starts_at,p.id),'[]'::jsonb),
      'total_items',(select count(*) from filtered),'limit',p_limit,'offset',p_offset)
    into result from page p;
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code,''),'SAI_INTERNAL_ERROR');
  end;
  if code is not null then
    return app_private.agenda_read_v2_denied('agenda.list',code,correlation,
      case when ctx.scope_kind = 'institution' then ctx.scope_institution_id else null end);
  end if;
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'agenda.read',ctx.aal,'agenda.list','success'::public.audit_outcome,null::text,correlation,
    case when ctx.scope_kind = 'institution' then ctx.scope_institution_id else null::uuid end,
    null::text,null::uuid,jsonb_build_object('row_count',jsonb_array_length(result->'items')));
  return jsonb_build_object('ok',true,'data',result || jsonb_build_object('correlation_id',correlation),'error',null);
end $$;

create function public.superadmin_agenda_get_v2(p_event_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid := gen_random_uuid();
  event_record public.agenda_events;
  result jsonb;
  code text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('agenda.read');
    if p_event_id is null then
      raise invalid_parameter_value using detail = 'AGENDA_INVALID_ARGUMENT';
    end if;
    select e.* into event_record from public.agenda_events e
    where e.id = p_event_id and (ctx.scope_kind = 'platform' or
      (ctx.scope_kind = 'institution' and e.institution_id = ctx.scope_institution_id))
      and app_private.agenda_read_v2_context_valid(e.institution_id,e.context_kind,e.context_id);
    if not found then
      raise no_data_found using detail = 'AGENDA_NOT_FOUND';
    end if;
    result := jsonb_build_object('item',app_private.agenda_read_v2_item(event_record,true));
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code,''),'SAI_INTERNAL_ERROR');
  end;
  if code is not null then
    return app_private.agenda_read_v2_denied('agenda.get',code,correlation,
      case when ctx.scope_kind = 'institution' then ctx.scope_institution_id else null end);
  end if;
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'agenda.read',ctx.aal,'agenda.get','success'::public.audit_outcome,null::text,correlation,
    case when ctx.scope_kind = 'institution' then ctx.scope_institution_id else null::uuid end,
    null::text,null::uuid,jsonb_build_object('row_count',1));
  return jsonb_build_object('ok',true,'data',result || jsonb_build_object('correlation_id',correlation),'error',null);
end $$;

create function public.superadmin_agenda_contexts_v2()
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid := gen_random_uuid();
  result jsonb;
  granted jsonb;
  restricted jsonb;
  code text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('agenda.read');
    with capabilities as (
      select c.ordinal,c.name,exists(select 1 from public.platform_permissions p
        join public.platform_role_permissions rp on rp.permission_id = p.id
        where p.code = c.permission_code and p.status = 'active'
          and rp.role_id = ctx.platform_role_id and rp.status = 'active'
          and rp.revoked_at is null and rp.effect = 'allow') as allowed
      from (values
        (1,'createAgendaItems','agenda.create'),(2,'editOwnAgendaItems','agenda.edit_own'),
        (3,'editAllAgendaItems','agenda.edit_all'),(4,'publishAgendaItems','agenda.publish'),
        (5,'cancelOrRestoreAgendaItems','agenda.cancel_restore'),
        (6,'manageResponsesAndAuthorizations','agenda.manage_responses'),
        (7,'overrideReservationConflict','agenda.override_reservation')
      ) c(ordinal,name,permission_code)
    )
    select coalesce(jsonb_agg(name order by ordinal) filter(where allowed),'[]'::jsonb),
      coalesce(jsonb_agg(name order by ordinal) filter(where not allowed),'[]'::jsonb)
      into granted,restricted from capabilities;
    with institutions as (
      select i.id,i.public_name from public.institutions i
      where i.status = 'active' and i.deleted_at is null
        and (ctx.scope_kind = 'platform' or
          (ctx.scope_kind = 'institution' and i.id = ctx.scope_institution_id))
    ), units as (
      select u.id,u.name,u.institution_id from public.units u
      join institutions i on i.id = u.institution_id where u.status = 'active'
    ), context_rows as (
      select i.id,i.public_name as name,i.id as institution_id,null::uuid as parent_id,
        'institution'::text as level,1 as ordinal from institutions i
      union all
      select u.id,u.name,u.institution_id,u.institution_id,'unit',2 from units u
      union all
      select g.id,g.name,g.institution_id,g.unit_id,'group',3 from public.groups g
      join units u on u.id = g.unit_id and u.institution_id = g.institution_id
      where g.status = 'active'
      union all
      select a.id,a.name,a.institution_id,coalesce(a.origin_unit_id,a.institution_id),'activity',4
      from public.activity_definitions a join institutions i on i.id = a.institution_id
      where a.status = 'active' and (a.origin_unit_id is null or exists(select 1 from units u
        where u.id = a.origin_unit_id and u.institution_id = a.institution_id))
    )
    select jsonb_build_object('contexts',coalesce(jsonb_agg(jsonb_build_object(
      'id',c.id,'name',c.name,'institution_id',c.institution_id,'parent_id',c.parent_id,
      'level',c.level,'granted_capabilities',granted,'restricted_capabilities',restricted)
      order by c.institution_id,c.ordinal,lower(c.name),c.id),'[]'::jsonb),
      'mutation_actions_available',false) into result from context_rows c;
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code,''),'SAI_INTERNAL_ERROR');
  end;
  if code is not null then
    return app_private.agenda_read_v2_denied('agenda.contexts',code,correlation,
      case when ctx.scope_kind = 'institution' then ctx.scope_institution_id else null end);
  end if;
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'agenda.read',ctx.aal,'agenda.contexts','success'::public.audit_outcome,null::text,correlation,
    case when ctx.scope_kind = 'institution' then ctx.scope_institution_id else null::uuid end,
    null::text,null::uuid,jsonb_build_object('row_count',jsonb_array_length(result->'contexts')));
  return jsonb_build_object('ok',true,'data',result || jsonb_build_object('correlation_id',correlation),'error',null);
end $$;

alter function app_private.agenda_read_v2_context_valid(uuid,text,uuid) owner to postgres;
alter function app_private.agenda_read_v2_item(public.agenda_events,boolean) owner to postgres;
alter function app_private.agenda_read_v2_denied(text,text,uuid,uuid) owner to postgres;
alter function public.superadmin_agenda_list_v2(timestamptz,timestamptz,uuid,text,integer,integer) owner to postgres;
alter function public.superadmin_agenda_get_v2(uuid) owner to postgres;
alter function public.superadmin_agenda_contexts_v2() owner to postgres;
revoke all on function app_private.agenda_read_v2_context_valid(uuid,text,uuid),
  app_private.agenda_read_v2_item(public.agenda_events,boolean),
  app_private.agenda_read_v2_denied(text,text,uuid,uuid),
  public.superadmin_agenda_list_v2(timestamptz,timestamptz,uuid,text,integer,integer),
  public.superadmin_agenda_get_v2(uuid), public.superadmin_agenda_contexts_v2()
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_agenda_list_v2(timestamptz,timestamptz,uuid,text,integer,integer),
  public.superadmin_agenda_get_v2(uuid), public.superadmin_agenda_contexts_v2() to authenticated;

commit;
