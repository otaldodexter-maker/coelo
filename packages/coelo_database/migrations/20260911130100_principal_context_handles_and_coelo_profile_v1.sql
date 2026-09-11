-- Rodada 5 (E2-R05-20260911), principal-chat-sistema. Decisoes do Owner de
-- 11/09: P28 ("o @ do perfil deve aparecer"), P35 B (perfil/usuario Coelo que
-- segue e e seguido por todos; arrobas coelo e coelo.me reservados) e a regra
-- do @ (ADR 0034 Decisao 16: o Identificador e o @; em institutions o @ e a
-- coluna slug, normalizada por enforce_institution_handle).
--
-- O que este pacote faz, forward-only e idempotente:
--   1. list_my_principal_contexts passa a devolver institution_handle (o @ da
--      instituicao = slug) e unit_handle (units.handle). O tipo de retorno
--      muda, entao a funcao e recriada (drop + create); grants identicos.
--   2. public.reserved_handles: lista de arrobas que nenhuma entidade pode usar
--      (coelo, coelo.me; cresce por migration). Gatilhos BEFORE em institutions
--      (slug) e units (handle) recusam com check_violation. Pessoas ainda nao
--      tem coluna de @ (pacote do grupo acessos-pessoas); quando ela existir,
--      o mesmo gatilho e reaproveitado.
--   3. Perfil Coelo: pessoa de servico fixa c0e10000-0000-4000-8000-000000000001
--      ("Coelo"), seguida por toda pessoa ativa e seguindo toda pessoa ativa em
--      public.follow_links (origem manual, porque a origem automatic exige
--      contexto de crianca; pendencia: valor 'system' no enum). Backfill agora
--      e gatilho AFTER INSERT em people. Avatar (logo laranja/coelho branco) e
--      capa da marca dependem do catalogo de midia de perfil de pessoa, que
--      ainda nao existe: pendencia registrada.
-- Nao concede nada a anon; nada de RLS e afrouxado.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $$
begin
  if to_regprocedure('public.list_my_principal_contexts()') is null
     or to_regprocedure('app_private.person_id_for_auth_user(uuid)') is null
     or to_regclass('public.follow_links') is null then
    raise exception 'principal_context_handles_and_coelo_profile_v1: exige 20260911130000 e 20260910171100';
  end if;
end $$;

