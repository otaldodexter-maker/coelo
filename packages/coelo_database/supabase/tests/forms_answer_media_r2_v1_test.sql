-- answer-image no R2: prepare (legado + espelho), descritor, finalize, discard e leitura pela RPC de 230011.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);
create function pg_temp.aid(n integer) returns uuid language sql immutable as $$
  select ('8c0a0000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.aid(integer) to service_role;
insert into public.institution_types(id,code,name,status) values (pg_temp.aid(1),'answer-media-test','Answer media','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status) values (pg_temp.aid(10),pg_temp.aid(1),'Answer media A','answer-media-a','active');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values (pg_temp.aid(1000),'adult','Resp','Onde','Respondente','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
values (pg_temp.aid(101),'authenticated','authenticated','answer-media@invalid.test',now(),now(),now(),'{}','{}');
insert into public.person_auth_links(person_id,auth_user_id,status) values (pg_temp.aid(1000),pg_temp.aid(101),'active');
insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_person_id,updated_by_person_id)
values (pg_temp.aid(210),pg_temp.aid(10),'form','identified','person','Form respostas',pg_temp.aid(1000),pg_temp.aid(1000));
insert into public.form_versions(id,form_id,version_number,created_by_person_id) values (pg_temp.aid(1210),pg_temp.aid(210),1,pg_temp.aid(1000));
insert into public.form_sections(id,form_version_id,title,position) values (pg_temp.aid(2210),pg_temp.aid(1210),'Secao',0);
insert into public.form_items(id,form_version_id,section_id,kind,label,position) values (pg_temp.aid(3210),pg_temp.aid(1210),pg_temp.aid(2210),'photo','Foto',0);
insert into public.form_applications(id,form_id,institution_id,name,created_by_person_id) values (pg_temp.aid(4210),pg_temp.aid(210),pg_temp.aid(10),'App',pg_temp.aid(1000));
insert into public.form_schedules(id,application_id,time_zone,starts_at_local,recurrence_kind) values (pg_temp.aid(5210),pg_temp.aid(4210),'UTC','2026-09-08 00:00:00','once');
insert into public.form_occurrences(id,application_id,schedule_id,institution_id,form_id,form_version_id,scheduled_local,time_zone,opens_at,closes_at)
values (pg_temp.aid(6210),pg_temp.aid(4210),pg_temp.aid(5210),pg_temp.aid(10),pg_temp.aid(210),pg_temp.aid(1210),'2026-09-08 00:00:00','UTC',now()-interval '1 day',now()+interval '1 day');

-- form_assets preparado (o legado form_prepare_asset_upload exige participacao elegivel; aqui o espelho e provado direto)
insert into public.form_assets(id,institution_id,occurrence_id,item_id,prepared_by_person_id,storage_path,mime_type,expected_byte_length,expected_checksum_sha256,state)
values (pg_temp.aid(9210),pg_temp.aid(10),pg_temp.aid(6210),pg_temp.aid(3210),pg_temp.aid(1000),'8c/'||pg_temp.aid(9210),'image/png',1000,repeat('a',64),'prepared');
select ok(has_function_privilege('authenticated','public.form_prepare_asset_upload_r2_v1(uuid,bigint,jsonb)','execute')
  and not has_function_privilege('authenticated','public.form_asset_r2_descriptor_v1(uuid)','execute')
  and has_function_privilege('service_role','public.form_media_finalize_answer_r2_v1(uuid,bigint,text,integer,integer)','execute'),
  'grants: prepare para authenticated; descritor e finalize para service_role');

-- espelho
select is((select count(*) from public.media_assets where source_form_asset_id=pg_temp.aid(9210)),0::bigint,'sem gatilho: form_assets a mao nao cria espelho (suites legadas intactas)');
select lives_ok($$select app_private.form_assets_answer_media_mirror_v1(pg_temp.aid(9210))$$,'espelho criado pelo wrapper');
select ok((select a.status='pending' and a.media_purpose='answer-image' and a.owner_person_id=pg_temp.aid(1000)
  and a.object_key ~ ('^tenants/'||pg_temp.aid(10)||'/forms/form/'||pg_temp.aid(210)||'/answer-image/[0-9a-f-]{36}/original/[0-9a-f-]{36}[.]png$')
  from public.media_assets a where a.source_form_asset_id=pg_temp.aid(9210)),'espelho pending com dono e chave na convencao');
select is((select count(*) from public.media_bindings b join public.media_assets a on a.id=b.media_asset_id where a.source_form_asset_id=pg_temp.aid(9210) and b.purpose='answer-image'),1::bigint,'binding answer-image criado');
select ok((select id=(select id from public.media_assets where source_form_asset_id=pg_temp.aid(9210)) from app_private.form_assets_answer_media_mirror_v1(pg_temp.aid(9210))),'espelhar de novo e idempotente');

-- descritor e finalize (service_role)
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
reset role;
create temporary table am(label text primary key, body jsonb not null);
grant select,insert on am to service_role;
set local role service_role;
insert into am values('desc',public.form_asset_r2_descriptor_v1(pg_temp.aid(9210)));
reset role;
select ok((select body->>'ok'='true' and body#>>'{data,bucket}'='coelo-media-prod' and (body#>>'{data,expected_byte_size}')::int=1000 and body#>>'{data,state}'='prepared' from am where label='desc'),'descritor devolve chave e esperados');
-- o usuario confirma o upload (legado) -> uploaded
update public.form_assets set state='uploaded' where id=pg_temp.aid(9210);
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
insert into am values('fin_bad',public.form_media_finalize_answer_r2_v1(pg_temp.aid(9210),1000,repeat('f',64),100,100));
reset role;
select is((select body#>>'{error,code}' from am where label='fin_bad'),'FORM_MEDIA_MISMATCH','sha diferente: mismatch');
select is((select state from public.form_assets where id=pg_temp.aid(9210)),'discarded','legado descartado pelo worker');
select is((select status::text from public.media_assets where source_form_asset_id=pg_temp.aid(9210)),'deleted','espelho apagado pelo gatilho de discard');
select is((select count(*) from app_private.form_media_r2_cleanup c join public.media_assets a on a.id=c.asset_id where a.source_form_asset_id=pg_temp.aid(9210)),1::bigint,'chave na fila de limpeza');

-- segundo asset: caminho feliz
insert into public.form_assets(id,institution_id,occurrence_id,item_id,prepared_by_person_id,storage_path,mime_type,expected_byte_length,expected_checksum_sha256,state)
values (pg_temp.aid(9211),pg_temp.aid(10),pg_temp.aid(6210),pg_temp.aid(3210),pg_temp.aid(1000),'8c/'||pg_temp.aid(9211),'image/png',2048,repeat('d',64),'uploaded');
create temporary table mirror2 as select (app_private.form_assets_answer_media_mirror_v1(pg_temp.aid(9211))).id;
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
insert into am values('fin_ok',public.form_media_finalize_answer_r2_v1(pg_temp.aid(9211),2048,repeat('d',64),640,480));
insert into am values('fin_again',public.form_media_finalize_answer_r2_v1(pg_temp.aid(9211),2048,repeat('d',64),640,480));
reset role;
select ok((select body->>'ok'='true' and body#>>'{data,media_status}'='ready' and body#>>'{data,state}'='finalized' from am where label='fin_ok'),'finalize correto: legado finalized e espelho ready');
select ok((select (body#>>'{data,replayed}')::boolean from am where label='fin_again'),'repetir o finalize e replay');
select ok(exists (select 1 from public.media_variants v join public.media_assets a on a.id=v.media_asset_id
  where a.source_form_asset_id=pg_temp.aid(9211) and v.rendition='original' and v.pixel_width=640 and v.byte_size=2048),'variante original gravada');

select * from finish();
rollback;
