-- Prova pgTAP do pacote 20260910220800: snapshot de Locais na rota v1
-- (public.form_save_draft). Antes do pacote a mesma fixture devolve 23514
-- "location item requires at least one active location" sem opcoes, ou 23514
-- "location options must come from the catalog snapshot" com opcoes forjadas
-- (RED reproduzido com a segunda forma no
-- espelho local coelo_baseline_p16 em 11/09/2026); depois, o rascunho salva
-- com o snapshot. Fixture sintetica, rollback total.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
create function pg_temp.r1_id(n integer) returns uuid language sql immutable as $$
  select ('8f170000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.r1_id(integer) to authenticated;

select ok((select prosrc like '%form_apply_location_options_v1%' from pg_proc
  where oid='app_private.form_replace_working_definition(uuid,jsonb)'::regprocedure),'v1 route calls the location snapshot helper');
select ok(not has_function_privilege('anon','app_private.form_replace_working_definition(uuid,jsonb)','execute'),'anon cannot call the v1 helper');
select ok(not has_function_privilege('authenticated','app_private.form_replace_working_definition(uuid,jsonb)','execute'),'authenticated cannot call the v1 helper');
select ok(not has_function_privilege('anon','public.form_save_draft(uuid,bigint,jsonb)','execute'),'anon cannot save drafts (v1)');

insert into public.institution_types(id,code,name,status) values (pg_temp.r1_id(1),'r1-type','R1 type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 (pg_temp.r1_id(10),pg_temp.r1_id(1),'R1 A','r1-a','active'),
 (pg_temp.r1_id(20),pg_temp.r1_id(1),'R1 B','r1-b','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select pg_temp.r1_id(n),'authenticated','authenticated','r1-'||n||'@invalid.test',now(),now(),now(),'{}','{}' from unnest(array[111]) n;
insert into app_private.superadmin_internal_identities(id) values (pg_temp.r1_id(301));
insert into public.activity_locations(id,institution_id,unit_id,name,status,scope_kind,kind,visibility,created_by_internal_identity_id) values
 (pg_temp.r1_id(601),pg_temp.r1_id(10),null,'Sala Azul','active','institution','internal','team',pg_temp.r1_id(301)),
 (pg_temp.r1_id(602),pg_temp.r1_id(10),null,'Sala Verde','active','institution','internal','team',pg_temp.r1_id(301)),
 (pg_temp.r1_id(604),pg_temp.r1_id(10),null,'Sala Fechada','archived','institution','internal','team',pg_temp.r1_id(301)),
 (pg_temp.r1_id(621),pg_temp.r1_id(20),null,'Sala B','active','institution','internal','team',pg_temp.r1_id(301));
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.r1_id(211),'adult','R1','Author','R1 author','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values (pg_temp.r1_id(211),pg_temp.r1_id(111),'active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select pg_temp.r1_id(211),r.id,'active','platform',false from public.platform_roles r where r.code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow'::public.permission_effect,'active' from public.platform_roles r cross join public.platform_permissions p
where r.code='owner' and p.code in('forms.read','forms.manage')
on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null;

create temporary table r1_results(key text primary key,value jsonb not null);
grant select,insert,update on r1_results to authenticated;

select set_config('request.jwt.claims','{"sub":"8f170000-0000-4000-8000-000000000111","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into r1_results values('draft_a',public.form_save_draft(pg_temp.r1_id(801),0,jsonb_build_object(
 'id',pg_temp.r1_id(701),'institution_id',pg_temp.r1_id(10),'kind','form','identity_mode','identified','response_unit','person',
 'title','Onde foi (v1)?','description',null,
 'sections',jsonb_build_array(jsonb_build_object('id','s1','title','Local','position',0,'items',jsonb_build_array(
   jsonb_build_object('id','q1','kind','location','label','Em qual sala?','position',0,'is_required',true,
     'options',jsonb_build_array(jsonb_build_object('id','forjada','label','Opcao forjada pelo cliente','position',0))),
   jsonb_build_object('id','q2','kind','short_text','label','Comentario','position',1)))))));
reset role;
select is((select value->>'id' from r1_results where key='draft_a'),pg_temp.r1_id(701)::text,'v1 draft with a location question is saved (was 23514 before the package)');
select results_eq($$select o.label,o.location_id,o.location_status,o.position
  from public.form_question_options o join public.form_items i on i.id=o.item_id
  join public.form_versions v on v.id=i.form_version_id where v.form_id=pg_temp.r1_id(701) and i.kind='location' order by o.position$$,
 $$values ('Sala Azul',pg_temp.r1_id(601),'active'::text,0),('Sala Verde',pg_temp.r1_id(602),'active'::text,1)$$,
 'v1 snapshot comes from the active catalog of institution A, not from the client');
select is((select count(*) from public.form_question_options o join public.form_items i on i.id=o.item_id
  join public.form_versions v on v.id=i.form_version_id where v.form_id=pg_temp.r1_id(701) and o.label='Opcao forjada pelo cliente'),0::bigint,'forged option discarded on v1');

-- Reenvio v1 (expected_version 1) refaz o snapshot depois de revogar um local.
update public.activity_locations set status='archived' where id=pg_temp.r1_id(602);
select set_config('request.jwt.claims','{"sub":"8f170000-0000-4000-8000-000000000111","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into r1_results values('draft_a2',public.form_save_draft(pg_temp.r1_id(802),1,jsonb_build_object(
 'id',pg_temp.r1_id(701),'institution_id',pg_temp.r1_id(10),'kind','form','identity_mode','identified','response_unit','person',
 'title','Onde foi (v1)?','description',null,
 'sections',jsonb_build_array(jsonb_build_object('id','s1','title','Local','position',0,'items',jsonb_build_array(
   jsonb_build_object('id','q1','kind','location','label','Em qual sala?','position',0,'is_required',true),
   jsonb_build_object('id','q2','kind','short_text','label','Comentario','position',1)))))));
reset role;
select is((select count(*) from public.form_question_options o join public.form_items i on i.id=o.item_id
  join public.form_versions v on v.id=i.form_version_id where v.form_id=pg_temp.r1_id(701) and i.kind='location'),1::bigint,'v1 resave refreshes the snapshot (revoked location dropped)');
select * from finish();
rollback;
