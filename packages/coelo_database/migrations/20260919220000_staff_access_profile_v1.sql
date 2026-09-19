-- Etapa 3 F7 (ADR 0035) — horário de uso do app no PERFIL de funcionário (decisão do Owner 19/09).
-- A instituição/unidade define o horário pelo perfil (institution_roles); o vínculo herda; regra
-- própria do vínculo (staff_access_rules) prevalece e marca "fora do padrão do perfil"; limpar a
-- regra própria (staff_access_rule_save_v1 clear) volta a herdar. Afastamento continua acima de tudo.
-- Uma tabela nova (1 regra por perfil), um resolvedor unico (staff_access_effective_rule) usado por
-- evaluate/popup/state/item; staff_access_list_v1 ganha p_sources (profile|own|none).
begin;

-- 1. tabela ---------------------------------------------------------------------------------------
create table if not exists public.staff_access_profile_rules (
  id uuid primary key default gen_random_uuid(),
  role_id uuid not null unique references public.institution_roles(id) on delete cascade,
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
  constraint staff_access_profile_rules_validity_check check (valid_from is null or valid_until is null or valid_until >= valid_from),
  constraint staff_access_profile_rules_surfaces_check check (surfaces <@ array['web','mobile_web','tablet_web','installed_app']),
  constraint staff_access_profile_rules_validity_surfaces_check check (validity_surfaces <@ array['web','mobile_web','tablet_web','installed_app']),
  constraint staff_access_profile_rules_version_check check (version > 0),
  constraint staff_access_profile_rules_windows_array_check check (jsonb_typeof(windows) = 'array')
);
create index if not exists staff_access_profile_rules_institution_idx on public.staff_access_profile_rules(institution_id);
alter table public.staff_access_profile_rules enable row level security;
alter table public.staff_access_profile_rules force row level security;
revoke all on public.staff_access_profile_rules from public, anon, authenticated;
grant select on public.staff_access_profile_rules to authenticated;

drop policy if exists staff_access_profile_rules_read on public.staff_access_profile_rules;
create policy staff_access_profile_rules_read on public.staff_access_profile_rules for select to authenticated
using (
  app_private.has_institution_permission(institution_id, 'staff_access.manage', null, null, false)
  or exists (select 1 from public.institution_role_assignments assignment
             join public.institution_memberships membership on membership.id = assignment.membership_id
             where assignment.role_id = staff_access_profile_rules.role_id
               and assignment.status = 'active'
               and membership.person_id = app_private.current_person_id())
);

