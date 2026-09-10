-- Scoped professional lookup for Activity assignments.
-- Contact and CPF lookup intentionally remain fail-closed until the identity
-- domain exposes a server-side keyed lookup command. Their stored digests do
-- not have a public/raw normalization contract.

create or replace function app_private.superadmin_search_activity_professionals(
  p_institution_id uuid,
  p_query text,
  p_limit integer default 20
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := btrim(coalesce(p_query, ''));
  v_handle text;
  v_limit integer;
begin
  if (select auth.uid()) is null
    or app_private.current_person_id() is null then
    raise exception using errcode = '42501', message = 'unauthorized';
  end if;

  if not app_private.has_platform_permission('activities.assign_people') then
    raise exception using errcode = '42501', message = 'unauthorized';
  end if;

  if not app_private.has_mfa_aal2() then
    raise exception using errcode = '42501', message = 'mfa_required';
  end if;

  if p_institution_id is null
    or not exists (
      select 1
      from public.institutions institution_record
      where institution_record.id = p_institution_id
        and institution_record.status = 'active'
    ) then
    raise exception using errcode = 'P0002', message = 'not_found';
  end if;

  if char_length(v_query) < 3 or char_length(v_query) > 160 then
    raise exception using errcode = '22023', message = 'invalid_query';
  end if;

  if p_limit is null or p_limit < 1 or p_limit > 50 then
    raise exception using errcode = '22023', message = 'invalid_limit';
  end if;
  v_limit := p_limit;

  -- A raw CPF, email or phone cannot be compared safely with the current
  -- identity schema: CPF is keyed-HMAC and person_contacts does not publish
  -- the algorithm/key contract for normalized_value_hash. Plain text remains
  -- an institution-scoped display-name search.
  if (position('@' in v_query) > 1)
    or v_query ~ '^[+() 0-9.-]+$' then
    raise exception using
      errcode = '0A000',
      message = 'identity_lookup_not_configured';
  end if;

  if left(v_query, 1) = '@' then
    v_handle := app_private.normalize_person_handle(substr(v_query, 2));
    if char_length(v_handle) < 3 then
      raise exception using errcode = '22023', message = 'invalid_query';
    end if;
  end if;

  return jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'membership_id', candidate.membership_id,
          'person_id', candidate.person_id,
          'name', candidate.display_name,
          'role', candidate.role_code
        )
        order by lower(candidate.display_name), candidate.membership_id
      )
      from (
        select
          membership.id as membership_id,
          person_record.id as person_id,
          person_record.display_name,
          membership.role_code
        from public.institution_memberships membership
        join public.people person_record
          on person_record.id = membership.person_id
         and person_record.status = 'active'
         and person_record.deleted_at is null
         and person_record.person_type <> 'child'
        where membership.institution_id = p_institution_id
          and membership.status = 'active'
          and membership.revoked_at is null
          and (
            (
              v_handle is not null
              and exists (
                select 1
                from public.person_handles person_handle
                where person_handle.person_id = person_record.id
                  and person_handle.status = 'active'
                  and person_handle.revoked_at is null
                  and person_handle.normalized_handle like v_handle || '%'
              )
            )
            or (
              v_handle is null
              and position(lower(v_query) in lower(person_record.display_name)) > 0
            )
          )
        order by lower(person_record.display_name), membership.id
        limit v_limit
      ) candidate
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.superadmin_search_activity_professionals(
  p_institution_id uuid,
  p_query text,
  p_limit integer default 20
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select app_private.superadmin_search_activity_professionals($1, $2, $3)
$$;

revoke all on function app_private.superadmin_search_activity_professionals(uuid, text, integer)
  from public, anon, authenticated;
revoke all on function public.superadmin_search_activity_professionals(uuid, text, integer)
  from public, anon;
grant execute on function public.superadmin_search_activity_professionals(uuid, text, integer)
  to authenticated;

comment on function public.superadmin_search_activity_professionals(uuid, text, integer) is
  'Institution-scoped professional lookup for Activity assignment. Returns minimum identity fields only. Raw CPF/email/phone remain disabled until the identity domain provides a keyed lookup command.';
