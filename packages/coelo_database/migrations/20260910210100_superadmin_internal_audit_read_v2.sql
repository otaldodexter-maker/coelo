-- AUDIT-READ-V2. Cut audit readers to the internal Superadmin identity realm.
-- General exports remain deferred; historical jobs and service workers are preserved.
begin;

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message='AUDIT-READ-V2 must be applied as postgres';
  end if;
  if pg_catalog.to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or pg_catalog.to_regtype('app_private.superadmin_internal_context') is null
    or pg_catalog.to_regprocedure(
      'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)'
    ) is null
    or pg_catalog.to_regprocedure(
      'app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)'
    ) is null
    or pg_catalog.to_regprocedure(
      'public.audit_list_events_for_superadmin(text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer)'
    ) is null
    or pg_catalog.to_regprocedure('public.audit_get_event_for_superadmin(uuid)') is null
    or pg_catalog.to_regclass('audit.audit_logs') is null then
    raise object_not_in_prerequisite_state using
      message='AUDIT-READ-V2 requires the nominal internal Auth and audit foundations';
  end if;
  if not exists(
    select 1 from public.platform_permissions permission_record
    where permission_record.code='audit.read' and permission_record.status='active'
  ) then
    raise object_not_in_prerequisite_state using
      message='AUDIT-READ-V2 requires the active audit.read capability';
  end if;
end
$preflight$;

