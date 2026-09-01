begin;

create extension if not exists pgtap with schema extensions;

select plan(10);

select is(
  (select proargnames from pg_catalog.pg_proc
    where oid='public.superadmin_access_profile_model_detail(uuid)'::regprocedure),
  array['p_model_id']::text[],
  'model detail exposes the PostgREST parameter name'
);
select is(
  (select proargnames from pg_catalog.pg_proc
    where oid='public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)'::regprocedure),
  array['p_query','p_domain','p_status','p_scope','p_limit','p_after_name','p_after_id']::text[],
  'model cursor exposes all PostgREST parameter names'
);
select is(
  (select proargnames from pg_catalog.pg_proc
    where oid='public.superadmin_access_profile_model_create(uuid,jsonb)'::regprocedure),
  array['p_request_id','p_draft']::text[],
  'model create exposes its PostgREST parameter names'
);
select is(
  (select proargnames from pg_catalog.pg_proc
    where oid='public.superadmin_access_profile_model_update(uuid,jsonb)'::regprocedure),
  array['p_request_id','p_draft']::text[],
  'model update exposes its PostgREST parameter names'
);
select is(
  (select proargnames from pg_catalog.pg_proc
    where oid='public.superadmin_access_profile_model_delete(uuid,uuid,bigint,text)'::regprocedure),
  array['p_request_id','p_model_id','p_expected_version','p_reason']::text[],
  'model delete exposes its PostgREST parameter names'
);
select is(
  (select proargnames from pg_catalog.pg_proc
    where oid='public.superadmin_access_profile_model_duplicate(uuid,jsonb)'::regprocedure),
  array['p_request_id','p_draft']::text[],
  'model duplicate exposes its PostgREST parameter names'
);
select is(
  (select proargnames from pg_catalog.pg_proc
    where oid='public.superadmin_access_profile_models_export(text)'::regprocedure),
  array['p_domain']::text[],
  'model export exposes its PostgREST parameter name'
);
select is(
  (select proargnames from pg_catalog.pg_proc
    where oid='public.superadmin_access_profile_models_import_preview(text,jsonb)'::regprocedure),
  array['p_domain','p_rows']::text[],
  'model import preview exposes its PostgREST parameter names'
);
select is(
  (select proargnames from pg_catalog.pg_proc
    where oid='public.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text)'::regprocedure),
  array['p_request_id','p_domain','p_rows','p_reason']::text[],
  'model import confirmation exposes its PostgREST parameter names'
);
select is(
  (select count(*)::bigint
    from (values
      ('public.superadmin_access_profile_model_detail(uuid)'::regprocedure),
      ('public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)'::regprocedure),
      ('public.superadmin_access_profile_model_create(uuid,jsonb)'::regprocedure),
      ('public.superadmin_access_profile_model_update(uuid,jsonb)'::regprocedure),
      ('public.superadmin_access_profile_model_delete(uuid,uuid,bigint,text)'::regprocedure),
      ('public.superadmin_access_profile_model_duplicate(uuid,jsonb)'::regprocedure),
      ('public.superadmin_access_profile_models_export(text)'::regprocedure),
      ('public.superadmin_access_profile_models_import_preview(text,jsonb)'::regprocedure),
      ('public.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text)'::regprocedure)
    ) rpc(function_oid)
    where has_function_privilege('authenticated',rpc.function_oid,'EXECUTE')
      and not has_function_privilege('anon',rpc.function_oid,'EXECUTE')),
  9::bigint,
  'all named gateways remain authenticated-only'
);

select * from finish();

rollback;
