begin;

do $preflight$
declare
  invalid_argument_probe jsonb;
begin
  if current_user<>'postgres' then
    raise insufficient_privilege using
      message='internal institution edit migration must run as postgres';
  end if;
  if to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or to_regprocedure(
      'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)'
    ) is null
    or to_regprocedure(
      'app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)'
    ) is null
    or to_regprocedure('app_private.superadmin_internal_error_envelope(text,uuid)') is null
    or to_regclass('app_private.superadmin_internal_identities') is null
    or to_regclass('public.institutions') is null
    or to_regclass('public.institution_types') is null
    or to_regclass('public.institution_addresses') is null then
    raise object_not_in_prerequisite_state using
      message='internal Auth, audit and institution dependencies are required';
  end if;
  invalid_argument_probe:=app_private.superadmin_internal_error_envelope(
    'SAI_INVALID_ARGUMENT',gen_random_uuid()
  );
  if invalid_argument_probe->'error'->>'code'
       is distinct from 'SAI_INVALID_ARGUMENT'
    or (invalid_argument_probe->'error'->>'http_status')::integer
       is distinct from 400 then
    raise object_not_in_prerequisite_state using
      message='SAI_INVALID_ARGUMENT error envelope dependency is required';
  end if;
end
$preflight$;

create table app_private.superadmin_internal_institution_edit_receipts(
  request_id uuid primary key,
  actor_internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id),
  institution_id uuid not null references public.institutions(id),
  expected_version bigint not null check(expected_version>0),
  request_hash bytea not null check(pg_catalog.octet_length(request_hash)=32),
  result_management_version bigint not null
    check(
      result_management_version>0
      and result_management_version=expected_version+1
    ),
  original_correlation_id uuid not null,
  created_at timestamptz not null default pg_catalog.now()
);

comment on column
  app_private.superadmin_internal_institution_edit_receipts.request_hash is
  'Derived pseudonymous command hash; private, non-exportable and without retention automation';

create index superadmin_internal_institution_edit_receipts_actor_idx
  on app_private.superadmin_internal_institution_edit_receipts(
    actor_internal_identity_id
  );
create index superadmin_internal_institution_edit_receipts_institution_idx
  on app_private.superadmin_internal_institution_edit_receipts(institution_id);

alter table app_private.superadmin_internal_institution_edit_receipts
  enable row level security;
alter table app_private.superadmin_internal_institution_edit_receipts
  force row level security;
revoke all on table
  app_private.superadmin_internal_institution_edit_receipts
  from public,anon,authenticated,service_role;

create function app_private.superadmin_institution_edit_core_validate_v2(
  p_payload jsonb
) returns jsonb
language plpgsql
stable
security invoker
set search_path=''
as $$
declare
  unknown_key text;
  key_name text;
  normalized_payload jsonb:='{}'::jsonb;
  normalized_child jsonb;
  normalized_type_id uuid;
