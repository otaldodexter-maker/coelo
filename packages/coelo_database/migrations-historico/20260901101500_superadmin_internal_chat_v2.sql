begin;

do $$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message='internal chat migration must run as postgres';
  end if;
  if to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
     or to_regprocedure('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid,jsonb)') is null
     or to_regclass('public.conversations') is null
     or to_regclass('public.messages') is null
     or to_regclass('public.chat_attachment_metadata') is null then
    raise exception using errcode='55000',message='internal auth, audit and chat dependencies are unavailable';
  end if;
end
$$;

insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status,updated_at
) values
 ('chat.internal.read','communication','chat','read',
  'Ler conversas institucionais pelo realm interno do Superadmin.','high',false,'active',now()),
 ('chat.internal.send','communication','chat','send',
  'Enviar mensagens institucionais pelo realm interno do Superadmin.','critical',true,'active',now())
on conflict(code) do update set module_code=excluded.module_code,screen_code=excluded.screen_code,
 action_code=excluded.action_code,description=excluded.description,risk_level=excluded.risk_level,
 requires_mfa=excluded.requires_mfa,status='active',updated_at=now();

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='owner' and permission_record.code in('chat.internal.read','chat.internal.send')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='operations' and permission_record.code='chat.internal.read'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

alter table public.messages alter column author_person_id drop not null;
alter table public.messages
  add column author_kind text not null default 'person',
  add column author_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id) on delete restrict,
  add column author_internal_membership_id uuid
    references app_private.superadmin_internal_memberships(id) on delete restrict,
  add constraint messages_author_realm_check check(
    (author_kind='person' and author_person_id is not null
      and author_internal_identity_id is null and author_internal_membership_id is null)
    or
    (author_kind='superadmin_internal' and author_person_id is null
      and author_internal_identity_id is not null and author_internal_membership_id is not null)
  );

create index messages_internal_author_idx
  on public.messages(author_internal_identity_id,created_at desc)
  where author_internal_identity_id is not null;

create function app_private.guard_chat_message_internal_author()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.author_kind='superadmin_internal' and not exists(
  select 1 from app_private.superadmin_internal_memberships membership
  where membership.id=new.author_internal_membership_id
    and membership.internal_identity_id=new.author_internal_identity_id
 ) then
  raise foreign_key_violation using message='inconsistent internal chat author';
 end if;
 return new;
end $$;
create trigger messages_internal_author_guard
before insert or update of author_kind,author_internal_identity_id,author_internal_membership_id
on public.messages for each row execute function app_private.guard_chat_message_internal_author();
revoke all on function app_private.guard_chat_message_internal_author()
 from public,anon,authenticated,service_role;

create table app_private.superadmin_internal_chat_receipts(
  message_id uuid not null references public.messages(id) on delete cascade,
  internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete cascade,
  delivered_at timestamptz,
  read_at timestamptz,
  primary key(message_id,internal_identity_id)
);
create index superadmin_internal_chat_receipts_unread_idx
  on app_private.superadmin_internal_chat_receipts(internal_identity_id,message_id)
  where read_at is null;

