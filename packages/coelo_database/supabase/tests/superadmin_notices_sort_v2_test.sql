-- Candidate test for 20260908190652_superadmin_notices_sort_v2.sql.
--
-- Covers what is deterministic without an authenticated fixture: the extended
-- signature, the fixed-expression allowlist and the two-part cursor
-- fingerprint. The authorisation, cross-scope and reset paths exercised through
-- superadmin_notice_directory_v2 need the internal-identity fixture and a local
-- replay, which R01-C05-I007 keeps behind the lease currently held elsewhere.

begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

-- The extended signature exists and the previous one is gone, so the two never
-- coexist as an ambiguous overload.
select has_function('public', 'superadmin_notice_directory_v2',
  array['text[]','text','text[]','text[]','timestamp with time zone','uuid','integer',
        'text','boolean','text','text']);
select hasnt_function('public', 'superadmin_notice_directory_v2',
  array['text[]','text','text[]','text[]','timestamp with time zone','uuid','integer']);
select has_function('app_private', 'superadmin_notice_sort_value',
  array['platform_notices','text']);
select has_function('app_private', 'superadmin_notice_cursor_fingerprint',
  array['text','text','boolean','text[]','text','text[]','text[]']);

insert into public.institution_types(id, code, name, status) values
  ('9d100000-0000-4000-8000-000000000001', 'notices-sort-v2', 'Notices sort v2', 'active');
insert into public.institutions(id, public_name, slug, status, institution_type_id) values
  ('9d100000-0000-4000-8000-000000000010', 'Colégio Ordena', 'notices-sort-v2-a', 'active',
   '9d100000-0000-4000-8000-000000000001');
insert into public.platform_notices(
  id, title, message, notice_type, status, priority_code, starts_at, ends_at, updated_at)
values
  ('9d100000-0000-4000-8000-000000000101', 'Zebra', 'Corpo', 'notice', 'active', 'routine',
   timestamptz '2026-01-02 03:04:05.678901+00', null, timestamptz '2026-05-01 10:00:00+00'),
  ('9d100000-0000-4000-8000-000000000102', 'alfa', 'Corpo', 'highlight', 'draft', 'urgent',
   null, null, timestamptz '2026-05-02 10:00:00+00');

-- Allowlist: one fixed expression per column, no SQL built from client text.
select is(
  (select app_private.superadmin_notice_sort_value(notice, 'updated_at')
   from public.platform_notices notice where notice.id = '9d100000-0000-4000-8000-000000000101'),
  '20260501100000000000',
  'updated_at becomes fixed-width UTC text');
select is(
  (select app_private.superadmin_notice_sort_value(notice, 'starts_at')
   from public.platform_notices notice where notice.id = '9d100000-0000-4000-8000-000000000101'),
  '20260102030405678901',
  'starts_at keeps microseconds so the keyset never ties on time alone');
select is(
  (select app_private.superadmin_notice_sort_value(notice, 'starts_at')
   from public.platform_notices notice where notice.id = '9d100000-0000-4000-8000-000000000102'),
  '',
  'a null starts_at sorts deterministically instead of vanishing');
select is(
  (select app_private.superadmin_notice_sort_value(notice, 'title')
   from public.platform_notices notice where notice.id = '9d100000-0000-4000-8000-000000000101'),
  'zebra',
  'title sorts case-insensitively');
select is(
  (select app_private.superadmin_notice_sort_value(notice, 'type')
   from public.platform_notices notice where notice.id = '9d100000-0000-4000-8000-000000000102'),
  'highlight',
  'type uses the enum text');
select is(
  (select app_private.superadmin_notice_sort_value(notice, 'priority')
   from public.platform_notices notice where notice.id = '9d100000-0000-4000-8000-000000000102'),
  'urgent',
  'priority uses the stored code');
select is(
  (select app_private.superadmin_notice_sort_value(notice, 'status')
   from public.platform_notices notice where notice.id = '9d100000-0000-4000-8000-000000000102'),
  'draft',
  'status uses the enum text');
select is(
  (select app_private.superadmin_notice_sort_value(notice, 'created_at')
   from public.platform_notices notice where notice.id = '9d100000-0000-4000-8000-000000000101'),
  null,
  'a column outside the allowlist resolves to nothing instead of leaking an expression');

-- Ordering: lower-case folding must not reorder by byte value.
select is(
  (select string_agg(notice.title, ',' order by
     app_private.superadmin_notice_sort_value(notice, 'title') asc, notice.id desc)
   from public.platform_notices notice
   where notice.id in ('9d100000-0000-4000-8000-000000000101',
                       '9d100000-0000-4000-8000-000000000102')),
  'alfa,Zebra',
  'ascending title ordering ignores case');

-- Fingerprint: two md5 halves, scope then query.
select matches(
  app_private.superadmin_notice_cursor_fingerprint(
    'institution:9d100000-0000-4000-8000-000000000010:owner',
    'updated_at', false, null, null, null, null),
  '^[0-9a-f]{32}\.[0-9a-f]{32}$',
  'the fingerprint is two md5 halves');

select isnt(
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'institution:9d100000-0000-4000-8000-000000000010:owner',
    'updated_at', false, null, null, null, null), '.', 1),
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'institution:9d100000-0000-4000-8000-000000000020:owner',
    'updated_at', false, null, null, null, null), '.', 1),
  'another scope changes the scope half, so its cursor can never be replayed');

select is(
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'institution:9d100000-0000-4000-8000-000000000010:owner',
    'updated_at', false, null, null, null, null), '.', 1),
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'institution:9d100000-0000-4000-8000-000000000010:owner',
    'title', true, array['notice'], 'busca', null, null), '.', 1),
  'the scope half ignores sort and filters');

select isnt(
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'updated_at', false, null, null, null, null), '.', 2),
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'title', false, null, null, null, null), '.', 2),
  'a different sort column changes the query half');

select isnt(
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'updated_at', false, null, null, null, null), '.', 2),
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'updated_at', true, null, null, null, null), '.', 2),
  'a different direction changes the query half');

select isnt(
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'updated_at', false, null, null, null, null), '.', 2),
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'updated_at', false, array['notice'], null, null, null), '.', 2),
  'a different type filter changes the query half');

select isnt(
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'updated_at', false, null, null, null, null), '.', 2),
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'updated_at', false, null, 'busca', null, null), '.', 2),
  'a different search changes the query half');

select isnt(
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'updated_at', false, null, null, null, null), '.', 2),
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'updated_at', false, null, null, array['active'], null), '.', 2),
  'a different status filter changes the query half');

select isnt(
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'updated_at', false, null, null, null, null), '.', 2),
  split_part(app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'updated_at', false, null, null, null, array['urgent']), '.', 2),
  'a different priority filter changes the query half');

select is(
  app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'updated_at', false, null, null, null, null),
  app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'updated_at', false, null, '   ', null, null),
  'a blank search is the same query as no search');

select is(
  app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'updated_at', false, null, 'busca', null, null),
  app_private.superadmin_notice_cursor_fingerprint(
    'scope', 'updated_at', false, null, '  busca  ', null, null),
  'surrounding whitespace does not invent a different query');

-- The caller is never trusted to execute the function directly as a table read.
select function_privs_are('public', 'superadmin_notice_directory_v2',
  array['text[]','text','text[]','text[]','timestamp with time zone','uuid','integer',
        'text','boolean','text','text'],
  'authenticated', array['EXECUTE'],
  'only authenticated may execute, and only through the RPC');

select * from finish();
rollback;
