-- LOCAL SNAPSHOT ONLY, NOT A PRODUCTION MIGRATION. Never execute remotely.
-- Provenance: 25cd74a9, catalog read 2026-09-08T05:28:22Z, PG170006.
-- Exact reviewed remote definition is JSON-escaped to preserve mixed EOL bytes.
-- Eng1 must supply the opt-in in the same transaction through a nominal profile.
begin;
set local search_path=public,pg_catalog;
do $local_snapshot$
declare
  snapshot jsonb := $snapshot${
  "source": "Supabase production catalog read-only 2026-09-08T05:28:22Z; authorized local replay snapshot only",
  "signature": "app_private.superadmin_get_activity_form_options(uuid)",
  "definition_md5_raw": "65fe6408f0f2c6b0c1c9d71a809f2d80",
  "definition_md5_lf": "516a06602a96073317e495dbb9d5b040",
  "source_md5_raw": "1f40c83ab7cbd772a9983a5e61138eb0",
  "source_md5_lf": "08697eaa5c84dc2938b0c1ffaf6de056",
  "definition": "CREATE OR REPLACE FUNCTION app_private.superadmin_get_activity_form_options(p_institution_id uuid)\n RETURNS jsonb\n LANGUAGE plpgsql\n STABLE SECURITY DEFINER\n SET search_path TO ''\nAS $function$\r\ndeclare result jsonb;\r\nbegin\r\n if (select auth.uid()) is null or\r\n    not app_private.has_platform_permission('activities.read') then\r\n  raise insufficient_privilege using message='activities.read required';\r\n end if;\r\n if p_institution_id is not null and not exists(select 1 from public.institutions institution\r\n   where institution.id=p_institution_id) then\r\n  raise no_data_found using message='institution not found';\r\n end if;\r\n select jsonb_build_object(\r\n  'institutions',coalesce((select jsonb_agg(jsonb_build_object(\r\n    'id',institution.id,'name',institution.public_name) order by institution.public_name)\r\n    from public.institutions institution\r\n    where p_institution_id is null or institution.id=p_institution_id),'[]'::jsonb),\r\n  'units',coalesce((select jsonb_agg(jsonb_build_object(\r\n    'id',unit.id,'institution_id',unit.institution_id,'name',unit.name) order by unit.name)\r\n    from public.units unit where (p_institution_id is null\r\n      or unit.institution_id=p_institution_id) and unit.status<>'archived'),'[]'::jsonb),\r\n  'locations',coalesce((select jsonb_agg(jsonb_build_object(\r\n    'id',location.id,'unit_id',location.unit_id,'name',location.name) order by location.name)\r\n    from public.activity_locations location where (p_institution_id is null\r\n      or location.institution_id=p_institution_id) and location.status='active'),'[]'::jsonb),\r\n  'groups',coalesce((select jsonb_agg(jsonb_build_object(\r\n    'id',group_record.id,'unit_id',group_record.unit_id,'name',group_record.name,\r\n    'participant_count',(select count(*) from public.child_group_links child_link\r\n      where child_link.group_id=group_record.id and child_link.status='active'))\r\n    order by group_record.name) from public.groups group_record\r\n    where (p_institution_id is null or group_record.institution_id=p_institution_id)\r\n     and group_record.status<>'archived'),'[]'::jsonb),\r\n  'professionals',coalesce((select jsonb_agg(jsonb_build_object(\r\n    'membership_id',membership.id,'person_id',person.id,'name',person.display_name,\r\n    'role',membership.role_code) order by person.display_name)\r\n    from public.institution_memberships membership\r\n    join public.people person on person.id=membership.person_id\r\n    where (p_institution_id is null or membership.institution_id=p_institution_id)\r\n     and membership.status='active' and membership.revoked_at is null\r\n     and person.person_type<>'child' and person.status='active'),'[]'::jsonb),\r\n  'taxonomy',coalesce((select jsonb_agg(jsonb_build_object(\r\n    'id',category.id,'label',category.name,'is_other',category.code='outros',\r\n    'subtypes',coalesce((select jsonb_agg(jsonb_build_object(\r\n      'id',subtype.id,'label',subtype.name) order by subtype.sort_order,subtype.name)\r\n      from public.activity_taxonomies subtype where subtype.parent_id=category.id\r\n       and subtype.status='active'),'[]'::jsonb))\r\n    order by category.sort_order,category.name)\r\n    from public.activity_taxonomies category\r\n    where category.taxonomy_kind='category' and category.status='active'),'[]'::jsonb),\r\n  'templates',coalesce((select jsonb_agg(jsonb_build_object(\n    'id',template.id,'name',template.name,\n    'description',template.description,\n    'scope_kind',template.scope_kind,\n    'institution_id',template.institution_id,\n    'governance_kind',template.governance_kind,\n    'taxonomy_id',coalesce(taxonomy.parent_id,taxonomy.id),\n    'subtype_id',case when taxonomy.taxonomy_kind='subtype' then taxonomy.id end)\r\n    order by template.name)\r\n    from public.activity_templates template\r\n    join public.activity_taxonomies taxonomy on taxonomy.id=template.taxonomy_id\r\n    where template.status='active' and (template.scope_kind='platform'\r\n      or template.institution_id=p_institution_id)),'[]'::jsonb)\r\n ) into result;\r\n return result;\r\nend $function$\n"
}$snapshot$::jsonb;
  proc_record record;
