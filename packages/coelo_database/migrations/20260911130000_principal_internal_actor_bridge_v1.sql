-- Rodada 5 (E2-R05-20260911), principal-chat-sistema. P35 (Owner, 11/09): "o
-- superadmin entra no app vendo tudo" (regra de produto); a pessoa de servico
-- de qa-r03 ja tem membership owner nas instituicoes sinteticas (lote 27).
--
-- Problema medido em producao (11/09 12:10): list_my_principal_contexts devolve
-- [] para qa-r03 porque ela, happens_actor, now_actor,
-- moments_actor_for_auth_user e os dois resgates de ticket de midia resolvem a
-- pessoa por public.person_auth_links, que a identidade interna nao tem (guard
-- do realm, ADR 0019). A ponte de ator (220400) so cobre
-- app_private.current_person_id(). Alem disso a membership do lote 27 nao tem
-- institution_role_assignments, e has_context_permission exige um papel: sem
-- ele o resultado e happens_permission_denied.
--
-- O que este pacote faz, forward-only e idempotente:
--   1. app_private.person_id_for_auth_user(uuid): a mesma resolucao de
--      current_person_id() (people-based com precedencia, depois o espelho
--      interno), parametrizada pelo auth user, para funcoes que recebem o
--      viewer por argumento (resgate de ticket pelas Edge Functions).
--   2. Reescreve as seis funcoes acima para usar esse helper. Nada muda para
--      quem tem person_auth_link.
--   3. app_private.superadmin_internal_actor_institution_access_sync(): para
--      cada espelho interno ativo (com platform_membership ativa) e cada
--      instituicao ativa garante membership owner/institution ativa e
--      institution_role_assignment ao papel de sistema institution_admin
--      (P31), que concede happens/now/moments/profiles. Executada agora
--      (backfill) e por gatilho quando nasce uma instituicao ou um espelho
--      interno. E a forma de "Superadmin ve tudo" que nao exige reescrever as
--      RPCs por familia.
-- Nao cria person_auth_link, nao afrouxa RLS nem o guard do realm, nao
-- concede nada a anon. Pendencia registrada: refinar por papel interno
-- (operations) se o Owner quiser distinguir.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $$
begin
  if to_regprocedure('app_private.current_person_id()') is null
     or to_regclass('app_private.superadmin_internal_actor_people') is null
     or to_regprocedure('public.list_my_principal_contexts()') is null
     or to_regprocedure('app_private.happens_actor(uuid,text,uuid,uuid)') is null
     or to_regprocedure('app_private.now_actor(uuid,text,uuid,uuid)') is null
     or to_regprocedure('app_private.moments_actor_for_auth_user(uuid,uuid,text,uuid,uuid)') is null
     or to_regprocedure('public.redeem_now_media_read_ticket(uuid,uuid)') is null
     or to_regprocedure('public.redeem_happens_media_read_ticket(uuid,uuid)') is null
     or to_regprocedure('app_private.now_viewer_role_class(uuid,uuid,uuid,uuid,uuid)') is null
     or not exists (
       select 1 from public.institution_roles
       where code = 'institution_admin' and is_system and institution_id is null
     ) then
    raise exception 'principal_internal_actor_bridge_v1: cadeia exigida ausente (220400, 191000, 190300..190700, 230017, 171600)';
  end if;
end $$;

-- 1. helper parametrizado -----------------------------------------------------
create or replace function app_private.person_id_for_auth_user(p_auth_user_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select auth_link.person_id
      from public.person_auth_links auth_link
      where auth_link.auth_user_id = p_auth_user_id
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
      where internal_link.auth_user_id = p_auth_user_id
        and internal_link.status = 'active'
      order by internal_link.created_at desc
      limit 1
    )
  )
$$;
revoke all on function app_private.person_id_for_auth_user(uuid) from public, anon, authenticated;

-- 2. contextos do Principal -----------------------------------------------------
create or replace function public.list_my_principal_contexts()
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
  group_name text
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
    scoped_group.name
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

