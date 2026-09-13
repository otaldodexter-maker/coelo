-- Adapter scoped to Turmas: delegates the actual write to the canonical
-- student-link command, which retains its authorization, hierarchy, receipt,
-- and audit guarantees. It never creates an institutional membership.
create or replace function public.superadmin_group_student_link(
  p_request_id uuid,
  p_person_id uuid,
  p_group_id uuid
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  resolved_child_context_id uuid;
  group_row public.groups%rowtype;
  receipt jsonb;
begin
  if p_request_id is null or p_person_id is null or p_group_id is null then
    raise invalid_parameter_value using message='group student link requires request, person, and group';
  end if;

  begin
    select * into group_row
    from public.groups
    where id=p_group_id and status='active';
    if group_row.id is null then
      raise no_data_found using message='student link unavailable';
    end if;

    select child_context.id into resolved_child_context_id
    from public.child_contexts child_context
    where child_context.child_person_id=p_person_id
      and child_context.institution_id=group_row.institution_id
      and child_context.status='active'
    order by child_context.created_at, child_context.id
    limit 1;
    if resolved_child_context_id is null then
      raise no_data_found using message='student link unavailable';
    end if;

    -- O comando canonico consulta recibo antes do escopo. O adaptador protege
    -- seu replay: valida a capacidade atual, serializa por contexto e aceita
    -- somente o recibo que pertence exatamente a esta crianca e turma.
    perform app_private.student_link_require_scope(
      resolved_child_context_id, group_row.unit_id, group_row.id
    );
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(resolved_child_context_id::text, 0)
    );
    receipt := app_private.student_link_receipt(p_request_id, actor, 'link');
    if receipt is not null then
      if not exists (
        select 1
        from public.child_group_links group_link
        join public.child_unit_links unit_link on unit_link.id=group_link.child_unit_link_id
        where group_link.id=(receipt->>'group_link_id')::uuid
          and group_link.group_id=group_row.id
          and unit_link.child_context_id=resolved_child_context_id
          and unit_link.unit_id=group_row.unit_id
      ) then
        raise invalid_parameter_value using message='request id reused for another link target';
      end if;
      return receipt;
    end if;

    return app_private.superadmin_student_link(
      p_request_id,
      resolved_child_context_id,
      jsonb_build_object('unit_id', group_row.unit_id, 'group_id', group_row.id)
    );
  exception when no_data_found or insufficient_privilege then
    -- Sem people.assign_children, grupo e crianca recebem a mesma negativa
    -- opaca. A escrita ainda so acontece pelo comando canonico autorizado.
    raise no_data_found using message='student link unavailable';
  end;
end
$$;

revoke all on function public.superadmin_group_student_link(uuid,uuid,uuid) from public, anon;
grant execute on function public.superadmin_group_student_link(uuid,uuid,uuid) to authenticated, service_role;


-- Read projection for Turmas. Student membership is contextual and therefore
-- never appears in effective_access, which is reserved for institutional roles.
create or replace function app_private.superadmin_group_students_payload(
  p_group_id uuid
) returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'child_context_id', child_context.id,
    'person_id', child_person.id,
    'display_name', child_person.display_name,
    'status', group_link.status
  ) order by child_person.display_name, child_context.id), '[]'::jsonb)
  from public.groups group_row
  join public.child_group_links group_link
    on group_link.group_id=group_row.id and group_link.status='active'
  join public.child_unit_links unit_link
    on unit_link.id=group_link.child_unit_link_id
    and unit_link.status='active' and unit_link.unit_id=group_row.unit_id
  join public.child_contexts child_context
    on child_context.id=unit_link.child_context_id
    and child_context.status='active'
    and child_context.institution_id=group_row.institution_id
  join public.people child_person
    on child_person.id=child_context.child_person_id and child_person.status='active'
  where group_row.id=p_group_id and group_row.status='active'
$$;

-- Both public entry points already authorize before their private command. The
-- projection remains app_private and cannot be called by a client directly.
create or replace function public.superadmin_group_get(p_group_id uuid)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select app_private.superadmin_group_get(p_group_id)
    || jsonb_build_object('students', app_private.superadmin_group_students_payload(p_group_id))
$$;

