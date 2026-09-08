-- Auth47 catalog probe only. No application calls, grants, DDL repair or function bodies emitted.
begin;
reset role;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions,pg_catalog;
select extensions.plan(7);
with expected(position, signature, expected_md5) as (values
  (1, 'app_private.activity_management_payload(uuid)', 'dbfb21e52b0773a41815a0986be0d64f'),
  (2, 'app_private.superadmin_activity_directory(text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean)', 'f1809b1c0b268ed571eaaa958a061015'),
  (3, 'public.superadmin_activity_directory(text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean)', 'e1e94802dd59857459e6816c8b6a4069'),
  (4, 'app_private.superadmin_get_activity_form_options(uuid)', '65fe6408f0f2c6b0c1c9d71a809f2d80'),
  (5, 'public.superadmin_get_activity_form_options(uuid)', '4600bdfb92b0ea38f597947365750052'),
  (6, 'app_private.superadmin_create_activity_locations(uuid,uuid[],text,uuid)', '886752274164d0d435c9df8ced18d896'),
  (7, 'public.superadmin_create_activity_locations(uuid,uuid[],text,uuid)', '1898ddd4ec4ea12373e1c13c55336774')
)
select extensions.ok(to_regprocedure(signature) is not null, 'LOC fingerprint catalog function exists: ' || signature)
from expected order by position;

-- Match the candidate's exact formatting context when computing pg_get_functiondef.
set local search_path=public,pg_catalog;
with expected(position, signature, expected_md5) as (values
  (1, 'app_private.activity_management_payload(uuid)', 'dbfb21e52b0773a41815a0986be0d64f'),
  (2, 'app_private.superadmin_activity_directory(text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean)', 'f1809b1c0b268ed571eaaa958a061015'),
  (3, 'public.superadmin_activity_directory(text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean)', 'e1e94802dd59857459e6816c8b6a4069'),
  (4, 'app_private.superadmin_get_activity_form_options(uuid)', '65fe6408f0f2c6b0c1c9d71a809f2d80'),
  (5, 'public.superadmin_get_activity_form_options(uuid)', '4600bdfb92b0ea38f597947365750052'),
  (6, 'app_private.superadmin_create_activity_locations(uuid,uuid[],text,uuid)', '886752274164d0d435c9df8ced18d896'),
  (7, 'public.superadmin_create_activity_locations(uuid,uuid[],text,uuid)', '1898ddd4ec4ea12373e1c13c55336774')
), catalog as (
  select e.*, p.oid, r.rolname as owner, p.prosecdef, p.provolatile, p.proconfig,
    pg_get_functiondef(p.oid) as definition, p.proacl, p.proowner
  from expected e left join pg_proc p on p.oid=to_regprocedure(e.signature)
  left join pg_roles r on r.oid=p.proowner
), fingerprints as (
  select c.*, md5(definition) as actual_raw,
    md5(replace(definition, E'\r\n', E'\n')) as actual_lf
  from catalog c
)
select '# ' || jsonb_build_object(
  'probe', 'loc_legacy_helper_fingerprints_auth47',
  'actor', current_user, 'search_path', current_setting('search_path'),
  'server_version_num', current_setting('server_version_num')::integer,
  'functions', jsonb_agg(jsonb_build_object(
    'position', position, 'signature', signature, 'oid', oid, 'owner', owner,
    'security_definer', prosecdef, 'volatility', provolatile, 'config', proconfig,
    'expected_md5', expected_md5, 'actual_md5_raw', actual_raw,
    'actual_md5_lf', actual_lf, 'matches_raw', actual_raw=expected_md5,
    'matches_lf', actual_lf=expected_md5,
    'raw_bytes', octet_length(definition),
    'lf_bytes', octet_length(replace(definition,E'\r\n',E'\n')),
    'cr_count', length(definition)-length(replace(definition,E'\r','')),
    'lf_count', length(definition)-length(replace(definition,E'\n','')),
    'crlf_count', (length(definition)-length(replace(definition,E'\r\n','')))/2,
    'acl', (select coalesce(jsonb_agg(jsonb_build_object(
      'grantor', pg_get_userbyid(a.grantor),
      'grantee', case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
      'privilege', a.privilege_type, 'grantable', a.is_grantable)
      order by a.grantee,a.privilege_type),'[]'::jsonb)
      from aclexplode(coalesce(proacl,acldefault('f',proowner))) a)
  ) order by position)
)::text
from fingerprints;
set local search_path=public,extensions,pg_catalog;
select * from extensions.finish();
rollback;
