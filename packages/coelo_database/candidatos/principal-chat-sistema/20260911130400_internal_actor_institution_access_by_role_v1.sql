-- 20260911130400_internal_actor_institution_access_by_role_v1.sql
-- Rodada 6, frente principal-chat-sistema. P48 (Owner, 11/09/2026 16:45,
-- opcao A): o sincronizador "Superadmin ve tudo" (130000) passa a distinguir o
-- papel interno do usuario Superadmin:
--   * owner      -> membership owner + papel de sistema institution_admin
--                   (como hoje);
--   * operations -> membership 'professional' + papel de sistema
--                   institution_reader (somente permissoes *.read);
--   * demais papeis internos (auditor, content, support...) -> nenhum vinculo
--                   automatico; o que o 130000 ja tinha concedido a eles e
--                   revogado (status inactive + revoked_at) neste pacote.
-- O papel institution_reader nasce aqui como modelo de sistema (institution_id
-- nulo, is_system) com toda permissao ativa cujo codigo termina em ".read".
-- Forward-only, idempotente; nunca apaga linhas: revoga por status/revoked_at.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user not in ('postgres', 'supabase_admin') then
    raise insufficient_privilege using message = 'must run as postgres';
  end if;
  if to_regprocedure('app_private.superadmin_internal_actor_institution_access_sync()') is null then
    raise object_not_in_prerequisite_state using message = 'pacote 20260911130000 e prerequisito';
  end if;
  if to_regclass('public.institution_permissions') is null
     or to_regclass('public.institution_role_permissions') is null then
    raise object_not_in_prerequisite_state using message = 'catalogo de papeis de instituicao e prerequisito';
  end if;
end
$preflight$;

-- 1. Papel de sistema de leitura (idempotente por codigo + is_system + institution_id nulo).
do $reader$
declare
  reader_role_id uuid;
begin
  insert into public.institution_roles (institution_id, code, name, description, is_system, status, max_scope_kind)
  select null, 'institution_reader', 'Leitura', 'Somente leitura da instituicao, unidades e turmas (equipe interna Coelo de operacoes).', true, 'active', 'institution'
  where not exists (
    select 1 from public.institution_roles r
    where r.institution_id is null and r.code = 'institution_reader' and r.is_system
  );
  select r.id into reader_role_id from public.institution_roles r
  where r.institution_id is null and r.code = 'institution_reader' and r.is_system
  order by r.created_at limit 1;

  insert into public.institution_role_permissions (role_id, permission_id, effect, status)
  select reader_role_id, p.id, 'allow', 'active'
  from public.institution_permissions p
  where p.status = 'active' and p.code like '%.read'
    and not exists (
      select 1 from public.institution_role_permissions existing
      where existing.role_id = reader_role_id and existing.permission_id = p.id
        and existing.status = 'active' and existing.revoked_at is null
    );
end
$reader$;

-- 2. Sincronizador por papel interno.
create or replace function app_private.superadmin_internal_actor_institution_access_sync()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  admin_role_id uuid;
  reader_role_id uuid;
  touched integer := 0;
  n integer;
begin
  select id into admin_role_id from public.institution_roles
  where code = 'institution_admin' and is_system and institution_id is null and status = 'active'
  order by created_at limit 1;
  select id into reader_role_id from public.institution_roles
  where code = 'institution_reader' and is_system and institution_id is null and status = 'active'
  order by created_at limit 1;
  if admin_role_id is null or reader_role_id is null then return 0; end if;

  -- Alvo por espelho interno ativo: papel interno -> (role_code da membership, papel de sistema).
  drop table if exists internal_actor_targets;
  create temp table internal_actor_targets on commit drop as
  select actor.person_id,
         pr.code as platform_role_code,
         case pr.code when 'owner' then 'owner' when 'operations' then 'professional' end as membership_role_code,
         case pr.code when 'owner' then admin_role_id when 'operations' then reader_role_id end as target_role_id
  from app_private.superadmin_internal_actor_people actor
  join public.platform_memberships pm on pm.id = actor.platform_membership_id
    and pm.status = 'active' and pm.revoked_at is null
  join public.platform_roles pr on pr.id = pm.role_id;

  -- 2a. Revoga papeis de sistema concedidos pelo sincronizador que nao batem com o alvo
  -- (ex.: institution_admin dado a operations pelo 130000; ou papel interno rebaixado).
  update public.institution_role_assignments a
     set status = 'inactive', updated_at = now(), version = a.version + 1
    from public.institution_memberships m
    join internal_actor_targets t on t.person_id = m.person_id
   where a.membership_id = m.id
     and a.status = 'active' and a.scope_kind = 'institution'
     and a.role_id in (admin_role_id, reader_role_id)
     and a.role_id is distinct from t.target_role_id;
  get diagnostics n = row_count; touched := touched + n;

  -- 2b. Espelhos sem alvo (auditor, content, support...) perdem a membership automatica.
  update public.institution_memberships m
     set status = 'inactive', revoked_at = now()
    from internal_actor_targets t
   where m.person_id = t.person_id and t.target_role_id is null
     and m.status = 'active' and m.revoked_at is null
     and m.role_code in ('owner', 'professional');
  get diagnostics n = row_count; touched := touched + n;

  -- 2c. Membership com o role_code do alvo em toda instituicao ativa.
  update public.institution_memberships m
     set role_code = t.membership_role_code
    from internal_actor_targets t
   where m.person_id = t.person_id and t.target_role_id is not null
     and m.status = 'active' and m.revoked_at is null
     and m.role_code in ('owner', 'professional')
     and m.role_code <> t.membership_role_code;
  get diagnostics n = row_count; touched := touched + n;

  insert into public.institution_memberships (person_id, institution_id, role_code, status, scope_kind)
  select t.person_id, inst.id, t.membership_role_code, 'active', 'institution'
  from internal_actor_targets t
  cross join public.institutions inst
  where t.target_role_id is not null
    and inst.status = 'active' and inst.deleted_at is null
    and not exists (
      select 1 from public.institution_memberships m
      where m.person_id = t.person_id and m.institution_id = inst.id
        and m.status = 'active' and m.revoked_at is null
    );
  get diagnostics n = row_count; touched := touched + n;

  -- 2d. Papel de sistema do alvo.
  insert into public.institution_role_assignments (membership_id, role_id, scope_kind, status)
  select m.id, t.target_role_id, 'institution', 'active'
  from public.institution_memberships m
  join internal_actor_targets t on t.person_id = m.person_id and t.target_role_id is not null
  join public.institutions inst on inst.id = m.institution_id
    and inst.status = 'active' and inst.deleted_at is null
  where m.status = 'active' and m.revoked_at is null
    and not exists (
      select 1 from public.institution_role_assignments a
      where a.membership_id = m.id and a.role_id = t.target_role_id
        and a.status = 'active' and a.scope_kind = 'institution'
    );
  get diagnostics n = row_count; touched := touched + n;

  drop table if exists internal_actor_targets;
  return touched;
end
$$;
revoke all on function app_private.superadmin_internal_actor_institution_access_sync() from public, anon, authenticated;

-- 3. Backfill agora (os gatilhos do 130000 continuam chamando esta funcao).
select app_private.superadmin_internal_actor_institution_access_sync();

commit;
