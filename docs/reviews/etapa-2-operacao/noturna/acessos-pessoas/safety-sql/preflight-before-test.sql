-- LOCAL ONLY. Generated from actual Safety candidate preflight; rollback restores envelope.
begin;
create extension if not exists pgtap with schema extensions;
select plan(2);
select lives_ok($d04$do $preflight$
declare dependency text; target text;
begin
  if to_regtype('app_private.superadmin_internal_context') is null then
    raise exception 'D04 dependency missing: internal context type';
  end if;
  foreach dependency in array array[
    'app_private.require_superadmin_internal_context(text)',
    'app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)',
    'app_private.superadmin_internal_error_envelope(text,uuid)',
    'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)',
    'app_private.validate_child_safety_context()'] loop
    if to_regprocedure(dependency) is null then
      raise exception 'D04 dependency missing: %',dependency;
    end if;
  end loop;
  foreach target in array array['authorized_people','authorized_person_authorizations',
    'authorized_person_authorization_capabilities','child_safety_restrictions','child_safety_alerts','child_safety_evidence'] loop
    if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname=target and c.relrowsecurity and c.relforcerowsecurity)
      or has_table_privilege('authenticated','public.'||target,'SELECT,INSERT,UPDATE,DELETE') then
      raise exception 'D04 dependency requires forced RLS and no direct client grant: %',target;
    end if;
  end loop;
  foreach target in array array['authorized_person_authorizations','child_safety_restrictions','child_safety_alerts','child_safety_evidence'] loop
    if not exists(select 1 from pg_trigger t
      where t.tgrelid=to_regclass('public.'||target) and not t.tgisinternal
        and t.tgname=target||'_validate' and t.tgenabled in ('O','A')
        and t.tgfoid='app_private.validate_child_safety_context()'::regprocedure) then
      raise exception 'D04 context integrity trigger missing: %',target;
    end if;
  end loop;
  if exists(select 1 from pg_proc p, lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
    where p.oid='app_private.require_superadmin_internal_context(text)'::regprocedure
      and a.privilege_type='EXECUTE' and (a.grantee=0 or a.grantee in
        (select oid from pg_roles where rolname in ('anon','authenticated','service_role')))) then
    raise exception 'D04 internal context helper ACL is not private';
  end if;
end;
$preflight$;$d04$, 'reviewed envelope satisfies candidate preflight');
create or replace function app_private.superadmin_internal_error_envelope(
  p_code text,p_correlation_id uuid
) returns jsonb language sql immutable security invoker set search_path='' as $$
  select pg_catalog.jsonb_build_object('ok',false,'data',null,'error',
    pg_catalog.jsonb_build_object('code',case when p_code in(
      'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED','SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE')
      then p_code else 'SAI_INTERNAL_ERROR' end,
      'message',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 'Autenticação necessária.'
        when p_code='SAI_MFA_REQUIRED' then 'Confirme o segundo fator.'
        when p_code in('SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE') then 'O estado mudou. Recarregue e tente novamente.'
        when p_code like 'SAI_%DENIED' or p_code like 'SAI_MEMBERSHIP_%' then 'Acesso não autorizado.'
        else 'Não foi possível concluir a operação.' end,
      'correlation_id',p_correlation_id,
      'http_status',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when p_code in('SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE') then 409
        when p_code in('SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then 403
        else 500 end))
$$;
select throws_ok($d04$do $preflight$
declare dependency text; target text;
begin
  if to_regtype('app_private.superadmin_internal_context') is null then
    raise exception 'D04 dependency missing: internal context type';
  end if;
  foreach dependency in array array[
    'app_private.require_superadmin_internal_context(text)',
    'app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)',
    'app_private.superadmin_internal_error_envelope(text,uuid)',
    'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)',
    'app_private.validate_child_safety_context()'] loop
    if to_regprocedure(dependency) is null then
      raise exception 'D04 dependency missing: %',dependency;
    end if;
  end loop;
  foreach target in array array['authorized_people','authorized_person_authorizations',
    'authorized_person_authorization_capabilities','child_safety_restrictions','child_safety_alerts','child_safety_evidence'] loop
    if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname=target and c.relrowsecurity and c.relforcerowsecurity)
      or has_table_privilege('authenticated','public.'||target,'SELECT,INSERT,UPDATE,DELETE') then
      raise exception 'D04 dependency requires forced RLS and no direct client grant: %',target;
    end if;
  end loop;
  foreach target in array array['authorized_person_authorizations','child_safety_restrictions','child_safety_alerts','child_safety_evidence'] loop
    if not exists(select 1 from pg_trigger t
      where t.tgrelid=to_regclass('public.'||target) and not t.tgisinternal
        and t.tgname=target||'_validate' and t.tgenabled in ('O','A')
        and t.tgfoid='app_private.validate_child_safety_context()'::regprocedure) then
      raise exception 'D04 context integrity trigger missing: %',target;
    end if;
  end loop;
  if exists(select 1 from pg_proc p, lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
    where p.oid='app_private.require_superadmin_internal_context(text)'::regprocedure
      and a.privilege_type='EXECUTE' and (a.grantee=0 or a.grantee in
        (select oid from pg_roles where rolname in ('anon','authenticated','service_role')))) then
    raise exception 'D04 internal context helper ACL is not private';
  end if;
end;
$preflight$;$d04$, 'P0001',
  'D04 dependency requires SAI_INVALID_ARGUMENT envelope',
  'Auth45 envelope is rejected before installing Safety wrappers');
select * from finish();
rollback;
