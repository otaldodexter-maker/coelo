-- PROPOSAL ONLY. Remote execution is not authorized by this file.
-- Atomic composition of the pinned envelope prerequisite and CHILD-READ01 migration.
-- Only each source's top-level BEGIN/COMMIT wrapper was removed.
begin;
-- BEGIN PINNED SOURCE: child-envelope-prerequisite.sql (wrapper removed)
-- D03 proposal only; NOT authorized for remote execution.
-- Source: exact helper body from 20260827235500; current remote body from Auth039.
-- Applies only the missing error-envelope dependency, not the historical migration.
set local lock_timeout = '5s';
set local statement_timeout = '30s';
select pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('coelo.child-envelope-prerequisite',0));
do $preflight$
declare p record;
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message='envelope prerequisite requires postgres';
  end if;
  select * into p from pg_catalog.pg_proc
    where oid=pg_catalog.to_regprocedure('app_private.superadmin_internal_error_envelope(text,uuid)');
  if p.oid is null
    or md5(replace(p.prosrc,E'\r\n',E'\n')) <> 'b89d2dc22f032a1c3f155a77f0eaaf08'
    or p.prokind <> 'f' or p.provolatile <> 'i' or p.prosecdef or p.proretset
    or p.prorettype <> 'jsonb'::regtype
    or pg_catalog.pg_get_userbyid(p.proowner) <> 'postgres'
    or coalesce(p.proconfig,'{}'::text[]) <> array['search_path=""']::text[]
    or (select lanname from pg_catalog.pg_language where oid=p.prolang) <> 'sql'
    or exists(select 1 from pg_catalog.aclexplode(coalesce(p.proacl,
      pg_catalog.acldefault('f',p.proowner))) acl where acl.grantee <> p.proowner) then
    raise object_not_in_prerequisite_state using message='envelope prerequisite dependency drift';
  end if;
end
$preflight$;

create or replace function app_private.superadmin_internal_error_envelope(
  p_code text,p_correlation_id uuid
) returns jsonb
language sql
immutable
security invoker
set search_path=''
as $$
  select pg_catalog.jsonb_build_object('ok',false,'data',null,'error',
    pg_catalog.jsonb_build_object('code',case when p_code in(
      'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED','SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE',
      'SAI_INVALID_ARGUMENT') then p_code else 'SAI_INTERNAL_ERROR' end,
      'message',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID')
          then 'Autenticação necessária.'
        when p_code='SAI_MFA_REQUIRED' then 'Confirme o segundo fator.'
        when p_code='SAI_INVALID_ARGUMENT' then 'Revise os dados enviados.'
        when p_code in('SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE')
          then 'O estado mudou. Recarregue e tente novamente.'
        when p_code like 'SAI_%DENIED' or p_code like 'SAI_MEMBERSHIP_%'
          then 'Acesso não autorizado.'
        else 'Não foi possível concluir a operação.' end,
      'correlation_id',p_correlation_id,
      'http_status',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when p_code='SAI_INVALID_ARGUMENT' then 400
        when p_code in('SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE') then 409
        when p_code in('SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then 403
        else 500 end))
$$;

do $postflight$
begin
  if (select md5(replace(prosrc,E'\r\n',E'\n')) from pg_catalog.pg_proc
    where oid=pg_catalog.to_regprocedure('app_private.superadmin_internal_error_envelope(text,uuid)'))
    is distinct from 'bfce7b85b8d5d43e93e5d3fba3a66dc8' then
    raise object_not_in_prerequisite_state using message='envelope prerequisite result drift';
  end if;
end
$postflight$;

-- END PINNED SOURCE: child-envelope-prerequisite.sql
-- BEGIN PINNED SOURCE: 20260908051500_superadmin_child_context_directory_v2.sql (wrapper removed)
-- CHILD-READ01 candidate; no execution authority. Auth + envelope only.
set local lock_timeout = '5s';
set local statement_timeout = '60s';
select pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('coelo.child-directory-v2',0));

