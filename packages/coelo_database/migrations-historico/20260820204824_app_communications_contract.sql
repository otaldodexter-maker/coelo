create or replace function app_private.notice_json(p_notice public.platform_notices)
returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object(
  'id',p_notice.id,
  'type',case p_notice.notice_type::text
    when 'content_card' then 'content_card'
    when 'highlight' then 'highlight'
    when 'for_you' then 'for_you'
    else 'popup'
  end,
  'title',p_notice.title,'body',p_notice.body_text,'priority',p_notice.priority_code,'status',p_notice.status,
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

revoke all on function app_private.notice_json(public.platform_notices) from public,anon,authenticated;

create or replace function public.list_notices_for_superadmin(
  p_types text[],p_search text default null,p_statuses text[] default null,p_priorities text[] default null,
  p_cursor_occurred_at timestamptz default null,p_cursor_id uuid default null,p_limit int default 25
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_items jsonb; v_cursor_time timestamptz; v_cursor_id uuid; v_has_more boolean;
begin
  perform app_private.assert_notice_permission('notice.read');
  if p_limit not between 1 and 100 or length(coalesce(p_search,''))>120
     or not (coalesce(p_types,'{}'::text[]) <@ array['popup','content_card','highlight','for_you']::text[]) then
    raise exception using errcode='22023',message='invalid_directory_query';
  end if;
  with raw_page as (
    select n notice,row_number() over(order by n.updated_at desc,n.id desc) page_row from public.platform_notices n
    where (p_search is null or n.title ilike '%'||replace(replace(p_search,'%','\%'),'_','\_')||'%' escape '\')
      and (p_statuses is null or n.status::text=any(p_statuses))
      and (p_priorities is null or n.priority_code=any(p_priorities))
      and (p_types is null or case n.notice_type::text
        when 'content_card' then 'content_card' when 'highlight' then 'highlight' when 'for_you' then 'for_you' else 'popup' end=any(p_types))
      and (p_cursor_occurred_at is null or (n.updated_at,n.id)<(p_cursor_occurred_at,p_cursor_id))
    order by n.updated_at desc,n.id desc limit p_limit+1
  ), page as (select (notice).* from raw_page where page_row<=p_limit), counts as (
    select r.notice_id,count(*) reach,count(*) filter(where r.delivered_at is not null) delivered,
      count(*) filter(where r.opened_at is not null) viewed,count(*) filter(where r.acted_at is not null) accepted
    from public.notice_receipts r where r.notice_id in(select id from page) group by r.notice_id
  ), aggregate_page as (
    select coalesce(jsonb_agg(app_private.notice_json(page)||jsonb_build_object('reach',coalesce(c.reach,0),'delivered_count',coalesce(c.delivered,0),'viewed_count',coalesce(c.viewed,0),'accepted_count',coalesce(c.accepted,0)) order by updated_at desc,id desc),'[]'::jsonb) items,
      coalesce((select bool_or(page_row>p_limit) from raw_page),false) has_more from page left join counts c on c.notice_id=page.id
  ) select items,has_more into v_items,v_has_more from aggregate_page;
  if v_has_more and jsonb_array_length(v_items)>0 then
    v_cursor_time:=(v_items->(jsonb_array_length(v_items)-1)->>'updated_at')::timestamptz;
    v_cursor_id:=(v_items->(jsonb_array_length(v_items)-1)->>'id')::uuid;
  end if;
  return jsonb_build_object('items',v_items,'next_cursor_occurred_at',v_cursor_time,'next_cursor_id',v_cursor_id);
end $$;

revoke all on function public.list_notices_for_superadmin(text[],text,text[],text[],timestamptz,uuid,int) from public,anon;
grant execute on function public.list_notices_for_superadmin(text[],text,text[],text[],timestamptz,uuid,int) to authenticated;

create or replace function public.save_notice_draft_for_superadmin(
  p_request_id uuid,p_payload jsonb,p_notice_id uuid default null,p_expected_version bigint default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid; v_hash bytea; v_cached record; v_notice public.platform_notices; v_before jsonb; v_type text;
begin
  v_actor:=app_private.assert_notice_permission('notice.manage');
  v_hash:=digest(p_payload::text||coalesce(p_notice_id::text,'')||coalesce(p_expected_version::text,''),'sha256');
  select * into v_cached from app_private.notice_command_receipts where actor_person_id=v_actor and request_id=p_request_id and action='save';
  if found then
    if v_cached.request_hash<>v_hash then raise exception using errcode='P0003',message='idempotency_conflict'; end if;
    return v_cached.result_json;
  end if;
  v_type:=coalesce(p_payload->>'type','popup');
  if p_payload - array['type','title','body','priority','audience','audience_label','behavior','target_device','content_format','background_color','text_color','button_color','popup_size','has_outer_inset','button_label','link_label','recurrence','interval_days','weekly_days','day_of_month','recurrence_until','image_orientation','starts_at','ends_at'] <> '{}'::jsonb
     or v_type not in ('popup','content_card','highlight','for_you')
     or length(trim(p_payload->>'title')) not between 1 and 140 or length(trim(p_payload->>'body')) not between 1 and 5000
     or length(trim(coalesce(p_payload->>'audience_label',''))) not between 1 and 200
     or p_payload->>'priority' not in ('routine','important','urgent')
     or p_payload->>'behavior' not in ('dismissible','confirmation','checkbox_confirmation')
     or (v_type<>'popup' and p_payload->>'behavior'<>'dismissible')
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
      v_type::public.notice_type,'draft',case p_payload->>'priority' when 'urgent' then 2 when 'important' then 1 else 0 end,p_payload->>'priority',
      trim(p_payload->>'title'),trim(p_payload->>'body'),trim(p_payload->>'button_label'),(p_payload->>'starts_at')::timestamptz,(p_payload->>'ends_at')::timestamptz,v_actor,v_actor,
      p_payload->'audience',trim(p_payload->>'audience_label'),case when v_type='popup' then p_payload->>'behavior' else 'dismissible' end,p_payload->>'target_device',p_payload->>'content_format',
      case when v_type='popup' then p_payload->>'background_color' end,case when v_type='popup' then p_payload->>'text_color' end,case when v_type='popup' then p_payload->>'button_color' end,
      case when v_type='popup' then p_payload->>'popup_size' else 'standard' end,
      case when v_type<>'popup' then true when p_payload->>'popup_size'='fullscreen' then false else coalesce((p_payload->>'has_outer_inset')::boolean,true) end,
      p_payload->>'recurrence',jsonb_build_object('interval_days',p_payload->'interval_days','weekly_days',coalesce(p_payload->'weekly_days','[]'::jsonb),'day_of_month',p_payload->'day_of_month','until',p_payload->'recurrence_until'),
      p_payload->>'image_orientation',jsonb_build_object('link_label',nullif(trim(p_payload->>'link_label'),''))
    ) returning * into v_notice;
  else
    select jsonb_build_object('status',status,'version',management_version) into v_before from public.platform_notices where id=p_notice_id;
    update public.platform_notices set
      notice_type=v_type::public.notice_type,
      priority=case p_payload->>'priority' when 'urgent' then 2 when 'important' then 1 else 0 end,priority_code=p_payload->>'priority',
      title=trim(p_payload->>'title'),body_text=trim(p_payload->>'body'),cta_label=trim(p_payload->>'button_label'),
      starts_at=(p_payload->>'starts_at')::timestamptz,ends_at=(p_payload->>'ends_at')::timestamptz,updated_by=v_actor,updated_at=now(),
      audience_json=p_payload->'audience',audience_label=trim(p_payload->>'audience_label'),behavior=case when v_type='popup' then p_payload->>'behavior' else 'dismissible' end,target_device=p_payload->>'target_device',
      content_format=p_payload->>'content_format',background_color=case when v_type='popup' then p_payload->>'background_color' end,text_color=case when v_type='popup' then p_payload->>'text_color' end,button_color=case when v_type='popup' then p_payload->>'button_color' end,
      popup_size=case when v_type='popup' then p_payload->>'popup_size' else 'standard' end,
      has_outer_inset=case when v_type<>'popup' then true when p_payload->>'popup_size'='fullscreen' then false else coalesce((p_payload->>'has_outer_inset')::boolean,true) end,
      recurrence=p_payload->>'recurrence',recurrence_config=jsonb_build_object('interval_days',p_payload->'interval_days','weekly_days',coalesce(p_payload->'weekly_days','[]'::jsonb),'day_of_month',p_payload->'day_of_month','until',p_payload->'recurrence_until'),
      image_orientation=p_payload->>'image_orientation',silencing_policy=jsonb_build_object('link_label',nullif(trim(p_payload->>'link_label'),'')),processing_state='idle',management_version=management_version+1
    where id=p_notice_id and management_version=p_expected_version and status::text in ('draft','scheduled','paused') returning * into v_notice;
    if not found then
      if not exists(select 1 from public.platform_notices where id=p_notice_id) then raise exception using errcode='P0002',message='notice_not_found'; end if;
      raise exception using errcode='P0003',message='notice_conflict';
    end if;
  end if;
  insert into app_private.notice_command_receipts values(v_actor,p_request_id,'save',v_hash,app_private.notice_json(v_notice),now());
  perform app_private.append_notice_audit(v_actor,'notice.save',v_notice.id,jsonb_build_object('before',v_before,'after',jsonb_build_object('type',v_type,'status',v_notice.status,'version',v_notice.management_version)),null,p_request_id,'success');
  return app_private.notice_json(v_notice);
end $$;

revoke all on function public.save_notice_draft_for_superadmin(uuid,jsonb,uuid,bigint) from public,anon;
grant execute on function public.save_notice_draft_for_superadmin(uuid,jsonb,uuid,bigint) to authenticated;
