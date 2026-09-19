-- Lote 98 (CODE-REVIEW r4, 20/09/2026): activity_canonical_handle_v2
--
-- O @ da atividade passa a ser `stem.@daunidade` (origem unidade) ou
-- `stem.@dainstituicao` (origem instituicao), usando o handle REAL da unidade
-- (units.handle) e o @ da instituicao (institutions.slug), em vez de
-- `stem.unit.slug.institution.slug`. O stem segue as mesmas regras de segmento
-- das unidades e turmas ([a-z0-9_], sem hifen; padrao = structure_handle_segment
-- do nome) e o @ completo e unico no sistema (structure_handle_in_use, que
-- agora tambem considera os aliases de atividade). Troca so por
-- superadmin_structure_handle_set_v1 (30 dias, SAI_HANDLE_COOLDOWN).
--
--   * app_private.activity_handle_stem_normalize(text) e
--     app_private.activity_canonical_handle_for(stem, inst, escopo, unidade).
--   * gatilho set_activity_canonical_handle recomposto; refresh_unit_activity_handles
--     dispara tambem na troca de units.handle; capture_activity_handle_alias
--     passa a ouvir todo UPDATE (antes perdia o alias quando o canonical mudava
--     por recomposicao no BEFORE).
--   * superadmin_activity_create_v2: @ explicito unico (SAI_HANDLE_TAKEN), padrao
--     sem hifen com sufixo curto em colisao.
--   * superadmin_structure_handle_availability_v1('activity', 'stem.@escopo'):
--     confere o @ completo enquanto digita; superadmin_structure_handle_set_v1
--     confere unicidade do @ completo da atividade.
--   * CHECKs de handle_stem / canonical_handle / alias alinhados; backfill das
--     atividades existentes (o canonical antigo vira alias).
--
-- Reversao: recriar as funcoes e CHECKs como em 20260911180000 /
-- 20260911211100 / baseline; aliases criados pelo backfill podem ficar.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '300s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'activity canonical handle v2 must run as postgres';
  end if;
  if to_regprocedure('app_private.structure_handle_in_use(text,text,uuid)') is null
    or to_regprocedure('app_private.structure_handle_segment(text)') is null
    or to_regprocedure('app_private.structure_handle_normalize(text)') is null
    or to_regprocedure('public.superadmin_structure_handle_set_v1(uuid,text,uuid,bigint,text)') is null
    or to_regprocedure('public.superadmin_activity_create_v2(uuid,jsonb)') is null
    or to_regprocedure('app_private.capture_activity_handle_alias()') is null then
    raise object_not_in_prerequisite_state using message = 'structure_handles_v1 and activity v2 are required';
  end if;
