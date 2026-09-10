-- F-AUTHOR01. LOCAL nominal package; reviewed replay is owned by Eng1.
-- No publication, distribution, responder, worker or media implementation.
begin;

do $preflight$
declare probe jsonb;
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message='F-AUTHOR01 requires postgres';
  end if;
  if pg_catalog.to_regtype('app_private.superadmin_internal_context') is null
    or pg_catalog.to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or pg_catalog.to_regprocedure('app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)') is null
    or pg_catalog.to_regprocedure('app_private.form_definition_projection(uuid)') is null
    or pg_catalog.to_regprocedure('app_private.form_assert_distribution_target(uuid,uuid,uuid)') is null
    or pg_catalog.to_regclass('public.form_file_jobs') is null then
    raise object_not_in_prerequisite_state using message='F-AUTHOR01 requires nominal Auth and effective Forms dependencies';
  end if;
  if pg_catalog.to_regprocedure('public.superadmin_forms_save_draft_v2(uuid,bigint,jsonb)') is not null
    or pg_catalog.to_regclass('app_private.superadmin_internal_form_draft_receipts') is not null then
    raise object_not_in_prerequisite_state using message='F-AUTHOR01 already exists; reconcile nominal ledger';
  end if;
  probe:=app_private.superadmin_internal_error_envelope('SAI_INVALID_ARGUMENT',pg_catalog.gen_random_uuid());
  if probe#>>'{error,code}' is distinct from 'SAI_INVALID_ARGUMENT' or probe#>>'{error,http_status}' is distinct from '400' then
    raise object_not_in_prerequisite_state using message='F-AUTHOR01 requires invalid argument envelope';
  end if;
  probe:=app_private.superadmin_internal_error_envelope('SAI_CONCURRENT_CHANGE',pg_catalog.gen_random_uuid());
  if probe#>>'{error,code}' is distinct from 'SAI_CONCURRENT_CHANGE' or probe#>>'{error,http_status}' is distinct from '409' then
    raise object_not_in_prerequisite_state using message='F-AUTHOR01 requires concurrent change envelope';
  end if;
end
$preflight$;

alter table public.forms
  add column created_by_internal_identity_id uuid references app_private.superadmin_internal_identities(id) on delete restrict,
  add column updated_by_internal_identity_id uuid references app_private.superadmin_internal_identities(id) on delete restrict,
  alter column created_by_person_id drop not null,
  alter column updated_by_person_id drop not null,
  add constraint forms_creator_realm_xor check ((created_by_person_id is null) <> (created_by_internal_identity_id is null)),
  add constraint forms_updater_realm_xor check ((updated_by_person_id is null) <> (updated_by_internal_identity_id is null));
alter table public.form_versions
  add column created_by_internal_identity_id uuid references app_private.superadmin_internal_identities(id) on delete restrict,
  alter column created_by_person_id drop not null,
  add constraint form_versions_creator_realm_xor check ((created_by_person_id is null) <> (created_by_internal_identity_id is null));
create index forms_internal_creator_idx on public.forms(created_by_internal_identity_id) where created_by_internal_identity_id is not null;
create index forms_internal_updater_idx on public.forms(updated_by_internal_identity_id) where updated_by_internal_identity_id is not null;
create index form_versions_internal_creator_idx on public.form_versions(created_by_internal_identity_id) where created_by_internal_identity_id is not null;

create table app_private.superadmin_internal_form_draft_receipts (
  request_id uuid primary key,
  actor_internal_identity_id uuid not null references app_private.superadmin_internal_identities(id) on delete restrict,
  form_id uuid not null references public.forms(id) on delete restrict,
  institution_id uuid not null references public.institutions(id) on delete restrict,
  expected_version bigint not null check (expected_version >= 0),
  request_hash bytea not null check (octet_length(request_hash)=32),
  result_jsonb jsonb not null check (jsonb_typeof(result_jsonb)='object'),
  created_at timestamptz not null default now()
);
create index superadmin_form_draft_receipts_actor_idx on app_private.superadmin_internal_form_draft_receipts(actor_internal_identity_id);
create index superadmin_form_draft_receipts_form_idx on app_private.superadmin_internal_form_draft_receipts(form_id);
create index superadmin_form_draft_receipts_institution_idx on app_private.superadmin_internal_form_draft_receipts(institution_id);
alter table app_private.superadmin_internal_form_draft_receipts enable row level security;
alter table app_private.superadmin_internal_form_draft_receipts force row level security;
revoke all on table app_private.superadmin_internal_form_draft_receipts from public,anon,authenticated,service_role;

-- Provenance alone is NOT a permanent audience policy. Dependency absence is
-- deliberately excluded here: an unexpected application/job cannot unprotect it.
create function app_private.superadmin_form_is_internal_draft_v2(p_form_id uuid)
returns boolean language sql stable security definer set search_path='' as $function$
  select exists(select 1 from public.forms f where f.id=p_form_id
    and f.created_by_internal_identity_id is not null and f.status='draft'
    and f.first_published_at is null and f.published_version_id is null);
$function$;

create function app_private.superadmin_form_assert_legacy_resource_v2(p_form_id uuid)
returns void language plpgsql stable security definer set search_path='' as $function$
begin
  if app_private.superadmin_form_is_internal_draft_v2(p_form_id) then
    raise no_data_found using message='form unavailable';
  end if;
  -- Missing rows remain missing: do not break historical delete receipt replay.
end
$function$;

create function app_private.superadmin_form_lock_legacy_resource_v2(p_form_id uuid)
returns void language plpgsql volatile security definer set search_path='' as $function$
begin
  perform app_private.superadmin_form_assert_legacy_resource_v2(p_form_id);
  perform 1 from public.forms f where f.id=p_form_id for update;
  perform app_private.superadmin_form_assert_legacy_resource_v2(p_form_id);
end
$function$;

create function app_private.superadmin_form_validate_draft_payload_v2(p_payload jsonb)
returns void language plpgsql immutable security definer set search_path='' as $function$
declare
  s jsonb; i jsonb; o jsonb; c jsonb;
  field_name text;
  section_position integer:=0;
  item_position integer;
  option_position integer;
  item_count integer:=0;
