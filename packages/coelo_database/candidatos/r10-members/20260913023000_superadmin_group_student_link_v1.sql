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
  child_context_id uuid;
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

    select child_context.id into child_context_id
    from public.child_contexts child_context
    where child_context.child_person_id=p_person_id
      and child_context.institution_id=group_row.institution_id
      and child_context.status='active'
    order by child_context.created_at, child_context.id
    limit 1;
    if child_context_id is null then
      raise no_data_found using message='student link unavailable';
    end if;

    -- O comando canonico consulta recibo antes do escopo. O adaptador protege
    -- seu replay: valida a capacidade atual, serializa por contexto e aceita
    -- somente o recibo que pertence exatamente a esta crianca e turma.
    perform app_private.student_link_require_scope(
      child_context_id, group_row.unit_id, group_row.id
    );
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(child_context_id::text, 0)
    );
    receipt := app_private.student_link_receipt(p_request_id, actor, 'link');
    if receipt is not null then
      if not exists (
        select 1
        from public.child_group_links group_link
        join public.child_unit_links unit_link on unit_link.id=group_link.child_unit_link_id
        where group_link.id=(receipt->>'group_link_id')::uuid
          and group_link.group_id=group_row.id
          and unit_link.child_context_id=child_context_id
          and unit_link.unit_id=group_row.unit_id
      ) then
        raise invalid_parameter_value using message='request id reused for another link target';
      end if;
      return receipt;
    end if;

    return app_private.superadmin_student_link(
      p_request_id,
      child_context_id,
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
