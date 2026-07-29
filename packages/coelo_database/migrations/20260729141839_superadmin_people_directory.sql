-- Superadmin people directory, draft creation and concurrency-safe editing.

insert into public.platform_permissions(
  code,
  module_code,
  screen_code,
  action_code,
  description,
  risk_level,
  requires_mfa
)
values
  (
    'people.read', 'people', 'directory', 'read',
    'Listar e consultar resumos minimizados de pessoas e vinculos.', 'high', true
  ),
  (
    'people.create', 'people', 'create', 'create',
    'Criar adultos e criancas em draft sem ativar acesso.', 'high', true
  ),
  (
    'people.update', 'people', 'edit', 'update',
    'Editar somente campos globais de identidade aprovados.', 'high', true
  ),
  (
    'people.memberships.manage', 'people', 'memberships', 'manage',
    'Gerenciar memberships institucionais e papeis contextuais.', 'high', true
  ),
  (
    'people.child_contexts.manage', 'people', 'child_contexts', 'manage',
    'Gerenciar contextos institucionais de criancas.', 'high', true
  )
on conflict (code) do update
set
  module_code = excluded.module_code,
  screen_code = excluded.screen_code,
  action_code = excluded.action_code,
  description = excluded.description,
  risk_level = excluded.risk_level,
  requires_mfa = excluded.requires_mfa,
  status = 'active';

insert into public.platform_role_permissions(role_id, permission_id, effect)
select role.id, permission.id, 'allow'
from public.platform_roles role
cross join public.platform_permissions permission
where role.code = 'owner'
  and permission.code in (
    'people.read',
    'people.create',
    'people.update',
    'people.memberships.manage',
    'people.child_contexts.manage'
  )
on conflict (role_id, permission_id) do update
set effect = 'allow', status = 'active', revoked_at = null;

create index if not exists people_directory_sort_idx
  on public.people(lower(display_name), id)
  where deleted_at is null;

create index if not exists institution_memberships_people_directory_idx
  on public.institution_memberships(
    institution_id,
    role_code,
    scope_unit_id,
    scope_group_id,
    person_id
  )
  where status = 'active' and revoked_at is null;

create index if not exists institution_role_assignments_people_directory_idx
  on public.institution_role_assignments(
    scope_unit_id,
    scope_group_id,
    membership_id,
    role_id
  )
  where status = 'active';

create index if not exists child_contexts_people_directory_idx
  on public.child_contexts(institution_id, child_person_id)
  where status = 'active';

create or replace function app_private.touch_people_context_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_person_id uuid;
  target_membership_id uuid;
  target_child_context_id uuid;
  target_child_unit_link_id uuid;
begin
  if tg_table_name = 'institution_memberships' then
    target_person_id := case
      when tg_op = 'DELETE' then old.person_id
      else new.person_id
    end;
  elsif tg_table_name = 'institution_role_assignments' then
    target_membership_id := case
      when tg_op = 'DELETE' then old.membership_id
      else new.membership_id
    end;
    select membership.person_id
    into target_person_id
    from public.institution_memberships membership
    where membership.id = target_membership_id;
  elsif tg_table_name = 'child_contexts' then
    target_person_id := case
      when tg_op = 'DELETE' then old.child_person_id
      else new.child_person_id
    end;
  elsif tg_table_name = 'child_unit_links' then
    target_child_context_id := case
      when tg_op = 'DELETE' then old.child_context_id
      else new.child_context_id
    end;
    select child_context.child_person_id
    into target_person_id
    from public.child_contexts child_context
    where child_context.id = target_child_context_id;
  elsif tg_table_name = 'child_group_links' then
    target_child_unit_link_id := case
      when tg_op = 'DELETE' then old.child_unit_link_id
      else new.child_unit_link_id
    end;
    select child_context.child_person_id
    into target_person_id
    from public.child_unit_links unit_link
    join public.child_contexts child_context
      on child_context.id = unit_link.child_context_id
    where unit_link.id = target_child_unit_link_id;
  end if;

  if target_person_id is not null then
    update public.people person
    set updated_at = greatest(
      clock_timestamp(),
      person.updated_at + interval '1 microsecond'
    )
    where person.id = target_person_id;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end
$$;

revoke execute on function app_private.touch_people_context_owner()
  from public, anon, authenticated;

drop trigger if exists institution_memberships_touch_person
  on public.institution_memberships;
create trigger institution_memberships_touch_person
after insert or update or delete on public.institution_memberships
for each row execute function app_private.touch_people_context_owner();

drop trigger if exists institution_role_assignments_touch_person
  on public.institution_role_assignments;
create trigger institution_role_assignments_touch_person
after insert or update or delete on public.institution_role_assignments
for each row execute function app_private.touch_people_context_owner();

drop trigger if exists child_contexts_touch_person on public.child_contexts;
create trigger child_contexts_touch_person
after insert or update or delete on public.child_contexts
for each row execute function app_private.touch_people_context_owner();

drop trigger if exists child_unit_links_touch_person
  on public.child_unit_links;
create trigger child_unit_links_touch_person
after insert or update or delete on public.child_unit_links
for each row execute function app_private.touch_people_context_owner();

drop trigger if exists child_group_links_touch_person
  on public.child_group_links;
create trigger child_group_links_touch_person
after insert or update or delete on public.child_group_links
for each row execute function app_private.touch_people_context_owner();

drop policy if exists people_self_or_platform_read on public.people;
drop policy if exists people_self_or_people_read on public.people;
create policy people_self_read on public.people
  for select to authenticated
  using (id = (select app_private.current_person_id()));

drop policy if exists person_profile_self_or_platform_read
  on public.person_profile_details;
drop policy if exists person_profile_self_or_people_read
  on public.person_profile_details;
drop policy if exists person_profile_self_read
  on public.person_profile_details;
create policy person_profile_self_read
  on public.person_profile_details
  for select to authenticated
  using (person_id = (select app_private.current_person_id()));

drop policy if exists person_professional_self_or_platform_read
  on public.person_professional_details;
drop policy if exists person_professional_self_or_people_read
  on public.person_professional_details;
drop policy if exists person_professional_self_read
  on public.person_professional_details;
create policy person_professional_self_read
  on public.person_professional_details
  for select to authenticated
  using (person_id = (select app_private.current_person_id()));

drop policy if exists person_education_self_or_platform_read
  on public.person_education_details;
drop policy if exists person_education_self_or_people_read
  on public.person_education_details;
drop policy if exists person_education_self_read
  on public.person_education_details;
create policy person_education_self_read
  on public.person_education_details
  for select to authenticated
  using (person_id = (select app_private.current_person_id()));

drop policy if exists person_addresses_self_or_platform_read
  on public.person_addresses;
drop policy if exists person_addresses_self_or_people_read
  on public.person_addresses;
drop policy if exists person_addresses_self_read
  on public.person_addresses;
create policy person_addresses_self_read
  on public.person_addresses
  for select to authenticated
  using (person_id = (select app_private.current_person_id()));

drop policy if exists person_contacts_self_or_platform_read
  on public.person_contacts;
drop policy if exists person_contacts_self_or_people_read
  on public.person_contacts;
drop policy if exists person_contacts_self_read
  on public.person_contacts;
create policy person_contacts_self_read
  on public.person_contacts
  for select to authenticated
  using (person_id = (select app_private.current_person_id()));

create or replace function app_private.has_active_institution_membership(
  target_institution_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(exists (
    select 1
    from public.institution_memberships membership
    where membership.person_id = app_private.current_person_id()
      and membership.institution_id = target_institution_id
      and membership.status = 'active'
      and membership.revoked_at is null
  ), false)
$$;

revoke execute on function app_private.has_active_institution_membership(uuid)
  from public, anon;
grant execute on function app_private.has_active_institution_membership(uuid)
  to authenticated, service_role;

drop policy if exists platform_memberships_platform_read
  on public.platform_memberships;
drop policy if exists platform_memberships_self_or_people_read
  on public.platform_memberships;
create policy platform_memberships_self_read
  on public.platform_memberships
  for select to authenticated
  using (person_id = (select app_private.current_person_id()));

drop policy if exists institution_memberships_platform_read
  on public.institution_memberships;
drop policy if exists institution_memberships_self_or_people_read
  on public.institution_memberships;
create policy institution_memberships_self_read
  on public.institution_memberships
  for select to authenticated
  using (person_id = (select app_private.current_person_id()));

drop policy if exists institution_roles_platform_read on public.institution_roles;
drop policy if exists institution_roles_context_or_people_read
  on public.institution_roles;
create policy institution_roles_own_context_read
  on public.institution_roles
  for select to authenticated
  using (
    (
      institution_id is null
      and exists (
        select 1
        from public.institution_memberships own_membership
        where own_membership.person_id =
          (select app_private.current_person_id())
          and own_membership.status = 'active'
          and own_membership.revoked_at is null
      )
    )
    or (select app_private.has_active_institution_membership(institution_id))
  );

drop policy if exists institution_permissions_platform_read
  on public.institution_permissions;
drop policy if exists institution_permissions_context_or_people_read
  on public.institution_permissions;
create policy institution_permissions_own_context_read
  on public.institution_permissions
  for select to authenticated
  using (
    exists (
      select 1
      from public.institution_memberships own_membership
      where own_membership.person_id = (select app_private.current_person_id())
        and own_membership.status = 'active'
        and own_membership.revoked_at is null
    )
  );

drop policy if exists institution_role_permissions_platform_read
  on public.institution_role_permissions;
drop policy if exists institution_role_permissions_context_or_people_read
  on public.institution_role_permissions;
create policy institution_role_permissions_own_context_read
  on public.institution_role_permissions
  for select to authenticated
  using (
    exists (
      select 1
      from public.institution_roles role
      where role.id = role_id
        and (
          (
            role.institution_id is null
            and exists (
              select 1
              from public.institution_memberships own_membership
              where own_membership.person_id =
                (select app_private.current_person_id())
                and own_membership.status = 'active'
                and own_membership.revoked_at is null
            )
          )
          or (
            select app_private.has_active_institution_membership(
              role.institution_id
            )
          )
        )
    )
  );

drop policy if exists institution_role_assignments_platform_read
  on public.institution_role_assignments;
drop policy if exists institution_role_assignments_self_or_people_read
  on public.institution_role_assignments;
create policy institution_role_assignments_self_read
  on public.institution_role_assignments
  for select to authenticated
  using (
    exists (
      select 1
      from public.institution_memberships own_membership
      where own_membership.id = membership_id
        and own_membership.person_id = (select app_private.current_person_id())
    )
  );

drop policy if exists guardian_links_platform_read on public.guardian_links;
drop policy if exists guardian_links_self_or_people_read
  on public.guardian_links;
create policy guardian_links_self_read
  on public.guardian_links
  for select to authenticated
  using (
    guardian_person_id = (select app_private.current_person_id())
    or child_person_id = (select app_private.current_person_id())
  );

drop policy if exists child_contexts_platform_read on public.child_contexts;
drop policy if exists child_contexts_context_or_people_read
  on public.child_contexts;
create policy child_contexts_guardian_context_read
  on public.child_contexts
  for select to authenticated
  using (
    child_person_id = (select app_private.current_person_id())
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
      where guardian_link.child_person_id = child_person_id
        and guardian_link.guardian_person_id =
          (select app_private.current_person_id())
        and guardian_link.status = 'active'
        and guardian_link.revoked_at is null
    )
  );

