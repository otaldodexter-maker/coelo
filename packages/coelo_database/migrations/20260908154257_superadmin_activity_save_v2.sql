-- Aggregate the approved activity v2 commands without weakening any child
-- capability check. A caught error rolls back the complete inner block,
-- including successful child receipts and audits from this save attempt.
create table app_private.superadmin_internal_activity_save_receipts (
  request_id uuid primary key,
  internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete restrict,
  institution_id uuid not null references public.institutions(id) on delete restrict,
  activity_id uuid not null references public.activity_definitions(id) on delete restrict,
  request_hash bytea not null check(octet_length(request_hash)=32),
  resulting_version bigint not null check(resulting_version>0),
  resulting_status text not null,
  correlation_id uuid not null,
  created_at timestamptz not null default now()
);

create index superadmin_internal_activity_save_receipts_identity_idx
  on app_private.superadmin_internal_activity_save_receipts(internal_identity_id);
create index superadmin_internal_activity_save_receipts_institution_idx
  on app_private.superadmin_internal_activity_save_receipts(institution_id);
create index superadmin_internal_activity_save_receipts_activity_idx
  on app_private.superadmin_internal_activity_save_receipts(activity_id);

alter table app_private.superadmin_internal_activity_save_receipts enable row level security;
alter table app_private.superadmin_internal_activity_save_receipts force row level security;
revoke all on table app_private.superadmin_internal_activity_save_receipts
  from public,anon,authenticated,service_role;

