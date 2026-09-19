-- Etapa 3 F7 (ADR 0035) — erro com motivo quando o vinculo do ator esta bloqueado (item 5).
-- app_private.staff_access_assert(p_institution_id, p_unit_id, p_group_id) levanta PT403 /
-- STAFF_ACCESS_DENIED com detail JSON {code, reason, popup, membership_id} quando TODO vinculo de
-- equipe ativo do ator na instituicao esta bloqueado agora (staff_access_evaluate). Sem vinculo, ou com
-- algum vinculo livre, nao faz nada: o resolvedor segue e nega (ou nao) pelo caminho normal. Nunca 40001.
-- Chamada no comeco de happens_actor, now_actor, circular_actor, moments_actor_for_auth_user e, em
-- now_reader_actor, so no fim do caminho de equipe (a familia — guardian_links — continua passando).
-- assert_agenda/plan/people/support_permission sao do realm interno (sem membership de instituicao): fora.
begin;

create or replace function app_private.staff_access_assert(
  p_institution_id uuid,
  p_unit_id uuid default null,
  p_group_id uuid default null,
  p_person_id uuid default null
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_person uuid := coalesce(p_person_id, app_private.current_person_id());
  v_blocked record;
begin
  if v_person is null or p_institution_id is null then
    return;
  end if;
  -- algum vinculo de equipe livre na instituicao: nada a declarar
  if exists (
    select 1 from public.institution_memberships membership
    where membership.person_id = v_person and membership.institution_id = p_institution_id
      and membership.status = 'active' and membership.revoked_at is null
      and membership.role_code not in ('guardian','student')
      and not app_private.staff_access_blocked(membership.id)
  ) then
    return;
  end if;
  select membership.id as membership_id, evaluation.reason, evaluation.rule_id, evaluation.leave_id
    into v_blocked
  from public.institution_memberships membership
  cross join lateral app_private.staff_access_evaluate(membership.id, app_private.staff_access_request_surface(), now()) evaluation
  where membership.person_id = v_person and membership.institution_id = p_institution_id
    and membership.status = 'active' and membership.revoked_at is null
    and membership.role_code not in ('guardian','student')
    and not evaluation.allowed
  order by membership.created_at, membership.id
  limit 1;
  if v_blocked.membership_id is null then
    return;
  end if;
  raise exception using
    errcode = 'PT403',
    message = 'STAFF_ACCESS_DENIED',
    detail = jsonb_build_object(
      'code', 'STAFF_ACCESS_DENIED',
      'membership_id', v_blocked.membership_id,
      'institution_id', p_institution_id,
      'reason', v_blocked.reason,
      'popup', app_private.staff_access_popup_json(v_blocked.membership_id, v_blocked.reason, v_blocked.rule_id, v_blocked.leave_id)
    )::text;
end
$$;
revoke all on function app_private.staff_access_assert(uuid, uuid, uuid, uuid) from public, anon, authenticated;

-- happens_actor: assert no comeco
CREATE OR REPLACE FUNCTION app_private.happens_actor(p_institution_id uuid, p_permission text, p_unit_id uuid, p_group_id uuid)
 RETURNS TABLE(person_id uuid, membership_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if (select auth.uid()) is null then raise insufficient_privilege using message='authentication_required'; end if;
  perform app_private.staff_access_assert(p_institution_id, p_unit_id, p_group_id);
  if not app_private.has_institution_permission(p_institution_id,p_permission,p_unit_id,p_group_id,false)
  then raise insufficient_privilege using message='happens_permission_denied'; end if;
  return query select membership.person_id,membership.id
  from public.institution_memberships membership
  where membership.person_id=app_private.person_id_for_auth_user((select auth.uid()))
    and membership.institution_id=p_institution_id
    and membership.status='active' and membership.revoked_at is null order by membership.created_at limit 1;
  if not found then raise insufficient_privilege using message='active_membership_required'; end if;
end $function$;

-- now_actor: assert no comeco
CREATE OR REPLACE FUNCTION app_private.now_actor(p_institution_id uuid, p_permission text, p_unit_id uuid, p_group_id uuid)
 RETURNS TABLE(person_id uuid, membership_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if (select auth.uid()) is null then raise insufficient_privilege using message='authentication_required'; end if;
  perform app_private.staff_access_assert(p_institution_id, p_unit_id, p_group_id);
  if p_unit_id is not null and not exists(
    select 1 from public.units where id=p_unit_id and institution_id=p_institution_id
  ) then raise insufficient_privilege using message='context_not_authorized'; end if;
  if p_group_id is not null and (
    p_unit_id is null or not exists(
      select 1 from public.groups
      where id=p_group_id and institution_id=p_institution_id and unit_id=p_unit_id
    )
  ) then raise insufficient_privilege using message='context_not_authorized'; end if;
  if not app_private.has_institution_permission(p_institution_id,p_permission,p_unit_id,p_group_id,false)
  then raise insufficient_privilege using message='now_permission_denied'; end if;
  return query select membership.person_id,membership.id
  from public.institution_memberships membership
  where membership.person_id=app_private.person_id_for_auth_user((select auth.uid()))
    and membership.institution_id=p_institution_id
    and membership.status='active' and membership.revoked_at is null order by membership.created_at limit 1;
  if not found then raise insufficient_privilege using message='active_membership_required'; end if;
end $function$;

-- circular_actor: assert no comeco
CREATE OR REPLACE FUNCTION app_private.circular_actor(p_institution_id uuid, p_permission text, p_unit_id uuid, p_group_id uuid)
 RETURNS TABLE(person_id uuid, membership_id uuid, role_code text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_person_id uuid;
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication_required';
  end if;
  perform app_private.staff_access_assert(p_institution_id, p_unit_id, p_group_id);
  -- Capacidade: realm people-based (perfis da instituicao) OU realm interno v2
  -- (platform_permissions do Superadmin, com escopo de instituicao respeitado),
  -- somadas como em 220400; nenhuma das duas afrouxa a outra.
  if not app_private.has_institution_permission(p_institution_id, p_permission, p_unit_id, p_group_id, false)
     and not app_private.circular_internal_capability(p_institution_id, p_permission) then
    raise insufficient_privilege using message = 'circular_permission_denied';
  end if;
  -- Ponte de ator (220400): pessoa do realm people-based quando existe,
  -- senao a pessoa de servico espelhada da identidade interna.
  v_person_id := app_private.current_person_id();
  if v_person_id is null then
    raise insufficient_privilege using message = 'active_membership_required';
  end if;
  return query
    select membership.person_id, membership.id, membership.role_code
    from public.institution_memberships membership
    where membership.person_id = v_person_id
      and membership.institution_id = p_institution_id
      and membership.status = 'active'
      and membership.revoked_at is null
    order by membership.created_at
    limit 1;
  if not found then
    raise insufficient_privilege using message = 'active_membership_required';
  end if;
end;
$function$;

-- moments_actor_for_auth_user: assert no comeco (ator explicito)
CREATE OR REPLACE FUNCTION app_private.moments_actor_for_auth_user(p_auth_user_id uuid, p_institution_id uuid, p_permission text, p_unit_id uuid, p_group_id uuid)
 RETURNS TABLE(person_id uuid, membership_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if p_auth_user_id is null then
    raise insufficient_privilege using message = 'authentication_required';
  end if;
  perform app_private.staff_access_assert(p_institution_id, p_unit_id, p_group_id, app_private.person_id_for_auth_user(p_auth_user_id));
  if not app_private.has_institution_permission(
    p_institution_id, p_permission, p_unit_id, p_group_id, false
  ) then
    raise insufficient_privilege using message = 'moments_permission_denied';
  end if;
  return query
  select membership.person_id, membership.id
  from public.institution_memberships membership
  where membership.person_id = app_private.person_id_for_auth_user(p_auth_user_id)
    and membership.institution_id = p_institution_id
    and membership.status = 'active'
    and membership.revoked_at is null
  order by membership.created_at
  limit 1;
  if not found then
    raise insufficient_privilege using message = 'active_membership_required';
  end if;
end
$function$;

-- now_reader_actor: assert so quando equipe e familia falharam
CREATE OR REPLACE FUNCTION app_private.now_reader_actor(p_institution_id uuid, p_permission text, p_unit_id uuid, p_group_id uuid)
 RETURNS TABLE(person_id uuid, membership_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor_person_id uuid;
  actor_membership_id uuid;
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message='authentication_required';
  end if;
  if p_unit_id is not null and not exists(
    select 1 from public.units where id=p_unit_id and institution_id=p_institution_id
  ) then raise insufficient_privilege using message='context_not_authorized'; end if;
  if p_group_id is not null and (
    p_unit_id is null or not exists(
      select 1 from public.groups
      where id=p_group_id and institution_id=p_institution_id and unit_id=p_unit_id
    )
  ) then raise insufficient_privilege using message='context_not_authorized'; end if;

  actor_person_id:=app_private.person_id_for_auth_user((select auth.uid()));
  if actor_person_id is null then
    raise insufficient_privilege using message='now_permission_denied';
  end if;

  -- Caminho de equipe (contrato vigente): permissao institucional no contexto + membership ativa.
  if app_private.has_institution_permission(p_institution_id,p_permission,p_unit_id,p_group_id,false) then
    select membership.id into actor_membership_id
    from public.institution_memberships membership
    where membership.person_id=actor_person_id
      and membership.institution_id=p_institution_id
      and membership.status='active' and membership.revoked_at is null
    order by membership.created_at limit 1;
    if actor_membership_id is null then
      raise insufficient_privilege using message='active_membership_required';
    end if;
    person_id:=actor_person_id;
    membership_id:=actor_membership_id;
    return next;
    return;
  end if;

  -- Caminho de responsavel (spec 070): guardian_links ativo + child_contexts ativo na instituicao pedida +
  -- guardian_context_permissions.can_view vigente (+ vinculo de unidade/turma quando o contexto e informado),
  -- pelo mesmo predicado guardian_context de now_viewer_role_class. Sem membership; sem capacidade de escrita.
  if app_private.now_viewer_role_class(actor_person_id,null,p_institution_id,p_unit_id,p_group_id)
     is distinct from 'guardian' then
    -- equipe bloqueada e sem caminho de familia: motivo em vez de 'sem permissao'
    perform app_private.staff_access_assert(p_institution_id, p_unit_id, p_group_id, actor_person_id);
    raise insufficient_privilege using message='now_permission_denied';
  end if;
  person_id:=actor_person_id;
  membership_id:=null;
  return next;
end $function$;

commit;