drop policy if exists child_unit_links_platform_read on public.child_unit_links;
drop policy if exists child_unit_links_context_or_people_read
  on public.child_unit_links;
create policy child_unit_links_guardian_context_read
  on public.child_unit_links
  for select to authenticated
  using (
    exists (
      select 1
      from public.child_contexts own_child_context
      where own_child_context.id = child_context_id
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
      where child_context.id = child_context_id
    )
  );

drop policy if exists child_group_links_platform_read
  on public.child_group_links;
drop policy if exists child_group_links_context_or_people_read
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
      where own_unit_link.id = child_unit_link_id
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
      where unit_link.id = child_unit_link_id
    )
  );

drop policy if exists guardian_context_permissions_platform_read
  on public.guardian_context_permissions;
drop policy if exists guardian_context_permissions_context_or_people_read
  on public.guardian_context_permissions;
create policy guardian_context_permissions_self_read
  on public.guardian_context_permissions
  for select to authenticated
  using (
    exists (
      select 1
      from public.guardian_links guardian_link
      where guardian_link.id = guardian_link_id
        and guardian_link.guardian_person_id =
          (select app_private.current_person_id())
    )
  );

drop policy if exists child_unit_access_requests_platform_read
  on public.child_unit_access_requests;
drop policy if exists child_unit_access_requests_context_or_people_read
  on public.child_unit_access_requests;
create policy child_unit_access_requests_self_read
  on public.child_unit_access_requests
  for select to authenticated
  using (
    requested_by = (select app_private.current_person_id())
  );

drop policy if exists child_unit_access_request_children_platform_read
  on public.child_unit_access_request_children;
drop policy if exists child_unit_access_request_children_context_or_people_read
  on public.child_unit_access_request_children;
create policy child_unit_access_request_children_self_read
  on public.child_unit_access_request_children
  for select to authenticated
  using (
    exists (
      select 1
      from public.child_unit_access_requests request
      where request.id = request_id
        and request.requested_by = (select app_private.current_person_id())
    )
  );

drop policy if exists invitations_platform_read on public.invitations;
drop policy if exists invitations_context_or_people_read on public.invitations;
create policy invitations_self_read
  on public.invitations
  for select to authenticated
  using (
    target_person_id = (select app_private.current_person_id())
    or invited_by = (select app_private.current_person_id())
  );

create or replace view public.person_directory
with (security_invoker = true)
as
select
  person.id,
  person.person_type,
  person.display_name,
  person.status,
  exists (
    select 1
    from public.person_auth_links auth_link
    where auth_link.person_id = person.id
      and auth_link.status = 'active'
      and auth_link.revoked_at is null
  ) as has_active_login,
  (
    select count(*)
    from public.institution_memberships membership
    where membership.person_id = person.id
      and membership.status = 'active'
      and membership.revoked_at is null
  ) as institution_count,
  (
    select count(*)
    from public.guardian_links guardian_link
    where guardian_link.guardian_person_id = person.id
      and guardian_link.status = 'active'
      and guardian_link.revoked_at is null
  ) as child_count
from public.people person
where person.deleted_at is null
  and person.id = (select app_private.current_person_id());

revoke all on table public.person_directory from public, anon, authenticated;
grant select on table public.person_directory to authenticated;
grant all on table public.person_directory to service_role;

create or replace function app_private.platform_permission_membership_id(
  permission_code text
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select membership.id
  from public.platform_memberships membership
  join public.platform_roles role on role.id = membership.role_id
  where membership.person_id = app_private.current_person_id()
    and membership.status = 'active'
    and membership.revoked_at is null
    and role.status = 'active'
    and (
      role.code = 'owner'
      or exists (
        select 1
        from public.platform_member_permission_overrides override_row
        join public.platform_permissions permission
          on permission.id = override_row.permission_id
        where override_row.membership_id = membership.id
          and permission.code = permission_code
          and permission.status = 'active'
          and override_row.status = 'active'
          and override_row.effect = 'allow'
          and (
            override_row.starts_at is null
            or override_row.starts_at <= pg_catalog.now()
          )
          and (
            override_row.expires_at is null
            or override_row.expires_at > pg_catalog.now()
          )
      )
      or exists (
        select 1
        from public.platform_role_permissions role_permission
        join public.platform_permissions permission
          on permission.id = role_permission.permission_id
        where role_permission.role_id = membership.role_id
          and permission.code = permission_code
          and permission.status = 'active'
          and role_permission.status = 'active'
          and role_permission.effect = 'allow'
      )
    )
  order by (role.code = 'owner') desc, membership.created_at, membership.id
  limit 1
$$;

revoke execute on function app_private.platform_permission_membership_id(text)
  from public, anon, authenticated;
grant execute on function app_private.platform_permission_membership_id(text)
  to service_role;

create or replace function app_private.assert_people_permission(
  permission_code text
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null
     or not (select app_private.has_platform_permission(permission_code)) then
    raise insufficient_privilege using message = 'people permission denied';
  end if;
  if not (select app_private.has_mfa_aal2()) then
    raise insufficient_privilege using message = 'people permission requires aal2';
  end if;
end
$$;

revoke execute on function app_private.assert_people_permission(text)
  from public, anon, authenticated;
grant execute on function app_private.assert_people_permission(text)
  to service_role;

create or replace function app_private.list_superadmin_people(
  p_search text default null,
  p_person_types public.person_type[] default null,
  p_statuses public.record_status[] default null,
  p_institution_id uuid default null,
  p_unit_id uuid default null,
  p_group_id uuid default null,
  p_role_code text default null,
  p_has_auth boolean default null,
  p_page integer default 1,
  p_page_size integer default 20
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform app_private.assert_people_permission('people.read');

  if p_page < 1 then
    raise invalid_parameter_value using message = 'page must be positive';
  end if;
  if p_page_size not in (20, 50, 100) then
    raise invalid_parameter_value using message = 'page_size must be 20, 50 or 100';
  end if;
  if p_unit_id is not null and not exists (
    select 1 from public.units unit
    where unit.id = p_unit_id
      and (p_institution_id is null or unit.institution_id = p_institution_id)
  ) then
    raise check_violation using message = 'unit does not belong to institution';
  end if;
  if p_group_id is not null and not exists (
    select 1 from public.groups group_row
    where group_row.id = p_group_id
      and (p_institution_id is null or group_row.institution_id = p_institution_id)
      and (p_unit_id is null or group_row.unit_id = p_unit_id)
  ) then
    raise check_violation using message = 'group does not belong to requested context';
  end if;

  with filtered as (
    select person.*
    from public.people person
    where person.deleted_at is null
      and (
        p_search is null
        or btrim(p_search) = ''
        or person.display_name ilike '%' || btrim(p_search) || '%'
        or person.first_name ilike '%' || btrim(p_search) || '%'
        or person.last_name ilike '%' || btrim(p_search) || '%'
      )
      and (p_person_types is null or person.person_type = any(p_person_types))
      and (p_statuses is null or person.status = any(p_statuses))
      and (
        p_has_auth is null
        or p_has_auth = exists (
          select 1
          from public.person_auth_links auth_link
          where auth_link.person_id = person.id
            and auth_link.status = 'active'
            and auth_link.revoked_at is null
        )
      )
      and (
        (
          p_institution_id is null
          and p_unit_id is null
          and p_group_id is null
          and p_role_code is null
        )
        or (
          person.person_type in ('adult', 'service')
          and exists (
            select 1
            from public.institution_memberships membership
            left join public.institution_role_assignments assignment
              on assignment.membership_id = membership.id
              and assignment.status = 'active'
            left join public.institution_roles role
              on role.id = assignment.role_id
            where membership.person_id = person.id
              and membership.status = 'active'
              and membership.revoked_at is null
              and (
                p_institution_id is null
                or membership.institution_id = p_institution_id
              )
              and (
                p_unit_id is null
                or membership.scope_unit_id = p_unit_id
                or assignment.scope_unit_id = p_unit_id
              )
              and (
                p_group_id is null
                or membership.scope_group_id = p_group_id
                or assignment.scope_group_id = p_group_id
              )
              and (
                p_role_code is null
                or membership.role_code = p_role_code
                or role.code = p_role_code
              )
          )
        )
        or (
          person.person_type = 'child'
          and p_role_code is null
          and exists (
            select 1
            from public.child_contexts child_context
            left join public.child_unit_links unit_link
              on unit_link.child_context_id = child_context.id
              and unit_link.status in ('pending', 'awaiting_allocation', 'active')
              and unit_link.revoked_at is null
            left join public.child_group_links group_link
              on group_link.child_unit_link_id = unit_link.id
              and group_link.status = 'active'
            where child_context.child_person_id = person.id
              and child_context.status = 'active'
              and (
                p_institution_id is null
                or child_context.institution_id = p_institution_id
              )
              and (p_unit_id is null or unit_link.unit_id = p_unit_id)
              and (p_group_id is null or group_link.group_id = p_group_id)
          )
        )
      )
  ),
  page_rows as (
    select *
    from filtered
    order by lower(display_name), id
    offset (p_page - 1) * p_page_size
    limit p_page_size
  )
  select jsonb_build_object(
    'items',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', row.id,
            'person_type', row.person_type,
            'display_name', row.display_name,
            'status', row.status,
            'updated_at', row.updated_at,
            'has_active_login', exists (
              select 1
              from public.person_auth_links auth_link
              where auth_link.person_id = row.id
                and auth_link.status = 'active'
                and auth_link.revoked_at is null
            ),
            'institution_count', (
              select count(distinct scope.institution_id)
              from (
                select membership.institution_id
                from public.institution_memberships membership
                where membership.person_id = row.id
                  and membership.status = 'active'
                  and membership.revoked_at is null
                union
                select child_context.institution_id
                from public.child_contexts child_context
                where child_context.child_person_id = row.id
                  and child_context.status = 'active'
              ) scope
            )
          )
          order by lower(row.display_name), row.id
        )
        from page_rows row
      ),
      '[]'::jsonb
    ),
    'page', p_page,
    'page_size', p_page_size,
    'total', (select count(*) from filtered)
  )
  into result;

  return result;
