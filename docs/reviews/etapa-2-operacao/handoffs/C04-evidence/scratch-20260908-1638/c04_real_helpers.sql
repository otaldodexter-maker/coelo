create function app_private.superadmin_location_normalize_v2(p_payload jsonb)
returns jsonb language plpgsql immutable security invoker set search_path=''
as $$
declare result jsonb; address_value jsonb; field text; text_value text; limit_bytes integer;
  institution uuid; unit_id uuid;
begin
  if p_payload is null or jsonb_typeof(p_payload)<>'object'
    or not(p_payload ?& array['scope_kind','institution_id','unit_id','name','description','kind','floor','address','visibility'])
    or (select count(*) from jsonb_object_keys(p_payload))<>9 then
    raise invalid_parameter_value using message='invalid location payload',detail='SAI_INVALID_ARGUMENT';
  end if;
  foreach field in array array['scope_kind','institution_id','name','kind','visibility'] loop
    if jsonb_typeof(p_payload->field)<>'string' then
      raise invalid_parameter_value using message='invalid location payload',detail='SAI_INVALID_ARGUMENT';
    end if;
  end loop;
  if p_payload->>'scope_kind' not in('institution','unit')
    or p_payload->>'kind' not in('internal','external')
    or p_payload->>'visibility' not in('team','guardians','students','all')
    or jsonb_typeof(p_payload->'unit_id') not in('string','null') then
    raise invalid_parameter_value using message='invalid location payload',detail='SAI_INVALID_ARGUMENT';
  end if;
  begin
    institution:=(p_payload->>'institution_id')::uuid;
    unit_id:=(p_payload->>'unit_id')::uuid;
  exception when invalid_text_representation then
    raise invalid_parameter_value using message='invalid location owner',detail='SAI_INVALID_ARGUMENT';
  end;
  if (p_payload->>'scope_kind'='institution' and unit_id is not null)
    or (p_payload->>'scope_kind'='unit' and unit_id is null) then
    raise invalid_parameter_value using message='invalid location owner',detail='SAI_INVALID_ARGUMENT';
  end if;
  result:=p_payload||jsonb_build_object('institution_id',institution,'unit_id',unit_id);
  foreach field in array array['name','description','floor'] loop
    if jsonb_typeof(p_payload->field) not in('string','null') then
      raise invalid_parameter_value using message='invalid location text',detail='SAI_INVALID_ARGUMENT';
    end if;
    text_value:=nullif(btrim(p_payload->>field),'');
    if (field='name' and text_value is null)
      or length(text_value)>(case when field='description' then 500 else 120 end)
      or text_value ~ U&'[\0001-\001f\007f]' then
      raise invalid_parameter_value using message='invalid location text',detail='SAI_INVALID_ARGUMENT';
    end if;
    result:=result||jsonb_build_object(field,text_value);
  end loop;
  address_value:=p_payload->'address';
  if address_value='null'::jsonb then
    if p_payload->>'kind'='external' then
      raise invalid_parameter_value using message='external location address required',detail='SAI_INVALID_ARGUMENT';
    end if;
  else
    if jsonb_typeof(address_value)<>'object' or btrim(address_value->>'country') is distinct from 'Brasil'
      or exists(select 1 from jsonb_object_keys(address_value) k where k not in(
        'country','state','city','district','street','number','complement','postal_code')) then
      raise invalid_parameter_value using message='invalid location address',detail='SAI_INVALID_ARGUMENT';
    end if;
    foreach field in array array['country','state','city','district','street','number','complement','postal_code'] loop
      if address_value ? field then
        if jsonb_typeof(address_value->field) not in('string','null') then
          raise invalid_parameter_value using message='invalid location address',detail='SAI_INVALID_ARGUMENT';
        end if;
        text_value:=nullif(btrim(address_value->>field),'');
        limit_bytes:=case when field='country' then 80 when field in('number','postal_code') then 64 else 240 end;
        if octet_length(text_value)>limit_bytes or text_value ~ U&'[\0001-\001f\007f]'
          or (field='postal_code' and text_value !~ '^[0-9]{8}$') then
          raise invalid_parameter_value using message='invalid location address',detail='SAI_INVALID_ARGUMENT';
        end if;
        address_value:=address_value||jsonb_build_object(field,text_value);
      end if;
    end loop;
  end if;
  return result||jsonb_build_object('address',address_value);
end
$$;

create function app_private.superadmin_location_owner_v2(
  p_context app_private.superadmin_internal_context,
  p_scope_kind text,p_institution_id uuid,p_unit_id uuid
) returns void language plpgsql volatile security definer set search_path=''
as $$
begin
  if p_context.internal_identity_id is null or p_context.platform_role_code is distinct from 'owner'
    or p_context.scope_kind is null or p_context.scope_kind not in('platform','institution')
    or p_scope_kind is null or p_scope_kind not in('institution','unit')
    or p_institution_id is null
    or (p_scope_kind='institution' and p_unit_id is not null)
    or (p_scope_kind='unit' and p_unit_id is null)
    or (p_context.scope_kind='institution' and p_context.scope_institution_id is distinct from p_institution_id) then
    raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
  end if;
  perform 1 from public.institutions institution
    where institution.id=p_institution_id and institution.deleted_at is null for share;
  if not found then
    raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
  end if;
  if p_scope_kind='unit' then
    perform 1 from public.units unit_record where unit_record.id=p_unit_id
      and unit_record.institution_id=p_institution_id and unit_record.status<>'archived' for share;
    if not found then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
  end if;
end
$$;

create function app_private.superadmin_location_payload_v2(p_location_id uuid)
returns jsonb language sql stable security definer set search_path=''
as $$
  select jsonb_build_object('id',l.id,'scope_kind',l.scope_kind,
    'institution_id',l.institution_id,'unit_id',l.unit_id,'name',l.name,
    'description',l.description,'kind',l.kind,'floor',l.floor,'address',l.address,
    'visibility',l.visibility,'status',l.status,'management_version',l.management_version,
    'created_at',l.created_at,'updated_at',l.updated_at)
  from public.activity_locations l where l.id=p_location_id
$$;
