-- Perfis de cuidado e Planos de medicacao: fundacao Supabase.
--
-- Contexto: as duas familias existem no cliente apenas como repositorios de
-- /dev e como UnavailableHealthCareRepository. Nao ha migration nem teste
-- pgTAP neste repositorio, entao as nove acoes do inventario
-- (health-care.list/create/detail/edit e medication.list/create/detail/edit/
-- evidence) nunca tiveram backend. Esta migration cria a fundacao.
--
-- Autorizacao para existir: specs/020-superadmin-health-care.md, secao
-- "Decisao superveniente para o backend", em que o Owner determinou em
-- 2026-08-28 que as pendencias juridicas de Perfis de cuidado nao bloqueiam a
-- implementacao Supabase local do dominio, com dados exclusivamente
-- sinteticos. Contrato de comportamento e seguranca:
-- docs/superpowers/specs/2026-09-01-superadmin-access-health-care-finalization-design.md.
--
-- O que essa decisao NAO resolveu, e continua aberto na OQ-003: prazo de
-- retencao, base legal e regra clinica. Por isso esta migration nao apaga
-- nada por tempo, nao infere consentimento e nao classifica gravidade por
-- conta propria: a gravidade descreve o episodio documentado e nada mais,
-- como a spec 020 exige em texto.
--
-- Minimizacao: dado de saude de crianca so e legivel por quem tem capacidade
-- contextual na instituicao do contexto infantil. Nao ha leitura por
-- plataforma inteira, nem mesmo para platform.read: saude nao segue a regra
-- geral de leitura do Superadmin.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '600s';
select pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('coelo.health-care.foundation', 0)
);

do $preflight$
begin
  if current_user <> 'postgres' then
    raise exception using errcode='42501',
      message='health care foundation must run as postgres';
  end if;
  if pg_catalog.to_regclass('public.health_care_profiles') is not null then
    raise exception using errcode='55000',
      message='health care foundation already present';
  end if;
  if pg_catalog.to_regclass('public.child_contexts') is null
    or pg_catalog.to_regclass('audit.audit_logs') is null then
    raise exception using errcode='55000',
      message='health care foundation requires the contextual core';
  end if;
end
$preflight$;

-- ---------------------------------------------------------------------------
-- Capacidades
-- ---------------------------------------------------------------------------

insert into public.platform_permissions(
  code, module_code, module_label, screen_code, screen_label,
  action_code, action_label, description, risk_level, requires_mfa
) values
  ('health_care.read','health_care','Saude e cuidado','health_care_profiles',
   'Perfis de cuidado','read','Ver',
   'Visualizar perfis de cuidado no escopo autorizado.','critical',false),
  ('health_care.manage','health_care','Saude e cuidado','health_care_profiles',
   'Perfis de cuidado','manage','Gerenciar',
   'Criar e editar perfis de cuidado no escopo autorizado.','critical',true),
  ('medication.read','health_care','Saude e cuidado','medication_plans',
   'Planos de medicacao','read','Ver',
   'Visualizar planos de medicacao no escopo autorizado.','critical',false),
  ('medication.manage','health_care','Saude e cuidado','medication_plans',
   'Planos de medicacao','manage','Gerenciar',
   'Criar e editar planos de medicacao no escopo autorizado.','critical',true),
  ('medication.record_evidence','health_care','Saude e cuidado','medication_plans',
   'Planos de medicacao','record_evidence','Gerenciar',
   'Registrar evidencia de administracao de medicamento.','critical',true)
on conflict (code) do update set
  module_code=excluded.module_code, module_label=excluded.module_label,
  screen_code=excluded.screen_code, screen_label=excluded.screen_label,
  action_code=excluded.action_code, action_label=excluded.action_label,
  description=excluded.description, risk_level=excluded.risk_level,
  requires_mfa=excluded.requires_mfa, status='active', updated_at=now();

