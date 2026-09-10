insert into public.platform_permissions(
  code,module_code,module_label,screen_code,screen_label,action_code,action_label,
  description,risk_level,requires_mfa,status
) values (
  'attendance.export','attendance','Presença','dashboard','Dashboard de assiduidade',
  'export','Exportar',
  'Exportar visão e tabela de assiduidade no escopo autorizado.','sensitive',false,'active'
) on conflict(code) do update set
  description=excluded.description,status='active',updated_at=now();

insert into public.institution_permissions(
  code,module_code,module_label,screen_code,screen_label,action_code,action_label,
  description,risk_level,requires_mfa,status
) values (
  'attendance.export','attendance','Presença','dashboard','Dashboard de assiduidade',
  'export','Exportar',
  'Exportar visão e tabela de assiduidade no escopo autorizado.','sensitive',false,'active'
) on conflict(code) do update set
  description=excluded.description,status='active',updated_at=now();

create index if not exists attendance_sessions_dashboard_scope_date_idx
  on public.attendance_sessions(institution_id,unit_id,session_date desc,id)
  include(group_id,activity_id,status,created_by_person_id)
  where status<>'cancelled';

create index if not exists attendance_records_dashboard_active_idx
  on public.attendance_records(attendance_session_id,outcome,child_context_id)
  where status='active';

create index if not exists attendance_notices_dashboard_pending_idx
  on public.attendance_notices(institution_id,unit_id,starts_at,child_context_id)
  where review_status='pending' and cancelled_at is null;

create or replace function app_private.attendance_dashboard_access()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid:=app_private.current_person_id();
  membership_record record;
  scope_name text;
  child_ids jsonb;
  group_ids jsonb;
  activity_ids jsonb;
begin
  if actor is null then
    raise insufficient_privilege using message='authentication required';
  end if;

  if app_private.has_platform_permission('attendance.read')
     or app_private.has_platform_permission('attendance.manage') then
    return jsonb_build_object(
      'scope','platform','can_read',true,
      'can_create_call',app_private.has_platform_permission('attendance.manage'),
      'can_export',app_private.has_platform_permission('attendance.export'),
      'assigned_group_ids','[]'::jsonb,'assigned_activity_ids','[]'::jsonb,
      'child_ids','[]'::jsonb
    );
  end if;

  select membership.id,membership.institution_id,
         case
           when bool_or(assignment.scope_kind='institution') then 'institution'
           when bool_or(assignment.scope_kind='unit') then 'unit'
           else 'assignments'
         end as scope_kind,
         min(assignment.scope_unit_id::text)::uuid as unit_id
    into membership_record
  from public.institution_memberships membership
  join public.institution_role_assignments assignment
    on assignment.membership_id=membership.id
   and assignment.status='active'
   and (assignment.starts_at is null or assignment.starts_at<=now())
   and (assignment.expires_at is null or assignment.expires_at>now())
  where membership.person_id=actor and membership.status='active'
    and membership.revoked_at is null
    and (
      app_private.has_context_permission(membership.institution_id,'attendance.read',
        assignment.scope_unit_id,assignment.scope_group_id,null,null,false)
      or app_private.has_context_permission(membership.institution_id,'attendance.manage',
        assignment.scope_unit_id,assignment.scope_group_id,null,null,false)
    )
  group by membership.id,membership.institution_id
  order by case when bool_or(assignment.scope_kind='institution') then 0
                when bool_or(assignment.scope_kind='unit') then 1 else 2 end
  limit 1;

  if membership_record.id is not null then
    scope_name:=membership_record.scope_kind;
    select
      coalesce(jsonb_agg(distinct link.group_id)
        filter(where link.group_id is not null),'[]'::jsonb),
      coalesce(jsonb_agg(distinct link.activity_id)
        filter(where link.activity_id is not null),'[]'::jsonb)
      into group_ids,activity_ids
    from public.activity_group_assignments assignment
    join public.activity_group_links link
      on link.id=assignment.activity_group_link_id
     and link.institution_id=assignment.institution_id
    where assignment.membership_id=membership_record.id
      and assignment.person_id=actor
      and assignment.institution_id=membership_record.institution_id
      and assignment.status='active' and assignment.revoked_at is null
      and link.status='active' and link.starts_at<=now()
      and (link.ends_at is null or link.ends_at>now());

    return jsonb_build_object(
      'scope',scope_name,'can_read',true,
      'institution_id',membership_record.institution_id,
      'unit_id',case when scope_name='unit' then membership_record.unit_id else null end,
      'can_create_call',app_private.has_context_permission(
        membership_record.institution_id,'attendance.manage',membership_record.unit_id,null,null,null,false),
      'can_export',case when scope_name='assignments' then exists(
        select 1
        from public.groups authorized_group
        where authorized_group.institution_id=membership_record.institution_id
          and authorized_group.status='active'
          and group_ids ? authorized_group.id::text
          and app_private.has_context_permission(
            membership_record.institution_id,'attendance.export',
            authorized_group.unit_id,authorized_group.id,null,null,false)
      ) else app_private.has_context_permission(
        membership_record.institution_id,'attendance.export',membership_record.unit_id,null,null,null,false)
      end,
      'assigned_group_ids',coalesce(group_ids,'[]'::jsonb),
      'assigned_activity_ids',coalesce(activity_ids,'[]'::jsonb),
      'child_ids','[]'::jsonb
    );
  end if;

  select coalesce(jsonb_agg(distinct child_context.id),'[]'::jsonb)
    into child_ids
  from public.guardian_links guardian
  join public.child_contexts child_context on child_context.child_person_id=guardian.child_person_id
  where guardian.guardian_person_id=actor and guardian.status='active'
    and guardian.revoked_at is null and child_context.status='active'
    and app_private.guardian_has_capability(child_context.id,'manage_attendance_notices');

  if jsonb_array_length(child_ids)>0 then
    return jsonb_build_object(
      'scope','guardian','can_read',true,'can_create_call',false,'can_export',false,
      'assigned_group_ids','[]'::jsonb,'assigned_activity_ids','[]'::jsonb,
      'child_ids',child_ids
    );
  end if;

  raise insufficient_privilege using message='attendance.read required';
