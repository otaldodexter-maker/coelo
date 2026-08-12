begin;

do $$
declare
  table_name text;
  function_oid oid;
  function_definition text;
begin
  foreach table_name in array array[
    'medication_plans','medication_plan_versions','medication_schedules',
    'medication_schedule_weekdays','medication_plan_reviews',
    'medication_plan_responsibles','medication_plan_suspensions',
    'medication_dose_occurrences','medication_administration_events',
    'medication_assets','medication_transfer_jobs'
  ] loop
    if to_regclass('public.' || table_name) is null then
      raise exception 'missing medication table: %', table_name;
    end if;
    if not exists (
      select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname=table_name
        and c.relrowsecurity and c.relforcerowsecurity
    ) then raise exception 'RLS/FORCE missing: %', table_name; end if;
    if has_table_privilege('anon','public.' || table_name,'SELECT')
       or has_table_privilege('authenticated','public.' || table_name,'INSERT')
       or has_table_privilege('authenticated','public.' || table_name,'UPDATE')
       or has_table_privilege('authenticated','public.' || table_name,'DELETE') then
      raise exception 'unsafe medication grant: %', table_name;
    end if;
  end loop;

  if not exists (
    select 1 from pg_constraint
    where conrelid='public.medication_plan_responsibles'::regclass
      and contype='u'
  ) then raise exception 'responsible duplicate guard missing'; end if;

  if not exists (
    select 1 from pg_trigger
    where tgrelid='public.medication_plans'::regclass
      and tgname='medication_plans_child_immutable'
  ) then raise exception 'child immutability trigger missing'; end if;

  if app_private.medication_release_ready()
     or not exists(select 1 from app_private.health_domain_release_gates
       where gate_code='legal_basis_and_retention' and gate_status='pending') then
    raise exception 'canonical health release gates must fail closed';
  end if;

  foreach function_oid in array array[
    'public.medication_plan_detail(uuid)'::regprocedure::oid,
    'public.create_medication_plan(uuid,jsonb)'::regprocedure::oid,
    'public.update_medication_plan(uuid,uuid,bigint,jsonb)'::regprocedure::oid,
    'public.add_medication_responsible(uuid,uuid,bigint,uuid)'::regprocedure::oid,
    'public.suspend_medication_plan(uuid,uuid,bigint,text)'::regprocedure::oid,
    'public.record_medication_administration(uuid,uuid,text,text,timestamptz)'::regprocedure::oid,
    'public.correct_medication_administration(uuid,uuid,text,text)'::regprocedure::oid,
    'public.create_medication_asset_upload_intent(uuid,uuid,text,text,bigint)'::regprocedure::oid,
    'app_private.finalize_medication_asset_upload(uuid,text,text,bigint)'::regprocedure::oid
  ] loop
    if has_function_privilege('anon',function_oid,'EXECUTE') then
      raise exception 'anon can execute medication RPC: %', function_oid::regprocedure;
    end if;
  end loop;

  function_definition := pg_get_functiondef(
    'app_private.assert_medication_write_access(uuid,uuid,uuid,uuid)'::regprocedure
  );
  if function_definition not like '%professional_child_assignments%'
     or function_definition not like '%medication.manage%'
     or function_definition not like '%legal_health_processing_approved%'
     or function_definition not like '%aal2%' then
    raise exception 'medication write authorization is incomplete';
  end if;

  function_definition := pg_get_functiondef(
    'app_private.validate_medication_storage_object(text,text,bigint)'::regprocedure
  );
  if function_definition not like '%image/jpeg%'
     or function_definition not like '%application/pdf%'
     or function_definition not like '%image/webp%'
     or function_definition not like '%medication/%' then
    raise exception 'storage path/MIME validation is incomplete';
  end if;

  function_definition := pg_get_functiondef(
    'public.update_medication_plan(uuid,uuid,bigint,jsonb)'::regprocedure
  );
  if function_definition not like '%medication_schedule_weekdays%'
     or function_definition not like '%jsonb_array_elements%' then
    raise exception 'medication update does not persist schedules and weekdays';
  end if;

  foreach function_oid in array array[
    'public.add_medication_responsible(uuid,uuid,bigint,uuid)'::regprocedure::oid,
    'public.suspend_medication_plan(uuid,uuid,bigint,text)'::regprocedure::oid,
    'public.record_medication_administration(uuid,uuid,text,text,timestamptz)'::regprocedure::oid,
    'public.correct_medication_administration(uuid,uuid,text,text)'::regprocedure::oid,
    'public.create_medication_asset_upload_intent(uuid,uuid,text,text,bigint)'::regprocedure::oid
  ] loop
    if pg_get_functiondef(function_oid) not like '%medication_receipt%' then
      raise exception 'secondary command is not idempotent: %', function_oid::regprocedure;
    end if;
  end loop;

  if has_function_privilege('authenticated','app_private.finalize_medication_asset_upload(uuid,text,text,bigint)','EXECUTE') then
    raise exception 'browser can finalize medication uploads';
  end if;

  if not exists (
    select 1 from pg_views
    where schemaname='public' and viewname='medication_plan_directory'
      and definition like '%medication_plans%'
  ) then raise exception 'scoped medication read model missing'; end if;
  if (select reloptions @> array['security_invoker=true']
      from pg_class where oid='public.medication_plan_directory'::regclass) is not true then
    raise exception 'medication view is not security_invoker';
  end if;
end $$;

rollback;
