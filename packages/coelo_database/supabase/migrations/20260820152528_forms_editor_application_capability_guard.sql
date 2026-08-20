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
   where form_row.id = p_form_id;

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

revoke all on function app_private.form_get_editor(uuid)
  from public, anon, authenticated;
revoke all on function public.form_get_editor(uuid) from public, anon;
grant execute on function public.form_get_editor(uuid) to authenticated;
