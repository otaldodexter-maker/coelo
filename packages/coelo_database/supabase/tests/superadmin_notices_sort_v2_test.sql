-- Candidate test for 20260908190652_superadmin_notices_sort_v2.sql.
--
-- Covers what is deterministic without an authenticated fixture: the extended
-- signature, the fixed-expression allowlist and the two-part cursor
-- fingerprint. The authorisation, cross-scope and reset paths exercised through
-- superadmin_notice_directory_v2 need the internal-identity fixture and a local
-- replay, which R01-C05-I007 keeps behind the lease currently held elsewhere.

begin;
create extension if not exists pgtap with schema extensions;
select plan(37);

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

-- Regression guard for the ACL defect found in review: an earlier draft revoked
-- EXECUTE from every superadmin_notice_% function and granted only the
-- directory back, which silently broke five contracts the Superadmin client
-- already calls. Each one is asserted by name so the wildcard cannot come back.
select function_privs_are('public', 'superadmin_notice_detail_v2',
  array['uuid'], 'authenticated', array['EXECUTE'],
  'detail keeps the grant 20260901185008 gave it');
select function_privs_are('public', 'superadmin_notice_audience_options_v2',
  array['text','text','uuid[]','text','text','integer'],
  'authenticated', array['EXECUTE'],
  'audience options keeps the grant 20260901185008 gave it');
select function_privs_are('public', 'superadmin_notice_save_draft_v2',
  array['uuid','uuid','bigint','jsonb'], 'authenticated', array['EXECUTE'],
  'save draft keeps the grant 20260901185008 gave it');
select function_privs_are('public', 'superadmin_notice_publish_v2',
  array['uuid','uuid','bigint'], 'authenticated', array['EXECUTE'],
  'publish keeps the grant 20260901185008 gave it');
select function_privs_are('public', 'superadmin_notice_change_status_v2',
  array['uuid','uuid','bigint','text','text'], 'authenticated', array['EXECUTE'],
  'change status keeps the grant 20260901185008 gave it');

-- Regression guard for the error-code defect: NOTICE_INVALID_CURSOR is raised by
-- the directory, so it has to survive the envelope allowlist. Without the entry
-- it collapsed to NOTICE_INTERNAL_ERROR and the caller could not tell an
-- unusable cursor from a server fault.
select is(
  app_private.superadmin_notice_error(
    'NOTICE_INVALID_CURSOR', '9d100000-0000-4000-8000-0000000009c1')
    -> 'error' ->> 'code',
  'NOTICE_INVALID_CURSOR',
  'an unusable cursor keeps its own code instead of becoming an internal error');
select is(
  (app_private.superadmin_notice_error(
    'NOTICE_INVALID_CURSOR', '9d100000-0000-4000-8000-0000000009c1')
    -> 'error' ->> 'http_status')::integer,
  422,
  'an unusable cursor is a client-fixable refusal, not a 500');

-- The tie case, as a source contract rather than as live behaviour.
--
-- Executing it needs the internal-identity fixture and a local replay, which
-- stays behind a lease, so what is asserted here is the property that made the
-- defect possible: the ORDER BY direction and the keyset comparison operator
-- have to agree. Ascending orders id asc and resumes with `>`; descending orders
-- id desc and resumes with `<`. Mixing them is exactly what duplicated or
-- skipped rows whose sort value ties. Same technique the Momentos candidate uses
-- and that activity_template_unit_scope_test.sql established in this repository:
-- it catches the reintroduction, it does not replace the replay, and the replay
-- is still owed before anything here is called end to end.
-- Normalised definition: whitespace-squeezed and lowercased so the asserts track
-- the guard itself, not the formatting around it. A temporary table, not a CTE:
-- a `with` clause binds to one statement only, and these are five.
create temporary table notices_directory_definition(name text primary key, body text);
insert into notices_directory_definition values (
  'directory',
  regexp_replace(
    lower(
      pg_catalog.pg_get_functiondef(
        'public.superadmin_notice_directory_v2(text[],text,text[],text[],timestamptz,uuid,'
        'integer,text,boolean,text,text)'::regprocedure)),
    '\s+', ' ', 'g'));

select ok(
  (select body from notices_directory_definition) like
    '%case when p_sort_ascending then filtered.id end asc%',
  'ascending pages order the id tiebreak ascending');
select ok(
  (select body from notices_directory_definition) like
    '%p_sort_ascending and (filtered.sort_value, filtered.id) > (cursor_sort_value, cursor_id)%',
  'ascending pages resume with the matching > comparison');
select ok(
  (select body from notices_directory_definition) like
    '%case when not p_sort_ascending then filtered.id end desc%',
  'descending pages order the id tiebreak descending');
select ok(
  (select body from notices_directory_definition) like
    '%not p_sort_ascending and (filtered.sort_value, filtered.id) < (cursor_sort_value, cursor_id)%',
  'descending pages resume with the matching < comparison');
select ok(
  (select body from notices_directory_definition) not like '%filtered.id desc) page_row%',
  'the unconditional id desc tiebreak that disagreed with the filter is gone');

select * from finish();
rollback;
