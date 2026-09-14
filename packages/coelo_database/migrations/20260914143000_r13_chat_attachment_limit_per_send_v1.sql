-- R13 / ADR 0038 (anexos por mensagem, opcao C): ate 10 anexos por envio, validado
-- no servidor em superadmin_chat_attachment_prepare_v1. O limite por arquivo continua o
-- da ADR 0032 e nao ha teto por conversa. Codigo novo CHAT_ATTACHMENT_LIMIT (422).

create or replace function app_private.superadmin_chat_error(p_code text,p_correlation_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select pg_catalog.jsonb_build_object('ok',false,'data',null,'error',
    pg_catalog.jsonb_build_object(
      'code',case when p_code in(
        'CHAT_INVALID_INPUT','CHAT_NOT_FOUND','CHAT_READ_ONLY','CHAT_REPLAY_MISMATCH',
        'CHAT_NOT_AUTHOR','CHAT_EDIT_WINDOW_CLOSED','CHAT_ALREADY_REVOKED',
        'CHAT_MEMBER_INVALID','CHAT_ATTACHMENT_INVALID','CHAT_ATTACHMENT_NOT_READY',
        'CHAT_ATTACHMENT_TICKET_INVALID','CHAT_ATTACHMENT_MISMATCH','CHAT_ATTACHMENT_LIMIT',
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
        'SAI_MFA_REQUIRED') then p_code else 'SAI_INTERNAL_ERROR' end,
      'message',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 'Autenticação necessária.'
        when p_code='SAI_MFA_REQUIRED' then 'Confirme o segundo fator.'
        when p_code='CHAT_INVALID_INPUT' then 'Revise os dados enviados.'
        when p_code='CHAT_NOT_FOUND' then 'Conversa não encontrada.'
        when p_code='CHAT_READ_ONLY' then 'Esta conversa é somente leitura.'
        when p_code='CHAT_REPLAY_MISMATCH' then 'A solicitação já foi usada com outros dados.'
        when p_code='CHAT_NOT_AUTHOR' then 'Só o autor pode alterar esta mensagem.'
        when p_code='CHAT_EDIT_WINDOW_CLOSED' then 'O prazo de edição desta mensagem terminou.'
        when p_code='CHAT_ALREADY_REVOKED' then 'Esta mensagem já foi revogada.'
        when p_code='CHAT_MEMBER_INVALID' then 'Um dos participantes não pertence a esta instituição.'
        when p_code='CHAT_ATTACHMENT_INVALID' then 'Arquivo não permitido: confira o tipo e o tamanho.'
        when p_code='CHAT_ATTACHMENT_NOT_READY' then 'O anexo ainda não terminou de ser enviado.'
        when p_code='CHAT_ATTACHMENT_TICKET_INVALID' then 'O envio expirou. Anexe o arquivo novamente.'
        when p_code='CHAT_ATTACHMENT_MISMATCH' then 'O arquivo recebido não confere com o anunciado.'
        when p_code='CHAT_ATTACHMENT_LIMIT' then 'Limite de 10 anexos por mensagem atingido.'
        when p_code like 'SAI_%DENIED' or p_code like 'SAI_MEMBERSHIP_%' then 'Acesso não autorizado.'
        else 'Não foi possível concluir a operação.' end,
      'http_status',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when p_code in('CHAT_INVALID_INPUT','CHAT_MEMBER_INVALID','CHAT_ATTACHMENT_INVALID',
          'CHAT_ATTACHMENT_MISMATCH','CHAT_ATTACHMENT_LIMIT') then 422
        when p_code='CHAT_NOT_FOUND' then 404
        when p_code in('CHAT_READ_ONLY','CHAT_REPLAY_MISMATCH','CHAT_EDIT_WINDOW_CLOSED',
          'CHAT_ALREADY_REVOKED','CHAT_ATTACHMENT_NOT_READY','CHAT_ATTACHMENT_TICKET_INVALID') then 409
        when p_code in('CHAT_NOT_AUTHOR','SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then 403
        else 500 end,
      'correlation_id',p_correlation_id))
$$;

create or replace function public.superadmin_chat_attachment_prepare_v1(
  p_request_id uuid, p_conversation_id uuid, p_file_name text, p_content_type text,
  p_byte_size bigint, p_sha256 text
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid := gen_random_uuid();
  institution uuid; read_only boolean; code text;
  actor_person uuid; limit_bytes bigint; request_hash bytea;
  prior app_private.superadmin_internal_chat_attachment_tickets%rowtype;
  attachment public.chat_attachment_metadata%rowtype;
  created_message public.messages%rowtype;
  file_name text := btrim(coalesce(p_file_name, ''));
  content_type text := lower(btrim(coalesce(p_content_type, '')));
  sha text := lower(btrim(coalesce(p_sha256, '')));
  new_attachment_id uuid := gen_random_uuid();
  object_key text; ticket_expiry timestamptz := now() + interval '30 minutes';
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.send');
    if p_request_id is null or p_conversation_id is null then
      raise invalid_parameter_value using detail='CHAT_INVALID_INPUT';
    end if;
    limit_bytes := app_private.chat_attachment_limit_v1(content_type);
    if limit_bytes is null or file_name = '' or char_length(file_name) > 255
      or file_name ~ '[[:cntrl:]/\\]' or p_byte_size is null or p_byte_size < 1
      or p_byte_size > limit_bytes or sha !~ '^[0-9a-f]{64}$' then
      raise invalid_parameter_value using detail='CHAT_ATTACHMENT_INVALID';
    end if;
    select institution_id, is_read_only into institution, read_only from public.conversations
    where id = p_conversation_id and status = 'active'
      and (ctx.scope_kind <> 'institution' or institution_id = ctx.scope_institution_id) for share;
    if institution is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
    if read_only then raise object_not_in_prerequisite_state using detail='CHAT_READ_ONLY'; end if;
    actor_person := app_private.current_person_id();
    if actor_person is null then raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED'; end if;

    request_hash := extensions.digest(convert_to(jsonb_build_object('conversation_id', p_conversation_id,
      'file_name', file_name, 'content_type', content_type, 'byte_size', p_byte_size,
      'sha256', sha)::text, 'UTF8'), 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(ctx.internal_identity_id::text || p_request_id::text, 0));
    select * into prior from app_private.superadmin_internal_chat_attachment_tickets t
    where t.internal_identity_id = ctx.internal_identity_id and t.request_id = p_request_id for update;
    if prior.attachment_id is not null then
      if prior.request_hash <> request_hash then raise unique_violation using detail='CHAT_REPLAY_MISMATCH'; end if;
      select * into attachment from public.chat_attachment_metadata where id = prior.attachment_id;
    else
      -- ADR 0038: ate 10 anexos por envio. Conta os anexos deste autor nesta conversa
      -- ainda pendentes (ticket vivo, upload nao finalizado); sem teto por conversa.
      if (select count(*) from app_private.superadmin_internal_chat_attachment_tickets t
            join public.chat_attachment_metadata a on a.id = t.attachment_id
          where t.internal_identity_id = ctx.internal_identity_id
            and t.conversation_id = p_conversation_id and t.used_at is null
            and t.expires_at >= now() and a.upload_status = 'pending') >= 10 then
        raise check_violation using detail='CHAT_ATTACHMENT_LIMIT';
      end if;
      insert into public.messages(conversation_id, author_person_id, body_text, message_type, status,
        author_membership_id, author_experience_kind, author_role_snapshot, author_kind,
        author_internal_identity_id, author_internal_membership_id)
      values (p_conversation_id, null, file_name, 'attachment', 'draft', null, null,
        ctx.platform_role_code, 'superadmin_internal', ctx.internal_identity_id, ctx.internal_membership_id)
      returning * into created_message;
      object_key := 'tenants/' || institution::text || '/chat/conversation/' || p_conversation_id::text
        || '/attachment/' || new_attachment_id::text || '/original/' || gen_random_uuid()::text
        || '.' || app_private.chat_attachment_extension_v1(content_type);
      insert into public.chat_attachment_metadata(id, message_id, provider, object_key, file_name,
        content_type, byte_size, sha256, upload_status, created_by_person_id)
      values (new_attachment_id, created_message.id, 'r2', object_key, file_name, content_type,
        p_byte_size, sha, 'pending', actor_person)
      returning * into attachment;
      insert into app_private.superadmin_internal_chat_attachment_tickets(attachment_id,
        internal_identity_id, internal_auth_link_id, internal_membership_id, session_id,
        conversation_id, institution_id, request_id, request_hash, expires_at)
      values (attachment.id, ctx.internal_identity_id, ctx.internal_auth_link_id,
        ctx.internal_membership_id, ctx.session_id, p_conversation_id, institution, p_request_id,
        request_hash, ticket_expiry)
      returning * into prior;
      perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
        ctx.internal_auth_link_id, ctx.internal_membership_id, ctx.session_id,
        'chat.internal.send', ctx.aal, 'chat.attachment.prepare', 'success', null, correlation,
        institution, 'chat_attachment', attachment.id);
    end if;
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code, ''), 'SAI_INTERNAL_ERROR');
  end;
  if code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'chat.internal.send', 'chat.attachment.prepare', code, correlation, institution);
    return app_private.superadmin_chat_error(code, correlation);
  end if;
  return app_private.superadmin_chat_success(jsonb_build_object(
    'message_id', attachment.message_id, 'attachment_id', attachment.id,
    'object_key', attachment.object_key, 'bucket', 'coelo-media-prod',
    'file_name', attachment.file_name, 'content_type', attachment.content_type,
    'byte_size', attachment.byte_size, 'sha256', attachment.sha256,
    'upload_status', attachment.upload_status, 'finalize_ticket', prior.finalize_ticket,
    'expires_at', prior.expires_at, 'replayed', prior.used_at is not null or attachment.upload_status <> 'pending'));
end $$;

revoke all on function public.superadmin_chat_attachment_prepare_v1(uuid,uuid,text,text,bigint,text) from public, anon, service_role;
grant execute on function public.superadmin_chat_attachment_prepare_v1(uuid,uuid,text,text,bigint,text) to authenticated;
