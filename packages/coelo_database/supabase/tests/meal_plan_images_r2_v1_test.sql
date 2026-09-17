-- Somente replay LOCAL descartavel. Fixtures sinteticas com rollback. Nenhuma conta real.
-- Prova da migration 20260917180000_meal_plan_images_r2_v1 (R15 Bloco C2, owner.r12-38, spec 063):
-- prepare v2 em R2 com chave canonica, bilhete + finalize por service_role, substituicao com
-- fila de limpeza por provedor, descritor sem URL, escopo cross-tenant, v1 legada intacta.
begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

select ok((select count(*)=1 from pg_attribute where attrelid='public.meal_plan_image_assets'::regclass
  and attname='storage_provider' and not attisdropped),'meal_plan_image_assets tem storage_provider');
select ok(has_function_privilege('authenticated','public.meal_plan_prepare_image_upload_v2(text,uuid,text,text,bigint,text,uuid)','execute')
  and not has_function_privilege('anon','public.meal_plan_prepare_image_upload_v2(text,uuid,text,text,bigint,text,uuid)','execute'),
  'prepare v2: authenticated sim, anon nao');
select ok(not has_function_privilege('authenticated','public.meal_plan_finalize_image_upload_v2(uuid,uuid,bigint,text,text,text,uuid)','execute')
  and has_function_privilege('service_role','public.meal_plan_finalize_image_upload_v2(uuid,uuid,bigint,text,text,text,uuid)','execute'),
  'finalize v2 e exclusivo do service_role');
select ok(to_regprocedure('public.meal_plan_prepare_image_upload(text,uuid,text,text,bigint,text,uuid)') is not null
  and to_regprocedure('public.meal_plan_finalize_image_upload(uuid,text,text,uuid)') is not null,
  'RPCs v1 (legado Supabase Storage) permanecem');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='app_private.meal_plan_image_finalize_tickets'::regclass),
  'bilhetes de finalize com RLS forcada');

