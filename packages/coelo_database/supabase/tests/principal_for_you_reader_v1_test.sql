-- B9 principal.for-you: list_my_principal_for_you — ator por auth.uid(), vinculo proprio,
-- tipo/status/destino/vigencia/audiencia no servidor; cross-tenant; exclusao vence; grants.
begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

-- fixture: instituicoes A e B, pessoa P (auth U) com vinculo staff em A (unidade UA), pessoa Q em B
insert into public.institution_types(id,code,name,status) values
 ('9f160000-0000-4000-8000-000000000001','qa-r15-fy','QA R15 fy','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9f160000-0000-4000-8000-000000000010','QA R15 FY A','qa-r15-fy-a','active','9f160000-0000-4000-8000-000000000001'),
 ('9f160000-0000-4000-8000-000000000020','QA R15 FY B','qa-r15-fy-b','active','9f160000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,unit_type_id,name,slug,status,handle) values
 ('9f160000-0000-4000-8000-000000000011','9f160000-0000-4000-8000-000000000010',(select id from public.unit_types where code='sede' limit 1),'Unidade A','unidade-a','active','unidadea.qar15fya');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9f160000-0000-4000-8000-000000000061','adult','QA R15','Pessoa A','QA R15 Pessoa A','active'),
 ('9f160000-0000-4000-8000-000000000062','adult','QA R15','Pessoa B','QA R15 Pessoa B','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9f160000-0000-4000-8000-000000000101','authenticated','authenticated','fy-a@invalid.test',now(),now(),now(),'{}','{}'),
 ('9f160000-0000-4000-8000-000000000102','authenticated','authenticated','fy-b@invalid.test',now(),now(),now(),'{}','{}'),
 ('9f160000-0000-4000-8000-000000000103','authenticated','authenticated','fy-none@invalid.test',now(),now(),now(),'{}','{}');
insert into public.person_auth_links(auth_user_id,person_id,status) values
 ('9f160000-0000-4000-8000-000000000101','9f160000-0000-4000-8000-000000000061','active'),
 ('9f160000-0000-4000-8000-000000000102','9f160000-0000-4000-8000-000000000062','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,scope_kind,scope_unit_id) values
 ('9f160000-0000-4000-8000-000000000071','9f160000-0000-4000-8000-000000000061','9f160000-0000-4000-8000-000000000010','staff','unit','9f160000-0000-4000-8000-000000000011'),
 ('9f160000-0000-4000-8000-000000000072','9f160000-0000-4000-8000-000000000062','9f160000-0000-4000-8000-000000000020','guardian','institution',null);

create or replace function pg_temp.notice(p_id uuid, p_type text, p_title text, p_audience jsonb,
  p_status text default 'active', p_device text default 'all', p_starts timestamptz default now() - interval '1 hour',
  p_ends timestamptz default null, p_priority text default 'routine') returns void language sql as $$
  insert into public.platform_notices(id,notice_type,status,title,body_text,starts_at,ends_at,priority_code,audience_json,target_device,published_at)
  values (p_id,p_type::public.notice_type,p_status::public.notice_status,p_title,'corpo '||p_title,p_starts,p_ends,p_priority,p_audience,p_device,now());
$$;
select pg_temp.notice('9f160000-0000-4000-8000-000000000201','for_you','plataforma',
  '{"rules":[{"dimension":"platform","select_all":true}]}');
select pg_temp.notice('9f160000-0000-4000-8000-000000000202','highlight','instituicao A',
  '{"rules":[{"dimension":"institution","select_all":false,"target_ids":["9f160000-0000-4000-8000-000000000010"]}]}', 'active','all', now()-interval '1 hour', null, 'urgent');
select pg_temp.notice('9f160000-0000-4000-8000-000000000203','content_card','instituicao B',
  '{"rules":[{"dimension":"institution","select_all":false,"target_ids":["9f160000-0000-4000-8000-000000000020"]}]}');
select pg_temp.notice('9f160000-0000-4000-8000-000000000204','for_you','unidade A',
  '{"rules":[{"dimension":"unit","select_all":false,"target_ids":["9f160000-0000-4000-8000-000000000011"]}]}');
select pg_temp.notice('9f160000-0000-4000-8000-000000000205','for_you','excluida para A',
  '{"rules":[{"dimension":"platform","select_all":true,"excluded_ids":["9f160000-0000-4000-8000-000000000010"]}]}');
select pg_temp.notice('9f160000-0000-4000-8000-000000000206','popup','popup nunca sai',
  '{"rules":[{"dimension":"platform","select_all":true}]}');
select pg_temp.notice('9f160000-0000-4000-8000-000000000207','for_you','so mobile',
  '{"rules":[{"dimension":"platform","select_all":true}]}', 'active', 'mobile');
select pg_temp.notice('9f160000-0000-4000-8000-000000000208','for_you','rascunho',
  '{"rules":[{"dimension":"platform","select_all":true}]}', 'draft');
select pg_temp.notice('9f160000-0000-4000-8000-000000000209','for_you','vencida',
  '{"rules":[{"dimension":"platform","select_all":true}]}', 'active', 'all', now()-interval '2 days', now()-interval '1 day');
select pg_temp.notice('9f160000-0000-4000-8000-000000000210','for_you','so guardian',
  '{"rules":[{"dimension":"platform","select_all":true}],"role_codes":["guardian"]}');
select pg_temp.notice('9f160000-0000-4000-8000-000000000211','for_you','futura',
  '{"rules":[{"dimension":"platform","select_all":true}]}', 'active', 'all', now()+interval '1 day');

create temporary table fy(label text primary key, body jsonb not null);
grant select,insert on fy to authenticated;
create or replace function pg_temp.titles(p jsonb) returns text[] language sql immutable as $$
  select coalesce(array_agg(i->>'title' order by i->>'title'), '{}') from jsonb_array_elements(p#>'{data,items}') i $$;
grant execute on function pg_temp.titles(jsonb) to authenticated;

-- 1. grants
select ok(has_function_privilege('authenticated','public.list_my_principal_for_you(text,uuid,integer)','execute')
  and not has_function_privilege('anon','public.list_my_principal_for_you(text,uuid,integer)','execute')
  and not has_function_privilege('service_role','public.list_my_principal_for_you(text,uuid,integer)','execute'),
  'authenticated executa; anon e service_role nao');
select throws_like($$select public.list_my_principal_for_you('web')$$, '%authentication_required%', 'sem sessao e recusado');

-- 2. ator A (staff, unidade A)
select set_config('request.jwt.claims',jsonb_build_object('sub','9f160000-0000-4000-8000-000000000101','role','authenticated')::text,true);
set local role authenticated;
insert into fy values('a_web',public.list_my_principal_for_you('web'));
insert into fy values('a_mobile',public.list_my_principal_for_you('mobile'));
insert into fy values('a_ctx',public.list_my_principal_for_you('web','9f160000-0000-4000-8000-000000000071'));
insert into fy values('a_ctx_alheio',public.list_my_principal_for_you('web','9f160000-0000-4000-8000-000000000072'));
insert into fy values('a_ctx_inexistente',public.list_my_principal_for_you('web','9f160000-0000-4000-8000-0000000000ff'));
insert into fy values('a_limit',public.list_my_principal_for_you('web',null,1));
reset role;
select is((select body->>'ok' from fy where label='a_web'),'true','envelope ok');
select is((select pg_temp.titles(body) from fy where label='a_web'),array['instituicao A','plataforma','unidade A'],
  'web: ve plataforma, instituicao A e unidade A; nao ve B, excluida, popup, so mobile, rascunho, vencida, so guardian, futura');
select is((select body#>>'{data,items,0,title}' from fy where label='a_web'),'instituicao A','urgente vem primeiro');
select is((select pg_temp.titles(body) from fy where label='a_mobile'),array['instituicao A','plataforma','so mobile','unidade A'],
  'mobile: ganha o aviso so mobile');
select is((select pg_temp.titles(body) from fy where label='a_ctx'),array['instituicao A','plataforma','unidade A'],'vinculo proprio explicito: mesma lista');
select is((select jsonb_array_length(body#>'{data,items}') from fy where label='a_ctx_alheio'),0,'vinculo de outra pessoa: lista vazia (nao enumeravel)');
select is((select jsonb_array_length(body#>'{data,items}') from fy where label='a_ctx_inexistente'),0,'vinculo inexistente: lista vazia');
select is((select jsonb_array_length(body#>'{data,items}') from fy where label='a_limit'),1,'p_limit respeitado');
select ok((select bool_and(i ? 'audience' and i ? 'type' and i ? 'body' and i ? 'status' and not (i ? 'popup_size' and false))
  from fy, jsonb_array_elements(body#>'{data,items}') i where label='a_web'),'itens no envelope do diretorio (superadmin_notice_json)');
select ok((select bool_and(i->>'type' in ('highlight','content_card','for_you')) from fy, jsonb_array_elements(body#>'{data,items}') i where label in ('a_web','a_mobile')),
  'nenhum popup/notice/critical_notice sai');

-- 3. entradas invalidas
set local role authenticated;
select throws_like($$select public.list_my_principal_for_you('desktop')$$, '%invalid_for_you_target_device%', 'destino fora da allowlist e recusado');
select throws_like($$select public.list_my_principal_for_you(null)$$, '%invalid_for_you_target_device%', 'destino nulo e recusado');
select throws_like($$select public.list_my_principal_for_you('web',null,0)$$, '%invalid_for_you_query%', 'limite 0 e recusado');
select throws_like($$select public.list_my_principal_for_you('web',null,101)$$, '%invalid_for_you_query%', 'limite 101 e recusado');
reset role;

-- 4. ator B (guardian, instituicao B): cross-tenant
select set_config('request.jwt.claims',jsonb_build_object('sub','9f160000-0000-4000-8000-000000000102','role','authenticated')::text,true);
set local role authenticated;
insert into fy values('b_web',public.list_my_principal_for_you('web'));
insert into fy values('b_ctx_a',public.list_my_principal_for_you('web','9f160000-0000-4000-8000-000000000071'));
reset role;
select is((select pg_temp.titles(body) from fy where label='b_web'),array['excluida para A','instituicao B','plataforma','so guardian'],
  'B: ve plataforma, instituicao B, a excluida so para A e a de guardian; nao ve A nem unidade A');
select is((select jsonb_array_length(body#>'{data,items}') from fy where label='b_ctx_a'),0,'B pedindo o vinculo de A: vazio');

-- 5. usuario sem pessoa vinculada
select set_config('request.jwt.claims',jsonb_build_object('sub','9f160000-0000-4000-8000-000000000103','role','authenticated')::text,true);
set local role authenticated;
select throws_like($$select public.list_my_principal_for_you('web')$$, '%principal_context_denied%', 'auth sem pessoa: negado');
reset role;

-- 6. exclusao defensiva por notice_rules
insert into public.notice_rules(notice_id,effect,target_type,target_id) values
 ('9f160000-0000-4000-8000-000000000201','exclude','institution','9f160000-0000-4000-8000-000000000010');
select set_config('request.jwt.claims',jsonb_build_object('sub','9f160000-0000-4000-8000-000000000101','role','authenticated')::text,true);
set local role authenticated;
insert into fy values('a_rules',public.list_my_principal_for_you('web'));
reset role;
select is((select pg_temp.titles(body) from fy where label='a_rules'),array['instituicao A','unidade A'],'notice_rules exclude retira a plataforma para A');
select ok(true,'reservado');

select * from finish();
rollback;
