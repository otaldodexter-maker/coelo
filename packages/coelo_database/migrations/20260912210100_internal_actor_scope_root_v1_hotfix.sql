-- R06 realm-interno (1b): HOTFIX do 20260912210000 aplicado em producao no lote 50
-- (20:12) na versao da rev 40. Aquela versao definia o escopo do espelho so
-- sobre instituicoes ATIVAS, e a reconciliacao desativou as memberships de
-- espelho de PLATAFORMA na instituicao em rascunho qa-r04-escola (7 linhas
-- medidas as 20:18: os qa-r06-* do lote 49), quebrando o padrao do lote 27/P42.
--
-- O que este pacote faz (idempotente):
--   1. instala a versao final (rev 42) de superadmin_internal_actor_scope_targets
--      (devolve institution_status; escopo sem filtro de status) e do sync
--      (reconcilia so FORA do escopo; insere so em instituicoes ativas);
--   2. reativa as memberships de espelho desativadas pela reconciliacao da
--      versao anterior: status inactive, revoked_at nas ultimas 24 h, pessoa de
--      servico e instituicao dentro do escopo da versao final.
-- has_platform_permission(text,uuid) do 20260912210000 nao muda.
-- Reversao: recriar as funcoes como em 20260912210000 (versao aplicada).

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $$
begin
  if to_regprocedure('app_private.superadmin_internal_actor_scope_targets()') is null then
    raise object_not_in_prerequisite_state using message = 'internal_actor_scope_root_v1 (20260912210000) e pre-requisito';
  end if;
end $$;

-- R1 ------------------------------------------------------------------------
-- Escopo do espelho: plataforma -> todas as instituicoes (nao apagadas);
-- instituicao -> so a propria. O status da instituicao nao entra aqui: a
-- reconciliacao so desativa membership FORA do escopo (ou de espelho inativo),
-- nunca a de uma instituicao em rascunho/arquivada (lote 27 e P42).
drop function if exists app_private.superadmin_internal_actor_scope_targets();
create function app_private.superadmin_internal_actor_scope_targets()
returns table (person_id uuid, institution_id uuid, institution_status text)
language sql
stable
security definer
set search_path = ''
as $$
  select actor.person_id, inst.id, inst.status::text
  from app_private.superadmin_internal_actor_people actor
  join public.platform_memberships pm on pm.id = actor.platform_membership_id
    and pm.status = 'active' and pm.revoked_at is null
  join public.institutions inst on inst.deleted_at is null
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
  where t.institution_status = 'active'
    and not exists (
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
    and t.institution_status = 'active'
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

-- 2. Reativacao do que a versao anterior desativou indevidamente -------------------
create or replace function app_private.superadmin_internal_actor_scope_reactivate_v1()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare n integer;
begin
  update public.institution_memberships m set status = 'active', revoked_at = null
  from app_private.superadmin_internal_actor_people actor
  where m.person_id = actor.person_id
    and m.status = 'inactive' and m.revoked_at >= now() - interval '24 hours'
    and exists (
      select 1 from app_private.superadmin_internal_actor_scope_targets() t
      where t.person_id = m.person_id and t.institution_id = m.institution_id
    )
    and not exists (
      select 1 from public.institution_memberships other
      where other.person_id = m.person_id and other.institution_id = m.institution_id
        and other.status = 'active' and other.revoked_at is null
    );
  get diagnostics n = row_count;
  return n;
end
$$;
alter function app_private.superadmin_internal_actor_scope_reactivate_v1() owner to postgres;
revoke all on function app_private.superadmin_internal_actor_scope_reactivate_v1() from public, anon, authenticated, service_role;

do $$
declare n integer;
begin
  n := app_private.superadmin_internal_actor_scope_reactivate_v1();
  raise notice 'internal_actor_scope_root_v1_hotfix: % membership(s) de espelho reativada(s)', n;
  n := app_private.superadmin_internal_actor_institution_access_sync();
  raise notice 'internal_actor_scope_root_v1_hotfix: sync reconciliou % linha(s)', n;
end $$;

commit;
