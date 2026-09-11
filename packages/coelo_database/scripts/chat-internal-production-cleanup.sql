-- Remove a fixture sintetica de chat-internal-production-fixture.sql e tudo
-- que a prova criou a partir dela (grupos, mensagens, recibos, preferencias,
-- trilhas de edicao). A trilha de auditoria (audit.audit_logs) e append-only e
-- fica; ela referencia apenas ids sinteticos.
begin;

with synthetic_conversations as (
  select id from public.conversations
  where institution_id = '9f040000-0000-4000-8000-000000000010'
), synthetic_messages as (
  select id from public.messages where conversation_id in (select id from synthetic_conversations)
)
delete from app_private.superadmin_internal_chat_command_receipts
where conversation_id in (select id from synthetic_conversations);

delete from app_private.superadmin_internal_chat_group_receipts
where conversation_id in (select id from public.conversations
  where institution_id = '9f040000-0000-4000-8000-000000000010');

delete from app_private.superadmin_internal_chat_preferences
where conversation_id in (select id from public.conversations
  where institution_id = '9f040000-0000-4000-8000-000000000010');

delete from app_private.superadmin_internal_chat_message_edits
where message_id in (select id from public.messages where conversation_id in
  (select id from public.conversations where institution_id = '9f040000-0000-4000-8000-000000000010'));

delete from app_private.superadmin_internal_chat_receipts
where message_id in (select id from public.messages where conversation_id in
  (select id from public.conversations where institution_id = '9f040000-0000-4000-8000-000000000010'));

-- messages, conversation_participants, message_receipts caem por cascade.
delete from public.conversations where institution_id = '9f040000-0000-4000-8000-000000000010';

delete from public.child_contexts where id = '9f040000-0000-4000-8000-000000000091';
delete from public.guardian_links where id = '9f040000-0000-4000-8000-000000000081';
delete from public.family_relationship_types where id = '9f040000-0000-4000-8000-000000000090';
delete from public.institution_memberships where id = '9f040000-0000-4000-8000-000000000071';
delete from public.people where id in (
  '9f040000-0000-4000-8000-000000000061',
  '9f040000-0000-4000-8000-000000000062',
  '9f040000-0000-4000-8000-000000000064');
-- audit.audit_logs (append-only) referencia institution_id por FK: a instituicao
-- sintetica nao pode ser apagada; fica arquivada e marcada, sem vinculo algum.
update public.institutions
set status = 'archived', deleted_at = now(), updated_at = now(),
    public_name = 'QA R04 Instituicao Sintetica (arquivada)'
where id = '9f040000-0000-4000-8000-000000000010';

commit;
