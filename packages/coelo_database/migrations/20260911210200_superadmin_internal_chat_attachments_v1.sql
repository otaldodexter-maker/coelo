-- R05 realm-interno (3): chat.attach — contrato de anexo do chat interno v2
-- sobre public.chat_attachment_metadata (240000) e o R2 privado
-- coelo-media-prod, sem Stream (ADR 0032; chat nao usa copia HOT).
--
-- Fluxo (mesmo desenho de moments-media / circular-media):
--   1. cliente -> superadmin_chat_attachment_prepare_v1 (authenticated,
--      chat.internal.send): cria a mensagem em `draft` (invisivel na thread)
--      e o anexo `pending` com object_key opaco versionado; devolve
--      {message_id, attachment_id, object_key, bucket, content_type,
--      byte_size, finalize_ticket, expires_at, replayed}.
--   2. Edge Function chat-media (a implantar pelo coordenador) assina o PUT
--      no R2 para object_key; o cliente envia os bytes.
--   3. cliente -> chat-media "finalize": a funcao valida o ticket com
--      superadmin_chat_attachment_authorize_finalize_v1 (authenticated), faz
--      HEAD/leitura do objeto, mede bytes e sha256 e chama
--      superadmin_chat_attachment_finalize_v1 (service_role) com as medidas;
--      o anexo vira `ready`, a mensagem vira `active` e aparece na thread com
--      attachments[] (240100/240200 ja devolvem).
--   4. leitura: chat-media "read" chama superadmin_chat_attachment_authorize_read_v1
--      (authenticated, chat.internal.read, escopo da conversa) e assina o GET.
--   5. superadmin_chat_attachment_expire_v1 (service_role, cron/worker):
--      pendentes com ticket vencido viram `failed` e a mensagem `archived`.
--
-- Limites (ADR 0032, por finalidade): image/jpeg|png|webp ate 4 MiB;
-- application/pdf ate 10 MiB; nome ate 255 sem controle; sha256 informado pelo
-- cliente no prepare e conferido no finalize. Tickets expiram em 30 minutos.
-- Sem grant a anon; helpers privados; deny-by-default na tabela de tickets.
--
-- Reversao: drop das funcoes *_attachment_*_v1 e da tabela
-- app_private.superadmin_internal_chat_attachment_tickets; recriar
-- app_private.superadmin_chat_error como em 20260910240200.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'chat attachments migration must run as postgres';
  end if;
  if to_regclass('public.chat_attachment_metadata') is null
    or to_regclass('app_private.superadmin_internal_chat_command_receipts') is null
    or to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or to_regprocedure('app_private.superadmin_chat_error(text,uuid)') is null
    or to_regprocedure('app_private.superadmin_chat_success(jsonb)') is null
    or to_regprocedure('app_private.current_person_id()') is null
    or not exists (select 1 from public.platform_permissions where code = 'chat.internal.send') then
    raise object_not_in_prerequisite_state using
      message = 'chat v2 (240000..240400), internal actor bridge and chat.internal.send are required';
  end if;
end
$preflight$;

