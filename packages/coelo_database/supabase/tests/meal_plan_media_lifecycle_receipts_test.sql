begin;

create extension if not exists pgtap with schema extensions;

select plan(30);

select has_table('app_private', 'meal_plan_command_receipts', 'command receipts exist');
select has_column('public', 'meal_plan_image_assets', 'revision', 'image assets are revisioned');
select has_column('app_private', 'meal_plan_image_upload_intents', 'finalize_payload_hash', 'finalize replay fingerprints the full payload');
select has_column('app_private', 'meal_plan_image_delete_requests', 'state', 'cleanup lifecycle is persisted');
select has_column('app_private', 'meal_plan_image_delete_requests', 'attempts', 'cleanup retries are persisted');
select has_function('public', 'meal_plan_archive', array['text','uuid','integer'], 'archive is explicit');
select has_function('public', 'meal_plan_request_image_delete', array['uuid','uuid','integer'], 'delete accepts optimistic revision');
select has_function('public', 'meal_plan_claim_image_cleanup', array['integer'], 'worker can claim cleanup jobs');
select has_function('public', 'meal_plan_complete_image_cleanup', array['uuid','boolean','text'], 'worker can complete cleanup jobs');
select ok(
  (select relrowsecurity and relforcerowsecurity
   from pg_class where oid = 'app_private.meal_plan_command_receipts'::regclass),
  'receipts force RLS');
select ok(
  not has_table_privilege('authenticated', 'app_private.meal_plan_command_receipts', 'SELECT')
  and not has_table_privilege('anon', 'app_private.meal_plan_command_receipts', 'SELECT'),
  'browser roles cannot read private receipts');
select ok(
  not exists (select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'meal_plan_image_object_delete'),
  'authenticated clients cannot physically delete private meal-plan objects');
select ok(
  has_function_privilege('authenticated',
    'public.meal_plan_request_image_delete(uuid,uuid,integer)', 'EXECUTE')
  and not has_function_privilege('anon',
    'public.meal_plan_request_image_delete(uuid,uuid,integer)', 'EXECUTE'),
  'revisioned delete is authenticated only');
select ok(
  has_function_privilege('service_role',
    'public.meal_plan_claim_image_cleanup(integer)', 'EXECUTE')
  and not has_function_privilege('authenticated',
    'public.meal_plan_claim_image_cleanup(integer)', 'EXECUTE'),
  'only service_role can claim cleanup jobs');
select ok(
  has_function_privilege('service_role',
    'public.meal_plan_complete_image_cleanup(uuid,boolean,text)', 'EXECUTE')
  and not has_function_privilege('authenticated',
    'public.meal_plan_complete_image_cleanup(uuid,boolean,text)', 'EXECUTE'),
  'only service_role can complete cleanup jobs');
select ok(
  pg_get_functiondef(
    'app_private.meal_plan_request_image_delete(uuid,uuid,integer)'::regprocedure)
      like '%asset.created_by <> actor_id%'
  and pg_get_functiondef(
    'app_private.meal_plan_request_image_delete(uuid,uuid,integer)'::regprocedure)
      like '%meal_plan_scope_allowed%'
  and pg_get_functiondef(
    'app_private.meal_plan_request_image_delete(uuid,uuid,integer)'::regprocedure)
      like '%asset.revision <> p_expected_revision%',
  'delete revalidates owner, tenant scope and revision');
select ok(
  pg_get_functiondef(
    'app_private.meal_plan_finalize_image_upload(uuid,text,text,uuid)'::regprocedure)
      like '%finalize_payload_hash%'
  and pg_get_functiondef(
    'app_private.meal_plan_finalize_image_upload(uuid,text,text,uuid)'::regprocedure)
      like '%pg_advisory_xact_lock%'
  and pg_get_functiondef(
    'app_private.meal_plan_finalize_image_upload(uuid,text,text,uuid)'::regprocedure)
      like '%replacement image ownership denied%',
  'finalize replay is complete, locked and owner-bound');
select ok(
  pg_get_functiondef('public.meal_plan_claim_image_cleanup(integer)'::regprocedure)
      like '%skip locked%'
  and pg_get_functiondef('public.meal_plan_claim_image_cleanup(integer)'::regprocedure)
      like '%attempts < 10%'
  and pg_get_functiondef('public.meal_plan_claim_image_cleanup(integer)'::regprocedure)
      like '%pg_try_advisory_xact_lock%',
  'cleanup claims are concurrent, bounded and asset-locked');
