-- 20260910220600_child_context_directory_v2_baseline
--
-- Diretorio de contextos de crianca (Alunos) para o realm interno v2, recarimbado
-- sobre a baseline 20260910000000 + lotes 1..21 (ADR 0034; achado F-R04-FCR-006
-- do grupo formularios-cuidado-rotina, Rodada 4, 11/09/2026).
--
-- O candidato CHILD-READ01 (migrations-historico/20260908051500) nunca entrou na
-- baseline: o cliente (apps/superadmin, SupabaseChildDirectoryReader) chama
-- public.superadmin_child_context_directory_v2 e recebe PGRST202 em
-- /health-care/profiles/new, /health-care/medication-plans/new e /students.
--
-- O corpo da funcao e o do historico, sem alteracao de contrato:
--   * autorizacao por app_private.require_superadmin_internal_context('people.read')
--     com papel owner e escopo platform/institution, releitura do contexto
--     depois dos locks, envelope {ok,data,error} e auditoria por
--     app_private.audit_append_superadmin_internal;
--   * a ponte de ator (20260910220400) nao e necessaria aqui: o realm interno v2
--     autoriza diretamente, sem pessoa de servico;
--   * retorno: data.items[{context_id,person_id,person_name,institution_id,
--     institution_name}] e data.next_cursor {name,context_id} | null.
--
-- O preflight de pins de hash do candidato (md5 do prosrc de cinco funcoes de
-- 09/2026) foi substituido por verificacao de existencia e de forma: as funcoes
-- de Auth mudaram de corpo desde entao (lotes 1..21) e o pin divergiria por
-- desenho. Sem AAL2, sem segredo; grant somente a authenticated.
--
-- Reversao (manual, forward-only): drop function
-- public.superadmin_child_context_directory_v2(uuid,text,uuid,integer).

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
select pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('coelo.child-directory-v2',0));

do $preflight$
declare expected record; function_record record;
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message='child directory migration requires postgres';
  end if;
  for expected in select * from (values
    ('app_private.require_superadmin_internal_context(text)',true,'app_private.superadmin_internal_context'),
    ('app_private.superadmin_internal_error_envelope(text,uuid)',false,'jsonb'),
    ('app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)',true,'void'),
    ('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)',true,'uuid')
  ) v(signature,security_definer,return_type) loop
    select p.* into function_record from pg_catalog.pg_proc p
      where p.oid = pg_catalog.to_regprocedure(expected.signature);
    if function_record.oid is null then
      raise object_not_in_prerequisite_state using message='child directory dependency missing',detail=expected.signature;
    end if;
    if function_record.prosecdef <> expected.security_definer
      or function_record.prorettype is distinct from pg_catalog.to_regtype(expected.return_type)
      or pg_catalog.pg_get_userbyid(function_record.proowner) <> 'postgres'
      or pg_catalog.has_function_privilege('anon',function_record.oid,'EXECUTE')
      or pg_catalog.has_function_privilege('authenticated',function_record.oid,'EXECUTE') then
      raise object_not_in_prerequisite_state using message='child directory dependency drift',detail=expected.signature;
    end if;
  end loop;
  if to_regclass('public.people') is null or to_regclass('public.institutions') is null
    or to_regclass('public.child_contexts') is null
    or not exists(select 1 from pg_catalog.pg_attribute where attrelid='public.child_contexts'::regclass and attname='child_person_id' and not attisdropped)
    or not exists(select 1 from pg_catalog.pg_attribute where attrelid='public.child_contexts'::regclass and attname='institution_id' and not attisdropped)
    or not exists(select 1 from pg_catalog.pg_attribute where attrelid='public.people'::regclass and attname='person_type' and not attisdropped) then
    raise object_not_in_prerequisite_state using message='child directory physical schema drift';
  end if;
  if not exists(select 1 from public.platform_permissions where code='people.read' and status='active') then
    raise object_not_in_prerequisite_state using message='child directory requires active people.read';
  end if;
  if exists(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname in('public','app_private') and p.proname='superadmin_child_context_directory_v2') then
    raise duplicate_function using message='child directory gateway already exists';
  end if;
end
$preflight$;

