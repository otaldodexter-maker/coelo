-- Secure Superadmin institution management commands.
-- Public RPCs are hardened SECURITY DEFINER gateways. Privileged writes are isolated in
-- app_private and authorize the authenticated person before any data lookup.

begin;

insert into public.platform_permissions(
  code, module_code, screen_code, action_code, description,
  risk_level, requires_mfa, status, updated_at
)
values (
  'institution.update', 'institutions', 'management', 'update',
  'Editar o cadastro geral de instituicoes.', 'high', true, 'active', now()
)
on conflict (code) do update set
  module_code = excluded.module_code,
  screen_code = excluded.screen_code,
  action_code = excluded.action_code,
  description = excluded.description,
  risk_level = excluded.risk_level,
  requires_mfa = excluded.requires_mfa,
  status = excluded.status,
  updated_at = excluded.updated_at;

delete from public.platform_role_permissions role_permission
using public.platform_roles role_record,
      public.platform_permissions permission_record
where role_permission.role_id = role_record.id
  and role_permission.permission_id = permission_record.id
  and permission_record.code = 'institution.update'
  and role_record.code not in ('owner', 'operations');

insert into public.platform_role_permissions(
  role_id, permission_id, effect, status, revoked_at
)
select role_record.id, permission_record.id, 'allow', 'active', null
from public.platform_roles role_record
cross join public.platform_permissions permission_record
where role_record.code in ('owner', 'operations')
  and permission_record.code = 'institution.update'
on conflict (role_id, permission_id) do update set
  effect = 'allow', status = 'active', revoked_at = null;

alter table public.institutions
  add column management_version bigint not null default 1;

alter table public.institutions
  add constraint institutions_management_version_positive
  check (management_version > 0);

create table app_private.institution_management_command_receipts (
  request_id uuid primary key,
  actor_person_id uuid not null references public.people(id),
  command_kind text not null check (command_kind in ('create', 'update')),
  institution_id uuid not null references public.institutions(id),
  request_hash bytea not null check (octet_length(request_hash) = 32),
  result_management_version bigint not null
    check (result_management_version > 0),
  created_at timestamptz not null default now()
);

revoke all on table app_private.institution_management_command_receipts
  from public, anon, authenticated, service_role;

create index institution_subscriptions_latest_idx
  on public.institution_subscriptions(
    institution_id,
    created_at desc,
    id desc
  );

