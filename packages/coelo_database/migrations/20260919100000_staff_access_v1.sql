-- 20260919100000_staff_access_v1
--
-- Etapa 3, F7 (ADR 0035 "Acesso contextual de funcionarios"; ADR 0045 item 3). Sessao ACESSO-CONTEXTUAL, 19/09/2026.
--
-- A regra pertence ao VINCULO PROFISSIONAL (public.institution_memberships de papel de equipe), nunca
-- a pessoa, ao @ ou a sessao. Horario, vigencia e afastamento governam a autorizacao NO SERVIDOR:
-- app_private.has_context_permission (base de todas as RLS/RPCs contextuais) e
-- app_private.has_active_institution_membership passam a ignorar a membership bloqueada agora.
-- O popup e so informativo: desliga-lo nao desliga a restricao.
--
-- O que este pacote cria, forward-only e idempotente:
--   1. Capacidade institution 'staff_access.manage' (modulo Acessos), concedida ao papel de sistema
--      institution_admin. Escopo = o vinculo estar sob a hierarquia do ator (unidade do vinculo).
--   2. public.staff_access_rules (1 por vinculo): superficies liberadas, janelas por dia da semana
--      (podem cruzar meia-noite; pertencem ao dia de inicio), vigencia inclusiva (de/ate) com suas
--      superficies, popup, versao, auditoria. RLS deny-by-default; leitura pela hierarquia
--      (staff_access.manage) ou pelo proprio titular; escrita so por RPC.
--   3. public.staff_leaves (n por vinculo): afastamento de/ate inclusivo, popup, motivo interno,
--      versao. Mesma RLS.
--   4. app_private.staff_access_evaluate(membership, superficie, instante): fuso da unidade
--      (fallback instituicao, fallback America/Sao_Paulo); precedencia afastamento > vigencia >
--      horario > superficie; sem configuracao = liberado. app_private.staff_access_blocked(membership)
--      usa a superficie declarada no header x-coelo-surface (fallback 'web'; o servidor nao consegue
--      verificar a superficie: limite documentado) e now().
--   5. RPCs: staff_access_list_v1, staff_access_rule_get_v1, staff_access_rule_save_v1,
--      staff_leaves_list_v1, staff_leave_save_v1, staff_access_check_v1. Versao defasada =
--      errcode PT409 / detail STAFF_ACCESS_STALE_VERSION (nunca 40001, OQ-047). Auditoria em
--      audit.audit_logs (hash v1) de toda alteracao administrativa.
--   6. public.list_my_principal_contexts passa a projetar access_blocked/access_reason/access_popup
--      para o vinculo bloqueado, sem expor dados do contexto; a troca de contexto continua disponivel.
-- Vinculos de responsavel/aluno (role_code guardian/student) e pessoas de servico (espelhos internos)
-- nunca recebem regra pela RPC. Nada e concedido a anon.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if to_regprocedure('app_private.has_context_permission(uuid,text,uuid,uuid,uuid,uuid,boolean)') is null
    or to_regprocedure('app_private.has_active_institution_membership(uuid)') is null
    or to_regprocedure('public.list_my_principal_contexts()') is null
    or to_regprocedure('app_private.current_person_id()') is null
    or to_regprocedure('app_private.person_id_for_auth_user(uuid)') is null
    or to_regclass('public.institution_memberships') is null
    or not exists (select 1 from public.institution_roles where code = 'institution_admin' and is_system and institution_id is null) then
    raise exception 'staff_access_v1: cadeia exigida ausente (baseline, 20260911130000, 20260911130100, 20260910171600)';
  end if;
end
$preflight$;

-- 1. capacidade -----------------------------------------------------------------------------------
insert into public.institution_permissions(
  code, module_code, module_label, screen_code, screen_label,
  action_code, action_label, description, risk_level, requires_mfa
) values
  ('staff_access.manage','access','Acessos','staff_access','Acesso de funcionarios',
   'manage','Gerenciar','Configurar horario, vigencia, superficies, afastamentos e popups do acesso de funcionarios no escopo contextual.','high',false)
on conflict (code) do update set
  module_code = excluded.module_code, module_label = excluded.module_label,
  screen_code = excluded.screen_code, screen_label = excluded.screen_label,
  action_code = excluded.action_code, action_label = excluded.action_label,
  description = excluded.description, status = 'active', updated_at = now();