-- 2b. atores de Acontece, Agora e Momentos -------------------------------------
create or replace function app_private.happens_actor(p_institution_id uuid,p_permission text,p_unit_id uuid,p_group_id uuid)
returns table(person_id uuid,membership_id uuid) language plpgsql stable security definer set search_path='' as $$
begin
  if (select auth.uid()) is null then raise insufficient_privilege using message='authentication_required'; end if;
  if not app_private.has_institution_permission(p_institution_id,p_permission,p_unit_id,p_group_id,false)
  then raise insufficient_privilege using message='happens_permission_denied'; end if;
  return query select membership.person_id,membership.id
  from public.institution_memberships membership
  where membership.person_id=app_private.person_id_for_auth_user((select auth.uid()))
    and membership.institution_id=p_institution_id
    and membership.status='active' and membership.revoked_at is null order by membership.created_at limit 1;
  if not found then raise insufficient_privilege using message='active_membership_required'; end if;
end $$;
revoke all on function app_private.happens_actor(uuid,text,uuid,uuid) from public,anon,authenticated;

create or replace function app_private.now_actor(p_institution_id uuid,p_permission text,p_unit_id uuid,p_group_id uuid)
returns table(person_id uuid,membership_id uuid) language plpgsql stable security definer set search_path='' as $$
begin
  if (select auth.uid()) is null then raise insufficient_privilege using message='authentication_required'; end if;
  if p_unit_id is not null and not exists(
    select 1 from public.units where id=p_unit_id and institution_id=p_institution_id
  ) then raise insufficient_privilege using message='context_not_authorized'; end if;
  if p_group_id is not null and (
    p_unit_id is null or not exists(
      select 1 from public.groups
      where id=p_group_id and institution_id=p_institution_id and unit_id=p_unit_id
    )
  ) then raise insufficient_privilege using message='context_not_authorized'; end if;
  if not app_private.has_institution_permission(p_institution_id,p_permission,p_unit_id,p_group_id,false)
  then raise insufficient_privilege using message='now_permission_denied'; end if;
  return query select membership.person_id,membership.id
  from public.institution_memberships membership
  where membership.person_id=app_private.person_id_for_auth_user((select auth.uid()))
    and membership.institution_id=p_institution_id
    and membership.status='active' and membership.revoked_at is null order by membership.created_at limit 1;
  if not found then raise insufficient_privilege using message='active_membership_required'; end if;
end $$;
revoke all on function app_private.now_actor(uuid,text,uuid,uuid) from public,anon,authenticated;

create or replace function app_private.moments_actor_for_auth_user(
  p_auth_user_id uuid,
  p_institution_id uuid,
  p_permission text,
  p_unit_id uuid,
  p_group_id uuid
)
returns table (person_id uuid, membership_id uuid)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_auth_user_id is null then
    raise insufficient_privilege using message = 'authentication_required';
  end if;
  if not app_private.has_institution_permission(
    p_institution_id, p_permission, p_unit_id, p_group_id, false
  ) then
    raise insufficient_privilege using message = 'moments_permission_denied';
  end if;
  return query
  select membership.person_id, membership.id
  from public.institution_memberships membership
  where membership.person_id = app_private.person_id_for_auth_user(p_auth_user_id)
    and membership.institution_id = p_institution_id
    and membership.status = 'active'
    and membership.revoked_at is null
  order by membership.created_at
  limit 1;
  if not found then
    raise insufficient_privilege using message = 'active_membership_required';
  end if;
end
$$;
revoke all on function app_private.moments_actor_for_auth_user(uuid,uuid,text,uuid,uuid) from public,anon,authenticated;

