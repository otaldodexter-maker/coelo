begin;
select plan(13);

select enum_has_labels(
  'public',
  'notice_type',
  array['notice','critical_notice','popup','content_card','highlight','for_you'],
  'notice_type preserves legacy labels and adds the communication types'
);
select has_function(
  'public',
  'list_notices_for_superadmin',
  array['text[]','text','text[]','text[]','timestamp with time zone','uuid','integer'],
  'typed directory overload exists without removing the legacy RPC'
);
select has_function(
  'public',
  'list_notices_for_superadmin',
  array['text','text[]','text[]','timestamp with time zone','uuid','integer'],
  'legacy directory RPC remains available'
);
select ok(
  position('notice_type' in pg_get_functiondef('app_private.notice_json(public.platform_notices)'::regprocedure)) > 0,
  'serialized payload includes communication type'
);
select ok(
  position('p_types' in pg_get_functiondef('public.list_notices_for_superadmin(text[],text,text[],text[],timestamptz,uuid,int)'::regprocedure)) > 0,
  'typed directory filters on the server'
);
select ok(
  position("p_payload->>'type'" in pg_get_functiondef('public.save_notice_draft_for_superadmin(uuid,jsonb,uuid,bigint)'::regprocedure)) > 0,
  'save validates the requested type'
);
select ok(
  position("notice_type=v_type::public.notice_type" in replace(pg_get_functiondef('public.save_notice_draft_for_superadmin(uuid,jsonb,uuid,bigint)'::regprocedure),' ','')) > 0,
  'save persists the normalized type on updates'
);
select ok(
  position("v_type='popup'" in pg_get_functiondef('public.save_notice_draft_for_superadmin(uuid,jsonb,uuid,bigint)'::regprocedure)) > 0,
  'popup-only fields are gated by type'
);
select ok(
  has_function_privilege('authenticated','public.list_notices_for_superadmin(text[],text,text[],text[],timestamptz,uuid,int)','execute'),
  'authenticated users can call the authorized typed RPC'
);
select ok(
  not has_function_privilege('anon','public.list_notices_for_superadmin(text[],text,text[],text[],timestamptz,uuid,int)','execute'),
  'anonymous callers cannot use the typed RPC'
);
select ok(
  not has_table_privilege('authenticated','public.platform_notices','select,insert,update,delete'),
  'direct table access remains revoked'
);
select ok(
  (select relrowsecurity and relforcerowsecurity from pg_class where oid='public.platform_notices'::regclass),
  'RLS remains enabled and forced'
);
select ok(
  position('assert_notice_permission' in pg_get_functiondef('public.list_notices_for_superadmin(text[],text,text[],text[],timestamptz,uuid,int)'::regprocedure)) > 0,
  'typed RPC preserves server-side authorization'
);

select * from finish();
rollback;
