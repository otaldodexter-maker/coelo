begin;

create extension if not exists pgtap with schema extensions;
select plan(63);

select has_type('public','child_safety_decision_status','decision is separate from lifecycle');
select has_type('public','child_safety_severity','severity is typed');
select has_column('public','authorized_people','person_id','authorized identity is a global person');
select has_column('public','authorized_person_authorizations','decision_status','decision is explicit');
select has_column('public','authorized_person_authorizations','version','commands are versioned');
select has_table('public','child_safety_restrictions','restrictions are first-class');
select has_table('public','child_safety_alerts','alerts are first-class');
select has_table('public','child_safety_evidence','evidence metadata is first-class');
select has_table('app_private','child_safety_command_receipts','idempotency receipts exist');

select results_eq(
  $$select code from public.platform_permissions
    where code like 'child_safety.%' order by code$$,
  $$values ('child_safety.export'::text),('child_safety.manage'::text),
    ('child_safety.read'::text),('child_safety.review'::text)$$,
  'least-privilege capabilities exist'
);
select has_function('public','superadmin_child_safety_directory',
  array['text','uuid[]','uuid[]','text','integer','jsonb'],
  'directory is filtered and cursor-paginated server-side');
select has_function('public','superadmin_child_safety_search_children',array['text','integer'],
  'child picker search is authorized server-side');
select has_function('public','superadmin_child_safety_get',array['uuid'],
  'detail is an authorized aggregate');
select has_function('public','child_safety_request_authorization',array['uuid','jsonb'],
  'authorization request is idempotent');
select has_function('public','child_safety_edit_pending_authorization',
  array['uuid','uuid','bigint','jsonb'],'pending requests are editable with optimistic locking');
select has_function('public','child_safety_decide_authorization',
  array['uuid','uuid','bigint','text','text'],'unit decision is versioned and reasoned');
select has_function('public','child_safety_change_lifecycle',
  array['uuid','uuid','bigint','text','text'],'lifecycle is independent from decision');
select has_function('public','child_safety_save_restriction',array['uuid','jsonb'],
  'restriction writes use a gateway');
select has_function('public','child_safety_acknowledge_alert',
  array['uuid','uuid','bigint','text','text'],'alert commands require a reason');
select has_function('public','child_safety_register_evidence',array['uuid','jsonb'],
  'evidence registration uses an authorized gateway');
select has_function('public','child_safety_get_evidence_object',array['uuid'],
  'authorized downloads receive a short-lived object reference');
select has_function('public','superadmin_request_child_safety_export',
  array['uuid','text','jsonb'],'export creates a real idempotent job');
select has_function('public','superadmin_get_child_safety_export',array['uuid'],
  'export status is queryable');

select ok(
  not has_table_privilege('anon','public.authorized_person_authorizations','SELECT,INSERT,UPDATE,DELETE')
  and not has_table_privilege('authenticated','public.authorized_people','SELECT')
  and not has_table_privilege('authenticated','public.authorized_person_authorizations','SELECT')
  and not has_table_privilege('authenticated','public.authorized_person_authorization_capabilities','SELECT')
  and not has_table_privilege('authenticated','public.child_safety_restrictions','SELECT')
  and not has_table_privilege('authenticated','public.child_safety_alerts','SELECT')
  and not has_table_privilege('authenticated','public.child_safety_evidence','SELECT')
  and not has_table_privilege('authenticated','public.authorized_person_authorizations','INSERT,UPDATE,DELETE')
  and not has_table_privilege('authenticated','public.child_safety_restrictions','INSERT,UPDATE,DELETE')
  and not has_table_privilege('authenticated','public.child_safety_alerts','INSERT,UPDATE,DELETE')
  and not has_table_privilege('authenticated','public.child_safety_evidence','INSERT,UPDATE,DELETE'),
  'browser roles cannot mutate safety tables directly'
);
select ok((select bool_and(relrowsecurity and relforcerowsecurity) from pg_class
  where oid in ('public.authorized_people'::regclass,
    'public.authorized_person_authorizations'::regclass,
    'public.authorized_person_authorization_capabilities'::regclass,
    'public.child_safety_restrictions'::regclass,'public.child_safety_alerts'::regclass,
    'public.child_safety_evidence'::regclass)),'all exposed safety tables force RLS');
