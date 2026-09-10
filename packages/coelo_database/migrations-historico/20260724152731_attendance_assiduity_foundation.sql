-- Attendance and assiduity: family notices are pending intent; only an
-- authorized professional creates the official record.

create table public.attendance_reason_catalog (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  unit_id uuid references public.units(id) on delete cascade,
  code text not null check (code ~ '^[a-z][a-z0-9_]*$'),
  name text not null check (btrim(name) <> ''),
  applies_to text[] not null default array[
    'absence','expected_presence','late_arrival','early_departure'
  ]::text[],
  requires_attachment boolean not null default false,
  status public.record_status not null default 'active',
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index attendance_reason_catalog_scope_code_uidx
  on public.attendance_reason_catalog(
    institution_id,coalesce(unit_id,'00000000-0000-0000-0000-000000000000'::uuid),
    code
  ) where status='active';

create table public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  group_id uuid not null references public.groups(id) on delete cascade,
  activity_id uuid references public.activity_definitions(id) on delete cascade,
  session_kind text not null check (session_kind in ('group','activity')),
  session_date date not null,
  starts_at timestamptz,
  ends_at timestamptz,
  status text not null default 'open'
    check (status in ('draft','open','closed','cancelled')),
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  closed_by_person_id uuid references public.people(id) on delete restrict,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint attendance_sessions_kind_check check (
    (session_kind='group' and activity_id is null)
    or (session_kind='activity' and activity_id is not null)
  ),
  constraint attendance_sessions_dates_check
    check (ends_at is null or starts_at is null or ends_at>starts_at)
);
create unique index attendance_sessions_context_date_uidx
  on public.attendance_sessions(
    group_id,coalesce(activity_id,'00000000-0000-0000-0000-000000000000'::uuid),
    session_date
  ) where status<>'cancelled';
create index attendance_sessions_unit_date_idx
  on public.attendance_sessions(unit_id,session_date,status);

create table public.attendance_expected_participants (
  id uuid primary key default gen_random_uuid(),
  attendance_session_id uuid not null
    references public.attendance_sessions(id) on delete cascade,
  child_context_id uuid not null references public.child_contexts(id) on delete cascade,
  child_group_link_id uuid not null
    references public.child_group_links(id) on delete restrict,
  activity_group_participant_id uuid
    references public.activity_group_participants(id) on delete set null,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(attendance_session_id,child_context_id)
);

create table public.attendance_notices (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  group_id uuid not null references public.groups(id) on delete cascade,
  activity_id uuid references public.activity_definitions(id) on delete cascade,
  child_context_id uuid not null references public.child_contexts(id) on delete cascade,
  child_group_link_id uuid not null
    references public.child_group_links(id) on delete restrict,
  guardian_link_id uuid not null references public.guardian_links(id) on delete restrict,
  notice_type text not null check (
    notice_type in ('absence','expected_presence','late_arrival','early_departure')
  ),
  starts_at timestamptz not null,
  ends_at timestamptz,
  reason_id uuid references public.attendance_reason_catalog(id) on delete restrict,
  reason_detail text,
  note text,
  review_status text not null default 'pending'
    check (review_status in ('pending','confirmed','rejected')),
  reviewed_by_person_id uuid references public.people(id) on delete restrict,
  reviewed_at timestamptz,
  review_note text,
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  cancelled_at timestamptz,
  constraint attendance_notices_dates_check
    check (ends_at is null or ends_at>=starts_at),
  constraint attendance_notices_review_check check (
    (review_status='pending' and reviewed_by_person_id is null and reviewed_at is null)
    or (review_status in ('confirmed','rejected')
      and reviewed_by_person_id is not null and reviewed_at is not null)
  ),
  constraint attendance_notices_detail_check
    check (reason_detail is null or btrim(reason_detail) <> '')
);
create index attendance_notices_pending_context_idx
  on public.attendance_notices(unit_id,group_id,starts_at)
  where review_status='pending' and cancelled_at is null;
