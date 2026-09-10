-- Shared Forms definition graph and exact capability catalog.
-- Access is RPC-only; public tables are deny-by-default and force RLS.

create table public.forms (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete restrict,
  kind text not null,
  status text not null default 'draft',
  identity_mode text not null,
  response_unit text not null,
  title text not null,
  description text,
  working_version_id uuid,
  published_version_id uuid,
  first_published_at timestamptz,
  management_version bigint not null default 1,
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  updated_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint forms_kind_ck check (kind in ('form', 'quick_poll')),
  constraint forms_status_ck check (status in ('draft', 'published', 'archived')),
  constraint forms_identity_mode_ck check (identity_mode in ('identified', 'anonymous')),
  constraint forms_response_unit_ck check (response_unit in ('person', 'child_family_context')),
  constraint forms_title_ck check (char_length(btrim(title)) between 1 and 200),
  constraint forms_description_ck check (description is null or char_length(description) <= 4000),
  constraint forms_management_version_ck check (management_version > 0),
  constraint forms_publication_state_ck check (
    (first_published_at is null and published_version_id is null)
    or (first_published_at is not null and published_version_id is not null)
  )
);

create table public.form_versions (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references public.forms(id) on delete cascade,
  version_number integer not null,
  state text not null default 'working',
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  published_at timestamptz,
  constraint form_versions_number_ck check (version_number > 0),
  constraint form_versions_state_ck check (state in ('working', 'published', 'superseded')),
  constraint form_versions_published_ck check (
    (state = 'working' and published_at is null)
    or (state in ('published', 'superseded') and published_at is not null)
  )
);

alter table public.forms
  add constraint forms_working_version_fk foreign key (working_version_id)
    references public.form_versions(id) on delete restrict,
  add constraint forms_published_version_fk foreign key (published_version_id)
    references public.form_versions(id) on delete restrict;

create table public.form_sections (
  id uuid primary key default gen_random_uuid(),
  form_version_id uuid not null references public.form_versions(id) on delete cascade,
  title text not null,
  description text,
  position integer not null,
  constraint form_sections_title_ck check (char_length(btrim(title)) between 1 and 200),
  constraint form_sections_description_ck check (description is null or char_length(description) <= 2000),
  constraint form_sections_position_ck check (position >= 0)
);

create or replace function app_private.form_item_config_valid(p_kind text, p_config jsonb)
returns boolean
language plpgsql
immutable
security definer
set search_path = ''
as $$
declare
  value_min numeric;
  value_max numeric;
  date_min date;
  date_max date;
  selection_min integer;
  selection_max integer;
  image_min integer;
  image_max integer;
  scale_min integer;
  scale_max integer;
  max_length integer;