end
$preflight$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
-- Stem a partir do que o cliente digitou: sem @, minusculo, so o primeiro
-- segmento, sem acento, so [a-z0-9_] (hifen e espaco caem, como em
-- structure_handle_segment).
create or replace function app_private.activity_handle_stem_normalize(p_value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.regexp_replace(
    pg_catalog.translate(
      pg_catalog.split_part(app_private.structure_handle_normalize(p_value), '.', 1),
      'áàâãäéèêëíìîïóòôõöúùûüçñ', 'aaaaaeeeeiiiiooooouuuucn'),
    '[^a-z0-9_]', '', 'g')
$$;

-- @ completo da atividade: stem.@unidade (origem unidade) ou stem.@instituicao.
create or replace function app_private.activity_canonical_handle_for(
  p_stem text,
  p_institution_id uuid,
  p_scope_kind text,
  p_unit_id uuid
) returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  institution_handle text;
  suffix text;
begin
  select pg_catalog.lower(i.slug) into institution_handle
  from public.institutions i where i.id = p_institution_id;
  if institution_handle is null then
    raise foreign_key_violation using message = 'institution not found', detail = 'ACTIVITY_INVALID_REFERENCE';
  end if;
  if p_scope_kind = 'unit' then
    select coalesce(pg_catalog.lower(u.handle),
      pg_catalog.regexp_replace(pg_catalog.lower(u.slug), '[^a-z0-9]', '', 'g') || '.' || institution_handle)
      into suffix
    from public.units u where u.id = p_unit_id and u.institution_id = p_institution_id;
    if suffix is null then
      raise foreign_key_violation using message = 'unit outside institution', detail = 'ACTIVITY_INVALID_REFERENCE';
    end if;
  else
    suffix := institution_handle;
  end if;
  return p_stem || '.' || suffix;
end
$$;

revoke all on function app_private.activity_handle_stem_normalize(text) from public, anon, authenticated, service_role;
revoke all on function app_private.activity_canonical_handle_for(text, uuid, text, uuid) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- CHECKs alinhados (stem sem hifen, com underscore; @ completo aceita _ e o
-- hifen que o slug de instituicao ainda pode ter). O CHECK do stem volta
-- depois do backfill.
-- ---------------------------------------------------------------------------
alter table public.activity_definitions drop constraint if exists activity_definitions_handle_check;
alter table public.activity_definitions drop constraint if exists activity_definitions_canonical_handle_check;
alter table public.activity_definitions add constraint activity_definitions_canonical_handle_check
  check (canonical_handle = lower(canonical_handle) and canonical_handle ~ '^[a-z0-9_-]+(?:\.[a-z0-9_-]+)+$');
alter table public.activity_handle_aliases drop constraint if exists activity_handle_aliases_alias_check;
alter table public.activity_handle_aliases add constraint activity_handle_aliases_alias_check
  check (alias = lower(alias) and alias ~ '^[a-z0-9_-]+(?:\.[a-z0-9_-]+)+$');

-- ---------------------------------------------------------------------------
-- Gatilhos
-- ---------------------------------------------------------------------------
create or replace function app_private.set_activity_canonical_handle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.handle_stem := app_private.activity_handle_stem_normalize(new.handle_stem);
  if new.handle_stem !~ '^[a-z0-9][a-z0-9_]{0,62}[a-z0-9]$' then
    raise invalid_parameter_value using message = 'invalid activity handle stem', detail = 'SAI_INVALID_ARGUMENT';
  end if;
  new.canonical_handle := app_private.activity_canonical_handle_for(
    new.handle_stem, new.institution_id, new.origin_scope_kind::text, new.origin_unit_id);
  if app_private.structure_handle_in_use(new.canonical_handle, 'activity', new.id) then
    raise unique_violation using message = 'activity handle taken', detail = 'SAI_HANDLE_TAKEN';
  end if;
  return new;
end
$$;

create or replace function app_private.refresh_unit_activity_handles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.slug is distinct from new.slug or old.handle is distinct from new.handle then
    update public.activity_definitions set handle_stem = handle_stem, updated_at = pg_catalog.now()
    where origin_unit_id = new.id and institution_id = new.institution_id;
  end if;
  return new;
end
$$;

-- O alias do @ antigo nunca era capturado quando o canonical mudava por
-- recomposicao no BEFORE (UPDATE OF canonical_handle olha so o SET do comando);
-- a funcao ja compara old/new, entao o gatilho passa a ouvir todo UPDATE.
drop trigger if exists activity_canonical_handle_alias_after on public.activity_definitions;
create trigger activity_canonical_handle_alias_after
  after update on public.activity_definitions
  for each row execute function app_private.capture_activity_handle_alias();

drop trigger if exists unit_activity_handles_after on public.units;
create trigger unit_activity_handles_after
  after update of slug, handle on public.units
  for each row execute function app_private.refresh_unit_activity_handles();

-- ---------------------------------------------------------------------------
-- Unicidade global (agora com aliases), troca, disponibilidade e criacao
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app_private.structure_handle_in_use(p_handle text, p_kind text, p_exclude_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    or exists (select 1 from public.activity_handle_aliases al
      where pg_catalog.lower(al.alias) = p_handle
        and not (p_kind = 'activity' and al.activity_id is not distinct from p_exclude_id))
    or exists (select 1 from public.person_handles ph
      where ph.normalized_handle = p_handle)
$function$;

CREATE OR REPLACE FUNCTION public.superadmin_structure_handle_set_v1(p_request_id uuid, p_kind text, p_entity_id uuid, p_expected_version bigint, p_handle text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  activity_scope text;
  activity_unit uuid;
  candidate text;
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
    if p_kind = 'activity' then normalized := app_private.activity_handle_stem_normalize(p_handle); end if;
    if (p_kind = 'activity' and normalized !~ '^[a-z0-9][a-z0-9_]{0,62}[a-z0-9]$')
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
      select a.institution_id, a.management_version, a.handle_last_changed_at, a.handle_stem, a.origin_scope_kind, a.origin_unit_id
        into institution_of_entity, current_version, last_changed, old_handle, activity_scope, activity_unit
      from public.activity_definitions a where a.id = p_entity_id for update;
    end if;
    if institution_of_entity is null
      or (context_record.scope_kind = 'institution'
        and context_record.scope_institution_id is distinct from institution_of_entity) then
      -- outro tenant e id inexistente sao indistinguiveis
      raise no_data_found using message = 'entity not found', detail = 'SAI_NOT_FOUND';
    end if;
    if current_version <> p_expected_version then
      raise exception using errcode='PT409', message = 'stale version', detail = 'SAI_CONCURRENT_CHANGE';
    end if;
    if last_changed is not null and last_changed + cooldown > pg_catalog.now() then
      next_allowed := last_changed + cooldown;
      raise check_violation using message = 'handle cooldown', detail = 'SAI_HANDLE_COOLDOWN';
    end if;
    if old_handle = normalized then
      raise invalid_parameter_value using message = 'handle unchanged', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    -- atividade: a unicidade e do @ completo (stem.@escopo), como nas demais entidades
    candidate := case when p_kind = 'activity'
      then app_private.activity_canonical_handle_for(normalized, institution_of_entity, activity_scope, activity_unit)
      else normalized end;
    if app_private.structure_handle_in_use(candidate, p_kind, p_entity_id) then
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
      -- o gatilho set_activity_canonical_handle recompoe stem.@unidade ou stem.@instituicao
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
    when serialization_failure or sqlstate 'PT409' then
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
$function$;

CREATE OR REPLACE FUNCTION public.superadmin_structure_handle_availability_v1(p_kind text, p_handle text, p_exclude_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    elsif p_kind = 'activity' and pg_catalog.split_part(normalized, '.', 1) !~ '^[a-z0-9][a-z0-9_]{0,62}[a-z0-9]$' then
      reason := 'HANDLE_INVALID';
    elsif p_kind = 'institution' and normalized !~ '^[a-z0-9][a-z0-9._-]{2,29}$' then
      reason := 'HANDLE_INVALID';
    elsif p_kind in ('unit', 'group') and normalized !~ '^[a-z0-9][a-z0-9._]{1,48}[a-z0-9]$' then
      reason := 'HANDLE_INVALID';
    -- atividade: so o @ completo (stem.@escopo, como a previa mostra) e conferido; o stem sozinho so valida formato
    elsif (p_kind <> 'activity' or pg_catalog.strpos(normalized, '.') > 0)
      and app_private.structure_handle_in_use(normalized, p_kind, p_exclude_id) then
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
$function$;

CREATE OR REPLACE FUNCTION public.superadmin_activity_create_v2(p_request_id uuid, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid(); institution uuid; activity uuid:=gen_random_uuid(); taxonomy uuid; units uuid[]; h bytea; replay jsonb; a public.activity_definitions%rowtype; code text; stem text;
begin begin
 select * into strict ctx from app_private.activity_v2_require_context('activities.create',null);
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or p_payload-array['institution_id','name','description','taxonomy_id','icon_key','initials','unit_ids','handle']<>'{}'::jsonb
 or jsonb_typeof(p_payload->'institution_id')<>'string' or jsonb_typeof(p_payload->'name')<>'string'
 or jsonb_typeof(p_payload->'taxonomy_id')<>'string' or jsonb_typeof(p_payload->'unit_ids')<>'array'
 or (p_payload?'description' and p_payload->'description'<>'null'::jsonb and jsonb_typeof(p_payload->'description')<>'string')
 or (p_payload?'icon_key' and p_payload->'icon_key'<>'null'::jsonb and jsonb_typeof(p_payload->'icon_key')<>'string')
 or (p_payload?'initials' and p_payload->'initials'<>'null'::jsonb and jsonb_typeof(p_payload->'initials')<>'string')
 or exists(select 1 from jsonb_array_elements(p_payload->'unit_ids') item where jsonb_typeof(item)<>'string')
 or length(btrim(coalesce(p_payload->>'name',''))) not between 1 and 120
 or length(coalesce(p_payload->>'description',''))>500 or length(coalesce(p_payload->>'icon_key',''))>64
 or length(btrim(coalesce(p_payload->>'initials',''))) not between 1 and 2
 or nullif(p_payload->>'institution_id','') is null or nullif(p_payload->>'taxonomy_id','') is null
 then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 begin institution:=(p_payload->>'institution_id')::uuid; taxonomy:=(p_payload->>'taxonomy_id')::uuid; select array_agg(x::uuid) into units from jsonb_array_elements_text(p_payload->'unit_ids')x; exception when others then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end;
 if p_request_id is null or nullif(btrim(p_payload->>'name'),'') is null or coalesce(array_length(units,1),0) not between 1 and 100 or cardinality(units)<>(select count(distinct unit_id) from unnest(units) unit_id) then raise invalid_parameter_value using detail='ACTIVITY_INVALID_INPUT'; end if;
 select * into strict ctx from app_private.activity_v2_require_context('activities.create',institution); perform app_private.activity_v2_require_context('activities.link_units',institution);
 h:=app_private.activity_v2_command_request_hash('activity.create',institution,null,null,p_payload); replay:=app_private.activity_v2_replay_or_error(ctx,p_request_id,institution,null,'activity.create',h,correlation); if replay is not null then return replay; end if;
 perform 1 from public.activity_taxonomies t where t.id=taxonomy order by t.id for share;
 perform 1 from public.units u where u.id=any(units) order by u.id for share;
 if not exists(select 1 from public.activity_taxonomies t where t.id=taxonomy and t.status='active' and t.code<>'outros') or (select count(*) from public.units u where u.id=any(units) and u.institution_id=institution and u.status='active')<>cardinality(units) then raise invalid_parameter_value using detail='ACTIVITY_INVALID_REFERENCE'; end if;
 perform app_private.activity_v2_set_marker(ctx,'activities.create','create',correlation);
 -- Decisao 16: @ opcional; explicito -> stem.@instituicao unico (SAI_HANDLE_TAKEN); ausente -> segmento do nome
 -- com as mesmas regras de unidade/turma (sem hifen), sufixo curto em colisao
 stem:=nullif(app_private.activity_handle_stem_normalize(p_payload->>'handle'),'');
 if stem is not null then
  if app_private.structure_handle_in_use(app_private.activity_canonical_handle_for(stem,institution,'institution',null),'activity',null)
  then raise unique_violation using message='handle already in use',detail='SAI_HANDLE_TAKEN'; end if;
 else
  stem:=coalesce(nullif(app_private.structure_handle_segment(p_payload->>'name'),''),'atividade');
  if length(stem)<2 then stem:=stem||'0'; end if;
  if app_private.structure_handle_in_use(app_private.activity_canonical_handle_for(stem,institution,'institution',null),'activity',null)
  then stem:=stem||'_'||left(replace(activity::text,'-',''),8); end if;
 end if;
 insert into public.activity_definitions(id,institution_id,name,description,origin_scope_kind,origin_unit_id,created_by_person_id,status,taxonomy_id,handle_stem,identity_mode,identity_initials,identity_color,identity_icon)
 values(activity,institution,btrim(p_payload->>'name'),nullif(btrim(p_payload->>'description'),''),'institution',null,null,'draft',taxonomy,stem,'initials',nullif(p_payload->>'initials',''),'#D63C00',nullif(p_payload->>'icon_key','')) returning * into a;
 perform app_private.activity_v2_set_marker(ctx,'activities.link_units','link_units',correlation);
 insert into public.activity_unit_links(activity_id,institution_id,unit_id,linked_by_person_id) select activity,institution,x,null from unnest(units)x;
 correlation:=app_private.activity_v2_append_audit(ctx,institution,activity,'activities.create','activity.create',pg_catalog.jsonb_build_object('units',cardinality(units)));
 return app_private.activity_v2_finish_command(ctx,p_request_id,institution,activity,'activity.create',h,a.management_version,a.status::text,correlation,pg_catalog.jsonb_build_object('units',cardinality(units)));
 exception when others then get stacked diagnostics code=pg_exception_detail; code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 if code='SAI_HANDLE_TAKEN' then
  -- mesmo envelope de superadmin_structure_handle_set_v1 (o normalizador de erros v2 nao conhece este codigo)
  perform app_private.audit_superadmin_internal_denial_if_identified('activities.create','activity.create',code,correlation,institution);
  return pg_catalog.jsonb_build_object('ok',false,'data',null,'error',pg_catalog.jsonb_build_object(
   'code','SAI_HANDLE_TAKEN','message','Este @ ja esta em uso.','http_status',409,'correlation_id',correlation));
 end if;
 return app_private.activity_v2_denied_envelope('activities.create','activity.create',code,correlation,institution); end $function$;

-- ---------------------------------------------------------------------------
-- Backfill: cada atividade recebe o @ novo; colisao ganha sufixo curto; o
-- canonical antigo vira alias pelo gatilho capture_activity_handle_alias.
-- ---------------------------------------------------------------------------
create or replace function app_private.activity_canonical_handle_backfill_v2()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  new_stem text;
  candidate text;
  changed integer := 0;
begin
  for r in
    select a.id, a.handle_stem, a.canonical_handle, a.institution_id, a.origin_scope_kind, a.origin_unit_id
    from public.activity_definitions a
    order by a.created_at, a.id
  loop
    new_stem := app_private.activity_handle_stem_normalize(r.handle_stem);
    if pg_catalog.length(new_stem) < 2 then new_stem := 'atividade'; end if;
    candidate := app_private.activity_canonical_handle_for(new_stem, r.institution_id, r.origin_scope_kind::text, r.origin_unit_id);
    if candidate = r.canonical_handle then continue; end if;
    if app_private.structure_handle_in_use(candidate, 'activity', r.id) then
      new_stem := new_stem || '_' || pg_catalog.left(pg_catalog.replace(r.id::text, '-', ''), 8);
    end if;
    update public.activity_definitions set handle_stem = new_stem, updated_at = pg_catalog.now() where id = r.id;
    changed := changed + 1;
  end loop;
  return changed;
end
$$;

revoke all on function app_private.activity_canonical_handle_backfill_v2() from public, anon, authenticated, service_role;

-- gatilho constraint deferido (activity_definition_requires_unit) precisa disparar antes do ALTER TABLE
set constraints all immediate;
select app_private.activity_canonical_handle_backfill_v2();

alter table public.activity_definitions add constraint activity_definitions_handle_check
  check (handle_stem = lower(handle_stem) and handle_stem ~ '^[a-z0-9][a-z0-9_]{0,62}[a-z0-9]$');

do $post$
begin
  if exists (
    select 1 from public.activity_definitions a
    where a.canonical_handle <> app_private.activity_canonical_handle_for(a.handle_stem, a.institution_id, a.origin_scope_kind::text, a.origin_unit_id)
  ) then
    raise exception 'activity canonical handles out of sync after backfill';
  end if;
end
$post$;

commit;
