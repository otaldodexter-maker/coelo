-- Meal plans v2: reusable versioned templates, dynamic audiences, canonical
-- scopes, future occurrence snapshots, and RPC-only writes.
-- This file is intended to replace migration
-- packages/coelo_database/migrations/20260820160000_meal_plans_model_audience_availability.sql.

begin;

alter table public.meal_plans
  add column if not exists plan_variant text not null default 'simple',
  add column if not exists audience_segment text not null default 'students',
  add column if not exists visibility_mode text not null default 'immediate',
  add column if not exists visible_from timestamptz,
  add column if not exists source_template_id uuid,
  add column if not exists source_template_version integer,
  add column if not exists scope_rules jsonb not null default '{}'::jsonb,
  add column if not exists excluded_dates date[] not null default '{}',
  add column if not exists exceptions jsonb not null default '[]'::jsonb,
  add column if not exists simple_image_meta jsonb not null default '{}'::jsonb,
  add column if not exists simple_image_alt text,
  add column if not exists simple_notes text;

alter table public.meal_plans
  drop constraint if exists meal_plans_scope_level_check;
alter table public.meal_plans
  add constraint meal_plans_scope_level_check
  check (scope_level in ('global', 'institution', 'unit', 'classLevel', 'activity', 'person'));

do $migration$
begin
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.meal_plans'::regclass
      and conname = 'meal_plans_plan_variant_check'
  ) then
    alter table public.meal_plans add constraint meal_plans_plan_variant_check
      check (plan_variant in ('simple', 'complete'));
  end if;
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.meal_plans'::regclass
      and conname = 'meal_plans_audience_segment_check'
  ) then
    alter table public.meal_plans add constraint meal_plans_audience_segment_check
      check (audience_segment in ('students', 'staff', 'all'));
  end if;
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.meal_plans'::regclass
      and conname = 'meal_plans_visibility_check'
  ) then
    alter table public.meal_plans add constraint meal_plans_visibility_check
      check (
        (visibility_mode = 'immediate' and visible_from is null)
        or (visibility_mode = 'scheduled' and visible_from is not null)
      );
  end if;
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.meal_plans'::regclass
      and conname = 'meal_plans_source_template_version_check'
  ) then
    alter table public.meal_plans add constraint meal_plans_source_template_version_check
      check (
        (source_template_id is null and source_template_version is null)
        or (source_template_id is not null and source_template_version > 0)
      );
  end if;
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.meal_plans'::regclass
      and conname = 'meal_plans_scope_rules_array_check'
  ) then
    alter table public.meal_plans add constraint meal_plans_scope_rules_array_check
      check (jsonb_typeof(scope_rules) = 'object');
  end if;
end
$migration$;

create unique index if not exists meal_plans_id_tenant_uidx
  on public.meal_plans(id, tenant_id);
create index if not exists meal_plans_audience_visibility_idx
  on public.meal_plans(tenant_id, audience_segment, visibility_mode, visible_from);

create table public.meal_plan_templates (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  institution_id uuid references public.institutions(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 240),
  description text,
  plan_variant text not null default 'simple'
    check (plan_variant in ('simple', 'complete')),
  audience_segment text not null default 'students'
    check (audience_segment in ('students', 'staff', 'all')),
  status text not null default 'draft'
    check (status in ('draft', 'published', 'archived')),
  current_version integer not null default 1 check (current_version > 0),
  payload jsonb not null default '{}'::jsonb,
  source_meal_plan_id uuid,
  created_by uuid not null references public.people(id) on delete restrict,
  updated_by uuid not null references public.people(id) on delete restrict,
  published_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meal_plan_templates_tenant_shape_check check (
    institution_id is null or tenant_id = institution_id
  ),
  constraint meal_plan_templates_status_shape_check check (
    (status = 'draft' and published_at is null and archived_at is null)
    or (status = 'published' and published_at is not null and archived_at is null)
    or (status = 'archived' and archived_at is not null)
  ),
  constraint meal_plan_templates_source_plan_tenant_fk
    foreign key (source_meal_plan_id, tenant_id)
    references public.meal_plans(id, tenant_id) on delete restrict
);

create unique index meal_plan_templates_id_tenant_uidx
  on public.meal_plan_templates(id, tenant_id);
create index meal_plan_templates_directory_idx
  on public.meal_plan_templates(tenant_id, institution_id, status, updated_at desc);

create table public.meal_plan_template_versions (
  template_id uuid not null,
  tenant_id uuid not null,
  version integer not null check (version > 0),
  name text not null check (length(btrim(name)) between 1 and 240),
  plan_variant text not null check (plan_variant in ('simple', 'complete')),
  audience_segment text not null check (audience_segment in ('students', 'staff', 'all')),
  payload jsonb not null,
  change_summary text,
  created_by uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (template_id, version),
  constraint meal_plan_template_versions_parent_fk
    foreign key (template_id, tenant_id)
    references public.meal_plan_templates(id, tenant_id) on delete cascade
);

create index meal_plan_template_versions_tenant_idx
  on public.meal_plan_template_versions(tenant_id, template_id, version desc);
create unique index meal_plan_template_versions_tenant_uidx
  on public.meal_plan_template_versions(template_id, tenant_id, version);

alter table public.meal_plans
  add constraint meal_plans_source_template_fk
  foreign key (source_template_id, tenant_id, source_template_version)
  references public.meal_plan_template_versions(template_id, tenant_id, version)
  on delete restrict;

create table public.meal_plan_template_links (
  meal_plan_id uuid primary key,
  tenant_id uuid not null,
  template_id uuid not null,
  template_version integer not null check (template_version > 0),
  link_kind text not null default 'copied' check (link_kind = 'copied'),
  created_by uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint meal_plan_template_links_plan_fk
    foreign key (meal_plan_id, tenant_id)
    references public.meal_plans(id, tenant_id) on delete cascade,
  constraint meal_plan_template_links_version_fk
    foreign key (template_id, tenant_id, template_version)
    references public.meal_plan_template_versions(template_id, tenant_id, version)
    on delete restrict
);

create index meal_plan_template_links_template_idx
  on public.meal_plan_template_links(tenant_id, template_id, template_version);

create table public.meal_plan_scopes (
  id uuid primary key default gen_random_uuid(),
  meal_plan_id uuid not null,
  tenant_id uuid not null,
  scope_level text not null
    check (scope_level in ('global', 'institution', 'unit', 'classLevel', 'activity', 'person')),
  scope_id text not null default '',
  institution_id uuid references public.institutions(id) on delete restrict,
  unit_id uuid references public.units(id) on delete restrict,
  class_id uuid references public.groups(id) on delete restrict,
  activity_id uuid references public.activity_definitions(id) on delete restrict,
  person_id uuid references public.people(id) on delete restrict,
  priority integer not null default 0 check (priority >= 0),
  created_at timestamptz not null default now(),
  constraint meal_plan_scopes_plan_fk
    foreign key (meal_plan_id, tenant_id)
    references public.meal_plans(id, tenant_id) on delete cascade,
  constraint meal_plan_scopes_target_shape_check check (
    (scope_level = 'global' and scope_id = '' and institution_id is null and unit_id is null and class_id is null and activity_id is null and person_id is null)
    or (scope_level = 'institution' and scope_id = institution_id::text and institution_id is not null and unit_id is null and class_id is null and activity_id is null and person_id is null)
    or (scope_level = 'unit' and scope_id = unit_id::text and institution_id is not null and unit_id is not null and class_id is null and activity_id is null and person_id is null)
    or (scope_level = 'classLevel' and scope_id = class_id::text and institution_id is not null and class_id is not null and activity_id is null and person_id is null)
    or (scope_level = 'activity' and scope_id = activity_id::text and institution_id is not null and activity_id is not null and person_id is null)
    or (scope_level = 'person' and scope_id = person_id::text and institution_id is not null and person_id is not null)
  ),
  unique (meal_plan_id, scope_level, scope_id)
);