create function app_private.audit_internal_error_envelope_v2(
  p_code text,p_correlation_id uuid
) returns jsonb
language sql
immutable
security invoker
set search_path=''
as $function$
  select pg_catalog.jsonb_build_object('ok',false,'data',null,'error',
    pg_catalog.jsonb_build_object(
      'code',case when p_code in(
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
        'SAI_MFA_REQUIRED','SAI_INVALID_ARGUMENT') then p_code else 'SAI_INTERNAL_ERROR' end,
      'message',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 'Autenticação necessária.'
        when p_code='SAI_INVALID_ARGUMENT' then 'Revise os dados enviados.'
        when p_code='SAI_MFA_REQUIRED' then 'Confirme o segundo fator.'
        when p_code like 'SAI_%DENIED' or p_code like 'SAI_MEMBERSHIP_%'
          then 'Acesso não autorizado.'
        else 'Não foi possível concluir a operação.' end,
      'correlation_id',p_correlation_id,
      'http_status',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when p_code='SAI_INVALID_ARGUMENT' then 400
        when p_code in('SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then 403
        else 500 end))
$function$;

create function app_private.audit_validate_internal_list_filters_v2(
  p_search text,p_actor_ids uuid[],p_context_kinds text[],p_action_codes text[],
  p_resource_types text[],p_outcomes text[],p_origins text[],p_from timestamptz,
  p_to timestamptz,p_cursor_occurred_at timestamptz,p_cursor_id uuid,p_limit integer
) returns void
language plpgsql
immutable
security invoker
set search_path=''
as $function$
begin
  if p_limit is null or p_limit not between 1 and 100
    or pg_catalog.char_length(coalesce(p_search,''))>200
    or coalesce(p_search,'')~'[[:cntrl:]]'
    or (p_from is not null and not pg_catalog.isfinite(p_from))
    or (p_to is not null and not pg_catalog.isfinite(p_to))
    or (p_from is not null and p_to is not null and p_from>p_to)
    or ((p_cursor_occurred_at is null)<>(p_cursor_id is null))
    or (p_cursor_occurred_at is not null and not pg_catalog.isfinite(p_cursor_occurred_at))
    or coalesce(pg_catalog.cardinality(p_actor_ids),0)>50
    or coalesce(pg_catalog.cardinality(p_context_kinds),0)>10
    or coalesce(pg_catalog.cardinality(p_action_codes),0)>20
    or coalesce(pg_catalog.cardinality(p_resource_types),0)>20
    or coalesce(pg_catalog.cardinality(p_outcomes),0)>10
    or coalesce(pg_catalog.cardinality(p_origins),0)>10
    or exists(select 1 from pg_catalog.unnest(coalesce(p_actor_ids,'{}'::uuid[])) item
      where item is null)
    or exists(select 1 from pg_catalog.unnest(coalesce(p_context_kinds,'{}'::text[])) item
      where item is null or item not in('global','institution','unit','group','activity','child'))
    or exists(select 1 from pg_catalog.unnest(coalesce(p_action_codes,'{}'::text[])) item
      where item is null or item!~'^[a-z0-9][a-z0-9._-]{0,119}$')
    or exists(select 1 from pg_catalog.unnest(coalesce(p_resource_types,'{}'::text[])) item
      where item is null or item!~'^[a-z0-9][a-z0-9._-]{0,119}$')
    or exists(select 1 from pg_catalog.unnest(coalesce(p_outcomes,'{}'::text[])) item
      where item is null or item not in('success','failure','denied'))
    or exists(select 1 from pg_catalog.unnest(coalesce(p_origins,'{}'::text[])) item
      where item is null or item not in('database','edge_function','system','admin_ui','import')) then
    raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
  end if;
end
$function$;

create or replace function app_private.audit_list_events_for_superadmin(
  p_search text default null,p_actor_ids uuid[] default null,p_context_kinds text[] default null,
  p_action_codes text[] default null,p_resource_types text[] default null,
  p_outcomes text[] default null,p_origins text[] default null,p_institution_id uuid default null,
  p_from timestamptz default null,p_to timestamptz default null,
  p_cursor_occurred_at timestamptz default null,p_cursor_id uuid default null,p_limit integer default 25
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $function$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid:=pg_catalog.gen_random_uuid();
  error_code text;
  result jsonb;
  audit_institution_id uuid;
begin
  begin
    select * into strict ctx
    from app_private.require_superadmin_internal_context('audit.read');
    if ctx.scope_kind is null or ctx.scope_kind not in('platform','institution')
      or (ctx.scope_kind='platform' and ctx.scope_institution_id is not null)
      or (ctx.scope_kind='institution' and ctx.scope_institution_id is null)
      or ctx.aal is null or ctx.aal not in('aal1','aal2') then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    perform app_private.audit_validate_internal_list_filters_v2(
      p_search,p_actor_ids,p_context_kinds,p_action_codes,p_resource_types,p_outcomes,
      p_origins,p_from,p_to,p_cursor_occurred_at,p_cursor_id,p_limit);

    if p_cursor_id is not null and not exists(
      select 1
      from audit.audit_logs cursor_record
      left join public.people cursor_person on cursor_person.id=cursor_record.actor_person_id
      left join public.institutions cursor_institution on cursor_institution.id=cursor_record.institution_id
      where cursor_record.id=p_cursor_id
        and cursor_record.occurred_at=p_cursor_occurred_at
        and (ctx.scope_kind='platform' or cursor_record.institution_id=ctx.scope_institution_id)
        and (p_institution_id is null or cursor_record.institution_id=p_institution_id)
        and (p_actor_ids is null or pg_catalog.cardinality(p_actor_ids)=0
          or coalesce(cursor_record.actor_internal_identity_id,
            cursor_record.actor_person_id)=any(p_actor_ids))
        and (p_context_kinds is null or pg_catalog.cardinality(p_context_kinds)=0
          or cursor_record.context_kind=any(p_context_kinds))
        and (p_action_codes is null or pg_catalog.cardinality(p_action_codes)=0
          or cursor_record.action_code=any(p_action_codes))
        and (p_resource_types is null or pg_catalog.cardinality(p_resource_types)=0
          or cursor_record.object_type=any(p_resource_types))
        and (p_outcomes is null or pg_catalog.cardinality(p_outcomes)=0 or
          case cursor_record.outcome::text when 'failed' then 'failure'
            else cursor_record.outcome::text end=any(p_outcomes))
        and (p_origins is null or pg_catalog.cardinality(p_origins)=0
          or cursor_record.origin=any(p_origins))
        and (p_from is null or cursor_record.occurred_at>=p_from)
        and (p_to is null or cursor_record.occurred_at<=p_to)
        and (nullif(pg_catalog.btrim(p_search),'') is null
          or pg_catalog.strpos(pg_catalog.lower(pg_catalog.concat_ws(' ',
            cursor_record.action_code,cursor_record.object_type,cursor_record.object_id::text,
            cursor_record.correlation_id::text,
            case when cursor_record.actor_kind='superadmin_internal' then 'Usuário interno'
              when cursor_record.actor_kind='auth_session' then 'Sessão autenticada'
              else cursor_person.display_name end,cursor_institution.public_name)),
            pg_catalog.lower(pg_catalog.btrim(p_search)))>0)
    ) then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;

    with filtered as materialized(
      select log_record.*,person.display_name,institution.public_name institution_name,
        coalesce(log_record.actor_internal_identity_id,
          log_record.actor_person_id) effective_actor_id,
        case when log_record.actor_kind='superadmin_internal' then 'Usuário interno'
          when log_record.actor_kind='auth_session' then 'Sessão autenticada'
          when log_record.actor_person_id is null then 'Sistema'
          else coalesce(person.display_name,'Ator não disponível') end effective_actor_name
      from audit.audit_logs log_record
      left join public.people person on person.id=log_record.actor_person_id
      left join public.institutions institution on institution.id=log_record.institution_id
      where (ctx.scope_kind='platform' or log_record.institution_id=ctx.scope_institution_id)
        and (p_institution_id is null or log_record.institution_id=p_institution_id)
        and (p_actor_ids is null or pg_catalog.cardinality(p_actor_ids)=0
          or coalesce(log_record.actor_internal_identity_id,
            log_record.actor_person_id)=any(p_actor_ids))
        and (p_context_kinds is null or pg_catalog.cardinality(p_context_kinds)=0
          or log_record.context_kind=any(p_context_kinds))
        and (p_action_codes is null or pg_catalog.cardinality(p_action_codes)=0
          or log_record.action_code=any(p_action_codes))
        and (p_resource_types is null or pg_catalog.cardinality(p_resource_types)=0
          or log_record.object_type=any(p_resource_types))
        and (p_outcomes is null or pg_catalog.cardinality(p_outcomes)=0 or
          case log_record.outcome::text when 'failed' then 'failure'
            else log_record.outcome::text end=any(p_outcomes))
        and (p_origins is null or pg_catalog.cardinality(p_origins)=0
          or log_record.origin=any(p_origins))
        and (p_from is null or log_record.occurred_at>=p_from)
        and (p_to is null or log_record.occurred_at<=p_to)
        and (nullif(pg_catalog.btrim(p_search),'') is null
          or pg_catalog.strpos(pg_catalog.lower(pg_catalog.concat_ws(' ',
            log_record.action_code,log_record.object_type,log_record.object_id::text,
            log_record.correlation_id::text,
            case when log_record.actor_kind='superadmin_internal' then 'Usuário interno'
              when log_record.actor_kind='auth_session' then 'Sessão autenticada'
              else person.display_name end,institution.public_name)),
            pg_catalog.lower(pg_catalog.btrim(p_search)))>0)
    ),page_plus_one as materialized(
      select * from filtered
      where p_cursor_occurred_at is null
        or (occurred_at,id)<(p_cursor_occurred_at,p_cursor_id)
      order by occurred_at desc,id desc
      limit p_limit+1
    ),visible as materialized(
      select * from page_plus_one order by occurred_at desc,id desc limit p_limit
    )
    select pg_catalog.jsonb_build_object(
      'items',coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',id,'actor',pg_catalog.jsonb_build_object(
          'kind',coalesce(actor_kind,
            case when actor_person_id is null then 'system' else 'person' end),
          'id',effective_actor_id,'display_name',effective_actor_name,
          'role_code',case
            when actor_kind='auth_session' then null
            when actor_kind='superadmin_internal' then coalesce(actor_role_code,'internal_unknown')
            when actor_person_id is null then 'system'
            else coalesce(actor_role_code,'legacy_unknown') end),
        'institution',case when institution_id is null then null else
          pg_catalog.jsonb_build_object('id',institution_id,'name',
            coalesce(institution_name,'Instituição não disponível')) end,
        'action_code',action_code,'permission_code',permission_code,'aal',mfa_aal,
        'object_type',object_type,'object_id',object_id,
        'outcome',case outcome::text when 'failed' then 'failure' else outcome::text end,
        'reason_code',reason_code,'correlation_id',correlation_id,'origin',origin,
        'context',pg_catalog.jsonb_build_object('kind',context_kind,'id',context_id),
        'occurred_at',occurred_at
      ) order by occurred_at desc,id desc) from visible),'[]'::jsonb),
      'has_more',(select pg_catalog.count(*) from page_plus_one)>p_limit,
      'next_cursor',case when (select pg_catalog.count(*) from page_plus_one)>p_limit then
        (select pg_catalog.jsonb_build_object('occurred_at',occurred_at,'event_id',id)
         from visible order by occurred_at,id limit 1) else null end,
      'total_count',(select pg_catalog.count(*) from filtered),
      'can_export',false
    ) into result;
  exception
    when invalid_parameter_value or invalid_text_representation or datetime_field_overflow
      or invalid_datetime_format or numeric_value_out_of_range then
      error_code:='SAI_INVALID_ARGUMENT';
    when others then
      get stacked diagnostics error_code=pg_exception_detail;
      if error_code is null or error_code not in(
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
        'SAI_MFA_REQUIRED') then
        error_code:='SAI_INTERNAL_ERROR';
      end if;
  end;
  select institution_record.id into audit_institution_id
  from public.institutions institution_record
  where institution_record.id=case
    when ctx.scope_kind='institution' then ctx.scope_institution_id
    when ctx.scope_kind='platform' then p_institution_id
    else null end;

  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'audit.read','superadmin.audit.list',error_code,correlation,
      audit_institution_id);
    return app_private.audit_internal_error_envelope_v2(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'audit.read',ctx.aal,'superadmin.audit.list','success',null,
    correlation,audit_institution_id);
  return result;
