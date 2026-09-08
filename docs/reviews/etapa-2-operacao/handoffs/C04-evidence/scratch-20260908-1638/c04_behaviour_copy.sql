\set ON_ERROR_STOP on

do $seedb$
declare i1 uuid:='11111111-1111-4111-8111-111111111111';
  i2 uuid:='22222222-2222-4222-8222-222222222222';
begin
  insert into public.units(id,institution_id) values
    ('33333333-3333-4333-8333-333333333334',i1),
    ('33333333-3333-4333-8333-333333333335',i2);
  update app_private.harness_actor set role_code='owner',scope_kind='platform',
    scope_institution_id=null,denied=false;
  delete from app_private.harness_audit;
end
$seedb$;

do $copytests$
declare i1 uuid:='11111111-1111-4111-8111-111111111111';
  i2 uuid:='22222222-2222-4222-8222-222222222222';
  u1 uuid:='33333333-3333-4333-8333-333333333333';
  u2 uuid:='33333333-3333-4333-8333-333333333334';
  u3 uuid:='33333333-3333-4333-8333-333333333335';
  l1 uuid:='aaaaaaaa-0000-4000-8000-000000000001';
  l2 uuid:='aaaaaaaa-0000-4000-8000-000000000002';
  l3 uuid:='aaaaaaaa-0000-4000-8000-000000000003';
  rc uuid:='cccccccc-0000-4000-8000-000000000001';
  res jsonb; first_id uuid; second_id uuid;
