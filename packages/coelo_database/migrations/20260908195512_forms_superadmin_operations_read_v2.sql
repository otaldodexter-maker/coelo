-- C02 I010: internal operational reads; no global People impersonation.
-- Hierarchy/people remain a separate gate until branch/context granularity is
-- represented by their contract. This candidate implements four safe reads.
begin;

create function app_private.superadmin_forms_operations_read_v2(p_operation text,p_query jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  ctx app_private.superadmin_internal_context; final_ctx app_private.superadmin_internal_context;
  capability text:=case p_operation when 'monitor' then 'forms.monitor'
    when 'file_jobs' then 'forms.responses.export' else 'forms.responses.read' end;
  action_code text:='superadmin.forms.'||p_operation;
  correlation uuid:=gen_random_uuid(); error_code text; result jsonb;
  allowed text[]; field_name text; page_limit integer:=25;
  form_row public.forms; response_row public.form_responses; version_row public.form_versions;
  v_form_id uuid; v_response_id uuid; v_application_id uuid; v_occurrence_id uuid; v_scope_id uuid;
  v_cursor_id uuid; cursor_time timestamptz; cursor_field text;
  starts_on date; ends_on date; v_scope_kind text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context(capability);
    if ctx.scope_kind is null or ctx.scope_kind not in ('platform','institution')
      or (ctx.scope_kind='institution' and ctx.scope_institution_id is null)
      or ctx.aal is null or ctx.aal not in ('aal1','aal2') then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    allowed:=case p_operation
      when 'monitor' then array['form_id','application_id','occurrence_id','starts_on_or_after','ends_on_or_before','scope_id']
      when 'responses' then array['form_id','occurrence_id','cursor_submitted_at','cursor_id','limit']
      when 'response_detail' then array['response_id','form_id']
      when 'file_jobs' then array['form_id','cursor_created_at','cursor_id','limit'] end;
    if allowed is null or p_query is null or jsonb_typeof(p_query)<>'object'
      or octet_length(p_query::text)>16384 or p_query-allowed<>'{}'::jsonb then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    foreach field_name in array allowed loop
      if field_name='limit' then continue; end if;
      if p_query?field_name and p_query->field_name<>'null'::jsonb
        and jsonb_typeof(p_query->field_name)<>'string' then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
    end loop;
    foreach field_name in array array['form_id','response_id','application_id','occurrence_id','scope_id','cursor_id'] loop
      if p_query->>field_name is not null and p_query->>field_name!~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
    end loop;
    if p_query?'limit' then
      if jsonb_typeof(p_query->'limit') is distinct from 'number' or p_query->>'limit'!~'^[0-9]{1,3}$' then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
      page_limit:=(p_query->>'limit')::integer;
      if page_limit not between 1 and 100 then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
    end if;
    v_form_id:=(p_query->>'form_id')::uuid; v_response_id:=(p_query->>'response_id')::uuid;
    v_application_id:=(p_query->>'application_id')::uuid; v_occurrence_id:=(p_query->>'occurrence_id')::uuid;
    v_scope_id:=(p_query->>'scope_id')::uuid; v_cursor_id:=(p_query->>'cursor_id')::uuid;
    if p_operation='response_detail' then
      if v_response_id is null then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
      select r.* into response_row from public.form_responses r
        join public.forms f on f.id=r.form_id and f.institution_id=r.institution_id
        join public.institutions i on i.id=f.institution_id and i.deleted_at is null
        join public.form_versions v on v.id=r.form_version_id and v.form_id=f.id
        join public.form_occurrences o on o.id=r.occurrence_id and o.form_id=f.id and o.institution_id=f.institution_id
          and o.form_version_id=r.form_version_id
        where r.id=v_response_id and r.status='submitted' and (v_form_id is null or r.form_id=v_form_id)
          and (ctx.scope_kind='platform' or f.institution_id=ctx.scope_institution_id) for share of r;
      if response_row.id is null then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
      v_form_id:=response_row.form_id;
    elsif v_form_id is null then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    select f.* into form_row from public.forms f join public.institutions i on i.id=f.institution_id and i.deleted_at is null
      where f.id=v_form_id and (ctx.scope_kind='platform' or f.institution_id=ctx.scope_institution_id) for share of f;
    if form_row.id is null then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    if v_application_id is not null and not exists(select 1 from public.form_applications a
      where a.id=v_application_id and a.form_id=form_row.id and a.institution_id=form_row.institution_id) then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    if v_occurrence_id is not null and not exists(select 1 from public.form_occurrences o
      where o.id=v_occurrence_id and o.form_id=form_row.id and o.institution_id=form_row.institution_id
        and (v_application_id is null or o.application_id=v_application_id)) then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
    foreach field_name in array array['starts_on_or_after','ends_on_or_before'] loop
      if p_query->>field_name is not null and p_query->>field_name!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
    end loop;
    starts_on:=(p_query->>'starts_on_or_after')::date; ends_on:=(p_query->>'ends_on_or_before')::date;
    if starts_on>ends_on then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
    cursor_field:=case p_operation when 'responses' then 'cursor_submitted_at' when 'file_jobs' then 'cursor_created_at' end;
    if p_operation='responses' and form_row.identity_mode='anonymous' then
      if p_query->>'cursor_submitted_at' is not null then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
    elsif cursor_field is not null then
      if (v_cursor_id is null)<>((p_query->>cursor_field) is null) then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
      if p_query->>cursor_field is not null then
        if p_query->>cursor_field!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ](0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]{1,6})?(Z|[+-](0[0-9]|1[0-5]):[0-5][0-9])$' then
          raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
        end if;
        cursor_time:=(p_query->>cursor_field)::timestamptz;
        if not isfinite(cursor_time) then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
      end if;
    end if;

    if p_operation='monitor' then
      if v_scope_id is not null then
        select min(m.scope_kind) into v_scope_kind from public.form_scope_metrics m
          join public.form_occurrences o on o.id=m.occurrence_id and o.institution_id=m.institution_id
          where o.form_id=form_row.id and m.institution_id=form_row.institution_id and m.scope_id=v_scope_id
            and (v_application_id is null or o.application_id=v_application_id)
            and (v_occurrence_id is null or o.id=v_occurrence_id)
          having count(distinct m.scope_kind)=1;
        if v_scope_kind is null then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
      end if;
      select jsonb_build_object(
        'eligible_count',coalesce(sum(case when v_scope_id is null then om.eligible_count else sm.eligible_count end),0),
        'responded_count',coalesce(sum(case when v_scope_id is null then om.responded_count else sm.responded_count end),0),
        'pending_count',coalesce(sum(case when v_scope_id is null then om.pending_count else sm.pending_count end),0),
        'is_anonymous',form_row.identity_mode='anonymous') into result
      from public.form_occurrences o
      left join public.form_occurrence_metrics om on om.occurrence_id=o.id and om.institution_id=form_row.institution_id
      left join public.form_scope_metrics sm on sm.occurrence_id=o.id and sm.institution_id=form_row.institution_id
        and sm.scope_id=v_scope_id and sm.scope_kind=v_scope_kind
      where o.form_id=form_row.id and o.institution_id=form_row.institution_id
        and (v_application_id is null or o.application_id=v_application_id) and (v_occurrence_id is null or o.id=v_occurrence_id)
        and (starts_on is null or o.opens_at::date>=starts_on) and (ends_on is null or o.closes_at::date<=ends_on);
    elsif p_operation='responses' then
      if exists(select 1 from public.form_responses r where r.form_id=form_row.id
        and r.status='submitted' and (r.institution_id is distinct from form_row.institution_id
          or r.identity_mode is distinct from form_row.identity_mode)) then
        raise check_violation using detail='SAI_UNAVAILABLE';
      end if;
      with page as materialized (
        select r.id,r.occurrence_id,r.form_version_id,r.identity_mode,r.submitted_at,p.display_name
        from public.form_responses r
        join public.form_occurrences o on o.id=r.occurrence_id and o.form_id=form_row.id and o.institution_id=form_row.institution_id
          and o.form_version_id=r.form_version_id
        join public.form_versions v on v.id=r.form_version_id and v.form_id=form_row.id
        left join public.people p on p.id=r.respondent_person_id and r.identity_mode='identified'
        where r.form_id=form_row.id and r.institution_id=form_row.institution_id and r.status='submitted'
          and (v_occurrence_id is null or r.occurrence_id=v_occurrence_id)
          and (v_cursor_id is null or case when form_row.identity_mode='anonymous' then r.id<v_cursor_id
            else (r.submitted_at,r.id)<(cursor_time,v_cursor_id) end)
        order by case when form_row.identity_mode='identified' then r.submitted_at end desc,r.id desc limit page_limit+1
      ), visible as materialized (
        select * from page order by case when form_row.identity_mode='identified' then submitted_at end desc,id desc limit page_limit
      ) select jsonb_build_object('identity_mode',form_row.identity_mode,
        'items',coalesce(jsonb_agg(jsonb_build_object('id',id,'occurrence_id',vis.occurrence_id,'form_version_id',form_version_id,
          'identity_mode',identity_mode,'submitted_at',case when identity_mode='identified' then submitted_at else null end,
          'respondent_label',case when identity_mode='identified' then display_name else null end)
          order by case when form_row.identity_mode='identified' then submitted_at end desc,id desc),'[]'::jsonb),
        'has_more',(select count(*)>page_limit from page),
        'next_cursor',case when (select count(*)>page_limit from page) then
          (select case when form_row.identity_mode='anonymous' then jsonb_build_object('id',id)
            else jsonb_build_object('submitted_at',submitted_at,'id',id) end from visible
            order by case when form_row.identity_mode='identified' then submitted_at end,id limit 1) else null end)
        into result from visible vis;
    elsif p_operation='response_detail' then
      select v.* into strict version_row from public.form_versions v
        where v.id=response_row.form_version_id and v.form_id=form_row.id;
      if response_row.identity_mode is distinct from form_row.identity_mode
        or exists(select 1 from public.form_answers a
        left join public.form_items i on i.id=a.item_id and i.form_version_id=response_row.form_version_id
        left join public.form_sections s on s.id=i.section_id and s.form_version_id=response_row.form_version_id
        where a.response_id=response_row.id and (a.form_version_id is distinct from response_row.form_version_id
          or i.id is null or s.id is null)) then
        raise check_violation using detail='SAI_UNAVAILABLE';
      end if;
      if exists(select 1 from public.form_answer_options ao
        join public.form_answers a on a.id=ao.answer_id
        left join public.form_question_options qo on qo.id=ao.option_id and qo.item_id=a.item_id
          and qo.form_version_id=response_row.form_version_id
        where a.response_id=response_row.id and qo.id is null)
        or exists(select 1 from public.form_answer_assets aa
          join public.form_answers a on a.id=aa.answer_id
          left join public.form_assets fa on fa.id=aa.asset_id and fa.item_id=a.item_id
            and fa.occurrence_id=response_row.occurrence_id and fa.institution_id=form_row.institution_id
          where a.response_id=response_row.id and fa.id is null) then
        raise check_violation using detail='SAI_UNAVAILABLE';
      end if;
      result:=jsonb_build_object('id',response_row.id,'occurrence_id',response_row.occurrence_id,
        'form_id',form_row.id,'form_version_id',version_row.id,
        'form_version_number',version_row.version_number,'form_version_state',version_row.state,
        'identity_mode',response_row.identity_mode,
        'submitted_at',case when response_row.identity_mode='identified' then response_row.submitted_at else null end,
        'respondent_label',case when response_row.identity_mode='identified' then
          (select display_name from public.people where id=response_row.respondent_person_id) else null end,
        'definition',app_private.form_definition_projection(form_row.id,response_row.form_version_id),
        'answers',coalesce((select jsonb_agg(jsonb_build_object(
          'item_id',a.item_id,'kind',a.answer_kind,'text_value',a.text_value,'integer_value',a.integer_value,
          'decimal_value',a.decimal_value,'money_minor_units',a.money_minor_units,'date_value',a.date_value,
          'yes_no_value',a.yes_no_value,'scale_value',a.scale_value,
          'option_ids',coalesce((select jsonb_agg(ao.option_id order by ao.position)
            from public.form_answer_options ao join public.form_question_options qo on qo.id=ao.option_id and qo.item_id=i.id
            where ao.answer_id=a.id),'[]'::jsonb),
          'asset_ids',coalesce((select jsonb_agg(aa.asset_id order by aa.position)
            from public.form_answer_assets aa where aa.answer_id=a.id),'[]'::jsonb))
          order by s.position,i.position,i.id)
          from public.form_answers a join public.form_items i on i.id=a.item_id
          join public.form_sections s on s.id=i.section_id where a.response_id=response_row.id),'[]'::jsonb));
    else
      with page as materialized (
        select j.* from public.form_file_jobs j where j.form_id=form_row.id and j.institution_id=form_row.institution_id
          and j.artifact_provider='r2' and j.export_kind='xlsx' and j.requested_by_internal_identity_id=ctx.internal_identity_id
          and (v_cursor_id is null or (j.created_at,j.id)<(cursor_time,v_cursor_id))
          order by j.created_at desc,j.id desc limit page_limit+1
      ), visible as materialized (
        select * from page order by created_at desc,id desc limit page_limit
      ) select jsonb_build_object('items',coalesce(jsonb_agg(jsonb_build_object('id',j.id,
          'status',case when j.expires_at<=clock_timestamp() then 'expired' else j.state end,'progress',j.progress,
          'error_code',case when j.error_code in ('export_failed','export_timeout','empty_export','retry_exhausted') then j.error_code else null end,
          'expires_at',j.expires_at,'download_available',j.state='succeeded' and j.expires_at>clock_timestamp()
            and exists(select 1 from public.media_assets a where a.id=j.artifact_media_asset_id
              and a.export_file_job_id=j.id and a.form_id=j.form_id and a.institution_id=j.institution_id
              and a.owner_internal_identity_id=ctx.internal_identity_id and a.catalog_kind='form-xlsx'
              and a.storage_provider='r2' and a.status='ready' and a.expires_at>clock_timestamp()))
          order by j.created_at desc,j.id desc),'[]'::jsonb),
        'has_more',(select count(*)>page_limit from page),
        'next_cursor',case when (select count(*)>page_limit from page) then
          (select jsonb_build_object('created_at',created_at,'id',id) from visible order by created_at,id limit 1) else null end)
        into result from visible j;
    end if;
    select * into strict final_ctx from app_private.require_superadmin_internal_context(capability);
    if (ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,ctx.scope_kind,ctx.scope_institution_id)
      is distinct from (final_ctx.internal_identity_id,final_ctx.internal_auth_link_id,final_ctx.internal_membership_id,
        final_ctx.session_id,final_ctx.scope_kind,final_ctx.scope_institution_id)
      or not exists(select 1 from auth.sessions where id=final_ctx.session_id and user_id=final_ctx.auth_user_id
        and (not_after is null or not_after>clock_timestamp()))
      or not exists(select 1 from public.institutions where id=form_row.institution_id and deleted_at is null) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
  exception
    when invalid_parameter_value or invalid_text_representation or datetime_field_overflow or invalid_datetime_format or numeric_value_out_of_range then
      error_code:='SAI_INVALID_ARGUMENT';
    when others then
      get stacked diagnostics error_code=pg_exception_detail;
      error_code:=app_private.superadmin_internal_error_envelope(error_code,correlation)#>>'{error,code}';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(capability,action_code,error_code,correlation);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,capability,ctx.aal,action_code,'success',null,correlation,form_row.institution_id,
    case when p_operation='response_detail' then 'form_response' else 'form' end,
    case when p_operation='response_detail' then response_row.id else form_row.id end);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end;
