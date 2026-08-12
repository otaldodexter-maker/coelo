-- Production contract for Superadmin Notices. Exposed access is RPC-only.

alter table public.platform_notices
  alter column notice_type set default 'popup',
  add column if not exists priority_code text not null default 'routine',
  add column if not exists audience_json jsonb not null default jsonb_build_object('rules',jsonb_build_array()),
  add column if not exists audience_label text,
  add column if not exists behavior text not null default 'dismissible',
  add column if not exists target_device text not null default 'all',
  add column if not exists content_format text not null default 'text_background',
  add column if not exists background_color text,
  add column if not exists text_color text,
  add column if not exists button_color text,
  add column if not exists popup_size text not null default 'standard',
  add column if not exists has_outer_inset boolean not null default true,
  add column if not exists recurrence text not null default 'one_time',
  add column if not exists recurrence_config jsonb not null default '{}'::jsonb,
  add column if not exists image_orientation text not null default 'vertical',
  add column if not exists processing_state text not null default 'idle',
  add column if not exists management_version bigint not null default 1,
  add column if not exists updated_by uuid references public.people(id),
  add column if not exists updated_at timestamptz not null default now();

do $$ begin
  if not exists(select 1 from pg_constraint where conname='platform_notices_production_values_ck') then
    alter table public.platform_notices add constraint platform_notices_production_values_ck check (
      priority_code in ('routine','important','urgent')
      and behavior in ('dismissible','confirmation','checkbox_confirmation')
      and target_device in ('all','web','mobile','tablet')
      and content_format in ('text_background','image')
      and popup_size in ('compact','standard','large','fullscreen')
      and recurrence in ('one_time','daily','weekly','monthly','interval')
      and image_orientation in ('vertical','horizontal')
      and processing_state in ('idle','queued','processing','ready','failed')
      and management_version > 0
      and (audience_label is null or char_length(trim(audience_label)) between 1 and 200)
      and (popup_size <> 'fullscreen' or has_outer_inset=false)
      and (background_color is null or background_color ~ '^#[0-9A-F]{6}$')
      and (text_color is null or text_color ~ '^#[0-9A-F]{6}$')
      and (button_color is null or button_color ~ '^#[0-9A-F]{6}$')
    );
  end if;
end $$;

create index if not exists platform_notices_directory_cursor_idx on public.platform_notices(updated_at desc,id desc);
create index if not exists platform_notices_status_schedule_idx on public.platform_notices(status,starts_at,id);
create index if not exists notice_rules_notice_position_idx on public.notice_rules(notice_id,position,id);
create unique index if not exists notice_receipts_platform_scope_uidx on public.notice_receipts(notice_id,person_id) where institution_id is null;

create table if not exists app_private.notice_command_receipts(
  actor_person_id uuid not null references public.people(id), request_id uuid not null,
  action text not null, request_hash bytea not null check(octet_length(request_hash)=32),
  result_json jsonb not null, created_at timestamptz not null default now(),
  primary key(actor_person_id,request_id,action)
);
create table if not exists app_private.notice_publication_jobs(
  id uuid primary key default gen_random_uuid(), notice_id uuid not null references public.platform_notices(id) on delete cascade,
  notice_version bigint not null, audience_snapshot jsonb not null,
  state text not null default 'queued' check(state in ('queued','processing','completed','failed')),
  attempts int not null default 0 check(attempts between 0 and 20), available_at timestamptz not null default now(),
  locked_at timestamptz, locked_by text, last_error_code text, created_at timestamptz not null default now(), completed_at timestamptz,
  cursor_key text, resolved_count bigint not null default 0,
  unique(notice_id,notice_version)
);
create index if not exists notice_publication_jobs_claim_idx on app_private.notice_publication_jobs(state,available_at,created_at) where state in ('queued','failed');
create table if not exists app_private.notice_admin_audit(
  id uuid primary key default gen_random_uuid(), actor_person_id uuid not null references public.people(id),
  actor_context text not null default 'superadmin', action text not null, resource_id uuid not null,
  before_after jsonb not null default '{}'::jsonb, reason text, correlation_id uuid not null,
  origin text not null default 'superadmin_rpc', result text not null, occurred_at timestamptz not null default now(),
  previous_hash bytea, event_hash bytea not null
);
create index if not exists notice_admin_audit_resource_idx on app_private.notice_admin_audit(resource_id,occurred_at desc,id desc);
revoke all on app_private.notice_command_receipts,app_private.notice_publication_jobs,app_private.notice_admin_audit from public,anon,authenticated;

create or replace function app_private.block_notice_audit_mutation() returns trigger language plpgsql set search_path='' as $$
begin raise exception using errcode='42501',message='notice_audit_append_only'; end $$;
drop trigger if exists notice_admin_audit_append_only on app_private.notice_admin_audit;
create trigger notice_admin_audit_append_only before update or delete on app_private.notice_admin_audit for each row execute function app_private.block_notice_audit_mutation();

insert into public.platform_permissions(code,module_code,screen_code,action_code,description,risk_level,requires_mfa)
values ('notice.read','notices','directory','read','Ler avisos de plataforma.','normal',false),
       ('notice.manage','notices','editor','manage','Criar e alterar avisos de plataforma.','high',true)
on conflict(code) do update set requires_mfa=excluded.requires_mfa;
update public.platform_permissions set requires_mfa=true,risk_level='high' where code='notice.publish';
insert into public.platform_role_permissions(role_id,permission_id,effect)
select r.id,p.id,'allow' from public.platform_roles r join public.platform_permissions p on p.code in ('notice.read','notice.manage','notice.publish')
where r.code in ('owner','content') on conflict(role_id,permission_id) do update set effect='allow',status='active';

