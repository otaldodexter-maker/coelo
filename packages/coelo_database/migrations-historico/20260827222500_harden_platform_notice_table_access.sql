begin;

do $preflight$
declare
  relation_name text;
  relation_oid regclass;
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using
      message = 'platform Notice table hardening requires postgres';
  end if;

  foreach relation_name in array array[
    'public.platform_notices',
    'public.notice_rules',
    'public.notice_media',
    'public.notice_receipts',
    'analytics.notice_events'
  ] loop
    relation_oid := to_regclass(relation_name);
    if relation_oid is null then
      raise object_not_in_prerequisite_state using
        message = 'required platform Notice table is missing';
    end if;
    if (select relowner from pg_class where oid = relation_oid) <> 'postgres'::regrole then
      raise object_not_in_prerequisite_state using
        message = 'unexpected platform Notice table owner';
    end if;
  end loop;
end
$preflight$;

revoke all on table
  public.platform_notices,
  public.notice_rules,
  public.notice_media,
  public.notice_receipts,
  analytics.notice_events
from public, anon, authenticated;

alter table public.platform_notices enable row level security;
alter table public.platform_notices force row level security;
alter table public.notice_rules enable row level security;
alter table public.notice_rules force row level security;
alter table public.notice_media enable row level security;
alter table public.notice_media force row level security;
alter table public.notice_receipts enable row level security;
alter table public.notice_receipts force row level security;
alter table analytics.notice_events enable row level security;
alter table analytics.notice_events force row level security;

commit;
