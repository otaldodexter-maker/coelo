-- R15 / ADR 0042 E3 (Chat, owner.r12-52 = B): varios anexos por MENSAGEM.
-- prepare_v2 recebe um lote de 1..10 itens e cria UMA mensagem draft com N
-- anexos e N tickets (request_id por item derivado por uuid v5 do request_id do
-- lote; o hash do lote inteiro vai em todos os tickets -> replay identico
-- devolve a mesma mensagem, replay divergente e CHAT_REPLAY_MISMATCH). O limite
-- do lote 67 (ate 10 pendentes por autor/conversa) continua valendo e o 11o
-- item do lote e recusado com CHAT_ATTACHMENT_LIMIT (422). finalize_v2 marca o
-- anexo ready e so publica a mensagem quando NENHUM irmao continua pendente e
-- ao menos um esta ready; mismatch deixa o anexo failed sem arquivar a mensagem
-- enquanto houver irmaos. discard_v1 (dono, mensagem draft) descarta um anexo
-- (pendente/falho/pronto), consome o ticket e publica/arquiva a mensagem pelo
-- mesmo criterio. expire_v1 passa a respeitar os irmaos. thread_v2 lista apenas
-- anexos ready por mensagem (asset_id = id do binding, lote 72).
-- Reversao: drop das funcoes v2/discard/list/settle e restauracao dos corpos
-- de expire_v1 e thread_v2 a partir de 20260911211300 e 20260915130100.
-- v1 (prepare/finalize) permanece intacta para o app hospedado ate a publicacao.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise exception 'executar como postgres';
  end if;
  if to_regprocedure('public.superadmin_chat_attachment_prepare_v1(uuid,uuid,text,text,bigint,text)') is null
    or to_regprocedure('public.superadmin_chat_attachment_finalize_v1(uuid,uuid,bigint,text)') is null
    or to_regprocedure('public.superadmin_chat_attachment_expire_v1(integer)') is null
    or to_regprocedure('public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer)') is null
    or to_regprocedure('app_private.chat_attachment_limit_v1(text)') is null
    or to_regprocedure('app_private.chat_attachment_extension_v1(text)') is null
    or to_regprocedure('app_private.superadmin_chat_error(text,uuid)') is null
    or to_regprocedure('extensions.uuid_generate_v5(uuid,text)') is null
    or to_regclass('app_private.superadmin_internal_chat_attachment_tickets') is null then
    raise exception 'pre-requisitos do chat (lotes 67/72) ausentes';
  end if;
end $preflight$;

-- 0. Ordem dos anexos dentro da mensagem (inserts do mesmo lote compartilham created_at).
alter table public.chat_attachment_metadata
  add column if not exists position smallint not null default 0
  check (position between 0 and 9);

-- 1. Envelope de erro: novo codigo para descarte fora de hora.
create or replace function app_private.superadmin_chat_error(p_code text,p_correlation_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select pg_catalog.jsonb_build_object('ok',false,'data',null,'error',
    pg_catalog.jsonb_build_object(
      'code',case when p_code in(
        'CHAT_INVALID_INPUT','CHAT_NOT_FOUND','CHAT_READ_ONLY','CHAT_REPLAY_MISMATCH',
        'CHAT_NOT_AUTHOR','CHAT_EDIT_WINDOW_CLOSED','CHAT_ALREADY_REVOKED',
        'CHAT_MEMBER_INVALID','CHAT_ATTACHMENT_INVALID','CHAT_ATTACHMENT_NOT_READY',
        'CHAT_ATTACHMENT_TICKET_INVALID','CHAT_ATTACHMENT_MISMATCH','CHAT_ATTACHMENT_LIMIT',
        'CHAT_ATTACHMENT_DISCARD_INVALID',
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
        when p_code='CHAT_ATTACHMENT_DISCARD_INVALID' then 'Este anexo não pode mais ser removido.'
        when p_code like 'SAI_%DENIED' or p_code like 'SAI_MEMBERSHIP_%' then 'Acesso não autorizado.'
        else 'Não foi possível concluir a operação.' end,
      'http_status',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when p_code in('CHAT_INVALID_INPUT','CHAT_MEMBER_INVALID','CHAT_ATTACHMENT_INVALID',
          'CHAT_ATTACHMENT_MISMATCH','CHAT_ATTACHMENT_LIMIT') then 422
        when p_code='CHAT_NOT_FOUND' then 404
        when p_code in('CHAT_READ_ONLY','CHAT_REPLAY_MISMATCH','CHAT_EDIT_WINDOW_CLOSED',
          'CHAT_ALREADY_REVOKED','CHAT_ATTACHMENT_NOT_READY','CHAT_ATTACHMENT_TICKET_INVALID',
          'CHAT_ATTACHMENT_DISCARD_INVALID') then 409
        when p_code in('CHAT_NOT_AUTHOR','SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then 403
        else 500 end,
      'correlation_id',p_correlation_id))
$$;

-- 2. Lista de anexos de uma mensagem (privada; usada nos envelopes).
create or replace function app_private.superadmin_chat_attachment_list_v2(p_message_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id', a.id, 'attachment_id', a.id, 'asset_id', a.id, 'file_name', a.file_name,
      'content_type', a.content_type, 'byte_size', a.byte_size, 'sha256', a.sha256,
      'upload_status', a.upload_status, 'uploaded_at', a.uploaded_at, 'position', a.position)
      order by a.created_at, a.position, a.id)
    from public.chat_attachment_metadata a where a.message_id = p_message_id), '[]'::jsonb)
