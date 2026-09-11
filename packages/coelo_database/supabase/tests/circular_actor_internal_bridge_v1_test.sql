-- pgTAP comportamental do candidato 20260911190000_circular_actor_internal_bridge_v1:
-- a identidade interna (realm v2) com pessoa de servico (220400) e membership owner
-- na instituicao (230024) prepara anexo e responde Circular; sem membership continua
-- negada; outra instituicao (cross-tenant) continua negada; anon continua negado.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

select has_function('app_private','circular_actor',array['uuid','text','uuid','uuid'],'circular_actor existe');
select has_function('app_private','circular_audience_matches_role',
  array['text','public.circular_audience_kind'],'circular_audience_matches_role existe');
select is(app_private.circular_audience_matches_role('owner','guardians_only'::public.circular_audience_kind),true,
  'owner da instituicao alcanca qualquer audiencia (P23/P35)');
select is(app_private.circular_audience_matches_role('visitor','school_staff'::public.circular_audience_kind),false,
  'papel desconhecido continua sem audiencia');

-- Fixture: dois usuarios internos (owner de plataforma), duas instituicoes.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9c200000-0000-4000-8000-000000000101','authenticated','authenticated','bridge-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c200000-0000-4000-8000-000000000102','authenticated','authenticated','bridge-nomember@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9c200000-0000-4000-8000-000000000201','9c200000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour'),
 ('9c200000-0000-4000-8000-000000000202','9c200000-0000-4000-8000-000000000102',now(),now(),'aal1',now()+interval '1 hour');
insert into public.institution_types(id,code,name,status) values
 ('9c200000-0000-4000-8000-000000000001','bridge-test','Bridge test','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9c200000-0000-4000-8000-000000000010','Escola Ponte','bridge-ponte','active','9c200000-0000-4000-8000-000000000001'),
 ('9c200000-0000-4000-8000-000000000011','Escola Outra','bridge-outra','active','9c200000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_identities(id) values
 ('9c200000-0000-4000-8000-000000000301'),('9c200000-0000-4000-8000-000000000302');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9c200000-0000-4000-8000-000000000401','9c200000-0000-4000-8000-000000000301','9c200000-0000-4000-8000-000000000101'),
 ('9c200000-0000-4000-8000-000000000402','9c200000-0000-4000-8000-000000000302','9c200000-0000-4000-8000-000000000102');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,role_record.id,'platform'::app_private.superadmin_internal_scope_kind,null
from (values
 ('9c200000-0000-4000-8000-000000000501'::uuid,'9c200000-0000-4000-8000-000000000301'::uuid),
 ('9c200000-0000-4000-8000-000000000502'::uuid,'9c200000-0000-4000-8000-000000000302'::uuid)
) fixture(id,identity_id)
join public.platform_roles role_record on role_record.code='owner';

select ok(exists(select 1 from app_private.superadmin_internal_actor_people
  where internal_identity_id='9c200000-0000-4000-8000-000000000301'),
  'ponte de ator espelhou a identidade interna em pessoa de servico');

-- Membership owner da pessoa de servico do primeiro usuario SO na instituicao 10 (como 230024).
insert into public.institution_memberships(person_id,institution_id,role_code,status,scope_kind)
select actor.person_id,'9c200000-0000-4000-8000-000000000010','owner','active','institution'
from app_private.superadmin_internal_actor_people actor
where actor.internal_identity_id='9c200000-0000-4000-8000-000000000301';

create temporary table bridge_results(label text primary key,body jsonb not null);
create temporary table bridge_errors(label text primary key,message text not null);

-- Sessao do usuario interno com membership: cria e publica Circular com pergunta na 10.
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9c200000-0000-4000-8000-000000000101','session_id','9c200000-0000-4000-8000-000000000201',
 'aal','aal1','role','authenticated')::text,true);
insert into bridge_results values('saved',public.superadmin_circular_save_draft_v2(
 '9c200000-0000-4000-8000-000000000701','9c200000-0000-4000-8000-000000000010',null,null,null,
 jsonb_build_object('id','','title','Circular com anexo e pergunta','version',0,'status','draft',
  'response_policy','per_person','audiences',jsonb_build_array('families','school_staff'),
  'blocks',jsonb_build_array(
    jsonb_build_object('id','9c200000-0000-4000-8000-000000000801','kind','text','text','Texto.'),
    jsonb_build_object('id','9c200000-0000-4000-8000-000000000802','kind','question','question',
      jsonb_build_object('id','9c200000-0000-4000-8000-000000000802','prompt','Vai participar?','kind','single_choice',
        'required',true,'options',jsonb_build_array(
          jsonb_build_object('id','9c200000-0000-4000-8000-000000000901','label','Sim'),
          jsonb_build_object('id','9c200000-0000-4000-8000-000000000902','label','Nao'))))))));
select is((select body->>'ok' from bridge_results where label='saved'),'true','rascunho v2 criado pela identidade interna');

