begin;

create or replace function app_private.superadmin_authorize_activity_file_job(
 p_import_job_id uuid,p_action text
) returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare
 actor uuid:=app_private.current_person_id();
 job public.import_jobs%rowtype;
 required_capability text;
begin
 if (select auth.uid()) is null or actor is null then
  raise insufficient_privilege using message='authentication required';
 end if;
 if p_action not in ('import','export') then
  raise invalid_parameter_value using message='invalid activity file action';
 end if;
 required_capability:=case p_action
  when 'import' then 'activities.import' else 'activities.export' end;
 if not app_private.has_platform_permission(required_capability) then
  raise insufficient_privilege using message=required_capability||' required';
 end if;
 if not app_private.has_mfa_aal2() then
  raise insufficient_privilege using message='MFA AAL2 required';
 end if;
 select * into job from public.import_jobs job_record
 where job_record.id=p_import_job_id
  and job_record.created_by=actor
  and job_record.target_domain='activities'
  and job_record.target_table='activity_definitions'
  and job_record.summary->>'operation'=p_action;
 if job.id is null then
  raise insufficient_privilege using message='activity file job unavailable';
 end if;
 return jsonb_build_object(
  'authorized',true,'job_id',job.id,'action',p_action,
  'state',job.processing_state
 );
end $$;

create or replace function public.superadmin_authorize_activity_file_job(
 p_import_job_id uuid,p_action text
) returns jsonb language sql stable security definer set search_path=''
as $$select app_private.superadmin_authorize_activity_file_job(
 p_import_job_id,p_action)$$;

revoke all on function app_private.superadmin_authorize_activity_file_job(uuid,text)
 from public,anon,authenticated,service_role;
revoke all on function public.superadmin_authorize_activity_file_job(uuid,text)
 from public,anon,authenticated,service_role;
grant execute on function public.superadmin_authorize_activity_file_job(uuid,text)
 to authenticated;

commit;