begin
  if p_payload is null
    or pg_catalog.jsonb_typeof(p_payload)<>'object'
    or p_payload='{}'::jsonb
    or pg_catalog.octet_length(p_payload::text)>65536 then
    raise invalid_parameter_value using
      message='invalid institution edit payload',detail='SAI_INVALID_ARGUMENT';
  end if;

  select payload_key into unknown_key
  from pg_catalog.jsonb_object_keys(p_payload) payload_key
  where not(payload_key=any(array[
    'public_name','trade_name','legal_name','timezone','locale',
    'institution_type_id','address'
  ]::text[]))
  limit 1;
  if unknown_key is not null then
    raise invalid_parameter_value using
      message='invalid institution edit payload',detail='SAI_INVALID_ARGUMENT';
  end if;

  foreach key_name in array array[
    'public_name','trade_name','legal_name','timezone','locale'
  ]::text[] loop
    if p_payload?key_name then
      if pg_catalog.jsonb_typeof(p_payload->key_name) not in('string','null') then
        raise invalid_parameter_value using
          message='invalid institution edit payload',detail='SAI_INVALID_ARGUMENT';
      end if;
      if key_name=any(array[
        'public_name','timezone','locale'
      ]::text[]) and (
        pg_catalog.jsonb_typeof(p_payload->key_name)='null'
        or pg_catalog.btrim(p_payload->>key_name)=''
      ) then
        raise invalid_parameter_value using
          message='invalid institution edit payload',detail='SAI_INVALID_ARGUMENT';
      end if;
      normalized_payload:=normalized_payload||pg_catalog.jsonb_build_object(
        key_name,
        case
          when key_name=any(array[
            'public_name','timezone','locale'
          ]::text[]) then pg_catalog.to_jsonb(pg_catalog.btrim(p_payload->>key_name))
          when pg_catalog.jsonb_typeof(p_payload->key_name)='null'
            or pg_catalog.btrim(p_payload->>key_name)='' then 'null'::jsonb
          else pg_catalog.to_jsonb(pg_catalog.btrim(p_payload->>key_name))
        end
      );

      if pg_catalog.jsonb_typeof(normalized_payload->key_name)='string'
        and (
          normalized_payload->>key_name ~ U&'[\0001-\001f\007f]'
          or pg_catalog.octet_length(normalized_payload->>key_name)>
            case
              when key_name in('public_name','trade_name','legal_name') then 240
              when key_name='timezone' then 64
              when key_name='locale' then 35
            end
        ) then
        raise invalid_parameter_value using
          message='invalid institution edit payload',detail='SAI_INVALID_ARGUMENT';
      end if;
    end if;
  end loop;

  if normalized_payload?'timezone' and not exists(
    select 1 from pg_catalog.pg_timezone_names timezone_item
    where timezone_item.name=normalized_payload->>'timezone'
  ) then
    raise invalid_parameter_value using
      message='invalid institution edit payload',detail='SAI_INVALID_ARGUMENT';
  end if;
  if normalized_payload?'locale'
    and normalized_payload->>'locale'
      !~ '^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$' then
    raise invalid_parameter_value using
      message='invalid institution edit payload',detail='SAI_INVALID_ARGUMENT';
  end if;

  if p_payload?'institution_type_id' then
    if pg_catalog.jsonb_typeof(p_payload->'institution_type_id')<>'string'
      or pg_catalog.btrim(p_payload->>'institution_type_id')='' then
      raise invalid_parameter_value using
        message='invalid institution edit payload',detail='SAI_INVALID_ARGUMENT';
    end if;
    begin
      normalized_type_id:=
        pg_catalog.btrim(p_payload->>'institution_type_id')::uuid;
    exception when invalid_text_representation then
      raise invalid_parameter_value using
        message='invalid institution edit payload',detail='SAI_INVALID_ARGUMENT';
    end;
    normalized_payload:=normalized_payload||pg_catalog.jsonb_build_object(
      'institution_type_id',
      normalized_type_id::text
    );
  end if;

  if p_payload?'address' then
    if pg_catalog.jsonb_typeof(p_payload->'address')<>'object'
      or p_payload->'address'='{}'::jsonb then
      raise invalid_parameter_value using
        message='invalid institution edit payload',detail='SAI_INVALID_ARGUMENT';
    end if;
    select payload_key into unknown_key
    from pg_catalog.jsonb_object_keys(p_payload->'address') payload_key
    where not(payload_key=any(array[
      'country','state','city','district','street','number','complement','postal_code'
    ]::text[]))
    limit 1;
    if unknown_key is not null then
      raise invalid_parameter_value using
        message='invalid institution edit payload',detail='SAI_INVALID_ARGUMENT';
    end if;
    normalized_child:='{}'::jsonb;
    foreach key_name in array array[
      'country','state','city','district','street','number','complement','postal_code'
    ]::text[] loop
      if (p_payload->'address')?key_name then
        if pg_catalog.jsonb_typeof(p_payload->'address'->key_name)
          not in('string','null')
          or (key_name='country' and (
            pg_catalog.jsonb_typeof(p_payload->'address'->key_name)='null'
            or pg_catalog.btrim(p_payload->'address'->>key_name)=''
          )) then
          raise invalid_parameter_value using
            message='invalid institution edit payload',detail='SAI_INVALID_ARGUMENT';
        end if;
        normalized_child:=normalized_child||pg_catalog.jsonb_build_object(
          key_name,
          case
            when pg_catalog.jsonb_typeof(p_payload->'address'->key_name)='null'
              or pg_catalog.btrim(p_payload->'address'->>key_name)=''
              then 'null'::jsonb
            else pg_catalog.to_jsonb(
              pg_catalog.btrim(p_payload->'address'->>key_name))
          end
        );
        if pg_catalog.jsonb_typeof(normalized_child->key_name)='string'
          and (
            normalized_child->>key_name ~ U&'[\0001-\001f\007f]'
            or pg_catalog.octet_length(normalized_child->>key_name)>
              case
                when key_name='country' then 80
                when key_name in(
                  'state','city','district','street','complement'
                ) then 240
                when key_name in('number','postal_code') then 64
              end
          ) then
          raise invalid_parameter_value using
            message='invalid institution edit payload',detail='SAI_INVALID_ARGUMENT';
        end if;
        if key_name='country'
          and normalized_child->>key_name<>'Brasil' then
          raise invalid_parameter_value using
            message='invalid institution edit payload',detail='SAI_INVALID_ARGUMENT';
        end if;
        if key_name='postal_code'
          and pg_catalog.jsonb_typeof(normalized_child->key_name)='string'
          and normalized_child->>key_name !~ '^[0-9]{8}$' then
          raise invalid_parameter_value using
            message='invalid institution edit payload',detail='SAI_INVALID_ARGUMENT';
        end if;
      end if;
    end loop;
    normalized_payload:=normalized_payload||
      pg_catalog.jsonb_build_object('address',normalized_child);
  end if;

  return normalized_payload;
