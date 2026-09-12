begin;

create extension if not exists pgtap with schema extensions;

select plan(4);

select is(
  (
    select count(*)::bigint
    from public.institution_role_permissions role_permission
    join public.institution_roles role_record on role_record.id = role_permission.role_id
    join public.institution_permissions permission_record on permission_record.id = role_permission.permission_id
    where role_record.institution_id is null
      and role_record.code = 'institution_admin'
      and role_record.is_system
      and role_record.status = 'active'
      and permission_record.code = 'moments.publications.remove'
      and permission_record.status = 'active'
      and role_permission.effect = 'allow'
      and role_permission.status = 'active'
      and role_permission.revoked_at is null
  ),
  1::bigint,
  'institution_admin receives the active Momentos withdrawal capability'
);

select ok(
  not exists (
    select 1
    from public.institution_role_permissions role_permission
    join public.institution_roles role_record on role_record.id = role_permission.role_id
    join public.institution_permissions permission_record on permission_record.id = role_permission.permission_id
    where role_record.institution_id is null
      and role_record.code = 'institution_reader'
      and role_record.is_system
      and permission_record.code = 'moments.publications.remove'
      and role_permission.effect = 'allow'
      and role_permission.status = 'active'
      and role_permission.revoked_at is null
  ),
  'read-only internal operators do not receive withdrawal capability'
);

select ok(
  position('publication.author_person_id = actor.person_id' in pg_get_functiondef(
    'public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)'::regprocedure
  )) > 0
  and position('moments.publications.remove' in pg_get_functiondef(
    'public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)'::regprocedure
  )) > 0
  and position('app_private.has_institution_permission' in pg_get_functiondef(
    'public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)'::regprocedure
  )) > 0,
  'can_withdraw requires both authorship and the same capability enforced by the command'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)',
    'EXECUTE'
  ),
  'feed execute ACL remains authenticated-only'
);

select * from finish();
rollback;
