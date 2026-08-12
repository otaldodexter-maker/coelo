begin;
create extension if not exists pgtap with schema extensions;
select plan(70);
select has_column('public','activity_definitions','canonical_handle','global handle');
select has_column('public','activity_definitions','management_version','optimistic version');
select has_column('public','activity_definitions','taxonomy_id','normalized taxonomy');
select has_column('public','activity_definitions','identity_storage_bucket','Supabase identity bucket');
select has_column('public','activity_definitions','identity_storage_path','Supabase identity path');
select has_column('public','activity_definitions','template_id','source activity template');
select has_table('public','activity_taxonomies','taxonomy catalog');
select has_table('public','activity_taxonomy_requests','audited taxonomy requests');
select has_table('public','activity_handle_aliases','handle aliases');
select has_table('public','activity_locations','unit locations');
select has_table('public','activity_templates','activity templates');
select has_table('public','activity_assignment_capability_actions','professional actions');
select has_table('public','activity_admin_assignments','activity-scoped admins');
select has_table('app_private','activity_identity_upload_intents','private upload intents');
select has_table('app_private','activity_management_command_receipts','private receipts');
select has_table('app_private','activity_template_command_receipts','private template receipts');
select results_eq(
  $$select count(*)::bigint from public.platform_permissions where code in (
    'activities.read','activities.create','activities.manage','activities.link_units',
    'activities.link_groups','activities.assign_people','activities.manage_permissions',
    'activities.import','activities.export','activities.templates.manage',
    'activities.taxonomy.manage') and status='active'$$,
  array[11::bigint],'platform capabilities');
select results_eq(
  $$select count(*)::bigint from public.activity_taxonomies
    where taxonomy_kind='category' and status='active'$$,
  array[12::bigint],'category seed');
select ok((select count(*)>=20 from public.activity_templates
  where scope_kind='platform' and status='active'),'template seed');
select results_eq(
 $$select count(*)::bigint from public.activity_templates where scope_kind='platform'
   and status='active' and code in (
    'musica','teatro','danca-bale','artes-visuais','capoeira','futsal','natacao',
    'judo','ingles','espanhol','robotica','programacao','ciencias-experimentais',
    'reforco-matematica','leitura-producao-textual','psicomotricidade',
    'yoga-relaxamento','horta-educacao-ambiental','culinaria','xadrez',
    'oficina-socioemocional')$$,
 array[21::bigint],'complete platform activity template seed');
select has_function('public','superadmin_activity_detail',array['uuid'],'detail RPC');
select has_function('public','superadmin_activity_directory',
  array['text','uuid[]','uuid[]','uuid[]','text[]','text[]','integer','integer','text','boolean'],
  'directory RPC');
select has_function('public','superadmin_activity_filter_options',array[]::text[],'filter RPC');
select has_function('public','superadmin_upsert_activity',array['jsonb','uuid'],'upsert RPC');
select has_function('public','superadmin_get_activity_form_options',array['uuid'],'form RPC');
select has_function('public','superadmin_activity_template_options',
  array['uuid'],'minimal template options RPC');
select has_function('public','superadmin_create_activity_locations',
  array['uuid','uuid[]','text','uuid'],'location RPC');
select has_function('public','superadmin_duplicate_activity_template',
  array['uuid','uuid','uuid'],'duplicate RPC');
select has_function('public','superadmin_copy_activity_template',
  array['uuid','uuid','uuid'],'copy template RPC');
select has_function('public','superadmin_request_activity_export',
  array['text','jsonb','uuid'],'export RPC');
select has_function('public','superadmin_create_activity_import_job',
  array['text','text','text','uuid'],'import RPC');
select has_function('public','superadmin_prepare_activity_identity_upload',
  array['uuid','text','text','bigint','uuid'],'identity prepare RPC');
select has_function('public','superadmin_finalize_activity_identity_upload',
  array['uuid','text','text','bigint','text','uuid'],'identity finalize RPC');
select has_function('public','superadmin_authorize_activity_file_job',
  array['uuid','text'],'activity file authorization RPC');
select ok(not has_table_privilege('authenticated','public.activity_definitions','INSERT')
  and not has_table_privilege('authenticated','public.activity_definitions','UPDATE')
  and not has_table_privilege('authenticated','public.activity_templates','INSERT'),
  'no direct aggregate writes');