end
$$;

create function app_private.superadmin_institution_edit_core_request_hash_v2(
  p_institution_id uuid,
  p_expected_version bigint,
  p_payload jsonb
) returns bytea
language sql
immutable
security invoker
set search_path=''
as $$
  select extensions.digest(
    pg_catalog.convert_to(pg_catalog.jsonb_build_object(
      'command_kind','institution.edit_core',
      'institution_id',p_institution_id,
      'expected_version',p_expected_version,
      'payload',p_payload
    )::text,'UTF8'),
    'sha256'
  )
$$;

create function app_private.superadmin_institution_edit_core_apply_v2(
  p_request_id uuid,
  p_institution_id uuid,
  p_expected_version bigint,
  p_payload jsonb,
  p_request_hash bytea,
  p_context app_private.superadmin_internal_context,
  p_correlation_id uuid
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  prior_receipt app_private.superadmin_internal_institution_edit_receipts%rowtype;
  institution_record public.institutions%rowtype;
  address_record public.institution_addresses%rowtype;
  requested_type_id uuid;
  requested_public_name text;
  requested_trade_name text;
  requested_legal_name text;
  requested_timezone text;
  requested_locale text;
  requested_country text;
  requested_state text;
  requested_city text;
  requested_district text;
  requested_street text;
  requested_number text;
  requested_complement text;
  requested_postal_code text;
  address_changed boolean:=false;
  root_changed boolean:=false;
  result_version bigint;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_request_id::text,0)
  );

  select receipt.* into prior_receipt
  from app_private.superadmin_internal_institution_edit_receipts receipt
  where receipt.request_id=p_request_id;

  if prior_receipt.request_id is not null then
    if prior_receipt.actor_internal_identity_id
         is distinct from p_context.internal_identity_id
      or prior_receipt.institution_id is distinct from p_institution_id
      or prior_receipt.expected_version is distinct from p_expected_version
      or prior_receipt.request_hash is distinct from p_request_hash then
      raise invalid_parameter_value using
        message='request id already used',detail='SAI_INVALID_ARGUMENT';
    end if;

    return pg_catalog.jsonb_build_object(
      'institution_id',prior_receipt.institution_id,
      'management_version',prior_receipt.result_management_version,
      'correlation_id',p_correlation_id,
      'replayed',true
    );
  end if;

  select institution.* into institution_record
  from public.institutions institution
  where institution.id=p_institution_id and institution.deleted_at is null
  for update;
  if institution_record.id is null then
    raise insufficient_privilege using
      message='internal institution access denied',detail='SAI_PERMISSION_DENIED';
  end if;
  if institution_record.management_version is distinct from p_expected_version then
    raise serialization_failure using
      message='stale institution version',detail='SAI_CONCURRENT_CHANGE';
  end if;

  requested_type_id:=institution_record.institution_type_id;
  if p_payload?'institution_type_id' then
    select institution_type.id into requested_type_id
    from public.institution_types institution_type
    where institution_type.id=(p_payload->>'institution_type_id')::uuid
      and institution_type.status='active'
    for share;
    if not found then
      raise invalid_parameter_value using
        message='invalid institution type',detail='SAI_INVALID_ARGUMENT';
    end if;
  end if;

  requested_public_name:=case when p_payload?'public_name'
    then p_payload->>'public_name' else institution_record.public_name end;
  requested_trade_name:=case when p_payload?'trade_name'
    then p_payload->>'trade_name' else institution_record.trade_name end;
  requested_legal_name:=case when p_payload?'legal_name'
    then p_payload->>'legal_name' else institution_record.legal_name end;
  requested_timezone:=case when p_payload?'timezone'
    then p_payload->>'timezone' else institution_record.timezone end;
  requested_locale:=case when p_payload?'locale'
    then p_payload->>'locale' else institution_record.locale end;

  root_changed:=requested_public_name is distinct from institution_record.public_name
    or requested_trade_name is distinct from institution_record.trade_name
    or requested_legal_name is distinct from institution_record.legal_name
    or requested_timezone is distinct from institution_record.timezone
    or requested_locale is distinct from institution_record.locale
    or requested_type_id is distinct from institution_record.institution_type_id;

  if p_payload?'address' then
    select address_item.* into address_record
    from public.institution_addresses address_item
    where address_item.institution_id=p_institution_id;
    if address_record.institution_id is null
      and (
        not((p_payload->'address')?'country')
        or p_payload->'address'->>'country'<>'Brasil'
      ) then
      raise invalid_parameter_value using
        message='country Brasil is required for a new institution address',
        detail='SAI_INVALID_ARGUMENT';
    end if;
    requested_country:=case when (p_payload->'address')?'country'
      then p_payload->'address'->>'country'
      else address_record.country end;
    requested_state:=case when (p_payload->'address')?'state'
      then p_payload->'address'->>'state' else address_record.state end;
    requested_city:=case when (p_payload->'address')?'city'
      then p_payload->'address'->>'city' else address_record.city end;
    requested_district:=case when (p_payload->'address')?'district'
      then p_payload->'address'->>'district' else address_record.district end;
    requested_street:=case when (p_payload->'address')?'street'
      then p_payload->'address'->>'street' else address_record.street end;
    requested_number:=case when (p_payload->'address')?'number'
      then p_payload->'address'->>'number' else address_record.number end;
    requested_complement:=case when (p_payload->'address')?'complement'
      then p_payload->'address'->>'complement' else address_record.complement end;
    requested_postal_code:=case when (p_payload->'address')?'postal_code'
      then p_payload->'address'->>'postal_code' else address_record.postal_code end;
    address_changed:=address_record.institution_id is null
      or requested_country is distinct from address_record.country
      or requested_state is distinct from address_record.state
      or requested_city is distinct from address_record.city
      or requested_district is distinct from address_record.district
      or requested_street is distinct from address_record.street
      or requested_number is distinct from address_record.number
      or requested_complement is distinct from address_record.complement
      or requested_postal_code is distinct from address_record.postal_code;
  end if;

  if not(root_changed or address_changed) then
    raise invalid_parameter_value using
      message='institution edit is a no-op',detail='SAI_INVALID_ARGUMENT';
  end if;

  update public.institutions institution set
    public_name=requested_public_name,
    trade_name=requested_trade_name,
    legal_name=requested_legal_name,
    timezone=requested_timezone,
    locale=requested_locale,
    institution_type_id=requested_type_id,
    management_version=institution.management_version+1,
    updated_at=greatest(
      pg_catalog.clock_timestamp(),institution.updated_at+interval '1 microsecond'
    )
  where institution.id=p_institution_id
  returning institution.management_version into result_version;

  if address_changed then
    insert into public.institution_addresses(
      institution_id,country,state,city,district,street,number,complement,
      postal_code,status,created_at,updated_at
    ) values(
      p_institution_id,requested_country,requested_state,requested_city,
      requested_district,requested_street,requested_number,requested_complement,
      requested_postal_code,'active',pg_catalog.now(),pg_catalog.now()
    )
    on conflict(institution_id) do update set
      country=excluded.country,state=excluded.state,city=excluded.city,
      district=excluded.district,street=excluded.street,number=excluded.number,
      complement=excluded.complement,postal_code=excluded.postal_code,
      updated_at=greatest(
        pg_catalog.clock_timestamp(),
        public.institution_addresses.updated_at+interval '1 microsecond'
      );
  end if;

  insert into app_private.superadmin_internal_institution_edit_receipts(
    request_id,actor_internal_identity_id,institution_id,expected_version,
    request_hash,result_management_version,original_correlation_id
  ) values(
    p_request_id,p_context.internal_identity_id,p_institution_id,
    p_expected_version,p_request_hash,result_version,p_correlation_id
  );

  return pg_catalog.jsonb_build_object(
    'institution_id',p_institution_id,
    'management_version',result_version,
    'correlation_id',p_correlation_id,
    'replayed',false
  );
