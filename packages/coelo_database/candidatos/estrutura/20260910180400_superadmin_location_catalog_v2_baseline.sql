-- LOC-CATALOG01 LOCAL CANDIDATE. No remote lease or production capability provisioning.
-- Replay owner must supply the separately reviewed Owner-only capability fixture.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
set local search_path=public,pg_catalog;

do $preflight$
declare expected record; actual_oid oid; capability text; actual_columns text[]; actual_definition text;
begin
  if current_user<>'postgres' then
    raise insufficient_privilege using message='location candidate requires postgres';
  end if;
  if to_regclass('public.activity_locations') is null
    or to_regclass('app_private.superadmin_internal_identities') is null
    or to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or to_regprocedure('app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)') is null
    or to_regprocedure('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)') is null
    or to_regprocedure('app_private.superadmin_internal_error_envelope(text,uuid)') is null then
    raise object_not_in_prerequisite_state using message='location internal dependencies missing';
  end if;
  lock table public.activity_locations in access exclusive mode;
  if exists(select 1 from public.activity_locations) then
    raise object_not_in_prerequisite_state using message='location candidate requires empty catalog';
  end if;
  select array_agg(attname::text||':'||format_type(atttypid,atttypmod)||':'||attnotnull::text order by attnum)
    into actual_columns from pg_attribute
    where attrelid='public.activity_locations'::regclass and attnum>0 and not attisdropped;
  if actual_columns is distinct from array[
    'id:uuid:true','institution_id:uuid:true','unit_id:uuid:true','name:text:true',
    'description:text:false','status:record_status:true','management_version:bigint:true',
    'created_by_person_id:uuid:true','created_at:timestamp with time zone:true',
    'updated_at:timestamp with time zone:true'] then
    raise object_not_in_prerequisite_state using message='location column drift';
  end if;
  if not exists(select 1 from pg_class c join pg_roles r on r.oid=c.relowner
      where c.oid='public.activity_locations'::regclass and c.relrowsecurity
        and c.relforcerowsecurity and r.rolname='postgres')
    or (select count(*) from pg_constraint where conrelid='public.activity_locations'::regclass)<>8
    or (select count(*) from pg_index where indrelid='public.activity_locations'::regclass)<>4 then
    raise object_not_in_prerequisite_state using message='location relation security or constraint drift';
  end if;
  for expected in select * from (values
    ('activity_locations_created_by_person_id_fkey','FOREIGN KEY (created_by_person_id) REFERENCES people(id) ON DELETE RESTRICT'),
    ('activity_locations_description_check','CHECK (((description IS NULL) OR (length(description) <= 500)))'),
    ('activity_locations_id_institution_unit_key','UNIQUE (id, institution_id, unit_id)'),
    ('activity_locations_institution_id_fkey','FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE CASCADE'),
    ('activity_locations_management_version_check','CHECK ((management_version > 0))'),
    ('activity_locations_name_check',$def$CHECK (((btrim(name) <> ''::text) AND (length(name) <= 120)))$def$),
    ('activity_locations_pkey','PRIMARY KEY (id)'),
    ('activity_locations_unit_institution_fkey','FOREIGN KEY (unit_id, institution_id) REFERENCES units(id, institution_id) ON DELETE CASCADE')
  ) v(name,definition) loop
    if not exists(select 1 from pg_constraint where conrelid='public.activity_locations'::regclass
      and conname=expected.name and convalidated and pg_get_constraintdef(oid)=expected.definition) then
      raise object_not_in_prerequisite_state using message='location constraint definition drift';
    end if;
  end loop;
  if not exists(select 1 from pg_indexes where schemaname='public' and tablename='activity_locations'
    and indexname='activity_locations_active_name_uidx'
    and indexdef=$def$CREATE UNIQUE INDEX activity_locations_active_name_uidx ON public.activity_locations USING btree (unit_id, lower(name)) WHERE (status <> 'archived'::record_status)$def$)
    or (select count(*) from pg_policies where schemaname='public' and tablename='activity_locations')<>1
    or not exists(select 1 from pg_policies where schemaname='public' and tablename='activity_locations'
      and policyname='activity_locations_authorized_read' and cmd='SELECT'
      and roles=array['authenticated']::name[]
      and qual=$def$(( SELECT app_private.has_platform_permission('activities.read'::text) AS has_platform_permission) OR app_private.has_institution_permission(institution_id, 'activities.read'::text, unit_id, NULL::uuid, false))$def$) then
    raise object_not_in_prerequisite_state using message='location index or policy drift';
  end if;
  -- A versao historica comparava a ACL com um array literal de nove entradas.
  -- Aquilo era o retrato de uma cadeia local, nao um invariante: muda com a
  -- versao do Postgres (MAINTAIN so existe a partir do 17) e com qualquer
  -- concessao adicional legitima, e por isso barrava sobre a baseline de
  -- producao. A guarda passa a afirmar o que de fato importa para a seguranca
  -- desta tabela, sem depender de retrato: quem nao e service_role nem dono nao
  -- pode escrever, e nem anon nem PUBLIC podem qualquer coisa.
  if exists(
      select 1
      from pg_class c
      cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a
      left join pg_roles r on r.oid=a.grantee
      where c.oid='public.activity_locations'::regclass
        and a.grantee<>c.relowner
        and (
          -- grantee nulo em aclexplode e PUBLIC
          r.rolname is null
          or r.rolname='anon'
          or (r.rolname<>'service_role'
              and a.privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE'))
          or a.is_grantable
        )) then
    raise object_not_in_prerequisite_state using message='location table ACL drift';
  end if;
  for expected in select * from (values
    ('app_private.activity_management_payload(uuid)','dbfb21e52b0773a41815a0986be0d64f',false),
    ('app_private.superadmin_activity_directory(text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean)','f1809b1c0b268ed571eaaa958a061015',false),
    ('public.superadmin_activity_directory(text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean)','e1e94802dd59857459e6816c8b6a4069',true),
    ('app_private.superadmin_get_activity_form_options(uuid)','65fe6408f0f2c6b0c1c9d71a809f2d80',false),
    ('public.superadmin_get_activity_form_options(uuid)','4600bdfb92b0ea38f597947365750052',true),
    ('app_private.superadmin_create_activity_locations(uuid,uuid[],text,uuid)','886752274164d0d435c9df8ced18d896',false),
    ('public.superadmin_create_activity_locations(uuid,uuid[],text,uuid)','1898ddd4ec4ea12373e1c13c55336774',true)
  ) v(signature,hash,client_execute) loop
    actual_oid:=to_regprocedure(expected.signature);
    if actual_oid is null then
      raise object_not_in_prerequisite_state using message='location legacy helper fingerprint drift';
    end if;
    actual_definition:=pg_get_functiondef(actual_oid);
    if expected.signature='app_private.superadmin_create_activity_locations(uuid,uuid[],text,uuid)' then
      -- Only this signature: remote/catalog and canonical prosrc are identical
      -- after CRLF -> LF. Mixed EOL explains raw drift (evidence 25cd74a9).
      -- Do not trim or normalize any other helper, especially options #4.
      if md5(replace(actual_definition,E'\r\n',E'\n'))<>'3167d90039df952c9ae561f28486223c'
        or (select pg_get_userbyid(proowner) from pg_proc where oid=actual_oid)<>'postgres' then
        raise object_not_in_prerequisite_state using message='location legacy writer fingerprint drift';
      end if;
    elsif md5(actual_definition)<>expected.hash then
      raise object_not_in_prerequisite_state using message='location legacy helper fingerprint drift';
    end if;
    if expected.signature='app_private.superadmin_get_activity_form_options(uuid)'
      and not exists(select 1 from pg_proc where oid=actual_oid
        and pg_get_userbyid(proowner)='postgres' and prosecdef and provolatile='s'
        and proconfig=array['search_path=""']::text[]) then
      raise object_not_in_prerequisite_state using message='location legacy options metadata drift';
    end if;
    if (select coalesce(array_agg(coalesce(r.rolname,'PUBLIC')::text||':'||a.privilege_type||':'||a.is_grantable::text order by r.rolname),'{}'::text[])
        from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
        left join pg_roles r on r.oid=a.grantee where p.oid=actual_oid and a.grantee<>p.proowner)
      is distinct from (case when expected.client_execute then array['authenticated:EXECUTE:false'] else '{}'::text[] end) then
      raise object_not_in_prerequisite_state using message='location legacy helper ACL drift';
    end if;
  end loop;
  foreach capability in array array['locations.read','locations.create'] loop
    if not exists(select 1 from public.platform_permissions where code=capability and status='active')
      or (select array_agg(r.code order by r.code) from public.platform_role_permissions rp
        join public.platform_roles r on r.id=rp.role_id and r.status='active'
        join public.platform_permissions p on p.id=rp.permission_id
        where p.code=capability and rp.effect='allow' and rp.status='active' and rp.revoked_at is null)
        is distinct from array['owner']::text[] then
      raise object_not_in_prerequisite_state using message='location candidate requires separate Owner-only capability fixture';
    end if;
  end loop;
  if app_private.superadmin_internal_error_envelope('SAI_INVALID_ARGUMENT',gen_random_uuid())#>>'{error,code}'
      is distinct from 'SAI_INVALID_ARGUMENT'
    or app_private.superadmin_internal_error_envelope('SAI_CONCURRENT_CHANGE',gen_random_uuid())#>>'{error,code}'
      is distinct from 'SAI_CONCURRENT_CHANGE' then
    raise object_not_in_prerequisite_state using message='location error envelope dependency missing';
  end if;
  if to_regclass('app_private.superadmin_location_create_receipts') is not null
    or exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname in('public','app_private') and p.proname in(
        'superadmin_location_normalize_v2','superadmin_location_owner_v2',
        'superadmin_location_payload_v2','superadmin_location_create_v2',
        'superadmin_location_detail_v2','superadmin_location_directory_v2')) then
    raise duplicate_object using message='location candidate objects already exist';
  end if;