begin
  -- 01 a copy into another unit of the same institution succeeds and starts fresh
  res:=public.superadmin_location_copy_v2(l1,'unit',i1,u2,'Sala Azul Cinco',rc);
  perform public.harness_expect('c01 copy into a sibling unit',res,true,null);
  first_id:=(res#>>'{data,id}')::uuid;
  if first_id=l1 then raise exception 'FAIL c01 returned the source'; end if;
  if res#>>'{data,status}'<>'active' or (res#>>'{data,management_version}')::bigint<>1 then
    raise exception 'FAIL c01 the copy did not start fresh: %',res; end if;
  if res#>>'{data,unit_id}' is distinct from u2::text then raise exception 'FAIL c01 owner %',res; end if;

  -- 02 provenance is recorded once, privately
  if not exists(select 1 from app_private.superadmin_location_copy_lineage
    where location_id=first_id and source_location_id=l1) then
    raise exception 'FAIL c02 no lineage'; end if;

  -- 03 the same request replayed returns the same row, not a second one
  res:=public.superadmin_location_copy_v2(l1,'unit',i1,u2,'Sala Azul Cinco',rc);
  perform public.harness_expect('c03 copy replay is idempotent',res,true,null);
  if (res#>>'{data,id}')::uuid<>first_id then raise exception 'FAIL c03 second row'; end if;
  if (select count(*) from app_private.superadmin_location_copy_lineage where source_location_id=l1)<>1 then
    raise exception 'FAIL c03 lineage duplicated'; end if;

  -- 04 the same request id carrying different arguments is a different request
  res:=public.superadmin_location_copy_v2(l1,'unit',i1,u2,'Outro nome',rc);
  perform public.harness_expect('c04 request id reuse refused',res,false,'SAI_CONCURRENT_CHANGE');

  -- 05 a request id already spent on an edit cannot be respent on a copy
  res:=public.superadmin_location_copy_v2(l1,'unit',i1,u2,'Mais um',
    'bbbbbbbb-0000-4000-8000-000000000001');
  perform public.harness_expect('c05 request id is not reusable across verbs',res,false,'SAI_CONCURRENT_CHANGE');

  -- 06 the two partial unique indexes are separate namespaces
  res:=public.superadmin_location_copy_v2(l1,'institution',i1,null,'Sala Azul Cinco',gen_random_uuid());
  perform public.harness_expect('c06 the same name is free at institution scope',res,true,null);
  second_id:=(res#>>'{data,id}')::uuid;
  if res#>>'{data,unit_id}' is not null then raise exception 'FAIL c06 kept a unit'; end if;

  -- 07 a copy onto the very same owner and name is not a copy
  res:=public.superadmin_location_copy_v2(l1,'unit',i1,u1,'Sala Azul Cinco',gen_random_uuid());
  perform public.harness_expect('c07 same owner and name refused',res,false,'SAI_INVALID_ARGUMENT');

  -- 08 nor onto a name a live sibling already holds
  res:=public.superadmin_location_copy_v2(l1,'unit',i1,u1,'Sala Verde',gen_random_uuid());
  perform public.harness_expect('c08 taken name refused',res,false,'SAI_INVALID_ARGUMENT');

  -- 09 a copy stays inside its institution
  res:=public.superadmin_location_copy_v2(l1,'unit',i2,u3,'Sala Azul Cinco',gen_random_uuid());
  perform public.harness_expect('c09 cross institution copy refused',res,false,'SAI_INVALID_ARGUMENT');
  if exists(select 1 from public.activity_locations where institution_id=i2) then
    raise exception 'FAIL c09 a row landed in the other institution'; end if;

  -- 10 an incoherent target owner is refused by the shared owner check
  res:=public.superadmin_location_copy_v2(l1,'unit',i1,null,'Sala Azul Cinco',gen_random_uuid());
  perform public.harness_expect('c10 unit scope without a unit refused',res,false,'SAI_PERMISSION_DENIED');
  res:=public.superadmin_location_copy_v2(l1,'institution',i1,u1,'Sala Azul Cinco',gen_random_uuid());
  perform public.harness_expect('c11 institution scope with a unit refused',res,false,'SAI_PERMISSION_DENIED');

  -- 12 the external source carries its address, and the normalizer still judges it
  res:=public.superadmin_location_copy_v2(l3,'unit',i1,u2,'Quadra coberta',gen_random_uuid());
  perform public.harness_expect('c12 external source copies its address',res,true,null);
  if res#>>'{data,kind}'<>'external' or res#>>'{data,address,city}'<>'Campinas' then
    raise exception 'FAIL c12 address lost: %',res; end if;

  -- 13 an archived source is a usable template and yields an active entry
  update public.activity_locations set status='archived' where id=l2;
  res:=public.superadmin_location_copy_v2(l2,'unit',i1,u2,'Sala Verde',gen_random_uuid());
  perform public.harness_expect('c13 archived source copies',res,true,null);
  if res#>>'{data,status}'<>'active' then raise exception 'FAIL c13 copied the archive'; end if;
  update public.activity_locations set status='active' where id=l2;

  -- 14 an unreachable source is denied, and nothing about it leaks
  res:=public.superadmin_location_copy_v2(gen_random_uuid(),'unit',i1,u2,'Fantasma',gen_random_uuid());
  perform public.harness_expect('c14 unknown source denied',res,false,'SAI_PERMISSION_DENIED');

  -- 15 an Owner scoped to another institution reaches neither source nor target
  update app_private.harness_actor set scope_kind='institution',scope_institution_id=i2;
  res:=public.superadmin_location_copy_v2(l1,'unit',i1,u2,'Fora de escopo',gen_random_uuid());
  perform public.harness_expect('c15 cross institution owner denied',res,false,'SAI_PERMISSION_DENIED');
  update app_private.harness_actor set scope_kind='platform',scope_institution_id=null;

  -- 16 a caller who is not the Owner reaches nothing
  update app_private.harness_actor set role_code='support';
  res:=public.superadmin_location_copy_v2(l1,'unit',i1,u2,'Sem papel',gen_random_uuid());
  perform public.harness_expect('c16 non owner denied',res,false,'SAI_PERMISSION_DENIED');
  update app_private.harness_actor set role_code='owner';

  -- 17 an expired session invalidates the copy and leaves nothing behind
  update auth.sessions set not_after=now()-interval '1 minute';
  res:=public.superadmin_location_copy_v2(l1,'unit',i1,u2,'Sessao morta',gen_random_uuid());
  perform public.harness_expect('c17 expired session refused',res,false,'SAI_SESSION_INVALID');
  if exists(select 1 from public.activity_locations where name='Sessao morta') then
    raise exception 'FAIL c17 the refused copy was kept'; end if;
  if exists(select 1 from app_private.superadmin_location_copy_lineage l
    join public.activity_locations a on a.id=l.location_id where a.name='Sessao morta') then
    raise exception 'FAIL c17 lineage survived a refused copy'; end if;
  update auth.sessions set not_after=now()+interval '1 day';

  -- 18 an unidentified caller is denied by the context itself
  update app_private.harness_actor set denied=true;
  res:=public.superadmin_location_copy_v2(l1,'unit',i1,u2,'Sem contexto',gen_random_uuid());
  perform public.harness_expect('c18 denied context refused',res,false,'SAI_INTERNAL_CONTEXT_DENIED');
  update app_private.harness_actor set denied=false;

  raise notice '--- all copy checks passed ---';
end
$copytests$;

do $copyaudit$
declare denied_count integer; success_count integer; wrong integer;
begin
  select count(*) into denied_count from app_private.harness_audit where outcome='denied';
  select count(*) into success_count from app_private.harness_audit where outcome='success';
  select count(*) into wrong from app_private.harness_audit
    where capability<>'locations.copy' or action<>'location.copy';
  raise notice 'copy audit: % denied, % success, % off vocabulary',denied_count,success_count,wrong;
  -- Five successes: c01, the c03 replay, c06, c12 and c13.
  -- Twelve refusals: c04, c05, c07, c08, c09, c10, c11, c14, c15, c16, c17, c18.
  if success_count<>5 or denied_count<>12 or wrong<>0 then
    raise exception 'FAIL copy audit coverage';
  end if;
end
$copyaudit$;
