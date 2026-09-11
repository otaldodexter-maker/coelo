-- pgTAP do candidato 20260911190100_agenda_requests_labels_v1: superadmin_agenda_requests
-- devolve title, institution_name, requested_by_name e decided_by_name; guarda e negativas
-- preservadas. Fixture reaproveitada de agenda_internal_realm_compat_v1_test.
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

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
select pg_temp.capture('saved', $q$select public.superadmin_agenda_save(
 '9b100000-0000-4000-8000-000000000901',null,null,jsonb_build_object('institutionId','9b100000-0000-4000-8000-000000000010','contextKind','institution',
  'contextId','9b100000-0000-4000-8000-000000000010','title','Feira de ciências','type','event',
  'startsAt',(now()+interval '1 day')::text,'endsAt',(now()+interval '1 day 2 hours')::text,'status','draft'),null,false)$q$);
select pg_temp.capture('requested', format($q$select public.superadmin_agenda_command(
 '9b100000-0000-4000-8000-000000000902',%L,%s,'request_publication',null)$q$,
  (select body->>'id' from agenda_results where label='saved'),
  (select body->>'revision' from agenda_results where label='saved')));
select ok((select body->>'request_id' is not null from agenda_results where label='requested'),
  'request_publication cria o pedido');
select pg_temp.capture('requests', $q$select public.superadmin_agenda_requests('publication',null,50,0)$q$);
select is((select r->>'title' from agenda_results, jsonb_array_elements(body) r where label='requests'
  and r->>'id'=(select body->>'request_id' from agenda_results where label='requested')),'Feira de ciências',
  'pedido traz o titulo do evento');
select is((select r->>'institution_name' from agenda_results, jsonb_array_elements(body) r where label='requests'
  and r->>'id'=(select body->>'request_id' from agenda_results where label='requested')),'Colégio Ipê',
  'pedido traz o nome da instituicao');
select ok((select coalesce(r->>'requested_by_name','')<>'' from agenda_results, jsonb_array_elements(body) r where label='requests'
  and r->>'id'=(select body->>'request_id' from agenda_results where label='requested')),
  'pedido traz o nome de quem pediu (pessoa de servico da ponte)');
select pg_temp.capture('decided', format($q$select public.superadmin_agenda_decide_publication(
 '9b100000-0000-4000-8000-000000000903',%L,true,'Aprovado no pgTAP')$q$,
  (select body->>'request_id' from agenda_results where label='requested')));
select pg_temp.capture('requests_after', $q$select public.superadmin_agenda_requests('publication','approved',50,0)$q$);
select ok((select coalesce(r->>'decided_by_name','')<>'' from agenda_results, jsonb_array_elements(body) r where label='requests_after'
  and r->>'id'=(select body->>'request_id' from agenda_results where label='requested')),
  'pedido decidido traz o nome de quem decidiu');
select throws_ok($$select public.superadmin_agenda_requests('other',null,50,0)$$,'22023',null,'tipo de pedido invalido continua recusado');
-- anon
select set_config('request.jwt.claims','{"role":"anon"}',true);
select throws_ok($$select public.superadmin_agenda_requests('publication',null,50,0)$$,'28000',null,'anon nao le pedidos');

select * from finish();
rollback;