-- 1. Envelope: novos codigos de anexo -----------------------------------------
create or replace function app_private.superadmin_chat_error(p_code text,p_correlation_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select pg_catalog.jsonb_build_object('ok',false,'data',null,'error',
    pg_catalog.jsonb_build_object(
      'code',case when p_code in(
        'CHAT_INVALID_INPUT','CHAT_NOT_FOUND','CHAT_READ_ONLY','CHAT_REPLAY_MISMATCH',
        'CHAT_NOT_AUTHOR','CHAT_EDIT_WINDOW_CLOSED','CHAT_ALREADY_REVOKED',
        'CHAT_MEMBER_INVALID','CHAT_ATTACHMENT_INVALID','CHAT_ATTACHMENT_NOT_READY',
        'CHAT_ATTACHMENT_TICKET_INVALID','CHAT_ATTACHMENT_MISMATCH',
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
        when p_code like 'SAI_%DENIED' or p_code like 'SAI_MEMBERSHIP_%' then 'Acesso não autorizado.'
        else 'Não foi possível concluir a operação.' end,
      'http_status',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when p_code in('CHAT_INVALID_INPUT','CHAT_MEMBER_INVALID','CHAT_ATTACHMENT_INVALID',
          'CHAT_ATTACHMENT_MISMATCH') then 422
        when p_code='CHAT_NOT_FOUND' then 404
        when p_code in('CHAT_READ_ONLY','CHAT_REPLAY_MISMATCH','CHAT_EDIT_WINDOW_CLOSED',
          'CHAT_ALREADY_REVOKED','CHAT_ATTACHMENT_NOT_READY','CHAT_ATTACHMENT_TICKET_INVALID') then 409
        when p_code in('CHAT_NOT_AUTHOR','SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then 403
        else 500 end,
      'correlation_id',p_correlation_id))
$$;

-- 2. Tickets de finalizacao (privados) ---------------------------------------
create table app_private.superadmin_internal_chat_attachment_tickets (
  attachment_id uuid primary key references public.chat_attachment_metadata(id) on delete cascade,
  finalize_ticket uuid not null unique default gen_random_uuid(),
  internal_identity_id uuid not null references app_private.superadmin_internal_identities(id),
  internal_auth_link_id uuid not null,
  internal_membership_id uuid not null,
  session_id uuid not null,
  conversation_id uuid not null references public.conversations(id),
  institution_id uuid not null references public.institutions(id),
  request_id uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now(),
  unique (internal_identity_id, request_id)
);
alter table app_private.superadmin_internal_chat_attachment_tickets enable row level security;
alter table app_private.superadmin_internal_chat_attachment_tickets force row level security;
revoke all on table app_private.superadmin_internal_chat_attachment_tickets
  from public, anon, authenticated, service_role;
create index superadmin_internal_chat_attachment_tickets_expiry_idx
  on app_private.superadmin_internal_chat_attachment_tickets (expires_at) where used_at is null;

-- 3. Limites por tipo ---------------------------------------------------------
create function app_private.chat_attachment_limit_v1(p_content_type text)
returns bigint language sql immutable security invoker set search_path='' as $$
  select case p_content_type
    when 'image/jpeg' then 4194304::bigint
    when 'image/png' then 4194304::bigint
    when 'image/webp' then 4194304::bigint
    when 'application/pdf' then 10485760::bigint
    else null end
$$;
create function app_private.chat_attachment_extension_v1(p_content_type text)
returns text language sql immutable security invoker set search_path='' as $$
  select case p_content_type
    when 'image/jpeg' then 'jpg' when 'image/png' then 'png'
    when 'image/webp' then 'webp' when 'application/pdf' then 'pdf' end
$$;

-- 4. prepare ---------------------------------------------------------------------
create function public.superadmin_chat_attachment_prepare_v1(
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

-- 5. authorize_finalize (authenticated): o dono do ticket libera a finalizacao ------
create function public.superadmin_chat_attachment_authorize_finalize_v1(p_attachment_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid(); code text;
  ticket app_private.superadmin_internal_chat_attachment_tickets%rowtype;
  attachment public.chat_attachment_metadata%rowtype;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.send');
    if p_attachment_id is null then raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;
    select * into ticket from app_private.superadmin_internal_chat_attachment_tickets t
    where t.attachment_id = p_attachment_id and t.internal_identity_id = ctx.internal_identity_id
      and (ctx.scope_kind <> 'institution' or t.institution_id = ctx.scope_institution_id);
    if ticket.attachment_id is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
    if ticket.used_at is not null or ticket.expires_at < now() then
      raise object_not_in_prerequisite_state using detail='CHAT_ATTACHMENT_TICKET_INVALID';
    end if;
    select * into attachment from public.chat_attachment_metadata where id = p_attachment_id;
    if attachment.upload_status <> 'pending' then
      raise object_not_in_prerequisite_state using detail='CHAT_ATTACHMENT_TICKET_INVALID';
    end if;
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code, ''), 'SAI_INTERNAL_ERROR');
  end;
  if code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'chat.internal.send', 'chat.attachment.authorize_finalize', code, correlation, ticket.institution_id);
    return app_private.superadmin_chat_error(code, correlation);
  end if;
  return app_private.superadmin_chat_success(jsonb_build_object(
    'attachment_id', attachment.id, 'object_key', attachment.object_key, 'bucket', 'coelo-media-prod',
    'content_type', attachment.content_type, 'byte_size', attachment.byte_size, 'sha256', attachment.sha256,
    'finalize_ticket', ticket.finalize_ticket, 'expires_at', ticket.expires_at));
end $$;

-- 6. finalize (service_role, pela Edge Function apos medir o objeto) ----------------
create function public.superadmin_chat_attachment_finalize_v1(
  p_attachment_id uuid, p_finalize_ticket uuid, p_byte_size bigint, p_checksum_sha256 text
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  correlation uuid := gen_random_uuid(); code text; mismatch boolean := false;
  ticket app_private.superadmin_internal_chat_attachment_tickets%rowtype;
  attachment public.chat_attachment_metadata%rowtype;
begin
  begin
    if current_setting('request.jwt.claim.role', true) is distinct from 'service_role'
      and coalesce(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role' is distinct from 'service_role' then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    if p_attachment_id is null or p_finalize_ticket is null then
      raise invalid_parameter_value using detail='CHAT_INVALID_INPUT';
    end if;
    select * into ticket from app_private.superadmin_internal_chat_attachment_tickets t
    where t.attachment_id = p_attachment_id and t.finalize_ticket = p_finalize_ticket for update;
    if ticket.attachment_id is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
    if ticket.used_at is not null or ticket.expires_at < now() then
      raise object_not_in_prerequisite_state using detail='CHAT_ATTACHMENT_TICKET_INVALID';
    end if;
    select * into attachment from public.chat_attachment_metadata where id = p_attachment_id for update;
    if attachment.upload_status <> 'pending' then
      raise object_not_in_prerequisite_state using detail='CHAT_ATTACHMENT_TICKET_INVALID';
    end if;
    if p_byte_size is distinct from attachment.byte_size
      or lower(coalesce(p_checksum_sha256, '')) is distinct from attachment.sha256 then
      mismatch := true;
    end if;
    if not mismatch then
    update public.chat_attachment_metadata set upload_status = 'ready', uploaded_at = now()
      where id = attachment.id returning * into attachment;
    update public.messages set status = 'active', updated_at = now() where id = attachment.message_id;
    update app_private.superadmin_internal_chat_attachment_tickets set used_at = now()
      where attachment_id = attachment.id;
    perform app_private.audit_append_superadmin_internal(ticket.internal_identity_id,
      ticket.internal_auth_link_id, ticket.internal_membership_id, ticket.session_id,
      'chat.internal.send', 'aal1', 'chat.attachment.finalize', 'success', null, correlation,
      ticket.institution_id, 'chat_attachment', attachment.id);
    end if;
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code, ''), 'SAI_INTERNAL_ERROR');
  end;
  if code is null and mismatch then
    -- fora do bloco protegido: o estado falho precisa persistir
    update public.chat_attachment_metadata set upload_status = 'failed' where id = attachment.id;
    update public.messages set status = 'archived', deleted_at = now() where id = attachment.message_id;
    update app_private.superadmin_internal_chat_attachment_tickets set used_at = now()
      where attachment_id = attachment.id;
    perform app_private.audit_append_superadmin_internal(ticket.internal_identity_id,
      ticket.internal_auth_link_id, ticket.internal_membership_id, ticket.session_id,
      'chat.internal.send', 'aal1', 'chat.attachment.finalize', 'failed', 'CHAT_ATTACHMENT_MISMATCH',
      correlation, ticket.institution_id, 'chat_attachment', attachment.id);
    code := 'CHAT_ATTACHMENT_MISMATCH';
  end if;
  if code is not null then return app_private.superadmin_chat_error(code, correlation); end if;
  return app_private.superadmin_chat_success(jsonb_build_object(
    'attachment_id', attachment.id, 'message_id', attachment.message_id,
    'upload_status', attachment.upload_status, 'uploaded_at', attachment.uploaded_at));
end $$;

-- 7. authorize_read (authenticated): leitura pelo escopo da conversa --------------
create function public.superadmin_chat_attachment_authorize_read_v1(p_attachment_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid(); code text;
  attachment public.chat_attachment_metadata%rowtype; institution uuid; conversation uuid;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.read');
    if p_attachment_id is null then raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;
    select a.* into attachment
    from public.chat_attachment_metadata a
    join public.messages m on m.id = a.message_id
    join public.conversations c on c.id = m.conversation_id
    where a.id = p_attachment_id and m.status = 'active' and m.deleted_at is null
      and (ctx.scope_kind <> 'institution' or c.institution_id = ctx.scope_institution_id);
    if attachment.id is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
    select c.institution_id, c.id into institution, conversation
    from public.messages m join public.conversations c on c.id = m.conversation_id
    where m.id = attachment.message_id;
    if attachment.upload_status <> 'ready' then
      raise object_not_in_prerequisite_state using detail='CHAT_ATTACHMENT_NOT_READY';
    end if;
    perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
      ctx.internal_auth_link_id, ctx.internal_membership_id, ctx.session_id,
      'chat.internal.read', ctx.aal, 'chat.attachment.read', 'success', null, correlation,
      institution, 'chat_attachment', attachment.id);
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code, ''), 'SAI_INTERNAL_ERROR');
  end;
  if code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'chat.internal.read', 'chat.attachment.read', code, correlation, institution);
    return app_private.superadmin_chat_error(code, correlation);
  end if;
  return app_private.superadmin_chat_success(jsonb_build_object(
    'attachment_id', attachment.id, 'message_id', attachment.message_id, 'conversation_id', conversation,
    'object_key', attachment.object_key, 'bucket', 'coelo-media-prod',
    'file_name', attachment.file_name, 'content_type', attachment.content_type,
    'byte_size', attachment.byte_size, 'sha256', attachment.sha256, 'ttl_seconds', 300));
