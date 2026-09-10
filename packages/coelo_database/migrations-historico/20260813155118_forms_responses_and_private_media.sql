create table public.form_responses (
  id uuid primary key default gen_random_uuid(),
  occurrence_id uuid not null references public.form_occurrences(id) on delete restrict,
  institution_id uuid not null references public.institutions(id) on delete restrict,
  form_id uuid not null references public.forms(id) on delete restrict,
  form_version_id uuid not null references public.form_versions(id) on delete restrict,
  identity_mode text not null,
  respondent_person_id uuid references public.people(id) on delete restrict,
  status text not null default 'draft',
  management_version bigint not null default 1,
  anonymous_edit_secret_hash text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  submitted_at timestamptz,
  constraint form_responses_identity_ck check (identity_mode in ('identified', 'anonymous')),
  constraint form_responses_status_ck check (status in ('draft', 'submitted')),
  constraint form_responses_anonymity_ck check (
    (identity_mode = 'anonymous' and respondent_person_id is null and anonymous_edit_secret_hash is not null)
    or (identity_mode = 'identified' and respondent_person_id is not null and anonymous_edit_secret_hash is null)
  ),
  constraint form_responses_submission_ck check (
    (status = 'draft' and submitted_at is null) or (status = 'submitted' and submitted_at is not null)
  ),
  constraint form_responses_version_ck check (management_version > 0)
);

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values (
  'coelo-forms-private', 'coelo-forms-private', false, 10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict(id) do update set
  public = false,
  file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

comment on table public.form_responses is
  'Anonymous responses intentionally have no participation_id, person_id, response unit key, or shared correlation key.';

create table public.form_answers (
  id uuid primary key default gen_random_uuid(),
  response_id uuid not null references public.form_responses(id) on delete cascade,
  form_version_id uuid not null references public.form_versions(id) on delete restrict,
  item_id uuid not null references public.form_items(id) on delete restrict,
  answer_kind text not null,
  text_value text,
  integer_value bigint,
  decimal_value numeric,
  money_minor_units bigint,
  date_value date,
  yes_no_value boolean,
  scale_value integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint form_answers_kind_ck check (answer_kind in (
    'short_text', 'integer', 'decimal', 'money', 'date', 'yes_no',
    'single_choice', 'multiple_choice', 'scale', 'photo', 'gallery'
  )),
  constraint form_answers_typed_value_ck check (
    num_nonnulls(text_value, integer_value, decimal_value, money_minor_units, date_value, yes_no_value, scale_value)
      = case when answer_kind in ('single_choice', 'multiple_choice', 'photo', 'gallery') then 0 else 1 end
  ),
  unique(response_id, item_id)
);

create table public.form_answer_options (
  answer_id uuid not null references public.form_answers(id) on delete cascade,
  option_id uuid not null references public.form_question_options(id) on delete restrict,
  position integer not null,
  primary key(answer_id, option_id),
  constraint form_answer_options_position_ck check (position >= 0)
);

create table public.form_assets (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  occurrence_id uuid not null references public.form_occurrences(id) on delete cascade,
  item_id uuid not null references public.form_items(id) on delete restrict,
  prepared_by_person_id uuid references public.people(id) on delete restrict,
  anonymous_upload_secret_hash text,
  storage_path text not null unique,
  mime_type text not null,
  expected_byte_length bigint not null,
  actual_byte_length bigint,
  expected_checksum_sha256 text not null,
  actual_checksum_sha256 text,
  state text not null default 'prepared',
  prepared_at timestamptz not null default now(),
  finalized_at timestamptz,
  discarded_at timestamptz,
  -- Supabase signed upload tokens live for two hours. Keep a safety margin so
  -- cleanup cannot delete the reservation while its upload token still works.
  expires_at timestamptz not null default (now() + interval '3 hours'),
  constraint form_assets_path_ck check (storage_path ~ '^[0-9a-f]{2}/[0-9a-f-]{36}$'),
  constraint form_assets_mime_ck check (mime_type in ('image/jpeg', 'image/png', 'image/webp')),
  constraint form_assets_expected_size_ck check (expected_byte_length between 1 and 10485760),
  constraint form_assets_actual_size_ck check (actual_byte_length is null or actual_byte_length between 1 and 10485760),
  constraint form_assets_checksum_ck check (
    expected_checksum_sha256 ~ '^[0-9a-f]{64}$'
    and (actual_checksum_sha256 is null or actual_checksum_sha256 ~ '^[0-9a-f]{64}$')
  ),
  constraint form_assets_state_ck check (state in ('prepared', 'uploaded', 'finalized', 'discarded', 'expired')),
  constraint form_assets_owner_ck check (
    (prepared_by_person_id is not null and anonymous_upload_secret_hash is null)
    or (prepared_by_person_id is null and anonymous_upload_secret_hash like '$2%')
  )
);

create table public.form_answer_assets (
  answer_id uuid not null references public.form_answers(id) on delete cascade,
  asset_id uuid not null unique references public.form_assets(id) on delete restrict,
  position integer not null,
  primary key(answer_id, asset_id),
  constraint form_answer_assets_position_ck check (position between 0 and 4)
);

create table public.form_response_revisions (
  id uuid primary key default gen_random_uuid(),
  response_id uuid not null references public.form_responses(id) on delete cascade,
  revision_number integer not null,
  action text not null,
  answers_snapshot jsonb not null,
  changed_by_person_id uuid references public.people(id) on delete restrict,
  changed_at timestamptz not null default now(),
  constraint form_response_revisions_number_ck check (revision_number > 0),
  constraint form_response_revisions_action_ck check (action in ('draft_saved', 'submitted', 'edited')),
  unique(response_id, revision_number)
);

create index form_responses_occurrence_cursor_idx on public.form_responses(occurrence_id, submitted_at desc, id desc);
create unique index form_responses_identified_occurrence_person_uidx
  on public.form_responses(occurrence_id, respondent_person_id)
  where identity_mode = 'identified';
create index form_responses_form_cursor_idx on public.form_responses(form_id, submitted_at desc, id desc);
create index form_responses_version_id_idx on public.form_responses(form_version_id);
create index form_responses_person_id_idx on public.form_responses(respondent_person_id) where respondent_person_id is not null;
create index form_answers_response_id_idx on public.form_answers(response_id);
create index form_answers_item_id_idx on public.form_answers(item_id);
create index form_answer_options_option_id_idx on public.form_answer_options(option_id);
create index form_assets_occurrence_item_idx on public.form_assets(occurrence_id, item_id, state, id);
create index form_assets_cleanup_idx on public.form_assets(expires_at, id) where state in ('prepared', 'uploaded');
create index form_response_revisions_response_id_idx on public.form_response_revisions(response_id);

create or replace function app_private.form_hash_anonymous_edit_secret(p_secret text)
returns text
language sql
security definer
set search_path = ''
as $$
  select extensions.crypt(p_secret, extensions.gen_salt('bf', 12));
$$;

create or replace function app_private.form_verify_anonymous_edit_secret(p_secret text, p_hash text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_hash is not null and extensions.crypt(p_secret, p_hash) = p_hash;
$$;

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'form_responses', 'form_answers', 'form_answer_options', 'form_assets',
    'form_answer_assets', 'form_response_revisions'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
    execute format('revoke all on table public.%I from public, anon, authenticated', table_name);
  end loop;
end $$;

revoke all on function app_private.form_hash_anonymous_edit_secret(text) from public, anon, authenticated;
revoke all on function app_private.form_verify_anonymous_edit_secret(text, text) from public, anon, authenticated;
