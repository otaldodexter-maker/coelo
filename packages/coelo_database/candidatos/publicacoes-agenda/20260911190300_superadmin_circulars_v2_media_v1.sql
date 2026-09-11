-- 20260911190300_superadmin_circulars_v2_media_v1
--
-- Anexos no gateway interno v2 de Circulares (circulars.attach, R05
-- publicacoes-agenda, 11/09/2026). Ate aqui superadmin_circular_save_draft_v2
-- recusava qualquer bloco 'media' (CIRCULAR_MEDIA_BLOCKED) e
-- superadmin_circular_publish_v2 recusava revisao com circular_media_links:
-- o anexo era enviado ao R2 (prepare -> PUT -> finalize) e o rascunho nao
-- conseguia referencia-lo. Com 20260911190200 (R2 para Circulares) e
-- 20260911190000 (ponte de ator), o fluxo completo fica autorizado.
--
-- O que muda (texto de 200400/200100 preservado, so os trechos abaixo):
--   save_draft_v2: aceita blocos 'media' com ate 4 asset_ids; cada asset deve
--     pertencer a esta circular e instituicao e estar 'ready'; senao
--     CIRCULAR_MEDIA_BLOCKED (sem vazar existencia). Regrava
--     circular_media_links da revisao de trabalho a cada save.
--   superadmin_circular_draft_json: devolve os asset_ids dos links (antes '[]').
--   publish_v2: deixa de recusar revisao com midia.
-- Leitura do arquivo continua exclusivamente pela Edge Function circular-media
-- (authorize_circular_media_read: circular visivel ao ator). Forward-only.

begin;

create or replace function app_private.superadmin_circular_draft_json(
  p_target public.circulars,p_revision public.circular_revisions
) returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object(
 'id',p_target.id,'version',p_target.management_version,'revision_id',p_revision.id,
 'title',p_revision.title,'status',p_target.status::text,
 'response_policy',p_target.response_policy::text,
 'responses_close_at',p_target.responses_close_at,
 'blocks',(select coalesce(jsonb_agg(case block_record.block_kind
   when 'text' then jsonb_build_object('id',block_record.id,'kind','text','text',block_record.text_content)
   when 'media' then jsonb_build_object('id',block_record.id,'kind','media','asset_ids',
     (select coalesce(jsonb_agg(link.media_asset_id order by link.display_order),'[]'::jsonb)
      from public.circular_media_links link where link.revision_id=p_revision.id and link.block_id=block_record.id))
   else jsonb_build_object('id',block_record.id,'kind','question','question',(
     select jsonb_build_object('id',question_record.id,'prompt',question_record.prompt,
       'kind',question_record.question_kind::text,'required',question_record.required,
       'options',(select coalesce(jsonb_agg(jsonb_build_object('id',option_record.id,
         'label',option_record.label) order by option_record.display_order),'[]'::jsonb)
        from public.circular_question_options option_record
        where option_record.question_id=question_record.id))
     from public.circular_questions question_record where question_record.block_id=block_record.id))
   end order by block_record.display_order),'[]'::jsonb)
   from public.circular_blocks block_record where block_record.revision_id=p_revision.id),
 'audiences',(select coalesce(jsonb_agg(distinct audience_record.audience_kind::text),'[]'::jsonb)
   from public.circular_audience_rules audience_record where audience_record.circular_id=p_target.id))
$$;