create index meal_plan_scopes_lookup_idx
  on public.meal_plan_scopes(tenant_id, scope_level, scope_id, priority desc);
create index meal_plan_scopes_activity_idx
  on public.meal_plan_scopes(activity_id, meal_plan_id) where activity_id is not null;

create table public.meal_plan_audiences (
  id uuid primary key default gen_random_uuid(),
  meal_plan_id uuid not null,
  tenant_id uuid not null,
  audience_segment text not null check (audience_segment in ('students', 'staff', 'all')),
  selection_mode text not null check (selection_mode in ('include', 'exclude')),
  target_kind text not null
    check (target_kind in ('institution', 'unit', 'classLevel', 'activity', 'person')),
  target_id uuid not null,
  institution_id uuid not null references public.institutions(id) on delete restrict,
  unit_id uuid references public.units(id) on delete restrict,
  class_id uuid references public.groups(id) on delete restrict,
  activity_id uuid references public.activity_definitions(id) on delete restrict,
  person_id uuid references public.people(id) on delete restrict,
  effective_from date,
  effective_until date,
  rule jsonb not null default '{}'::jsonb,
  label text,
  created_at timestamptz not null default now(),
  constraint meal_plan_audiences_plan_fk
    foreign key (meal_plan_id, tenant_id)
    references public.meal_plans(id, tenant_id) on delete cascade,
  constraint meal_plan_audiences_period_check check (
    effective_until is null or effective_from is null or effective_until >= effective_from
  ),
  constraint meal_plan_audiences_target_shape_check check (
    (target_kind = 'institution' and target_id = institution_id and unit_id is null and class_id is null and activity_id is null and person_id is null)
    or (target_kind = 'unit' and target_id = unit_id and unit_id is not null and class_id is null and activity_id is null and person_id is null)
    or (target_kind = 'classLevel' and target_id = class_id and class_id is not null and activity_id is null and person_id is null)
    or (target_kind = 'activity' and target_id = activity_id and activity_id is not null and person_id is null)
    or (target_kind = 'person' and target_id = person_id and person_id is not null)
  ),
  unique (meal_plan_id, audience_segment, selection_mode, target_kind, target_id)
);

create index meal_plan_audiences_resolution_idx
  on public.meal_plan_audiences(tenant_id, meal_plan_id, audience_segment, selection_mode, effective_from, effective_until);
create index meal_plan_audiences_person_idx
  on public.meal_plan_audiences(person_id, meal_plan_id) where person_id is not null;