drop policy if exists platform_notices_platform_read on public.platform_notices;
drop policy if exists notice_rules_platform_read on public.notice_rules;
drop policy if exists notice_media_platform_read on public.notice_media;
drop policy if exists notice_receipts_platform_read on public.notice_receipts;
drop policy if exists notice_events_platform_read on public.notice_events;
alter table public.platform_notices enable row level security;
alter table public.platform_notices force row level security;
alter table public.notice_rules enable row level security;
alter table public.notice_rules force row level security;
alter table public.notice_media enable row level security;
alter table public.notice_media force row level security;
alter table public.notice_receipts enable row level security;
alter table public.notice_receipts force row level security;
alter table public.notice_events enable row level security;
alter table public.notice_events force row level security;
revoke all on public.platform_notices,public.notice_rules,public.notice_media,public.notice_receipts,public.notice_events from public,anon,authenticated;

create or replace function app_private.assert_notice_permission(p_permission text)
returns uuid language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=app_private.current_person_id();
begin
  if v_actor is null or not app_private.has_scoped_platform_permission(p_permission,null) then
    raise exception using errcode='42501',message='not_authorized';
  end if;
  if exists(select 1 from public.platform_permissions where code=p_permission and status='active' and requires_mfa)
     and not app_private.has_mfa_aal2() then
    raise exception using errcode='42501',message='aal2_required';
  end if;
  return v_actor;
end $$;

create or replace function app_private.append_notice_audit(
  p_actor uuid,p_action text,p_resource uuid,p_before_after jsonb,p_reason text,p_correlation uuid,p_result text
) returns void language plpgsql security definer set search_path='' as $$
declare v_previous bytea; v_now timestamptz:=clock_timestamp();
begin
  perform pg_advisory_xact_lock(hashtext('coelo.notice_admin_audit'));
  select event_hash into v_previous from app_private.notice_admin_audit order by occurred_at desc,id desc limit 1;
  insert into app_private.notice_admin_audit(actor_person_id,action,resource_id,before_after,reason,correlation_id,result,occurred_at,previous_hash,event_hash)
  values(p_actor,p_action,p_resource,coalesce(p_before_after,'{}'::jsonb),left(p_reason,500),p_correlation,p_result,v_now,v_previous,
    digest(coalesce(encode(v_previous,'hex'),'')||p_actor::text||p_action||p_resource::text||coalesce(p_before_after,'{}'::jsonb)::text||p_correlation::text||p_result||v_now::text,'sha256'));
end $$;

