-- Standalone closure for the three private helpers present in the remote schema.
-- Public wrappers retain their reviewed least-privilege ACLs.

do $$
declare v_signature text; v_oid oid;
begin
  foreach v_signature in array array[
    'app_private.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)',
    'app_private.superadmin_materialize_unit_export_from_edge(uuid)',
    'app_private.superadmin_unit_export_page_v2(uuid,bigint,integer)'
  ] loop
    v_oid:=pg_catalog.to_regprocedure(v_signature);
    if v_oid is null then
      raise object_not_in_prerequisite_state using message='missing expected private import/export function: '||v_signature;
    end if;
    if not exists(select 1 from pg_catalog.pg_proc p where p.oid=v_oid and p.proowner='postgres'::regrole and p.prosecdef and coalesce(p.proconfig,'{}'::text[]) @> array['search_path=""']::text[]) then
      raise object_not_in_prerequisite_state using message='unexpected owner/security/search_path for: '||v_signature;
    end if;
  end loop;
  if not (
    has_function_privilege('service_role','public.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)'::regprocedure,'EXECUTE')
    and not has_function_privilege('authenticated','public.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)'::regprocedure,'EXECUTE')
    and has_function_privilege('service_role','public.superadmin_materialize_unit_export_from_edge(uuid)'::regprocedure,'EXECUTE')
    and not has_function_privilege('authenticated','public.superadmin_materialize_unit_export_from_edge(uuid)'::regprocedure,'EXECUTE')
    and has_function_privilege('authenticated','public.superadmin_unit_export_page_v2(uuid,bigint,integer)'::regprocedure,'EXECUTE')
    and not has_function_privilege('anon','public.superadmin_unit_export_page_v2(uuid,bigint,integer)'::regprocedure,'EXECUTE')
  ) then
    raise object_not_in_prerequisite_state using message='unexpected public import/export gateway ACL';
  end if;
end $$;

revoke all on function app_private.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text) from public,anon,authenticated,service_role;
revoke all on function app_private.superadmin_materialize_unit_export_from_edge(uuid) from public,anon,authenticated,service_role;
revoke all on function app_private.superadmin_unit_export_page_v2(uuid,bigint,integer) from public,anon,authenticated,service_role;

do $$
declare v_signature text; v_role text; v_oid oid;
begin
  foreach v_signature in array array[
    'app_private.superadmin_preview_unit_import_from_edge(uuid,uuid,jsonb,jsonb,text,bigint,text,text)',
    'app_private.superadmin_materialize_unit_export_from_edge(uuid)',
    'app_private.superadmin_unit_export_page_v2(uuid,bigint,integer)'
  ] loop
    v_oid:=pg_catalog.to_regprocedure(v_signature);
    foreach v_role in array array['public','anon','authenticated','service_role'] loop
      if pg_catalog.has_function_privilege(v_role,v_oid,'EXECUTE') then
        raise object_not_in_prerequisite_state using message=format('EXECUTE remains for role %s on %s',v_role,v_signature);
      end if;
    end loop;
  end loop;
end $$;
