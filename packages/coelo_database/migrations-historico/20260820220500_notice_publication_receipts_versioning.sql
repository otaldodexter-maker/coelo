alter table public.platform_notices
  add column if not exists current_publication_job_id uuid;

alter table public.notice_receipts
  add column if not exists publication_job_id uuid,
  add column if not exists notice_version bigint,
  add column if not exists materialized_at timestamptz not null default now(),
  add column if not exists delivery_state text not null default 'pending';

-- pgcrypto is installed in the trusted extensions schema. The existing notice
-- commands use digest() with a locked search_path, so include only that schema.
alter function app_private.append_notice_audit(uuid,text,uuid,jsonb,text,uuid,text)
  set search_path = pg_catalog, extensions;
alter function public.save_notice_draft_for_superadmin(uuid,jsonb,uuid,bigint)
  set search_path = pg_catalog, extensions;
alter function public.publish_notice_for_superadmin(uuid,uuid,bigint)
  set search_path = pg_catalog, extensions;
alter function public.change_notice_status_for_superadmin(uuid,uuid,bigint,text,text)
  set search_path = pg_catalog, extensions;

update public.notice_receipts
set delivery_state = case
  when acted_at is not null then 'acted'
  when opened_at is not null then 'opened'
  when delivered_at is not null then 'delivered'
  else 'pending'
end;

alter table public.notice_receipts drop constraint if exists notice_receipts_delivery_state_ck;
alter table public.notice_receipts add constraint notice_receipts_delivery_state_ck check (
  delivery_state in ('pending','delivered','opened','acted')
  and (delivery_state <> 'delivered' or delivered_at is not null)
  and (delivery_state <> 'opened' or opened_at is not null)
  and (delivery_state <> 'acted' or acted_at is not null)
);

alter table public.notice_receipts
  drop constraint if exists notice_receipts_notice_id_person_id_institution_id_key;
drop index if exists public.notice_receipts_platform_scope_uidx;

alter table public.notice_receipts drop constraint if exists notice_receipts_publication_job_id_fkey;
alter table public.notice_receipts add constraint notice_receipts_publication_job_id_fkey
  foreign key (publication_job_id) references app_private.notice_publication_jobs(id) on delete restrict;
alter table public.platform_notices drop constraint if exists platform_notices_current_publication_job_id_fkey;
alter table public.platform_notices add constraint platform_notices_current_publication_job_id_fkey
  foreign key (current_publication_job_id) references app_private.notice_publication_jobs(id) on delete restrict;

with latest_completed as (
  select distinct on (notice_id) id,notice_id,notice_version
  from app_private.notice_publication_jobs
  where state = 'completed'
  order by notice_id,notice_version desc,completed_at desc nulls last
)
update public.platform_notices notice
set current_publication_job_id = latest.id
from latest_completed latest
where latest.notice_id = notice.id
  and notice.current_publication_job_id is null;

update public.notice_receipts receipt
set publication_job_id = notice.current_publication_job_id,
    notice_version = job.notice_version
from public.platform_notices notice
join app_private.notice_publication_jobs job on job.id = notice.current_publication_job_id
where receipt.notice_id = notice.id
  and receipt.publication_job_id is null;

create unique index if not exists notice_receipts_job_institution_uidx
  on public.notice_receipts(publication_job_id,person_id,institution_id)
  where publication_job_id is not null and institution_id is not null;
create unique index if not exists notice_receipts_job_platform_uidx
  on public.notice_receipts(publication_job_id,person_id)
  where publication_job_id is not null and institution_id is null;
create index if not exists notice_receipts_current_metrics_idx
  on public.notice_receipts(publication_job_id,delivered_at,opened_at,acted_at);

