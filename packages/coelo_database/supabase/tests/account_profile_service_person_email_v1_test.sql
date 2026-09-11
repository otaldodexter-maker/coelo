begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

-- Usuario interno cuja pessoa NAO tem person_auth_links (forma da ponte 220400).
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at) values
 ('86100000-0000-4000-8000-000000000001','authenticated','authenticated','servico@test.invalid',now(),now(),now());
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('86200000-0000-4000-8000-000000000001','service','Servico','Interno','Servico Interno','active');

select set_config('request.jwt.claims',jsonb_build_object('sub','86100000-0000-4000-8000-000000000001','session_id','86110000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);

-- Sem vinculo e sem ser o ator: nenhum e-mail (nao vaza o do usuario logado para outra pessoa).
select is((app_private.account_profile_projection('86200000-0000-4000-8000-000000000001')->>'email'),'','projection without link and not the actor keeps email empty');

-- Simula a ponte: a pessoa e o ator da sessao.
create or replace function app_private.current_person_id() returns uuid language sql stable as $$ select '86200000-0000-4000-8000-000000000001'::uuid $$;
select is((app_private.account_profile_projection('86200000-0000-4000-8000-000000000001')->>'email'),'servico@test.invalid','service person of the actor gets the auth email');
select is((app_private.account_profile_projection('86200000-0000-4000-8000-000000000001')->>'first_name'),'Servico','rest of the projection unchanged');

select * from finish();
rollback;