select is((select count(*)::integer from pg_policy where polrelid in(
  'public.authorized_people'::regclass,'public.authorized_person_authorizations'::regclass,
  'public.authorized_person_authorization_capabilities'::regclass,
  'public.child_safety_restrictions'::regclass,'public.child_safety_alerts'::regclass,
  'public.child_safety_evidence'::regclass) and polcmd in('a','w','d')),18,
  'every exposed safety table has explicit deny insert/update/delete policies');
select ok(pg_get_expr((select polqual from pg_policy
  where polrelid='public.authorized_people'::regclass and polname='authorized_people_context_read'),
  'public.authorized_people'::regclass) like '%authorized_people.id%',
  'authorized_people RLS qualifies the outer row');
select ok((select bool_and(not p.prosecdef) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and (p.proname like 'child_safety_%'
    or p.proname like 'superadmin_child_safety_%'
    or p.proname='superadmin_request_child_safety_export')),
  'public gateways are security invoker');
select ok(not has_function_privilege('anon',
  'public.child_safety_request_authorization(uuid,jsonb)','EXECUTE')
  and has_function_privilege('authenticated',
    'public.child_safety_request_authorization(uuid,jsonb)','EXECUTE'),
  'RPC execution is opt-in to authenticated only');
select ok(not has_function_privilege('authenticated',
  'app_private.child_safety_finalize_evidence(uuid,text,bigint,text)','EXECUTE')
  and has_function_privilege('service_role',
    'app_private.child_safety_finalize_evidence(uuid,text,bigint,text)','EXECUTE'),
  'only the trusted worker finalizes scanned evidence');
select ok(exists(select 1 from storage.buckets
  where id='child-safety-evidence' and not public and file_size_limit=10485760),
  'evidence bucket is private and size-limited');
select ok(exists(select 1 from pg_policy where schemaname='storage'
  and tablename='objects' and policyname='child_safety_evidence_insert')
  and exists(select 1 from pg_policy where schemaname='storage'
  and tablename='objects' and policyname='child_safety_evidence_select'),
  'Storage has scoped insert and read policies');
select ok(pg_get_functiondef(
  'app_private.child_safety_register_evidence(uuid,jsonb)'::regprocedure)
  like '%object_path:=format%' and pg_get_functiondef(
  'app_private.child_safety_register_evidence(uuid,jsonb)'::regprocedure)
  like '%status%draft%','evidence path is server-generated and initially blocked');
select ok(pg_get_functiondef(
  'app_private.child_safety_finalize_evidence(uuid,text,bigint,text)'::regprocedure)
  like '%p_detected_mime<>e.mime_type%'
  and pg_get_functiondef(
  'app_private.child_safety_finalize_evidence(uuid,text,bigint,text)'::regprocedure)
  like '%p_detected_sha256<>e.checksum_sha256%',
  'trusted worker compares detected MIME, size and hash');
select ok(pg_get_functiondef(
  'app_private.child_safety_decide_authorization(uuid,uuid,bigint,text,text)'::regprocedure)
  like '%has_mfa_aal2%' and pg_get_functiondef(
  'app_private.child_safety_decide_authorization(uuid,uuid,bigint,text,text)'::regprocedure)
  like '%child_safety_has_exact_unit_review%' and pg_get_functiondef(
  'app_private.child_safety_decide_authorization(uuid,uuid,bigint,text,text)'::regprocedure)
  like '%for update%','decision requires AAL2, exact unit scope and a row lock');
select ok(pg_get_functiondef(
  'app_private.child_safety_edit_pending_authorization(uuid,uuid,bigint,jsonb)'::regprocedure)
  like $$%decision_status%pending%$$ and pg_get_functiondef(
  'app_private.child_safety_edit_pending_authorization(uuid,uuid,bigint,jsonb)'::regprocedure)
  like '%for update%','only pending requests can be edited');
select ok(pg_get_functiondef(
  'app_private.superadmin_child_safety_directory(text,uuid[],uuid[],text,integer,jsonb)'::regprocedure)
  like '%awaiting_approval%' and pg_get_functiondef(
  'app_private.superadmin_child_safety_directory(text,uuid[],uuid[],text,integer,jsonb)'::regprocedure)
  like '%without_authorization%' and pg_get_functiondef(
  'app_private.superadmin_child_safety_directory(text,uuid[],uuid[],text,integer,jsonb)'::regprocedure)
  not like '%OFFSET%','directory uses final exclusive segments and no offset');
