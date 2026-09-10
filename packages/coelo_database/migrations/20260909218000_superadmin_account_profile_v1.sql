-- ACCOUNT-PROFILE-V1
-- Perfil da Conta no realm interno. O cliente consome somente os RPCs.
begin;

alter table public.people add column if not exists mobile_phone text;
alter table public.people
  drop constraint if exists people_mobile_phone_length,
  add constraint people_mobile_phone_length check (mobile_phone is null or char_length(trim(mobile_phone)) between 7 and 40);

create table if not exists public.account_email_change_requests (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people(id) on delete cascade,
  requested_email text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by_person_id uuid references public.people(id) on delete restrict
);

create unique index if not exists account_email_pending_person_uidx
  on public.account_email_change_requests(person_id) where status = 'pending';
alter table public.account_email_change_requests enable row level security;
alter table public.account_email_change_requests force row level security;
revoke all on table public.account_email_change_requests from public, anon, authenticated;

create table if not exists public.account_profile_command_receipts (
  request_id uuid primary key,
  person_id uuid not null references public.people(id) on delete cascade,
  action_code text not null check (action_code in ('save','cancel_email_change')),
  response_json jsonb not null,
  created_at timestamptz not null default now()
);
alter table public.account_profile_command_receipts enable row level security;
alter table public.account_profile_command_receipts force row level security;
revoke all on table public.account_profile_command_receipts from public, anon, authenticated;

create or replace function app_private.assert_account_actor()
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare actor_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;
  actor_id := app_private.current_person_id();
  if actor_id is null then
    raise exception using errcode = '42501', message = 'internal_actor_required';
  end if;
  if not app_private.has_platform_permission('platform.read') then
    raise exception using errcode = '42501', message = 'permission_denied';
  end if;
  return actor_id;
end;
$$;
revoke all on function app_private.assert_account_actor() from public, anon, authenticated;

create or replace function app_private.account_profile_projection(p_person_id uuid)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare result jsonb; email_value text; pending jsonb; role_value text;
begin
  select u.email into email_value
  from auth.users u join public.person_auth_links link on link.auth_user_id = u.id
  where link.person_id = p_person_id and link.status = 'active'
  order by link.linked_at desc limit 1;
  select jsonb_build_object(
    'requested_email', request.requested_email, 'status', request.status,
    'requested_at', request.requested_at
  ) into pending
  from public.account_email_change_requests request
  where request.person_id = p_person_id and request.status = 'pending'
  order by request.requested_at desc limit 1;
  select coalesce(role.name, role.code, 'Acesso interno') into role_value
  from public.platform_memberships membership
  join public.platform_roles role on role.id = membership.role_id
  where membership.person_id = p_person_id and membership.status = 'active'
  order by membership.created_at limit 1;
  select jsonb_build_object(
    'first_name', person.first_name, 'last_name', person.last_name,
    'email', coalesce(email_value, ''), 'mobile_phone', coalesce(person.mobile_phone, ''),
    'avatar', jsonb_build_object('mode','initials', 'initials',
      left(upper(coalesce(nullif(left(trim(person.first_name), 1), ''), '') ||
        coalesce(nullif(left(trim(person.last_name), 1), ''), '')), 2),
      'background_color', '#FFF1EB'),
    'access', jsonb_build_object(
      'role', coalesce(role_value, 'Acesso interno'),
      'mfa_enabled', coalesce((select auth.jwt()->>'aal') = 'aal2', false),
      'capabilities', coalesce((select jsonb_agg(permission.description order by permission.code)
        from public.platform_memberships membership
        join public.platform_role_permissions role_permission on role_permission.role_id = membership.role_id
        join public.platform_permissions permission on permission.id = role_permission.permission_id
        where membership.person_id = p_person_id and membership.status = 'active'
          and role_permission.status = 'active' and role_permission.effect = 'allow'
          and permission.status = 'active'), '[]'::jsonb)
    ), 'email_change', pending
  ) into result from public.people person where person.id = p_person_id and person.deleted_at is null;
  if result is null then raise exception using errcode = 'P0002', message = 'account_profile_not_found'; end if;
  return result;
