-- R06 realm-interno (1): raiz da ponte de ator — identidade interna escopada
-- em instituicao nao ganha capacidade nem membership fora do seu escopo.
--
-- Achado (R05, lote 44 corrigiu so a Agenda): produção tem 0 identidades
-- internas escopadas, mas a cadeia das pontes concedia a elas acesso de
-- plataforma por dois caminhos:
--   R1. app_private.superadmin_internal_actor_institution_access_sync (130000)
--       dava membership owner + institution_admin em TODAS as instituicoes
--       ativas a todo espelho interno com platform_membership ativa, sem olhar
--       o escopo da membership (P35 "Superadmin ve tudo" vale so para escopo
--       de plataforma).
--   R2. app_private.has_platform_permission(text) (171000, P7) conta qualquer
--       membership ativa, inclusive a espelhada com escopo de instituicao, e os
--       12 helpers people-based (require_routine_actor, require_health_care_actor,
--       assert_people_permission, assert_child_safety_platform,
--       require_forms_actor, form_require_owner, assert_support_permission,
--       assert_account_actor, access_profile_require_mutation,
--       assert_institution_file_access, assert_institution_identity_access,
--       require_profile_authority) decidem so por essa forma de um argumento.
--
-- Correcao de raiz, sem reescrever helper algum:
--   R1. o sync respeita o escopo: plataforma -> todas as instituicoes ativas;
--       instituicao -> so a propria; memberships de espelho interno fora do
--       escopo (ou de espelho inativo) sao desativadas (inactive + revoked_at).
--   R2. em has_platform_permission(text, uuid), quando o auth user e uma
--       identidade INTERNA (superadmin_internal_auth_links ativo), a
--       membership espelhada com escopo de instituicao so conta quando o
--       chamador informa a instituicao e ela coincide — nunca na forma de um
--       argumento (generaliza a regra do 211200 a todos os 188 chamadores e
--       69 policies). Pessoas do realm people-based mantem P7 intacto.
--   Efeito para uma identidade escopada: RPCs de plataforma negam
--   (deny-by-default) em vez de vazar; RPCs que conhecem a instituicao
--   (forma de dois argumentos ou has_context_permission na membership da
--   propria instituicao) continuam funcionando dentro do escopo.
--
-- Reversao: recriar as duas funcoes como em 20260910171000 e 20260911130000.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $$
begin
  if to_regprocedure('app_private.has_platform_permission(text,uuid)') is null
     or to_regprocedure('app_private.superadmin_internal_actor_institution_access_sync()') is null
     or to_regclass('app_private.superadmin_internal_auth_links') is null
     or to_regclass('app_private.superadmin_internal_actor_people') is null then
    raise object_not_in_prerequisite_state using
      message = 'internal_actor_scope_root_v1: 171000, 220400 e 130000 sao pre-requisitos';
  end if;
end $$;

-- R2 ------------------------------------------------------------------------
create or replace function app_private.has_platform_permission(
  permission_code text,
  institution_id uuid
)
returns boolean
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
as $$
  with internal_actor as (
    select exists (
      select 1 from app_private.superadmin_internal_auth_links auth_link
      where auth_link.auth_user_id = (select auth.uid())
        and auth_link.status = 'active'
    ) as is_internal
  ), memberships as (
    select membership.id, membership.role_id
    from public.platform_memberships membership
    join public.platform_roles role_record on role_record.id = membership.role_id
    cross join internal_actor
    where membership.person_id = app_private.current_person_id()
      and membership.status = 'active' and membership.revoked_at is null
      and role_record.status = 'active'
      and (
        (membership.scope_kind = 'platform' and membership.scope_institution_id is null)
        or (
          membership.scope_kind = 'institution'
          and membership.scope_institution_id is not null
          and (
            membership.scope_institution_id = institution_id
            -- P7: pessoa do realm people-based conta a membership de instituicao
            -- mesmo sem instituicao informada; espelho de identidade interna
            -- escopada, nunca (a instituicao precisa ser informada e coincidir).
            or (institution_id is null and not internal_actor.is_internal)
          )
        )
      )
  ), target as (
    select id from public.platform_permissions
    where code = permission_code and status = 'active'
  ), effects as (
    select grant_record.effect from memberships
    join public.platform_role_permissions grant_record
      on grant_record.role_id = memberships.role_id
     and grant_record.status = 'active' and grant_record.revoked_at is null
    join target on target.id = grant_record.permission_id
    union all
    select override_record.effect from memberships
    join public.platform_member_permission_overrides override_record
      on override_record.membership_id = memberships.id
     and override_record.status = 'active'
     and (override_record.starts_at is null or override_record.starts_at <= now())
     and (override_record.expires_at is null or override_record.expires_at > now())
    join target on target.id = override_record.permission_id
  )
  select exists(select 1 from effects where effect = 'allow')
     and not exists(select 1 from effects where effect = 'deny')