create table public.meal_plan_availability (
  meal_plan_id uuid primary key,
  tenant_id uuid not null,
  visibility_mode text not null check (visibility_mode in ('immediate', 'scheduled')),
  visible_from timestamptz,
  starts_on date not null,
  ends_on date not null,
  recurrence jsonb not null default '{}'::jsonb,
  excluded_dates date[] not null default '{}',
  exception_rules jsonb not null default '[]'::jsonb,
  timezone text not null default 'America/Sao_Paulo'
    check (length(btrim(timezone)) between 1 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meal_plan_availability_plan_fk
    foreign key (meal_plan_id, tenant_id)
    references public.meal_plans(id, tenant_id) on delete cascade,
  constraint meal_plan_availability_period_check check (ends_on >= starts_on),
  constraint meal_plan_availability_visibility_check check (
    (visibility_mode = 'immediate' and visible_from is null)
    or (visibility_mode = 'scheduled' and visible_from is not null)
  ),
  constraint meal_plan_availability_recurrence_object_check
    check (jsonb_typeof(recurrence) = 'object'),
  constraint meal_plan_availability_exceptions_array_check
    check (jsonb_typeof(exception_rules) = 'array')
);

create index meal_plan_availability_period_idx
  on public.meal_plan_availability(tenant_id, starts_on, ends_on);

create table public.meal_plan_meals (
  id uuid primary key default gen_random_uuid(),
  meal_plan_id uuid not null,
  tenant_id uuid not null,
  meal_type text not null check (length(btrim(meal_type)) between 1 and 80),
  custom_meal_type text,
  has_time_range boolean not null default false,
  starts_at time,
  ends_at time,
  dish_name text not null check (length(btrim(dish_name)) between 1 and 240),
  dish_details text,
  has_nutrition boolean not null default false,
  portion_grams numeric(8,2) check (portion_grams is null or portion_grams > 0),
  energy_kcal numeric(8,2) check (energy_kcal is null or energy_kcal >= 0),
  protein_g numeric(8,2) check (protein_g is null or protein_g >= 0),
  carbohydrate_g numeric(8,2) check (carbohydrate_g is null or carbohydrate_g >= 0),
  fat_g numeric(8,2) check (fat_g is null or fat_g >= 0),
  restrictions jsonb not null default '[]'::jsonb,
  image_meta jsonb not null default '{}'::jsonb,
  image_alt text,
  weekdays smallint[] not null default '{}',
  specific_dates date[] not null default '{}',
  alternative_group text,
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meal_plan_meals_plan_fk
    foreign key (meal_plan_id, tenant_id)
    references public.meal_plans(id, tenant_id) on delete cascade,
  constraint meal_plan_meals_type_check check (
    meal_type <> 'other' or length(btrim(custom_meal_type)) between 1 and 80
  ),
  constraint meal_plan_meals_time_check check (
    (has_time_range = false and starts_at is null and ends_at is null)
    or (has_time_range = true and starts_at is not null and ends_at is not null and ends_at > starts_at)
  ),
  constraint meal_plan_meals_nutrition_check check (
    has_nutrition = true
    or (portion_grams is null and energy_kcal is null and protein_g is null and carbohydrate_g is null and fat_g is null)
  ),
  constraint meal_plan_meals_weekdays_check check (
    weekdays <@ array[1,2,3,4,5,6,7]::smallint[]
  ),
  constraint meal_plan_meals_schedule_check check (
    cardinality(weekdays) > 0 or cardinality(specific_dates) > 0
  )
);

create unique index meal_plan_meals_id_tenant_uidx
  on public.meal_plan_meals(id, tenant_id);
create index meal_plan_meals_plan_order_idx
  on public.meal_plan_meals(meal_plan_id, sort_order);

create table public.meal_plan_meal_items (
  id uuid primary key default gen_random_uuid(),
  meal_id uuid not null,
  tenant_id uuid not null,
  item_name text not null check (length(btrim(item_name)) between 1 and 240),
  details text,
  portion_grams numeric(8,2) check (portion_grams is null or portion_grams > 0),
  energy_kcal numeric(8,2) check (energy_kcal is null or energy_kcal >= 0),
  protein_g numeric(8,2) check (protein_g is null or protein_g >= 0),
  carbohydrate_g numeric(8,2) check (carbohydrate_g is null or carbohydrate_g >= 0),
  fat_g numeric(8,2) check (fat_g is null or fat_g >= 0),
  restrictions jsonb not null default '[]'::jsonb,
  image_meta jsonb not null default '{}'::jsonb,
  image_alt text,
  alternative_group text,
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  constraint meal_plan_meal_items_meal_fk
    foreign key (meal_id, tenant_id)
    references public.meal_plan_meals(id, tenant_id) on delete cascade
);

create index meal_plan_meal_items_order_idx
  on public.meal_plan_meal_items(meal_id, sort_order);

create table public.meal_plan_audience_snapshots (
  meal_plan_id uuid not null,
  tenant_id uuid not null,
  occurrence_date date not null,
  person_id uuid not null references public.people(id) on delete restrict,
  audience_segment text not null check (audience_segment in ('students', 'staff')),
  resolution jsonb not null,
  resolved_at timestamptz not null default now(),
  primary key (meal_plan_id, occurrence_date, person_id),
  constraint meal_plan_audience_snapshots_plan_fk
    foreign key (meal_plan_id, tenant_id)
    references public.meal_plans(id, tenant_id) on delete cascade
);

create index meal_plan_audience_snapshots_person_idx
  on public.meal_plan_audience_snapshots(tenant_id, person_id, occurrence_date);

create or replace function app_private.meal_plan_validate_target()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, app_private
as $function$
declare
  plan_record public.meal_plans;
  valid_target boolean := false;
begin
  select * into plan_record
  from public.meal_plans plan
  where plan.id = new.meal_plan_id and plan.tenant_id = new.tenant_id;

  if not found then
    raise foreign_key_violation using message = 'meal plan tenant mismatch';
  end if;

  if new.institution_id is distinct from plan_record.institution_id then
    raise check_violation using message = 'target institution does not match meal plan';
  end if;

  if tg_table_name = 'meal_plan_scopes' then
    if new.scope_level = 'global' then
      valid_target := true;
    elsif new.scope_level = 'institution' then
      valid_target := new.institution_id = plan_record.institution_id;
    elsif new.scope_level = 'unit' then
      select exists (
        select 1 from public.units unit_record
        where unit_record.id = new.unit_id
          and unit_record.institution_id = plan_record.institution_id
      ) into valid_target;
    elsif new.scope_level = 'classLevel' then
      select exists (
        select 1 from public.groups group_record
        where group_record.id = new.class_id
          and group_record.institution_id = plan_record.institution_id
          and (new.unit_id is null or group_record.unit_id = new.unit_id)
      ) into valid_target;
    elsif new.scope_level = 'activity' then
      select exists (
        select 1 from public.activity_definitions activity
        where activity.id = new.activity_id
          and activity.institution_id = plan_record.institution_id
      ) into valid_target;
    elsif new.scope_level = 'person' then
      select exists (
        select 1 from public.child_contexts child_context
        where child_context.child_person_id = new.person_id
          and child_context.institution_id = plan_record.institution_id
          and child_context.status = 'active'
        union all
        select 1 from public.institution_memberships membership
        where membership.person_id = new.person_id
          and membership.institution_id = plan_record.institution_id
          and membership.status = 'active'
          and membership.revoked_at is null
      ) into valid_target;
    end if;
  else
    if new.target_kind = 'institution' then
      valid_target := new.target_id = plan_record.institution_id;
    elsif new.target_kind = 'unit' then
      select exists (
        select 1 from public.units unit_record
        where unit_record.id = new.target_id
          and unit_record.institution_id = plan_record.institution_id
      ) into valid_target;
    elsif new.target_kind = 'classLevel' then
      select exists (
        select 1 from public.groups group_record
        where group_record.id = new.target_id
          and group_record.institution_id = plan_record.institution_id
      ) into valid_target;
    elsif new.target_kind = 'activity' then
      select exists (
        select 1 from public.activity_definitions activity
        where activity.id = new.target_id
          and activity.institution_id = plan_record.institution_id
      ) into valid_target;
    elsif new.target_kind = 'person' then
      if new.audience_segment = 'students' then
        select exists (
          select 1 from public.child_contexts child_context
          where child_context.child_person_id = new.target_id
            and child_context.institution_id = plan_record.institution_id
            and child_context.status = 'active'
        ) into valid_target;
      elsif new.audience_segment = 'staff' then
        select exists (
          select 1
          from public.institution_memberships membership
          join public.people person_record on person_record.id = membership.person_id
          where membership.person_id = new.target_id
            and membership.institution_id = plan_record.institution_id
            and membership.status = 'active'
            and membership.revoked_at is null
            and person_record.person_type = 'adult'
            and lower(membership.role_code) not in ('guardian', 'responsible', 'parent', 'family')
        ) into valid_target;
      else
        select exists (
          select 1 from public.child_contexts child_context
          where child_context.child_person_id = new.target_id
            and child_context.institution_id = plan_record.institution_id
            and child_context.status = 'active'
          union all
          select 1
          from public.institution_memberships membership
          join public.people person_record on person_record.id = membership.person_id
          where membership.person_id = new.target_id
            and membership.institution_id = plan_record.institution_id
            and membership.status = 'active'
            and membership.revoked_at is null
            and person_record.person_type = 'adult'
            and lower(membership.role_code) not in ('guardian', 'responsible', 'parent', 'family')
        ) into valid_target;
      end if;
    end if;
  end if;

  if not valid_target then
    raise check_violation using message = 'meal plan target is outside the authorized hierarchy or is not eligible';
  end if;
  return new;
end;
$function$;

create trigger meal_plan_scopes_validate_target
before insert or update on public.meal_plan_scopes
for each row execute function app_private.meal_plan_validate_target();

create trigger meal_plan_audiences_validate_target
before insert or update on public.meal_plan_audiences
for each row execute function app_private.meal_plan_validate_target();

do $rls$
declare
  target_table text;
begin
  foreach target_table in array array[
    'meal_plan_templates',
    'meal_plan_template_versions',
    'meal_plan_template_links',
    'meal_plan_scopes',
    'meal_plan_audiences',
    'meal_plan_availability',
    'meal_plan_meals',
    'meal_plan_meal_items',
    'meal_plan_audience_snapshots'
  ] loop
    execute format('alter table public.%I enable row level security', target_table);
    execute format('alter table public.%I force row level security', target_table);
  end loop;
end
$rls$;

create policy meal_plan_templates_read on public.meal_plan_templates
for select to authenticated using (
  app_private.has_platform_permission('meal_plans.read')
  and app_private.meal_plan_scope_allowed(tenant_id, institution_id)
);

create policy meal_plan_template_versions_read on public.meal_plan_template_versions
for select to authenticated using (
  app_private.has_platform_permission('meal_plans.read')
  and exists (
    select 1 from public.meal_plan_templates template
    where template.id = meal_plan_template_versions.template_id
      and template.tenant_id = meal_plan_template_versions.tenant_id
      and app_private.meal_plan_scope_allowed(template.tenant_id, template.institution_id)
  )
);

create policy meal_plan_template_links_read on public.meal_plan_template_links
for select to authenticated using (
  app_private.has_platform_permission('meal_plans.read')
  and exists (
    select 1 from public.meal_plans plan
    where plan.id = meal_plan_template_links.meal_plan_id
      and plan.tenant_id = meal_plan_template_links.tenant_id
      and app_private.meal_plan_scope_allowed(plan.tenant_id, plan.institution_id)
  )
);

create policy meal_plan_scopes_read on public.meal_plan_scopes
for select to authenticated using (
  app_private.has_platform_permission('meal_plans.read')
  and exists (
    select 1 from public.meal_plans plan
    where plan.id = meal_plan_scopes.meal_plan_id
      and plan.tenant_id = meal_plan_scopes.tenant_id
      and app_private.meal_plan_scope_allowed(plan.tenant_id, plan.institution_id)
  )
);

create policy meal_plan_audiences_read on public.meal_plan_audiences
for select to authenticated using (
  app_private.has_platform_permission('meal_plans.read')
  and exists (
    select 1 from public.meal_plans plan
    where plan.id = meal_plan_audiences.meal_plan_id
      and plan.tenant_id = meal_plan_audiences.tenant_id
      and app_private.meal_plan_scope_allowed(plan.tenant_id, plan.institution_id)
  )
);

create policy meal_plan_availability_read on public.meal_plan_availability
for select to authenticated using (
  app_private.has_platform_permission('meal_plans.read')
  and exists (
    select 1 from public.meal_plans plan
    where plan.id = meal_plan_availability.meal_plan_id
      and plan.tenant_id = meal_plan_availability.tenant_id
      and app_private.meal_plan_scope_allowed(plan.tenant_id, plan.institution_id)
  )
);

create policy meal_plan_meals_read on public.meal_plan_meals
for select to authenticated using (
  app_private.has_platform_permission('meal_plans.read')
  and exists (
    select 1 from public.meal_plans plan
    where plan.id = meal_plan_meals.meal_plan_id
      and plan.tenant_id = meal_plan_meals.tenant_id
      and app_private.meal_plan_scope_allowed(plan.tenant_id, plan.institution_id)
  )
);

create policy meal_plan_meal_items_read on public.meal_plan_meal_items
for select to authenticated using (
  app_private.has_platform_permission('meal_plans.read')
  and exists (
    select 1
    from public.meal_plan_meals meal
    join public.meal_plans plan
      on plan.id = meal.meal_plan_id and plan.tenant_id = meal.tenant_id
    where meal.id = meal_plan_meal_items.meal_id
      and meal.tenant_id = meal_plan_meal_items.tenant_id
      and app_private.meal_plan_scope_allowed(plan.tenant_id, plan.institution_id)
  )
);

create policy meal_plan_audience_snapshots_read on public.meal_plan_audience_snapshots
for select to authenticated using (
  app_private.has_platform_permission('meal_plans.read')
  and exists (
    select 1 from public.meal_plans plan
    where plan.id = meal_plan_audience_snapshots.meal_plan_id
      and plan.tenant_id = meal_plan_audience_snapshots.tenant_id
      and app_private.meal_plan_scope_allowed(plan.tenant_id, plan.institution_id)
  )
);

revoke all on table public.meal_plan_templates from public, anon, authenticated;
revoke all on table public.meal_plan_template_versions from public, anon, authenticated;
revoke all on table public.meal_plan_template_links from public, anon, authenticated;
revoke all on table public.meal_plan_scopes from public, anon, authenticated;
revoke all on table public.meal_plan_audiences from public, anon, authenticated;
revoke all on table public.meal_plan_availability from public, anon, authenticated;
revoke all on table public.meal_plan_meals from public, anon, authenticated;
revoke all on table public.meal_plan_meal_items from public, anon, authenticated;
revoke all on table public.meal_plan_audience_snapshots from public, anon, authenticated;

grant select on table public.meal_plan_templates to authenticated;
grant select on table public.meal_plan_template_versions to authenticated;
grant select on table public.meal_plan_template_links to authenticated;
grant select on table public.meal_plan_scopes to authenticated;
grant select on table public.meal_plan_audiences to authenticated;
grant select on table public.meal_plan_availability to authenticated;
grant select on table public.meal_plan_meals to authenticated;
grant select on table public.meal_plan_meal_items to authenticated;
grant select on table public.meal_plan_audience_snapshots to authenticated;

create or replace function public.meal_plan_json(plan public.meal_plans)
returns jsonb
language sql
stable
security invoker
set search_path = pg_catalog, public
as $function$
  select jsonb_build_object(
    'id', ($1).id,
    'tenantId', ($1).tenant_id,
    'institutionId', ($1).institution_id,
    'unitId', ($1).unit_id,
    'classId', ($1).class_id,
    'personId', ($1).person_id,
    'name', ($1).name,
    'status', ($1).status,
    'sourceType', ($1).source_type,
    'scopeLevel', ($1).scope_level,
    'scopeId', nullif(($1).scope_id, ''),
    'startDate', ($1).start_date,
    'endDate', ($1).end_date,
    'recurrence', ($1).recurrence,
    'excludedDates', ($1).excluded_dates,
    'exceptions', ($1).exceptions,
    'menu', ($1).menu,
    'allergens', ($1).allergens,
    'alerts', ($1).alerts,
    'attachments', ($1).attachments_meta,
    'priority', ($1).priority,
    'conflictState', ($1).conflict_state,
    'revision', ($1).revision,
    'isDraft', ($1).is_draft,
    'requiresReview', ($1).requires_review,
    'planVariant', ($1).plan_variant,
    'audienceSegment', ($1).audience_segment,
    'visibilityMode', ($1).visibility_mode,
    'visibleFrom', ($1).visible_from,
    'sourceTemplateId', ($1).source_template_id,
    'sourceTemplateVersion', ($1).source_template_version,
    'scopeRules', ($1).scope_rules,
    'simpleImageMeta', ($1).simple_image_meta,
    'simpleImageAlt', ($1).simple_image_alt,
    'simpleNotes', ($1).simple_notes,
    'createdBy', ($1).created_by,
    'updatedBy', ($1).updated_by,
    'createdAt', ($1).created_at,
    'updatedAt', ($1).updated_at
  );
$function$;

create or replace function public.meal_plan_template_list(p_query jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app_private
as $function$
declare
  search_text text := btrim(coalesce(p_query ->> 'search', ''));
  page_number integer := greatest(coalesce((p_query ->> 'page')::integer, 0), 0);
  page_size integer := least(greatest(coalesce((p_query ->> 'pageSize')::integer, 12), 1), 100);
  total_count bigint;
  result_items jsonb;
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.read') then
    raise insufficient_privilege using message = 'meal plans read permission required';
  end if;

  select count(*) into total_count
  from public.meal_plan_templates template
  where app_private.meal_plan_scope_allowed(template.tenant_id, template.institution_id)
    and (search_text = '' or template.name ilike '%' || search_text || '%')
    and (nullif(p_query ->> 'institutionId', '') is null or template.institution_id = (p_query ->> 'institutionId')::uuid)
    and (nullif(p_query ->> 'status', '') is null or template.status = p_query ->> 'status')
    and (nullif(p_query ->> 'planVariant', '') is null or template.plan_variant = p_query ->> 'planVariant')
    and (nullif(p_query ->> 'audienceSegment', '') is null or template.audience_segment = p_query ->> 'audienceSegment');

  select coalesce(jsonb_agg(row_payload order by updated_at desc), '[]'::jsonb)
  into result_items
  from (
    select jsonb_build_object(
      'id', template.id,
      'tenantId', template.tenant_id,
      'institutionId', template.institution_id,
      'name', template.name,
      'description', template.description,
      'planVariant', template.plan_variant,
      'audienceSegment', template.audience_segment,
      'status', template.status,
      'version', template.current_version,
      'payload', template.payload,
      'sourceMealPlanId', template.source_meal_plan_id,
      'createdBy', template.created_by,
      'updatedBy', template.updated_by,
      'publishedAt', template.published_at,
      'createdAt', template.created_at,
      'updatedAt', template.updated_at
    ) as row_payload, template.updated_at
    from public.meal_plan_templates template
    where app_private.meal_plan_scope_allowed(template.tenant_id, template.institution_id)
      and (search_text = '' or template.name ilike '%' || search_text || '%')
      and (nullif(p_query ->> 'institutionId', '') is null or template.institution_id = (p_query ->> 'institutionId')::uuid)
      and (nullif(p_query ->> 'status', '') is null or template.status = p_query ->> 'status')
      and (nullif(p_query ->> 'planVariant', '') is null or template.plan_variant = p_query ->> 'planVariant')
      and (nullif(p_query ->> 'audienceSegment', '') is null or template.audience_segment = p_query ->> 'audienceSegment')
    order by template.updated_at desc
    offset page_number * page_size limit page_size
  ) page_rows;

  return jsonb_build_object(
    'items', result_items,
    'total', total_count,
    'limit', page_size,
    'offset', page_number * page_size
  );
end;
$function$;

create or replace function public.meal_plan_template_get(p_template_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app_private
as $function$
declare
  template public.meal_plan_templates;
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.read') then
    raise insufficient_privilege using message = 'meal plans read permission required';
  end if;

  select candidate.* into template
  from public.meal_plan_templates candidate
  where candidate.id = p_template_id
    and app_private.meal_plan_scope_allowed(candidate.tenant_id, candidate.institution_id);
  if not found then
    raise no_data_found using message = 'meal plan template not found';
  end if;

  return jsonb_build_object(
    'id', template.id,
    'tenantId', template.tenant_id,
    'institutionId', template.institution_id,
    'name', template.name,
    'description', template.description,
    'planVariant', template.plan_variant,
    'audienceSegment', template.audience_segment,
    'status', template.status,
    'version', template.current_version,
    'payload', template.payload,
    'sourceMealPlanId', template.source_meal_plan_id,
    'createdBy', template.created_by,
    'updatedBy', template.updated_by,
    'publishedAt', template.published_at,
    'createdAt', template.created_at,
    'updatedAt', template.updated_at,
    'versions', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'version', version_record.version,
        'changeSummary', version_record.change_summary,
        'createdBy', version_record.created_by,
        'createdAt', version_record.created_at
      ) order by version_record.version desc), '[]'::jsonb)
      from public.meal_plan_template_versions version_record
      where version_record.template_id = template.id
        and version_record.tenant_id = template.tenant_id
    )
  );