end
$$;

create or replace function app_private.get_superadmin_person(p_person_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform app_private.assert_people_permission('people.read');

  select jsonb_build_object(
    'id', person.id,
    'person_type', person.person_type,
    'first_name', person.first_name,
    'last_name', person.last_name,
    'display_name', person.display_name,
    'legal_name', person.legal_name,
    'status', person.status,
    'updated_at', person.updated_at,
    'auth_summary', jsonb_build_object(
      'has_active_login', exists (
        select 1 from public.person_auth_links auth_link
        where auth_link.person_id = person.id
          and auth_link.status = 'active'
          and auth_link.revoked_at is null
      ),
      'active_link_count', (
        select count(*) from public.person_auth_links auth_link
        where auth_link.person_id = person.id
          and auth_link.status = 'active'
          and auth_link.revoked_at is null
      )
    ),
    'platform_memberships', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', membership.id,
        'role_code', role.code,
        'status', membership.status,
        'scope_kind', membership.scope_kind,
        'scope_institution_id', membership.scope_institution_id
      ) order by role.code, membership.id)
      from public.platform_memberships membership
      join public.platform_roles role on role.id = membership.role_id
      where membership.person_id = person.id
    ), '[]'::jsonb),
    'institution_memberships', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', membership.id,
        'institution_id', membership.institution_id,
        'role_code', membership.role_code,
        'status', membership.status,
        'scope_kind', membership.scope_kind,
        'scope_unit_id', membership.scope_unit_id,
        'scope_group_id', membership.scope_group_id
      ) order by membership.created_at, membership.id)
      from public.institution_memberships membership
      where membership.person_id = person.id
    ), '[]'::jsonb),
    'child_contexts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', child_context.id,
        'institution_id', child_context.institution_id,
        'status', child_context.status,
        'units', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', unit_link.id,
            'unit_id', unit_link.unit_id,
            'status', unit_link.status,
            'groups', coalesce((
              select jsonb_agg(jsonb_build_object(
                'id', group_link.id,
                'group_id', group_link.group_id,
                'status', group_link.status
              ) order by group_link.created_at, group_link.id)
              from public.child_group_links group_link
              where group_link.child_unit_link_id = unit_link.id
            ), '[]'::jsonb)
          ) order by unit_link.created_at, unit_link.id)
          from public.child_unit_links unit_link
          where unit_link.child_context_id = child_context.id
        ), '[]'::jsonb)
      ) order by child_context.created_at, child_context.id)
      from public.child_contexts child_context
      where child_context.child_person_id = person.id
    ), '[]'::jsonb),
    'guardian_summary', jsonb_build_object(
      'as_guardian_count', (
        select count(*) from public.guardian_links guardian_link
        where guardian_link.guardian_person_id = person.id
          and guardian_link.status = 'active'
          and guardian_link.revoked_at is null
      ),
      'guardian_count', (
        select count(*) from public.guardian_links guardian_link
        where guardian_link.child_person_id = person.id
          and guardian_link.status = 'active'
          and guardian_link.revoked_at is null
      )
    )
  )
  into result
  from public.people person
  where person.id = p_person_id
    and person.deleted_at is null;

  if result is null then
    raise no_data_found using message = 'person not found';
  end if;
  return result;
end
$$;

