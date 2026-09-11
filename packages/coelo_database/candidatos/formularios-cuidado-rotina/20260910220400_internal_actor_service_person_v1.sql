-- 20260910220400_internal_actor_service_person_v1
--
-- Ator do realm interno v2 nas familias people-based (ADR 0034; achado
-- F-R04-FCR-002 do grupo formularios-cuidado-rotina, 10/09/2026).
--
-- O que estava errado: a sessao interna do Superadmin (realm interno v2,
-- app_private.superadmin_internal_*) nao tem person_auth_link nem
-- platform_membership. As RPCs de Cuidado, Medicacao, Rotina, Assiduidade,
-- Alunos e Formularios resolvem o ator por app_private.current_person_id() e a
-- capacidade por app_private.has_platform_permission(), que so olham o realm
-- people-based; para elas a sessao interna e "nao autenticada". Alem disso, o
-- catalogo de producao nao tem os codigos attendance.read, attendance.manage
-- e people.assign_children, e nenhum papel de plataforma concede health_care,
-- medication, routine ou attendance.
--
-- O que este pacote faz, sem reescrever RPC alguma:
--   1. completa o catalogo (attendance.read, attendance.manage,
--      people.assign_children) e concede ao papel owner as permissoes das
--      familias do recorte (Decisao 12/P7: tudo passa por perfil e permissao;
--      owner e o piso, nada e Owner-only por desenho);
--   2. espelha cada identidade interna numa pessoa de servico
--      (people.person_type = 'service') e a membership interna ativa numa
--      platform_membership no MESMO papel de plataforma; mantido por gatilho;
--   3. app_private.current_person_id() passa a cair no espelho quando o auth
--      user nao tem person_auth_link (o realm people-based continua tendo
--      precedencia e nada muda para quem ja tem pessoa).
--
-- Nao cria person_auth_link (o guard do realm interno impede e nao e preciso).
-- Nao afrouxa RLS: a tabela nova fica em app_private sem grant a cliente.

-- ---------------------------------------------------------------------------
-- 1. Catalogo e concessoes ao papel owner
-- ---------------------------------------------------------------------------

insert into public.platform_permissions(
  code, module_code, module_label, screen_code, screen_label,
  action_code, action_label, description, risk_level, requires_mfa
) values
  ('attendance.read','attendance','Assiduidade','attendance_calls',
   'Chamadas','read','Ver',
   'Visualizar chamadas e presencas no escopo autorizado.','high',false),
  ('attendance.manage','attendance','Assiduidade','attendance_calls',
   'Chamadas','manage','Gerenciar',
   'Abrir, marcar, corrigir e concluir chamadas no escopo autorizado.','high',false),
  ('people.assign_children','people','Pessoas','students',
   'Alunos','assign_children','Vincular',
   'Vincular, transferir, editar e revogar vinculos de crianca com unidades e turmas.','critical',false)
on conflict (code) do nothing;

insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_row.id, permission_row.id, 'allow', 'active'
from public.platform_roles role_row
cross join public.platform_permissions permission_row
where role_row.code = 'owner'
  and permission_row.status = 'active'
  and (permission_row.code like 'health_care.%'
    or permission_row.code like 'medication.%'
    or permission_row.code like 'routine.%'
    or permission_row.code like 'attendance.%'
    or permission_row.code in ('people.assign_children', 'people.read'))
  and not exists (
    select 1 from public.platform_role_permissions existing
    where existing.role_id = role_row.id
      and existing.permission_id = permission_row.id
  );

-- ---------------------------------------------------------------------------
-- 2. Espelho da identidade interna como pessoa de servico
-- ---------------------------------------------------------------------------

