begin;

-- Client-provided institution ids are untrusted. A denial for an unknown id
-- must remain auditable without violating the audit institution foreign key or
-- persisting the forged identifier as a trusted tenant reference.
create or replace function app_private.audit_superadmin_internal_denial_if_identified(
  p_permission_code text,p_action_code text,p_reason_code text,
  p_correlation_id uuid,p_institution_id uuid default null
) returns void language plpgsql volatile security definer set search_path='' as $$
declare current_auth_user_id uuid; current_session_id uuid; jwt_aal text;
  auth_link_id uuid; identity_id uuid; membership_id uuid;
  audit_institution_id uuid;
begin
  current_auth_user_id:=auth.uid();
  if current_auth_user_id is null then return; end if;
  begin current_session_id:=(auth.jwt()->>'session_id')::uuid;
  exception when others then return; end;
  if not exists(select 1 from auth.sessions session_record
    where session_record.id=current_session_id and session_record.user_id=current_auth_user_id
      and (session_record.not_after is null or session_record.not_after>pg_catalog.now())) then
    return;
  end if;
  jwt_aal:=auth.jwt()->>'aal';
  if jwt_aal not in('aal1','aal2') then return; end if;
  select auth_link.id,auth_link.internal_identity_id into auth_link_id,identity_id
  from app_private.superadmin_internal_auth_links auth_link
  where auth_link.auth_user_id=current_auth_user_id
  order by auth_link.created_at desc limit 1;
  if auth_link_id is null then
    perform app_private.audit_append_auth_session_denial(current_session_id,
      p_permission_code,jwt_aal,p_action_code,p_reason_code,p_correlation_id);
    return;
  end if;
  select membership.id into membership_id
  from app_private.superadmin_internal_memberships membership
  where membership.internal_identity_id=identity_id
  order by (membership.status='active') desc,membership.created_at desc limit 1;
  if membership_id is null then
    perform app_private.audit_append_auth_session_denial(current_session_id,
      p_permission_code,jwt_aal,p_action_code,p_reason_code,p_correlation_id);
    return;
  end if;
  select institution.id into audit_institution_id
  from public.institutions institution
  where institution.id=p_institution_id;
  perform app_private.audit_append_superadmin_internal(identity_id,auth_link_id,
    membership_id,current_session_id,p_permission_code,jwt_aal,p_action_code,
    'denied',p_reason_code,p_correlation_id,audit_institution_id,
    case when audit_institution_id is null then null else 'institution' end,
    audit_institution_id);
end
$$;

alter function app_private.audit_superadmin_internal_denial_if_identified(
  text,text,text,uuid,uuid
) owner to postgres;
revoke all on function app_private.audit_superadmin_internal_denial_if_identified(
  text,text,text,uuid,uuid
) from public,anon,authenticated,service_role;

commit;