create or replace function app_private.create_superadmin_person_draft(
  p_person_type public.person_type,
  p_first_name text,
  p_last_name text,
  p_display_name text default null,
  p_legal_name text default null,
  p_contexts jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  created_person public.people;
  context jsonb;
  context_kind text;
  institution_id uuid;
  unit_id uuid;
  group_id uuid;
  membership_id uuid;
  role_id uuid;
  role_scope_kind text;
  assignment_id uuid;
  child_context_id uuid;
  child_unit_link_id uuid;
  child_group_link_id uuid;
  actor_person_id uuid;
  actor_platform_membership_id uuid;
begin
  perform app_private.assert_people_permission('people.create');

  if p_person_type = 'service' then
    raise invalid_parameter_value using message = 'service people are read-only';
  end if;
  if nullif(btrim(p_first_name), '') is null
     or nullif(btrim(p_last_name), '') is null then
    raise invalid_parameter_value using message = 'first and last name are required';
  end if;
  if jsonb_typeof(coalesce(p_contexts, '[]'::jsonb)) <> 'array' then
    raise invalid_parameter_value using message = 'contexts must be an array';
  end if;

  if jsonb_array_length(coalesce(p_contexts, '[]'::jsonb)) > 0 then
    if p_person_type = 'adult' then
      perform app_private.assert_people_permission('people.memberships.manage');
    else
      perform app_private.assert_people_permission('people.child_contexts.manage');
    end if;
  end if;

  insert into public.people(
    person_type,
    first_name,
    last_name,
    display_name,
    legal_name,
    status
  )
  values (
    p_person_type,
    btrim(p_first_name),
    btrim(p_last_name),
    coalesce(
      nullif(btrim(p_display_name), ''),
      btrim(p_first_name) || ' ' || btrim(p_last_name)
    ),
    nullif(btrim(p_legal_name), ''),
    'draft'
  )
  returning * into created_person;

  actor_person_id := app_private.current_person_id();

  for context in
    select value from jsonb_array_elements(coalesce(p_contexts, '[]'::jsonb))
  loop
    context_kind := context ->> 'kind';
    institution_id := nullif(context ->> 'institution_id', '')::uuid;
    unit_id := nullif(context ->> 'scope_unit_id', '')::uuid;
    group_id := nullif(context ->> 'scope_group_id', '')::uuid;

    if p_person_type = 'adult'
       and context_kind = 'institution_membership' then
      if institution_id is null
         or nullif(btrim(context ->> 'role_code'), '') is null then
        raise invalid_parameter_value using
          message = 'adult membership requires institution and role';
      end if;
      if not exists (
        select 1 from public.institutions institution
        where institution.id = institution_id
      ) then
        raise foreign_key_violation using message = 'institution not found';
      end if;
      if unit_id is not null and not exists (
        select 1 from public.units unit
        where unit.id = unit_id and unit.institution_id = institution_id
      ) then
        raise check_violation using message = 'unit belongs to another institution';
      end if;
      if group_id is not null and not exists (
        select 1 from public.groups group_row
        where group_row.id = group_id
          and group_row.institution_id = institution_id
          and (unit_id is null or group_row.unit_id = unit_id)
      ) then
        raise check_violation using message = 'group belongs to another context';
      end if;
      select role.id
      into role_id
      from public.institution_roles role
      where role.institution_id = institution_id
        and role.code = btrim(context ->> 'role_code')
        and role.status = 'active'
      limit 1;
      if role_id is null then
        raise foreign_key_violation using
          message = 'contextual role does not belong to institution';
      end if;
      role_scope_kind := case
        when group_id is not null then 'group'
        when unit_id is not null then 'unit'
        else 'institution'
      end;

      membership_id := null;
      select existing_membership.id
      into membership_id
      from public.institution_memberships existing_membership
      where existing_membership.person_id = created_person.id
        and existing_membership.institution_id = institution_id
        and existing_membership.status = 'active'
        and existing_membership.revoked_at is null
      limit 1;
      if membership_id is null then
        insert into public.institution_memberships(
          person_id,
          institution_id,
          role_code,
          status,
          scope_kind,
          scope_unit_id,
          scope_group_id
        )
        values (
          created_person.id,
          institution_id,
          btrim(context ->> 'role_code'),
          'active',
          role_scope_kind,
          unit_id,
          group_id
        )
        returning id into membership_id;
      end if;

      insert into public.institution_role_assignments(
        membership_id,
        role_id,
        scope_kind,
        scope_unit_id,
        scope_group_id
      )
      values (
        membership_id,
        role_id,
        role_scope_kind,
        unit_id,
        group_id
      )
      returning id into assignment_id;

      insert into audit.audit_logs(
        actor_person_id,
        actor_membership_id,
        mfa_aal,
        action_code,
        object_type,
        object_id,
        institution_id,
        outcome,
        after_json
      )
      values (
        actor_person_id,
        app_private.platform_permission_membership_id(
          'people.memberships.manage'
        ),
        auth.jwt() ->> 'aal',
        'people.membership.context.add',
        'institution_role_assignments',
        assignment_id,
        institution_id,
        'success',
        jsonb_build_object(
          'operation', 'add',
          'changed_fields', jsonb_build_array('role', 'scope')
        )
      );
    elsif p_person_type = 'child' and context_kind = 'child_context' then
      unit_id := nullif(
        coalesce(context ->> 'unit_id', context ->> 'scope_unit_id'), ''
      )::uuid;
      group_id := nullif(
        coalesce(context ->> 'group_id', context ->> 'scope_group_id'), ''
      )::uuid;
      if institution_id is null then
        raise invalid_parameter_value using
          message = 'child context requires institution';
      end if;
      if unit_id is not null and not exists (
        select 1 from public.units unit
        where unit.id = unit_id and unit.institution_id = institution_id
      ) then
        raise check_violation using message = 'unit belongs to another institution';
      end if;
      if group_id is not null and (
        unit_id is null or not exists (
          select 1 from public.groups group_row
          where group_row.id = group_id
            and group_row.institution_id = institution_id
            and group_row.unit_id = unit_id
        )
      ) then
        raise check_violation using message = 'group belongs to another context';
      end if;

      insert into public.child_contexts(child_person_id, institution_id)
      values (created_person.id, institution_id)
      returning id into child_context_id;
      if unit_id is not null then
        insert into public.child_unit_links(
          child_context_id, unit_id, status
        )
        values (child_context_id, unit_id, 'pending')
        returning id into child_unit_link_id;
      end if;
      if group_id is not null then
        insert into public.child_group_links(child_unit_link_id, group_id)
        values (child_unit_link_id, group_id)
        returning id into child_group_link_id;
      end if;

      insert into audit.audit_logs(
        actor_person_id,
        actor_membership_id,
        mfa_aal,
        action_code,
        object_type,
        object_id,
        institution_id,
        outcome,
        after_json
      )
      values (
        actor_person_id,
        app_private.platform_permission_membership_id(
          'people.child_contexts.manage'
        ),
        auth.jwt() ->> 'aal',
        'people.child_context.context.add',
        'child_contexts',
        child_context_id,
        institution_id,
        'success',
        jsonb_build_object(
          'operation', 'add',
          'changed_fields',
            jsonb_build_array('institution', 'unit', 'group')
        )
      );
    else
      raise invalid_parameter_value using
        message = 'context kind does not match person type';
    end if;
  end loop;

  actor_platform_membership_id :=
    app_private.platform_permission_membership_id('people.create');

  insert into audit.audit_logs(
    actor_person_id,
    actor_membership_id,
    mfa_aal,
    action_code,
    object_type,
    object_id,
    outcome,
    after_json
  )
  values (
    actor_person_id,
    actor_platform_membership_id,
    auth.jwt() ->> 'aal',
    'people.create_draft',
    'people',
    created_person.id,
    'success',
    jsonb_build_object(
      'changed_fields', jsonb_build_array('person_type', 'identity', 'contexts'),
      'context_count', jsonb_array_length(coalesce(p_contexts, '[]'::jsonb))
    )
  );

  return jsonb_build_object(
    'id', created_person.id,
    'person_type', created_person.person_type,
    'display_name', created_person.display_name,
    'status', created_person.status,
    'updated_at', created_person.updated_at
  );
end
$$;

create or replace function app_private.update_superadmin_person(
  p_person_id uuid,
  p_expected_updated_at timestamptz,
  p_identity_patch jsonb default '{}'::jsonb,
  p_context_changes jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  current_person public.people;
  updated_person public.people;
  change jsonb;
  membership public.institution_memberships;
  assignment public.institution_role_assignments;
  child_context public.child_contexts;
  institution_id uuid;
  unit_id uuid;
  group_id uuid;
  role_id uuid;
  role_scope_kind text;
  child_unit_link_id uuid;
  child_group_link_id uuid;
  child_unit_link_count integer;
  child_group_link_count integer;
  changed_fields text[];
  actor_person_id uuid;
  actor_platform_membership_id uuid;
begin
  perform app_private.assert_people_permission('people.update');

  if jsonb_typeof(coalesce(p_identity_patch, '{}'::jsonb)) <> 'object'
     or jsonb_typeof(coalesce(p_context_changes, '[]'::jsonb)) <> 'array' then
    raise invalid_parameter_value using message = 'invalid patch shape';
  end if;
  if exists (
    select 1
    from jsonb_object_keys(coalesce(p_identity_patch, '{}'::jsonb)) key
    where key not in ('first_name', 'last_name', 'display_name', 'legal_name')
  ) then
    raise invalid_parameter_value using message = 'identity field is not editable';
  end if;

  select *
  into current_person
  from public.people person
  where person.id = p_person_id
    and person.deleted_at is null
  for update;
  if not found then
    raise no_data_found using message = 'person not found';
  end if;
  if current_person.person_type = 'service' then
    raise invalid_parameter_value using message = 'service people are read-only';
  end if;
  if current_person.updated_at <> p_expected_updated_at then
    raise serialization_failure using message = 'person was updated concurrently';
  end if;

  select coalesce(array_agg(key order by key), array[]::text[])
  into changed_fields
  from jsonb_object_keys(coalesce(p_identity_patch, '{}'::jsonb)) key;

  if jsonb_array_length(coalesce(p_context_changes, '[]'::jsonb)) > 0 then
    if current_person.person_type = 'adult' then
      perform app_private.assert_people_permission('people.memberships.manage');
    else
      perform app_private.assert_people_permission('people.child_contexts.manage');
    end if;
  end if;

  actor_person_id := app_private.current_person_id();
  actor_platform_membership_id :=
    app_private.platform_permission_membership_id('people.update');

  update public.people person
  set
    first_name = case
      when p_identity_patch ? 'first_name'
        then coalesce(nullif(btrim(p_identity_patch ->> 'first_name'), ''), person.first_name)
      else person.first_name
    end,
    last_name = case
      when p_identity_patch ? 'last_name'
        then coalesce(nullif(btrim(p_identity_patch ->> 'last_name'), ''), person.last_name)
      else person.last_name
    end,
    display_name = case
      when p_identity_patch ? 'display_name'
        then coalesce(nullif(btrim(p_identity_patch ->> 'display_name'), ''), person.display_name)
      else person.display_name
    end,
    legal_name = case
      when p_identity_patch ? 'legal_name'
        then nullif(btrim(p_identity_patch ->> 'legal_name'), '')
      else person.legal_name
    end,
    updated_at = greatest(
      clock_timestamp(),
      person.updated_at + interval '1 microsecond'
    )
  where person.id = p_person_id
  returning * into updated_person;

  for change in
    select value
    from jsonb_array_elements(coalesce(p_context_changes, '[]'::jsonb))
  loop
    if current_person.person_type = 'adult'
       and change ->> 'kind' = 'institution_membership' then
      if change ->> 'operation' = 'add' then
        institution_id := nullif(change ->> 'institution_id', '')::uuid;
        unit_id := nullif(change ->> 'scope_unit_id', '')::uuid;
        group_id := nullif(change ->> 'scope_group_id', '')::uuid;
        if institution_id is null
           or nullif(btrim(change ->> 'role_code'), '') is null then
          raise invalid_parameter_value using message = 'membership context is incomplete';
        end if;
        if unit_id is not null and not exists (
          select 1 from public.units unit
          where unit.id = unit_id and unit.institution_id = institution_id
        ) then
          raise check_violation using message = 'unit belongs to another institution';
        end if;
        if group_id is not null and not exists (
          select 1 from public.groups group_row
          where group_row.id = group_id
            and group_row.institution_id = institution_id
            and (unit_id is null or group_row.unit_id = unit_id)
        ) then
          raise check_violation using message = 'group belongs to another context';
        end if;
        select role.id
        into role_id
        from public.institution_roles role
        where role.institution_id = institution_id
          and role.code = btrim(change ->> 'role_code')
          and role.status = 'active'
        limit 1;
        if role_id is null then
          raise foreign_key_violation using
            message = 'contextual role does not belong to institution';
        end if;
        role_scope_kind := case
          when group_id is not null then 'group'
          when unit_id is not null then 'unit'
          else 'institution'
        end;
        if nullif(change ->> 'membership_id', '') is not null then
          select *
          into membership
          from public.institution_memberships target
          where target.id = (change ->> 'membership_id')::uuid
            and target.person_id = p_person_id
            and target.institution_id = institution_id
            and target.status = 'active'
            and target.revoked_at is null
          for update;
          if not found then
            raise no_data_found using
              message = 'membership not found for person and institution';
          end if;
        else
          select *
          into membership
          from public.institution_memberships target
          where target.person_id = p_person_id
            and target.institution_id = institution_id
            and target.status = 'active'
            and target.revoked_at is null
          for update;
          if not found then
            insert into public.institution_memberships(
              person_id,
              institution_id,
              role_code,
              status,
              scope_kind,
              scope_unit_id,
              scope_group_id
            ) values (
              p_person_id,
              institution_id,
              btrim(change ->> 'role_code'),
              'active',
              role_scope_kind,
              unit_id,
              group_id
            )
            returning * into membership;
          end if;
        end if;
        insert into public.institution_role_assignments(
          membership_id,
          role_id,
          scope_kind,
          scope_unit_id,
          scope_group_id
        )
        values (
          membership.id,
          role_id,
          role_scope_kind,
          unit_id,
          group_id
        )
        returning * into assignment;
      elsif change ->> 'operation' in ('update', 'revoke') then
        select *
        into membership
        from public.institution_memberships target
        where target.id = nullif(change ->> 'membership_id', '')::uuid
          and target.person_id = p_person_id
        for update;
        if not found then
          raise no_data_found using message = 'membership not found for person';
        end if;
        select *
        into assignment
        from public.institution_role_assignments target
        where target.id = nullif(change ->> 'assignment_id', '')::uuid
          and target.membership_id = membership.id
        for update;
        if not found then
          raise no_data_found using message = 'role assignment not found for membership';
        end if;
        if change ->> 'operation' = 'revoke' then
          update public.institution_role_assignments target
          set status = 'inactive', updated_at = clock_timestamp()
          where target.id = assignment.id;
          if not exists (
            select 1
            from public.institution_role_assignments remaining
            where remaining.membership_id = membership.id
              and remaining.status = 'active'
          ) then
            update public.institution_memberships target
            set status = 'inactive', revoked_at = clock_timestamp()
            where target.id = membership.id;
          end if;
        else
          institution_id := membership.institution_id;
          unit_id := case
            when change ? 'scope_unit_id'
              then nullif(change ->> 'scope_unit_id', '')::uuid
            else assignment.scope_unit_id
          end;
          group_id := case
            when change ? 'scope_group_id'
              then nullif(change ->> 'scope_group_id', '')::uuid
            else assignment.scope_group_id
          end;
          if unit_id is not null and not exists (
            select 1 from public.units unit
            where unit.id = unit_id and unit.institution_id = institution_id
          ) then
            raise check_violation using message = 'unit belongs to another institution';
          end if;
          if group_id is not null and not exists (
            select 1 from public.groups group_row
            where group_row.id = group_id
              and group_row.institution_id = institution_id
              and (unit_id is null or group_row.unit_id = unit_id)
          ) then
            raise check_violation using message = 'group belongs to another context';
          end if;
          select role.id
          into role_id
          from public.institution_roles role
          where role.institution_id = institution_id
            and role.code = coalesce(
              nullif(btrim(change ->> 'role_code'), ''),
              (
                select assigned_role.code
                from public.institution_roles assigned_role
                where assigned_role.id = assignment.role_id
              )
            )
            and role.status = 'active'
          limit 1;
          if role_id is null then
            raise foreign_key_violation using
              message = 'contextual role does not belong to institution';
          end if;
          role_scope_kind := case
            when group_id is not null then 'group'
            when unit_id is not null then 'unit'
            else 'institution'
          end;
          update public.institution_role_assignments target
          set
            role_id = role_id,
            scope_kind = role_scope_kind,
            scope_unit_id = unit_id,
            scope_group_id = group_id,
            updated_at = clock_timestamp()
          where target.id = assignment.id
          returning * into assignment;
        end if;
      else
        raise invalid_parameter_value using message = 'unsupported membership operation';
      end if;
    elsif current_person.person_type = 'child'
          and change ->> 'kind' = 'child_context' then
      if change ->> 'operation' = 'add' then
        institution_id := nullif(change ->> 'institution_id', '')::uuid;
        unit_id := nullif(change ->> 'unit_id', '')::uuid;
        group_id := nullif(change ->> 'group_id', '')::uuid;
        if institution_id is null then
          raise invalid_parameter_value using message = 'child context requires institution';
        end if;
        if unit_id is not null and not exists (
          select 1 from public.units unit
          where unit.id = unit_id and unit.institution_id = institution_id
        ) then
          raise check_violation using message = 'unit belongs to another institution';
        end if;
        if group_id is not null and (
          unit_id is null or not exists (
            select 1 from public.groups group_row
            where group_row.id = group_id
              and group_row.institution_id = institution_id
              and group_row.unit_id = unit_id
          )
        ) then
          raise check_violation using message = 'group belongs to another context';
        end if;
        select *
        into child_context
        from public.child_contexts target
        where target.child_person_id = p_person_id
          and target.institution_id = institution_id
        for update;
        if found then
          update public.child_contexts target
          set
            status = 'active',
            archived_at = null,
            updated_at = clock_timestamp()
          where target.id = child_context.id
          returning * into child_context;
        else
          insert into public.child_contexts(child_person_id, institution_id)
          values (p_person_id, institution_id)
          returning * into child_context;
        end if;
        if unit_id is not null then
          insert into public.child_unit_links(child_context_id, unit_id, status)
          values (child_context.id, unit_id, 'pending')
          on conflict (child_context_id, unit_id)
          do update set
            status = 'pending',
            accepted_by = null,
            accepted_at = null,
            revoked_at = null,
            updated_at = clock_timestamp()
          returning id into child_unit_link_id;
        end if;
        if group_id is not null then
          insert into public.child_group_links(
            child_unit_link_id,
            group_id,
            status
          )
          values (child_unit_link_id, group_id, 'active')
          on conflict (child_unit_link_id, group_id)
          do update set
            status = 'active',
            ends_at = null,
            updated_at = clock_timestamp()
          returning id into child_group_link_id;
        end if;
      elsif change ->> 'operation' in ('update', 'revoke') then
        select *
        into child_context
        from public.child_contexts target
        where target.id = nullif(change ->> 'child_context_id', '')::uuid
          and target.child_person_id = p_person_id
        for update;
        if not found then
          raise no_data_found using message = 'child context not found for person';
        end if;
        if change ->> 'operation' = 'revoke' then
          update public.child_group_links group_link
          set status = 'inactive', updated_at = clock_timestamp()
          where group_link.child_unit_link_id in (
            select child_unit_link.id
            from public.child_unit_links child_unit_link
            where child_unit_link.child_context_id = child_context.id
          );
          update public.child_unit_links unit_link
          set status = 'inactive', revoked_at = clock_timestamp()
          where unit_link.child_context_id = child_context.id;
          update public.child_contexts target
          set status = 'inactive', updated_at = clock_timestamp()
          where target.id = child_context.id;
        else
          unit_id := case
            when change ? 'unit_id'
              then nullif(change ->> 'unit_id', '')::uuid
            else null
          end;
          group_id := case
            when change ? 'group_id'
              then nullif(change ->> 'group_id', '')::uuid
            else null
          end;
          child_unit_link_id :=
            nullif(change ->> 'child_unit_link_id', '')::uuid;
          child_group_link_id :=
            nullif(change ->> 'child_group_link_id', '')::uuid;

          if unit_id is null then
            raise invalid_parameter_value using
              message = 'child context update requires unit';
          end if;
          if child_unit_link_id is null then
            select count(*)
            into child_unit_link_count
            from public.child_unit_links unit_link
            where unit_link.child_context_id = child_context.id
              and unit_link.status in (
                'pending', 'awaiting_allocation', 'active'
              )
              and unit_link.revoked_at is null;
            if child_unit_link_count > 1 then
              raise invalid_parameter_value using
                message = 'child unit link id is required for ambiguous context';
            elsif child_unit_link_count = 0 then
              insert into public.child_unit_links(
                child_context_id,
                unit_id,
                status
              )
              values (child_context.id, unit_id, 'pending')
              returning id into child_unit_link_id;
            else
              select unit_link.id
              into child_unit_link_id
              from public.child_unit_links unit_link
              where unit_link.child_context_id = child_context.id
                and unit_link.status in (
                  'pending', 'awaiting_allocation', 'active'
                )
                and unit_link.revoked_at is null
              order by unit_link.created_at, unit_link.id
              limit 1;
            end if;
          end if;
          if not exists (
            select 1
            from public.child_unit_links unit_link
            where unit_link.id = child_unit_link_id
              and unit_link.child_context_id = child_context.id
          ) then
            raise no_data_found using
              message = 'child unit link not found for context';
          end if;
          if not exists (
            select 1
            from public.units unit
            where unit.id = unit_id
              and unit.institution_id = child_context.institution_id
          ) then
            raise check_violation using
              message = 'unit belongs to another institution';
          end if;
          if group_id is not null and not exists (
            select 1
            from public.groups group_row
            where group_row.id = group_id
              and group_row.institution_id = child_context.institution_id
              and group_row.unit_id = unit_id
          ) then
            raise check_violation using
              message = 'group belongs to another context';
          end if;

          update public.child_unit_links unit_link
          set
            unit_id = unit_id,
            status = 'pending',
            accepted_by = null,
            accepted_at = null,
            revoked_at = null,
            updated_at = clock_timestamp()
          where unit_link.id = child_unit_link_id;

          if child_group_link_id is null then
            select count(*)
            into child_group_link_count
            from public.child_group_links group_link
            where group_link.child_unit_link_id = child_unit_link_id
              and group_link.status = 'active';
            if child_group_link_count > 1 then
              raise invalid_parameter_value using
                message = 'child group link id is required for ambiguous context';
            elsif child_group_link_count = 1 then
              select group_link.id
              into child_group_link_id
              from public.child_group_links group_link
              where group_link.child_unit_link_id = child_unit_link_id
                and group_link.status = 'active'
              order by group_link.created_at, group_link.id
              limit 1;
            end if;
          end if;
          if child_group_link_id is not null then
            if not exists (
              select 1
              from public.child_group_links group_link
              where group_link.id = child_group_link_id
                and group_link.child_unit_link_id = child_unit_link_id
            ) then
              raise no_data_found using
                message = 'child group link not found for unit link';
            end if;
            update public.child_group_links group_link
            set
              group_id = coalesce(group_id, group_link.group_id),
              status = case
                when group_id is null then 'inactive'
                else 'active'
              end,
              updated_at = clock_timestamp()
            where group_link.id = child_group_link_id;
          elsif group_id is not null then
            insert into public.child_group_links(
              child_unit_link_id,
              group_id,
              status
            )
            values (child_unit_link_id, group_id, 'active')
            on conflict (child_unit_link_id, group_id)
            do update set
              status = 'active',
              updated_at = clock_timestamp()
            returning id into child_group_link_id;
          end if;
        end if;
      else
        raise invalid_parameter_value using message = 'unsupported child context operation';
      end if;
    else
      raise invalid_parameter_value using
        message = 'context change does not match person type';
    end if;

    insert into audit.audit_logs(
      actor_person_id,
      actor_membership_id,
      mfa_aal,
      action_code,
      object_type,
      object_id,
      institution_id,
      outcome,
      after_json
    )
    values (
      actor_person_id,
      case
        when current_person.person_type = 'adult'
          then app_private.platform_permission_membership_id(
            'people.memberships.manage'
          )
        else app_private.platform_permission_membership_id(
          'people.child_contexts.manage'
        )
      end,
      auth.jwt() ->> 'aal',
      case
        when current_person.person_type = 'adult'
          then 'people.membership.context.' || (change ->> 'operation')
        else 'people.child_context.context.' || (change ->> 'operation')
      end,
      case
        when current_person.person_type = 'adult'
          then 'institution_role_assignments'
        else 'child_contexts'
      end,
      case
        when current_person.person_type = 'adult' then assignment.id
        else child_context.id
      end,
      case
        when current_person.person_type = 'adult'
          then membership.institution_id
        else child_context.institution_id
      end,
      'success',
      jsonb_build_object(
        'operation', change ->> 'operation',
        'changed_fields', case
          when current_person.person_type = 'adult'
            then jsonb_build_array('role', 'scope')
          else jsonb_build_array('institution', 'unit', 'group')
        end
      )
    );
  end loop;

  insert into audit.audit_logs(
    actor_person_id,
    actor_membership_id,
    mfa_aal,
    action_code,
    object_type,
    object_id,
    outcome,
    before_json,
    after_json
  )
  values (
    actor_person_id,
    actor_platform_membership_id,
    auth.jwt() ->> 'aal',
    'people.update',
    'people',
    p_person_id,
    'success',
    jsonb_build_object('expected_updated_at', p_expected_updated_at),
    jsonb_build_object(
      'changed_fields', to_jsonb(changed_fields),
      'context_operation_count',
        jsonb_array_length(coalesce(p_context_changes, '[]'::jsonb))
    )
  );

  return jsonb_build_object(
    'id', updated_person.id,
    'person_type', updated_person.person_type,
    'display_name', updated_person.display_name,
    'status', updated_person.status,
    'updated_at', updated_person.updated_at
  );
end
$$;

create or replace function app_private.superadmin_person_payload(
  target_person_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', person.id,
    'first_name', person.first_name,
    'last_name', person.last_name,
    'display_name', person.display_name,
    'legal_name', person.legal_name,
    'type', person.person_type,
    'status', person.status,
    'auth_link', case
      when exists (
        select 1
        from public.person_auth_links auth_link
        where auth_link.person_id = person.id
          and auth_link.status = 'active'
          and auth_link.revoked_at is null
      ) then 'linked'
      when exists (
        select 1
        from public.person_auth_links auth_link
        where auth_link.person_id = person.id
          and auth_link.revoked_at is null
      ) then 'pending'
      else 'unlinked'
    end,
    'memberships', coalesce((
      select jsonb_agg(membership_payload order by membership_payload ->> 'institution_name')
      from (
        select jsonb_build_object(
          'id', assignment.id,
          'assignment_id', assignment.id,
          'membership_id', membership.id,
          'institution_id', membership.institution_id,
          'institution_name', institution.public_name,
          'unit_id', assignment.scope_unit_id,
          'unit_name', unit.name,
          'group_id', assignment.scope_group_id,
          'group_name', group_row.name,
          'role', role.code,
          'role_name', role.name,
          'is_platform', false
        ) as membership_payload
        from public.institution_memberships membership
        join public.institution_role_assignments assignment
          on assignment.membership_id = membership.id
          and assignment.status = 'active'
        join public.institution_roles role
          on role.id = assignment.role_id
        join public.institutions institution
          on institution.id = membership.institution_id
        left join public.units unit
          on unit.id = assignment.scope_unit_id
        left join public.groups group_row
          on group_row.id = assignment.scope_group_id
        where membership.person_id = person.id
          and membership.status = 'active'
          and membership.revoked_at is null
        union all
        select jsonb_build_object(
          'id', child_context.id,
          'institution_id', child_context.institution_id,
          'institution_name', institution.public_name,
          'unit_id', unit_link.unit_id,
          'unit_name', unit.name,
          'group_id', group_link.group_id,
          'group_name', group_row.name,
          'role', 'student',
          'is_platform', false
        )
        from public.child_contexts child_context
        join public.institutions institution
          on institution.id = child_context.institution_id
        left join public.child_unit_links unit_link
          on unit_link.child_context_id = child_context.id
          and unit_link.status in ('pending', 'awaiting_allocation', 'active')
          and unit_link.revoked_at is null
        left join public.units unit on unit.id = unit_link.unit_id
        left join public.child_group_links group_link
          on group_link.child_unit_link_id = unit_link.id
          and group_link.status = 'active'
        left join public.groups group_row on group_row.id = group_link.group_id
        where child_context.child_person_id = person.id
          and child_context.status = 'active'
      ) membership_rows
    ), '[]'::jsonb),
    'child_contexts', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', child_context.id,
          'institution_id', child_context.institution_id,
          'institution_name', institution.public_name,
          'status', child_context.status,
          'child_unit_link_id', (
            select unit_link.id
            from public.child_unit_links unit_link
            where unit_link.child_context_id = child_context.id
              and unit_link.status in (
                'pending', 'awaiting_allocation', 'active'
              )
              and unit_link.revoked_at is null
            order by unit_link.created_at, unit_link.id
            limit 1
          ),
          'child_group_link_id', (
            select group_link.id
            from public.child_unit_links unit_link
            join public.child_group_links group_link
              on group_link.child_unit_link_id = unit_link.id
              and group_link.status = 'active'
            where unit_link.child_context_id = child_context.id
              and unit_link.status in (
                'pending', 'awaiting_allocation', 'active'
              )
              and unit_link.revoked_at is null
            order by group_link.created_at, group_link.id
            limit 1
          ),
          'unit_id', (
            select unit_link.unit_id
            from public.child_unit_links unit_link
            where unit_link.child_context_id = child_context.id
              and unit_link.status in (
                'pending', 'awaiting_allocation', 'active'
              )
              and unit_link.revoked_at is null
            order by unit_link.created_at, unit_link.id
            limit 1
          ),
          'group_id', (
            select group_link.group_id
            from public.child_unit_links unit_link
            join public.child_group_links group_link
              on group_link.child_unit_link_id = unit_link.id
              and group_link.status = 'active'
            where unit_link.child_context_id = child_context.id
              and unit_link.status in (
                'pending', 'awaiting_allocation', 'active'
              )
              and unit_link.revoked_at is null
            order by group_link.created_at, group_link.id
            limit 1
          ),
          'unit_links', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'id', unit_link.id,
                'unit_id', unit_link.unit_id,
                'unit_name', unit.name,
                'status', unit_link.status,
                'group_links', coalesce((
                  select jsonb_agg(
                    jsonb_build_object(
                      'id', group_link.id,
                      'group_id', group_link.group_id,
                      'group_name', group_row.name,
                      'status', group_link.status
                    )
                    order by lower(group_row.name), group_link.id
                  )
                  from public.child_group_links group_link
                  join public.groups group_row
                    on group_row.id = group_link.group_id
                  where group_link.child_unit_link_id = unit_link.id
                    and group_link.status = 'active'
                ), '[]'::jsonb)
              )
              order by lower(unit.name), unit_link.id
            )
            from public.child_unit_links unit_link
            join public.units unit on unit.id = unit_link.unit_id
            where unit_link.child_context_id = child_context.id
              and unit_link.status in (
                'pending', 'awaiting_allocation', 'active'
              )
              and unit_link.revoked_at is null
          ), '[]'::jsonb)
        )
        order by lower(institution.public_name), child_context.id
      )
      from public.child_contexts child_context
      join public.institutions institution
        on institution.id = child_context.institution_id
      where child_context.child_person_id = person.id
        and child_context.status = 'active'
    ), '[]'::jsonb),
    'platform_membership_summary', (
      select string_agg(role.name, ', ' order by role.name)
      from public.platform_memberships membership
      join public.platform_roles role on role.id = membership.role_id
      where membership.person_id = person.id
        and membership.status in ('invited', 'active', 'suspended')
        and membership.revoked_at is null
    ),
    'guardian_links_summary', concat_ws(
      ' · ',
      case when (
        select count(*)
        from public.guardian_links guardian_link
        where guardian_link.guardian_person_id = person.id
          and guardian_link.status = 'active'
          and guardian_link.revoked_at is null
      ) > 0 then (
        select count(*)::text || ' criança(s)'
        from public.guardian_links guardian_link
        where guardian_link.guardian_person_id = person.id
          and guardian_link.status = 'active'
          and guardian_link.revoked_at is null
      ) end,
      case when (
        select count(*)
        from public.guardian_links guardian_link
        where guardian_link.child_person_id = person.id
          and guardian_link.status = 'active'
          and guardian_link.revoked_at is null
      ) > 0 then (
        select count(*)::text || ' responsável(is)'
        from public.guardian_links guardian_link
        where guardian_link.child_person_id = person.id
          and guardian_link.status = 'active'
          and guardian_link.revoked_at is null
      ) end
    ),
    'updated_at', person.updated_at
  )
  from public.people person
  where person.id = target_person_id
    and person.deleted_at is null
