create or replace function public.list_my_principal_contexts()
returns table(
  membership_id uuid,
  person_id uuid,
  institution_id uuid,
  institution_name text,
  role_code text,
  scope_kind text,
  unit_id uuid,
  unit_name text,
  group_id uuid,
  group_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication_required';
  end if;

  return query
  select
    membership.id,
    membership.person_id,
    membership.institution_id,
    institution.public_name,
    membership.role_code,
    membership.scope_kind,
    scoped_unit.id,
    scoped_unit.name,
    scoped_group.id,
    scoped_group.name
  from public.person_auth_links auth_link
  join public.people person
    on person.id = auth_link.person_id
   and person.status = 'active'
  join public.institution_memberships membership
    on membership.person_id = person.id
   and membership.status = 'active'
   and membership.revoked_at is null
  join public.institutions institution
    on institution.id = membership.institution_id
   and institution.status = 'active'
  left join public.groups scoped_group
    on scoped_group.id = membership.scope_group_id
   and scoped_group.institution_id = membership.institution_id
   and scoped_group.status = 'active'
  left join public.units scoped_unit
    on scoped_unit.id = coalesce(membership.scope_unit_id, scoped_group.unit_id)
   and scoped_unit.institution_id = membership.institution_id
   and scoped_unit.status = 'active'
  where auth_link.auth_user_id = (select auth.uid())
    and auth_link.status = 'active'
    and auth_link.revoked_at is null
    and (
      (
        membership.scope_kind = 'institution'
        and membership.scope_unit_id is null
        and membership.scope_group_id is null
      )
      or (
        membership.scope_kind = 'unit'
        and membership.scope_unit_id is not null
        and membership.scope_group_id is null
        and scoped_unit.id is not null
      )
      or (
        membership.scope_kind = 'group'
        and membership.scope_group_id is not null
        and scoped_group.id is not null
        and (
          membership.scope_unit_id is null
          or membership.scope_unit_id = scoped_group.unit_id
        )
      )
    )
  order by institution.public_name, scoped_unit.name nulls first,
    scoped_group.name nulls first, membership.created_at, membership.id;
end
$$;

revoke all on function public.list_my_principal_contexts()
  from public, anon, authenticated;
grant execute on function public.list_my_principal_contexts() to authenticated;