create index attendance_notices_child_idx
  on public.attendance_notices(child_context_id,starts_at desc);

create table public.attendance_notice_attachments (
  id uuid primary key default gen_random_uuid(),
  attendance_notice_id uuid not null
    references public.attendance_notices(id) on delete cascade,
  media_asset_id uuid not null,
  media_kind text not null default 'document',
  created_at timestamptz not null default now(),
  unique(attendance_notice_id,media_asset_id)
);

create table public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  attendance_session_id uuid not null
    references public.attendance_sessions(id) on delete cascade,
  child_context_id uuid not null references public.child_contexts(id) on delete cascade,
  outcome text not null check (
    outcome in ('present','absent','late_arrival','early_departure','late_and_early')
  ),
  source_notice_id uuid references public.attendance_notices(id) on delete set null,
  note text,
  confirmed_by_person_id uuid not null references public.people(id) on delete restrict,
  confirmed_at timestamptz not null default now(),
  status public.record_status not null default 'active',
  reverted_by_person_id uuid references public.people(id) on delete restrict,
  reverted_at timestamptz,
  revert_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint attendance_records_revert_check check (
    (status='active' and reverted_by_person_id is null
      and reverted_at is null and revert_reason is null)
    or (status='inactive' and reverted_by_person_id is not null
      and reverted_at is not null and btrim(revert_reason) <> '')
  )
);
create unique index attendance_records_current_uidx
  on public.attendance_records(attendance_session_id,child_context_id)
  where status='active';
create index attendance_records_child_idx
  on public.attendance_records(child_context_id,confirmed_at desc);