$$;

revoke execute on function app_private.superadmin_person_payload(uuid)
  from public, anon, authenticated;
grant execute on function app_private.superadmin_person_payload(uuid)
  to service_role;

create or replace function public.superadmin_people_list(
  p_search text default '',
  p_types public.person_type[] default array[]::public.person_type[],
  p_statuses public.record_status[] default array[]::public.record_status[],
  p_institution_ids uuid[] default array[]::uuid[],
  p_unit_ids uuid[] default array[]::uuid[],
  p_group_ids uuid[] default array[]::uuid[],
  p_contextual_roles text[] default array[]::text[],
  p_auth_links text[] default array[]::text[],
  p_sort text default 'display_name',
  p_sort_ascending boolean default true,
  p_offset integer default 0,
  p_limit integer default 11
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform app_private.assert_people_permission('people.read');
  if p_offset < 0 then
    raise invalid_parameter_value using message = 'offset must not be negative';
  end if;
  if p_limit not in (8, 11, 20, 50, 100) then
    raise invalid_parameter_value using
      message = 'limit must be 8, 11, 20, 50 or 100';
  end if;
  if p_sort not in (
    'display_name', 'type', 'status', 'institution_name', 'unit_name',
    'group_name', 'contextual_role', 'auth_link'
  ) then
    raise invalid_parameter_value using message = 'unsupported people sort';
  end if;
  if exists (
    select 1
    from public.units unit
    where unit.id = any(coalesce(p_unit_ids, array[]::uuid[]))
      and cardinality(coalesce(p_institution_ids, array[]::uuid[])) > 0
      and not unit.institution_id = any(p_institution_ids)
  ) then
    raise check_violation using message = 'unit filter crosses institution selection';
  end if;
  if exists (
    select 1
    from public.groups group_row
    where group_row.id = any(coalesce(p_group_ids, array[]::uuid[]))
      and (
        (
          cardinality(coalesce(p_institution_ids, array[]::uuid[])) > 0
          and not group_row.institution_id = any(p_institution_ids)
        )
        or (
          cardinality(coalesce(p_unit_ids, array[]::uuid[])) > 0
          and not group_row.unit_id = any(p_unit_ids)
        )
      )
  ) then
    raise check_violation using message = 'group filter crosses selected context';
  end if;

  with context_rows as (
    select
      membership.person_id,
      assignment.id as row_id,
      assignment.id as assignment_id,
      membership.id as membership_id,
      null::uuid as child_context_id,
      membership.institution_id,
      institution.public_name as institution_name,
      assignment.scope_unit_id as unit_id,
      unit.name as unit_name,
      assignment.scope_group_id as group_id,
      group_row.name as group_name,
      role.code as contextual_role,
      role.name as contextual_role_name
    from public.institution_memberships membership
    join public.institution_role_assignments assignment
      on assignment.membership_id = membership.id
      and assignment.status = 'active'
    join public.institution_roles role on role.id = assignment.role_id
    join public.institutions institution
      on institution.id = membership.institution_id
    left join public.units unit on unit.id = assignment.scope_unit_id
    left join public.groups group_row on group_row.id = assignment.scope_group_id
    where membership.status = 'active'
      and membership.revoked_at is null
    union all
    select
      child_context.child_person_id,
      child_context.id,
      null::uuid,
      null::uuid,
      child_context.id,
      child_context.institution_id,
      institution.public_name,
      unit_link.unit_id,
      unit.name,
      group_link.group_id,
      group_row.name,
      'student',
      'Aluno'
    from public.child_contexts child_context
    join public.institutions institution
      on institution.id = child_context.institution_id
    left join public.child_unit_links unit_link
      on unit_link.child_context_id = child_context.id
      and unit_link.status in ('pending', 'awaiting_allocation', 'active')
      and unit_link.revoked_at is null
    left join public.units unit on unit.id = unit_link.unit_id
    left join public.child_group_links group_link
      on group_link.child_unit_link_id = unit_link.id
      and group_link.status = 'active'
    left join public.groups group_row on group_row.id = group_link.group_id
    where child_context.status = 'active'
  ),
  context_summary as (
    select
      context_row.person_id,
      min(lower(context_row.institution_name)) as institution_sort,
      min(lower(context_row.unit_name)) as unit_sort,
      min(lower(context_row.group_name)) as group_sort,
      min(lower(context_row.contextual_role_name)) as role_sort
    from context_rows context_row
    group by context_row.person_id
  ),
  filtered as (
    select
      person.id,
      person.display_name,
      person.person_type,
      person.status,
      person.updated_at,
      coalesce(context_summary.institution_sort, '') as institution_sort,
      coalesce(context_summary.unit_sort, '') as unit_sort,
      coalesce(context_summary.group_sort, '') as group_sort,
      coalesce(context_summary.role_sort, '') as role_sort,
      case
        when exists (
          select 1 from public.person_auth_links auth_link
          where auth_link.person_id = person.id
            and auth_link.status = 'active'
            and auth_link.revoked_at is null
        ) then 'linked'
        when exists (
          select 1 from public.person_auth_links auth_link
          where auth_link.person_id = person.id
            and auth_link.revoked_at is null
        ) then 'pending'
        else 'unlinked'
      end as auth_link_state
    from public.people person
    left join context_summary on context_summary.person_id = person.id
    where person.deleted_at is null
      and (
        nullif(btrim(coalesce(p_search, '')), '') is null
        or person.display_name ilike '%' || btrim(p_search) || '%'
      )
      and (
        cardinality(coalesce(p_types, array[]::public.person_type[])) = 0
        or person.person_type = any(p_types)
      )
      and (
        cardinality(coalesce(p_statuses, array[]::public.record_status[])) = 0
        or person.status = any(p_statuses)
      )
      and (
        cardinality(coalesce(p_auth_links, array[]::text[])) = 0
        or (
          case
            when exists (
              select 1 from public.person_auth_links auth_link
              where auth_link.person_id = person.id
                and auth_link.status = 'active'
                and auth_link.revoked_at is null
            ) then 'linked'
            when exists (
              select 1 from public.person_auth_links auth_link
              where auth_link.person_id = person.id
                and auth_link.revoked_at is null
            ) then 'pending'
            else 'unlinked'
          end
        ) = any(p_auth_links)
      )
      and (
        (
          cardinality(coalesce(p_institution_ids, array[]::uuid[])) = 0
          and cardinality(coalesce(p_unit_ids, array[]::uuid[])) = 0
          and cardinality(coalesce(p_group_ids, array[]::uuid[])) = 0
          and cardinality(coalesce(p_contextual_roles, array[]::text[])) = 0
        )
        or exists (
          select 1
          from context_rows context_row
          where context_row.person_id = person.id
            and (
              cardinality(coalesce(p_institution_ids, array[]::uuid[])) = 0
              or context_row.institution_id = any(p_institution_ids)
            )
            and (
              cardinality(coalesce(p_unit_ids, array[]::uuid[])) = 0
              or context_row.unit_id = any(p_unit_ids)
            )
            and (
              cardinality(coalesce(p_group_ids, array[]::uuid[])) = 0
              or context_row.group_id = any(p_group_ids)
            )
            and (
              cardinality(coalesce(p_contextual_roles, array[]::text[])) = 0
              or context_row.contextual_role = any(p_contextual_roles)
            )
        )
      )
  ),
  ranked as (
    select
      filtered.*,
      row_number() over (
        order by
          case when p_sort_ascending and p_sort = 'display_name'
            then lower(display_name) end asc,
          case when not p_sort_ascending and p_sort = 'display_name'
            then lower(display_name) end desc,
          case when p_sort_ascending and p_sort = 'type'
            then person_type::text end asc,
          case when not p_sort_ascending and p_sort = 'type'
            then person_type::text end desc,
          case when p_sort_ascending and p_sort = 'status'
            then status::text end asc,
          case when not p_sort_ascending and p_sort = 'status'
            then status::text end desc,
          case when p_sort_ascending and p_sort = 'institution_name'
            then institution_sort end asc,
          case when not p_sort_ascending and p_sort = 'institution_name'
            then institution_sort end desc,
          case when p_sort_ascending and p_sort = 'unit_name'
            then unit_sort end asc,
          case when not p_sort_ascending and p_sort = 'unit_name'
            then unit_sort end desc,
          case when p_sort_ascending and p_sort = 'group_name'
            then group_sort end asc,
          case when not p_sort_ascending and p_sort = 'group_name'
            then group_sort end desc,
          case when p_sort_ascending and p_sort = 'contextual_role'
            then role_sort end asc,
          case when not p_sort_ascending and p_sort = 'contextual_role'
            then role_sort end desc,
          case when p_sort_ascending and p_sort = 'auth_link'
            then auth_link_state end asc,
          case when not p_sort_ascending and p_sort = 'auth_link'
            then auth_link_state end desc,
          lower(display_name),
          id
      ) as ordinal
    from filtered
  ),
  page_rows as (
    select *
    from ranked
    where ordinal > p_offset
      and ordinal <= p_offset + p_limit
  ),
  membership_payloads as (
    select
      page_row.id as person_id,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', context_row.row_id,
            'assignment_id', context_row.assignment_id,
            'membership_id', context_row.membership_id,
            'child_context_id', context_row.child_context_id,
            'institution_id', context_row.institution_id,
            'institution_name', context_row.institution_name,
            'unit_id', context_row.unit_id,
            'unit_name', context_row.unit_name,
            'group_id', context_row.group_id,
            'group_name', context_row.group_name,
            'role', context_row.contextual_role,
            'role_name', context_row.contextual_role_name
          )
          order by
            lower(context_row.institution_name),
            lower(context_row.unit_name),
            lower(context_row.group_name),
            context_row.row_id
        ) filter (where context_row.row_id is not null),
        '[]'::jsonb
      ) as memberships
    from page_rows page_row
    left join context_rows context_row on context_row.person_id = page_row.id
    group by page_row.id
  )
  select jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', page_row.id,
          'display_name', page_row.display_name,
          'type', page_row.person_type,
          'status', page_row.status,
          'auth_link', page_row.auth_link_state,
          'memberships', membership_payload.memberships,
          'updated_at', page_row.updated_at
        )
        order by page_row.ordinal
      )
      from page_rows page_row
      join membership_payloads membership_payload
        on membership_payload.person_id = page_row.id
    ), '[]'::jsonb),
    'total_count', (select count(*) from filtered)
  )
  into result;
  return result;