-- 2. projecao da regra do perfil -----------------------------------------------------------------
create or replace function app_private.staff_access_profile_rule_json(p_rule public.staff_access_profile_rules)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when p_rule.id is null then null else jsonb_build_object(
    'id', p_rule.id,
    'role_id', p_rule.role_id,
    'role_name', (select r.name from public.institution_roles r where r.id = p_rule.role_id),
    'institution_id', p_rule.institution_id,
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
revoke all on function app_private.staff_access_profile_rule_json(public.staff_access_profile_rules) from public, anon, authenticated;

-- 3. resolvedor unico: regra propria > regra do perfil atribuido > nenhuma ------------------------
-- source: own | profile | none. Regra propria igual a do perfil conta como 'profile' (esta no padrao).
-- Perfil = institution_role_assignments ativo (mais antigo, se houver mais de um) do vinculo.
create or replace function app_private.staff_access_effective_rule(p_membership_id uuid)
returns table(
  source text, rule_id uuid, role_id uuid, role_name text,
  surfaces text[], windows jsonb, valid_from date, valid_until date, validity_surfaces text[],
  popup_enabled boolean, popup_show_validity boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with own as (
    select r.* from public.staff_access_rules r where r.membership_id = p_membership_id
  ), profile as (
    select pr.*, role_record.name as profile_name
    from public.institution_role_assignments assignment
    join public.institution_roles role_record on role_record.id = assignment.role_id and role_record.status = 'active'
    join public.staff_access_profile_rules pr on pr.role_id = role_record.id
    where assignment.membership_id = p_membership_id
      and assignment.status = 'active'
      and (assignment.starts_at is null or assignment.starts_at <= now())
      and (assignment.expires_at is null or assignment.expires_at > now())
    order by assignment.created_at, assignment.id
    limit 1
  )
  select
    case
      when own.id is null and profile.id is null then 'none'
      when own.id is null then 'profile'
      when profile.id is not null
        and own.surfaces <@ profile.surfaces and own.surfaces @> profile.surfaces and own.windows = profile.windows
        and own.valid_from is not distinct from profile.valid_from
        and own.valid_until is not distinct from profile.valid_until
        and own.validity_surfaces <@ profile.validity_surfaces and own.validity_surfaces @> profile.validity_surfaces
        and own.popup_enabled = profile.popup_enabled
        and own.popup_show_validity = profile.popup_show_validity then 'profile'
      else 'own'
    end,
    coalesce(own.id, profile.id),
    profile.role_id,
    profile.profile_name,
    coalesce(own.surfaces, profile.surfaces),
    coalesce(own.windows, profile.windows),
    case when own.id is not null then own.valid_from else profile.valid_from end,
    case when own.id is not null then own.valid_until else profile.valid_until end,
    coalesce(own.validity_surfaces, profile.validity_surfaces),
    coalesce(own.popup_enabled, profile.popup_enabled),
    coalesce(own.popup_show_validity, profile.popup_show_validity)
  from (select 1) seed
  left join own on true
  left join profile on true
$$;
revoke all on function app_private.staff_access_effective_rule(uuid) from public, anon, authenticated;

-- 4. avaliacao (mesma assinatura e retorno do lote 84; so troca a origem da regra) ---------------
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
  v_rule record;
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
  select * into v_rule from app_private.staff_access_effective_rule(p_membership_id);
  if v_rule.source = 'none' and not exists (select 1 from public.staff_leaves where membership_id = p_membership_id) then
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
    return query select false, 'leave'::text, v_rule.rule_id, v_leave.id;
    return;
  end if;
  if v_rule.source = 'none' then
    return query select true, null::text, null::uuid, null::uuid;
    return;
  end if;

  -- vigencia (inclusiva) > horario, apenas nas superficies a que ela se aplica
  if v_surface = any(v_rule.validity_surfaces) and (
       (v_rule.valid_from is not null and v_date < v_rule.valid_from)
    or (v_rule.valid_until is not null and v_date > v_rule.valid_until)) then
    return query select false, 'validity'::text, v_rule.rule_id, null::uuid;
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
      return query select false, 'schedule'::text, v_rule.rule_id, null::uuid;
      return;
    end if;
  end if;

  -- superficie
  if not (v_surface = any(v_rule.surfaces)) then
    return query select false, 'surface'::text, v_rule.rule_id, null::uuid;
    return;
  end if;

  return query select true, null::text, v_rule.rule_id, null::uuid;
end
$$;
revoke all on function app_private.staff_access_evaluate(uuid, text, timestamptz) from public, anon, authenticated;

-- 5. popup e estado passam a ler a regra efetiva ---------------------------------------------------
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
      from app_private.staff_access_effective_rule(p_membership_id) rule_record where rule_record.source <> 'none')
    else null end
$$;
revoke all on function app_private.staff_access_popup_json(uuid, text, uuid, uuid) from public, anon, authenticated;

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
    when exists (select 1 from app_private.staff_access_effective_rule(p_membership_id) r where r.source <> 'none' and (r.valid_from is not null or r.valid_until is not null)) then 'validity'
    when exists (select 1 from app_private.staff_access_effective_rule(p_membership_id) r where r.source <> 'none' and (jsonb_array_length(r.windows) > 0 or cardinality(r.surfaces) < 4)) then 'schedule'
    else 'free' end
$$;
revoke all on function app_private.staff_access_state(uuid) from public, anon, authenticated;

-- 6. item do diretorio: origem do horario + regra do perfil -----------------------------------------
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
    'source', effective.source,
    'profile_name', effective.role_name,
    'rule', (select app_private.staff_access_rule_json(r) from public.staff_access_rules r where r.membership_id = membership.id),
    'profile_rule', (select app_private.staff_access_profile_rule_json(pr) from public.staff_access_profile_rules pr where pr.role_id = effective.role_id),
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
  cross join lateral app_private.staff_access_effective_rule(membership.id) effective
  where membership.id = p_membership_id
$$;
revoke all on function app_private.staff_access_item_json(uuid) from public, anon, authenticated;

-- 7. lista com filtro por origem (assinatura nova: p_sources) --------------------------------------
drop function if exists public.staff_access_list_v1(text, uuid, uuid, text[], integer, integer);
create or replace function public.staff_access_list_v1(
  p_search text default null,
  p_institution_id uuid default null,
  p_unit_id uuid default null,
  p_states text[] default null,
  p_page integer default 1,
  p_page_size integer default 20,
  p_sources text[] default null
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
      and (p_sources is null or cardinality(p_sources) = 0
           or (select e.source from app_private.staff_access_effective_rule(membership.id) e) = any(p_sources))
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
revoke all on function public.staff_access_list_v1(text, uuid, uuid, text[], integer, integer, text[]) from public, anon, authenticated;
grant execute on function public.staff_access_list_v1(text, uuid, uuid, text[], integer, integer, text[]) to authenticated;

-- 8. RPCs do perfil ---------------------------------------------------------------------------------
-- Perfil elegivel: papel de instituicao (institution_id not null; papeis de sistema globais nao
-- recebem horario), ativo, e o ator tem staff_access.manage na instituicao do perfil.
create or replace function app_private.staff_access_require_role(p_role_id uuid)
returns public.institution_roles
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role public.institution_roles%rowtype;
begin
  select * into v_role from public.institution_roles where id = p_role_id;
  if v_role.id is null then
    raise no_data_found using message = 'STAFF_ACCESS_PROFILE_NOT_FOUND';
  end if;
  if v_role.institution_id is null then
    raise invalid_parameter_value using message = 'STAFF_ACCESS_PROFILE_GLOBAL';
  end if;
  if not app_private.has_institution_permission(v_role.institution_id, 'staff_access.manage', null, null, false) then
    raise insufficient_privilege using message = 'STAFF_ACCESS_FORBIDDEN';
  end if;
  return v_role;
end
$$;
revoke all on function app_private.staff_access_require_role(uuid) from public, anon, authenticated;

create or replace function public.staff_access_profile_rule_get_v1(p_role_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.staff_access_require_actor();
  v_role public.institution_roles%rowtype := app_private.staff_access_require_role(p_role_id);
begin
  return jsonb_build_object(
    'role_id', v_role.id,
    'role_name', v_role.name,
    'institution_id', v_role.institution_id,
    'rule', (select app_private.staff_access_profile_rule_json(pr) from public.staff_access_profile_rules pr where pr.role_id = p_role_id),
    'membership_count', (select count(distinct a.membership_id) from public.institution_role_assignments a where a.role_id = p_role_id and a.status = 'active'),
    'own_rule_count', (select count(distinct a.membership_id) from public.institution_role_assignments a
                       join public.staff_access_rules r on r.membership_id = a.membership_id
                       where a.role_id = p_role_id and a.status = 'active'));
end
$$;
revoke all on function public.staff_access_profile_rule_get_v1(uuid) from public, anon, authenticated;
grant execute on function public.staff_access_profile_rule_get_v1(uuid) to authenticated;

-- Mesmo payload de staff_access_rule_save_v1 ({surfaces, windows, valid_from, valid_until,
-- validity_surfaces, popup_enabled, popup_show_validity, clear}); PT409 na versao defasada.
create or replace function public.staff_access_profile_rule_save_v1(
  p_role_id uuid,
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
  v_role public.institution_roles%rowtype;
  v_existing public.staff_access_profile_rules%rowtype;
  v_saved public.staff_access_profile_rules%rowtype;
  v_surfaces text[];
  v_validity_surfaces text[];
  v_windows jsonb;
  v_from date;
  v_until date;
  v_clear boolean := coalesce((p_payload ->> 'clear')::boolean, false);
begin
  v_role := app_private.staff_access_require_role(p_role_id);
  select * into v_existing from public.staff_access_profile_rules where role_id = p_role_id for update;

  if v_existing.id is not null and (p_expected_version is null or p_expected_version <> v_existing.version) then
    raise exception using errcode = 'PT409', message = 'STAFF_ACCESS_STALE_VERSION', detail = 'STAFF_ACCESS_STALE_VERSION';
  end if;
  if v_existing.id is null and p_expected_version is not null then
    raise exception using errcode = 'PT409', message = 'STAFF_ACCESS_STALE_VERSION', detail = 'STAFF_ACCESS_STALE_VERSION';
  end if;

  if v_clear then
    if v_existing.id is not null then
      delete from public.staff_access_profile_rules where id = v_existing.id;
      insert into audit.audit_logs(actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id, outcome, reason, before_json, after_json)
      values (v_actor, 'aal1', 'permission_changed', 'staff_access_profile_rule', v_existing.id, v_role.institution_id, 'success',
        'staff_access.profile_rule.cleared', app_private.staff_access_profile_rule_json(v_existing), null);
    end if;
    return public.staff_access_profile_rule_get_v1(p_role_id);
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
    insert into public.staff_access_profile_rules(role_id, institution_id, surfaces, windows, valid_from, valid_until, validity_surfaces,
      popup_enabled, popup_show_validity, created_by, updated_by)
    values (p_role_id, v_role.institution_id, v_surfaces, v_windows, v_from, v_until, v_validity_surfaces,
      coalesce((p_payload ->> 'popup_enabled')::boolean, false), coalesce((p_payload ->> 'popup_show_validity')::boolean, false), v_actor, v_actor)
    returning * into v_saved;
  else
    update public.staff_access_profile_rules set
      surfaces = v_surfaces, windows = v_windows, valid_from = v_from, valid_until = v_until, validity_surfaces = v_validity_surfaces,
      popup_enabled = coalesce((p_payload ->> 'popup_enabled')::boolean, false),
      popup_show_validity = coalesce((p_payload ->> 'popup_show_validity')::boolean, false),
      version = version + 1, updated_at = now(), updated_by = v_actor
    where id = v_existing.id
    returning * into v_saved;
  end if;

  insert into audit.audit_logs(actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id, outcome, reason, before_json, after_json)
  values (v_actor, 'aal1', 'permission_changed', 'staff_access_profile_rule', v_saved.id, v_role.institution_id, 'success',
    case when v_existing.id is null then 'staff_access.profile_rule.created' else 'staff_access.profile_rule.updated' end,
    app_private.staff_access_profile_rule_json(v_existing), app_private.staff_access_profile_rule_json(v_saved));
  return public.staff_access_profile_rule_get_v1(p_role_id);
end
$$;
revoke all on function public.staff_access_profile_rule_save_v1(uuid, bigint, jsonb) from public, anon, authenticated;
grant execute on function public.staff_access_profile_rule_save_v1(uuid, bigint, jsonb) to authenticated;

commit;
