begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into public.institution_types(id,code,name,status) values
 ('9f080000-0000-4000-8000-000000000001','qa-r08-fmedia-retry','QA R08 forms media retry','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9f080000-0000-4000-8000-000000000010','QA R08 FM A','qa-r08-fm-a','active','9f080000-0000-4000-8000-000000000001'),
 ('9f080000-0000-4000-8000-000000000020','QA R08 FM B','qa-r08-fm-b','active','9f080000-0000-4000-8000-000000000001');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9f080000-0000-4000-8000-000000000102','authenticated','authenticated','fm-retry-a@invalid.test',now(),now(),now(),'{}','{}'),
 ('9f080000-0000-4000-8000-000000000103','authenticated','authenticated','fm-retry-b@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9f080000-0000-4000-8000-000000000202','9f080000-0000-4000-8000-000000000102',now(),now(),'aal1',now()+interval '1 hour'),
 ('9f080000-0000-4000-8000-000000000203','9f080000-0000-4000-8000-000000000103',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('9f080000-0000-4000-8000-000000000302'),('9f080000-0000-4000-8000-000000000303');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9f080000-0000-4000-8000-000000000402','9f080000-0000-4000-8000-000000000302','9f080000-0000-4000-8000-000000000102'),
 ('9f080000-0000-4000-8000-000000000403','9f080000-0000-4000-8000-000000000303','9f080000-0000-4000-8000-000000000103');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select f.id,f.identity_id,r.id,'institution'::app_private.superadmin_internal_scope_kind,f.institution_id
from (values
 ('9f080000-0000-4000-8000-000000000502'::uuid,'9f080000-0000-4000-8000-000000000302'::uuid,'9f080000-0000-4000-8000-000000000010'::uuid),
 ('9f080000-0000-4000-8000-000000000503'::uuid,'9f080000-0000-4000-8000-000000000303'::uuid,'9f080000-0000-4000-8000-000000000020'::uuid)
) f(id,identity_id,institution_id) join public.platform_roles r on r.code='owner';

insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_internal_identity_id,updated_by_internal_identity_id)
values ('9f080000-0000-4000-8000-000000000600','9f080000-0000-4000-8000-000000000010','form','identified','person','Form retry',
  '9f080000-0000-4000-8000-000000000302','9f080000-0000-4000-8000-000000000302');
insert into public.form_versions(id,form_id,version_number,created_by_internal_identity_id)
values ('9f080000-0000-4000-8000-000000000601','9f080000-0000-4000-8000-000000000600',1,'9f080000-0000-4000-8000-000000000302');
update public.forms set working_version_id='9f080000-0000-4000-8000-000000000601'
where id='9f080000-0000-4000-8000-000000000600';
insert into public.form_sections(id,form_version_id,title,position)
values ('9f080000-0000-4000-8000-000000000602','9f080000-0000-4000-8000-000000000601','Secao',0);
insert into public.form_items(id,form_version_id,section_id,kind,label,position)
values ('9f080000-0000-4000-8000-000000000603','9f080000-0000-4000-8000-000000000601','9f080000-0000-4000-8000-000000000602','photo','Foto',0);

-- Form people-based para provar que cross-tenant nao enumera existencia.
insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_person_id,updated_by_person_id)
select '9f080000-0000-4000-8000-000000000610','9f080000-0000-4000-8000-000000000010','form','identified','person','Form people A',actor.person_id,actor.person_id
from app_private.superadmin_internal_actor_people actor
where actor.internal_identity_id='9f080000-0000-4000-8000-000000000302';
insert into public.form_versions(id,form_id,version_number,created_by_person_id)
select '9f080000-0000-4000-8000-000000000611','9f080000-0000-4000-8000-000000000610',1,actor.person_id
from app_private.superadmin_internal_actor_people actor
where actor.internal_identity_id='9f080000-0000-4000-8000-000000000302';
update public.forms set working_version_id='9f080000-0000-4000-8000-000000000611'
where id='9f080000-0000-4000-8000-000000000610';

create temporary table fm_retry(label text primary key, body jsonb not null);
grant select,insert on fm_retry to authenticated,service_role;

