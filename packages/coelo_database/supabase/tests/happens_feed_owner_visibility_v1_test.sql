-- Owner ve tudo no feed do Acontece (pacote 20260911130200, R05 principal-chat-sistema).
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('e6000000-0000-4000-8000-000000000001','adult','Owner','Feed','Owner Feed','active'),
  ('e6000000-0000-4000-8000-000000000002','adult','Prof','Feed','Prof Feed','active'),
  ('e6000000-0000-4000-8000-000000000003','adult','Nada','Feed','Nada Feed','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('e7000000-0000-4000-8000-000000000001','Feed X','Feed X','feed-x','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
  ('e8000000-0000-4000-8000-000000000001','e6000000-0000-4000-8000-000000000001','e7000000-0000-4000-8000-000000000001','owner','active','institution'),
  ('e8000000-0000-4000-8000-000000000002','e6000000-0000-4000-8000-000000000002','e7000000-0000-4000-8000-000000000001','teacher','active','institution'),
  ('e8000000-0000-4000-8000-000000000003','e6000000-0000-4000-8000-000000000003','e7000000-0000-4000-8000-000000000001','visitor','active','institution');
insert into public.posts(id,institution_id,author_person_id,author_membership_id,caption,status,publish_at,published_at) values
  ('e9000000-0000-4000-8000-000000000001','e7000000-0000-4000-8000-000000000001','e6000000-0000-4000-8000-000000000001','e8000000-0000-4000-8000-000000000001','para familias','published',now()-interval '1 minute',now()-interval '1 minute'),
  ('e9000000-0000-4000-8000-000000000002','e7000000-0000-4000-8000-000000000001','e6000000-0000-4000-8000-000000000001','e8000000-0000-4000-8000-000000000001','para equipe','published',now()-interval '1 minute',now()-interval '1 minute');
insert into public.post_audiences(post_id,audience_kind,institution_id) values
  ('e9000000-0000-4000-8000-000000000001','families','e7000000-0000-4000-8000-000000000001'),
  ('e9000000-0000-4000-8000-000000000002','school_staff','e7000000-0000-4000-8000-000000000001');

select ok(app_private.circular_feed_post_visible((select p from public.posts p where p.id='e9000000-0000-4000-8000-000000000001'),'e6000000-0000-4000-8000-000000000001','owner',null,null),
  'owner ve o post para familias');
select ok(app_private.circular_feed_post_visible((select p from public.posts p where p.id='e9000000-0000-4000-8000-000000000002'),'e6000000-0000-4000-8000-000000000001','owner',null,null),
  'owner ve o post para a equipe');
select ok(not app_private.circular_feed_post_visible((select p from public.posts p where p.id='e9000000-0000-4000-8000-000000000001'),'e6000000-0000-4000-8000-000000000002','teacher',null,null),
  'professor continua sem ver o post so para familias');
select ok(app_private.circular_feed_post_visible((select p from public.posts p where p.id='e9000000-0000-4000-8000-000000000002'),'e6000000-0000-4000-8000-000000000002','teacher',null,null),
  'professor ve o post para a equipe');
select ok(not app_private.circular_feed_post_visible((select p from public.posts p where p.id='e9000000-0000-4000-8000-000000000002'),'e6000000-0000-4000-8000-000000000003','visitor',null,null),
  'papel desconhecido continua sem ver nada (deny-by-default)');
select ok(not has_function_privilege('authenticated','app_private.circular_feed_post_visible(public.posts,uuid,text,uuid,uuid)','execute'),
  'predicado sem execute a cliente');

select * from finish();
rollback;
