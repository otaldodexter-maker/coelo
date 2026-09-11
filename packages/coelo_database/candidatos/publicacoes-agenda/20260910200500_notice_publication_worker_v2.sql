-- Worker de materializacao de audiencia dos Avisos (v2) sobre a baseline de
-- producao. Grupo publicacoes-agenda, Rodada 4 (E2-R04-20260911).
--
-- Origem: a cadeia legada people-based (migrations-historico/20260812003000,
-- 20260820212340 e 20260820220500) criou a fila app_private.notice_publication_jobs,
-- o claim/materialize/run e os wrappers publicos *_for_worker consumidos pela
-- Edge Function supabase/functions/notice-publication-worker (index.ts). Nada
-- dessa cadeia chegou a producao: o gateway v2 (migrations/20260910200000) foi
-- entregue sem fila, e o worker ficou sem RPC para chamar. Este pacote reentrega
-- somente o minimo que o index.ts consome, adaptado ao v2:
--
--   * index.ts chama rpc('claim_notice_publication_jobs_for_worker',
--     {p_worker, p_limit}) e espera um array de linhas com "id"; e chama
--     rpc('run_notice_publication_job_for_worker', {p_job_id, p_limit}) e
--     espera um objeto com "state" em ('processing','completed','failed').
--     As assinaturas e retornos sao os mesmos do legado.
--   * O v2 ja decide scheduled/active no publish e promove scheduled->active na
--     leitura (superadmin_notice_refresh_lifecycle). O worker NAO muda o status
--     do aviso: so gera recibos em public.notice_receipts. Audiencia vazia
--     marca o job como failed/empty_audience sem tocar em platform_notices.
--   * Sem app_private.append_notice_audit, notice_command_receipts e
--     notice_admin_audit (legado people-based). O rastro do worker fica em
--     analytics.notice_events (audience_materialized / audience_empty), que ja
--     e a tabela canonica em producao.
--   * "Job superado" nao pode usar management_version: o refresh_lifecycle do
--     v2 incrementa a versao ao promover scheduled->active, o que invalidaria
--     todo job agendado. Um job e superado quando existe job mais novo para o
--     mesmo aviso (a fila e unica por notice_id+notice_version).
--   * A audiencia materializada e a de platform_notices.audience_json no
--     momento da primeira pagina (o rascunho agendado/pausado pode ser editado
--     pelo save_draft_v2 sem novo job); o snapshot do job registra o que foi
--     usado.
--   * Sem publication_job_id/notice_version/current_publication_job_id
--     (20260820220500): index.ts e superadmin_notice_json nao os exigem e a
--     re-materializacao (pausar -> reagendar) so acrescenta recibos novos.
--     A unicidade (notice_id, person_id, institution_id) trata NULL como
--     distinto, por isso nasce o indice parcial de escopo plataforma que o
--     "on conflict do nothing" precisa.
--   * superadmin_notice_publish_v2 e superadmin_notice_change_status_v2 sao
--     recriadas com o texto de 20260910200000 acrescido apenas do enfileiramento
--     do job (publicar; reagendar a partir de pausado), on conflict do nothing.
--   * Nenhuma capacidade nova, nenhum requires_mfa (ADR 0034, Decisao 12).
--     pg_cron, segredo do worker e deploy da Edge Function sao do coordenador.
--
-- Ordem: depois de candidatos/publicacoes-agenda/20260910200400.
begin;

