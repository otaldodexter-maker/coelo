-- Perfis oficiais — spec 068: o follow automático cobre também a pessoa-ator dos operadores
-- internos (app_private.superadmin_internal_actor_people), que usam o Principal hospedado e
-- resolvem por app_private.current_person_id() sem person_auth_links. Lote 105.
-- Reversão: recriar app_private.official_profiles_backfill_follows_v1() do lote 95.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then raise exception 'executar como postgres'; end if;
  if to_regclass('app_private.superadmin_internal_actor_people') is null
    or to_regprocedure('app_private.official_profiles_backfill_follows_v1()') is null then
    raise exception 'pre-requisitos ausentes (lotes 95/104 e ator interno)';
  end if;
end $preflight$;

create or replace function app_private.official_profiles_backfill_follows_v1()
returns integer language plpgsql security definer set search_path = '' as $$
declare inserted integer;
begin
  with followers as (
    -- famílias e equipes: login vinculado a uma pessoa ativa, nunca pessoa técnica
    select l.person_id
    from public.person_auth_links l
    join public.people p on p.id = l.person_id
    where l.status = 'active' and p.status = 'active' and p.person_type <> 'service'
    union
    -- operadores internos: a pessoa-ator do vínculo interno ativo
    select actor.person_id
    from app_private.superadmin_internal_actor_people actor
    join app_private.superadmin_internal_auth_links link
      on link.internal_identity_id = actor.internal_identity_id and link.status = 'active'
    join public.people p on p.id = actor.person_id and p.status = 'active'
  )
  insert into public.follow_links(follower_person_id, target_kind, target_id, origin)
  select distinct fw.person_id, 'person'::public.follow_target_kind, o.person_id, 'official_auto'::public.follow_origin
  from public.official_profiles o
  cross join followers fw
  where o.status = 'active' and fw.person_id <> o.person_id
    and not exists (select 1 from public.official_profiles x where x.person_id = fw.person_id)
    -- já segue por qualquer origem
    and not exists (select 1 from public.follow_links f where f.follower_person_id = fw.person_id
      and f.target_kind = 'person' and f.target_id = o.person_id and f.status = 'active')
    -- revogou um follow automático de oficial não obrigatório: respeita
    and not (not o.mandatory and exists (select 1 from public.follow_links f
      where f.follower_person_id = fw.person_id and f.target_kind = 'person'
        and f.target_id = o.person_id and f.origin = 'official_auto' and f.status <> 'active'));
  get diagnostics inserted = row_count;
  return inserted;
end
$$;
alter function app_private.official_profiles_backfill_follows_v1() owner to postgres;
revoke all on function app_private.official_profiles_backfill_follows_v1() from public, anon, authenticated, service_role;

select app_private.official_profiles_backfill_follows_v1();

commit;
