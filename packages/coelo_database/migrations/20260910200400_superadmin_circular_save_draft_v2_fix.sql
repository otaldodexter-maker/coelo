-- Correcao forward-only de superadmin_circular_save_draft_v2 (aplicada em producao
-- em 20260910200100): a variavel plpgsql "circular_id" era ambigua com a coluna em
-- "delete from public.circular_audience_rules where circular_id=target.id" (42702),
-- derrubando toda edicao de rascunho com SAI_INTERNAL_ERROR. A variavel passa a
-- chamar-se target_circular_id; corpo, assinatura e grants inalterados.
-- Encontrado na prova em producao com a sessao qa-r03 (circulars.edit).
-- Grupo publicacoes-agenda, Rodada 4 (E2-R04-20260911).
begin;

do $preflight$
begin
  if current_user <> 'postgres'
    or to_regprocedure('public.superadmin_circular_save_draft_v2(uuid,uuid,uuid,uuid,uuid,jsonb)') is null
    or to_regprocedure('app_private.superadmin_circular_context(text,uuid)') is null then
    raise object_not_in_prerequisite_state using
      message = 'superadmin circulars v2 (20260910200100) is required';
  end if;
end
$preflight$;

create or replace function public.superadmin_circular_save_draft_v2(
 p_request_id uuid,p_institution_id uuid,p_unit_id uuid,p_group_id uuid,p_activity_id uuid,p_payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 target public.circulars%rowtype; revision public.circular_revisions%rowtype;
 target_circular_id uuid:=nullif(p_payload->>'id','')::uuid; expected bigint:=coalesce((p_payload->>'version')::bigint,0);
 block jsonb; question jsonb; option jsonb; audience text; body text:=''; position int; option_position int;
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
  if block->>'kind'='media' then raise invalid_parameter_value using detail='CIRCULAR_MEDIA_BLOCKED'; end if;
  if block->>'kind'='text' then body:=body||coalesce(block->>'text',''); end if;
  if block->>'kind' not in ('text','question') then raise invalid_parameter_value using detail='CIRCULAR_INVALID_INPUT'; end if;
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

alter function public.superadmin_circular_save_draft_v2(uuid,uuid,uuid,uuid,uuid,jsonb) owner to postgres;
revoke all on function public.superadmin_circular_save_draft_v2(uuid,uuid,uuid,uuid,uuid,jsonb) from public, anon, service_role;
grant execute on function public.superadmin_circular_save_draft_v2(uuid,uuid,uuid,uuid,uuid,jsonb) to authenticated;

commit;