do $preflight$
begin
  if current_user <> 'postgres'
    or to_regprocedure('public.superadmin_notice_publish_v2(uuid,uuid,bigint)') is null
    or to_regprocedure('public.superadmin_notice_change_status_v2(uuid,uuid,bigint,text,text)') is null
    or to_regprocedure('app_private.superadmin_notice_context(text)') is null
    or to_regprocedure('app_private.superadmin_notice_json(public.platform_notices)') is null
    or to_regprocedure('app_private.superadmin_notice_denied(text,text,text,uuid)') is null
    or to_regprocedure('app_private.superadmin_notice_append_audit(app_private.superadmin_internal_context,text,uuid,text,text,uuid)') is null
    or to_regclass('app_private.superadmin_notice_command_receipts') is null
    or to_regclass('public.notice_receipts') is null
    or to_regclass('analytics.notice_events') is null
    or not exists (select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'platform_notices'
        and column_name = 'audience_json') then
    raise object_not_in_prerequisite_state using
      message = 'superadmin notices v2 (20260910200000) is required';
  end if;
  if to_regprocedure('public.claim_notice_publication_jobs_for_worker(text,integer)') is not null
    or to_regprocedure('public.run_notice_publication_job_for_worker(uuid,integer)') is not null then
    raise object_not_in_prerequisite_state using
      message = 'notice publication worker already present; forward-only package must not be replayed';
  end if;
  if to_regclass('app_private.notice_publication_jobs') is not null
    or to_regprocedure('app_private.claim_notice_publication_jobs(text,integer)') is not null
    or to_regprocedure('app_private.materialize_notice_publication_job(uuid,integer)') is not null
    or to_regprocedure('app_private.run_notice_publication_job(uuid,integer)') is not null then
    raise object_not_in_prerequisite_state using
      message = 'legacy notice publication objects partially present; write a new forward-only package';
  end if;
end
$preflight$;

-- (a) Fila de materializacao. Mesma forma de 20260812003000 (FK restrict).
create table app_private.notice_publication_jobs (
  id uuid primary key default gen_random_uuid(),
  notice_id uuid not null references public.platform_notices(id) on delete restrict,
  notice_version bigint not null,
  audience_snapshot jsonb not null,
  state text not null default 'queued'
    check (state in ('queued', 'processing', 'completed', 'failed')),
  attempts integer not null default 0 check (attempts between 0 and 20),
  available_at timestamptz not null default now(),
  locked_at timestamptz,
  locked_by text,
  last_error_code text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  cursor_key text,
  resolved_count bigint not null default 0,
  unique (notice_id, notice_version)
);
create index notice_publication_jobs_claim_idx
  on app_private.notice_publication_jobs(state, available_at, created_at)
  where state in ('queued', 'failed');

alter table app_private.notice_publication_jobs enable row level security;
alter table app_private.notice_publication_jobs force row level security;
revoke all on table app_private.notice_publication_jobs
  from public, anon, authenticated, service_role;

-- Recibo de escopo plataforma (institution_id nulo) precisa de unicidade propria.
create unique index if not exists notice_receipts_platform_scope_uidx
  on public.notice_receipts(notice_id, person_id) where institution_id is null;

-- (b) Claim com recuperacao de lease expirado (20260820212340).
create function app_private.claim_notice_publication_jobs(
  p_worker text, p_limit integer default 20
) returns setof app_private.notice_publication_jobs
language plpgsql volatile security definer set search_path = '' as $$
begin
  if auth.role() is distinct from 'service_role'
    or p_limit not between 1 and 100
    or length(trim(coalesce(p_worker, ''))) not between 1 and 120 then
    raise exception using errcode = '42501', message = 'not_authorized';
  end if;

  update app_private.notice_publication_jobs
  set state = 'failed', available_at = now(), locked_at = null, locked_by = null,
      last_error_code = 'lease_expired'
  where state = 'processing'
    and locked_at < now() - interval '5 minutes'
    and attempts < 20;

  return query
  with claimed as (
    select id from app_private.notice_publication_jobs
    where state in ('queued', 'failed') and available_at <= now() and attempts < 20
    order by available_at, created_at
    for update skip locked
    limit p_limit
  )
  update app_private.notice_publication_jobs job
  set state = 'processing', attempts = job.attempts + 1, locked_at = now(),
      locked_by = trim(p_worker), last_error_code = null
  from claimed
  where job.id = claimed.id
  returning job.*;
end
$$;

