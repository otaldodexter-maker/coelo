-- Superadmin Foundation v1
-- Source: specs/011-superadmin-database-rls.md

create schema if not exists app_private;
create schema if not exists audit;

create extension if not exists pgcrypto;

do $$
begin
  create type public.person_type as enum ('adult', 'child', 'service');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.record_status as enum ('draft', 'active', 'inactive', 'suspended', 'archived');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.institution_status as enum ('draft', 'onboarding', 'active', 'inactive', 'suspended', 'archived');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.platform_membership_status as enum ('invited', 'active', 'suspended', 'revoked');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.subscription_status as enum ('draft', 'trial', 'active', 'paused', 'suspended', 'cancelled');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.notice_type as enum ('notice', 'critical_notice', 'popup', 'content_card');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.notice_status as enum ('draft', 'scheduled', 'published', 'expired', 'archived');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.notice_rule_effect as enum ('include', 'exclude');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.permission_effect as enum ('allow', 'deny');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.target_type as enum ('platform', 'institution', 'unit', 'group', 'role', 'plan', 'custom_segment');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.support_session_status as enum ('open', 'pending', 'resolved', 'expired', 'closed', 'revoked');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.audit_outcome as enum ('success', 'denied', 'failed');
exception when duplicate_object then null;
end $$;

