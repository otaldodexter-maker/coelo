-- Prova do candidato 20260911170300_institution_profile_system_model_create_v1 (P31).
-- Projeto descartavel LOCAL: fixtures sinteticas em transacao com rollback.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
values ('a0600000-0000-4000-8000-000000000001','authenticated','authenticated','r05-profile-actor@invalid.test',now(),now(),now(),'{}','{}');
insert into public.people(id,person_type,first_name,last_name,display_name)
values ('a0600000-0000-4000-8000-000000000011','adult','Ator','R05','Ator R05');
insert into public.person_auth_links(person_id,auth_user_id)
values ('a0600000-0000-4000-8000-000000000011','a0600000-0000-4000-8000-000000000001');
-- Ator de plataforma com gestao de perfis e todas as permissoes institucionais delegaveis.
insert into public.platform_roles(id,code,name,max_scope_kind)
values ('a0600000-0000-4000-8000-000000000021','qa_r05_profile_actor','QA R05 ator','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect)
select 'a0600000-0000-4000-8000-000000000021',id,'allow' from public.platform_permissions where status='active';
insert into public.platform_memberships(person_id,role_id,status,scope_kind)
values ('a0600000-0000-4000-8000-000000000011','a0600000-0000-4000-8000-000000000021','active','platform');
insert into public.institutions(id,public_name,slug,status)
values ('a0600000-0000-4000-8000-000000000031','Escola QA R05','escola-qa-r05-perfis','active');

select set_config('request.jwt.claims',
  jsonb_build_object('sub','a0600000-0000-4000-8000-000000000001','role','authenticated','aal','aal1')::text, true);

create temporary table r05_profiles(key text primary key, result jsonb not null);

-- 1-3. sem institution_id: nasce modelo do sistema (antes: 23514 institution_roles_global_system_check)
insert into r05_profiles values ('global', public.superadmin_access_profile_save(gen_random_uuid(), 0, 'prova R05',
  jsonb_build_object('domain','institution','name','Professor QA R05','description','a partir do modelo','status','active',
    'max_scope_kind','unit','capabilities',jsonb_build_array(jsonb_build_object('code','activities.read','effect','allow')))));
select is((select (result->'profile'->>'is_system')::boolean from r05_profiles where key='global'), true,
  'perfil Admin criado pela plataforma sem instituicao e modelo do sistema');
select is((select institution_id from public.institution_roles where id=(select (result->>'profile_id')::uuid from r05_profiles where key='global')), null,
  'modelo do sistema nao pertence a instituicao');
select is((select count(*) from public.institution_role_permissions where role_id=(select (result->>'profile_id')::uuid from r05_profiles where key='global') and status='active'), 1::bigint,
  'concessao selecionada persistiu');

-- 4-5. com institution_id: perfil proprio da instituicao; instituicao inexistente e recusada
insert into r05_profiles values ('own', public.superadmin_access_profile_save(gen_random_uuid(), 0, 'prova R05',
  jsonb_build_object('domain','institution','institution_id','a0600000-0000-4000-8000-000000000031','name','Secretaria QA R05','description','proprio','status','active',
    'max_scope_kind','institution','capabilities','[]'::jsonb)));
select is((select institution_id::text||'|'||is_system::text from public.institution_roles where id=(select (result->>'profile_id')::uuid from r05_profiles where key='own')),
  'a0600000-0000-4000-8000-000000000031|false', 'perfil com institution_id e proprio da instituicao (nao e sistema)');
select throws_ok($$select public.superadmin_access_profile_save(gen_random_uuid(), 0, 'x',
  jsonb_build_object('domain','institution','institution_id','a0600000-0000-4000-8000-0000000000ff','name','Fantasma','description','d','status','active','max_scope_kind','institution','capabilities','[]'::jsonb))$$,
  '22023', 'invalid institution for profile', 'institution_id inexistente e recusado');

-- 6-7. modelo do sistema de Admin e editavel pela plataforma; modelo de plataforma continua protegido
insert into r05_profiles values ('edit', public.superadmin_access_profile_save(gen_random_uuid(), 1, 'ajuste R05',
  jsonb_build_object('id',(select result->>'profile_id' from r05_profiles where key='global'),'domain','institution','name','Professor QA R05 v2','description','editado','status','active',
    'max_scope_kind','unit','capabilities',jsonb_build_array(jsonb_build_object('code','activities.read','effect','allow')))));
select is((select name from public.institution_roles where id=(select (result->>'profile_id')::uuid from r05_profiles where key='global')), 'Professor QA R05 v2',
  'modelo do sistema de Admin editado pela plataforma (P31)');
select throws_ok(format($$select public.superadmin_access_profile_save(gen_random_uuid(), %s, 'x',
  jsonb_build_object('id','%s','domain','platform','name','Owner x','description','d','status','active','max_scope_kind','platform','capabilities','[]'::jsonb))$$,
  (select version from public.platform_roles where code='owner'), (select id from public.platform_roles where code='owner')),
  '42501', 'system profile is protected', 'modelo de plataforma (Owner) continua protegido');

-- 8. o modelo de sistema semeado pelo lote 25 tambem e editavel pela plataforma
select lives_ok(format($$select public.superadmin_access_profile_save(gen_random_uuid(), %s, 'ajuste R05',
  jsonb_build_object('id','%s','domain','institution','name','Secretaria','description','Pessoas, familias, transferencias e circulares (R05).','status','active','max_scope_kind','institution',
    'capabilities',(select coalesce(jsonb_agg(jsonb_build_object('code',p.code,'effect','allow')),'[]'::jsonb) from public.institution_role_permissions rp join public.institution_permissions p on p.id=rp.permission_id where rp.role_id='%s' and rp.status='active')))$$,
  (select version from public.institution_roles where code='secretary' and is_system), (select id from public.institution_roles where code='secretary' and is_system), (select id from public.institution_roles where code='secretary' and is_system)),
  'modelo Secretaria (lote 25) editavel pela plataforma');

select * from finish();
rollback;
