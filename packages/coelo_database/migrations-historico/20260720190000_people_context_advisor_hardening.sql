-- Harden the people-context foundation after Supabase advisor validation.

create index if not exists child_unit_access_requests_decided_by_idx
  on public.child_unit_access_requests(decided_by)
  where decided_by is not null;

create index if not exists child_unit_links_accepted_by_idx
  on public.child_unit_links(accepted_by)
  where accepted_by is not null;

create index if not exists institution_role_assignments_granted_by_idx
  on public.institution_role_assignments(granted_by)
  where granted_by is not null;

create index if not exists institution_role_assignments_scope_group_idx
  on public.institution_role_assignments(scope_group_id)
  where scope_group_id is not null;

create index if not exists institution_role_permissions_granted_by_idx
  on public.institution_role_permissions(granted_by)
  where granted_by is not null;

create index if not exists invitations_accepted_by_idx
  on public.invitations(accepted_by)
  where accepted_by is not null;

create index if not exists invitations_institution_idx
  on public.invitations(institution_id);

create index if not exists invitations_invited_by_idx
  on public.invitations(invited_by)
  where invited_by is not null;

alter table public.invitations enable row level security;
revoke all on table public.invitations from anon, authenticated;
grant select on table public.invitations to authenticated;
grant all on table public.invitations to service_role;

drop policy if exists invitations_platform_read on public.invitations;
create policy invitations_platform_read
on public.invitations
for select
to authenticated
using ((select app_private.has_platform_permission('platform.read')));