-- 2c. resgate de ticket de midia (chamado pelas Edge Functions com service_role)
create or replace function public.redeem_now_media_read_ticket(
  p_ticket uuid,
  p_viewer_auth_user_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  redeemed record;
begin
  delete from app_private.now_media_read_tickets ticket
  using public.institution_memberships membership,
        public.now_media_assets asset,
        public.now_publications publication
  where ticket.token=p_ticket
    and ticket.expires_at>now()
    and ticket.viewer_person_id=app_private.person_id_for_auth_user(p_viewer_auth_user_id)
    and membership.person_id=ticket.viewer_person_id
    and membership.institution_id=asset.institution_id
    and membership.status='active'
    and membership.revoked_at is null
    and asset.id=ticket.media_asset_id
    and asset.status='ready'
    and publication.id=asset.publication_id
    and publication.institution_id=asset.institution_id
    and publication.status in('scheduled','published')
    and publication.publish_at<=now()
    and publication.expires_at>now()
    and publication.status<>'expired'
    and app_private.now_viewer_role_class(
      ticket.viewer_person_id,
      membership.id,
      publication.institution_id,
      publication.unit_id,
      publication.group_id
    ) is not null
    and exists(
      select 1
      from public.now_publication_audiences audience
      where audience.publication_id=publication.id
        and audience.institution_id=publication.institution_id
        and audience.unit_id is not distinct from publication.unit_id
        and audience.group_id is not distinct from publication.group_id
        and app_private.now_audience_matches_role(
          app_private.now_viewer_role_class(
            ticket.viewer_person_id,
            membership.id,
            publication.institution_id,
            publication.unit_id,
            publication.group_id
          ),
          audience.audience_kind
        )
    )
  returning asset.storage_provider,asset.bucket_id,asset.object_key,asset.mime_type into redeemed;
  if redeemed.object_key is null then
    raise insufficient_privilege using message='media_read_ticket_invalid';
  end if;
  return jsonb_build_object(
    'storage_provider',redeemed.storage_provider,
    'bucket_id',redeemed.bucket_id,
    'object_key',redeemed.object_key,
    'mime_type',redeemed.mime_type
  );
end $$;

revoke all on function public.redeem_now_media_read_ticket(uuid,uuid) from public, anon, authenticated;

create or replace function public.redeem_happens_media_read_ticket(p_ticket uuid,p_viewer_auth_user_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  redeemed record;
begin
  delete from app_private.happens_media_read_tickets ticket
  using public.media_assets asset
  where ticket.token=p_ticket
    and ticket.expires_at>now()
    and ticket.viewer_person_id=app_private.person_id_for_auth_user(p_viewer_auth_user_id)
    and asset.id=ticket.media_asset_id
    and asset.status='ready'
  returning asset.storage_provider,asset.bucket_id,asset.object_key,asset.mime_type into redeemed;
  if redeemed.object_key is null then
    raise insufficient_privilege using message='media_read_ticket_invalid';
  end if;
  return jsonb_build_object(
    'storage_provider',redeemed.storage_provider,
    'bucket_id',redeemed.bucket_id,
    'object_key',redeemed.object_key,
    'mime_type',redeemed.mime_type
  );
end $$;

revoke all on function public.redeem_happens_media_read_ticket(uuid,uuid) from public, anon, authenticated;

-- 3. Superadmin ve tudo: membership + papel institution_admin por gatilho ------
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

  insert into public.institution_memberships (person_id, institution_id, role_code, status, scope_kind)
  select actor.person_id, inst.id, 'owner', 'active', 'institution'
  from app_private.superadmin_internal_actor_people actor
  join public.platform_memberships pm on pm.id = actor.platform_membership_id
    and pm.status = 'active' and pm.revoked_at is null
  cross join public.institutions inst
  where inst.status = 'active' and inst.deleted_at is null
    and not exists (
      select 1 from public.institution_memberships m
      where m.person_id = actor.person_id and m.institution_id = inst.id
        and m.status = 'active' and m.revoked_at is null
    );
  get diagnostics n = row_count; touched := touched + n;

  insert into public.institution_role_assignments (membership_id, role_id, scope_kind, status)
  select m.id, admin_role_id, 'institution', 'active'
  from public.institution_memberships m
  join app_private.superadmin_internal_actor_people actor on actor.person_id = m.person_id
  join public.platform_memberships pm on pm.id = actor.platform_membership_id
    and pm.status = 'active' and pm.revoked_at is null
  join public.institutions inst on inst.id = m.institution_id
    and inst.status = 'active' and inst.deleted_at is null
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
revoke all on function app_private.superadmin_internal_actor_institution_access_sync() from public, anon, authenticated;

create or replace function app_private.superadmin_internal_actor_institution_access_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app_private.superadmin_internal_actor_institution_access_sync();
  return null;
end
$$;
revoke all on function app_private.superadmin_internal_actor_institution_access_trigger() from public, anon, authenticated;

drop trigger if exists institutions_superadmin_internal_access on public.institutions;
create trigger institutions_superadmin_internal_access
  after insert or update of status on public.institutions
  for each row when (new.status = 'active')
  execute function app_private.superadmin_internal_actor_institution_access_trigger();

drop trigger if exists superadmin_internal_actor_people_institution_access on app_private.superadmin_internal_actor_people;
create trigger superadmin_internal_actor_people_institution_access
  after insert or update of platform_membership_id on app_private.superadmin_internal_actor_people
  for each row
  execute function app_private.superadmin_internal_actor_institution_access_trigger();

select app_private.superadmin_internal_actor_institution_access_sync();

commit;
