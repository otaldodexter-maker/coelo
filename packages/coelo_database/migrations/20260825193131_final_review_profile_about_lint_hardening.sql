-- Final Revisao Supabase: forward-only runtime/lint hardening.
-- Public signatures and existing privileges are preserved.

CREATE OR REPLACE FUNCTION public.save_profile_about(p_subject_type text, p_subject_id uuid, p_payload jsonb, p_expected_version bigint, p_request_id uuid, p_official_updates jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
<<vars>>
declare actor uuid:=app_private.current_person_id(); p public.profile_about_pages; inst uuid; unit_id uuid; group_id uuid; activity_id uuid; item jsonb; next_version bigint; result jsonb; official jsonb:='[]'; stored_hash text; request_hash text:=md5(p_payload::text||p_official_updates::text);
begin
 if actor is null then raise insufficient_privilege; end if;
 if p_request_id is null or jsonb_typeof(p_payload)<>'object' or jsonb_typeof(coalesce(p_payload->'fields','[]'))<>'array' or jsonb_typeof(coalesce(p_payload->'sections','[]'))<>'array' then raise check_violation; end if;
 if p_subject_type='person' then raise insufficient_privilege using message='person About is not released'; end if;
 select result_json,profile_about_command_receipts.request_hash into result,stored_hash from app_private.profile_about_command_receipts where request_id=p_request_id and actor_person_id=actor;
 if result is not null then
  if stored_hash<>request_hash then raise unique_violation using message='request_id reused with different payload'; end if;
  return result;
 end if;
 if p_subject_type='institution' then select id into inst from public.institutions where id=p_subject_id;
 elsif p_subject_type='unit' then select unit_row.institution_id,unit_row.id into inst,unit_id from public.units unit_row where unit_row.id=p_subject_id;
 elsif p_subject_type='group' then select group_row.institution_id,group_row.unit_id,group_row.id into inst,unit_id,group_id from public.groups group_row where group_row.id=p_subject_id;
 elsif p_subject_type='activity' then select institution_id,id into inst,activity_id from public.activity_definitions where id=p_subject_id;
 elsif p_subject_type='person' then select m.institution_id into inst from public.institution_memberships m where m.person_id=p_subject_id and m.status='active' and m.revoked_at is null order by m.created_at limit 1;
 end if;
 if inst is null or not app_private.profile_about_can(inst,'profiles.about.manage',unit_id,group_id,activity_id) then raise insufficient_privilege; end if;
 if coalesce(p_payload->>'state','draft')='published' and not app_private.profile_about_can(inst,'profiles.about.publish',unit_id,group_id,activity_id) then
  raise insufficient_privilege using message='profiles.about.publish required';
 end if;
 p:=app_private.profile_about_page_for(p_subject_type,p_subject_id);
 if p.id is null then
  if p_expected_version<>0 then raise serialization_failure using message='profile about version conflict'; end if;
  insert into public.profile_about_pages(institution_id,subject_type,institution_subject_id,unit_subject_id,group_subject_id,activity_subject_id,person_subject_id,created_by_person_id,updated_by_person_id)
  values(inst,p_subject_type,case when p_subject_type='institution' then p_subject_id end,unit_id,group_id,activity_id,case when p_subject_type='person' then p_subject_id end,actor,actor) returning * into p;
 elsif p.version<>p_expected_version then raise serialization_failure using message='profile about version conflict'; end if;
 next_version:=p.version+1;
 delete from public.profile_about_structured_fields where page_id=p.id;
 for item in select value from jsonb_array_elements(coalesce(p_payload->'fields','[]')) loop
  if not app_private.profile_about_allowed_field(p_subject_type,item->>'key') then raise check_violation using message='field not allowed for subject'; end if;
  insert into public.profile_about_structured_fields(page_id,field_key,value,latitude,longitude,visibility,origin,source_label,revision,created_by_person_id,updated_by_person_id)
  values(p.id,item->>'key',item->>'value',(item->>'latitude')::double precision,(item->>'longitude')::double precision,coalesce(item->>'visibility','profile_access'),coalesce(item->>'origin','manual'),item->>'source_label',next_version,actor,actor);
 end loop;
 delete from public.profile_about_sections where page_id=p.id;
 for item in select value from jsonb_array_elements(coalesce(p_payload->'sections','[]')) loop
  insert into public.profile_about_sections(id,page_id,section_type,title,body,items,position,visibility,state,origin,revision,created_by_person_id,updated_by_person_id)
  values(case when coalesce(item->>'id','')~*'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then (item->>'id')::uuid else gen_random_uuid() end,p.id,item->>'type',nullif(item->>'title',''),nullif(item->>'body',''),coalesce(array(select jsonb_array_elements_text(coalesce(item->'items','[]'))),'{}'),(item->>'position')::integer,coalesce(item->>'visibility','profile_access'),coalesce(item->>'state','draft'),coalesce(item->>'origin','manual'),next_version,actor,actor);
 end loop;
 update public.profile_about_pages set version=next_version,state=coalesce(p_payload->>'state',state),updated_by_person_id=actor,updated_at=now(),published_at=case when p_payload->>'state'='published' then now() else published_at end where id=p.id;
 insert into public.profile_about_revisions(page_id,version,actor_person_id,command_kind,snapshot) values(p.id,next_version,actor,'save',p_payload);
 if jsonb_array_length(coalesce(p_official_updates,'[]'))>0 then
  if not app_private.profile_about_can(inst,'profiles.about.update_official_data',unit_id,group_id,activity_id) then raise insufficient_privilege using message='profiles.about.update_official_data required'; end if;
  for item in select value from jsonb_array_elements(p_official_updates) loop
   begin
    if p_subject_type='institution' and item->>'key' in('email','phone','mobile','website') then
     insert into public.institution_contacts(institution_id,email,phone,mobile_phone,website_url,status)
     values(inst,case when item->>'key'='email' then item->>'value' end,case when item->>'key'='phone' then item->>'value' end,case when item->>'key'='mobile' then item->>'value' end,case when item->>'key'='website' then item->>'value' end,'active')
     on conflict(institution_id) do update set email=coalesce(excluded.email,institution_contacts.email),phone=coalesce(excluded.phone,institution_contacts.phone),mobile_phone=coalesce(excluded.mobile_phone,institution_contacts.mobile_phone),website_url=coalesce(excluded.website_url,institution_contacts.website_url),updated_at=now();
    elsif p_subject_type='unit' and item->>'key' in('email','phone','mobile') then
     insert into public.unit_contacts(unit_id,email,phone,mobile_phone,status) values(vars.unit_id,case when item->>'key'='email' then item->>'value' end,case when item->>'key'='phone' then item->>'value' end,case when item->>'key'='mobile' then item->>'value' end,'active')
     on conflict on constraint unit_contacts_pkey do update set email=coalesce(excluded.email,unit_contacts.email),phone=coalesce(excluded.phone,unit_contacts.phone),mobile_phone=coalesce(excluded.mobile_phone,unit_contacts.mobile_phone),updated_at=now();
    else raise feature_not_supported using message='official field has no approved mapping'; end if;
    official:=official||jsonb_build_array(jsonb_build_object('key',item->>'key','status','updated'));
   exception when others then official:=official||jsonb_build_array(jsonb_build_object('key',item->>'key','status','failed','message',sqlerrm)); end;
  end loop;
 end if;
 result:=jsonb_build_object('page_id',p.id,'version',next_version,'about','saved','official',official);
 insert into app_private.profile_about_command_receipts values(p_request_id,actor,request_hash,result,now());
 insert into audit.profile_about_commands(request_id,actor_person_id,page_id,command_kind,destinations) values(p_request_id,actor,p.id,'save',jsonb_build_object('about','saved','official',official));
 return result;
end$function$;
