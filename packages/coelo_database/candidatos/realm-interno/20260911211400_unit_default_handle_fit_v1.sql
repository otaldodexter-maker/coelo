-- R05 realm-interno (15): correcao do @ padrao de unidade (achado da G2 em producao
-- com 211100): "unidadeqar05transfer.qa-r04-cu" violava units_handle_normalized_check
-- porque o slug da instituicao mantinha hifens e o corte em 30 caracteres cortava o
-- sufixo. Agora o sufixo (@instituicao) e o slug so com [a-z0-9] (ate 24) e o segmento
-- da unidade e truncado ANTES do ponto para o todo caber em 30; em colisao, abre
-- espaco para _xxxx. Com `handle` explicito nada muda. Corpo igual ao de 211100
-- fora desse bloco. Reversao: recriar como em 20260911211100.
begin;
do $$ begin
  if to_regprocedure('app_private.structure_handle_segment(text)') is null then
    raise object_not_in_prerequisite_state using message='211100 is required';
  end if;
end $$;
CREATE OR REPLACE FUNCTION app_private.create_unit_for_superadmin(p_request_id uuid, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=app_private.current_person_id();tenant uuid;target uuid:=gen_random_uuid();type_id uuid;plan_id uuid;
h bytea;prior app_private.unit_management_command_receipts%rowtype;handle_value text;result jsonb;begin
tenant:=nullif(p_payload->>'institution_id','')::uuid;type_id:=nullif(p_payload->>'unit_type_id','')::uuid;plan_id:=nullif(p_payload->>'plan_override_id','')::uuid;
if p_request_id is null or actor is null or(select auth.uid())is null or not app_private.has_scoped_platform_permission('units.create',tenant)
or not app_private.has_mfa_aal2()then raise insufficient_privilege using message='units.create and AAL2 required';end if;
if nullif(btrim(p_payload->>'name'),'')is null or nullif(btrim(p_payload->>'slug'),'')is null or type_id is null
then raise invalid_parameter_value using message='institution, name, slug and unit type required';end if;
if plan_id is not null and(not app_private.has_platform_permission('units.plan.manage')or not app_private.unit_plan_is_available(plan_id,tenant))
then raise insufficient_privilege using message='units.plan.manage and available plan required';end if;
perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));h:=app_private.unit_management_hash(p_payload);
select*into prior from app_private.unit_management_command_receipts where request_id=p_request_id;
if prior.request_id is not null then if prior.actor_person_id<>actor or prior.command_kind<>'create'or prior.request_hash<>h
then raise invalid_parameter_value using message='request replay mismatch';end if;return app_private.unit_form_payload(prior.unit_id);end if;
-- Decisao 16: @ opcional; ausente -> @nomedaunidade.nomedainstituicao (sufixo curto em colisao)
if nullif(btrim(p_payload->>'handle'),'') is not null then
  handle_value:=app_private.structure_handle_normalize(p_payload->>'handle');
  if app_private.structure_handle_in_use(handle_value,'unit',null) then
    raise unique_violation using message='handle already in use',detail='SAI_HANDLE_TAKEN';
  end if;
else
  -- units_handle_normalized_check: so [a-z0-9._], ate 30 caracteres, comeca e termina
  -- em [a-z0-9]. O sufixo (@instituicao) vem do slug sem hifen/underscore e fica
  -- inteiro; o segmento da unidade e truncado ANTES do ponto para caber.
  declare
    inst_segment text := coalesce(nullif(regexp_replace(
      (select lower(i.slug) from public.institutions i where i.id=tenant),'[^a-z0-9]','','g'),''),'instituicao');
    unit_segment text := coalesce(nullif(app_private.structure_handle_segment(p_payload->>'name'),''),'unidade');
    room integer;
  begin
    inst_segment:=left(inst_segment,24);
    room:=30-1-length(inst_segment);
    handle_value:=left(unit_segment,greatest(room,1))||'.'||inst_segment;
    if app_private.structure_handle_in_use(handle_value,'unit',null) then
      handle_value:=left(unit_segment,greatest(room-5,1))||'.'||inst_segment||'_'||left(replace(target::text,'-',''),4);
    end if;
  end;
end if;
insert into public.units(id,institution_id,name,slug,status,unit_type_id,unit_type_other_description,plan_override_id,
management_version,timezone,handle,public_discovery_enabled,public_address_visible,public_contact_visible,
inherit_address,inherit_contact,inherit_branding,inherit_representatives,inherit_administrators,inherit_plan)
values(target,tenant,btrim(p_payload->>'name'),lower(btrim(p_payload->>'slug')),
coalesce(nullif(p_payload->>'unit_status','')::public.record_status,'active'),type_id,
nullif(btrim(p_payload->>'unit_type_other_description'),''),plan_id,1,
coalesce(nullif(p_payload->>'timezone',''),'America/Sao_Paulo'),handle_value,
coalesce((p_payload#>>'{public_profile,discovery_enabled}')::boolean,false),
coalesce((p_payload#>>'{public_profile,address_visible}')::boolean,false),
coalesce((p_payload#>>'{public_profile,contact_visible}')::boolean,false),
coalesce((p_payload#>>'{inheritance,address}')::boolean,true),
coalesce((p_payload#>>'{inheritance,contact}')::boolean,true),
coalesce((p_payload#>>'{inheritance,branding}')::boolean,true),
coalesce((p_payload#>>'{inheritance,representatives}')::boolean,true),
coalesce((p_payload#>>'{inheritance,administrators}')::boolean,true),plan_id is null);
perform app_private.persist_unit_children(target,actor,p_payload);result:=app_private.unit_form_payload(target);
insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
values(actor,'aal2','unit.create','unit',target,tenant,'success',jsonb_build_object('unit_type_id',type_id,'plan_override_id',plan_id));
insert into app_private.unit_management_command_receipts values(p_request_id,h,actor,'create',target,1,now());return result;end$function$;
alter function app_private.create_unit_for_superadmin(uuid,jsonb) owner to postgres;
revoke all on function app_private.create_unit_for_superadmin(uuid,jsonb) from public, anon, authenticated, service_role;
commit;
