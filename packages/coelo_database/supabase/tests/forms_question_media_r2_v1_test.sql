-- forms_files: prepare -> authorize_finalize -> finalize (service_role) -> resolve -> delete;
-- expire, fila de limpeza, cross-tenant e grants.
begin;
create extension if not exists pgtap with schema extensions;
select plan(33);

insert into public.institution_types(id,code,name,status) values
 ('9f060000-0000-4000-8000-000000000001','qa-r05-fmedia','QA R05 forms media','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9f060000-0000-4000-8000-000000000010','QA R05 FM A','qa-r05-fm-a','active','9f060000-0000-4000-8000-000000000001'),
 ('9f060000-0000-4000-8000-000000000020','QA R05 FM B','qa-r05-fm-b','active','9f060000-0000-4000-8000-000000000001');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9f060000-0000-4000-8000-000000000102','authenticated','authenticated','fm-owner-a@invalid.test',now(),now(),now(),'{}','{}'),
 ('9f060000-0000-4000-8000-000000000103','authenticated','authenticated','fm-owner-b@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9f060000-0000-4000-8000-000000000202','9f060000-0000-4000-8000-000000000102',now(),now(),'aal1',now()+interval '1 hour'),
 ('9f060000-0000-4000-8000-000000000203','9f060000-0000-4000-8000-000000000103',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('9f060000-0000-4000-8000-000000000302'),('9f060000-0000-4000-8000-000000000303');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9f060000-0000-4000-8000-000000000402','9f060000-0000-4000-8000-000000000302','9f060000-0000-4000-8000-000000000102'),
 ('9f060000-0000-4000-8000-000000000403','9f060000-0000-4000-8000-000000000303','9f060000-0000-4000-8000-000000000103');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select f.id,f.identity_id,r.id,'institution'::app_private.superadmin_internal_scope_kind,f.institution_id
from (values
 ('9f060000-0000-4000-8000-000000000502'::uuid,'9f060000-0000-4000-8000-000000000302'::uuid,'9f060000-0000-4000-8000-000000000010'::uuid),
 ('9f060000-0000-4000-8000-000000000503'::uuid,'9f060000-0000-4000-8000-000000000303'::uuid,'9f060000-0000-4000-8000-000000000020'::uuid)
) f(id,identity_id,institution_id) join public.platform_roles r on r.code='owner';
-- formulario interno preserva a regressao original do RPC v2.
insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_internal_identity_id,updated_by_internal_identity_id)
values ('9f060000-0000-4000-8000-000000000600','9f060000-0000-4000-8000-000000000010','form','identified','person','Form imagens',
  '9f060000-0000-4000-8000-000000000302','9f060000-0000-4000-8000-000000000302');
insert into public.form_versions(id,form_id,version_number,created_by_internal_identity_id)
values ('9f060000-0000-4000-8000-000000000601','9f060000-0000-4000-8000-000000000600',1,'9f060000-0000-4000-8000-000000000302');
update public.forms set working_version_id='9f060000-0000-4000-8000-000000000601'
where id='9f060000-0000-4000-8000-000000000600';
insert into public.form_sections(id,form_version_id,title,position)
values ('9f060000-0000-4000-8000-000000000602','9f060000-0000-4000-8000-000000000601','Secao',0);
insert into public.form_items(id,form_version_id,section_id,kind,label,position)
values ('9f060000-0000-4000-8000-000000000603','9f060000-0000-4000-8000-000000000601','9f060000-0000-4000-8000-000000000602','photo','Foto',0);

-- formulario do host produtivo: autoria people-based do mesmo ator interno,
-- resolvida pela ponte sem fabricar person_auth_link nem alternar realm.
insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_person_id,updated_by_person_id)
select '9f060000-0000-4000-8000-000000000610','9f060000-0000-4000-8000-000000000010','form','identified','person','Form produtivo',
  actor.person_id,actor.person_id
