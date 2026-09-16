-- R14 Bloco E / owner.r12-52: explicita a identidade de catalogo do anexo.
-- chat_attachment_metadata.id continua sendo a unica identidade de ownership;
-- o envelope usa o nome asset_id sem criar um segundo catalogo.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'chat asset binding migration must run as postgres';
  end if;
  if to_regprocedure('public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer)') is null
    or to_regprocedure('app_private.require_superadmin_internal_context(text)') is null then
    raise object_not_in_prerequisite_state using message = 'chat thread v2 and internal context are required';
  end if;
end
$preflight$;

create or replace function public.superadmin_chat_thread_v2(
  p_conversation_id uuid, p_cursor_created_at timestamptz default null,
  p_cursor_message_id uuid default null, p_limit integer default 50
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
  result jsonb; code text; institution uuid;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.read');
    if p_conversation_id is null or p_limit is null or p_limit not between 1 and 100
      or (p_cursor_created_at is null)<>(p_cursor_message_id is null) then
      raise invalid_parameter_value using detail='CHAT_INVALID_INPUT';
    end if;
    select institution_id into institution from public.conversations where id=p_conversation_id
      and (ctx.scope_kind<>'institution' or institution_id=ctx.scope_institution_id);
    if institution is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
    with filtered as (
      select message_row.* from public.messages message_row
      where message_row.conversation_id=p_conversation_id and message_row.status='active'
        and message_row.deleted_at is null and (p_cursor_created_at is null
          or (message_row.created_at,message_row.id)<(p_cursor_created_at,p_cursor_message_id))
    ), page as (select * from filtered order by created_at desc,id desc limit p_limit+1)
    select jsonb_build_object(
      'items',coalesce((select jsonb_agg(jsonb_build_object(
        'message_id',item.id,'body_text',coalesce(item.body_text,''),'message_type',item.message_type,
        'created_at',item.created_at,'updated_at',item.updated_at,
        'author_name',case when item.author_kind='superadmin_internal' then 'Equipe Coelo'
          else coalesce((select person.display_name from public.people person where person.id=item.author_person_id),'') end,
        'is_mine',item.author_internal_identity_id=ctx.internal_identity_id,
        'edited_at',(select max(edit.edited_at) from app_private.superadmin_internal_chat_message_edits edit where edit.message_id=item.id),
        'can_manage',coalesce(item.author_internal_identity_id=ctx.internal_identity_id,false),
        'receipt',app_private.superadmin_chat_message_receipt(item.id,p_conversation_id,
          coalesce(item.author_internal_identity_id=ctx.internal_identity_id,false),ctx.internal_identity_id),
        'attachments',coalesce((select jsonb_agg(jsonb_build_object(
          'id',attachment.id,'asset_id',attachment.id,'file_name',attachment.file_name,
          'content_type',attachment.content_type,'byte_size',attachment.byte_size,
          'sha256',attachment.sha256,'upload_status',attachment.upload_status)
          order by attachment.created_at) from public.chat_attachment_metadata attachment
          where attachment.message_id=item.id),'[]'::jsonb))
        order by item.created_at desc,item.id desc) from(select * from page limit p_limit)item),'[]'::jsonb),
      'total',(select count(*) from public.messages message_row where message_row.conversation_id=p_conversation_id
        and message_row.status='active' and message_row.deleted_at is null),
      'has_more',(select count(*)>p_limit from page),
      'next_cursor',case when (select count(*) from page)>p_limit then
        (select jsonb_build_object('timestamp',item.created_at,'id',item.id)
          from(select * from page limit p_limit)item order by item.created_at,item.id limit 1) else null end
    ) into result;
    return app_private.superadmin_chat_success(result);
  exception when others then
    get stacked diagnostics code=pg_exception_detail;
    code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR');
  end;
  perform app_private.audit_superadmin_internal_denial_if_identified(
    'chat.internal.read','chat.thread',code,correlation,institution);
  return app_private.superadmin_chat_error(code,correlation);
end $$;

alter function public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer) owner to postgres;
revoke all on function public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer) to authenticated;
commit;