create table public.attendance_record_revisions (
  id uuid primary key default gen_random_uuid(),
  attendance_record_id uuid not null
    references public.attendance_records(id) on delete cascade,
  action_code text not null check (action_code in ('confirmed','corrected','reverted')),
  before_json jsonb,
  after_json jsonb,
  reason text,
  changed_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index attendance_record_revisions_record_idx
  on public.attendance_record_revisions(attendance_record_id,created_at desc);

create or replace function app_private.validate_attendance_context_row()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if tg_table_name='attendance_reason_catalog' then
    if new.unit_id is not null and not exists (
      select 1 from public.units where id=new.unit_id
        and institution_id=new.institution_id
    ) then raise exception 'attendance reason tenant mismatch'; end if;
  elsif tg_table_name='attendance_sessions' then
    if not exists (
      select 1 from public.groups group_row
      where group_row.id=new.group_id and group_row.unit_id=new.unit_id
        and group_row.institution_id=new.institution_id
    ) then raise exception 'attendance session context mismatch'; end if;
    if new.activity_id is not null and not exists (
      select 1 from public.activity_group_links link
      where link.activity_id=new.activity_id and link.group_id=new.group_id
        and link.unit_id=new.unit_id and link.institution_id=new.institution_id
        and link.status='active'
    ) then raise exception 'attendance activity context mismatch'; end if;
  elsif tg_table_name='attendance_expected_participants' then
    if not exists (
      select 1
      from public.attendance_sessions session_row
      join public.child_group_links child_group
        on child_group.id=new.child_group_link_id
       and child_group.group_id=session_row.group_id
      join public.child_unit_links child_unit
        on child_unit.id=child_group.child_unit_link_id
       and child_unit.unit_id=session_row.unit_id
      join public.child_contexts child_context
        on child_context.id=child_unit.child_context_id
       and child_context.id=new.child_context_id
       and child_context.institution_id=session_row.institution_id
      where session_row.id=new.attendance_session_id
        and (
          session_row.activity_id is null
          or new.activity_group_participant_id is not null
        )
    ) then raise exception 'attendance participant context mismatch'; end if;
  elsif tg_table_name='attendance_notices' then
    if not exists (
      select 1
      from public.child_group_links child_group
      join public.child_unit_links child_unit
        on child_unit.id=child_group.child_unit_link_id
      join public.child_contexts child_context
        on child_context.id=child_unit.child_context_id
      join public.groups group_row on group_row.id=child_group.group_id
      where child_group.id=new.child_group_link_id
        and child_context.id=new.child_context_id
        and child_context.institution_id=new.institution_id
        and child_unit.unit_id=new.unit_id
        and group_row.id=new.group_id
    ) then raise exception 'attendance notice context mismatch'; end if;
    if new.activity_id is not null and not exists (
      select 1 from public.activity_group_links link
      where link.activity_id=new.activity_id and link.group_id=new.group_id
        and link.unit_id=new.unit_id and link.institution_id=new.institution_id
    ) then raise exception 'attendance notice activity mismatch'; end if;
  elsif tg_table_name='attendance_records' then
    if not exists (
      select 1 from public.attendance_expected_participants participant
      where participant.attendance_session_id=new.attendance_session_id
        and participant.child_context_id=new.child_context_id
        and participant.status='active'
    ) then raise exception 'official attendance requires expected participant'; end if;
  end if;
  return new;
end;
$$;

create trigger attendance_reason_catalog_validate before insert or update
on public.attendance_reason_catalog for each row
execute function app_private.validate_attendance_context_row();
create trigger attendance_sessions_validate before insert or update
on public.attendance_sessions for each row
execute function app_private.validate_attendance_context_row();
create trigger attendance_expected_participants_validate before insert or update
on public.attendance_expected_participants for each row
execute function app_private.validate_attendance_context_row();
create trigger attendance_notices_validate before insert or update
on public.attendance_notices for each row
execute function app_private.validate_attendance_context_row();
create trigger attendance_records_validate before insert or update
on public.attendance_records for each row
execute function app_private.validate_attendance_context_row();

create or replace function app_private.can_access_attendance_child(
  target_institution_id uuid,target_unit_id uuid,target_group_id uuid,
  target_activity_id uuid,target_child_context_id uuid,require_manage boolean
)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select
    app_private.has_platform_permission('platform.read')
    or app_private.has_context_permission(
      target_institution_id,
      case when require_manage then 'attendance.manage' else 'attendance.read' end,
      target_unit_id,target_group_id,target_activity_id,target_child_context_id,false
    )
    or (
      not require_manage
      and app_private.guardian_has_capability(
        target_child_context_id,'manage_attendance_notices'
      )
    )
    or (
      target_activity_id is not null
      and app_private.has_activity_capability(
        target_activity_id,target_group_id,'attendance'
      )
    )
$$;

create or replace function app_private.submit_attendance_notice(
  target_child_group_link_id uuid,
  target_notice_type text,
  target_starts_at timestamptz,
  target_ends_at timestamptz,
  target_reason_id uuid,
  target_reason_detail text,
  target_note text,
  target_attachment_media_id uuid
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  actor_person_id uuid:=app_private.current_person_id();
  context_record record;
  guardian_link_id uuid;
  created_notice_id uuid;
  notification_id uuid;
begin
  if target_notice_type not in (
    'absence','expected_presence','late_arrival','early_departure'
  ) then raise exception 'invalid attendance notice type'; end if;
  select child_context.id child_context_id,child_context.institution_id,
         child_unit.unit_id,child_group.group_id,child_context.child_person_id
    into context_record
  from public.child_group_links child_group
  join public.child_unit_links child_unit on child_unit.id=child_group.child_unit_link_id
  join public.child_contexts child_context on child_context.id=child_unit.child_context_id
  where child_group.id=target_child_group_link_id
    and child_group.status='active'
    and child_unit.status in ('active','awaiting_allocation')
    and child_context.status='active';
  if context_record.child_context_id is null then raise exception 'child context not active'; end if;
  if not app_private.guardian_has_capability(
    context_record.child_context_id,'manage_attendance_notices'
  ) then raise exception 'guardian cannot submit attendance notice'; end if;
  select id into guardian_link_id from public.guardian_links
  where guardian_person_id=actor_person_id
    and child_person_id=context_record.child_person_id
    and status='active' and revoked_at is null;

  insert into public.attendance_notices(
    institution_id,unit_id,group_id,child_context_id,child_group_link_id,
    guardian_link_id,notice_type,starts_at,ends_at,reason_id,reason_detail,
    note,created_by_person_id
  ) values (
    context_record.institution_id,context_record.unit_id,context_record.group_id,
    context_record.child_context_id,target_child_group_link_id,guardian_link_id,
    target_notice_type,target_starts_at,target_ends_at,target_reason_id,
    nullif(btrim(target_reason_detail),''),nullif(btrim(target_note),''),
    actor_person_id
  ) returning id into created_notice_id;

  if target_attachment_media_id is not null then
    insert into public.attendance_notice_attachments(
      attendance_notice_id,media_asset_id
    ) values (created_notice_id,target_attachment_media_id);
  end if;

  insert into public.context_notification_events(
    institution_id,unit_id,group_id,child_context_id,event_code,object_type,
    object_id,payload_json,created_by_person_id
  ) values (
    context_record.institution_id,context_record.unit_id,context_record.group_id,
    context_record.child_context_id,'attendance_notice_created',
    'attendance_notice',created_notice_id,
    jsonb_build_object('notice_type',target_notice_type,'review_status','pending'),
    actor_person_id
  );

  if target_starts_at>now()+interval '1 day' then
    insert into public.context_notification_events(
      institution_id,unit_id,group_id,child_context_id,event_code,object_type,
      object_id,payload_json,deliver_at,created_by_person_id
    ) values (
      context_record.institution_id,context_record.unit_id,context_record.group_id,
      context_record.child_context_id,'attendance_notice_reminder',
      'attendance_notice',created_notice_id,
      jsonb_build_object('notice_type',target_notice_type),
      target_starts_at-interval '1 day',actor_person_id
    );
  end if;
  return created_notice_id;
end;
$$;

create or replace function public.submit_attendance_notice(
  child_group_link_id uuid,notice_type text,starts_at timestamptz,
  ends_at timestamptz default null,reason_id uuid default null,
  reason_detail text default null,note text default null,
  attachment_media_id uuid default null
)
returns uuid language sql volatile security invoker set search_path=''
as $$
  select app_private.submit_attendance_notice(
    child_group_link_id,notice_type,starts_at,ends_at,reason_id,
    reason_detail,note,attachment_media_id
  )
$$;

create or replace function app_private.confirm_attendance_record(
  target_session_id uuid,target_child_context_id uuid,target_outcome text,
  target_notice_id uuid,target_note text
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  actor_person_id uuid:=app_private.current_person_id();
  session_record public.attendance_sessions%rowtype;
  existing_record public.attendance_records%rowtype;
  result_id uuid;
begin
  if target_outcome not in (
    'present','absent','late_arrival','early_departure','late_and_early'
  ) then raise exception 'invalid attendance outcome'; end if;
  select * into session_record from public.attendance_sessions
  where id=target_session_id and status in ('open','closed');
  if session_record.id is null then raise exception 'attendance session not found'; end if;
  if not app_private.can_access_attendance_child(
    session_record.institution_id,session_record.unit_id,session_record.group_id,
    session_record.activity_id,target_child_context_id,true
  ) then raise exception 'attendance management required'; end if;
  select * into existing_record from public.attendance_records
  where attendance_session_id=target_session_id
    and child_context_id=target_child_context_id and status='active'
  for update;
  if existing_record.id is null then
    insert into public.attendance_records(
      attendance_session_id,child_context_id,outcome,source_notice_id,note,
      confirmed_by_person_id
    ) values (
      target_session_id,target_child_context_id,target_outcome,target_notice_id,
      nullif(btrim(target_note),''),actor_person_id
    ) returning id into result_id;
    insert into public.attendance_record_revisions(
      attendance_record_id,action_code,after_json,changed_by_person_id
    ) select id,'confirmed',to_jsonb(record_row),actor_person_id
      from public.attendance_records record_row where id=result_id;
  else
    update public.attendance_records set
      outcome=target_outcome,source_notice_id=target_notice_id,
      note=nullif(btrim(target_note),''),confirmed_by_person_id=actor_person_id,
      confirmed_at=now(),updated_at=now()
    where id=existing_record.id returning id into result_id;
    insert into public.attendance_record_revisions(
      attendance_record_id,action_code,before_json,after_json,changed_by_person_id
    ) select result_id,'corrected',to_jsonb(existing_record),to_jsonb(record_row),
      actor_person_id from public.attendance_records record_row where id=result_id;
  end if;
  if target_notice_id is not null then
    update public.attendance_notices set review_status='confirmed',
      reviewed_by_person_id=actor_person_id,reviewed_at=now(),
      updated_at=now()
    where id=target_notice_id and child_context_id=target_child_context_id
      and institution_id=session_record.institution_id;
  end if;
  return result_id;
end;
$$;

create or replace function public.confirm_attendance_record(
  session_id uuid,child_context_id uuid,outcome text,
  notice_id uuid default null,note text default null
)
returns uuid language sql volatile security invoker set search_path=''
as $$
  select app_private.confirm_attendance_record(
    session_id,child_context_id,outcome,notice_id,note
  )
$$;

create or replace function app_private.revert_attendance_record(
  target_record_id uuid,target_reason text
)
returns void language plpgsql security definer set search_path=''
as $$
declare
  actor_person_id uuid:=app_private.current_person_id();
  record_row public.attendance_records%rowtype;
  session_row public.attendance_sessions%rowtype;
begin
  select * into record_row from public.attendance_records
  where id=target_record_id and status='active' for update;
  if record_row.id is null then raise exception 'active attendance record not found'; end if;
  select * into session_row from public.attendance_sessions
  where id=record_row.attendance_session_id;
  if not app_private.can_access_attendance_child(
    session_row.institution_id,session_row.unit_id,session_row.group_id,
    session_row.activity_id,record_row.child_context_id,true
  ) then raise exception 'attendance management required'; end if;
  if nullif(btrim(target_reason),'') is null then raise exception 'revert reason required'; end if;
  update public.attendance_records set status='inactive',
    reverted_by_person_id=actor_person_id,reverted_at=now(),
    revert_reason=btrim(target_reason),updated_at=now()
  where id=target_record_id;
  insert into public.attendance_record_revisions(
    attendance_record_id,action_code,before_json,after_json,reason,
    changed_by_person_id
  ) select target_record_id,'reverted',to_jsonb(record_row),to_jsonb(current_row),
    btrim(target_reason),actor_person_id
  from public.attendance_records current_row where id=target_record_id;
end;
$$;

create or replace function public.revert_attendance_record(
  record_id uuid,reason text
)
returns void language sql volatile security invoker set search_path=''
as $$ select app_private.revert_attendance_record(record_id,reason) $$;

do $$
declare current_table text;
begin
  foreach current_table in array array[
    'attendance_reason_catalog','attendance_sessions',
    'attendance_expected_participants','attendance_notices',
    'attendance_notice_attachments','attendance_records',
    'attendance_record_revisions'
  ] loop
    execute format('alter table public.%I enable row level security',current_table);
    execute format('revoke all on public.%I from public,anon,authenticated',current_table);
    execute format('grant all on public.%I to service_role',current_table);
    execute format('grant select,insert,update on public.%I to authenticated',current_table);
  end loop;
end;
$$;

create policy attendance_reason_catalog_read
on public.attendance_reason_catalog for select to authenticated
using (
  status='active' and app_private.has_context_permission(
    institution_id,'attendance.read',unit_id,null,null,null,unit_id is null
  )
);
create policy attendance_reason_catalog_manage
on public.attendance_reason_catalog for all to authenticated
using (
  app_private.has_context_permission(
    institution_id,'attendance.manage',unit_id,null,null,null,unit_id is null
  )
)
with check (
  app_private.has_context_permission(
    institution_id,'attendance.manage',unit_id,null,null,null,unit_id is null
  )
);
create policy attendance_sessions_context
on public.attendance_sessions for all to authenticated
using (
  app_private.can_access_attendance_child(
    institution_id,unit_id,group_id,activity_id,null,
    false
  )
)
with check (
  app_private.has_context_permission(
    institution_id,'attendance.manage',unit_id,group_id,activity_id,null,false
  )
);
create policy attendance_expected_participants_context
on public.attendance_expected_participants for all to authenticated
using (
  exists (
    select 1 from public.attendance_sessions session_row
    where session_row.id=attendance_session_id
      and app_private.can_access_attendance_child(
        session_row.institution_id,session_row.unit_id,session_row.group_id,
        session_row.activity_id,child_context_id,false
      )
  )
)
with check (
  exists (
    select 1 from public.attendance_sessions session_row
    where session_row.id=attendance_session_id
      and app_private.can_access_attendance_child(
        session_row.institution_id,session_row.unit_id,session_row.group_id,
        session_row.activity_id,child_context_id,true
      )
  )
);
create policy attendance_notices_read on public.attendance_notices
for select to authenticated using (
  app_private.can_access_attendance_child(
    institution_id,unit_id,group_id,activity_id,child_context_id,false
  )
);
create policy attendance_notice_attachments_read
on public.attendance_notice_attachments for select to authenticated
using (
  exists (
    select 1 from public.attendance_notices notice_row
    where notice_row.id=attendance_notice_id
      and app_private.can_access_attendance_child(
        notice_row.institution_id,notice_row.unit_id,notice_row.group_id,
        notice_row.activity_id,notice_row.child_context_id,false
      )
  )
);
create policy attendance_records_read on public.attendance_records
for select to authenticated using (
  exists (
    select 1 from public.attendance_sessions session_row
    where session_row.id=attendance_session_id
      and app_private.can_access_attendance_child(
        session_row.institution_id,session_row.unit_id,session_row.group_id,
        session_row.activity_id,child_context_id,false
      )
  )
);
create policy attendance_record_revisions_read
on public.attendance_record_revisions for select to authenticated
using (
  exists (
    select 1 from public.attendance_records record_row
    join public.attendance_sessions session_row
      on session_row.id=record_row.attendance_session_id
    where record_row.id=attendance_record_id
      and app_private.can_access_attendance_child(
        session_row.institution_id,session_row.unit_id,session_row.group_id,
        session_row.activity_id,record_row.child_context_id,false
      )
  )
);

create or replace view public.attendance_pending_notices
with (security_invoker=true)
as
select notice.*
from public.attendance_notices notice
where notice.review_status='pending' and notice.cancelled_at is null;

create or replace view public.attendance_summary
with (security_invoker=true)
as
select session_row.institution_id,session_row.unit_id,session_row.group_id,
       session_row.activity_id,record_row.child_context_id,
       count(*) filter (where record_row.outcome='present') present_count,
       count(*) filter (where record_row.outcome='absent') absent_count,
       count(*) official_count,
       round(
         100.0*count(*) filter (where record_row.outcome<>'absent')
         /nullif(count(*),0),2
       ) attendance_percentage
from public.attendance_records record_row
join public.attendance_sessions session_row
  on session_row.id=record_row.attendance_session_id
where record_row.status='active'
group by session_row.institution_id,session_row.unit_id,session_row.group_id,
         session_row.activity_id,record_row.child_context_id;

revoke all on public.attendance_pending_notices,public.attendance_summary
  from public,anon,authenticated;
grant select on public.attendance_pending_notices,public.attendance_summary
  to authenticated;
grant all on public.attendance_pending_notices,public.attendance_summary
  to service_role;

revoke all on function app_private.validate_attendance_context_row()
  from public,anon,authenticated;
revoke all on function app_private.can_access_attendance_child(
  uuid,uuid,uuid,uuid,uuid,boolean
) from public,anon;
grant execute on function app_private.can_access_attendance_child(
  uuid,uuid,uuid,uuid,uuid,boolean
) to authenticated,service_role;
revoke all on function app_private.submit_attendance_notice(
  uuid,text,timestamptz,timestamptz,uuid,text,text,uuid
) from public,anon;
grant execute on function app_private.submit_attendance_notice(
  uuid,text,timestamptz,timestamptz,uuid,text,text,uuid
) to authenticated,service_role;
revoke all on function public.submit_attendance_notice(
  uuid,text,timestamptz,timestamptz,uuid,text,text,uuid
) from public,anon;
grant execute on function public.submit_attendance_notice(
  uuid,text,timestamptz,timestamptz,uuid,text,text,uuid
) to authenticated;
revoke all on function app_private.confirm_attendance_record(uuid,uuid,text,uuid,text)
  from public,anon;
grant execute on function app_private.confirm_attendance_record(uuid,uuid,text,uuid,text)
  to authenticated,service_role;
revoke all on function public.confirm_attendance_record(uuid,uuid,text,uuid,text)
  from public,anon;
grant execute on function public.confirm_attendance_record(uuid,uuid,text,uuid,text)
  to authenticated;
revoke all on function app_private.revert_attendance_record(uuid,text)
  from public,anon;
grant execute on function app_private.revert_attendance_record(uuid,text)
  to authenticated,service_role;
revoke all on function public.revert_attendance_record(uuid,text)
  from public,anon;
grant execute on function public.revert_attendance_record(uuid,text)
  to authenticated;

with table_catalog(table_name,table_label,table_description,domain) as (
  values
    ('attendance_reason_catalog','Motivos de presenca','Catalogo institucional extensivel.','attendance'),
    ('attendance_sessions','Listas de presenca','Sessao oficial de grupo ou atividade.','attendance'),
    ('attendance_expected_participants','Participantes esperados','Criancas esperadas na sessao.','attendance'),
    ('attendance_notices','Avisos familiares','Intencao familiar mantida pendente.','attendance'),
    ('attendance_notice_attachments','Anexos de avisos','Referencias privadas de midia.','attendance'),
    ('attendance_records','Registros oficiais','Resultado confirmado por profissional.','attendance'),
    ('attendance_record_revisions','Revisoes de presenca','Historico de confirmar, corrigir e desfazer.','attendance')
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
  'Campo de assiduidade '||c.column_name||'.',c.data_type,c.is_nullable='NO',
  c.is_nullable='YES',false,c.column_name in (
    'institution_id','unit_id','group_id','activity_id','child_context_id',
    'attendance_session_id','notice_type','review_status','outcome','status'
  ),false,true,c.ordinal_position,'["pt-BR"]'::jsonb,'{}'::jsonb,'[]'::jsonb,now()
from information_schema.columns c join public.schema_tables st
  on st.schema_name=c.table_schema and st.table_name=c.table_name and st.version=1
where c.table_schema='public' and c.table_name in (
  'attendance_reason_catalog','attendance_sessions',
  'attendance_expected_participants','attendance_notices',
  'attendance_notice_attachments','attendance_records',
  'attendance_record_revisions'
)
on conflict(schema_table_id,column_name) do update set
  column_type=excluded.column_type,is_required=excluded.is_required,
  is_nullable=excluded.is_nullable,is_filterable=excluded.is_filterable,
  is_active=true,position=excluded.position,updated_at=now();