from app_private.superadmin_internal_actor_people actor
where actor.internal_identity_id='9f060000-0000-4000-8000-000000000302';
insert into public.form_versions(id,form_id,version_number,created_by_person_id)
select '9f060000-0000-4000-8000-000000000611','9f060000-0000-4000-8000-000000000610',1,actor.person_id
from app_private.superadmin_internal_actor_people actor
where actor.internal_identity_id='9f060000-0000-4000-8000-000000000302';
update public.forms set working_version_id='9f060000-0000-4000-8000-000000000611'
where id='9f060000-0000-4000-8000-000000000610';
insert into public.form_sections(id,form_version_id,title,position)
values ('9f060000-0000-4000-8000-000000000612','9f060000-0000-4000-8000-000000000611','Secao produtiva',0);
insert into public.form_items(id,form_version_id,section_id,kind,label,position)
values ('9f060000-0000-4000-8000-000000000613','9f060000-0000-4000-8000-000000000611','9f060000-0000-4000-8000-000000000612','photo','Foto produtiva',0);

create temporary table fm(label text primary key, body jsonb not null);
grant select,insert on fm to authenticated, service_role;

select ok(has_function_privilege('authenticated','public.superadmin_form_media_prepare_v2(uuid,uuid,uuid,uuid,text,bigint,text)','execute')
  and has_function_privilege('authenticated','public.superadmin_form_media_resolve_v2(uuid)','execute')
  and has_function_privilege('authenticated','public.superadmin_form_media_delete_v2(uuid,uuid)','execute')
  and not has_function_privilege('authenticated','public.form_media_finalize_question_r2_v1(uuid,uuid,bigint,text,integer,integer)','execute')
  and has_function_privilege('service_role','public.form_media_finalize_question_r2_v1(uuid,uuid,bigint,text,integer,integer)','execute')
  and has_function_privilege('service_role','public.form_media_claim_cleanup_r2_v1(integer)','execute')
  and not has_function_privilege('anon','public.superadmin_form_media_prepare_v2(uuid,uuid,uuid,uuid,text,bigint,text)','execute'),
  'grants: authenticated prepara/resolve/exclui; service_role finaliza/expira/limpa; anon nada');
select ok(not exists (select 1 from information_schema.role_table_grants where table_schema='app_private'
  and table_name in ('form_media_upload_tickets','form_media_r2_cleanup') and grantee in ('PUBLIC','anon','authenticated','service_role')),
  'tabelas privadas sem grant a cliente');

-- prepare pela autora (owner escopado a A)
select set_config('request.jwt.claims',jsonb_build_object('sub','9f060000-0000-4000-8000-000000000102','session_id','9f060000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into fm values('prepare',public.superadmin_form_media_prepare_v2('9f060000-0000-4000-8000-000000000901',
  '9f060000-0000-4000-8000-000000000600','9f060000-0000-4000-8000-000000000601','9f060000-0000-4000-8000-000000000603','image/png',1000,repeat('a',64)));