end $$;

-- 8. expire (service_role, worker) ------------------------------------------------
create function public.superadmin_chat_attachment_expire_v1(p_limit integer default 100)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare expired integer := 0; item record;
begin
  if current_setting('request.jwt.claim.role', true) is distinct from 'service_role'
    and coalesce(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role' is distinct from 'service_role' then
    return app_private.superadmin_chat_error('SAI_PERMISSION_DENIED', gen_random_uuid());
  end if;
  for item in
    select t.attachment_id, a.message_id, a.object_key
    from app_private.superadmin_internal_chat_attachment_tickets t
    join public.chat_attachment_metadata a on a.id = t.attachment_id
    where t.used_at is null and t.expires_at < now() and a.upload_status = 'pending'
    order by t.expires_at limit least(greatest(coalesce(p_limit, 100), 1), 500)
    for update of t skip locked
  loop
    update public.chat_attachment_metadata set upload_status = 'failed' where id = item.attachment_id;
    update public.messages set status = 'archived', deleted_at = now() where id = item.message_id;
    update app_private.superadmin_internal_chat_attachment_tickets set used_at = now()
      where attachment_id = item.attachment_id;
    expired := expired + 1;
  end loop;
  return app_private.superadmin_chat_success(jsonb_build_object('expired', expired));
end $$;

-- 9. Donos e privilegios ---------------------------------------------------------
alter table app_private.superadmin_internal_chat_attachment_tickets owner to postgres;
do $grants$ declare p regprocedure; begin
  foreach p in array array[
    'app_private.chat_attachment_limit_v1(text)'::regprocedure,
    'app_private.chat_attachment_extension_v1(text)'::regprocedure,
    'public.superadmin_chat_attachment_prepare_v1(uuid,uuid,text,text,bigint,text)'::regprocedure,
    'public.superadmin_chat_attachment_authorize_finalize_v1(uuid)'::regprocedure,
    'public.superadmin_chat_attachment_finalize_v1(uuid,uuid,bigint,text)'::regprocedure,
    'public.superadmin_chat_attachment_authorize_read_v1(uuid)'::regprocedure,
    'public.superadmin_chat_attachment_expire_v1(integer)'::regprocedure
  ] loop
    execute format('alter function %s owner to postgres', p);
    execute format('revoke all on function %s from public, anon, authenticated, service_role', p);
  end loop;
end $grants$;
grant execute on function public.superadmin_chat_attachment_prepare_v1(uuid,uuid,text,text,bigint,text),
  public.superadmin_chat_attachment_authorize_finalize_v1(uuid),
  public.superadmin_chat_attachment_authorize_read_v1(uuid) to authenticated;
grant execute on function public.superadmin_chat_attachment_finalize_v1(uuid,uuid,bigint,text),
  public.superadmin_chat_attachment_expire_v1(integer) to service_role;

commit;
