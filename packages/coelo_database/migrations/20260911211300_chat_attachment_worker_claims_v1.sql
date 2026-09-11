-- R05 realm-interno (14): hardening do finalize/expire de anexos do chat.
-- Sem claims na sessao, ''::jsonb lancava excecao e a chamada caia em
-- SAI_INTERNAL_ERROR (fechava, mas com o codigo errado). Passa a usar a
-- mesma forma de app_private.audit_assert_worker (nullif + coalesce) e a
-- responder SAI_PERMISSION_DENIED. Corpos iguais aos de 210200 fora disso.
-- Reversao: recriar as duas funcoes como em 20260911210200.
begin;
do $$ begin
  if to_regprocedure('public.superadmin_chat_attachment_finalize_v1(uuid,uuid,bigint,text)') is null then
    raise object_not_in_prerequisite_state using message='210200 is required';
  end if;
end $$;
create or replace function public.superadmin_chat_attachment_finalize_v1(
  p_attachment_id uuid, p_finalize_ticket uuid, p_byte_size bigint, p_checksum_sha256 text
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  correlation uuid := gen_random_uuid(); code text; mismatch boolean := false;
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
    update public.messages set status = 'archived', deleted_at = now() where id = item.message_id;
    update app_private.superadmin_internal_chat_attachment_tickets set used_at = now()
      where attachment_id = item.attachment_id;
    expired := expired + 1;
  end loop;
  return app_private.superadmin_chat_success(jsonb_build_object('expired', expired));
end $$;

alter function public.superadmin_chat_attachment_finalize_v1(uuid,uuid,bigint,text) owner to postgres;
alter function public.superadmin_chat_attachment_expire_v1(integer) owner to postgres;
revoke all on function public.superadmin_chat_attachment_finalize_v1(uuid,uuid,bigint,text), public.superadmin_chat_attachment_expire_v1(integer) from public, anon, authenticated, service_role;
grant execute on function public.superadmin_chat_attachment_finalize_v1(uuid,uuid,bigint,text), public.superadmin_chat_attachment_expire_v1(integer) to service_role;
commit;