$$;

-- 3. Decisao de publicacao da mensagem draft pelo estado dos irmaos (E3):
--    pendente restante -> draft; nenhum ready -> archived (nada a publicar);
--    algum failed -> draft (espera o autor remover os que falharam);
--    todos terminaram e ao menos um ready -> active. Fora de draft nao muda.
create or replace function app_private.superadmin_chat_message_settle_v2(p_message_id uuid)
returns text language plpgsql volatile security invoker set search_path='' as $$
declare
  current_status text; pending_count integer; ready_count integer; failed_count integer;
begin
  select m.status::text into current_status from public.messages m where m.id = p_message_id for update;
  if current_status is null then return null; end if;
  if current_status <> 'draft' then return current_status; end if;
  select count(*) filter (where a.upload_status = 'pending'),
         count(*) filter (where a.upload_status = 'ready'),
         count(*) filter (where a.upload_status = 'failed')
    into pending_count, ready_count, failed_count
  from public.chat_attachment_metadata a where a.message_id = p_message_id;
  if pending_count > 0 then return 'draft'; end if;
  if ready_count = 0 then
    update public.messages set status = 'archived', deleted_at = now(), updated_at = now()
      where id = p_message_id;
    return 'archived';
  end if;
  if failed_count > 0 then return 'draft'; end if;
  update public.messages set status = 'active', updated_at = now() where id = p_message_id;
  return 'active';
end $$;

