-- pgTAP de compatibilidade da Agenda com o realm interno (candidato 20260910200300).
-- Fixture de identidades internas reaproveitada de superadmin_internal_notices_v2_baseline_test.
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users(
  id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data
) values
 ('9b100000-0000-4000-8000-000000000101','authenticated','authenticated',
  'notices-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('9b100000-0000-4000-8000-000000000102','authenticated','authenticated',
  'notices-content@invalid.test',now(),now(),now(),'{}','{}'),
 ('9b100000-0000-4000-8000-000000000103','authenticated','authenticated',
  'notices-scoped@invalid.test',now(),now(),now(),'{}','{}'),
 ('9b100000-0000-4000-8000-000000000104','authenticated','authenticated',
  'notices-people@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9b100000-0000-4000-8000-000000000201','9b100000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('9b100000-0000-4000-8000-000000000202','9b100000-0000-4000-8000-000000000102',now(),now(),'aal2',now()+interval '1 hour'),
 ('9b100000-0000-4000-8000-000000000203','9b100000-0000-4000-8000-000000000103',now(),now(),'aal2',now()+interval '1 hour'),
 ('9b100000-0000-4000-8000-000000000204','9b100000-0000-4000-8000-000000000104',now(),now(),'aal2',now()+interval '1 hour');

insert into public.institution_types(id,code,name,status) values
 ('9b100000-0000-4000-8000-000000000001','notice-v2-test','Notice v2 test','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9b100000-0000-4000-8000-000000000010','Colégio Ipê','notice-v2-ipe','active',
  '9b100000-0000-4000-8000-000000000001');

insert into app_private.superadmin_internal_identities(id) values
 ('9b100000-0000-4000-8000-000000000301'),
 ('9b100000-0000-4000-8000-000000000302'),
 ('9b100000-0000-4000-8000-000000000303');
insert into app_private.superadmin_internal_auth_links(
  id,internal_identity_id,auth_user_id
) values
 ('9b100000-0000-4000-8000-000000000401','9b100000-0000-4000-8000-000000000301','9b100000-0000-4000-8000-000000000101'),
 ('9b100000-0000-4000-8000-000000000402','9b100000-0000-4000-8000-000000000302','9b100000-0000-4000-8000-000000000102'),
 ('9b100000-0000-4000-8000-000000000403','9b100000-0000-4000-8000-000000000303','9b100000-0000-4000-8000-000000000103');
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id
)
select fixture.id,fixture.identity_id,role_record.id,
  fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 ('9b100000-0000-4000-8000-000000000501'::uuid,'9b100000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('9b100000-0000-4000-8000-000000000502'::uuid,'9b100000-0000-4000-8000-000000000302'::uuid,'content','platform',null::uuid),
 ('9b100000-0000-4000-8000-000000000503'::uuid,'9b100000-0000-4000-8000-000000000303'::uuid,'operations','institution','9b100000-0000-4000-8000-000000000010'::uuid)
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9b100000-0000-4000-8000-000000000601','adult','Pessoa','Global','Pessoa Global','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('9b100000-0000-4000-8000-000000000601','9b100000-0000-4000-8000-000000000104','active');

create temporary table agenda_results(label text primary key,body jsonb not null);
create temporary table agenda_errors(label text primary key,sqlstate text,message text);
create or replace function pg_temp.capture(p_label text, p_sql text) returns void language plpgsql as $$
declare r jsonb;
begin
  execute p_sql into r;
  insert into agenda_results values (p_label, r);
exception when others then
  insert into agenda_errors values (p_label, sqlstate, sqlerrm);
end $$;

-- Owner interno (AAL1: MFA fora do MVP)
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9b100000-0000-4000-8000-000000000101','session_id','9b100000-0000-4000-8000-000000000201',
 'aal','aal1','role','authenticated')::text,true);
select pg_temp.capture('contexts', $q$select public.superadmin_agenda_contexts()$q$);
select pg_temp.capture('saved', $q$select public.superadmin_agenda_save(
 '9b100000-0000-4000-8000-000000000801',null,null,jsonb_build_object('institutionId','9b100000-0000-4000-8000-000000000010','contextKind','institution',
  'contextId','9b100000-0000-4000-8000-000000000010','title','Reunião de pais','type','event',
  'startsAt',(now()+interval '1 day')::text,'endsAt',(now()+interval '1 day 2 hours')::text,'status','draft'),null,false)$q$);
select pg_temp.capture('saved_replay', $q$select public.superadmin_agenda_save(
 '9b100000-0000-4000-8000-000000000801',null,null,jsonb_build_object('institutionId','9b100000-0000-4000-8000-000000000010','contextKind','institution',
  'contextId','9b100000-0000-4000-8000-000000000010','title','Reunião de pais','type','event',
  'startsAt',(now()+interval '1 day')::text,'endsAt',(now()+interval '1 day 2 hours')::text,'status','draft'),null,false)$q$);
select pg_temp.capture('got', format($q$select public.superadmin_agenda_get(%L)$q$,
  (select body->>'id' from agenda_results where label='saved')));
select pg_temp.capture('listed', $q$select public.superadmin_agenda_list(now()-interval '1 day',now()+interval '7 days',null,'',100,0)$q$);
select pg_temp.capture('edited', format($q$select public.superadmin_agenda_save(
 '9b100000-0000-4000-8000-000000000802',%L,%s,jsonb_build_object('institutionId','9b100000-0000-4000-8000-000000000010','contextKind','institution',
  'contextId','9b100000-0000-4000-8000-000000000010','title','Reunião de pais (editada)','type','event',
  'startsAt',(now()+interval '1 day')::text,'endsAt',(now()+interval '1 day 2 hours')::text,'status','published'),null,false)$q$,
  (select body->>'id' from agenda_results where label='saved'),
  (select body->>'revision' from agenda_results where label='saved')));
