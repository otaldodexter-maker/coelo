-- Prova pgTAP da migration 20260919213000_media_happens_draft_read_v1 (lote 92):
-- o autor relê a mídia pronta do próprio rascunho do Acontece (Edge happens-media `read-draft`);
-- ninguém de fora do tenant, nem quem não é o dono, recebe o descritor.
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

select has_function('public','authorize_happens_draft_media_read',array['uuid','uuid'],'authorize_happens_draft_media_read(institution, asset) exists');
select ok(has_function_privilege('authenticated','public.authorize_happens_draft_media_read(uuid,uuid)','execute')
  and not has_function_privilege('anon','public.authorize_happens_draft_media_read(uuid,uuid)','execute'),'authenticated only');

-- Fixtures (prefixo b2): autora A com happens.posts.create no tenant A; leitora L no mesmo tenant sem ser dona; tenant B.
insert into auth.users(id) values ('b2000000-0000-4000-8000-000000000001'),('b2000000-0000-4000-8000-000000000002');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('b2100000-0000-4000-8000-000000000001','adult','Bia','Autora','Bia Autora','active'),
  ('b2100000-0000-4000-8000-000000000002','adult','Lia','Leitora','Lia Leitora','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
  ('b2100000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001','active'),
  ('b2100000-0000-4000-8000-000000000002','b2000000-0000-4000-8000-000000000002','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('b2200000-0000-4000-8000-000000000001','Draft Tenant A','Draft Tenant A','draft-tenant-a','active'),
  ('b2200000-0000-4000-8000-000000000002','Draft Tenant B','Draft Tenant B','draft-tenant-b','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
  ('b2300000-0000-4000-8000-000000000001','b2100000-0000-4000-8000-000000000001','b2200000-0000-4000-8000-000000000001','teacher','active','institution'),
  ('b2300000-0000-4000-8000-000000000002','b2100000-0000-4000-8000-000000000002','b2200000-0000-4000-8000-000000000001','teacher','active','institution');
insert into public.institution_member_permission_overrides(membership_id,permission_code,effect,scope_kind,reason,status,changed_by_person_id) values
  ('b2300000-0000-4000-8000-000000000001','happens.posts.create','allow','institution','fixture','active','b2100000-0000-4000-8000-000000000001'),
  ('b2300000-0000-4000-8000-000000000002','happens.posts.create','allow','institution','fixture','active','b2100000-0000-4000-8000-000000000002');
insert into public.posts(id,institution_id,author_person_id,author_membership_id,caption,status) values
  ('b2400000-0000-4000-8000-000000000001','b2200000-0000-4000-8000-000000000001',
   'b2100000-0000-4000-8000-000000000001','b2300000-0000-4000-8000-000000000001','rascunho','draft');

create function pg_temp.as_user(p_sub text, p_sql text) returns jsonb language plpgsql as $fn$
declare result jsonb;
begin
  perform set_config('request.jwt.claim.sub',p_sub,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',p_sub,'role','authenticated')::text,true);
  set local role authenticated;
  execute p_sql into result;
  reset role;
  return result;
end $fn$;
create function pg_temp.try_user(p_sub text, p_sql text) returns text language plpgsql as $fn$
begin
  perform pg_temp.as_user(p_sub,p_sql);
  return 'ok';
exception when others then
  reset role;
  return sqlstate;
end $fn$;
create function pg_temp.asset() returns uuid language sql stable as $$
  select id from public.media_assets where post_id='b2400000-0000-4000-8000-000000000001' and upload_request_id='req-draft-1'
$$;

-- A autora prepara e finaliza (R2, checksum medido pelo gateway) → ativo pronto.
select pg_temp.as_user('b2000000-0000-4000-8000-000000000001',
  $$select public.prepare_happens_media_upload('req-draft-1','b2200000-0000-4000-8000-000000000001','b2400000-0000-4000-8000-000000000001','foto.png','image/png',1024)$$);
select is(pg_temp.try_user('b2000000-0000-4000-8000-000000000001',
  format($$select public.authorize_happens_draft_media_read('b2200000-0000-4000-8000-000000000001',%L)$$,pg_temp.asset())),
  '42501','draft asset not ready yet: refused');
select pg_temp.as_user('b2000000-0000-4000-8000-000000000001',
  format($$select public.finalize_happens_media_upload(%L,'b2400000-0000-4000-8000-000000000001',repeat('a',64),0)$$,pg_temp.asset()));
select is((select status::text from public.media_assets where id=pg_temp.asset()),'ready','fixture asset is ready');
select is(pg_temp.as_user('b2000000-0000-4000-8000-000000000001',
  format($$select public.authorize_happens_draft_media_read('b2200000-0000-4000-8000-000000000001',%L)$$,pg_temp.asset()))->>'mime_type',
  'image/png','author reads the descriptor of her own draft media');
select is(pg_temp.try_user('b2000000-0000-4000-8000-000000000002',
  format($$select public.authorize_happens_draft_media_read('b2200000-0000-4000-8000-000000000001',%L)$$,pg_temp.asset())),
  '42501','another staff member of the tenant (not the owner) is refused');
select is(pg_temp.try_user('b2000000-0000-4000-8000-000000000001',
  format($$select public.authorize_happens_draft_media_read('b2200000-0000-4000-8000-000000000002',%L)$$,pg_temp.asset())),
  '42501','wrong tenant is refused');

select * from finish();
rollback;
