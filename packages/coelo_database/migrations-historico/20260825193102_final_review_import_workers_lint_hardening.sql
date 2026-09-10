-- Final Revisao Supabase: forward-only runtime/lint hardening.
-- Public signatures and existing privileges are preserved.

CREATE OR REPLACE FUNCTION app_private.superadmin_group_import_apply(p_request_id uuid, p_import_job_id uuid, p_file jsonb, p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
<<vars>>
declare
  actor_person_id uuid;
  job public.import_jobs%rowtype;
  source_row jsonb;
  row_index bigint;
  row_number_value integer;
  institution_value uuid;
  unit_value uuid;
  group_value uuid;
  unit_record public.units%rowtype;
  group_record public.groups%rowtype;
  strategy_value text;
  name_value text;
  type_value text;
  type_other_value text;
  status_value text;
  created_count integer := 0;
  updated_count integer := 0;
  ignored_count integer := 0;
  rejected_count integer := 0;
  final_state public.import_processing_state;
  apply_hash bytea;
begin
  if p_request_id is null or p_import_job_id is null
     or jsonb_typeof(p_file) <> 'object' or jsonb_typeof(p_rows) <> 'array' then
    raise invalid_parameter_value using message = 'invalid import payload';
  end if;
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null
     or not app_private.has_platform_permission('imports.manage')
     or not app_private.has_platform_permission('groups.manage') then
    raise insufficient_privilege using message = 'import and group management required';
  end if;
  if not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message = 'MFA AAL2 required';
  end if;
  if jsonb_array_length(p_rows) < 1 or jsonb_array_length(p_rows) > 5000 then
    raise invalid_parameter_value using message = 'row count outside allowed range';
  end if;
  if p_file - array['storage_path','file_name','mime_type','size_bytes','checksum_sha256'] <> '{}'::jsonb
     or length(coalesce(p_file ->> 'file_name', '')) > 180
     or coalesce((p_file ->> 'size_bytes')::bigint, 0) not between 1 and 5242880
     or p_file ->> 'mime_type' not in (
       'text/csv','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
     )
     or p_file ->> 'storage_path' not like 'imports/' || p_import_job_id::text || '/%'
     or p_file ->> 'checksum_sha256' !~ '^[0-9a-f]{64}$' then
    raise invalid_parameter_value using message = 'invalid import file metadata';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_import_job_id::text, 0));
  apply_hash := extensions.digest(
    convert_to(jsonb_build_object('file', p_file, 'rows', p_rows)::text, 'UTF8'), 'sha256'
  );
  select * into job from public.import_jobs where id = p_import_job_id for update;
  if job.id is null or job.target_table <> 'groups' or job.target_domain <> 'superadmin' then
    raise no_data_found using message = 'group import job not found';
  end if;
  if job.created_by <> actor_person_id then
    raise insufficient_privilege using message = 'import job outside actor scope';
  end if;
  if job.apply_request_id is not null then
    if job.apply_request_id <> p_request_id or job.apply_request_hash <> apply_hash then
      raise invalid_parameter_value using message = 'import already applied with another request';
    end if;
    return app_private.superadmin_import_payload(job.id);
  end if;
  if job.processing_state in ('SUCESSO','REJEICAO') then
    return app_private.superadmin_import_payload(job.id);
  end if;

  update public.import_jobs set
    apply_request_id = p_request_id,
    apply_request_hash = apply_hash,
    processing_state = 'PROCESSANDO',
    status = 'active',
    started_at = coalesce(started_at, now()),
    summary = summary || jsonb_build_object('progress', 1),
    updated_at = now()
  where id = job.id;
  delete from public.import_errors where import_job_id = job.id;
  delete from public.import_rows where import_job_id = job.id;
  strategy_value := coalesce(job.summary ->> 'strategy', 'createOnly');
  if strategy_value not in ('createOnly','createAndUpdate') then
    raise invalid_parameter_value using message = 'invalid import strategy';
  end if;

  for source_row, row_index in
    select item.value, item.ordinality
    from jsonb_array_elements(p_rows) with ordinality as item(value, ordinality)
  loop
    begin
      if jsonb_typeof(source_row) <> 'object'
         or source_row - array[
           'row_number','id','institution_id','unit_id','name','group_type',
           'group_type_other_text','status'
         ] <> '{}'::jsonb then
        raise invalid_parameter_value using message = 'unknown import column';
      end if;
      row_number_value := coalesce(nullif(source_row ->> 'row_number', '')::integer, row_index::integer + 1);
      if row_number_value < 2 then
        raise invalid_parameter_value using message = 'invalid row number';
      end if;
      institution_value := nullif(source_row ->> 'institution_id', '')::uuid;
      unit_value := nullif(source_row ->> 'unit_id', '')::uuid;
      group_value := nullif(source_row ->> 'id', '')::uuid;
      name_value := nullif(btrim(source_row ->> 'name'), '');
      type_value := lower(coalesce(nullif(btrim(source_row ->> 'group_type'), ''), 'class'));
      type_other_value := nullif(btrim(source_row ->> 'group_type_other_text'), '');
      status_value := lower(coalesce(nullif(btrim(source_row ->> 'status'), ''), 'active'));
      if institution_value is null or unit_value is null or name_value is null
         or length(name_value) > 160 or length(type_value) > 80
         or length(coalesce(type_other_value, '')) > 160
         or status_value not in ('draft','active','inactive','suspended','archived')
         or (type_value = 'other' and type_other_value is null) then
        raise invalid_parameter_value using message = 'invalid group fields';
      end if;
      select * into unit_record from public.units
      where id = unit_value and institution_id = institution_value;
      if unit_record.id is null then
        raise foreign_key_violation using message = 'unit outside institution';
      end if;

      if group_value is not null then
        select * into group_record from public.groups where id = group_value for update;
        if group_record.id is null then
          raise no_data_found using message = 'group not found';
        end if;
        if group_record.institution_id <> institution_value or group_record.unit_id <> unit_value then
          raise insufficient_privilege using message = 'group hierarchy cannot change';
        end if;
        if strategy_value = 'createOnly' then
          ignored_count := ignored_count + 1;
        else
          update public.groups set
            name = name_value,
            group_type = type_value,
            group_type_other_text = type_other_value,
            status = status_value::public.record_status,
            management_version = management_version + 1,
            updated_at = now()
          where id = group_record.id;
          updated_count := updated_count + 1;
        end if;
      else
        insert into public.groups(
          institution_id, unit_id, name, group_type, group_type_other_text, status,
          inherit_appearance, inherit_access, inherit_activities, created_at, updated_at
        ) values (
          institution_value, unit_value, name_value, type_value, type_other_value,
          status_value::public.record_status, true, true, true, now(), now()
        ) returning id into group_value;
        created_count := created_count + 1;
      end if;
      insert into public.import_rows(import_job_id, row_number, payload_json, status)
      values (job.id, row_number_value, source_row, 'active');
    exception when others then
      rejected_count := rejected_count + 1;
      insert into public.import_rows(import_job_id, row_number, payload_json, status, error_code)
      values (
        job.id, coalesce(row_number_value, row_index::integer + 1), source_row,
        'inactive', sqlstate
      ) on conflict (import_job_id, row_number) do update set
        payload_json = excluded.payload_json, status = excluded.status, error_code = excluded.error_code;
      insert into public.import_errors(
        import_job_id, row_number, column_name, error_code, message
      ) values (
        job.id, coalesce(row_number_value, row_index::integer + 1), null,
        sqlstate, 'Linha rejeitada pela validacao do backend.'
      );
    end;
    row_number_value := null;
  end loop;

  final_state := case when rejected_count > 0 then 'REJEICAO'::public.import_processing_state
                      else 'SUCESSO'::public.import_processing_state end;
  insert into public.import_files(
    import_job_id, storage_path, file_name, mime_type, size_bytes,
    checksum_sha256, source_locale, expires_at
  ) values (
    job.id, p_file ->> 'storage_path', p_file ->> 'file_name', p_file ->> 'mime_type',
    (p_file ->> 'size_bytes')::bigint, p_file ->> 'checksum_sha256', job.source_locale,
    now() + interval '24 hours'
  );
  update public.import_results set
    created_count = vars.created_count,
    updated_count = vars.updated_count,
    ignored_count = vars.ignored_count,
    rejected_count = vars.rejected_count,
    completed_at = now()
  where import_job_id = job.id;
  update public.import_jobs set
    processing_state = final_state,
    finished_at = now(),
    summary = summary || jsonb_build_object(
      'progress', 100, 'row_count', jsonb_array_length(p_rows),
      'storage_path', p_file ->> 'storage_path', 'expires_at', now() + interval '24 hours'
    ),
    updated_at = now()
  where id = job.id;
  update app_private.import_processing_queue set
    state = final_state, locked_at = null, locked_by = null, updated_at = now()
  where import_job_id = job.id;
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    actor_person_id, auth.jwt() ->> 'aal', 'group.import.complete', 'import_job', job.id,
    job.institution_id, 'success', jsonb_build_object(
      'state', final_state, 'created', created_count, 'updated', updated_count,
      'ignored', ignored_count, 'rejected', rejected_count
    )
  );
  return app_private.superadmin_import_payload(job.id);