$$;
alter function app_private.has_platform_permission(text, uuid) owner to postgres;
revoke all on function app_private.has_platform_permission(text, uuid) from public, anon;
grant execute on function app_private.has_platform_permission(text, uuid) to authenticated;
comment on function app_private.has_platform_permission(text, uuid) is
  'P7 (ADR 0034, Decisao 12) + raiz da ponte de ator (R06): memberships de plataforma e de instituicao contam; com institution_id, a de instituicao so vale para aquela instituicao; para identidade interna (superadmin_internal_auth_links) a membership espelhada com escopo de instituicao nunca conta sem institution_id. Deny vence allow; sem membership ativa, false.';

-- R1 ------------------------------------------------------------------------
-- Escopo do espelho: plataforma -> todas as instituicoes ativas; instituicao -> so a propria.
create or replace function app_private.superadmin_internal_actor_scope_targets()
returns table (person_id uuid, institution_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select actor.person_id, inst.id
  from app_private.superadmin_internal_actor_people actor
  join public.platform_memberships pm on pm.id = actor.platform_membership_id
    and pm.status = 'active' and pm.revoked_at is null
  join public.institutions inst on inst.status = 'active' and inst.deleted_at is null
    and (
      (pm.scope_kind = 'platform' and pm.scope_institution_id is null)
      or (pm.scope_kind = 'institution' and pm.scope_institution_id = inst.id)
    )
$$;
alter function app_private.superadmin_internal_actor_scope_targets() owner to postgres;
revoke all on function app_private.superadmin_internal_actor_scope_targets() from public, anon, authenticated, service_role;

create or replace function app_private.superadmin_internal_actor_institution_access_sync()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  admin_role_id uuid;
  touched integer := 0;
  n integer;
begin
  select id into admin_role_id from public.institution_roles
  where code = 'institution_admin' and is_system and institution_id is null and status = 'active'
  order by created_at limit 1;
  if admin_role_id is null then return 0; end if;

  -- Reconciliacao: membership de espelho interno fora do escopo (ou de espelho
  -- sem platform_membership ativa) deixa de valer.
  update public.institution_memberships m set status = 'inactive', revoked_at = now()
  from app_private.superadmin_internal_actor_people actor
  where m.person_id = actor.person_id
    and m.status = 'active' and m.revoked_at is null
    and not exists (
      select 1 from app_private.superadmin_internal_actor_scope_targets() t
      where t.person_id = m.person_id and t.institution_id = m.institution_id
    );
  get diagnostics n = row_count; touched := touched + n;

  insert into public.institution_memberships (person_id, institution_id, role_code, status, scope_kind)
  select t.person_id, t.institution_id, 'owner', 'active', 'institution'
  from app_private.superadmin_internal_actor_scope_targets() t
  where not exists (
    select 1 from public.institution_memberships m
    where m.person_id = t.person_id and m.institution_id = t.institution_id
      and m.status = 'active' and m.revoked_at is null
  );
  get diagnostics n = row_count; touched := touched + n;

  insert into public.institution_role_assignments (membership_id, role_id, scope_kind, status)
  select m.id, admin_role_id, 'institution', 'active'
  from public.institution_memberships m
  join app_private.superadmin_internal_actor_scope_targets() t
    on t.person_id = m.person_id and t.institution_id = m.institution_id
  where m.status = 'active' and m.revoked_at is null
    and not exists (
      select 1 from public.institution_role_assignments a
      where a.membership_id = m.id and a.role_id = admin_role_id
        and a.status = 'active' and a.scope_kind = 'institution'
    );
  get diagnostics n = row_count; touched := touched + n;

  return touched;
end
$$;
alter function app_private.superadmin_internal_actor_institution_access_sync() owner to postgres;
revoke all on function app_private.superadmin_internal_actor_institution_access_sync() from public, anon, authenticated;

-- Backfill: reconcilia o que as pontes ja espelharam (em producao, 0 escopadas: no-op esperado).
do $$
declare n integer;
begin
  n := app_private.superadmin_internal_actor_institution_access_sync();
  raise notice 'internal_actor_scope_root_v1: sync reconciliou % linha(s)', n;
end $$;

commit;