-- Fixtures (forma do teste meal_plan_image_delete_requires_revision).
insert into public.platform_role_permissions(role_id,permission_id,effect)
select r.id,p.id,'allow' from public.platform_roles r, public.platform_permissions p
where r.code='owner' and p.code in ('meal_plans.read','meal_plans.manage') on conflict do nothing;
insert into auth.users(id,aud,role,email,created_at,updated_at) values
('9c000000-0000-4000-8000-000000000001','authenticated','authenticated','meal-r2-a@test.invalid',now(),now()),
('9c000000-0000-4000-8000-000000000002','authenticated','authenticated','meal-r2-b@test.invalid',now(),now());
insert into public.people(id,person_type,first_name,last_name,display_name)
values ('c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema') on conflict do nothing;
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
('9c100000-0000-4000-8000-000000000001','adult','Meal','R2 A','Meal R2 A','active'),
('9c100000-0000-4000-8000-000000000002','adult','Meal','R2 B','Meal R2 B','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
('9c100000-0000-4000-8000-000000000001','9c000000-0000-4000-8000-000000000001','active'),
('9c100000-0000-4000-8000-000000000002','9c000000-0000-4000-8000-000000000002','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
('9c200000-0000-4000-8000-000000000001','Meal R2 A','Meal R2 A','meal-r2-a','active'),
('9c200000-0000-4000-8000-000000000002','Meal R2 B','Meal R2 B','meal-r2-b','active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,scope_institution_id,mfa_required)
select '9c100000-0000-4000-8000-000000000001',id,'active','platform',null,false from public.platform_roles where code='owner';
insert into public.platform_memberships(person_id,role_id,status,scope_kind,scope_institution_id,mfa_required)
select '9c100000-0000-4000-8000-000000000002',id,'active','institution','9c200000-0000-4000-8000-000000000002',false from public.platform_roles where code='owner';
insert into public.meal_plans(id,tenant_id,institution_id,name,status,source_type,scope_level,scope_id,start_date,end_date,created_by,updated_by)
values ('9c300000-0000-4000-8000-000000000001','9c200000-0000-4000-8000-000000000001','9c200000-0000-4000-8000-000000000001',
  'Meal R2 A','draft','institution','institution','9c200000-0000-4000-8000-000000000001',current_date,current_date,
  '9c100000-0000-4000-8000-000000000001','9c100000-0000-4000-8000-000000000001');
-- Ativo legado (Supabase Storage) continua valido.
insert into public.meal_plan_image_assets(id,tenant_id,institution_id,resource_kind,meal_plan_id,storage_path,mime_type,size_bytes,checksum_sha256,status,created_by,activated_at)
values ('9c400000-0000-4000-8000-000000000001','9c200000-0000-4000-8000-000000000001','9c200000-0000-4000-8000-000000000001','meal_plan',
  '9c300000-0000-4000-8000-000000000001','meal-plans/9c300000-0000-4000-8000-000000000001/9c400000-0000-4000-8000-000000000001.jpg',
  'image/jpeg',100,repeat('b',64),'active','9c100000-0000-4000-8000-000000000001',now());
select is((select storage_provider from public.meal_plan_image_assets where id='9c400000-0000-4000-8000-000000000001'),'supabase_mvp',
  'ativo legado nasce como supabase_mvp');

-- Ator A (plataforma): prepare v2.
select set_config('request.jwt.claims',jsonb_build_object('sub','9c000000-0000-4000-8000-000000000001','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select set_config('test.r2_prep',public.meal_plan_prepare_image_upload_v2('meal_plan','9c300000-0000-4000-8000-000000000001',
  'capa.png','image/png',8,null,'9c500000-0000-4000-8000-000000000001')::text,true);
select is(current_setting('test.r2_prep')::jsonb->>'storage_provider','r2','prepare v2 devolve provedor r2');
select is(current_setting('test.r2_prep')::jsonb->>'bucket_id','coelo-media-prod','prepare v2 usa coelo-media-prod');
select ok(current_setting('test.r2_prep')::jsonb->>'object_key' ~ ('^tenants/9c200000-0000-4000-8000-000000000001/meal_plans/meal_plan/9c300000-0000-4000-8000-000000000001/image/'
  ||(current_setting('test.r2_prep')::jsonb->>'asset_id')||'/original/[0-9a-f-]{36}[.]png$'),'chave opaca canonica da ADR 0032');
select ok(current_setting('test.r2_prep') !~ 'http','descritor de prepare nao contem URL');
select is(current_setting('test.r2_prep'),public.meal_plan_prepare_image_upload_v2('meal_plan','9c300000-0000-4000-8000-000000000001',
  'capa.png','image/png',8,null,'9c500000-0000-4000-8000-000000000001')::text,'prepare v2 e idempotente pela chave');
select set_config('test.r2_asset',current_setting('test.r2_prep')::jsonb->>'asset_id',true);
select set_config('test.r2_ticket',(public.meal_plan_authorize_image_finalize_v2('9c500000-0000-4000-8000-000000000001'))->>'finalize_ticket',true);
select throws_ok($$select public.meal_plan_finalize_image_upload_v2('9c500000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000000',8,'image/png',repeat('a',64))$$,
  '42501',null,'authenticated nao finaliza v2');
reset role;
select is((select status||'/'||storage_provider from public.meal_plan_image_assets where id=current_setting('test.r2_asset')::uuid),'pending/r2',
  'ativo R2 nasce pending');

-- Ator B (escopado em outra instituicao): prepare e bilhete negados.
select set_config('request.jwt.claims',jsonb_build_object('sub','9c000000-0000-4000-8000-000000000002','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select throws_ok($$select public.meal_plan_prepare_image_upload_v2('meal_plan','9c300000-0000-4000-8000-000000000001','capa.png','image/png',8,null,'9c500000-0000-4000-8000-000000000002')$$,
  '42501',null,'prepare v2 cross-tenant e negado');
select throws_ok($$select public.meal_plan_authorize_image_finalize_v2('9c500000-0000-4000-8000-000000000001')$$,
  'P0002',null,'bilhete de finalize so para o dono da intencao');
select throws_ok($$select public.meal_plan_image_read_descriptor_v2('9c400000-0000-4000-8000-000000000001')$$,
  '42501',null,'descritor de leitura cross-tenant e negado');
reset role;

-- service_role: finalize com bytes errados falha; com bilhete valido ativa e substitui o legado.
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
select throws_ok(format($$select public.meal_plan_finalize_image_upload_v2('9c500000-0000-4000-8000-000000000001','%s',9,'image/png',repeat('a',64))$$,
  current_setting('test.r2_ticket')),'22023','uploaded object metadata mismatch','bytes diferentes do declarado sao recusados');
select set_config('test.r2_fin',public.meal_plan_finalize_image_upload_v2('9c500000-0000-4000-8000-000000000001',
  current_setting('test.r2_ticket')::uuid,8,'image/png',repeat('a',64),'Capa','9c400000-0000-4000-8000-000000000001')::text,true);
select is(current_setting('test.r2_fin')::jsonb->>'status','active','finalize v2 ativa o ativo R2');
select is(current_setting('test.r2_fin')::jsonb->>'cleanup_asset_id','9c400000-0000-4000-8000-000000000001','substituicao enfileira o ativo anterior');
select is((select status from public.meal_plan_image_assets where id='9c400000-0000-4000-8000-000000000001'),'pending_delete','ativo substituido vai a pending_delete');
select is(current_setting('test.r2_fin'),public.meal_plan_finalize_image_upload_v2('9c500000-0000-4000-8000-000000000001',
  current_setting('test.r2_ticket')::uuid,8,'image/png',repeat('a',64),'Capa','9c400000-0000-4000-8000-000000000001')::text,
  'finalize v2 e idempotente pela intencao (mesmo payload)');
select set_config('test.r2_claim',public.meal_plan_claim_image_cleanup(10)::text,true);
select is(current_setting('test.r2_claim')::jsonb->0->>'storage_provider','supabase_mvp','claim de limpeza informa o provedor');
select is(current_setting('test.r2_claim')::jsonb->0->>'bucket','coelo-meal-plans-private','claim de limpeza informa o bucket real');
reset role;

-- Ator A le o descritor do ativo R2 e pede a exclusao (fila, nao delecao imediata).
select set_config('request.jwt.claims',jsonb_build_object('sub','9c000000-0000-4000-8000-000000000001','role','authenticated','aal','aal1')::text,true);
set local role authenticated;
select set_config('test.r2_read',public.meal_plan_image_read_descriptor_v2(current_setting('test.r2_asset')::uuid)::text,true);
select is(current_setting('test.r2_read')::jsonb->>'storage_provider','r2','descritor de leitura v2 informa r2');
select ok(current_setting('test.r2_read') !~ 'http' and current_setting('test.r2_read')::jsonb->>'expires_in_seconds'='300',
  'descritor de leitura sem URL e com janela de 300 s');
select is((public.meal_plan_request_image_delete(current_setting('test.r2_asset')::uuid,'9c500000-0000-4000-8000-000000000009',1))->>'confirmed','false',
  'exclusao de ativo R2 vai para a fila (nao confirma sem o worker)');
reset role;

select * from finish();
rollback;
