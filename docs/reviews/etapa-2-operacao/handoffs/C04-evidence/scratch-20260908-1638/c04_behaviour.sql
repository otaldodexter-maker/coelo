\set ON_ERROR_STOP on

create function public.harness_expect(p_label text,p_actual jsonb,p_ok boolean,p_code text)
returns void language plpgsql as $$
begin
  if p_ok then
    if p_actual->>'ok' <> 'true' then
      raise exception 'FAIL % expected ok, got %',p_label,p_actual;
    end if;
  else
    if p_actual->>'ok' <> 'false' or p_actual#>>'{error,code}' is distinct from p_code then
      raise exception 'FAIL % expected %, got %',p_label,p_code,p_actual;
    end if;
  end if;
  raise notice 'ok  %',p_label;
end $$;

create function public.harness_version(p_id uuid) returns bigint language sql stable as $$
  select management_version from public.activity_locations where id=p_id $$;

create function public.harness_status(p_id uuid) returns text language sql stable as $$
  select status::text from public.activity_locations where id=p_id $$;

create function public.harness_payload(
  p_scope text,p_institution uuid,p_unit uuid,p_name text,p_kind text default 'internal',
  p_visibility text default 'team',p_address jsonb default 'null'::jsonb,
  p_description text default null,p_floor text default null)
returns jsonb language sql immutable as $$
  select jsonb_build_object('scope_kind',p_scope,'institution_id',p_institution,'unit_id',p_unit,
    'name',p_name,'description',p_description,'kind',p_kind,'floor',p_floor,
    'address',p_address,'visibility',p_visibility) $$;

do $seed$
declare i1 uuid:='11111111-1111-4111-8111-111111111111';
  i2 uuid:='22222222-2222-4222-8222-222222222222';
  u1 uuid:='33333333-3333-4333-8333-333333333333';
  s1 uuid:='44444444-4444-4444-8444-444444444444';
  a1 uuid:='55555555-5555-4555-8555-555555555555';
begin
  insert into public.institutions(id) values(i1),(i2);
  insert into public.units(id,institution_id) values(u1,i1);
  insert into app_private.superadmin_internal_identities(id) values(a1);
  insert into auth.sessions(id,not_after) values(s1,now()+interval '1 day');
  insert into public.activity_locations(id,institution_id,unit_id,name,status,scope_kind,kind,visibility,
    created_by_internal_identity_id)
  values('aaaaaaaa-0000-4000-8000-000000000001',i1,u1,'Sala Azul','active','unit','internal','team',a1),
        ('aaaaaaaa-0000-4000-8000-000000000002',i1,u1,'Sala Verde','active','unit','internal','team',a1);
  insert into public.activity_locations(id,institution_id,unit_id,name,status,scope_kind,kind,visibility,
    address,created_by_internal_identity_id)
  values('aaaaaaaa-0000-4000-8000-000000000003',i1,null,'Quadra','active','institution','external','all',
    jsonb_build_object('country','Brasil','city','Campinas'),a1);
  insert into app_private.harness_actor(identity_id,session_id,role_code,scope_kind)
    values(a1,s1,'owner','platform');
end
$seed$;

do $tests$
declare i1 uuid:='11111111-1111-4111-8111-111111111111';
  i2 uuid:='22222222-2222-4222-8222-222222222222';
  u1 uuid:='33333333-3333-4333-8333-333333333333';
  s1 uuid:='44444444-4444-4444-8444-444444444444';
  l1 uuid:='aaaaaaaa-0000-4000-8000-000000000001';
  l2 uuid:='aaaaaaaa-0000-4000-8000-000000000002';
  l3 uuid:='aaaaaaaa-0000-4000-8000-000000000003';
  r1 uuid:='bbbbbbbb-0000-4000-8000-000000000001';
  r uuid; res jsonb;