create or replace function app_private.validate_notice_audience(p_audience jsonb)
returns void language plpgsql stable security definer set search_path='' as $$
declare v_rule jsonb; v_dimension text; v_id text;
begin
  if jsonb_typeof(p_audience)<>'object' or jsonb_typeof(p_audience->'rules')<>'array'
     or jsonb_array_length(p_audience->'rules') <> 1
     or jsonb_typeof(coalesce(p_audience->'role_codes','[]'::jsonb))<>'array'
     or jsonb_typeof(coalesce(p_audience->'plan_ids','[]'::jsonb))<>'array'
     or jsonb_array_length(coalesce(p_audience->'role_codes','[]'::jsonb))>20
     or jsonb_array_length(coalesce(p_audience->'plan_ids','[]'::jsonb))>50 then
    raise exception using errcode='22023',message='invalid_audience';
  end if;
  for v_rule in select value from jsonb_array_elements(p_audience->'rules') loop
    v_dimension:=v_rule->>'dimension';
    if v_dimension not in ('platform','institution','unit','group','person')
       or jsonb_typeof(coalesce(v_rule->'target_ids','[]'::jsonb))<>'array'
       or jsonb_typeof(coalesce(v_rule->'excluded_ids','[]'::jsonb))<>'array'
       or jsonb_typeof(coalesce(v_rule->'filters','{}'::jsonb))<>'object'
       or jsonb_array_length(coalesce(v_rule->'target_ids','[]'::jsonb))>500
       or jsonb_array_length(coalesce(v_rule->'excluded_ids','[]'::jsonb))>500 then
      raise exception using errcode='22023',message='invalid_audience_rule';
    end if;
    if not coalesce((v_rule->>'select_all')::boolean,false)
       and jsonb_array_length(coalesce(v_rule->'target_ids','[]'::jsonb))=0 then
      raise exception using errcode='22023',message='empty_audience_rule';
    end if;
    if v_dimension='platform' and (
      not coalesce((v_rule->>'select_all')::boolean,false)
      or jsonb_array_length(coalesce(v_rule->'target_ids','[]'::jsonb))<>0
      or jsonb_array_length(coalesce(v_rule->'excluded_ids','[]'::jsonb))<>0
      or coalesce(v_rule->'filters','{}'::jsonb)<>'{}'::jsonb
    ) then
      raise exception using errcode='22023',message='invalid_platform_audience';
    end if;
    if exists(select 1 from jsonb_object_keys(coalesce(v_rule->'filters','{}'::jsonb)) k where k not in ('status','institution_ids','unit_ids','search')) then
      raise exception using errcode='22023',message='unsupported_audience_filter';
    end if;
    if v_rule->'filters' ? 'search' and (
      v_dimension = 'platform'
      or
      jsonb_typeof(v_rule->'filters'->'search') <> 'array'
      or jsonb_array_length(v_rule->'filters'->'search') <> 1
      or length(trim(v_rule->'filters'->'search'->>0)) not between 1 and 120
    ) then
      raise exception using errcode='22023',message='invalid_audience_search';
    end if;
    if jsonb_typeof(coalesce(v_rule->'filters'->'institution_ids','[]'::jsonb)) <> 'array'
       or jsonb_typeof(coalesce(v_rule->'filters'->'unit_ids','[]'::jsonb)) <> 'array' then
      raise exception using errcode='22023',message='invalid_audience_parent_filter';
    end if;
    if jsonb_array_length(coalesce(v_rule->'filters'->'institution_ids','[]'::jsonb)) > 100
       or jsonb_array_length(coalesce(v_rule->'filters'->'unit_ids','[]'::jsonb)) > 100 then
      raise exception using errcode='22023',message='invalid_audience_parent_filter';
    end if;
    for v_id in select value from jsonb_array_elements_text(coalesce(v_rule->'filters'->'institution_ids','[]'::jsonb)) loop
      begin
        perform v_id::uuid;
      exception when invalid_text_representation then
        raise exception using errcode='22023',message='invalid_audience_filter_id';
      end;
      if not exists(select 1 from public.institutions where id=v_id::uuid and deleted_at is null) then
        raise exception using errcode='22023',message='invalid_audience_filter_target';
      end if;
    end loop;
    for v_id in select value from jsonb_array_elements_text(coalesce(v_rule->'filters'->'unit_ids','[]'::jsonb)) loop
      begin
        perform v_id::uuid;
      exception when invalid_text_representation then
        raise exception using errcode='22023',message='invalid_audience_filter_id';
      end;
      if not exists(select 1 from public.units where id=v_id::uuid) then
        raise exception using errcode='22023',message='invalid_audience_filter_target';
      end if;
    end loop;
    if v_dimension='unit' and jsonb_array_length(coalesce(v_rule->'filters'->'institution_ids','[]'::jsonb))>0
       and exists(select 1 from jsonb_array_elements_text(coalesce(v_rule->'target_ids','[]'::jsonb)) target
         join public.units u on u.id=target::uuid where not(v_rule->'filters'->'institution_ids' ? u.institution_id::text)) then
      raise exception using errcode='22023',message='audience_parent_mismatch';
    end if;
    if v_dimension='group' and jsonb_array_length(coalesce(v_rule->'filters'->'unit_ids','[]'::jsonb))>0
       and exists(select 1 from jsonb_array_elements_text(coalesce(v_rule->'target_ids','[]'::jsonb)) target
         join public.groups g on g.id=target::uuid where not(v_rule->'filters'->'unit_ids' ? g.unit_id::text)) then
      raise exception using errcode='22023',message='audience_parent_mismatch';
    end if;
    for v_id in select value from jsonb_array_elements_text(coalesce(v_rule->'target_ids','[]'::jsonb)) loop
      begin perform v_id::uuid; exception when invalid_text_representation then raise exception using errcode='22023',message='invalid_audience_id'; end;
      if (v_dimension='institution' and not exists(select 1 from public.institutions where id=v_id::uuid and deleted_at is null))
         or (v_dimension='unit' and not exists(select 1 from public.units where id=v_id::uuid))
         or (v_dimension='group' and not exists(select 1 from public.groups where id=v_id::uuid))
         or (v_dimension='person' and not exists(select 1 from public.people where id=v_id::uuid)) then
        raise exception using errcode='22023',message='invalid_audience_target';
      end if;
    end loop;
  end loop;
  if exists(select 1 from jsonb_array_elements_text(coalesce(p_audience->'role_codes','[]'::jsonb)) r
    where r not in ('guardian','professional','institution_admin','unit_admin','teacher','coordinator','student')) then
    raise exception using errcode='22023',message='invalid_role_filter';
  end if;
  if exists(select 1 from jsonb_array_elements_text(coalesce(p_audience->'plan_ids','[]'::jsonb)) p
    where p !~ '^[0-9a-fA-F-]{36}$' or not exists(select 1 from public.plans where id=p::uuid and status='active')) then
    raise exception using errcode='22023',message='invalid_plan_filter';
  end if;
end $$;

create or replace function app_private.notice_json(p_notice public.platform_notices)
returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object(
  'id',p_notice.id,'title',p_notice.title,'body',p_notice.body_text,'priority',p_notice.priority_code,'status',p_notice.status,
  'starts_at',p_notice.starts_at,'ends_at',p_notice.ends_at,'audience',p_notice.audience_json,'audience_label',p_notice.audience_label,
  'behavior',p_notice.behavior,'target_device',p_notice.target_device,'content_format',p_notice.content_format,
  'background_color',p_notice.background_color,'text_color',p_notice.text_color,'button_color',p_notice.button_color,
  'popup_size',p_notice.popup_size,'has_outer_inset',p_notice.has_outer_inset,'button_label',p_notice.cta_label,'link_label',p_notice.silencing_policy->>'link_label',
  'recurrence',p_notice.recurrence,'interval_days',p_notice.recurrence_config->'interval_days',
  'weekly_days',coalesce(p_notice.recurrence_config->'weekly_days','[]'::jsonb),'day_of_month',p_notice.recurrence_config->'day_of_month',
  'recurrence_until',p_notice.recurrence_config->>'until','image_orientation',p_notice.image_orientation,
  'processing_state',p_notice.processing_state,'management_version',p_notice.management_version,
  'updated_at',p_notice.updated_at,
  'reach',0,'delivered_count',0,'viewed_count',0,'accepted_count',0
)
$$;

revoke all on function app_private.assert_notice_permission(text) from public,anon,authenticated;
revoke all on function app_private.block_notice_audit_mutation() from public,anon,authenticated;
revoke all on function app_private.append_notice_audit(uuid,text,uuid,jsonb,text,uuid,text) from public,anon,authenticated;
revoke all on function app_private.validate_notice_audience(jsonb) from public,anon,authenticated;
revoke all on function app_private.notice_json(public.platform_notices) from public,anon,authenticated;