end
$$;

create function public.superadmin_institution_edit_core_v2(
  p_request_id uuid,
  p_institution_id uuid,
  p_expected_version bigint,
  p_payload jsonb
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  context_record app_private.superadmin_internal_context;
  correlation_id uuid:=gen_random_uuid();
  normalized_payload jsonb;
  request_hash bytea;
  response_data jsonb;
  error_code text;
  error_detail text;
begin
  begin
    select * into strict context_record
    from app_private.require_superadmin_internal_context('institution.update');

    if context_record.platform_role_code not in('owner','operations') then
      raise insufficient_privilege using
        message='internal institution access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    if p_institution_id is null
      or (context_record.scope_kind='institution'
        and context_record.scope_institution_id is distinct from p_institution_id) then
      raise insufficient_privilege using
        message='internal institution access denied',detail='SAI_PERMISSION_DENIED';
    end if;

    if p_request_id is null or p_expected_version is null or p_expected_version<=0 then
      raise invalid_parameter_value using
        message='invalid institution edit request',detail='SAI_INVALID_ARGUMENT';
    end if;
    normalized_payload:=
      app_private.superadmin_institution_edit_core_validate_v2(p_payload);
    request_hash:=app_private.superadmin_institution_edit_core_request_hash_v2(
      p_institution_id,p_expected_version,normalized_payload
    );
    response_data:=app_private.superadmin_institution_edit_core_apply_v2(
      p_request_id,p_institution_id,p_expected_version,normalized_payload,
      request_hash,context_record,correlation_id
    );
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail in(
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED',
        'SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED'
      ) then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation or unique_violation
      or foreign_key_violation then
      error_code:='SAI_INVALID_ARGUMENT';
    when serialization_failure then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail='SAI_CONCURRENT_CHANGE'
        then error_detail else 'SAI_INTERNAL_ERROR' end;
    when others then
      error_code:='SAI_INTERNAL_ERROR';
  end;

  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'institution.update','institution.edit_core',error_code,correlation_id,
      case when context_record.scope_kind='institution'
        then context_record.scope_institution_id end
    );
    return app_private.superadmin_internal_error_envelope(
      error_code,correlation_id
    );
  end if;

  perform app_private.audit_append_superadmin_internal(
    context_record.internal_identity_id,
    context_record.internal_auth_link_id,
    context_record.internal_membership_id,
    context_record.session_id,
    'institution.update',
    context_record.aal,
    case when (response_data->>'replayed')::boolean
      then 'institution.edit_core.replay' else 'institution.edit_core' end,
    'success',
    null,
    correlation_id,
    p_institution_id,
    'institution',
    p_institution_id
  );

  return pg_catalog.jsonb_build_object(
    'ok',true,'data',response_data,'error',null
  );