-- (b) Materializacao paginada por cursor. Nao altera platform_notices.
create function app_private.materialize_notice_publication_job(
  p_job_id uuid, p_limit integer default 1000
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  job app_private.notice_publication_jobs;
  rule jsonb; dimension text; role_codes jsonb; plan_ids jsonb; excluded jsonb;
  search_term text; search_pattern text;
  page_count integer; last_key text;
begin
  if auth.role() is distinct from 'service_role' or p_limit not between 1 and 5000 then
    raise exception using errcode = '42501', message = 'not_authorized';
  end if;
  select * into job from app_private.notice_publication_jobs
  where id = p_job_id and state = 'processing' for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'publication_job_not_found';
  end if;

  rule := coalesce(job.audience_snapshot -> 'rules' -> 0, '{}'::jsonb);
  dimension := coalesce(rule ->> 'dimension', 'platform');
  role_codes := coalesce(job.audience_snapshot -> 'role_codes', '[]'::jsonb);
  plan_ids := coalesce(job.audience_snapshot -> 'plan_ids', '[]'::jsonb);
  excluded := coalesce(rule -> 'excluded_ids', '[]'::jsonb);
  search_term := nullif(trim(coalesce(rule -> 'filters' -> 'search' ->> 0, '')), '');
  search_pattern := case when search_term is null then null
    else '%' || replace(replace(replace(search_term, '\', '\\'), '%', '\%'), '_', '\_') || '%' end;

  with institutional_candidates as (
    select distinct membership.person_id, membership.institution_id,
      membership.person_id::text || ':' || membership.institution_id::text as recipient_key
    from public.institution_memberships membership
    where membership.status = 'active'::public.record_status
      and membership.revoked_at is null
      and (jsonb_array_length(coalesce(rule -> 'filters' -> 'institution_ids', '[]'::jsonb)) = 0
        or rule -> 'filters' -> 'institution_ids' ? membership.institution_id::text)
      and (jsonb_array_length(coalesce(rule -> 'filters' -> 'unit_ids', '[]'::jsonb)) = 0
        or rule -> 'filters' -> 'unit_ids' ? membership.scope_unit_id::text
        or exists (select 1 from public.groups filter_group
          where filter_group.id = membership.scope_group_id
            and rule -> 'filters' -> 'unit_ids' ? filter_group.unit_id::text))
      and (jsonb_array_length(role_codes) = 0 or role_codes ? membership.role_code)
      and (jsonb_array_length(plan_ids) = 0 or exists (
        select 1 from public.institution_subscriptions subscription
        where subscription.institution_id = membership.institution_id
          and subscription.status::text in ('active', 'trial')
          and plan_ids ? subscription.plan_id::text))
      and (search_pattern is null or case dimension
        when 'institution' then exists (select 1 from public.institutions institution
          where institution.id = membership.institution_id
            and institution.public_name ilike search_pattern escape '\')
        when 'unit' then exists (select 1 from public.units unit
          where (unit.id = membership.scope_unit_id or unit.id = (select scoped_group.unit_id
              from public.groups scoped_group where scoped_group.id = membership.scope_group_id))
            and unit.name ilike search_pattern escape '\')
        when 'group' then exists (select 1 from public.groups scoped_group
          where scoped_group.id = membership.scope_group_id
            and scoped_group.name ilike search_pattern escape '\')
        else true end)
      and case dimension
        when 'platform' then true
        when 'institution' then (
          (coalesce((rule ->> 'select_all')::boolean, false)
            or rule -> 'target_ids' ? membership.institution_id::text)
          and not (excluded ? membership.institution_id::text))
        when 'unit' then (
          (coalesce((rule ->> 'select_all')::boolean, false)
            or rule -> 'target_ids' ? membership.scope_unit_id::text
            or exists (select 1 from public.groups scoped_group
              where scoped_group.id = membership.scope_group_id
                and rule -> 'target_ids' ? scoped_group.unit_id::text))
          and not (excluded ? membership.scope_unit_id::text
            or exists (select 1 from public.groups scoped_group
              where scoped_group.id = membership.scope_group_id
                and excluded ? scoped_group.unit_id::text)))
        when 'group' then (
          (coalesce((rule ->> 'select_all')::boolean, false)
            or rule -> 'target_ids' ? membership.scope_group_id::text)
          and not (excluded ? membership.scope_group_id::text))
        else false end
  ), platform_candidates as (
    select distinct membership.person_id, null::uuid as institution_id,
      membership.person_id::text || ':platform' as recipient_key
    from public.platform_memberships membership
    where dimension = 'platform'
      and membership.status::text = 'active'
      and membership.revoked_at is null
      and jsonb_array_length(role_codes) = 0
  ), person_candidates as (
    select person.id as person_id, null::uuid as institution_id,
      person.id::text || ':person' as recipient_key
    from public.people person
    where dimension = 'person'
      and person.deleted_at is null
      and (coalesce((rule ->> 'select_all')::boolean, false) or rule -> 'target_ids' ? person.id::text)
      and not (excluded ? person.id::text)
      and (search_pattern is null or person.display_name ilike search_pattern escape '\')
  ), candidates as (
    select * from institutional_candidates
    union select * from platform_candidates
    union select * from person_candidates
  ), selected as (
    select * from candidates
    where job.cursor_key is null or recipient_key > job.cursor_key
    order by recipient_key limit p_limit
  ), inserted as (
    insert into public.notice_receipts(notice_id, person_id, institution_id)
    select job.notice_id, person_id, institution_id from selected
    on conflict do nothing returning 1
  )
  select count(*), max(recipient_key) into page_count, last_key from selected;

  update app_private.notice_publication_jobs
  set cursor_key = coalesce(last_key, cursor_key),
      resolved_count = resolved_count + page_count,
      state = case when page_count < p_limit then 'completed' else 'processing' end,
      completed_at = case when page_count < p_limit then now() else null end
  where id = job.id returning * into job;

  if page_count < p_limit then
    if job.resolved_count = 0 then
      update app_private.notice_publication_jobs
      set state = 'failed', last_error_code = 'empty_audience', completed_at = null,
          attempts = 20, locked_at = null, locked_by = null
      where id = job.id;
      insert into analytics.notice_events(notice_id, event_name, properties_json)
      values (job.notice_id, 'audience_empty', jsonb_build_object(
        'publication_job_id', job.id, 'notice_version', job.notice_version));
      return jsonb_build_object('state', 'failed', 'error_code', 'empty_audience');
    end if;
    update app_private.notice_publication_jobs
    set locked_at = null, locked_by = null where id = job.id;
    insert into analytics.notice_events(notice_id, event_name, properties_json)
    values (job.notice_id, 'audience_materialized', jsonb_build_object(
      'publication_job_id', job.id, 'notice_version', job.notice_version,
      'recipient_count', job.resolved_count));
  end if;
  return jsonb_build_object('state', job.state, 'resolved_count', job.resolved_count,
    'cursor_key', job.cursor_key);
end
$$;

-- (c) Entrada guardada do worker: valida o aviso e delega a materializacao.
create function app_private.run_notice_publication_job(
  p_job_id uuid, p_limit integer default 1000
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  job app_private.notice_publication_jobs;
  notice public.platform_notices;
  failure_code text;
begin
  if auth.role() is distinct from 'service_role' or p_limit not between 1 and 5000 then
    raise exception using errcode = '42501', message = 'not_authorized';
  end if;
  select * into job from app_private.notice_publication_jobs
  where id = p_job_id and state = 'processing' for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'publication_job_not_found';
  end if;
  select * into notice from public.platform_notices where id = job.notice_id for share;

  failure_code := case
    when notice.id is null then 'notice_missing'
    when exists (select 1 from app_private.notice_publication_jobs newer
      where newer.notice_id = job.notice_id and newer.notice_version > job.notice_version)
      then 'notice_superseded'
    when notice.ends_at is not null and notice.ends_at <= now() then 'notice_expired'
    when notice.status::text not in ('scheduled', 'active') then 'notice_not_publishable'
    else null end;
  if failure_code is not null then
    update app_private.notice_publication_jobs
    set state = 'failed', attempts = 20, completed_at = null, locked_at = null,
        locked_by = null, last_error_code = failure_code
    where id = job.id;
    return jsonb_build_object('state', 'failed', 'error_code', failure_code);
  end if;

  -- Primeira pagina: materializa a audiencia vigente do aviso e registra no job.
  if job.cursor_key is null and job.resolved_count = 0
    and notice.audience_json is distinct from job.audience_snapshot then
    update app_private.notice_publication_jobs
    set audience_snapshot = notice.audience_json where id = job.id;
  end if;
  return app_private.materialize_notice_publication_job(p_job_id, p_limit);
end
$$;

-- (c) Wrappers publicos com as assinaturas e retornos que index.ts consome.
create function public.claim_notice_publication_jobs_for_worker(
  p_worker text, p_limit integer default 20
) returns table(id uuid) language sql volatile security definer set search_path = '' as $$
  select claimed.id from app_private.claim_notice_publication_jobs(p_worker, p_limit) claimed;
$$;

create function public.run_notice_publication_job_for_worker(
  p_job_id uuid, p_limit integer default 1000
) returns jsonb language sql volatile security definer set search_path = '' as $$
  select app_private.run_notice_publication_job(p_job_id, p_limit);
$$;

alter function app_private.claim_notice_publication_jobs(text, integer) owner to postgres;
alter function app_private.materialize_notice_publication_job(uuid, integer) owner to postgres;
alter function app_private.run_notice_publication_job(uuid, integer) owner to postgres;
alter function public.claim_notice_publication_jobs_for_worker(text, integer) owner to postgres;
alter function public.run_notice_publication_job_for_worker(uuid, integer) owner to postgres;

revoke all on function app_private.claim_notice_publication_jobs(text, integer)
  from public, anon, authenticated, service_role;
revoke all on function app_private.materialize_notice_publication_job(uuid, integer)
  from public, anon, authenticated, service_role;
revoke all on function app_private.run_notice_publication_job(uuid, integer)
  from public, anon, authenticated, service_role;
revoke all on function public.claim_notice_publication_jobs_for_worker(text, integer)
  from public, anon, authenticated, service_role;
revoke all on function public.run_notice_publication_job_for_worker(uuid, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.claim_notice_publication_jobs_for_worker(text, integer)
  to service_role;
grant execute on function public.run_notice_publication_job_for_worker(uuid, integer)
  to service_role;

-- (d) Publicar enfileira o job. Texto de 20260910200000 + insert na fila.
create or replace function public.superadmin_notice_publish_v2(
  p_request_id uuid, p_notice_id uuid, p_expected_version bigint
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare context_record app_private.superadmin_internal_context;
  notice_record public.platform_notices%rowtype; cached_record record;
  correlation_id uuid := gen_random_uuid(); error_code text;
  request_hash bytea; result_json jsonb; next_status public.notice_status;
begin
  begin
    context_record := app_private.superadmin_notice_context('notices.publish');
    if p_request_id is null or p_notice_id is null or p_expected_version is null then
      raise invalid_parameter_value using message = 'publish command incomplete', detail = 'NOTICE_INVALID_INPUT';
    end if;
    request_hash := extensions.digest(p_notice_id::text || '|' || coalesce(p_expected_version::text, ''), 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(
      context_record.internal_identity_id::text || p_request_id::text || 'notice.publish', 0));
    select * into cached_record from app_private.superadmin_notice_command_receipts
      where internal_identity_id = context_record.internal_identity_id
        and request_id = p_request_id and action_code = 'publish';
    if cached_record.request_id is not null then
      if cached_record.request_hash <> request_hash then
        raise unique_violation using message = 'idempotency conflict', detail = 'NOTICE_CONFLICT';
      end if;
      return cached_record.result_json;
    end if;
    select * into notice_record from public.platform_notices where id = p_notice_id for update;
    if notice_record.id is null then
      raise no_data_found using message = 'notice unavailable', detail = 'NOTICE_NOT_FOUND';
    end if;
    if notice_record.management_version <> p_expected_version then
      raise serialization_failure using message = 'version conflict', detail = 'NOTICE_CONFLICT';
    end if;
    if notice_record.status::text <> 'draft' then
      raise object_not_in_prerequisite_state using message = 'notice cannot be published',
        detail = case when notice_record.status::text in ('expired', 'inactive')
          then 'NOTICE_TERMINAL' else 'NOTICE_INVALID_TRANSITION' end;
    end if;
    if notice_record.content_format <> 'text_background' then
      raise invalid_parameter_value using message = 'notice media blocked', detail = 'NOTICE_MEDIA_BLOCKED';
    end if;
    if notice_record.ends_at is not null and notice_record.ends_at <= clock_timestamp() then
      raise invalid_parameter_value using message = 'notice already ended', detail = 'NOTICE_INVALID_INPUT';
    end if;
    next_status := case when notice_record.starts_at > clock_timestamp()
      then 'scheduled'::public.notice_status else 'active'::public.notice_status end;
    update public.platform_notices set status = next_status,
      published_at = case when next_status::text = 'active' then clock_timestamp() else null end,
      published_by_internal_identity_id = context_record.internal_identity_id,
      updated_by_internal_identity_id = context_record.internal_identity_id,
      management_version = management_version + 1, updated_at = clock_timestamp()
    where id = p_notice_id returning * into notice_record;
    insert into app_private.notice_publication_jobs(
      notice_id, notice_version, audience_snapshot, available_at
    ) values (notice_record.id, notice_record.management_version, notice_record.audience_json,
      greatest(coalesce(notice_record.starts_at, now()), now()))
    on conflict do nothing;
    result_json := jsonb_build_object('ok', true,
      'data', app_private.superadmin_notice_json(notice_record), 'error', null);
    insert into app_private.superadmin_notice_command_receipts(
      internal_identity_id, request_id, action_code, request_hash, result_json
    ) values (context_record.internal_identity_id, p_request_id, 'publish', request_hash, result_json);
    perform app_private.superadmin_notice_append_audit(context_record, 'notice.publish',
      notice_record.id, 'success', null, correlation_id);
    return result_json;
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    return app_private.superadmin_notice_denied(
      'notices.publish', 'notice.publish', error_code, correlation_id);
  end;
end
$$;

-- (d) Reagendar (pausado -> scheduled/active) enfileira o job.
create or replace function public.superadmin_notice_change_status_v2(
  p_request_id uuid, p_notice_id uuid, p_expected_version bigint,
  p_status text, p_reason text default null
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare context_record app_private.superadmin_internal_context;
  notice_record public.platform_notices%rowtype; cached_record record;
  correlation_id uuid := gen_random_uuid(); error_code text;
  request_hash bytea; result_json jsonb; target_status public.notice_status;
begin
  begin
    context_record := app_private.superadmin_notice_context('notices.publish');
    if p_request_id is null or p_notice_id is null or p_expected_version is null then
      raise invalid_parameter_value using message = 'status command incomplete', detail = 'NOTICE_INVALID_INPUT';
    end if;
    if p_status not in ('paused', 'scheduled', 'inactive')
      or (p_status = 'inactive' and char_length(btrim(coalesce(p_reason, ''))) not between 3 and 500) then
      raise invalid_parameter_value using message = 'invalid status command', detail = 'NOTICE_INVALID_INPUT';
    end if;
    request_hash := extensions.digest(p_notice_id::text || '|' || coalesce(p_expected_version::text, '') ||
      '|' || p_status || '|' || coalesce(btrim(p_reason), ''), 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(
      context_record.internal_identity_id::text || p_request_id::text || 'notice.status', 0));
    select * into cached_record from app_private.superadmin_notice_command_receipts
      where internal_identity_id = context_record.internal_identity_id
        and request_id = p_request_id and action_code = 'status';
    if cached_record.request_id is not null then
      if cached_record.request_hash <> request_hash then
        raise unique_violation using message = 'idempotency conflict', detail = 'NOTICE_CONFLICT';
      end if;
      return cached_record.result_json;
    end if;
    select * into notice_record from public.platform_notices where id = p_notice_id for update;
    if notice_record.id is null then
      raise no_data_found using message = 'notice unavailable', detail = 'NOTICE_NOT_FOUND';
    end if;
    if notice_record.management_version <> p_expected_version then
      raise serialization_failure using message = 'version conflict', detail = 'NOTICE_CONFLICT';
    end if;
    if notice_record.status::text in ('expired', 'inactive') then
      raise object_not_in_prerequisite_state using message = 'terminal notice state', detail = 'NOTICE_TERMINAL';
    end if;
    if (p_status = 'paused' and notice_record.status::text <> 'active')
      or (p_status = 'scheduled' and notice_record.status::text <> 'paused') then
      raise object_not_in_prerequisite_state using message = 'invalid notice transition', detail = 'NOTICE_INVALID_TRANSITION';
    end if;
    target_status := case
      when p_status = 'scheduled' and notice_record.starts_at <= clock_timestamp()
        then 'active'::public.notice_status
      else p_status::public.notice_status end;
    update public.platform_notices set status = target_status,
      published_at = case when target_status::text = 'active'
        then coalesce(published_at, clock_timestamp()) else published_at end,
      silencing_policy = case when p_status = 'inactive'
        then silencing_policy || jsonb_build_object('inactive_reason', left(btrim(p_reason), 500))
        else silencing_policy end,
      management_version = management_version + 1,
      updated_by_internal_identity_id = context_record.internal_identity_id,
      updated_at = clock_timestamp()
    where id = p_notice_id returning * into notice_record;
    if p_status = 'scheduled' then
      insert into app_private.notice_publication_jobs(
        notice_id, notice_version, audience_snapshot, available_at
      ) values (notice_record.id, notice_record.management_version, notice_record.audience_json,
        greatest(coalesce(notice_record.starts_at, now()), now()))
      on conflict do nothing;
    end if;
    result_json := jsonb_build_object('ok', true,
      'data', app_private.superadmin_notice_json(notice_record), 'error', null);
    insert into app_private.superadmin_notice_command_receipts(
      internal_identity_id, request_id, action_code, request_hash, result_json
    ) values (context_record.internal_identity_id, p_request_id, 'status', request_hash, result_json);
    perform app_private.superadmin_notice_append_audit(context_record,
      'notice.status.' || p_status, notice_record.id, 'success',
      case when p_status = 'inactive' then 'NOTICE_INACTIVE_REASON_RECORDED' else null end,
      correlation_id);
    return result_json;
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    return app_private.superadmin_notice_denied(
      'notices.publish', 'notice.status.' || coalesce(p_status, 'invalid'),
      error_code, correlation_id);
  end;
end
$$;

-- CREATE OR REPLACE preserva a ACL de 20260910200000; reafirmada por clareza.
alter function public.superadmin_notice_publish_v2(uuid, uuid, bigint) owner to postgres;
alter function public.superadmin_notice_change_status_v2(uuid, uuid, bigint, text, text) owner to postgres;
revoke all on function public.superadmin_notice_publish_v2(uuid, uuid, bigint)
  from public, anon, authenticated, service_role;
revoke all on function public.superadmin_notice_change_status_v2(uuid, uuid, bigint, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_notice_publish_v2(uuid, uuid, bigint) to authenticated;
grant execute on function public.superadmin_notice_change_status_v2(uuid, uuid, bigint, text, text)
  to authenticated;

commit;
