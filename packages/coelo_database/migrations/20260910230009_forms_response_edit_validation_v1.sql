-- C02 / I008. Forward-only candidate; no remote application authorized.
-- Preserve the canonical mutation; require visible answers on submitted edits.
-- Existing authorization, anonymous replay, locking, versions and audit are unchanged.
begin;

CREATE OR REPLACE FUNCTION app_private.form_mutate_response(p_command text, p_request_id uuid, p_expected_version bigint, p_payload jsonb, p_submit boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid := app_private.require_forms_actor('forms.respond');
declare response_row public.form_responses;
declare occurrence_row public.form_occurrences;
declare participation_row public.form_participations;
declare replay jsonb;
declare revision_number integer;
declare result jsonb;
declare expected_action text;
begin
  perform app_private.form_assert_payload_keys(
    p_payload, array['response_id','participation_id','edit_secret','answers'], 'form response mutation'
  );
  select * into response_row from public.form_responses
   where id = (p_payload ->> 'response_id')::uuid for update;
  if response_row.id is null then raise no_data_found using message = 'form response unavailable'; end if;
  perform app_private.form_assert_response_actor(response_row, actor, p_payload ->> 'edit_secret');
  if response_row.identity_mode = 'identified' then
    replay := app_private.form_begin_command(
      p_request_id, actor, p_command, p_expected_version, p_payload
    );
    if replay is not null then return replay; end if;
  else
    expected_action := case when p_submit then 'submitted'
      when p_command = 'form_edit_response' then 'edited' else 'draft_saved' end;
    if response_row.management_version = p_expected_version + 1
       and exists (
         select 1 from public.form_response_revisions revision
          where revision.response_id = response_row.id
            and revision.action = expected_action
            and revision.answers_snapshot = p_payload -> 'answers'
       ) then
      return app_private.form_response_draft_projection(response_row.id);
    end if;
  end if;
  if response_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  select * into occurrence_row from public.form_occurrences
   where id = response_row.occurrence_id for update;
  if occurrence_row.status <> 'open' or now() not between occurrence_row.opens_at and occurrence_row.closes_at then
    raise no_data_found using message = 'form occurrence unavailable';
  end if;
  select participation.* into participation_row
    from public.form_participations participation
   where participation.id = (p_payload ->> 'participation_id')::uuid
     and participation.occurrence_id = response_row.occurrence_id
     and participation.eligibility_state = 'eligible'
     and (
       participation.person_id = actor
       or exists(select 1 from public.form_participation_responders responder
                 where responder.participation_id = participation.id and responder.person_id = actor)
     )
   for update;
  if participation_row.id is null then
    raise no_data_found using message = 'form participation unavailable';
  end if;
  if p_submit and response_row.status <> 'draft' then
    raise check_violation using message = 'only a draft response can be submitted';
  end if;
  if p_command = 'form_edit_response' and response_row.status <> 'submitted' then
    raise check_violation using message = 'only a submitted response can be edited';
  end if;
  if p_command = 'form_save_response_draft' and response_row.status <> 'draft' then
    raise check_violation using message = 'only a draft response can be saved';
  end if;
  perform app_private.form_replace_response_answers(
    response_row, p_payload -> 'answers', p_payload ->> 'edit_secret'
  );
  if p_submit or p_command = 'form_edit_response' then
    perform app_private.form_assert_required_response_answers(response_row);
  end if;
  if p_submit then
    if participation_row.response_state = 'responded' then
      raise no_data_found using message = 'form participation unavailable';
    end if;
    update public.form_responses
       set status = 'submitted', submitted_at = now(), updated_at = now(),
           management_version = management_version + 1
     where id = response_row.id returning * into response_row;
    update public.form_participations
       set response_state = 'responded', responded_at = now()
     where id = participation_row.id;
    perform app_private.form_rebuild_occurrence_metrics(response_row.occurrence_id);
  else
    update public.form_responses
       set updated_at = now(), management_version = management_version + 1
     where id = response_row.id returning * into response_row;
  end if;
  select coalesce(max(revision_row.revision_number), 0) + 1 into revision_number
    from public.form_response_revisions revision_row where revision_row.response_id = response_row.id;
  insert into public.form_response_revisions(
    response_id, revision_number, action, answers_snapshot, changed_by_person_id
  ) values (
    response_row.id, revision_number,
    case when p_submit then 'submitted'
         when p_command = 'form_edit_response' then 'edited'
         else 'draft_saved' end,
    p_payload -> 'answers', case when response_row.identity_mode = 'identified' then actor else null end
  );
  result := app_private.form_response_draft_projection(response_row.id);
  if response_row.identity_mode = 'anonymous' then return result; end if;
  return app_private.form_complete_command(p_request_id, result);
end;
$function$;

revoke all on function app_private.form_mutate_response(text, uuid, bigint, jsonb, boolean) from public, anon, authenticated;
commit;
