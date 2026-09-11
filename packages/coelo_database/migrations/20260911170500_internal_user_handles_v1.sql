-- 20260911170500_internal_user_handles_v1
-- P46 = A (Owner, 11/09 16:45): usuarios internos tambem tem @, pela pessoa
-- de servico que a ponte de ator (20260910220400) espelha para cada
-- identidade interna (people.person_type = 'service').
--
-- O que este pacote faz, reutilizando o 20260911170100 sem trocar contrato:
--   1. enforce_person_handle_rules e ensure_person_handle aceitam 'service'
--      (visibilidade sempre privada, como a de crianca);
--   2. o @ padrao da pessoa de servico nasce do nome do perfil interno
--      (superadmin_internal_profiles), nao de "Operador interno <id>";
--   3. person_handle_actor_can: para pessoa de servico, quem tem
--      platform.member.read/platform.member.update (Usuarios internos) ve/edita,
--      alem da propria identidade (current_person_id ja cai no espelho);
--   4. RPC superadmin_internal_user_service_person_v1(p_internal_identity_id)
--      devolve o person_id da pessoa de servico (mesma autorizacao do detalhe
--      de Usuarios internos) para o cliente reutilizar
--      superadmin_person_handle_get/availability/set;
--   5. a ponte de ator (superadmin_internal_actor_sync, 220400) da o @ a
--      pessoa de servico DEPOIS de registrar o espelho, porque o gatilho de
--      people dispara antes de o mapeamento existir; o gatilho de people
--      pula 'service' (pessoa de servico so nasce pela ponte);
--   6. backfill idempotente das pessoas de servico existentes.
-- Trava de 30 dias, reservados, formato e ledger continuam os do 170100.

-- 1. trava/regra: aceitar service -----------------------------------------------
create or replace function app_private.enforce_person_handle_rules() returns trigger
language plpgsql security definer set search_path=''
as $$
declare
  person_kind public.person_type;
begin
  new.normalized_handle := app_private.normalize_person_handle(new.normalized_handle);

  select person.person_type into person_kind
  from public.people person
  where person.id = new.person_id and person.deleted_at is null;

  if person_kind is null then
    raise foreign_key_violation using message = 'active person required';
  end if;
  if person_kind not in ('adult', 'child', 'service') then
    raise check_violation using message = 'handles belong only to adults, children or service people';
  end if;
  if person_kind in ('child', 'service') and new.visibility <> 'private' then
    raise check_violation using message = 'child and service handles must remain private';
  end if;
  if tg_op = 'UPDATE' and old.revoked_at is not null then
    raise check_violation using message = 'revoked handles are immutable';
  end if;

  if tg_op = 'INSERT' or new.normalized_handle is distinct from old.normalized_handle then
    if tg_op = 'UPDATE' and exists (
         select 1 from app_private.person_identity_correction_ledger ledger
         where ledger.person_id = new.person_id and ledger.correction_kind = 'handle'
           and ledger.old_value is not null
           and ledger.changed_at > clock_timestamp() - interval '30 days'
       ) then
      raise check_violation using
        message = 'person handle can be changed only once every 30 days';
    end if;
    new.last_changed_at := clock_timestamp();
  else
    new.last_changed_at := old.last_changed_at;
  end if;

  new.updated_at := clock_timestamp();
  return new;
end
$$;

-- 2. geracao: pessoa de servico usa o nome do perfil interno --------------------
create or replace function app_private.ensure_person_handle(p_person_id uuid) returns text
language plpgsql volatile security definer set search_path=''
as $$
declare
  person_record public.people%rowtype;
  existing text;
  generated text;
  profile_first text;
  profile_last text;
begin
  select * into person_record from public.people where id = p_person_id and deleted_at is null;
  if not found or person_record.person_type not in ('adult','child','service') then
    return null;
  end if;
  select h.normalized_handle into existing from public.person_handles h
  where h.person_id = p_person_id and h.status = 'active' and h.revoked_at is null;
  if existing is not null then
    return existing;
  end if;
  if person_record.person_type = 'service' then
    select profile.first_name, profile.last_name into profile_first, profile_last
    from app_private.superadmin_internal_actor_people actor
    join app_private.superadmin_internal_profiles profile
      on profile.internal_identity_id = actor.internal_identity_id
    where actor.person_id = p_person_id;
  end if;
  generated := app_private.generate_person_handle(
    coalesce(profile_first, person_record.first_name),
    coalesce(profile_last, person_record.last_name),
    person_record.display_name);
  insert into public.person_handles(person_id, normalized_handle, visibility, status)
  values (p_person_id, generated, 'private', 'active');
  return generated;
