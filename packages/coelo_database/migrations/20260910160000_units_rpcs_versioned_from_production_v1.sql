-- Versiona as 13 RPCs de Unidades que existiam em producao fora do versionamento.
-- Corpo lido de pg_get_functiondef em 2026-09-10 (projeto coelo, Postgres 17), sem alteracao.
-- Idempotente: create or replace; grants reproduzem a ACL observada em producao.
-- Achado registrado: funcoes security definer em public com execute para authenticated e sem revoke de PUBLIC.

-- public.change_unit_handle_for_superadmin (acl em producao: postgres=X/postgres|authenticated=X/postgres)
CREATE OR REPLACE FUNCTION public.change_unit_handle_for_superadmin(p_request_id uuid, p_unit_id uuid, p_expected_version bigint, p_handle text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'app_private'
AS $function$
  select app_private.change_unit_handle_for_superadmin(
    p_request_id,
    p_unit_id,
    p_expected_version,
    p_handle
  );
$function$;
revoke all on function public.change_unit_handle_for_superadmin(p_request_id uuid, p_unit_id uuid, p_expected_version bigint, p_handle text) from public;
grant execute on function public.change_unit_handle_for_superadmin(p_request_id uuid, p_unit_id uuid, p_expected_version bigint, p_handle text) to authenticated;

-- public.create_unit_for_superadmin (acl em producao: postgres=X/postgres|authenticated=X/postgres)
CREATE OR REPLACE FUNCTION public.create_unit_for_superadmin(p_request_id uuid, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'app_private'
AS $function$
  select app_private.create_unit_for_superadmin(p_request_id, p_payload);
$function$;
revoke all on function public.create_unit_for_superadmin(p_request_id uuid, p_payload jsonb) from public;
grant execute on function public.create_unit_for_superadmin(p_request_id uuid, p_payload jsonb) to authenticated;

-- public.get_unit_form_for_superadmin (acl em producao: postgres=X/postgres|authenticated=X/postgres)
CREATE OR REPLACE FUNCTION public.get_unit_form_for_superadmin(p_unit_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'app_private'
AS $function$
  select app_private.get_unit_form_for_superadmin(p_unit_id);
$function$;
revoke all on function public.get_unit_form_for_superadmin(p_unit_id uuid) from public;
grant execute on function public.get_unit_form_for_superadmin(p_unit_id uuid) to authenticated;

-- public.list_units_for_superadmin (acl em producao: postgres=X/postgres|authenticated=X/postgres)
CREATE OR REPLACE FUNCTION public.list_units_for_superadmin(p_search text, p_institution_ids uuid[], p_institution_type_ids uuid[], p_unit_type_ids uuid[], p_unit_statuses text[], p_plan_ids text[], p_states text[], p_cities text[], p_districts text[], p_sort text, p_ascending boolean, p_offset integer, p_limit integer)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'app_private'
AS $function$
  select app_private.list_units_for_superadmin(
    p_search,
    p_institution_ids,
    p_institution_type_ids,
    p_unit_type_ids,
    p_unit_statuses,
    p_plan_ids,
    p_states,
    p_cities,
    p_districts,
    p_sort,
    p_ascending,
    p_offset,
    p_limit
  );
$function$;
revoke all on function public.list_units_for_superadmin(p_search text, p_institution_ids uuid[], p_institution_type_ids uuid[], p_unit_type_ids uuid[], p_unit_statuses text[], p_plan_ids text[], p_states text[], p_cities text[], p_districts text[], p_sort text, p_ascending boolean, p_offset integer, p_limit integer) from public;
grant execute on function public.list_units_for_superadmin(p_search text, p_institution_ids uuid[], p_institution_type_ids uuid[], p_unit_type_ids uuid[], p_unit_statuses text[], p_plan_ids text[], p_states text[], p_cities text[], p_districts text[], p_sort text, p_ascending boolean, p_offset integer, p_limit integer) to authenticated;

-- public.preview_unit_institution_transfer_for_superadmin (acl em producao: postgres=X/postgres|authenticated=X/postgres)
CREATE OR REPLACE FUNCTION public.preview_unit_institution_transfer_for_superadmin(p_unit_id uuid, p_destination_institution_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'app_private'
AS $function$
  select app_private.preview_unit_institution_transfer(
    p_unit_id,
    p_destination_institution_id
  );
$function$;
revoke all on function public.preview_unit_institution_transfer_for_superadmin(p_unit_id uuid, p_destination_institution_id uuid) from public;
grant execute on function public.preview_unit_institution_transfer_for_superadmin(p_unit_id uuid, p_destination_institution_id uuid) to authenticated;

-- public.request_unit_type_for_superadmin (acl em producao: postgres=X/postgres|authenticated=X/postgres)
CREATE OR REPLACE FUNCTION public.request_unit_type_for_superadmin(p_request_id uuid, p_unit_id uuid, p_description text, p_context jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'app_private'
AS $function$
  select app_private.request_unit_type_for_superadmin(
    p_request_id,
    p_unit_id,
    p_description,
    p_context
  );
$function$;
revoke all on function public.request_unit_type_for_superadmin(p_request_id uuid, p_unit_id uuid, p_description text, p_context jsonb) from public;
grant execute on function public.request_unit_type_for_superadmin(p_request_id uuid, p_unit_id uuid, p_description text, p_context jsonb) to authenticated;

-- public.superadmin_prepare_unit_identity_upload (acl em producao: postgres=X/postgres|authenticated=X/postgres)
CREATE OR REPLACE FUNCTION public.superadmin_prepare_unit_identity_upload(uuid, text, text, bigint, uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$select app_private.superadmin_prepare_unit_identity_upload($1,$2,$3,$4,$5)$function$;
revoke all on function public.superadmin_prepare_unit_identity_upload(uuid, text, text, bigint, uuid) from public;
grant execute on function public.superadmin_prepare_unit_identity_upload(uuid, text, text, bigint, uuid) to authenticated;

-- public.superadmin_request_unit_identity_delete (acl em producao: postgres=X/postgres|authenticated=X/postgres)
CREATE OR REPLACE FUNCTION public.superadmin_request_unit_identity_delete(uuid, uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$select app_private.superadmin_request_unit_identity_delete($1,$2)$function$;
revoke all on function public.superadmin_request_unit_identity_delete(uuid, uuid) from public;
grant execute on function public.superadmin_request_unit_identity_delete(uuid, uuid) to authenticated;

-- public.superadmin_unit_identity_download_descriptor (acl em producao: postgres=X/postgres|authenticated=X/postgres)
CREATE OR REPLACE FUNCTION public.superadmin_unit_identity_download_descriptor(uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$select app_private.superadmin_unit_identity_download_descriptor($1)$function$;
revoke all on function public.superadmin_unit_identity_download_descriptor(uuid) from public;
grant execute on function public.superadmin_unit_identity_download_descriptor(uuid) to authenticated;

-- public.superadmin_unit_import_template (acl em producao: postgres=X/postgres|authenticated=X/postgres)
CREATE OR REPLACE FUNCTION public.superadmin_unit_import_template()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$select app_private.superadmin_unit_import_template()$function$;
revoke all on function public.superadmin_unit_import_template() from public;
grant execute on function public.superadmin_unit_import_template() to authenticated;

-- public.transfer_unit_institution_for_superadmin (acl em producao: postgres=X/postgres|authenticated=X/postgres)
CREATE OR REPLACE FUNCTION public.transfer_unit_institution_for_superadmin(p_request_id uuid, p_unit_id uuid, p_destination_institution_id uuid, p_expected_version bigint, p_confirmed boolean)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'app_private'
AS $function$
  select app_private.transfer_unit_institution_for_superadmin(
    p_request_id,
    p_unit_id,
    p_destination_institution_id,
    p_expected_version,
    p_confirmed
  );
$function$;
revoke all on function public.transfer_unit_institution_for_superadmin(p_request_id uuid, p_unit_id uuid, p_destination_institution_id uuid, p_expected_version bigint, p_confirmed boolean) from public;
grant execute on function public.transfer_unit_institution_for_superadmin(p_request_id uuid, p_unit_id uuid, p_destination_institution_id uuid, p_expected_version bigint, p_confirmed boolean) to authenticated;

-- public.unit_directory_filter_options (acl em producao: postgres=X/postgres|authenticated=X/postgres)
CREATE OR REPLACE FUNCTION public.unit_directory_filter_options(p_states text[], p_cities text[])
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'app_private'
AS $function$
  select app_private.unit_directory_filter_options(p_states, p_cities);
$function$;
revoke all on function public.unit_directory_filter_options(p_states text[], p_cities text[]) from public;
grant execute on function public.unit_directory_filter_options(p_states text[], p_cities text[]) to authenticated;

-- public.update_unit_for_superadmin (acl em producao: postgres=X/postgres|authenticated=X/postgres)
CREATE OR REPLACE FUNCTION public.update_unit_for_superadmin(p_request_id uuid, p_payload jsonb, p_unit_id uuid, p_expected_version bigint)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'app_private'
AS $function$
  select app_private.update_unit_for_superadmin(
    p_request_id,
    p_payload,
    p_unit_id,
    p_expected_version
  );
$function$;
revoke all on function public.update_unit_for_superadmin(p_request_id uuid, p_payload jsonb, p_unit_id uuid, p_expected_version bigint) from public;
grant execute on function public.update_unit_for_superadmin(p_request_id uuid, p_payload jsonb, p_unit_id uuid, p_expected_version bigint) to authenticated;

-- app_private.change_unit_handle_for_superadmin (acl em producao: sem ACL explicita)
CREATE OR REPLACE FUNCTION app_private.change_unit_handle_for_superadmin(p_request_id uuid, p_unit_id uuid, p_expected_version bigint, p_requested_handle text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=app_private.current_person_id();u public.units%rowtype;n text;prior public.unit_handle_history%rowtype;begin
select*into u from public.units where id=p_unit_id for update;if u.id is null then raise no_data_found using message='unit not found';end if;
if actor is null or not app_private.has_platform_permission('units.handle.manage')
or not app_private.has_scoped_platform_permission('units.update',u.institution_id)or not app_private.has_mfa_aal2()
then raise insufficient_privilege using message='units.handle.manage and AAL2 required';end if;
n:=lower(regexp_replace(btrim(p_requested_handle),'^@','','g'));select*into prior from public.unit_handle_history where request_id=p_request_id;
if prior.id is not null then if prior.unit_id<>p_unit_id or prior.new_handle<>n then raise invalid_parameter_value using message='request replay mismatch';end if;
return app_private.unit_form_payload(p_unit_id);end if;
if u.management_version<>p_expected_version then raise serialization_failure using message='stale unit version';end if;
if u.handle_last_changed_at is not null and u.handle_last_changed_at>now()-interval'15 days'
then raise check_violation using message='unit handle can only change every 15 days';end if;
if n!~'^[a-z0-9][a-z0-9._]{1,28}[a-z0-9]$'then raise invalid_parameter_value using message='invalid handle';end if;
update public.units set handle=n,handle_last_changed_at=now(),management_version=management_version+1,updated_at=now()where id=p_unit_id;
insert into public.unit_handle_history(request_id,unit_id,institution_id,old_handle,new_handle,changed_by_person_id)
values(p_request_id,p_unit_id,u.institution_id,u.handle,n,actor);
insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome)
values(actor,'aal2','unit.handle.change','unit',p_unit_id,u.institution_id,'success');return app_private.unit_form_payload(p_unit_id);end$function$;
revoke all on function app_private.change_unit_handle_for_superadmin(p_request_id uuid, p_unit_id uuid, p_expected_version bigint, p_requested_handle text) from public;
revoke all on function app_private.change_unit_handle_for_superadmin(p_request_id uuid, p_unit_id uuid, p_expected_version bigint, p_requested_handle text) from anon, authenticated;

-- app_private.create_unit_for_superadmin (acl em producao: postgres=X/postgres)
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
handle_value:=lower(regexp_replace(coalesce(nullif(p_payload->>'handle',''),
left(regexp_replace(p_payload->>'slug','[^A-Za-z0-9]+','','g'),20)||'_'||left(replace(target::text,'-',''),8)),'^@','','g'));
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
revoke all on function app_private.create_unit_for_superadmin(p_request_id uuid, p_payload jsonb) from public;
revoke all on function app_private.create_unit_for_superadmin(p_request_id uuid, p_payload jsonb) from anon, authenticated;

-- app_private.get_unit_form_for_superadmin (acl em producao: postgres=X/postgres)
CREATE OR REPLACE FUNCTION app_private.get_unit_form_for_superadmin(p_unit_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$declare t uuid;begin
if(select auth.uid())is null or app_private.current_person_id()is null then raise insufficient_privilege using message='authentication required';end if;
if p_unit_id is not null then select institution_id into t from public.units where id=p_unit_id;
if t is null then return jsonb_build_object('unit',null,'not_found',true,'institutions','[]'::jsonb,'unit_types','[]'::jsonb,'plans','[]'::jsonb);end if;
if not app_private.has_scoped_platform_permission('units.read',t)then raise insufficient_privilege using message='units.read required';end if;end if;
return jsonb_build_object('unit',case when p_unit_id is null then null else app_private.unit_form_payload(p_unit_id)end,'not_found',false,
'institutions',coalesce((select jsonb_agg(jsonb_build_object('institution_id',i.id,'institution_name',i.public_name,
'institution_type',jsonb_build_object('id',i.institution_type_id,'label',it.name),'effective_plan',jsonb_build_object('id',sub.plan_id,'code',p.code,'label',p.name))order by i.public_name)
from public.institutions i left join public.institution_types it on it.id=i.institution_type_id
left join lateral(select s.plan_id from public.institution_subscriptions s where s.institution_id=i.id and s.status not in('cancelled','suspended')order by s.created_at desc,s.id desc limit 1)sub on true
left join public.plans p on p.id=sub.plan_id where i.deleted_at is null and app_private.has_scoped_platform_permission('units.read',i.id)),'[]'::jsonb),
'unit_types',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',name,'code',code)order by name)from public.unit_types where status='active'),'[]'::jsonb),
'plans',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'label',p.name,'code',p.code)order by p.name)from public.plans p where p.status='active'),'[]'::jsonb));end$function$;
revoke all on function app_private.get_unit_form_for_superadmin(p_unit_id uuid) from public;
revoke all on function app_private.get_unit_form_for_superadmin(p_unit_id uuid) from anon, authenticated;

-- app_private.list_units_for_superadmin (acl em producao: postgres=X/postgres)
CREATE OR REPLACE FUNCTION app_private.list_units_for_superadmin(p_search text, p_institution_ids uuid[], p_institution_type_ids uuid[], p_unit_type_ids uuid[], p_unit_statuses text[], p_plan_ids text[], p_states text[], p_cities text[], p_districts text[], p_sort text, p_ascending boolean, p_offset integer, p_limit integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$declare r jsonb;s text;begin
if(select auth.uid())is null or app_private.current_person_id()is null then raise insufficient_privilege using message='authentication required';end if;
if p_offset<0 or p_limit not between 1 and 100 then raise invalid_parameter_value using message='invalid pagination';end if;s:=app_private.normalize_unit_sort(p_sort);
with f as(select*from public.unit_directory d where app_private.has_scoped_platform_permission('units.read',d.institution_id)
and(nullif(btrim(p_search),'')is null or d.name ilike'%'||p_search||'%'or d.institution_name ilike'%'||p_search||'%'or d.handle ilike'%'||regexp_replace(p_search,'^@','','g')||'%')
and(app_private.unit_filter_is_empty(p_institution_ids)or d.institution_id=any(p_institution_ids))
and(app_private.unit_filter_is_empty(p_institution_type_ids)or d.institution_type_id=any(p_institution_type_ids))
and(app_private.unit_filter_is_empty(p_unit_type_ids)or d.unit_type_id=any(p_unit_type_ids))
and(app_private.unit_filter_is_empty(p_unit_statuses)or d.unit_status=any(p_unit_statuses))
and(app_private.unit_filter_is_empty(p_plan_ids)or d.effective_plan_id::text=any(p_plan_ids)or d.effective_plan_code=any(p_plan_ids))
and(app_private.unit_filter_is_empty(p_states)or d.address->>'state'=any(p_states))
and(app_private.unit_filter_is_empty(p_cities)or d.address->>'city'=any(p_cities))
and(app_private.unit_filter_is_empty(p_districts)or d.address->>'district'=any(p_districts))),
q as(select*from f order by
case when p_ascending and s='name'then lower(name)end,case when not p_ascending and s='name'then lower(name)end desc,
case when p_ascending and s='institution_name'then lower(institution_name)end,case when not p_ascending and s='institution_name'then lower(institution_name)end desc,
case when p_ascending and s='institution_type_name'then lower(coalesce(institution_type_name,''))end,case when not p_ascending and s='institution_type_name'then lower(coalesce(institution_type_name,''))end desc,
case when p_ascending and s='unit_type_name'then lower(unit_type_name)end,case when not p_ascending and s='unit_type_name'then lower(unit_type_name)end desc,
case when p_ascending and s='unit_status'then unit_status end,case when not p_ascending and s='unit_status'then unit_status end desc,
case when p_ascending and s='plan_name'then lower(coalesce(effective_plan_name,''))end,case when not p_ascending and s='plan_name'then lower(coalesce(effective_plan_name,''))end desc,
case when p_ascending and s='groups_count'then groups_count end,case when not p_ascending and s='groups_count'then groups_count end desc,
case when p_ascending and s='activities_count'then activities_count end,case when not p_ascending and s='activities_count'then activities_count end desc,
case when p_ascending and s='updated_at'then updated_at end,case when not p_ascending and s='updated_at'then updated_at end desc,
case when p_ascending and s='contact_email'then lower(coalesce(contact->>'email',''))end,case when not p_ascending and s='contact_email'then lower(coalesce(contact->>'email',''))end desc,
case when p_ascending and s='contact_phone'then coalesce(contact->>'phone','')end,case when not p_ascending and s='contact_phone'then coalesce(contact->>'phone','')end desc,
case when p_ascending and s='contact_mobile_phone'then coalesce(contact->>'mobile_phone','')end,case when not p_ascending and s='contact_mobile_phone'then coalesce(contact->>'mobile_phone','')end desc,
case when p_ascending and s='street'then lower(coalesce(address->>'street',''))end,case when not p_ascending and s='street'then lower(coalesce(address->>'street',''))end desc,
case when p_ascending and s='address_number'then lower(coalesce(address->>'number',''))end,case when not p_ascending and s='address_number'then lower(coalesce(address->>'number',''))end desc,
case when p_ascending and s='complement'then lower(coalesce(address->>'complement',''))end,case when not p_ascending and s='complement'then lower(coalesce(address->>'complement',''))end desc,
case when p_ascending and s='district'then lower(coalesce(address->>'district',''))end,case when not p_ascending and s='district'then lower(coalesce(address->>'district',''))end desc,
case when p_ascending and s='postal_code'then coalesce(address->>'postal_code','')end,case when not p_ascending and s='postal_code'then coalesce(address->>'postal_code','')end desc,
case when p_ascending and s='city'then lower(coalesce(address->>'city',''))end,case when not p_ascending and s='city'then lower(coalesce(address->>'city',''))end desc,
case when p_ascending and s='state'then lower(coalesce(address->>'state',''))end,case when not p_ascending and s='state'then lower(coalesce(address->>'state',''))end desc,id offset p_offset limit p_limit)
select jsonb_build_object('items',coalesce((select jsonb_agg(app_private.unit_directory_row_payload(to_jsonb(q)))from q),'[]'::jsonb),'total_count',(select count(*)from f))into r;return r;end$function$;
revoke all on function app_private.list_units_for_superadmin(p_search text, p_institution_ids uuid[], p_institution_type_ids uuid[], p_unit_type_ids uuid[], p_unit_statuses text[], p_plan_ids text[], p_states text[], p_cities text[], p_districts text[], p_sort text, p_ascending boolean, p_offset integer, p_limit integer) from public;
revoke all on function app_private.list_units_for_superadmin(p_search text, p_institution_ids uuid[], p_institution_type_ids uuid[], p_unit_type_ids uuid[], p_unit_statuses text[], p_plan_ids text[], p_states text[], p_cities text[], p_districts text[], p_sort text, p_ascending boolean, p_offset integer, p_limit integer) from anon, authenticated;

-- app_private.request_unit_type_for_superadmin (acl em producao: sem ACL explicita)
CREATE OR REPLACE FUNCTION app_private.request_unit_type_for_superadmin(p_request_id uuid, p_unit_id uuid, p_description text, p_context jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=app_private.current_person_id();t uuid;r public.unit_type_requests%rowtype;begin
select institution_id into t from public.units where id=p_unit_id;
if p_request_id is null or t is null or nullif(btrim(p_description),'')is null or jsonb_typeof(p_context)<>'object'
then raise invalid_parameter_value using message='invalid type request';end if;
if actor is null or not app_private.has_scoped_platform_permission('unit_types.request',t)or not app_private.has_mfa_aal2()
then raise insufficient_privilege using message='unit_types.request and AAL2 required';end if;
perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));select*into r from public.unit_type_requests where request_id=p_request_id;
if r.id is null then insert into public.unit_type_requests(request_id,institution_id,unit_id,requested_description,context_json,requested_by_person_id)
values(p_request_id,t,p_unit_id,btrim(p_description),p_context,actor)returning*into r;
insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome)
values(actor,'aal2','unit_type.request','unit_type_request',r.id,t,'success');end if;return to_jsonb(r);end$function$;
revoke all on function app_private.request_unit_type_for_superadmin(p_request_id uuid, p_unit_id uuid, p_description text, p_context jsonb) from public;
revoke all on function app_private.request_unit_type_for_superadmin(p_request_id uuid, p_unit_id uuid, p_description text, p_context jsonb) from anon, authenticated;

-- app_private.superadmin_prepare_unit_identity_upload (acl em producao: postgres=X/postgres)
CREATE OR REPLACE FUNCTION app_private.superadmin_prepare_unit_identity_upload(unit_id uuid, kind text, mime text, bytes bigint, request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=app_private.current_person_id();institution uuid;media uuid;path text;ext text;
 prior app_private.unit_identity_upload_intents%rowtype;expiry timestamptz:=now()+interval'15 minutes';begin
 if(select auth.uid())is null or actor is null or request_id is null then raise insufficient_privilege using message='authentication required';end if;
 select u.institution_id into institution from public.units u where u.id=unit_id;
 if institution is null then raise no_data_found using message='unit not found';end if;
 if not app_private.has_scoped_platform_permission('units.update',institution)or not app_private.has_mfa_aal2()
 then raise insufficient_privilege using message='units.update and AAL2 required';end if;
 if kind not in('profile','cover','featured')or mime not in('image/jpeg','image/png')or bytes not between 1 and 5242880
 then raise invalid_parameter_value using message='invalid unit identity upload';end if;
 perform pg_advisory_xact_lock(hashtextextended(request_id::text,0));
 select*into prior from app_private.unit_identity_upload_intents i where i.request_id=superadmin_prepare_unit_identity_upload.request_id;
 if prior.request_id is not null then
  if prior.actor_person_id<>actor or prior.unit_id<>unit_id or prior.media_kind::text<>kind or prior.mime_type<>mime or prior.size_bytes<>bytes
  then raise invalid_parameter_value using message='idempotency key reused';end if;
  return jsonb_build_object('media_id',prior.media_id,'bucket','coelo-unit-identities','upload_path',prior.storage_path,'expires_at',prior.expires_at);end if;
 media:=gen_random_uuid();ext:=case mime when'image/jpeg'then'jpg'else'png'end;
 path:='institutions/'||institution||'/units/'||unit_id||'/'||kind||'/'||media||'.'||ext;
 insert into public.unit_identity_media(id,institution_id,unit_id,media_kind,storage_path,mime_type,size_bytes,created_by_person_id)
 values(media,institution,unit_id,kind::public.unit_identity_media_kind,path,mime,bytes,actor);
 insert into app_private.unit_identity_upload_intents values(request_id,media,institution,unit_id,kind::public.unit_identity_media_kind,actor,path,mime,bytes,expiry,null,now());
 insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
 values(actor,auth.jwt()->>'aal','unit.identity.upload.prepare','unit_identity_media',media,institution,'success',
 jsonb_build_object('unit_id',unit_id,'kind',kind,'bucket','coelo-unit-identities','path',path,'mime_type',mime,'size_bytes',bytes));
 return jsonb_build_object('media_id',media,'bucket','coelo-unit-identities','upload_path',path,'expires_at',expiry);end$function$;
revoke all on function app_private.superadmin_prepare_unit_identity_upload(unit_id uuid, kind text, mime text, bytes bigint, request_id uuid) from public;
revoke all on function app_private.superadmin_prepare_unit_identity_upload(unit_id uuid, kind text, mime text, bytes bigint, request_id uuid) from anon, authenticated;

-- app_private.superadmin_request_unit_identity_delete (acl em producao: postgres=X/postgres)
CREATE OR REPLACE FUNCTION app_private.superadmin_request_unit_identity_delete(media_id uuid, request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$declare actor uuid:=app_private.current_person_id();
 media public.unit_identity_media%rowtype;prior app_private.unit_identity_delete_requests%rowtype;begin
 if(select auth.uid())is null or actor is null or request_id is null then raise insufficient_privilege using message='authentication required';end if;
 perform pg_advisory_xact_lock(hashtextextended(request_id::text,0));select*into prior from app_private.unit_identity_delete_requests r
 where r.request_id=superadmin_request_unit_identity_delete.request_id;
 if prior.request_id is not null then if prior.actor_person_id<>actor or prior.media_id<>media_id then raise invalid_parameter_value using message='idempotency key reused';end if;
  return jsonb_build_object('media_id',prior.media_id,'bucket','coelo-unit-identities','delete_path',prior.storage_path);end if;
 select*into media from public.unit_identity_media m where m.id=media_id for update;
 if media.id is null then raise no_data_found using message='unit identity media not found';end if;
 if not app_private.has_scoped_platform_permission('units.update',media.institution_id)or not app_private.has_mfa_aal2()
 then raise insufficient_privilege using message='units.update and AAL2 required';end if;
 if media.status not in('active','pending_delete')then raise invalid_parameter_value using message='unit identity media cannot be deleted';end if;
 update public.unit_identity_media set status='pending_delete',pending_delete_at=coalesce(pending_delete_at,now())where id=media.id;
 if media.media_kind='profile'then update public.unit_branding set logo_media_asset_id=null,updated_by=actor,updated_at=now()
  where unit_id=media.unit_id and logo_media_asset_id=media.id;
 elsif media.media_kind='cover'then update public.unit_branding set cover_media_asset_id=null,updated_by=actor,updated_at=now()
  where unit_id=media.unit_id and cover_media_asset_id=media.id;end if;
 insert into app_private.unit_identity_delete_requests values(request_id,media.id,actor,media.storage_path,null,now());
 insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,before_json,after_json)
 values(actor,auth.jwt()->>'aal','unit.identity.delete.request','unit_identity_media',media.id,media.institution_id,'success',to_jsonb(media),jsonb_build_object('status','pending_delete'));
 return jsonb_build_object('media_id',media.id,'bucket','coelo-unit-identities','delete_path',media.storage_path);end$function$;
revoke all on function app_private.superadmin_request_unit_identity_delete(media_id uuid, request_id uuid) from public;
revoke all on function app_private.superadmin_request_unit_identity_delete(media_id uuid, request_id uuid) from anon, authenticated;

-- app_private.superadmin_unit_identity_download_descriptor (acl em producao: postgres=X/postgres)
CREATE OR REPLACE FUNCTION app_private.superadmin_unit_identity_download_descriptor(media_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$declare media public.unit_identity_media%rowtype;begin
 select*into media from public.unit_identity_media m where m.id=media_id and m.status='active';
 if media.id is null then raise no_data_found using message='unit identity media not found';end if;
 if(select auth.uid())is null or not app_private.has_scoped_platform_permission('units.read',media.institution_id)
 then raise insufficient_privilege using message='units.read required';end if;
 return jsonb_build_object('media_id',media.id,'bucket',media.storage_bucket,'path',media.storage_path,'signed_url_ttl_seconds',300);end$function$;
revoke all on function app_private.superadmin_unit_identity_download_descriptor(media_id uuid) from public;
revoke all on function app_private.superadmin_unit_identity_download_descriptor(media_id uuid) from anon, authenticated;

-- app_private.superadmin_unit_import_template (acl em producao: postgres=X/postgres)
CREATE OR REPLACE FUNCTION app_private.superadmin_unit_import_template()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform app_private.assert_unit_file_access('units.import',null);
 return jsonb_build_object(
  'formats',jsonb_build_array('csv','xlsx'),
  'headers',jsonb_build_array('institution_id','name','slug','unit_type_id','unit_type_other_text','status'),
  'required',jsonb_build_array('institution_id','name','slug','unit_type_id'),
  'max_rows',5000,'max_bytes',5242880
 );
end $function$;
revoke all on function app_private.superadmin_unit_import_template() from public;
revoke all on function app_private.superadmin_unit_import_template() from anon, authenticated;

-- app_private.transfer_unit_institution_for_superadmin (acl em producao: sem ACL explicita)
CREATE OR REPLACE FUNCTION app_private.transfer_unit_institution_for_superadmin(p_request_id uuid, p_unit_id uuid, p_destination_institution_id uuid, p_expected_version bigint, p_confirmed boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=app_private.current_person_id();u public.units%rowtype;impact jsonb;h bytea;prior app_private.unit_management_command_receipts%rowtype;begin
if p_request_id is null or not coalesce(p_confirmed,false)then raise invalid_parameter_value using message='explicit transfer confirmation required';end if;
if actor is null or not app_private.has_mfa_aal2()then raise insufficient_privilege using message='AAL2 required';end if;
h:=app_private.unit_management_hash(jsonb_build_object('unit_id',p_unit_id,'destination_institution_id',p_destination_institution_id,'expected_version',p_expected_version,'confirmed',true));
perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
select*into prior from app_private.unit_management_command_receipts where request_id=p_request_id;
if prior.request_id is not null then
 if prior.request_hash<>h or prior.actor_person_id<>actor or prior.command_kind<>'transfer' or prior.unit_id<>p_unit_id then raise invalid_parameter_value using message='request replay mismatch';end if;
 if not exists(select 1 from public.units where id=p_unit_id and app_private.has_scoped_platform_permission('units.read',institution_id))then raise insufficient_privilege using message='unit read scope required';end if;
 return app_private.unit_form_payload(p_unit_id);
end if;
select*into u from public.units where id=p_unit_id for update;if u.id is null then raise no_data_found using message='unit not found';end if;
if u.management_version<>p_expected_version then raise serialization_failure using message='stale unit version';end if;
impact:=app_private.preview_unit_institution_transfer(p_unit_id,p_destination_institution_id);
if jsonb_array_length(impact->'incompatible_dependencies')>0 then raise check_violation using message='unit transfer blocked by incompatible dependencies';end if;
update public.units set institution_id=p_destination_institution_id,management_version=management_version+1,updated_at=now()where id=p_unit_id;
insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
values(actor,'aal2','unit.institution.transfer','unit',p_unit_id,p_destination_institution_id,'success',impact);
insert into app_private.unit_management_command_receipts(request_id,request_hash,actor_person_id,command_kind,unit_id,result_management_version)
values(p_request_id,h,actor,'transfer',p_unit_id,p_expected_version+1);
return app_private.unit_form_payload(p_unit_id);end$function$;
revoke all on function app_private.transfer_unit_institution_for_superadmin(p_request_id uuid, p_unit_id uuid, p_destination_institution_id uuid, p_expected_version bigint, p_confirmed boolean) from public;
revoke all on function app_private.transfer_unit_institution_for_superadmin(p_request_id uuid, p_unit_id uuid, p_destination_institution_id uuid, p_expected_version bigint, p_confirmed boolean) from anon, authenticated;

-- app_private.unit_directory_filter_options (acl em producao: postgres=X/postgres)
CREATE OR REPLACE FUNCTION app_private.unit_directory_filter_options(p_states text[], p_cities text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$begin
if(select auth.uid())is null or app_private.current_person_id()is null then raise insufficient_privilege using message='authentication required';end if;
return app_private.unit_directory_filter_options_payload(p_states,p_cities);end$function$;
revoke all on function app_private.unit_directory_filter_options(p_states text[], p_cities text[]) from public;
revoke all on function app_private.unit_directory_filter_options(p_states text[], p_cities text[]) from anon, authenticated;

-- app_private.update_unit_for_superadmin (acl em producao: postgres=X/postgres)
CREATE OR REPLACE FUNCTION app_private.update_unit_for_superadmin(p_request_id uuid, p_payload jsonb, p_unit_id uuid, p_expected_version bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=app_private.current_person_id();u public.units%rowtype;plan_id uuid;type_id uuid;h bytea;
prior app_private.unit_management_command_receipts%rowtype;result jsonb;begin
select*into u from public.units where id=p_unit_id;if u.id is null then raise no_data_found using message='unit not found';end if;
if p_request_id is null or actor is null or(select auth.uid())is null or not app_private.has_scoped_platform_permission('units.update',u.institution_id)
or not app_private.has_mfa_aal2()then raise insufficient_privilege using message='units.update and AAL2 required';end if;
if p_payload?'institution_id'and(p_payload->>'institution_id')::uuid<>u.institution_id then raise invalid_parameter_value using message='use transfer command';end if;
if p_payload?'handle'then raise invalid_parameter_value using message='use handle command';end if;
perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
h:=app_private.unit_management_hash(jsonb_build_object('unit_id',p_unit_id,'expected_version',p_expected_version,'payload',p_payload));
select*into prior from app_private.unit_management_command_receipts where request_id=p_request_id;
if prior.request_id is not null then if prior.actor_person_id<>actor or prior.command_kind<>'update'or prior.unit_id<>p_unit_id or prior.request_hash<>h
then raise invalid_parameter_value using message='request replay mismatch';end if;return app_private.unit_form_payload(prior.unit_id);end if;
select*into u from public.units where id=p_unit_id for update;if u.management_version<>p_expected_version then raise serialization_failure using message='stale unit version';end if;
plan_id:=case when p_payload?'plan_override_id'then nullif(p_payload->>'plan_override_id','')::uuid else u.plan_override_id end;
type_id:=case when p_payload?'unit_type_id'then(p_payload->>'unit_type_id')::uuid else u.unit_type_id end;
if plan_id is distinct from u.plan_override_id and(not app_private.has_platform_permission('units.plan.manage')
or(plan_id is not null and not app_private.unit_plan_is_available(plan_id,u.institution_id)))
then raise insufficient_privilege using message='units.plan.manage and available plan required';end if;
update public.units x set name=coalesce(nullif(btrim(p_payload->>'name'),''),x.name),
slug=coalesce(nullif(lower(btrim(p_payload->>'slug')),''),x.slug),
status=case when p_payload?'unit_status'then(p_payload->>'unit_status')::public.record_status else x.status end,
unit_type_id=type_id,unit_type_other_description=case when p_payload?'unit_type_other_description'
then nullif(btrim(p_payload->>'unit_type_other_description'),'')else x.unit_type_other_description end,
plan_override_id=plan_id,timezone=case when p_payload?'timezone'then p_payload->>'timezone'else x.timezone end,
public_discovery_enabled=coalesce((p_payload#>>'{public_profile,discovery_enabled}')::boolean,x.public_discovery_enabled),
public_address_visible=coalesce((p_payload#>>'{public_profile,address_visible}')::boolean,x.public_address_visible),
public_contact_visible=coalesce((p_payload#>>'{public_profile,contact_visible}')::boolean,x.public_contact_visible),
inherit_address=coalesce((p_payload#>>'{inheritance,address}')::boolean,x.inherit_address),
inherit_contact=coalesce((p_payload#>>'{inheritance,contact}')::boolean,x.inherit_contact),
inherit_branding=coalesce((p_payload#>>'{inheritance,branding}')::boolean,x.inherit_branding),
inherit_representatives=coalesce((p_payload#>>'{inheritance,representatives}')::boolean,x.inherit_representatives),
inherit_administrators=coalesce((p_payload#>>'{inheritance,administrators}')::boolean,x.inherit_administrators),
inherit_plan=plan_id is null,management_version=x.management_version+1,updated_at=now()where id=p_unit_id;
perform app_private.persist_unit_children(p_unit_id,actor,p_payload);result:=app_private.unit_form_payload(p_unit_id);
insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,before_json,after_json)
values(actor,'aal2','unit.update','unit',p_unit_id,u.institution_id,'success',jsonb_build_object('management_version',u.management_version),
jsonb_build_object('management_version',result->'management_version'));
insert into app_private.unit_management_command_receipts values(p_request_id,h,actor,'update',p_unit_id,(result->>'management_version')::bigint,now());return result;end$function$;
revoke all on function app_private.update_unit_for_superadmin(p_request_id uuid, p_payload jsonb, p_unit_id uuid, p_expected_version bigint) from public;
revoke all on function app_private.update_unit_for_superadmin(p_request_id uuid, p_payload jsonb, p_unit_id uuid, p_expected_version bigint) from anon, authenticated;