create table app_private.superadmin_internal_chat_command_receipts(
  request_id uuid not null,
  internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete restrict,
  conversation_id uuid not null references public.conversations(id) on delete restrict,
  request_hash bytea not null check(octet_length(request_hash)=32),
  message_id uuid not null references public.messages(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key(internal_identity_id,request_id)
);

alter table app_private.superadmin_internal_chat_receipts enable row level security;
alter table app_private.superadmin_internal_chat_receipts force row level security;
alter table app_private.superadmin_internal_chat_command_receipts enable row level security;
alter table app_private.superadmin_internal_chat_command_receipts force row level security;
revoke all on table app_private.superadmin_internal_chat_receipts
  from public,anon,authenticated,service_role;
revoke all on table app_private.superadmin_internal_chat_command_receipts
  from public,anon,authenticated,service_role;

-- The internal realm has no people identity, therefore existing contextual RLS
-- policies expose it no rows. Its only usable path is the guarded gateway below;
-- grants needed by the separate Principal/Admin security-invoker RPCs stay intact.

create function app_private.superadmin_chat_success(p_data jsonb)
returns jsonb language sql stable security invoker set search_path=''
as $$select pg_catalog.jsonb_build_object('ok',true,'data',p_data,'error',null)$$;

create function app_private.superadmin_chat_error(p_code text,p_correlation_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select pg_catalog.jsonb_build_object('ok',false,'data',null,'error',
    pg_catalog.jsonb_build_object(
      'code',case when p_code in(
        'CHAT_INVALID_INPUT','CHAT_NOT_FOUND','CHAT_READ_ONLY','CHAT_REPLAY_MISMATCH',
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
        when p_code like 'SAI_%DENIED' or p_code like 'SAI_MEMBERSHIP_%' then 'Acesso não autorizado.'
        else 'Não foi possível concluir a operação.' end,
      'http_status',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when p_code in('CHAT_INVALID_INPUT') then 422
        when p_code='CHAT_NOT_FOUND' then 404
        when p_code in('CHAT_READ_ONLY','CHAT_REPLAY_MISMATCH') then 409
        when p_code in('SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then 403
        else 500 end,
      'correlation_id',p_correlation_id))
$$;

create function public.superadmin_chat_inbox_v2(
  p_cursor_activity_at timestamptz default null,p_cursor_conversation_id uuid default null,
  p_limit integer default 30,p_search text default null,p_unread_only boolean default false
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
  result jsonb; code text; normalized_search text:=nullif(btrim(p_search),'');
begin
 begin
  select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.read');
  if p_limit is null or p_limit not between 1 and 100
     or (p_cursor_activity_at is null)<>(p_cursor_conversation_id is null)
     or length(coalesce(normalized_search,''))>100 then
    raise invalid_parameter_value using detail='CHAT_INVALID_INPUT';
  end if;
  with candidate as(
    select conversation_row.id,conversation_row.title,conversation_row.conversation_type,
      conversation_row.scope_kind,conversation_row.institution_id,conversation_row.is_read_only,
      latest.id latest_message_id,latest.body_text latest_message_text,
      latest.created_at latest_message_at,
      coalesce(latest.created_at,conversation_row.updated_at) activity_at,
      (select count(*) from public.messages unread_message
       left join app_private.superadmin_internal_chat_receipts receipt
         on receipt.message_id=unread_message.id
        and receipt.internal_identity_id=ctx.internal_identity_id
       where unread_message.conversation_id=conversation_row.id
         and unread_message.status='active' and unread_message.deleted_at is null
         and unread_message.author_internal_identity_id is distinct from ctx.internal_identity_id
         and receipt.read_at is null) unread_count
    from public.conversations conversation_row
    left join lateral(select message_row.id,message_row.body_text,message_row.created_at
      from public.messages message_row where message_row.conversation_id=conversation_row.id
       and message_row.status='active' and message_row.deleted_at is null
      order by message_row.created_at desc,message_row.id desc limit 1) latest on true
    where (ctx.scope_kind<>'institution' or conversation_row.institution_id=ctx.scope_institution_id)
      and (normalized_search is null or conversation_row.title ilike '%'||normalized_search||'%'
        or latest.body_text ilike '%'||normalized_search||'%')
  ), eligible as(select * from candidate where not p_unread_only or unread_count>0),
  filtered as(select * from eligible where
    p_cursor_activity_at is null or (activity_at,id)<(p_cursor_activity_at,p_cursor_conversation_id)),
  page as(select * from filtered order by activity_at desc,id desc limit p_limit+1),
  stats as(select count(*) total,coalesce(sum(unread_count),0) total_unread from eligible)
  select pg_catalog.jsonb_build_object(
    'items',coalesce((select jsonb_agg(jsonb_build_object(
      'conversation_id',item.id,'title',coalesce(item.title,''),
      'conversation_type',item.conversation_type,'scope_kind',item.scope_kind,
      'institution_id',item.institution_id,'latest_message_id',item.latest_message_id,
      'latest_message_text',coalesce(item.latest_message_text,''),
      'latest_message_at',item.latest_message_at,'unread_count',item.unread_count,
      'activity_at',item.activity_at,'is_read_only',item.is_read_only)
      order by item.activity_at desc,item.id desc) from(select * from page limit p_limit)item),'[]'::jsonb),
    'total',(select total from stats),'total_unread',(select total_unread from stats),
    'has_more',(select count(*)>p_limit from page),
    'next_cursor',case when (select count(*) from page)>p_limit then
      (select jsonb_build_object('timestamp',item.activity_at,'id',item.id)
       from(select * from page limit p_limit)item order by item.activity_at,item.id limit 1) else null end
  ) into result;
  return app_private.superadmin_chat_success(result);
 exception when others then get stacked diagnostics code=pg_exception_detail;
  code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 perform app_private.audit_superadmin_internal_denial_if_identified(
   'chat.internal.read','chat.inbox',code,correlation);
 return app_private.superadmin_chat_error(code,correlation);
end $$;

create function public.superadmin_chat_unread_total_v2()
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
  total bigint; code text;
begin begin
 select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.read');
 select count(*) into total from public.messages message_row
 join public.conversations conversation_row on conversation_row.id=message_row.conversation_id
 left join app_private.superadmin_internal_chat_receipts receipt
   on receipt.message_id=message_row.id and receipt.internal_identity_id=ctx.internal_identity_id
 where message_row.status='active' and message_row.deleted_at is null and receipt.read_at is null
   and message_row.author_internal_identity_id is distinct from ctx.internal_identity_id
   and (ctx.scope_kind<>'institution' or conversation_row.institution_id=ctx.scope_institution_id);
 return app_private.superadmin_chat_success(jsonb_build_object('total_unread',total));
exception when others then get stacked diagnostics code=pg_exception_detail;
 code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 perform app_private.audit_superadmin_internal_denial_if_identified(
  'chat.internal.read','chat.unread_total',code,correlation);
 return app_private.superadmin_chat_error(code,correlation); end $$;

create function public.superadmin_chat_thread_v2(
 p_conversation_id uuid,p_cursor_created_at timestamptz default null,
 p_cursor_message_id uuid default null,p_limit integer default 50
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 result jsonb; code text; institution uuid;
begin begin
 select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.read');
 if p_conversation_id is null or p_limit is null or p_limit not between 1 and 100
   or (p_cursor_created_at is null)<>(p_cursor_message_id is null) then
  raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;
 select institution_id into institution from public.conversations where id=p_conversation_id
  and (ctx.scope_kind<>'institution' or institution_id=ctx.scope_institution_id);
 if institution is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
 with filtered as(select message_row.* from public.messages message_row
   where message_row.conversation_id=p_conversation_id and message_row.status='active'
    and message_row.deleted_at is null and (p_cursor_created_at is null
      or (message_row.created_at,message_row.id)<(p_cursor_created_at,p_cursor_message_id))),
 page as(select * from filtered order by created_at desc,id desc limit p_limit+1)
 select jsonb_build_object(
  'items',coalesce((select jsonb_agg(jsonb_build_object(
    'message_id',item.id,'body_text',coalesce(item.body_text,''),'message_type',item.message_type,
    'created_at',item.created_at,'updated_at',item.updated_at,
    'author_name',case when item.author_kind='superadmin_internal' then 'Equipe Coelo'
      else coalesce((select person.display_name from public.people person where person.id=item.author_person_id),'') end,
    'is_mine',item.author_internal_identity_id=ctx.internal_identity_id,
    'attachments',coalesce((select jsonb_agg(jsonb_build_object('id',attachment.id,
      'file_name',attachment.file_name,'content_type',attachment.content_type,
      'byte_size',attachment.byte_size,'sha256',attachment.sha256,
      'upload_status',attachment.upload_status) order by attachment.created_at)
      from public.chat_attachment_metadata attachment where attachment.message_id=item.id),'[]'::jsonb))
    order by item.created_at desc,item.id desc) from(select * from page limit p_limit)item),'[]'::jsonb),
  'total',(select count(*) from public.messages message_row where message_row.conversation_id=p_conversation_id
    and message_row.status='active' and message_row.deleted_at is null),
  'has_more',(select count(*)>p_limit from page),
  'next_cursor',case when (select count(*) from page)>p_limit then
    (select jsonb_build_object('timestamp',item.created_at,'id',item.id)
     from(select * from page limit p_limit)item order by item.created_at,item.id limit 1) else null end
 ) into result;
 return app_private.superadmin_chat_success(result);
exception when others then get stacked diagnostics code=pg_exception_detail;
 code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 perform app_private.audit_superadmin_internal_denial_if_identified(
  'chat.internal.read','chat.thread',code,correlation,institution);
 return app_private.superadmin_chat_error(code,correlation); end $$;

create function public.superadmin_chat_send_message_v2(
 p_conversation_id uuid,p_body_text text,p_request_id uuid
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 normalized_body text:=nullif(btrim(p_body_text),''); institution uuid; read_only boolean;
 request_hash bytea; prior record; created_message public.messages%rowtype; code text;
begin begin
 select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.send');
 if p_conversation_id is null or p_request_id is null or normalized_body is null
   or length(normalized_body)>4000 then raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;
 select institution_id,is_read_only into institution,read_only from public.conversations
  where id=p_conversation_id and status='active'
   and (ctx.scope_kind<>'institution' or institution_id=ctx.scope_institution_id) for share;
 if institution is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
 if read_only then raise object_not_in_prerequisite_state using detail='CHAT_READ_ONLY'; end if;
 request_hash:=extensions.digest(convert_to(jsonb_build_object('conversation_id',p_conversation_id,
   'body_text',normalized_body)::text,'UTF8'),'sha256');
 perform pg_advisory_xact_lock(hashtextextended(ctx.internal_identity_id::text||p_request_id::text,0));
 select * into prior from app_private.superadmin_internal_chat_command_receipts receipt
  where receipt.internal_identity_id=ctx.internal_identity_id and receipt.request_id=p_request_id for update;
 if prior.request_id is not null then
  if prior.request_hash<>request_hash then raise unique_violation using detail='CHAT_REPLAY_MISMATCH'; end if;
  select * into created_message from public.messages where id=prior.message_id;
 else
  insert into public.messages(conversation_id,author_person_id,body_text,message_type,
    author_membership_id,author_experience_kind,author_role_snapshot,author_kind,
    author_internal_identity_id,author_internal_membership_id)
  values(p_conversation_id,null,normalized_body,'text',null,null,ctx.platform_role_code,
    'superadmin_internal',ctx.internal_identity_id,ctx.internal_membership_id)
  returning * into created_message;
  insert into app_private.superadmin_internal_chat_command_receipts(
   request_id,internal_identity_id,conversation_id,request_hash,message_id)
  values(p_request_id,ctx.internal_identity_id,p_conversation_id,request_hash,created_message.id);
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
    ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'chat.internal.send',ctx.aal,'chat.message.send','success',null,correlation,
    institution,'conversation',p_conversation_id,
    jsonb_build_object('id',created_message.id,'created_at',created_message.created_at));
 end if;
 return app_private.superadmin_chat_success(jsonb_build_object(
  'message_id',created_message.id,'body_text',created_message.body_text,
  'message_type',created_message.message_type,'created_at',created_message.created_at,
  'updated_at',created_message.updated_at,'author_name','Equipe Coelo','is_mine',true,
  'attachments','[]'::jsonb,'replayed',prior.request_id is not null));
exception when others then get stacked diagnostics code=pg_exception_detail;
 code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 perform app_private.audit_superadmin_internal_denial_if_identified(
  'chat.internal.send','chat.message.send',code,correlation,institution);
 return app_private.superadmin_chat_error(code,correlation); end $$;

create function public.superadmin_chat_mark_read_v2(p_conversation_id uuid,p_through_message_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 cutoff timestamptz; institution uuid; marked_at timestamptz:=now(); count_written integer; code text;
begin begin
 select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.read');
 if p_conversation_id is null or p_through_message_id is null then
  raise invalid_parameter_value using detail='CHAT_INVALID_INPUT'; end if;
 select institution_id into institution from public.conversations where id=p_conversation_id
   and (ctx.scope_kind<>'institution' or institution_id=ctx.scope_institution_id);
 select created_at into cutoff from public.messages where id=p_through_message_id
   and conversation_id=p_conversation_id and status='active' and deleted_at is null;
 if institution is null or cutoff is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
 with written as(insert into app_private.superadmin_internal_chat_receipts(
   message_id,internal_identity_id,delivered_at,read_at)
  select message_row.id,ctx.internal_identity_id,marked_at,marked_at from public.messages message_row
  where message_row.conversation_id=p_conversation_id and message_row.status='active'
   and message_row.deleted_at is null and message_row.created_at<=cutoff
   and message_row.author_internal_identity_id is distinct from ctx.internal_identity_id
  on conflict(message_id,internal_identity_id) do update set
   delivered_at=coalesce(app_private.superadmin_internal_chat_receipts.delivered_at,excluded.delivered_at),
   read_at=excluded.read_at returning 1)
 select count(*) into count_written from written;
 perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
   ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
   'chat.internal.read',ctx.aal,'chat.conversation.read','success',null,correlation,
   institution,'conversation',p_conversation_id,jsonb_build_object('updated_count',count_written));
 return app_private.superadmin_chat_success(jsonb_build_object(
   'updated_count',count_written,'read_at',marked_at));
exception when others then get stacked diagnostics code=pg_exception_detail;
 code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 perform app_private.audit_superadmin_internal_denial_if_identified(
  'chat.internal.read','chat.conversation.read',code,correlation,institution);
 return app_private.superadmin_chat_error(code,correlation); end $$;

create function public.superadmin_chat_realtime_refresh_v2(p_conversation_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid:=gen_random_uuid();
 institution uuid; result jsonb; code text;
begin begin
 select * into strict ctx from app_private.require_superadmin_internal_context('chat.internal.read');
 select institution_id into institution from public.conversations where id=p_conversation_id
   and (ctx.scope_kind<>'institution' or institution_id=ctx.scope_institution_id);
 if institution is null then raise no_data_found using detail='CHAT_NOT_FOUND'; end if;
 select jsonb_build_object('conversation_id',conversation_row.id,
   'latest_message_id',latest.id,'latest_message_at',coalesce(latest.created_at,conversation_row.updated_at),
   'unread_count',(select count(*) from public.messages unread_message
    left join app_private.superadmin_internal_chat_receipts receipt on receipt.message_id=unread_message.id
      and receipt.internal_identity_id=ctx.internal_identity_id
    where unread_message.conversation_id=conversation_row.id and unread_message.status='active'
      and unread_message.deleted_at is null and receipt.read_at is null
      and unread_message.author_internal_identity_id is distinct from ctx.internal_identity_id)) into result
 from public.conversations conversation_row left join lateral(
   select message_row.id,message_row.created_at from public.messages message_row
   where message_row.conversation_id=conversation_row.id and message_row.status='active'
    and message_row.deleted_at is null order by message_row.created_at desc,message_row.id desc limit 1)latest on true
 where conversation_row.id=p_conversation_id;
 return app_private.superadmin_chat_success(result);
exception when others then get stacked diagnostics code=pg_exception_detail;
 code:=coalesce(nullif(code,''),'SAI_INTERNAL_ERROR'); end;
 perform app_private.audit_superadmin_internal_denial_if_identified(
  'chat.internal.read','chat.realtime.refresh',code,correlation,institution);
 return app_private.superadmin_chat_error(code,correlation); end $$;

-- Contextual clients must also receive and acknowledge messages authored by the
-- separate internal realm. `IS DISTINCT FROM` is intentional because an
-- internal message has no people-realm author id.
create or replace function public.chat_inbox_page(
 p_cursor_activity_at timestamptz default null,p_cursor_conversation_id uuid default null,
 p_limit integer default 30,p_search text default null,p_unread_only boolean default false
) returns table(conversation_id uuid,title text,conversation_type text,scope_kind text,
 latest_message_id uuid,latest_message_text text,latest_message_at timestamptz,
 unread_count bigint,next_cursor_activity_at timestamptz,next_cursor_conversation_id uuid,
 is_read_only boolean)
language plpgsql stable security invoker set search_path='' as $$
begin
 if p_limit not between 1 and 100 then raise invalid_parameter_value using message='page limit must be between 1 and 100'; end if;
 if (p_cursor_activity_at is null)<>(p_cursor_conversation_id is null) then raise invalid_parameter_value using message='cursor values must be provided together'; end if;
 if length(coalesce(btrim(p_search),''))>100 then raise invalid_parameter_value using message='search is too long'; end if;
 return query with candidate as(select conversation_row.id,conversation_row.title,
  conversation_row.conversation_type,conversation_row.scope_kind,conversation_row.is_read_only,
  latest.id latest_message_id,latest.body_text latest_message_text,latest.created_at latest_message_at,
  coalesce(latest.created_at,conversation_row.updated_at) activity_at,
  (select count(*) from public.messages unread_message
   left join public.message_receipts receipt on receipt.message_id=unread_message.id
    and receipt.person_id=app_private.current_person_id()
   where unread_message.conversation_id=conversation_row.id and unread_message.status='active'
    and unread_message.deleted_at is null
    and unread_message.author_person_id is distinct from app_private.current_person_id()
    and receipt.read_at is null) unread_count
 from public.conversations conversation_row left join lateral(
  select message_row.id,message_row.body_text,message_row.created_at from public.messages message_row
  where message_row.conversation_id=conversation_row.id and message_row.status='active'
   and message_row.deleted_at is null order by message_row.created_at desc,message_row.id desc limit 1
 )latest on true where app_private.can_access_chat_conversation(conversation_row.id,false)
  and (nullif(btrim(p_search),'') is null or conversation_row.title ilike '%'||btrim(p_search)||'%'
   or latest.body_text ilike '%'||btrim(p_search)||'%')),
 filtered as(select * from candidate where(not p_unread_only or unread_count>0)
  and(p_cursor_activity_at is null or(activity_at,id)<(p_cursor_activity_at,p_cursor_conversation_id))
  order by activity_at desc,id desc limit p_limit)
 select id,title,conversation_type,scope_kind,latest_message_id,latest_message_text,
  latest_message_at,unread_count,activity_at,id,is_read_only from filtered
 order by activity_at desc,id desc;
end $$;

create or replace function public.chat_thread_page(
 p_conversation_id uuid,p_cursor_created_at timestamptz default null,
 p_cursor_message_id uuid default null,p_limit integer default 50
) returns table(message_id uuid,author_person_id uuid,author_name text,is_mine boolean,
 body_text text,message_type text,created_at timestamptz,updated_at timestamptz,
 attachments jsonb,next_cursor_created_at timestamptz,next_cursor_message_id uuid)
language plpgsql stable security invoker set search_path='' as $$
begin
 if p_limit not between 1 and 100 then raise invalid_parameter_value using message='page limit must be between 1 and 100'; end if;
 if (p_cursor_created_at is null)<>(p_cursor_message_id is null) then raise invalid_parameter_value using message='cursor values must be provided together'; end if;
 return query select message_row.id,message_row.author_person_id,
  case when message_row.author_kind='superadmin_internal' then 'Equipe Coelo'
   else app_private.chat_author_display_name(message_row.conversation_id,message_row.author_person_id) end,
  message_row.author_kind='person' and message_row.author_person_id=app_private.current_person_id(),
  message_row.body_text,message_row.message_type,message_row.created_at,message_row.updated_at,
  coalesce(attachment_rows.attachments,'[]'::jsonb),message_row.created_at,message_row.id
 from public.messages message_row left join lateral(select jsonb_agg(jsonb_build_object(
   'id',attachment.id,'file_name',attachment.file_name,'content_type',attachment.content_type,
   'byte_size',attachment.byte_size,'sha256',attachment.sha256,'upload_status',attachment.upload_status)
   order by attachment.created_at)attachments from public.chat_attachment_metadata attachment
   where attachment.message_id=message_row.id)attachment_rows on true
 where message_row.conversation_id=p_conversation_id and message_row.status='active'
  and message_row.deleted_at is null and app_private.can_access_chat_conversation(message_row.conversation_id,false)
  and(p_cursor_created_at is null or(message_row.created_at,message_row.id)<(p_cursor_created_at,p_cursor_message_id))
 order by message_row.created_at desc,message_row.id desc limit p_limit;
end $$;

create or replace function public.chat_unread_total()
returns table(total_unread bigint) language sql stable security invoker set search_path='' as $$
 select count(*) from public.messages message_row
 left join public.message_receipts receipt on receipt.message_id=message_row.id
  and receipt.person_id=app_private.current_person_id()
 where message_row.status='active' and message_row.deleted_at is null
  and message_row.author_person_id is distinct from app_private.current_person_id()
  and receipt.read_at is null
  and app_private.can_access_chat_conversation(message_row.conversation_id,false)
$$;

create or replace function app_private.chat_mark_read(
 p_conversation_id uuid,p_through_message_id uuid default null
) returns table(updated_count integer,read_at timestamptz)
language plpgsql volatile security definer set search_path='' as $$
declare actor_id uuid:=app_private.current_person_id();cutoff timestamptz;marked_at timestamptz:=now();
begin
 if actor_id is null then raise insufficient_privilege using message='authentication required'; end if;
 if not app_private.can_access_chat_conversation(p_conversation_id,false) then return query select 0,marked_at;return; end if;
 if p_through_message_id is not null then
  select created_at into cutoff from public.messages where id=p_through_message_id
   and conversation_id=p_conversation_id and status='active' and deleted_at is null;
  if cutoff is null then return query select 0,marked_at;return; end if;
 end if;
 insert into audit.audit_logs(actor_person_id,action_code,object_type,object_id,institution_id,outcome,after_json)
 select actor_id,'chat.conversation.read','conversation',conversation_row.id,
  conversation_row.institution_id,'success',jsonb_build_object('through_message_id',p_through_message_id)
 from public.conversations conversation_row where conversation_row.id=p_conversation_id;
 return query with written as(insert into public.message_receipts(message_id,person_id,delivered_at,read_at)
  select message_row.id,actor_id,marked_at,marked_at from public.messages message_row
  where message_row.conversation_id=p_conversation_id and message_row.status='active'
   and message_row.deleted_at is null and message_row.author_person_id is distinct from actor_id
   and(cutoff is null or message_row.created_at<=cutoff)
  on conflict(message_id,person_id) do update set
   delivered_at=coalesce(public.message_receipts.delivered_at,excluded.delivered_at),
   read_at=coalesce(public.message_receipts.read_at,excluded.read_at)
  where public.message_receipts.read_at is null returning 1)
 select count(*)::integer,marked_at from written;
end $$;

do $$declare p regprocedure; begin foreach p in array array[
 'app_private.superadmin_chat_success(jsonb)'::regprocedure,
 'app_private.superadmin_chat_error(text,uuid)'::regprocedure,
 'app_private.guard_chat_message_internal_author()'::regprocedure,
 'public.superadmin_chat_inbox_v2(timestamptz,uuid,integer,text,boolean)'::regprocedure,
 'public.superadmin_chat_unread_total_v2()'::regprocedure,
 'public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer)'::regprocedure,
 'public.superadmin_chat_send_message_v2(uuid,text,uuid)'::regprocedure,
 'public.superadmin_chat_mark_read_v2(uuid,uuid)'::regprocedure,
 'public.superadmin_chat_realtime_refresh_v2(uuid)'::regprocedure
] loop execute format('alter function %s owner to postgres',p);
 execute format('revoke all on function %s from public,anon,authenticated,service_role',p); end loop; end $$;

grant execute on function public.superadmin_chat_inbox_v2(timestamptz,uuid,integer,text,boolean) to authenticated;
grant execute on function public.superadmin_chat_unread_total_v2() to authenticated;
grant execute on function public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer) to authenticated;
grant execute on function public.superadmin_chat_send_message_v2(uuid,text,uuid) to authenticated;
grant execute on function public.superadmin_chat_mark_read_v2(uuid,uuid) to authenticated;
grant execute on function public.superadmin_chat_realtime_refresh_v2(uuid) to authenticated;

commit;