create function public.superadmin_child_context_directory_v2(
  p_institution_id uuid default null,
  p_after_name text default null,
  p_after_context_id uuid default null,
  p_limit integer default 20
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  ctx app_private.superadmin_internal_context;
  fresh app_private.superadmin_internal_context;
  effective_institution_id uuid;
  correlation_id uuid := gen_random_uuid();
  error_code text;
  error_detail text;
  items jsonb := '[]'::jsonb;
  next_cursor jsonb := 'null'::jsonb;
  last_key text;
  last_id uuid;
  row_record record;
  row_count integer := 0;
  -- Same C0 + DEL contract as the existing DTO; no extra cadastral restriction.
  control_pattern text := '['||chr(1)||'-'||chr(31)||chr(127)||']';
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('people.read');
    if ctx.platform_role_code is distinct from 'owner'
      or ctx.scope_kind not in('platform','institution') then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;

    -- Stable lock order; hold actor authorization rows through append/return.
    perform 1 from auth.users u where u.id=ctx.auth_user_id for share;
    perform 1 from auth.sessions s where s.id=ctx.session_id and s.user_id=ctx.auth_user_id for share;
    perform 1 from app_private.superadmin_internal_auth_links l where l.id=ctx.internal_auth_link_id for share;
    perform 1 from app_private.superadmin_internal_memberships m where m.id=ctx.internal_membership_id for share;
    perform 1 from public.platform_roles r where r.id=ctx.platform_role_id for share;
    perform 1 from public.platform_permissions p where p.code='people.read' for share;
    perform 1 from public.platform_role_permissions g join public.platform_permissions p on p.id=g.permission_id
      where g.role_id=ctx.platform_role_id and p.code='people.read' for share of g;
    select * into strict fresh from app_private.require_superadmin_internal_context('people.read');
    if fresh is distinct from ctx then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;

    if ctx.scope_kind='institution' then
      if ctx.scope_institution_id is null or (p_institution_id is not null
        and p_institution_id <> ctx.scope_institution_id) then
        raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
      end if;
      effective_institution_id := ctx.scope_institution_id;
    else
      effective_institution_id := p_institution_id;
    end if;
    if effective_institution_id is not null then
      perform 1 from public.institutions i where i.id=effective_institution_id
        and i.deleted_at is null for share;
      if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    end if;
    if p_limit is null or p_limit < 1 or p_limit > 50
      or (p_after_name is null) <> (p_after_context_id is null)
      or (p_after_name is not null and (p_after_name='' or octet_length(p_after_name) > 8192
        or p_after_name ~ control_pattern)) then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;

    -- Materialize only limit+1 locked candidates, then sort the actual returned
    -- values again: READ COMMITTED can observe renamed rows after lock waits.
    -- No cross-page snapshot is promised; cursor never authorizes a resource.
    for row_record in
      with locked as materialized (
        select cc.id, cc.child_person_id, cc.institution_id, p.display_name, i.public_name,
          lower(p.display_name) collate "C" as sort_key
        from public.child_contexts cc join public.people p on p.id=cc.child_person_id
        join public.institutions i on i.id=cc.institution_id
        where cc.status = 'active' and p.person_type = 'child'
          and p.deleted_at is null and i.deleted_at is null
          and (effective_institution_id is null or cc.institution_id = effective_institution_id)
          and (p_after_name is null or (lower(p.display_name) collate "C", cc.id)
            > (p_after_name collate "C", p_after_context_id))
        order by lower(p.display_name) collate "C", cc.id
        limit (p_limit + 1) for share of cc, p, i
      ) select * from locked order by sort_key collate "C", id
    loop
      row_count := row_count + 1;
      if row_count > p_limit then
        if octet_length(last_key) > 8192 then
          raise program_limit_exceeded using message='child directory cursor exceeds transport budget';
        end if;
        next_cursor := jsonb_build_object('name',last_key,'context_id',last_id);
        exit;
      end if;
      if row_record.display_name='' or row_record.public_name=''
        or row_record.display_name ~ control_pattern or row_record.public_name ~ control_pattern then
        raise data_exception using message='child directory projection invalid';
      end if;
      items := items || jsonb_build_array(jsonb_build_object(
        'context_id', row_record.id, 'person_id', row_record.child_person_id,
        'person_name', row_record.display_name, 'institution_id', row_record.institution_id,
        'institution_name', row_record.public_name));
      last_key := row_record.sort_key;
      last_id := row_record.id;
    end loop;
    select * into strict fresh from app_private.require_superadmin_internal_context('people.read');
    if fresh is distinct from ctx then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    if not exists(select 1 from auth.sessions s where s.id=ctx.session_id
      and s.user_id=ctx.auth_user_id and (s.not_after is null or s.not_after > clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_SESSION_INVALID';
    end if;
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code := case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID',
        'SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED',
        'SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value then error_code := 'SAI_INVALID_ARGUMENT';
    when serialization_failure or deadlock_detected then error_code := 'SAI_CONCURRENT_CHANGE';
    when others then error_code := 'SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    -- The inherited denial helper uses transaction time. Do not manufacture
    -- an audited actor for a session already expired by the actual wall clock.
    if exists(select 1 from auth.sessions s where s.id::text=auth.jwt()->>'session_id'
      and s.user_id=auth.uid() and (s.not_after is null or s.not_after > clock_timestamp())) then
      perform app_private.audit_superadmin_internal_denial_if_identified(
        'people.read', 'child_context.directory', error_code, correlation_id, null);
    end if;
    return app_private.superadmin_internal_error_envelope(error_code,correlation_id);
  end if;
  -- Outside the error-capture block: failed audit must never release data.
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'people.read',ctx.aal,'child_context.directory','success',null,
    correlation_id,effective_institution_id,'child_context_catalog', null);
  -- Append itself can wait on audit locks. Expiration during that wait must
  -- abort the successful append and response, not return a partial success.
  if not exists(select 1 from auth.sessions s where s.id=ctx.session_id
    and s.user_id=ctx.auth_user_id and (s.not_after is null or s.not_after > clock_timestamp())) then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_SESSION_INVALID';
  end if;
  return jsonb_build_object('ok',true,'data',jsonb_build_object('items',items,'next_cursor',next_cursor),'error',null);
end
$$;
alter function public.superadmin_child_context_directory_v2(uuid,text,uuid,integer) owner to postgres;
revoke all on function public.superadmin_child_context_directory_v2(uuid,text,uuid,integer)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_child_context_directory_v2(uuid,text,uuid,integer) to authenticated;
commit;
