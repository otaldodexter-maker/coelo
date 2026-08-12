-- Close application-save scope gaps: model inheritance and responsible memberships
-- are validated in the database even when callers bypass Flutter.

create or replace function app_private.validate_routine_application_hierarchy()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  unit_institution uuid;
  group_unit uuid;
  group_institution uuid;
  parent_row public.routine_applications;
  model_row public.routine_models;
begin
  if new.unit_id is not null then
    select institution_id into unit_institution from public.units where id = new.unit_id;
  end if;
  if new.group_id is not null then
    select unit_id, institution_id into group_unit, group_institution
    from public.groups where id = new.group_id;
  end if;
  if unit_institution is distinct from new.institution_id
     or (new.group_id is not null and
       (group_unit is distinct from new.unit_id or group_institution is distinct from new.institution_id)) then
    raise check_violation using message = 'routine application hierarchy mismatch';
  end if;

  select m.* into model_row
  from public.routine_model_versions v
  join public.routine_models m on m.id = v.model_id
  where v.id = new.source_model_version_id;
  if model_row.id is null
     or (model_row.origin_scope_kind = 'institution' and model_row.institution_id <> new.institution_id)
     or (model_row.origin_scope_kind = 'unit' and
       (model_row.institution_id <> new.institution_id or model_row.origin_unit_id is distinct from new.unit_id)) then
    raise check_violation using message = 'routine model application hierarchy mismatch';
  end if;

  if new.parent_application_id is not null then
    select * into parent_row
    from public.routine_applications
    where id = new.parent_application_id;
    if parent_row.id is null
       or parent_row.institution_id <> new.institution_id
       or parent_row.source_model_version_id <> new.source_model_version_id
       or (new.scope_kind = 'unit' and parent_row.scope_kind <> 'institution')
       or (new.scope_kind = 'group' and parent_row.scope_kind not in ('institution', 'unit'))
       or (new.scope_kind = 'group' and parent_row.scope_kind = 'unit'
         and parent_row.unit_id is distinct from new.unit_id) then
      raise check_violation using message = 'routine application inheritance mismatch';
    end if;
  end if;
  return new;
end $$;

create or replace function app_private.validate_routine_assignee()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  application_row public.routine_applications;
  membership_row public.institution_memberships;
begin
  select * into application_row
  from public.routine_applications
  where id = new.application_id
    and institution_id = new.institution_id;
  select * into membership_row
  from public.institution_memberships
  where id = new.membership_id
    and institution_id = new.institution_id
    and status = 'active'
    and revoked_at is null;

  if application_row.id is null or membership_row.id is null
     or (membership_row.scope_kind = 'unit' and
       (application_row.unit_id is null or membership_row.scope_unit_id is distinct from application_row.unit_id))
     or (membership_row.scope_kind = 'group' and
       (application_row.group_id is null or membership_row.scope_group_id is distinct from application_row.group_id))
     or membership_row.scope_kind not in ('institution', 'unit', 'group') then
    raise check_violation using message = 'routine assignee scope mismatch';
  end if;
  return new;
end $$;

revoke all on function app_private.validate_routine_application_hierarchy() from public, anon, authenticated;
revoke all on function app_private.validate_routine_assignee() from public, anon, authenticated;
