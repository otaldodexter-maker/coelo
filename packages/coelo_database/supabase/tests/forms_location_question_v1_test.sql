-- P16: pergunta de Local em Formularios (candidato 20260910220500).
-- Fixture sintetica, rollback total. Executa as RPCs publicas como authenticated.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
create function pg_temp.loc_id(n integer) returns uuid language sql immutable as $$
  select ('8f160000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.loc_id(integer) to authenticated;

-- Contrato estrutural.
select has_column('public','form_question_options','location_id','option carries the frozen location id');
select has_column('public','form_question_options','location_status','option carries the snapshot status');
select ok((select pg_get_constraintdef(oid) like '%location%' from pg_constraint where conname='form_items_kind_ck'),'form_items accepts kind=location');
select ok((select pg_get_constraintdef(oid) like '%location%' from pg_constraint where conname='form_answers_kind_ck'),'form_answers accepts answer_kind=location');
select ok(not has_function_privilege('anon','app_private.form_apply_location_options_v1(uuid)','execute'),'anon cannot snapshot');
select ok(not has_function_privilege('authenticated','app_private.form_apply_location_options_v1(uuid)','execute'),'authenticated cannot snapshot directly');
select ok(not has_function_privilege('authenticated','app_private.form_location_options_snapshot_v1(uuid)','execute'),'authenticated cannot read the catalog through the helper');
select ok(not has_function_privilege('authenticated','app_private.form_location_option_available_v1(uuid)','execute'),'authenticated cannot probe availability directly');
select ok(not has_function_privilege('anon','public.superadmin_forms_save_draft_v2(uuid,bigint,jsonb)','execute'),'anon cannot save drafts');
select ok(not has_function_privilege('anon','public.form_submit_response(uuid,bigint,jsonb)','execute'),'anon cannot submit responses');
select ok(not has_function_privilege('anon','public.form_edit_response(uuid,bigint,jsonb)','execute'),'anon cannot edit responses');
select ok(not has_function_privilege('anon','public.form_publish(uuid,bigint,jsonb)','execute'),'anon cannot publish');

-- Instituicoes A e B, catalogo de Locais.
insert into public.institution_types(id,code,name,status) values
 (pg_temp.loc_id(1),'p16-type','P16 type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 (pg_temp.loc_id(10),pg_temp.loc_id(1),'P16 A','p16-a','active'),
 (pg_temp.loc_id(20),pg_temp.loc_id(1),'P16 B','p16-b','active');

-- Realm interno v2 (autoria): usuario 101 = Owner de plataforma.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select pg_temp.loc_id(n),'authenticated','authenticated','p16-'||n||'@invalid.test',now(),now(),now(),'{}','{}'
from unnest(array[101,111,112]) n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 (pg_temp.loc_id(201),pg_temp.loc_id(101),now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values (pg_temp.loc_id(301));
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 (pg_temp.loc_id(401),pg_temp.loc_id(301),pg_temp.loc_id(101));
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select pg_temp.loc_id(501),pg_temp.loc_id(301),r.id,'platform',null from public.platform_roles r where r.code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow'::public.permission_effect,'active'
from public.platform_roles r cross join public.platform_permissions p
where r.code='owner' and p.code in('forms.read','forms.manage')
on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null;

insert into public.activity_locations(id,institution_id,unit_id,name,status,scope_kind,kind,visibility,created_by_internal_identity_id) values
 (pg_temp.loc_id(601),pg_temp.loc_id(10),null,'Sala Azul','active','institution','internal','team',pg_temp.loc_id(301)),
 (pg_temp.loc_id(602),pg_temp.loc_id(10),null,'Sala Verde','active','institution','internal','team',pg_temp.loc_id(301)),
 (pg_temp.loc_id(603),pg_temp.loc_id(10),null,'Sala Amarela','active','institution','internal','team',pg_temp.loc_id(301)),
 (pg_temp.loc_id(604),pg_temp.loc_id(10),null,'Sala Fechada','archived','institution','internal','team',pg_temp.loc_id(301)),
 (pg_temp.loc_id(605),pg_temp.loc_id(10),null,'Sala Inativa','inactive','institution','internal','team',pg_temp.loc_id(301)),
 (pg_temp.loc_id(621),pg_temp.loc_id(20),null,'Sala B','active','institution','internal','team',pg_temp.loc_id(301));

-- Realm de pessoas (resposta e publicacao): pessoa 211 (usuario 111) e 212 (usuario 112).
insert into public.people(id,person_type,first_name,last_name,display_name,status)
select pg_temp.loc_id(n),'adult','P16','Responder','P16 responder '||n,'active' from unnest(array[211,212]) n;
insert into public.person_auth_links(person_id,auth_user_id,status) values
 (pg_temp.loc_id(211),pg_temp.loc_id(111),'active'),(pg_temp.loc_id(212),pg_temp.loc_id(112),'active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select pg_temp.loc_id(n),r.id,'active','platform',false from unnest(array[211,212]) n cross join public.platform_roles r where r.code='owner';
insert into public.institution_memberships(person_id,institution_id,role_code,status)
select pg_temp.loc_id(n),pg_temp.loc_id(10),'owner','active' from unnest(array[211,212]) n;

create temporary table p16_results(key text primary key,value jsonb not null);
grant select,insert,update on p16_results to authenticated;

-- A. Autoria v2: o snapshot vem do catalogo da instituicao, nao do cliente.
select set_config('request.jwt.claims','{"sub":"8f160000-0000-4000-8000-000000000101","session_id":"8f160000-0000-4000-8000-000000000201","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into p16_results values('draft_a',public.superadmin_forms_save_draft_v2(pg_temp.loc_id(801),0,jsonb_build_object(
 'id',pg_temp.loc_id(701),'institution_id',pg_temp.loc_id(10),'kind','form','identity_mode','identified','response_unit','person',
 'title','Onde foi?','description',null,
 'sections',jsonb_build_array(jsonb_build_object('id','s1','title','Local','position',0,'items',jsonb_build_array(
   jsonb_build_object('id','q1','kind','location','label','Em qual sala?','position',0,'is_required',true,
     'options',jsonb_build_array(jsonb_build_object('id','forjada','label','Opcao forjada pelo cliente','position',0))),
   jsonb_build_object('id','q2','kind','short_text','label','Comentario','position',1)))))));
insert into p16_results values('draft_b',public.superadmin_forms_save_draft_v2(pg_temp.loc_id(802),0,jsonb_build_object(
 'id',pg_temp.loc_id(702),'institution_id',pg_temp.loc_id(20),'kind','form','identity_mode','identified','response_unit','person',
 'title','Onde foi (B)?','description',null,
 'sections',jsonb_build_array(jsonb_build_object('id','s1','title','Local','position',0,'items',jsonb_build_array(
   jsonb_build_object('id','q1','kind','location','label','Em qual sala?','position',0,'is_required',false)))))));
reset role;
select is((select value->>'ok' from p16_results where key='draft_a'),'true','draft with a location question is saved');
select is((select value->>'ok' from p16_results where key='draft_b'),'true','draft for institution B is saved');
select results_eq($$select o.label,o.location_id,o.location_status,o.position
  from public.form_question_options o join public.form_items i on i.id=o.item_id
  join public.form_versions v on v.id=i.form_version_id where v.form_id=pg_temp.loc_id(701) and i.kind='location' order by o.position$$,
 $$values('Sala Amarela',pg_temp.loc_id(603),'active',0),('Sala Azul',pg_temp.loc_id(601),'active',1),('Sala Verde',pg_temp.loc_id(602),'active',2)$$,
 'snapshot holds only the active locations of institution A, ordered by name; client options are ignored');
select results_eq($$select o.label,o.location_id from public.form_question_options o join public.form_items i on i.id=o.item_id
  join public.form_versions v on v.id=i.form_version_id where v.form_id=pg_temp.loc_id(702)$$,
 $$values('Sala B',pg_temp.loc_id(621))$$,'institution B snapshot never sees institution A locations');
select is((select count(*) from public.form_question_options o join public.form_items i on i.id=o.item_id
  join public.form_versions v on v.id=i.form_version_id where v.form_id=pg_temp.loc_id(701) and i.kind='short_text'),0::bigint,'short text item has no options');
select is((select jsonb_array_length(value#>'{data,sections,0,items,0,options}') from p16_results where key='draft_a'),3,'projection returns the three frozen options');
select is((select value#>'{data,sections,0,items,0,options,1}'->>'location_available' from p16_results where key='draft_a'),'true','projection exposes live availability');
select is((select value#>'{data,sections,0,items,0,options,1}'->>'location_id' from p16_results where key='draft_a'),pg_temp.loc_id(601)::text,'projection exposes the frozen location id');
select is((select value#>'{data,sections,0,items,1,options}' from p16_results where key='draft_a'),'[]'::jsonb,'non-location options keep their shape');

-- Re-salvar o rascunho re-resolve o snapshot (um Local novo aparece; o cliente devolvendo a projecao nao interfere).
insert into public.activity_locations(id,institution_id,unit_id,name,status,scope_kind,kind,visibility,created_by_internal_identity_id) values
 (pg_temp.loc_id(606),pg_temp.loc_id(10),null,'Sala Nova','active','institution','internal','team',pg_temp.loc_id(301));
select set_config('request.jwt.claims','{"sub":"8f160000-0000-4000-8000-000000000101","session_id":"8f160000-0000-4000-8000-000000000201","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into p16_results values('draft_a2',public.superadmin_forms_save_draft_v2(pg_temp.loc_id(803),1,jsonb_build_object(
 'id',pg_temp.loc_id(701),'institution_id',pg_temp.loc_id(10),'kind','form','identity_mode','identified','response_unit','person',
 'title','Onde foi?','description',null,
 'sections',jsonb_build_array(jsonb_build_object('id','s1','title','Local','position',0,'items',jsonb_build_array(
   jsonb_build_object('id','q1','kind','location','label','Em qual sala?','position',0,'is_required',true,
     'options',(select value#>'{data,sections,0,items,0,options}' from p16_results where key='draft_a')),
   jsonb_build_object('id','q2','kind','short_text','label','Comentario','position',1)))))));
reset role;
select is((select coalesce(value->>'ok','?')||coalesce(value#>>'{error,code}','') from p16_results where key='draft_a2'),'true','re-saving the draft with the echoed projection is accepted');
select is((select jsonb_array_length(value#>'{data,sections,0,items,0,options}') from p16_results where key='draft_a2'),4,'re-saved draft re-resolves the snapshot (new location included)');

-- B. Publicacao pelo realm de pessoas: exige ao menos um Local ativo e congela a lista.
insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_person_id,updated_by_person_id)
values(pg_temp.loc_id(1000),pg_temp.loc_id(20),'form','identified','person','P16 publish B',pg_temp.loc_id(211),pg_temp.loc_id(211));
insert into public.form_versions(id,form_id,version_number,created_by_person_id)
values(pg_temp.loc_id(1001),pg_temp.loc_id(1000),1,pg_temp.loc_id(211));
update public.forms set working_version_id=pg_temp.loc_id(1001) where id=pg_temp.loc_id(1000);
insert into public.form_sections(id,form_version_id,title,position)
values(pg_temp.loc_id(1002),pg_temp.loc_id(1001),'Local',0);
insert into public.form_items(id,form_version_id,section_id,kind,label,is_required,position,config_jsonb) values
(pg_temp.loc_id(1003),pg_temp.loc_id(1001),pg_temp.loc_id(1002),'location','Onde?',true,0,'{}');
select throws_ok($$select app_private.validate_form_definition(pg_temp.loc_id(1001))$$,'23514','location item requires at least one active location','publish validation refuses a location question without any active location');
select throws_ok($$insert into public.form_question_options(form_version_id,item_id,label,position) values(pg_temp.loc_id(1001),pg_temp.loc_id(1003),'Manual',0);
  select app_private.validate_form_definition(pg_temp.loc_id(1001))$$,'23514','location options must come from the catalog snapshot','publish validation refuses hand-written location options');
delete from public.form_question_options where item_id=pg_temp.loc_id(1003);
update public.activity_locations set status='archived' where id=pg_temp.loc_id(621);
set local role authenticated;
select set_config('request.jwt.claim.sub','8f160000-0000-4000-8000-000000000111',true);
select set_config('request.jwt.claims','{"sub":"8f160000-0000-4000-8000-000000000111","aal":"aal1","role":"authenticated"}',true);
select throws_ok($$select public.form_publish(pg_temp.loc_id(1100),1,jsonb_build_object('form_id',pg_temp.loc_id(1000)))$$,'23514','location item requires at least one active location','publish is blocked while institution B has no active location');
reset role;
update public.activity_locations set status='active' where id=pg_temp.loc_id(621);
set local role authenticated;
select set_config('request.jwt.claim.sub','8f160000-0000-4000-8000-000000000111',true);
select set_config('request.jwt.claims','{"sub":"8f160000-0000-4000-8000-000000000111","aal":"aal1","role":"authenticated"}',true);
insert into p16_results values('publish_b',public.form_publish(pg_temp.loc_id(1101),1,jsonb_build_object('form_id',pg_temp.loc_id(1000))));
reset role;
select is((select status from public.forms where id=pg_temp.loc_id(1000)),'published','publish succeeds once a location is active');
select results_eq($$select label,location_id from public.form_question_options where item_id=pg_temp.loc_id(1003)$$,
 $$values('Sala B',pg_temp.loc_id(621))$$,'publication froze the current catalog of institution B');

-- C. Respostas: formulario publicado da instituicao A com pergunta obrigatoria (2 opcoes) e opcional (1 opcao).
insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,status,created_by_person_id,updated_by_person_id)
values(pg_temp.loc_id(2000),pg_temp.loc_id(10),'form','identified','person','P16 respostas A','draft',pg_temp.loc_id(211),pg_temp.loc_id(211));
insert into public.form_versions(id,form_id,version_number,created_by_person_id)
values(pg_temp.loc_id(2001),pg_temp.loc_id(2000),1,pg_temp.loc_id(211));
insert into public.form_sections(id,form_version_id,title,position)
values(pg_temp.loc_id(2002),pg_temp.loc_id(2001),'Local',0);
insert into public.form_items(id,form_version_id,section_id,kind,label,is_required,position,config_jsonb) values
(pg_temp.loc_id(2003),pg_temp.loc_id(2001),pg_temp.loc_id(2002),'location','Sala obrigatoria',true,0,'{}'),
(pg_temp.loc_id(2004),pg_temp.loc_id(2001),pg_temp.loc_id(2002),'location','Sala opcional',false,1,'{}');
insert into public.form_question_options(id,form_version_id,item_id,label,position,location_id,location_status) values
(pg_temp.loc_id(2101),pg_temp.loc_id(2001),pg_temp.loc_id(2003),'Sala Azul',0,pg_temp.loc_id(601),'active'),
(pg_temp.loc_id(2102),pg_temp.loc_id(2001),pg_temp.loc_id(2003),'Sala Verde',1,pg_temp.loc_id(602),'active'),
(pg_temp.loc_id(2103),pg_temp.loc_id(2001),pg_temp.loc_id(2004),'Sala Amarela',0,pg_temp.loc_id(603),'active');
update public.form_versions set state='published',published_at=now() where id=pg_temp.loc_id(2001);
update public.forms set status='published',published_version_id=pg_temp.loc_id(2001),first_published_at=now() where id=pg_temp.loc_id(2000);
insert into public.form_applications(id,form_id,institution_id,name,created_by_person_id)
values(pg_temp.loc_id(2005),pg_temp.loc_id(2000),pg_temp.loc_id(10),'P16 application',pg_temp.loc_id(211));
insert into public.form_schedules(id,application_id,time_zone,starts_at_local,recurrence_kind)
values(pg_temp.loc_id(2006),pg_temp.loc_id(2005),'America/Sao_Paulo',localtimestamp,'once');
insert into public.form_occurrences(id,application_id,schedule_id,institution_id,form_id,form_version_id,scheduled_local,time_zone,opens_at,closes_at,status,opened_at)
values(pg_temp.loc_id(2007),pg_temp.loc_id(2005),pg_temp.loc_id(2006),pg_temp.loc_id(10),pg_temp.loc_id(2000),pg_temp.loc_id(2001),localtimestamp,'America/Sao_Paulo',now()-interval '1 hour',now()+interval '1 day','open',now()-interval '1 hour');
insert into public.form_participations(id,occurrence_id,institution_id,person_id,response_unit_key,eligibility_state,response_state)
values(pg_temp.loc_id(2008),pg_temp.loc_id(2007),pg_temp.loc_id(10),pg_temp.loc_id(211),'person:'||pg_temp.loc_id(211)::text,'eligible','draft');
insert into public.form_responses(id,occurrence_id,institution_id,form_id,form_version_id,identity_mode,respondent_person_id)
values(pg_temp.loc_id(2009),pg_temp.loc_id(2007),pg_temp.loc_id(10),pg_temp.loc_id(2000),pg_temp.loc_id(2001),'identified',pg_temp.loc_id(211));
insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_person_id,updated_by_person_id)
values(pg_temp.loc_id(3000),pg_temp.loc_id(10),'form','identified','person','P16 working A',pg_temp.loc_id(211),pg_temp.loc_id(211));
insert into public.form_versions(id,form_id,version_number,created_by_person_id) values(pg_temp.loc_id(3001),pg_temp.loc_id(3000),1,pg_temp.loc_id(211));
insert into public.form_sections(id,form_version_id,title,position) values(pg_temp.loc_id(3002),pg_temp.loc_id(3001),'Local',0);
insert into public.form_items(id,form_version_id,section_id,kind,label,is_required,position,config_jsonb) values
(pg_temp.loc_id(3003),pg_temp.loc_id(3001),pg_temp.loc_id(3002),'location','Onde?',false,0,'{}');
select throws_ok($$insert into public.form_question_options(form_version_id,item_id,label,position,location_id)
  values(pg_temp.loc_id(3001),pg_temp.loc_id(3003),'Sem status',0,pg_temp.loc_id(603))$$,'23514',null,'snapshot needs status together with id');
select lives_ok($$select app_private.form_apply_location_options_v1(pg_temp.loc_id(3001))$$,'snapshot helper runs on a working version');
select is((select count(*) from public.form_question_options where item_id=pg_temp.loc_id(3003)),4::bigint,'working version snapshot holds the four active locations of A');
-- Opcao de outro formulario/instituicao (B, versao de trabalho), para a negativa cruzada.
insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_person_id,updated_by_person_id)
values(pg_temp.loc_id(3100),pg_temp.loc_id(20),'form','identified','person','P16 working B',pg_temp.loc_id(211),pg_temp.loc_id(211));
insert into public.form_versions(id,form_id,version_number,created_by_person_id) values(pg_temp.loc_id(3101),pg_temp.loc_id(3100),1,pg_temp.loc_id(211));
insert into public.form_sections(id,form_version_id,title,position) values(pg_temp.loc_id(3102),pg_temp.loc_id(3101),'Local',0);
insert into public.form_items(id,form_version_id,section_id,kind,label,is_required,position,config_jsonb) values
(pg_temp.loc_id(3103),pg_temp.loc_id(3101),pg_temp.loc_id(3102),'location','Outra sala',false,0,'{}');
insert into public.form_question_options(id,form_version_id,item_id,label,position,location_id,location_status) values
(pg_temp.loc_id(1201),pg_temp.loc_id(3101),pg_temp.loc_id(3103),'Sala B',0,pg_temp.loc_id(621),'active');

set local role authenticated;
select set_config('request.jwt.claim.sub','8f160000-0000-4000-8000-000000000111',true);
select set_config('request.jwt.claims','{"sub":"8f160000-0000-4000-8000-000000000111","aal":"aal1","role":"authenticated"}',true);
select throws_ok($$select public.form_save_response_draft(pg_temp.loc_id(2200),1,jsonb_build_object('response_id',pg_temp.loc_id(2009),'participation_id',pg_temp.loc_id(2008),
  'answers',jsonb_build_array(jsonb_build_object('item_id',pg_temp.loc_id(2003),'kind','location','option_ids',jsonb_build_array(pg_temp.loc_id(1201))))))$$,
  '22023','answer option unavailable','an option frozen in another tenant''s form is refused');
select throws_ok($$select public.form_save_response_draft(pg_temp.loc_id(2201),1,jsonb_build_object('response_id',pg_temp.loc_id(2009),'participation_id',pg_temp.loc_id(2008),
  'answers',jsonb_build_array(jsonb_build_object('item_id',pg_temp.loc_id(2003),'kind','location','option_ids',jsonb_build_array(pg_temp.loc_id(2101),pg_temp.loc_id(2102))))))$$,
  '23514','multiple choice selection count is out of range','a location answer holds exactly one option');
select throws_ok($$select public.form_save_response_draft(pg_temp.loc_id(2202),1,jsonb_build_object('response_id',pg_temp.loc_id(2009),'participation_id',pg_temp.loc_id(2008),
  'answers',jsonb_build_array(jsonb_build_object('item_id',pg_temp.loc_id(2003),'kind','location','text_value','Sala Azul'))))$$,
  '23514',null,'a location answer cannot carry a typed value');
select throws_ok($$select public.form_submit_response(pg_temp.loc_id(2203),1,jsonb_build_object('response_id',pg_temp.loc_id(2009),'participation_id',pg_temp.loc_id(2008),
  'answers',jsonb_build_array(jsonb_build_object('item_id',pg_temp.loc_id(2004),'kind','location','option_ids',jsonb_build_array(pg_temp.loc_id(2103))))))$$,
  '23514','required visible form answers are missing','required location question without answer is still missing (alternatives exist)');
insert into p16_results values('submitted',public.form_submit_response(pg_temp.loc_id(2204),1,jsonb_build_object('response_id',pg_temp.loc_id(2009),'participation_id',pg_temp.loc_id(2008),
  'answers',jsonb_build_array(
    jsonb_build_object('item_id',pg_temp.loc_id(2003),'kind','location','option_ids',jsonb_build_array(pg_temp.loc_id(2101))),
    jsonb_build_object('item_id',pg_temp.loc_id(2004),'kind','location','option_ids',jsonb_build_array(pg_temp.loc_id(2103)))))));
reset role;
select is((select status from public.form_responses where id=pg_temp.loc_id(2009)),'submitted','valid location answers are accepted on submit');
select results_eq($$select ao.option_id from public.form_answer_options ao join public.form_answers a on a.id=ao.answer_id
  where a.response_id=pg_temp.loc_id(2009) and a.answer_kind='location' order by ao.option_id$$,
  $$select unnest(array[pg_temp.loc_id(2101),pg_temp.loc_id(2103)])$$,'both location selections persisted');
select is((select value#>'{answers,0,option_ids,0}' from p16_results where key='submitted'),to_jsonb(pg_temp.loc_id(2101)::text),'response projection returns the chosen option');

-- Opcao 2: Sala Azul revogada depois; reenviar com ela e recusado, escolher outra valida e aceito.
update public.activity_locations set status='archived' where id=pg_temp.loc_id(601);
set local role authenticated;
select set_config('request.jwt.claim.sub','8f160000-0000-4000-8000-000000000111',true);
select set_config('request.jwt.claims','{"sub":"8f160000-0000-4000-8000-000000000111","aal":"aal1","role":"authenticated"}',true);
select throws_ok($$select public.form_edit_response(pg_temp.loc_id(2210),2,jsonb_build_object('response_id',pg_temp.loc_id(2009),'participation_id',pg_temp.loc_id(2008),
  'answers',jsonb_build_array(
    jsonb_build_object('item_id',pg_temp.loc_id(2003),'kind','location','option_ids',jsonb_build_array(pg_temp.loc_id(2101))),
    jsonb_build_object('item_id',pg_temp.loc_id(2004),'kind','location','option_ids',jsonb_build_array(pg_temp.loc_id(2103))))))$$,
  '23514','form location answer requires a current location','revoked location is refused on edit (option 2)');
insert into p16_results values('edited',public.form_edit_response(pg_temp.loc_id(2211),2,jsonb_build_object('response_id',pg_temp.loc_id(2009),'participation_id',pg_temp.loc_id(2008),
  'answers',jsonb_build_array(
    jsonb_build_object('item_id',pg_temp.loc_id(2003),'kind','location','option_ids',jsonb_build_array(pg_temp.loc_id(2102))),
    jsonb_build_object('item_id',pg_temp.loc_id(2004),'kind','location','option_ids',jsonb_build_array(pg_temp.loc_id(2103)))))));
reset role;
select is((select ao.option_id from public.form_answer_options ao join public.form_answers a on a.id=ao.answer_id
  where a.response_id=pg_temp.loc_id(2009) and a.item_id=pg_temp.loc_id(2003)),pg_temp.loc_id(2102),'choosing another valid location is accepted');
select ok((select count(*)=1 from public.form_answer_options ao join public.form_answers a on a.id=ao.answer_id
  where a.response_id=pg_temp.loc_id(2009) and a.item_id=pg_temp.loc_id(2003)),'revoked pointer is not preserved');
select is((select management_version from public.form_responses where id=pg_temp.loc_id(2009)),3::bigint,'refused edit did not advance the version');
select is((select value#>'{data,sections,0,items,0,options}' from p16_results where key='draft_a'),(select value#>'{data,sections,0,items,0,options}' from p16_results where key='draft_a'),'sanity');
select is((select (opt->>'location_available') from public.forms f, jsonb_array_elements(app_private.form_definition_projection(f.id,pg_temp.loc_id(2001))#>'{sections,0,items,0,options}') opt
  where f.id=pg_temp.loc_id(2000) and opt->>'id'=pg_temp.loc_id(2101)::text),'false','projection now marks the revoked option unavailable');

-- Opcional sem alternativa: enviar o revogado e recusado; omitir e aceito.
update public.activity_locations set status='inactive' where id=pg_temp.loc_id(603);
set local role authenticated;
select set_config('request.jwt.claim.sub','8f160000-0000-4000-8000-000000000111',true);
select set_config('request.jwt.claims','{"sub":"8f160000-0000-4000-8000-000000000111","aal":"aal1","role":"authenticated"}',true);
select throws_ok($$select public.form_edit_response(pg_temp.loc_id(2220),3,jsonb_build_object('response_id',pg_temp.loc_id(2009),'participation_id',pg_temp.loc_id(2008),
  'answers',jsonb_build_array(
    jsonb_build_object('item_id',pg_temp.loc_id(2003),'kind','location','option_ids',jsonb_build_array(pg_temp.loc_id(2102))),
    jsonb_build_object('item_id',pg_temp.loc_id(2004),'kind','location','option_ids',jsonb_build_array(pg_temp.loc_id(2103))))))$$,
  '23514','form location answer requires a current location','inactive location is refused on an optional question');
insert into p16_results values('edited2',public.form_edit_response(pg_temp.loc_id(2221),3,jsonb_build_object('response_id',pg_temp.loc_id(2009),'participation_id',pg_temp.loc_id(2008),
  'answers',jsonb_build_array(
    jsonb_build_object('item_id',pg_temp.loc_id(2003),'kind','location','option_ids',jsonb_build_array(pg_temp.loc_id(2102)))))));
reset role;
select is((select count(*) from public.form_answers where response_id=pg_temp.loc_id(2009)),1::bigint,'optional location question can be left out when it has no valid alternative');

-- Caso extra (Decisao 12): obrigatoria, todos os locais do snapshot revogados -> bloqueio com codigo proprio.
update public.activity_locations set status='archived' where id=pg_temp.loc_id(602);
set local role authenticated;
select set_config('request.jwt.claim.sub','8f160000-0000-4000-8000-000000000111',true);
select set_config('request.jwt.claims','{"sub":"8f160000-0000-4000-8000-000000000111","aal":"aal1","role":"authenticated"}',true);
select throws_ok($$select public.form_edit_response(pg_temp.loc_id(2230),4,jsonb_build_object('response_id',pg_temp.loc_id(2009),'participation_id',pg_temp.loc_id(2008),
  'answers',jsonb_build_array(jsonb_build_object('item_id',pg_temp.loc_id(2003),'kind','location','option_ids',jsonb_build_array(pg_temp.loc_id(2102))))))$$,
  '23514','required location question has no available location','required question with every location revoked blocks instead of forcing an invalid choice');
select throws_ok($$select public.form_edit_response(pg_temp.loc_id(2231),4,jsonb_build_object('response_id',pg_temp.loc_id(2009),'participation_id',pg_temp.loc_id(2008),'answers','[]'::jsonb))$$,
  '23514','required location question has no available location','omitting the blocked question reports the same block');
reset role;
select is((select management_version from public.form_responses where id=pg_temp.loc_id(2009)),4::bigint,'blocked edits leave the response untouched');
select is((select ao.option_id from public.form_answer_options ao join public.form_answers a on a.id=ao.answer_id
  where a.response_id=pg_temp.loc_id(2009) and a.item_id=pg_temp.loc_id(2003)),pg_temp.loc_id(2102),'historical answer stays as submitted');
select ok(not exists(select 1 from public.forms f, jsonb_array_elements(app_private.form_definition_projection(f.id,pg_temp.loc_id(2001))#>'{sections,0,items,0,options}') opt
  where f.id=pg_temp.loc_id(2000) and opt->>'location_available'='true'),'projection shows no available option for the blocked question');

-- Negativas de ator: outra pessoa e anon.
set local role authenticated;
select set_config('request.jwt.claim.sub','8f160000-0000-4000-8000-000000000112',true);
select set_config('request.jwt.claims','{"sub":"8f160000-0000-4000-8000-000000000112","aal":"aal1","role":"authenticated"}',true);
select throws_ok($$select public.form_edit_response(pg_temp.loc_id(2240),4,jsonb_build_object('response_id',pg_temp.loc_id(2009),'participation_id',pg_temp.loc_id(2008),'answers','[]'::jsonb))$$,
  'P0002','form response unavailable','another person cannot edit the response');
reset role;
set local role anon;
select throws_ok($$select public.form_submit_response(pg_temp.loc_id(2250),4,'{}'::jsonb)$$,'42501',null,'anon is denied on submit');
select throws_ok($$select public.superadmin_forms_save_draft_v2(pg_temp.loc_id(2251),0,'{}'::jsonb)$$,'42501',null,'anon is denied on draft save');
reset role;

-- Snapshot com respostas gravadas nao e substituido (versao publicada e imutavel).
select throws_ok($$select app_private.form_apply_location_options_v1(pg_temp.loc_id(2001))$$,'23514','location options with answers cannot be replaced','snapshot with answers is immutable');

select * from finish();