create or replace function app_private.run_notice_publication_job(
  p_job_id uuid,
  p_limit integer default 1000
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  job app_private.notice_publication_jobs;
  notice public.platform_notices;
  result jsonb;
  materialization_started_at timestamptz;
begin
  if coalesce(
       nullif(current_setting('request.jwt.claim.role',true),''),
       nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'role',
       ''
     ) <> 'service_role'
     or p_limit not between 1 and 5000 then
    raise exception using errcode = '42501', message = 'not_authorized';
  end if;

  select * into job
    from app_private.notice_publication_jobs
   where id = p_job_id and state = 'processing'
   for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'publication_job_not_found';
  end if;

  select * into notice
    from public.platform_notices
   where id = job.notice_id
   for share;
  if not found
     or notice.management_version <> job.notice_version
     or notice.status::text <> 'scheduled'
     or (notice.ends_at is not null and notice.ends_at <= now()) then
    update app_private.notice_publication_jobs
       set state = 'failed',
           attempts = 20,
           completed_at = null,
           locked_at = null,
           locked_by = null,
           last_error_code = case
             when notice.id is null then 'notice_missing'
             when notice.management_version <> job.notice_version then 'notice_superseded'
             when notice.ends_at is not null and notice.ends_at <= now() then 'notice_expired'
             else 'notice_not_scheduled'
           end
     where id = job.id;
    if notice.id is not null and notice.management_version = job.notice_version then
      update public.platform_notices
         set processing_state = 'failed', updated_at = now()
       where id = notice.id and status::text = 'scheduled';
    end if;
    return jsonb_build_object('state','failed','error_code',case
      when notice.id is null then 'notice_missing'
      when notice.management_version <> job.notice_version then 'notice_superseded'
      when notice.ends_at is not null and notice.ends_at <= now() then 'notice_expired'
      else 'notice_not_scheduled'
    end);
  end if;

  materialization_started_at := transaction_timestamp();
  result := app_private.materialize_notice_publication_job(p_job_id,p_limit);

  update public.notice_receipts
     set publication_job_id = job.id,
         notice_version = job.notice_version,
         materialized_at = coalesce(materialized_at,now()),
         delivery_state = 'pending',
         delivered_at = null
   where notice_id = job.notice_id
     and publication_job_id is null
     and materialized_at >= materialization_started_at;

  if result->>'state' = 'completed' then
    update public.platform_notices
       set current_publication_job_id = job.id
     where id = job.notice_id
       and management_version = job.notice_version
       and status::text = 'active';
  elsif result->>'state' = 'failed' then
    update app_private.notice_publication_jobs
       set attempts = 20,locked_at = null,locked_by = null
     where id = job.id;
  end if;
  return result;
end;
$$;

revoke all on function app_private.run_notice_publication_job(uuid,integer) from public,anon,authenticated;
grant execute on function app_private.run_notice_publication_job(uuid,integer) to service_role;

create or replace function public.get_notice_for_superadmin(p_notice_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare notice public.platform_notices;
begin
  perform app_private.assert_notice_permission('notice.read');
  select * into notice from public.platform_notices where id = p_notice_id;
  if not found then raise exception using errcode = 'P0002',message = 'notice_not_found'; end if;
  return app_private.notice_json(notice) || (
    select jsonb_build_object(
      'reach',count(*),
      'delivered_count',count(*) filter(where delivered_at is not null),
      'viewed_count',count(*) filter(where opened_at is not null),
      'accepted_count',count(*) filter(where acted_at is not null)
    ) from public.notice_receipts
      where notice_id = notice.id
        and publication_job_id = notice.current_publication_job_id
  );
end;
$$;

create or replace function public.list_notices_for_superadmin(
  p_types text[],p_search text default null,p_statuses text[] default null,p_priorities text[] default null,
  p_cursor_occurred_at timestamptz default null,p_cursor_id uuid default null,p_limit integer default 25
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare items jsonb; cursor_time timestamptz; cursor_id uuid; has_more boolean;
begin
  perform app_private.assert_notice_permission('notice.read');
  if p_limit not between 1 and 100 or length(coalesce(p_search,'')) > 120
     or not (coalesce(p_types,'{}'::text[]) <@ array['popup','content_card','highlight','for_you']::text[]) then
    raise exception using errcode = '22023',message = 'invalid_directory_query';
  end if;
  with raw_page as (
    select n notice,row_number() over(order by n.updated_at desc,n.id desc) page_row
    from public.platform_notices n
    where (p_search is null or n.title ilike '%'||replace(replace(p_search,'%','\%'),'_','\_')||'%' escape '\')
      and (p_statuses is null or n.status::text = any(p_statuses))
      and (p_priorities is null or n.priority_code = any(p_priorities))
      and (p_types is null or case n.notice_type::text
        when 'content_card' then 'content_card' when 'highlight' then 'highlight' when 'for_you' then 'for_you' else 'popup' end = any(p_types))
      and (p_cursor_occurred_at is null or (n.updated_at,n.id) < (p_cursor_occurred_at,p_cursor_id))
    order by n.updated_at desc,n.id desc limit p_limit + 1
  ), page as (
    select (notice).* from raw_page where page_row <= p_limit
  ), counts as (
    select r.notice_id,r.publication_job_id,count(*) reach,
      count(*) filter(where r.delivered_at is not null) delivered,
      count(*) filter(where r.opened_at is not null) viewed,
      count(*) filter(where r.acted_at is not null) accepted
    from public.notice_receipts r
    where r.notice_id in(select id from page)
    group by r.notice_id,r.publication_job_id
  ), aggregate_page as (
    select coalesce(jsonb_agg(
      app_private.notice_json(page) || jsonb_build_object(
        'reach',coalesce(c.reach,0),'delivered_count',coalesce(c.delivered,0),
        'viewed_count',coalesce(c.viewed,0),'accepted_count',coalesce(c.accepted,0)
      ) order by updated_at desc,id desc
    ),'[]'::jsonb) items,
    coalesce((select bool_or(page_row > p_limit) from raw_page),false) has_more
    from page left join counts c
      on c.notice_id = page.id and c.publication_job_id = page.current_publication_job_id
  ) select aggregate_page.items,aggregate_page.has_more into items,has_more from aggregate_page;
  if has_more and jsonb_array_length(items) > 0 then
    cursor_time := (items->(jsonb_array_length(items)-1)->>'updated_at')::timestamptz;
    cursor_id := (items->(jsonb_array_length(items)-1)->>'id')::uuid;
  end if;
  return jsonb_build_object('items',items,'next_cursor_occurred_at',cursor_time,'next_cursor_id',cursor_id);
end;
$$;

create or replace function public.list_notices_for_superadmin(
  p_search text default null,p_statuses text[] default null,p_priorities text[] default null,
  p_cursor_occurred_at timestamptz default null,p_cursor_id uuid default null,p_limit integer default 25
) returns jsonb language sql security definer set search_path = '' as $$
  select public.list_notices_for_superadmin(
    null::text[],p_search,p_statuses,p_priorities,p_cursor_occurred_at,p_cursor_id,p_limit
  );
$$;

revoke all on function public.get_notice_for_superadmin(uuid) from public,anon;
revoke all on function public.list_notices_for_superadmin(text[],text,text[],text[],timestamptz,uuid,integer) from public,anon;
revoke all on function public.list_notices_for_superadmin(text,text[],text[],timestamptz,uuid,integer) from public,anon;
grant execute on function public.get_notice_for_superadmin(uuid) to authenticated;
grant execute on function public.list_notices_for_superadmin(text[],text,text[],text[],timestamptz,uuid,integer) to authenticated;
grant execute on function public.list_notices_for_superadmin(text,text[],text[],timestamptz,uuid,integer) to authenticated;