begin
  if current_user <> 'postgres' or current_setting('coelo.local_replay',true)
    is distinct from 'location-catalog-v2-remote-options-snapshot' then
    raise insufficient_privilege using message='nominal local snapshot opt-in required';
  end if;
  select p.* into proc_record from pg_proc p where p.oid=to_regprocedure(
    'app_private.superadmin_get_activity_form_options(uuid)');
  if proc_record.oid is null then
    raise object_not_in_prerequisite_state using message='local options baseline missing';
  end if;
  if md5(pg_get_functiondef(proc_record.oid)) <> '70700ddc38d42df4fae75765b7ff2617'
    or md5(replace(pg_get_functiondef(proc_record.oid),E'\r\n',E'\n')) <> 'b951e603ef34b7d26597356a16eb6d06'
    or pg_get_userbyid(proc_record.proowner) <> 'postgres'
    or not proc_record.prosecdef or proc_record.provolatile <> 's'
    or proc_record.proconfig is distinct from array['search_path=""']::text[]
    or exists(select 1 from aclexplode(coalesce(proc_record.proacl,acldefault('f',proc_record.proowner))) a
      where a.grantee <> proc_record.proowner) then
    raise object_not_in_prerequisite_state using message='local options baseline drift';
  end if;
  if snapshot->>'signature' <> 'app_private.superadmin_get_activity_form_options(uuid)'
    or md5(snapshot->>'definition') <> '65fe6408f0f2c6b0c1c9d71a809f2d80'
    or md5(replace(snapshot->>'definition',E'\r\n',E'\n')) <> '516a06602a96073317e495dbb9d5b040' then
    raise object_not_in_prerequisite_state using message='local remote snapshot bytes drift';
  end if;
  execute (snapshot->>'definition');
  if md5(pg_get_functiondef(proc_record.oid)) <> '65fe6408f0f2c6b0c1c9d71a809f2d80'
    or (select md5(prosrc) from pg_proc where oid=proc_record.oid) <> '1f40c83ab7cbd772a9983a5e61138eb0'
    or (select md5(replace(prosrc,E'\r\n',E'\n')) from pg_proc where oid=proc_record.oid) <> '08697eaa5c84dc2938b0c1ffaf6de056'
    or (select proacl is distinct from proc_record.proacl or proowner <> proc_record.proowner
      or not prosecdef or provolatile <> 's' or proconfig is distinct from proc_record.proconfig
      from pg_proc where oid=proc_record.oid) then
    raise object_not_in_prerequisite_state using message='local remote snapshot postcondition drift';
  end if;
end
$local_snapshot$;
commit;
