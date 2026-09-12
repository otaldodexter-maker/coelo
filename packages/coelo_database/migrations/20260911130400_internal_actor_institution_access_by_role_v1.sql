-- 20260911130400_internal_actor_institution_access_by_role_v1.sql
-- Rodada 6, frente principal-chat-sistema. P48 (Owner, 11/09/2026 16:45,
-- opcao A). Reescrito (21:30) sobre o corpo do 20260912210100 (realm-interno),
-- que ja esta em producao: escopo por superadmin_internal_actor_scope_targets()
-- e reconciliacao fora do escopo preservadas. O sincronizador passa a distinguir o
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
  if to_regprocedure('app_private.superadmin_internal_actor_scope_targets()') is null then
    raise object_not_in_prerequisite_state using message = 'pacote 20260912210100 (realm-interno) e prerequisito';
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

-- 2. Sincronizador por papel interno, sobre o corpo do 20260912210100
--    (realm-interno): o escopo vem de superadmin_internal_actor_scope_targets()
--    (platform -> toda instituicao; institution -> so a instituicao do vinculo)
--    e a reconciliacao fora do escopo continua desativando.
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

  -- Alvo = escopo (210100) x papel interno (P48): owner -> owner/institution_admin;
  -- operations -> professional/institution_reader; demais -> sem alvo.
  drop table if exists internal_actor_targets;
  create temp table internal_actor_targets on commit drop as
  select t.person_id, t.institution_id, t.institution_status,
         pr.code as platform_role_code,
         case pr.code when 'owner' then 'owner' when 'operations' then 'professional' end as membership_role_code,
         case pr.code when 'owner' then admin_role_id when 'operations' then reader_role_id end as target_role_id
  from app_private.superadmin_internal_actor_scope_targets() t
  join app_private.superadmin_internal_actor_people actor on actor.person_id = t.person_id
  join public.platform_memberships pm on pm.id = actor.platform_membership_id
  join public.platform_roles pr on pr.id = pm.role_id;

  -- 2a. Reconciliacao (210100): membership de espelho interno fora do escopo, de
  -- espelho sem platform_membership ativa ou de papel interno sem alvo deixa de valer.
  update public.institution_memberships m set status = 'inactive', revoked_at = now()
  from app_private.superadmin_internal_actor_people actor
  where m.person_id = actor.person_id
    and m.status = 'active' and m.revoked_at is null
    and not exists (
      select 1 from internal_actor_targets t
      where t.person_id = m.person_id and t.institution_id = m.institution_id
        and t.target_role_id is not null
    );
  get diagnostics n = row_count; touched := touched + n;

  -- 2b. Papel de sistema que nao bate com o alvo (ex.: institution_admin dado a
  -- operations pelo 130000/210100; papel interno rebaixado ou promovido).
  update public.institution_role_assignments a
     set status = 'inactive', updated_at = now(), version = a.version + 1
    from public.institution_memberships m
    join internal_actor_targets t on t.person_id = m.person_id and t.institution_id = m.institution_id
   where a.membership_id = m.id
     and a.status = 'active' and a.scope_kind = 'institution'
     and a.role_id in (admin_role_id, reader_role_id)
     and a.role_id is distinct from t.target_role_id;
  get diagnostics n = row_count; touched := touched + n;

  -- 2c. role_code da membership acompanha o alvo.
  update public.institution_memberships m
     set role_code = t.membership_role_code
    from internal_actor_targets t
   where m.person_id = t.person_id and m.institution_id = t.institution_id
     and t.target_role_id is not null
     and m.status = 'active' and m.revoked_at is null
     and m.role_code in ('owner', 'professional')
     and m.role_code <> t.membership_role_code;
  get diagnostics n = row_count; touched := touched + n;

  insert into public.institution_memberships (person_id, institution_id, role_code, status, scope_kind)
  select t.person_id, t.institution_id, t.membership_role_code, 'active', 'institution'
  from internal_actor_targets t
  where t.target_role_id is not null and t.institution_status = 'active'
    and not exists (
      select 1 from public.institution_memberships m
      where m.person_id = t.person_id and m.institution_id = t.institution_id
        and m.status = 'active' and m.revoked_at is null
    );
  get diagnostics n = row_count; touched := touched + n;

  -- 2d. Papel de sistema do alvo.
  insert into public.institution_role_assignments (membership_id, role_id, scope_kind, status)
  select m.id, t.target_role_id, 'institution', 'active'
  from public.institution_memberships m
  join internal_actor_targets t
    on t.person_id = m.person_id and t.institution_id = m.institution_id
  where m.status = 'active' and m.revoked_at is null
    and t.target_role_id is not null and t.institution_status = 'active'
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
alter function app_private.superadmin_internal_actor_institution_access_sync() owner to postgres;
revoke all on function app_private.superadmin_internal_actor_institution_access_sync() from public, anon, authenticated;

-- 3. Backfill agora (os gatilhos do 130000 continuam chamando esta funcao).
select app_private.superadmin_internal_actor_institution_access_sync();

commit;