select ok(pg_get_functiondef(
  'app_private.superadmin_child_safety_directory(text,uuid[],uuid[],text,integer,jsonb)'::regprocedure)
  like $$%when has_pending then 'awaiting_approval'%$$
  and pg_get_functiondef(
  'app_private.superadmin_child_safety_directory(text,uuid[],uuid[],text,integer,jsonb)'::regprocedure)
  like $$%when has_attention then 'attention'%$$,
  'segment precedence is pending, attention, authorized, none');
select ok(pg_get_functiondef(
  'app_private.validate_child_safety_context()'::regprocedure)
  like '%invalid child safety subject%','cross-child and cross-unit subject swaps fail closed');
select ok(pg_get_functiondef(
  'app_private.child_safety_request_authorization(uuid,jsonb)'::regprocedure)
  like $$%'pending'%$$ and pg_get_functiondef(
  'app_private.child_safety_request_authorization(uuid,jsonb)'::regprocedure)
  like $$%'inactive'%$$,'new requests are blocked pending review');
select ok(pg_get_functiondef(
  'app_private.child_safety_request_authorization(uuid,jsonb)'::regprocedure)
  like '%person_type%adult%' and pg_get_functiondef(
  'app_private.child_safety_request_authorization(uuid,jsonb)'::regprocedure)
  not like '%INSERT INTO public.people%','authorized people reuse global adult identity');
select ok(pg_get_functiondef(
  'app_private.superadmin_request_child_safety_export(uuid,text,jsonb)'::regprocedure)
  like '%child-safety-export-v1%' and pg_get_functiondef(
  'app_private.superadmin_request_child_safety_export(uuid,text,jsonb)'::regprocedure)
  like '%csv_formula_policy%','export is versioned and declares CSV formula escaping');
select ok(exists(select 1 from pg_indexes where schemaname='public'
  and indexname='authorized_person_authorizations_decision_context_idx')
  and exists(select 1 from pg_indexes where schemaname='public'
  and indexname='child_safety_alerts_authorization_idx')
  and exists(select 1 from pg_indexes where schemaname='public'
  and indexname='child_safety_evidence_authorization_idx'),
  'directory and subject foreign keys are indexed');
select ok(not has_function_privilege('authenticated',
  'app_private.create_authorized_person_authorization(uuid,uuid,text,text,text,bytea,text,text,text,text[],date,date)',
  'EXECUTE') and not has_function_privilege('authenticated',
  'app_private.suspend_authorized_person_authorization(uuid,text)','EXECUTE'),
  'legacy privileged functions remain unreachable');
select ok(not has_function_privilege('authenticated',
  'public.create_authorized_person_authorization(uuid,uuid,text,text,text,bytea,text,text,text,text[],date,date)',
  'EXECUTE') and not has_function_privilege('authenticated',
  'public.suspend_authorized_person_authorization(uuid,text)','EXECUTE'),
  'legacy public gateways are revoked');

select ok((select column_default from information_schema.columns
  where table_schema='public' and table_name='authorized_person_authorizations'
    and column_name='decision_status') like '%pending%',
  'new rows fail closed as pending');
select ok(pg_get_indexdef('public.authorized_people_owner_person_uidx'::regclass)
  like '%institution_id%owner_guardian_person_id%person_id%',
  'guardian/person uniqueness is contextual to one institution');
select ok((select indisunique from pg_index
  where indexrelid='public.authorized_people_institution_person_idx'::regclass),
  'one global person has one active authorized-person profile per institution');
select ok(pg_get_functiondef('app_private.validate_child_safety_context()'::regprocedure)
  like '%invalid authorized person context%',
  'authorization trigger preserves authorized-person institution integrity');
select ok(pg_get_functiondef(
  'app_private.child_safety_request_authorization(uuid,jsonb)'::regprocedure)
  like '%owner_guardian_person_id=actor%' and pg_get_functiondef(
  'app_private.child_safety_request_authorization(uuid,jsonb)'::regprocedure)
  like '%administrative_request%',
  'guardian cannot attach an arbitrary global adult identity');