end;
$function$;

create or replace function public.meal_plan_template_save(
  p_template_id uuid,
  p_payload jsonb,
  p_expected_version integer default 0,
  p_publish boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app_private
as $function$
declare
  actor_id uuid := app_private.current_person_id();
  requested_institution_id uuid := nullif(p_payload ->> 'institutionId', '')::uuid;
  requested_tenant_id uuid := coalesce(requested_institution_id, nullif(p_payload ->> 'tenantId', '')::uuid);
  template public.meal_plan_templates;
  next_version integer;
  template_name text := btrim(coalesce(p_payload ->> 'name', ''));
  template_variant text := coalesce(p_payload ->> 'planVariant', 'simple');
  template_audience text := coalesce(p_payload ->> 'audienceSegment', 'students');
begin
  if auth.uid() is null or actor_id is null or not app_private.has_platform_permission('meal_plans.manage') then
    raise insufficient_privilege using message = 'meal plans manage permission required';
  end if;
  if requested_tenant_id is null or template_name = '' then
    raise invalid_parameter_value using message = 'template tenant and name are required';
  end if;
  if template_variant not in ('simple', 'complete') or template_audience not in ('students', 'staff', 'all') then
    raise invalid_parameter_value using message = 'invalid template variant or audience';
  end if;
  if not app_private.meal_plan_scope_allowed(requested_tenant_id, requested_institution_id) then
    raise insufficient_privilege using message = 'template scope is not allowed';
  end if;

  if p_template_id is null then
    insert into public.meal_plan_templates(
      tenant_id, institution_id, name, description, plan_variant, audience_segment,
      status, current_version, payload, source_meal_plan_id, created_by, updated_by,
      published_at
    ) values (
      requested_tenant_id, requested_institution_id, template_name, nullif(p_payload ->> 'description', ''),
      template_variant, template_audience, case when p_publish then 'published' else 'draft' end,
      1, p_payload, nullif(p_payload ->> 'sourceMealPlanId', '')::uuid, actor_id, actor_id,
      case when p_publish then now() else null end
    ) returning * into template;
    next_version := 1;
  else
    select candidate.* into template
    from public.meal_plan_templates candidate
    where candidate.id = p_template_id
      and app_private.meal_plan_scope_allowed(candidate.tenant_id, candidate.institution_id)
    for update;
    if not found then
      raise no_data_found using message = 'meal plan template not found';
    end if;
    if template.current_version <> p_expected_version then
      raise exception 'meal plan template version conflict' using errcode = 'P0003';
    end if;
    if template.tenant_id <> requested_tenant_id then
      raise insufficient_privilege using message = 'template tenant cannot be changed';
    end if;
    next_version := template.current_version + 1;
    update public.meal_plan_templates set
      institution_id = requested_institution_id,
      name = template_name,
      description = nullif(p_payload ->> 'description', ''),
      plan_variant = template_variant,
      audience_segment = template_audience,
      status = case when p_publish then 'published' else 'draft' end,
      current_version = next_version,
      payload = p_payload,
      updated_by = actor_id,
      published_at = case when p_publish then coalesce(published_at, now()) else null end,
      archived_at = null,
      updated_at = now()
    where id = template.id
    returning * into template;
  end if;

  insert into public.meal_plan_template_versions(
    template_id, tenant_id, version, name, plan_variant, audience_segment,
    payload, change_summary, created_by
  ) values (
    template.id, template.tenant_id, next_version, template.name, template.plan_variant,
    template.audience_segment, template.payload, nullif(p_payload ->> 'changeSummary', ''), actor_id
  );

  return public.meal_plan_template_get(template.id);
end;
$function$;

create or replace function public.meal_plan_audience_options(p_query jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app_private
as $function$
declare
  search_text text := btrim(coalesce(p_query ->> 'search', ''));
  requested_institution uuid := nullif(p_query ->> 'institutionId', '')::uuid;
  requested_unit uuid := nullif(p_query ->> 'unitId', '')::uuid;
  requested_class uuid := nullif(p_query ->> 'classId', '')::uuid;
  result_limit integer := least(greatest(coalesce((p_query ->> 'limit')::integer, 100), 1), 300);
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.read') then
    raise insufficient_privilege using message = 'meal plans read permission required';
  end if;
  if requested_institution is not null
    and not app_private.meal_plan_scope_allowed(requested_institution, requested_institution) then
    raise insufficient_privilege using message = 'institution scope is not allowed';
  end if;

  return jsonb_build_object(
    'institutions', (
      select coalesce(jsonb_agg(jsonb_build_object('id', institution.id, 'label', institution.public_name) order by institution.public_name), '[]'::jsonb)
      from public.institutions institution
      where app_private.meal_plan_scope_allowed(institution.id, institution.id)
        and (requested_institution is null or institution.id = requested_institution)
        and (search_text = '' or institution.public_name ilike '%' || search_text || '%')
    ),
    'units', (
      select coalesce(jsonb_agg(jsonb_build_object('id', unit_record.id, 'institutionId', unit_record.institution_id, 'label', unit_record.name) order by unit_record.name), '[]'::jsonb)
      from public.units unit_record
      where app_private.meal_plan_scope_allowed(unit_record.institution_id, unit_record.institution_id)
        and (requested_institution is null or unit_record.institution_id = requested_institution)
        and (requested_unit is null or unit_record.id = requested_unit)
        and (search_text = '' or unit_record.name ilike '%' || search_text || '%')
    ),
    'classes', (
      select coalesce(jsonb_agg(jsonb_build_object('id', group_record.id, 'institutionId', group_record.institution_id, 'unitId', group_record.unit_id, 'label', group_record.name) order by group_record.name), '[]'::jsonb)
      from public.groups group_record
      where app_private.meal_plan_scope_allowed(group_record.institution_id, group_record.institution_id)
        and (requested_institution is null or group_record.institution_id = requested_institution)
        and (requested_unit is null or group_record.unit_id = requested_unit)
        and (requested_class is null or group_record.id = requested_class)
        and (search_text = '' or group_record.name ilike '%' || search_text || '%')
    ),
    'activities', (
      select coalesce(jsonb_agg(jsonb_build_object('id', activity.id, 'institutionId', activity.institution_id, 'label', activity.name) order by activity.name), '[]'::jsonb)
      from public.activity_definitions activity
      where app_private.meal_plan_scope_allowed(activity.institution_id, activity.institution_id)
        and (requested_institution is null or activity.institution_id = requested_institution)
        and (search_text = '' or activity.name ilike '%' || search_text || '%')
    ),
    'people', (
      with eligible_people as (
        select distinct person_record.id, child_context.institution_id,
          person_record.display_name as label, 'students'::text as segment
        from public.child_contexts child_context
        join public.people person_record on person_record.id = child_context.child_person_id
        left join public.child_unit_links unit_link
          on unit_link.child_context_id = child_context.id
          and unit_link.status = 'active' and unit_link.revoked_at is null
        left join public.child_group_links group_link
          on group_link.child_unit_link_id = unit_link.id
          and group_link.status = 'active'
          and (group_link.starts_at is null or group_link.starts_at <= now())
          and (group_link.ends_at is null or group_link.ends_at > now())
        where child_context.status = 'active'
          and app_private.meal_plan_scope_allowed(child_context.institution_id, child_context.institution_id)
          and (requested_institution is null or child_context.institution_id = requested_institution)
          and (requested_unit is null or unit_link.unit_id = requested_unit)
          and (requested_class is null or group_link.group_id = requested_class)
        union
        select distinct person_record.id, membership.institution_id,
          person_record.display_name as label, 'staff'::text as segment
        from public.institution_memberships membership
        join public.people person_record on person_record.id = membership.person_id
        where membership.status = 'active' and membership.revoked_at is null
          and person_record.person_type = 'adult'
          and lower(membership.role_code) not in ('guardian', 'responsible', 'parent', 'family')
          and app_private.meal_plan_scope_allowed(membership.institution_id, membership.institution_id)
          and (requested_institution is null or membership.institution_id = requested_institution)
      )
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', person_option.id,
        'institutionId', person_option.institution_id,
        'label', person_option.label,
        'segment', person_option.segment
      ) order by person_option.label), '[]'::jsonb)
      from (
        select * from eligible_people
        where search_text = '' or label ilike '%' || search_text || '%'
        order by label limit result_limit
      ) person_option
    )
  );