create function public.superadmin_activity_save_v2(
  p_request_id uuid,
  p_activity_id uuid,
  p_expected_version bigint,
  p_publish boolean,
  p_payload jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  ctx app_private.superadmin_internal_context;
  activity public.activity_definitions%rowtype;
  correlation_id uuid := gen_random_uuid();
  institution_id uuid;
  unit_ids uuid[];
  group_ids uuid[];
  definition jsonb;
  result jsonb;
  request_hash bytea;
  receipt app_private.superadmin_internal_activity_save_receipts%rowtype;
  current_activity_id uuid := p_activity_id;
  current_version bigint;
  required_capability text := case
    when p_activity_id is null then 'activities.create'
    else 'activities.manage'
  end;
  error_code text;
begin
  begin
    select * into strict ctx
    from app_private.activity_v2_require_context(required_capability, null);

    if p_request_id is null
      or p_expected_version is null
      or p_publish is null
      or p_payload is null
      or jsonb_typeof(p_payload) <> 'object'
      or not (p_payload ?& array[
        'institution_id','definition','unit_ids','group_ids',
        'group_participation','participants','professional_assignments',
        'capability_policies','group_capability_settings',
        'professional_capability_actions'
      ])
      or exists(
        select 1 from jsonb_object_keys(p_payload) key
        where key not in(
          'institution_id','definition','unit_ids','group_ids',
          'group_participation','participants','professional_assignments',
          'capability_policies','group_capability_settings',
          'professional_capability_actions'
        )
      )
      or jsonb_typeof(p_payload->'institution_id') <> 'string'
      or jsonb_typeof(p_payload->'definition') <> 'object'
      or (p_payload->'definition') = '{}'::jsonb
      or exists(
        select 1 from jsonb_object_keys(p_payload->'definition') key
        where key not in('name','description','taxonomy_id','icon_key','initials')
      )
      or jsonb_typeof(p_payload->'unit_ids') <> 'array'
      or jsonb_typeof(p_payload->'group_ids') <> 'array'
      or jsonb_typeof(p_payload->'group_participation') <> 'object'
      or jsonb_typeof(p_payload->'participants') <> 'array'
      or jsonb_typeof(p_payload->'professional_assignments') <> 'array'
      or jsonb_typeof(p_payload->'capability_policies') <> 'object'
      or jsonb_typeof(p_payload->'group_capability_settings') <> 'array'
      or jsonb_typeof(p_payload->'professional_capability_actions') <> 'array'
    then
      raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
    end if;

    begin
      institution_id := (p_payload->>'institution_id')::uuid;
      select coalesce(array_agg(item.value::uuid order by item.ordinality), '{}'::uuid[])
      into unit_ids
      from jsonb_array_elements_text(p_payload->'unit_ids') with ordinality item(value, ordinality);
      select coalesce(array_agg(item.value::uuid order by item.ordinality), '{}'::uuid[])
      into group_ids
      from jsonb_array_elements_text(p_payload->'group_ids') with ordinality item(value, ordinality);
    exception when others then
      raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
    end;

    definition := p_payload->'definition';
    if p_activity_id is null then
      if p_expected_version <> 0 then
        raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
      end if;
      select * into strict ctx
      from app_private.activity_v2_require_context('activities.create', institution_id);
    else
      if p_expected_version < 1 then
        raise invalid_parameter_value using detail = 'ACTIVITY_INVALID_INPUT';
      end if;
      select * into activity
      from public.activity_definitions candidate
      where candidate.id = p_activity_id
        and (ctx.scope_kind <> 'institution'
          or candidate.institution_id = ctx.scope_institution_id);
      if activity.id is null then
        raise no_data_found using detail = 'ACTIVITY_NOT_FOUND';
      end if;
      select * into strict ctx
      from app_private.activity_v2_require_context('activities.manage', activity.institution_id);
      if institution_id <> activity.institution_id then
        raise foreign_key_violation using detail = 'ACTIVITY_INVALID_REFERENCE';
      end if;
    end if;

    required_capability := 'activities.link_units';
    perform app_private.activity_v2_require_context(required_capability, institution_id);
    required_capability := 'activities.link_groups';
    perform app_private.activity_v2_require_context(required_capability, institution_id);
    required_capability := 'activities.assign_people';
    perform app_private.activity_v2_require_context(required_capability, institution_id);
    required_capability := 'activities.manage_permissions';
    perform app_private.activity_v2_require_context(required_capability, institution_id);
    if p_publish then
      required_capability := 'activities.manage';
      perform app_private.activity_v2_require_context(required_capability, institution_id);
    end if;

    required_capability := case
      when p_activity_id is null then 'activities.create'
      else 'activities.manage'
    end;
    request_hash := app_private.activity_v2_command_request_hash(
      'activity.save',institution_id,p_activity_id,p_expected_version,
      pg_catalog.jsonb_build_object('publish',p_publish,'payload',p_payload)
    );
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_request_id::text,0)
    );
    select * into receipt
    from app_private.superadmin_internal_activity_save_receipts candidate
    where candidate.request_id = p_request_id;
    if receipt.request_id is not null then
      if receipt.internal_identity_id <> ctx.internal_identity_id then
        raise insufficient_privilege using detail = 'SAI_PERMISSION_DENIED';
      end if;
      if receipt.institution_id is distinct from institution_id
        or (p_activity_id is not null and receipt.activity_id is distinct from p_activity_id)
        or receipt.request_hash <> request_hash
      then
        raise serialization_failure using detail = 'SAI_CONCURRENT_CHANGE';
      end if;
      return app_private.activity_v2_success_envelope(pg_catalog.jsonb_build_object(
        'activity_id',receipt.activity_id,
        'management_version',receipt.resulting_version,
        'status',receipt.resulting_status,
        'correlation_id',receipt.correlation_id,
        'replayed',true
      ));
    end if;

    if p_activity_id is null then
      required_capability := 'activities.create';
      result := public.superadmin_activity_create_v2(
        app_private.activity_request_uuid('activity-save-create', p_request_id),
        definition || pg_catalog.jsonb_build_object(
          'institution_id', institution_id,
          'unit_ids', to_jsonb(unit_ids)
        )
      );
    else
      required_capability := 'activities.manage';
      result := public.superadmin_activity_update_v2(
        app_private.activity_request_uuid('activity-save-update', p_request_id),
        p_activity_id,
        p_expected_version,
        definition
      );
    end if;

    if result#>>'{ok}' is distinct from 'true' then
      raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
    end if;
    current_activity_id := (result#>>'{data,activity_id}')::uuid;
    current_version := (result#>>'{data,management_version}')::bigint;

    if p_activity_id is not null then
      required_capability := 'activities.link_units';
      result := public.superadmin_activity_set_units_v2(
        app_private.activity_request_uuid('activity-save-units', p_request_id),
        current_activity_id,current_version,unit_ids
      );
      if result#>>'{ok}' is distinct from 'true' then
        raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
      end if;
      current_version := (result#>>'{data,management_version}')::bigint;
    end if;

    required_capability := 'activities.link_groups';
    result := public.superadmin_activity_set_groups_v2(
      app_private.activity_request_uuid('activity-save-groups', p_request_id),
      current_activity_id,current_version,group_ids,p_payload->'group_participation'
    );
    if result#>>'{ok}' is distinct from 'true' then
      raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
    end if;
    current_version := (result#>>'{data,management_version}')::bigint;

    required_capability := 'activities.assign_people';
    result := public.superadmin_activity_set_participants_v2(
      app_private.activity_request_uuid('activity-save-participants', p_request_id),
      current_activity_id,current_version,p_payload->'participants'
    );
    if result#>>'{ok}' is distinct from 'true' then
      raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
    end if;
    current_version := (result#>>'{data,management_version}')::bigint;

    result := public.superadmin_activity_set_professionals_v2(
      app_private.activity_request_uuid('activity-save-professionals', p_request_id),
      current_activity_id,current_version,p_payload->'professional_assignments'
    );
    if result#>>'{ok}' is distinct from 'true' then
      raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
    end if;
    current_version := (result#>>'{data,management_version}')::bigint;

    required_capability := 'activities.manage_permissions';
    result := public.superadmin_activity_set_permissions_v2(
      app_private.activity_request_uuid('activity-save-permissions', p_request_id),
      current_activity_id,current_version,p_payload->'capability_policies',
      p_payload->'group_capability_settings',p_payload->'professional_capability_actions'
    );
    if result#>>'{ok}' is distinct from 'true' then
      raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
    end if;
    current_version := (result#>>'{data,management_version}')::bigint;

    if p_publish then
      required_capability := 'activities.manage';
      result := public.superadmin_activity_publish_v2(
        app_private.activity_request_uuid('activity-save-publish', p_request_id),
        current_activity_id,current_version
      );
      if result#>>'{ok}' is distinct from 'true' then
        raise exception using detail = coalesce(result#>>'{error,code}', 'SAI_INTERNAL_ERROR');
      end if;
    end if;
    current_version := (result#>>'{data,management_version}')::bigint;
    correlation_id := (result#>>'{data,correlation_id}')::uuid;
    insert into app_private.superadmin_internal_activity_save_receipts(
      request_id,internal_identity_id,institution_id,activity_id,request_hash,
      resulting_version,resulting_status,correlation_id
    ) values(
      p_request_id,ctx.internal_identity_id,institution_id,current_activity_id,request_hash,
      current_version,result#>>'{data,status}',correlation_id
    );
    return app_private.activity_v2_success_envelope(pg_catalog.jsonb_build_object(
      'activity_id',current_activity_id,
      'management_version',current_version,
      'status',result#>>'{data,status}',
      'correlation_id',correlation_id,
      'replayed',false
    ));
  exception when others then
    get stacked diagnostics error_code = pg_exception_detail;
    error_code := coalesce(nullif(error_code, ''), 'SAI_INTERNAL_ERROR');
  end;

  return app_private.activity_v2_denied_envelope(
    required_capability,'activity.save',error_code,correlation_id,institution_id
  );
end
$$;

comment on function public.superadmin_activity_save_v2(uuid,uuid,bigint,boolean,jsonb) is
  'Transactional activity v2 snapshot orchestrator. Reuses every child authorization, receipt, concurrency and audit contract.';

revoke all on function public.superadmin_activity_save_v2(uuid,uuid,bigint,boolean,jsonb)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_activity_save_v2(uuid,uuid,bigint,boolean,jsonb)
  to authenticated;