end
$$;

create or replace function public.superadmin_people_filter_options()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform app_private.assert_people_permission('people.read');
  return jsonb_build_object(
    'institutions', coalesce((
      select jsonb_agg(
        jsonb_build_object('id', institution.id, 'label', institution.public_name)
        order by lower(institution.public_name), institution.id
      )
      from public.institutions institution
      where institution.deleted_at is null
    ), '[]'::jsonb),
    'units', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', unit.id,
          'label', unit.name,
          'institution_id', unit.institution_id
        )
        order by lower(unit.name), unit.id
      )
      from public.units unit
      where unit.status = 'active'
    ), '[]'::jsonb),
    'groups', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', group_row.id,
          'label', group_row.name,
          'institution_id', group_row.institution_id,
          'unit_id', group_row.unit_id
        )
        order by lower(group_row.name), group_row.id
      )
      from public.groups group_row
      where group_row.status = 'active'
    ), '[]'::jsonb),
    'roles', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', role.id,
          'label', role.name,
          'code', role.code,
          'institution_id', role.institution_id
        )
        order by lower(role.name), role.institution_id, role.id
      )
      from public.institution_roles role
      where role.status = 'active'
    ), '[]'::jsonb)
  );
end
$$;

create or replace function public.superadmin_people_detail(p_person_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform app_private.assert_people_permission('people.read');
  result := app_private.superadmin_person_payload(p_person_id);
  if result is null then
    raise no_data_found using message = 'person not found';
  end if;
  return result;
end
$$;

create or replace function public.superadmin_people_create_draft(p_draft jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  person_type public.person_type;
  first_name text;
  last_name text;
  display_name text;
  legal_name text;
  memberships jsonb;
  normalized_contexts jsonb;
  created jsonb;
  created_person_id uuid;
begin
  perform app_private.assert_people_permission('people.create');
  if jsonb_typeof(coalesce(p_draft, '{}'::jsonb)) <> 'object' then
    raise invalid_parameter_value using message = 'draft must be an object';
  end if;
  if exists (
    select 1
    from jsonb_object_keys(coalesce(p_draft, '{}'::jsonb)) key
    where key not in (
      'type',
      'person_type',
      'first_name',
      'last_name',
      'display_name',
      'legal_name',
      'contexts',
      'memberships',
      'child_contexts'
    )
  ) then
    raise invalid_parameter_value using message = 'draft field is not accepted';
  end if;
  person_type := nullif(
    coalesce(p_draft ->> 'person_type', p_draft ->> 'type'), ''
  )::public.person_type;
  first_name := nullif(btrim(p_draft ->> 'first_name'), '');
  last_name := nullif(btrim(p_draft ->> 'last_name'), '');
  display_name := nullif(btrim(p_draft ->> 'display_name'), '');
  legal_name := nullif(btrim(p_draft ->> 'legal_name'), '');
  memberships := case
    when person_type = 'child'
      then coalesce(p_draft -> 'child_contexts', p_draft -> 'memberships')
    else p_draft -> 'memberships'
  end;
  memberships := coalesce(memberships, '[]'::jsonb);
  if person_type is null
     or first_name is null
     or last_name is null
     or display_name is null
     or jsonb_typeof(memberships) <> 'array'
     or (
       p_draft ? 'contexts'
       and jsonb_typeof(p_draft -> 'contexts') <> 'array'
     ) then
    raise invalid_parameter_value using message = 'draft identity is incomplete';
  end if;

  if p_draft ? 'contexts' then
    normalized_contexts := p_draft -> 'contexts';
  else
    select coalesce(jsonb_agg(
      case
        when person_type = 'adult' then jsonb_build_object(
          'kind', 'institution_membership',
          'institution_id', membership ->> 'institution_id',
          'scope_unit_id', membership ->> 'unit_id',
          'scope_group_id', membership ->> 'group_id',
          'role_code', coalesce(
            membership ->> 'role_code', membership ->> 'role'
          )
        )
        else jsonb_build_object(
          'kind', 'child_context',
          'institution_id', membership ->> 'institution_id',
          'unit_id', membership ->> 'unit_id',
          'group_id', membership ->> 'group_id'
        )
      end
    ), '[]'::jsonb)
    into normalized_contexts
    from jsonb_array_elements(memberships) membership;
  end if;

  created := app_private.create_superadmin_person_draft(
    person_type,
    first_name,
    last_name,
    display_name,
    legal_name,
    normalized_contexts
  );
  created_person_id := (created ->> 'id')::uuid;
  return app_private.superadmin_person_payload(created_person_id);
end
$$;

create or replace function public.superadmin_people_update(p_update jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  person_id uuid;
  expected_updated_at timestamptz;
  person_type public.person_type;
  normalized_changes jsonb;
begin
  perform app_private.assert_people_permission('people.update');
  if jsonb_typeof(coalesce(p_update, '{}'::jsonb)) <> 'object' then
    raise invalid_parameter_value using message = 'update must be an object';
  end if;
  if exists (
    select 1
    from jsonb_object_keys(coalesce(p_update, '{}'::jsonb)) key
    where key not in (
      'person_id',
      'expected_updated_at',
      'first_name',
      'last_name',
      'display_name',
      'legal_name',
      'context_changes',
      'membership_changes',
      'child_context_changes'
    )
  ) then
    raise invalid_parameter_value using message = 'update field is not editable';
  end if;
  person_id := nullif(p_update ->> 'person_id', '')::uuid;
  expected_updated_at :=
    nullif(p_update ->> 'expected_updated_at', '')::timestamptz;
  select person.person_type
  into person_type
  from public.people person
  where person.id = person_id
    and person.deleted_at is null;
  if not found then
    raise no_data_found using message = 'person not found';
  end if;
  if expected_updated_at is null then
    raise invalid_parameter_value using message = 'expected_updated_at is required';
  end if;

  if p_update ? 'context_changes' then
    if jsonb_typeof(p_update -> 'context_changes') <> 'array' then
      raise invalid_parameter_value using message = 'context_changes must be an array';
    end if;
    normalized_changes := p_update -> 'context_changes';
  else
    select coalesce(jsonb_agg(jsonb_build_object(
      'kind', case
        when person_type = 'adult' then 'institution_membership'
        else 'child_context'
      end,
      'operation', case
        when change ->> 'operation' = 'remove' then 'revoke'
        else change ->> 'operation'
      end,
      'membership_id', change ->> 'membership_id',
      'assignment_id', change ->> 'assignment_id',
      'child_context_id', coalesce(
        change ->> 'child_context_id',
        change ->> 'membership_id'
      ),
      'child_unit_link_id', change ->> 'child_unit_link_id',
      'child_group_link_id', change ->> 'child_group_link_id',
      'institution_id', change ->> 'institution_id',
      'scope_unit_id', change ->> 'unit_id',
      'scope_group_id', change ->> 'group_id',
      'unit_id', change ->> 'unit_id',
      'group_id', change ->> 'group_id',
      'role_code', coalesce(change ->> 'role_code', change ->> 'role')
    )), '[]'::jsonb)
    into normalized_changes
    from jsonb_array_elements(case
      when person_type = 'child'
        then coalesce(p_update -> 'child_context_changes', '[]'::jsonb)
      else coalesce(p_update -> 'membership_changes', '[]'::jsonb)
    end) change;
  end if;

  perform app_private.update_superadmin_person(
    person_id,
    expected_updated_at,
    p_update
      - 'person_id'
      - 'expected_updated_at'
      - 'context_changes'
      - 'membership_changes'
      - 'child_context_changes',
    normalized_changes
  );

  return app_private.superadmin_person_payload(person_id);
end
$$;

revoke execute on function app_private.list_superadmin_people(
  text,
  public.person_type[],
  public.record_status[],
  uuid,
  uuid,
  uuid,
  text,
  boolean,
  integer,
  integer
) from public, anon, authenticated;
revoke execute on function app_private.get_superadmin_person(uuid)
  from public, anon, authenticated;
revoke execute on function app_private.create_superadmin_person_draft(
  public.person_type,
  text,
  text,
  text,
  text,
  jsonb
) from public, anon, authenticated;
revoke execute on function app_private.update_superadmin_person(
  uuid,
  timestamptz,
  jsonb,
  jsonb
) from public, anon, authenticated;

grant execute on function app_private.list_superadmin_people(
  text,
  public.person_type[],
  public.record_status[],
  uuid,
  uuid,
  uuid,
  text,
  boolean,
  integer,
  integer
) to service_role;
grant execute on function app_private.get_superadmin_person(uuid)
  to service_role;
grant execute on function app_private.create_superadmin_person_draft(
  public.person_type,
  text,
  text,
  text,
  text,
  jsonb
) to service_role;
grant execute on function app_private.update_superadmin_person(
  uuid,
  timestamptz,
  jsonb,
  jsonb
) to service_role;

revoke execute on function public.superadmin_people_list(
  text,
  public.person_type[],
  public.record_status[],
  uuid[],
  uuid[],
  uuid[],
  text[],
  text[],
  text,
  boolean,
  integer,
  integer
) from public, anon;
revoke execute on function public.superadmin_people_filter_options()
  from public, anon;
revoke execute on function public.superadmin_people_detail(uuid)
  from public, anon;
revoke execute on function public.superadmin_people_create_draft(jsonb)
  from public, anon;
revoke execute on function public.superadmin_people_update(jsonb)
  from public, anon;

grant execute on function public.superadmin_people_list(
  text,
  public.person_type[],
  public.record_status[],
  uuid[],
  uuid[],
  uuid[],
  text[],
  text[],
  text,
  boolean,
  integer,
  integer
) to authenticated, service_role;
grant execute on function public.superadmin_people_filter_options()
  to authenticated, service_role;
grant execute on function public.superadmin_people_detail(uuid)
  to authenticated, service_role;
grant execute on function public.superadmin_people_create_draft(jsonb)
  to authenticated, service_role;
grant execute on function public.superadmin_people_update(jsonb)
  to authenticated, service_role;
