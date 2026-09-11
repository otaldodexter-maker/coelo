-- R05 realm-interno (13): Agenda — identidade interna escopada nao le a Agenda de plataforma.
--
-- Achado (prova cross-tenant no descartavel sobre a ordem real ate o lote 43):
-- uma identidade interna escopada em instituicao A listava eventos da
-- instituicao B por superadmin_agenda_list. Causa: as pontes de ator
-- (20260910220400 e 20260911130000) espelham a membership interna escopada
-- como platform_membership sem escopo, e app_private.agenda_has_permission
-- (200300) consultava has_platform_permission antes do realm interno, entao
-- o espelho concedia agenda.read de plataforma a quem so tem escopo de
-- instituicao. superadmin_agenda_list nao filtra por tenant alem da
-- capacidade (e um RPC de plataforma por desenho).
--
-- Correcao minima: em agenda_has_permission, quando o auth user tem vinculo
-- interno ativo, so a membership interna de PLATAFORMA decide (logica original
-- do 200300); has_platform_permission continua valendo para pessoas do realm
-- people-based. agenda_actor_id nao muda: o ator segue sendo a pessoa de
-- servico da ponte (190100 depende disso).
--
-- Pendencia registrada: a mesma exposicao pode existir em outros RPCs de
-- plataforma do realm people-based (has_platform_permission sem escopo para
-- identidades internas escopadas); revisar na revisao profunda de seguranca.
--
-- Reversao: recriar app_private.agenda_has_permission como em 20260910200300.

begin;
do $$
begin
  if to_regprocedure('app_private.agenda_has_permission(text)') is null
    or to_regclass('app_private.superadmin_internal_auth_links') is null then
    raise object_not_in_prerequisite_state using message = 'agenda_internal_realm_compat_v1 (200300) is required';
  end if;
end $$;

create or replace function app_private.agenda_has_permission(p_permission_code text)
returns boolean language sql stable security definer set search_path = '' as $$
  -- Identidade interna primeiro: com vinculo interno ativo, so a membership interna
  -- de PLATAFORMA decide (a platform_membership espelhada pelas pontes de ator
  -- concederia agenda.* a identidades escopadas em instituicao).
  select case when exists (
      select 1 from app_private.superadmin_internal_auth_links auth_link
      where auth_link.auth_user_id = (select auth.uid()) and auth_link.status = 'active')
    then false else app_private.has_platform_permission(p_permission_code) end
  or (
    exists (
      select 1
      from app_private.superadmin_internal_auth_links auth_link
      join app_private.superadmin_internal_memberships membership
        on membership.internal_identity_id = auth_link.internal_identity_id
       and membership.status = 'active'
       and membership.scope_kind::text = 'platform'
      join public.platform_roles role_record
        on role_record.id = membership.platform_role_id and role_record.status = 'active'
      join public.platform_role_permissions grant_record
        on grant_record.role_id = role_record.id
       and grant_record.status = 'active' and grant_record.revoked_at is null
       and grant_record.effect = 'allow'
      join public.platform_permissions permission_record
        on permission_record.id = grant_record.permission_id
       and permission_record.code = p_permission_code and permission_record.status = 'active'
      where auth_link.auth_user_id = (select auth.uid()) and auth_link.status = 'active'
    )
    and not exists (
      select 1
      from app_private.superadmin_internal_auth_links auth_link
      join app_private.superadmin_internal_memberships membership
        on membership.internal_identity_id = auth_link.internal_identity_id
       and membership.status = 'active'
      join public.platform_role_permissions grant_record
        on grant_record.role_id = membership.platform_role_id
       and grant_record.status = 'active' and grant_record.revoked_at is null
       and grant_record.effect = 'deny'
      join public.platform_permissions permission_record
        on permission_record.id = grant_record.permission_id
       and permission_record.code = p_permission_code
      where auth_link.auth_user_id = (select auth.uid()) and auth_link.status = 'active'
    )
  )
$$;
alter function app_private.agenda_has_permission(text) owner to postgres;
revoke all on function app_private.agenda_has_permission(text) from public, anon, authenticated, service_role;
commit;