-- 4. prepare_v2: lote de 1..10 itens em UMA mensagem.
create or replace function public.superadmin_chat_attachment_prepare_v2(
  p_request_id uuid, p_conversation_id uuid, p_items jsonb, p_body_text text default null
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid := gen_random_uuid();
  institution uuid; read_only boolean; code text;
  actor_person uuid; batch_hash bytea; item_count integer; idx integer;
  item jsonb; file_name text; content_type text; sha text; byte_size bigint; limit_bytes bigint;
  first_ticket app_private.superadmin_internal_chat_attachment_tickets%rowtype;
  item_request uuid; message_row public.messages%rowtype; attachment_id uuid; object_key text;
  ticket_expiry timestamptz := now() + interval '30 minutes';
  body text := nullif(btrim(coalesce(p_body_text, '')), '');
  replayed boolean := false; items_out jsonb;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.send');
    if p_request_id is null or p_conversation_id is null or p_items is null
      or jsonb_typeof(p_items) <> 'array' then
      raise invalid_parameter_value using detail='CHAT_INVALID_INPUT';
    end if;
    item_count := jsonb_array_length(p_items);
    if item_count < 1 then raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;
    if item_count > 10 then raise check_violation using detail='CHAT_ATTACHMENT_LIMIT'; end if;
    if body is not null and char_length(body) > 4000 then
      raise invalid_parameter_value using detail='CHAT_INVALID_INPUT';
    end if;
    -- valida cada item com as mesmas regras da v1
    for idx in 0 .. item_count - 1 loop
      item := p_items -> idx;
      if jsonb_typeof(item) <> 'object' then raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;
      file_name := btrim(coalesce(item ->> 'file_name', ''));
      content_type := lower(btrim(coalesce(item ->> 'content_type', '')));
      sha := lower(btrim(coalesce(item ->> 'sha256', '')));
      byte_size := case when jsonb_typeof(item -> 'byte_size') = 'number' then (item ->> 'byte_size')::bigint else null end;
      limit_bytes := app_private.chat_attachment_limit_v1(content_type);
      if limit_bytes is null or file_name = '' or char_length(file_name) > 255
        or file_name ~ '[[:cntrl:]/\\]' or byte_size is null or byte_size < 1
        or byte_size > limit_bytes or sha !~ '^[0-9a-f]{64}$' then
        raise invalid_parameter_value using detail='CHAT_ATTACHMENT_INVALID';
      end if;
    end loop;
    select institution_id, is_read_only into institution, read_only from public.conversations
    where id = p_conversation_id and status = 'active'
      and (ctx.scope_kind <> 'institution' or institution_id = ctx.scope_institution_id) for share;
    if institution is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
    if read_only then raise object_not_in_prerequisite_state using detail='CHAT_READ_ONLY'; end if;
    actor_person := app_private.current_person_id();
    if actor_person is null then raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED'; end if;

    batch_hash := extensions.digest(convert_to(jsonb_build_object('conversation_id', p_conversation_id,
      'body_text', body, 'items', (select jsonb_agg(jsonb_build_object(
        'file_name', btrim(i ->> 'file_name'), 'content_type', lower(btrim(i ->> 'content_type')),
        'byte_size', (i ->> 'byte_size')::bigint, 'sha256', lower(btrim(i ->> 'sha256'))))
        from jsonb_array_elements(p_items) i))::text, 'UTF8'), 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(ctx.internal_identity_id::text || p_request_id::text, 0));
    select * into first_ticket from app_private.superadmin_internal_chat_attachment_tickets t
    where t.internal_identity_id = ctx.internal_identity_id
      and t.request_id = extensions.uuid_generate_v5(p_request_id, 'chat-attachment-item:0') for update;
    if first_ticket.attachment_id is not null then
      if first_ticket.request_hash <> batch_hash then raise unique_violation using detail='CHAT_REPLAY_MISMATCH'; end if;
      select m.* into message_row from public.messages m
        join public.chat_attachment_metadata a on a.message_id = m.id
        where a.id = first_ticket.attachment_id;
      replayed := true;
    else
      -- lote 67: ate 10 pendentes por autor nesta conversa, contando o lote novo.
      if (select count(*) from app_private.superadmin_internal_chat_attachment_tickets t
            join public.chat_attachment_metadata a on a.id = t.attachment_id
          where t.internal_identity_id = ctx.internal_identity_id
            and t.conversation_id = p_conversation_id and t.used_at is null
            and t.expires_at >= now() and a.upload_status = 'pending') + item_count > 10 then
        raise check_violation using detail='CHAT_ATTACHMENT_LIMIT';
      end if;
      insert into public.messages(conversation_id, author_person_id, body_text, message_type, status,
        author_membership_id, author_experience_kind, author_role_snapshot, author_kind,
        author_internal_identity_id, author_internal_membership_id)
      values (p_conversation_id, null,
        coalesce(body, case when item_count = 1 then btrim(p_items -> 0 ->> 'file_name')
          else item_count::text || ' anexos' end),
        'attachment', 'draft', null, null,
        ctx.platform_role_code, 'superadmin_internal', ctx.internal_identity_id, ctx.internal_membership_id)
      returning * into message_row;
      for idx in 0 .. item_count - 1 loop
        item := p_items -> idx;
        file_name := btrim(item ->> 'file_name');
        content_type := lower(btrim(item ->> 'content_type'));
        sha := lower(btrim(item ->> 'sha256'));
        byte_size := (item ->> 'byte_size')::bigint;
        attachment_id := gen_random_uuid();
        item_request := extensions.uuid_generate_v5(p_request_id, 'chat-attachment-item:' || idx::text);
        object_key := 'tenants/' || institution::text || '/chat/conversation/' || p_conversation_id::text
          || '/attachment/' || attachment_id::text || '/original/' || gen_random_uuid()::text
          || '.' || app_private.chat_attachment_extension_v1(content_type);
        insert into public.chat_attachment_metadata(id, message_id, provider, object_key, file_name,
          content_type, byte_size, sha256, upload_status, created_by_person_id, position)
        values (attachment_id, message_row.id, 'r2', object_key, file_name, content_type,
          byte_size, sha, 'pending', actor_person, idx);
        insert into app_private.superadmin_internal_chat_attachment_tickets(attachment_id,
          internal_identity_id, internal_auth_link_id, internal_membership_id, session_id,
          conversation_id, institution_id, request_id, request_hash, expires_at)
        values (attachment_id, ctx.internal_identity_id, ctx.internal_auth_link_id,
          ctx.internal_membership_id, ctx.session_id, p_conversation_id, institution, item_request,
          batch_hash, ticket_expiry);
        perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
          ctx.internal_auth_link_id, ctx.internal_membership_id, ctx.session_id,
          'chat.internal.send', ctx.aal, 'chat.attachment.prepare', 'success', null, correlation,
          institution, 'chat_attachment', attachment_id);
      end loop;
    end if;
    select jsonb_agg(jsonb_build_object(
        'index', a.position, 'attachment_id', a.id, 'asset_id', a.id, 'object_key', a.object_key,
        'file_name', a.file_name, 'content_type', a.content_type, 'byte_size', a.byte_size,
        'sha256', a.sha256, 'upload_status', a.upload_status,
        'finalize_ticket', t.finalize_ticket, 'expires_at', t.expires_at,
        'replayed', replayed and (t.used_at is not null or a.upload_status <> 'pending'))
        order by a.position, a.id)
      into items_out
    from public.chat_attachment_metadata a
    join app_private.superadmin_internal_chat_attachment_tickets t on t.attachment_id = a.id
    where a.message_id = message_row.id;
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
    'message_id', message_row.id, 'message_status', message_row.status::text,
    'body_text', coalesce(message_row.body_text, ''), 'bucket', 'coelo-media-prod',
    'replayed', replayed, 'items', coalesce(items_out, '[]'::jsonb)));
