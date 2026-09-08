-- Local parser proof only; both CREATE statements run on one server/transaction.
-- Full migration: 20260813155005_forms_definition_and_capabilities.sql
-- Source SHA256 (CRLF UTF-8): 3a3d2bd348948cdef78a3a0c712c9eae8a6a6fb8be59b8fd942a445f6cbb6e36
-- Derived SHA256 (CRLF UTF-8): 06b71570bbb25c84efe5efed6a6d1f2416a33a5a6fdf71bc20b4776d01833dfe
-- Only delta: parenthesize the two CASE expressions at source lines 105-107/145-146.
-- No migration replay, seed, privilege change or validation bypass is performed here.
begin;

create extension if not exists pgtap with schema extensions;
create schema if not exists app_private;

select plan(3);
select ok(current_user = 'postgres' and current_setting('server_version_num')::integer between 170000 and 179999, 'parser proof runs under postgres on PostgreSQL 17');
select diag('server_version_num=' || current_setting('server_version_num'));

select throws_ok(
$original_sql$
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
$original_sql$,
  '42601',
  null::text,
  'the unchanged canonical CREATE raises syntax_error'
);

select lives_ok(
$corrected_sql$
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
    if p_config - (case when p_kind = 'decimal' then array['min_value','max_value','decimal_places']
                       when p_kind = 'money' then array['min_value','max_value','currency']
                       else array['min_value','max_value'] end) <> '{}'::jsonb
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
    if p_config - (case when p_kind = 'photo' then array['allow_camera','min_images','max_images']
                       else array['allow_existing','min_images','max_images'] end) <> '{}'::jsonb
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
$corrected_sql$,
  'the identical CREATE with four parentheses compiles'
);

select * from finish();
rollback;