do $preflight$
declare expected record; function_record record; relation_oid oid;
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message='child directory migration requires postgres';
  end if;
  -- Pins are MD5(prosrc UTF-8, CRLF -> LF only), extracted from canonical source.
  -- No trim/reformat or pg_get_functiondef pretty-print assumptions.
  -- Sources respectively: 20260901200206, 20260827235500, 20260901124500,
  -- and 20260827233000 (last two). Static gate recalculates all five pins.
  for expected in select * from (values
    ('app_private.require_superadmin_internal_context(text)','5cdb28081d40e15232ef50912edd8082','s',true,'app_private.superadmin_internal_context',true),
    ('app_private.superadmin_internal_error_envelope(text,uuid)','bfce7b85b8d5d43e93e5d3fba3a66dc8','i',false,'jsonb',false),
    ('app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)','d218f9e256e2dca89ed92cf7b702cc13','v',true,'void',false),
    ('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)','950412c5312aae7361164a95f35dfa43','v',true,'uuid',false),
    ('app_private.audit_append_auth_session_denial(uuid,text,text,text,text,uuid)','072e47ff682be44ca3fce7b0d80ea4a4','v',true,'uuid',false)
  ) v(signature,body_md5,volatility,security_definer,return_type,returns_set) loop
    select p.* into function_record from pg_catalog.pg_proc p
      where p.oid = pg_catalog.to_regprocedure(expected.signature);
    if function_record.oid is null then
      raise object_not_in_prerequisite_state using message='child directory dependency missing',detail=expected.signature;
    end if;
    if md5(replace(function_record.prosrc, E'\r\n', E'\n')) is distinct from expected.body_md5
      or function_record.prokind <> 'f'
      or function_record.provolatile::text <> expected.volatility
      or function_record.prosecdef <> expected.security_definer
      or function_record.proretset <> expected.returns_set
      or function_record.prorettype is distinct from pg_catalog.to_regtype(expected.return_type)
      or (select l.lanname from pg_catalog.pg_language l where l.oid=function_record.prolang)
        is distinct from (case when expected.volatility='i' then 'sql' else 'plpgsql' end)
      or pg_catalog.pg_get_userbyid(function_record.proowner) <> 'postgres'
      or coalesce(function_record.proconfig,'{}'::text[]) <> array['search_path=""']::text[]
      or exists(select 1 from pg_catalog.aclexplode(coalesce(function_record.proacl,
        pg_catalog.acldefault('f',function_record.proowner))) a where a.grantee <> function_record.proowner)
      or pg_catalog.has_function_privilege('anon',function_record.oid,'EXECUTE')
      or pg_catalog.has_function_privilege('authenticated',function_record.oid,'EXECUTE')
      or pg_catalog.has_function_privilege('service_role',function_record.oid,'EXECUTE') then
      raise object_not_in_prerequisite_state using message='child directory dependency drift',detail=expected.signature;
    end if;
  end loop;
  if (select array_agg(a.attname::text||':'||pg_catalog.format_type(a.atttypid,a.atttypmod) order by a.attnum)
    from pg_catalog.pg_type t join pg_catalog.pg_attribute a on a.attrelid=t.typrelid
    where t.oid=pg_catalog.to_regtype('app_private.superadmin_internal_context')
      and a.attnum>0 and not a.attisdropped) is distinct from array[
      'internal_identity_id:uuid','internal_auth_link_id:uuid','internal_membership_id:uuid',
      'auth_user_id:uuid','session_id:uuid','platform_role_id:uuid','platform_role_code:text',
      'scope_kind:text','scope_institution_id:uuid','resolved_institution_id:uuid',
      'aal:text','permission_code:text','requires_mfa:boolean']::text[] then
    raise object_not_in_prerequisite_state using message='child directory Auth context type drift';
  end if;
  for expected in select * from (values
    ('people','id','uuid',true),('people','person_type','public.person_type',true),
    ('people','display_name','text',true),('people','deleted_at','timestamptz',false),
    ('institutions','id','uuid',true),('institutions','public_name','text',true),
    ('institutions','deleted_at','timestamptz',false),
    ('child_contexts','id','uuid',true),('child_contexts','child_person_id','uuid',true),
    ('child_contexts','institution_id','uuid',true),('child_contexts','status','public.record_status',true)
  ) v(relation_name,column_name,type_name,not_null) loop
    relation_oid := pg_catalog.to_regclass('public.' || expected.relation_name);
    if not exists(select 1 from pg_catalog.pg_class c where c.oid=relation_oid
      and c.relkind='r' and c.relrowsecurity and pg_catalog.pg_get_userbyid(c.relowner)='postgres')
      or not exists(select 1 from pg_catalog.pg_attribute a where a.attrelid=relation_oid
        and a.attname=expected.column_name and a.attnum>0 and not a.attisdropped
        and a.atttypid=pg_catalog.to_regtype(expected.type_name) and a.attnotnull=expected.not_null) then
      raise object_not_in_prerequisite_state using message='child directory physical schema drift';
    end if;
  end loop;
  for expected in select * from (values('people'),('institutions'),('child_contexts')) v(relation_name) loop
    if not exists(select 1 from pg_catalog.pg_constraint c join pg_catalog.pg_attribute a
      on a.attrelid=c.conrelid and a.attname='id'
      where c.conrelid=pg_catalog.to_regclass('public.'||expected.relation_name)
        and c.contype='p' and c.conkey=array[a.attnum]::smallint[] and c.convalidated) then
      raise object_not_in_prerequisite_state using message='child directory primary key drift';
    end if;
  end loop;
  if not exists(select 1 from pg_catalog.pg_constraint c
    join pg_catalog.pg_attribute p on p.attrelid=c.conrelid and p.attname='child_person_id'
    join pg_catalog.pg_attribute i on i.attrelid=c.conrelid and i.attname='institution_id'
    where c.conrelid=pg_catalog.to_regclass('public.child_contexts') and c.contype='u'
      and c.conkey=array[p.attnum,i.attnum]::smallint[] and c.convalidated) then
    raise object_not_in_prerequisite_state using message='child directory context uniqueness drift';
  end if;
  for expected in select * from (values
    ('child_person_id','people'),('institution_id','institutions')
  ) v(column_name,target_name) loop
    if not exists(select 1 from pg_catalog.pg_constraint c
      join pg_catalog.pg_attribute a on a.attrelid=c.conrelid and a.attname=expected.column_name
      join pg_catalog.pg_attribute target on target.attrelid=c.confrelid and target.attname='id'
      where c.conrelid=pg_catalog.to_regclass('public.child_contexts') and c.contype='f'
        and c.confrelid=pg_catalog.to_regclass('public.'||expected.target_name)
        and c.conkey=array[a.attnum]::smallint[] and c.confkey=array[target.attnum]::smallint[]
        and c.convalidated) then
      raise object_not_in_prerequisite_state using message='child directory relationship drift';
    end if;
  end loop;
  if (select count(*) from public.platform_permissions where code='people.read'
      and status='active' and module_code='people' and screen_code='directory'
      and action_code='read' and risk_level='high') <> 1
    or (select array_agg(r.code::text order by r.code) from public.platform_permissions p
      join public.platform_role_permissions g on g.permission_id=p.id
      join public.platform_roles r on r.id=g.role_id
      where p.code='people.read' and p.status='active' and r.status='active'
        and g.effect='allow' and g.status='active' and g.revoked_at is null)
      is distinct from array['owner']::text[] then
    raise object_not_in_prerequisite_state using message='child directory requires existing Owner-only people.read';
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

