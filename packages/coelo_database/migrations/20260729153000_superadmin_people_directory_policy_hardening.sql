-- Correlate guardian reads to the exact child context row being selected.

drop policy if exists child_contexts_guardian_context_read
  on public.child_contexts;
create policy child_contexts_guardian_context_read
  on public.child_contexts
  for select to authenticated
  using (
    child_contexts.child_person_id =
      (select app_private.current_person_id())
    or exists (
      select 1
      from public.guardian_links guardian_link
      join public.guardian_context_permissions guardian_permission
        on guardian_permission.guardian_link_id = guardian_link.id
        and guardian_permission.child_context_id = child_contexts.id
        and guardian_permission.status = 'active'
        and guardian_permission.can_view
        and (
          guardian_permission.starts_at is null
          or guardian_permission.starts_at <= pg_catalog.now()
        )
        and (
          guardian_permission.expires_at is null
          or guardian_permission.expires_at > pg_catalog.now()
        )
      where guardian_link.child_person_id =
          child_contexts.child_person_id
        and guardian_link.guardian_person_id =
          (select app_private.current_person_id())
        and guardian_link.status = 'active'
        and guardian_link.revoked_at is null
    )
  );

drop policy if exists child_unit_links_guardian_context_read
  on public.child_unit_links;
create policy child_unit_links_guardian_context_read
  on public.child_unit_links
  for select to authenticated
  using (
    exists (
      select 1
      from public.child_contexts own_child_context
      where own_child_context.id = child_unit_links.child_context_id
        and own_child_context.child_person_id =
          (select app_private.current_person_id())
    )
    or exists (
      select 1
      from public.child_contexts child_context
      join public.guardian_links guardian_link
        on guardian_link.child_person_id = child_context.child_person_id
        and guardian_link.guardian_person_id =
          (select app_private.current_person_id())
        and guardian_link.status = 'active'
        and guardian_link.revoked_at is null
      join public.guardian_context_permissions guardian_permission
        on guardian_permission.guardian_link_id = guardian_link.id
        and guardian_permission.child_context_id = child_context.id
        and guardian_permission.status = 'active'
        and guardian_permission.can_view
        and (
          guardian_permission.starts_at is null
          or guardian_permission.starts_at <= pg_catalog.now()
        )
        and (
          guardian_permission.expires_at is null
          or guardian_permission.expires_at > pg_catalog.now()
        )
      where child_context.id = child_unit_links.child_context_id
    )
  );

drop policy if exists child_group_links_guardian_context_read
  on public.child_group_links;
create policy child_group_links_guardian_context_read
  on public.child_group_links
  for select to authenticated
  using (
    exists (
      select 1
      from public.child_unit_links own_unit_link
      join public.child_contexts own_child_context
        on own_child_context.id = own_unit_link.child_context_id
      where own_unit_link.id = child_group_links.child_unit_link_id
        and own_child_context.child_person_id =
          (select app_private.current_person_id())
    )
    or exists (
      select 1
      from public.child_unit_links unit_link
      join public.child_contexts child_context
        on child_context.id = unit_link.child_context_id
      join public.guardian_links guardian_link
        on guardian_link.child_person_id = child_context.child_person_id
        and guardian_link.guardian_person_id =
          (select app_private.current_person_id())
        and guardian_link.status = 'active'
        and guardian_link.revoked_at is null
      join public.guardian_context_permissions guardian_permission
        on guardian_permission.guardian_link_id = guardian_link.id
        and guardian_permission.child_context_id = child_context.id
        and guardian_permission.status = 'active'
        and guardian_permission.can_view
        and (
          guardian_permission.starts_at is null
          or guardian_permission.starts_at <= pg_catalog.now()
        )
        and (
          guardian_permission.expires_at is null
          or guardian_permission.expires_at > pg_catalog.now()
        )
      where unit_link.id = child_group_links.child_unit_link_id
    )
  );

-- The original function uses `#variable_conflict use_variable`. PostgreSQL
-- therefore resolves the unqualified ON CONFLICT inference names as PL/pgSQL
-- variables instead of target columns. Bind the upserts to their canonical
-- named constraints without duplicating the full function body.
do $hardening$
declare
  function_definition text;
begin
  select pg_catalog.pg_get_functiondef(
    'app_private.update_superadmin_person(uuid,timestamptz,jsonb,jsonb)'
      ::regprocedure
  )
  into function_definition;

  if pg_catalog.strpos(
    function_definition,
    'on conflict (child_context_id, unit_id)'
  ) = 0
     or pg_catalog.strpos(
       function_definition,
       'on conflict (child_unit_link_id, group_id)'
     ) = 0
     or pg_catalog.strpos(
       function_definition,
       $fragment$when group_id is null then 'inactive'
                else 'active'$fragment$
     ) = 0 then
    raise exception
      'expected child link conflict inference was not found';
  end if;

  function_definition := pg_catalog.replace(
    function_definition,
    'on conflict (child_context_id, unit_id)',
    'on conflict on constraint child_unit_links_child_context_id_unit_id_key'
  );
  function_definition := pg_catalog.replace(
    function_definition,
    'on conflict (child_unit_link_id, group_id)',
    'on conflict on constraint child_group_links_child_unit_link_id_group_id_key'
  );
  function_definition := pg_catalog.replace(
    function_definition,
    $fragment$when group_id is null then 'inactive'
                else 'active'$fragment$,
    $fragment$when group_id is null
                  then 'inactive'::public.record_status
                else 'active'::public.record_status$fragment$
  );
  execute function_definition;
end
$hardening$;
