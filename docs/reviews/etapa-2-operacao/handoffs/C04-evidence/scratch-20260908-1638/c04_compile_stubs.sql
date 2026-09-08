-- Scratch-only stubs. Their single purpose is to let PostgreSQL compile the
-- plpgsql bodies of the candidate; none of this is part of the package.
create schema if not exists app_private;
create schema if not exists extensions;
create schema if not exists auth;
create extension if not exists pgcrypto with schema extensions;

create type public.record_status as enum ('draft','active','inactive','suspended','archived');

create table public.activity_locations(
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null,
  unit_id uuid,
  name text not null,
  description text,
  status public.record_status not null default 'active',
  management_version bigint not null default 1,
  created_by_person_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  scope_kind text not null,
  kind text not null,
  floor text,
  address jsonb,
  visibility text not null,
  created_by_internal_identity_id uuid
);

create table app_private.superadmin_internal_identities(id uuid primary key);
create table auth.sessions(id uuid primary key, not_after timestamptz);

create type app_private.superadmin_internal_context as(
  internal_identity_id uuid,internal_auth_link_id uuid,internal_membership_id uuid,
  auth_user_id uuid,session_id uuid,platform_role_id uuid,platform_role_code text,
  scope_kind text,scope_institution_id uuid,resolved_institution_id uuid,
  aal text,permission_code text,requires_mfa boolean
);

create function app_private.require_superadmin_internal_context(p_permission_code text)
returns setof app_private.superadmin_internal_context language sql stable as $$
  select null::app_private.superadmin_internal_context $$;

create function app_private.superadmin_location_normalize_v2(p_payload jsonb)
returns jsonb language sql immutable as $$ select p_payload $$;

create function app_private.superadmin_location_owner_v2(
  p_context app_private.superadmin_internal_context,p_scope_kind text,
  p_institution_id uuid,p_unit_id uuid) returns void language sql as $$ select $$;

create function app_private.superadmin_location_payload_v2(p_location_id uuid)
returns jsonb language sql stable as $$ select '{}'::jsonb $$;

create function app_private.superadmin_internal_error_envelope(p_code text,p_correlation uuid)
returns jsonb language sql stable as $$ select '{}'::jsonb $$;

create function app_private.audit_superadmin_internal_denial_if_identified(
  p_capability text,p_action text,p_code text,p_correlation uuid,p_resource uuid)
returns void language sql as $$ select $$;

create type public.audit_outcome as enum('success','denied');

create function app_private.audit_append_superadmin_internal(
  p_identity uuid,p_link uuid,p_membership uuid,p_session uuid,p_capability text,
  p_aal text,p_action text,p_outcome public.audit_outcome,p_reason text,
  p_correlation uuid,p_institution uuid,p_resource_kind text,p_resource_id uuid)
returns void language sql as $$ select $$;