end
$function$;

create or replace function app_private.audit_get_event_for_superadmin(p_event_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $function$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid:=pg_catalog.gen_random_uuid();
  error_code text;
  result jsonb;
  event_institution_id uuid;
begin
  begin
    select * into strict ctx
    from app_private.require_superadmin_internal_context('audit.read');
    if ctx.scope_kind is null or ctx.scope_kind not in('platform','institution')
      or (ctx.scope_kind='platform' and ctx.scope_institution_id is not null)
      or (ctx.scope_kind='institution' and ctx.scope_institution_id is null)
      or ctx.aal is null or ctx.aal not in('aal1','aal2') then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    if p_event_id is null then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    select pg_catalog.jsonb_build_object(
      'id',log_record.id,
      'actor',pg_catalog.jsonb_build_object(
        'kind',coalesce(log_record.actor_kind,
          case when log_record.actor_person_id is null then 'system' else 'person' end),
        'id',coalesce(log_record.actor_internal_identity_id,log_record.actor_person_id),
        'display_name',case when log_record.actor_kind='superadmin_internal' then 'Usuário interno'
          when log_record.actor_kind='auth_session' then 'Sessão autenticada'
          when log_record.actor_person_id is null then 'Sistema'
          else coalesce(person.display_name,'Ator não disponível') end,
        'role_code',case
          when log_record.actor_kind='auth_session' then null
          when log_record.actor_kind='superadmin_internal'
            then coalesce(log_record.actor_role_code,'internal_unknown')
          when log_record.actor_person_id is null then 'system'
          else coalesce(log_record.actor_role_code,'legacy_unknown') end),
      'institution',case when log_record.institution_id is null then null else
        pg_catalog.jsonb_build_object('id',log_record.institution_id,'name',
          coalesce(institution.public_name,'Instituição não disponível')) end,
      'action_code',log_record.action_code,'permission_code',log_record.permission_code,
      'aal',log_record.mfa_aal,'object_type',log_record.object_type,
      'object_id',log_record.object_id,
      'outcome',case log_record.outcome::text when 'failed' then 'failure'
        else log_record.outcome::text end,
      'reason',coalesce(log_record.reason_code,
        app_private.audit_mask_reason(log_record.reason)),
      'before',app_private.audit_mask_payload(log_record.before_json),
      'after',app_private.audit_mask_payload(log_record.after_json),
      'correlation_id',log_record.correlation_id,'origin',log_record.origin,
      'context',pg_catalog.jsonb_build_object('kind',log_record.context_kind,'id',log_record.context_id),
      'occurred_at',log_record.occurred_at,
      'integrity',pg_catalog.jsonb_build_object(
        'version',log_record.hash_version,'position',log_record.chain_position,
        'previous_hash',case when log_record.previous_hash is null then null
          else pg_catalog.encode(log_record.previous_hash,'hex') end,
        'hash',pg_catalog.encode(log_record.entry_hash,'hex'),
        'verified',app_private.audit_verify_entry(log_record.id))) ,log_record.institution_id
      into result,event_institution_id
    from audit.audit_logs log_record
    left join public.people person on person.id=log_record.actor_person_id
    left join public.institutions institution on institution.id=log_record.institution_id
    where log_record.id=p_event_id
      and (ctx.scope_kind='platform' or log_record.institution_id=ctx.scope_institution_id);
  exception
    when invalid_parameter_value or invalid_text_representation then
      error_code:='SAI_INVALID_ARGUMENT';
    when others then
      get stacked diagnostics error_code=pg_exception_detail;
      if error_code is null or error_code not in(
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
        'SAI_MFA_REQUIRED') then
        error_code:='SAI_INTERNAL_ERROR';
      end if;
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'audit.read','superadmin.audit.detail',error_code,correlation,
      case when ctx.scope_kind='institution' then ctx.scope_institution_id else null end);
    return app_private.audit_internal_error_envelope_v2(error_code,correlation);
  end if;
  if result is null then
    perform app_private.audit_append_superadmin_internal(
      ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
      ctx.session_id,'audit.read',ctx.aal,'superadmin.audit.detail','denied',
      'SAI_PERMISSION_DENIED',correlation,
      case when ctx.scope_kind='institution' then ctx.scope_institution_id else null end);
    return null;
  end if;
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'audit.read',ctx.aal,'superadmin.audit.detail','success',null,
    correlation,event_institution_id,'audit_event',p_event_id);
  return result;
