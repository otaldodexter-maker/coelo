-- F-AUTHOR02. LOCAL nominal package; execution/replay belongs exclusively to Eng1.
-- Extends the editor context and adds a minimal paginated creation catalog.
-- Does not change save receipts, publication, legacy population, or shared Auth.
begin;
do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message='F-AUTHOR02 requires postgres';
  end if;
  if pg_catalog.to_regprocedure('app_private.superadmin_forms_editor_v2(uuid)') is null
    or pg_catalog.to_regprocedure('public.superadmin_forms_save_draft_v2(uuid,bigint,jsonb)') is null
    or pg_catalog.to_regclass('app_private.superadmin_internal_form_draft_receipts') is null then
    raise object_not_in_prerequisite_state using message='F-AUTHOR02 requires reviewed F-AUTHOR01';
  end if;
  if pg_catalog.to_regprocedure('public.superadmin_forms_authoring_institutions_v2(jsonb)') is not null
    or pg_catalog.to_regprocedure('app_private.superadmin_forms_authoring_institutions_v2(jsonb)') is not null then
    raise object_not_in_prerequisite_state using message='F-AUTHOR02 already exists; reconcile nominal ledger';
  end if;
  if pg_catalog.strpos(pg_catalog.pg_get_functiondef(
      'app_private.superadmin_forms_editor_v2(uuid)'::regprocedure),'clock_timestamp')=0 then
    raise object_not_in_prerequisite_state using message='F-AUTHOR02 requires temporal reauthorization in F-AUTHOR01';
  end if;
end
$preflight$;