end;
$$;
revoke all on function app_private.account_profile_projection(uuid) from public, anon, authenticated;

create or replace function public.superadmin_account_profile_get()
returns jsonb language plpgsql security definer set search_path = ''
as $$
begin
  return app_private.account_profile_projection(app_private.assert_account_actor());
end;
$$;

create or replace function public.superadmin_account_profile_save(
  p_request_id uuid, p_first_name text, p_last_name text, p_mobile_phone text,
  p_requested_email text default null, p_avatar_initials text default null
) returns jsonb language plpgsql security definer set search_path = ''
as $$
declare actor_id uuid; result jsonb; current_email text; normalized_email text;
begin
  actor_id := app_private.assert_account_actor();
  if p_request_id is null or char_length(trim(coalesce(p_first_name,''))) not between 1 and 80
    or char_length(trim(coalesce(p_last_name,''))) not between 1 and 120
    or char_length(trim(coalesce(p_mobile_phone,''))) not between 7 and 40
    or (p_avatar_initials is not null and p_avatar_initials !~ '^[[:alpha:]]{1,2}$') then
    raise exception using errcode = '22023', message = 'invalid_account_profile';
  end if;
  select response_json into result from public.account_profile_command_receipts where request_id = p_request_id;
  if result is not null then return result; end if;
  select u.email into current_email
  from auth.users u join public.person_auth_links link on link.auth_user_id = u.id
  where link.person_id = actor_id and link.status = 'active'
  order by link.linked_at desc limit 1;
  update public.people set first_name = trim(p_first_name), last_name = trim(p_last_name),
    display_name = trim(p_first_name) || ' ' || trim(p_last_name), mobile_phone = trim(p_mobile_phone), updated_at = now()
  where id = actor_id and deleted_at is null;
  if not found then raise exception using errcode = 'P0002', message = 'account_profile_not_found'; end if;
  normalized_email := lower(trim(coalesce(p_requested_email, '')));
  if normalized_email <> '' and normalized_email <> lower(coalesce(current_email, '')) then
    insert into public.account_email_change_requests(person_id, requested_email)
      values (actor_id, normalized_email)
      on conflict (person_id) where status = 'pending'
      do update set requested_email = excluded.requested_email, requested_at = now();
  end if;
  result := app_private.account_profile_projection(actor_id);
  insert into public.account_profile_command_receipts(request_id, person_id, action_code, response_json)
    values (p_request_id, actor_id, 'save', result);
  return result;
end;
$$;

create or replace function public.superadmin_account_email_change_cancel(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare actor_id uuid; result jsonb;
begin
  actor_id := app_private.assert_account_actor();
  if p_request_id is null then raise exception using errcode = '22023', message = 'request_id_required'; end if;
  select response_json into result from public.account_profile_command_receipts where request_id = p_request_id;
  if result is not null then return result; end if;
  update public.account_email_change_requests set status = 'cancelled', decided_at = now(), decided_by_person_id = actor_id
    where person_id = actor_id and status = 'pending';
  result := app_private.account_profile_projection(actor_id);
  insert into public.account_profile_command_receipts(request_id, person_id, action_code, response_json)
    values (p_request_id, actor_id, 'cancel_email_change', result);
  return result;
end;
$$;

revoke all on function public.superadmin_account_profile_get() from public, anon;
revoke all on function public.superadmin_account_profile_save(uuid,text,text,text,text,text) from public, anon;
revoke all on function public.superadmin_account_email_change_cancel(uuid) from public, anon;
grant execute on function public.superadmin_account_profile_get() to authenticated;
grant execute on function public.superadmin_account_profile_save(uuid,text,text,text,text,text) to authenticated;
grant execute on function public.superadmin_account_email_change_cancel(uuid) to authenticated;

commit;
