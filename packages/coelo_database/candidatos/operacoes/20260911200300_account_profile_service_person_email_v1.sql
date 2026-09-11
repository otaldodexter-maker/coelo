-- R06 · Operacoes — account.profile: e-mail da pessoa de servico.
-- A projecao lia o e-mail so por person_auth_links; a pessoa de servico da
-- ponte de ator (220400) nao tem vinculo e o Perfil mostrava e-mail vazio.
-- Reaplica app_private.account_profile_projection com fallback para o e-mail
-- do proprio auth.uid() quando p_person_id e o ator da sessao.

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