end
$$;

alter table app_private.superadmin_internal_institution_edit_receipts
  owner to postgres;
alter function app_private.superadmin_institution_edit_core_validate_v2(jsonb)
  owner to postgres;
alter function app_private.superadmin_institution_edit_core_request_hash_v2(
  uuid,bigint,jsonb
) owner to postgres;
alter function app_private.superadmin_institution_edit_core_apply_v2(
  uuid,uuid,bigint,jsonb,bytea,app_private.superadmin_internal_context,uuid
) owner to postgres;
alter function public.superadmin_institution_edit_core_v2(
  uuid,uuid,bigint,jsonb
) owner to postgres;

revoke all on function
  app_private.superadmin_institution_edit_core_validate_v2(jsonb)
  from public,anon,authenticated,service_role;
revoke all on function
  app_private.superadmin_institution_edit_core_request_hash_v2(uuid,bigint,jsonb)
  from public,anon,authenticated,service_role;
revoke all on function
  app_private.superadmin_institution_edit_core_apply_v2(
    uuid,uuid,bigint,jsonb,bytea,app_private.superadmin_internal_context,uuid
  ) from public,anon,authenticated,service_role;
revoke all on function public.superadmin_institution_edit_core_v2(
  uuid,uuid,bigint,jsonb
) from public,anon,authenticated,service_role;
grant execute on function public.superadmin_institution_edit_core_v2(
  uuid,uuid,bigint,jsonb
) to authenticated;

commit;
