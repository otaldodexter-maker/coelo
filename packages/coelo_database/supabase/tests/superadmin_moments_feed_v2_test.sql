-- Candidate test for 20260908190654_superadmin_moments_feed_v2.sql.
--
-- Covers what is deterministic without an authenticated fixture: the read
-- contract exists with the expected shape, the audience rule matches the
-- Acontece one, and the privilege split holds — the browser may list, only the
-- gateway may redeem, and nobody reaches the ticket table. The membership,
-- audience and cursor paths through list_visible_moments need the internal
-- identity fixture and a local replay, which R01-C05-I007 keeps behind the lease
-- currently held elsewhere.

begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

select has_function('public', 'list_visible_moments',
  array['uuid','uuid','uuid','timestamp with time zone','uuid','integer']);
select has_function('public', 'redeem_moments_media_read_ticket', array['uuid','uuid']);
select has_function('app_private', 'moments_audience_matches_role',
  array['text','moments_audience_kind']);
select has_table('app_private', 'moments_media_read_tickets', 'the ticket store exists');

-- The projection returns descriptors, never storage coordinates.
select set_eq(
  $$select unnest(proargnames) from pg_proc
    where proname = 'list_visible_moments' and pronamespace = 'public'::regnamespace$$,
  $$values ('p_institution_id'),('p_unit_id'),('p_group_id'),('p_cursor_published_at'),
           ('p_cursor_id'),('p_limit'),('moment_id'),('author_name'),('author_initials'),
           ('context_label'),('caption'),('published_at'),('media')$$,
  'the read contract exposes no bucket, object key or URL');

-- Audience rule: identical to Acontece, so the two feeds cannot drift.
select is(app_private.moments_audience_matches_role('guardian', 'families'), true,
  'a guardian sees family audiences');
select is(app_private.moments_audience_matches_role('responsavel', 'guardians_only'), true,
  'a responsavel sees guardian-only audiences');
select is(app_private.moments_audience_matches_role('guardian', 'students'), false,
  'a guardian does not see student audiences');
select is(app_private.moments_audience_matches_role('guardian', 'school_staff'), false,
  'a guardian does not see staff audiences');
select is(app_private.moments_audience_matches_role('student', 'students'), true,
  'a student sees student audiences');
select is(app_private.moments_audience_matches_role('aluno', 'families'), false,
  'a student does not see family audiences');
select is(app_private.moments_audience_matches_role('teacher', 'school_staff'), true,
  'staff sees staff audiences');
select is(app_private.moments_audience_matches_role('teacher', 'guardians_only'), false,
  'staff does not inherit guardian-only audiences');
select is(app_private.moments_audience_matches_role(null, 'school_staff'), true,
  'an unknown role falls back to staff rather than to everything');
select is(app_private.moments_audience_matches_role(null, 'families'), false,
  'an unknown role never gains the family audience');

-- Privilege split.
select function_privs_are('public', 'list_visible_moments',
  array['uuid','uuid','uuid','timestamp with time zone','uuid','integer'],
  'authenticated', array['EXECUTE'],
  'the browser may list through the RPC');
select function_privs_are('public', 'redeem_moments_media_read_ticket', array['uuid','uuid'],
  'authenticated', array[]::text[],
  'the browser may never redeem a ticket itself');
select function_privs_are('public', 'redeem_moments_media_read_ticket', array['uuid','uuid'],
  'service_role', array['EXECUTE'],
  'only the gateway redeems, and it re-authorises again');
select function_privs_are('app_private', 'moments_audience_matches_role',
  array['text','moments_audience_kind'],
  'authenticated', array[]::text[],
  'the audience rule is not callable from the browser');
select table_privs_are('app_private', 'moments_media_read_tickets', 'authenticated',
  array[]::text[], 'tickets are unreachable from the browser');
select table_privs_are('app_private', 'moments_media_read_tickets', 'anon',
  array[]::text[], 'tickets are unreachable anonymously');

select * from finish();
rollback;
