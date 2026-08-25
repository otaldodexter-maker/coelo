begin;
create extension if not exists pgtap with schema extensions;
select plan(43);

select has_table('public','activity_assessment_settings','activity assessment periodicity exists');
select has_table('public','activity_assessment_periods','activity assessment periods exist');
select has_table('public','evaluation_scales','evaluation scales exist');
select has_table('public','assessment_instruments','canonical gradebook instruments exist');
select has_table('public','assessment_student_results','canonical gradebook results exist');
select has_table('public','competency_categories','competency categories exist');
select has_table('public','competencies','competencies exist');
select has_table('public','student_competency_scores','versioned competency scores exist');
select has_table('public','student_development_indicators','participation and behavior definitions exist');
select has_table('public','student_development_scores','participation and behavior results exist');
select has_table('public','student_report_cards','published report cards exist');
select has_table('public','student_teacher_recommendations','published recommendations exist');
select has_table('public','agenda_events','canonical agenda events exist');
select has_table('public','agenda_audiences','canonical agenda audiences exist');

select has_function('public','student_tracking_children',array['text','text','uuid','integer'],
 'children read model is cursor paginated');
select has_function('public','student_tracking_snapshot',array['uuid','uuid','uuid','timestamp with time zone','uuid','integer'],
 'student snapshot read model exists');
select has_function('public','superadmin_student_tracking_save_period',array['uuid','uuid','bigint','jsonb'],
 'period command exists');
select hasnt_function('public','superadmin_student_tracking_publish_assessment',array['uuid','bigint','text','jsonb'],
 'legacy direct assessment publication command is retired');

select ok((select bool_and(c.relrowsecurity and c.relforcerowsecurity)
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname in(
  'activity_assessment_settings','activity_assessment_periods','evaluation_scales',
  'assessment_instruments','assessment_student_results','competency_categories',
  'competencies','student_competency_scores','student_development_indicators',
  'student_development_scores','student_report_cards','student_teacher_recommendations',
  'agenda_events','agenda_audiences')),'student tracking tables force RLS');

select ok(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and (p.proname like 'student_tracking_%' or p.proname like 'superadmin_student_tracking_%')
 and has_function_privilege('anon',p.oid,'EXECUTE')),'anonymous cannot execute tracking RPCs');

select ok(
  has_function_privilege(
    'authenticated',
    'app_private.student_tracking_children(text,text,uuid,integer)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'app_private.student_tracking_snapshot(uuid,uuid,uuid,timestamp with time zone,uuid,integer)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'app_private.student_tracking_children(text,text,uuid,integer)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'app_private.student_tracking_snapshot(uuid,uuid,uuid,timestamp with time zone,uuid,integer)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'app_private.student_tracking_children(text,text,uuid,integer)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'app_private.student_tracking_snapshot(uuid,uuid,uuid,timestamp with time zone,uuid,integer)',
    'EXECUTE'
  ),
  'private tracking reads grant only the authenticated wrapper caller'
);

select ok(not has_function_privilege(
  'authenticated',
  'public.student_tracking_normalize_assessment(text,jsonb,numeric,boolean,text)',
  'EXECUTE'
),'browser clients cannot execute the internal assessment normalizer');

select ok(not has_table_privilege('authenticated','public.assessment_student_results','SELECT')
 and not has_table_privilege('authenticated','public.assessment_student_results','INSERT')
 and not has_table_privilege('authenticated','public.student_competency_scores','UPDATE'),
 'browser clients cannot bypass authorized RPCs');

select is(public.student_tracking_normalize('zero_to_ten',7,null,null),0.7::numeric,
 '0-10 is normalized server side');
select is(public.student_tracking_normalize('one_to_five',3,null,null),0.5::numeric,
 '1-5 is normalized server side');
select is(public.student_tracking_normalize('stars',4,null,null),0.8::numeric,
 'stars are normalized server side');
select is(public.student_tracking_normalize('zero_to_hundred',75,null,null),0.75::numeric,
 '0-100 is normalized server side');
select is(public.student_tracking_normalize('concept',null,null,0.6),0.6::numeric,
 'concepts are normalized server side');
select is(public.student_tracking_normalize('binary',null,true,null),1::numeric,
 'binary values are normalized server side');
select is(public.student_tracking_normalize_assessment('concept','{"concepts":["Atingiu","Em desenvolvimento"]}'::jsonb,null,null,'Atingiu'),1::numeric,
 'assessment concepts are normalized server side from their configured order');