-- 1. contextos com @ ----------------------------------------------------------
drop function public.list_my_principal_contexts();
create function public.list_my_principal_contexts()
returns table(
  membership_id uuid,
  person_id uuid,
  institution_id uuid,
  institution_name text,
  role_code text,
  scope_kind text,
  unit_id uuid,
  unit_name text,
  group_id uuid,
  group_name text,
  institution_handle text,
  unit_handle text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication_required';
  end if;

  return query
  select
    membership.id,
    membership.person_id,
    membership.institution_id,
    institution.public_name,
    membership.role_code,
    membership.scope_kind,
    scoped_unit.id,
    scoped_unit.name,
    scoped_group.id,
    scoped_group.name,
    institution.slug,
    scoped_unit.handle
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
  where person.id = app_private.person_id_for_auth_user((select auth.uid()))
    and person.status = 'active'
    and (
      (
        membership.scope_kind = 'institution'
        and membership.scope_unit_id is null
        and membership.scope_group_id is null
      )
      or (
        membership.scope_kind = 'unit'
        and membership.scope_unit_id is not null
        and membership.scope_group_id is null
        and scoped_unit.id is not null
      )
      or (
        membership.scope_kind = 'group'
        and membership.scope_group_id is not null
        and scoped_group.id is not null
        and (
          membership.scope_unit_id is null
          or membership.scope_unit_id = scoped_group.unit_id
        )
      )
    )
  order by institution.public_name, scoped_unit.name nulls first,
    scoped_group.name nulls first, membership.created_at, membership.id;
end
$$;
revoke all on function public.list_my_principal_contexts() from public, anon, authenticated;
grant execute on function public.list_my_principal_contexts() to authenticated;

-- 2. arrobas reservados ---------------------------------------------------------
create table if not exists public.reserved_handles (
  handle text primary key,
  reason text not null,
  created_at timestamptz not null default now()
);
alter table public.reserved_handles enable row level security;
revoke all on public.reserved_handles from public, anon, authenticated;
insert into public.reserved_handles (handle, reason) values
  ('coelo', 'perfil oficial do app (P35)'),
  ('coelo.me', 'dominio e perfil oficial do app (P35)')
on conflict (handle) do nothing;

create or replace function app_private.is_reserved_handle(p_handle text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.reserved_handles r
    where r.handle = lower(trim(coalesce(p_handle, '')))
  )
$$;
revoke all on function app_private.is_reserved_handle(text) from public, anon, authenticated;

create or replace function app_private.enforce_institution_reserved_handle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if app_private.is_reserved_handle(new.slug) then
    raise check_violation using message = 'handle_reserved';
  end if;
  return new;
end
$$;
revoke all on function app_private.enforce_institution_reserved_handle() from public, anon, authenticated;

create or replace function app_private.enforce_unit_reserved_handle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if app_private.is_reserved_handle(new.handle) then
    raise check_violation using message = 'handle_reserved';
  end if;
  return new;
end
$$;
revoke all on function app_private.enforce_unit_reserved_handle() from public, anon, authenticated;

drop trigger if exists institutions_reserved_handle on public.institutions;
create trigger institutions_reserved_handle
  before insert or update of slug on public.institutions
  for each row execute function app_private.enforce_institution_reserved_handle();

drop trigger if exists units_reserved_handle on public.units;
create trigger units_reserved_handle
  before insert or update of handle on public.units
  for each row execute function app_private.enforce_unit_reserved_handle();

-- 3. perfil Coelo ----------------------------------------------------------------
insert into public.people (id, person_type, first_name, last_name, display_name, status)
values ('c0e10000-0000-4000-8000-000000000001', 'service', 'Coelo', '', 'Coelo', 'active')
on conflict (id) do nothing;

create or replace function app_private.coelo_profile_follow_sync()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  coelo constant uuid := 'c0e10000-0000-4000-8000-000000000001';
  touched integer := 0;
  n integer;
begin
  -- todos acompanham a Coelo
  insert into public.follow_links (follower_person_id, target_kind, target_id, origin)
  select person.id, 'person', coelo, 'manual'
  from public.people person
  where person.status = 'active' and person.deleted_at is null and person.id <> coelo
    and not exists (
      select 1 from public.follow_links link
      where link.follower_person_id = person.id and link.target_kind = 'person'
        and link.target_id = coelo and link.status = 'active'
    );
  get diagnostics n = row_count; touched := touched + n;
  -- a Coelo acompanha todos
  insert into public.follow_links (follower_person_id, target_kind, target_id, origin)
  select coelo, 'person', person.id, 'manual'
  from public.people person
  where person.status = 'active' and person.deleted_at is null and person.id <> coelo
    and not exists (
      select 1 from public.follow_links link
      where link.follower_person_id = coelo and link.target_kind = 'person'
        and link.target_id = person.id and link.status = 'active'
    );
  get diagnostics n = row_count; touched := touched + n;
  return touched;
end
$$;
revoke all on function app_private.coelo_profile_follow_sync() from public, anon, authenticated;

create or replace function app_private.coelo_profile_follow_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app_private.coelo_profile_follow_sync();
  return null;
end
$$;
revoke all on function app_private.coelo_profile_follow_trigger() from public, anon, authenticated;

drop trigger if exists people_coelo_profile_follow on public.people;
create trigger people_coelo_profile_follow
  after insert on public.people
  for each row when (new.status = 'active')
  execute function app_private.coelo_profile_follow_trigger();

select app_private.coelo_profile_follow_sync();

commit;
