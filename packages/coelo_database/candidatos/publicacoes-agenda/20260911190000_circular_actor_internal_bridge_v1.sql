-- 20260911190000_circular_actor_internal_bridge_v1
--
-- Ator do realm interno v2 nas RPCs people-based de Circulares (ADR 0034;
-- achado da frente publicacoes-agenda na prova em producao de 11/09/2026,
-- R05: circulars.attach devolvia media_prepare_denied e circulars.respond
-- devolvia active_membership_required para qa-r03, embora a pessoa de servico
-- da ponte de ator (220400) tenha membership owner ativa nas instituicoes
-- sinteticas (230024)).
--
-- O que estava errado: app_private.circular_actor() resolvia a pessoa por
-- public.person_auth_links diretamente, ignorando a ponte de ator. A
-- capacidade (has_institution_permission) ja passava; a resolucao do ator nao.
-- Alem disso, app_private.circular_audience_matches_role() nao conhece o papel
-- 'owner' das memberships de instituicao, entao o Owner da instituicao nao via
-- (nem respondia) circular alguma como audiencia.
--
-- O que este pacote faz:
--   1. circular_actor soma a capacidade interna v2 (platform_permissions,
--      mapeadas por circular_internal_capability) a capacidade people-based e
--      passa a resolver a pessoa por app_private.current_person_id()
--      (people-based primeiro, espelho interno depois, exatamente como 220400)
--      e mantem a exigencia de membership ATIVA na instituicao alvo: sem
--      membership continua active_membership_required (deny-by-default).
--   2. circular_audience_matches_role e circular_person_matches_scope reconhecem
--      o papel owner da instituicao em qualquer audiencia (decisao do Owner P23, 11/09/2026: Owner de
--      instituicao e de unidade fazem tudo dentro do seu contexto; P35: o
--      Superadmin ve tudo). Papeis desconhecidos continuam false.
--
-- Nenhuma RPC cliente muda de assinatura; grants nao mudam (funcoes app_private
-- sem grant a cliente). Forward-only; idempotente (create or replace).

begin;

-- Capacidade do realm interno v2 para os codigos people-based de Circulares.
-- Mapeia o codigo people-based para a permissao interna (200100) e exige o
-- contexto interno valido; escopo de instituicao da membership interna precisa
-- coincidir com a instituicao alvo. Qualquer negativa vira false (a RPC
-- chamadora decide a mensagem), nunca excecao vazando detalhe.
create or replace function app_private.circular_internal_capability(
  p_institution_id uuid,
  p_permission text
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_code text;
  v_ctx app_private.superadmin_internal_context;
begin
  v_code := case p_permission
    when 'circulars.circulars.read' then 'circulars.read'
    when 'circulars.circulars.respond' then 'circulars.read'
    when 'circulars.circulars.create' then 'circulars.manage'
    when 'circulars.circulars.manage' then 'circulars.manage'
    when 'circulars.circulars.publish' then 'circulars.publish'
    else null
  end;
  if v_code is null then
    return false;
  end if;
  begin
    select * into strict v_ctx from app_private.require_superadmin_internal_context(v_code);
  exception when others then
    return false;
  end;
  if v_ctx.scope_kind = 'institution' and v_ctx.scope_institution_id is distinct from p_institution_id then
    return false;
  end if;
  return true;
end;
$$;

revoke all on function app_private.circular_internal_capability(uuid, text) from public, anon, authenticated, service_role;

create or replace function app_private.circular_actor(
  p_institution_id uuid,
  p_permission text,
  p_unit_id uuid,
  p_group_id uuid
) returns table(person_id uuid, membership_id uuid, role_code text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_person_id uuid;
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication_required';
  end if;
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
$$;

comment on function app_private.circular_actor(uuid, text, uuid, uuid) is
  'Ator de Circulares: capacidade por has_institution_permission e pessoa por current_person_id (ponte de ator 220400); exige membership ativa na instituicao.';

create or replace function app_private.circular_audience_matches_role(
  p_role text,
  p_audience public.circular_audience_kind
) returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    when lower(coalesce(p_role, '')) in ('owner', 'institution_owner', 'unit_owner') then true
    when lower(coalesce(p_role, '')) in ('guardian', 'responsible', 'responsavel', 'parent', 'family') then p_audience in ('families', 'guardians_only')
    when lower(coalesce(p_role, '')) in ('student', 'aluno') then p_audience = 'students'
    when lower(coalesce(p_role, '')) in ('professional', 'institution_admin', 'unit_admin', 'teacher', 'coordinator') then p_audience = 'school_staff'
    else false
  end
$$;

comment on function app_private.circular_audience_matches_role(text, public.circular_audience_kind) is
  'Papel da membership x audiencia da Circular; owner da instituicao alcanca toda audiencia (P23/P35, 11/09/2026).';

-- Escopo por pessoa: o owner da instituicao nao depende de vinculo de responsavel
-- nem de crianca; alcanca a regra como a equipe escolar (P23).
create or replace function app_private.circular_person_matches_scope(
  p_person_id uuid,
  p_role text,
  p_audience public.circular_audience_rules
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when lower(coalesce(p_role,'')) in ('owner','institution_owner','unit_owner') then true
    when lower(coalesce(p_role,'')) in ('guardian','responsible','responsavel','parent','family') then exists (
      select 1
      from public.guardian_links guardian
      join public.guardian_context_permissions permission on permission.guardian_link_id=guardian.id
      where guardian.guardian_person_id=p_person_id
        and guardian.status='active' and guardian.revoked_at is null
        and permission.status='active' and permission.can_view
        and (permission.starts_at is null or permission.starts_at<=now())
        and (permission.expires_at is null or permission.expires_at>now())
        and app_private.circular_child_scope_matches(permission.child_context_id,p_audience)
    )
    when lower(coalesce(p_role,'')) in ('student','aluno') then exists (
      select 1 from public.child_contexts child
      where child.child_person_id=p_person_id
        and app_private.circular_child_scope_matches(child.id,p_audience)
    )
    when lower(coalesce(p_role,'')) in ('professional','institution_admin','unit_admin','teacher','coordinator') then true
    else false
  end
$$;

commit;