create function app_private.superadmin_forms_authoring_institutions_v2(p_query jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $function$
declare
  ctx app_private.superadmin_internal_context;
  initial_ctx app_private.superadmin_internal_context;
  correlation uuid:=pg_catalog.gen_random_uuid();
  error_code text;
  search_text text:='';
  search_pattern text;
  page_limit integer:=20;
  cursor_name text;
  cursor_id uuid;
  result jsonb;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.manage');
    if ctx.aal is null or ctx.aal not in ('aal1','aal2')
      or ctx.scope_kind is null or ctx.scope_kind not in ('platform','institution')
      or (ctx.scope_kind='institution' and ctx.scope_institution_id is null) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    initial_ctx:=ctx;
    if pg_catalog.current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_query is null or pg_catalog.jsonb_typeof(p_query)<>'object'
      or pg_catalog.octet_length(pg_catalog.convert_to(p_query::text,'UTF8'))>8192 then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    if exists(select 1 from pg_catalog.jsonb_object_keys(p_query) k where k not in ('search','limit','cursor')) then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_query ? 'search' then
      if pg_catalog.jsonb_typeof(p_query->'search') is distinct from 'string'
        or pg_catalog.char_length(p_query->>'search')>160 then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
      search_text:=p_query->>'search';
    end if;
    if p_query ? 'limit' then
      if pg_catalog.jsonb_typeof(p_query->'limit') is distinct from 'number' then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
      if (p_query->>'limit')::numeric<>pg_catalog.trunc((p_query->>'limit')::numeric)
        or (p_query->>'limit')::numeric<1 or (p_query->>'limit')::numeric>50 then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
      page_limit:=(p_query->>'limit')::numeric::integer;
    end if;
    if p_query ? 'cursor' and p_query->'cursor'<>'null'::jsonb then
      if pg_catalog.jsonb_typeof(p_query->'cursor') is distinct from 'object' then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
      if not ((p_query->'cursor') ?& array['name_key','id'])
        or exists(select 1 from pg_catalog.jsonb_object_keys(p_query->'cursor') k where k not in ('name_key','id'))
        or pg_catalog.jsonb_typeof(p_query#>'{cursor,name_key}') is distinct from 'string'
        or pg_catalog.jsonb_typeof(p_query#>'{cursor,id}') is distinct from 'string'
        or pg_catalog.char_length(p_query#>>'{cursor,name_key}')>1024
        or (p_query#>>'{cursor,id}') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
      cursor_name:=p_query#>>'{cursor,name_key}';
      cursor_id:=(p_query#>>'{cursor,id}')::uuid;
    end if;
    -- Literal search. The same lower(public_name), id pair orders and seeks.
    search_pattern:='%'||pg_catalog.replace(pg_catalog.replace(pg_catalog.replace(
      search_text,E'\\',E'\\\\'),'%',E'\\%'),'_',E'\\_')||'%';
    with candidates as materialized (
      select i.id,i.public_name,pg_catalog.lower(i.public_name) as name_key
      from public.institutions i
      where i.status='active' and i.deleted_at is null
        and (ctx.scope_kind='platform' or i.id=ctx.scope_institution_id)
        and (search_text='' or i.public_name ilike search_pattern escape E'\\')
        and (cursor_id is null or (pg_catalog.lower(i.public_name),i.id)>(cursor_name,cursor_id))
      order by pg_catalog.lower(i.public_name),i.id limit page_limit+1
    ), visible as (
      select * from candidates order by name_key,id limit page_limit
    )
    select pg_catalog.jsonb_build_object(
      'items',coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',id,'public_name',public_name) order by name_key,id) from visible),'[]'::jsonb),
      'has_more',(select count(*)>page_limit from candidates),
      'next_cursor',case when (select count(*)>page_limit from candidates)
        then (select pg_catalog.jsonb_build_object('name_key',name_key,'id',id)
              from visible order by name_key desc,id desc limit 1) else null end
    ) into result;
    -- Candidate rows are a snapshot, not an authorization grant. Save performs
    -- its own real-institution check. Reauthorize the actor before returning it.
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.manage');
    if row(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
           ctx.auth_user_id,ctx.session_id,ctx.scope_kind,ctx.scope_institution_id)
       is distinct from row(initial_ctx.internal_identity_id,initial_ctx.internal_auth_link_id,
           initial_ctx.internal_membership_id,initial_ctx.auth_user_id,initial_ctx.session_id,
           initial_ctx.scope_kind,initial_ctx.scope_institution_id)
      or ctx.aal is null or ctx.aal not in ('aal1','aal2')
      or ctx.scope_kind is null or ctx.scope_kind not in ('platform','institution')
      or (ctx.scope_kind='institution' and ctx.scope_institution_id is null) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    if not exists(select 1 from auth.sessions s where s.id=initial_ctx.session_id
      and s.user_id=initial_ctx.auth_user_id
      and (s.not_after is null or s.not_after>pg_catalog.clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_SESSION_INVALID';
    end if;
  exception
    when invalid_parameter_value or invalid_text_representation or numeric_value_out_of_range then
      error_code:='SAI_INVALID_ARGUMENT';
    when others then
      get stacked diagnostics error_code=pg_exception_detail;
      error_code:=app_private.superadmin_internal_error_envelope(error_code,correlation)#>>'{error,code}';
  end;
  -- Audit is intentionally outside the error conversion block: audit failure
  -- cannot produce a successful response or a silently unaudited denial.
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'forms.manage','superadmin.forms.authoring.institutions',error_code,correlation);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
    ctx.internal_membership_id,ctx.session_id,'forms.manage',ctx.aal,
    'superadmin.forms.authoring.institutions','success',null,correlation,ctx.scope_institution_id);
  return pg_catalog.jsonb_build_object('ok',true,'data',result,'error',null);
end
$function$;

create or replace function app_private.superadmin_forms_editor_v2(p_form_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $function$
declare
  ctx app_private.superadmin_internal_context;
  initial_ctx app_private.superadmin_internal_context;
  f public.forms;
  institution_name text;
  correlation uuid:=pg_catalog.gen_random_uuid();
  permission text:='forms.manage';
  error_code text;
  result jsonb;
begin
  begin
    begin
      select * into strict ctx from app_private.require_superadmin_internal_context(permission);
    exception when insufficient_privilege then
      get stacked diagnostics error_code=pg_exception_detail;
      if error_code is distinct from 'SAI_PERMISSION_DENIED' then raise; end if;
      permission:='forms.read';
      select * into strict ctx from app_private.require_superadmin_internal_context(permission);
      error_code:=null;
    end;
    if ctx.aal is null or ctx.aal not in ('aal1','aal2') or ctx.scope_kind is null or ctx.scope_kind not in ('platform','institution')
      or (ctx.scope_kind='institution' and ctx.scope_institution_id is null) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    initial_ctx:=ctx;
    if pg_catalog.current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_form_id is null then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
    select * into f from public.forms where id=p_form_id
      and (ctx.scope_kind='platform' or institution_id=ctx.scope_institution_id) for share;
    select i.public_name into institution_name from public.institutions i where i.id=f.institution_id and i.deleted_at is null for share;
    if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    -- A new SPI statement in this VOLATILE function gets a fresh READ COMMITTED
    -- snapshot after all explicit waits. Keep the originally selected capability.
    select * into strict ctx from app_private.require_superadmin_internal_context(permission);
    if row(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.auth_user_id,ctx.session_id,
           ctx.scope_kind,ctx.scope_institution_id)
       is distinct from row(initial_ctx.internal_identity_id,initial_ctx.internal_auth_link_id,initial_ctx.internal_membership_id,
           initial_ctx.auth_user_id,initial_ctx.session_id,initial_ctx.scope_kind,initial_ctx.scope_institution_id)
      or ctx.aal is null or ctx.aal not in ('aal1','aal2') or ctx.scope_kind is null or ctx.scope_kind not in ('platform','institution')
      or (ctx.scope_kind='institution' and (ctx.scope_institution_id is null or f.institution_id is distinct from ctx.scope_institution_id)) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    if not exists(select 1 from auth.sessions s where s.id=initial_ctx.session_id and s.user_id=initial_ctx.auth_user_id
      and (s.not_after is null or s.not_after>pg_catalog.clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_SESSION_INVALID';
    end if;
    if f.id is null or f.created_by_internal_identity_id is null or f.status<>'draft'
      or f.first_published_at is not null or f.published_version_id is not null
      or exists(select 1 from public.form_versions v where v.form_id=f.id and (v.state<>'working' or v.published_at is not null))
      or exists(select 1 from public.form_applications a where a.form_id=f.id)
      or exists(select 1 from public.form_occurrences o where o.form_id=f.id)
      or exists(select 1 from public.form_file_jobs j where j.form_id=f.id) then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    result:=pg_catalog.jsonb_build_object('definition',app_private.form_definition_projection(f.id),'application',null,
      'institution',pg_catalog.jsonb_build_object('id',f.institution_id,'public_name',institution_name),
      'capabilities',pg_catalog.jsonb_build_object('manage',permission='forms.manage'));
  exception
    when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
    when others then
      get stacked diagnostics error_code=pg_exception_detail;
      error_code:=app_private.superadmin_internal_error_envelope(error_code,correlation)#>>'{error,code}';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(permission,'superadmin.forms.editor',error_code,correlation);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,permission,ctx.aal,'superadmin.forms.editor','success',null,correlation,f.institution_id);
  return pg_catalog.jsonb_build_object('ok',true,'data',result,'error',null);
end
$function$;

create function public.superadmin_forms_authoring_institutions_v2(p_query jsonb)
returns jsonb language sql volatile security definer set search_path='' as $function$
  select app_private.superadmin_forms_authoring_institutions_v2(p_query);
$function$;
alter function app_private.superadmin_forms_authoring_institutions_v2(jsonb) owner to postgres;
alter function public.superadmin_forms_authoring_institutions_v2(jsonb) owner to postgres;
alter function app_private.superadmin_forms_editor_v2(uuid) owner to postgres;
revoke all on function app_private.superadmin_forms_authoring_institutions_v2(jsonb) from public,anon,authenticated,service_role;
revoke all on function public.superadmin_forms_authoring_institutions_v2(jsonb) from public,anon,authenticated,service_role;
revoke all on function app_private.superadmin_forms_editor_v2(uuid) from public,anon,authenticated,service_role;
grant execute on function public.superadmin_forms_authoring_institutions_v2(jsonb) to authenticated;
commit;
