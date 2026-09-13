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
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_child_context_id::text, 0)
  );

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
