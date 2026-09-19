-- Prova pgTAP da migration 20260920100000 (spec 068 §4: post do perfil oficial no feed Acontece).
-- Fixture com rollback (prefixo 9f4): operador owner publica/retira; responsável fictício (lote 106) lê o feed.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

select has_table('public','official_posts','official_posts exists');
select ok(not has_table_privilege('authenticated','public.official_posts','SELECT'),'posts are RPC-only');
select has_function('public','superadmin_official_post_publish_v1',array['uuid','uuid','text'],'publish rpc');
select has_function('public','list_visible_happens_feed_context_v1',array['uuid','uuid','uuid','uuid','timestamp with time zone','text','uuid','integer'],'context feed renamed');
select ok(not has_function_privilege('authenticated','public.list_visible_happens_feed_context_v1(uuid,uuid,uuid,uuid,timestamptz,text,uuid,integer)','EXECUTE'),'context feed is internal');

-- operador interno owner
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9f400000-0000-4000-8000-000000000101','authenticated','authenticated','op-9f4@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9f400000-0000-4000-8000-000000000201','9f400000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values ('9f400000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9f400000-0000-4000-8000-000000000501','9f400000-0000-4000-8000-000000000301','9f400000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select '9f400000-0000-4000-8000-000000000601','9f400000-0000-4000-8000-000000000301',r.id,'platform',null from public.platform_roles r where r.code='owner';
select set_config('request.jwt.claims',jsonb_build_object('sub','9f400000-0000-4000-8000-000000000101',
 'session_id','9f400000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);
select set_config('request.jwt.claim.sub','9f400000-0000-4000-8000-000000000101',true);

create temporary table r(label text primary key, body jsonb not null);
insert into r values ('pub', public.superadmin_official_post_publish_v1('9f400000-0000-4000-8000-000000000801',
  (select id from public.official_profiles where handle='coelo.educa'), 'Sono: rotina calma antes de dormir ajuda mais que qualquer app.'));
select is((select body#>>'{data,status}' from r where label='pub'),'published','post published');
select is((select body#>>'{data,handle}' from r where label='pub'),'coelo.educa','post signed by the profile');
insert into r values ('replay', public.superadmin_official_post_publish_v1('9f400000-0000-4000-8000-000000000801',
  (select id from public.official_profiles where handle='coelo.educa'), 'Sono: rotina calma antes de dormir ajuda mais que qualquer app.'));
select is((select body#>>'{data,replayed}' from r where label='replay'),'true','same request id replays');
insert into r values ('empty', public.superadmin_official_post_publish_v1('9f400000-0000-4000-8000-000000000802',
  (select id from public.official_profiles where handle='coelo.educa'), '   '));
select is((select body#>>'{error,code}' from r where label='empty'),'SAI_INVALID_ARGUMENT','empty caption refused');

-- responsável fictício do Horizonte Azul lê o feed do seu contexto
insert into auth.users(id) values ('9f400000-0000-4000-8000-000000000102');
insert into public.person_auth_links(person_id,auth_user_id,status) values ('f1c71000-0000-4000-8000-000400000004','9f400000-0000-4000-8000-000000000102','active');
select set_config('request.jwt.claims',jsonb_build_object('sub','9f400000-0000-4000-8000-000000000102','role','authenticated','aal','aal1')::text,true);
select set_config('request.jwt.claim.sub','9f400000-0000-4000-8000-000000000102',true);
set local role authenticated;
select is((select count(*) from public.list_visible_happens_feed('f1c71000-0000-4000-8000-000100000000','f1c71000-0000-4000-8000-000200000001','f1c71000-0000-4000-8000-000300000001',null,null,null,null,20) f
  where f.item_type='post' and f.payload->>'context_label'='Coelo · @coelo.educa'),1::bigint,'official post appears in the Acontece feed of the guardian');
select is((select jsonb_array_length(public.principal_official_profiles_v1('coelo.educa')#>'{data,posts}')),1,'profile page lists the post');
reset role;

-- retirada
select set_config('request.jwt.claims',jsonb_build_object('sub','9f400000-0000-4000-8000-000000000101',
 'session_id','9f400000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);
select set_config('request.jwt.claim.sub','9f400000-0000-4000-8000-000000000101',true);
insert into r values ('stale', public.superadmin_official_post_withdraw_v1('9f400000-0000-4000-8000-000000000803',
  (select (body#>>'{data,id}')::uuid from r where label='pub'), 9, 'Publicado por engano'));
select is((select body#>>'{error,code}' from r where label='stale'),'SAI_CONCURRENT_CHANGE','stale version is PT409');
insert into r values ('wd', public.superadmin_official_post_withdraw_v1('9f400000-0000-4000-8000-000000000804',
  (select (body#>>'{data,id}')::uuid from r where label='pub'), 1, 'Publicado por engano'));
select is((select body#>>'{data,status}' from r where label='wd'),'withdrawn','post withdrawn');

select * from finish();
rollback;