end $$;

create or replace function app_private.attendance_dashboard_ranking_page(
  p_start date,p_end date,p_institution_id uuid,p_unit_id uuid,p_group_id uuid,
  p_activity_id uuid,p_child_id uuid,p_kind text,p_direction text,p_page integer,p_page_size integer
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  result jsonb;
  access_payload jsonb;
  scope_name text;
begin
  if p_kind not in('institutions','units','groups','activities','students','teachers')
     or p_direction not in('highest','lowest') or p_page<1 or p_page_size not between 1 and 100 then
    raise invalid_parameter_value using message='invalid ranking request';
  end if;
  access_payload:=app_private.attendance_dashboard_access();
  scope_name:=access_payload->>'scope';
  if (scope_name='guardian' and p_kind<>'students')
     or (scope_name in('institution','unit','assignments') and p_kind='institutions')
     or (scope_name in('unit','assignments') and p_kind='units') then
    raise insufficient_privilege using message='ranking outside attendance scope';
  end if;

  if p_kind='teachers' then
    with authorized_sessions as materialized (
      select session.*
      from public.attendance_sessions session
      where session.session_date between p_start and p_end
        and session.status<>'cancelled'
        and (p_institution_id is null or session.institution_id=p_institution_id)
        and (p_unit_id is null or session.unit_id=p_unit_id)
        and (p_group_id is null or session.group_id=p_group_id)
        and (p_activity_id is null or session.activity_id=p_activity_id)
        and app_private.can_access_attendance_child(
          session.institution_id,session.unit_id,session.group_id,session.activity_id,null,false)
    ), ranked as (
      select person.id,person.display_name as label,
        count(*)::integer as total_records,
        count(*) filter(where session.status in('closed','corrected'))::integer as completed,
        case when count(*)=0 then null else
          count(*) filter(where session.status in('closed','corrected'))::numeric/count(*)*100 end as percent,
        count(*) over()::integer as total_items
      from authorized_sessions session
      join public.people person on person.id=session.created_by_person_id
      group by person.id,person.display_name
    ), paged as (
      select * from ranked
      order by case when p_direction='highest' then percent end desc nulls last,
               case when p_direction='lowest' then percent end asc nulls last,label,id
      offset (p_page-1)*p_page_size limit p_page_size
    )
    select jsonb_build_object(
      'kind',p_kind,'direction',p_direction,'total',coalesce(max(total_items),0),
      'items',coalesce(jsonb_agg(jsonb_build_object(
        'id',id,'label',label,'official_records',total_records,'percent',percent,
        'auxiliary_label',completed||' de '||total_records||' chamadas concluídas'
      )),'[]'::jsonb)
    ) into result from paged;
    return result;
  end if;

  with authorized_sessions as materialized (
    select session.*
    from public.attendance_sessions session
    where session.session_date between p_start and p_end
      and session.status in('closed','corrected')
      and (p_institution_id is null or session.institution_id=p_institution_id)
      and (p_unit_id is null or session.unit_id=p_unit_id)
      and (p_group_id is null or session.group_id=p_group_id)
      and (p_activity_id is null or session.activity_id=p_activity_id)
      and (
        app_private.can_access_attendance_child(
          session.institution_id,session.unit_id,session.group_id,session.activity_id,p_child_id,false)
        or (p_child_id is null and exists(
          select 1 from public.attendance_expected_participants expected
          where expected.attendance_session_id=session.id and expected.status='active'
            and app_private.can_access_attendance_child(
              session.institution_id,session.unit_id,session.group_id,session.activity_id,
              expected.child_context_id,false)
        ))
      )
  ), source_rows as (
    select
      case p_kind
        when 'institutions' then session.institution_id
        when 'units' then session.unit_id
        when 'groups' then session.group_id
        when 'activities' then session.activity_id
        when 'students' then record.child_context_id
      end as item_id,
      case p_kind
        when 'institutions' then institution.public_name
        when 'units' then unit_record.name
        when 'groups' then group_record.name
        when 'activities' then activity.name
        when 'students' then child_person.display_name
      end as label,
      record.outcome
    from authorized_sessions session
    join public.attendance_records record
      on record.attendance_session_id=session.id and record.status='active'
    join public.institutions institution on institution.id=session.institution_id
    join public.units unit_record on unit_record.id=session.unit_id
    join public.groups group_record on group_record.id=session.group_id
    left join public.activity_definitions activity on activity.id=session.activity_id
    join public.child_contexts child_context on child_context.id=record.child_context_id
    join public.people child_person on child_person.id=child_context.child_person_id
    where (p_child_id is null or record.child_context_id=p_child_id)
      and app_private.can_access_attendance_child(
        session.institution_id,session.unit_id,session.group_id,session.activity_id,
        record.child_context_id,false)
  ), ranked as (
    select item_id,label,count(*)::integer as official_records,
      count(*) filter(where outcome in('present','late_arrival','early_departure','late_and_early'))
        ::numeric/count(*)*100 as percent,
      count(*) over()::integer as total_items
    from source_rows where item_id is not null
    group by item_id,label
  ), paged as (
    select * from ranked
    order by case when p_direction='highest' then percent end desc,
             case when p_direction='lowest' then percent end asc,label,item_id
    offset (p_page-1)*p_page_size limit p_page_size
  )
  select jsonb_build_object(
    'kind',p_kind,'direction',p_direction,'total',coalesce(max(total_items),0),
    'items',coalesce(jsonb_agg(jsonb_build_object(
      'id',item_id,'label',label,'official_records',official_records,'percent',percent
    )),'[]'::jsonb)
  ) into result from paged;
  return result;
end $$;

create or replace function app_private.attendance_dashboard_read(
  p_start date,p_end date,p_granularity text,p_institution_id uuid,p_unit_id uuid,
  p_group_id uuid,p_activity_id uuid,p_child_id uuid,p_search text,p_statuses text[],
  p_responsible_id uuid,p_sort text,p_desc boolean,p_page integer,p_page_size integer,
  p_ranking_direction text
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid:=app_private.current_person_id();
  access_payload jsonb;
  result jsonb;
  previous_start date;
  days integer;
begin
  if actor is null then raise insufficient_privilege using message='authentication required'; end if;
  if p_start is null or p_end is null or p_start>p_end or p_end>current_date
     or p_end-p_start>366 then raise invalid_parameter_value using message='invalid attendance period'; end if;
  if p_granularity not in('daily','weekly','monthly')
     or p_sort not in('context','date','responsible','presence','status')
     or p_page<1 or p_page_size not between 1 and 100
     or p_ranking_direction not in('highest','lowest') then
    raise invalid_parameter_value using message='invalid dashboard query';
  end if;
  if p_statuses is not null and exists(
    select 1 from unnest(p_statuses) value where value not in('pending','completed','inReview')
  ) then raise invalid_parameter_value using message='invalid attendance status'; end if;

  access_payload:=app_private.attendance_dashboard_access();
  if access_payload->>'scope'='guardian' and (
    p_institution_id is not null or p_unit_id is not null or p_group_id is not null
    or p_activity_id is not null or p_responsible_id is not null
  ) then
    raise insufficient_privilege using message='filter outside attendance scope';
  end if;
  days:=p_end-p_start+1;
  previous_start:=p_start-days;

  with authorized_sessions as materialized (
    select session.*,institution.public_name as institution_name,unit_record.name as unit_name,
      group_record.name as group_name,activity.name as activity_name,
      responsible.display_name as responsible_name
    from public.attendance_sessions session
    join public.institutions institution on institution.id=session.institution_id
    join public.units unit_record on unit_record.id=session.unit_id
    join public.groups group_record on group_record.id=session.group_id
    left join public.activity_definitions activity on activity.id=session.activity_id
    join public.people responsible on responsible.id=session.created_by_person_id
    where session.session_date between previous_start and p_end and session.status<>'cancelled'
      and (p_institution_id is null or session.institution_id=p_institution_id)
      and (p_unit_id is null or session.unit_id=p_unit_id)
      and (p_group_id is null or session.group_id=p_group_id)
      and (p_activity_id is null or session.activity_id=p_activity_id)
      and (p_responsible_id is null or session.created_by_person_id=p_responsible_id)
      and (
        app_private.can_access_attendance_child(
          session.institution_id,session.unit_id,session.group_id,session.activity_id,p_child_id,false)
        or (p_child_id is null and exists(
          select 1 from public.attendance_expected_participants expected
          where expected.attendance_session_id=session.id and expected.status='active'
            and app_private.can_access_attendance_child(
              session.institution_id,session.unit_id,session.group_id,session.activity_id,
              expected.child_context_id,false)
        ))
      )
  ), official_records as materialized (
    select session.*,record.child_context_id,record.outcome
    from authorized_sessions session
    join public.attendance_records record
      on record.attendance_session_id=session.id and record.status='active'
    where session.status in('closed','corrected')
      and (p_child_id is null or record.child_context_id=p_child_id)
      and app_private.can_access_attendance_child(
        session.institution_id,session.unit_id,session.group_id,session.activity_id,
        record.child_context_id,false)
  ), current_metrics as (
    select count(*)::integer as official_records,
      count(*) filter(where outcome in('present','late_arrival','early_departure','late_and_early'))::integer as numerator,
      count(*) filter(where outcome='absent')::integer as absences
    from official_records where session_date between p_start and p_end
  ), pending as (
    select count(*)::integer as count from authorized_sessions
    where session_date between p_start and p_end and status in('draft','open','reopened')
  ), reviews as (
    select count(*)::integer as count
    from public.attendance_notices notice
    where notice.review_status='pending' and notice.cancelled_at is null
      and notice.starts_at::date between p_start and p_end
      and (p_institution_id is null or notice.institution_id=p_institution_id)
      and (p_unit_id is null or notice.unit_id=p_unit_id)
      and (p_group_id is null or notice.group_id=p_group_id)
      and (p_activity_id is null or notice.activity_id=p_activity_id)
      and (p_child_id is null or notice.child_context_id=p_child_id)
      and app_private.can_access_attendance_child(
        notice.institution_id,notice.unit_id,notice.group_id,notice.activity_id,
        notice.child_context_id,false)
  ), calls_base as (
    select session.id,
      concat_ws(' · ',session.institution_name,session.unit_name,session.group_name,session.activity_name) as context,
      session.session_date,session.responsible_name,session.created_by_person_id,
      case when session.status in('closed','corrected') then 'completed' else 'pending' end as dashboard_status,
      count(record.*) filter(where record.status='active')::integer as official_records,
      count(record.*) filter(where record.status='active' and record.outcome in('present','late_arrival','early_departure','late_and_early'))::integer as numerator,
      count(record.*) filter(where record.status='active' and record.outcome='present')::integer as present,
      count(record.*) filter(where record.status='active' and record.outcome='absent')::integer as absent,
      count(record.*) filter(where record.status='active' and record.outcome in('late_arrival','late_and_early'))::integer as late
    from authorized_sessions session
    left join public.attendance_records record
      on record.attendance_session_id=session.id
     and app_private.can_access_attendance_child(
       session.institution_id,session.unit_id,session.group_id,session.activity_id,
       record.child_context_id,false)
    where session.session_date between p_start and p_end
    group by session.id,session.institution_name,session.unit_name,session.group_name,
      session.activity_name,session.session_date,session.responsible_name,
      session.created_by_person_id,session.status
  ), calls_filtered as (
    select *,count(*) over()::integer as total_items from calls_base
    where (coalesce(btrim(p_search),'')='' or context ilike '%'||btrim(p_search)||'%')
      and (p_statuses is null or cardinality(p_statuses)=0 or dashboard_status=any(p_statuses))
  ), calls_page as (
    select * from calls_filtered
    order by
      case when p_sort='date' and p_desc then session_date end desc,
      case when p_sort='date' and not p_desc then session_date end asc,
      case when p_sort='context' and p_desc then context end desc,
      case when p_sort='context' and not p_desc then context end asc,
      case when p_sort='responsible' and p_desc then responsible_name end desc,
      case when p_sort='responsible' and not p_desc then responsible_name end asc,
      case when p_sort='presence' and p_desc then numerator/nullif(official_records,0)::numeric end desc nulls last,
      case when p_sort='presence' and not p_desc then numerator/nullif(official_records,0)::numeric end asc nulls last,
      session_date desc,id
    offset (p_page-1)*p_page_size limit p_page_size
  ), series_raw as (
    select case p_granularity
        when 'weekly' then date_trunc('week',session_date::timestamp)::date
        when 'monthly' then date_trunc('month',session_date::timestamp)::date
        else session_date end as bucket,
      session_date>=p_start as current_period,count(*)::integer as official_records,
      count(*) filter(where outcome in('present','late_arrival','early_departure','late_and_early'))::integer as numerator,
      count(*) filter(where outcome='absent')::integer as absences,
      count(*) filter(where outcome in('late_arrival','late_and_early'))::integer as late
    from official_records
    group by 1,2
  ), current_series as (
    select *,row_number() over(order by bucket) as ordinal from series_raw where current_period
  ), previous_series as (
    select *,row_number() over(order by bucket) as ordinal from series_raw where not current_period
  ), series as (
    select current_series.bucket,current_series.official_records,current_series.numerator,
      current_series.absences,current_series.late,
      previous_series.official_records as previous_records,
      previous_series.numerator as previous_numerator
    from current_series left join previous_series using(ordinal)
  )
  select jsonb_build_object(
    'access',access_payload,
    'context_label',case when access_payload->>'scope'='guardian' then 'Todas as crianças'
      else coalesce((select public_name from public.institutions where id=p_institution_id),'Todas as instituições') end,
    'kpis',jsonb_build_object(
      'presence',jsonb_build_object('official_records',metrics.official_records,
        'percent',case when metrics.official_records=0 then null else metrics.numerator::numeric/metrics.official_records*100 end),
      'pending_calls',pending.count,'absences',metrics.absences,'in_review',reviews.count
    ),
    'attention',jsonb_build_array(
      jsonb_build_object('id','pending-calls','label','Chamadas pendentes','detail','Aguardando conclusão','count',pending.count),
      jsonb_build_object('id','absences','label','Faltas no período','detail','Registros oficiais','count',metrics.absences),
      jsonb_build_object('id','reviews','label','Em revisão','detail','Avisos familiares pendentes','count',reviews.count)
    ),
    'rankings',case access_payload->>'scope'
      when 'platform' then jsonb_build_array(
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'institutions',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'units',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'groups',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'activities',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'students',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'teachers',p_ranking_direction,1,3))
      when 'institution' then jsonb_build_array(
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'units',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'groups',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'activities',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'students',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'teachers',p_ranking_direction,1,3))
      when 'guardian' then jsonb_build_array(
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'students',p_ranking_direction,1,3))
      else jsonb_build_array(
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'groups',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'activities',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'students',p_ranking_direction,1,3),
        app_private.attendance_dashboard_ranking_page(p_start,p_end,p_institution_id,p_unit_id,p_group_id,p_activity_id,p_child_id,'teachers',p_ranking_direction,1,3))
    end,
    'series',coalesce((select jsonb_agg(jsonb_build_object(
      'start',bucket,'label',to_char(bucket,'DD/MM'),'official_records',official_records,
      'percent',case when official_records=0 then null else numerator::numeric/official_records*100 end,
      'previous_official_records',previous_records,
      'previous_percent',case when previous_records=0 then null else previous_numerator::numeric/previous_records*100 end,
      'absences',absences,'late',late
    ) order by bucket) from series),'[]'::jsonb),
    'calls',jsonb_build_object(
      'page',p_page,'page_size',p_page_size,'total_items',coalesce((select max(total_items) from calls_page),0),
      'items',coalesce((select jsonb_agg(jsonb_build_object(
        'id',id,
        'context',case when access_payload->>'scope'='guardian' then 'Registro de assiduidade' else context end,
        'date',session_date,
        'responsible',case when access_payload->>'scope'='guardian' then 'Equipe responsável' else responsible_name end,
        'present',present,'absent',absent,'late',late,'official_records',official_records,
        'presence_percent',case when official_records=0 then null else numerator::numeric/official_records*100 end,
        'status',dashboard_status,'can_open',access_payload->>'scope'<>'guardian'
      ) order by session_date desc,id) from calls_page),'[]'::jsonb)
    )
  ) into result
  from current_metrics metrics cross join pending cross join reviews;
  return result;