create table if not exists app_private.superadmin_internal_actor_people (
  internal_identity_id uuid primary key
    references app_private.superadmin_internal_identities(id) on delete cascade,
  person_id uuid not null unique references public.people(id) on delete restrict,
  platform_membership_id uuid references public.platform_memberships(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
revoke all on app_private.superadmin_internal_actor_people from anon, authenticated;

create or replace function app_private.superadmin_internal_actor_sync(
  p_internal_identity_id uuid
) returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  mapping app_private.superadmin_internal_actor_people;
  membership app_private.superadmin_internal_memberships;
  actor_person_id uuid;
  mirror_id uuid;
  short_id text := left(p_internal_identity_id::text, 8);
begin
  select * into membership
  from app_private.superadmin_internal_memberships
  where internal_identity_id = p_internal_identity_id
  order by (status = 'active') desc, created_at desc
  limit 1;

  select * into mapping
  from app_private.superadmin_internal_actor_people
  where internal_identity_id = p_internal_identity_id;

  if mapping.person_id is null then
    -- Pessoa de servico: representa a identidade interna nas tabelas que
    -- exigem people(id). Sem CPF, sem contato, sem vinculo familiar.
    insert into public.people(person_type, first_name, last_name, display_name, status)
    values ('service', 'Operador interno', short_id, 'Operador interno ' || short_id, 'active')
    returning id into actor_person_id;
    insert into app_private.superadmin_internal_actor_people(internal_identity_id, person_id)
    values (p_internal_identity_id, actor_person_id);
  else
    actor_person_id := mapping.person_id;
  end if;

  if membership.id is not null and membership.status = 'active' then
    if mapping.platform_membership_id is null then
      insert into public.platform_memberships(
        person_id, role_id, status, scope_kind, scope_institution_id, mfa_required
      ) values (
        actor_person_id, membership.platform_role_id, 'active',
        membership.scope_kind::text, membership.scope_institution_id, false
      ) returning id into mirror_id;
      update app_private.superadmin_internal_actor_people
        set platform_membership_id = mirror_id, updated_at = now()
        where internal_identity_id = p_internal_identity_id;
    else
      update public.platform_memberships set
        role_id = membership.platform_role_id,
        status = 'active',
        scope_kind = membership.scope_kind::text,
        scope_institution_id = membership.scope_institution_id,
        revoked_at = null
      where id = mapping.platform_membership_id;
    end if;
  elsif mapping.platform_membership_id is not null then
    -- Suspensa ou revogada no realm interno: o espelho acompanha, e
    -- has_platform_permission deixa de reconhecer a sessao.
    update public.platform_memberships set
      status = case when membership.status = 'suspended' then 'suspended' else 'revoked' end,
      revoked_at = case when membership.status = 'suspended' then null else now() end
    where id = mapping.platform_membership_id;
  end if;

  return actor_person_id;
end
$$;
revoke all on function app_private.superadmin_internal_actor_sync(uuid) from public, anon, authenticated;

create or replace function app_private.superadmin_internal_actor_sync_trigger()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  perform app_private.superadmin_internal_actor_sync(new.internal_identity_id);
  return new;
end
$$;

drop trigger if exists superadmin_internal_memberships_actor_mirror
  on app_private.superadmin_internal_memberships;
create trigger superadmin_internal_memberships_actor_mirror
  after insert or update of platform_role_id, status, scope_kind, scope_institution_id
  on app_private.superadmin_internal_memberships
  for each row execute function app_private.superadmin_internal_actor_sync_trigger();

-- ---------------------------------------------------------------------------
-- 3. Ator da sessao: realm people-based primeiro, espelho interno depois
-- ---------------------------------------------------------------------------

create or replace function app_private.current_person_id()
returns uuid
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(
    (
      select auth_link.person_id
      from public.person_auth_links auth_link
      where auth_link.auth_user_id = (select auth.uid())
        and auth_link.status = 'active'
        and auth_link.revoked_at is null
      order by auth_link.linked_at desc, auth_link.id
      limit 1
    ),
    (
      select actor.person_id
      from app_private.superadmin_internal_auth_links internal_link
      join app_private.superadmin_internal_actor_people actor
        on actor.internal_identity_id = internal_link.internal_identity_id
      where internal_link.auth_user_id = (select auth.uid())
        and internal_link.status = 'active'
      order by internal_link.created_at desc
      limit 1
    )
  )
$$;

-- ---------------------------------------------------------------------------
-- 4. Backfill das identidades que ja existem
-- ---------------------------------------------------------------------------

select app_private.superadmin_internal_actor_sync(identity_row.id)
from app_private.superadmin_internal_identities identity_row;