begin
  if jsonb_typeof(p_config) <> 'object' or exists (
    select 1 from jsonb_object_keys(p_config) as key
     where key not in (
       'max_length', 'min_value', 'max_value', 'decimal_places', 'currency',
       'min_selections', 'max_selections', 'scale_min', 'scale_max',
       'scale_min_label', 'scale_max_label', 'allow_camera', 'allow_existing',
       'min_images', 'max_images'
     )
  ) then return false; end if;

  if p_kind = 'short_text' then
    if p_config - 'max_length' <> '{}'::jsonb
       or (p_config ? 'max_length' and (jsonb_typeof(p_config -> 'max_length') <> 'number'
           or (p_config ->> 'max_length')::numeric <> trunc((p_config ->> 'max_length')::numeric))) then return false; end if;
    max_length := coalesce((p_config ->> 'max_length')::integer, 1000);
    return max_length between 1 and 10000;
  elsif p_kind in ('integer', 'decimal', 'money') then
    if p_config - case when p_kind = 'decimal' then array['min_value','max_value','decimal_places']
                       when p_kind = 'money' then array['min_value','max_value','currency']
                       else array['min_value','max_value'] end <> '{}'::jsonb
       or (p_config ? 'min_value' and jsonb_typeof(p_config -> 'min_value') <> 'number')
       or (p_config ? 'max_value' and jsonb_typeof(p_config -> 'max_value') <> 'number') then return false; end if;
    value_min := (p_config ->> 'min_value')::numeric; value_max := (p_config ->> 'max_value')::numeric;
    if (p_kind in ('integer','money') and ((value_min is not null and value_min <> trunc(value_min)) or (value_max is not null and value_max <> trunc(value_max))))
       or (value_min is not null and value_max is not null and value_min > value_max) then return false; end if;
    return p_kind <> 'decimal' or not (p_config ? 'decimal_places')
      or (jsonb_typeof(p_config -> 'decimal_places') = 'number'
          and (p_config ->> 'decimal_places')::numeric = trunc((p_config ->> 'decimal_places')::numeric)
          and (p_config ->> 'decimal_places')::integer between 0 and 6);
  elsif p_kind = 'date' then
    if p_config - array['min_value','max_value'] <> '{}'::jsonb
       or (p_config ? 'min_value' and (jsonb_typeof(p_config -> 'min_value') <> 'string' or p_config ->> 'min_value' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'))
       or (p_config ? 'max_value' and (jsonb_typeof(p_config -> 'max_value') <> 'string' or p_config ->> 'max_value' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')) then return false; end if;
    date_min := (p_config ->> 'min_value')::date; date_max := (p_config ->> 'max_value')::date;
    return date_min is null or date_max is null or date_min <= date_max;
  elsif p_kind = 'multiple_choice' then
    if p_config - array['min_selections','max_selections'] <> '{}'::jsonb
       or (p_config ? 'min_selections' and jsonb_typeof(p_config -> 'min_selections') <> 'number')
       or (p_config ? 'max_selections' and jsonb_typeof(p_config -> 'max_selections') <> 'number')
       or (p_config ? 'min_selections' and (p_config ->> 'min_selections')::numeric <> trunc((p_config ->> 'min_selections')::numeric))
       or (p_config ? 'max_selections' and (p_config ->> 'max_selections')::numeric <> trunc((p_config ->> 'max_selections')::numeric)) then return false; end if;
    selection_min := coalesce((p_config ->> 'min_selections')::integer, 1);
    selection_max := coalesce((p_config ->> 'max_selections')::integer, 50);
    return selection_min between 1 and 50 and selection_max between selection_min and 50;
  elsif p_kind = 'scale' then
    if p_config - array['scale_min','scale_max','scale_min_label','scale_max_label'] <> '{}'::jsonb
       or (p_config ? 'scale_min' and jsonb_typeof(p_config -> 'scale_min') <> 'number')
       or (p_config ? 'scale_max' and jsonb_typeof(p_config -> 'scale_max') <> 'number')
       or (p_config ? 'scale_min' and (p_config ->> 'scale_min')::numeric <> trunc((p_config ->> 'scale_min')::numeric))
       or (p_config ? 'scale_max' and (p_config ->> 'scale_max')::numeric <> trunc((p_config ->> 'scale_max')::numeric)) then return false; end if;
    scale_min := coalesce((p_config ->> 'scale_min')::integer, 1);
    scale_max := coalesce((p_config ->> 'scale_max')::integer, 10);
    if scale_min <> 1 or scale_max not in (5, 10) then
      raise check_violation using message = 'scale configuration must be 1-5 or 1-10';
    end if;
    return true;
  elsif p_kind in ('photo','gallery') then
    if p_config - case when p_kind = 'photo' then array['allow_camera','min_images','max_images']
                       else array['allow_existing','min_images','max_images'] end <> '{}'::jsonb
       or (p_kind = 'photo' and p_config ? 'allow_camera' and jsonb_typeof(p_config -> 'allow_camera') <> 'boolean')
       or (p_kind = 'gallery' and p_config ? 'allow_existing' and jsonb_typeof(p_config -> 'allow_existing') <> 'boolean')
       or (p_config ? 'min_images' and jsonb_typeof(p_config -> 'min_images') <> 'number')
       or (p_config ? 'max_images' and jsonb_typeof(p_config -> 'max_images') <> 'number')
       or (p_config ? 'min_images' and (p_config ->> 'min_images')::numeric <> trunc((p_config ->> 'min_images')::numeric))
       or (p_config ? 'max_images' and (p_config ->> 'max_images')::numeric <> trunc((p_config ->> 'max_images')::numeric)) then return false; end if;
    image_min := coalesce((p_config ->> 'min_images')::integer, 1);
    image_max := coalesce((p_config ->> 'max_images')::integer, case when p_kind = 'photo' then 1 else 5 end);
    return image_min between 1 and 5 and image_max between image_min and 5
      and (p_kind <> 'photo' or (image_min = 1 and image_max = 1));
  end if;
  return p_config = '{}'::jsonb;
exception when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow then
  return false;
end;
$$;

create table public.form_items (
  id uuid primary key default gen_random_uuid(),
  form_version_id uuid not null references public.form_versions(id) on delete cascade,
  section_id uuid not null references public.form_sections(id) on delete cascade,
  kind text not null,
  label text not null,
  help_text text,
  is_required boolean not null default false,
  position integer not null,
  config_jsonb jsonb not null default '{}'::jsonb,
  constraint form_items_kind_ck check (kind in (
    'short_text', 'integer', 'decimal', 'money', 'date', 'yes_no', 'single_choice',
    'multiple_choice', 'scale', 'photo', 'gallery', 'information'
  )),
  constraint form_items_label_ck check (char_length(btrim(label)) between 1 and 1000),
  constraint form_items_help_ck check (help_text is null or char_length(help_text) <= 2000),
  constraint form_items_position_ck check (position >= 0),
  constraint form_items_required_ck check (kind <> 'information' or not is_required),
  constraint form_items_config_ck check (app_private.form_item_config_valid(kind, config_jsonb))
);

create table public.form_question_options (
  id uuid primary key default gen_random_uuid(),
  form_version_id uuid not null references public.form_versions(id) on delete cascade,
  item_id uuid not null references public.form_items(id) on delete cascade,
  label text not null,
  position integer not null,
  constraint form_options_label_ck check (char_length(btrim(label)) between 1 and 500),
  constraint form_options_position_ck check (position >= 0)
);

create table public.form_question_conditions (
  id uuid primary key default gen_random_uuid(),
  form_version_id uuid not null references public.form_versions(id) on delete cascade,
  target_item_id uuid not null references public.form_items(id) on delete cascade,
  source_item_id uuid not null references public.form_items(id) on delete cascade,
  condition_kind text not null,
  expected_yes_no boolean,
  source_option_id uuid references public.form_question_options(id) on delete cascade,
  constraint form_question_conditions_kind_ck check (condition_kind in ('yes_no', 'choice')),
  constraint form_question_conditions_distinct_ck check (target_item_id <> source_item_id),
  constraint form_question_conditions_value_ck check (
    (condition_kind = 'yes_no' and expected_yes_no is not null and source_option_id is null)
    or (condition_kind = 'choice' and expected_yes_no is null and source_option_id is not null)
  )
);

create table public.form_item_assets (
  id uuid primary key default gen_random_uuid(),
  form_version_id uuid not null references public.form_versions(id) on delete cascade,
  item_id uuid not null references public.form_items(id) on delete cascade,
  storage_path text not null unique,
  mime_type text not null,
  byte_length bigint not null,
  checksum_sha256 text not null,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  constraint form_item_assets_path_ck check (
    storage_path ~ '^[0-9a-f]{2}/[0-9a-f-]{36}$'
    and storage_path !~ '[[:space:]]'
  ),
  constraint form_item_assets_mime_ck check (mime_type in ('image/jpeg', 'image/png', 'image/webp')),
  constraint form_item_assets_size_ck check (byte_length between 1 and 10485760),
  constraint form_item_assets_checksum_ck check (checksum_sha256 ~ '^[0-9a-f]{64}$'),
  constraint form_item_assets_position_ck check (position >= 0)
);

create unique index form_versions_form_number_uidx
  on public.form_versions(form_id, version_number);
create unique index form_versions_one_working_uidx
  on public.form_versions(form_id) where state = 'working';
create unique index form_sections_version_position_uidx
  on public.form_sections(form_version_id, position);
create unique index form_items_section_position_uidx
  on public.form_items(section_id, position);
create unique index form_options_item_position_uidx
  on public.form_question_options(item_id, position);
create unique index form_conditions_edge_value_uidx
  on public.form_question_conditions(
    target_item_id,
    source_item_id,
    condition_kind,
    coalesce(source_option_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(expected_yes_no, false)
  );
create unique index form_item_assets_item_position_uidx
  on public.form_item_assets(item_id, position);

create index forms_institution_status_updated_cursor_idx
  on public.forms(institution_id, status, updated_at desc, id desc);
create index forms_institution_kind_updated_cursor_idx
  on public.forms(institution_id, kind, updated_at desc, id desc);
create index form_versions_form_id_idx on public.form_versions(form_id);
create index form_sections_version_id_idx on public.form_sections(form_version_id);
create index form_items_version_id_idx on public.form_items(form_version_id);
create index form_items_section_id_idx on public.form_items(section_id);
create index form_options_version_id_idx on public.form_question_options(form_version_id);
create index form_options_item_id_idx on public.form_question_options(item_id);
create index form_conditions_version_id_idx on public.form_question_conditions(form_version_id);
create index form_conditions_target_item_id_idx on public.form_question_conditions(target_item_id);
create index form_conditions_source_item_id_idx on public.form_question_conditions(source_item_id);
create index form_conditions_source_option_id_idx on public.form_question_conditions(source_option_id);
create index form_item_assets_version_id_idx on public.form_item_assets(form_version_id);
create index form_item_assets_item_id_idx on public.form_item_assets(item_id);

create or replace function app_private.validate_form_definition(p_version_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_has_cycle boolean;
  v_max_depth integer;
  v_form_kind text;
  v_quick_poll_intent text;
  v_quick_poll_item_count integer;
begin
  if (select count(*) from public.form_sections where form_version_id = p_version_id) > 20 then
    raise check_violation using message = 'maximum 20 form sections';
  end if;
  if (select count(*) from public.form_items where form_version_id = p_version_id) > 200 then
    raise check_violation using message = 'maximum 200 form items';
  end if;
  select form_row.kind, form_row.description
    into v_form_kind, v_quick_poll_intent
    from public.form_versions version_row
    join public.forms form_row on form_row.id = version_row.form_id
   where version_row.id = p_version_id;
  if v_form_kind = 'quick_poll' then
    if char_length(btrim(coalesce(v_quick_poll_intent, ''))) not between 1 and 280 then
      raise check_violation using message = 'quick poll intent requires between 1 and 280 characters';
    end if;
    select count(*) into v_quick_poll_item_count
      from public.form_items item where item.form_version_id = p_version_id;
    if v_quick_poll_item_count <> 1
       or exists(
         select 1 from public.form_items item
          where item.form_version_id = p_version_id and item.kind = 'information'
       ) then
      raise check_violation using message = 'quick poll requires exactly one question';
    end if;
  end if;
  if exists (
    select 1
      from public.form_items item
     where item.form_version_id = p_version_id
       and item.kind in ('single_choice', 'multiple_choice')
       and (select count(*) from public.form_question_options option_row where option_row.item_id = item.id) not between 2 and 50
  ) then
    raise check_violation using message = 'choice item requires between 2 and 50 options';
  end if;
  if exists (
    select 1
      from public.form_question_options option_row
      join public.form_items item on item.id = option_row.item_id
     where option_row.form_version_id = p_version_id
       and (item.form_version_id <> p_version_id or item.kind not in ('single_choice', 'multiple_choice'))
  ) then
    raise check_violation using message = 'form options require a choice item in the same version';
  end if;
  if exists (
    select 1
      from public.form_question_conditions condition_row
      join public.form_items source_item on source_item.id = condition_row.source_item_id
     where condition_row.form_version_id = p_version_id
       and (
         (condition_row.condition_kind = 'yes_no' and source_item.kind <> 'yes_no')
         or (condition_row.condition_kind = 'choice' and source_item.kind not in ('single_choice', 'multiple_choice'))
       )
  ) then
    raise check_violation using message = 'condition source kind is not allowed';
  end if;
  if exists (
    select 1
      from public.form_items item
      join public.form_sections section_row on section_row.id = item.section_id
     where item.form_version_id = p_version_id
       and section_row.form_version_id <> p_version_id
  ) or exists (
    select 1
      from public.form_question_conditions condition_row
      join public.form_items source_item on source_item.id = condition_row.source_item_id
      join public.form_items target_item on target_item.id = condition_row.target_item_id
     where condition_row.form_version_id = p_version_id
       and (source_item.form_version_id <> p_version_id or target_item.form_version_id <> p_version_id)
  ) then
    raise check_violation using message = 'form definition version mismatch';
  end if;

  with recursive walk(current_item_id, path, depth, cycle) as (
    select condition_row.target_item_id,
           array[condition_row.source_item_id, condition_row.target_item_id],
           1,
           condition_row.target_item_id = condition_row.source_item_id
      from public.form_question_conditions condition_row
     where condition_row.form_version_id = p_version_id
    union all
    select condition_row.target_item_id,
           walk.path || condition_row.target_item_id,
           walk.depth + 1,
           condition_row.target_item_id = any(walk.path)
      from walk
      join public.form_question_conditions condition_row
        on condition_row.source_item_id = walk.current_item_id
     where condition_row.form_version_id = p_version_id
       and not walk.cycle
       and walk.depth <= 4
  )
  select coalesce(bool_or(cycle), false), coalesce(max(depth), 0)
    into v_has_cycle, v_max_depth
    from walk;

  if v_has_cycle then
    raise check_violation using message = 'form condition cycle';
  end if;
  if v_max_depth > 4 then
    raise check_violation using message = 'maximum form condition depth is 4';
  end if;
end;
$$;

insert into public.platform_permissions(
  code, module_code, screen_code, action_code, description, risk_level, requires_mfa
)
values
  ('forms.read', 'forms', 'directory', 'read', 'Ler formulários.', 'normal', false),
  ('forms.manage', 'forms', 'editor', 'manage', 'Criar e editar formulários.', 'normal', false),
  ('forms.publish', 'forms', 'editor', 'publish', 'Publicar formulários.', 'high', false),
  ('forms.manage_applications', 'forms', 'applications', 'manage', 'Gerenciar aplicações.', 'normal', false),
  ('forms.monitor', 'forms', 'monitor', 'read', 'Monitorar formulários.', 'normal', false),
  ('forms.responses.read', 'forms', 'responses', 'read', 'Ler respostas.', 'high', false),
  ('forms.responses.export', 'forms', 'responses', 'export', 'Exportar respostas.', 'high', false),
  ('forms.transfer_cross_institution', 'forms', 'editor', 'transfer', 'Transferir formulários entre instituições.', 'high', false),
  ('forms.anonymous_participation.read', 'forms', 'monitor', 'anonymous_read', 'Consultar participação nominal anônima.', 'high', false),
  ('forms.anonymous_participation.export', 'forms', 'files', 'anonymous_export', 'Exportar participação nominal anônima.', 'high', false),
  ('forms.respond', 'forms', 'response', 'respond', 'Responder formulários.', 'normal', false)
on conflict(code) do update set
  module_code = excluded.module_code,
  screen_code = excluded.screen_code,
  action_code = excluded.action_code,
  description = excluded.description,
  risk_level = excluded.risk_level,
  requires_mfa = false,
  status = 'active',
  updated_at = now();

insert into public.platform_role_permissions(role_id, permission_id, effect)
select role_row.id, permission_row.id, 'allow'
  from public.platform_roles role_row
  join public.platform_permissions permission_row on permission_row.code like 'forms.%'
 where role_row.code = 'owner'
on conflict(role_id, permission_id) do update set
  effect = 'allow',
  status = 'active',
  revoked_at = null;

insert into public.platform_role_permissions(role_id, permission_id, effect)
select role_row.id, permission_row.id, 'allow'
  from public.platform_roles role_row
  join public.platform_permissions permission_row on permission_row.code in (
    'forms.read', 'forms.manage', 'forms.publish', 'forms.manage_applications',
    'forms.monitor', 'forms.responses.read', 'forms.responses.export', 'forms.respond'
  )
 where role_row.code = 'content'
on conflict(role_id, permission_id) do update set
  effect = 'allow',
  status = 'active',
  revoked_at = null;

alter table public.forms enable row level security;
alter table public.forms force row level security;
alter table public.form_versions enable row level security;
alter table public.form_versions force row level security;
alter table public.form_sections enable row level security;
alter table public.form_sections force row level security;
alter table public.form_items enable row level security;
alter table public.form_items force row level security;
alter table public.form_question_options enable row level security;
alter table public.form_question_options force row level security;
alter table public.form_question_conditions enable row level security;
alter table public.form_question_conditions force row level security;
alter table public.form_item_assets enable row level security;
alter table public.form_item_assets force row level security;

revoke all on table public.forms from public, anon, authenticated;
revoke all on table public.form_versions from public, anon, authenticated;
revoke all on table public.form_sections from public, anon, authenticated;
revoke all on table public.form_items from public, anon, authenticated;
revoke all on table public.form_question_options from public, anon, authenticated;
revoke all on table public.form_question_conditions from public, anon, authenticated;
revoke all on table public.form_item_assets from public, anon, authenticated;
revoke all on function app_private.form_item_config_valid(text, jsonb) from public, anon, authenticated;
revoke all on function app_private.validate_form_definition(uuid) from public, anon, authenticated;
