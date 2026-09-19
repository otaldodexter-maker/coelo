-- staff_access: dois perfis com horario no mesmo vinculo -> vale a mais restritiva (Sessao ACESSO-PERFIL-FECHAMENTO, 20/09/2026)
-- staff_access_effective_rule(p_membership_id, p_role_id default null): com p_role_id, devolve a regra daquele perfil.
-- staff_access_evaluate(..., p_role_id default null): quando a regra efetiva e de perfil e libera, reavalia os outros
-- perfis com regra do vinculo; o primeiro que bloquear vence (reason/rule_id/popup dele). Regra propria segue acima.
begin;
set local statement_timeout = '60s';

drop function if exists app_private.staff_access_effective_rule(uuid);
create or replace function app_private.staff_access_effective_rule(p_membership_id uuid, p_role_id uuid default null)
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
      and (p_role_id is null or assignment.role_id = p_role_id)
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
revoke all on function app_private.staff_access_effective_rule(uuid, uuid) from public, anon, authenticated;

drop function if exists app_private.staff_access_evaluate(uuid, text, timestamptz);
create or replace function app_private.staff_access_evaluate(
  p_membership_id uuid,
  p_surface text default 'web',
  p_at timestamptz default now(),
  p_role_id uuid default null
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
  v_other record;
begin
  if v_surface not in ('web','mobile_web','tablet_web','installed_app') then
    v_surface := 'web';
  end if;
  select * into v_rule from app_private.staff_access_effective_rule(p_membership_id, p_role_id);
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

  -- v2: mais de um perfil com regra no mesmo vinculo -> vale a MAIS RESTRITIVA (bloqueia se qualquer
  -- uma bloquear; o popup e o da regra que bloqueou). Regra propria continua acima de todos os perfis.
  if p_role_id is null and v_rule.source = 'profile' then
    for v_other in
      select distinct assignment.role_id
      from public.institution_role_assignments assignment
      join public.staff_access_profile_rules pr on pr.role_id = assignment.role_id
      where assignment.membership_id = p_membership_id and assignment.status = 'active'
        and assignment.role_id <> v_rule.role_id
        and (assignment.starts_at is null or assignment.starts_at <= p_at)
        and (assignment.expires_at is null or assignment.expires_at > p_at)
    loop
      return query select e.* from app_private.staff_access_evaluate(p_membership_id, v_surface, p_at, v_other.role_id) e where not e.allowed;
      if found then return; end if;
    end loop;
  end if;

  return query select true, null::text, v_rule.rule_id, null::uuid;
end
$$;
revoke all on function app_private.staff_access_evaluate(uuid, text, timestamptz, uuid) from public, anon, authenticated;

commit;
