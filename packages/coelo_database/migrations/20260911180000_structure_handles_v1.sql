-- R05 estrutura (@): structure_handles_v1
--
-- Regra do @ decidida pelo Owner (ADR 0034 Decisao 16, P40/P41): toda entidade
-- nasce com um @ hierarquico gerado no servidor, editavel com verificacao de
-- disponibilidade enquanto digita e troca no maximo uma vez a cada 30 dias.
-- Producao ja tem: institutions.slug como @ (+handle_last_changed_at), units.handle
-- (+handle_last_changed_at, troca por change_unit_handle_for_superadmin com
-- carencia de 15 dias no realm people-based) e activity_definitions.handle_stem
-- + canonical_handle (gatilho set_activity_canonical_handle: stem.unidade.inst).
-- Turmas nao tinham @. Este pacote:
--
--   * public.groups.handle (padrao @nomedaturma.nomedaunidade gerado por
--     gatilho a partir do nome e do @ da unidade, unico, mesmo CHECK das
--     unidades) e groups.handle_last_changed_at; backfill das turmas.
--   * activity_definitions.handle_last_changed_at.
--   * app_private.structure_handle_in_use(p_handle, p_kind, p_exclude_id):
--     unicidade global entre instituicoes, unidades, turmas, atividades
--     (canonical_handle) e pessoas, mais a lista reservada (coelo, coelo.me).
--   * public.superadmin_structure_handle_availability_v1(p_kind, p_handle,
--     p_exclude_id): verificacao enquanto digita (leitura; exige o read da
--     familia no realm interno v2).
--   * public.superadmin_structure_handle_set_v1(p_request_id, p_kind,
--     p_entity_id, p_expected_version, p_handle): troca do @ de unidade, turma
--     ou atividade (stem) com trava de 30 dias (SAI_HANDLE_COOLDOWN com
--     next_allowed_at), versao otimista, recibo idempotente por request_id e
--     auditoria interna (13 argumentos). Instituicoes seguem pelo edit_core.
--
-- Envelope spec-039 {ok, data, error{code, message, http_status,
-- correlation_id}}. Nenhuma funcao exige AAL2 (MFA fora do MVP).
--
-- Reversao: drop das funcoes deste arquivo, drop trigger groups_assign_handle,
-- alter table public.groups drop column handle, handle_last_changed_at;
-- alter table public.activity_definitions drop column handle_last_changed_at.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'structure handles migration must run as postgres';
  end if;
  if to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or to_regprocedure(
      'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)'
    ) is null
    or to_regprocedure('app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)') is null
    or to_regprocedure('app_private.superadmin_internal_error_envelope(text,uuid)') is null
    or to_regprocedure('app_private.activity_slugify(text)') is null
    or to_regclass('public.groups') is null
    or to_regclass('public.units') is null
    or to_regclass('public.activity_definitions') is null
    or to_regclass('public.person_handles') is null then
    raise object_not_in_prerequisite_state using
      message = 'internal Auth, audit, slugify and structure tables are required';
  end if;
end
$preflight$;

-- ---------------------------------------------------------------------------
-- Colunas
-- ---------------------------------------------------------------------------
alter table public.groups
  add column if not exists handle text,
  add column if not exists handle_last_changed_at timestamptz;

alter table public.activity_definitions
  add column if not exists handle_last_changed_at timestamptz;

-- ---------------------------------------------------------------------------
-- Normalizacao e unicidade global
-- ---------------------------------------------------------------------------
create or replace function app_private.structure_handle_normalize(p_handle text)
returns text
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.lower(pg_catalog.regexp_replace(pg_catalog.btrim(coalesce(p_handle, '')), '^@', ''))
$$;