reset role;
select is((select body->>'ok' from fm where label='prepare'),'true','prepare aceito');
select ok((select body#>>'{data,object_key}' ~ '^tenants/9f060000-0000-4000-8000-000000000010/forms/form/9f060000-0000-4000-8000-000000000600/question-image/[0-9a-f-]{36}/original/[0-9a-f-]{36}[.]png$'
  and body#>>'{data,bucket}'='coelo-media-prod' and body#>>'{data,status}'='pending' from fm where label='prepare'),
  'object_key na convencao do catalogo, bucket privado, pending');
create temporary table fm_ids as select (body#>>'{data,asset_id}')::uuid asset_id,(body#>>'{data,finalize_ticket}')::uuid ticket from fm where label='prepare';
grant select on fm_ids to authenticated, service_role;
select is((select count(*) from public.media_bindings where media_asset_id=(select asset_id from fm_ids) and purpose='question-image' and position=0),1::bigint,
  'binding question-image criado na posicao 0');

-- replay / mismatch / limites
insert into fm values('replay',public.superadmin_form_media_prepare_v2('9f060000-0000-4000-8000-000000000901',
  '9f060000-0000-4000-8000-000000000600','9f060000-0000-4000-8000-000000000601','9f060000-0000-4000-8000-000000000603','image/png',1000,repeat('a',64)));
select ok((select body->>'ok'='true' and (body#>>'{data,asset_id}')::uuid=(select asset_id from fm_ids) from fm where label='replay'),'replay devolve o mesmo asset');
insert into fm values('mismatch',public.superadmin_form_media_prepare_v2('9f060000-0000-4000-8000-000000000901',
  '9f060000-0000-4000-8000-000000000600','9f060000-0000-4000-8000-000000000601','9f060000-0000-4000-8000-000000000603','image/png',2000,repeat('a',64)));
select is((select body#>>'{error,code}' from fm where label='mismatch'),'FORM_MEDIA_REPLAY_MISMATCH','request_id com outro arquivo e recusado');
insert into fm values
 ('big',public.superadmin_form_media_prepare_v2(gen_random_uuid(),'9f060000-0000-4000-8000-000000000600','9f060000-0000-4000-8000-000000000601','9f060000-0000-4000-8000-000000000603','image/png',4194305,repeat('b',64))),
 ('pdf',public.superadmin_form_media_prepare_v2(gen_random_uuid(),'9f060000-0000-4000-8000-000000000600','9f060000-0000-4000-8000-000000000601','9f060000-0000-4000-8000-000000000603','application/pdf',10,repeat('b',64)));
select ok((select bool_and(body#>>'{error,code}'='FORM_MEDIA_INVALID') from fm where label in ('big','pdf')),'acima de 4 MiB e PDF sao FORM_MEDIA_INVALID');
insert into fm values('resolve_early',public.superadmin_form_media_resolve_v2((select asset_id from fm_ids)));
select is((select body#>>'{error,code}' from fm where label='resolve_early'),'FORM_MEDIA_NOT_READY','pendente nao resolve');

-- cross-tenant (owner escopado a B)
select set_config('request.jwt.claims',jsonb_build_object('sub','9f060000-0000-4000-8000-000000000103','session_id','9f060000-0000-4000-8000-000000000203','aal','aal1','role','authenticated')::text,true);
insert into fm values
 ('b_prepare',public.superadmin_form_media_prepare_v2(gen_random_uuid(),'9f060000-0000-4000-8000-000000000600','9f060000-0000-4000-8000-000000000601','9f060000-0000-4000-8000-000000000603','image/png',10,repeat('c',64))),
 ('b_auth',public.superadmin_form_media_authorize_finalize_v2((select asset_id from fm_ids))),
 ('b_resolve',public.superadmin_form_media_resolve_v2((select asset_id from fm_ids))),
 ('b_delete',public.superadmin_form_media_delete_v2(gen_random_uuid(),(select asset_id from fm_ids)));
select ok((select bool_and(body#>>'{error,code}'='FORM_MEDIA_NOT_FOUND') from fm where label like 'b\_%'),
  'outro tenant: prepare, authorize, resolve e delete respondem FORM_MEDIA_NOT_FOUND');

-- authorize_finalize pela autora e finalize errado/certo
select set_config('request.jwt.claims',jsonb_build_object('sub','9f060000-0000-4000-8000-000000000102','session_id','9f060000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
insert into fm values('auth',public.superadmin_form_media_authorize_finalize_v2((select asset_id from fm_ids)));
select ok((select body->>'ok'='true' and (body#>>'{data,finalize_ticket}')::uuid=(select ticket from fm_ids) from fm where label='auth'),'autora recebe o ticket');
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
insert into fm values('fin_bad',public.form_media_finalize_question_r2_v1((select asset_id from fm_ids),(select ticket from fm_ids),1000,repeat('f',64),100,100));
reset role;
select is((select body#>>'{error,code}' from fm where label='fin_bad'),'FORM_MEDIA_MISMATCH','sha diferente e FORM_MEDIA_MISMATCH');
select is((select status::text from public.media_assets where id=(select asset_id from fm_ids)),'deleted','asset com mismatch vira deleted');
select is((select reason from app_private.form_media_r2_cleanup where asset_id=(select asset_id from fm_ids)),'mismatch','chave entra na fila de limpeza');

-- segundo asset, finalize correto, resolve
select set_config('request.jwt.claims',jsonb_build_object('sub','9f060000-0000-4000-8000-000000000102','session_id','9f060000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
insert into fm values('prepare2',public.superadmin_form_media_prepare_v2('9f060000-0000-4000-8000-000000000902',
  '9f060000-0000-4000-8000-000000000600','9f060000-0000-4000-8000-000000000601','9f060000-0000-4000-8000-000000000603','image/jpeg',2048,repeat('d',64)));
create temporary table fm2 as select (body#>>'{data,asset_id}')::uuid asset_id,(body#>>'{data,finalize_ticket}')::uuid ticket from fm where label='prepare2';
grant select on fm2 to authenticated, service_role;
select is((select position from public.media_bindings where media_asset_id=(select asset_id from fm2)),0,'posicao reaproveitada apos o asset deletado');
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
insert into fm values('fin_ok',public.form_media_finalize_question_r2_v1((select asset_id from fm2),(select ticket from fm2),2048,repeat('d',64),640,480));
insert into fm values('fin_again',public.form_media_finalize_question_r2_v1((select asset_id from fm2),(select ticket from fm2),2048,repeat('d',64),640,480));
reset role;
select is((select body#>>'{data,status}' from fm where label='fin_ok'),'ready','finalize correto deixa ready');
select is((select body#>>'{error,code}' from fm where label='fin_again'),'FORM_MEDIA_TICKET_INVALID','ticket nao reutilizavel');
select ok(exists (select 1 from public.media_variants v where v.media_asset_id=(select asset_id from fm2) and v.rendition='original'
  and v.byte_size=2048 and v.pixel_width=640),'variante original registrada com as medidas');
select set_config('request.jwt.claims',jsonb_build_object('sub','9f060000-0000-4000-8000-000000000102','session_id','9f060000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into fm values('prepare_legacy',public.superadmin_form_media_prepare_v2('9f060000-0000-4000-8000-000000000907',
  '9f060000-0000-4000-8000-000000000610','9f060000-0000-4000-8000-000000000611','9f060000-0000-4000-8000-000000000613','image/png',3072,repeat('1',64)));
reset role;
create temporary table fmlegacy as select (body#>>'{data,asset_id}')::uuid asset_id,(body#>>'{data,finalize_ticket}')::uuid ticket from fm where label='prepare_legacy';
grant select on fmlegacy to authenticated, service_role;
select is((select body->>'ok' from fm where label='prepare_legacy'),'true','prepare aceita autoria people-based do mesmo ator interno autorizado');
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
insert into fm values('fin_legacy',public.form_media_finalize_question_r2_v1((select asset_id from fmlegacy),(select ticket from fmlegacy),3072,repeat('1',64),800,600));
reset role;
select is((select body#>>'{data,status}' from fm where label='fin_legacy'),'ready','question-image produtiva finaliza no catalogo privado');
select set_config('request.jwt.claims',jsonb_build_object('sub','9f060000-0000-4000-8000-000000000102','session_id','9f060000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into fm values('editor_media',public.form_get_editor('9f060000-0000-4000-8000-000000000610'));
insert into fm values('save_after_media',public.form_save_draft(
  '9f060000-0000-4000-8000-000000000906',
  1,
  jsonb_build_object(
    'id','9f060000-0000-4000-8000-000000000610',
    'institution_id','9f060000-0000-4000-8000-000000000010',
    'kind','form','identity_mode','identified','response_unit','person',
    'title','Form imagens revisado','description',null,
    'sections',jsonb_build_array(jsonb_build_object(
      'id','9f060000-0000-4000-8000-000000000612','title','Secao revisada',
      'description',null,'position',0,'items',jsonb_build_array(
        jsonb_build_object(
          'id','novo-texto','kind','short_text','label','Texto novo',
          'help_text',null,'position',0,'is_required',false,
          'config','{}'::jsonb,'options','[]'::jsonb,'conditions','[]'::jsonb
        ),
        jsonb_build_object(
          'id','9f060000-0000-4000-8000-000000000613','kind','photo',
          'label','Foto revisada','help_text',null,'position',1,'is_required',false,
          'config','{}'::jsonb,'options','[]'::jsonb,'conditions','[]'::jsonb
        )
      )
    ))
  )
));
insert into fm values('editor_after_save',public.form_get_editor('9f060000-0000-4000-8000-000000000610'));
insert into fm values('resolve',public.superadmin_form_media_resolve_v2((select asset_id from fmlegacy)));
reset role;
select ok((select body#>>'{media_context,form_version_id}'='9f060000-0000-4000-8000-000000000611'
  and body#>>'{media_context,question_images,0,asset_id}'=(select asset_id::text from fmlegacy)
  and body#>>'{media_context,question_images,0,item_id}'='9f060000-0000-4000-8000-000000000613'
  from fm where label='editor_media'),'editor interno expoe somente ids/status da question-image autorizada');
select is((select body->>'title' from fm where label='save_after_media'),'Form imagens revisado','salvar texto depois do upload preserva o rascunho');
select ok((select body#>>'{media_context,question_images,0,asset_id}'=(select asset_id::text from fmlegacy)
  and body#>>'{media_context,question_images,0,item_id}'='9f060000-0000-4000-8000-000000000613'
  and body#>>'{definition,sections,0,items,1,id}'='9f060000-0000-4000-8000-000000000613'
  from fm where label='editor_after_save'),'reorder preserva binding pelo item_id autoritativo, nunca pela posicao');
select throws_like($$
  select app_private.form_replace_working_definition(
    '9f060000-0000-4000-8000-000000000611',
    '[{"id":"secao-sem-foto","title":"Secao","description":null,"position":0,"items":[{"id":"texto-restante","kind":"short_text","label":"Texto","help_text":null,"position":0,"is_required":false,"config":{},"options":[],"conditions":[]}]}]'::jsonb
  )
$$,'%media_bindings_item_id_fkey%','remover pergunta com imagem falha fechado ate excluir a midia');
select ok(exists(select 1 from public.media_bindings where media_asset_id=(select asset_id from fm2)
  and item_id='9f060000-0000-4000-8000-000000000603')
  and exists(select 1 from public.media_bindings where media_asset_id=(select asset_id from fmlegacy)
  and item_id='9f060000-0000-4000-8000-000000000613'),'falha de remocao preserva item e binding sem associacao indevida');
update public.forms set working_version_id=null where id='9f060000-0000-4000-8000-000000000610';
set local role authenticated;
insert into fm values('editor_without_working',public.form_get_editor('9f060000-0000-4000-8000-000000000610'));
reset role;
select is((select body->'media_context' from fm where label='editor_without_working'),'null'::jsonb,
  'editor sem working version devolve media_context nulo');
select ok((select body->>'ok'='true' and body#>>'{data,object_key}' like 'tenants/%' and (body#>>'{data,ttl_seconds}')::int=300 from fm where label='resolve'),
  'resolve devolve chave e ttl para o gateway');
set local role authenticated;
insert into fm values('delete',public.superadmin_form_media_delete_v2('9f060000-0000-4000-8000-000000000903',(select asset_id from fm2)));
insert into fm values('delete2',public.superadmin_form_media_delete_v2('9f060000-0000-4000-8000-000000000904',(select asset_id from fm2)));
reset role;
select ok((select body->>'ok'='true' and (body#>>'{data,replayed}')::boolean=false from fm where label='delete')
  and (select (body#>>'{data,replayed}')::boolean from fm where label='delete2'),'delete exclui e a repeticao e idempotente');
select is((select status::text from public.media_assets where id=(select asset_id from fm2)),'deleted','asset excluido');

-- expire e limpeza
select set_config('request.jwt.claims',jsonb_build_object('sub','9f060000-0000-4000-8000-000000000102','session_id','9f060000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
insert into fm values('prepare3',public.superadmin_form_media_prepare_v2('9f060000-0000-4000-8000-000000000905',
  '9f060000-0000-4000-8000-000000000600','9f060000-0000-4000-8000-000000000601','9f060000-0000-4000-8000-000000000603','image/webp',10,repeat('e',64)));
update app_private.form_media_upload_tickets set expires_at=now()-interval '1 minute' where asset_id=(select (body#>>'{data,asset_id}')::uuid from fm where label='prepare3');
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
insert into fm values('expire',public.form_media_expire_question_r2_v1(100));
insert into fm values('claim',public.form_media_claim_cleanup_r2_v1(50));
reset role;
select is((select (body#>>'{data,expired}')::int from fm where label='expire'),1,'expire marca o pendente vencido');
select is((select jsonb_array_length(body->'data'->'items') from fm where label='claim'),3,'fila de limpeza entrega as 3 chaves (mismatch, deleted, expired)');
set local role authenticated;
select throws_like($$select public.form_media_expire_question_r2_v1(100)$$,'%permission denied%','authenticated nao expira (negado no privilegio)');
reset role;

select ok((select count(*)>=5 from audit.audit_logs where action_code like 'forms.media.%' and institution_id='9f060000-0000-4000-8000-000000000010'),
  'prepare, finalize, resolve e delete auditados');

select * from finish();
rollback;