end
$$;

-- 2b. gatilho de people: pessoa de servico recebe o @ pela ponte, nao aqui ------
create or replace function app_private.people_assign_initial_handle() returns trigger
language plpgsql security definer set search_path=''
as $$
begin
  if new.person_type = 'service' then
    return new;
  end if;
  begin
    perform app_private.ensure_person_handle(new.id);
  exception when others then
    -- O @ nunca impede o cadastro da pessoa; fica para o backfill/set.
    raise warning 'person handle not assigned for %: %', new.id, sqlerrm;
  end;
  return new;
end
$$;

-- 2c. ponte de ator: @ da pessoa de servico depois do espelho (corpo do 220400 + 1 bloco)
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
    insert into public.people(person_type, first_name, last_name, display_name, status)
    values ('service', 'Operador interno', short_id, 'Operador interno ' || short_id, 'active')
    returning id into actor_person_id;
    insert into app_private.superadmin_internal_actor_people(internal_identity_id, person_id)
    values (p_internal_identity_id, actor_person_id);
  else
    actor_person_id := mapping.person_id;
  end if;

  -- P46: o @ da pessoa de servico nasce do nome do perfil interno (170500).
  begin
    perform app_private.ensure_person_handle(actor_person_id);
  exception when others then
    raise warning 'service person handle not assigned for %: %', actor_person_id, sqlerrm;
  end;

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
    update public.platform_memberships set
      status = (case when membership.status = 'suspended' then 'suspended' else 'revoked' end)
        ::public.platform_membership_status,
      revoked_at = case when membership.status = 'suspended' then null else now() end
    where id = mapping.platform_membership_id;
  end if;

  return actor_person_id;
end
$$;

-- 3. autorizacao: Usuarios internos ve/edita o @ da pessoa de servico ----------
create or replace function app_private.person_handle_actor_can(p_person_id uuid, p_write boolean) returns boolean
language sql stable security definer set search_path=''
as $$
  select (select auth.uid()) is not null and (
    app_private.has_platform_permission(case when p_write then 'people.update' else 'people.read' end)
    or app_private.current_person_id() = p_person_id
    or exists (
      select 1 from public.guardian_links gl
      where gl.child_person_id = p_person_id
        and gl.guardian_person_id = app_private.current_person_id()
        and gl.status = 'active' and gl.revoked_at is null)
    or (
      exists (select 1 from public.people p
              where p.id = p_person_id and p.person_type = 'service' and p.deleted_at is null)
      and app_private.has_platform_permission(
            case when p_write then 'platform.member.update' else 'platform.member.read' end))
  );
$$;

-- 4. RPC: pessoa de servico de um usuario interno --------------------------------
create or replace function public.superadmin_internal_user_service_person_v1(p_internal_identity_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=''
as $$
declare
  ctx app_private.superadmin_internal_context;
  service_person uuid;
begin
  select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.member.read');
  if not app_private.superadmin_internal_user_target_allowed(ctx, p_internal_identity_id) then
    raise insufficient_privilege using message = 'internal user unavailable', detail = 'SAI_PERMISSION_DENIED';
  end if;
  select actor.person_id into service_person
  from app_private.superadmin_internal_actor_people actor
  where actor.internal_identity_id = p_internal_identity_id;
  return jsonb_build_object('ok', true, 'data',
    case when service_person is null then null
         else jsonb_build_object('person_id', service_person) end, 'error', null);
end
$$;
revoke all on function public.superadmin_internal_user_service_person_v1(uuid) from public, anon;
grant execute on function public.superadmin_internal_user_service_person_v1(uuid) to authenticated, service_role;

-- 6. backfill idempotente das pessoas de servico ---------------------------------
select app_private.ensure_person_handle(actor.person_id)
from app_private.superadmin_internal_actor_people actor
join public.people person on person.id = actor.person_id and person.deleted_at is null
where not exists (select 1 from public.person_handles h
                  where h.person_id = actor.person_id and h.status = 'active' and h.revoked_at is null);