end $$;

-- 5. finalize_v2 (service_role): igual a v1, mas a mensagem so publica quando
--    todos os irmaos terminaram; mismatch nao arquiva a mensagem se houver irmaos.
create or replace function public.superadmin_chat_attachment_finalize_v2(
  p_attachment_id uuid, p_finalize_ticket uuid, p_byte_size bigint, p_checksum_sha256 text
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  correlation uuid := gen_random_uuid(); code text; mismatch boolean := false; message_status text;
  ticket app_private.superadmin_internal_chat_attachment_tickets%rowtype;
  attachment public.chat_attachment_metadata%rowtype;
begin
  begin
    if coalesce(nullif(current_setting('request.jwt.claim.role', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '') <> 'service_role' then
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
      update app_private.superadmin_internal_chat_attachment_tickets set used_at = now()
        where attachment_id = attachment.id;
      message_status := app_private.superadmin_chat_message_settle_v2(attachment.message_id);
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
    update app_private.superadmin_internal_chat_attachment_tickets set used_at = now()
      where attachment_id = attachment.id;
    message_status := app_private.superadmin_chat_message_settle_v2(attachment.message_id);
    perform app_private.audit_append_superadmin_internal(ticket.internal_identity_id,
      ticket.internal_auth_link_id, ticket.internal_membership_id, ticket.session_id,
      'chat.internal.send', 'aal1', 'chat.attachment.finalize', 'failed', 'CHAT_ATTACHMENT_MISMATCH',
      correlation, ticket.institution_id, 'chat_attachment', attachment.id);
    code := 'CHAT_ATTACHMENT_MISMATCH';
  end if;
  if code is not null then return app_private.superadmin_chat_error(code, correlation); end if;
  return app_private.superadmin_chat_success(jsonb_build_object(
    'attachment_id', attachment.id, 'message_id', attachment.message_id,
    'upload_status', attachment.upload_status, 'uploaded_at', attachment.uploaded_at,
    'message_status', message_status,
    'attachments', app_private.superadmin_chat_attachment_list_v2(attachment.message_id)));
end $$;

-- 6. discard_v1 (dono, mensagem draft): remove um anexo do lote e decide a mensagem.
create or replace function public.superadmin_chat_attachment_discard_v1(p_attachment_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid(); code text;
  ticket app_private.superadmin_internal_chat_attachment_tickets%rowtype;
  attachment public.chat_attachment_metadata%rowtype; previous_status text; message_status text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.send');
    if p_attachment_id is null then raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;
    select * into ticket from app_private.superadmin_internal_chat_attachment_tickets t
    where t.attachment_id = p_attachment_id and t.internal_identity_id = ctx.internal_identity_id
      and (ctx.scope_kind <> 'institution' or t.institution_id = ctx.scope_institution_id) for update;
    if ticket.attachment_id is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
    select a.* into attachment from public.chat_attachment_metadata a
      join public.messages m on m.id = a.message_id
      where a.id = p_attachment_id and m.status = 'draft'
        and m.author_internal_identity_id = ctx.internal_identity_id for update of a;
    if attachment.id is null or attachment.upload_status = 'deleted' then
      raise object_not_in_prerequisite_state using detail='CHAT_ATTACHMENT_DISCARD_INVALID';
    end if;
    previous_status := attachment.upload_status;
    update public.chat_attachment_metadata set upload_status = 'deleted' where id = attachment.id
      returning * into attachment;
    update app_private.superadmin_internal_chat_attachment_tickets set used_at = coalesce(used_at, now())
      where attachment_id = attachment.id;
    message_status := app_private.superadmin_chat_message_settle_v2(attachment.message_id);
    perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
      ctx.internal_auth_link_id, ctx.internal_membership_id, ctx.session_id,
      'chat.internal.send', ctx.aal, 'chat.attachment.discard', 'success', null, correlation,
      ticket.institution_id, 'chat_attachment', attachment.id);
  exception when others then
    get stacked diagnostics code = pg_exception_detail;
    code := coalesce(nullif(code, ''), 'SAI_INTERNAL_ERROR');
  end;
  if code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'chat.internal.send', 'chat.attachment.discard', code, correlation, ticket.institution_id);
    return app_private.superadmin_chat_error(code, correlation);
  end if;
  return app_private.superadmin_chat_success(jsonb_build_object(
    'attachment_id', attachment.id, 'message_id', attachment.message_id,
    'object_key', attachment.object_key, 'bucket', 'coelo-media-prod',
    'previous_status', previous_status, 'upload_status', attachment.upload_status,
    'message_status', message_status,
    'attachments', app_private.superadmin_chat_attachment_list_v2(attachment.message_id)));
end $$;

-- 7. expire_v1: sensivel aos irmaos (mesma assinatura; chamado pela Edge/cron).
create or replace function public.superadmin_chat_attachment_expire_v1(p_limit integer default 100)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare expired integer := 0; item record;
begin
  if coalesce(nullif(current_setting('request.jwt.claim.role', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '') <> 'service_role' then
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
    update app_private.superadmin_internal_chat_attachment_tickets set used_at = now()
      where attachment_id = item.attachment_id;
    perform app_private.superadmin_chat_message_settle_v2(item.message_id);
    expired := expired + 1;
  end loop;
  return app_private.superadmin_chat_success(jsonb_build_object('expired', expired));
end $$;

-- 8. thread_v2: lista por mensagem so os anexos ready, na ordem do lote (corpo do lote 72 + filtro/ordem).
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
          order by attachment.created_at,attachment.position,attachment.id) from public.chat_attachment_metadata attachment
          where attachment.message_id=item.id and attachment.upload_status='ready'),'[]'::jsonb))
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

