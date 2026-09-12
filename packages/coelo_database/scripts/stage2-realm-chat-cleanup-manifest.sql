-- PREVIEW ONLY. Inventário para a futura limpeza formal da Etapa 2.
-- Não contém DELETE/UPDATE, não altera auth.users, audit.audit_logs ou R2.
-- Execute como leitura somente após C0 conferir o alvo e a base.
begin;
set local transaction read only;

create temporary table cleanup_auth_users on commit drop as
select id, email
from auth.users
where email = any(array[
  'qa-r06-estrutura@coelo.me',
  'qa-r06-acessos@coelo.me',
  'qa-r06-formularios@coelo.me',
  'qa-r06-principal@coelo.me',
  'qa-r06-realm@coelo.me',
  'qa-r06-publicacoes@coelo.me',
  'qa-r06-operacoes@coelo.me'
]::text[]);

create temporary table cleanup_internal_identities on commit drop as
select distinct link.internal_identity_id
from app_private.superadmin_internal_auth_links link
join cleanup_auth_users target on target.id = link.auth_user_id;

create temporary table cleanup_actor_people on commit drop as
select distinct actor.person_id
from app_private.superadmin_internal_actor_people actor
join cleanup_internal_identities target
  on target.internal_identity_id = actor.internal_identity_id;

create temporary table cleanup_institutions on commit drop as
select id, slug
from public.institutions
where id = '9f040000-0000-4000-8000-000000000010'
   or slug = any(array[
     'qa-r04-chat',
     'qa-r04-cuidado-sintetico',
     'qa-r04-escola'
   ]::text[]);

select category, relation_name, row_count, future_action
from (
  select 10 as sort_order, 'auth'::text as category,
    'auth.users'::text as relation_name, count(*)::bigint as row_count,
    'ban/delete only through Auth Admin after sessions are revoked'::text as future_action
  from cleanup_auth_users
  union all
  select 20, 'realm', 'app_private.superadmin_internal_identities', count(*),
    'remove dependent realm rows only after Auth cleanup receipt'
  from cleanup_internal_identities
  union all
  select 30, 'realm', 'app_private.superadmin_internal_profiles', count(*),
    'delete by internal_identity_id allowlist'
  from app_private.superadmin_internal_profiles profile
  join cleanup_internal_identities target using (internal_identity_id)
  union all
  select 40, 'realm', 'app_private.superadmin_internal_memberships', count(*),
    'revoke first; preserve audit references'
  from app_private.superadmin_internal_memberships membership
  join cleanup_internal_identities target using (internal_identity_id)
  union all
  select 50, 'realm', 'app_private.superadmin_internal_actor_people', count(*),
    'remove bridge only after dependent institution memberships'
  from app_private.superadmin_internal_actor_people actor
  join cleanup_internal_identities target using (internal_identity_id)
  union all
  select 60, 'realm', 'public.institution_memberships', count(*),
    'revoke/delete only memberships owned by allowlisted actor people'
  from public.institution_memberships membership
  join cleanup_actor_people target using (person_id)
  union all
  select 70, 'chat', 'public.conversations', count(*),
    'reuse chat-internal-production-cleanup ordering; retain audit'
  from public.conversations conversation
  join cleanup_institutions target on target.id = conversation.institution_id
  union all
  select 80, 'chat-media', 'public.chat_attachment_metadata', count(*),
    'purge private R2 keys through chat-media worker before metadata cleanup'
  from public.chat_attachment_metadata attachment
  join public.messages message on message.id = attachment.message_id
  join public.conversations conversation on conversation.id = message.conversation_id
  join cleanup_institutions target on target.id = conversation.institution_id
  union all
  select 90, 'retained', 'audit.audit_logs', count(*),
    'never delete; append-only evidence'
  from audit.audit_logs log
  where log.actor_internal_identity_id in (
    select internal_identity_id from cleanup_internal_identities
  )
) inventory
order by sort_order;

rollback;