create or replace function public.superadmin_group_save(
  p_request_id uuid, p_group_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb
language sql
volatile
security definer
set search_path=''
as $$
  with saved as (
    select app_private.superadmin_group_save(
      p_request_id, p_group_id, p_expected_version, p_payload
    ) as value
  )
  select value || jsonb_build_object(
    'students', app_private.superadmin_group_students_payload((value->>'id')::uuid)
  ) from saved
$$;

revoke all on function app_private.superadmin_group_students_payload(uuid) from public, anon, authenticated;
revoke all on function public.superadmin_group_get(uuid) from public, anon;
grant execute on function public.superadmin_group_get(uuid) to authenticated;
revoke all on function public.superadmin_group_save(uuid,uuid,bigint,jsonb) from public, anon;
grant execute on function public.superadmin_group_save(uuid,uuid,bigint,jsonb) to authenticated;


-- Desvincula uma crianca de uma unica turma. O vinculo com a unidade e as
-- demais turmas ficam ativos; para estes ha comandos canonicos distintos.
create or replace function public.superadmin_group_student_unlink(
  p_request_id uuid,
  p_child_context_id uuid,
  p_group_id uuid
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  institution uuid;
  group_row public.groups%rowtype;
  target_group_link public.child_group_links%rowtype;
  before_state jsonb;
  response jsonb;
begin
  if p_group_id is null or p_child_context_id is null then
    raise invalid_parameter_value using message='group student unlink requires request, child context, and group';
  end if;

  select * into group_row
  from public.groups
  where id = p_group_id and status = 'active';
  if group_row.id is null then
    raise no_data_found using message='student link unavailable';
  end if;

  institution := app_private.student_link_require_scope(
    p_child_context_id, group_row.unit_id, group_row.id
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_child_context_id::text, 0)
  );
  -- Um replay precisa passar pela autorizacao atual. O recibo tambem e preso
  -- ao contexto e turma, para que o mesmo request id nao aceite outro alvo.
  response := app_private.student_link_receipt(p_request_id, actor, 'unlink');
  if response is not null then
    if response->>'child_context_id' is distinct from p_child_context_id::text
      or response->>'group_id' is distinct from p_group_id::text then
      raise invalid_parameter_value using message='request id reused for another unlink target';
    end if;
    return response;
  end if;
  select child_group_link_row.* into target_group_link
  from public.child_group_links child_group_link_row
  join public.child_unit_links unit_link on unit_link.id = child_group_link_row.child_unit_link_id
  where child_group_link_row.group_id = group_row.id
    and child_group_link_row.status = 'active'
    and unit_link.child_context_id = p_child_context_id
    and unit_link.unit_id = group_row.unit_id
    and unit_link.status = 'active'
  for update of child_group_link_row;
  if target_group_link.id is null then
    raise no_data_found using message='student link unavailable';
  end if;

  before_state := to_jsonb(target_group_link);
  update public.child_group_links set
    status = 'inactive',
    ends_at = coalesce(ends_at, now()),
    updated_at = now()
  where id = target_group_link.id
  returning * into target_group_link;

  response := jsonb_build_object(
    'child_context_id', p_child_context_id,
    'unit_link_id', target_group_link.child_unit_link_id,
    'group_link_id', target_group_link.id,
    'group_id', group_row.id,
    'status', target_group_link.status
  );
  insert into app_private.student_link_command_receipts
    values (p_request_id, actor, 'unlink', target_group_link.id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, before_json, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'student.unlink', 'child_group_link', target_group_link.id,
    institution, 'success', before_state, response
  );
  return response;
end
$$;

revoke all on function public.superadmin_group_student_unlink(uuid,uuid,uuid)
  from public, anon;
grant execute on function public.superadmin_group_student_unlink(uuid,uuid,uuid)
  to authenticated, service_role;


-- R10 assessments: reload an explicitly selected configuration without
-- changing the activity/unit reader consumed by daily assessment flows.
create or replace function public.superadmin_assessment_configuration_read_by_id(
  target_configuration uuid
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid := gen_random_uuid();
  target_institution uuid;
  result jsonb;
  code text;
begin
  begin
    select * into strict ctx
    from app_private.assessment_v2_require_context('activities.read', null);
    select c.institution_id into target_institution
    from public.activity_assessment_configurations c
    where c.id = target_configuration
      and (ctx.scope_kind <> 'institution' or c.institution_id = ctx.scope_institution_id);
    if target_institution is null then return app_private.assessment_v2_ok(null); end if;
    select * into strict ctx
    from app_private.assessment_v2_require_context('activities.read', target_institution);
    result := app_private.assessment_v2_configuration_snapshot(target_configuration);
    return app_private.assessment_v2_ok(result);
  exception when others then get stacked diagnostics code = pg_exception_detail; end;
  return app_private.assessment_v2_denied(
    'activities.read', 'assessment.configuration.read_by_id',
    coalesce(nullif(code, ''), 'SAI_INTERNAL_ERROR'), correlation, target_institution
  );
end $$;

alter function public.superadmin_assessment_configuration_read_by_id(uuid) owner to postgres;
revoke all on function public.superadmin_assessment_configuration_read_by_id(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_assessment_configuration_read_by_id(uuid) to authenticated;


-- R10 chat video: private MP4 only, same 10 MiB ceiling as Chat PDF.
-- No bucket, credential, retention, permission or read-path change.
create or replace function app_private.chat_attachment_limit_v1(p_content_type text)
returns bigint language sql immutable security invoker set search_path='' as $$
  select case p_content_type
    when 'image/jpeg' then 4194304::bigint
    when 'image/png' then 4194304::bigint
    when 'image/webp' then 4194304::bigint
    when 'application/pdf' then 10485760::bigint
    when 'video/mp4' then 10485760::bigint
    else null end
$$;
create or replace function app_private.chat_attachment_extension_v1(p_content_type text)
returns text language sql immutable security invoker set search_path='' as $$
  select case p_content_type
    when 'image/jpeg' then 'jpg' when 'image/png' then 'png'
    when 'image/webp' then 'webp' when 'application/pdf' then 'pdf'
    when 'video/mp4' then 'mp4' end
$$;
alter function app_private.chat_attachment_limit_v1(text) owner to postgres;
alter function app_private.chat_attachment_extension_v1(text) owner to postgres;
revoke all on function app_private.chat_attachment_limit_v1(text),
  app_private.chat_attachment_extension_v1(text) from public, anon, authenticated, service_role;