create or replace function public.superadmin_circular_save_draft_v2(
 p_request_id uuid,p_institution_id uuid,p_unit_id uuid,p_group_id uuid,p_activity_id uuid,p_payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 target public.circulars%rowtype; revision public.circular_revisions%rowtype;
 target_circular_id uuid:=nullif(p_payload->>'id','')::uuid; expected bigint:=coalesce((p_payload->>'version')::bigint,0);
 block jsonb; question jsonb; option jsonb; audience text; asset_id uuid; body text:=''; position int; option_position int;
 hash bytea:=extensions.digest(convert_to(coalesce(p_payload,'{}')::text,'UTF8'),'sha256');
 prior record; result jsonb; code text;
begin begin
 ctx:=app_private.superadmin_circular_context('circulars.manage',p_institution_id);
 perform app_private.superadmin_circular_validate_scope(p_institution_id,p_unit_id,p_group_id,p_activity_id);
 select * into prior from app_private.superadmin_circular_command_receipts receipt
  where receipt.internal_identity_id=ctx.internal_identity_id and receipt.request_id=p_request_id and receipt.action_code='save';
 if prior.result_json is not null then
  if prior.request_hash<>hash then raise unique_violation using detail='CIRCULAR_CONFLICT'; end if;
  return jsonb_build_object('ok',true,'data',prior.result_json,'error',null);
 end if;
 if jsonb_typeof(p_payload)<>'object' or char_length(btrim(coalesce(p_payload->>'title',''))) not between 1 and 120
  or p_payload->>'response_policy' not in ('per_person','per_child_any_guardian','per_child_each_guardian','per_staff_member')
  or jsonb_typeof(coalesce(p_payload->'blocks','[]'))<>'array'
  or jsonb_array_length(coalesce(p_payload->'blocks','[]'))>64
  or (select count(*) from jsonb_array_elements(coalesce(p_payload->'blocks','[]')) item
      where item->>'kind'='question')>10
  or jsonb_typeof(coalesce(p_payload->'audiences','[]'))<>'array' then
  raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT';
 end if;
 for block in select value from jsonb_array_elements(coalesce(p_payload->'blocks','[]')) loop
  if block->>'kind'='text' then body:=body||coalesce(block->>'text',''); end if;
  if block->>'kind' not in ('text','question','media') then raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT'; end if;
  if block->>'kind'='media' and (jsonb_typeof(coalesce(block->'asset_ids','[]'))<>'array'
   or jsonb_array_length(coalesce(block->'asset_ids','[]'))>4) then
   raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT';
  end if;
 end loop;
 if char_length(body)>10000 then raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT'; end if;
 if target_circular_id is null then
  insert into public.circulars(institution_id,unit_id,group_id,activity_id,
   author_internal_identity_id,author_internal_membership_id,response_policy,responses_close_at)
  values(p_institution_id,p_unit_id,p_group_id,p_activity_id,ctx.internal_identity_id,
   ctx.internal_membership_id,(p_payload->>'response_policy')::public.circular_response_policy,
   nullif(p_payload->>'responses_close_at','')::timestamptz) returning * into target;
  insert into public.circular_revisions(circular_id,institution_id,revision_number,title,body_text,
   created_by_internal_identity_id) values(target.id,p_institution_id,1,btrim(p_payload->>'title'),body,
   ctx.internal_identity_id) returning * into revision;
 else
  select * into target from public.circulars c where c.id=target_circular_id and c.institution_id=p_institution_id
   and c.deleted_at is null for update;
  if target.id is null then raise no_data_found using detail='CIRCULAR_NOT_FOUND'; end if;
  if target.management_version<>expected or target.status in ('closed','archived') then
   raise serialization_failure using detail=case when target.management_version<>expected then 'CIRCULAR_CONFLICT' else 'CIRCULAR_INVALID_STATE' end;
  end if;
  if target.working_revision_id is null then
   insert into public.circular_revisions(circular_id,institution_id,revision_number,title,body_text,
    created_by_internal_identity_id) values(target.id,p_institution_id,
    (select coalesce(max(r.revision_number),0)+1 from public.circular_revisions r where r.circular_id=target.id),
    btrim(p_payload->>'title'),body,ctx.internal_identity_id) returning * into revision;
  else
   select * into revision from public.circular_revisions r where r.id=target.working_revision_id and r.status='working';
   if revision.id is null then raise invalid_parameter_value using detail='CIRCULAR_INVALID_STATE'; end if;
   update public.circular_revisions set title=btrim(p_payload->>'title'),body_text=body where id=revision.id;
   delete from public.circular_media_links where revision_id=revision.id;
   delete from public.circular_blocks where revision_id=revision.id;
  end if;
  delete from public.circular_audience_rules where circular_id=target.id;
  update public.circulars set response_policy=(p_payload->>'response_policy')::public.circular_response_policy,
   responses_close_at=nullif(p_payload->>'responses_close_at','')::timestamptz,
   management_version=management_version+1,updated_at=clock_timestamp() where id=target.id returning * into target;
 end if;
 update public.circulars set working_revision_id=revision.id where id=target.id;
 position:=0;
 for block in select value from jsonb_array_elements(coalesce(p_payload->'blocks','[]')) loop
  insert into public.circular_blocks(id,revision_id,block_kind,display_order,text_content)
  values((block->>'id')::uuid,revision.id,(block->>'kind')::public.circular_block_kind,position,
   case when block->>'kind'='text' then coalesce(block->>'text','') end);
  if block->>'kind'='question' then
   question:=coalesce(block->'question',block);
   if char_length(btrim(coalesce(question->>'prompt',''))) not between 1 and 240
    or question->>'kind' not in ('single_choice','multiple_choice')
    or jsonb_array_length(coalesce(question->'options','[]')) not between 2 and 10 then
    raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT';
   end if;
   insert into public.circular_questions(id,revision_id,block_id,question_kind,prompt,required)
   values((question->>'id')::uuid,revision.id,(block->>'id')::uuid,
    (question->>'kind')::public.circular_question_kind,btrim(question->>'prompt'),
    coalesce((question->>'required')::boolean,false));
   option_position:=0;
   for option in select value from jsonb_array_elements(question->'options') loop
    insert into public.circular_question_options(id,question_id,label,display_order)
    values((option->>'id')::uuid,(question->>'id')::uuid,btrim(option->>'label'),option_position);
    option_position:=option_position+1;
   end loop;
  end if;
  if block->>'kind'='media' then
   -- Cada asset precisa pertencer a ESTA circular, estar finalizado (ready) e
   -- nao excluido; qualquer outro id e CIRCULAR_MEDIA_BLOCKED (nao vaza existencia).
   for asset_id in select value::uuid from jsonb_array_elements_text(coalesce(block->'asset_ids','[]')) loop
    if not exists(select 1 from public.circular_media_assets asset where asset.id=asset_id
      and asset.circular_id=target.id and asset.institution_id=p_institution_id and asset.status='ready') then
     raise invalid_parameter_value using detail='CIRCULAR_MEDIA_BLOCKED';
    end if;
    insert into public.circular_media_links(revision_id,block_id,media_asset_id,display_order)
    values(revision.id,(block->>'id')::uuid,asset_id,
     (select count(*)::smallint from public.circular_media_links link where link.revision_id=revision.id));
   end loop;
  end if;
  position:=position+1;
 end loop;
 for audience in select value from jsonb_array_elements_text(coalesce(p_payload->'audiences','[]')) loop
  if audience not in ('families','students','school_staff','guardians_only') then
   raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT';
  end if;
  insert into public.circular_audience_rules(circular_id,revision_id,institution_id,audience_kind,scope_kind,
   unit_id,group_id,activity_id) values(target.id,revision.id,p_institution_id,
   audience::public.circular_audience_kind,
   case when p_activity_id is not null then 'activity' when p_group_id is not null then 'group'
    when p_unit_id is not null then 'unit' else 'institution' end::public.circular_scope_kind,
   case when p_activity_id is null then p_unit_id end,
   case when p_activity_id is null then p_group_id end,p_activity_id);
 end loop;
 result:=jsonb_build_object('id',target.id,'revision_id',revision.id,
  'version',target.management_version,'status',target.status::text);
 insert into app_private.superadmin_circular_command_receipts
  values(ctx.internal_identity_id,p_request_id,'save',hash,result,clock_timestamp());
 insert into app_private.circular_audit(circular_id,revision_id,institution_id,
  actor_internal_identity_id,event_code,detail) values(target.id,revision.id,p_institution_id,
  ctx.internal_identity_id,'internal_draft_saved',jsonb_build_object('version',target.management_version));
 perform app_private.superadmin_circular_audit(ctx,'save',target.id,'success','saved',correlation);
 return jsonb_build_object('ok',true,'data',result,'error',null);
exception when others then get stacked diagnostics code=pg_exception_detail;
 return app_private.superadmin_circular_denied('circulars.manage','save',code,correlation); end; end
$$;

create or replace function public.superadmin_circular_publish_v2(
 p_request_id uuid,p_circular_id uuid,p_expected_version bigint,p_publish_at timestamptz default null
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 target public.circulars%rowtype; revision public.circular_revisions%rowtype; result jsonb; prior record;
 at timestamptz:=coalesce(p_publish_at,clock_timestamp()); code text;
 hash bytea:=extensions.digest(convert_to(p_circular_id::text||p_expected_version::text||coalesce(p_publish_at::text,'now'),'UTF8'),'sha256');
begin begin
 select * into target from public.circulars c where c.id=p_circular_id and c.deleted_at is null for update;
 if target.id is null then raise no_data_found using detail='CIRCULAR_NOT_FOUND'; end if;
 ctx:=app_private.superadmin_circular_context('circulars.publish',target.institution_id);
 select * into prior from app_private.superadmin_circular_command_receipts receipt
  where receipt.internal_identity_id=ctx.internal_identity_id and receipt.request_id=p_request_id and receipt.action_code='publish';
 if prior.result_json is not null then
  if prior.request_hash<>hash then raise unique_violation using detail='CIRCULAR_CONFLICT'; end if;
  return jsonb_build_object('ok',true,'data',prior.result_json,'error',null);
 end if;
 if target.management_version<>p_expected_version then raise serialization_failure using detail='CIRCULAR_CONFLICT'; end if;
 if target.working_revision_id is null or target.status in ('closed','archived')
  or not exists(select 1 from public.circular_audience_rules a where a.circular_id=target.id) then
  raise invalid_parameter_value using detail='CIRCULAR_INVALID_STATE';
 end if;
 -- Midia liberada (20260911190300): os links da revisao ja foram validados no save
 -- (asset desta circular, ready, nao excluido).
 select * into revision from public.circular_revisions r where r.id=target.working_revision_id and r.status='working';
 update public.circular_revisions set status='superseded' where circular_id=target.id and status='published';
 update public.circular_revisions set status='published',published_at=clock_timestamp() where id=revision.id;
 update public.circulars set status=case when at>clock_timestamp() then 'scheduled' else 'published' end::public.circular_status,
  current_revision_id=revision.id,working_revision_id=null,publish_at=at,
  published_at=case when at<=clock_timestamp() then coalesce(published_at,clock_timestamp()) else published_at end,
  revised_at=case when published_at is not null then clock_timestamp() end,
  management_version=management_version+1,updated_at=clock_timestamp()
 where id=target.id returning * into target;
 result:=jsonb_build_object('id',target.id,'revision_id',revision.id,'version',target.management_version,'status',target.status::text);
 insert into app_private.superadmin_circular_command_receipts values(ctx.internal_identity_id,p_request_id,'publish',hash,result,clock_timestamp());
 insert into app_private.circular_audit(circular_id,revision_id,institution_id,actor_internal_identity_id,event_code,detail)
 values(target.id,revision.id,target.institution_id,ctx.internal_identity_id,'internal_published',jsonb_build_object('publish_at',at));
 perform app_private.superadmin_circular_audit(ctx,'publish',target.id,'success','published',correlation);
 return jsonb_build_object('ok',true,'data',result,'error',null);
exception when others then get stacked diagnostics code=pg_exception_detail;
 return app_private.superadmin_circular_denied('circulars.publish','publish',code,correlation); end; end
$$;

commit;