insert into public.institution_role_permissions (role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow', 'active'
from public.institution_roles role_record
join public.institution_permissions permission_record on permission_record.code = 'staff_access.manage'
where role_record.code = 'institution_admin' and role_record.is_system and role_record.institution_id is null
on conflict (role_id, permission_id) do update set effect = 'allow', status = 'active', revoked_at = null;

-- 2. tabelas --------------------------------------------------------------------------------------
create table if not exists public.staff_access_rules (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null unique references public.institution_memberships(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  surfaces text[] not null default array['web','mobile_web','tablet_web','installed_app'],
  windows jsonb not null default '[]'::jsonb,
  valid_from date,
  valid_until date,
  validity_surfaces text[] not null default array['web','mobile_web','tablet_web','installed_app'],
  popup_enabled boolean not null default false,
  popup_show_validity boolean not null default false,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.people(id),
  updated_by uuid references public.people(id),
  constraint staff_access_rules_validity_check check (valid_from is null or valid_until is null or valid_until >= valid_from),
  constraint staff_access_rules_surfaces_check check (surfaces <@ array['web','mobile_web','tablet_web','installed_app']),
  constraint staff_access_rules_validity_surfaces_check check (validity_surfaces <@ array['web','mobile_web','tablet_web','installed_app']),
  constraint staff_access_rules_version_check check (version > 0),
  constraint staff_access_rules_windows_array_check check (jsonb_typeof(windows) = 'array')
);
create index if not exists staff_access_rules_institution_idx on public.staff_access_rules(institution_id);

create table if not exists public.staff_leaves (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null references public.institution_memberships(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  starts_on date not null,
  ends_on date not null,
  popup_enabled boolean not null default false,
  internal_note text,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.people(id),
  updated_by uuid references public.people(id),
  constraint staff_leaves_period_check check (ends_on >= starts_on),
  constraint staff_leaves_version_check check (version > 0),
  constraint staff_leaves_note_check check (internal_note is null or length(internal_note) <= 500)
);
create index if not exists staff_leaves_membership_idx on public.staff_leaves(membership_id, starts_on, ends_on);
create index if not exists staff_leaves_institution_idx on public.staff_leaves(institution_id);

alter table public.staff_access_rules enable row level security;
alter table public.staff_access_rules force row level security;
alter table public.staff_leaves enable row level security;
alter table public.staff_leaves force row level security;
revoke all on public.staff_access_rules from public, anon, authenticated;
revoke all on public.staff_leaves from public, anon, authenticated;
grant select on public.staff_access_rules to authenticated;
grant select on public.staff_leaves to authenticated;

-- 3. validacao das janelas ------------------------------------------------------------------------
-- windows: [{"weekday":1..7 (ISO, 1 = segunda), "start":"HH:MM", "end":"HH:MM"}]. end <= start cruza
-- meia-noite e pertence ao dia de inicio (22:00-02:00 de sexta vale ate 02:00 de sabado).
create or replace function app_private.staff_access_normalize_windows(p_windows jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  item jsonb;
  result jsonb := '[]'::jsonb;
  v_weekday integer;
  v_start text;
  v_end text;
begin
  if p_windows is null or jsonb_typeof(p_windows) = 'null' then
    return '[]'::jsonb;
  end if;
  if jsonb_typeof(p_windows) <> 'array' then
    raise invalid_parameter_value using message = 'STAFF_ACCESS_WINDOWS_INVALID';
  end if;
  if jsonb_array_length(p_windows) > 70 then
    raise invalid_parameter_value using message = 'STAFF_ACCESS_WINDOWS_TOO_MANY';
  end if;
  for item in select value from jsonb_array_elements(p_windows) loop
    if jsonb_typeof(item) <> 'object' then
      raise invalid_parameter_value using message = 'STAFF_ACCESS_WINDOWS_INVALID';
    end if;
    begin
      v_weekday := (item ->> 'weekday')::integer;
    exception when others then
      raise invalid_parameter_value using message = 'STAFF_ACCESS_WINDOW_WEEKDAY_INVALID';
    end;
    if v_weekday is null or v_weekday < 1 or v_weekday > 7 then
      raise invalid_parameter_value using message = 'STAFF_ACCESS_WINDOW_WEEKDAY_INVALID';
    end if;
    v_start := item ->> 'start';
    v_end := item ->> 'end';
    if v_start !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' or v_end !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
      raise invalid_parameter_value using message = 'STAFF_ACCESS_WINDOW_TIME_INVALID';
    end if;
    if v_start = v_end then
      raise invalid_parameter_value using message = 'STAFF_ACCESS_WINDOW_EMPTY';
    end if;
    result := result || jsonb_build_object('weekday', v_weekday, 'start', v_start, 'end', v_end);
  end loop;
  return result;
end
$$;
revoke all on function app_private.staff_access_normalize_windows(jsonb) from public, anon, authenticated;

-- 4. avaliacao ------------------------------------------------------------------------------------
create or replace function app_private.staff_access_timezone(p_membership_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(unit_record.timezone, institution.timezone, 'America/Sao_Paulo')
  from public.institution_memberships membership
  join public.institutions institution on institution.id = membership.institution_id
  left join public.groups scoped_group on scoped_group.id = membership.scope_group_id
  left join public.units unit_record on unit_record.id = coalesce(membership.scope_unit_id, scoped_group.unit_id)
  where membership.id = p_membership_id
$$;
revoke all on function app_private.staff_access_timezone(uuid) from public, anon, authenticated;

-- allowed + reason (leave|validity|schedule|surface|null) + regra + afastamento vigente.
create or replace function app_private.staff_access_evaluate(
  p_membership_id uuid,
  p_surface text default 'web',
  p_at timestamptz default now()
)
returns table(allowed boolean, reason text, rule_id uuid, leave_id uuid)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_rule public.staff_access_rules%rowtype;
  v_leave public.staff_leaves%rowtype;
  v_tz text;
  v_local timestamp;
  v_date date;
  v_dow integer;
  v_prev_dow integer;
  v_minute integer;
  v_surface text := coalesce(nullif(btrim(p_surface), ''), 'web');
  v_window jsonb;
  v_start integer;
  v_end integer;
  v_inside boolean := false;
begin
  if v_surface not in ('web','mobile_web','tablet_web','installed_app') then
    v_surface := 'web';
  end if;
  select * into v_rule from public.staff_access_rules where membership_id = p_membership_id;
  if not exists (select 1 from public.staff_leaves where membership_id = p_membership_id) and v_rule.id is null then
    return query select true, null::text, null::uuid, null::uuid;
    return;
  end if;

  v_tz := coalesce(app_private.staff_access_timezone(p_membership_id), 'America/Sao_Paulo');
  v_local := p_at at time zone v_tz;
  v_date := v_local::date;

  -- afastamento > tudo (datas inclusivas nas duas pontas, no fuso do vinculo)
  select * into v_leave from public.staff_leaves
  where membership_id = p_membership_id and starts_on <= v_date and ends_on >= v_date
  order by starts_on, id limit 1;
  if v_leave.id is not null then
    return query select false, 'leave'::text, v_rule.id, v_leave.id;
    return;
  end if;
  if v_rule.id is null then
    return query select true, null::text, null::uuid, null::uuid;
    return;
  end if;

  -- vigencia (inclusiva) > horario, apenas nas superficies a que ela se aplica
  if v_surface = any(v_rule.validity_surfaces) and (
       (v_rule.valid_from is not null and v_date < v_rule.valid_from)
    or (v_rule.valid_until is not null and v_date > v_rule.valid_until)) then
    return query select false, 'validity'::text, v_rule.id, null::uuid;
    return;
  end if;

  -- horario: sem janelas = liberado; janela que cruza meia-noite pertence ao dia de inicio
  if jsonb_array_length(v_rule.windows) > 0 then
    v_dow := extract(isodow from v_date)::integer;
    v_prev_dow := case when v_dow = 1 then 7 else v_dow - 1 end;
    v_minute := extract(hour from v_local)::integer * 60 + extract(minute from v_local)::integer;
    for v_window in select value from jsonb_array_elements(v_rule.windows) loop
      v_start := split_part(v_window ->> 'start', ':', 1)::integer * 60 + split_part(v_window ->> 'start', ':', 2)::integer;
      v_end := split_part(v_window ->> 'end', ':', 1)::integer * 60 + split_part(v_window ->> 'end', ':', 2)::integer;
      if v_end > v_start then
        if (v_window ->> 'weekday')::integer = v_dow and v_minute >= v_start and v_minute < v_end then
          v_inside := true; exit;
        end if;
      else
        if ((v_window ->> 'weekday')::integer = v_dow and v_minute >= v_start)
           or ((v_window ->> 'weekday')::integer = v_prev_dow and v_minute < v_end) then
          v_inside := true; exit;
        end if;
      end if;
    end loop;
    if not v_inside then
      return query select false, 'schedule'::text, v_rule.id, null::uuid;
      return;
    end if;
  end if;

  -- superficie
  if not (v_surface = any(v_rule.surfaces)) then
    return query select false, 'surface'::text, v_rule.id, null::uuid;
    return;
  end if;

  return query select true, null::text, v_rule.id, null::uuid;
end
$$;
revoke all on function app_private.staff_access_evaluate(uuid, text, timestamptz) from public, anon, authenticated;

-- Superficie declarada pelo cliente no header x-coelo-surface. Limite: o servidor nao consegue
-- verificar a superficie real; o que ele garante e que a regra valha para a superficie declarada e
-- que web (o padrao) seja sempre a mais restrita a ser negada quando nao declarada.
create or replace function app_private.staff_access_request_surface()
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v_headers text;
  v_surface text;
begin
  begin
    v_headers := current_setting('request.headers', true);
    if v_headers is not null and v_headers <> '' then
      v_surface := lower(btrim(coalesce((v_headers::jsonb) ->> 'x-coelo-surface', '')));
    end if;
  exception when others then
    v_surface := null;
  end;
  if v_surface in ('web','mobile_web','tablet_web','installed_app') then
    return v_surface;
  end if;
  return 'web';
end
$$;
revoke all on function app_private.staff_access_request_surface() from public, anon, authenticated;

create or replace function app_private.staff_access_blocked(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select not evaluation.allowed
    from app_private.staff_access_evaluate(p_membership_id, app_private.staff_access_request_surface(), now()) evaluation
  ), false)
$$;
revoke all on function app_private.staff_access_blocked(uuid) from public, anon, authenticated;

-- 5. enforcement no nucleo da autorizacao contextual --------------------------------------------
-- Corpo vigente (baseline 20260910000000) com uma unica linha a mais na CTE active_memberships.
CREATE OR REPLACE FUNCTION "app_private"."has_context_permission"("target_institution_id" "uuid", "target_permission_code" "text", "target_unit_id" "uuid" DEFAULT NULL::"uuid", "target_group_id" "uuid" DEFAULT NULL::"uuid", "target_activity_id" "uuid" DEFAULT NULL::"uuid", "target_child_context_id" "uuid" DEFAULT NULL::"uuid", "require_institution_scope" boolean DEFAULT false) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with active_memberships as(
    select membership.id from public.institution_memberships membership
    where membership.person_id=app_private.current_person_id()
      and membership.institution_id=target_institution_id and membership.status='active'
      and membership.revoked_at is null
      and not app_private.staff_access_blocked(membership.id)
  ),role_effects as(
    select role_permission.effect from active_memberships membership
    join public.institution_role_assignments assignment on assignment.membership_id=membership.id
      and assignment.status='active' and (assignment.starts_at is null or assignment.starts_at<=now())
      and (assignment.expires_at is null or assignment.expires_at>now())
    join public.institution_roles role_record on role_record.id=assignment.role_id
      and role_record.status='active' and (role_record.institution_id is null or role_record.institution_id=target_institution_id)
    join public.institution_role_permissions role_permission on role_permission.role_id=role_record.id
      and role_permission.status='active' and role_permission.revoked_at is null
    join public.institution_permissions permission_record on permission_record.id=role_permission.permission_id
      and permission_record.code=target_permission_code and permission_record.status='active'
    where (require_institution_scope and assignment.scope_kind='institution') or
      (not require_institution_scope and (assignment.scope_kind='institution'
        or (assignment.scope_kind='unit' and assignment.scope_unit_id=target_unit_id)
        or (assignment.scope_kind='group' and assignment.scope_group_id=target_group_id
          and (target_unit_id is null or assignment.scope_unit_id=target_unit_id))))
  ),individual_effects as(
    select override_record.effect from active_memberships membership
    join public.institution_member_permission_overrides override_record on override_record.membership_id=membership.id
      and override_record.institution_id=target_institution_id
      and override_record.permission_code=target_permission_code
      and override_record.status='active' and override_record.revoked_at is null
      and (override_record.starts_at is null or override_record.starts_at<=now())
      and (override_record.expires_at is null or override_record.expires_at>now())
    where (require_institution_scope and override_record.scope_kind='institution') or
      (not require_institution_scope and (override_record.scope_kind='institution'
        or (override_record.scope_kind='unit' and override_record.scope_unit_id=target_unit_id)
        or (override_record.scope_kind='group' and override_record.scope_group_id=target_group_id
          and (target_unit_id is null or override_record.scope_unit_id=target_unit_id))))
  )
  select not exists(select 1 from individual_effects where effect='deny')
    and not exists(select 1 from role_effects where effect='deny')
    and (exists(select 1 from individual_effects where effect='allow')
      or exists(select 1 from role_effects where effect='allow'))
$$;

CREATE OR REPLACE FUNCTION "app_private"."has_active_institution_membership"("target_institution_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select coalesce(exists (
    select 1
    from public.institution_memberships membership
    where membership.person_id = app_private.current_person_id()
      and membership.institution_id = target_institution_id
      and membership.status = 'active'
      and membership.revoked_at is null
      and not app_private.staff_access_blocked(membership.id)
  ), false)
$$;

-- 6. RLS: leitura pela hierarquia (staff_access.manage no escopo do vinculo) ou pelo titular ----
create or replace function app_private.staff_access_can_manage(p_membership_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select app_private.has_institution_permission(
      membership.institution_id, 'staff_access.manage',
      coalesce(membership.scope_unit_id, scoped_group.unit_id), null, false)
    from public.institution_memberships membership
    left join public.groups scoped_group on scoped_group.id = membership.scope_group_id
    where membership.id = p_membership_id
  ), false)
$$;
-- Usada dentro das policies (executam como o chamador): precisa de execute para authenticated, como has_context_permission.
revoke all on function app_private.staff_access_can_manage(uuid) from public, anon;
grant execute on function app_private.staff_access_can_manage(uuid) to authenticated;

drop policy if exists staff_access_rules_read on public.staff_access_rules;
create policy staff_access_rules_read on public.staff_access_rules for select to authenticated
using (
  app_private.staff_access_can_manage(membership_id)
  or exists (select 1 from public.institution_memberships membership
             where membership.id = staff_access_rules.membership_id
               and membership.person_id = app_private.current_person_id())
);
drop policy if exists staff_leaves_read on public.staff_leaves;
create policy staff_leaves_read on public.staff_leaves for select to authenticated
using (
  app_private.staff_access_can_manage(membership_id)
  or exists (select 1 from public.institution_memberships membership
             where membership.id = staff_leaves.membership_id
               and membership.person_id = app_private.current_person_id())
);

-- 7. projecoes ------------------------------------------------------------------------------------
create or replace function app_private.staff_access_rule_json(p_rule public.staff_access_rules)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case when p_rule.id is null then null else jsonb_build_object(
    'id', p_rule.id,
    'membership_id', p_rule.membership_id,
    'surfaces', to_jsonb(p_rule.surfaces),
    'windows', p_rule.windows,
    'valid_from', p_rule.valid_from,
    'valid_until', p_rule.valid_until,
    'validity_surfaces', to_jsonb(p_rule.validity_surfaces),
    'popup_enabled', p_rule.popup_enabled,
    'popup_show_validity', p_rule.popup_show_validity,
    'version', p_rule.version,
    'updated_at', p_rule.updated_at
  ) end
$$;
revoke all on function app_private.staff_access_rule_json(public.staff_access_rules) from public, anon, authenticated;

create or replace function app_private.staff_leave_json(p_leave public.staff_leaves)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case when p_leave.id is null then null else jsonb_build_object(
    'id', p_leave.id,
    'membership_id', p_leave.membership_id,
    'starts_on', p_leave.starts_on,
    'ends_on', p_leave.ends_on,
    'popup_enabled', p_leave.popup_enabled,
    'internal_note', p_leave.internal_note,
    'version', p_leave.version,
    'updated_at', p_leave.updated_at
  ) end
$$;
revoke all on function app_private.staff_leave_json(public.staff_leaves) from public, anon, authenticated;

-- Popup: texto fixo no cliente a partir destes dados; so quando o popup esta ligado.
create or replace function app_private.staff_access_popup_json(p_membership_id uuid, p_reason text, p_rule_id uuid, p_leave_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_reason = 'leave' then (
      select case when leave_record.popup_enabled then jsonb_build_object(
        'kind', 'leave', 'leave_from', leave_record.starts_on, 'leave_until', leave_record.ends_on) end
      from public.staff_leaves leave_record where leave_record.id = p_leave_id)
    when p_reason in ('validity','schedule','surface') then (
      select case when rule_record.popup_enabled then jsonb_build_object(
        'kind', p_reason,
        'windows', rule_record.windows,
        'surfaces', to_jsonb(rule_record.surfaces),
        'valid_from', case when rule_record.popup_show_validity then rule_record.valid_from end,
        'valid_until', case when rule_record.popup_show_validity then rule_record.valid_until end,
        'timezone', app_private.staff_access_timezone(p_membership_id)) end
      from public.staff_access_rules rule_record where rule_record.id = p_rule_id)
    else null end
$$;
revoke all on function app_private.staff_access_popup_json(uuid, text, uuid, uuid) from public, anon, authenticated;

-- Estado do vinculo para o diretorio: free | schedule | validity | leave | blocked_now.
create or replace function app_private.staff_access_state(p_membership_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when exists (select 1 from app_private.staff_access_evaluate(p_membership_id, 'web', now()) e where not e.allowed) then 'blocked_now'
    when exists (select 1 from public.staff_leaves l where l.membership_id = p_membership_id and l.ends_on >= (now() at time zone coalesce(app_private.staff_access_timezone(p_membership_id),'America/Sao_Paulo'))::date) then 'leave'
    when exists (select 1 from public.staff_access_rules r where r.membership_id = p_membership_id and (r.valid_from is not null or r.valid_until is not null)) then 'validity'
    when exists (select 1 from public.staff_access_rules r where r.membership_id = p_membership_id and (jsonb_array_length(r.windows) > 0 or cardinality(r.surfaces) < 4)) then 'schedule'
    else 'free' end
$$;
revoke all on function app_private.staff_access_state(uuid) from public, anon, authenticated;

-- 8. RPCs -----------------------------------------------------------------------------------------
create or replace function app_private.staff_access_require_actor()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication_required';
  end if;
  v_actor := app_private.current_person_id();
  if v_actor is null then
    raise insufficient_privilege using message = 'STAFF_ACCESS_ACTOR_REQUIRED';
  end if;
  return v_actor;
end
$$;
revoke all on function app_private.staff_access_require_actor() from public, anon, authenticated;

-- Vinculo de equipe elegivel: pessoa adulta, papel de equipe (nao guardian/student), membership ativa.
create or replace function app_private.staff_access_require_membership(p_membership_id uuid, p_for_write boolean)
returns public.institution_memberships
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_membership public.institution_memberships%rowtype;
  v_person_type text;
begin
  select * into v_membership from public.institution_memberships where id = p_membership_id;
  if v_membership.id is null then
    raise no_data_found using message = 'STAFF_ACCESS_MEMBERSHIP_NOT_FOUND';
  end if;
  if not app_private.staff_access_can_manage(p_membership_id) then
    raise insufficient_privilege using message = 'STAFF_ACCESS_FORBIDDEN';
  end if;
  if p_for_write then
    select person_type::text into v_person_type from public.people where id = v_membership.person_id;
    if v_membership.role_code in ('guardian','student') then
      raise invalid_parameter_value using message = 'STAFF_ACCESS_NOT_STAFF_MEMBERSHIP';
    end if;
    if v_person_type is distinct from 'adult' then
      raise invalid_parameter_value using message = 'STAFF_ACCESS_SERVICE_PERSON';
    end if;
    if v_membership.status <> 'active' or v_membership.revoked_at is not null then
      raise invalid_parameter_value using message = 'STAFF_ACCESS_MEMBERSHIP_INACTIVE';
    end if;
  end if;
  return v_membership;
end
$$;
revoke all on function app_private.staff_access_require_membership(uuid, boolean) from public, anon, authenticated;

-- Item do diretorio (uma linha por vinculo).
create or replace function app_private.staff_access_item_json(p_membership_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'membership_id', membership.id,
    'person_id', person.id,
    'person_name', person.display_name,
    'role_code', membership.role_code,
    'role_name', coalesce((select r.name from public.institution_roles r where r.code = membership.role_code and (r.institution_id = membership.institution_id or r.institution_id is null) order by r.institution_id nulls last limit 1), membership.role_code),
    'institution_id', institution.id,
    'institution_name', institution.public_name,
    'unit_id', unit_record.id,
    'unit_name', unit_record.name,
    'group_id', scoped_group.id,
    'group_name', scoped_group.name,
    'timezone', coalesce(unit_record.timezone, institution.timezone, 'America/Sao_Paulo'),
    'membership_status', membership.status,
    'state', app_private.staff_access_state(membership.id),
    'rule', (select app_private.staff_access_rule_json(r) from public.staff_access_rules r where r.membership_id = membership.id),
    'current_leave', (select app_private.staff_leave_json(l) from public.staff_leaves l
                      where l.membership_id = membership.id
                        and l.starts_on <= (now() at time zone coalesce(unit_record.timezone, institution.timezone, 'America/Sao_Paulo'))::date
                        and l.ends_on >= (now() at time zone coalesce(unit_record.timezone, institution.timezone, 'America/Sao_Paulo'))::date
                      order by l.starts_on limit 1),
    'leaves_count', (select count(*) from public.staff_leaves l where l.membership_id = membership.id),
    'can_manage', app_private.staff_access_can_manage(membership.id)
  )
  from public.institution_memberships membership
  join public.people person on person.id = membership.person_id
  join public.institutions institution on institution.id = membership.institution_id
  left join public.groups scoped_group on scoped_group.id = membership.scope_group_id
  left join public.units unit_record on unit_record.id = coalesce(membership.scope_unit_id, scoped_group.unit_id)
  where membership.id = p_membership_id
$$;
revoke all on function app_private.staff_access_item_json(uuid) from public, anon, authenticated;

create or replace function public.staff_access_list_v1(
  p_search text default null,
  p_institution_id uuid default null,
  p_unit_id uuid default null,
  p_states text[] default null,
  p_page integer default 1,
  p_page_size integer default 20
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.staff_access_require_actor();
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_size integer := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_total integer;
  v_items jsonb;
begin
  if v_search is not null and length(v_search) < 2 then
    raise invalid_parameter_value using message = 'STAFF_ACCESS_SEARCH_TOO_SHORT';
  end if;
  with filtered as (
    select membership.id as membership_id, person.display_name as sort_name, institution.public_name as sort_inst
    from public.institution_memberships membership
    join public.people person on person.id = membership.person_id and person.person_type = 'adult'
    join public.institutions institution on institution.id = membership.institution_id
    left join public.groups scoped_group on scoped_group.id = membership.scope_group_id
    where membership.status = 'active' and membership.revoked_at is null
      and membership.role_code not in ('guardian','student')
      and (p_institution_id is null or membership.institution_id = p_institution_id)
      and (p_unit_id is null or coalesce(membership.scope_unit_id, scoped_group.unit_id) = p_unit_id)
      and (v_search is null or person.display_name ilike '%' || v_search || '%')
      and app_private.staff_access_can_manage(membership.id)
      and (p_states is null or cardinality(p_states) = 0 or app_private.staff_access_state(membership.id) = any(p_states))
  ), paged as (
    select * from filtered order by sort_inst, sort_name, membership_id limit v_size offset (v_page - 1) * v_size
  )
  select (select count(*) from filtered),
         coalesce((select jsonb_agg(app_private.staff_access_item_json(paged.membership_id) order by paged.sort_inst, paged.sort_name, paged.membership_id) from paged), '[]'::jsonb)
    into v_total, v_items;
  return jsonb_build_object('items', v_items, 'total_count', v_total, 'page', v_page, 'page_size', v_size,
    'filters', jsonb_build_object(
      'institutions', (select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'name', i.public_name) order by i.public_name), '[]'::jsonb)
                       from public.institutions i where i.status = 'active'
                         and exists (select 1 from public.institution_memberships m where m.institution_id = i.id and m.status = 'active'
                                     and m.role_code not in ('guardian','student') and app_private.staff_access_can_manage(m.id))),
      'units', (select coalesce(jsonb_agg(jsonb_build_object('id', u.id, 'name', u.name, 'institution_id', u.institution_id) order by u.name), '[]'::jsonb)
                from public.units u where u.status = 'active' and (p_institution_id is null or u.institution_id = p_institution_id)
                  and exists (select 1 from public.institution_memberships m left join public.groups g on g.id = m.scope_group_id
                              where coalesce(m.scope_unit_id, g.unit_id) = u.id and m.status = 'active'
                                and m.role_code not in ('guardian','student') and app_private.staff_access_can_manage(m.id)))));
end
$$;
revoke all on function public.staff_access_list_v1(text, uuid, uuid, text[], integer, integer) from public, anon, authenticated;
grant execute on function public.staff_access_list_v1(text, uuid, uuid, text[], integer, integer) to authenticated;

create or replace function public.staff_access_rule_get_v1(p_membership_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.staff_access_require_actor();
  v_membership public.institution_memberships%rowtype;
begin
  v_membership := app_private.staff_access_require_membership(p_membership_id, false);
  return app_private.staff_access_item_json(p_membership_id)
    || jsonb_build_object('leaves', (select coalesce(jsonb_agg(app_private.staff_leave_json(l) order by l.starts_on desc, l.id), '[]'::jsonb)
                                     from public.staff_leaves l where l.membership_id = p_membership_id));
end
$$;
revoke all on function public.staff_access_rule_get_v1(uuid) from public, anon, authenticated;
grant execute on function public.staff_access_rule_get_v1(uuid) to authenticated;

-- payload: {surfaces:[], windows:[], valid_from, valid_until, validity_surfaces:[], popup_enabled, popup_show_validity, clear:bool}
-- expected_version: null ao criar; obrigatoria ao editar/limpar (PT409 se defasada).
create or replace function public.staff_access_rule_save_v1(
  p_membership_id uuid,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.staff_access_require_actor();
  v_membership public.institution_memberships%rowtype;
  v_existing public.staff_access_rules%rowtype;
  v_saved public.staff_access_rules%rowtype;
  v_surfaces text[];
  v_validity_surfaces text[];
  v_windows jsonb;
  v_from date;
  v_until date;
  v_clear boolean := coalesce((p_payload ->> 'clear')::boolean, false);
begin
  v_membership := app_private.staff_access_require_membership(p_membership_id, true);
  select * into v_existing from public.staff_access_rules where membership_id = p_membership_id for update;

  if v_existing.id is not null and (p_expected_version is null or p_expected_version <> v_existing.version) then
    raise exception using errcode = 'PT409', message = 'STAFF_ACCESS_STALE_VERSION', detail = 'STAFF_ACCESS_STALE_VERSION';
  end if;
  if v_existing.id is null and p_expected_version is not null then
    raise exception using errcode = 'PT409', message = 'STAFF_ACCESS_STALE_VERSION', detail = 'STAFF_ACCESS_STALE_VERSION';
  end if;

  if v_clear then
    if v_existing.id is not null then
      delete from public.staff_access_rules where id = v_existing.id;
      insert into audit.audit_logs(actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id, outcome, reason, before_json, after_json)
      values (v_actor, 'aal1', 'permission_changed', 'staff_access_rule', v_existing.id, v_membership.institution_id, 'success',
        'staff_access.rule.cleared', app_private.staff_access_rule_json(v_existing), null);
    end if;
    return app_private.staff_access_item_json(p_membership_id);
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise invalid_parameter_value using message = 'STAFF_ACCESS_PAYLOAD_INVALID';
  end if;
  v_surfaces := coalesce((select array_agg(distinct value order by value) from jsonb_array_elements_text(coalesce(p_payload -> 'surfaces', '[]'::jsonb))), '{}');
  if cardinality(v_surfaces) = 0 then
    raise invalid_parameter_value using message = 'STAFF_ACCESS_SURFACES_REQUIRED';
  end if;
  if not (v_surfaces <@ array['web','mobile_web','tablet_web','installed_app']) then
    raise invalid_parameter_value using message = 'STAFF_ACCESS_SURFACE_INVALID';
  end if;
  v_validity_surfaces := coalesce((select array_agg(distinct value order by value) from jsonb_array_elements_text(coalesce(p_payload -> 'validity_surfaces', '[]'::jsonb))), '{}');
  if cardinality(v_validity_surfaces) = 0 then
    v_validity_surfaces := array['web','mobile_web','tablet_web','installed_app'];
  end if;
  if not (v_validity_surfaces <@ array['web','mobile_web','tablet_web','installed_app']) then
    raise invalid_parameter_value using message = 'STAFF_ACCESS_SURFACE_INVALID';
  end if;
  v_windows := app_private.staff_access_normalize_windows(p_payload -> 'windows');
  begin
    v_from := nullif(p_payload ->> 'valid_from', '')::date;
    v_until := nullif(p_payload ->> 'valid_until', '')::date;
  exception when others then
    raise invalid_parameter_value using message = 'STAFF_ACCESS_VALIDITY_INVALID';
  end;
  if v_from is not null and v_until is not null and v_until < v_from then
    raise invalid_parameter_value using message = 'STAFF_ACCESS_VALIDITY_INVALID';
  end if;

  if v_existing.id is null then
    insert into public.staff_access_rules(membership_id, institution_id, surfaces, windows, valid_from, valid_until, validity_surfaces,
      popup_enabled, popup_show_validity, created_by, updated_by)
    values (p_membership_id, v_membership.institution_id, v_surfaces, v_windows, v_from, v_until, v_validity_surfaces,
      coalesce((p_payload ->> 'popup_enabled')::boolean, false), coalesce((p_payload ->> 'popup_show_validity')::boolean, false), v_actor, v_actor)
    returning * into v_saved;
  else
    update public.staff_access_rules set
      surfaces = v_surfaces, windows = v_windows, valid_from = v_from, valid_until = v_until, validity_surfaces = v_validity_surfaces,
      popup_enabled = coalesce((p_payload ->> 'popup_enabled')::boolean, false),
      popup_show_validity = coalesce((p_payload ->> 'popup_show_validity')::boolean, false),
      version = version + 1, updated_at = now(), updated_by = v_actor
    where id = v_existing.id
    returning * into v_saved;
  end if;

  insert into audit.audit_logs(actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id, outcome, reason, before_json, after_json)
  values (v_actor, 'aal1', 'permission_changed', 'staff_access_rule', v_saved.id, v_membership.institution_id, 'success',
    case when v_existing.id is null then 'staff_access.rule.created' else 'staff_access.rule.updated' end,
    app_private.staff_access_rule_json(v_existing), app_private.staff_access_rule_json(v_saved));
  return app_private.staff_access_item_json(p_membership_id);
end
$$;
revoke all on function public.staff_access_rule_save_v1(uuid, bigint, jsonb) from public, anon, authenticated;
grant execute on function public.staff_access_rule_save_v1(uuid, bigint, jsonb) to authenticated;

-- p_period: current | upcoming | past | null (todos).
create or replace function public.staff_leaves_list_v1(
  p_search text default null,
  p_institution_id uuid default null,
  p_unit_id uuid default null,
  p_period text default null,
  p_page integer default 1,
  p_page_size integer default 20
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.staff_access_require_actor();
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_size integer := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_total integer;
  v_items jsonb;
begin
  if v_search is not null and length(v_search) < 2 then
    raise invalid_parameter_value using message = 'STAFF_ACCESS_SEARCH_TOO_SHORT';
  end if;
  with filtered as (
    select leave_record.id as leave_id, membership.id as membership_id, leave_record.starts_on, person.display_name as sort_name
    from public.staff_leaves leave_record
    join public.institution_memberships membership on membership.id = leave_record.membership_id
    join public.people person on person.id = membership.person_id
    left join public.groups scoped_group on scoped_group.id = membership.scope_group_id
    cross join lateral (select (now() at time zone coalesce(app_private.staff_access_timezone(membership.id), 'America/Sao_Paulo'))::date as today) clock
    where (p_institution_id is null or membership.institution_id = p_institution_id)
      and (p_unit_id is null or coalesce(membership.scope_unit_id, scoped_group.unit_id) = p_unit_id)
      and (v_search is null or person.display_name ilike '%' || v_search || '%')
      and (p_period is null or p_period = ''
        or (p_period = 'current' and leave_record.starts_on <= clock.today and leave_record.ends_on >= clock.today)
        or (p_period = 'upcoming' and leave_record.starts_on > clock.today)
        or (p_period = 'past' and leave_record.ends_on < clock.today))
      and app_private.staff_access_can_manage(membership.id)
  ), paged as (
    select * from filtered order by starts_on desc, sort_name, leave_id limit v_size offset (v_page - 1) * v_size
  )
  select (select count(*) from filtered),
         coalesce((select jsonb_agg(
             (select app_private.staff_leave_json(l) from public.staff_leaves l where l.id = paged.leave_id)
             || jsonb_build_object('membership', app_private.staff_access_item_json(paged.membership_id) - 'rule' - 'current_leave' - 'leaves_count')
             order by paged.starts_on desc, paged.sort_name, paged.leave_id) from paged), '[]'::jsonb)
    into v_total, v_items;
  return jsonb_build_object('items', v_items, 'total_count', v_total, 'page', v_page, 'page_size', v_size);
end
$$;
revoke all on function public.staff_leaves_list_v1(text, uuid, uuid, text, integer, integer) from public, anon, authenticated;
grant execute on function public.staff_leaves_list_v1(text, uuid, uuid, text, integer, integer) to authenticated;

-- payload: {starts_on, ends_on, popup_enabled, internal_note, remove:bool}. p_leave_id null = criar.
create or replace function public.staff_leave_save_v1(
  p_leave_id uuid,
  p_membership_id uuid,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.staff_access_require_actor();
  v_membership public.institution_memberships%rowtype;
  v_existing public.staff_leaves%rowtype;
  v_saved public.staff_leaves%rowtype;
  v_from date;
  v_until date;
  v_note text;
  v_remove boolean := coalesce((p_payload ->> 'remove')::boolean, false);
begin
  if p_leave_id is not null then
    select * into v_existing from public.staff_leaves where id = p_leave_id for update;
    if v_existing.id is null then
      raise no_data_found using message = 'STAFF_ACCESS_LEAVE_NOT_FOUND';
    end if;
    if p_membership_id is not null and p_membership_id <> v_existing.membership_id then
      raise invalid_parameter_value using message = 'STAFF_ACCESS_LEAVE_MEMBERSHIP_MISMATCH';
    end if;
    p_membership_id := v_existing.membership_id;
    if p_expected_version is null or p_expected_version <> v_existing.version then
      raise exception using errcode = 'PT409', message = 'STAFF_ACCESS_STALE_VERSION', detail = 'STAFF_ACCESS_STALE_VERSION';
    end if;
  elsif p_expected_version is not null then
    raise exception using errcode = 'PT409', message = 'STAFF_ACCESS_STALE_VERSION', detail = 'STAFF_ACCESS_STALE_VERSION';
  end if;
  v_membership := app_private.staff_access_require_membership(p_membership_id, true);

  if v_remove then
    if v_existing.id is null then
      raise invalid_parameter_value using message = 'STAFF_ACCESS_LEAVE_NOT_FOUND';
    end if;
    delete from public.staff_leaves where id = v_existing.id;
    insert into audit.audit_logs(actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id, outcome, reason, before_json, after_json)
    values (v_actor, 'aal1', 'permission_changed', 'staff_leave', v_existing.id, v_membership.institution_id, 'success',
      'staff_access.leave.removed', app_private.staff_leave_json(v_existing), null);
    return jsonb_build_object('removed', true, 'membership', app_private.staff_access_item_json(p_membership_id));
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise invalid_parameter_value using message = 'STAFF_ACCESS_PAYLOAD_INVALID';
  end if;
  begin
    v_from := nullif(p_payload ->> 'starts_on', '')::date;
    v_until := nullif(p_payload ->> 'ends_on', '')::date;
  exception when others then
    raise invalid_parameter_value using message = 'STAFF_ACCESS_LEAVE_PERIOD_INVALID';
  end;
  if v_from is null or v_until is null or v_until < v_from then
    raise invalid_parameter_value using message = 'STAFF_ACCESS_LEAVE_PERIOD_INVALID';
  end if;
  v_note := nullif(btrim(coalesce(p_payload ->> 'internal_note', '')), '');
  if v_note is not null and length(v_note) > 500 then
    raise invalid_parameter_value using message = 'STAFF_ACCESS_LEAVE_NOTE_TOO_LONG';
  end if;

  if v_existing.id is null then
    insert into public.staff_leaves(membership_id, institution_id, starts_on, ends_on, popup_enabled, internal_note, created_by, updated_by)
    values (p_membership_id, v_membership.institution_id, v_from, v_until, coalesce((p_payload ->> 'popup_enabled')::boolean, false), v_note, v_actor, v_actor)
    returning * into v_saved;
  else
    update public.staff_leaves set
      starts_on = v_from, ends_on = v_until, popup_enabled = coalesce((p_payload ->> 'popup_enabled')::boolean, false),
      internal_note = v_note, version = version + 1, updated_at = now(), updated_by = v_actor
    where id = v_existing.id
    returning * into v_saved;
  end if;

  insert into audit.audit_logs(actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id, outcome, reason, before_json, after_json)
  values (v_actor, 'aal1', 'permission_changed', 'staff_leave', v_saved.id, v_membership.institution_id, 'success',
    case when v_existing.id is null then 'staff_access.leave.created' else 'staff_access.leave.updated' end,
    app_private.staff_leave_json(v_existing), app_private.staff_leave_json(v_saved));
  return app_private.staff_leave_json(v_saved) || jsonb_build_object('membership', app_private.staff_access_item_json(p_membership_id));
end
$$;
revoke all on function public.staff_leave_save_v1(uuid, uuid, bigint, jsonb) from public, anon, authenticated;
grant execute on function public.staff_leave_save_v1(uuid, uuid, bigint, jsonb) to authenticated;

-- Consulta: o titular do vinculo ou quem o administra. Devolve allowed + reason; detalhes so com popup ligado.
create or replace function public.staff_access_check_v1(
  p_membership_id uuid,
  p_surface text default null,
  p_at timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.staff_access_require_actor();
  v_membership public.institution_memberships%rowtype;
  v_eval record;
  v_surface text := coalesce(nullif(btrim(coalesce(p_surface, '')), ''), app_private.staff_access_request_surface());
begin
  select * into v_membership from public.institution_memberships where id = p_membership_id;
  if v_membership.id is null then
    raise no_data_found using message = 'STAFF_ACCESS_MEMBERSHIP_NOT_FOUND';
  end if;
  if v_membership.person_id <> v_actor and not app_private.staff_access_can_manage(p_membership_id) then
    raise insufficient_privilege using message = 'STAFF_ACCESS_FORBIDDEN';
  end if;
  select * into v_eval from app_private.staff_access_evaluate(p_membership_id, v_surface, coalesce(p_at, now()));
  return jsonb_build_object(
    'membership_id', p_membership_id,
    'surface', v_surface,
    'allowed', v_eval.allowed,
    'reason', v_eval.reason,
    'code', case when v_eval.allowed then null else 'STAFF_ACCESS_DENIED' end,
    'popup', case when v_eval.allowed then null else app_private.staff_access_popup_json(p_membership_id, v_eval.reason, v_eval.rule_id, v_eval.leave_id) end);
end
$$;
revoke all on function public.staff_access_check_v1(uuid, text, timestamptz) from public, anon, authenticated;
grant execute on function public.staff_access_check_v1(uuid, text, timestamptz) to authenticated;

-- 9. contextos do Principal: o vinculo bloqueado continua listado, marcado, sem dados do contexto ---
drop function public.list_my_principal_contexts();
create function public.list_my_principal_contexts()
returns table(
  membership_id uuid,
  person_id uuid,
  institution_id uuid,
  institution_name text,
  role_code text,
  scope_kind text,
  unit_id uuid,
  unit_name text,
  group_id uuid,
  group_name text,
  institution_handle text,
  unit_handle text,
  access_blocked boolean,
  access_reason text,
  access_popup jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication_required';
  end if;

  return query
  select
    membership.id,
    membership.person_id,
    membership.institution_id,
    institution.public_name,
    membership.role_code,
    membership.scope_kind,
    scoped_unit.id,
    scoped_unit.name,
    scoped_group.id,
    scoped_group.name,
    institution.slug,
    scoped_unit.handle,
    not evaluation.allowed,
    evaluation.reason,
    case when evaluation.allowed then null
         else app_private.staff_access_popup_json(membership.id, evaluation.reason, evaluation.rule_id, evaluation.leave_id) end
  from public.people person
  join public.institution_memberships membership
    on membership.person_id = person.id
   and membership.status = 'active'
   and membership.revoked_at is null
  join public.institutions institution
    on institution.id = membership.institution_id
   and institution.status = 'active'
  left join public.groups scoped_group
    on scoped_group.id = membership.scope_group_id
   and scoped_group.institution_id = membership.institution_id
   and scoped_group.status = 'active'
  left join public.units scoped_unit
    on scoped_unit.id = coalesce(membership.scope_unit_id, scoped_group.unit_id)
   and scoped_unit.institution_id = membership.institution_id
   and scoped_unit.status = 'active'
  cross join lateral app_private.staff_access_evaluate(membership.id, app_private.staff_access_request_surface(), now()) evaluation
  where person.id = app_private.person_id_for_auth_user((select auth.uid()))
    and person.status = 'active'
    and (
      (
        membership.scope_kind = 'institution'
        and membership.scope_unit_id is null
        and membership.scope_group_id is null
      )
      or (
        membership.scope_kind = 'unit'
        and membership.scope_unit_id is not null
        and membership.scope_group_id is null
        and scoped_unit.id is not null
      )
      or (
        membership.scope_kind = 'group'
        and membership.scope_group_id is not null
        and scoped_group.id is not null
        and (
          membership.scope_unit_id is null
          or membership.scope_unit_id = scoped_group.unit_id
        )
      )
    )
  order by institution.public_name, scoped_unit.name nulls first,
    scoped_group.name nulls first, membership.created_at, membership.id;
end
$$;
revoke all on function public.list_my_principal_contexts() from public, anon, authenticated;
grant execute on function public.list_my_principal_contexts() to authenticated;

commit;