end $function$;

CREATE OR REPLACE FUNCTION app_private.superadmin_activity_import_apply(p_request_id uuid, p_import_job_id uuid, p_file jsonb, p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
<<vars>>
declare job public.import_jobs%rowtype; source_row jsonb; row_index bigint;
 row_number_value integer; target_activity_id uuid; target_institution_id uuid;
 target_taxonomy_id uuid; target_origin_unit_id uuid; selected_unit_ids uuid[];
 existing public.activity_definitions%rowtype; created_count integer:=0;
 updated_count integer:=0; rejected_count integer:=0; apply_hash bytea;
begin
 if p_request_id is null or p_import_job_id is null
    or jsonb_typeof(p_file)<>'object' or jsonb_typeof(p_rows)<>'array'
    or jsonb_array_length(p_rows) not between 1 and 5000 then
  raise invalid_parameter_value using message='invalid import payload';
 end if;
 if p_file-array['storage_path','file_name','mime_type','size_bytes','checksum_sha256']
      <>'{}'::jsonb
    or p_file->>'storage_path' not like 'imports/'||p_import_job_id::text||'/%'
    or length(coalesce(p_file->>'file_name',''))>180
    or coalesce((p_file->>'size_bytes')::bigint,0) not between 1 and 5242880
    or p_file->>'mime_type' not in (
      'text/csv','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    or p_file->>'checksum_sha256' !~ '^[0-9a-f]{64}$' then
  raise invalid_parameter_value using message='invalid import file metadata';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(p_import_job_id::text,0));
 apply_hash:=extensions.digest(convert_to(
   jsonb_build_object('file',p_file,'rows',p_rows)::text,'UTF8'),'sha256');
 select * into job from public.import_jobs job_record
  where job_record.id=p_import_job_id for update;
 if job.id is null or job.target_domain<>'activities'
    or job.target_table<>'activity_definitions'
    or job.summary->>'operation'<>'import' then
  raise no_data_found using message='activity import job not found';
 end if;
 if job.apply_request_id is not null then
  if job.apply_request_id<>p_request_id or job.apply_request_hash<>apply_hash then
   raise invalid_parameter_value using message='import already applied';
  end if;
  return jsonb_build_object('job_id',job.id,'state',job.processing_state,'summary',job.summary);
 end if;
 update public.import_jobs set apply_request_id=p_request_id,
  apply_request_hash=apply_hash,processing_state='PROCESSANDO',status='active',
  started_at=coalesce(started_at,now()),
  summary=summary||jsonb_build_object('progress',1),updated_at=now()
 where id=job.id;
 delete from public.import_errors where import_job_id=job.id;
 delete from public.import_rows where import_job_id=job.id;

 for source_row,row_index in
  select value,ordinality from jsonb_array_elements(p_rows)
   with ordinality item(value,ordinality)
 loop
  begin
   row_number_value:=coalesce(nullif(source_row->>'row_number','')::integer,
     row_index::integer+1);
   if jsonb_typeof(source_row)<>'object'
      or source_row-array[
       'row_number','id','institution_id','name','description','handle_stem',
       'origin_scope_kind','origin_unit_id','governance_kind','status',
       'taxonomy_code','taxonomy_other_description','unit_ids'
      ]<>'{}'::jsonb or row_number_value<2 then
    raise invalid_parameter_value using message='unknown import column';
   end if;
   target_activity_id:=nullif(source_row->>'id','')::uuid;
   target_institution_id:=nullif(source_row->>'institution_id','')::uuid;
   target_origin_unit_id:=nullif(source_row->>'origin_unit_id','')::uuid;
   select taxonomy.id into target_taxonomy_id from public.activity_taxonomies taxonomy
    where taxonomy.code=source_row->>'taxonomy_code' and taxonomy.status='active';
   if target_institution_id is null or target_taxonomy_id is null
      or nullif(btrim(source_row->>'name'),'') is null
      or length(btrim(source_row->>'name'))>160
      or coalesce(source_row->>'origin_scope_kind','institution') not in ('institution','unit')
      or coalesce(source_row->>'governance_kind','optional') not in ('optional','mandatory')
      or coalesce(source_row->>'status','draft') not in (
       'draft','active','inactive','suspended','archived')
      or not exists(select 1 from public.institutions institution
       where institution.id=target_institution_id) then
    raise invalid_parameter_value using message='invalid activity fields';
   end if;
   if coalesce(source_row->>'origin_scope_kind','institution')='unit'
      and not exists(select 1 from public.units unit
       where unit.id=target_origin_unit_id
        and unit.institution_id=target_institution_id) then
    raise foreign_key_violation using message='origin unit outside institution';
   end if;
   if exists(select 1 from public.activity_taxonomies taxonomy
      where taxonomy.id=target_taxonomy_id and taxonomy.code='outros')
      and nullif(btrim(source_row->>'taxonomy_other_description'),'') is null then
    raise invalid_parameter_value using message='other taxonomy description required';
   end if;

   if target_activity_id is null then
    target_activity_id:=gen_random_uuid();
    insert into public.activity_definitions(
     id,institution_id,name,description,handle_stem,origin_scope_kind,origin_unit_id,
     governance_kind,status,taxonomy_id,taxonomy_other_description,identity_mode,
     identity_initials,identity_color,created_by_person_id
    ) values(
     target_activity_id,target_institution_id,btrim(source_row->>'name'),
     nullif(btrim(source_row->>'description'),''),
     coalesce(nullif(app_private.activity_slugify(coalesce(
      nullif(source_row->>'handle_stem',''),source_row->>'name')),''),'atividade')||'-'||left(target_activity_id::text,6),
     coalesce(source_row->>'origin_scope_kind','institution')::public.activity_origin_scope,
     target_origin_unit_id,coalesce(source_row->>'governance_kind','optional'),
     coalesce(source_row->>'status','draft')::public.record_status,target_taxonomy_id,
     nullif(btrim(source_row->>'taxonomy_other_description'),''),
     'initials',upper(left(regexp_replace(source_row->>'name','[^[:alnum:]]','','g'),2)),
     '#D63C00',job.created_by);
    created_count:=created_count+1;
   else
    select * into existing from public.activity_definitions activity
     where activity.id=target_activity_id for update;
    if existing.id is null then raise no_data_found using message='activity not found'; end if;
    if existing.institution_id<>target_institution_id then
     raise insufficient_privilege using message='activity outside institution';
    end if;
    update public.activity_definitions set name=btrim(source_row->>'name'),
     description=nullif(btrim(source_row->>'description'),''),
     handle_stem=coalesce(nullif(app_private.activity_slugify(coalesce(
      nullif(source_row->>'handle_stem',''),source_row->>'name')),''),
      'atividade-'||left(target_activity_id::text,6)),
     origin_scope_kind=coalesce(source_row->>'origin_scope_kind','institution')::public.activity_origin_scope,
     origin_unit_id=target_origin_unit_id,
     governance_kind=coalesce(source_row->>'governance_kind','optional'),
     status=coalesce(source_row->>'status','draft')::public.record_status,
     taxonomy_id=target_taxonomy_id,
     taxonomy_other_description=nullif(btrim(source_row->>'taxonomy_other_description'),''),
     management_version=management_version+1,updated_at=now()
    where id=target_activity_id;
    updated_count:=updated_count+1;
   end if;
   if source_row?'unit_ids' then
    select coalesce(array_agg(distinct value::uuid),'{}'::uuid[]) into selected_unit_ids
     from jsonb_array_elements_text(source_row->'unit_ids');
    if (select count(*) from public.units unit
      where unit.id=any(selected_unit_ids)
       and unit.institution_id=target_institution_id)<>cardinality(selected_unit_ids) then
     raise foreign_key_violation using message='unit outside institution';
    end if;
    insert into public.activity_unit_links(
     activity_id,institution_id,unit_id,linked_by_person_id,status
    ) select target_activity_id,target_institution_id,unit_id,job.created_by,'active'
      from unnest(selected_unit_ids) unit_id
    on conflict(activity_id,unit_id) do update set status='active',ends_at=null,updated_at=now();
   end if;
   insert into public.import_rows(import_job_id,row_number,payload_json,status)
    values(job.id,row_number_value,source_row,'active');
  exception when others then
   rejected_count:=rejected_count+1;
   insert into public.import_rows(
    import_job_id,row_number,payload_json,status,error_code
   ) values(job.id,coalesce(row_number_value,row_index::integer+1),
    source_row,'inactive',sqlstate)
   on conflict(import_job_id,row_number) do update set payload_json=excluded.payload_json,
    status=excluded.status,error_code=excluded.error_code;
   insert into public.import_errors(
    import_job_id,row_number,error_code,message
   ) values(job.id,coalesce(row_number_value,row_index::integer+1),sqlstate,
    'Linha rejeitada pela validação do backend.');
  end;
  row_number_value:=null;
 end loop;

 insert into public.import_files(
  import_job_id,storage_path,file_name,mime_type,size_bytes,checksum_sha256,expires_at
 ) values(job.id,p_file->>'storage_path',p_file->>'file_name',p_file->>'mime_type',
  (p_file->>'size_bytes')::bigint,p_file->>'checksum_sha256',now()+interval '24 hours');
 update public.import_results set created_count=vars.created_count,updated_count=vars.updated_count,
  rejected_count=vars.rejected_count,completed_at=now() where import_job_id=job.id;
 update public.import_jobs set
  processing_state=case when rejected_count>0 then 'REJEICAO'::public.import_processing_state
   else 'SUCESSO'::public.import_processing_state end,
  finished_at=now(),summary=summary||jsonb_build_object(
   'progress',100,'created',created_count,'updated',updated_count,
   'rejected',rejected_count),updated_at=now() where id=job.id;
 update app_private.import_processing_queue set
  state=case when rejected_count>0 then 'REJEICAO'::public.import_processing_state
   else 'SUCESSO'::public.import_processing_state end,
  locked_at=null,locked_by=null,updated_at=now() where import_job_id=job.id;
 insert into audit.audit_logs(
  actor_person_id,action_code,object_type,object_id,outcome,after_json
 ) values(job.created_by,'activity.import.complete','import_job',job.id,'success',
  jsonb_build_object('created',created_count,'updated',updated_count,'rejected',rejected_count));
 return jsonb_build_object('job_id',job.id,
  'state',case when rejected_count>0 then 'REJEICAO' else 'SUCESSO' end,
  'created',created_count,'updated',updated_count,'rejected',rejected_count);
end $function$;
