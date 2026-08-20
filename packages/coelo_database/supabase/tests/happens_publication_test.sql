begin;
create extension if not exists pgtap with schema extensions;
select plan(53);

select has_table('public','posts','Acontece posts exist');
select has_table('public','post_audiences','post audiences exist');
select has_table('public','media_assets','media metadata exists');
select has_table('public','media_links','post media links exist');
select has_table('app_private','happens_publication_audit','publication audit exists');
select has_table('app_private','happens_media_read_tickets','private media read tickets exist');
select has_function('public','load_happens_draft',array['uuid','uuid','uuid'],'draft query exists');
select has_function('public','save_happens_draft',array['uuid','jsonb','uuid','bigint'],'draft command exists');
select has_function('public','prepare_happens_media_upload',array['text','uuid','uuid','text','text','bigint'],'upload intent exists');
select has_function('public','finalize_happens_media_upload',array['uuid','uuid','text','bigint'],'upload finalization exists');
select has_function('public','remove_happens_media',array['uuid'],'authorized media removal exists');
select has_function('public','publish_happens_post',array['uuid','uuid','bigint','timestamp with time zone'],'publish command exists');
select has_function('public','list_visible_happens_posts',array['uuid','uuid','uuid','integer'],'audience-resolved feed projection exists');
select has_function('public','redeem_happens_media_read_ticket',array['uuid','uuid'],'service-only ticket redemption exists');
select has_function('app_private','happens_audience_matches_role',array['text','happens_audience_kind'],'audience matcher exists');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.posts'::regclass),'posts force RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.post_audiences'::regclass),'audiences force RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.media_assets'::regclass),'media force RLS');
select ok(not has_table_privilege('authenticated','public.posts','insert,update,delete'),'client cannot mutate posts directly');
select ok(not has_table_privilege('authenticated','public.post_audiences','insert,update,delete'),'client cannot mutate audiences directly');
select ok(not has_table_privilege('authenticated','public.media_assets','insert,update,delete'),'client cannot mutate media metadata directly');
select ok(has_function_privilege('authenticated','public.save_happens_draft(uuid,jsonb,uuid,bigint)','execute'),'authenticated can save through RPC');
select ok(has_function_privilege('authenticated','public.publish_happens_post(uuid,uuid,bigint,timestamptz)','execute'),'authenticated can publish through RPC');
select ok(not has_function_privilege('authenticated','public.redeem_happens_media_read_ticket(uuid,uuid)','execute'),'client cannot redeem storage descriptors directly');
select ok(has_function_privilege('service_role','public.redeem_happens_media_read_ticket(uuid,uuid)','execute'),'media worker can redeem a read ticket');
select ok(exists(select 1 from storage.buckets where id='coelo-happens-mvp' and not public),'temporary bucket is private');
select ok(not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname like 'happens_media_%_write'),'browser has no direct write policy');
select ok(position('happens.posts.create' in pg_get_functiondef('public.save_happens_draft(uuid,jsonb,uuid,bigint)'::regprocedure))>0,'save checks create capability');
select ok(position('happens.posts.publish' in pg_get_functiondef('public.publish_happens_post(uuid,uuid,bigint,timestamptz)'::regprocedure))>0,'publish checks publish capability');
select ok(exists(select 1 from public.institution_permissions where code='happens.posts.read'),'read capability exists');
select ok(position('happens.posts.read' in pg_get_functiondef('public.list_visible_happens_posts(uuid,uuid,uuid,integer)'::regprocedure))>0,'feed checks read capability');
select ok(position('author_person_id' in pg_get_functiondef('public.prepare_happens_media_upload(text,uuid,uuid,text,text,bigint)'::regprocedure))>0,'upload preparation binds post ownership');
select ok(position('institution_id=asset.institution_id' in replace(pg_get_functiondef('public.finalize_happens_media_upload(uuid,uuid,text,bigint)'::regprocedure),' ',''))>0,'media finalization binds post tenant');
select ok(position('post.institution_id=p_institution_id' in replace(pg_get_functiondef('public.list_visible_happens_posts(uuid,uuid,uuid,integer)'::regprocedure),' ',''))>0,'feed query remains tenant scoped');
select ok(position('unit_scope_invalid' in pg_get_functiondef('public.save_happens_draft(uuid,jsonb,uuid,bigint)'::regprocedure))>0,'draft rejects cross-institution unit scope');
select ok(position('group_scope_invalid' in pg_get_functiondef('public.save_happens_draft(uuid,jsonb,uuid,bigint)'::regprocedure))>0,'draft rejects cross-institution group scope');
select ok(position('target.unit_id,target.group_id' in replace(pg_get_functiondef('public.prepare_happens_media_upload(text,uuid,uuid,text,text,bigint)'::regprocedure),' ',''))>0,'media authorization uses the post scope');
select ok(position('expected_version' in pg_get_functiondef('public.save_happens_draft(uuid,jsonb,uuid,bigint)'::regprocedure))>0,'save uses optimistic version');
select ok(position('publish_at' in pg_get_functiondef('public.list_visible_happens_posts(uuid,uuid,uuid,integer)'::regprocedure))>0,'feed visibility derives scheduled state from time');
select ok(position('published_media_immutable' in pg_get_functiondef('public.remove_happens_media(uuid)'::regprocedure))>0,'published media cannot be removed');
select ok(
  pg_get_function_result('public.list_visible_happens_posts(uuid,uuid,uuid,integer)'::regprocedure)
    = 'TABLE(author_name text, author_initials text, context_label text, caption text, published_at timestamp with time zone, media jsonb)',
  'feed exposes only the minimum presentation projection'
);
select ok(
  position('post_audiences' in pg_get_functiondef('public.list_visible_happens_posts(uuid,uuid,uuid,integer)'::regprocedure))>0,
  'feed resolves post audiences'
);
select ok(
  position('guardians_only' in pg_get_functiondef('app_private.happens_audience_matches_role(text,public.happens_audience_kind)'::regprocedure))>0
  and position('students' in pg_get_functiondef('app_private.happens_audience_matches_role(text,public.happens_audience_kind)'::regprocedure))>0
  and position('school_staff' in pg_get_functiondef('app_private.happens_audience_matches_role(text,public.happens_audience_kind)'::regprocedure))>0,
  'feed keeps family, student and staff audiences separated'
);
select ok(
  position('happens_media_read_tickets' in pg_get_functiondef('public.list_visible_happens_posts(uuid,uuid,uuid,integer)'::regprocedure))>0,
  'feed issues opaque media read tickets instead of storage paths'
);
select ok(
  position('ticket.expires_at>now()' in replace(pg_get_functiondef('public.redeem_happens_media_read_ticket(uuid,uuid)'::regprocedure),' ',''))>0,
  'ticket redemption rejects expired tickets'
);
select ok(
  position('delete from app_private.happens_media_read_tickets' in pg_get_functiondef('public.redeem_happens_media_read_ticket(uuid,uuid)'::regprocedure))>0,
  'read tickets are single use'
);
select ok(
  position('auth_link.auth_user_id=p_viewer_auth_user_id' in replace(pg_get_functiondef('public.redeem_happens_media_read_ticket(uuid,uuid)'::regprocedure),' ',''))>0,
  'ticket redemption remains bound to the authenticated viewer'
);
select is(app_private.happens_audience_matches_role('guardian','families'),true,'guardian receives family posts');
select is(app_private.happens_audience_matches_role('guardian','guardians_only'),true,'guardian receives guardian-only posts');
select is(app_private.happens_audience_matches_role('guardian','students'),false,'guardian never crosses into student posts');
select is(app_private.happens_audience_matches_role('student','students'),true,'student receives student posts');
select is(app_private.happens_audience_matches_role('student','school_staff'),false,'student never crosses into staff posts');
select is(app_private.happens_audience_matches_role('teacher','school_staff'),true,'staff receives staff posts');

select * from finish();
rollback;
