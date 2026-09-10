-- Final Revisao Supabase: forward-only runtime/lint hardening.
-- Public signatures and existing privileges are preserved.

CREATE OR REPLACE FUNCTION app_private.student_tracking_children(p_query text, p_after_name text, p_after_id uuid, p_limit integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=app_private.current_person_id(); result jsonb;
begin
 if actor is null then raise insufficient_privilege using message='authentication required';end if;
 if p_limit not between 1 and 50 then raise invalid_parameter_value using message='limit must be between 1 and 50';end if;
 select jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(q) order by q.child_name,q.child_context_id),'[]'::jsonb),
  'next_cursor',case when count(*)=p_limit then jsonb_build_object(
    'name',(array_agg(q.child_name order by lower(q.child_name),q.child_context_id))[count(*)::integer],
    'id',(array_agg(q.child_context_id order by lower(q.child_name),q.child_context_id))[count(*)::integer]) end)
 into result from(
  select cc.id child_context_id,cc.child_person_id,p.display_name child_name,cc.institution_id,coalesce(i.trade_name,i.legal_name,'') institution_name
  from public.child_contexts cc join public.people p on p.id=cc.child_person_id
  join public.institutions i on i.id=cc.institution_id
  where cc.status='active' and app_private.student_tracking_can_read(cc.id,null)
   and (nullif(btrim(p_query),'') is null or p.display_name ilike '%'||btrim(p_query)||'%')
   and (p_after_name is null or (lower(p.display_name),cc.id)>(lower(p_after_name),p_after_id))
  order by lower(p.display_name),cc.id limit p_limit
 )q;
 return result;
end $function$;

