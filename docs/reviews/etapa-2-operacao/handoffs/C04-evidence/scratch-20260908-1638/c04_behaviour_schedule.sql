\set ON_ERROR_STOP on

do $seedc$
begin
  update app_private.harness_actor set role_code='owner',scope_kind='platform',
    scope_institution_id=null,denied=false;
  update auth.sessions set not_after=now()+interval '1 day';
  delete from app_private.harness_audit;
end
$seedc$;

do $scheduletests$
declare i1 uuid:='11111111-1111-4111-8111-111111111111';
  i2 uuid:='22222222-2222-4222-8222-222222222222';
  l1 uuid:='aaaaaaaa-0000-4000-8000-000000000001';
  l2 uuid:='aaaaaaaa-0000-4000-8000-000000000002';
  rs uuid:='dddddddd-0000-4000-8000-000000000001';
  week jsonb:='[{"weekday":1,"starts_minute":480,"ends_minute":720},
                {"weekday":1,"starts_minute":780,"ends_minute":1020},
                {"weekday":3,"starts_minute":480,"ends_minute":720}]'::jsonb;
  res jsonb; v bigint;
begin
  -- 01 a location with nothing published answers with an empty week, not with silence
  res:=public.superadmin_location_schedule_v2(l1);
  perform public.harness_expect('s01 an unpublished schedule reads as empty',res,true,null);
  if res#>>'{data,windows}'<>'[]' then raise exception 'FAIL s01 %',res; end if;
  v:=(res#>>'{data,management_version}')::bigint;

  -- 02 publishing a week advances the location version and reads back canonically
  res:=public.superadmin_location_schedule_set_v2(l1,week,v,rs);
  perform public.harness_expect('s02 publishing a week succeeds',res,true,null);
  if (res#>>'{data,management_version}')::bigint<>v+1 then raise exception 'FAIL s02 version %',res; end if;
  if jsonb_array_length(res#>'{data,windows}')<>3 then raise exception 'FAIL s02 windows %',res; end if;
  if (res#>'{data,windows}')->0->>'weekday'<>'1'
    or (res#>'{data,windows}')->0->>'starts_minute'<>'480' then
    raise exception 'FAIL s02 order %',res; end if;
  if (select count(*) from public.activity_location_schedules where location_id=l1)<>3 then
    raise exception 'FAIL s02 rows'; end if;

  -- 03 the read command sees exactly what was published
  res:=public.superadmin_location_schedule_v2(l1);
  perform public.harness_expect('s03 the read matches the write',res,true,null);
  if res#>'{data,windows}'<>(select coalesce(jsonb_agg(jsonb_build_object('weekday',weekday,
      'starts_minute',starts_minute,'ends_minute',ends_minute) order by weekday,starts_minute),'[]'::jsonb)
      from public.activity_location_schedules where location_id=l1) then
    raise exception 'FAIL s03 %',res; end if;

  -- 04 the same request replayed changes nothing
  res:=public.superadmin_location_schedule_set_v2(l1,week,v,rs);
  perform public.harness_expect('s04 replay is idempotent',res,true,null);
  if (res#>>'{data,management_version}')::bigint<>v+1
    or (select count(*) from public.activity_location_schedules where location_id=l1)<>3 then
    raise exception 'FAIL s04 %',res; end if;

  -- 05 a week that means the same thing written differently is the same request
  res:=public.superadmin_location_schedule_set_v2(l1,
    '[{"weekday":3,"starts_minute":480,"ends_minute":720},
      {"weekday":1,"starts_minute":780,"ends_minute":1020},
      {"weekday":1,"starts_minute":480,"ends_minute":720}]'::jsonb,v,rs);
  perform public.harness_expect('s05 reordering is not a different request',res,true,null);

  -- 06 the same request id carrying a different week is a different request
  res:=public.superadmin_location_schedule_set_v2(l1,'[]'::jsonb,v,rs);
  perform public.harness_expect('s06 request id reuse refused',res,false,'SAI_CONCURRENT_CHANGE');

  -- 07 a request id already spent on an edit cannot be respent on a schedule
  res:=public.superadmin_location_schedule_set_v2(l1,'[]'::jsonb,v+1,
    'bbbbbbbb-0000-4000-8000-000000000001');
  perform public.harness_expect('s07 request id is not reusable across verbs',res,false,'SAI_CONCURRENT_CHANGE');

  -- 08 a stale version loses and the published week survives untouched
  res:=public.superadmin_location_schedule_set_v2(l1,'[]'::jsonb,v,gen_random_uuid());
  perform public.harness_expect('s08 stale version refused',res,false,'SAI_CONCURRENT_CHANGE');
  if (select count(*) from public.activity_location_schedules where location_id=l1)<>3 then
    raise exception 'FAIL s08 the refused week was applied'; end if;

  -- 09 replacing is total: the old week does not survive alongside the new one
  res:=public.superadmin_location_schedule_set_v2(l1,
    '[{"weekday":5,"starts_minute":60,"ends_minute":120}]'::jsonb,v+1,gen_random_uuid());
  perform public.harness_expect('s09 a new week replaces the old one',res,true,null);
  if (select count(*) from public.activity_location_schedules where location_id=l1)<>1
    or (select weekday from public.activity_location_schedules where location_id=l1)<>5 then
    raise exception 'FAIL s09 leftovers'; end if;

  -- 10 clearing the week is publishing an empty week, not a failure
  res:=public.superadmin_location_schedule_set_v2(l1,'[]'::jsonb,v+2,gen_random_uuid());
  perform public.harness_expect('s10 an empty week clears the schedule',res,true,null);
  if (select count(*) from public.activity_location_schedules where location_id=l1)<>0 then
    raise exception 'FAIL s10 rows survived'; end if;

  -- 11 overlapping windows are refused before anything is written
  res:=public.superadmin_location_schedule_set_v2(l1,
    '[{"weekday":1,"starts_minute":480,"ends_minute":600},
      {"weekday":1,"starts_minute":540,"ends_minute":660}]'::jsonb,v+3,gen_random_uuid());
  perform public.harness_expect('s11 overlapping windows refused',res,false,'SAI_INVALID_ARGUMENT');
  if (select count(*) from public.activity_location_schedules where location_id=l1)<>0 then
    raise exception 'FAIL s11 a refused week was written'; end if;

  -- 12 an archived location publishes nothing
  res:=public.superadmin_location_set_status_v2(l1,'archived',v+3,gen_random_uuid());
  perform public.harness_expect('s12 archive succeeds',res,true,null);
  res:=public.superadmin_location_schedule_set_v2(l1,week,v+4,gen_random_uuid());
  perform public.harness_expect('s13 archived location publishes no schedule',res,false,'SAI_INVALID_ARGUMENT');
  res:=public.superadmin_location_set_status_v2(l1,'active',v+4,gen_random_uuid());
  perform public.harness_expect('s14 restore succeeds',res,true,null);
  v:=(res#>>'{data,management_version}')::bigint;

  -- 15 the windows leave with the location they belong to. Proven on a bare row,
  -- because any location these commands have written keeps a receipt, and that is
  -- what check 16 is about.
  insert into public.activity_locations(id,institution_id,unit_id,name,status,scope_kind,kind,
    visibility,created_by_internal_identity_id)
  values('aaaaaaaa-0000-4000-8000-00000000000f',i1,null,'Sala descartavel','active','institution',
    'internal','team','55555555-5555-4555-8555-555555555555');
  insert into public.activity_location_schedules(location_id,weekday,starts_minute,ends_minute,
    created_by_internal_identity_id)
  values('aaaaaaaa-0000-4000-8000-00000000000f',2,60,120,'55555555-5555-4555-8555-555555555555');
  delete from public.activity_locations where id='aaaaaaaa-0000-4000-8000-00000000000f';
  if exists(select 1 from public.activity_location_schedules
    where location_id='aaaaaaaa-0000-4000-8000-00000000000f') then
    raise exception 'FAIL s15 orphan windows'; end if;

  -- 16 a location any of these commands has written keeps its receipt, and the receipt
  -- refuses to lose its referent. That is inherited from the create package and it
  -- means such a row is never hard deleted; retiring it is what archiving is for.
  res:=public.superadmin_location_schedule_set_v2(l1,week,v,gen_random_uuid());
  perform public.harness_expect('s16 publish before attempting a delete',res,true,null);
  begin
    delete from public.activity_locations where id=l1;
    raise exception 'FAIL s16 a written location was hard deleted';
  exception when foreign_key_violation then null;
  end;

  -- 16 a caller who is not the Owner reaches neither command
  update app_private.harness_actor set role_code='support';
  res:=public.superadmin_location_schedule_v2(l2);
  perform public.harness_expect('s17 non owner cannot read',res,false,'SAI_PERMISSION_DENIED');
  res:=public.superadmin_location_schedule_set_v2(l2,'[]'::jsonb,1,gen_random_uuid());
  perform public.harness_expect('s18 non owner cannot publish',res,false,'SAI_PERMISSION_DENIED');
  update app_private.harness_actor set role_code='owner';

  -- 18 an Owner scoped to another institution reaches nothing either
  update app_private.harness_actor set scope_kind='institution',scope_institution_id=i2;
  res:=public.superadmin_location_schedule_v2(l2);
  perform public.harness_expect('s19 cross institution read denied',res,false,'SAI_PERMISSION_DENIED');
  update app_private.harness_actor set scope_kind='platform',scope_institution_id=null;

  -- 19 an unknown location is denied, not reported as missing
  res:=public.superadmin_location_schedule_v2(gen_random_uuid());
  perform public.harness_expect('s20 unknown location denied',res,false,'SAI_PERMISSION_DENIED');

  -- 20 an expired session invalidates the publication and leaves nothing behind
  update auth.sessions set not_after=now()-interval '1 minute';
  res:=public.superadmin_location_schedule_set_v2(l2,week,1,gen_random_uuid());
  perform public.harness_expect('s21 expired session refused',res,false,'SAI_SESSION_INVALID');
  if (select count(*) from public.activity_location_schedules where location_id=l2)<>0 then
    raise exception 'FAIL s20 the refused week was kept'; end if;
  update auth.sessions set not_after=now()+interval '1 day';

  -- 21 an unidentified caller is denied by the context itself
  update app_private.harness_actor set denied=true;
  res:=public.superadmin_location_schedule_set_v2(l2,week,1,gen_random_uuid());
  perform public.harness_expect('s22 denied context refused',res,false,'SAI_INTERNAL_CONTEXT_DENIED');
  update app_private.harness_actor set denied=false;

  raise notice '--- all schedule checks passed ---';
end
$scheduletests$;

do $scheduleaudit$
declare denied_count integer; success_count integer; wrong integer;
begin
  select count(*) into denied_count from app_private.harness_audit where outcome='denied';
  select count(*) into success_count from app_private.harness_audit where outcome='success';
  select count(*) into wrong from app_private.harness_audit
    where capability not in('locations.read','locations.schedule','locations.status')
      or action not in('location.schedule_read','location.schedule','location.status');
  raise notice 'schedule audit: % denied, % success, % off vocabulary',denied_count,success_count,wrong;
  -- Ten successes: s01, s02, s03, the s04 and s05 replays, s09, s10, s12, s14 and s16.
  -- Eleven refusals: s06, s07, s08, s11, s13, s17, s18, s19, s20, s21 and s22.
  if success_count<>10 or denied_count<>11 or wrong<>0 then
    raise exception 'FAIL schedule audit coverage';
  end if;
end
$scheduleaudit$;