create or replace function app_private.has_scoped_platform_permission(
  p_permission_code text,
  p_institution_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with active_memberships as (
    select
      membership.id as membership_id,
      membership.role_id,
      role_record.code as role_code
    from public.platform_memberships membership
    join public.platform_roles role_record
      on role_record.id = membership.role_id
     and role_record.status = 'active'
    where membership.person_id = app_private.current_person_id()
      and membership.status = 'active'
      and membership.revoked_at is null
      and (
        not membership.mfa_required
        or app_private.has_mfa_aal2()
      )
      and (
        (
          p_institution_id is null
          and membership.scope_kind = 'platform'
          and membership.scope_institution_id is null
        )
        or (
          p_institution_id is not null
          and (
            (
              membership.scope_kind = 'platform'
              and membership.scope_institution_id is null
            )
            or (
              membership.scope_kind = 'institution'
              and membership.scope_institution_id = p_institution_id
            )
          )
        )
      )
  ),
  target_permission as (
    select permission_record.id
    from public.platform_permissions permission_record
    where permission_record.code = p_permission_code
      and permission_record.status = 'active'
  )
  select coalesce(exists (
    select 1
    from active_memberships membership
    cross join target_permission permission_record
    where not exists (
      select 1
      from public.platform_member_permission_overrides permission_override
      where permission_override.membership_id = membership.membership_id
        and permission_override.permission_id = permission_record.id
        and permission_override.status = 'active'
        and permission_override.effect = 'deny'
        and (
          permission_override.starts_at is null
          or permission_override.starts_at <= pg_catalog.now()
        )
        and (
          permission_override.expires_at is null
          or permission_override.expires_at > pg_catalog.now()
        )
    )
      and (
        membership.role_code = 'owner'
        or exists (
         select 1
         from public.platform_member_permission_overrides permission_override
         where permission_override.membership_id = membership.membership_id
           and permission_override.permission_id = permission_record.id
           and permission_override.status = 'active'
           and permission_override.effect = 'allow'
           and (
             permission_override.starts_at is null
             or permission_override.starts_at <= pg_catalog.now()
           )
           and (
             permission_override.expires_at is null
             or permission_override.expires_at > pg_catalog.now()
           )
       )
        or exists (
          select 1
          from public.platform_role_permissions role_permission
          where role_permission.role_id = membership.role_id
            and role_permission.permission_id = permission_record.id
            and role_permission.status = 'active'
            and role_permission.revoked_at is null
            and role_permission.effect = 'allow'
        )
      )
  ), false)
$$;

drop policy if exists institutions_platform_read on public.institutions;
drop policy if exists institution_addresses_platform_read
  on public.institution_addresses;
drop policy if exists institution_contacts_platform_read
  on public.institution_contacts;
drop policy if exists institution_branding_platform_read
  on public.institution_branding;
drop policy if exists institution_subscriptions_platform_read
  on public.institution_subscriptions;
drop policy if exists units_platform_read on public.units;
drop policy if exists groups_platform_read on public.groups;

create policy institutions_scoped_platform_read on public.institutions
  for select to authenticated
  using (
    (select app_private.has_scoped_platform_permission('platform.read', id))
  );
create policy institution_addresses_scoped_platform_read
  on public.institution_addresses
  for select to authenticated
  using (
    (select app_private.has_scoped_platform_permission(
      'platform.read', institution_id
    ))
  );
create policy institution_contacts_scoped_platform_read
  on public.institution_contacts
  for select to authenticated
  using (
    (select app_private.has_scoped_platform_permission(
      'platform.read', institution_id
    ))
  );
create policy institution_branding_scoped_platform_read
  on public.institution_branding
  for select to authenticated
  using (
    (select app_private.has_scoped_platform_permission(
      'platform.read', institution_id
    ))
  );
create policy institution_subscriptions_scoped_platform_read
  on public.institution_subscriptions
  for select to authenticated
  using (
    (select app_private.has_scoped_platform_permission(
      'platform.read', institution_id
    ))
  );
create policy units_scoped_platform_read on public.units
  for select to authenticated
  using (
    (select app_private.has_scoped_platform_permission(
      'platform.read', institution_id
    ))
  );
create policy groups_scoped_platform_read on public.groups
  for select to authenticated
  using (
    (select app_private.has_scoped_platform_permission(
      'platform.read', institution_id
    ))
  );

create or replace function app_private.institution_management_request_hash(
  p_request jsonb
)
returns bytea
language sql
immutable
security invoker
set search_path = ''
as $$
  select extensions.digest(
    pg_catalog.convert_to(p_request::text, 'UTF8'),
    'sha256'
  )
$$;

-- Accepted top-level payload keys are deliberately closed. Nested objects use
-- the same rule so new remote behavior cannot be enabled accidentally.
create or replace function app_private.assert_institution_management_payload(
  p_payload jsonb,
  p_is_create boolean
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  unknown_key text;
  profile_link jsonb;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise invalid_parameter_value using message = 'payload must be an object';
  end if;
  if pg_catalog.octet_length(p_payload::text) > 65536 then
    raise invalid_parameter_value using message = 'payload is too large';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise invalid_parameter_value using
      message = 'institution payload must be a JSON object';
  end if;

  select key_name into unknown_key
  from jsonb_object_keys(p_payload) key_name
  where not (key_name = any(array[
    'public_name', 'trade_name', 'legal_name', 'slug', 'primary_domain',
    'document_ref', 'document_type', 'status', 'timezone', 'locale',
    'institution_type_name', 'address', 'contact', 'branding', 'subscription'
  ]::text[]))
  limit 1;
  if unknown_key is not null then
    raise invalid_parameter_value using message = 'unknown institution payload key';
  end if;

  if p_is_create and (
    btrim(coalesce(p_payload ->> 'public_name', '')) = ''
    or btrim(coalesce(p_payload ->> 'slug', '')) = ''
    or btrim(coalesce(p_payload ->> 'institution_type_name', '')) = ''
  ) then
    raise invalid_parameter_value using
      message = 'public_name, slug and institution_type_name are required';
  end if;
  if not p_is_create and p_payload = '{}'::jsonb then
    raise invalid_parameter_value using message = 'update payload cannot be empty';
  end if;

  if p_payload ? 'public_name'
     and btrim(coalesce(p_payload ->> 'public_name', '')) = '' then
    raise invalid_parameter_value using message = 'public_name cannot be blank';
  end if;
  if p_payload ? 'slug' and btrim(coalesce(p_payload ->> 'slug', '')) = '' then
    raise invalid_parameter_value using message = 'slug cannot be blank';
  end if;
  if p_payload ? 'document_type'
     and btrim(coalesce(p_payload ->> 'document_type', '')) = '' then
    raise invalid_parameter_value using message = 'document_type cannot be blank';
  end if;
  if p_payload ? 'timezone'
     and btrim(coalesce(p_payload ->> 'timezone', '')) = '' then
    raise invalid_parameter_value using message = 'timezone cannot be blank';
  end if;
  if p_payload ? 'locale'
     and btrim(coalesce(p_payload ->> 'locale', '')) = '' then
    raise invalid_parameter_value using message = 'locale cannot be blank';
  end if;
  if p_payload ? 'institution_type_name'
     and btrim(coalesce(p_payload ->> 'institution_type_name', '')) = '' then
    raise invalid_parameter_value using
      message = 'institution_type_name cannot be blank';
  end if;

  if p_payload ? 'address' then
    if jsonb_typeof(p_payload -> 'address') <> 'object' then
      raise invalid_parameter_value using message = 'address must be an object';
    end if;
    select key_name into unknown_key
    from jsonb_object_keys(p_payload -> 'address') key_name
    where not (key_name = any(array[
      'country', 'state', 'city', 'district', 'street', 'number',
      'complement', 'postal_code'
    ]::text[])) limit 1;
    if unknown_key is not null then
      raise invalid_parameter_value using message = 'unknown address payload key';
    end if;
    if (p_payload -> 'address') ? 'country'
       and btrim(coalesce(p_payload -> 'address' ->> 'country', '')) = '' then
      raise invalid_parameter_value using message = 'address country cannot be blank';
    end if;
  end if;

  unknown_key := null;
  if p_payload ? 'contact' then
    if jsonb_typeof(p_payload -> 'contact') <> 'object' then
      raise invalid_parameter_value using message = 'contact must be an object';
    end if;
    select key_name into unknown_key
    from jsonb_object_keys(p_payload -> 'contact') key_name
    where not (key_name = any(array[
      'email', 'phone', 'mobile_phone', 'website_url', 'whatsapp_number'
    ]::text[])) limit 1;
    if unknown_key is not null then
      raise invalid_parameter_value using message = 'unknown contact payload key';
    end if;
  end if;

  unknown_key := null;
  if p_payload ? 'branding' then
    if jsonb_typeof(p_payload -> 'branding') <> 'object' then
      raise invalid_parameter_value using message = 'branding must be an object';
    end if;
    select key_name into unknown_key
    from jsonb_object_keys(p_payload -> 'branding') key_name
    where not (key_name = any(array[
      'display_name', 'logo_media_asset_id', 'cover_media_asset_id',
      'accent_color', 'secondary_color', 'tertiary_color', 'text_color',
      'secondary_text_color', 'tertiary_text_color', 'surface_color',
      'approval_status', 'profile_bio', 'profile_links'
    ]::text[])) limit 1;
    if unknown_key is not null then
      raise invalid_parameter_value using message = 'unknown branding payload key';
    end if;
    if (p_payload -> 'branding') ? 'profile_bio'
       and char_length(coalesce(p_payload -> 'branding' ->> 'profile_bio', '')) > 220 then
      raise invalid_parameter_value using message = 'profile_bio is too long';
    end if;
    if (p_payload -> 'branding') ? 'profile_links' then
      if jsonb_typeof(p_payload -> 'branding' -> 'profile_links') <> 'array' then
        raise invalid_parameter_value using message = 'profile_links must be an array';
      end if;
      if jsonb_array_length(p_payload -> 'branding' -> 'profile_links') > 12 then
        raise invalid_parameter_value using message = 'profile_links exceeds the limit';
      end if;
      for profile_link in
        select value
        from jsonb_array_elements(p_payload -> 'branding' -> 'profile_links')
      loop
        if jsonb_typeof(profile_link) <> 'object' then
          raise invalid_parameter_value using message = 'invalid profile_link';
        end if;
        if not (profile_link ? 'label')
           or not (profile_link ? 'url')
           or exists (
             select 1
             from jsonb_object_keys(profile_link) key_name
             where key_name not in ('label', 'url')
           )
           or jsonb_typeof(profile_link -> 'label') is distinct from 'string'
           or jsonb_typeof(profile_link -> 'url') is distinct from 'string'
           or btrim(profile_link ->> 'label') = ''
           or char_length(profile_link ->> 'label') > 80
           or char_length(profile_link ->> 'url') > 2048
           or (profile_link ->> 'url') !~* '^https?://[^[:space:][:cntrl:]]+$' then
          raise invalid_parameter_value using message = 'invalid profile_link';
        end if;
      end loop;
    end if;
  end if;

  unknown_key := null;
  if p_payload ? 'subscription' then
    if jsonb_typeof(p_payload -> 'subscription') <> 'object' then
      raise invalid_parameter_value using message = 'subscription must be an object';
    end if;
    select key_name into unknown_key
    from jsonb_object_keys(p_payload -> 'subscription') key_name
    where not (key_name = any(array[
      'plan_code', 'status', 'starts_at', 'trial_ends_at', 'manual_reason',
      'paused_at', 'cancelled_at'
    ]::text[])) limit 1;
    if unknown_key is not null then
      raise invalid_parameter_value using message = 'unknown subscription payload key';
    end if;
    if btrim(coalesce(p_payload -> 'subscription' ->> 'plan_code', '')) = '' then
      raise invalid_parameter_value using message = 'subscription plan_code is required';
    end if;
  end if;
end;
$$;

create or replace function app_private.institution_management_payload(
  p_institution_id uuid
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'id', institution_record.id,
    'public_name', institution_record.public_name,
    'trade_name', institution_record.trade_name,
    'legal_name', institution_record.legal_name,
    'slug', institution_record.slug,
    'primary_domain', institution_record.primary_domain,
    'document_ref', institution_record.document_ref,
    'document_type', institution_record.document_type,
    'status', institution_record.status::text,
    'timezone', institution_record.timezone,
    'locale', institution_record.locale,
    'management_version', institution_record.management_version,
    'created_at', institution_record.created_at,
    'updated_at', institution_record.updated_at,
    'institution_type', case when institution_type.id is null then null else
      jsonb_build_object('id', institution_type.id, 'name', institution_type.name)
    end,
    'address', case when address_record.institution_id is null then null else
      jsonb_build_object(
        'country', address_record.country, 'state', address_record.state,
        'city', address_record.city, 'district', address_record.district,
        'street', address_record.street, 'number', address_record.number,
        'complement', address_record.complement,
        'postal_code', address_record.postal_code
      ) end,
    'contact', case when contact_record.institution_id is null then null else
      jsonb_build_object(
        'email', contact_record.email, 'phone', contact_record.phone,
        'mobile_phone', contact_record.mobile_phone,
        'website_url', contact_record.website_url,
        'whatsapp_number', contact_record.whatsapp_number
      ) end,
    'branding', case when branding_record.institution_id is null then null else
      jsonb_build_object(
        'display_name', branding_record.display_name,
        'logo_media_asset_id', branding_record.logo_media_asset_id,
        'cover_media_asset_id', branding_record.cover_media_asset_id,
        'accent_color', branding_record.accent_color,
        'secondary_color', branding_record.secondary_color,
        'tertiary_color', branding_record.tertiary_color,
        'text_color', branding_record.text_color,
        'secondary_text_color', branding_record.secondary_text_color,
        'tertiary_text_color', branding_record.tertiary_text_color,
        'surface_color', branding_record.surface_color,
        'approval_status', branding_record.approval_status,
        'profile_bio', branding_record.profile_bio,
        'profile_links', branding_record.profile_links
      ) end,
    'subscription', case when latest_subscription.id is null then null else
      jsonb_build_object(
        'id', latest_subscription.id,
        'plan_id', latest_subscription.plan_id,
        'plan_code', latest_subscription.plan_code,
        'plan_name', latest_subscription.plan_name,
        'status', latest_subscription.subscription_status,
        'starts_at', latest_subscription.starts_at,
        'trial_ends_at', latest_subscription.trial_ends_at,
        'paused_at', latest_subscription.paused_at,
        'cancelled_at', latest_subscription.cancelled_at,
        'created_at', latest_subscription.created_at,
        'justification', latest_subscription.manual_reason
      ) end
  )
  from public.institutions institution_record
  left join public.institution_types institution_type
    on institution_type.id = institution_record.institution_type_id
  left join public.institution_addresses address_record
    on address_record.institution_id = institution_record.id
  left join public.institution_contacts contact_record
    on contact_record.institution_id = institution_record.id
  left join public.institution_branding branding_record
    on branding_record.institution_id = institution_record.id
  left join lateral (
    select subscription_record.id, subscription_record.plan_id,
      plan_record.code as plan_code, plan_record.name as plan_name,
      subscription_record.status::text as subscription_status,
      subscription_record.starts_at, subscription_record.trial_ends_at,
      subscription_record.paused_at, subscription_record.cancelled_at,
      subscription_record.created_at, subscription_record.manual_reason
    from public.institution_subscriptions subscription_record
    left join public.plans plan_record on plan_record.id = subscription_record.plan_id
    where subscription_record.institution_id = institution_record.id
    order by subscription_record.created_at desc, subscription_record.id desc
    limit 1
  ) latest_subscription on true
  where institution_record.id = p_institution_id
    and institution_record.deleted_at is null
$$;

-- Applies only the approved child aggregates. Existing values are merged for
-- partial updates; empty nullable strings become NULL.
create or replace function app_private.apply_institution_management_children(
  p_institution_id uuid,
  p_actor_person_id uuid,
  p_payload jsonb,
  p_plan_id uuid
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  merged jsonb;
  email_value text;
  phone_value text;
  mobile_value text;
  website_value text;
  whatsapp_value text;
begin
  if p_payload ? 'address' then
    select coalesce(to_jsonb(address_record), '{}'::jsonb)
      || (p_payload -> 'address') into merged
    from (select 1) seed
    left join public.institution_addresses address_record
      on address_record.institution_id = p_institution_id;
    insert into public.institution_addresses(
      institution_id, country, state, city, district, street, number,
      complement, postal_code, status, updated_at
    ) values (
      p_institution_id, coalesce(nullif(btrim(merged ->> 'country'), ''), 'BR'),
      nullif(btrim(merged ->> 'state'), ''),
      nullif(btrim(merged ->> 'city'), ''),
      nullif(btrim(merged ->> 'district'), ''),
      nullif(btrim(merged ->> 'street'), ''),
      nullif(btrim(merged ->> 'number'), ''),
      nullif(btrim(merged ->> 'complement'), ''),
      nullif(btrim(merged ->> 'postal_code'), ''), 'active', clock_timestamp()
    ) on conflict (institution_id) do update set
      country = excluded.country, state = excluded.state, city = excluded.city,
      district = excluded.district, street = excluded.street,
      number = excluded.number, complement = excluded.complement,
      postal_code = excluded.postal_code, status = 'active',
      updated_at = excluded.updated_at;
  end if;

  if p_payload ? 'contact' then
    select coalesce(to_jsonb(contact_record), '{}'::jsonb)
      || (p_payload -> 'contact') into merged
    from (select 1) seed
    left join public.institution_contacts contact_record
      on contact_record.institution_id = p_institution_id;
    email_value := nullif(btrim(merged ->> 'email'), '');
    phone_value := nullif(btrim(merged ->> 'phone'), '');
    mobile_value := nullif(btrim(merged ->> 'mobile_phone'), '');
    website_value := nullif(btrim(merged ->> 'website_url'), '');
    whatsapp_value := nullif(btrim(merged ->> 'whatsapp_number'), '');
    if num_nonnulls(
      email_value, phone_value, mobile_value, website_value, whatsapp_value
    ) = 0 then
      delete from public.institution_contacts
      where institution_id = p_institution_id;
    else
      insert into public.institution_contacts(
        institution_id, email, phone, mobile_phone, website_url,
        whatsapp_number, status, updated_at
      ) values (
        p_institution_id, email_value, phone_value, mobile_value,
        website_value, whatsapp_value, 'active', clock_timestamp()
      ) on conflict (institution_id) do update set
        email = excluded.email, phone = excluded.phone,
        mobile_phone = excluded.mobile_phone,
        website_url = excluded.website_url,
        whatsapp_number = excluded.whatsapp_number,
        status = 'active', updated_at = excluded.updated_at;
    end if;
  end if;

  if p_payload ? 'branding' then
    select coalesce(to_jsonb(branding_record), '{}'::jsonb)
      || (p_payload -> 'branding') into merged
    from (select 1) seed
    left join public.institution_branding branding_record
      on branding_record.institution_id = p_institution_id;
    insert into public.institution_branding(
      institution_id, display_name, logo_media_asset_id, cover_media_asset_id,
      accent_color, secondary_color, tertiary_color, text_color,
      secondary_text_color, tertiary_text_color, surface_color,
      approval_status, profile_bio, profile_links, updated_by, updated_at
    ) values (
      p_institution_id, nullif(btrim(merged ->> 'display_name'), ''),
      nullif(merged ->> 'logo_media_asset_id', '')::uuid,
      nullif(merged ->> 'cover_media_asset_id', '')::uuid,
      nullif(btrim(merged ->> 'accent_color'), ''),
      nullif(btrim(merged ->> 'secondary_color'), ''),
      nullif(btrim(merged ->> 'tertiary_color'), ''),
      nullif(btrim(merged ->> 'text_color'), ''),
      nullif(btrim(merged ->> 'secondary_text_color'), ''),
      nullif(btrim(merged ->> 'tertiary_text_color'), ''),
      nullif(btrim(merged ->> 'surface_color'), ''),
      coalesce(nullif(btrim(merged ->> 'approval_status'), ''), 'draft'),
      nullif(merged ->> 'profile_bio', ''),
      coalesce(merged -> 'profile_links', '[]'::jsonb),
      p_actor_person_id, clock_timestamp()
    ) on conflict (institution_id) do update set
      display_name = excluded.display_name,
      logo_media_asset_id = excluded.logo_media_asset_id,
      cover_media_asset_id = excluded.cover_media_asset_id,
      accent_color = excluded.accent_color,
      secondary_color = excluded.secondary_color,
      tertiary_color = excluded.tertiary_color,
      text_color = excluded.text_color,
      secondary_text_color = excluded.secondary_text_color,
      tertiary_text_color = excluded.tertiary_text_color,
      surface_color = excluded.surface_color,
      approval_status = excluded.approval_status,
      profile_bio = excluded.profile_bio,
      profile_links = excluded.profile_links,
      updated_by = excluded.updated_by,
      updated_at = excluded.updated_at;
  end if;

  if p_payload ? 'subscription' then
    insert into public.institution_subscriptions(
      institution_id, plan_id, status, starts_at, trial_ends_at,
      manual_reason, changed_by, paused_at, cancelled_at
    ) values (
      p_institution_id, p_plan_id,
      coalesce(p_payload -> 'subscription' ->> 'status', 'draft')
        ::public.subscription_status,
      nullif(p_payload -> 'subscription' ->> 'starts_at', '')::timestamptz,
      nullif(p_payload -> 'subscription' ->> 'trial_ends_at', '')::timestamptz,
      nullif(btrim(p_payload -> 'subscription' ->> 'manual_reason'), ''),
      p_actor_person_id,
      nullif(p_payload -> 'subscription' ->> 'paused_at', '')::timestamptz,
      nullif(p_payload -> 'subscription' ->> 'cancelled_at', '')::timestamptz
    );
  end if;
end;
$$;

create or replace function app_private.get_institution_for_superadmin(
  p_institution_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_person_id uuid;
  result jsonb;
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null then
    raise insufficient_privilege using message = 'active person identity required';
  end if;
  if not app_private.has_scoped_platform_permission('platform.read', p_institution_id) then
    raise insufficient_privilege using message = 'platform.read required';
  end if;
  result := app_private.institution_management_payload(p_institution_id);
  if result is null then
    raise no_data_found using message = 'institution not found';
  end if;
  return result;
end;
$$;

create or replace function app_private.create_institution_for_superadmin(
  p_request_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  actor_person_id uuid;
  institution_id uuid;
  institution_type_id uuid;
  plan_id uuid;
  plan_code text;
  requested_status public.institution_status;
  request_hash bytea;
  result jsonb;
  prior_hash bytea;
  prior_actor uuid;
  prior_command text;
  prior_institution_id uuid;
  prior_result_management_version bigint;
  changed_fields jsonb;
  effective_payload jsonb;
  subscription_changed boolean := false;
begin
  if p_request_id is null then
    raise invalid_parameter_value using message = 'request_id is required';
  end if;
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null then
    raise insufficient_privilege using message = 'active person identity required';
  end if;
  if not app_private.has_scoped_platform_permission('institution.activate', null) then
    raise insufficient_privilege using message = 'institution.activate required';
  end if;
  if not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message = 'MFA AAL2 required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  request_hash := app_private.institution_management_request_hash(p_payload);
  select receipt.request_hash, receipt.actor_person_id,
         receipt.command_kind, receipt.institution_id,
         receipt.result_management_version
    into prior_hash, prior_actor, prior_command, prior_institution_id,
         prior_result_management_version
  from app_private.institution_management_command_receipts receipt
  where receipt.request_id = p_request_id;
  if prior_institution_id is not null then
    if prior_actor is distinct from actor_person_id
       or prior_command is distinct from 'create'
       or prior_hash is distinct from request_hash then
      raise invalid_parameter_value using
        message = 'request_id already used with a different command payload';
    end if;
    result := app_private.institution_management_payload(prior_institution_id);
    if result is null then
      raise no_data_found using message = 'institution receipt target not found';
    end if;
    if (result ->> 'management_version')::bigint
       is distinct from prior_result_management_version then
      raise serialization_failure using
        message = 'receipt result version is no longer current';
    end if;
    return result;
  end if;

  perform app_private.assert_institution_management_payload(p_payload, true);
  requested_status := coalesce(p_payload ->> 'status', 'draft')
    ::public.institution_status;
  if requested_status <> 'draft'
     and not app_private.has_scoped_platform_permission('institution.status.change', null) then
    raise insufficient_privilege using
      message = 'institution.status.change required for non-draft create';
  end if;
  select type_record.id into institution_type_id
  from public.institution_types type_record
  where lower(type_record.name) = lower(btrim(p_payload ->> 'institution_type_name'))
    and type_record.status = 'active'
  limit 1;
  if institution_type_id is null then
    raise invalid_parameter_value using message = 'unknown or inactive institution type';
  end if;

  plan_id := null;
  if p_payload ? 'subscription' then
    if not app_private.has_scoped_platform_permission('plan.change', null) then
      raise insufficient_privilege using message = 'plan.change required';
    end if;
    plan_code := lower(btrim(p_payload -> 'subscription' ->> 'plan_code'));
    select plan_record.id into plan_id
    from public.plans plan_record
    where plan_record.code = plan_code and plan_record.status = 'active'
    limit 1;
    if plan_id is null then
      raise invalid_parameter_value using message = 'unknown or inactive plan';
    end if;
  end if;

  insert into public.institutions(
    public_name, trade_name, legal_name, slug, primary_domain, document_ref,
    document_type, status, timezone, locale, institution_type_id,
    created_by, management_version
  ) values (
    btrim(p_payload ->> 'public_name'),
    nullif(btrim(p_payload ->> 'trade_name'), ''),
    nullif(btrim(p_payload ->> 'legal_name'), ''),
    lower(btrim(p_payload ->> 'slug')),
    nullif(lower(btrim(p_payload ->> 'primary_domain')), ''),
    nullif(btrim(p_payload ->> 'document_ref'), ''),
    coalesce(nullif(btrim(p_payload ->> 'document_type'), ''), 'cnpj'),
    requested_status,
    coalesce(nullif(btrim(p_payload ->> 'timezone'), ''), 'America/Sao_Paulo'),
    coalesce(nullif(btrim(p_payload ->> 'locale'), ''), 'pt-BR'),
    institution_type_id, actor_person_id, 1
  ) returning id into institution_id;

  perform app_private.apply_institution_management_children(
    institution_id, actor_person_id, p_payload, plan_id
  );
  select coalesce(jsonb_agg(key_name order by key_name), '[]'::jsonb)
    into changed_fields from jsonb_object_keys(p_payload) key_name;
  result := app_private.institution_management_payload(institution_id);

  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, before_json, after_json
  ) values (
    actor_person_id, 'aal2', 'institution.create', 'institution', institution_id,
    institution_id, 'success', null,
    jsonb_build_object(
      'status', result ->> 'status',
      'plan_id', result -> 'subscription' -> 'plan_id',
      'plan_code', result -> 'subscription' -> 'plan_code',
      'changed_fields', changed_fields
    )
  );
  insert into app_private.institution_management_command_receipts(
    request_id, actor_person_id, command_kind, institution_id,
    request_hash, result_management_version
  ) values (
    p_request_id, actor_person_id, 'create', institution_id, request_hash,
    (result ->> 'management_version')::bigint
  );
  return result;
exception
  when invalid_text_representation or datetime_field_overflow
    or check_violation or not_null_violation or foreign_key_violation
    or unique_violation then
    raise invalid_parameter_value using message = 'invalid institution payload';
end;
$$;

create or replace function app_private.update_institution_for_superadmin(
  p_request_id uuid,
  p_institution_id uuid,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  actor_person_id uuid;
  institution_record public.institutions%rowtype;
  institution_type_id uuid;
  current_plan_id uuid;
  current_plan_code text;
  current_subscription_status text;
  current_starts_at timestamptz;
  current_trial_ends_at timestamptz;
  current_manual_reason text;
  current_paused_at timestamptz;
  current_cancelled_at timestamptz;
  requested_plan_id uuid;
  requested_plan_code text;
  requested_status public.institution_status;
  request_hash bytea;
  result jsonb;
  prior_hash bytea;
  request_record jsonb;
  prior_actor uuid;
  prior_command text;
  prior_institution_id uuid;
  prior_result_management_version bigint;
  changed_fields jsonb;
  effective_payload jsonb;
  subscription_changed boolean := false;
begin
  if p_request_id is null or p_institution_id is null
     or p_expected_version is null or p_expected_version < 1 then
    raise invalid_parameter_value using
      message = 'request_id, institution_id and positive expected_version are required';
  end if;
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null then
    raise insufficient_privilege using message = 'active person identity required';
  end if;
  if not app_private.has_scoped_platform_permission('institution.update', p_institution_id) then
    raise insufficient_privilege using message = 'institution.update required';
  end if;
  if not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message = 'MFA AAL2 required';
  end if;

  effective_payload := p_payload;
  request_record := jsonb_build_object(
    'institution_id', p_institution_id,
    'expected_version', p_expected_version,
    'payload', p_payload
  );
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  request_hash := app_private.institution_management_request_hash(request_record);
  select receipt.request_hash, receipt.actor_person_id,
         receipt.command_kind, receipt.institution_id,
         receipt.result_management_version
    into prior_hash, prior_actor, prior_command, prior_institution_id,
         prior_result_management_version
  from app_private.institution_management_command_receipts receipt
  where receipt.request_id = p_request_id;
  if prior_institution_id is not null then
    if prior_actor is distinct from actor_person_id
       or prior_command is distinct from 'update'
       or prior_hash is distinct from request_hash then
      raise invalid_parameter_value using
        message = 'request_id already used with a different command payload';
    end if;
    result := app_private.institution_management_payload(prior_institution_id);
    if result is null then
      raise no_data_found using message = 'institution receipt target not found';
    end if;
    if (result ->> 'management_version')::bigint
       is distinct from prior_result_management_version then
      raise serialization_failure using
        message = 'receipt result version is no longer current';
    end if;
    return result;
  end if;

  perform app_private.assert_institution_management_payload(p_payload, false);
  select institution_row.* into institution_record
  from public.institutions institution_row
  where institution_row.id = p_institution_id
    and institution_row.deleted_at is null
  for update;
  if institution_record.id is null then
    raise no_data_found using message = 'institution not found';
  end if;
  if institution_record.management_version is distinct from p_expected_version then
    raise serialization_failure using message = 'stale institution version';
  end if;

  requested_status := institution_record.status;
  if p_payload ? 'status' then
    requested_status := (p_payload ->> 'status')::public.institution_status;
    if requested_status is distinct from institution_record.status
       and not app_private.has_scoped_platform_permission('institution.status.change', p_institution_id) then
      raise insufficient_privilege using message = 'institution.status.change required';
    end if;
  end if;

  institution_type_id := institution_record.institution_type_id;
  if p_payload ? 'institution_type_name' then
    select type_record.id into institution_type_id
    from public.institution_types type_record
    where lower(type_record.name) = lower(btrim(p_payload ->> 'institution_type_name'))
      and type_record.status = 'active'
    limit 1;
    if institution_type_id is null then
      raise invalid_parameter_value using message = 'unknown or inactive institution type';
    end if;
  end if;

  select subscription_record.plan_id, plan_record.code,
         subscription_record.status::text, subscription_record.starts_at,
         subscription_record.trial_ends_at, subscription_record.manual_reason,
         subscription_record.paused_at, subscription_record.cancelled_at
    into current_plan_id, current_plan_code, current_subscription_status,
         current_starts_at, current_trial_ends_at, current_manual_reason,
         current_paused_at, current_cancelled_at
  from public.institution_subscriptions subscription_record
  left join public.plans plan_record on plan_record.id = subscription_record.plan_id
  where subscription_record.institution_id = p_institution_id
  order by subscription_record.created_at desc, subscription_record.id desc
  limit 1;
  requested_plan_id := current_plan_id;
  requested_plan_code := current_plan_code;
  if p_payload ? 'subscription' then
    requested_plan_code := lower(btrim(p_payload -> 'subscription' ->> 'plan_code'));
    select plan_record.id into requested_plan_id
    from public.plans plan_record
    where plan_record.code = requested_plan_code and plan_record.status = 'active'
    limit 1;
    if requested_plan_id is null then
      raise invalid_parameter_value using message = 'unknown or inactive plan';
    end if;
    subscription_changed := current_plan_id is null
      or requested_plan_id is distinct from current_plan_id
      or coalesce(p_payload -> 'subscription' ->> 'status', 'draft')
           is distinct from current_subscription_status
      or nullif(p_payload -> 'subscription' ->> 'starts_at', '')::timestamptz
           is distinct from current_starts_at
      or nullif(p_payload -> 'subscription' ->> 'trial_ends_at', '')::timestamptz
           is distinct from current_trial_ends_at
      or nullif(btrim(p_payload -> 'subscription' ->> 'manual_reason'), '')
           is distinct from current_manual_reason
      or nullif(p_payload -> 'subscription' ->> 'paused_at', '')::timestamptz
           is distinct from current_paused_at
      or nullif(p_payload -> 'subscription' ->> 'cancelled_at', '')::timestamptz
           is distinct from current_cancelled_at;
    if subscription_changed
       and not app_private.has_scoped_platform_permission('plan.change', p_institution_id) then
      raise insufficient_privilege using message = 'plan.change required';
    end if;
    if not subscription_changed then
      effective_payload := p_payload - 'subscription';
    end if;
  end if;

  update public.institutions institution_row set
    public_name = case when p_payload ? 'public_name'
      then btrim(p_payload ->> 'public_name') else institution_row.public_name end,
    trade_name = case when p_payload ? 'trade_name'
      then nullif(btrim(p_payload ->> 'trade_name'), '') else institution_row.trade_name end,
    legal_name = case when p_payload ? 'legal_name'
      then nullif(btrim(p_payload ->> 'legal_name'), '') else institution_row.legal_name end,
    slug = case when p_payload ? 'slug'
      then lower(btrim(p_payload ->> 'slug')) else institution_row.slug end,
    primary_domain = case when p_payload ? 'primary_domain'
      then nullif(lower(btrim(p_payload ->> 'primary_domain')), '')
      else institution_row.primary_domain end,
    document_ref = case when p_payload ? 'document_ref'
      then nullif(btrim(p_payload ->> 'document_ref'), '')
      else institution_row.document_ref end,
    document_type = case when p_payload ? 'document_type'
      then btrim(p_payload ->> 'document_type') else institution_row.document_type end,
    status = requested_status,
    timezone = case when p_payload ? 'timezone'
      then btrim(p_payload ->> 'timezone') else institution_row.timezone end,
    locale = case when p_payload ? 'locale'
      then btrim(p_payload ->> 'locale') else institution_row.locale end,
    institution_type_id = institution_type_id,
    management_version = institution_row.management_version + 1,
    updated_at = greatest(
      clock_timestamp(), institution_row.updated_at + interval '1 microsecond'
    )
  where institution_row.id = p_institution_id;

  perform app_private.apply_institution_management_children(
    p_institution_id, actor_person_id, effective_payload, requested_plan_id
  );
  select coalesce(jsonb_agg(key_name order by key_name), '[]'::jsonb)
    into changed_fields from jsonb_object_keys(p_payload) key_name;
  result := app_private.institution_management_payload(p_institution_id);

  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, before_json, after_json
  ) values (
    actor_person_id, 'aal2', 'institution.update', 'institution', p_institution_id,
    p_institution_id, 'success',
    jsonb_build_object(
      'status', institution_record.status::text,
      'plan_id', current_plan_id, 'plan_code', current_plan_code,
      'changed_fields', changed_fields
    ),
    jsonb_build_object(
      'status', result ->> 'status',
      'plan_id', result -> 'subscription' -> 'plan_id',
      'plan_code', result -> 'subscription' -> 'plan_code',
      'changed_fields', changed_fields
    )
  );
  insert into app_private.institution_management_command_receipts(
    request_id, actor_person_id, command_kind, institution_id,
    request_hash, result_management_version
  ) values (
    p_request_id, actor_person_id, 'update', p_institution_id,
    request_hash, (result ->> 'management_version')::bigint
  );
  return result;
exception
  when invalid_text_representation or datetime_field_overflow
    or check_violation or not_null_violation or foreign_key_violation
    or unique_violation then
    raise invalid_parameter_value using message = 'invalid institution payload';
end;
$$;

create or replace function public.get_institution_for_superadmin(
  p_institution_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  return app_private.get_institution_for_superadmin(p_institution_id);
end;
$$;

create or replace function public.create_institution_for_superadmin(
  p_request_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  return app_private.create_institution_for_superadmin(p_request_id, p_payload);
end;
$$;

create or replace function public.update_institution_for_superadmin(
  p_request_id uuid,
  p_institution_id uuid,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  return app_private.update_institution_for_superadmin(
    p_request_id, p_institution_id, p_expected_version, p_payload
  );
end;
$$;

revoke all on function
  app_private.has_scoped_platform_permission(text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function
  app_private.has_scoped_platform_permission(text, uuid)
  to authenticated;
revoke all on function
  app_private.assert_institution_management_payload(jsonb, boolean)
  from public, anon, authenticated, service_role;
revoke all on function
  app_private.institution_management_request_hash(jsonb)
  from public, anon, authenticated, service_role;
revoke all on function
  app_private.institution_management_payload(uuid)
  from public, anon, authenticated, service_role;
revoke all on function
  app_private.apply_institution_management_children(uuid, uuid, jsonb, uuid)
  from public, anon, authenticated, service_role;

revoke all on function app_private.get_institution_for_superadmin(uuid)
  from public, anon, authenticated, service_role;
revoke all on function app_private.create_institution_for_superadmin(uuid, jsonb)
  from public, anon, authenticated, service_role;
revoke all on function
  app_private.update_institution_for_superadmin(uuid, uuid, bigint, jsonb)
  from public, anon, authenticated, service_role;

revoke all on function public.get_institution_for_superadmin(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.create_institution_for_superadmin(uuid, jsonb)
  from public, anon, authenticated, service_role;
revoke all on function
  public.update_institution_for_superadmin(uuid, uuid, bigint, jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.get_institution_for_superadmin(uuid)
  to authenticated;
grant execute on function public.create_institution_for_superadmin(uuid, jsonb)
  to authenticated;
grant execute on function
  public.update_institution_for_superadmin(uuid, uuid, bigint, jsonb)
  to authenticated;

revoke insert, update, delete on table public.institutions from authenticated;
revoke insert, update, delete on table public.institution_addresses from authenticated;
revoke insert, update, delete on table public.institution_contacts from authenticated;
revoke insert, update, delete on table public.institution_branding from authenticated;
revoke insert, update, delete on table public.institution_subscriptions from authenticated;

commit;