-- END PINNED SOURCE: 20260908051500_superadmin_child_context_directory_v2.sql
do $child_package_postflight$
declare p record;
begin
  select * into p from pg_catalog.pg_proc
    where oid=pg_catalog.to_regprocedure(
      'public.superadmin_child_context_directory_v2(uuid,text,uuid,integer)');
  if p.oid is null
    or p.prokind <> 'f'
    or (select l.lanname from pg_catalog.pg_language l where l.oid=p.prolang) <> 'plpgsql'
    or p.provolatile <> 'v'
    or not p.prosecdef
    or p.proretset
    or p.prorettype <> 'jsonb'::regtype
    or pg_catalog.pg_get_userbyid(p.proowner) <> 'postgres'
    or coalesce(p.proconfig,'{}'::text[]) <> array['search_path=""']::text[]
    or md5(replace(p.prosrc,E'\r\n',E'\n')) <> '302916710017ece5fa029d9ea388e3f9'
    or not pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE')
    or pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE')
    or pg_catalog.has_function_privilege('service_role',p.oid,'EXECUTE')
    or exists(
      select 1
      from pg_catalog.aclexplode(coalesce(p.proacl,
        pg_catalog.acldefault('f',p.proowner))) a
      where a.grantee not in(
        p.proowner,
        (select r.oid from pg_catalog.pg_roles r where r.rolname='authenticated'))
        or a.privilege_type <> 'EXECUTE'
        or (a.grantee <> p.proowner and a.is_grantable)
    ) then
    raise object_not_in_prerequisite_state
      using message='child directory package result drift';
  end if;
end
$child_package_postflight$;
commit;