end
$preflight$;

alter table public.activity_locations
  alter column unit_id drop not null,
  alter column created_by_person_id drop not null,
  add column scope_kind text not null check(scope_kind in('institution','unit')),
  add column kind text not null check(kind in('internal','external')),
  add column floor text check(floor is null or length(floor)<=120),
  add column address jsonb,
  add column visibility text not null check(visibility in('team','guardians','students','all')),
  add column created_by_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id) on delete restrict,
  add constraint activity_locations_owner_scope_check check(
    (scope_kind='institution' and unit_id is null) or (scope_kind='unit' and unit_id is not null)),
  add constraint activity_locations_author_xor_check check(
    num_nonnulls(created_by_person_id,created_by_internal_identity_id)=1);
create unique index activity_locations_institution_name_uidx
  on public.activity_locations(institution_id,lower(name))
  where unit_id is null and status<>'archived';
create index activity_locations_internal_author_idx
  on public.activity_locations(created_by_internal_identity_id)
  where created_by_internal_identity_id is not null;
revoke all on public.activity_locations from public,anon,authenticated;
revoke all on public.activity_locations from service_role;
drop policy activity_locations_authorized_read on public.activity_locations;

create table app_private.superadmin_location_create_receipts(
  actor_internal_identity_id uuid not null references app_private.superadmin_internal_identities(id) on delete restrict,
  request_id uuid not null,
  request_hash bytea not null check(octet_length(request_hash)=32),
  location_id uuid not null references public.activity_locations(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key(actor_internal_identity_id,request_id)
);
create index superadmin_location_receipt_location_idx
  on app_private.superadmin_location_create_receipts(location_id);
alter table app_private.superadmin_location_create_receipts enable row level security;
alter table app_private.superadmin_location_create_receipts force row level security;
revoke all on app_private.superadmin_location_create_receipts from public,anon,authenticated,service_role;

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
revoke all on function app_private.superadmin_location_normalize_v2(jsonb)
  from public,anon,authenticated,service_role;

alter table public.activity_locations add constraint activity_locations_normalized_payload_check check(
  app_private.superadmin_location_normalize_v2(jsonb_build_object(
    'scope_kind',scope_kind,'institution_id',institution_id,'unit_id',unit_id,
    'name',name,'description',description,'kind',kind,'floor',floor,'address',address,'visibility',visibility))
  =jsonb_build_object('scope_kind',scope_kind,'institution_id',institution_id,'unit_id',unit_id,
    'name',name,'description',description,'kind',kind,'floor',floor,'address',address,'visibility',visibility));

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
revoke all on function app_private.superadmin_location_owner_v2(app_private.superadmin_internal_context,text,uuid,uuid)
  from public,anon,authenticated,service_role;

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
revoke all on function app_private.superadmin_location_payload_v2(uuid)
  from public,anon,authenticated,service_role;

create function public.superadmin_location_detail_v2(p_location_id uuid)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare ctx app_private.superadmin_internal_context; target public.activity_locations%rowtype;
  initial_actor_id uuid; initial_session_id uuid;
  result jsonb; correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.read');
    if current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using message='location isolation unsupported',detail='SAI_INVALID_ARGUMENT';
    end if;
    initial_actor_id:=ctx.internal_identity_id;
    initial_session_id:=ctx.session_id;
    select l.* into target from public.activity_locations l where l.id=p_location_id
      and ctx.platform_role_code='owner'
      and (ctx.scope_kind='platform' or
        (ctx.scope_kind='institution' and ctx.scope_institution_id=l.institution_id)) for share;
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.read');
    if ctx.internal_identity_id is distinct from initial_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    if ctx.session_id is distinct from initial_session_id or not exists(
      select 1 from auth.sessions session_record where session_record.id=initial_session_id
        and (session_record.not_after is null or session_record.not_after>clock_timestamp())) then
      raise insufficient_privilege using message='location session invalid',detail='SAI_SESSION_INVALID';
    end if;
    result:=app_private.superadmin_location_payload_v2(target.id);
  exception when insufficient_privilege then
    get stacked diagnostics error_detail=pg_exception_detail;
    error_code:=case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
      then error_detail else 'SAI_INTERNAL_ERROR' end;
  when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
  when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'locations.read','location.detail',error_code,correlation,null);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
    ctx.internal_membership_id,ctx.session_id,'locations.read',ctx.aal,'location.detail','success',null,
    correlation,target.institution_id,'location',target.id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;