$$;
revoke all on function app_private.superadmin_forms_operations_read_v2(text,jsonb) from public,anon,authenticated,service_role;

create function public.superadmin_forms_monitor_v2(p_query jsonb) returns jsonb
language sql volatile security definer set search_path='' as $$
  select app_private.superadmin_forms_operations_read_v2('monitor',$1);
$$;
create function public.superadmin_forms_responses_v2(p_query jsonb) returns jsonb
language sql volatile security definer set search_path='' as $$
  select app_private.superadmin_forms_operations_read_v2('responses',$1);
$$;
create function public.superadmin_forms_response_detail_v2(p_query jsonb) returns jsonb
language sql volatile security definer set search_path='' as $$
  select app_private.superadmin_forms_operations_read_v2('response_detail',$1);
$$;
create function public.superadmin_forms_file_jobs_v2(p_query jsonb) returns jsonb
language sql volatile security definer set search_path='' as $$
  select app_private.superadmin_forms_operations_read_v2('file_jobs',$1);
$$;
revoke all on function public.superadmin_forms_monitor_v2(jsonb),public.superadmin_forms_responses_v2(jsonb),
  public.superadmin_forms_response_detail_v2(jsonb),public.superadmin_forms_file_jobs_v2(jsonb)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_forms_monitor_v2(jsonb),public.superadmin_forms_responses_v2(jsonb),
  public.superadmin_forms_response_detail_v2(jsonb),public.superadmin_forms_file_jobs_v2(jsonb) to authenticated;
commit;