insert into public.institution_permissions(
  code, module_code, module_label, screen_code, screen_label,
  action_code, action_label, description, risk_level, requires_mfa
) values
  ('health_care.read','health_care','Saude e cuidado','health_care_profiles',
   'Perfis de cuidado','read','Ver',
   'Visualizar perfis de cuidado dentro do escopo contextual.','critical',false),
  ('health_care.manage','health_care','Saude e cuidado','health_care_profiles',
   'Perfis de cuidado','manage','Gerenciar',
   'Gerenciar perfis de cuidado dentro do escopo contextual.','critical',true),
  ('medication.read','health_care','Saude e cuidado','medication_plans',
   'Planos de medicacao','read','Ver',
   'Visualizar planos de medicacao dentro do escopo contextual.','critical',false),
  ('medication.manage','health_care','Saude e cuidado','medication_plans',
   'Planos de medicacao','manage','Gerenciar',
   'Gerenciar planos de medicacao dentro do escopo contextual.','critical',true),
  ('medication.record_evidence','health_care','Saude e cuidado','medication_plans',
   'Planos de medicacao','record_evidence','Gerenciar',
   'Registrar evidencia de administracao dentro do escopo contextual.','critical',true)
on conflict (code) do update set
  module_code=excluded.module_code, module_label=excluded.module_label,
  screen_code=excluded.screen_code, screen_label=excluded.screen_label,
  action_code=excluded.action_code, action_label=excluded.action_label,
  description=excluded.description, risk_level=excluded.risk_level,
  requires_mfa=excluded.requires_mfa, status='active', updated_at=now();

-- ---------------------------------------------------------------------------
-- Perfis de cuidado
-- ---------------------------------------------------------------------------

create table public.health_care_profiles (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  child_context_id uuid not null unique
    references public.child_contexts(id) on delete cascade,
  operational_status text not null default 'implementation'
    check (operational_status in ('active','implementation','inactive')),
  important_signs text not null default '',
  adaptations text not null default '',
  management_version bigint not null default 0,
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index health_care_profiles_directory_idx
  on public.health_care_profiles(institution_id, operational_status, updated_at desc);

create table public.health_care_profile_items (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.health_care_profiles(id) on delete cascade,
  catalog_item_id text not null check (catalog_item_id ~ '^[a-z][a-z0-9_]*$'),
  other_text text,
  created_at timestamptz not null default now(),
  unique (profile_id, catalog_item_id),
  -- O catalogo vive no cliente e pode crescer sem migration; o banco garante
  -- apenas o que nao pode variar: 'other' exige texto e os demais nao o tem.
  constraint health_care_profile_items_other_check check (
    (catalog_item_id = 'other' and other_text is not null and btrim(other_text) <> '')
    or (catalog_item_id <> 'other' and other_text is null)
  )
);

create table public.health_care_allergies (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.health_care_profiles(id) on delete cascade,
  label text not null check (btrim(label) <> ''),
  allergy_type text not null
    check (allergy_type in ('medication','food','restriction','other')),
  -- Status e gravidade sao dimensoes independentes (spec 020): a gravidade
  -- descreve o episodio documentado e nao prediz intensidade futura.
  status text not null default 'active'
    check (status in ('active','monitoring','history')),
  active boolean not null default true,
  last_episode_at timestamptz,
  episode_severity text check (episode_severity in ('mild','moderate','severe')),
  observed_reaction text not null default '',
  guidance text not null default '',
  notes text not null default '',
  inactivated_at timestamptz,
  inactivation_reason text,
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint health_care_allergies_inactivation_check check (
    (active and inactivated_at is null and inactivation_reason is null)
    or (not active and inactivated_at is not null
        and inactivation_reason is not null and btrim(inactivation_reason) <> '')
  ),
  constraint health_care_allergies_severity_check check (
    episode_severity is null or last_episode_at is not null
  )
);
create index health_care_allergies_profile_idx
  on public.health_care_allergies(profile_id, active, status);

-- Toda mudanca sensivel carrega justificativa. A trilha fica aqui, ao lado do
-- dado, alem de audit.audit_logs, porque a tela de detalhe mostra o historico
-- ao usuario autorizado e audit nao tem grant de cliente.
create table public.health_care_profile_revisions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.health_care_profiles(id) on delete cascade,
  revision_no integer not null check (revision_no > 0),
  subject text not null
    check (subject in ('medication','allergy_or_restriction','care_profile')),
  justification text not null check (btrim(justification) <> ''),
  before_json jsonb,
  after_json jsonb,
  changed_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (profile_id, revision_no)
);

-- ---------------------------------------------------------------------------
-- Planos de medicacao
-- ---------------------------------------------------------------------------