-- attach: prepare pelo ator interno (antes do pacote: active_membership_required).
do $$
declare v_body jsonb;
begin
  begin
    v_body := public.prepare_circular_media_upload('9c200000-0000-4000-8000-000000000702',
      '9c200000-0000-4000-8000-000000000010',
      (select (body#>>'{data,id}')::uuid from bridge_results where label='saved'),
      'pixel.png','image/png',70);
    insert into bridge_results values('prepare',v_body);
  exception when others then
    insert into bridge_errors values('prepare',sqlerrm);
  end;
end $$;
select ok((select body->>'asset_id' is not null from bridge_results where label='prepare'),
  'prepare_circular_media_upload autoriza o ator interno com membership: '||coalesce((select message from bridge_errors where label='prepare'),'ok'));
select is((select status from public.circular_media_assets
  where id=(select (body->>'asset_id')::uuid from bridge_results where label='prepare')),'pending',
  'descritor do anexo persiste como pending para a circular');

-- publica imediato para responder
insert into bridge_results values('published',public.superadmin_circular_publish_v2(
 '9c200000-0000-4000-8000-000000000703',(select (body#>>'{data,id}')::uuid from bridge_results where label='saved'),
 (select (body#>>'{data,version}')::bigint from bridge_results where label='saved'),null));
select is((select body#>>'{data,status}' from bridge_results where label='published'),'published','publicacao imediata');
-- publish_v2 grava publish_at por clock_timestamp(); dentro da transacao do teste now() fica
-- congelado antes disso, entao a fixture recua publish_at (em producao o relogio anda).
update public.circulars set publish_at=now()-interval '1 minute'
  where id=(select (body#>>'{data,id}')::uuid from bridge_results where label='saved');

-- respond: rascunho de resposta pelo ator interno (antes do pacote: active_membership_required;
-- e owner nao alcancava audiencia alguma).
do $$
declare v_body jsonb; v_rev uuid; v_q uuid; v_opt uuid;
begin
  select current_revision_id into v_rev from public.circulars
    where id=(select (body#>>'{data,id}')::uuid from bridge_results where label='saved');
  select q.id into v_q from public.circular_questions q where q.revision_id=v_rev limit 1;
  select o.id into v_opt from public.circular_question_options o where o.question_id=v_q order by o.display_order limit 1;
  begin
    v_body := public.save_circular_response_draft('9c200000-0000-4000-8000-000000000704',v_rev,
      jsonb_build_object('child_context_id',null,'answers',jsonb_build_array(
        jsonb_build_object('question_id',v_q,'option_ids',jsonb_build_array(v_opt)))),0);
    insert into bridge_results values('respond',v_body);
  exception when others then
    insert into bridge_errors values('respond',sqlerrm);
  end;
end $$;
select ok((select body->>'session_id' is not null from bridge_results where label='respond'),
  'save_circular_response_draft aceita o owner interno como audiencia: '||coalesce((select message from bridge_errors where label='respond'),'ok'));
do $$
declare v_body jsonb;
begin
  begin
    v_body := public.submit_circular_response('9c200000-0000-4000-8000-000000000705',
      (select (body->>'session_id')::uuid from bridge_results where label='respond'),
      (select (body->>'version')::bigint from bridge_results where label='respond'));
    insert into bridge_results values('submit',v_body);
  exception when others then
    insert into bridge_errors values('submit',sqlerrm);
  end;
end $$;
select is((select body->>'status' from bridge_results where label='submit'),'submitted',
  'submit_circular_response persiste: '||coalesce((select message from bridge_errors where label='submit'),'ok'));

-- negativa cross-tenant: mesmo usuario, circular em instituicao 11 (sem membership la).
insert into bridge_results values('saved_outra',public.superadmin_circular_save_draft_v2(
 '9c200000-0000-4000-8000-000000000706','9c200000-0000-4000-8000-000000000011',null,null,null,
 jsonb_build_object('id','','title','Outra','version',0,'status','draft','response_policy','per_person',
  'audiences',jsonb_build_array('families'),'blocks',jsonb_build_array(
   jsonb_build_object('id','9c200000-0000-4000-8000-000000000803','kind','text','text','x')))));
do $$
begin
  begin
    perform public.prepare_circular_media_upload('9c200000-0000-4000-8000-000000000707',
      '9c200000-0000-4000-8000-000000000011',
      (select (body#>>'{data,id}')::uuid from bridge_results where label='saved_outra'),'x.png','image/png',70);
    insert into bridge_errors values('prepare_outra','sem erro');
  exception when others then
    insert into bridge_errors values('prepare_outra',sqlerrm);
  end;
end $$;
select is((select message from bridge_errors where label='prepare_outra'),'active_membership_required',
  'cross-tenant: sem membership na instituicao 11 o anexo e negado');

-- negativa: usuario interno SEM membership de instituicao nao responde.
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9c200000-0000-4000-8000-000000000102','session_id','9c200000-0000-4000-8000-000000000202',
 'aal','aal1','role','authenticated')::text,true);
do $$
declare v_rev uuid;
begin
  select current_revision_id into v_rev from public.circulars
    where id=(select (body#>>'{data,id}')::uuid from bridge_results where label='saved');
  begin
    perform public.save_circular_response_draft('9c200000-0000-4000-8000-000000000708',v_rev,
      jsonb_build_object('child_context_id',null,'answers',jsonb_build_array()),0);
    insert into bridge_errors values('respond_nomember','sem erro');
  exception when others then
    insert into bridge_errors values('respond_nomember',sqlerrm);
  end;
end $$;
select is((select message from bridge_errors where label='respond_nomember'),'active_membership_required',
  'identidade interna sem membership continua negada (deny-by-default)');

-- anon
select set_config('request.jwt.claims','{"role":"anon"}',true);
select throws_ok(
  $$select public.prepare_circular_media_upload('9c200000-0000-4000-8000-000000000709',
     '9c200000-0000-4000-8000-000000000010','9c200000-0000-4000-8000-000000000010','x.png','image/png',70)$$,
  '42501',null,'anon nao prepara anexo');

select * from finish();
rollback;
