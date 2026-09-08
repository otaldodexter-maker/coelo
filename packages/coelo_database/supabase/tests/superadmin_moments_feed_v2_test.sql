-- Candidate test for 20260908190654_superadmin_moments_feed_v2.sql.
--
-- What this file proves without an authenticated fixture: the read contract
-- exists with the expected shape and leaks no storage coordinate; the audience
-- rule is a closed set so an unrecognised or absent viewer class matches
-- nothing; the permission catalogue is reused rather than re-declared; the
-- ticket store is deny-by-default with RLS enabled, forced, unpolicied and
-- ungranted; the privilege split holds, so the browser may list and only the
-- gateway may redeem; and both entry points fail closed for a session that
-- carries no identity.
--
-- What this file proves as a source contract rather than as live behaviour:
-- that redemption re-authorises the publication, the membership, the audience
-- row, the auth link, the asset link and the ticket clock. Executing those
-- paths needs institution, person, membership, publication and asset rows, and
-- this candidate is not allowed to mint synthetic `public.people` identities,
-- so the guards are asserted against `pg_get_functiondef` in the same way
-- activity_template_unit_scope_test.sql asserts its internal-context guards.
-- Reintroducing any of the removed defects changes that definition and turns
-- the corresponding assert red, but a live replay with the internal identity
-- fixture is still owed before this is declared end to end.

begin;
create extension if not exists pgtap with schema extensions;
select plan(47);

-- === Contract surface =====================================================
select has_function('public', 'list_visible_moments',
  array['uuid','uuid','uuid','timestamp with time zone','uuid','integer']);
select has_function('public', 'redeem_moments_media_read_ticket', array['uuid','uuid']);
select has_function('app_private', 'moments_audience_matches_role',
  array['text','moments_audience_kind']);
select has_function('app_private', 'moments_viewer_role_class',
  array['uuid','uuid','uuid','uuid','uuid']);
select has_table('app_private', 'moments_media_read_tickets', 'the ticket store exists');

-- The projection returns descriptors, never storage coordinates.
select set_eq(
  $$select unnest(proargnames) from pg_proc
    where proname = 'list_visible_moments' and pronamespace = 'public'::regnamespace$$,
  $$values ('p_institution_id'),('p_unit_id'),('p_group_id'),('p_cursor_published_at'),
           ('p_cursor_id'),('p_limit'),('moment_id'),('author_name'),('author_initials'),
           ('context_label'),('caption'),('published_at'),('media')$$,
  'the read contract exposes no bucket, object key or URL');

-- === Permission catalogue is reused, not re-declared =======================
select hasnt_column('public', 'institution_permissions', 'name',
  'the permission catalogue has no name column, so nothing may insert one');
select is(
  (select count(*) from public.institution_permissions permission
    where permission.code = 'moments.publications.read'),
  1::bigint,
  'moments.publications.read is catalogued exactly once');
select is(
  (select permission.module_code || '/' || coalesce(permission.screen_code, '')
     || '/' || permission.action_code || '/' || permission.status::text
   from public.institution_permissions permission
   where permission.code = 'moments.publications.read'),
  'moments/publications/read/active',
  'the foundation module, screen, action and status survive untouched');

-- === Audience rule is a closed set ========================================
select is(app_private.moments_audience_matches_role('guardian', 'families'), true,
  'a guardian sees family audiences');
select is(app_private.moments_audience_matches_role('guardian', 'guardians_only'), true,
  'a guardian sees guardian-only audiences');
select is(app_private.moments_audience_matches_role('guardian', 'students'), false,
  'a guardian does not see student audiences');
select is(app_private.moments_audience_matches_role('guardian', 'school_staff'), false,
  'a guardian does not see staff audiences');
select is(app_private.moments_audience_matches_role('student', 'students'), true,
  'a student sees student audiences');
select is(app_private.moments_audience_matches_role('student', 'families'), false,
  'a student does not see family audiences');
select is(app_private.moments_audience_matches_role('school_staff', 'school_staff'), true,
  'a classified staff viewer sees staff audiences');
select is(app_private.moments_audience_matches_role('school_staff', 'guardians_only'), false,
  'staff does not inherit guardian-only audiences');

-- === An unknown class gets nothing ========================================
select is(app_private.moments_audience_matches_role(null, 'school_staff'), false,
  'a null class never falls back to the staff audience');
