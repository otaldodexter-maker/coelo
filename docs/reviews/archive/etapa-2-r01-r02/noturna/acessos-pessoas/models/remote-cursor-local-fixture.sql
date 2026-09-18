-- LOCAL FIXTURE ONLY: catalog definitions observed in production, 2026-09-09.
-- No rows, secrets or authorization bypass. Reproduce the exact package preflight.
CREATE OR REPLACE FUNCTION public.superadmin_access_profile_models_cursor(p_query text DEFAULT NULL::text, p_domain text DEFAULT NULL::text, p_status text DEFAULT NULL::text, p_scope text DEFAULT NULL::text, p_limit integer DEFAULT 25, p_after_name text DEFAULT NULL::text, p_after_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$select app_private.superadmin_access_profile_models_cursor(p_query,p_domain,p_status,p_scope,p_limit,p_after_name,p_after_id)$function$;

CREATE OR REPLACE FUNCTION app_private.superadmin_access_profile_models_cursor(p_query text DEFAULT NULL::text, p_domain text DEFAULT NULL::text, p_status text DEFAULT NULL::text, p_scope text DEFAULT NULL::text, p_limit integer DEFAULT 25, p_after_name text DEFAULT NULL::text, p_after_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare size_no int:=least(greatest(coalesce(p_limit,25),1),100);result jsonb;
begin
  if p_domain not in('platform','institution','principal') then raise invalid_parameter_value using message='unsupported profile domain';end if;
  perform app_private.require_profile_authority(p_domain);
  with rows as(
    select template.id,template.domain,template.code,template.name,template.description,
      template.status::text,template.max_scope_kind,template.version,template.is_system,
      case template.domain when 'platform' then (select count(*) from public.access_profile_template_platform_permissions item where item.template_id=template.id)
        when 'institution' then (select count(*) from public.access_profile_template_institution_permissions item where item.template_id=template.id)
        else (select count(*) from public.access_profile_template_principal_capabilities item where item.template_id=template.id) end::int capability_count,
      case template.domain
        when 'platform' then coalesce((select jsonb_agg(jsonb_build_object('code',summary.code,'label',summary.label) order by summary.code)
          from(select permission_record.code,permission_record.screen_label label
            from public.access_profile_template_platform_permissions item
            join public.platform_permissions permission_record on permission_record.id=item.permission_id
            where item.template_id=template.id order by permission_record.code limit 4) summary),'[]'::jsonb)
        when 'institution' then coalesce((select jsonb_agg(jsonb_build_object('code',summary.code,'label',summary.label) order by summary.code)
          from(select permission_record.code,permission_record.screen_label label
            from public.access_profile_template_institution_permissions item
            join public.institution_permissions permission_record on permission_record.id=item.permission_id
            where item.template_id=template.id order by permission_record.code limit 4) summary),'[]'::jsonb)
        else coalesce((select jsonb_agg(jsonb_build_object('code',summary.code,'label',summary.label) order by summary.code)
          from(select capability.code,capability.screen_label label
            from public.access_profile_template_principal_capabilities item
            join public.guardian_permission_capabilities capability on capability.id=item.capability_id
            where item.template_id=template.id order by capability.code limit 4) summary),'[]'::jsonb)
      end capability_summary
    from public.access_profile_templates template
    where template.domain=p_domain and (nullif(btrim(p_query),'') is null or template.name ilike '%'||btrim(p_query)||'%')
      and (p_status is null or template.status::text=p_status) and (p_scope is null or template.max_scope_kind=p_scope)
      and (p_after_name is null or (lower(template.name),template.id)>(lower(p_after_name),p_after_id))
  ),page as(select * from rows order by lower(name),id limit size_no+1)
  select jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(page)-'row_number' order by lower(name),id)
    filter(where row_number<=size_no),'[]'::jsonb),'next_cursor',case when count(*)>size_no then
    (select jsonb_build_object('name',name,'id',id) from page order by lower(name),id offset size_no-1 limit 1) end)
  into result from(select page.*,row_number() over(order by lower(name),id) row_number from page) page;
  return result;
end $function$;

