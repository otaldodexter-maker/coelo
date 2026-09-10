begin;

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
      and form_record.deleted_at is null
  ) then
    raise invalid_parameter_value using message = 'form and institution must match';
  end if;

  if not app_private.audit_actor_has_permission(p_actor, 'forms.manage', p_institution_id, false) then
    raise insufficient_privilege using message = 'form distribution institution unavailable';
  end if;
end;
$$;

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
  if application_row.id is null then
    raise no_data_found using message = 'form application unavailable';
  end if;
  perform app_private.form_assert_distribution_target(
    actor, application_row.form_id, application_row.institution_id
  );
  return app_private.form_save_schedule(p_request_id, p_expected_version, p_payload);
end;
$$;

revoke all on function app_private.form_assert_distribution_target(uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.form_save_application(uuid, bigint, jsonb) from public, anon;
revoke all on function public.form_save_schedule(uuid, bigint, jsonb) from public, anon;
grant execute on function public.form_save_application(uuid, bigint, jsonb) to authenticated;
grant execute on function public.form_save_schedule(uuid, bigint, jsonb) to authenticated;

commit;