select ok(
 pg_get_functiondef('app_private.superadmin_student_tracking_publish_competency(uuid,bigint,text,jsonb)'::regprocedure) not like '%p_payload->>''normalized_value''%'
 and pg_get_functiondef('app_private.superadmin_student_tracking_publish_development(uuid,bigint,text,jsonb)'::regprocedure) not like '%p_payload->>''normalized_value''%',
 'score publication never trusts a client supplied normalized value');

select ok(pg_get_functiondef('app_private.student_tracking_snapshot(uuid,uuid,uuid,timestamp with time zone,uuid,integer)'::regprocedure)
 like '%assessment_gradebooks%' and
 pg_get_functiondef('app_private.student_tracking_snapshot(uuid,uuid,uuid,timestamp with time zone,uuid,integer)'::regprocedure)
 like '%family_release_at%',
 'student tracking reads canonical released gradebook results');

select ok(pg_get_functiondef('app_private.student_tracking_can_read(uuid,uuid)'::regprocedure)
 like '%guardian_links%' and pg_get_functiondef('app_private.student_tracking_can_read(uuid,uuid)'::regprocedure)
 like '%guardian_context_permissions%', 'guardian reads require active link and contextual permission');
select ok(pg_get_functiondef('app_private.student_tracking_can_read(uuid,uuid)'::regprocedure)
 like '%child_unit_links%' and pg_get_functiondef('app_private.student_tracking_can_read(uuid,uuid)'::regprocedure)
 like '%child_group_links%' and pg_get_functiondef('app_private.student_tracking_can_read(uuid,uuid)'::regprocedure)
 like '%activity_group_participants%', 'unit, group and activity scope block cross-tenant IDOR');
select ok(pg_get_functiondef('app_private.student_tracking_snapshot(uuid,uuid,uuid,timestamp with time zone,uuid,integer)'::regprocedure)
 like '%gb.status=''published''%' and pg_get_functiondef('app_private.student_tracking_snapshot(uuid,uuid,uuid,timestamp with time zone,uuid,integer)'::regprocedure)
 like '%e.status=''published''%', 'draft assessments and agenda events are excluded');
select ok(pg_get_functiondef('app_private.student_tracking_snapshot(uuid,uuid,uuid,timestamp with time zone,uuid,integer)'::regprocedure)
 like '%s.status=''closed''%', 'attendance counts only closed sessions');
select ok(pg_get_functiondef('app_private.student_tracking_snapshot(uuid,uuid,uuid,timestamp with time zone,uuid,integer)'::regprocedure)
 like '%cat.activity_id=selected_activity_id%' and
 pg_get_functiondef('app_private.student_tracking_snapshot(uuid,uuid,uuid,timestamp with time zone,uuid,integer)'::regprocedure)
 like '%aa.activity_id=selected_activity_id%', 'School, Ballet and future activity taxonomies remain context-filtered');
select ok(pg_get_functiondef('app_private.student_tracking_snapshot(uuid,uuid,uuid,timestamp with time zone,uuid,integer)'::regprocedure)
 not like '%activity_id=activity_id%' and
 pg_get_functiondef('app_private.student_tracking_snapshot(uuid,uuid,uuid,timestamp with time zone,uuid,integer)'::regprocedure)
 not like '%period_id=period_id%', 'snapshot parameters cannot degrade into tautological IDOR filters');
select ok(pg_get_functiondef('app_private.student_tracking_assert_manage()'::regprocedure)
 like '%student_tracking.manage%' and pg_get_functiondef('app_private.student_tracking_assert_manage()'::regprocedure)
 like '%has_mfa_aal2%', 'management requires explicit capability and AAL2');
select ok(pg_get_functiondef('app_private.superadmin_student_tracking_correct_assessment(uuid,bigint,text,jsonb)'::regprocedure)
 like '%correction reason is required%' and pg_get_functiondef('app_private.superadmin_student_tracking_correct_assessment(uuid,bigint,text,jsonb)'::regprocedure)
 like '%management_version%', 'published correction requires reason and optimistic version');
select ok((select not public and file_size_limit=5242880 and allowed_mime_types @> array['application/pdf','image/jpeg','image/png']::text[]
 from storage.buckets where id='student-tracking-private'), 'student files use a private constrained Supabase bucket');

select hasnt_table('public','student_tracking_legacy_assessment_instruments',
 'legacy assessment instrument aggregate is not exposed');

set local role authenticated;
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000099',true);
select throws_ok($$select public.student_tracking_snapshot(
 '99000000-0000-4000-8000-000000000001',null,null,null,null,20)$$,
 '42501','authentication required','unmapped caller cannot probe a child');
reset role;

select * from finish();
rollback;
