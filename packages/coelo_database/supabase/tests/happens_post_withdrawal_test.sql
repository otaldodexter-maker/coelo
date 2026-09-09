begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

select has_column('public','posts','withdrawn_at','withdrawal timestamp exists');
select has_column('public','posts','withdrawn_by_person_id','withdrawal actor exists');
select has_column('public','posts','withdrawal_reason','withdrawal reason exists');

select ok(
  exists(select 1 from public.institution_permissions where code='happens.posts.remove' and status='active'),
  'removal capability is catalogued and active'
);

select has_function(
  'public','withdraw_happens_post',array['uuid','uuid','bigint','text'],
  'withdrawal command exists'
);

select ok(
  (select prosecdef from pg_proc where oid='public.withdraw_happens_post(uuid,uuid,bigint,text)'::regprocedure),
  'withdrawal command is security definer'
);

select ok(
  (select coalesce(proconfig,'{}'::text[]) from pg_proc where oid='public.withdraw_happens_post(uuid,uuid,bigint,text)'::regprocedure)
    @> array['search_path=""']::text[],
  'withdrawal command pins an empty search path'
);

select ok(
  has_function_privilege('authenticated','public.withdraw_happens_post(uuid,uuid,bigint,text)','execute'),
  'authenticated withdraws through the RPC'
);

select ok(
  not has_function_privilege('anon','public.withdraw_happens_post(uuid,uuid,bigint,text)','execute'),
  'anonymous callers cannot withdraw'
);

select ok(
  position('happens.posts.remove' in pg_get_functiondef('public.withdraw_happens_post(uuid,uuid,bigint,text)'::regprocedure))>0,
  'withdrawal checks the removal capability'
);

select ok(
  position('target.author_person_id<>actor.person_id' in replace(pg_get_functiondef('public.withdraw_happens_post(uuid,uuid,bigint,text)'::regprocedure),' ',''))>0,
  'only the author withdraws their own post'
);

select ok(
  position('expected_version_conflict' in pg_get_functiondef('public.withdraw_happens_post(uuid,uuid,bigint,text)'::regprocedure))>0,
  'withdrawal uses the optimistic version'
);

select ok(
  position('post_not_published' in pg_get_functiondef('public.withdraw_happens_post(uuid,uuid,bigint,text)'::regprocedure))>0,
  'a draft cannot be withdrawn'
);

select ok(
  position('post_withdrawn' in pg_get_functiondef('public.withdraw_happens_post(uuid,uuid,bigint,text)'::regprocedure))>0,
  'withdrawal writes a publication audit event'
);

select ok(
  position('deletefrompublic.posts' in replace(lower(pg_get_functiondef('public.withdraw_happens_post(uuid,uuid,bigint,text)'::regprocedure)),' ',''))=0
  and position('deletefrompublic.media' in replace(lower(pg_get_functiondef('public.withdraw_happens_post(uuid,uuid,bigint,text)'::regprocedure)),' ',''))=0,
  'withdrawal never deletes the post or its media'
);

select ok(
  position('post.withdrawn_atisnull' in replace(pg_get_functiondef('public.list_visible_happens_posts(uuid,uuid,uuid,integer)'::regprocedure),' ',''))>0,
  'the feed hides withdrawn posts'
);

select ok(
  position('can_withdraw:=visible_post.author_person_id=actor.person_id' in replace(pg_get_functiondef('public.list_visible_happens_posts(uuid,uuid,uuid,integer)'::regprocedure),' ',''))>0,
  'the feed only offers withdrawal to the author'
);

select ok(
  position('post.institution_id=p_institution_id' in replace(pg_get_functiondef('public.list_visible_happens_posts(uuid,uuid,uuid,integer)'::regprocedure),' ',''))>0,
  'the rebuilt feed stays tenant scoped'
);

select * from finish();
rollback;