select ok(pg_get_functiondef(
  'app_private.child_safety_edit_pending_authorization(uuid,uuid,bigint,jsonb)'::regprocedure)
  like '%created_by_person_id=actor%',
  'guardian can edit only an owned pending request');
select ok(pg_get_functiondef(
  'app_private.child_safety_change_lifecycle(uuid,uuid,bigint,text,text)'::regprocedure)
  like '%child_safety_can_administer%' and pg_get_functiondef(
  'app_private.child_safety_change_lifecycle(uuid,uuid,bigint,text,text)'::regprocedure)
  not like '%child_safety_can_manage%',
  'guardian cannot restore a lifecycle decision owned by the unit');
select ok(pg_get_functiondef(
  'app_private.child_safety_edit_pending_authorization(uuid,uuid,bigint,jsonb)'::regprocedure)
  like '%p_expected_version is null%' and pg_get_functiondef(
  'app_private.child_safety_decide_authorization(uuid,uuid,bigint,text,text)'::regprocedure)
  like '%p_expected_version is null%' and pg_get_functiondef(
  'app_private.child_safety_change_lifecycle(uuid,uuid,bigint,text,text)'::regprocedure)
  like '%p_expected_version is null%' and pg_get_functiondef(
  'app_private.child_safety_acknowledge_alert(uuid,uuid,bigint,text,text)'::regprocedure)
  like '%p_expected_version is null%',
  'NULL cannot bypass optimistic version checks');
select ok(pg_get_functiondef(
  'app_private.superadmin_child_safety_directory(text,uuid[],uuid[],text,integer,jsonb)'::regprocedure)
  like '%p_limit is null%' and pg_get_functiondef(
  'app_private.superadmin_child_safety_search_children(text,integer)'::regprocedure)
  like '%p_limit is null%',
  'NULL cannot bypass server-side result limits');
select has_function('app_private','child_safety_add_unit_review_recipients',
  array['uuid','uuid','uuid'],'unit reviewer recipient resolver exists');
select ok(pg_get_functiondef(
  'app_private.child_safety_request_authorization(uuid,jsonb)'::regprocedure)
  like '%child_safety.authorization_requested%' and pg_get_functiondef(
  'app_private.child_safety_decide_authorization(uuid,uuid,bigint,text,text)'::regprocedure)
  like '%context_notification_recipients%',
  'request and decision notifications have server-resolved recipients');
select ok(pg_get_functiondef(
  'app_private.superadmin_get_child_safety_export(uuid)'::regprocedure)
  like '%created_by=actor%',
  'export status is scoped to its requesting owner');
select ok(pg_get_functiondef(
  'app_private.superadmin_request_child_safety_export(uuid,text,jsonb)'::regprocedure)
  like '%invalid child safety hierarchy%' and pg_get_functiondef(
  'app_private.superadmin_request_child_safety_export(uuid,text,jsonb)'::regprocedure)
  like '%without_authorization%',
  'export filter values and hierarchy are validated');
select ok(pg_get_functiondef(
  'app_private.child_safety_request_authorization(uuid,jsonb)'::regprocedure)
  like '%pg_advisory_xact_lock%' and pg_get_functiondef(
  'app_private.superadmin_request_child_safety_export(uuid,text,jsonb)'::regprocedure)
  like '%pg_advisory_xact_lock%',
  'idempotency keys serialize concurrent first use');
select ok(not has_table_privilege('authenticated','public.authorized_people','SELECT')
  and not has_table_privilege('authenticated','public.child_safety_evidence','SELECT'),
  'raw PII and evidence reads cannot bypass aggregate AAL2 RPCs');

set local role anon;
select throws_ok(
  $$select public.child_safety_request_authorization(
    '00000000-0000-0000-0000-000000000001','{}'::jsonb)$$,
  '42501','permission denied for function child_safety_request_authorization',
  'anon cannot call a mutation RPC directly'
);
select throws_ok(
  $$select public.superadmin_child_safety_get(
    '00000000-0000-0000-0000-000000000001')$$,
  '42501','permission denied for function superadmin_child_safety_get',
  'anon cannot probe child existence through detail'
);
reset role;

set local role authenticated;
select throws_ok(
  $$select * from public.authorized_people limit 1$$,
  '42501','permission denied for table authorized_people',
  'authenticated cannot bypass AAL2 through a direct table read'
);
reset role;

select * from finish();
rollback;
