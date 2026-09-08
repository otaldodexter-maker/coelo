-- F-AUTHOR03-SAFE: candidate only. Eng1 owns nominal local replay.
-- Exactly two existing bodies; no publishing endpoint or realm policy added.
begin;

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'Forms provenance repair requires postgres';
  end if;
  if pg_catalog.to_regprocedure('app_private.form_assert_distribution_target(uuid,uuid,uuid)') is null
    or pg_catalog.to_regprocedure('app_private.block_published_form_definition_mutation()') is null
    or not exists (
      select 1 from pg_catalog.pg_attribute
      where attrelid = 'public.form_versions'::regclass
        and attname = 'created_by_internal_identity_id' and not attisdropped
    ) then
    raise object_not_in_prerequisite_state using message = 'Forms provenance repair requires F-AUTHOR01 and both historical functions';
  end if;
end
$preflight$;

create or replace function app_private.form_assert_distribution_target(
  p_actor uuid,
  p_form_id uuid,
  p_institution_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.forms form_record
    where form_record.id = p_form_id
      and form_record.institution_id = p_institution_id
  ) then
    raise invalid_parameter_value using message = 'form and institution must match';
  end if;

  if not app_private.audit_actor_has_permission(p_actor, 'forms.manage', p_institution_id, false) then
    raise insufficient_privilege using message = 'form distribution institution unavailable';
  end if;
end;
$$;

create or replace function app_private.block_published_form_definition_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare version_id uuid;
begin
  if tg_table_name = 'form_versions' then
    if tg_op = 'DELETE' and old.state <> 'working' then
      raise insufficient_privilege using message = 'published form version is immutable';
    end if;
    if tg_op = 'UPDATE' then
      if old.form_id <> new.form_id
         or old.version_number <> new.version_number
         or old.created_by_person_id is distinct from new.created_by_person_id
         or old.created_by_internal_identity_id is distinct from new.created_by_internal_identity_id
         or old.created_at <> new.created_at
         or not (
           (old.state = 'working' and new.state = 'published' and new.published_at is not null)
           or (old.state = 'published' and new.state = 'superseded' and new.published_at = old.published_at)
         ) then
        raise insufficient_privilege using message = 'published form version is immutable';
      end if;
    end if;
    return coalesce(new, old);
  end if;
  version_id := coalesce(new.form_version_id, old.form_version_id);
  if exists(select 1 from public.form_versions where id = version_id and state <> 'working') then
    raise insufficient_privilege using message = 'published form version is immutable';
  end if;
  return coalesce(new, old);
end;
$$;

-- CREATE OR REPLACE retains existing identities, owners and ACLs.
-- Do not recreate triggers, change grants, XOR/FKs, wrappers or other writers.
commit;
