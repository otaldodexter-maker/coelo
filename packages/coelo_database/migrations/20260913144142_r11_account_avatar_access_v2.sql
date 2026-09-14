-- R11: self-owned initials/color and real capability metadata. No photo transport added.
begin;
alter table public.people add column account_avatar_initials text check(account_avatar_initials ~ '^[[:alpha:]]{1,2}$');
alter table public.people add column account_avatar_background_color text check(account_avatar_background_color ~ '^#[0-9A-F]{6}$');
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
  -- Pessoa de servico da ponte de ator (220400) nao tem person_auth_links:
  -- o e-mail e o do proprio usuario autenticado (assert_account_actor ja
  -- garante que p_person_id e o ator da sessao).
  if email_value is null and p_person_id = app_private.current_person_id() then
    select u.email into email_value from auth.users u where u.id = auth.uid();
  end if;
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
    'avatar_contract_version', 2, 'first_name', person.first_name, 'last_name', person.last_name,
    'email', coalesce(email_value, ''), 'mobile_phone', coalesce(person.mobile_phone, ''),
    'avatar', jsonb_build_object('mode','initials', 'initials',
      coalesce(person.account_avatar_initials, left(upper(coalesce(nullif(left(trim(person.first_name), 1), ''), '') ||
        coalesce(nullif(left(trim(person.last_name), 1), ''), '')), 2)),
      'background_color', coalesce(person.account_avatar_background_color, '#FFF1EB')),
    'access', jsonb_build_object(
      'role', coalesce(role_value, 'Acesso interno'),
      'mfa_enabled', coalesce((select auth.jwt()->>'aal') = 'aal2', false),
      'capabilities', coalesce((select jsonb_agg(distinct permission.description)
        from public.platform_permissions permission
        where permission.status='active' and exists (
          select 1 from public.platform_memberships membership
          where membership.person_id=p_person_id and membership.status='active'
            and membership.revoked_at is null
            and app_private.has_platform_permission(permission.code,membership.scope_institution_id))), '[]'::jsonb),
      'capability_details', coalesce((select jsonb_agg(item order by item->>'module_label',item->>'scope_label',item->>'label')
        from (select distinct jsonb_build_object(
          'code',permission.code,'label',permission.description,
          'module_code',permission.module_code,'module_label',permission.module_label,
          'scope_kind',membership.scope_kind,'scope_id',membership.scope_institution_id,
          'scope_label',case when membership.scope_kind='platform' then 'Plataforma' else institution.public_name end
        ) item
        from public.platform_memberships membership
        join public.platform_roles role on role.id=membership.role_id and role.status='active'
        cross join public.platform_permissions permission
        left join public.institutions institution on institution.id=membership.scope_institution_id
        where membership.person_id=p_person_id and membership.status='active'
          and membership.revoked_at is null and permission.status='active'
          and app_private.has_platform_permission(permission.code,membership.scope_institution_id)) items), '[]'::jsonb)
    ), 'email_change', pending
  ) into result from public.people person where person.id = p_person_id and person.deleted_at is null;
  if result is null then raise exception using errcode = 'P0002', message = 'account_profile_not_found'; end if;
  return result;
end;
$$;
revoke all on function app_private.account_profile_projection(uuid) from public, anon, authenticated;

create or replace function public.superadmin_account_profile_save_v2(
  p_request_id uuid, p_first_name text, p_last_name text, p_mobile_phone text,
  p_requested_email text default null, p_avatar_initials text default null,
  p_avatar_background_color text default null
) returns jsonb language plpgsql security definer set search_path = ''
as $$
declare actor_id uuid; result jsonb; current_email text; normalized_email text;
begin
  actor_id := app_private.assert_account_actor();
  if p_request_id is null or char_length(trim(coalesce(p_first_name,''))) not between 1 and 80
    or char_length(trim(coalesce(p_last_name,''))) not between 1 and 120
    or char_length(trim(coalesce(p_mobile_phone,''))) not between 7 and 40
    or (p_avatar_background_color is not null and p_avatar_background_color !~ '^#[0-9A-Fa-f]{6}$')
    or (p_avatar_initials is not null and p_avatar_initials !~ '^[[:alpha:]]{1,2}$') then
    raise exception using errcode = '22023', message = 'invalid_account_profile';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
  if exists (select 1 from public.account_profile_command_receipts where request_id=p_request_id and (person_id<>actor_id or action_code<>'save')) then
    raise exception using errcode='42501',message='account_request_not_owned';
  end if;
  select response_json into result from public.account_profile_command_receipts where request_id=p_request_id and person_id=actor_id and action_code='save';
  if result is not null then return result; end if;
  select u.email into current_email
  from auth.users u join public.person_auth_links link on link.auth_user_id = u.id
  where link.person_id = actor_id and link.status = 'active'
  order by link.linked_at desc limit 1;
  if current_email is null then select email into current_email from auth.users where id=auth.uid(); end if;
  update public.people set account_avatar_initials=coalesce(upper(p_avatar_initials),account_avatar_initials),
    account_avatar_background_color=coalesce(upper(p_avatar_background_color),account_avatar_background_color), first_name = trim(p_first_name), last_name = trim(p_last_name),
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
revoke all on function public.superadmin_account_profile_save_v2(uuid,text,text,text,text,text,text) from public,anon;
grant execute on function public.superadmin_account_profile_save_v2(uuid,text,text,text,text,text,text) to authenticated;
create or replace function public.superadmin_account_profile_save(
  p_request_id uuid,p_first_name text,p_last_name text,p_mobile_phone text,
  p_requested_email text default null,p_avatar_initials text default null
) returns jsonb language sql security definer set search_path='' as $$
  select public.superadmin_account_profile_save_v2(p_request_id,p_first_name,p_last_name,p_mobile_phone,p_requested_email,p_avatar_initials,null)
$$;
commit;