select ok(
  pg_get_functiondef(
    'public.meal_plan_complete_image_cleanup(uuid,boolean,text)'::regprocedure)
      like '%meal plan image object still exists%'
  and pg_get_functiondef(
    'public.meal_plan_complete_image_cleanup(uuid,boolean,text)'::regprocedure)
      like '%state = ''cancelled''%',
  'cleanup completion cannot hide a live or active object');
select ok(
  pg_get_functiondef(
    'public.meal_plan_create_or_update_draft(text,jsonb,uuid,integer)'::regprocedure)
      like '%meal_plan_command_receipts%'
  and pg_get_functiondef(
    'public.meal_plan_submit_for_review(text,uuid,integer)'::regprocedure)
      like '%meal_plan_command_receipts%'
  and pg_get_functiondef(
    'public.meal_plan_publish(text,uuid,integer)'::regprocedure)
      like '%meal_plan_command_receipts%'
  and pg_get_functiondef(
    'public.meal_plan_archive(text,uuid,integer)'::regprocedure)
      like '%meal_plan_command_receipts%',
  'all meal-plan commands persist actor-bound receipts');
select ok(
  pg_get_functiondef(
    'public.meal_plan_publish_unreceipted(text,uuid,integer)'::regprocedure)
      like '%unresolved conflict%',
  'publication still blocks unresolved equal-priority conflicts');