revoke all on function public.superadmin_location_detail_v2(uuid) from public,anon,authenticated,service_role;
grant execute on function public.superadmin_location_detail_v2(uuid) to authenticated;

create function public.superadmin_location_directory_v2(
  p_scope_kind text,p_institution_id uuid,p_unit_id uuid default null,
  p_search text default null,p_limit integer default 24,p_offset integer default 0
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare ctx app_private.superadmin_internal_context; result jsonb; normalized_search text;
  initial_actor_id uuid; initial_session_id uuid;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.read');
    if current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using message='location isolation unsupported',detail='SAI_INVALID_ARGUMENT';
    end if;
    initial_actor_id:=ctx.internal_identity_id;
    initial_session_id:=ctx.session_id;
    perform app_private.superadmin_location_owner_v2(ctx,p_scope_kind,p_institution_id,p_unit_id);
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.read');
    if ctx.internal_identity_id is distinct from initial_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    perform app_private.superadmin_location_owner_v2(ctx,p_scope_kind,p_institution_id,p_unit_id);
    if ctx.session_id is distinct from initial_session_id or not exists(
      select 1 from auth.sessions session_record where session_record.id=initial_session_id
        and (session_record.not_after is null or session_record.not_after>clock_timestamp())) then
      raise insufficient_privilege using message='location session invalid',detail='SAI_SESSION_INVALID';
    end if;
    normalized_search:=nullif(btrim(p_search),'');
    if p_limit is null or p_limit not between 1 and 100 or p_offset is null or p_offset not between 0 and 10000
      or length(normalized_search)>120 or normalized_search ~ U&'[\0001-\001f\007f]' then
      raise invalid_parameter_value using message='invalid location directory',detail='SAI_INVALID_ARGUMENT';
    end if;
    with filtered as materialized (
      select l.id,l.name from public.activity_locations l
      where l.scope_kind=p_scope_kind and l.institution_id=p_institution_id
        and l.unit_id is not distinct from p_unit_id
        and (normalized_search is null or position(lower(normalized_search) in lower(l.name))>0)
    ), page as (
      select * from filtered order by lower(name) collate "C",id limit p_limit offset p_offset
    ) select jsonb_build_object('items',coalesce((select jsonb_agg(
        app_private.superadmin_location_payload_v2(page.id) order by lower(page.name) collate "C",page.id)
        from page),'[]'::jsonb),'total_count',(select count(*) from filtered)) into result;
  exception when insufficient_privilege then
    get stacked diagnostics error_detail=pg_exception_detail;
    error_code:=case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
      then error_detail else 'SAI_INTERNAL_ERROR' end;
  when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
  when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'locations.read','location.directory',error_code,correlation,null);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
    ctx.internal_membership_id,ctx.session_id,'locations.read',ctx.aal,'location.directory','success',null,
    correlation,p_institution_id,'location_catalog',coalesce(p_unit_id,p_institution_id));
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;
revoke all on function public.superadmin_location_directory_v2(text,uuid,uuid,text,integer,integer)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_location_directory_v2(text,uuid,uuid,text,integer,integer)
  to authenticated;