begin
  -- 01 a plain edit succeeds and advances the version exactly once
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('unit',i1,u1,'Sala Azul Nova'),1,r1);
  perform public.harness_expect('01 update succeeds',res,true,null);
  if public.harness_version(l1)<>2 then raise exception 'FAIL 01 version %',public.harness_version(l1); end if;
  if res#>>'{data,name}' is distinct from 'Sala Azul Nova' then raise exception 'FAIL 01 payload %',res; end if;

  -- 02 the same request replayed returns the same result without a second write
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('unit',i1,u1,'Sala Azul Nova'),1,r1);
  perform public.harness_expect('02 replay is idempotent',res,true,null);
  if public.harness_version(l1)<>2 then raise exception 'FAIL 02 version %',public.harness_version(l1); end if;

  -- 03 the same request id carrying a different payload is a different request
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('unit',i1,u1,'Outro nome'),1,r1);
  perform public.harness_expect('03 request id reuse refused',res,false,'SAI_CONCURRENT_CHANGE');

  -- 04 a stale version loses
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('unit',i1,u1,'Sala Azul Nova'),1,gen_random_uuid());
  perform public.harness_expect('04 stale version refused',res,false,'SAI_CONCURRENT_CHANGE');

  -- 05 renaming onto a live sibling is refused as an argument, not as a constraint
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('unit',i1,u1,'Sala Verde'),2,gen_random_uuid());
  perform public.harness_expect('05 duplicate name refused',res,false,'SAI_INVALID_ARGUMENT');
  if public.harness_version(l1)<>2 then raise exception 'FAIL 05 version moved'; end if;

  -- 06 a location is never re-parented into another institution
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('unit',i2,u1,'Sala Azul Nova'),2,gen_random_uuid());
  perform public.harness_expect('06 institution move refused',res,false,'SAI_INVALID_ARGUMENT');

  -- 07 nor promoted out of its unit
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('institution',i1,null,'Sala Azul Nova'),2,gen_random_uuid());
  perform public.harness_expect('07 scope change refused',res,false,'SAI_INVALID_ARGUMENT');

  -- 08 an external location without an address is refused by the shared normalizer
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('unit',i1,u1,'Sala Azul Nova','external'),2,gen_random_uuid());
  perform public.harness_expect('08 external without address refused',res,false,'SAI_INVALID_ARGUMENT');

  -- 09 an incomplete request is refused before anything is read
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('unit',i1,u1,'Sala Azul Nova'),null,gen_random_uuid());
  perform public.harness_expect('09 missing version refused',res,false,'SAI_INVALID_ARGUMENT');
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('unit',i1,u1,'Sala Azul Nova'),2,null);
  perform public.harness_expect('10 missing request id refused',res,false,'SAI_INVALID_ARGUMENT');

  -- 11 an unknown location is denied, not reported as missing
  res:=public.superadmin_location_update_v2(gen_random_uuid(),
    public.harness_payload('unit',i1,u1,'Sala Azul Nova'),2,gen_random_uuid());
  perform public.harness_expect('11 unknown location denied',res,false,'SAI_PERMISSION_DENIED');

  -- 12 asking for the status the row already has is refused
  res:=public.superadmin_location_set_status_v2(l1,'active',2,gen_random_uuid());
  perform public.harness_expect('12 unchanged status refused',res,false,'SAI_INVALID_ARGUMENT');

  -- 13 a status the catalog does not model is refused
  res:=public.superadmin_location_set_status_v2(l1,'suspended',2,gen_random_uuid());
  perform public.harness_expect('13 unsupported status refused',res,false,'SAI_INVALID_ARGUMENT');

  -- 14 deactivating and archiving both advance the version
  res:=public.superadmin_location_set_status_v2(l1,'inactive',2,gen_random_uuid());
  perform public.harness_expect('14 deactivate succeeds',res,true,null);
  if public.harness_version(l1)<>3 or public.harness_status(l1)<>'inactive' then
    raise exception 'FAIL 14 %/%',public.harness_version(l1),public.harness_status(l1); end if;
  res:=public.superadmin_location_set_status_v2(l1,'archived',3,gen_random_uuid());
  perform public.harness_expect('15 archive succeeds',res,true,null);
  if public.harness_version(l1)<>4 or public.harness_status(l1)<>'archived' then
    raise exception 'FAIL 15 %/%',public.harness_version(l1),public.harness_status(l1); end if;

  -- 16 an archived location is read only
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('unit',i1,u1,'Sala Azul Nova'),4,gen_random_uuid());
  perform public.harness_expect('16 archived is read only',res,false,'SAI_INVALID_ARGUMENT');

  -- 17 the freed name can be taken, and then the restore has nowhere to land
  update public.activity_locations set name='Sala Azul Nova' where id=l2;
  res:=public.superadmin_location_set_status_v2(l1,'active',4,gen_random_uuid());
  perform public.harness_expect('17 restore onto a taken name refused',res,false,'SAI_INVALID_ARGUMENT');
  if public.harness_status(l1)<>'archived' then raise exception 'FAIL 17 status moved'; end if;
  update public.activity_locations set name='Sala Verde' where id=l2;
  res:=public.superadmin_location_set_status_v2(l1,'active',4,gen_random_uuid());
  perform public.harness_expect('18 restore succeeds once the name is free',res,true,null);
  if public.harness_status(l1)<>'active' or public.harness_version(l1)<>5 then
    raise exception 'FAIL 18 %/%',public.harness_status(l1),public.harness_version(l1); end if;

  -- 19 a request id spent on an edit cannot be respent on a status change
  r:=gen_random_uuid();
  res:=public.superadmin_location_update_v2(l3,
    public.harness_payload('institution',i1,null,'Quadra','external','all',
      jsonb_build_object('country','Brasil','city','Campinas')),1,r);
  perform public.harness_expect('19 institution scoped edit succeeds',res,true,null);
  res:=public.superadmin_location_set_status_v2(l3,'inactive',2,r);
  perform public.harness_expect('20 request id is not reusable across verbs',res,false,'SAI_CONCURRENT_CHANGE');

  -- 21 a caller who is not the Owner reaches nothing
  update app_private.harness_actor set role_code='support';
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('unit',i1,u1,'Sala Azul Nova'),5,gen_random_uuid());
  perform public.harness_expect('21 non owner denied',res,false,'SAI_PERMISSION_DENIED');
  res:=public.superadmin_location_set_status_v2(l1,'inactive',5,gen_random_uuid());
  perform public.harness_expect('22 non owner denied on status',res,false,'SAI_PERMISSION_DENIED');

  -- 23 an Owner scoped to another institution reaches nothing either
  update app_private.harness_actor set role_code='owner',scope_kind='institution',scope_institution_id=i2;
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('unit',i1,u1,'Sala Azul Nova'),5,gen_random_uuid());
  perform public.harness_expect('23 cross institution denied',res,false,'SAI_PERMISSION_DENIED');

  -- 24 the same Owner scoped to the right institution does reach it
  update app_private.harness_actor set scope_institution_id=i1;
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('unit',i1,u1,'Sala Azul Cinco'),5,gen_random_uuid());
  perform public.harness_expect('24 in scope owner succeeds',res,true,null);

  -- 25 an expired session invalidates the command and leaves nothing behind
  update app_private.harness_actor set scope_kind='platform',scope_institution_id=null;
  update auth.sessions set not_after=now()-interval '1 minute' where id=s1;
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('unit',i1,u1,'Sala Azul Seis'),6,gen_random_uuid());
  perform public.harness_expect('25 expired session refused',res,false,'SAI_SESSION_INVALID');
  if public.harness_version(l1)<>6 then raise exception 'FAIL 25 version %',public.harness_version(l1); end if;
  if exists(select 1 from public.activity_locations where id=l1 and name='Sala Azul Seis') then
    raise exception 'FAIL 25 the refused edit was kept'; end if;
  update auth.sessions set not_after=now()+interval '1 day' where id=s1;

  -- 26 an unidentified caller is denied by the context itself
  update app_private.harness_actor set denied=true;
  res:=public.superadmin_location_update_v2(l1,
    public.harness_payload('unit',i1,u1,'Sala Azul Sete'),6,gen_random_uuid());
  perform public.harness_expect('26 denied context refused',res,false,'SAI_INTERNAL_CONTEXT_DENIED');
  update app_private.harness_actor set denied=false;

  raise notice '--- all behaviour checks passed ---';
end
$tests$;

-- Every refusal is audited, and every success is audited exactly once.
do $audit$
declare denied_count integer; success_count integer;
begin
  select count(*) into denied_count from app_private.harness_audit where outcome='denied';
  select count(*) into success_count from app_private.harness_audit where outcome='success';
  raise notice 'audit: % denied, % success',denied_count,success_count;
  -- Seven, not six: the idempotent replay in check 02 was a request that was served,
  -- and an audit trail records requests served, not distinct rows written.
  if denied_count<15 or success_count<>7 then
    raise exception 'FAIL audit coverage: % denied, % success',denied_count,success_count;
  end if;
  if exists(select 1 from app_private.harness_audit where capability not in('locations.update','locations.status')
    or action not in('location.update','location.status')) then
    raise exception 'FAIL audit vocabulary drift';
  end if;
end
$audit$;