insert into auth.users(id, aud, role, email, created_at, updated_at) values
  ('9a000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'meal-owner-a@test.invalid', now(), now()),
  ('9a000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'meal-owner-b@test.invalid', now(), now());
insert into public.people(id, person_type, first_name, last_name, display_name, status) values
  ('9a100000-0000-4000-8000-000000000001', 'adult', 'Meal', 'Owner A', 'Meal Owner A', 'active'),
  ('9a100000-0000-4000-8000-000000000002', 'adult', 'Meal', 'Owner B', 'Meal Owner B', 'active');
insert into public.person_auth_links(person_id, auth_user_id, status) values
  ('9a100000-0000-4000-8000-000000000001', '9a000000-0000-4000-8000-000000000001', 'active'),
  ('9a100000-0000-4000-8000-000000000002', '9a000000-0000-4000-8000-000000000002', 'active');
insert into public.institutions(id, public_name, legal_name, slug, status) values
  ('9a200000-0000-4000-8000-000000000001', 'Meal Institution A', 'Meal Institution A', 'meal-receipts-a', 'active'),
  ('9a200000-0000-4000-8000-000000000002', 'Meal Institution B', 'Meal Institution B', 'meal-receipts-b', 'active');
insert into public.platform_memberships(
  person_id, role_id, status, scope_kind, scope_institution_id, mfa_required
)
select '9a100000-0000-4000-8000-000000000001', id, 'active', 'institution',
  '9a200000-0000-4000-8000-000000000001', false
from public.platform_roles where code = 'owner';
insert into public.platform_memberships(
  person_id, role_id, status, scope_kind, scope_institution_id, mfa_required
)
select '9a100000-0000-4000-8000-000000000002', id, 'active', 'institution',
  '9a200000-0000-4000-8000-000000000002', false
from public.platform_roles where code = 'owner';

insert into public.meal_plans(
  id, tenant_id, institution_id, name, status, source_type, scope_level,
  scope_id, start_date, end_date, created_by, updated_by
) values
  ('9a300000-0000-4000-8000-000000000001', '9a200000-0000-4000-8000-000000000001',
   '9a200000-0000-4000-8000-000000000001', 'Meal A', 'draft', 'institution',
   'institution', '9a200000-0000-4000-8000-000000000001', current_date, current_date,
   '9a100000-0000-4000-8000-000000000001', '9a100000-0000-4000-8000-000000000001'),
  ('9a300000-0000-4000-8000-000000000002', '9a200000-0000-4000-8000-000000000002',
   '9a200000-0000-4000-8000-000000000002', 'Meal B', 'draft', 'institution',
   'institution', '9a200000-0000-4000-8000-000000000002', current_date, current_date,
   '9a100000-0000-4000-8000-000000000002', '9a100000-0000-4000-8000-000000000002');
insert into public.meal_plan_image_assets(
  id, tenant_id, institution_id, resource_kind, meal_plan_id, storage_path,
  mime_type, size_bytes, checksum_sha256, status, created_by, activated_at
) values (
  '9a400000-0000-4000-8000-000000000001',
  '9a200000-0000-4000-8000-000000000001',
  '9a200000-0000-4000-8000-000000000001', 'meal_plan',
  '9a300000-0000-4000-8000-000000000001',
  'meal-plans/9a300000-0000-4000-8000-000000000001/9a400000-0000-4000-8000-000000000001.jpg',
  'image/jpeg', 100, repeat('a', 64), 'active',
  '9a100000-0000-4000-8000-000000000001', now()
);

create temporary table meal_plan_receipt_results(
  key text primary key,
  result jsonb not null
);
grant select, insert, update on meal_plan_receipt_results to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub', '9a000000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"9a000000-0000-4000-8000-000000000002","aal":"aal1","role":"authenticated"}', true);
select results_eq(
  $$select count(*)::bigint from public.meal_plan_image_assets
    where id = '9a400000-0000-4000-8000-000000000001'$$,
  array[0::bigint],
  'RLS hides tenant A image metadata from tenant B actor');
select throws_ok(
  $$select public.meal_plan_request_image_delete(
    '9a400000-0000-4000-8000-000000000001',
    '9a500000-0000-4000-8000-000000000001', 1)$$,
  '42501', 'meal plan image delete denied',
  'tenant B actor cannot delete tenant A owner media');

select set_config('request.jwt.claim.sub', '9a000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"9a000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}', true);
insert into meal_plan_receipt_results(key, result)
select 'delete', public.meal_plan_request_image_delete(
  '9a400000-0000-4000-8000-000000000001',
  '9a500000-0000-4000-8000-000000000001', 1);
select is(
  (select result ->> 'confirmed' from meal_plan_receipt_results where key = 'delete'),
  'true', 'owner can close metadata immediately when no object exists');
select is(
  (public.meal_plan_request_image_delete(
    '9a400000-0000-4000-8000-000000000001',
    '9a500000-0000-4000-8000-000000000001', 1) ->> 'revision'),
  (select result ->> 'revision' from meal_plan_receipt_results where key = 'delete'),
  'owner delete replay returns the same result');
select throws_ok(
  $$select public.meal_plan_request_image_delete(
    '9a400000-0000-4000-8000-000000000001',
    '9a500000-0000-4000-8000-000000000001', 2)$$,
  '22023', 'idempotency key reused',
  'changed delete payload cannot reuse a receipt');

insert into meal_plan_receipt_results(key, result)
select 'review-a', public.meal_plan_submit_for_review(
  'shared-review-request', '9a300000-0000-4000-8000-000000000001', 0);
select is(
  public.meal_plan_submit_for_review(
    'shared-review-request', '9a300000-0000-4000-8000-000000000001', 0),
  (select result from meal_plan_receipt_results where key = 'review-a'),
  'review replay returns the original result after revision changed');
select throws_ok(
  $$select public.meal_plan_submit_for_review(
    'shared-review-request', '9a300000-0000-4000-8000-000000000001', 1)$$,
  '22023', 'idempotency key reused',
  'changed lifecycle payload cannot reuse a receipt');

select set_config('request.jwt.claim.sub', '9a000000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"9a000000-0000-4000-8000-000000000002","aal":"aal1","role":"authenticated"}', true);
insert into meal_plan_receipt_results(key, result)
select 'review-b', public.meal_plan_submit_for_review(
  'shared-review-request', '9a300000-0000-4000-8000-000000000002', 0);

reset role;
select results_eq(
  $$select count(*)::bigint from app_private.meal_plan_command_receipts
    where request_id = 'shared-review-request'$$,
  array[2::bigint],
  'the same external request id remains isolated per actor');

set local role authenticated;
select set_config('request.jwt.claim.sub', '9a000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"9a000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}', true);
select is(
  public.meal_plan_archive(
    'archive-a', '9a300000-0000-4000-8000-000000000001', 1) ->> 'status',
  'archived', 'authorized owner archives with optimistic revision');

reset role;
select * from finish();
rollback;