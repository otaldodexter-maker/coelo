-- Contextual chat configuration, routing, participants and author snapshots.

create table public.institution_chat_settings (
  institution_id uuid primary key references public.institutions(id) on delete cascade,
  channel_mode text not null default 'both'
    check (channel_mode in ('institution_only','unit_only','both','unified')),
  institution_chat_enabled boolean not null default true,
  unit_chat_enabled boolean not null default true,
  changed_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint institution_chat_settings_mode_check check (
    (channel_mode='institution_only' and institution_chat_enabled and not unit_chat_enabled)
    or (channel_mode='unit_only' and not institution_chat_enabled and unit_chat_enabled)
    or (channel_mode in ('both','unified') and institution_chat_enabled and unit_chat_enabled)
  )
);

create table public.unit_chat_settings (
  unit_id uuid primary key references public.units(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  is_enabled boolean not null default true,
  changed_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.conversation_routing_teams (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  unit_id uuid references public.units(id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  handles_institution_chat boolean not null default false,
  handles_unit_chat boolean not null default false,
  status public.record_status not null default 'active',
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index conversation_routing_teams_scope_name_uidx
  on public.conversation_routing_teams(
    institution_id,coalesce(unit_id,'00000000-0000-0000-0000-000000000000'::uuid),
    lower(name)
  ) where status='active';

create table public.conversation_routing_team_members (
  team_id uuid not null references public.conversation_routing_teams(id) on delete cascade,
  membership_id uuid not null references public.institution_memberships(id) on delete cascade,
  status public.record_status not null default 'active',
  added_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  removed_at timestamptz,
  primary key(team_id,membership_id)
);

alter table public.conversations
  add column unit_id uuid references public.units(id) on delete cascade,
  add column group_id uuid references public.groups(id) on delete cascade,
  add column activity_id uuid references public.activity_definitions(id) on delete cascade,
  add column routing_team_id uuid
    references public.conversation_routing_teams(id) on delete set null,
  add column is_read_only boolean not null default false,
  add column read_only_reason text;

create table public.conversation_participants (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  person_id uuid not null references public.people(id) on delete cascade,
  membership_id uuid references public.institution_memberships(id) on delete cascade,
  experience_kind text not null check (experience_kind in ('family','professional')),
  role_snapshot text not null check (btrim(role_snapshot) <> ''),
  status public.record_status not null default 'active',
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index conversation_participants_active_uidx
  on public.conversation_participants(conversation_id,person_id,experience_kind)
  where status='active' and left_at is null;
create index conversation_participants_person_idx
  on public.conversation_participants(person_id,status,conversation_id);

create table public.conversation_child_contexts (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  child_context_id uuid not null references public.child_contexts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(conversation_id,child_context_id)
);

alter table public.messages
  add column author_membership_id uuid
    references public.institution_memberships(id) on delete set null,
  add column author_experience_kind text
    check (author_experience_kind in ('family','professional')),
  add column author_role_snapshot text;

create table public.message_child_contexts (
  message_id uuid not null references public.messages(id) on delete cascade,
  child_context_id uuid not null references public.child_contexts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(message_id,child_context_id)
);

create or replace function app_private.validate_chat_context_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare target_institution_id uuid;
begin
  if tg_table_name='unit_chat_settings' then
    select institution_id into target_institution_id
    from public.units where id=new.unit_id;
    if target_institution_id is null or target_institution_id<>new.institution_id
    then raise exception 'unit chat tenant mismatch'; end if;
  elsif tg_table_name='conversation_routing_teams' then
    if new.unit_id is not null and not exists (
      select 1 from public.units
      where id=new.unit_id and institution_id=new.institution_id
    ) then raise exception 'routing team tenant mismatch'; end if;
  elsif tg_table_name='conversation_routing_team_members' then
    if not exists (
      select 1 from public.conversation_routing_teams team
      join public.institution_memberships membership
        on membership.id=new.membership_id
       and membership.institution_id=team.institution_id
      where team.id=new.team_id
    ) then raise exception 'routing member tenant mismatch'; end if;
  elsif tg_table_name='conversations' then
    if new.scope_kind not in ('institution','unit','group','activity') then
      raise exception 'invalid conversation scope';
    end if;
    if new.scope_kind='institution' and (
      new.unit_id is not null or new.group_id is not null or new.activity_id is not null
    ) then raise exception 'institution conversation has child scope'; end if;
    if new.scope_kind='unit' and (
      new.unit_id is null or new.group_id is not null or new.activity_id is not null
    ) then raise exception 'invalid unit conversation scope'; end if;
    if new.scope_kind='group' and (
      new.unit_id is null or new.group_id is null or new.activity_id is not null
    ) then raise exception 'invalid group conversation scope'; end if;
    if new.scope_kind='activity' and (
      new.unit_id is null or new.group_id is null or new.activity_id is null
    ) then raise exception 'invalid activity conversation scope'; end if;
    if new.unit_id is not null and not exists (
      select 1 from public.units where id=new.unit_id
        and institution_id=new.institution_id
    ) then raise exception 'conversation unit tenant mismatch'; end if;
    if new.group_id is not null and not exists (
      select 1 from public.groups where id=new.group_id
        and unit_id=new.unit_id and institution_id=new.institution_id
    ) then raise exception 'conversation group tenant mismatch'; end if;
    if new.activity_id is not null and not exists (
      select 1 from public.activity_group_links link
      where link.activity_id=new.activity_id and link.group_id=new.group_id
        and link.unit_id=new.unit_id and link.institution_id=new.institution_id
    ) then raise exception 'conversation activity context mismatch'; end if;
  elsif tg_table_name='conversation_participants' then
    if new.membership_id is not null and not exists (
      select 1 from public.conversations conversation_row
      join public.institution_memberships membership
        on membership.id=new.membership_id
       and membership.institution_id=conversation_row.institution_id
       and membership.person_id=new.person_id
      where conversation_row.id=new.conversation_id
    ) then raise exception 'participant membership mismatch'; end if;
  elsif tg_table_name in ('conversation_child_contexts','message_child_contexts') then
    if tg_table_name='conversation_child_contexts' and not exists (
      select 1 from public.conversations conversation_row
      join public.child_contexts child_context
        on child_context.id=new.child_context_id
       and child_context.institution_id=conversation_row.institution_id
      where conversation_row.id=new.conversation_id
    ) then raise exception 'conversation child tenant mismatch'; end if;
    if tg_table_name='message_child_contexts' and not exists (
      select 1 from public.messages message_row
      join public.conversations conversation_row
        on conversation_row.id=message_row.conversation_id
      join public.child_contexts child_context
        on child_context.id=new.child_context_id
       and child_context.institution_id=conversation_row.institution_id
      where message_row.id=new.message_id
    ) then raise exception 'message child tenant mismatch'; end if;
  end if;
  return new;
end;
$$;

create trigger unit_chat_settings_validate before insert or update
on public.unit_chat_settings for each row
execute function app_private.validate_chat_context_row();
create trigger conversation_routing_teams_validate before insert or update
on public.conversation_routing_teams for each row
execute function app_private.validate_chat_context_row();
create trigger conversation_routing_team_members_validate before insert or update
on public.conversation_routing_team_members for each row
execute function app_private.validate_chat_context_row();
create trigger conversations_context_validate before insert or update
on public.conversations for each row
execute function app_private.validate_chat_context_row();
create trigger conversation_participants_validate before insert or update
on public.conversation_participants for each row
execute function app_private.validate_chat_context_row();
create trigger conversation_child_contexts_validate before insert or update
on public.conversation_child_contexts for each row
execute function app_private.validate_chat_context_row();
create trigger message_child_contexts_validate before insert or update
on public.message_child_contexts for each row
execute function app_private.validate_chat_context_row();

create or replace function app_private.can_access_conversation(
  target_conversation_id uuid,
  require_write boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.conversations conversation_row
    where conversation_row.id=target_conversation_id
      and (not require_write or (
        conversation_row.status='active' and not conversation_row.is_read_only
      ))
      and (
        app_private.has_platform_permission('platform.read')
        or exists (
          select 1 from public.conversation_participants participant
          where participant.conversation_id=conversation_row.id
            and participant.person_id=app_private.current_person_id()
            and participant.status='active' and participant.left_at is null
        )
        or app_private.has_context_permission(
          conversation_row.institution_id,
          case when require_write then 'chat.manage' else 'chat.read' end,
          conversation_row.unit_id,conversation_row.group_id,
          conversation_row.activity_id,null,
          conversation_row.scope_kind='institution'
        )
      )
  )
$$;

create or replace function app_private.send_context_message(
  target_conversation_id uuid,
  target_body_text text,
  target_child_context_ids uuid[] default array[]::uuid[]
)
returns public.messages
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_person_id uuid:=app_private.current_person_id();
  participant_record public.conversation_participants%rowtype;
  created_message public.messages%rowtype;
begin
  if nullif(btrim(target_body_text),'') is null then
    raise exception 'message body required';
  end if;
  if not app_private.can_access_conversation(target_conversation_id,true) then
    raise exception 'conversation is not writable';
  end if;
  select * into participant_record
  from public.conversation_participants
  where conversation_id=target_conversation_id and person_id=actor_person_id
    and status='active' and left_at is null
  order by joined_at desc limit 1;
  if participant_record.id is null then
    raise exception 'active participant required to send';
  end if;
  if exists (
    select 1 from unnest(target_child_context_ids) child_id
    where not exists (
      select 1 from public.conversation_child_contexts conversation_child
      where conversation_child.conversation_id=target_conversation_id
        and conversation_child.child_context_id=child_id
    )
  ) then raise exception 'message child is outside conversation'; end if;

  insert into public.messages(
    conversation_id,author_person_id,body_text,message_type,
    author_membership_id,author_experience_kind,author_role_snapshot
  ) values (
    target_conversation_id,actor_person_id,btrim(target_body_text),'text',
    participant_record.membership_id,participant_record.experience_kind,
    participant_record.role_snapshot
  ) returning * into created_message;

  insert into public.message_child_contexts(message_id,child_context_id)
  select distinct created_message.id,child_id
  from unnest(target_child_context_ids) child_id;
  return created_message;
end;
$$;

create or replace function public.send_context_message(
  conversation_id uuid,
  body_text text,
  child_context_ids uuid[] default array[]::uuid[]
)
returns public.messages
language sql
volatile
security invoker
set search_path=''
as $$
  select app_private.send_context_message(
    conversation_id,body_text,child_context_ids
  )
$$;

do $$
declare current_table text;
begin
  foreach current_table in array array[
    'institution_chat_settings','unit_chat_settings',
    'conversation_routing_teams','conversation_routing_team_members',
    'conversation_participants','conversation_child_contexts',
    'message_child_contexts'
  ] loop
    execute format('alter table public.%I enable row level security',current_table);
    execute format('revoke all on public.%I from public,anon,authenticated',current_table);
    execute format('grant all on public.%I to service_role',current_table);
    execute format('grant select,insert,update on public.%I to authenticated',current_table);
  end loop;
end;
$$;

drop policy if exists conversations_platform_read on public.conversations;
drop policy if exists messages_platform_read on public.messages;
grant select on public.conversations,public.messages to authenticated;

create policy conversations_context_read on public.conversations
for select to authenticated using (app_private.can_access_conversation(id,false));
create policy messages_context_read on public.messages
for select to authenticated using (
  app_private.can_access_conversation(conversation_id,false)
);
create policy conversation_participants_context_read
on public.conversation_participants for select to authenticated
using (app_private.can_access_conversation(conversation_id,false));
create policy conversation_child_contexts_context_read
on public.conversation_child_contexts for select to authenticated
using (app_private.can_access_conversation(conversation_id,false));
create policy message_child_contexts_context_read
on public.message_child_contexts for select to authenticated
using (
  exists (
    select 1 from public.messages message_row
    where message_row.id=message_id
      and app_private.can_access_conversation(message_row.conversation_id,false)
  )
);

create policy institution_chat_settings_context
on public.institution_chat_settings for all to authenticated
using (
  app_private.has_context_permission(
    institution_id,'chat.manage',null,null,null,null,true
  )
)
with check (
  app_private.has_context_permission(
    institution_id,'chat.manage',null,null,null,null,true
  )
);
create policy unit_chat_settings_context
on public.unit_chat_settings for all to authenticated
using (
  app_private.has_context_permission(
    institution_id,'chat.manage',unit_id,null,null,null,false
  )
)
with check (
  app_private.has_context_permission(
    institution_id,'chat.manage',unit_id,null,null,null,false
  )
);
create policy conversation_routing_teams_context
on public.conversation_routing_teams for all to authenticated
using (
  app_private.has_context_permission(
    institution_id,'chat.manage',unit_id,null,null,null,unit_id is null
  )
)
with check (
  app_private.has_context_permission(
    institution_id,'chat.manage',unit_id,null,null,null,unit_id is null
  )
);
create policy conversation_routing_team_members_context
on public.conversation_routing_team_members for all to authenticated
using (
  exists (
    select 1 from public.conversation_routing_teams team
    where team.id=team_id and app_private.has_context_permission(
      team.institution_id,'chat.manage',team.unit_id,null,null,null,
      team.unit_id is null
    )
  )
)
with check (
  exists (
    select 1 from public.conversation_routing_teams team
    where team.id=team_id and app_private.has_context_permission(
      team.institution_id,'chat.manage',team.unit_id,null,null,null,
      team.unit_id is null
    )
  )
);

create policy conversation_participants_manage
on public.conversation_participants for all to authenticated
using (
  exists (
    select 1 from public.conversations conversation_row
    where conversation_row.id=conversation_id and app_private.has_context_permission(
      conversation_row.institution_id,'chat.manage',conversation_row.unit_id,
      conversation_row.group_id,conversation_row.activity_id,null,
      conversation_row.scope_kind='institution'
    )
  )
)
with check (
  exists (
    select 1 from public.conversations conversation_row
    where conversation_row.id=conversation_id and app_private.has_context_permission(
      conversation_row.institution_id,'chat.manage',conversation_row.unit_id,
      conversation_row.group_id,conversation_row.activity_id,null,
      conversation_row.scope_kind='institution'
    )
  )
);
create policy conversation_child_contexts_manage
on public.conversation_child_contexts for all to authenticated
using (
  exists (
    select 1 from public.conversations conversation_row
    where conversation_row.id=conversation_id and app_private.has_context_permission(
      conversation_row.institution_id,'chat.manage',conversation_row.unit_id,
      conversation_row.group_id,conversation_row.activity_id,child_context_id,
      conversation_row.scope_kind='institution'
    )
  )
)
with check (
  exists (
    select 1 from public.conversations conversation_row
    where conversation_row.id=conversation_id and app_private.has_context_permission(
      conversation_row.institution_id,'chat.manage',conversation_row.unit_id,
      conversation_row.group_id,conversation_row.activity_id,child_context_id,
      conversation_row.scope_kind='institution'
    )
  )
);

revoke all on function app_private.validate_chat_context_row()
  from public,anon,authenticated;
revoke all on function app_private.can_access_conversation(uuid,boolean)
  from public,anon;
grant execute on function app_private.can_access_conversation(uuid,boolean)
  to authenticated,service_role;
revoke all on function app_private.send_context_message(uuid,text,uuid[])
  from public,anon;
grant execute on function app_private.send_context_message(uuid,text,uuid[])
  to authenticated,service_role;
revoke all on function public.send_context_message(uuid,text,uuid[])
  from public,anon;
grant execute on function public.send_context_message(uuid,text,uuid[])
  to authenticated;

with table_catalog(table_name,table_label,table_description,domain) as (
  values
    ('institution_chat_settings','Chat institucional','Modo de canais da instituicao.','chat'),
    ('unit_chat_settings','Chat da unidade','Disponibilidade de chat por unidade.','chat'),
    ('conversation_routing_teams','Equipes de conversa','Equipes que atendem canais.','chat'),
    ('conversation_routing_team_members','Membros das equipes','Profissionais roteados para conversas.','chat'),
    ('conversation_participants','Participantes da conversa','Pessoa, experiencia e papel contextual.','chat'),
    ('conversation_child_contexts','Criancas da conversa','Zero, uma ou varias criancas relacionadas.','chat'),
    ('message_child_contexts','Criancas da mensagem','Snapshot de sujeitos relacionados.','chat')
)
insert into public.schema_tables(
  schema_name,table_name,table_label,table_description,domain,status,version,updated_at
)
select 'public',table_name,table_label,table_description,domain,'active',1,now()
from table_catalog
on conflict(schema_name,table_name,version) do update set
  table_label=excluded.table_label,table_description=excluded.table_description,
  domain=excluded.domain,status=excluded.status,updated_at=now();

insert into public.schema_columns(
  schema_table_id,column_name,column_label,column_description,column_type,
  is_required,is_nullable,is_unique,is_filterable,is_importable,is_active,
  position,allowed_locales_json,aliases_json,examples_json,updated_at
)
select st.id,c.column_name,replace(c.column_name,'_',' '),
  'Campo de conversa '||c.column_name||'.',c.data_type,c.is_nullable='NO',
  c.is_nullable='YES',false,c.column_name in (
    'institution_id','unit_id','group_id','activity_id','conversation_id',
    'person_id','membership_id','child_context_id','status'
  ),false,true,c.ordinal_position,'["pt-BR"]'::jsonb,'{}'::jsonb,'[]'::jsonb,now()
from information_schema.columns c join public.schema_tables st
  on st.schema_name=c.table_schema and st.table_name=c.table_name and st.version=1
where c.table_schema='public' and c.table_name in (
  'institution_chat_settings','unit_chat_settings',
  'conversation_routing_teams','conversation_routing_team_members',
  'conversation_participants','conversation_child_contexts','message_child_contexts'
)
on conflict(schema_table_id,column_name) do update set
  column_type=excluded.column_type,is_required=excluded.is_required,
  is_nullable=excluded.is_nullable,is_filterable=excluded.is_filterable,
  is_active=true,position=excluded.position,updated_at=now();