create table public.medication_plans (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  child_context_id uuid not null references public.child_contexts(id) on delete cascade,
  scope_kind text not null default 'institution'
    check (scope_kind in ('institution','unit','group')),
  unit_id uuid references public.units(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  status text not null default 'draft'
    check (status in ('draft','active','suspended','ended')),
  current_version_id uuid,
  management_version bigint not null default 0,
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint medication_plans_scope_check check (
    (scope_kind='institution' and unit_id is null and group_id is null)
    or (scope_kind='unit' and unit_id is not null and group_id is null)
    or (scope_kind='group' and unit_id is not null and group_id is not null)
  )
);
create index medication_plans_directory_idx
  on public.medication_plans(institution_id, status, updated_at desc);
create index medication_plans_child_idx
  on public.medication_plans(child_context_id, status);

-- Versoes sao imutaveis: mudanca relevante cria versao, invalida aprovacao e
-- preserva o passado (spec 020). Nada aqui e atualizado depois de inserido,
-- exceto o campo de aprovacao, que e o proprio ato de revisar a versao.
create table public.medication_plan_versions (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.medication_plans(id) on delete cascade,
  version integer not null check (version > 0),
  medication_name text not null check (btrim(medication_name) <> ''),
  dose_amount numeric not null check (dose_amount > 0),
  dose_unit text not null check (btrim(dose_unit) <> ''),
  administration_route text not null check (btrim(administration_route) <> ''),
  route_details text,
  instructions text,
  reason text not null check (btrim(reason) <> ''),
  valid_from date not null,
  valid_until date,
  timezone text not null check (btrim(timezone) <> ''),
  review_status text not null default 'pending'
    check (review_status in ('pending','approved','rejected','invalidated')),
  review_reason text,
  approved_at timestamptz,
  approved_by_person_id uuid references public.people(id) on delete restrict,
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (plan_id, version),
  constraint medication_plan_versions_validity_check check (
    valid_until is null or valid_until >= valid_from
  ),
  constraint medication_plan_versions_approval_check check (
    (review_status = 'approved'
      and approved_at is not null and approved_by_person_id is not null)
    or (review_status <> 'approved'
      and approved_at is null and approved_by_person_id is null)
  )
);

alter table public.medication_plans
  add constraint medication_plans_current_version_fkey
  foreign key (current_version_id)
  references public.medication_plan_versions(id) on delete set null;

create table public.medication_plan_schedules (
  id uuid primary key default gen_random_uuid(),
  plan_version_id uuid not null
    references public.medication_plan_versions(id) on delete cascade,
  time_of_day time not null,
  weekdays smallint[] not null check (
    array_length(weekdays, 1) between 1 and 7
    and weekdays <@ array[1,2,3,4,5,6,7]::smallint[]
  ),
  timezone text not null check (btrim(timezone) <> ''),
  frequency_kind text not null default 'weekly'
    check (frequency_kind in ('daily','weekly')),
  start_date date,
  end_date date,
  max_occurrences_per_day smallint check (max_occurrences_per_day > 0),
  -- Cada horario pertence a casa ou a uma instituicao (spec 020). Nulo
  -- significa casa; a instituicao e explicita quando a dose e institucional.
  institution_id uuid references public.institutions(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint medication_plan_schedules_window_check check (
    end_date is null or start_date is null or end_date >= start_date
  )
);
create index medication_plan_schedules_version_idx
  on public.medication_plan_schedules(plan_version_id, time_of_day);

-- Evidencia de administracao nao e edicao do plano: comando proprio, capacidade
-- propria e registro append-only.
create table public.medication_plan_evidence (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.medication_plans(id) on delete cascade,
  plan_version_id uuid not null
    references public.medication_plan_versions(id) on delete restrict,
  schedule_id uuid references public.medication_plan_schedules(id) on delete set null,
  occurred_at timestamptz not null,
  outcome text not null
    check (outcome in ('administered','not_administered','refused')),
  reason text,
  note text,
  media_asset_id uuid,
  recorded_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint medication_plan_evidence_reason_check check (
    outcome = 'administered' or (reason is not null and btrim(reason) <> '')
  )
);
create index medication_plan_evidence_plan_idx
  on public.medication_plan_evidence(plan_id, occurred_at desc);

create table app_private.health_care_command_receipts (
  request_id uuid primary key,
  actor_person_id uuid not null references public.people(id) on delete restrict,
  command text not null check (btrim(command) <> ''),
  aggregate_id uuid,
  response jsonb not null,
  created_at timestamptz not null default now()
);

commit;