create or replace function public.list_notices_for_superadmin(
  p_search text default null,p_statuses text[] default null,p_priorities text[] default null,
  p_cursor_occurred_at timestamptz default null,p_cursor_id uuid default null,p_limit int default 25
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_items jsonb; v_cursor_time timestamptz; v_cursor_id uuid; v_has_more boolean;
begin
  perform app_private.assert_notice_permission('notice.read');
  if p_limit not between 1 and 100 or length(coalesce(p_search,''))>120 then raise exception using errcode='22023',message='invalid_directory_query'; end if;
  with raw_page as (
    select n notice,row_number() over(order by n.updated_at desc,n.id desc) page_row from public.platform_notices n
    where (p_search is null or n.title ilike '%'||replace(replace(p_search,'%','\%'),'_','\_')||'%' escape '\')
      and (p_statuses is null or n.status::text=any(p_statuses))
      and (p_priorities is null or n.priority_code=any(p_priorities))
      and (p_cursor_occurred_at is null or (n.updated_at,n.id)<(p_cursor_occurred_at,p_cursor_id))
    order by n.updated_at desc,n.id desc limit p_limit+1
  ), page as (
    select (notice).* from raw_page where page_row<=p_limit
  ), counts as (
    select r.notice_id,count(*) reach,count(*) filter(where r.delivered_at is not null) delivered,
      count(*) filter(where r.opened_at is not null) viewed,count(*) filter(where r.acted_at is not null) accepted
    from public.notice_receipts r where r.notice_id in(select id from page) group by r.notice_id
  ), aggregate_page as (
    select coalesce(jsonb_agg(app_private.notice_json(page)||jsonb_build_object('reach',coalesce(c.reach,0),'delivered_count',coalesce(c.delivered,0),'viewed_count',coalesce(c.viewed,0),'accepted_count',coalesce(c.accepted,0)) order by updated_at desc,id desc),'[]'::jsonb) items,
      coalesce((select bool_or(page_row>p_limit) from raw_page),false) has_more from page
    left join counts c on c.notice_id=page.id
  ) select items,has_more into v_items,v_has_more from aggregate_page;
  if v_has_more and jsonb_array_length(v_items)>0 then
    v_cursor_time:=(v_items->(jsonb_array_length(v_items)-1)->>'updated_at')::timestamptz;
    v_cursor_id:=(v_items->(jsonb_array_length(v_items)-1)->>'id')::uuid;
  end if;
  return jsonb_build_object('items',v_items,'next_cursor_occurred_at',v_cursor_time,'next_cursor_id',v_cursor_id);
end $$;

create or replace function public.get_notice_for_superadmin(p_notice_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_notice public.platform_notices;
begin
  perform app_private.assert_notice_permission('notice.read');
  select * into v_notice from public.platform_notices where id=p_notice_id;
  if not found then raise exception using errcode='P0002',message='notice_not_found'; end if;
  return app_private.notice_json(v_notice)||(
    select jsonb_build_object('reach',count(*),'delivered_count',count(*) filter(where delivered_at is not null),'viewed_count',count(*) filter(where opened_at is not null),'accepted_count',count(*) filter(where acted_at is not null))
    from public.notice_receipts where notice_id=v_notice.id
  );
end $$;

create or replace function public.list_notice_audience_options_for_superadmin(
  p_dimension text,p_search text default null,p_parent_ids uuid[] default null,
  p_cursor_label text default null,p_cursor_id text default null,p_limit int default 30
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_items jsonb; v_next_label text; v_next_id text; v_pattern text;
begin
  perform app_private.assert_notice_permission('notice.read');
  if p_dimension not in ('institution','unit','group','person','role','plan') or p_limit not between 1 and 100 or length(coalesce(p_search,''))>120 then
    raise exception using errcode='22023',message='invalid_audience_query';
  end if;
  v_pattern := case when p_search is null then null else '%'||replace(replace(replace(p_search,'\','\\'),'%','\%'),'_','\_')||'%' end;
  if p_dimension='institution' then
    select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',public_name) order by public_name,id),'[]'::jsonb) into v_items
    from (select id,public_name from public.institutions where deleted_at is null and (v_pattern is null or public_name ilike v_pattern escape '\')
      and (p_cursor_label is null or (public_name,id::text)>(p_cursor_label,p_cursor_id)) order by public_name,id limit p_limit) q;
  elsif p_dimension='unit' then
    select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',name,'parent_id',institution_id) order by name,id),'[]'::jsonb) into v_items
    from (select id,name,institution_id from public.units where (p_parent_ids is null or institution_id=any(p_parent_ids)) and (v_pattern is null or name ilike v_pattern escape '\')
      and (p_cursor_label is null or (name,id::text)>(p_cursor_label,p_cursor_id)) order by name,id limit p_limit) q;
  elsif p_dimension='group' then
    select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',name,'parent_id',unit_id) order by name,id),'[]'::jsonb) into v_items
    from (select id,name,unit_id from public.groups where (p_parent_ids is null or unit_id=any(p_parent_ids)) and (v_pattern is null or name ilike v_pattern escape '\')
      and (p_cursor_label is null or (name,id::text)>(p_cursor_label,p_cursor_id)) order by name,id limit p_limit) q;
  elsif p_dimension='person' then
    select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',display_name) order by display_name,id),'[]'::jsonb) into v_items
    from (select id,display_name from public.people where status='active' and deleted_at is null and (v_pattern is null or display_name ilike v_pattern escape '\')
      and (p_cursor_label is null or (display_name,id::text)>(p_cursor_label,p_cursor_id)) order by display_name,id limit p_limit) q;
  elsif p_dimension='role' then
    select coalesce(jsonb_agg(jsonb_build_object('id',code,'label',name) order by name,code),'[]'::jsonb) into v_items
    from (select code,name from (values ('guardian','Responsável'),('professional','Profissional'),('institution_admin','Administrador institucional'),('unit_admin','Administrador de unidade'),('teacher','Professor'),('coordinator','Coordenador'),('student','Aluno')) roles(code,name)
      where p_search is null or name ilike '%'||p_search||'%' order by name,code limit p_limit) q;
  else
    select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',name) order by name,id),'[]'::jsonb) into v_items
    from (select id,name from public.plans where status='active' and (p_search is null or name ilike '%'||p_search||'%') order by name,id limit p_limit) q;
  end if;
  select item->>'label',item->>'id' into v_next_label,v_next_id
  from jsonb_array_elements(v_items) with ordinality as entry(item,position)
  order by position desc limit 1;
  return jsonb_build_object(
    'items',v_items,
    'next_cursor_label',case when jsonb_array_length(v_items)=p_limit then v_next_label end,
    'next_cursor_id',case when jsonb_array_length(v_items)=p_limit then v_next_id end
  );
end $$;

revoke all on function public.list_notices_for_superadmin(text,text[],text[],timestamptz,uuid,int) from public,anon;
revoke all on function public.get_notice_for_superadmin(uuid) from public,anon;
revoke all on function public.list_notice_audience_options_for_superadmin(text,text,uuid[],text,text,int) from public,anon;
grant execute on function public.list_notices_for_superadmin(text,text[],text[],timestamptz,uuid,int) to authenticated;
grant execute on function public.get_notice_for_superadmin(uuid) to authenticated;
grant execute on function public.list_notice_audience_options_for_superadmin(text,text,uuid[],text,text,int) to authenticated;

create or replace function public.save_notice_draft_for_superadmin(
  p_request_id uuid,p_payload jsonb,p_notice_id uuid default null,p_expected_version bigint default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid; v_hash bytea; v_cached record; v_notice public.platform_notices; v_before jsonb;
begin
  v_actor:=app_private.assert_notice_permission('notice.manage');
  v_hash:=digest(p_payload::text||coalesce(p_notice_id::text,'')||coalesce(p_expected_version::text,''),'sha256');
  select * into v_cached from app_private.notice_command_receipts where actor_person_id=v_actor and request_id=p_request_id and action='save';
  if found then
    if v_cached.request_hash<>v_hash then raise exception using errcode='P0003',message='idempotency_conflict'; end if;
    return v_cached.result_json;
  end if;
  if p_payload - array['title','body','priority','audience','audience_label','behavior','target_device','content_format','background_color','text_color','button_color','popup_size','has_outer_inset','button_label','link_label','recurrence','interval_days','weekly_days','day_of_month','recurrence_until','image_orientation','starts_at','ends_at'] <> '{}'::jsonb
     or length(trim(p_payload->>'title')) not between 1 and 140 or length(trim(p_payload->>'body')) not between 1 and 5000
     or length(trim(coalesce(p_payload->>'audience_label',''))) not between 1 and 200
     or p_payload->>'priority' not in ('routine','important','urgent')
     or p_payload->>'behavior' not in ('dismissible','confirmation','checkbox_confirmation')
     or p_payload->>'target_device' not in ('all','web','mobile','tablet')
     or p_payload->>'content_format' not in ('text_background','image')
     or p_payload->>'popup_size' not in ('compact','standard','large','fullscreen')
     or p_payload->>'recurrence' not in ('one_time','daily','weekly','monthly','interval')
     or p_payload->>'image_orientation' not in ('vertical','horizontal')
     or length(coalesce(p_payload->>'button_label','')) not between 1 and 80
     or length(coalesce(p_payload->>'link_label',''))>80
     or trim(p_payload->>'title') ~ '[[:cntrl:]]'
     or replace(replace(replace(trim(p_payload->>'body'),chr(10),''),chr(13),''),chr(9),'') ~ '[[:cntrl:]]'
     or ((p_payload->>'starts_at') is not null and (p_payload->>'ends_at') is not null and (p_payload->>'ends_at')::timestamptz <= (p_payload->>'starts_at')::timestamptz)
     or (p_payload->>'recurrence'='interval' and coalesce((p_payload->>'interval_days')::int,0) not between 1 and 365)
     or (p_payload->>'recurrence'='monthly' and coalesce((p_payload->>'day_of_month')::int,0) not between 1 and 31)
     or (p_payload->>'background_color' is not null and p_payload->>'background_color' !~ '^#[0-9A-F]{6}$')
     or (p_payload->>'text_color' is not null and p_payload->>'text_color' !~ '^#[0-9A-F]{6}$')
     or (p_payload->>'button_color' is not null and p_payload->>'button_color' !~ '^#[0-9A-F]{6}$') then
    raise exception using errcode='22023',message='invalid_notice_payload';
  end if;
  perform app_private.validate_notice_audience(p_payload->'audience');
  if p_notice_id is null then
    insert into public.platform_notices(
      notice_type,status,priority,priority_code,title,body_text,cta_label,starts_at,ends_at,created_by,updated_by,
      audience_json,audience_label,behavior,target_device,content_format,background_color,text_color,button_color,
      popup_size,has_outer_inset,recurrence,recurrence_config,image_orientation,silencing_policy
    ) values(
      'popup','draft',case p_payload->>'priority' when 'urgent' then 2 when 'important' then 1 else 0 end,p_payload->>'priority',
      trim(p_payload->>'title'),trim(p_payload->>'body'),trim(p_payload->>'button_label'),(p_payload->>'starts_at')::timestamptz,(p_payload->>'ends_at')::timestamptz,v_actor,v_actor,
      p_payload->'audience',trim(p_payload->>'audience_label'),p_payload->>'behavior',p_payload->>'target_device',p_payload->>'content_format',
      p_payload->>'background_color',p_payload->>'text_color',p_payload->>'button_color',p_payload->>'popup_size',
      case when p_payload->>'popup_size'='fullscreen' then false else coalesce((p_payload->>'has_outer_inset')::boolean,true) end,
      p_payload->>'recurrence',jsonb_build_object('interval_days',p_payload->'interval_days','weekly_days',coalesce(p_payload->'weekly_days','[]'::jsonb),'day_of_month',p_payload->'day_of_month','until',p_payload->'recurrence_until'),
      p_payload->>'image_orientation',jsonb_build_object('link_label',nullif(trim(p_payload->>'link_label'),''))
    ) returning * into v_notice;
  else
    select jsonb_build_object('status',status,'version',management_version) into v_before from public.platform_notices where id=p_notice_id;
    update public.platform_notices set
      priority=case p_payload->>'priority' when 'urgent' then 2 when 'important' then 1 else 0 end,priority_code=p_payload->>'priority',
      title=trim(p_payload->>'title'),body_text=trim(p_payload->>'body'),cta_label=trim(p_payload->>'button_label'),
      starts_at=(p_payload->>'starts_at')::timestamptz,ends_at=(p_payload->>'ends_at')::timestamptz,updated_by=v_actor,updated_at=now(),
      audience_json=p_payload->'audience',audience_label=trim(p_payload->>'audience_label'),behavior=p_payload->>'behavior',target_device=p_payload->>'target_device',
      content_format=p_payload->>'content_format',background_color=p_payload->>'background_color',text_color=p_payload->>'text_color',button_color=p_payload->>'button_color',
      popup_size=p_payload->>'popup_size',has_outer_inset=case when p_payload->>'popup_size'='fullscreen' then false else coalesce((p_payload->>'has_outer_inset')::boolean,true) end,
      recurrence=p_payload->>'recurrence',recurrence_config=jsonb_build_object('interval_days',p_payload->'interval_days','weekly_days',coalesce(p_payload->'weekly_days','[]'::jsonb),'day_of_month',p_payload->'day_of_month','until',p_payload->'recurrence_until'),
      image_orientation=p_payload->>'image_orientation',silencing_policy=jsonb_build_object('link_label',nullif(trim(p_payload->>'link_label'),'')),processing_state='idle',management_version=management_version+1
    where id=p_notice_id and management_version=p_expected_version and status::text in ('draft','scheduled','paused') returning * into v_notice;
    if not found then
      if not exists(select 1 from public.platform_notices where id=p_notice_id) then raise exception using errcode='P0002',message='notice_not_found'; end if;
      raise exception using errcode='P0003',message='notice_conflict';
    end if;
  end if;
  insert into app_private.notice_command_receipts values(v_actor,p_request_id,'save',v_hash,app_private.notice_json(v_notice),now());
  perform app_private.append_notice_audit(v_actor,'notice.save',v_notice.id,jsonb_build_object('before',v_before,'after',jsonb_build_object('status',v_notice.status,'version',v_notice.management_version)),null,p_request_id,'success');
  return app_private.notice_json(v_notice);
end $$;

revoke all on function public.save_notice_draft_for_superadmin(uuid,jsonb,uuid,bigint) from public,anon;
grant execute on function public.save_notice_draft_for_superadmin(uuid,jsonb,uuid,bigint) to authenticated;

create or replace function public.publish_notice_for_superadmin(p_request_id uuid,p_notice_id uuid,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid; v_hash bytea; v_cached record; v_notice public.platform_notices;
begin
  v_actor:=app_private.assert_notice_permission('notice.publish');
  if not app_private.has_mfa_aal2() then raise exception using errcode='42501',message='aal2_required'; end if;
  v_hash:=digest(p_notice_id::text||p_expected_version::text,'sha256');
  select * into v_cached from app_private.notice_command_receipts where actor_person_id=v_actor and request_id=p_request_id and action='publish';
  if found then
    if v_cached.request_hash<>v_hash then raise exception using errcode='P0003',message='idempotency_conflict'; end if;
    return v_cached.result_json;
  end if;
  select * into v_notice from public.platform_notices where id=p_notice_id for update;
  if not found then raise exception using errcode='P0002',message='notice_not_found'; end if;
  if v_notice.management_version<>p_expected_version or v_notice.status::text not in ('draft','scheduled','paused') then raise exception using errcode='P0003',message='notice_conflict'; end if;
  if v_notice.content_format='image' then raise exception using errcode='22023',message='image_storage_decision_required'; end if;
  perform app_private.validate_notice_audience(v_notice.audience_json);
  update public.platform_notices set status='scheduled',processing_state='queued',published_at=null,approved_by=v_actor,updated_by=v_actor,updated_at=now(),management_version=management_version+1
    where id=p_notice_id returning * into v_notice;
  insert into app_private.notice_publication_jobs(notice_id,notice_version,audience_snapshot,available_at)
    values(v_notice.id,v_notice.management_version,v_notice.audience_json,greatest(coalesce(v_notice.starts_at,now()),now())) on conflict do nothing;
  insert into app_private.notice_command_receipts values(v_actor,p_request_id,'publish',v_hash,app_private.notice_json(v_notice),now());
  perform app_private.append_notice_audit(v_actor,'notice.publish.requested',v_notice.id,jsonb_build_object('after',jsonb_build_object('status',v_notice.status,'version',v_notice.management_version)),null,p_request_id,'queued');
  return app_private.notice_json(v_notice);
end $$;

create or replace function public.change_notice_status_for_superadmin(
  p_request_id uuid,p_notice_id uuid,p_expected_version bigint,p_status text,p_reason text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid; v_hash bytea; v_cached record; v_notice public.platform_notices; v_before text;
begin
  v_actor:=app_private.assert_notice_permission('notice.manage');
  if p_status not in ('paused','scheduled','inactive') or (p_status='inactive' and length(trim(coalesce(p_reason,''))) not between 3 and 500) then raise exception using errcode='22023',message='invalid_status_transition'; end if;
  if p_status='scheduled' then
    v_actor:=app_private.assert_notice_permission('notice.publish');
    if not app_private.has_mfa_aal2() then raise exception using errcode='42501',message='aal2_required'; end if;
  end if;
  v_hash:=digest(p_notice_id::text||p_expected_version::text||p_status||coalesce(p_reason,''),'sha256');
  select * into v_cached from app_private.notice_command_receipts where actor_person_id=v_actor and request_id=p_request_id and action='status';
  if found then
    if v_cached.request_hash<>v_hash then raise exception using errcode='P0003',message='idempotency_conflict'; end if;
    return v_cached.result_json;
  end if;
  select status::text into v_before from public.platform_notices where id=p_notice_id for update;
  if not found then raise exception using errcode='P0002',message='notice_not_found'; end if;
  update public.platform_notices set status=p_status::public.notice_status,
    processing_state=case when p_status='scheduled' then 'queued' else 'idle' end,
    updated_by=v_actor,updated_at=now(),management_version=management_version+1
  where id=p_notice_id and management_version=p_expected_version
    and ((p_status='paused' and status::text in ('active','scheduled')) or (p_status='scheduled' and status::text='paused') or p_status='inactive')
  returning * into v_notice;
  if not found then raise exception using errcode='P0003',message='notice_conflict'; end if;
  if p_status='scheduled' then
    insert into app_private.notice_publication_jobs(notice_id,notice_version,audience_snapshot,available_at)
      values(v_notice.id,v_notice.management_version,v_notice.audience_json,greatest(coalesce(v_notice.starts_at,now()),now())) on conflict do nothing;
  end if;
  insert into app_private.notice_command_receipts values(v_actor,p_request_id,'status',v_hash,app_private.notice_json(v_notice),now());
  perform app_private.append_notice_audit(v_actor,'notice.status.change',v_notice.id,jsonb_build_object('before',jsonb_build_object('status',v_before),'after',jsonb_build_object('status',v_notice.status,'version',v_notice.management_version)),p_reason,p_request_id,'success');
  return app_private.notice_json(v_notice);
end $$;

create or replace function app_private.claim_notice_publication_jobs(p_worker text,p_limit int default 20)
returns setof app_private.notice_publication_jobs language plpgsql security definer set search_path='' as $$
begin
  if auth.role()<>'service_role' or p_limit not between 1 and 100 or length(trim(p_worker)) not between 1 and 120 then raise exception using errcode='42501',message='not_authorized'; end if;
  return query with claimed as (
    select id from app_private.notice_publication_jobs where state in ('queued','failed') and available_at<=now() and attempts<20
    order by available_at,created_at for update skip locked limit p_limit
  ) update app_private.notice_publication_jobs j set state='processing',attempts=j.attempts+1,locked_at=now(),locked_by=p_worker
    from claimed where j.id=claimed.id returning j.*;
end $$;

revoke all on function public.publish_notice_for_superadmin(uuid,uuid,bigint) from public,anon;
revoke all on function public.change_notice_status_for_superadmin(uuid,uuid,bigint,text,text) from public,anon;
grant execute on function public.publish_notice_for_superadmin(uuid,uuid,bigint) to authenticated;
grant execute on function public.change_notice_status_for_superadmin(uuid,uuid,bigint,text,text) to authenticated;
revoke all on function app_private.claim_notice_publication_jobs(text,int) from public,anon,authenticated;
grant execute on function app_private.claim_notice_publication_jobs(text,int) to service_role;

create or replace function app_private.materialize_notice_publication_job(p_job_id uuid,p_limit int default 1000)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_job app_private.notice_publication_jobs; v_rule jsonb; v_dimension text; v_count int; v_last text; v_search text; v_search_pattern text;
begin
  if auth.role()<>'service_role' or p_limit not between 1 and 5000 then raise exception using errcode='42501',message='not_authorized'; end if;
  select * into v_job from app_private.notice_publication_jobs where id=p_job_id and state='processing' for update;
  if not found then raise exception using errcode='P0002',message='publication_job_not_found'; end if;
  v_rule:=v_job.audience_snapshot->'rules'->0; v_dimension:=v_rule->>'dimension'; v_search:=nullif(trim(v_rule->'filters'->'search'->>0),'');
  v_search_pattern:=case when v_search is null then null else '%'||replace(replace(replace(v_search,'\','\\'),'%','\%'),'_','\_')||'%' end;
  with institutional_candidates as (
    select distinct im.person_id,im.institution_id,(im.person_id::text||':'||im.institution_id::text) recipient_key
    from public.institution_memberships im
    where im.status='active' and im.revoked_at is null
      and (jsonb_array_length(coalesce(v_rule->'filters'->'institution_ids','[]'::jsonb))=0 or v_rule->'filters'->'institution_ids' ? im.institution_id::text)
      and (jsonb_array_length(coalesce(v_rule->'filters'->'unit_ids','[]'::jsonb))=0 or v_rule->'filters'->'unit_ids' ? im.scope_unit_id::text
        or exists(select 1 from public.groups filter_group where filter_group.id=im.scope_group_id and v_rule->'filters'->'unit_ids' ? filter_group.unit_id::text))
      and (jsonb_array_length(coalesce(v_job.audience_snapshot->'role_codes','[]'::jsonb))=0 or v_job.audience_snapshot->'role_codes' ? im.role_code)
      and (jsonb_array_length(coalesce(v_job.audience_snapshot->'plan_ids','[]'::jsonb))=0 or exists(
        select 1 from public.institution_subscriptions s where s.institution_id=im.institution_id and s.status::text in ('active','trial') and v_job.audience_snapshot->'plan_ids' ? s.plan_id::text
      ))
      and (v_search_pattern is null or case v_dimension
        when 'institution' then exists(select 1 from public.institutions i where i.id=im.institution_id and i.public_name ilike v_search_pattern escape '\')
        when 'unit' then exists(select 1 from public.units u where (u.id=im.scope_unit_id or u.id=(select g.unit_id from public.groups g where g.id=im.scope_group_id)) and u.name ilike v_search_pattern escape '\')
        when 'group' then exists(select 1 from public.groups g where g.id=im.scope_group_id and g.name ilike v_search_pattern escape '\')
        else true end)
      and case v_dimension
        when 'platform' then true
        when 'institution' then (
          (coalesce((v_rule->>'select_all')::boolean,false) or v_rule->'target_ids' ? im.institution_id::text)
          and not (coalesce(v_rule->'excluded_ids','[]'::jsonb) ? im.institution_id::text)
        )
        when 'unit' then (
          (coalesce((v_rule->>'select_all')::boolean,false) or v_rule->'target_ids' ? im.scope_unit_id::text
            or exists(select 1 from public.groups g where g.id=im.scope_group_id and v_rule->'target_ids' ? g.unit_id::text))
          and not (coalesce(v_rule->'excluded_ids','[]'::jsonb) ? im.scope_unit_id::text
            or exists(select 1 from public.groups g where g.id=im.scope_group_id and coalesce(v_rule->'excluded_ids','[]'::jsonb) ? g.unit_id::text))
        )
        when 'group' then (
          (coalesce((v_rule->>'select_all')::boolean,false) or v_rule->'target_ids' ? im.scope_group_id::text)
          and not (coalesce(v_rule->'excluded_ids','[]'::jsonb) ? im.scope_group_id::text)
        )
        else false end
  ), platform_candidates as (
    select distinct pm.person_id,null::uuid institution_id,(pm.person_id::text||':platform') recipient_key
    from public.platform_memberships pm where v_dimension='platform' and pm.status='active' and pm.revoked_at is null
      and jsonb_array_length(coalesce(v_job.audience_snapshot->'role_codes','[]'::jsonb))=0
  ), person_candidates as (
    select p.id person_id,null::uuid institution_id,(p.id::text||':person') recipient_key from public.people p
    where v_dimension='person'
      and (coalesce((v_rule->>'select_all')::boolean,false) or v_rule->'target_ids' ? p.id::text)
      and not(coalesce(v_rule->'excluded_ids','[]'::jsonb) ? p.id::text)
      and (v_search_pattern is null or p.display_name ilike v_search_pattern escape '\')
  ), candidates as (
    select * from institutional_candidates union select * from platform_candidates union select * from person_candidates
  ), selected as (
    select * from candidates where v_job.cursor_key is null or recipient_key>v_job.cursor_key order by recipient_key limit p_limit
  ), inserted as (
    insert into public.notice_receipts(notice_id,person_id,institution_id)
      select v_job.notice_id,person_id,institution_id from selected on conflict do nothing returning 1
  ) select count(*),max(recipient_key) into v_count,v_last from selected;
  update app_private.notice_publication_jobs set cursor_key=coalesce(v_last,cursor_key),resolved_count=resolved_count+v_count,
    state=case when v_count<p_limit then 'completed' else 'processing' end,completed_at=case when v_count<p_limit then now() else null end
    where id=v_job.id returning * into v_job;
  if v_count<p_limit then
    if v_job.resolved_count=0 then
      update app_private.notice_publication_jobs set state='failed',last_error_code='empty_audience',completed_at=null where id=v_job.id;
      update public.platform_notices set processing_state='failed',updated_at=now() where id=v_job.notice_id;
      return jsonb_build_object('state','failed','error_code','empty_audience');
    end if;
    update public.platform_notices set status='active',processing_state='ready',published_at=now(),updated_at=now()
      where id=v_job.notice_id and management_version=v_job.notice_version and status::text='scheduled';
    perform app_private.append_notice_audit((select approved_by from public.platform_notices where id=v_job.notice_id),'notice.publish.completed',v_job.notice_id,jsonb_build_object('recipient_count',v_job.resolved_count),null,v_job.id,'success');
  end if;
  return jsonb_build_object('state',v_job.state,'resolved_count',v_job.resolved_count,'cursor_key',v_job.cursor_key);
end $$;

revoke all on function app_private.materialize_notice_publication_job(uuid,int) from public,anon,authenticated;
grant execute on function app_private.materialize_notice_publication_job(uuid,int) to service_role;

alter table public.notice_receipts drop constraint if exists notice_receipts_notice_id_fkey;
alter table public.notice_receipts add constraint notice_receipts_notice_id_fkey foreign key(notice_id) references public.platform_notices(id) on delete restrict;
alter table public.notice_receipts drop constraint if exists notice_receipts_person_id_fkey;
alter table public.notice_receipts add constraint notice_receipts_person_id_fkey foreign key(person_id) references public.people(id) on delete restrict;
alter table public.notice_receipts drop constraint if exists notice_receipts_institution_id_fkey;
alter table public.notice_receipts add constraint notice_receipts_institution_id_fkey foreign key(institution_id) references public.institutions(id) on delete restrict;
alter table app_private.notice_publication_jobs drop constraint if exists notice_publication_jobs_notice_id_fkey;
alter table app_private.notice_publication_jobs add constraint notice_publication_jobs_notice_id_fkey foreign key(notice_id) references public.platform_notices(id) on delete restrict;
alter table public.notice_events drop constraint if exists notice_events_notice_id_fkey;
alter table public.notice_events add constraint notice_events_notice_id_fkey foreign key(notice_id) references public.platform_notices(id) on delete restrict;
alter table public.notice_events drop constraint if exists notice_events_person_id_fkey;
alter table public.notice_events add constraint notice_events_person_id_fkey foreign key(person_id) references public.people(id) on delete restrict;
alter table public.notice_events drop constraint if exists notice_events_institution_id_fkey;
alter table public.notice_events add constraint notice_events_institution_id_fkey foreign key(institution_id) references public.institutions(id) on delete restrict;