-- 9. Donos e grants.
alter function app_private.superadmin_chat_error(text,uuid) owner to postgres;
alter function app_private.superadmin_chat_attachment_list_v2(uuid) owner to postgres;
alter function app_private.superadmin_chat_message_settle_v2(uuid) owner to postgres;
alter function public.superadmin_chat_attachment_prepare_v2(uuid,uuid,jsonb,text) owner to postgres;
alter function public.superadmin_chat_attachment_finalize_v2(uuid,uuid,bigint,text) owner to postgres;
alter function public.superadmin_chat_attachment_discard_v1(uuid) owner to postgres;
alter function public.superadmin_chat_attachment_expire_v1(integer) owner to postgres;
alter function public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer) owner to postgres;

revoke all on function app_private.superadmin_chat_attachment_list_v2(uuid) from public, anon, authenticated, service_role;
revoke all on function app_private.superadmin_chat_message_settle_v2(uuid) from public, anon, authenticated, service_role;
revoke all on function public.superadmin_chat_attachment_prepare_v2(uuid,uuid,jsonb,text) from public, anon, service_role;
grant execute on function public.superadmin_chat_attachment_prepare_v2(uuid,uuid,jsonb,text) to authenticated;
revoke all on function public.superadmin_chat_attachment_discard_v1(uuid) from public, anon, service_role;
grant execute on function public.superadmin_chat_attachment_discard_v1(uuid) to authenticated;
revoke all on function public.superadmin_chat_attachment_finalize_v2(uuid,uuid,bigint,text) from public, anon, authenticated;
grant execute on function public.superadmin_chat_attachment_finalize_v2(uuid,uuid,bigint,text) to service_role;
revoke all on function public.superadmin_chat_attachment_expire_v1(integer) from public, anon, authenticated;
grant execute on function public.superadmin_chat_attachment_expire_v1(integer) to service_role;
revoke all on function public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer) from public, anon, service_role;
grant execute on function public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer) to authenticated;

commit;
