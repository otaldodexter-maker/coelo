-- R10 assessments: reload an explicitly selected configuration without
-- changing the activity/unit reader consumed by daily assessment flows.
create or replace function public.superadmin_assessment_configuration_read_by_id(
  target_configuration uuid
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid := gen_random_uuid();
  target_institution uuid;
  result jsonb;
  code text;
begin
  begin
    select * into strict ctx
    from app_private.assessment_v2_require_context('activities.read', null);
    select c.institution_id into target_institution
    from public.activity_assessment_configurations c
    where c.id = target_configuration
      and (ctx.scope_kind <> 'institution' or c.institution_id = ctx.scope_institution_id);
    if target_institution is null then return app_private.assessment_v2_ok(null); end if;
    select * into strict ctx
    from app_private.assessment_v2_require_context('activities.read', target_institution);
    result := app_private.assessment_v2_configuration_snapshot(target_configuration);
    return app_private.assessment_v2_ok(result);
  exception when others then get stacked diagnostics code = pg_exception_detail; end;
  return app_private.assessment_v2_denied(
    'activities.read', 'assessment.configuration.read_by_id',
    coalesce(nullif(code, ''), 'SAI_INTERNAL_ERROR'), correlation, target_institution
  );
end $$;

alter function public.superadmin_assessment_configuration_read_by_id(uuid) owner to postgres;
revoke all on function public.superadmin_assessment_configuration_read_by_id(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_assessment_configuration_read_by_id(uuid) to authenticated;
