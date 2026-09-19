-- Prova pgTAP da migration 20260919233000_staff_access_assert_v1 (erro com motivo, item 5 do F7).
-- Fixture sintetica com rollback total (prefixo fa): instituicao A com unidade A1; educadora E (teacher,
-- institution_admin p/ capacidade) com regra do vinculo que nunca bate agora e popup ligado; E tambem e
-- responsavel (guardian_links) de crianca em A. Cobre: resolvers levantam PT403/STAFF_ACCESS_DENIED com
-- detail JSON (reason + popup) em vez de 42501; now_reader_actor segue pela familia; vinculo livre em
-- outra instituicao nao dispara; sem vinculo, o assert e neutro; nunca 40001.
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

create function pg_temp.fa(n integer) returns uuid language sql immutable as $$
  select ('fa000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.fa(integer) to authenticated;
create function pg_temp.as_user(n integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', pg_temp.fa(n)::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.fa(n)::text, 'role', 'authenticated', 'aal', 'aal1')::text, true);
end $$;

-- estrutural ------------------------------------------------------------------------------------
select has_function('app_private','staff_access_assert',array['uuid','uuid','uuid','uuid'],'staff_access_assert exists');
select ok((select bool_and(p.prosrc like '%staff_access_assert(%')
  from pg_proc p where p.pronamespace='app_private'::regnamespace
  and p.proname in ('happens_actor','now_actor','now_reader_actor','circular_actor','moments_actor_for_auth_user')),
  'the 5 actor resolvers call staff_access_assert');
select ok(position('40001' in pg_get_functiondef('app_private.staff_access_assert(uuid,uuid,uuid,uuid)'::regprocedure))=0
  and position('PT403' in pg_get_functiondef('app_private.staff_access_assert(uuid,uuid,uuid,uuid)'::regprocedure))>0,'PT403, never 40001');

-- fixture ---------------------------------------------------------------------------------------
insert into public.institution_types(id,code,name,status) values (pg_temp.fa(1),'fa-type','FA type','active');
insert into public.unit_types(id,code,name,status) values (pg_temp.fa(2),'fa-unit','FA unit','active');
insert into public.people(id,person_type,first_name,last_name,display_name)
select 'c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema'
where not exists (select 1 from public.people where id='c0e10000-0000-4000-8000-000000000001');
insert into public.institutions(id,institution_type_id,public_name,slug,status,timezone) values
 (pg_temp.fa(10),pg_temp.fa(1),'FA Instituicao A','fa-a','active','America/Sao_Paulo'),
 (pg_temp.fa(20),pg_temp.fa(1),'FA Instituicao B','fa-b','active','America/Sao_Paulo');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status,timezone) values
 (pg_temp.fa(11),pg_temp.fa(10),'FA Unidade A1','fa-unidade-a1','faunidade.a1',pg_temp.fa(2),'active','America/Sao_Paulo');
insert into auth.users(id) values (pg_temp.fa(101)),(pg_temp.fa(102)),(pg_temp.fa(104));
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.fa(201),'adult','FA','Educadora E','FA Educadora E','active'),
 (pg_temp.fa(202),'adult','FA','Admin D','FA Admin D','active'),
 (pg_temp.fa(204),'adult','FA','Sem vinculo','FA Sem vinculo','active'),
 (pg_temp.fa(401),'child','FA','Crianca','FA Crianca','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 (pg_temp.fa(201),pg_temp.fa(101),'active'),(pg_temp.fa(202),pg_temp.fa(102),'active'),(pg_temp.fa(204),pg_temp.fa(104),'active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind,scope_unit_id,scope_group_id) values
 (pg_temp.fa(301),pg_temp.fa(201),pg_temp.fa(10),'teacher','active','unit',pg_temp.fa(11),null),
 (pg_temp.fa(302),pg_temp.fa(201),pg_temp.fa(20),'teacher','active','institution',null,null),
 (pg_temp.fa(304),pg_temp.fa(202),pg_temp.fa(10),'institution_admin','active','institution',null,null);
