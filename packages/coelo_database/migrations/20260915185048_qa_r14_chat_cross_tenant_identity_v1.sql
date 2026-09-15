-- R14 Bloco E: fixture produtiva descartável para provar leitura de anexo
-- entre tenants sem conceder escopo de plataforma ao ator sintético.
-- A função é mantida versionada para que a preparação da fixture seja
-- reproduzível e auditável; não contém credencial nem dado pessoal real.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

create or replace function app_private.seed_qa_r14_chat_cross_tenant_user(
  p_email text,
  p_institution_id uuid,
  p_cpf text default '00000000099'
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_auth_user_id uuid;
  v_identity_id uuid;
  v_role_id uuid;
  v_person_id uuid;
  v_membership_id uuid;
begin
  if p_email is null or btrim(p_email) = '' or p_institution_id is null
     or p_cpf is null or p_cpf !~ '^[0-9]{11}$' then
    raise invalid_parameter_value using message = 'invalid_qa_fixture_input';
  end if;

  select id into v_auth_user_id
  from auth.users
  where lower(email) = lower(btrim(p_email));
  if v_auth_user_id is null then
    raise no_data_found using message = 'qa_auth_user_missing';
  end if;

  if not exists (
    select 1 from public.institutions
    where id = p_institution_id and deleted_at is null
  ) then
    raise no_data_found using message = 'qa_institution_missing';
  end if;

  select role_record.id into v_role_id
  from public.platform_roles role_record
  where role_record.code = 'owner' and role_record.status = 'active'
  order by role_record.is_system desc, role_record.created_at
  limit 1;
  if v_role_id is null then
    raise no_data_found using message = 'qa_owner_role_missing';
  end if;

  select auth_link.internal_identity_id into v_identity_id
  from app_private.superadmin_internal_auth_links auth_link
  where auth_link.auth_user_id = v_auth_user_id
  order by (auth_link.status = 'active') desc, auth_link.created_at desc
  limit 1;

  if v_identity_id is null then
    insert into app_private.superadmin_internal_identities default values
      returning id into v_identity_id;
    insert into app_private.superadmin_internal_auth_links(
      internal_identity_id, auth_user_id, status
    ) values (v_identity_id, v_auth_user_id, 'active');
  else
    update app_private.superadmin_internal_auth_links
    set status = 'active', suspended_at = null, revoked_at = null,
        version = version + 1
    where internal_identity_id = v_identity_id and auth_user_id = v_auth_user_id
      and status <> 'active';
  end if;

  select membership.id into v_membership_id
  from app_private.superadmin_internal_memberships membership
  where membership.internal_identity_id = v_identity_id
    and membership.status = 'active';

  if v_membership_id is null then
    insert into app_private.superadmin_internal_memberships(
      internal_identity_id, platform_role_id, scope_kind,
      scope_institution_id, status
    ) values (
      v_identity_id, v_role_id, 'institution', p_institution_id, 'active'
    ) returning id into v_membership_id;
  elsif exists (
    select 1 from app_private.superadmin_internal_memberships membership
    where membership.id = v_membership_id
      and (membership.scope_kind <> 'institution'
        or membership.scope_institution_id <> p_institution_id)
  ) then
    raise unique_violation using message = 'qa_identity_has_existing_scope';
  end if;

  insert into app_private.superadmin_internal_profiles(
    internal_identity_id, first_name, last_name, display_name, cpf,
    professional_email, job_title, department, internal_function
  ) values (
    v_identity_id, 'QA', 'R14 Chat Cross Tenant', 'QA R14 Chat Cross Tenant',
    p_cpf, lower(btrim(p_email)), 'Usuario sintetico de teste', 'QA',
    'R14 - negativa cross-tenant Chat'
  )
  on conflict (internal_identity_id) do update set
    professional_email = excluded.professional_email,
    updated_at = now();

  v_person_id := app_private.superadmin_internal_actor_sync(v_identity_id);

  return jsonb_build_object(
    'created', true,
    'scope_kind', 'institution',
    'membership_present', v_membership_id is not null,
    'actor_present', v_person_id is not null
  );
end
$$;

revoke all on function app_private.seed_qa_r14_chat_cross_tenant_user(text, uuid, text)
  from public, anon, authenticated, service_role;

commit;