create function public.superadmin_location_create_v2(p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare ctx app_private.superadmin_internal_context; normalized jsonb; result jsonb;
  receipt app_private.superadmin_location_create_receipts%rowtype;
  target public.activity_locations%rowtype;
  requested_hash bytea; location_id uuid; institution_id uuid; unit_id uuid; locked_actor_id uuid;
  initial_session_id uuid;
  correlation uuid:=gen_random_uuid(); error_code text; error_detail text;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.create');
    initial_session_id:=ctx.session_id;
    if current_setting('transaction_isolation')<>'read committed' then
      raise invalid_parameter_value using message='location isolation unsupported',detail='SAI_INVALID_ARGUMENT';
    end if;
    if p_request_id is null then
      raise invalid_parameter_value using message='location request id required',detail='SAI_INVALID_ARGUMENT';
    end if;
    normalized:=app_private.superadmin_location_normalize_v2(p_payload);
    institution_id:=(normalized->>'institution_id')::uuid;
    unit_id:=(normalized->>'unit_id')::uuid;
    perform app_private.superadmin_location_owner_v2(ctx,normalized->>'scope_kind',institution_id,unit_id);
    requested_hash:=extensions.digest(convert_to(normalized::text,'UTF8'),'sha256');
    locked_actor_id:=ctx.internal_identity_id;
    perform pg_advisory_xact_lock(hashtextextended(locked_actor_id::text||':'||p_request_id::text,0));
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.create');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    perform app_private.superadmin_location_owner_v2(ctx,normalized->>'scope_kind',institution_id,unit_id);
    select r.* into receipt from app_private.superadmin_location_create_receipts r
      where r.actor_internal_identity_id=ctx.internal_identity_id and r.request_id=p_request_id;
    if found then
      if receipt.request_hash is distinct from requested_hash then
        raise serialization_failure using message='location request already used',detail='SAI_CONCURRENT_CHANGE';
      end if;
      location_id:=receipt.location_id;
      select l.* into target from public.activity_locations l where l.id=location_id
        and ctx.platform_role_code='owner'
        and (ctx.scope_kind='platform' or
          (ctx.scope_kind='institution' and ctx.scope_institution_id=l.institution_id)) for share;
      perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
      institution_id:=target.institution_id;
    else
      insert into public.activity_locations(scope_kind,institution_id,unit_id,name,description,kind,floor,address,
        visibility,created_by_internal_identity_id)
      values(normalized->>'scope_kind',institution_id,unit_id,normalized->>'name',normalized->>'description',
        normalized->>'kind',normalized->>'floor',nullif(normalized->'address','null'::jsonb),
        normalized->>'visibility',ctx.internal_identity_id)
      returning id into location_id;
      insert into app_private.superadmin_location_create_receipts(actor_internal_identity_id,request_id,request_hash,location_id)
        values(ctx.internal_identity_id,p_request_id,requested_hash,location_id);
    end if;
    -- Receipt/resource locks and INSERT may also wait after the advisory lock.
    select l.* into target from public.activity_locations l where l.id=location_id for share;
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.create');
    if ctx.internal_identity_id is distinct from locked_actor_id then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    perform app_private.superadmin_location_owner_v2(ctx,target.scope_kind,target.institution_id,target.unit_id);
    institution_id:=target.institution_id;
    if ctx.session_id is distinct from initial_session_id or not exists(
      select 1 from auth.sessions session_record where session_record.id=initial_session_id
        and (session_record.not_after is null or session_record.not_after>clock_timestamp())) then
      raise insufficient_privilege using message='location session invalid',detail='SAI_SESSION_INVALID';
    end if;
    result:=app_private.superadmin_location_payload_v2(location_id);
    if result is null then
      raise insufficient_privilege using message='location access denied',detail='SAI_PERMISSION_DENIED';
    end if;
  exception when insufficient_privilege then
    get stacked diagnostics error_detail=pg_exception_detail;
    error_code:=case when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
      then error_detail else 'SAI_INTERNAL_ERROR' end;
  when invalid_parameter_value then error_code:='SAI_INVALID_ARGUMENT';
  when unique_violation or serialization_failure then error_code:='SAI_CONCURRENT_CHANGE';
  when others then error_code:='SAI_INTERNAL_ERROR';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'locations.create','location.create',error_code,correlation,null);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,
    ctx.internal_membership_id,ctx.session_id,'locations.create',ctx.aal,'location.create','success',null,
    correlation,institution_id,'location',location_id);
  return jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;
