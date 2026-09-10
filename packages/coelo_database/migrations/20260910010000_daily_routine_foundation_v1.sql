-- Rotina diaria: fundacao do agregado (modelos, aplicacoes e lancamentos).
--
-- Contexto: a migration 20260825193112_final_review_daily_routine_lint_hardening
-- faz CREATE OR REPLACE de tres funcoes que dependem de treze tabelas publicas,
-- de uma tabela de recibos em app_private e de sete auxiliares que nenhuma
-- migration deste repositorio jamais criou. O teste pgTAP
-- supabase/tests/daily_routine_foundation_test.sql especifica esse contrato por
-- inteiro e falha desde entao. Esta migration cria o que falta e nao reescreve
-- os corpos ja endurecidos pela 20260825193112: as regressoes de escopo em
-- daily_routine_scope_closure_test.sql conferem justamente aqueles corpos.
--
-- Forward-only. Fase MVP em AAL1 conforme ADR 0034 e o precedente de
-- 20260908182839_access_profile_models_aal1_phase_policy: o metadado
-- requires_mfa permanece verdadeiro para o portao formal, e o corpo do comando
-- preserva a mensagem 'MFA AAL2 required', mas a exigencia so passa a valer
-- quando a fase de MFA for ligada. Isso mantem D7 (Lancamentos com tela minima
-- sobre daily-routine.publish) alcancavel no MVP sem apagar o portao.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '600s';
select pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('coelo.daily-routine.foundation', 0)
);

do $preflight$
begin
  if current_user <> 'postgres' then
    raise exception using errcode='42501',
      message='daily routine foundation must run as postgres';
  end if;
  if pg_catalog.to_regclass('public.routine_models') is not null then
    raise exception using errcode='55000',
      message='daily routine foundation already present';
  end if;
  if pg_catalog.to_regclass('public.institutions') is null
    or pg_catalog.to_regclass('public.child_contexts') is null
    or pg_catalog.to_regclass('audit.audit_logs') is null then
    raise exception using errcode='55000',
      message='daily routine foundation requires the contextual core';
  end if;
end
$preflight$;

-- ---------------------------------------------------------------------------
-- Capacidades
-- ---------------------------------------------------------------------------

insert into public.platform_permissions(
  code, module_code, screen_code, action_code, description, risk_level, requires_mfa
) values
  ('routine.read','routine','daily_routine','read',
   'Visualizar modelos, aplicacoes e lancamentos de rotina diaria.','normal',false),
  ('routine.manage_models','routine','daily_routine','manage_models',
   'Criar e editar modelos de rotina diaria.','high',false),
  ('routine.manage_applications','routine','daily_routine','manage_applications',
   'Aplicar modelos de rotina a instituicao, unidade, turma ou atividade.','high',false),
  ('routine.record','routine','daily_routine','record',
   'Registrar respostas de rotina em um lancamento em rascunho.','normal',false),
  ('routine.publish','routine','daily_routine','publish',
   'Publicar um lancamento de rotina para as familias.','high',true),
  ('routine.correct','routine','daily_routine','correct',
   'Corrigir um lancamento de rotina ja publicado, com justificativa.','high',true),
  ('routine.import','routine','daily_routine','import',
   'Importar modelos de rotina.','high',true),
  ('routine.export','routine','daily_routine','export',
   'Exportar rotinas e lancamentos.','high',true)
on conflict (code) do update set
  module_code=excluded.module_code, screen_code=excluded.screen_code,
  action_code=excluded.action_code, description=excluded.description,
  risk_level=excluded.risk_level, requires_mfa=excluded.requires_mfa,
  status='active', updated_at=now();

insert into public.institution_permissions(
  code, module_code, screen_code, action_code, description, risk_level, requires_mfa
) values
  ('routine.read','routine','daily_routine','read',
   'Visualizar rotina diaria dentro do escopo contextual.','normal',false),
  ('routine.manage_models','routine','daily_routine','manage_models',
   'Gerenciar modelos de rotina dentro do escopo contextual.','high',false),
  ('routine.manage_applications','routine','daily_routine','manage_applications',
   'Gerenciar aplicacoes de rotina dentro do escopo contextual.','high',false),
  ('routine.record','routine','daily_routine','record',
   'Registrar respostas de rotina dentro do escopo contextual.','normal',false),
  ('routine.publish','routine','daily_routine','publish',
   'Publicar lancamentos de rotina dentro do escopo contextual.','high',true),
  ('routine.correct','routine','daily_routine','correct',
   'Corrigir lancamentos publicados dentro do escopo contextual.','high',true),
  ('routine.import','routine','daily_routine','import',
   'Importar modelos de rotina dentro do escopo contextual.','high',true),
  ('routine.export','routine','daily_routine','export',
   'Exportar rotina dentro do escopo contextual.','high',true)