select pg_temp.capture('cross_tenant_unit', $q$select public.superadmin_agenda_save(
 '9b100000-0000-4000-8000-000000000803',null,null,jsonb_build_object('institutionId','9b100000-0000-4000-8000-000000000010','contextKind','unit',
  'contextId','00000000-0000-4000-8000-00000000dead','title','Unidade de outro tenant','type','event',
  'startsAt',(now()+interval '1 day')::text,'endsAt',(now()+interval '1 day 2 hours')::text),null,false)$q$);

-- Content interno: le, nao cria
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9b100000-0000-4000-8000-000000000102','session_id','9b100000-0000-4000-8000-000000000202',
 'aal','aal1','role','authenticated')::text,true);
select pg_temp.capture('content_list', $q$select public.superadmin_agenda_list(now()-interval '1 day',now()+interval '7 days',null,'',100,0)$q$);
select pg_temp.capture('content_save', $q$select public.superadmin_agenda_save(
 '9b100000-0000-4000-8000-000000000804',null,null,jsonb_build_object('institutionId','9b100000-0000-4000-8000-000000000010','contextKind','institution',
  'contextId','9b100000-0000-4000-8000-000000000010','title','Sem permissão','type','event',
  'startsAt',(now()+interval '1 day')::text,'endsAt',(now()+interval '1 day 2 hours')::text),null,false)$q$);

-- Identidade interna com escopo de instituicao: sem Agenda (deny-by-default)
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9b100000-0000-4000-8000-000000000103','session_id','9b100000-0000-4000-8000-000000000203',
 'aal','aal1','role','authenticated')::text,true);
select pg_temp.capture('scoped_list', $q$select public.superadmin_agenda_list(now()-interval '1 day',now()+interval '7 days',null,'',100,0)$q$);

-- Usuario somente do realm people-based, sem membership de plataforma
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9b100000-0000-4000-8000-000000000104','session_id','9b100000-0000-4000-8000-000000000204',
 'aal','aal1','role','authenticated')::text,true);
select pg_temp.capture('people_list', $q$select public.superadmin_agenda_list(now()-interval '1 day',now()+interval '7 days',null,'',100,0)$q$);

select is((select body#>>'{capabilities,createAgendaItems}' from agenda_results where label='contexts'),'true',
  'Owner interno recebe a capacidade de criar');
select ok((select body::text like '%9b100000-0000-4000-8000-000000000010%' from agenda_results where label='contexts'),
  'contexts lista a instituicao para o membership interno de plataforma');
select is((select body->>'status' from agenda_results where label='saved'),'draft','Owner interno cria rascunho');
select is((select body from agenda_results where label='saved_replay'),(select body from agenda_results where label='saved'),
  'save e idempotente por request_id');
select is((select body->>'title' from agenda_results where label='got'),'Reunião de pais','get relê o evento');
select ok((select (body ? 'created_by_internal_identity_id') is false and (body ? 'created_by_person_id') is false from agenda_results where label='got'),
  'JSON de saida nao expoe colunas de ator');
select is((select jsonb_array_length(body->'items')::text from agenda_results where label='listed'),'1','list ve o evento');
select is((select body->>'status' from agenda_results where label='edited'),'published','Owner interno edita e publica');
select is((select body->>'revision' from agenda_results where label='edited'),'2','revisao otimista incrementa');
select is((select created_by_internal_identity_id::text from public.agenda_events where id=(select (body->>'id')::uuid from agenda_results where label='saved')),
  '9b100000-0000-4000-8000-000000000301','trigger roteou o criador para a identidade interna');
select ok((select created_by_person_id is null and updated_by_person_id is null from public.agenda_events where id=(select (body->>'id')::uuid from agenda_results where label='saved')),
  'colunas de pessoa ficam nulas para ator interno');
select is((select count(*)::text from public.agenda_history_receipts where actor_internal_identity_id='9b100000-0000-4000-8000-000000000301'),'2',
  'recibos de historico gravam o ator interno');
select is((select message from agenda_errors where label='cross_tenant_unit'),'invalid_unit_context',
  'contexto de unidade fora do tenant e recusado');
select is((select jsonb_array_length(body->'items')::text from agenda_results where label='content_list'),'1','Content interno le a Agenda');
select is((select message from agenda_errors where label='content_save'),'agenda_permission_denied','Content interno nao cria');
select is((select message from agenda_errors where label='scoped_list'),'agenda_permission_denied',
  'identidade interna escopada em instituicao nao le a Agenda de plataforma');
select is((select message from agenda_errors where label='people_list'),'agenda_permission_denied',
  'pessoa sem membership de plataforma e negada');
select ok(not exists(select 1 from agenda_results where body::text like '%@invalid.test%'),'saidas nao expoem e-mail');
select is(has_table_privilege('authenticated','public.agenda_events','select'),false,'authenticated nao le agenda_events direto');
select ok(has_function_privilege('authenticated','public.superadmin_agenda_save(uuid,uuid,bigint,jsonb,text,boolean)','execute'),
  'authenticated executa superadmin_agenda_save');
select ok(not has_function_privilege('anon','public.superadmin_agenda_save(uuid,uuid,bigint,jsonb,text,boolean)','execute'),
  'anon nao executa superadmin_agenda_save');
select ok(not has_function_privilege('authenticated','app_private.agenda_has_permission(text)','execute'),
  'helper interno sem execute para authenticated');
select * from finish();
rollback;