revoke all on function public.superadmin_location_create_v2(jsonb,uuid) from public,anon,authenticated,service_role;
grant execute on function public.superadmin_location_create_v2(jsonb,uuid) to authenticated;

-- E2E5 review required. Fingerprints above bind each edit to its exact legacy helper.
-- Only fixed, reviewed catalog expressions are replaced; all other activity behavior remains.
do $legacy_closure$
declare change record; definition text; changed text; matches_count integer;
  matched_block text; block_start integer;
begin
  for change in select * from (values
    ('app_private.activity_management_payload(uuid)',
      $pattern$'location_names',coalesce\(\(select jsonb_agg\(distinct location.name order by location.name\).*?and location.status='active'\),'\[\]'::jsonb\)$pattern$,
      $replacement$'location_names','[]'::jsonb$replacement$),
    ('app_private.activity_management_payload(uuid)',
      $pattern$'locations',coalesce\(\(select jsonb_agg\(to_jsonb\(location\) order by location.name\).*?where location.status='active'\),'\[\]'::jsonb\)$pattern$,
      $replacement$'locations','[]'::jsonb$replacement$),
    ('app_private.superadmin_activity_directory(text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean)',
      $pattern$coalesce\(\(select jsonb_agg\(distinct location.name order by location.name\).*?where unit_link.activity_id=activity.id and unit_link.status='active'\),'\[\]'::jsonb\)[[:space:]]+location_names$pattern$,
      $replacement$'[]'::jsonb location_names$replacement$),
    ('app_private.superadmin_get_activity_form_options(uuid)',
      $pattern$'locations',coalesce\(\(select jsonb_agg\(jsonb_build_object\([[:space:]]*'id',location\.id,'unit_id',location\.unit_id,'name',location\.name\) order by location\.name\)[[:space:]]*from public\.activity_locations location where \(p_institution_id is null[[:space:]]*or location\.institution_id=p_institution_id\) and location\.status='active'\),'\[\]'::jsonb\)$pattern$,
      $replacement$'locations','[]'::jsonb$replacement$)
  ) v(signature,pattern,replacement) loop
    definition:=pg_get_functiondef(to_regprocedure(change.signature));
    select count(*) into matches_count from regexp_matches(definition,change.pattern,'gs');
    if matches_count<>1 then
      raise object_not_in_prerequisite_state using message='location legacy closure pattern drift';
    end if;
    changed:=regexp_replace(definition,change.pattern,change.replacement,'gs');
    if changed=definition then
      raise object_not_in_prerequisite_state using message='location legacy closure made no change';
    end if;
    if change.signature='app_private.superadmin_get_activity_form_options(uuid)' then
      matched_block:=substring(definition from change.pattern);
      block_start:=position(matched_block in definition);
      if matched_block is null or block_start<1
        or changed is distinct from
          left(definition,block_start-1)||change.replacement||
          substring(definition from block_start+length(matched_block))
        or md5(changed)<>'2486e539f723d3f61cd9f29984efcbb2' then
        raise object_not_in_prerequisite_state using message='location options cutover byte drift';
      end if;
    end if;
    execute changed;
    if change.signature='app_private.superadmin_get_activity_form_options(uuid)'
      and md5(pg_get_functiondef(to_regprocedure(change.signature)))<>'2486e539f723d3f61cd9f29984efcbb2' then
      raise object_not_in_prerequisite_state using message='location options output fingerprint drift';
    end if;
  end loop;
  for change in select unnest(array[
    'app_private.activity_management_payload(uuid)',
    'app_private.superadmin_activity_directory(text,uuid[],uuid[],uuid[],text[],text[],integer,integer,text,boolean)',
    'app_private.superadmin_get_activity_form_options(uuid)']) as signature loop
    if position('public.activity_locations' in pg_get_functiondef(to_regprocedure(change.signature)))>0 then
      raise object_not_in_prerequisite_state using message='location legacy discovery remains';
    end if;
  end loop;
end
$legacy_closure$;

create or replace function app_private.superadmin_create_activity_locations(
  p_institution_id uuid,p_unit_ids uuid[],p_name text,p_idempotency_key uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
begin
  raise insufficient_privilege using message='legacy location creation unavailable';
end
$$;
revoke all on function app_private.superadmin_create_activity_locations(uuid,uuid[],text,uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.superadmin_create_activity_locations(uuid,uuid[],text,uuid)
  from public,anon,authenticated,service_role;
commit;
