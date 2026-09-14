-- R13 / ADR 0038 H17 (P23): politicas de cuidado por capacidade, nao por papel fixo.
-- Cria `care_policies.manage` no catalogo do Superadmin (nasce no perfil de sistema
-- Owner) e no catalogo de instituicao (nasce em Administrador da instituicao) e
-- troca o guard de superadmin_unit_care_policy_set_v1 de units.update + papel
-- owner/operations para a capacidade propria. Leitura (get_v1) continua units.read.
insert into public.platform_permissions(
  code,module_code,module_label,screen_code,screen_label,action_code,action_label,
  description,risk_level,requires_mfa,status,updated_at
) values
 ('care_policies.manage','units','Unidades','care_policies','Politicas de cuidado','manage','Gerenciar',
  'Definir politicas de seguranca infantil, medicacao e notificacao de cuidado por unidade.',
  'high',false,'active',now())
on conflict(code) do update set module_code=excluded.module_code,
 module_label=excluded.module_label,screen_code=excluded.screen_code,
 screen_label=excluded.screen_label,action_code=excluded.action_code,
 action_label=excluded.action_label,description=excluded.description,
 risk_level=excluded.risk_level,requires_mfa=excluded.requires_mfa,status='active',updated_at=now();

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='owner' and permission_record.code='care_policies.manage'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

insert into public.institution_permissions(
  code,module_code,module_label,screen_code,screen_label,action_code,action_label,
  description,risk_level,requires_mfa,status,updated_at,application_code
) values
 ('care_policies.manage','units','Unidades','care_policies','Politicas de cuidado','manage','Gerenciar',
  'Definir politicas de seguranca infantil, medicacao e notificacao de cuidado nas unidades do contexto autorizado.',
  'high',false,'active',now(),'admin')
on conflict(code) do update set module_code=excluded.module_code,
 module_label=excluded.module_label,screen_code=excluded.screen_code,
 screen_label=excluded.screen_label,action_code=excluded.action_code,
 action_label=excluded.action_label,description=excluded.description,
 risk_level=excluded.risk_level,requires_mfa=excluded.requires_mfa,status='active',updated_at=now();

insert into public.institution_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.institution_roles role_record
join public.institution_permissions permission_record
  on permission_record.code='care_policies.manage' and permission_record.status='active'
where role_record.institution_id is null and role_record.code='institution_admin'
  and role_record.is_system and role_record.status='active'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

create or replace function public.superadmin_unit_care_policy_set_v1(p_request_id uuid, p_unit_id uuid, p_payload jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid(); code text; detail text;
  unit_record public.units%rowtype; unknown_key text; request_hash bytea; prior app_private.unit_care_policy_receipts%rowtype;
  cs_mode text; med_mode text; n_unit boolean; n_hier boolean; n_guard boolean; result_version bigint; replayed boolean := false;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('care_policies.manage');
    select * into unit_record from public.units where id = p_unit_id for share;
    if unit_record.id is null or (ctx.scope_kind = 'institution' and unit_record.institution_id is distinct from ctx.scope_institution_id) then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    if p_request_id is null or p_payload is null or jsonb_typeof(p_payload) <> 'object' or p_payload = '{}'::jsonb then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    select k into unknown_key from jsonb_object_keys(p_payload) k
    where k not in ('child_safety_mode','medication_mode','notify_unit','notify_child_hierarchy','notify_other_guardians') limit 1;
    if unknown_key is not null then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
    cs_mode := p_payload ->> 'child_safety_mode'; med_mode := p_payload ->> 'medication_mode';
    if (p_payload ? 'child_safety_mode' and cs_mode not in ('accept_to_release','inclusion_only','exclusion_only'))
      or (p_payload ? 'medication_mode' and med_mode not in ('accept_to_release','inclusion_only','exclusion_only','not_tracked'))
      or (p_payload ? 'notify_unit' and jsonb_typeof(p_payload -> 'notify_unit') <> 'boolean')
      or (p_payload ? 'notify_child_hierarchy' and jsonb_typeof(p_payload -> 'notify_child_hierarchy') <> 'boolean')
      or (p_payload ? 'notify_other_guardians' and jsonb_typeof(p_payload -> 'notify_other_guardians') <> 'boolean') then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    request_hash := extensions.digest(convert_to(jsonb_build_object('unit_id', p_unit_id, 'payload', p_payload)::text, 'UTF8'), 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
    select * into prior from app_private.unit_care_policy_receipts where request_id = p_request_id;
    if prior.request_id is not null then
      if prior.actor_internal_identity_id is distinct from ctx.internal_identity_id or prior.unit_id is distinct from p_unit_id
        or prior.request_hash is distinct from request_hash then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
      replayed := true; result_version := prior.result_version;
    else
      insert into public.unit_care_policies(unit_id, institution_id, updated_by_internal_identity_id)
      values (p_unit_id, unit_record.institution_id, ctx.internal_identity_id)
      on conflict (unit_id) do nothing;
      update public.unit_care_policies p set
        child_safety_mode = coalesce(cs_mode, p.child_safety_mode),
        medication_mode = coalesce(med_mode, p.medication_mode),
        notify_unit = coalesce((p_payload ->> 'notify_unit')::boolean, p.notify_unit),
        notify_child_hierarchy = coalesce((p_payload ->> 'notify_child_hierarchy')::boolean, p.notify_child_hierarchy),
        notify_other_guardians = coalesce((p_payload ->> 'notify_other_guardians')::boolean, p.notify_other_guardians),
        management_version = p.management_version + 1,
        updated_by_internal_identity_id = ctx.internal_identity_id,
        updated_at = now()
      where p.unit_id = p_unit_id
      returning management_version into result_version;
      insert into app_private.unit_care_policy_receipts(request_id, actor_internal_identity_id, unit_id, request_hash, result_version)
      values (p_request_id, ctx.internal_identity_id, p_unit_id, request_hash, result_version);
      perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id, ctx.internal_auth_link_id,
        ctx.internal_membership_id, ctx.session_id, 'care_policies.manage', ctx.aal, 'unit.care_policy.set', 'success',
        null, correlation, unit_record.institution_id, 'unit', p_unit_id);
    end if;
  exception when others then
    get stacked diagnostics detail = pg_exception_detail;
    code := case when detail like 'SAI_%' then detail else 'SAI_INTERNAL_ERROR' end;
  end;
  if code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified('care_policies.manage', 'unit.care_policy.set', code, correlation,
      case when ctx.scope_kind = 'institution' then ctx.scope_institution_id end);
    return app_private.superadmin_internal_error_envelope(code, correlation);
  end if;
  return jsonb_build_object('ok', true, 'data',
    app_private.unit_care_policy_payload_v1(p_unit_id) || jsonb_build_object('replayed', replayed, 'correlation_id', correlation), 'error', null);
end $$;

revoke all on function public.superadmin_unit_care_policy_set_v1(uuid,uuid,jsonb) from public, anon, service_role;
grant execute on function public.superadmin_unit_care_policy_set_v1(uuid,uuid,jsonb) to authenticated;