select ok(not has_function_privilege('anon',
  'public.superadmin_upsert_activity(jsonb,uuid)','EXECUTE'),'anon denied');
select ok((select bool_and(c.relrowsecurity and c.relforcerowsecurity)
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in (
    'activity_taxonomies','activity_taxonomy_requests','activity_handle_aliases',
    'activity_locations','activity_templates','activity_assignment_capability_actions')),
  'new tables force RLS');
select ok(exists(select 1 from storage.buckets
  where id='coelo-identities' and not public),'identity bucket private');
select ok(exists(select 1 from pg_policies where schemaname='storage'
  and tablename='objects' and policyname='activity_identity_select')
  and exists(select 1 from pg_policies where schemaname='storage'
  and tablename='objects' and policyname='activity_identity_insert'),
  'storage policies');
select ok(pg_get_functiondef(
  'app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%has_platform_permission%activities.manage%'
  and pg_get_functiondef(
  'app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%pg_advisory_xact_lock%'
  and pg_get_functiondef(
  'app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%activity_management_command_receipts%',
  'upsert authorization concurrency and replay');

select ok(
 pg_get_functiondef('app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%participants%'
 and pg_get_functiondef('app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%professional_assignments%'
 and pg_get_functiondef('app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%activity_admin%'
 and pg_get_functiondef('app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%attendance%',
 'canonical participant and professional payload is enforced');
select ok((select proargnames=array[
 'p_activity_id','p_storage_path','p_mime_type','p_size_bytes',
 'p_checksum_sha256','p_idempotency_key']::text[]
 from pg_proc where oid=
  'public.superadmin_finalize_activity_identity_upload(uuid,text,text,bigint,text,uuid)'::regprocedure),
 'identity finalize argument names match the adapter');
select ok(
 not has_function_privilege('authenticated',
  'public.superadmin_activity_import_apply(uuid,uuid,jsonb,jsonb)','EXECUTE')
 and has_function_privilege('service_role',
  'public.superadmin_activity_import_apply(uuid,uuid,jsonb,jsonb)','EXECUTE')
 and not has_function_privilege('authenticated',
  'public.superadmin_activity_export_prepare(uuid)','EXECUTE')
 and has_function_privilege('service_role',
  'public.superadmin_activity_export_prepare(uuid)','EXECUTE'),
 'worker RPCs are service-role only');
select ok(
 has_function_privilege('authenticated',
  'public.superadmin_authorize_activity_file_job(uuid,text)','EXECUTE')
 and not has_function_privilege('anon',
  'public.superadmin_authorize_activity_file_job(uuid,text)','EXECUTE'),
 'file authorization RPC is authenticated-only');
select ok(
 pg_get_functiondef('app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%activities.link_units required%'
 and pg_get_functiondef('app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%activities.link_groups required%'
 and pg_get_functiondef('app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%idempotency receipt actor mismatch%',
 'upsert revalidates link capabilities and replay actor');
select ok(
 pg_get_functiondef('app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%activity.assignments.snapshot%'
 and pg_get_functiondef('app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%revoked_instructors%'
 and pg_get_functiondef('app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%revoked_admins%',
 'professional assignment payload is an audited snapshot');
select ok(
 pg_get_functiondef('app_private.superadmin_activity_export_prepare(uuid)'::regprocedure)
  like '%canonical_handle%'
 and pg_get_functiondef('app_private.superadmin_activity_export_prepare(uuid)'::regprocedure)
  like '%updated_at%'
 and pg_get_functiondef('app_private.superadmin_activity_export_prepare(uuid)'::regprocedure)
  like '%governance%'
 and pg_get_functiondef('app_private.superadmin_activity_export_prepare(uuid)'::regprocedure)
  like '%taxonomy%',
 'activity export exposes canonical columns');
select ok(
 has_function_privilege('authenticated',
  'public.superadmin_duplicate_activity_template(uuid,uuid,uuid)','EXECUTE')
 and has_function_privilege('authenticated',
  'public.superadmin_copy_activity_template(uuid,uuid,uuid)','EXECUTE')
 and not has_function_privilege('anon',
  'public.superadmin_duplicate_activity_template(uuid,uuid,uuid)','EXECUTE')
 and not has_function_privilege('anon',
  'public.superadmin_copy_activity_template(uuid,uuid,uuid)','EXECUTE'),
 'template commands are authenticated-only');
select ok(
 pg_get_functiondef(
  'app_private.superadmin_duplicate_activity_template(uuid,uuid,uuid)'::regprocedure)
  like '%activities.create required%'
 and pg_get_functiondef(
  'app_private.superadmin_duplicate_activity_template(uuid,uuid,uuid)'::regprocedure)
  like '%MFA AAL2 required%'
 and pg_get_functiondef(
  'app_private.superadmin_duplicate_activity_template(uuid,uuid,uuid)'::regprocedure)
  like '%activity_template_command_receipts%'
 and pg_get_functiondef(
  'app_private.superadmin_duplicate_activity_template(uuid,uuid,uuid)'::regprocedure)
  like '%activity.template.instantiate%',
 'create from template is authorized idempotent and audited');
select ok(
 pg_get_functiondef(
  'app_private.superadmin_copy_activity_template(uuid,uuid,uuid)'::regprocedure)
  like '%activities.templates.manage required%'
 and pg_get_functiondef(
  'app_private.superadmin_copy_activity_template(uuid,uuid,uuid)'::regprocedure)
  like '%template_payload%'
 and pg_get_functiondef(
  'app_private.superadmin_copy_activity_template(uuid,uuid,uuid)'::regprocedure)
 like '%activity.template.copy%',
 'copy template preserves defaults with capability and audit');
select ok(
 position('Cópia de ' in pg_get_functiondef(
  'app_private.superadmin_copy_activity_template(uuid,uuid,uuid)'::regprocedure))>0
 and position(chr(65533) in pg_get_functiondef(
  'app_private.superadmin_copy_activity_template(uuid,uuid,uuid)'::regprocedure))=0,
 'copied template name is valid UTF-8 without mojibake');
select ok(
 pg_get_functiondef(
  'app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%template_payload%'
 and pg_get_functiondef(
  'app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%activity template origin cannot change%'
 and pg_get_functiondef(
  'app_private.superadmin_upsert_activity(jsonb,uuid)'::regprocedure)
  like '%template_id,created_by_person_id%',
 'upsert atomically applies template defaults and persists immutable provenance');
select ok(
 pg_get_functiondef(
  'app_private.superadmin_get_activity_form_options(uuid)'::regprocedure)
  like '%description%'
 and pg_get_functiondef(
  'app_private.superadmin_get_activity_form_options(uuid)'::regprocedure)
  like '%scope_kind%'
 and pg_get_functiondef(
  'app_private.superadmin_get_activity_form_options(uuid)'::regprocedure)
  like '%institution_id%'
 and pg_get_functiondef(
  'app_private.superadmin_get_activity_form_options(uuid)'::regprocedure)
  like '%governance_kind%',
 'form options distinguish platform and institution activity templates');
select ok(
 has_function_privilege('authenticated',
  'public.superadmin_activity_template_options(uuid)','EXECUTE')
 and not has_function_privilege('anon',
  'public.superadmin_activity_template_options(uuid)','EXECUTE'),
 'minimal template options RPC is authenticated-only');
select ok(
 pg_get_functiondef(
  'app_private.superadmin_get_activity_form_options(uuid)'::regprocedure)
  like '%where p_institution_id is not null%'
 and pg_get_functiondef(
  'app_private.superadmin_get_activity_form_options(uuid)'::regprocedure)
  like '%'||quote_literal('students')||'%',
 'null institution cannot enumerate contextual form relations');
select ok(
 pg_get_functiondef(
  'app_private.superadmin_activity_template_options(uuid)'::regprocedure)
  not like '%'||quote_literal('units')||'%'
 and pg_get_functiondef(
  'app_private.superadmin_activity_template_options(uuid)'::regprocedure)
  not like '%'||quote_literal('groups')||'%'
 and pg_get_functiondef(
  'app_private.superadmin_activity_template_options(uuid)'::regprocedure)
  not like '%'||quote_literal('professionals')||'%'
 and pg_get_functiondef(
  'app_private.superadmin_activity_template_options(uuid)'::regprocedure)
  not like '%'||quote_literal('students')||'%'
 and pg_get_functiondef(
  'app_private.superadmin_activity_template_options(uuid)'::regprocedure)
  not like '%public.people%',
 'minimal template options cannot project contextual or personal relations');
select ok(
 pg_get_functiondef(
  'app_private.superadmin_activity_template_options(uuid)'::regprocedure)
  like '%p_institution_id is not null%'
 and pg_get_functiondef(
  'app_private.superadmin_activity_template_options(uuid)'::regprocedure)
  like '%template.institution_id = p_institution_id%',
 'institution templates are constrained to the requested institution');

set local role anon;
select throws_ok(
 $call$insert into public.activity_definitions(name,status)
       values('BOLA','draft')$call$,
 '42501',null,'anon cannot write activity table directly');
select throws_ok(
 $call$select public.superadmin_upsert_activity('{}'::jsonb,
       '10000000-0000-4000-8000-000000000001'::uuid)$call$,
 '42501',null,'anon cannot invoke activity upsert');

reset role;
set local role authenticated;
do $claims$
begin
 perform set_config('request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000099',true);
 perform set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000099","aal":"aal2","role":"authenticated"}',true);
end
$claims$;
select throws_ok(
 $call$select public.superadmin_activity_directory(
  '',array[]::uuid[],array[]::uuid[],array[]::uuid[],
  array[]::text[],array[]::text[],25,0,'name',true)$call$,
 '42501','authentication required',
 'unmapped authenticated subject cannot enumerate activities');
select throws_ok(
 $call$select public.superadmin_activity_detail(
  '10000000-0000-4000-8000-000000000002'::uuid)$call$,
 '42501','authentication required',
 'unmapped authenticated subject cannot probe activity ids');
select throws_ok(
 $call$select public.superadmin_upsert_activity('{}'::jsonb,
  '10000000-0000-4000-8000-000000000003'::uuid)$call$,
 '42501','authentication required',
 'unmapped authenticated subject cannot mutate activities');
select throws_ok(
 $call$select public.superadmin_create_activity_locations(
  '10000000-0000-4000-8000-000000000004'::uuid,
  array['10000000-0000-4000-8000-000000000005'::uuid],
  'BOLA','10000000-0000-4000-8000-000000000006'::uuid)$call$,
 '42501','authentication required',
 'unmapped authenticated subject cannot create cross-scope locations');
select throws_ok(
 $call$select public.superadmin_request_activity_export(
  'csv','{}'::jsonb,'10000000-0000-4000-8000-000000000007'::uuid)$call$,
 '42501','authentication required',
 'unmapped authenticated subject cannot export');
select throws_ok(
 $call$select public.superadmin_create_activity_import_job(
  'activities.csv','text/csv','csv',
  '10000000-0000-4000-8000-000000000008'::uuid)$call$,
 '42501','authentication required',
 'unmapped authenticated subject cannot create imports');
select throws_ok(
 $call$select public.superadmin_prepare_activity_identity_upload(
  '10000000-0000-4000-8000-000000000009'::uuid,
  'avatar.png','image/png',100,
  '10000000-0000-4000-8000-000000000010'::uuid)$call$,
 '42501','authentication required',
 'unmapped authenticated subject cannot prepare identity upload');
select throws_ok(
 $call$select public.superadmin_activity_export_prepare(
  '10000000-0000-4000-8000-000000000011'::uuid)$call$,
 '42501',null,'authenticated clients cannot invoke export workers');
select throws_ok(
 $call$select public.superadmin_authorize_activity_file_job(
  '10000000-0000-4000-8000-000000000012'::uuid,'export')$call$,
 '42501','authentication required',
 'unmapped authenticated subject cannot authorize a file job');
select throws_ok(
 $call$select public.superadmin_copy_activity_template(
  '10000000-0000-4000-8000-000000000013'::uuid,
  '10000000-0000-4000-8000-000000000014'::uuid,
  '10000000-0000-4000-8000-000000000015'::uuid)$call$,
 '42501','authentication required',
 'unmapped authenticated subject cannot copy a template');
select throws_ok(
 $call$select public.superadmin_activity_template_options(null)$call$,
 '42501','activities.read required',
 'unmapped authenticated subject cannot enumerate the template catalog');
reset role;
select * from finish();
rollback;