end $$;

create or replace function app_private.attendance_dashboard_request_export(
  p_request_id uuid,p_kind text,p_format text,p_filters jsonb
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid:=app_private.current_person_id();
  request_hash bytea;
  job public.import_jobs%rowtype;
  access_payload jsonb;
  scope_name text;
  requested_institution_id uuid;
  requested_unit_id uuid;
  requested_group_id uuid;
  requested_activity_id uuid;
  requested_child_id uuid;
  period_start date;
  period_end date;
  requested_page integer;
  requested_page_size integer;
begin
  if actor is null then raise insufficient_privilege using message='authentication required'; end if;
  if p_request_id is null or p_kind not in('overview','table') or p_format not in('csv','xlsx')
     or p_filters is null or jsonb_typeof(p_filters)<>'object' then
    raise invalid_parameter_value using message='invalid attendance export request';
  end if;
  if exists(
    select 1 from jsonb_object_keys(p_filters) key
    where key not in(
      'period_start','period_end','granularity','institution_id','unit_id','group_id',
      'activity_id','child_id','search','statuses','responsible_id','sort','descending',
      'page','page_size','ranking_direction'
    )
  ) then raise invalid_parameter_value using message='unknown attendance export filter'; end if;

  begin
    requested_institution_id:=nullif(p_filters->>'institution_id','')::uuid;
    requested_unit_id:=nullif(p_filters->>'unit_id','')::uuid;
    requested_group_id:=nullif(p_filters->>'group_id','')::uuid;
    requested_activity_id:=nullif(p_filters->>'activity_id','')::uuid;
    requested_child_id:=nullif(p_filters->>'child_id','')::uuid;
    perform nullif(p_filters->>'responsible_id','')::uuid;
    period_start:=(p_filters->>'period_start')::date;
    period_end:=(p_filters->>'period_end')::date;
    requested_page:=(p_filters->>'page')::integer;
    requested_page_size:=(p_filters->>'page_size')::integer;
  exception when invalid_text_representation or datetime_field_overflow or numeric_value_out_of_range then
    raise invalid_parameter_value using message='invalid typed attendance export filter';
  end;
  if period_start is null or period_end is null or period_start>period_end
     or period_end>current_date or period_end-period_start>366
     or p_filters->>'granularity' is null
     or p_filters->>'granularity' not in('daily','weekly','monthly')
     or coalesce(length(p_filters->>'search'),0)>120
     or p_filters->>'sort' is null
     or p_filters->>'sort' not in('context','date','responsible','presence','status')
     or p_filters->>'ranking_direction' is null
     or p_filters->>'ranking_direction' not in('highest','lowest')
     or coalesce(requested_page,0)<1
     or coalesce(requested_page_size,0) not between 1 and 100
     or p_filters->'statuses' is null or jsonb_typeof(p_filters->'statuses')<>'array'
     or p_filters->'descending' is null or jsonb_typeof(p_filters->'descending')<>'boolean'
     or exists(select 1 from jsonb_array_elements_text(p_filters->'statuses') status
               where status not in('pending','completed','inReview')) then
    raise invalid_parameter_value using message='invalid attendance export filters';
  end if;
  if (requested_unit_id is not null and requested_institution_id is null)
     or (requested_group_id is not null and requested_unit_id is null)
     or (requested_child_id is not null and requested_group_id is null) then
    raise invalid_parameter_value using message='incomplete attendance export hierarchy';
  end if;

  access_payload:=app_private.attendance_dashboard_access();
  scope_name:=access_payload->>'scope';
  if not coalesce((access_payload->>'can_export')::boolean,false) then
    raise insufficient_privilege using message='attendance.export required';
  end if;
  if scope_name<>'platform' and requested_institution_id is distinct from
     nullif(access_payload->>'institution_id','')::uuid then
    raise insufficient_privilege using message='institution outside attendance export scope';
  end if;
  if scope_name='unit' and requested_unit_id is distinct from
     nullif(access_payload->>'unit_id','')::uuid then
    raise insufficient_privilege using message='unit outside attendance export scope';
  end if;
  if scope_name='assignments' and requested_group_id is null and requested_activity_id is null then
    raise insufficient_privilege using message='assignment filter required for attendance export';
  end if;
  if scope_name='assignments' and requested_group_id is not null
     and not (access_payload->'assigned_group_ids' ? requested_group_id::text) then
    raise insufficient_privilege using message='group outside attendance export scope';
  end if;
  if scope_name='assignments' and requested_activity_id is not null
     and not (access_payload->'assigned_activity_ids' ? requested_activity_id::text) then
    raise insufficient_privilege using message='activity outside attendance export scope';
  end if;
  if requested_institution_id is not null and not exists(
    select 1 from public.institutions institution
    where institution.id=requested_institution_id and institution.status='active'
  ) then raise invalid_parameter_value using message='attendance export institution mismatch'; end if;
  if requested_unit_id is not null and not exists(
    select 1 from public.units unit_record
    where unit_record.id=requested_unit_id
      and unit_record.institution_id=requested_institution_id
  ) then raise invalid_parameter_value using message='attendance export unit mismatch'; end if;
  if requested_group_id is not null and not exists(
    select 1 from public.groups group_record
    where group_record.id=requested_group_id
      and group_record.institution_id=requested_institution_id
      and group_record.unit_id=requested_unit_id
  ) then raise invalid_parameter_value using message='attendance export group mismatch'; end if;
  if requested_activity_id is not null and not exists(
    select 1 from public.activity_group_links link
    where link.activity_id=requested_activity_id
      and link.institution_id=requested_institution_id
      and (requested_unit_id is null or link.unit_id=requested_unit_id)
      and (requested_group_id is null or link.group_id=requested_group_id)
      and link.status='active'
  ) then raise invalid_parameter_value using message='attendance export activity mismatch'; end if;
  if requested_child_id is not null and not app_private.can_access_attendance_child(
    requested_institution_id,requested_unit_id,requested_group_id,
    requested_activity_id,requested_child_id,false
  ) then raise insufficient_privilege using message='child outside attendance export scope'; end if;
  if requested_child_id is not null and not exists(
    select 1 from public.child_group_links group_link
    join public.child_unit_links unit_link on unit_link.id=group_link.child_unit_link_id
    join public.child_contexts child_context
      on child_context.id=unit_link.child_context_id
     and child_context.institution_id=requested_institution_id
    where group_link.group_id=requested_group_id and group_link.status='active'
      and unit_link.child_context_id=requested_child_id
      and unit_link.unit_id=requested_unit_id
      and unit_link.status in('active','awaiting_allocation')
  ) then raise invalid_parameter_value using message='attendance export child hierarchy mismatch'; end if;
  request_hash:=extensions.digest(convert_to(jsonb_build_object(
    'kind',p_kind,'format',p_format,'filters',p_filters)::text,'UTF8'),'sha256');
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
  select * into job from public.import_jobs where request_id=p_request_id;
  if found then
    if job.created_by<>actor or job.request_hash<>request_hash
       or job.target_domain<>'attendance_dashboard_export' then
      raise invalid_parameter_value using message='export request replay mismatch';
    end if;
  else
    insert into public.import_jobs(
      request_id,request_hash,institution_id,target_domain,target_table,source_format,
      source_locale,target_locale,status,processing_state,started_at,summary,created_by
    ) values(
      p_request_id,request_hash,requested_institution_id,'attendance_dashboard_export','attendance_sessions',
      p_format,'pt-BR','pt-BR','active','PROCESSANDO',now(),
      jsonb_build_object('kind',p_kind,'filters',p_filters,'pii_included',false),actor
    ) returning * into job;
    insert into audit.audit_logs(
      actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,after_json
    ) values(
      actor,auth.jwt()->>'aal','attendance.export.request','import_job',job.id,'success',
      jsonb_build_object('kind',p_kind,'format',p_format,'pii_included',false)
    );
  end if;
  return jsonb_build_object('id',job.id,'state',lower(job.processing_state::text));
end $$;

create or replace function public.attendance_dashboard_access()
returns jsonb language sql stable security definer set search_path=''
as $$select app_private.attendance_dashboard_access()$$;

create or replace function public.attendance_dashboard_read(
  p_start date,p_end date,p_granularity text,p_institution_id uuid default null,
  p_unit_id uuid default null,p_group_id uuid default null,p_activity_id uuid default null,
  p_child_id uuid default null,p_search text default '',p_statuses text[] default null,
  p_responsible_id uuid default null,p_sort text default 'date',p_desc boolean default true,
  p_page integer default 1,p_page_size integer default 20,p_ranking_direction text default 'highest'
) returns jsonb language sql stable security definer set search_path=''
as $$select app_private.attendance_dashboard_read($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)$$;

create or replace function public.attendance_dashboard_ranking_page(
  p_start date,p_end date,p_institution_id uuid,p_unit_id uuid,p_group_id uuid,
  p_activity_id uuid,p_child_id uuid,p_kind text,p_direction text,p_page integer,p_page_size integer
) returns jsonb language sql stable security definer set search_path=''
as $$select app_private.attendance_dashboard_ranking_page($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)$$;

create or replace function public.attendance_dashboard_request_export(
  p_request_id uuid,p_kind text,p_format text,p_filters jsonb
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.attendance_dashboard_request_export($1,$2,$3,$4)$$;

revoke all on function app_private.attendance_dashboard_access() from public,anon,authenticated;
revoke all on function app_private.attendance_dashboard_read(date,date,text,uuid,uuid,uuid,uuid,uuid,text,text[],uuid,text,boolean,integer,integer,text) from public,anon,authenticated;
revoke all on function app_private.attendance_dashboard_ranking_page(date,date,uuid,uuid,uuid,uuid,uuid,text,text,integer,integer) from public,anon,authenticated;
revoke all on function app_private.attendance_dashboard_request_export(uuid,text,text,jsonb) from public,anon,authenticated;

revoke all on function public.attendance_dashboard_access() from public,anon;
revoke all on function public.attendance_dashboard_read(date,date,text,uuid,uuid,uuid,uuid,uuid,text,text[],uuid,text,boolean,integer,integer,text) from public,anon;
revoke all on function public.attendance_dashboard_ranking_page(date,date,uuid,uuid,uuid,uuid,uuid,text,text,integer,integer) from public,anon;
revoke all on function public.attendance_dashboard_request_export(uuid,text,text,jsonb) from public,anon;

grant execute on function public.attendance_dashboard_access() to authenticated;
grant execute on function public.attendance_dashboard_read(date,date,text,uuid,uuid,uuid,uuid,uuid,text,text[],uuid,text,boolean,integer,integer,text) to authenticated;
grant execute on function public.attendance_dashboard_ranking_page(date,date,uuid,uuid,uuid,uuid,uuid,text,text,integer,integer) to authenticated;
grant execute on function public.attendance_dashboard_request_export(uuid,text,text,jsonb) to authenticated;