select is(app_private.moments_audience_matches_role(null, 'families'), false,
  'a null class never gains the family audience');
select ok(
  not exists(
    select 1
    from (values ('teacher'),('responsavel'),('parent'),('family'),('aluno'),
                 ('admin'),(''),('  '),('School_Staff_Assistant')) unknown_role(label)
    cross join (values ('families'),('students'),('school_staff'),('guardians_only'))
      audience_kind(audience)
    where app_private.moments_audience_matches_role(
      unknown_role.label, audience_kind.audience::public.moments_audience_kind)),
  'no unrecognised or malformed role label matches any audience');
select ok(
  app_private.moments_viewer_role_class(
    '00000000-0000-4000-8000-0000000000a1'::uuid,
    '00000000-0000-4000-8000-0000000000a2'::uuid,
    '00000000-0000-4000-8000-0000000000a3'::uuid,
    null, null) is null,
  'a viewer with no child, guardian or capability link is classified as nothing');

-- Normalised definitions: whitespace-squeezed and lowercased so the asserts
-- below track the guards themselves, not the formatting around them.
create temporary table moments_feed_definitions(name text primary key, body text);
insert into moments_feed_definitions values
  ('list', regexp_replace(lower(pg_catalog.pg_get_functiondef(
     'public.list_visible_moments(uuid,uuid,uuid,timestamptz,uuid,integer)'::regprocedure)),
     '\s+', ' ', 'g')),
  ('redeem', regexp_replace(lower(pg_catalog.pg_get_functiondef(
     'public.redeem_moments_media_read_ticket(uuid,uuid)'::regprocedure)),
     '\s+', ' ', 'g')),
  ('class', regexp_replace(lower(pg_catalog.pg_get_functiondef(
     'app_private.moments_viewer_role_class(uuid,uuid,uuid,uuid,uuid)'::regprocedure)),
     '\s+', ' ', 'g'));

select ok(
  (select body from moments_feed_definitions where name = 'class') like '%else null%'
  and (select body from moments_feed_definitions where name = 'class')
    not like '%else ''school_staff''%',
  'an unproven viewer class resolves to null, never to a privileged default');
select ok(
  (select body from moments_feed_definitions where name = 'list')
    like '%app_private.moments_viewer_role_class(%'
  and (select body from moments_feed_definitions where name = 'list')
    like '%viewer_context_not_authorized%'
  and (select body from moments_feed_definitions where name = 'list')
    not like '%role_code%',
  'the feed classifies by links and capabilities and never reads free role_code');

-- === Realm is stated, not assumed =========================================
select ok(
  (select body from moments_feed_definitions where name = 'list')
    like '%app_private.superadmin_internal_auth_links%'
  and (select body from moments_feed_definitions where name = 'list')
    like '%moments_internal_realm_unsupported%',
  'an internal Superadmin session is denied by name instead of drifting into the people realm');
select throws_ok(
  $$select * from public.list_visible_moments('00000000-0000-4000-8000-0000000000b1'::uuid)$$,
  '42501', 'authentication_required',
  'a session with no identity is refused before any row is considered');
select ok(
  (select body from moments_feed_definitions where name = 'redeem')
    like '%app_private.superadmin_internal_auth_links internal_link%',
  'redemption applies the same realm assertion the feed applies');

-- === Redemption re-authorises the whole chain =============================
select ok(
  (select body from moments_feed_definitions where name = 'redeem')
    like '%and ticket.expires_at > now()%',
  'an expired ticket is rejected at redemption, not merely stored with a timestamp');
select ok(
  (select body from moments_feed_definitions where name = 'redeem')
    like '%and publication.status = ''published''%'
  and (select body from moments_feed_definitions where name = 'redeem')
    like '%and publication.published_at <= now()%',
  'a ticket stops redeeming once its publication is removed or unpublished');
select ok(
  (select body from moments_feed_definitions where name = 'redeem')
    like '%and membership.institution_id = publication.institution_id%'
  and (select body from moments_feed_definitions where name = 'redeem')
    like '%and membership.status = ''active''%'
  and (select body from moments_feed_definitions where name = 'redeem')
    like '%and membership.revoked_at is null%',
  'a revoked or foreign membership cannot redeem a previously issued ticket');