end
$function$;

create or replace function public.audit_list_events_for_superadmin(
  p_search text default null,p_actor_ids uuid[] default null,p_context_kinds text[] default null,
  p_action_codes text[] default null,p_resource_types text[] default null,
  p_outcomes text[] default null,p_origins text[] default null,p_institution_id uuid default null,
  p_from timestamptz default null,p_to timestamptz default null,
  p_cursor_occurred_at timestamptz default null,p_cursor_id uuid default null,p_limit integer default 25
) returns jsonb
language sql
volatile
security definer
set search_path=''
as $function$
  select app_private.audit_list_events_for_superadmin(
    p_search,p_actor_ids,p_context_kinds,p_action_codes,p_resource_types,p_outcomes,p_origins,
    p_institution_id,p_from,p_to,p_cursor_occurred_at,p_cursor_id,p_limit);
$function$;

create or replace function public.audit_get_event_for_superadmin(p_event_id uuid)
returns jsonb
language sql
volatile
security definer
set search_path=''
as $function$
  select app_private.audit_get_event_for_superadmin(p_event_id);
$function$;

alter function app_private.audit_internal_error_envelope_v2(text,uuid) owner to postgres;
alter function app_private.audit_validate_internal_list_filters_v2(
  text,uuid[],text[],text[],text[],text[],text[],timestamptz,timestamptz,timestamptz,uuid,integer
) owner to postgres;
alter function app_private.audit_list_events_for_superadmin(
  text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer
) owner to postgres;
alter function app_private.audit_get_event_for_superadmin(uuid) owner to postgres;
alter function public.audit_list_events_for_superadmin(
  text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer
) owner to postgres;
alter function public.audit_get_event_for_superadmin(uuid) owner to postgres;

