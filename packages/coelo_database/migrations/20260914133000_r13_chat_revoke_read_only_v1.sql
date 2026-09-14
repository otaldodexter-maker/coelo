-- R13 / ADR 0038 H06: revogar mensagem e proibido no servidor quando a conversa
-- e somente leitura (historico congelado). O cliente ja escondia o botao; agora a RPC
-- devolve CHAT_READ_ONLY antes de qualquer alteracao. Demais regras inalteradas.
create or replace function public.superadmin_chat_revoke_message_v2(
 p_conversation_id uuid,p_message_id uuid,p_request_id uuid
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 institution uuid; read_only boolean; request_hash bytea; prior record; target public.messages%rowtype; code text;
begin begin
 select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.manage');
 if p_conversation_id is null or p_message_id is null or p_request_id is null then
  raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;
 select institution_id,is_read_only into institution,read_only from public.conversations where id=p_conversation_id
   and (ctx.scope_kind<>'institution' or institution_id=ctx.scope_institution_id);
 if institution is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
 if read_only then raise object_not_in_prerequisite_state using detail='CHAT_READ_ONLY'; end if;
 perform pg_advisory_xact_lock(hashtextextended(ctx.internal_identity_id::text||p_request_id::text,0));
 request_hash:=extensions.digest(convert_to(jsonb_build_object('op','revoke',
   'message_id',p_message_id)::text,'UTF8'),'sha256');
 select * into prior from app_private.superadmin_internal_chat_command_receipts receipt
  where receipt.internal_identity_id=ctx.internal_identity_id and receipt.request_id=p_request_id for update;
 if prior.request_id is not null then
  if prior.request_hash<>request_hash then raise unique_violation using detail='CHAT_REPLAY_MISMATCH'; end if;
  select * into target from public.messages where id=prior.message_id;
 else
  select * into target from public.messages
   where id=p_message_id and conversation_id=p_conversation_id for update;
  if target.id is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
  if target.author_kind<>'superadmin_internal'
    or target.author_internal_identity_id is distinct from ctx.internal_identity_id then
   raise insufficient_privilege using detail='CHAT_NOT_AUTHOR'; end if;
  if target.status<>'active' or target.deleted_at is not null then
   raise object_not_in_prerequisite_state using detail='CHAT_ALREADY_REVOKED'; end if;
  update public.messages set status='archived',deleted_at=now(),updated_at=now()
   where id=target.id returning * into target;
  insert into app_private.superadmin_internal_chat_command_receipts(
    request_id,internal_identity_id,conversation_id,request_hash,message_id)
  values(p_request_id,ctx.internal_identity_id,p_conversation_id,request_hash,target.id);
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
    ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'chat.internal.manage',ctx.aal,'chat.message.revoke','success',null,correlation,
    institution,'message',target.id);
 end if;
 return app_private.superadmin_chat_success(jsonb_build_object(
  'message_id',target.id,'revoked_at',target.deleted_at,
  'replayed',prior.request_id is not null));
exception when others then get stacked diagnostics code=pg_exception_detail;
 code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 perform app_private.audit_superadmin_internal_denial_if_identified(
  'chat.internal.manage','chat.message.revoke',code,correlation,institution);
 return app_private.superadmin_chat_error(code,correlation); end $$;


revoke all on function public.superadmin_chat_revoke_message_v2(uuid,uuid,uuid) from public, anon;
grant execute on function public.superadmin_chat_revoke_message_v2(uuid,uuid,uuid) to authenticated;