begin
  -- Technical request ceiling; relational limits below remain authoritative.
  if p_payload is null or pg_catalog.jsonb_typeof(p_payload) is distinct from 'object'
    or pg_catalog.octet_length(p_payload::text)>33554432
    or p_payload-array['id','institution_id','kind','identity_mode','response_unit','title','description','sections']<>'{}'::jsonb
    or not (p_payload ?& array['institution_id','kind','identity_mode','response_unit','title','sections']) then
    raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
  end if;
  foreach field_name in array array['institution_id','kind','identity_mode','response_unit','title'] loop
    if pg_catalog.jsonb_typeof(p_payload->field_name) is distinct from 'string' then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
  end loop;
  foreach field_name in array array['id','description'] loop
    if p_payload ? field_name and p_payload->field_name<>'null'::jsonb
      and pg_catalog.jsonb_typeof(p_payload->field_name)<>'string' then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
  end loop;
  if p_payload->>'institution_id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    or (p_payload->>'id' is not null and p_payload->>'id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
    or p_payload->>'kind' not in ('form','quick_poll')
    or p_payload->>'identity_mode' not in ('identified','anonymous')
    or p_payload->>'response_unit' not in ('person','child_family_context')
    or pg_catalog.char_length(btrim(p_payload->>'title')) not between 1 and 200
    or pg_catalog.char_length(p_payload->>'description')>4000
    or pg_catalog.jsonb_typeof(p_payload->'sections') is distinct from 'array' then
    raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
  end if;
  if pg_catalog.jsonb_array_length(p_payload->'sections')>20 then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
  for s in select value from pg_catalog.jsonb_array_elements(p_payload->'sections') loop
    if pg_catalog.jsonb_typeof(s) is distinct from 'object'
      or s-array['id','title','description','position','items']<>'{}'::jsonb
      or not (s ?& array['id','title','position','items']) then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
    if pg_catalog.jsonb_typeof(s->'id') is distinct from 'string' or pg_catalog.char_length(s->>'id') not between 1 and 128
      or pg_catalog.jsonb_typeof(s->'title') is distinct from 'string'
      or pg_catalog.jsonb_typeof(s->'position') is distinct from 'number' or s->>'position' !~ '^[0-9]+$'
      or (s->>'position')::integer<>section_position
      or pg_catalog.jsonb_typeof(s->'items') is distinct from 'array'
      or (s ? 'description' and s->'description'<>'null'::jsonb and pg_catalog.jsonb_typeof(s->'description')<>'string') then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    section_position:=section_position+1; item_position:=0;
    for i in select value from pg_catalog.jsonb_array_elements(s->'items') loop
      item_count:=item_count+1;
      if item_count>200 or pg_catalog.jsonb_typeof(i) is distinct from 'object'
        or i-array['id','kind','label','help_text','position','is_required','config','options','conditions']<>'{}'::jsonb
        or not (i ?& array['id','kind','label','position']) then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
      foreach field_name in array array['id','kind','label'] loop
        if pg_catalog.jsonb_typeof(i->field_name) is distinct from 'string' then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
      end loop;
      if pg_catalog.char_length(i->>'id') not between 1 and 128
        or pg_catalog.jsonb_typeof(i->'position') is distinct from 'number' or i->>'position' !~ '^[0-9]+$'
        or (i->>'position')::integer<>item_position
        or (i ? 'help_text' and i->'help_text'<>'null'::jsonb and pg_catalog.jsonb_typeof(i->'help_text')<>'string')
        or (i ? 'is_required' and pg_catalog.jsonb_typeof(i->'is_required') is distinct from 'boolean')
        or (i ? 'config' and pg_catalog.jsonb_typeof(i->'config') is distinct from 'object') then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
      item_position:=item_position+1; option_position:=0;
      foreach field_name in array array['options','conditions'] loop
        if i ? field_name and pg_catalog.jsonb_typeof(i->field_name) is distinct from 'array' then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
      end loop;
      if pg_catalog.jsonb_array_length(coalesce(i->'options','[]'))>50
        or pg_catalog.jsonb_array_length(coalesce(i->'conditions','[]'))>200 then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
      for o in select value from pg_catalog.jsonb_array_elements(coalesce(i->'options','[]')) loop
        if pg_catalog.jsonb_typeof(o) is distinct from 'object' or o-array['id','label','position']<>'{}'::jsonb
          or not (o ?& array['id','label','position'])
          or pg_catalog.jsonb_typeof(o->'id') is distinct from 'string' or pg_catalog.char_length(o->>'id') not between 1 and 128
          or pg_catalog.jsonb_typeof(o->'label') is distinct from 'string'
          or pg_catalog.jsonb_typeof(o->'position') is distinct from 'number' or o->>'position' !~ '^[0-9]+$'
          or (o->>'position')::integer<>option_position then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
        option_position:=option_position+1;
      end loop;
      for c in select value from pg_catalog.jsonb_array_elements(coalesce(i->'conditions','[]')) loop
        if pg_catalog.jsonb_typeof(c) is distinct from 'object'
          or c-array['source_item_id','kind','expected_yes_no','option_ids']<>'{}'::jsonb
          or pg_catalog.jsonb_typeof(c->'source_item_id') is distinct from 'string'
          or pg_catalog.char_length(c->>'source_item_id') not between 1 and 128
          or pg_catalog.jsonb_typeof(c->'kind') is distinct from 'string'
          or c->>'kind' not in ('yes_no','choice') then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
        if c->>'kind'='yes_no' then
          if pg_catalog.jsonb_typeof(c->'expected_yes_no') is distinct from 'boolean'
            or (c ? 'option_ids' and c->'option_ids' not in ('[]'::jsonb,'null'::jsonb)) then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
        else
          if (c ? 'expected_yes_no' and c->'expected_yes_no'<>'null'::jsonb)
            or pg_catalog.jsonb_typeof(c->'option_ids') is distinct from 'array' then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
          if pg_catalog.jsonb_array_length(c->'option_ids') not between 1 and 50
            or exists(select 1 from pg_catalog.jsonb_array_elements(c->'option_ids') v where pg_catalog.jsonb_typeof(v)<>'string' or pg_catalog.char_length(v#>>'{}') not between 1 and 128) then
            raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
          end if;
        end if;
      end loop;
    end loop;
  end loop;
end
$function$;

create function app_private.superadmin_form_validate_draft_definition_v2(p_version_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_has_cycle boolean;
  v_max_depth integer;
begin
  if (select count(*) from public.form_sections where form_version_id = p_version_id) > 20 then
    raise check_violation using message = 'maximum 20 form sections';
  end if;
  if (select count(*) from public.form_items where form_version_id = p_version_id) > 200 then
    raise check_violation using message = 'maximum 200 form items';
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

  if exists (
    select 1 from public.form_question_conditions c
    join public.form_question_options o on o.id=c.source_option_id
    where c.form_version_id=p_version_id and (o.item_id<>c.source_item_id or o.form_version_id<>p_version_id)
  ) then raise check_violation using message='condition option does not belong to its source'; end if;

  -- One logical edge can have 50 option rows. Never enumerate option paths.
  -- UNION deduplicates (origin,target,depth), bounded by 200*200*5 states.
  with recursive edges(source_id,target_id) as (
    select distinct source_item_id,target_item_id from public.form_question_conditions
    where form_version_id=p_version_id
  ), walk(origin_id,current_item_id,depth) as (
    select source_id,target_id,1 from edges
    union
    select walk.origin_id,edges.target_id,walk.depth+1
    from walk join edges on edges.source_id=walk.current_item_id
    where walk.depth<5
  )
  select coalesce(bool_or(origin_id=current_item_id), false), coalesce(max(depth), 0)
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

create function app_private.superadmin_form_replace_draft_definition_v2(
  p_version_id uuid,
  p_sections jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  section_json jsonb;
  item_json jsonb;
  option_json jsonb;
  condition_json jsonb;
  source_section_id text;
  source_item_id text;
  source_option_id text;
  section_ids jsonb := '{}'::jsonb;
  item_ids jsonb := '{}'::jsonb;
  option_ids jsonb := '{}'::jsonb;
begin
  if jsonb_typeof(p_sections) <> 'array' then
    raise invalid_parameter_value using message = 'sections must be an array';
  end if;
  if jsonb_array_length(p_sections) > 20 then
    raise check_violation using message = 'maximum 20 form sections';
  end if;

  delete from public.form_sections where form_version_id = p_version_id;

  for section_json in select value from jsonb_array_elements(p_sections) loop
    perform app_private.form_assert_payload_keys(
      section_json,
      array['id','title','description','position','items'],
      'form section'
    );
    source_section_id := nullif(section_json ->> 'id', '');
    if source_section_id is null or section_ids ? source_section_id then
      raise invalid_parameter_value using message = 'unique section id required';
    end if;
    section_ids := section_ids || jsonb_build_object(source_section_id, gen_random_uuid()::text);
    if jsonb_typeof(section_json -> 'items') <> 'array' then
      raise invalid_parameter_value using message = 'section items must be an array';
    end if;
    for item_json in select value from jsonb_array_elements(section_json -> 'items') loop
      perform app_private.form_assert_payload_keys(
        item_json,
        array['id','kind','label','help_text','position','is_required','config','options','conditions'],
        'form item'
      );
      source_item_id := nullif(item_json ->> 'id', '');
      if source_item_id is null or item_ids ? source_item_id then
        raise invalid_parameter_value using message = 'unique item id required';
      end if;
      item_ids := item_ids || jsonb_build_object(source_item_id, gen_random_uuid()::text);
      if jsonb_typeof(coalesce(item_json -> 'options', '[]'::jsonb)) <> 'array'
         or jsonb_typeof(coalesce(item_json -> 'conditions', '[]'::jsonb)) <> 'array' then
        raise invalid_parameter_value using message = 'item options and conditions must be arrays';
      end if;
      if jsonb_array_length(coalesce(item_json -> 'options', '[]'::jsonb)) > 50 then
        raise check_violation using message = 'maximum 50 form options per item';
      end if;
      for option_json in select value from jsonb_array_elements(coalesce(item_json -> 'options', '[]'::jsonb)) loop
        perform app_private.form_assert_payload_keys(
          option_json, array['id','label','position'], 'form option'
        );
        source_option_id := nullif(option_json ->> 'id', '');
        if source_option_id is null or option_ids ? source_option_id then
          raise invalid_parameter_value using message = 'unique option id required';
        end if;
        option_ids := option_ids || jsonb_build_object(source_option_id, gen_random_uuid()::text);
      end loop;
    end loop;
  end loop;

  if (select count(*) from jsonb_object_keys(item_ids)) > 200 then
    raise check_violation using message = 'maximum 200 form items';
  end if;

  for section_json in select value from jsonb_array_elements(p_sections) loop
    source_section_id := section_json ->> 'id';
    insert into public.form_sections(id, form_version_id, title, description, position)
    values (
      (section_ids ->> source_section_id)::uuid,
      p_version_id,
      btrim(section_json ->> 'title'),
      nullif(btrim(section_json ->> 'description'), ''),
      (section_json ->> 'position')::integer
    );
    for item_json in select value from jsonb_array_elements(section_json -> 'items') loop
      source_item_id := item_json ->> 'id';
      insert into public.form_items(
        id, form_version_id, section_id, kind, label, help_text, is_required, position, config_jsonb
      ) values (
        (item_ids ->> source_item_id)::uuid,
        p_version_id,
        (section_ids ->> source_section_id)::uuid,
        item_json ->> 'kind',
        btrim(item_json ->> 'label'),
        nullif(btrim(item_json ->> 'help_text'), ''),
        coalesce((item_json ->> 'is_required')::boolean, false),
        (item_json ->> 'position')::integer,
        coalesce(item_json -> 'config', '{}'::jsonb)
      );
      for option_json in select value from jsonb_array_elements(coalesce(item_json -> 'options', '[]'::jsonb)) loop
        source_option_id := option_json ->> 'id';
        insert into public.form_question_options(id, form_version_id, item_id, label, position)
        values (
          (option_ids ->> source_option_id)::uuid,
          p_version_id,
          (item_ids ->> source_item_id)::uuid,
          btrim(option_json ->> 'label'),
          (option_json ->> 'position')::integer
        );
      end loop;
    end loop;
  end loop;

  for section_json in select value from jsonb_array_elements(p_sections) loop
    for item_json in select value from jsonb_array_elements(section_json -> 'items') loop
      source_item_id := item_json ->> 'id';
      for condition_json in select value from jsonb_array_elements(coalesce(item_json -> 'conditions', '[]'::jsonb)) loop
        perform app_private.form_assert_payload_keys(
          condition_json,
          array['source_item_id','kind','expected_yes_no','option_ids'],
          'form condition'
        );
        if not item_ids ? (condition_json ->> 'source_item_id') then
          raise invalid_parameter_value using message = 'condition source item not found';
        end if;
        for source_option_id in
          select value
            from jsonb_array_elements_text(
              case when condition_json ->> 'kind' = 'choice'
                then condition_json -> 'option_ids' else '[null]'::jsonb end
            )
        loop
          if condition_json ->> 'kind' = 'choice' and not option_ids ? source_option_id then
            raise invalid_parameter_value using message = 'condition source option not found';
          end if;
          insert into public.form_question_conditions(
            form_version_id, target_item_id, source_item_id, condition_kind,
            expected_yes_no, source_option_id
          ) values (
            p_version_id,
            (item_ids ->> source_item_id)::uuid,
            (item_ids ->> (condition_json ->> 'source_item_id'))::uuid,
            condition_json ->> 'kind',
            (condition_json ->> 'expected_yes_no')::boolean,
            case when source_option_id is null then null
                 else (option_ids ->> source_option_id)::uuid end
          );
        end loop;
      end loop;
    end loop;
  end loop;
  perform app_private.superadmin_form_validate_draft_definition_v2(p_version_id);
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260813155121_forms_commands_and_projections.sql
create or replace function app_private.form_list(p_query jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.read');
declare page_limit integer := least(greatest(coalesce((p_query ->> 'limit')::integer, 25), 1), 100);
declare cursor_updated timestamptz;
declare cursor_id uuid;
begin
  perform app_private.form_assert_payload_keys(
    p_query,
    array['institution_id','search','statuses','operational_statuses','kinds','starts_on_or_after','ends_on_or_before','cursor_updated_at','cursor_id','limit'],
    'form directory query'
  );
  cursor_updated := (p_query ->> 'cursor_updated_at')::timestamptz;
  cursor_id := (p_query ->> 'cursor_id')::uuid;
  return (
    with operational as (
      select form_row.*,
             case
               when form_row.status = 'archived' then 'archived'
               when form_row.status = 'draft' then 'draft'
               when coalesce(occurrence_window.is_active, false) then 'active'
               when coalesce(occurrence_window.is_scheduled, false) then 'scheduled'
               else 'closed'
             end as operational_status
        from public.forms form_row
        left join lateral (
          select bool_or(
                   occurrence_row.status in ('scheduled', 'open')
                   and occurrence_row.opens_at <= now()
                   and occurrence_row.closes_at > now()
                 ) as is_active,
                 bool_or(
                   occurrence_row.status in ('scheduled', 'open')
                   and occurrence_row.opens_at > now()
                 ) as is_scheduled
            from public.form_occurrences occurrence_row
           where occurrence_row.form_id = form_row.id
        ) occurrence_window on true
       where not app_private.superadmin_form_is_internal_draft_v2(form_row.id)
         and ((p_query ->> 'institution_id') is null
              or form_row.institution_id = (p_query ->> 'institution_id')::uuid)
         and (nullif(p_query ->> 'search', '') is null
              or form_row.title ilike '%' || app_private.form_escape_like(p_query ->> 'search') || '%' escape '\')
         and (coalesce(jsonb_array_length(p_query -> 'statuses'), 0) = 0 or form_row.status in (
           select jsonb_array_elements_text(p_query -> 'statuses')
         ))
         and (coalesce(jsonb_array_length(p_query -> 'kinds'), 0) = 0 or form_row.kind in (
           select jsonb_array_elements_text(p_query -> 'kinds')
         ))
         and ((p_query ->> 'starts_on_or_after') is null or exists (
           select 1 from public.form_occurrences occurrence_row
            where occurrence_row.form_id = form_row.id
              and occurrence_row.opens_at::date >= (p_query ->> 'starts_on_or_after')::date
         ))
         and ((p_query ->> 'ends_on_or_before') is null or exists (
           select 1 from public.form_occurrences occurrence_row
            where occurrence_row.form_id = form_row.id
              and occurrence_row.closes_at::date <= (p_query ->> 'ends_on_or_before')::date
         ))
    ), page as (
      select operational.*
        from operational
       where (coalesce(jsonb_array_length(p_query -> 'operational_statuses'), 0) = 0
              or operational_status in (
                select jsonb_array_elements_text(p_query -> 'operational_statuses')
              ))
         and (cursor_updated is null or (updated_at, id) < (cursor_updated, cursor_id))
       order by updated_at desc, id desc
       limit page_limit + 1
    ), visible as (select * from page limit page_limit)
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'title', title, 'kind', kind, 'status', status,
        'operational_status', operational_status,
        'identity_mode', identity_mode, 'updated_at', updated_at,
        'management_version', management_version
      ) order by updated_at desc, id desc), '[]'::jsonb),
      'has_more', (select count(*) > page_limit from page),
      'next_cursor', (select jsonb_build_object('updated_at', updated_at, 'id', id)
                        from visible order by updated_at, id limit 1)
    ) from visible
  );
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260820152528_forms_editor_application_capability_guard.sql
create or replace function app_private.form_get_editor(p_form_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  definition_projection jsonb;
  application_projection jsonb;
  form_institution_id uuid;
begin
  if app_private.has_platform_permission('forms.manage') then
    perform app_private.require_forms_actor('forms.manage');
  else
    perform app_private.require_forms_actor('forms.read');
  end if;

  select app_private.form_definition_projection(form_row.id),
         form_row.institution_id
    into definition_projection, form_institution_id
    from public.forms form_row
   where form_row.id = p_form_id
     and not app_private.superadmin_form_is_internal_draft_v2(form_row.id);

  if definition_projection is null then
    raise no_data_found using message = 'form unavailable';
  end if;

  if app_private.has_platform_permission('forms.manage_applications') then
    select app_private.form_application_projection(application.id)
      into application_projection
      from public.form_applications application
     where application.form_id = p_form_id
       and application.institution_id = form_institution_id
     order by
       (application.status = 'archived'),
       application.updated_at desc,
       application.id desc
     limit 1;
  end if;

  return jsonb_build_object(
    'definition', definition_projection,
    'application', application_projection
  );
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260813155121_forms_commands_and_projections.sql
create or replace function app_private.form_get_overview(p_form_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare result jsonb;
begin
  perform app_private.require_forms_actor('forms.read');
  perform app_private.superadmin_form_assert_legacy_resource_v2(p_form_id);
  select app_private.form_definition_projection(p_form_id) || jsonb_build_object(
    'application_count', (select count(*) from public.form_applications where form_id = p_form_id),
    'occurrence_count', (select count(*) from public.form_occurrences where form_id = p_form_id),
    'response_count', (select count(*) from public.form_responses where form_id = p_form_id)
  ) into result;
  if result is null then raise no_data_found using message = 'form unavailable'; end if;
  return result;
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260813155121_forms_commands_and_projections.sql
create or replace function app_private.form_save_draft(
  p_request_id uuid,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.require_forms_actor('forms.manage');
  target_form_id uuid := coalesce((p_payload ->> 'id')::uuid, gen_random_uuid());
  form_row public.forms;
  version_id uuid;
  version_number integer;
  replay jsonb;
  result jsonb;
  before_state jsonb;
begin
  perform app_private.form_assert_payload_keys(
    p_payload,
    array['id','institution_id','kind','identity_mode','response_unit','title','description','sections'],
    'form draft'
  );
  perform app_private.superadmin_form_lock_legacy_resource_v2(target_form_id);
  replay := app_private.form_begin_command(
    p_request_id, actor, 'form_save_draft', p_expected_version, p_payload
  );
  if replay is not null then return replay; end if;

  perform pg_advisory_xact_lock(hashtextextended(target_form_id::text, 0));
  select * into form_row from public.forms where id = target_form_id for update;
  perform app_private.superadmin_form_assert_legacy_resource_v2(form_row.id);
  before_state := case when form_row.id is null then null else app_private.form_definition_projection(target_form_id) end;
  if form_row.id is null then
    if p_expected_version <> 0 then
      raise serialization_failure using message = 'expected_version mismatch';
    end if;
    insert into public.forms(
      id, institution_id, kind, identity_mode, response_unit, title, description,
      created_by_person_id, updated_by_person_id
    ) values (
      target_form_id,
      (p_payload ->> 'institution_id')::uuid,
      p_payload ->> 'kind',
      p_payload ->> 'identity_mode',
      p_payload ->> 'response_unit',
      btrim(p_payload ->> 'title'),
      nullif(btrim(p_payload ->> 'description'), ''),
      actor,
      actor
    ) returning * into form_row;
    version_number := 1;
    insert into public.form_versions(form_id, version_number, created_by_person_id)
    values (target_form_id, version_number, actor)
    returning id into version_id;
    update public.forms set working_version_id = version_id where id = target_form_id;
  else
    if form_row.management_version <> p_expected_version then
      raise serialization_failure using message = 'expected_version mismatch';
    end if;
    if form_row.institution_id <> (p_payload ->> 'institution_id')::uuid then
      raise check_violation using message = 'use form_copy_or_move for institution changes';
    end if;
    if form_row.first_published_at is not null
       and form_row.identity_mode <> p_payload ->> 'identity_mode' then
      raise check_violation using message = 'identity mode is immutable after first publication';
    end if;
    version_id := form_row.working_version_id;
    if version_id is null then
      select coalesce(max(version_number), 0) + 1 into version_number
        from public.form_versions where form_id = form_row.id;
      insert into public.form_versions(form_id, version_number, created_by_person_id)
      values (target_form_id, version_number, actor)
      returning id into version_id;
    end if;
    update public.forms
       set institution_id = (p_payload ->> 'institution_id')::uuid,
           kind = p_payload ->> 'kind',
           identity_mode = p_payload ->> 'identity_mode',
           response_unit = p_payload ->> 'response_unit',
           title = btrim(p_payload ->> 'title'),
           description = nullif(btrim(p_payload ->> 'description'), ''),
           working_version_id = version_id,
           management_version = management_version + 1,
           updated_by_person_id = actor,
           updated_at = now()
     where id = target_form_id;
  end if;

  perform app_private.form_replace_working_definition(version_id, p_payload -> 'sections');
  result := app_private.form_definition_projection(target_form_id);
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id,
    outcome, before_json, after_json
  ) values (
    actor, auth.jwt() ->> 'aal', 'forms.draft.save', 'form', target_form_id,
    (p_payload ->> 'institution_id')::uuid, 'success', before_state,
    jsonb_build_object('management_version', result -> 'management_version')
  );
  return app_private.form_complete_command(p_request_id, result);
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260813155121_forms_commands_and_projections.sql
create or replace function app_private.form_publish(
  p_request_id uuid,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.require_forms_actor('forms.publish');
  target_form_id uuid;
  form_row public.forms;
  replay jsonb;
  result jsonb;
begin
  perform app_private.form_assert_payload_keys(p_payload, array['form_id'], 'form publish');
  target_form_id := (p_payload ->> 'form_id')::uuid;
  perform app_private.superadmin_form_lock_legacy_resource_v2(target_form_id);
  replay := app_private.form_begin_command(
    p_request_id, actor, 'form_publish', p_expected_version, p_payload
  );
  if replay is not null then return replay; end if;
  perform pg_advisory_xact_lock(hashtextextended(target_form_id::text, 0));
  select * into form_row from public.forms where id = target_form_id for update;
  perform app_private.superadmin_form_assert_legacy_resource_v2(form_row.id);
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if form_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  if form_row.working_version_id is null then
    raise check_violation using message = 'working version required';
  end if;
  perform app_private.validate_form_definition(form_row.working_version_id);
  update public.form_versions
     set state = 'superseded'
   where id = form_row.published_version_id and state = 'published';
  update public.form_versions
     set state = 'published', published_at = now()
   where id = form_row.working_version_id and state = 'working';
  update public.forms
     set status = 'published',
         published_version_id = working_version_id,
         working_version_id = null,
         first_published_at = coalesce(first_published_at, now()),
         management_version = management_version + 1,
         updated_by_person_id = actor,
         updated_at = now()
   where id = target_form_id;
  update public.form_occurrences
     set form_version_id = form_row.working_version_id,
         management_version = management_version + 1
   where form_occurrences.form_id = target_form_id
     and status = 'scheduled'
     and opens_at > now();
  result := app_private.form_definition_projection(target_form_id);
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id, outcome,
    after_json
  ) values (
    actor, auth.jwt() ->> 'aal', 'forms.publish', 'form', target_form_id,
    form_row.institution_id, 'success', jsonb_build_object('published_version_id', form_row.working_version_id)
  );
  return app_private.form_complete_command(p_request_id, result);
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260813155121_forms_commands_and_projections.sql
create or replace function app_private.form_duplicate(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.manage');
declare source_row public.forms;
declare target_id uuid;
declare replay jsonb;
begin
  perform app_private.form_assert_payload_keys(p_payload, array['form_id'], 'form duplicate');
  perform app_private.superadmin_form_lock_legacy_resource_v2((p_payload ->> 'form_id')::uuid);
  replay := app_private.form_begin_command(p_request_id, actor, 'form_duplicate', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  select * into source_row from public.forms where id = (p_payload ->> 'form_id')::uuid for share;
  perform app_private.superadmin_form_assert_legacy_resource_v2(source_row.id);
  if source_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if source_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  target_id := app_private.form_clone(actor, source_row.id, source_row.institution_id);
  return app_private.form_complete_command(p_request_id, app_private.form_definition_projection(target_id));
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260813155121_forms_commands_and_projections.sql
create or replace function app_private.form_copy_or_move(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.manage');
declare source_row public.forms;
declare target_id uuid;
declare replay jsonb;
declare mode text;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['form_id','target_institution_id','mode'], 'form copy or move'
  );
  mode := p_payload ->> 'mode';
  if mode not in ('copy', 'move') then raise invalid_parameter_value using message = 'invalid transfer mode'; end if;
  perform app_private.superadmin_form_lock_legacy_resource_v2((p_payload ->> 'form_id')::uuid);
  replay := app_private.form_begin_command(p_request_id, actor, 'form_copy_or_move', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  select * into source_row from public.forms where id = (p_payload ->> 'form_id')::uuid for update;
  perform app_private.superadmin_form_assert_legacy_resource_v2(source_row.id);
  if source_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if source_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  if (p_payload ->> 'target_institution_id')::uuid <> source_row.institution_id
     and not app_private.has_platform_permission('forms.transfer_cross_institution') then
    raise insufficient_privilege using message = 'forms.transfer_cross_institution required';
  end if;
  if mode = 'move' and source_row.first_published_at is null
     and not exists(select 1 from public.form_applications where form_id = source_row.id)
     and not exists(select 1 from public.form_responses where form_id = source_row.id) then
    update public.forms
       set institution_id = (p_payload ->> 'target_institution_id')::uuid,
           management_version = management_version + 1,
           updated_by_person_id = actor, updated_at = now()
     where id = source_row.id;
    target_id := source_row.id;
  else
    target_id := app_private.form_clone(
      actor, source_row.id, (p_payload ->> 'target_institution_id')::uuid
    );
  end if;
  return app_private.form_complete_command(p_request_id, app_private.form_definition_projection(target_id));
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260813155121_forms_commands_and_projections.sql
create or replace function app_private.form_archive_or_delete(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.manage');
declare form_row public.forms;
declare replay jsonb;
declare deleted boolean := false;
begin
  perform app_private.form_assert_payload_keys(p_payload, array['form_id','action'], 'form archive or delete');
  perform app_private.superadmin_form_lock_legacy_resource_v2((p_payload ->> 'form_id')::uuid);
  replay := app_private.form_begin_command(p_request_id, actor, 'form_archive_or_delete', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  select * into form_row from public.forms where id = (p_payload ->> 'form_id')::uuid for update;
  perform app_private.superadmin_form_assert_legacy_resource_v2(form_row.id);
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if form_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  if p_payload ->> 'action' = 'delete'
     and form_row.first_published_at is null
     and not exists(select 1 from public.form_applications where form_id = form_row.id)
     and not exists(select 1 from public.form_responses where form_id = form_row.id) then
    delete from public.forms where id = form_row.id;
    deleted := true;
  elsif p_payload ->> 'action' in ('delete', 'archive') then
    update public.forms set status = 'archived', archived_at = now(),
      management_version = management_version + 1, updated_by_person_id = actor, updated_at = now()
    where id = form_row.id;
  else
    raise invalid_parameter_value using message = 'invalid archive action';
  end if;
  return app_private.form_complete_command(
    p_request_id, jsonb_build_object('form_id', form_row.id, 'deleted', deleted)
  );
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260813155121_forms_commands_and_projections.sql
create or replace function app_private.form_clone(
  p_actor uuid,
  p_source_form_id uuid,
  p_target_institution_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare source_row public.forms;
declare source_projection jsonb;
declare target_form_id uuid := gen_random_uuid();
declare target_version_id uuid;
begin
  perform app_private.superadmin_form_lock_legacy_resource_v2(p_source_form_id);
  select * into source_row from public.forms where id = p_source_form_id;
  if source_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if p_target_institution_id <> source_row.institution_id
     and not app_private.has_platform_permission('forms.transfer_cross_institution') then
    raise insufficient_privilege using message = 'forms.transfer_cross_institution required';
  end if;
  source_projection := app_private.form_definition_projection(source_row.id);
  insert into public.forms(
    id, institution_id, kind, status, identity_mode, response_unit, title, description,
    created_by_person_id, updated_by_person_id
  ) values (
    target_form_id, p_target_institution_id, source_row.kind, 'draft', source_row.identity_mode,
    source_row.response_unit, source_row.title || ' (cópia)', source_row.description, p_actor, p_actor
  );
  insert into public.form_versions(form_id, version_number, created_by_person_id)
  values (target_form_id, 1, p_actor) returning id into target_version_id;
  update public.forms set working_version_id = target_version_id where id = target_form_id;
  perform app_private.form_replace_working_definition(target_version_id, source_projection -> 'sections');
  return target_form_id;
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260813155124_forms_jobs_notifications_and_exports.sql
create or replace function app_private.form_request_export(
  p_request_id uuid,
  p_expected_version bigint,
  p_payload jsonb,
  p_anonymous_participation boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor(
  case when p_anonymous_participation
       then 'forms.anonymous_participation.export'
       else 'forms.responses.export' end
);
declare form_row public.forms;
declare job_row public.form_file_jobs;
declare replay jsonb;
declare command_name text := case when p_anonymous_participation
  then 'form_request_anonymous_participation_export' else 'form_request_export' end;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['form_id','occurrence_id','kind','justification'], 'form export'
  );
  perform app_private.superadmin_form_lock_legacy_resource_v2((p_payload ->> 'form_id')::uuid);
  replay := app_private.form_begin_command(
    p_request_id, actor, command_name, p_expected_version, p_payload
  );
  if replay is not null then return replay; end if;
  select * into form_row from public.forms where id = (p_payload ->> 'form_id')::uuid;
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if form_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  if p_anonymous_participation then
    perform app_private.form_require_owner(actor, 'forms.anonymous_participation.export');
    if char_length(btrim(coalesce(p_payload ->> 'justification', ''))) < 10 then
      raise invalid_parameter_value using message = 'auditable justification required';
    end if;
  end if;
  insert into public.form_file_jobs(
    institution_id, form_id, occurrence_id, requested_by_person_id, request_id, export_kind,
    manifest_jsonb
  ) values (
    form_row.institution_id, form_row.id, (p_payload ->> 'occurrence_id')::uuid,
    actor, p_request_id,
    case when p_anonymous_participation then 'anonymous_participation' else p_payload ->> 'kind' end,
    case when p_anonymous_participation
         then jsonb_build_object('justification', btrim(p_payload ->> 'justification'))
         else '{}'::jsonb end
  ) returning * into job_row;
  insert into app_private.form_worker_jobs(job_kind, aggregate_id, payload_jsonb)
  values (
    case job_row.export_kind
      when 'csv' then 'export_csv'
      when 'xlsx' then 'export_xlsx'
      when 'zip' then 'export_zip'
      else 'export_anonymous_participation'
    end,
    job_row.id,
    jsonb_build_object('file_job_id', job_row.id)
  );
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id,
    outcome, reason, after_json
  ) values (
    actor, auth.jwt() ->> 'aal', command_name, 'form_file_job', job_row.id,
    form_row.institution_id, 'success',
    case when p_anonymous_participation then btrim(p_payload ->> 'justification') else null end,
    jsonb_build_object('form_id', form_row.id, 'export_kind', job_row.export_kind)
  );
  return app_private.form_complete_command(p_request_id, jsonb_build_object(
    'id', job_row.id, 'status', job_row.state, 'progress', job_row.progress,
    'download_path', null, 'error_code', null
  ));
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260825193120_final_review_forms_runtime_hardening.sql
CREATE OR REPLACE FUNCTION app_private.form_save_application(p_request_id uuid, p_expected_version bigint, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid := app_private.require_forms_actor('forms.manage_applications');
declare application_row public.form_applications;
declare rule_json jsonb;
declare replay jsonb;
declare application_id uuid := coalesce((p_payload ->> 'id')::uuid, gen_random_uuid());
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['id','form_id','institution_id','name','status','opens_for_days','rules'],
    'form application'
  );
  perform app_private.form_assert_application_payload_limits(p_payload);
  perform app_private.superadmin_form_lock_legacy_resource_v2((p_payload ->> 'form_id')::uuid);
  perform app_private.superadmin_form_lock_legacy_resource_v2((select a.form_id from public.form_applications a where a.id=application_id));
  replay := app_private.form_begin_command(p_request_id, actor, 'form_save_application', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  perform pg_advisory_xact_lock(hashtextextended(application_id::text, 11));
  select * into application_row from public.form_applications where id = application_id for update;
  if application_row.id is null then
    if p_expected_version <> 0 then raise serialization_failure using message = 'expected_version mismatch'; end if;
    insert into public.form_applications(
      id, form_id, institution_id, name, status, opens_for_days, created_by_person_id
    ) values (
      application_id, (p_payload ->> 'form_id')::uuid, (p_payload ->> 'institution_id')::uuid,
      btrim(p_payload ->> 'name'), coalesce(p_payload ->> 'status', 'active'),
      coalesce((p_payload ->> 'opens_for_days')::integer, 7), actor
    ) returning * into application_row;
  else
    if application_row.management_version <> p_expected_version then
      raise serialization_failure using message = 'expected_version mismatch';
    end if;
    update public.form_applications set name = btrim(p_payload ->> 'name'),
      status = coalesce(p_payload ->> 'status', status),
      opens_for_days = coalesce((p_payload ->> 'opens_for_days')::integer, opens_for_days),
      management_version = management_version + 1, updated_at = now()
    where id = application_id returning * into application_row;
  end if;
  delete from public.form_audience_rules audience_rule where audience_rule.application_id = application_row.id;
  for rule_json in select value from jsonb_array_elements(p_payload -> 'rules') loop
    perform app_private.form_assert_payload_keys(
      rule_json, array['kind','mode','target_id','filter','position'], 'form audience rule'
    );
    insert into public.form_audience_rules(
      application_id, institution_id, rule_kind, rule_mode, target_id, filter_jsonb, position
    ) values (
      application_row.id, application_row.institution_id, rule_json ->> 'kind', rule_json ->> 'mode',
      (rule_json ->> 'target_id')::uuid, coalesce(rule_json -> 'filter', '{}'::jsonb),
      (rule_json ->> 'position')::integer
    );
  end loop;
  return app_private.form_complete_command(
    p_request_id, app_private.form_application_projection(application_row.id)
  );
end;
$function$;

-- F-AUTHOR01 guarded effective body from 20260820154638_forms_distribution_cardinality_limits.sql
create or replace function app_private.form_save_schedule(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.manage_applications');
declare schedule_row public.form_schedules;
declare replay jsonb;
declare reminder_json jsonb;
declare target_schedule_id uuid := coalesce((p_payload ->> 'schedule_id')::uuid, gen_random_uuid());
declare target_application_id uuid := (p_payload ->> 'application_id')::uuid;
begin
  perform app_private.form_assert_payload_keys(
    p_payload,
    array['schedule_id','application_id','time_zone','starts_at_local','recurrence_kind','interval','weekdays',
          'monthly_day','monthly_last_day','end_kind','ends_on','occurrence_count','reminders'],
    'form schedule'
  );
  perform app_private.form_assert_schedule_payload_limits(p_payload);
  if not exists(select 1 from pg_timezone_names where name = p_payload ->> 'time_zone') then
    raise invalid_parameter_value using message = 'unknown IANA timezone';
  end if;
  perform app_private.superadmin_form_lock_legacy_resource_v2((select a.form_id from public.form_applications a where a.id=target_application_id));
  perform app_private.superadmin_form_lock_legacy_resource_v2((select a.form_id from public.form_schedules s join public.form_applications a on a.id=s.application_id where s.id=target_schedule_id));
  replay := app_private.form_begin_command(p_request_id, actor, 'form_save_schedule', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  perform pg_advisory_xact_lock(hashtextextended(target_application_id::text, 12));
  select * into schedule_row from public.form_schedules
   where id = target_schedule_id for update;
  if schedule_row.id is not null and schedule_row.application_id <> target_application_id then
    raise no_data_found using message = 'form schedule unavailable';
  end if;
  if schedule_row.id is not null and schedule_row.status <> 'active' then
    raise no_data_found using message = 'form schedule unavailable';
  end if;
  if schedule_row.id is null and p_expected_version <> 0 then
    raise serialization_failure using message = 'expected_version mismatch';
  elsif schedule_row.id is not null and schedule_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  perform app_private.form_assert_schedule_capacity(target_application_id, target_schedule_id);
  insert into public.form_schedules(
    id, application_id, time_zone, starts_at_local, recurrence_kind, interval_value, weekdays,
    monthly_day, monthly_last_day, end_kind, ends_on, occurrence_count
  ) values (
    target_schedule_id, target_application_id, p_payload ->> 'time_zone',
    (p_payload ->> 'starts_at_local')::timestamp, p_payload ->> 'recurrence_kind',
    coalesce((p_payload ->> 'interval')::integer, 1),
    coalesce(array(select jsonb_array_elements_text(p_payload -> 'weekdays')::smallint), '{}'),
    (p_payload ->> 'monthly_day')::smallint,
    coalesce((p_payload ->> 'monthly_last_day')::boolean, false),
    coalesce(p_payload ->> 'end_kind', 'never'), (p_payload ->> 'ends_on')::date,
    (p_payload ->> 'occurrence_count')::integer
  ) on conflict(id) do update set
    time_zone = excluded.time_zone, starts_at_local = excluded.starts_at_local,
    recurrence_kind = excluded.recurrence_kind, interval_value = excluded.interval_value,
    weekdays = excluded.weekdays, monthly_day = excluded.monthly_day,
    monthly_last_day = excluded.monthly_last_day, end_kind = excluded.end_kind,
    ends_on = excluded.ends_on, occurrence_count = excluded.occurrence_count,
    management_version = public.form_schedules.management_version + 1, updated_at = now()
  returning * into schedule_row;
  delete from public.form_schedule_reminders where schedule_id = schedule_row.id;
  for reminder_json in select value from jsonb_array_elements(coalesce(p_payload -> 'reminders', '[]'::jsonb)) loop
    perform app_private.form_assert_payload_keys(reminder_json, array['kind','amount','position'], 'form reminder');
    insert into public.form_schedule_reminders(schedule_id, reminder_kind, amount, position)
    values (schedule_row.id, reminder_json ->> 'kind', (reminder_json ->> 'amount')::integer,
            (reminder_json ->> 'position')::integer);
  end loop;
  insert into app_private.form_worker_jobs(job_kind, aggregate_id, payload_jsonb)
  values ('generate_occurrences', schedule_row.id, jsonb_build_object('schedule_id', schedule_row.id))
  on conflict do nothing;
  return app_private.form_complete_command(
    p_request_id, app_private.form_application_projection(schedule_row.application_id)
  );
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260813155121_forms_commands_and_projections.sql
create or replace function app_private.form_remove_schedule(
  p_request_id uuid, p_expected_version bigint, p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.manage_applications');
declare schedule_row public.form_schedules;
declare replay jsonb;
begin
  perform app_private.form_assert_payload_keys(p_payload, array['schedule_id'], 'remove form schedule');
  perform app_private.superadmin_form_lock_legacy_resource_v2((select a.form_id from public.form_schedules s join public.form_applications a on a.id=s.application_id where s.id=(p_payload ->> 'schedule_id')::uuid));
  replay := app_private.form_begin_command(p_request_id, actor, 'form_remove_schedule', p_expected_version, p_payload);
  if replay is not null then return replay; end if;
  select * into schedule_row from public.form_schedules
   where id = (p_payload ->> 'schedule_id')::uuid for update;
  if schedule_row.id is null then raise no_data_found using message = 'form schedule unavailable'; end if;
  if schedule_row.status <> 'active' then raise no_data_found using message = 'form schedule unavailable'; end if;
  if schedule_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  update public.form_schedules
     set status = 'archived', management_version = management_version + 1, updated_at = now()
   where id = schedule_row.id;
  update public.form_occurrences set status = 'cancelled'
   where schedule_id = schedule_row.id and status = 'scheduled';
  return app_private.form_complete_command(
    p_request_id, app_private.form_application_projection(schedule_row.application_id)
  );
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260813170001_forms_monitor_hierarchy.sql
create or replace function app_private.form_get_monitor(p_query jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.monitor');
declare form_row public.forms;
begin
  perform app_private.form_assert_payload_keys(
    p_query, array['form_id','application_id','occurrence_id','starts_on_or_after','ends_on_or_before','scope_id'],
    'form monitor query'
  );
  perform app_private.superadmin_form_assert_legacy_resource_v2((p_query ->> 'form_id')::uuid);
  select * into form_row from public.forms where id = (p_query ->> 'form_id')::uuid;
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if p_query ->> 'scope_id' is not null and not exists(
    select 1 from public.form_scope_metrics metric
    join public.form_occurrences occurrence on occurrence.id = metric.occurrence_id
     where occurrence.form_id = form_row.id
       and metric.institution_id = form_row.institution_id
       and metric.scope_id = (p_query ->> 'scope_id')::uuid
  ) then
    raise no_data_found using message = 'monitor scope unavailable';
  end if;
  return (
    select jsonb_build_object(
      'eligible_count', coalesce(sum(case when p_query ->> 'scope_id' is null
        then occurrence_metric.eligible_count else scope_metric.eligible_count end), 0),
      'responded_count', coalesce(sum(case when p_query ->> 'scope_id' is null
        then occurrence_metric.responded_count else scope_metric.responded_count end), 0),
      'pending_count', coalesce(sum(case when p_query ->> 'scope_id' is null
        then occurrence_metric.pending_count else scope_metric.pending_count end), 0),
      'is_anonymous', form_row.identity_mode = 'anonymous'
    )
      from public.form_occurrences occurrence
      left join public.form_occurrence_metrics occurrence_metric on occurrence_metric.occurrence_id = occurrence.id
      left join public.form_scope_metrics scope_metric on scope_metric.occurrence_id = occurrence.id
       and scope_metric.scope_id = (p_query ->> 'scope_id')::uuid
     where occurrence.form_id = form_row.id
       and ((p_query ->> 'application_id') is null or occurrence.application_id = (p_query ->> 'application_id')::uuid)
       and ((p_query ->> 'occurrence_id') is null or occurrence.id = (p_query ->> 'occurrence_id')::uuid)
       and ((p_query ->> 'starts_on_or_after') is null or occurrence.opens_at::date >= (p_query ->> 'starts_on_or_after')::date)
       and ((p_query ->> 'ends_on_or_before') is null or occurrence.closes_at::date <= (p_query ->> 'ends_on_or_before')::date)
  );
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260825193120_final_review_forms_runtime_hardening.sql
CREATE OR REPLACE FUNCTION app_private.form_list_monitor_hierarchy(p_query jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid := app_private.require_forms_actor('forms.monitor');
declare form_row public.forms;
declare requested_scope_kind text;
declare wanted_scope_kind text;
declare page_limit integer := least(greatest(coalesce((p_query ->> 'limit')::integer, 25), 1), 100);
declare cursor_label text := p_query ->> 'cursor_label';
declare cursor_id uuid := (p_query ->> 'cursor_id')::uuid;
begin
  perform app_private.form_assert_payload_keys(
    p_query, array['form_id','application_id','occurrence_id','starts_on_or_after','ends_on_or_before',
                    'scope_id','cursor_label','cursor_id','limit'],
    'form monitor hierarchy query'
  );
  perform app_private.superadmin_form_assert_legacy_resource_v2((p_query ->> 'form_id')::uuid);
  select * into form_row from public.forms where id = (p_query ->> 'form_id')::uuid;
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;

  if p_query ->> 'scope_id' is not null then
    select metric.scope_kind into requested_scope_kind
      from public.form_scope_metrics metric
      join public.form_occurrences occurrence on occurrence.id = metric.occurrence_id
     where occurrence.form_id = form_row.id and metric.scope_id = (p_query ->> 'scope_id')::uuid
     limit 1;
    if requested_scope_kind is null then
      raise no_data_found using message = 'monitor scope unavailable';
    end if;
  end if;
  wanted_scope_kind := case
    when requested_scope_kind is null then 'institution'
    when requested_scope_kind = 'institution' then 'unit'
    when requested_scope_kind = 'unit' then 'group'
    when requested_scope_kind = 'group' then 'activity'
    when requested_scope_kind = 'activity' then 'profile'
    else null
  end;
  if wanted_scope_kind is null then
    return jsonb_build_object('items', '[]'::jsonb, 'has_more', false, 'next_cursor', null);
  end if;

  return (
    with scopes as (
      select metric.scope_id, metric.scope_kind,
             case metric.scope_kind
               when 'institution' then (select coalesce(institution.trade_name, institution.legal_name, '') from public.institutions institution where institution.id = metric.scope_id)
               when 'unit' then (select unit.name from public.units unit where unit.id = metric.scope_id and unit.institution_id = form_row.institution_id)
               when 'group' then (select group_row.name from public.groups group_row where group_row.id = metric.scope_id and group_row.institution_id = form_row.institution_id)
               when 'activity' then (select activity.name from public.activity_definitions activity where activity.id = metric.scope_id and activity.institution_id = form_row.institution_id)
               when 'profile' then (select role_row.name from public.institution_roles role_row where role_row.id = metric.scope_id and role_row.institution_id = form_row.institution_id)
             end as label,
             sum(metric.eligible_count)::bigint as eligible_count,
             sum(metric.responded_count)::bigint as responded_count,
             sum(metric.pending_count)::bigint as pending_count
        from public.form_scope_metrics metric
        join public.form_occurrences occurrence on occurrence.id = metric.occurrence_id
       where occurrence.form_id = form_row.id and metric.institution_id = form_row.institution_id
         and metric.scope_kind = wanted_scope_kind
         and (
           requested_scope_kind is null
           or requested_scope_kind = 'institution'
           or (requested_scope_kind = 'unit' and exists(
             select 1 from public.groups group_row
              where group_row.id = metric.scope_id
                and group_row.unit_id = (p_query ->> 'scope_id')::uuid
                and group_row.institution_id = form_row.institution_id
           ))
           or (requested_scope_kind = 'group' and exists(
             select 1 from public.activity_group_links activity_link
              where activity_link.activity_id = metric.scope_id
                and activity_link.group_id = (p_query ->> 'scope_id')::uuid
                and activity_link.institution_id = form_row.institution_id
                and activity_link.status = 'active'
           ))
           or requested_scope_kind = 'activity'
         )
         and ((p_query ->> 'application_id') is null or occurrence.application_id = (p_query ->> 'application_id')::uuid)
         and ((p_query ->> 'occurrence_id') is null or occurrence.id = (p_query ->> 'occurrence_id')::uuid)
         and ((p_query ->> 'starts_on_or_after') is null or occurrence.opens_at::date >= (p_query ->> 'starts_on_or_after')::date)
         and ((p_query ->> 'ends_on_or_before') is null or occurrence.closes_at::date <= (p_query ->> 'ends_on_or_before')::date)
       group by metric.scope_id, metric.scope_kind
    ), page as (
      select * from scopes
       where label is not null
         and (cursor_label is null or (lower(label), scope_id) > (lower(cursor_label), cursor_id))
       order by lower(label), scope_id limit page_limit + 1
    ), visible as (select * from page limit page_limit)
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'scope_id', scope_id, 'scope_kind', scope_kind, 'label', label,
        'eligible_count', eligible_count, 'responded_count', responded_count, 'pending_count', pending_count
      ) order by lower(label), scope_id), '[]'::jsonb),
      'has_more', (select count(*) > page_limit from page),
      'next_cursor', (select jsonb_build_object('label', label, 'id', scope_id)
                        from visible order by lower(label) desc, scope_id desc limit 1)
    ) from visible
  );
end;
$function$;

-- F-AUTHOR01 guarded effective body from 20260813155121_forms_commands_and_projections.sql
create or replace function app_private.form_list_monitor_people(p_query jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.monitor');
declare form_row public.forms;
declare page_limit integer := least(greatest(coalesce((p_query ->> 'limit')::integer, 25), 1), 100);
begin
  perform app_private.form_assert_payload_keys(
    p_query, array[
      'form_id','application_id','occurrence_id','starts_on_or_after','ends_on_or_before','scope_id',
      'justification','cursor_name','cursor_id','limit'
    ],
    'form monitor people query'
  );
  perform app_private.superadmin_form_assert_legacy_resource_v2((p_query ->> 'form_id')::uuid);
  select * into form_row from public.forms where id = (p_query ->> 'form_id')::uuid;
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if form_row.identity_mode = 'anonymous' then
    perform app_private.form_require_owner(actor, 'forms.anonymous_participation.read');
    if char_length(btrim(coalesce(p_query ->> 'justification', ''))) < 10 then
      raise invalid_parameter_value using message = 'auditable justification required';
    end if;
  end if;
  return (
    with page as (
      select participation.id, coalesce(person.id, responder_person.id) as person_id,
             coalesce(person.display_name, responder_person.display_name) as display_name,
             membership.role_code as profile_label,
             participation.response_unit_key as context_label,
             participation.response_state = 'responded' as responded
        from public.form_participations participation
        join public.form_occurrences occurrence_row on occurrence_row.id = participation.occurrence_id
        left join public.people person on person.id = participation.person_id
        left join public.form_participation_responders responder on responder.participation_id = participation.id
        left join public.people responder_person on responder_person.id = responder.person_id
        left join public.institution_memberships membership
          on membership.person_id = coalesce(person.id, responder_person.id)
         and membership.institution_id = participation.institution_id and membership.status = 'active'
       where occurrence_row.form_id = form_row.id
         and ((p_query ->> 'application_id') is null
              or occurrence_row.application_id = (p_query ->> 'application_id')::uuid)
         and ((p_query ->> 'occurrence_id') is null or occurrence_row.id = (p_query ->> 'occurrence_id')::uuid)
         and ((p_query ->> 'starts_on_or_after') is null
              or occurrence_row.opens_at::date >= (p_query ->> 'starts_on_or_after')::date)
         and ((p_query ->> 'ends_on_or_before') is null
              or occurrence_row.closes_at::date <= (p_query ->> 'ends_on_or_before')::date)
         and participation.eligibility_state = 'eligible'
         and ((p_query ->> 'cursor_name') is null
              or (lower(coalesce(person.display_name, responder_person.display_name)), participation.id)
                 > (lower(p_query ->> 'cursor_name'), (p_query ->> 'cursor_id')::uuid))
       order by lower(coalesce(person.display_name, responder_person.display_name)), participation.id
       limit page_limit + 1
    ), visible as (select * from page limit page_limit)
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'person_id', person_id, 'display_name', display_name, 'profile_label', profile_label,
        'context_label', context_label, 'responded', responded
      )), '[]'::jsonb),
      'has_more', (select count(*) > page_limit from page),
      'next_cursor', (select jsonb_build_object('name', display_name, 'id', id)
                        from visible order by lower(display_name) desc, id desc limit 1)
    ) from visible
  );
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260813155124_forms_jobs_notifications_and_exports.sql
create or replace function app_private.form_anonymous_participation_lookup(p_query jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.anonymous_participation.read');
declare result jsonb;
begin
  perform app_private.form_assert_payload_keys(
    p_query, array['form_id','occurrence_id','justification','cursor_name','cursor_id','limit'],
    'anonymous participation query'
  );
  perform app_private.form_require_owner(actor, 'forms.anonymous_participation.read');
  if char_length(btrim(coalesce(p_query ->> 'justification', ''))) < 10 then
    raise invalid_parameter_value using message = 'auditable justification required';
  end if;
  perform app_private.superadmin_form_assert_legacy_resource_v2((p_query ->> 'form_id')::uuid);
  if not exists(
    select 1 from public.forms where id = (p_query ->> 'form_id')::uuid and identity_mode = 'anonymous'
  ) then
    raise no_data_found using message = 'anonymous form unavailable';
  end if;
  result := app_private.form_list_monitor_people(p_query);
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id,
    outcome, reason, after_json
  )
  select actor, auth.jwt() ->> 'aal', 'forms.anonymous_participation.read', 'form', form_row.id,
         form_row.institution_id, 'success', btrim(p_query ->> 'justification'),
         jsonb_build_object('occurrence_id', p_query ->> 'occurrence_id')
    from public.forms form_row where form_row.id = (p_query ->> 'form_id')::uuid;
  return result;
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260901194209_forms_distribution_target_authorization.sql
create or replace function public.form_save_application(
  p_request_id uuid,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.current_person_id();
  application_id uuid := (p_payload ->> 'id')::uuid;
  target_form_id uuid := (p_payload ->> 'form_id')::uuid;
  target_institution_id uuid := (p_payload ->> 'institution_id')::uuid;
  existing_application public.form_applications;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;

  if app_private.superadmin_form_is_internal_draft_v2(target_form_id) then
    raise invalid_parameter_value using message='form and institution must match';
  end if;
  if exists(select 1 from public.form_applications a where a.id=application_id
    and app_private.superadmin_form_is_internal_draft_v2(a.form_id)) then
    raise no_data_found using message='form application unavailable';
  end if;
  if application_id is not null then
    select * into existing_application
    from public.form_applications
    where id = application_id;
    if existing_application.id is null then
      raise no_data_found using message = 'form application unavailable';
    end if;
    if existing_application.form_id <> target_form_id
       or existing_application.institution_id <> target_institution_id then
      raise invalid_parameter_value using message = 'form application target cannot change';
    end if;
  end if;

  perform app_private.form_assert_distribution_target(actor, target_form_id, target_institution_id);
  return app_private.form_save_application(p_request_id, p_expected_version, p_payload);
end;
$$;

-- F-AUTHOR01 guarded effective body from 20260901194209_forms_distribution_target_authorization.sql
create or replace function public.form_save_schedule(
  p_request_id uuid,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.current_person_id();
  application_row public.form_applications;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  select * into application_row
  from public.form_applications
  where id = (p_payload ->> 'application_id')::uuid;
  if application_row.id is null or app_private.superadmin_form_is_internal_draft_v2(application_row.form_id) then
    raise no_data_found using message = 'form application unavailable';
  end if;
  perform app_private.form_assert_distribution_target(
    actor, application_row.form_id, application_row.institution_id
  );
  return app_private.form_save_schedule(p_request_id, p_expected_version, p_payload);
end;
$$;

create function app_private.superadmin_forms_editor_v2(p_form_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $function$
declare
  ctx app_private.superadmin_internal_context;
  initial_ctx app_private.superadmin_internal_context;
  f public.forms;
  correlation uuid:=pg_catalog.gen_random_uuid();
  permission text:='forms.manage';
  error_code text;
  result jsonb;
begin
  begin
    begin
      select * into strict ctx from app_private.require_superadmin_internal_context(permission);
    exception when insufficient_privilege then
      get stacked diagnostics error_code=pg_exception_detail;
      if error_code is distinct from 'SAI_PERMISSION_DENIED' then raise; end if;
      permission:='forms.read';
      select * into strict ctx from app_private.require_superadmin_internal_context(permission);
      error_code:=null;
    end;
    if ctx.aal is null or ctx.aal not in ('aal1','aal2') or ctx.scope_kind is null or ctx.scope_kind not in ('platform','institution')
      or (ctx.scope_kind='institution' and ctx.scope_institution_id is null) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    initial_ctx:=ctx;
    if pg_catalog.current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_form_id is null then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
    select * into f from public.forms where id=p_form_id
      and (ctx.scope_kind='platform' or institution_id=ctx.scope_institution_id) for share;
    perform 1 from public.institutions i where i.id=f.institution_id and i.deleted_at is null for share;
    if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    -- A new SPI statement in this VOLATILE function gets a fresh READ COMMITTED
    -- snapshot after all explicit waits. Keep the originally selected capability.
    select * into strict ctx from app_private.require_superadmin_internal_context(permission);
    if row(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.auth_user_id,ctx.session_id,
           ctx.scope_kind,ctx.scope_institution_id)
       is distinct from row(initial_ctx.internal_identity_id,initial_ctx.internal_auth_link_id,initial_ctx.internal_membership_id,
           initial_ctx.auth_user_id,initial_ctx.session_id,initial_ctx.scope_kind,initial_ctx.scope_institution_id)
      or ctx.aal is null or ctx.aal not in ('aal1','aal2') or ctx.scope_kind is null or ctx.scope_kind not in ('platform','institution')
      or (ctx.scope_kind='institution' and (ctx.scope_institution_id is null or f.institution_id is distinct from ctx.scope_institution_id)) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    if not exists(select 1 from auth.sessions s where s.id=initial_ctx.session_id and s.user_id=initial_ctx.auth_user_id
      and (s.not_after is null or s.not_after>pg_catalog.clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_SESSION_INVALID';
    end if;
    if f.id is null or f.created_by_internal_identity_id is null or f.status<>'draft'
      or f.first_published_at is not null or f.published_version_id is not null
      or exists(select 1 from public.form_versions v where v.form_id=f.id and (v.state<>'working' or v.published_at is not null))
      or exists(select 1 from public.form_applications a where a.form_id=f.id)
      or exists(select 1 from public.form_occurrences o where o.form_id=f.id)
      or exists(select 1 from public.form_file_jobs j where j.form_id=f.id) then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    result:=pg_catalog.jsonb_build_object('definition',app_private.form_definition_projection(f.id),'application',null);
  exception
    when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
    when others then
      get stacked diagnostics error_code=pg_exception_detail;
      error_code:=app_private.superadmin_internal_error_envelope(error_code,correlation)#>>'{error,code}';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(permission,'superadmin.forms.editor',error_code,correlation);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,permission,ctx.aal,'superadmin.forms.editor','success',null,correlation,f.institution_id);
  return pg_catalog.jsonb_build_object('ok',true,'data',result,'error',null);
end
$function$;

create function app_private.superadmin_forms_save_draft_v2(p_request_id uuid,p_expected_version bigint,p_payload jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $function$
declare
  ctx app_private.superadmin_internal_context;
  initial_ctx app_private.superadmin_internal_context;
  f public.forms;
  receipt app_private.superadmin_internal_form_draft_receipts;
  correlation uuid:=pg_catalog.gen_random_uuid();
  error_code text;
  target_id uuid;
  target_institution uuid;
  working_id uuid;
  request_hash bytea;
  result jsonb;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.manage');
    if ctx.aal is null or ctx.aal not in ('aal1','aal2') or ctx.scope_kind is null or ctx.scope_kind not in ('platform','institution')
      or (ctx.scope_kind='institution' and ctx.scope_institution_id is null) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    initial_ctx:=ctx;
    if pg_catalog.current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_request_id is null or p_expected_version is null or p_expected_version<0 then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    perform app_private.superadmin_form_validate_draft_payload_v2(p_payload);
    target_institution:=(p_payload->>'institution_id')::uuid;
    if (ctx.scope_kind='institution' and target_institution is distinct from ctx.scope_institution_id)
      or not exists(select 1 from public.institutions i where i.id=target_institution and i.deleted_at is null) then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    request_hash:=extensions.digest(pg_catalog.convert_to(p_expected_version::text||':'||p_payload::text,'UTF8'),'sha256');
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,6404));
    -- The request lock can wait before even the private receipt lookup.
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.manage');
    if row(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.auth_user_id,ctx.session_id,
           ctx.scope_kind,ctx.scope_institution_id)
       is distinct from row(initial_ctx.internal_identity_id,initial_ctx.internal_auth_link_id,initial_ctx.internal_membership_id,
           initial_ctx.auth_user_id,initial_ctx.session_id,initial_ctx.scope_kind,initial_ctx.scope_institution_id)
      or ctx.aal is null or ctx.aal not in ('aal1','aal2') or ctx.scope_kind is null or ctx.scope_kind not in ('platform','institution')
      or (ctx.scope_kind='institution' and (ctx.scope_institution_id is null or target_institution is distinct from ctx.scope_institution_id)) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    if not exists(select 1 from auth.sessions s where s.id=initial_ctx.session_id and s.user_id=initial_ctx.auth_user_id
      and (s.not_after is null or s.not_after>pg_catalog.clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_SESSION_INVALID';
    end if;
    select * into receipt from app_private.superadmin_internal_form_draft_receipts where request_id=p_request_id;
    if receipt.request_id is not null then
      if receipt.actor_internal_identity_id is distinct from ctx.internal_identity_id
        or receipt.institution_id is distinct from target_institution
        or receipt.expected_version is distinct from p_expected_version
        or receipt.request_hash is distinct from request_hash then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
      target_id:=receipt.form_id;
    else
      target_id:=coalesce((p_payload->>'id')::uuid,pg_catalog.gen_random_uuid());
    end if;
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(target_id::text,0));
    select * into f from public.forms where id=target_id for update;
    perform 1 from public.institutions i where i.id=target_institution and i.deleted_at is null for share;
    if not found then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    -- Reauthorize after request, form-row and institution waits, before exposing
    -- a receipt snapshot or writing. Never migrate the in-flight actor/context.
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.manage');
    if row(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.auth_user_id,ctx.session_id,
           ctx.scope_kind,ctx.scope_institution_id)
       is distinct from row(initial_ctx.internal_identity_id,initial_ctx.internal_auth_link_id,initial_ctx.internal_membership_id,
           initial_ctx.auth_user_id,initial_ctx.session_id,initial_ctx.scope_kind,initial_ctx.scope_institution_id)
      or ctx.aal is null or ctx.aal not in ('aal1','aal2') or ctx.scope_kind is null or ctx.scope_kind not in ('platform','institution')
      or (ctx.scope_kind='institution' and (ctx.scope_institution_id is null or target_institution is distinct from ctx.scope_institution_id)) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    if not exists(select 1 from auth.sessions s where s.id=initial_ctx.session_id and s.user_id=initial_ctx.auth_user_id
      and (s.not_after is null or s.not_after>pg_catalog.clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_SESSION_INVALID';
    end if;
    if f.id is not null then
      if f.institution_id is distinct from target_institution or f.created_by_internal_identity_id is null or f.status<>'draft'
        or f.first_published_at is not null or f.published_version_id is not null
        or exists(select 1 from public.form_versions v where v.form_id=f.id and (v.state<>'working' or v.published_at is not null))
        or exists(select 1 from public.form_applications a where a.form_id=f.id)
        or exists(select 1 from public.form_occurrences o where o.form_id=f.id)
        or exists(select 1 from public.form_file_jobs j where j.form_id=f.id) then
        raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
      end if;
    elsif receipt.request_id is not null then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    if receipt.request_id is not null then
      result:=receipt.result_jsonb;
    else
      if f.id is null then
        if p_expected_version<>0 then raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
        insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,description,
          created_by_internal_identity_id,updated_by_internal_identity_id)
        values(target_id,target_institution,p_payload->>'kind',p_payload->>'identity_mode',p_payload->>'response_unit',
          btrim(p_payload->>'title'),nullif(btrim(p_payload->>'description'),''),ctx.internal_identity_id,ctx.internal_identity_id)
        returning * into f;
        insert into public.form_versions(form_id,version_number,created_by_internal_identity_id)
        values(f.id,1,ctx.internal_identity_id) returning id into working_id;
        update public.forms set working_version_id=working_id where id=f.id;
      else
        if f.management_version is distinct from p_expected_version then raise serialization_failure using detail='SAI_CONCURRENT_CHANGE'; end if;
        working_id:=f.working_version_id;
        if working_id is null or not exists(select 1 from public.form_versions v where v.id=working_id and v.form_id=f.id and v.state='working') then
          raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
        end if;
        update public.forms set kind=p_payload->>'kind',identity_mode=p_payload->>'identity_mode',response_unit=p_payload->>'response_unit',
          title=btrim(p_payload->>'title'),description=nullif(btrim(p_payload->>'description'),''),management_version=management_version+1,
          updated_by_person_id=null,updated_by_internal_identity_id=ctx.internal_identity_id,updated_at=pg_catalog.now()
        where id=f.id;
      end if;
      perform app_private.superadmin_form_replace_draft_definition_v2(working_id,p_payload->'sections');
      result:=app_private.form_definition_projection(f.id);
      insert into app_private.superadmin_internal_form_draft_receipts(request_id,actor_internal_identity_id,form_id,institution_id,expected_version,request_hash,result_jsonb)
      values(p_request_id,ctx.internal_identity_id,f.id,target_institution,p_expected_version,request_hash,result);
    end if;
  exception
    when invalid_parameter_value or invalid_text_representation or numeric_value_out_of_range or check_violation or not_null_violation or foreign_key_violation or unique_violation then
      error_code:='SAI_INVALID_ARGUMENT';
    when serialization_failure then error_code:='SAI_CONCURRENT_CHANGE';
    when others then
      get stacked diagnostics error_code=pg_exception_detail;
      error_code:=app_private.superadmin_internal_error_envelope(error_code,correlation)#>>'{error,code}';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified('forms.manage','superadmin.forms.draft.save',error_code,correlation);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  -- Intentionally outside the inner exception block: audit failure rolls back
  -- business changes AND receipt rather than returning an unaudited denial.
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'forms.manage',ctx.aal,'superadmin.forms.draft.save','success',null,correlation,target_institution);
  return pg_catalog.jsonb_build_object('ok',true,'data',result,'error',null);
end
$function$;

create function public.superadmin_forms_editor_v2(p_form_id uuid)
returns jsonb language sql volatile security definer set search_path='' as $function$
  select app_private.superadmin_forms_editor_v2(p_form_id);
$function$;
create function public.superadmin_forms_save_draft_v2(p_request_id uuid,p_expected_version bigint,p_payload jsonb)
returns jsonb language sql volatile security definer set search_path='' as $function$
  select app_private.superadmin_forms_save_draft_v2(p_request_id,p_expected_version,p_payload);
$function$;

do $acl$
declare signature text;
begin
  foreach signature in array array[
    'app_private.superadmin_form_is_internal_draft_v2(uuid)',
    'app_private.superadmin_form_assert_legacy_resource_v2(uuid)',
    'app_private.superadmin_form_lock_legacy_resource_v2(uuid)',
    'app_private.superadmin_form_validate_draft_payload_v2(jsonb)',
    'app_private.superadmin_form_validate_draft_definition_v2(uuid)',
    'app_private.superadmin_form_replace_draft_definition_v2(uuid,jsonb)',
    'app_private.superadmin_forms_editor_v2(uuid)',
    'app_private.superadmin_forms_save_draft_v2(uuid,bigint,jsonb)',
    'public.superadmin_forms_editor_v2(uuid)',
    'public.superadmin_forms_save_draft_v2(uuid,bigint,jsonb)'
  ] loop
    execute 'alter function '||signature||' owner to postgres';
    execute 'revoke all on function '||signature||' from public,anon,authenticated,service_role';
  end loop;
end
$acl$;
grant execute on function public.superadmin_forms_editor_v2(uuid) to authenticated;
grant execute on function public.superadmin_forms_save_draft_v2(uuid,bigint,jsonb) to authenticated;
comment on function public.superadmin_forms_save_draft_v2(uuid,bigint,jsonb) is
  'F-AUTHOR01 internal draft-only command with real internal authors, reauthorized private receipts and mandatory audit; no publication/distribution/media.';
comment on function app_private.superadmin_form_is_internal_draft_v2(uuid) is
  'Temporary nominal coexistence for internally-created never-published drafts, not a permanent audience or author authorization policy.';
commit;
