-- CHILD-SQLVECTOR01: candidate catalog fixture, NOT EXECUTED.
-- Eng1-only isolated Auth + nominal envelope profile; pgTAP in extensions.
-- No application rows, gateway calls, audit calls, grants or repairs.
begin;
set local search_path = extensions, pg_catalog;
select extensions.plan(14);

select extensions.ok(current_user = 'postgres', 'catalog actor is postgres');

select extensions.ok((select count(*) = 3 from pg_catalog.pg_namespace
  where nspname in ('public', 'app_private', 'audit')), 'required schemas');

select extensions.ok(not exists (
  select 1 from (values
    ('people','id','uuid'), ('people','person_type','public.person_type'),
    ('people','display_name','text'), ('people','deleted_at','timestamptz'),
    ('institutions','id','uuid'), ('institutions','public_name','text'),
    ('institutions','deleted_at','timestamptz'),
    ('child_contexts','id','uuid'), ('child_contexts','child_person_id','uuid'),
    ('child_contexts','institution_id','uuid'),
    ('child_contexts','status','public.record_status')
  ) expected(relation_name,column_name,type_name)
  where not exists (select 1 from pg_catalog.pg_attribute a
    where a.attrelid = pg_catalog.to_regclass('public.' || expected.relation_name)
      and a.attname = expected.column_name and a.attnum > 0 and not a.attisdropped
      and a.atttypid = pg_catalog.to_regtype(expected.type_name))
), 'physical projection columns and types');

select extensions.ok(coalesce((select p.prosecdef and p.provolatile = 's'
  and pg_catalog.pg_get_userbyid(p.proowner) = 'postgres'
  and p.proconfig @> array['search_path=""']::text[]
  from pg_catalog.pg_proc p where p.oid = pg_catalog.to_regprocedure(
    'app_private.require_superadmin_internal_context(text)')), false),
  'Auth039 helper security metadata');

select extensions.ok(pg_catalog.to_regprocedure(
  'app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)'
) is not null, 'safe denial helper exists');

select extensions.ok(coalesce((select pg_catalog.strpos(
  pg_catalog.pg_get_functiondef(p.oid), 'SAI_INVALID_ARGUMENT') > 0
  from pg_catalog.pg_proc p where p.oid = pg_catalog.to_regprocedure(
    'app_private.superadmin_internal_error_envelope(text,uuid)')), false),
  'envelope includes invalid-argument contract');

select extensions.ok(pg_catalog.to_regprocedure(
  'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)'
) is not null, 'existing audit13 satisfies payload-free child read');

select extensions.ok(coalesce((select p.prosecdef and p.provolatile = 'v'
  and p.prorettype = pg_catalog.to_regtype('uuid')
  and pg_catalog.pg_get_userbyid(p.proowner) = 'postgres'
  and p.proconfig @> array['search_path=""']::text[]
  and not exists (select 1 from pg_catalog.aclexplode(coalesce(
    p.proacl, pg_catalog.acldefault('f',p.proowner))) a where a.grantee <> p.proowner)
  from pg_catalog.pg_proc p where p.oid = pg_catalog.to_regprocedure(
    'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)'
  )), false), 'audit13 private security metadata');

select extensions.ok((select count(*) = 1 from public.platform_permissions
  where code = 'people.read' and status = 'active' and module_code = 'people'
    and screen_code = 'directory' and action_code = 'read' and risk_level = 'high'),
  'existing people.read catalog, without provisioning');

select extensions.ok(coalesce((select array_agg(r.code::text order by r.code)
    = array['owner']::text[]
  from public.platform_permissions p
  join public.platform_role_permissions g on g.permission_id = p.id
  join public.platform_roles r on r.id = g.role_id
  where p.code = 'people.read' and p.status = 'active' and r.status = 'active'
    and g.effect = 'allow' and g.status = 'active' and g.revoked_at is null),false),
  'effective allow roles exactly Owner');

select extensions.ok(pg_catalog.to_regprocedure(
  'public.superadmin_child_context_directory_v2(uuid,text,uuid,integer)'
) is not null, 'child gateway exists (expected RED before implementation)');

select extensions.ok(coalesce((select p.prokind = 'f' and p.prosecdef
  and p.provolatile = 'v' and p.prorettype = pg_catalog.to_regtype('jsonb')
  and not p.proretset and pg_catalog.pg_get_userbyid(p.proowner) = 'postgres'
  and p.proconfig @> array['search_path=""']::text[] and p.pronargdefaults = 4
  and p.proargnames = array['p_institution_id','p_after_name','p_after_context_id','p_limit']::text[]
  from pg_catalog.pg_proc p where p.oid = pg_catalog.to_regprocedure(
    'public.superadmin_child_context_directory_v2(uuid,text,uuid,integer)')), false),
  'child gateway return, arguments and security metadata');

select extensions.ok((select count(*) = 1 from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public','app_private')
    and p.proname = 'superadmin_child_context_directory_v2'),
  'no competing gateway overloads');

select extensions.ok(coalesce((select
  (select array_agg(r.rolname::text || ':' || a.privilege_type || ':' || a.is_grantable::text
    order by r.rolname, a.privilege_type, a.is_grantable)
   from pg_catalog.aclexplode(coalesce(p.proacl,pg_catalog.acldefault('f',p.proowner))) a
   left join pg_catalog.pg_roles r on r.oid = a.grantee
   where a.grantee <> p.proowner) = array['authenticated:EXECUTE:false']::text[]
  and not exists (select 1 from pg_catalog.aclexplode(coalesce(
    p.proacl,pg_catalog.acldefault('f',p.proowner))) a where a.grantee = 0)
  and pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE')
  and not pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE')
  and not pg_catalog.has_function_privilege('service_role',p.oid,'EXECUTE')
  from pg_catalog.pg_proc p where p.oid = pg_catalog.to_regprocedure(
    'public.superadmin_child_context_directory_v2(uuid,text,uuid,integer)')), false),
  'gateway EXECUTE only authenticated, no grant option');

select * from extensions.finish();
rollback;
