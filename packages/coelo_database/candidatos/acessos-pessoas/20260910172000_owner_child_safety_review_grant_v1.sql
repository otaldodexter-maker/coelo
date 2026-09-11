-- Achado da R04 (11/09/2026, 03:08): editar/excluir/reatribuir perfil de acesso
-- (superadmin_access_profile_update / delete_and_reassign / assignment_unlink)
-- falha em producao com 23514 'active full-authority MFA replacement required'.
-- A guarda app_private.assert_full_authority_remains exige que continue
-- existindo uma membership de plataforma ativa cujo papel conceda TODAS as
-- permissoes de plataforma ativas. Em producao o Owner tem 134 das 135: falta
-- child_safety.review (criada pelo lote 4 sem concessao ao Owner). Resultado:
-- nenhuma edicao de perfil e possivel.
--
-- Este pacote concede child_safety.review ao papel owner (idempotente). Nao
-- muda quem decide autorizacoes de retirada: a decisao continua exigindo
-- revisor exato da unidade (P32 e o candidato retido 171800). A guarda ainda
-- exige membership.mfa_required em uma linha (ha uma em producao); alinha-la
-- a Decisao 12 fica registrado para o code review.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'owner grant must run as postgres';
  end if;
  if not exists (select 1 from public.platform_roles where code = 'owner' and status = 'active')
     or not exists (select 1 from public.platform_permissions where code = 'child_safety.review' and status = 'active') then
    raise object_not_in_prerequisite_state using message = 'owner role and child_safety.review are required';
  end if;
end
$preflight$;

insert into public.platform_role_permissions (role_id, permission_id, effect, conditions_json, status)
select role_record.id, permission_record.id, 'allow', '{}'::jsonb, 'active'
from public.platform_roles role_record
join public.platform_permissions permission_record on permission_record.code = 'child_safety.review'
where role_record.code = 'owner' and role_record.status = 'active'
  and not exists (
    select 1 from public.platform_role_permissions existing
    where existing.role_id = role_record.id and existing.permission_id = permission_record.id
      and existing.status = 'active' and existing.revoked_at is null
  );

do $postflight$
declare missing text;
begin
  select string_agg(permission_record.code, ',') into missing
  from public.platform_permissions permission_record
  where permission_record.status = 'active' and not exists (
    select 1 from public.platform_role_permissions grant_record
    join public.platform_roles role_record on role_record.id = grant_record.role_id and role_record.code = 'owner'
    where grant_record.permission_id = permission_record.id and grant_record.status = 'active'
      and grant_record.revoked_at is null and grant_record.effect = 'allow');
  if missing is not null then
    raise object_not_in_prerequisite_state using message = 'owner still lacks: ' || missing;
  end if;
end
$postflight$;

commit;