select ok(
  (select body from moments_feed_definitions where name = 'redeem')
    like '%public.moments_publication_audiences audience%'
  and (select body from moments_feed_definitions where name = 'redeem')
    like '%app_private.moments_audience_matches_role(%'
  and (select body from moments_feed_definitions where name = 'redeem')
    like '%app_private.moments_viewer_role_class(%',
  'the audience is rematched against the current viewer class at redemption');
select ok(
  (select body from moments_feed_definitions where name = 'redeem')
    like '%and auth_link.status = ''active''%'
  and (select body from moments_feed_definitions where name = 'redeem')
    like '%and asset.status = ''ready''%'
  and (select body from moments_feed_definitions where name = 'redeem')
    like '%and link.media_asset_id = asset.id%',
  'a deactivated link, an unready asset or an unlinked asset all void the ticket');
select throws_ok(
  $$select public.redeem_moments_media_read_ticket(
      '00000000-0000-4000-8000-0000000000c1'::uuid,
      '00000000-0000-4000-8000-0000000000c2'::uuid)$$,
  '42501', 'moments_media_not_authorized',
  'an unknown ticket yields a denial, never a storage coordinate');
select throws_ok(
  $$select public.redeem_moments_media_read_ticket(null, null)$$,
  '42501', 'moments_media_not_authorized',
  'a null ticket or null viewer is refused rather than probed');

-- === Private store hardening ==============================================
select ok((select rolbypassrls from pg_roles where rolname = 'postgres'),
  'the definer owner has BYPASSRLS, so FORCE does not lock the feed out of its own store');
select is(
  (select pg_get_userbyid(relation.relowner) from pg_class relation
    where relation.oid = 'app_private.moments_media_read_tickets'::regclass),
  'postgres',
  'the ticket store is owned by the same role that owns the definer functions');
select ok(
  (select relation.relrowsecurity from pg_class relation
    where relation.oid = 'app_private.moments_media_read_tickets'::regclass),
  'the ticket store enables RLS');
select ok(
  (select relation.relforcerowsecurity from pg_class relation
    where relation.oid = 'app_private.moments_media_read_tickets'::regclass),
  'the ticket store forces RLS');
select is(
  (select count(*) from pg_policies policy
    where policy.schemaname = 'app_private'
      and policy.tablename = 'moments_media_read_tickets'),
  0::bigint,
  'the ticket store stays deny-by-default with no policy at all');
select ok(
  not exists(
    select 1
    from (values ('anon'),('authenticated'),('service_role')) client(role_name)
    cross join (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'))
      operation(privilege)
    where has_table_privilege(
      client.role_name, 'app_private.moments_media_read_tickets', operation.privilege)),
  'no client or service role holds a direct privilege on the ticket store');
select ok(
  (select body from moments_feed_definitions where name = 'list')
    like '%delete from app_private.moments_media_read_tickets ticket where ticket.expires_at <= now()%',
  'expired tickets are actively purged on read rather than left to accumulate');

-- === Privilege split ======================================================
select function_privs_are('public', 'list_visible_moments',
  array['uuid','uuid','uuid','timestamp with time zone','uuid','integer'],
  'authenticated', array['EXECUTE'],
  'the browser may list through the RPC');
select function_privs_are('public', 'list_visible_moments',
  array['uuid','uuid','uuid','timestamp with time zone','uuid','integer'],
  'anon', array[]::text[],
  'an anonymous caller may not list');
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
select function_privs_are('app_private', 'moments_viewer_role_class',
  array['uuid','uuid','uuid','uuid','uuid'],
  'authenticated', array[]::text[],
  'the viewer classifier is not callable from the browser');

-- === Definer hygiene ======================================================
select ok(
  (select bool_and(
      procedure.prosecdef
      and pg_get_userbyid(procedure.proowner) = 'postgres'
      and coalesce(procedure.proconfig, '{}'::text[]) @> array['search_path=""']::text[])
   from unnest(array[
     'public.list_visible_moments(uuid,uuid,uuid,timestamptz,uuid,integer)',
     'public.redeem_moments_media_read_ticket(uuid,uuid)',
     'app_private.moments_viewer_role_class(uuid,uuid,uuid,uuid,uuid)'
   ]) as expected(signature)
   join pg_proc procedure on procedure.oid = expected.signature::regprocedure),
  'every definer in this contract is postgres-owned with an empty search_path');

select * from finish();
rollback;