create table if not exists public.people (
  id uuid primary key default gen_random_uuid(),
  person_type public.person_type not null,
  first_name text not null,
  last_name text not null,
  display_name text not null,
  legal_name text,
  date_of_birth date,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.person_profile_details (
  person_id uuid primary key references public.people(id) on delete cascade,
  preferred_name text,
  middle_name text,
  gender text,
  marital_status text,
  nationality text,
  naturality text,
  mother_name text,
  father_name text,
  locale text not null default 'pt-BR',
  timezone text not null default 'America/Sao_Paulo',
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.person_professional_details (
  person_id uuid primary key references public.people(id) on delete cascade,
  employment_type text,
  job_title text,
  company_name text,
  industry text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.person_education_details (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people(id) on delete cascade,
  education_level text,
  education_status text,
  institution_name text,
  course_name text,
  field_of_study text,
  start_year int,
  end_year int,
  is_current boolean not null default false,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.person_addresses (
  person_id uuid primary key references public.people(id) on delete cascade,
  country text not null default 'BR',
  state text,
  city text,
  district text,
  street text,
  number text,
  complement text,
  postal_code text,
  reference text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.person_auth_links (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people(id) on delete cascade,
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  status public.record_status not null default 'active',
  linked_at timestamptz not null default now(),
  revoked_at timestamptz
);

create unique index if not exists person_auth_links_auth_user_active_uidx
  on public.person_auth_links(auth_user_id)
  where status = 'active';

create table if not exists public.person_contacts (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people(id) on delete cascade,
  contact_type text not null,
  normalized_value_hash text not null,
  masked_value text,
  verified_at timestamptz,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now()
);

create index if not exists person_contacts_hash_idx on public.person_contacts(normalized_value_hash);

create table if not exists public.invitations (
  id uuid primary key default gen_random_uuid(),
  scope_kind text not null,
  institution_id uuid,
  target_person_id uuid references public.people(id),
  role_code text,
  token_hash text not null unique,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now()
);

create table if not exists public.schema_tables (
  id uuid primary key default gen_random_uuid(),
  schema_name text not null default 'public',
  table_name text not null,
  table_label text,
  table_description text,
  domain text not null,
  status public.record_status not null default 'active',
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(schema_name, table_name, version)
);

create table if not exists public.schema_columns (
  id uuid primary key default gen_random_uuid(),
  schema_table_id uuid not null references public.schema_tables(id) on delete cascade,
  column_name text not null,
  column_label text,
  column_description text,
  column_type text not null,
  is_required boolean not null default false,
  is_nullable boolean not null default true,
  is_unique boolean not null default false,
  is_filterable boolean not null default false,
  is_importable boolean not null default false,
  is_active boolean not null default true,
  position int not null default 0,
  allowed_locales_json jsonb not null default '["pt-BR"]'::jsonb,
  aliases_json jsonb not null default '{}'::jsonb,
  examples_json jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(schema_table_id, column_name)
);

create table if not exists public.institutions (
  id uuid primary key default gen_random_uuid(),
  public_name text not null,
  trade_name text,
  legal_name text,
  slug text not null unique,
  primary_domain text,
  document_ref text,
  document_type text not null default 'cnpj',
  status public.institution_status not null default 'draft',
  timezone text not null default 'America/Sao_Paulo',
  locale text not null default 'pt-BR',
  primary_contact_person_id uuid references public.people(id),
  created_by uuid references public.people(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create unique index if not exists institutions_primary_domain_uidx
  on public.institutions(lower(primary_domain))
  where primary_domain is not null;

create table if not exists public.units (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  name text not null,
  slug text not null,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(institution_id, slug)
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  unit_id uuid references public.units(id) on delete cascade,
  name text not null,
  group_type text not null default 'class',
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.institution_settings (
  institution_id uuid primary key references public.institutions(id) on delete cascade,
  enabled_modules jsonb not null default '[]'::jsonb,
  invite_policy jsonb not null default '{}'::jsonb,
  media_limits jsonb not null default '{}'::jsonb,
  notification_policy jsonb not null default '{}'::jsonb,
  feature_flags jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.institution_branding (
  institution_id uuid primary key references public.institutions(id) on delete cascade,
  display_name text,
  logo_media_asset_id uuid,
  cover_media_asset_id uuid,
  accent_color text,
  secondary_color text,
  text_color text,
  surface_color text,
  approval_status text not null default 'draft',
  updated_by uuid references public.people(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.unit_branding (
  unit_id uuid primary key references public.units(id) on delete cascade,
  display_name text,
  logo_media_asset_id uuid,
  cover_media_asset_id uuid,
  accent_color text,
  secondary_color text,
  text_color text,
  surface_color text,
  inherit_institution_branding boolean not null default true,
  approval_status text not null default 'draft',
  updated_by uuid references public.people(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  status public.record_status not null default 'active',
  billing_mode text not null default 'manual',
  created_at timestamptz not null default now()
);

create table if not exists public.plan_entitlements (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id) on delete cascade,
  entitlement_key text not null,
  value_kind text not null,
  value_json jsonb not null default '{}'::jsonb,
  status public.record_status not null default 'active',
  source_kind text not null default 'plan',
  unique(plan_id, entitlement_key)
);

create table if not exists public.institution_subscriptions (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  plan_id uuid references public.plans(id),
  status public.subscription_status not null default 'draft',
  starts_at timestamptz,
  trial_ends_at timestamptz,
  manual_reason text,
  changed_by uuid references public.people(id),
  paused_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.usage_limits (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  limit_key text not null,
  limit_value numeric not null,
  period_kind text,
  source text not null default 'manual',
  status public.record_status not null default 'active',
  unique(institution_id, limit_key, source)
);

create table if not exists public.platform_roles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  status public.record_status not null default 'active',
  is_system boolean not null default false,
  created_by uuid references public.people(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.platform_permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  module_code text not null,
  screen_code text,
  action_code text not null,
  description text,
  risk_level text not null default 'normal',
  requires_mfa boolean not null default false,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.platform_role_permissions (
  id uuid primary key default gen_random_uuid(),
  role_id uuid not null references public.platform_roles(id) on delete cascade,
  permission_id uuid not null references public.platform_permissions(id) on delete cascade,
  effect public.permission_effect not null default 'allow',
  conditions_json jsonb not null default '{}'::jsonb,
  granted_by uuid references public.people(id),
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  status public.record_status not null default 'active',
  unique(role_id, permission_id)
);

create table if not exists public.platform_memberships (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people(id) on delete cascade,
  role_id uuid not null references public.platform_roles(id),
  status public.platform_membership_status not null default 'invited',
  scope_kind text not null default 'platform',
  scope_institution_id uuid references public.institutions(id),
  mfa_required boolean not null default false,
  invited_by uuid references public.people(id),
  last_reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create table if not exists public.platform_member_permission_overrides (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null references public.platform_memberships(id) on delete cascade,
  permission_id uuid not null references public.platform_permissions(id) on delete cascade,
  effect public.permission_effect not null default 'allow',
  conditions_json jsonb not null default '{}'::jsonb,
  granted_by uuid references public.people(id),
  starts_at timestamptz,
  expires_at timestamptz,
  status public.record_status not null default 'active',
  unique(membership_id, permission_id)
);

create table if not exists public.institution_memberships (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  role_code text not null,
  status public.record_status not null default 'active',
  scope_kind text not null default 'institution',
  scope_unit_id uuid references public.units(id),
  scope_group_id uuid references public.groups(id),
  mfa_required boolean not null default false,
  invited_by uuid references public.people(id),
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create table if not exists public.institution_role_grants (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null references public.institution_memberships(id) on delete cascade,
  permission_code text not null,
  scope_kind text not null default 'institution',
  scope_id uuid,
  granted_by uuid references public.people(id),
  starts_at timestamptz,
  expires_at timestamptz,
  status public.record_status not null default 'active'
);

create table if not exists public.audience_segments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  expression_json jsonb not null default '{}'::jsonb,
  version int not null default 1,
  status public.record_status not null default 'active',
  created_by uuid references public.people(id)
);

create table if not exists public.platform_notices (
  id uuid primary key default gen_random_uuid(),
  notice_type public.notice_type not null,
  status public.notice_status not null default 'draft',
  priority int not null default 0,
  title text,
  body_text text,
  cta_label text,
  cta_url text,
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid references public.people(id),
  approved_by uuid references public.people(id),
  published_at timestamptz,
  silencing_policy jsonb not null default '{}'::jsonb
);

create table if not exists public.notice_rules (
  id uuid primary key default gen_random_uuid(),
  notice_id uuid not null references public.platform_notices(id) on delete cascade,
  segment_id uuid references public.audience_segments(id),
  effect public.notice_rule_effect not null default 'include',
  target_type public.target_type,
  target_id uuid,
  role_filter text,
  conditions_json jsonb not null default '{}'::jsonb,
  rule_version int not null default 1,
  position int not null default 0
);

create table if not exists public.notice_media (
  id uuid primary key default gen_random_uuid(),
  notice_id uuid not null references public.platform_notices(id) on delete cascade,
  media_asset_id uuid,
  media_kind text,
  expected_width int,
  expected_height int,
  max_bytes bigint,
  alt_text text,
  processing_status text not null default 'pending'
);

create table if not exists public.notice_receipts (
  id uuid primary key default gen_random_uuid(),
  notice_id uuid not null references public.platform_notices(id) on delete cascade,
  person_id uuid not null references public.people(id) on delete cascade,
  institution_id uuid references public.institutions(id) on delete cascade,
  delivered_at timestamptz,
  opened_at timestamptz,
  dismissed_at timestamptz,
  acted_at timestamptz,
  unique(notice_id, person_id, institution_id)
);

create table if not exists public.notice_events (
  id uuid primary key default gen_random_uuid(),
  notice_id uuid not null references public.platform_notices(id) on delete cascade,
  event_name text not null,
  person_id uuid references public.people(id),
  institution_id uuid references public.institutions(id),
  occurred_at timestamptz not null default now(),
  properties_json jsonb not null default '{}'::jsonb
);

create table if not exists public.import_jobs (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid references public.institutions(id),
  target_domain text not null,
  target_table text not null,
  source_format text not null,
  source_locale text not null default 'pt-BR',
  target_locale text not null default 'en',
  status public.record_status not null default 'draft',
  summary jsonb not null default '{}'::jsonb,
  created_by uuid references public.people(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.import_files (
  id uuid primary key default gen_random_uuid(),
  import_job_id uuid not null references public.import_jobs(id) on delete cascade,
  storage_path text not null,
  file_name text not null,
  mime_type text,
  size_bytes bigint,
  source_locale text not null default 'pt-BR',
  uploaded_at timestamptz not null default now()
);

create table if not exists public.import_mappings (
  id uuid primary key default gen_random_uuid(),
  import_job_id uuid not null references public.import_jobs(id) on delete cascade,
  target_table text not null,
  target_column text not null,
  source_column text not null,
  source_label text,
  source_locale text not null default 'pt-BR',
  source_aliases_json jsonb not null default '[]'::jsonb,
  transformation_json jsonb not null default '{}'::jsonb,
  position int not null default 0,
  description text
);

create table if not exists public.import_rows (
  id uuid primary key default gen_random_uuid(),
  import_job_id uuid not null references public.import_jobs(id) on delete cascade,
  row_number int not null,
  payload_json jsonb not null default '{}'::jsonb,
  status public.record_status not null default 'draft',
  error_code text
);

create table if not exists public.import_errors (
  id uuid primary key default gen_random_uuid(),
  import_job_id uuid not null references public.import_jobs(id) on delete cascade,
  row_number int,
  column_name text,
  error_code text not null,
  message text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.import_results (
  import_job_id uuid primary key references public.import_jobs(id) on delete cascade,
  created_count int not null default 0,
  updated_count int not null default 0,
  linked_count int not null default 0,
  ignored_count int not null default 0,
  rejected_count int not null default 0,
  completed_at timestamptz
);

create table if not exists public.support_sessions (
  id uuid primary key default gen_random_uuid(),
  opened_by_person_id uuid references public.people(id),
  opened_by_membership_id uuid references public.institution_memberships(id),
  institution_id uuid not null references public.institutions(id),
  unit_id uuid references public.units(id),
  reason_code text not null,
  subreason_code text,
  reported_issue text,
  scope_kind text not null default 'institution',
  scope_id uuid,
  status public.support_session_status not null default 'open',
  priority text not null default 'normal',
  assigned_to_membership_id uuid references public.platform_memberships(id),
  resolution_summary text,
  resolved_by_membership_id uuid references public.platform_memberships(id),
  resolved_at timestamptz,
  opened_at timestamptz not null default now(),
  expires_at timestamptz,
  closed_at timestamptz
);

create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  support_session_id uuid not null references public.support_sessions(id) on delete cascade,
  author_person_id uuid references public.people(id),
  author_membership_id uuid,
  message_text text not null,
  message_kind text not null default 'message',
  visibility text not null default 'participants',
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.support_session_actions (
  id uuid primary key default gen_random_uuid(),
  support_session_id uuid not null references public.support_sessions(id) on delete cascade,
  action_code text not null,
  object_type text,
  object_id uuid,
  sensitivity text not null default 'normal',
  outcome public.audit_outcome not null default 'success',
  occurred_at timestamptz not null default now(),
  metadata_json jsonb not null default '{}'::jsonb
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  scope_kind text not null,
  scope_id uuid,
  conversation_type text not null,
  title text,
  status public.record_status not null default 'active',
  policy_json jsonb not null default '{}'::jsonb,
  created_by uuid references public.people(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz
);

create table if not exists public.conversation_members (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  person_id uuid not null references public.people(id) on delete cascade,
  membership_id uuid,
  member_role text not null,
  status public.record_status not null default 'active',
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  muted_until timestamptz,
  unique(conversation_id, person_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  author_person_id uuid not null references public.people(id),
  body_text text,
  body_json jsonb not null default '{}'::jsonb,
  message_type text not null default 'text',
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.message_receipts (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  person_id uuid not null references public.people(id) on delete cascade,
  delivered_at timestamptz,
  read_at timestamptz,
  seen_at timestamptz,
  unique(message_id, person_id)
);

create table if not exists public.message_edits (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  edited_by uuid not null references public.people(id),
  old_body_text text,
  new_body_text text,
  edited_at timestamptz not null default now()
);

create table if not exists public.channel_policies (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  scope_kind text not null,
  scope_id uuid,
  channel_kind text not null,
  policy_json jsonb not null default '{}'::jsonb,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_person_id uuid references public.people(id),
  actor_membership_id uuid,
  support_session_id uuid references public.support_sessions(id),
  mfa_aal text,
  action_code text not null,
  object_type text,
  object_id uuid,
  institution_id uuid references public.institutions(id),
  outcome public.audit_outcome not null default 'success',
  reason text,
  before_json jsonb,
  after_json jsonb,
  occurred_at timestamptz not null default now()
);

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  event_name text not null,
  institution_id uuid references public.institutions(id),
  actor_pseudonym text,
  context_kind text,
  context_id uuid,
  properties_json jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create table if not exists public.usage_counters (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid references public.institutions(id),
  counter_name text not null,
  period_start timestamptz not null,
  period_end timestamptz not null,
  dimensions_json jsonb not null default '{}'::jsonb,
  value numeric not null default 0,
  updated_at timestamptz not null default now()
);

create unique index if not exists usage_counters_unique_idx
  on public.usage_counters(institution_id, counter_name, period_start, period_end, dimensions_json);

create table if not exists public.usage_snapshots (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid references public.institutions(id),
  snapshot_name text not null,
  period_start timestamptz not null,
  period_end timestamptz not null,
  payload_json jsonb not null default '{}'::jsonb,
  source_cursor text,
  generated_at timestamptz not null default now()
);

create index if not exists institutions_status_created_idx on public.institutions(status, created_at);
create index if not exists units_institution_idx on public.units(institution_id, status);
create index if not exists groups_institution_unit_idx on public.groups(institution_id, unit_id, status);
create index if not exists platform_memberships_person_role_status_idx on public.platform_memberships(person_id, role_id, status);
create index if not exists institution_memberships_person_institution_idx on public.institution_memberships(person_id, institution_id, status);
create index if not exists institution_subscriptions_status_idx on public.institution_subscriptions(institution_id, status, starts_at desc);
create index if not exists notice_rules_notice_position_idx on public.notice_rules(notice_id, position);
create index if not exists support_sessions_institution_status_idx on public.support_sessions(institution_id, status, expires_at);
create index if not exists conversations_scope_idx on public.conversations(institution_id, scope_kind, scope_id, status);
create index if not exists messages_conversation_created_idx on public.messages(conversation_id, created_at desc);
create index if not exists audit_logs_institution_date_idx on public.audit_logs(institution_id, occurred_at desc);
create index if not exists audit_logs_actor_date_idx on public.audit_logs(actor_person_id, occurred_at desc);
create index if not exists analytics_events_institution_event_date_idx on public.analytics_events(institution_id, event_name, occurred_at desc);

create or replace function app_private.current_person_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select pal.person_id
  from public.person_auth_links pal
  where pal.auth_user_id = auth.uid()
    and pal.status = 'active'
  limit 1
$$;

create or replace function app_private.has_mfa_aal2()
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
$$;

create or replace function app_private.has_platform_permission(permission_code text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  with current_person as (
    select app_private.current_person_id() as person_id
  ),
  active_memberships as (
    select pm.id as membership_id, pr.code as role_code, pm.role_id
    from public.platform_memberships pm
    join public.platform_roles pr on pr.id = pm.role_id
    join current_person cp on cp.person_id = pm.person_id
    where pm.status = 'active'
      and pr.status = 'active'
  ),
  target_permission as (
    select id
    from public.platform_permissions
    where code = permission_code
      and status = 'active'
  )
  select coalesce(
    exists (select 1 from active_memberships where role_code = 'owner')
    or exists (
      select 1
      from active_memberships am
      join public.platform_member_permission_overrides mpo
        on mpo.membership_id = am.membership_id
      join target_permission tp on tp.id = mpo.permission_id
      where mpo.status = 'active'
        and mpo.effect = 'allow'
        and (mpo.starts_at is null or mpo.starts_at <= now())
        and (mpo.expires_at is null or mpo.expires_at > now())
    )
    or exists (
      select 1
      from active_memberships am
      join public.platform_role_permissions prp on prp.role_id = am.role_id
      join target_permission tp on tp.id = prp.permission_id
      where prp.status = 'active'
        and prp.effect = 'allow'
    ),
    false
  )
$$;

grant usage on schema app_private to authenticated;
revoke all on schema app_private from anon;
grant execute on function app_private.current_person_id() to authenticated;
grant execute on function app_private.has_mfa_aal2() to authenticated;
grant execute on function app_private.has_platform_permission(text) to authenticated;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'people','person_profile_details','person_professional_details','person_education_details','person_addresses',
    'person_auth_links','person_contacts','invitations','schema_tables','schema_columns','institutions','units','groups',
    'institution_settings','institution_branding','unit_branding','plans','plan_entitlements','institution_subscriptions',
    'usage_limits','platform_roles','platform_permissions','platform_role_permissions','platform_memberships',
    'platform_member_permission_overrides','institution_memberships','institution_role_grants','audience_segments',
    'platform_notices','notice_rules','notice_media','notice_receipts','notice_events','import_jobs','import_files',
    'import_mappings','import_rows','import_errors','import_results','support_sessions','support_messages',
    'support_session_actions','conversations','conversation_members','messages','message_receipts','message_edits',
    'channel_policies','audit_logs','analytics_events','usage_counters','usage_snapshots'
  ]
  loop
    execute format('alter table public.%I enable row level security', table_name);
  end loop;
end $$;

create policy people_self_or_platform_read on public.people
  for select to authenticated
  using (id = app_private.current_person_id() or app_private.has_platform_permission('platform.read'));

create policy person_profile_self_or_platform_read on public.person_profile_details
  for select to authenticated
  using (person_id = app_private.current_person_id() or app_private.has_platform_permission('platform.read'));

create policy person_professional_self_or_platform_read on public.person_professional_details
  for select to authenticated
  using (person_id = app_private.current_person_id() or app_private.has_platform_permission('platform.read'));

create policy person_education_self_or_platform_read on public.person_education_details
  for select to authenticated
  using (person_id = app_private.current_person_id() or app_private.has_platform_permission('platform.read'));

create policy person_addresses_self_or_platform_read on public.person_addresses
  for select to authenticated
  using (person_id = app_private.current_person_id() or app_private.has_platform_permission('platform.read'));

create policy person_contacts_self_or_platform_read on public.person_contacts
  for select to authenticated
  using (person_id = app_private.current_person_id() or app_private.has_platform_permission('platform.read'));

create policy schema_tables_authenticated_read on public.schema_tables
  for select to authenticated
  using ((select auth.uid()) is not null);

create policy schema_columns_authenticated_read on public.schema_columns
  for select to authenticated
  using ((select auth.uid()) is not null);

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'institutions','units','groups','institution_settings','institution_branding','unit_branding','plans','plan_entitlements',
    'institution_subscriptions','usage_limits','platform_roles','platform_permissions','platform_role_permissions',
    'platform_memberships','platform_member_permission_overrides','institution_memberships','institution_role_grants',
    'audience_segments','platform_notices','notice_rules','notice_media','notice_receipts','notice_events','import_jobs',
    'import_files','import_mappings','import_rows','import_errors','import_results','support_sessions','support_messages',
    'support_session_actions','conversations','conversation_members','messages','message_receipts','message_edits',
    'channel_policies','audit_logs','analytics_events','usage_counters','usage_snapshots'
  ]
  loop
    execute format(
      'create policy %I on public.%I for select to authenticated using (app_private.has_platform_permission(''platform.read''))',
      table_name || '_platform_read',
      table_name
    );
  end loop;
end $$;

insert into public.platform_roles(code, name, description, is_system)
values
  ('owner', 'Owner', 'Acesso total Coelo com MFA obrigatoria e auditoria.', true),
  ('operations', 'Operations', 'Operacao de instituicoes, planos e ativacao.', true),
  ('support', 'Support', 'Atendimento e suporte auditado.', true),
  ('content', 'Content', 'Avisos, popups e comunicacao de plataforma.', true),
  ('auditor', 'Auditor', 'Leitura de logs e evidencias sem operacao.', true)
on conflict (code) do nothing;

insert into public.platform_permissions(code, module_code, screen_code, action_code, description, risk_level, requires_mfa)
values
  ('platform.read', 'platform', null, 'read', 'Ler configuracoes e dados operacionais do Superadmin.', 'normal', false),
  ('institution.activate', 'institutions', 'activation', 'create', 'Ativar instituicoes e criar configuracao inicial.', 'high', true),
  ('institution.status.change', 'institutions', 'status', 'update', 'Alterar status de instituicao.', 'high', true),
  ('plan.change', 'plans', 'subscription', 'update', 'Alterar plano/status de instituicao.', 'high', true),
  ('platform.member.invite', 'platform', 'members', 'invite', 'Convidar membros internos Coelo.', 'high', true),
  ('notice.publish', 'notices', 'publish', 'publish', 'Publicar avisos e popups.', 'normal', false),
  ('support.manage', 'support', 'sessions', 'manage', 'Abrir, responder e resolver atendimentos.', 'normal', false),
  ('audit.read', 'audit', 'logs', 'read', 'Ler trilhas de auditoria.', 'high', true)
on conflict (code) do nothing;

insert into public.platform_role_permissions(role_id, permission_id, effect)
select pr.id, pp.id, 'allow'
from public.platform_roles pr
cross join public.platform_permissions pp
where pr.code = 'owner'
on conflict (role_id, permission_id) do nothing;

insert into public.platform_role_permissions(role_id, permission_id, effect)
select pr.id, pp.id, 'allow'
from public.platform_roles pr
join public.platform_permissions pp on pp.code in ('platform.read', 'institution.activate', 'institution.status.change', 'plan.change')
where pr.code = 'operations'
on conflict (role_id, permission_id) do nothing;

insert into public.platform_role_permissions(role_id, permission_id, effect)
select pr.id, pp.id, 'allow'
from public.platform_roles pr
join public.platform_permissions pp on pp.code in ('platform.read', 'support.manage')
where pr.code = 'support'
on conflict (role_id, permission_id) do nothing;

insert into public.platform_role_permissions(role_id, permission_id, effect)
select pr.id, pp.id, 'allow'
from public.platform_roles pr
join public.platform_permissions pp on pp.code in ('platform.read', 'notice.publish')
where pr.code = 'content'
on conflict (role_id, permission_id) do nothing;

insert into public.platform_role_permissions(role_id, permission_id, effect)
select pr.id, pp.id, 'allow'
from public.platform_roles pr
join public.platform_permissions pp on pp.code in ('platform.read', 'audit.read')
where pr.code = 'auditor'
on conflict (role_id, permission_id) do nothing;

insert into public.schema_tables(schema_name, table_name, table_label, table_description, domain)
values
  ('public', 'people', 'Pessoas', 'Pessoa global com ou sem login.', 'identity'),
  ('public', 'person_profile_details', 'Dados pessoais', 'Dados pessoais complementares opcionais.', 'identity'),
  ('public', 'person_professional_details', 'Dados profissionais', 'Dados profissionais basicos.', 'identity'),
  ('public', 'person_education_details', 'Escolaridade', 'Historico ou situacao educacional basica.', 'identity'),
  ('public', 'person_addresses', 'Endereco', 'Endereco residencial opcional.', 'identity'),
  ('public', 'institutions', 'Instituicoes', 'Tenant principal do Coelo.', 'tenancy'),
  ('public', 'platform_roles', 'Perfis Superadmin', 'Catalogo de perfis internos Coelo.', 'superadmin'),
  ('public', 'platform_permissions', 'Permissoes Superadmin', 'Catalogo de permissoes por modulo, tela e acao.', 'superadmin'),
  ('public', 'support_sessions', 'Atendimentos Coelo', 'Canal de atendimento aberto por instituicao ou unidade.', 'support'),
  ('public', 'conversations', 'Conversas', 'Chat institucional por instituicao, unidade ou grupo.', 'chat')
on conflict do nothing;

insert into public.schema_columns(schema_table_id, column_name, column_label, column_description, column_type, is_required, is_nullable, is_importable, position)
select st.id, c.column_name, c.column_label, c.column_description, c.column_type, c.is_required, c.is_nullable, c.is_importable, c.position
from public.schema_tables st
join (
  values
    ('people','first_name','Nome','Primeiro nome da pessoa.','text',true,false,true,10),
    ('people','last_name','Sobrenome','Sobrenome da pessoa.','text',true,false,true,20),
    ('people','display_name','Nome de exibicao','Nome exibido no produto.','text',true,false,true,30),
    ('people','date_of_birth','Data de nascimento','Data de nascimento da pessoa.','date',false,true,true,40),
    ('person_profile_details','gender','Genero','Genero informado pela pessoa.','text',false,true,true,10),
    ('person_profile_details','naturality','Naturalidade','Cidade/UF ou origem de nascimento.','text',false,true,true,20),
    ('person_professional_details','employment_type','Tipo de trabalho','CLT, PJ, empresario, freelancer, estudante ou outro.','text',false,true,true,10),
    ('person_professional_details','job_title','Cargo','Cargo profissional.','text',false,true,true,20),
    ('person_professional_details','company_name','Empresa','Empresa ou organizacao atual.','text',false,true,true,30),
    ('person_education_details','education_level','Escolaridade','Nivel de escolaridade.','text',false,true,true,10),
    ('person_education_details','course_name','Curso','Nome do curso quando aplicavel.','text',false,true,true,20),
    ('person_education_details','field_of_study','Area de estudo','Area de estudo exibida condicionalmente no front.','text',false,true,true,30),
    ('person_addresses','postal_code','CEP','Codigo postal do endereco residencial.','text',false,true,true,10),
    ('institutions','document_ref','CNPJ','Documento principal da instituicao.','text',false,true,true,10),
    ('institutions','legal_name','Razao social','Nome legal da instituicao.','text',false,true,true,20),
    ('institutions','trade_name','Nome fantasia','Nome fantasia da instituicao.','text',false,true,true,30)
) as c(table_name, column_name, column_label, column_description, column_type, is_required, is_nullable, is_importable, position)
  on st.table_name = c.table_name
on conflict (schema_table_id, column_name) do nothing;