end;
$function$;

create or replace function public.meal_plan_create_or_update_draft(
  p_request_id text,
  p_payload jsonb,
  p_meal_plan_id uuid default null,
  p_expected_revision integer default 0
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app_private
as $function$
declare
  actor_id uuid := app_private.current_person_id();
  plan public.meal_plans;
  requested_institution_id uuid := nullif(p_payload ->> 'institutionId', '')::uuid;
  requested_tenant_id uuid := coalesce(requested_institution_id, nullif(p_payload ->> 'tenantId', '')::uuid);
  start_date_value date := (p_payload ->> 'startDate')::date;
  end_date_value date := (p_payload ->> 'endDate')::date;
  visibility_value text := coalesce(p_payload ->> 'visibilityMode', 'immediate');
  visible_from_value timestamptz := nullif(p_payload ->> 'visibleFrom', '')::timestamptz;
  source_template uuid := nullif(p_payload ->> 'sourceTemplateId', '')::uuid;
  source_version integer := nullif(p_payload ->> 'sourceTemplateVersion', '')::integer;
  scope_rule jsonb;
  meal_rule jsonb;
  saved_template jsonb;
begin
  if auth.uid() is null or actor_id is null or not app_private.has_platform_permission('meal_plans.manage') then
    raise insufficient_privilege using message = 'meal plans manage permission required';
  end if;
  if requested_tenant_id is null or btrim(coalesce(p_payload ->> 'name', '')) = '' then
    raise invalid_parameter_value using message = 'meal plan tenant and name are required';
  end if;
  if start_date_value is null or end_date_value is null or end_date_value < start_date_value then
    raise invalid_parameter_value using message = 'invalid meal plan period';
  end if;
  if visibility_value not in ('immediate', 'scheduled')
    or (visibility_value = 'immediate' and visible_from_value is not null)
    or (visibility_value = 'scheduled' and visible_from_value is null) then
    raise invalid_parameter_value using message = 'invalid visibility schedule';
  end if;
  if not app_private.meal_plan_scope_allowed(requested_tenant_id, requested_institution_id) then
    raise insufficient_privilege using message = 'meal plan scope is not allowed';
  end if;
  if source_template is not null and not exists (
    select 1 from public.meal_plan_template_versions version_record
    join public.meal_plan_templates template
      on template.id = version_record.template_id and template.tenant_id = version_record.tenant_id
    where version_record.template_id = source_template
      and version_record.tenant_id = requested_tenant_id
      and version_record.version = source_version
      and template.status = 'published'
      and app_private.meal_plan_scope_allowed(template.tenant_id, template.institution_id)
  ) then
    raise invalid_parameter_value using message = 'source template version is not available';
  end if;

  if p_meal_plan_id is null then
    insert into public.meal_plans(
      tenant_id, institution_id, unit_id, class_id, person_id, name, source_type,
      scope_level, scope_id, start_date, end_date, recurrence, excluded_dates,
      exceptions, menu, allergens, alerts, attachments_meta, priority,
      status, conflict_state, revision, is_draft, requires_review,
      plan_variant, audience_segment, visibility_mode, visible_from,
      source_template_id, source_template_version, scope_rules,
      simple_image_meta, simple_image_alt, simple_notes, created_by, updated_by
    ) values (
      requested_tenant_id, requested_institution_id, nullif(p_payload ->> 'unitId', '')::uuid,
      nullif(p_payload ->> 'classId', '')::uuid, nullif(p_payload ->> 'personId', '')::uuid,
      btrim(p_payload ->> 'name'), coalesce(p_payload ->> 'sourceType', 'institution'),
      coalesce(p_payload ->> 'scopeLevel', 'institution'), coalesce(p_payload ->> 'scopeId', requested_institution_id::text),
      start_date_value, end_date_value, coalesce(p_payload -> 'recurrence', '{}'::jsonb),
      coalesce(array(select jsonb_array_elements_text(coalesce(p_payload -> 'excludedDates', '[]'::jsonb))::date), '{}'),
      coalesce(p_payload -> 'exceptions', '[]'::jsonb), coalesce(p_payload -> 'menu', '[]'::jsonb),
      coalesce(p_payload -> 'allergens', '[]'::jsonb), coalesce(p_payload -> 'alerts', '[]'::jsonb),
      coalesce(p_payload -> 'attachments', '[]'::jsonb), coalesce((p_payload ->> 'priority')::integer, 0),
      'draft', false, 1, true, false,
      coalesce(p_payload ->> 'planVariant', 'simple'), coalesce(p_payload ->> 'audienceSegment', 'students'),
      visibility_value, visible_from_value, source_template, source_version,
      coalesce(p_payload -> 'scopeRules', '[]'::jsonb), coalesce(p_payload -> 'simpleImageMeta', '{}'::jsonb),
      nullif(p_payload ->> 'simpleImageAlt', ''), nullif(p_payload ->> 'simpleNotes', ''), actor_id, actor_id
    ) returning * into plan;
  else
    update public.meal_plans existing set
      institution_id = requested_institution_id,
      unit_id = nullif(p_payload ->> 'unitId', '')::uuid,
      class_id = nullif(p_payload ->> 'classId', '')::uuid,
      person_id = nullif(p_payload ->> 'personId', '')::uuid,
      name = btrim(p_payload ->> 'name'),
      source_type = coalesce(p_payload ->> 'sourceType', existing.source_type),
      scope_level = coalesce(p_payload ->> 'scopeLevel', existing.scope_level),
      scope_id = coalesce(p_payload ->> 'scopeId', existing.scope_id),
      start_date = start_date_value,
      end_date = end_date_value,
      recurrence = coalesce(p_payload -> 'recurrence', existing.recurrence),
      excluded_dates = coalesce(array(select jsonb_array_elements_text(coalesce(p_payload -> 'excludedDates', '[]'::jsonb))::date), '{}'),
      exceptions = coalesce(p_payload -> 'exceptions', existing.exceptions),
      menu = coalesce(p_payload -> 'menu', existing.menu),
      allergens = coalesce(p_payload -> 'allergens', existing.allergens),
      alerts = coalesce(p_payload -> 'alerts', existing.alerts),
      attachments_meta = coalesce(p_payload -> 'attachments', existing.attachments_meta),
      priority = coalesce((p_payload ->> 'priority')::integer, existing.priority),
      status = 'draft', conflict_state = false, is_draft = true, requires_review = false,
      revision = existing.revision + 1,
      plan_variant = coalesce(p_payload ->> 'planVariant', existing.plan_variant),
      audience_segment = coalesce(p_payload ->> 'audienceSegment', existing.audience_segment),
      visibility_mode = visibility_value, visible_from = visible_from_value,
      source_template_id = source_template, source_template_version = source_version,
      scope_rules = coalesce(p_payload -> 'scopeRules', existing.scope_rules),
      simple_image_meta = coalesce(p_payload -> 'simpleImageMeta', existing.simple_image_meta),
      simple_image_alt = nullif(p_payload ->> 'simpleImageAlt', ''),
      simple_notes = nullif(p_payload ->> 'simpleNotes', ''),
      updated_by = actor_id, updated_at = now()
    where existing.id = p_meal_plan_id
      and existing.tenant_id = requested_tenant_id
      and existing.revision = p_expected_revision
      and app_private.meal_plan_scope_allowed(existing.tenant_id, existing.institution_id)
    returning existing.* into plan;
    if not found then
      raise exception 'meal plan revision or scope conflict' using errcode = 'P0003';
    end if;
  end if;

  delete from public.meal_plan_scopes where meal_plan_id = plan.id and tenant_id = plan.tenant_id;
  for scope_rule in select value from jsonb_array_elements(coalesce(p_payload -> 'scopeRules', '[]'::jsonb)) loop
    insert into public.meal_plan_scopes(
      meal_plan_id, tenant_id, scope_level, scope_id, institution_id, unit_id,
      class_id, activity_id, person_id, priority
    ) values (
      plan.id, plan.tenant_id, scope_rule ->> 'scopeLevel', coalesce(scope_rule ->> 'scopeId', ''),
      nullif(scope_rule ->> 'institutionId', '')::uuid, nullif(scope_rule ->> 'unitId', '')::uuid,
      nullif(scope_rule ->> 'classId', '')::uuid, nullif(scope_rule ->> 'activityId', '')::uuid,
      nullif(scope_rule ->> 'personId', '')::uuid, coalesce((scope_rule ->> 'priority')::integer, plan.priority)
    );
  end loop;

  delete from public.meal_plan_audiences where meal_plan_id = plan.id and tenant_id = plan.tenant_id;
  for scope_rule in select value from jsonb_array_elements(coalesce(p_payload -> 'audienceRules', '[]'::jsonb)) loop
    insert into public.meal_plan_audiences(
      meal_plan_id, tenant_id, audience_segment, selection_mode, target_kind,
      target_id, institution_id, unit_id, class_id, activity_id, person_id,
      effective_from, effective_until, rule, label
    ) values (
      plan.id, plan.tenant_id, coalesce(scope_rule ->> 'audienceSegment', plan.audience_segment),
      coalesce(scope_rule ->> 'selectionMode', 'include'), scope_rule ->> 'targetKind',
      (scope_rule ->> 'targetId')::uuid, plan.institution_id,
      case when scope_rule ->> 'targetKind' = 'unit' then (scope_rule ->> 'targetId')::uuid end,
      case when scope_rule ->> 'targetKind' = 'classLevel' then (scope_rule ->> 'targetId')::uuid end,
      case when scope_rule ->> 'targetKind' = 'activity' then (scope_rule ->> 'targetId')::uuid end,
      case when scope_rule ->> 'targetKind' = 'person' then (scope_rule ->> 'targetId')::uuid end,
      nullif(scope_rule ->> 'effectiveFrom', '')::date, nullif(scope_rule ->> 'effectiveUntil', '')::date,
      coalesce(scope_rule -> 'rule', '{}'::jsonb), nullif(scope_rule ->> 'label', '')
    );
  end loop;

  insert into public.meal_plan_availability(
    meal_plan_id, tenant_id, visibility_mode, visible_from, starts_on, ends_on,
    recurrence, excluded_dates, exception_rules, timezone, updated_at
  ) values (
    plan.id, plan.tenant_id, plan.visibility_mode, plan.visible_from, plan.start_date, plan.end_date,
    plan.recurrence, plan.excluded_dates, plan.exceptions,
    coalesce(nullif(p_payload ->> 'timezone', ''), 'America/Sao_Paulo'), now()
  ) on conflict (meal_plan_id) do update set
    visibility_mode = excluded.visibility_mode, visible_from = excluded.visible_from,
    starts_on = excluded.starts_on, ends_on = excluded.ends_on,
    recurrence = excluded.recurrence, excluded_dates = excluded.excluded_dates,
    exception_rules = excluded.exception_rules, timezone = excluded.timezone, updated_at = now();

  delete from public.meal_plan_meals where meal_plan_id = plan.id and tenant_id = plan.tenant_id;
  for meal_rule in select value from jsonb_array_elements(coalesce(p_payload -> 'menu', '[]'::jsonb)) loop
    insert into public.meal_plan_meals(
      meal_plan_id, tenant_id, meal_type, custom_meal_type, has_time_range,
      starts_at, ends_at, dish_name, dish_details, has_nutrition, portion_grams,
      energy_kcal, protein_g, carbohydrate_g, fat_g, restrictions, image_meta,
      image_alt, weekdays, specific_dates, alternative_group, sort_order
    ) values (
      plan.id, plan.tenant_id, coalesce(meal_rule ->> 'mealType', 'other'),
      nullif(meal_rule ->> 'customMealType', ''), coalesce((meal_rule ->> 'hasTimeRange')::boolean, false),
      nullif(meal_rule ->> 'startsAt', '')::time, nullif(meal_rule ->> 'endsAt', '')::time,
      btrim(coalesce(meal_rule ->> 'dishName', meal_rule ->> 'name', '')),
      nullif(meal_rule ->> 'dishDetails', ''), coalesce((meal_rule ->> 'hasNutrition')::boolean, false),
      nullif(meal_rule ->> 'portionGrams', '')::numeric, nullif(meal_rule ->> 'energyKcal', '')::numeric,
      nullif(meal_rule ->> 'proteinG', '')::numeric, nullif(meal_rule ->> 'carbohydrateG', '')::numeric,
      nullif(meal_rule ->> 'fatG', '')::numeric, coalesce(meal_rule -> 'restrictions', '[]'::jsonb),
      coalesce(meal_rule -> 'imageMeta', '{}'::jsonb), nullif(meal_rule ->> 'imageAlt', ''),
      coalesce(array(select jsonb_array_elements_text(coalesce(meal_rule -> 'weekdays', '[]'::jsonb))::smallint), '{}'),
      coalesce(array(select jsonb_array_elements_text(coalesce(meal_rule -> 'specificDates', '[]'::jsonb))::date), '{}'),
      nullif(meal_rule ->> 'alternativeGroup', ''), coalesce((meal_rule ->> 'sortOrder')::integer, 0)
    );
  end loop;

  if source_template is not null then
    insert into public.meal_plan_template_links(
      meal_plan_id, tenant_id, template_id, template_version, created_by
    ) values (plan.id, plan.tenant_id, source_template, source_version, actor_id)
    on conflict (meal_plan_id) do update set
      template_id = excluded.template_id,
      template_version = excluded.template_version,
      created_by = excluded.created_by,
      created_at = now();
  else
    delete from public.meal_plan_template_links where meal_plan_id = plan.id;
  end if;

  if coalesce((p_payload ->> 'saveAsTemplate')::boolean, false) then
    saved_template := public.meal_plan_template_save(
      null,
      p_payload || jsonb_build_object(
        'name', coalesce(nullif(p_payload ->> 'templateName', ''), plan.name),
        'sourceMealPlanId', plan.id,
        'tenantId', plan.tenant_id,
        'institutionId', plan.institution_id
      ),
      0,
      false
    );
  end if;

  return public.meal_plan_json(plan) || jsonb_build_object('savedTemplate', saved_template);
end;
$function$;

create or replace function public.meal_plan_audience_resolve_occurrence(
  p_meal_plan_id uuid,
  p_occurrence_date date
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app_private
as $function$
declare
  plan public.meal_plans;
  inserted_count integer;
begin
  if auth.uid() is null or not app_private.has_platform_permission('meal_plans.manage') then
    raise insufficient_privilege using message = 'meal plans manage permission required';
  end if;
  select candidate.* into plan
  from public.meal_plans candidate
  where candidate.id = p_meal_plan_id
    and app_private.meal_plan_scope_allowed(candidate.tenant_id, candidate.institution_id)
  for update;
  if not found then raise no_data_found using message = 'meal plan not found'; end if;
  if p_occurrence_date < current_date then
    raise invalid_parameter_value using message = 'historical audience snapshots cannot be recalculated';
  end if;
  if p_occurrence_date < plan.start_date or p_occurrence_date > plan.end_date
    or p_occurrence_date = any(plan.excluded_dates) then
    raise invalid_parameter_value using message = 'occurrence is outside meal plan availability';
  end if;

  with eligible as (
    select distinct child_context.child_person_id as person_id, 'students'::text as segment,
      jsonb_build_object('kind', 'dynamic', 'source', 'child_context', 'resolvedFor', p_occurrence_date) as resolution
    from public.child_contexts child_context
    left join public.child_unit_links unit_link
      on unit_link.child_context_id = child_context.id
      and unit_link.status = 'active' and unit_link.revoked_at is null
    left join public.child_group_links group_link
      on group_link.child_unit_link_id = unit_link.id
      and group_link.status = 'active'
      and (group_link.starts_at is null or group_link.starts_at::date <= p_occurrence_date)
      and (group_link.ends_at is null or group_link.ends_at::date > p_occurrence_date)
    where plan.audience_segment in ('students', 'all')
      and child_context.institution_id = plan.institution_id
      and child_context.status = 'active'
      and (
        not exists (select 1 from public.meal_plan_scopes s where s.meal_plan_id = plan.id)
        or exists (
          select 1 from public.meal_plan_scopes s
          where s.meal_plan_id = plan.id and s.tenant_id = plan.tenant_id
            and (
              s.scope_level in ('global', 'institution')
              or (s.scope_level = 'unit' and s.unit_id = unit_link.unit_id)
              or (s.scope_level = 'classLevel' and s.class_id = group_link.group_id)
              or (s.scope_level = 'activity' and exists (
                select 1 from public.activity_group_links activity_link
                where activity_link.activity_id = s.activity_id
                  and activity_link.group_id = group_link.group_id
                  and activity_link.status = 'active'
                  and activity_link.starts_at::date <= p_occurrence_date
                  and (activity_link.ends_at is null or activity_link.ends_at::date > p_occurrence_date)
              ))
              or (s.scope_level = 'person' and s.person_id = child_context.child_person_id)
            )
        )
      )
    union
    select distinct membership.person_id, 'staff'::text,
      jsonb_build_object('kind', 'dynamic', 'source', 'institution_membership', 'resolvedFor', p_occurrence_date)
    from public.institution_memberships membership
    join public.people person_record on person_record.id = membership.person_id
    where plan.audience_segment in ('staff', 'all')
      and membership.institution_id = plan.institution_id
      and membership.status = 'active' and membership.revoked_at is null
      and person_record.person_type = 'adult'
      and lower(membership.role_code) not in ('guardian', 'responsible', 'parent', 'family')
      and (
        not exists (select 1 from public.meal_plan_scopes s where s.meal_plan_id = plan.id)
        or exists (
          select 1 from public.meal_plan_scopes s
          where s.meal_plan_id = plan.id and s.tenant_id = plan.tenant_id
            and (s.scope_level in ('global', 'institution') or (s.scope_level = 'person' and s.person_id = membership.person_id))
        )
      )
  ), explicit_includes as (
    select audience.person_id, case
      when exists (
        select 1 from public.child_contexts child_context
        where child_context.child_person_id = audience.person_id
          and child_context.institution_id = plan.institution_id
          and child_context.status = 'active'
      ) then 'students' else 'staff' end as segment,
      jsonb_build_object('kind', 'explicit_include', 'ruleId', audience.id, 'resolvedFor', p_occurrence_date) as resolution
    from public.meal_plan_audiences audience
    where audience.meal_plan_id = plan.id and audience.tenant_id = plan.tenant_id
      and audience.selection_mode = 'include' and audience.target_kind = 'person'
      and (audience.effective_from is null or audience.effective_from <= p_occurrence_date)
      and (audience.effective_until is null or audience.effective_until >= p_occurrence_date)
  ), combined as (
    select * from eligible union select * from explicit_includes
  ), allowed as (
    select combined.* from combined
    where not exists (
      select 1 from public.meal_plan_audiences exclusion
      where exclusion.meal_plan_id = plan.id and exclusion.tenant_id = plan.tenant_id
        and exclusion.selection_mode = 'exclude' and exclusion.target_kind = 'person'
        and exclusion.person_id = combined.person_id
        and (exclusion.effective_from is null or exclusion.effective_from <= p_occurrence_date)
        and (exclusion.effective_until is null or exclusion.effective_until >= p_occurrence_date)
    )
  )
  insert into public.meal_plan_audience_snapshots(
    meal_plan_id, tenant_id, occurrence_date, person_id, audience_segment, resolution
  )
  select plan.id, plan.tenant_id, p_occurrence_date, allowed.person_id, allowed.segment, allowed.resolution
  from allowed
  on conflict (meal_plan_id, occurrence_date, person_id) do nothing;

  get diagnostics inserted_count = row_count;
  return jsonb_build_object(
    'mealPlanId', plan.id,
    'occurrenceDate', p_occurrence_date,
    'inserted', inserted_count,
    'total', (
      select count(*) from public.meal_plan_audience_snapshots snapshot
      where snapshot.meal_plan_id = plan.id and snapshot.occurrence_date = p_occurrence_date
    )
  );
end;
$function$;

do $privileges$
declare
  signature text;
begin
  foreach signature in array array[
    'public.meal_plan_json(public.meal_plans)',
    'public.meal_plan_list(jsonb)',
    'public.meal_plan_get(uuid)',
    'public.meal_plan_create_or_update_draft(text,jsonb,uuid,integer)',
    'public.meal_plan_effective_snapshot(jsonb)',
    'public.meal_plan_conflicts_check(text,text,date,date,jsonb,jsonb)',
    'public.meal_plan_submit_for_review(text,uuid,integer)',
    'public.meal_plan_publish(text,uuid,integer)',
    'public.meal_plan_template_list(jsonb)',
    'public.meal_plan_template_get(uuid)',
    'public.meal_plan_template_save(uuid,jsonb,integer,boolean)',
    'public.meal_plan_audience_options(jsonb)',
    'public.meal_plan_audience_resolve_occurrence(uuid,date)'
  ] loop
    if to_regprocedure(signature) is not null then
      execute format('revoke execute on function %s from public, anon', signature);
      execute format('grant execute on function %s to authenticated', signature);
    end if;
  end loop;
end
$privileges$;

revoke execute on function app_private.meal_plan_validate_target() from public, anon, authenticated;

commit;
