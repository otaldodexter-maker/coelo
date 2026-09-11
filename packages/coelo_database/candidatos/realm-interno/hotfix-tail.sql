-- 2. Reativacao do que a versao anterior desativou indevidamente -------------------
create or replace function app_private.superadmin_internal_actor_scope_reactivate_v1()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare n integer;
begin
  update public.institution_memberships m set status = 'active', revoked_at = null
  from app_private.superadmin_internal_actor_people actor
  where m.person_id = actor.person_id
    and m.status = 'inactive' and m.revoked_at >= now() - interval '24 hours'
    and exists (
      select 1 from app_private.superadmin_internal_actor_scope_targets() t
      where t.person_id = m.person_id and t.institution_id = m.institution_id
    )
    and not exists (
      select 1 from public.institution_memberships other
      where other.person_id = m.person_id and other.institution_id = m.institution_id
        and other.status = 'active' and other.revoked_at is null
    );
  get diagnostics n = row_count;
  return n;
end
$$;
alter function app_private.superadmin_internal_actor_scope_reactivate_v1() owner to postgres;
revoke all on function app_private.superadmin_internal_actor_scope_reactivate_v1() from public, anon, authenticated, service_role;

do $$
declare n integer;
begin
  n := app_private.superadmin_internal_actor_scope_reactivate_v1();
  raise notice 'internal_actor_scope_root_v1_hotfix: % membership(s) de espelho reativada(s)', n;
  n := app_private.superadmin_internal_actor_institution_access_sync();
  raise notice 'internal_actor_scope_root_v1_hotfix: sync reconciliou % linha(s)', n;
end $$;

commit;