-- Segmento de @ a partir de um nome: so letras e numeros (o CHECK das
-- unidades nao aceita hifen), ate 20 caracteres.
create or replace function app_private.structure_handle_segment(p_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.left(pg_catalog.regexp_replace(app_private.activity_slugify(p_name), '-', '', 'g'), 20)
$$;

-- A lista reservada (public.reserved_handles / app_private.is_reserved_handle)
-- entrou por pacote de outra frente na R05; este helper a usa quando existir e
-- sempre reserva coelo e coelo.me (P35).
create or replace function app_private.structure_handle_is_reserved(p_handle text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  reserved boolean := false;
begin
  if p_handle in ('coelo', 'coelo.me') then return true; end if;
  if to_regprocedure('app_private.is_reserved_handle(text)') is not null then
    execute 'select app_private.is_reserved_handle($1)' into reserved using p_handle;
  end if;
  return coalesce(reserved, false);
end
$$;

revoke all on function app_private.structure_handle_is_reserved(text) from public, anon, authenticated, service_role;

create or replace function app_private.structure_handle_in_use(
  p_handle text,
  p_kind text,
  p_exclude_id uuid
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app_private.structure_handle_is_reserved(p_handle)
    or exists (select 1 from public.institutions i
      where pg_catalog.lower(i.slug) = p_handle and i.deleted_at is null
        and not (p_kind = 'institution' and i.id is not distinct from p_exclude_id))
    or exists (select 1 from public.units u
      where pg_catalog.lower(u.handle) = p_handle
        and not (p_kind = 'unit' and u.id is not distinct from p_exclude_id))
    or exists (select 1 from public.groups g
      where pg_catalog.lower(g.handle) = p_handle
        and not (p_kind = 'group' and g.id is not distinct from p_exclude_id))
    or exists (select 1 from public.activity_definitions a
      where pg_catalog.lower(a.canonical_handle) = p_handle
        and not (p_kind = 'activity' and a.id is not distinct from p_exclude_id))
    or exists (select 1 from public.person_handles ph
      where ph.normalized_handle = p_handle)
$$;

revoke all on function app_private.structure_handle_normalize(text) from public, anon, authenticated, service_role;
revoke all on function app_private.structure_handle_segment(text) from public, anon, authenticated, service_role;
revoke all on function app_private.structure_handle_in_use(text, text, uuid) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Turmas: @ padrao nomedaturma.nomedaunidade
-- ---------------------------------------------------------------------------
create or replace function app_private.groups_assign_handle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  unit_handle text;
  candidate text;
begin
  if new.handle is not null and pg_catalog.btrim(new.handle) <> '' then
    new.handle := app_private.structure_handle_normalize(new.handle);
    return new;
  end if;
  select u.handle into unit_handle from public.units u where u.id = new.unit_id;
  candidate := app_private.structure_handle_segment(new.name);
  if candidate = '' then candidate := 'turma'; end if;
  candidate := candidate || '.' || coalesce(unit_handle, 'unidade');
  if app_private.structure_handle_in_use(candidate, 'group', new.id) then
    candidate := candidate || '_' || pg_catalog.left(pg_catalog.replace(new.id::text, '-', ''), 8);
  end if;
  new.handle := candidate;
  return new;
end
$$;

revoke all on function app_private.groups_assign_handle() from public, anon, authenticated, service_role;

drop trigger if exists groups_assign_handle on public.groups;
create trigger groups_assign_handle
  before insert on public.groups
  for each row execute function app_private.groups_assign_handle();

-- backfill idempotente das turmas existentes
update public.groups g
set handle = sub.candidate
from (
  select g2.id,
    case when app_private.structure_handle_in_use(base.candidate, 'group', g2.id)
      then base.candidate || '_' || pg_catalog.left(pg_catalog.replace(g2.id::text, '-', ''), 8)
      else base.candidate end as candidate
  from public.groups g2
  join public.units u on u.id = g2.unit_id
  cross join lateral (
    select coalesce(nullif(app_private.structure_handle_segment(g2.name), ''), 'turma')
      || '.' || u.handle as candidate
  ) base
  where g2.handle is null
) sub
where sub.id = g.id;

alter table public.groups
  alter column handle set not null;

do $chk$
begin
  if not exists (select 1 from pg_constraint where conname = 'groups_handle_check') then
    alter table public.groups add constraint groups_handle_check
      check (handle = lower(handle) and handle ~ '^[a-z0-9][a-z0-9._]{1,48}[a-z0-9]$');
  end if;
end
$chk$;

create unique index if not exists groups_handle_unique_idx on public.groups (lower(handle));

-- ---------------------------------------------------------------------------
-- Disponibilidade enquanto digita
-- ---------------------------------------------------------------------------
create or replace function public.superadmin_structure_handle_availability_v1(
  p_kind text,
  p_handle text,
  p_exclude_id uuid default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  context_record app_private.superadmin_internal_context;
  correlation_id uuid := gen_random_uuid();
  normalized text;
  reason text;
  error_code text;
  error_detail text;
  read_permission text;
begin
  begin
    read_permission := case p_kind
      when 'institution' then 'institutions.read'
      when 'unit' then 'units.read'
      when 'group' then 'groups.read'
      when 'activity' then 'activities.read'
      else null end;
    if read_permission is null then
      raise invalid_parameter_value using
        message = 'unknown handle kind', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    select * into strict context_record
    from app_private.require_superadmin_internal_context(read_permission);

    normalized := app_private.structure_handle_normalize(p_handle);
    if normalized = '' then
      reason := 'HANDLE_EMPTY';
    elsif p_kind = 'activity' and normalized !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
      reason := 'HANDLE_INVALID';
    elsif p_kind = 'institution' and normalized !~ '^[a-z0-9][a-z0-9._-]{2,29}$' then
      reason := 'HANDLE_INVALID';
    elsif p_kind in ('unit', 'group') and normalized !~ '^[a-z0-9][a-z0-9._]{1,48}[a-z0-9]$' then
      reason := 'HANDLE_INVALID';
    elsif p_kind <> 'activity' and app_private.structure_handle_in_use(normalized, p_kind, p_exclude_id) then
      reason := 'HANDLE_TAKEN';
    end if;
    return pg_catalog.jsonb_build_object(
      'ok', true,
      'data', pg_catalog.jsonb_build_object(
        'kind', p_kind,
        'normalized', normalized,
        'available', reason is null,
        'reason', reason,
        'correlation_id', correlation_id),
      'error', null);
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail in (
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED'
      ) then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value then
      error_code := 'SAI_INVALID_ARGUMENT';
    when others then
      error_code := 'SAI_INTERNAL_ERROR';
  end;
  perform app_private.audit_superadmin_internal_denial_if_identified(
    coalesce(read_permission, 'structure.handle'), 'structure.handle.check', error_code, correlation_id, null);
  return app_private.superadmin_internal_error_envelope(error_code, correlation_id);
end
$$;

revoke all on function public.superadmin_structure_handle_availability_v1(text, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_structure_handle_availability_v1(text, text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Troca do @ com trava de 30 dias
-- ---------------------------------------------------------------------------
create table if not exists app_private.superadmin_structure_handle_receipts (
  request_id uuid primary key,
  actor_internal_identity_id uuid not null,
  kind text not null,
  entity_id uuid not null,
  expected_version bigint not null,
  new_handle text not null,
  result_version bigint not null,
  created_at timestamptz not null default now()
);

revoke all on table app_private.superadmin_structure_handle_receipts from public, anon, authenticated, service_role;

create or replace function public.superadmin_structure_handle_set_v1(
  p_request_id uuid,
  p_kind text,
  p_entity_id uuid,
  p_expected_version bigint,
  p_handle text
) returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  context_record app_private.superadmin_internal_context;
  correlation_id uuid := gen_random_uuid();
  normalized text;
  permission_code text;
  institution_of_entity uuid;
  current_version bigint;
  last_changed timestamptz;
  next_allowed timestamptz;
  result_version bigint;
  prior app_private.superadmin_structure_handle_receipts%rowtype;
  old_handle text;
  error_code text;
  error_detail text;
  cooldown constant interval := interval '30 days';
begin
  begin
    permission_code := case p_kind
      when 'unit' then 'units.update'
      when 'group' then 'groups.manage'
      when 'activity' then 'activities.manage'
      else null end;
    if permission_code is null then
      raise invalid_parameter_value using message = 'unknown handle kind', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    select * into strict context_record
    from app_private.require_superadmin_internal_context(permission_code);
    if context_record.platform_role_code not in ('owner', 'operations') then
      raise insufficient_privilege using message = 'structure handle denied', detail = 'SAI_PERMISSION_DENIED';
    end if;
    if p_request_id is null or p_entity_id is null or p_expected_version is null or p_expected_version <= 0 then
      raise invalid_parameter_value using message = 'invalid handle request', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    normalized := app_private.structure_handle_normalize(p_handle);
    if (p_kind = 'activity' and normalized !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
      or (p_kind <> 'activity' and normalized !~ '^[a-z0-9][a-z0-9._]{1,48}[a-z0-9]$') then
      raise invalid_parameter_value using message = 'invalid handle', detail = 'SAI_INVALID_ARGUMENT';
    end if;

    -- replay idempotente
    select * into prior from app_private.superadmin_structure_handle_receipts r where r.request_id = p_request_id;
    if prior.request_id is not null then
      if prior.actor_internal_identity_id <> context_record.internal_identity_id
        or prior.kind <> p_kind or prior.entity_id <> p_entity_id
        or prior.expected_version <> p_expected_version or prior.new_handle <> normalized then
        raise invalid_parameter_value using message = 'request replay mismatch', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      return pg_catalog.jsonb_build_object('ok', true, 'data', pg_catalog.jsonb_build_object(
        'kind', p_kind, 'entity_id', p_entity_id, 'handle', normalized,
        'management_version', prior.result_version, 'replayed', true, 'correlation_id', correlation_id),
        'error', null);
    end if;

    if p_kind = 'unit' then
      select u.institution_id, u.management_version, u.handle_last_changed_at, u.handle
        into institution_of_entity, current_version, last_changed, old_handle
      from public.units u where u.id = p_entity_id for update;
    elsif p_kind = 'group' then
      select g.institution_id, g.management_version, g.handle_last_changed_at, g.handle
        into institution_of_entity, current_version, last_changed, old_handle
      from public.groups g where g.id = p_entity_id for update;
    else
      select a.institution_id, a.management_version, a.handle_last_changed_at, a.handle_stem
        into institution_of_entity, current_version, last_changed, old_handle
      from public.activity_definitions a where a.id = p_entity_id for update;
    end if;
    if institution_of_entity is null
      or (context_record.scope_kind = 'institution'
        and context_record.scope_institution_id is distinct from institution_of_entity) then
      -- outro tenant e id inexistente sao indistinguiveis
      raise no_data_found using message = 'entity not found', detail = 'SAI_NOT_FOUND';
    end if;
    if current_version <> p_expected_version then
      raise serialization_failure using message = 'stale version', detail = 'SAI_CONCURRENT_CHANGE';
    end if;
    if last_changed is not null and last_changed + cooldown > pg_catalog.now() then
      next_allowed := last_changed + cooldown;
      raise check_violation using message = 'handle cooldown', detail = 'SAI_HANDLE_COOLDOWN';
    end if;
    if old_handle = normalized then
      raise invalid_parameter_value using message = 'handle unchanged', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    if p_kind <> 'activity' and app_private.structure_handle_in_use(normalized, p_kind, p_entity_id) then
      raise unique_violation using message = 'handle taken', detail = 'SAI_HANDLE_TAKEN';
    end if;

    if p_kind = 'unit' then
      update public.units set handle = normalized, handle_last_changed_at = pg_catalog.now(),
        management_version = management_version + 1, updated_at = pg_catalog.now()
      where id = p_entity_id returning management_version into result_version;
    elsif p_kind = 'group' then
      update public.groups set handle = normalized, handle_last_changed_at = pg_catalog.now(),
        management_version = management_version + 1, updated_at = pg_catalog.now()
      where id = p_entity_id returning management_version into result_version;
    else
      -- o gatilho set_activity_canonical_handle recompoe stem.unidade.instituicao
      update public.activity_definitions set handle_stem = normalized, handle_last_changed_at = pg_catalog.now(),
        management_version = management_version + 1, updated_at = pg_catalog.now()
      where id = p_entity_id returning management_version into result_version;
    end if;

    insert into app_private.superadmin_structure_handle_receipts
      (request_id, actor_internal_identity_id, kind, entity_id, expected_version, new_handle, result_version)
    values (p_request_id, context_record.internal_identity_id, p_kind, p_entity_id, p_expected_version, normalized, result_version);

    perform app_private.audit_append_superadmin_internal(
      context_record.internal_identity_id,
      context_record.internal_auth_link_id,
      context_record.internal_membership_id,
      context_record.session_id,
      permission_code,
      context_record.aal,
      p_kind || '.handle.change',
      'success',
      null,
      correlation_id,
      institution_of_entity,
      p_kind,
      p_entity_id
    );

    return pg_catalog.jsonb_build_object('ok', true, 'data', pg_catalog.jsonb_build_object(
      'kind', p_kind, 'entity_id', p_entity_id, 'handle', normalized,
      'management_version', result_version, 'replayed', false, 'correlation_id', correlation_id),
      'error', null);
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail in (
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED'
      ) then error_detail else 'SAI_INTERNAL_ERROR' end;
    when no_data_found then
      error_code := 'SAI_NOT_FOUND';
    when serialization_failure then
      error_code := 'SAI_CONCURRENT_CHANGE';
    when check_violation then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail = 'SAI_HANDLE_COOLDOWN' then 'SAI_HANDLE_COOLDOWN' else 'SAI_INVALID_ARGUMENT' end;
    when unique_violation then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail = 'SAI_HANDLE_TAKEN' then 'SAI_HANDLE_TAKEN' else 'SAI_INVALID_ARGUMENT' end;
    when invalid_parameter_value or foreign_key_violation or invalid_text_representation then
      error_code := 'SAI_INVALID_ARGUMENT';
    when others then
      error_code := 'SAI_INTERNAL_ERROR';
  end;

  perform app_private.audit_superadmin_internal_denial_if_identified(
    coalesce(permission_code, 'structure.handle'), coalesce(p_kind, 'structure') || '.handle.change',
    error_code, correlation_id, institution_of_entity);
  if error_code = 'SAI_HANDLE_COOLDOWN' then
    return pg_catalog.jsonb_build_object('ok', false, 'data', null, 'error', pg_catalog.jsonb_build_object(
      'code', 'SAI_HANDLE_COOLDOWN',
      'message', 'O @ so pode ser alterado uma vez a cada 30 dias.',
      'http_status', 409,
      'correlation_id', correlation_id,
      'next_allowed_at', next_allowed));
  end if;
  if error_code in ('SAI_HANDLE_TAKEN', 'SAI_NOT_FOUND') then
    return pg_catalog.jsonb_build_object('ok', false, 'data', null, 'error', pg_catalog.jsonb_build_object(
      'code', error_code,
      'message', case error_code when 'SAI_HANDLE_TAKEN' then 'Este @ ja esta em uso.' else 'Registro nao encontrado.' end,
      'http_status', case error_code when 'SAI_HANDLE_TAKEN' then 409 else 404 end,
      'correlation_id', correlation_id));
  end if;
  return app_private.superadmin_internal_error_envelope(error_code, correlation_id);
end
$$;

revoke all on function public.superadmin_structure_handle_set_v1(uuid, text, uuid, bigint, text)
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_structure_handle_set_v1(uuid, text, uuid, bigint, text) to authenticated;

-- Detalhe v2 de Turmas: expor o @ ao cliente sem mudar assinatura
-- (o cliente le `handle` e `handle_last_changed_at` do payload quando existirem).

do $post$
begin
  if exists (select 1 from public.groups where handle is null) then
    raise exception 'groups without handle after backfill';
  end if;
end
$post$;

commit;
