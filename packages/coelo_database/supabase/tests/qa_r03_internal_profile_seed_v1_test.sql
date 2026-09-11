-- Prova do candidato 20260910171200_qa_r03_internal_profile_seed_v1.
-- Projeto descartavel LOCAL: cria a identidade sintetica em transacao com rollback.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select is(app_private.seed_qa_r03_internal_profile(), 0, 'sem a identidade de qa-r03 a semente e no-op');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
values('a3000000-0000-4000-8000-000000000001','authenticated','authenticated','qa-r03@coelo.me',now(),now(),now(),'{}','{}');
insert into app_private.superadmin_internal_identities(id) values('a3000000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_auth_links(internal_identity_id,auth_user_id)
values('a3000000-0000-4000-8000-000000000002','a3000000-0000-4000-8000-000000000001');

select is(app_private.seed_qa_r03_internal_profile(), 1, 'com a identidade, grava exatamente um perfil');
select is(app_private.seed_qa_r03_internal_profile(), 0, 'rodar de novo e idempotente');
select is((select display_name||' / '||job_title from app_private.superadmin_internal_profiles
  where internal_identity_id='a3000000-0000-4000-8000-000000000002'),
  'QA R04 Sintetico / Usuario sintetico de teste', 'perfil sintetico com os valores esperados');
select is((select cpf from app_private.superadmin_internal_profiles
  where internal_identity_id='a3000000-0000-4000-8000-000000000002'), '00000000000', 'CPF de teste invalido, nunca real');
select ok(not has_function_privilege('anon','app_private.seed_qa_r03_internal_profile()','execute')
  and not has_function_privilege('authenticated','app_private.seed_qa_r03_internal_profile()','execute'),
  'semente fora do alcance de anon e authenticated');

select * from finish();
rollback;