insert into public.institution_role_assignments(membership_id,role_id,scope_kind,scope_unit_id)
select pg_temp.fa(301),r.id,'unit',pg_temp.fa(11) from public.institution_roles r where r.code='institution_admin' and r.is_system;
insert into public.institution_role_assignments(membership_id,role_id,scope_kind)
select m,r.id,'institution' from (values (pg_temp.fa(302)),(pg_temp.fa(304))) v(m), public.institution_roles r where r.code='institution_admin' and r.is_system;
-- familia: E responsavel da crianca com contexto em A e can_view
insert into public.family_relationship_types(code,name) values ('mother','Mae') on conflict (code) do nothing;
insert into public.child_contexts(id,child_person_id,institution_id,status) values (pg_temp.fa(411),pg_temp.fa(401),pg_temp.fa(10),'active');
insert into public.guardian_links(id,guardian_person_id,child_person_id,relation_type,relationship_type_id,status)
select pg_temp.fa(421),pg_temp.fa(201),pg_temp.fa(401),'mother',t.id,'active' from public.family_relationship_types t where t.code='mother';
insert into public.guardian_context_permissions(guardian_link_id,child_context_id,can_view,can_message,can_react,status)
values (pg_temp.fa(421),pg_temp.fa(411),true,true,true,'active');

-- antes da regra: resolvers passam ----------------------------------------------------------------
select pg_temp.as_user(101);
select is((select membership_id from app_private.happens_actor(pg_temp.fa(10),'people.read',pg_temp.fa(11),null)),pg_temp.fa(301),'happens_actor resolves E while free');
select lives_ok($$select app_private.staff_access_assert(pg_temp.fa(10),null,null)$$,'assert is neutral while free');

-- regra do vinculo que nunca bate agora (segunda 03:00-03:01), popup ligado ------------------------
select pg_temp.as_user(102);
set local role authenticated;
select lives_ok($$select public.staff_access_rule_save_v1(pg_temp.fa(301),null,jsonb_build_object(
  'surfaces',jsonb_build_array('web'),'windows',jsonb_build_array(jsonb_build_object('weekday',1,'start','03:00','end','03:01')),'popup_enabled',true))$$,'rule saved');
reset role;

select pg_temp.as_user(101);
select throws_ok($$select app_private.staff_access_assert(pg_temp.fa(10),null,null)$$,'PT403','STAFF_ACCESS_DENIED','assert raises PT403 STAFF_ACCESS_DENIED');
select throws_ok($$select * from app_private.happens_actor(pg_temp.fa(10),'people.read',pg_temp.fa(11),null)$$,'PT403',null,'happens_actor: PT403 instead of 42501');
select throws_ok($$select * from app_private.now_actor(pg_temp.fa(10),'people.read',pg_temp.fa(11),null)$$,'PT403',null,'now_actor: PT403');
select throws_ok($$select * from app_private.circular_actor(pg_temp.fa(10),'people.read',pg_temp.fa(11),null)$$,'PT403',null,'circular_actor: PT403');
select throws_ok($$select * from app_private.moments_actor_for_auth_user(pg_temp.fa(101),pg_temp.fa(10),'people.read',pg_temp.fa(11),null)$$,'PT403',null,'moments_actor_for_auth_user: PT403');
-- detail JSON com motivo e popup
create function pg_temp.assert_detail() returns jsonb language plpgsql as $$
declare d text;
begin
  begin
    perform app_private.staff_access_assert(pg_temp.fa(10),null,null);
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    return d::jsonb;
  end;
  return null;
end $$;
select is(pg_temp.assert_detail()->>'reason','schedule','detail carries the reason');
select is(pg_temp.assert_detail()->'popup'->>'kind','schedule','detail carries the popup (enabled)');
select is(pg_temp.assert_detail()->>'membership_id',pg_temp.fa(301)::text,'detail names the blocked vinculo');
-- familia continua: now_reader_actor resolve E como responsavel (membership nula)
select is((select membership_id from app_private.now_reader_actor(pg_temp.fa(10),'now.publications.read',null,null)),null,'now_reader_actor still resolves the family path (membership null)');
-- vinculo livre em B nao e afetado
select is((select membership_id from app_private.happens_actor(pg_temp.fa(20),'people.read',null,null)),pg_temp.fa(302),'happens_actor in B resolves normally');

-- sem vinculo: assert neutro (o resolvedor nega pelo caminho normal, 42501) --------------------------
select pg_temp.as_user(104);
select lives_ok($$select app_private.staff_access_assert(pg_temp.fa(10),null,null)$$,'no vinculo: assert neutral');
select throws_ok($$select * from app_private.happens_actor(pg_temp.fa(10),'people.read',pg_temp.fa(11),null)$$,'42501',null,'no vinculo: plain 42501 as before');

select * from finish();
rollback;