on conflict (code) do update set
  module_code=excluded.module_code, screen_code=excluded.screen_code,
  action_code=excluded.action_code, description=excluded.description,
  risk_level=excluded.risk_level, requires_mfa=excluded.requires_mfa,
  status='active', updated_at=now();

-- ---------------------------------------------------------------------------
-- Modelos e definicao
-- ---------------------------------------------------------------------------

create table public.routine_models (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  origin_scope text not null default 'institution'
    check (origin_scope in ('institution','unit')),
  origin_unit_id uuid references public.units(id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  description text not null default '',
  status text not null default 'draft'
    check (status in ('draft','active','inactive','archived')),
  current_version_id uuid,
  management_version bigint not null default 0,
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint routine_models_origin_check check (
    (origin_scope='institution' and origin_unit_id is null)
    or (origin_scope='unit' and origin_unit_id is not null)
  )
);
create unique index routine_models_scope_name_uidx
  on public.routine_models(
    institution_id,
    coalesce(origin_unit_id,'00000000-0000-0000-0000-000000000000'::uuid),
    lower(btrim(name))
  ) where status <> 'archived';
create index routine_models_directory_idx
  on public.routine_models(institution_id, status, updated_at desc);

create table public.routine_model_versions (
  id uuid primary key default gen_random_uuid(),
  model_id uuid not null references public.routine_models(id) on delete cascade,
  version integer not null check (version > 0),
  definition_json jsonb not null default '{}'::jsonb,
  published_at timestamptz,
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (model_id, version)
);

alter table public.routine_models
  add constraint routine_models_current_version_fkey
  foreign key (current_version_id)
  references public.routine_model_versions(id) on delete set null;

create table public.routine_sections (
  id uuid primary key default gen_random_uuid(),
  model_version_id uuid not null
    references public.routine_model_versions(id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  sort_order integer not null check (sort_order >= 0),
  created_at timestamptz not null default now(),
  unique (model_version_id, sort_order)
);

create table public.routine_fields (
  id uuid primary key default gen_random_uuid(),
  section_id uuid not null references public.routine_sections(id) on delete cascade,
  label text not null check (btrim(label) <> ''),
  kind text not null check (
    kind in ('short_text','long_text','number','boolean','single_choice','multiple_choice')
  ),
  sort_order integer not null check (sort_order >= 0),
  is_required boolean not null default false,
  initial_value jsonb,
  minimum_value numeric,
  maximum_value numeric,
  created_at timestamptz not null default now(),
  unique (section_id, sort_order),
  constraint routine_fields_range_check check (
    minimum_value is null or maximum_value is null or maximum_value >= minimum_value
  ),
  constraint routine_fields_range_kind_check check (
    kind = 'number' or (minimum_value is null and maximum_value is null)
  )
);
create index routine_fields_section_idx on public.routine_fields(section_id, sort_order);

create table public.routine_field_options (
  id uuid primary key default gen_random_uuid(),
  field_id uuid not null references public.routine_fields(id) on delete cascade,
  label text not null check (btrim(label) <> ''),
  sort_order integer not null check (sort_order >= 0),
  created_at timestamptz not null default now(),
  unique (field_id, sort_order)
);

create table public.routine_field_conditions (
  id uuid primary key default gen_random_uuid(),
  parent_field_id uuid not null references public.routine_fields(id) on delete cascade,
  target_field_id uuid not null references public.routine_fields(id) on delete cascade,
  option_id uuid references public.routine_field_options(id) on delete cascade,
  boolean_value boolean,
  depth integer not null default 1 check (depth between 1 and 4),
  created_at timestamptz not null default now(),
  constraint routine_field_conditions_self_check check (parent_field_id <> target_field_id),
  constraint routine_field_conditions_trigger_check check (
    (option_id is not null and boolean_value is null)
    or (option_id is null and boolean_value is not null)
  ),
  unique (parent_field_id, target_field_id,
    coalesce(option_id,'00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(boolean_value,false))
);
create index routine_field_conditions_target_idx
  on public.routine_field_conditions(target_field_id);

-- ---------------------------------------------------------------------------
-- Aplicacoes
-- ---------------------------------------------------------------------------

create table public.routine_applications (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  unit_id uuid references public.units(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  activity_id uuid references public.activity_definitions(id) on delete cascade,
  scope_kind text not null default 'institution'
    check (scope_kind in ('institution','unit','group','activity')),
  source_model_version_id uuid
    references public.routine_model_versions(id) on delete restrict,
  parent_application_id uuid references public.routine_applications(id) on delete set null,
  inheritance_mode text not null default 'inherited'
    check (inheritance_mode in ('inherited','customized')),
  visibility text not null default 'authorized_guardians'
    check (visibility in ('authorized_guardians','institution_staff','unit_staff')),
  valid_from date,
  valid_until date,
  starts_at time,
  ends_at time,
  status text not null default 'draft'
    check (status in ('draft','active','inactive','archived')),
  management_version bigint not null default 0,
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint routine_applications_scope_check check (
    (scope_kind='institution' and unit_id is null and group_id is null and activity_id is null)
    or (scope_kind='unit' and unit_id is not null and group_id is null and activity_id is null)
    or (scope_kind='group' and unit_id is not null and group_id is not null and activity_id is null)
    or (scope_kind='activity' and unit_id is not null and group_id is not null
      and activity_id is not null)
  ),
  constraint routine_applications_validity_check check (
    valid_until is null or valid_from is null or valid_until >= valid_from
  ),
  constraint routine_applications_window_check check (
    ends_at is null or starts_at is null or ends_at > starts_at
  ),
  constraint routine_applications_parent_check check (parent_application_id <> id)
);
create index routine_applications_directory_idx
  on public.routine_applications(institution_id, status, updated_at desc);
create index routine_applications_scope_idx
  on public.routine_applications(institution_id, unit_id, group_id, activity_id);
create index routine_applications_parent_idx
  on public.routine_applications(parent_application_id);

create table public.routine_application_revisions (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null
    references public.routine_applications(id) on delete cascade,
  revision_no integer not null check (revision_no > 0),
  source_model_version_id uuid
    references public.routine_model_versions(id) on delete set null,
  origin_application_id uuid
    references public.routine_applications(id) on delete set null,
  effective_definition jsonb not null default '{}'::jsonb,
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (application_id, revision_no)
);
create index routine_application_revisions_recent_idx
  on public.routine_application_revisions(application_id, revision_no desc);

create table public.routine_application_assignees (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null
    references public.routine_applications(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  membership_id uuid not null
    references public.institution_memberships(id) on delete cascade,
  responsibility text not null default 'record'
    check (responsibility in ('record','review','publish')),
  created_at timestamptz not null default now(),
  unique (application_id, membership_id, responsibility)
);

-- ---------------------------------------------------------------------------
-- Lancamentos
-- ---------------------------------------------------------------------------

create table public.routine_launches (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  unit_id uuid references public.units(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  application_id uuid not null
    references public.routine_applications(id) on delete restrict,
  application_revision_id uuid
    references public.routine_application_revisions(id) on delete set null,
  launch_date date not null,
  status text not null default 'draft'
    check (status in ('draft','published','corrected','cancelled')),
  management_version bigint not null default 0,
  published_at timestamptz,
  corrected_at timestamptz,
  published_by_person_id uuid references public.people(id) on delete restrict,
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint routine_launches_published_check check (
    (status in ('draft','cancelled') and published_at is null)
    or (status in ('published','corrected') and published_at is not null)
  )
);
create unique index routine_launches_application_date_uidx
  on public.routine_launches(application_id, launch_date)
  where status <> 'cancelled';
create index routine_launches_directory_idx
  on public.routine_launches(institution_id, launch_date desc, status);

create table public.routine_child_entries (
  id uuid primary key default gen_random_uuid(),
  launch_id uuid not null references public.routine_launches(id) on delete cascade,
  child_context_id uuid not null references public.child_contexts(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (launch_id, child_context_id)
);

create table public.routine_answers (
  id uuid primary key default gen_random_uuid(),
  child_entry_id uuid not null
    references public.routine_child_entries(id) on delete cascade,
  field_id uuid not null references public.routine_fields(id) on delete restrict,
  value_json jsonb,
  answered_by_person_id uuid references public.people(id) on delete restrict,
  answered_at timestamptz,
  created_at timestamptz not null default now(),
  unique (child_entry_id, field_id)
);
create index routine_answers_entry_idx on public.routine_answers(child_entry_id);

create table public.routine_launch_revisions (
  id uuid primary key default gen_random_uuid(),
  launch_id uuid not null references public.routine_launches(id) on delete cascade,
  revision_no integer not null check (revision_no > 0),
  reason text not null check (btrim(reason) <> ''),
  before_json jsonb,
  after_json jsonb,
  changed_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (launch_id, revision_no)
);

create table app_private.routine_command_receipts (
  request_id uuid primary key,
  actor_person_id uuid not null references public.people(id) on delete restrict,
  command text not null check (btrim(command) <> ''),
  aggregate_id uuid,
  response jsonb not null,
  created_at timestamptz not null default now()
);
create index routine_command_receipts_actor_idx
  on app_private.routine_command_receipts(actor_person_id, created_at desc);

commit;
