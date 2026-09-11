begin;
select plan(9);

-- Sem auth user, a semente e inerte por e-mail.
select is((app_private.seed_qa_r06_group_user('qa-r06-nao-existe@coelo.me', 'x'))->>'skipped',
  'auth user ausente', 'sem auth user a semente pula o e-mail');

-- Auth user sintetico so dentro desta transacao de teste (rollback ao fim);
-- em producao o usuario nasce pela API de administracao do Auth.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-0000000000a6', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'qa-r06-teste@coelo.me', 'x', now(), now(), now());
insert into public.platform_roles (code, name)
select 'owner', 'Owner' where not exists (select 1 from public.platform_roles where code = 'owner');
insert into public.institutions (id, public_name, slug)
select '00000000-0000-4000-8000-0000000000b6', 'QA R04 Escola (teste)', 'qa-r04-escola'
where not exists (select 1 from public.institutions where slug = 'qa-r04-escola');

select lives_ok($$ select app_private.seed_qa_r06_group_user('qa-r06-teste@coelo.me', 'teste') $$,
  'primeira execucao cria identidade, vinculo, membership, perfil e ponte');

select is((select count(*)::int from app_private.superadmin_internal_auth_links l
  where l.auth_user_id = '00000000-0000-4000-8000-0000000000a6' and l.status = 'active'), 1, 'vinculo auth ativo');
select is((select count(*)::int from app_private.superadmin_internal_memberships m
  join app_private.superadmin_internal_auth_links l on l.internal_identity_id = m.internal_identity_id
  where l.auth_user_id = '00000000-0000-4000-8000-0000000000a6' and m.status = 'active' and m.scope_kind = 'platform'), 1,
  'membership owner de plataforma ativa');
select is((select count(*)::int from app_private.superadmin_internal_profiles p
  join app_private.superadmin_internal_auth_links l on l.internal_identity_id = p.internal_identity_id
  where l.auth_user_id = '00000000-0000-4000-8000-0000000000a6'), 1, 'perfil interno criado');
select is((select count(*)::int from app_private.superadmin_internal_actor_people a
  join app_private.superadmin_internal_auth_links l on l.internal_identity_id = a.internal_identity_id
  where l.auth_user_id = '00000000-0000-4000-8000-0000000000a6'), 1, 'pessoa de servico (ponte de ator) criada');
select is((select count(*)::int from public.institution_memberships im
  join app_private.superadmin_internal_actor_people a on a.person_id = im.person_id
  join app_private.superadmin_internal_auth_links l on l.internal_identity_id = a.internal_identity_id
  where l.auth_user_id = '00000000-0000-4000-8000-0000000000a6' and im.role_code = 'owner' and im.status = 'active'), 1,
  'membership owner na instituicao sintetica qa-r04-escola');

select lives_ok($$ select app_private.seed_qa_r06_group_user('qa-r06-teste@coelo.me', 'teste') $$, 'segunda execucao nao falha');
select is((select count(*)::int from app_private.superadmin_internal_memberships m
  join app_private.superadmin_internal_auth_links l on l.internal_identity_id = m.internal_identity_id
  where l.auth_user_id = '00000000-0000-4000-8000-0000000000a6'), 1, 'segunda execucao nao duplica membership');

select * from finish();
rollback;
