-- R06 estrutura: assessment_configuration_read_variable_conflict_v1
-- superadmin_assessment_configuration_read (180350) respondia SAI_INTERNAL_ERROR
-- em producao para qualquer atividade: `c.institution_id = institution_id` e
-- ambiguo entre a coluna e a variavel plpgsql (42702), mesmo defeito corrigido
-- em assessment_v2_save_configuration na R04 com #variable_conflict
-- use_variable. Sem mudar assinatura, grants ou comportamento.
-- Reversao: reaplicar o corpo de 20260910180350.

do $guard$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'must run as postgres';
  end if;
  if to_regprocedure('public.superadmin_assessment_configuration_read(uuid,uuid)') is null then
    raise feature_not_supported using message = 'superadmin_assessment_configuration_read (180350) is required';
  end if;
end
$guard$;

create or replace function public.superadmin_assessment_configuration_read(
  target_activity uuid, target_unit uuid default null
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_variable
declare ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid();
  institution_id uuid; configuration_id uuid; result jsonb; code text;
begin
  begin
    select * into strict ctx from app_private.assessment_v2_require_context('activities.read', null);
    select a.institution_id into institution_id from public.activity_definitions a
    where a.id = target_activity
      and (ctx.scope_kind <> 'institution' or a.institution_id = ctx.scope_institution_id);
    if institution_id is null then return app_private.assessment_v2_ok(null); end if;
    select * into strict ctx
    from app_private.assessment_v2_require_context('activities.read', institution_id);
    if target_unit is not null and not exists (select 1 from public.units u
      where u.id = target_unit and u.institution_id = institution_id) then
      return app_private.assessment_v2_ok(null);
    end if;
    select c.id into configuration_id
    from public.activity_assessment_configurations c
    where c.activity_id = target_activity and c.institution_id = institution_id
      and c.unit_id is not distinct from target_unit and c.status in ('active','draft')
    order by (c.status = 'active') desc, c.version desc, c.created_at desc limit 1;
    result := case when configuration_id is null then null
      else app_private.assessment_v2_configuration_snapshot(configuration_id) end;
    return app_private.assessment_v2_ok(result);
  exception when others then get stacked diagnostics code = pg_exception_detail; end;
  return app_private.assessment_v2_denied('activities.read', 'assessment.configuration.read',
    coalesce(nullif(code,''), 'SAI_INTERNAL_ERROR'), correlation, institution_id);
end $$;
