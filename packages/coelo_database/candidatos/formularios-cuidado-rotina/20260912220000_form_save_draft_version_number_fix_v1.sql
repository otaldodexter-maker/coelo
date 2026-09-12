-- R06 formularios-cuidado-rotina: form_save_draft respondia 42702
-- ("column reference version_number is ambiguous") ao salvar o rascunho de um
-- formulario ja publicado (working_version_id nulo), porque a variavel
-- version_number tinha o mesmo nome da coluna de form_versions no
-- select ... into. Medido na rota real em 11/09/2026 (forms.location-question
-- sobre o formulario 4555ba07 publicado). Mesmo corpo do 230004, so com a
-- variavel renomeada e o alias na consulta; sem mudanca de contrato.
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
  next_version_number integer;
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
    next_version_number := 1;
    insert into public.form_versions(form_id, version_number, created_by_person_id)
    values (target_form_id, next_version_number, actor)
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
      select coalesce(max(fv.version_number), 0) + 1 into next_version_number
        from public.form_versions fv where fv.form_id = form_row.id;
      insert into public.form_versions(form_id, version_number, created_by_person_id)
      values (target_form_id, next_version_number, actor)
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