revoke all on function app_private.audit_internal_error_envelope_v2(text,uuid)
  from public,anon,authenticated,service_role;
revoke all on function app_private.audit_validate_internal_list_filters_v2(
  text,uuid[],text[],text[],text[],text[],text[],timestamptz,timestamptz,timestamptz,uuid,integer
) from public,anon,authenticated,service_role;
revoke all on function app_private.audit_list_events_for_superadmin(
  text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer
) from public,anon,authenticated,service_role;
revoke all on function app_private.audit_get_event_for_superadmin(uuid)
  from public,anon,authenticated,service_role;

revoke all on function public.audit_list_events_for_superadmin(
  text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer
) from public,anon,authenticated,service_role;
revoke all on function public.audit_get_event_for_superadmin(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.audit_list_events_for_superadmin(
  text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer
) to authenticated;
grant execute on function public.audit_get_event_for_superadmin(uuid) to authenticated;

-- General exports are deferred. Revoke every client/PUBLIC entry point without
-- touching private history, job/result tables, files, snapshots, or service workers.
revoke all on function public.audit_start_export_for_superadmin(text,jsonb,uuid)
  from public,anon,authenticated;
revoke all on function public.audit_get_export_job_for_superadmin(uuid)
  from public,anon,authenticated;
revoke all on function public.audit_authorize_export_download_for_superadmin(uuid)
  from public,anon,authenticated;

comment on function public.audit_list_events_for_superadmin(
  text,uuid[],text[],text[],text[],text[],text[],uuid,timestamptz,timestamptz,timestamptz,uuid,integer
) is 'Internal Superadmin audit directory. Requires audit.read in the 039 realm; applies platform/institution scope and returns can_export=false.';
comment on function public.audit_get_event_for_superadmin(uuid) is
  'Internal Superadmin minimized audit detail. Missing and out-of-scope ids are indistinguishable.';

commit;