CREATE OR REPLACE FUNCTION app_private.student_tracking_snapshot(p_child_context_id uuid, p_activity_id uuid, p_period_id uuid, p_agenda_after timestamp with time zone, p_agenda_after_id uuid, p_agenda_limit integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare cc public.child_contexts%rowtype; selected_activity_id uuid:=p_activity_id; selected_period_id uuid:=p_period_id; result jsonb;
begin
 if app_private.current_person_id() is null then raise insufficient_privilege using message='authentication required';end if;
 if not app_private.student_tracking_can_read(p_child_context_id,p_activity_id) then
  raise insufficient_privilege using message='student tracking access denied';
 end if;
 if p_agenda_limit not between 1 and 50 then raise invalid_parameter_value using message='agenda limit must be between 1 and 50';end if;
 select * into cc from public.child_contexts where id=p_child_context_id and status='active';
 if selected_activity_id is not null and not app_private.student_tracking_activity_allowed(cc.id,selected_activity_id) then
  raise insufficient_privilege using message='student tracking activity denied';end if;
 if selected_period_id is not null and not exists(select 1 from public.assessment_periods ap
  join public.activity_assessment_configurations cfg on cfg.activity_id=selected_activity_id and cfg.periodicity=ap.periodicity and cfg.status='active'
  where ap.id=selected_period_id and ap.institution_id=cc.institution_id and ap.status in('open','closed')) then
  raise insufficient_privilege using message='student tracking period denied';end if;

 select jsonb_build_object(
  'child',(select jsonb_build_object('child_context_id',cc.id,'person_id',p.id,'name',p.display_name,
    'institution_id',cc.institution_id,'institution_name',coalesce(i.trade_name,i.legal_name,'')) from public.people p join public.institutions i on i.id=cc.institution_id where p.id=cc.child_person_id),
  'contexts',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.name) order by a.name)
    from public.activity_definitions a where app_private.student_tracking_activity_allowed(cc.id,a.id)),'[]'::jsonb),
  'periods',coalesce((select jsonb_agg(jsonb_build_object('id',ap.id,'label',ap.name,'starts_on',ap.starts_on,'ends_on',ap.ends_on) order by ap.academic_year,ap.ordinal)
    from public.assessment_periods ap where ap.institution_id=cc.institution_id and ap.status in('open','closed') and exists(
      select 1 from public.activity_assessment_configurations cfg where cfg.activity_id=selected_activity_id and cfg.periodicity=ap.periodicity and cfg.status='active')),'[]'::jsonb),
  'assessments',coalesce((select jsonb_agg(jsonb_build_object('id',ir.id,'instrument_id',ins.id,'title',ins.name,
    'normalized',public.student_tracking_normalize_assessment(cfg.result_scale_kind,cfg.scale_options,ir.numeric_value,ir.boolean_value,ir.concept_code),
    'value',coalesce(ir.numeric_value::text,ir.concept_code,ir.boolean_value::text),'observation',fc.comment_text,'version',gb.management_version) order by ins.sort_order)
    from public.assessment_gradebooks gb
    join public.activity_group_links agl on agl.id=gb.activity_group_link_id and agl.activity_id=selected_activity_id
    join public.assessment_periods ap on ap.id=gb.period_id and ap.family_release_at is not null and ap.family_release_at<=now()
    join public.assessment_student_results sr on sr.gradebook_id=gb.id and sr.child_context_id=cc.id and sr.state='complete'
    join public.assessment_instrument_results ir on ir.student_result_id=sr.id and not ir.absent
    join public.assessment_instruments ins on ins.id=ir.instrument_id
    join public.activity_assessment_configurations cfg on cfg.id=gb.configuration_id
    left join public.assessment_family_comments fc on fc.student_result_id=sr.id
    where gb.period_id=selected_period_id and gb.status='published'),'[]'::jsonb),
  'competencies',coalesce((select jsonb_agg(row_to_json(x) order by x.category_ordinal,x.competency_ordinal)
    from(select c.id competency_id,cat.name category,cat.ordinal category_ordinal,c.name competency,c.ordinal competency_ordinal,s.normalized_value normalized,s.version
      from public.student_competency_scores s join public.competencies c on c.id=s.competency_id
      join public.competency_categories cat on cat.id=c.category_id
      where s.child_context_id=cc.id and s.period_id=selected_period_id and cat.activity_id=selected_activity_id and s.is_current)x),'[]'::jsonb),
  'category_scores',coalesce((select jsonb_agg(row_to_json(x) order by x.ordinal) from(
    select cat.name,cat.ordinal,round(avg(s.normalized_value),4) normalized
    from public.student_competency_scores s join public.competencies c on c.id=s.competency_id
    join public.competency_categories cat on cat.id=c.category_id
    where s.child_context_id=cc.id and s.period_id=selected_period_id and cat.activity_id=selected_activity_id and s.is_current
    group by cat.id,cat.name,cat.ordinal)x),'[]'::jsonb),
  'development',coalesce((select jsonb_agg(jsonb_build_object('indicator_id',d.id,'kind',d.indicator_kind,'name',d.name,'normalized',s.normalized_value,'version',s.version) order by d.indicator_kind,d.ordinal)
    from public.student_development_scores s join public.student_development_indicators d on d.id=s.indicator_id
    where s.child_context_id=cc.id and s.period_id=selected_period_id and d.activity_id=selected_activity_id and s.is_current),'[]'::jsonb),
  'attendance',(select jsonb_build_object('total',count(*),'present',count(*) filter(where ar.outcome='present'),
    'justified_absences',count(*) filter(where ar.outcome='absent' and n.review_status='confirmed'),
    'unjustified_absences',count(*) filter(where ar.outcome='absent' and (n.id is null or n.review_status<>'confirmed')),
    'late',count(*) filter(where ar.outcome in('late_arrival','late_and_early')),
    'percentage',coalesce(round(100.0*count(*) filter(where ar.outcome<>'absent')/nullif(count(*),0),1),0))
    from public.attendance_records ar join public.attendance_sessions s on s.id=ar.attendance_session_id and s.status='closed'
    left join public.attendance_notices n on n.id=ar.source_notice_id
    where ar.child_context_id=cc.id and ar.status='active' and (selected_activity_id is null or s.activity_id=selected_activity_id)),
  'agenda',coalesce((select jsonb_agg(row_to_json(x) order by x.starts_at,x.id) from(
    select distinct e.id,e.event_kind,e.title,e.description,e.starts_at,e.ends_at,e.all_day
    from public.agenda_events e join public.agenda_audiences aa on aa.agenda_event_id=e.id
    where e.institution_id=cc.institution_id and e.status='published'
     and (p_agenda_after is null or (e.starts_at,e.id)>(p_agenda_after,p_agenda_after_id))
     and (aa.child_context_id=cc.id or aa.activity_id=selected_activity_id or (aa.child_context_id is null and aa.activity_id is null
       and (aa.unit_id is null or exists(select 1 from public.child_unit_links cul where cul.child_context_id=cc.id and cul.unit_id=aa.unit_id and cul.status='active'))
       and (aa.group_id is null or exists(select 1 from public.child_group_links cgl join public.child_unit_links cul on cul.id=cgl.child_unit_link_id
         where cul.child_context_id=cc.id and cgl.group_id=aa.group_id and cgl.status='active'))))
    order by e.starts_at,e.id limit p_agenda_limit)x),'[]'::jsonb),
  'report_card',(select row_to_json(x) from(select rc.id,rc.title,rc.summary,rc.published_at,rc.version
    from public.student_report_cards rc where rc.child_context_id=cc.id and rc.activity_id=selected_activity_id and rc.period_id=selected_period_id and rc.is_current)x),
  'recommendation',(select row_to_json(x) from(select tr.id,tr.recommendation,tr.published_at,tr.version
    from public.student_teacher_recommendations tr where tr.child_context_id=cc.id and tr.activity_id=selected_activity_id and tr.period_id=selected_period_id and tr.is_current)x),
  'pending_notices',(select count(*) from public.attendance_notices n where n.child_context_id=cc.id and n.review_status='pending' and n.cancelled_at is null),
  'can_manage',app_private.has_platform_permission('student_tracking.manage') and app_private.has_mfa_aal2(),
  'instruments',case when app_private.has_platform_permission('student_tracking.manage') and app_private.has_mfa_aal2() then coalesce((select jsonb_agg(jsonb_build_object('id',ins.id,'name',ins.name) order by ins.sort_order)
    from public.assessment_instruments ins join public.activity_assessment_configurations cfg on cfg.id=ins.configuration_id where cfg.activity_id=selected_activity_id and cfg.status='active'),'[]'::jsonb) else '[]'::jsonb end,
  'competency_definitions',case when app_private.has_platform_permission('student_tracking.manage') and app_private.has_mfa_aal2() then coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'name',c.name,'category',cat.name) order by cat.ordinal,c.ordinal)
    from public.competencies c join public.competency_categories cat on cat.id=c.category_id where cat.activity_id=selected_activity_id and c.status='active'),'[]'::jsonb) else '[]'::jsonb end,
  'development_definitions',case when app_private.has_platform_permission('student_tracking.manage') and app_private.has_mfa_aal2() then coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'kind',d.indicator_kind) order by d.indicator_kind,d.ordinal)
    from public.student_development_indicators d where d.activity_id=selected_activity_id and d.status='active'),'[]'::jsonb) else '[]'::jsonb end
 ) into result;
 return result;
end $function$;

-- The public SECURITY INVOKER wrappers need authenticated to execute these
-- private implementations. Remove PostgreSQL's default PUBLIC grant so anon
-- and server roles cannot bypass the intended public RPC surface.
REVOKE EXECUTE ON FUNCTION
  app_private.student_tracking_children(text, text, uuid, integer),
  app_private.student_tracking_snapshot(uuid, uuid, uuid, timestamptz, uuid, integer)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION
  app_private.student_tracking_children(text, text, uuid, integer),
  app_private.student_tracking_snapshot(uuid, uuid, uuid, timestamptz, uuid, integer)
TO authenticated;
