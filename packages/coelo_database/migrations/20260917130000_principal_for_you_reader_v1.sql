-- R15 / ADR 0041 B9 (principal.for-you): leitor do hub "Para voce" com o contexto
-- real do ator, resolvido no servidor. Promove a proposta
-- plans/2026-09-09-principal-for-you-read-rpc.sql (E2 R02 L03) para migration
-- forward-only, com dois ajustes: (1) o ator e resolvido por
-- app_private.person_id_for_auth_user, como em list_my_principal_contexts;
-- (2) cada linha e projetada por app_private.superadmin_notice_json, o mesmo
-- envelope de item do diretorio administrativo, para o cliente reutilizar o
-- parser sem receber campo novo. Filtros no servidor: tipo (highlight,
-- content_card, for_you — nunca popup/notice/critical_notice), status active,
-- destino (p_target_device: all|web|mobile|tablet, valor fora da allowlist e
-- recusado), vigencia e audiencia (audience_json: papel, dimensao/target_ids/
-- select_all, excluded_ids; exclusao vence; notice_rules so como exclusao).
-- O contexto e escolhido pelo cliente entre os vinculos ATIVOS da propria
-- pessoa (p_membership_id, opcional): so um vinculo do proprio ator conta; um
-- id alheio ou inexistente resulta em lista vazia (nao enumeravel).
-- Nao substitui superadmin_notice_directory_v2 (gateway administrativo).
-- Reversao: drop function public.list_my_principal_for_you(text,uuid,integer).

begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then raise exception 'executar como postgres'; end if;
  if to_regprocedure('public.list_my_principal_contexts()') is null
    or to_regprocedure('app_private.person_id_for_auth_user(uuid)') is null
    or to_regprocedure('app_private.superadmin_notice_json(public.platform_notices)') is null
    or to_regclass('public.platform_notices') is null
    or to_regclass('public.notice_rules') is null then
    raise exception 'pre-requisitos do Principal/avisos ausentes';
  end if;
end $preflight$;

create or replace function public.list_my_principal_for_you(
  p_target_device text,
  p_membership_id uuid default null,
  p_limit integer default 50
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  actor_person uuid;
  items jsonb;
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication_required';
  end if;
  if p_limit is null or p_limit not between 1 and 100 then
    raise invalid_parameter_value using message = 'invalid_for_you_query';
  end if;
  if p_target_device is null or p_target_device not in ('all', 'web', 'mobile', 'tablet') then
    raise invalid_parameter_value using message = 'invalid_for_you_target_device';
  end if;
  actor_person := app_private.person_id_for_auth_user((select auth.uid()));
  if actor_person is null then
    raise insufficient_privilege using message = 'principal_context_denied';
  end if;

  with actor as (
    select
      membership.id             as membership_id,
      membership.person_id      as person_id,
      membership.institution_id as institution_id,
      membership.role_code      as role_code,
      scoped_unit.id            as unit_id,
      scoped_group.id           as group_id
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
    where person.id = actor_person
      and person.status = 'active'
      and (p_membership_id is null or membership.id = p_membership_id)
  ),
  eligible as (
    select notice.*,
      notice.audience_json -> 'rules' -> 0 as rule_json,
      coalesce(notice.audience_json -> 'role_codes', '[]'::jsonb) as role_codes
    from public.platform_notices notice
    where notice.notice_type::text in ('highlight', 'content_card', 'for_you')
      and notice.status::text = 'active'
      and (notice.target_device = 'all' or notice.target_device = p_target_device)
      and notice.starts_at is not null
      and notice.starts_at <= now()
      and (notice.ends_at is null or notice.ends_at > now())
  ),
  visible as (
    select distinct on (eligible.id) eligible.*
    from eligible
    cross join actor
    where
      (jsonb_array_length(eligible.role_codes) = 0
        or exists (select 1 from jsonb_array_elements_text(eligible.role_codes) code(value)
                   where code.value = actor.role_code))
      and (
        case eligible.rule_json ->> 'dimension'
          when 'platform' then true
          when 'institution' then
            coalesce((eligible.rule_json ->> 'select_all')::boolean, false)
            or (eligible.rule_json -> 'target_ids') ? actor.institution_id::text
          when 'unit' then
            actor.unit_id is not null and (
              coalesce((eligible.rule_json ->> 'select_all')::boolean, false)
              or (eligible.rule_json -> 'target_ids') ? actor.unit_id::text)
          when 'group' then
            actor.group_id is not null and (
              coalesce((eligible.rule_json ->> 'select_all')::boolean, false)
              or (eligible.rule_json -> 'target_ids') ? actor.group_id::text)
          when 'person' then
            coalesce((eligible.rule_json ->> 'select_all')::boolean, false)
            or (eligible.rule_json -> 'target_ids') ? actor.person_id::text
          else false
        end)
      and not exists (
        select 1 from jsonb_array_elements_text(coalesce(eligible.rule_json -> 'excluded_ids', '[]'::jsonb)) excluded(value)
        where excluded.value in (actor.institution_id::text, coalesce(actor.unit_id::text, ''),
          coalesce(actor.group_id::text, ''), actor.person_id::text, actor.membership_id::text))
      and not exists (
        select 1 from public.notice_rules rule
        where rule.notice_id = eligible.id and rule.effect = 'exclude'
          and ((rule.target_type = 'platform')
            or (rule.target_type = 'institution' and rule.target_id = actor.institution_id)
            or (rule.target_type = 'unit' and rule.target_id = actor.unit_id)
            or (rule.target_type = 'group' and rule.target_id = actor.group_id)
            or (rule.role_filter is not null and rule.role_filter = actor.role_code)))
    order by eligible.id
  )
  select coalesce(jsonb_agg(app_private.superadmin_notice_json(notice)
      order by page.rank, page.occurred_at desc, page.id desc), '[]'::jsonb)
    into items
  from (select visible.id,
          case visible.priority_code when 'urgent' then 0 when 'important' then 10 else 20 end as rank,
          coalesce(visible.starts_at, visible.published_at, visible.created_at) as occurred_at
        from visible
        order by 2, 3 desc, 1 desc
        limit p_limit) page
  join public.platform_notices notice on notice.id = page.id;

  return jsonb_build_object('ok', true, 'data', jsonb_build_object('items', items), 'error', null);
end $$;

alter function public.list_my_principal_for_you(text, uuid, integer) owner to postgres;
revoke all on function public.list_my_principal_for_you(text, uuid, integer) from public, anon, service_role;
grant execute on function public.list_my_principal_for_you(text, uuid, integer) to authenticated;
comment on function public.list_my_principal_for_you(text, uuid, integer) is
  'Leitura autorizada do hub Principal / Para voce (B9): ator por auth.uid(), vinculo ativo proprio (p_membership_id opcional), tipo, destino, vigencia e audiencia no servidor. Nunca expoe popup, notice ou critical_notice.';

commit;
