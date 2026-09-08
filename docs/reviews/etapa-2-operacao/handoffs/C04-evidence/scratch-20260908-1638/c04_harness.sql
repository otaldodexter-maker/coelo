-- Scratch harness. Everything here exists to exercise the candidate's own logic in
-- isolation; it replaces the authorization stack with a settable actor so the branches
-- of the two RPCs can be reached without the full internal-auth deployment.
create schema if not exists app_private;
create schema if not exists extensions;
create schema if not exists auth;
create extension if not exists pgcrypto with schema extensions;

create type public.record_status as enum ('draft','active','inactive','suspended','archived');
create type public.audit_outcome as enum('success','denied');

create table public.institutions(id uuid primary key, deleted_at timestamptz);
create table public.units(
  id uuid primary key, institution_id uuid not null references public.institutions(id),
  status public.record_status not null default 'active',
  unique(id,institution_id));

create table public.activity_locations(
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  unit_id uuid,
  name text not null,
  description text,
  status public.record_status not null default 'active',
  management_version bigint not null default 1 check(management_version>0),
  created_by_person_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  scope_kind text not null check(scope_kind in('institution','unit')),
  kind text not null check(kind in('internal','external')),
  floor text,
  address jsonb,
  visibility text not null check(visibility in('team','guardians','students','all')),
  created_by_internal_identity_id uuid,
  constraint activity_locations_unit_institution_fkey foreign key(unit_id,institution_id)
    references public.units(id,institution_id) on delete cascade
);
create unique index activity_locations_active_name_uidx
  on public.activity_locations(unit_id,lower(name)) where status<>'archived';
create unique index activity_locations_institution_name_uidx
  on public.activity_locations(institution_id,lower(name))
  where unit_id is null and status<>'archived';

create table app_private.superadmin_internal_identities(id uuid primary key);
create table auth.sessions(id uuid primary key, not_after timestamptz);

create type app_private.superadmin_internal_context as(
  internal_identity_id uuid,internal_auth_link_id uuid,internal_membership_id uuid,
  auth_user_id uuid,session_id uuid,platform_role_id uuid,platform_role_code text,
  scope_kind text,scope_institution_id uuid,resolved_institution_id uuid,
  aal text,permission_code text,requires_mfa boolean
);

-- The actor is a table row so a test can change identity, role, scope or session
-- between calls, which is how the re-verification branches get exercised.
create table app_private.harness_actor(
  singleton boolean primary key default true,
  identity_id uuid, session_id uuid, role_code text, scope_kind text,
  scope_institution_id uuid, denied boolean not null default false);

create function app_private.require_superadmin_internal_context(p_permission_code text)
returns setof app_private.superadmin_internal_context
language plpgsql stable security definer set search_path='' as $$
declare a app_private.harness_actor%rowtype;
begin
  select * into a from app_private.harness_actor;
  if not found then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_AUTH_REQUIRED';
  end if;
  if a.denied then
    raise insufficient_privilege using message='internal authorization denied',detail='SAI_INTERNAL_CONTEXT_DENIED';
  end if;
  return next (a.identity_id,gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),a.session_id,
    gen_random_uuid(),a.role_code,a.scope_kind,a.scope_institution_id,a.scope_institution_id,
    'aal1',p_permission_code,false)::app_private.superadmin_internal_context;
end $$;

create function app_private.superadmin_internal_error_envelope(p_code text,p_correlation uuid)
returns jsonb language sql stable as $$
  select jsonb_build_object('ok',false,'data',null,
    'error',jsonb_build_object('code',p_code,'correlation_id',p_correlation)) $$;

create table app_private.harness_audit(
  capability text, action text, outcome text, code text, resource_id uuid, at timestamptz default now());

create function app_private.audit_superadmin_internal_denial_if_identified(
  p_capability text,p_action text,p_code text,p_correlation uuid,p_resource uuid)
returns void language sql as $$
  insert into app_private.harness_audit(capability,action,outcome,code,resource_id)
  values(p_capability,p_action,'denied',p_code,p_resource) $$;

create function app_private.audit_append_superadmin_internal(
  p_identity uuid,p_link uuid,p_membership uuid,p_session uuid,p_capability text,
  p_aal text,p_action text,p_outcome public.audit_outcome,p_reason text,
  p_correlation uuid,p_institution uuid,p_resource_kind text,p_resource_id uuid)
returns void language sql as $$
  insert into app_private.harness_audit(capability,action,outcome,code,resource_id)
  values(p_capability,p_action,p_outcome::text,null,p_resource_id) $$;