select set_config('request.jwt.claims',jsonb_build_object('sub','9f080000-0000-4000-8000-000000000102','session_id','9f080000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into fm_retry values('prepare',public.superadmin_form_media_prepare_v2(
  '9f080000-0000-4000-8000-000000000901','9f080000-0000-4000-8000-000000000600',
  '9f080000-0000-4000-8000-000000000601','9f080000-0000-4000-8000-000000000603',
  'image/png',1024,repeat('a',64)));
reset role;
select is((select body->>'ok' from fm_retry where label='prepare'),'true','prepare cria ticket e binding');
create temporary table fm_retry_ids as
select (body#>>'{data,asset_id}')::uuid asset_id,(body#>>'{data,finalize_ticket}')::uuid ticket
from fm_retry where label='prepare';
grant select on fm_retry_ids to authenticated,service_role;

select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
insert into fm_retry values('finalize',public.form_media_finalize_question_r2_v1(
  (select asset_id from fm_retry_ids),(select ticket from fm_retry_ids),1024,repeat('a',64),640,480));
reset role;
select is((select body#>>'{data,status}' from fm_retry where label='finalize'),'ready','primeiro finalize confirma o asset');

select set_config('request.jwt.claims',jsonb_build_object('sub','9f080000-0000-4000-8000-000000000102','session_id','9f080000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into fm_retry values('authorize_retry',public.superadmin_form_media_authorize_finalize_v2((select asset_id from fm_retry_ids)));
reset role;
select ok((select body->>'ok'='true' and body#>>'{data,status}'='ready'
  and (body#>>'{data,replayed}')::boolean from fm_retry where label='authorize_retry'),
  'authorize reconcilia resposta perdida depois do finalize');

select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
insert into fm_retry values('finalize_retry',public.form_media_finalize_question_r2_v1(
  (select asset_id from fm_retry_ids),(select ticket from fm_retry_ids),1024,repeat('a',64),640,480));
insert into fm_retry values('finalize_changed',public.form_media_finalize_question_r2_v1(
  (select asset_id from fm_retry_ids),(select ticket from fm_retry_ids),1025,repeat('a',64),640,480));
reset role;
select ok((select body->>'ok'='true' and body#>>'{data,status}'='ready'
  and (body#>>'{data,replayed}')::boolean from fm_retry where label='finalize_retry'),
  'finalize identico e idempotente depois de resposta perdida');
select is((select body#>>'{error,code}' from fm_retry where label='finalize_changed'),'FORM_MEDIA_TICKET_INVALID',
  'retry com medidas diferentes permanece fail-closed');

select set_config('request.jwt.claims',jsonb_build_object('sub','9f080000-0000-4000-8000-000000000102','session_id','9f080000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into fm_retry values('delete',public.superadmin_form_media_delete_v2(
  '9f080000-0000-4000-8000-000000000902',(select asset_id from fm_retry_ids)));
reset role;
select ok((select body->>'ok'='true' from fm_retry where label='delete')
  and not exists(select 1 from public.media_bindings where media_asset_id=(select asset_id from fm_retry_ids)),
  'delete nominal remove o binding da pergunta');
select lives_ok($$
  select app_private.form_replace_working_definition(
    '9f080000-0000-4000-8000-000000000601',
    '[{"id":"secao-restante","title":"Secao","description":null,"position":0,"items":[{"id":"texto-restante","kind":"short_text","label":"Texto","help_text":null,"position":0,"is_required":false,"config":{},"options":[],"conditions":[]}]}]'::jsonb
  )
$$,'pergunta pode ser removida depois do delete nominal');

select set_config('request.jwt.claims',jsonb_build_object('sub','9f080000-0000-4000-8000-000000000103','session_id','9f080000-0000-4000-8000-000000000203','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_like($$select public.form_get_editor('9f080000-0000-4000-8000-000000000610')$$,
  '%form unavailable%','editor cross-tenant usa a mesma resposta de recurso indisponivel');
select throws_like($$select public.form_get_editor('9f080000-0000-4000-8000-000000009999')$$,
  '%form unavailable%','editor inexistente usa a mesma resposta de recurso indisponivel');
reset role;

select * from finish();
rollback;
