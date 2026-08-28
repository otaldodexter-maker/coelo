begin;
create extension if not exists pgtap with schema extensions;
select plan(47);

select has_function(
  'public',
  'superadmin_institution_edit_core_v2',
  array['uuid','uuid','bigint','jsonb'],
  'Institution EDIT CORE v2 has the approved public signature'
);

select has_table(
  'app_private',
  'superadmin_internal_institution_edit_receipts',
  'Institution EDIT CORE v2 has a separate internal-identity receipt'
);

select has_function(
  'app_private',
  'superadmin_institution_edit_core_validate_v2',
  array['jsonb'],
  'Institution EDIT CORE v2 has a private payload validator'
);

select has_function(
  'app_private',
  'superadmin_institution_edit_core_request_hash_v2',
  array['uuid','bigint','jsonb'],
  'Institution EDIT CORE v2 has a private canonical request hash'
);

select ok(
  pg_get_functiondef(
    'public.superadmin_institution_edit_core_v2(uuid,uuid,bigint,jsonb)'::regprocedure
  ) like '%require_superadmin_internal_context%'
  and pg_get_functiondef(
    'public.superadmin_institution_edit_core_v2(uuid,uuid,bigint,jsonb)'::regprocedure
  ) not like '%current_person_id%'
  and pg_get_functiondef(
    'app_private.superadmin_institution_edit_core_validate_v2(jsonb)'::regprocedure
  ) not like '%contact%',
  'the wrapper uses only internal authority and the validator is ROOT+ADDRESS only'
);

with expected(procedure_oid,security_definer) as(values
  ('public.superadmin_institution_edit_core_v2(uuid,uuid,bigint,jsonb)'::regprocedure,true),
  ('app_private.superadmin_institution_edit_core_validate_v2(jsonb)'::regprocedure,false),
  ('app_private.superadmin_institution_edit_core_request_hash_v2(uuid,bigint,jsonb)'::regprocedure,false),
  ('app_private.superadmin_institution_edit_core_apply_v2(uuid,uuid,bigint,jsonb,bytea,app_private.superadmin_internal_context,uuid)'::regprocedure,true)
)
select ok(
  not exists(
    select 1
    from expected
    join pg_proc procedure_record on procedure_record.oid=expected.procedure_oid
    join pg_roles owner_role on owner_role.oid=procedure_record.proowner
    where owner_role.rolname<>'postgres'
      or procedure_record.prosecdef is distinct from expected.security_definer
      or not(coalesce(procedure_record.proconfig,'{}'::text[])
        @> array['search_path=""']::text[])
  )
  and (select owner_role.rolname
    from pg_class table_record
    join pg_namespace namespace_record on namespace_record.oid=table_record.relnamespace
    join pg_roles owner_role on owner_role.oid=table_record.relowner
    where namespace_record.nspname='app_private'
      and table_record.relname='superadmin_internal_institution_edit_receipts'
  )='postgres',
  'all edit objects have the approved owners, security mode and empty search_path'
);

select ok(
  has_function_privilege('authenticated',
    'public.superadmin_institution_edit_core_v2(uuid,uuid,bigint,jsonb)','execute')
  and not has_function_privilege('anon',
    'public.superadmin_institution_edit_core_v2(uuid,uuid,bigint,jsonb)','execute')
  and not has_function_privilege('service_role',
    'public.superadmin_institution_edit_core_v2(uuid,uuid,bigint,jsonb)','execute')
  and not exists(
    select 1 from pg_proc procedure_record,
      lateral aclexplode(coalesce(procedure_record.proacl,
        acldefault('f',procedure_record.proowner))) acl
    where procedure_record.oid=
      'public.superadmin_institution_edit_core_v2(uuid,uuid,bigint,jsonb)'::regprocedure
      and acl.grantee=0 and acl.privilege_type='EXECUTE'
  ),
  'only authenticated executes the public edit wrapper'
);

with helpers(procedure_oid) as(values
  ('app_private.superadmin_institution_edit_core_validate_v2(jsonb)'::regprocedure),
  ('app_private.superadmin_institution_edit_core_request_hash_v2(uuid,bigint,jsonb)'::regprocedure),
  ('app_private.superadmin_institution_edit_core_apply_v2(uuid,uuid,bigint,jsonb,bytea,app_private.superadmin_internal_context,uuid)'::regprocedure)
),client_roles(role_name) as(values('anon'),('authenticated'),('service_role'))
select ok(
  not exists(
    select 1 from helpers cross join client_roles
    where has_function_privilege(role_name,procedure_oid,'execute')
  )
  and not exists(
    select 1 from helpers
    join pg_proc procedure_record on procedure_record.oid=procedure_oid
    cross join lateral aclexplode(coalesce(procedure_record.proacl,
      acldefault('f',procedure_record.proowner))) acl
    where acl.grantee=0 and acl.privilege_type='EXECUTE'
  ),
  'no client or service role executes private edit helpers'
);

select ok(
  (select table_record.relrowsecurity and table_record.relforcerowsecurity
   from pg_class table_record
   join pg_namespace namespace_record on namespace_record.oid=table_record.relnamespace
   where namespace_record.nspname='app_private'
     and table_record.relname='superadmin_internal_institution_edit_receipts')
  and not exists(
    select 1 from pg_policies
    where schemaname='app_private'
      and tablename='superadmin_internal_institution_edit_receipts'
  )
  and not exists(
    select 1 from information_schema.role_table_grants
    where table_schema='app_private'
      and table_name='superadmin_internal_institution_edit_receipts'
      and grantee in('PUBLIC','anon','authenticated','service_role')
  ),
  'the receipt enables and forces deny-by-default RLS with zero client grants'
);

select ok(
  (select count(*)=8 and bool_and(column_record.is_nullable='NO')
    and array_agg(column_record.column_name||':'||column_record.udt_name
      order by column_record.ordinal_position)=array[
        'request_id:uuid',
        'actor_internal_identity_id:uuid',
        'institution_id:uuid',
        'expected_version:int8',
        'request_hash:bytea',
        'result_management_version:int8',
        'original_correlation_id:uuid',
        'created_at:timestamptz'
      ]::text[]
   from information_schema.columns column_record
   where column_record.table_schema='app_private'
     and column_record.table_name='superadmin_internal_institution_edit_receipts')
  and (select count(*)=2 and bool_and(constraint_record.confdeltype='a')
    from pg_constraint constraint_record
    where constraint_record.conrelid=
      'app_private.superadmin_internal_institution_edit_receipts'::regclass
      and constraint_record.contype='f')
  and exists(
    select 1 from pg_constraint constraint_record
    where constraint_record.conrelid=
      'app_private.superadmin_internal_institution_edit_receipts'::regclass
      and pg_get_constraintdef(constraint_record.oid)
        like '%octet_length(request_hash) = 32%'
  )
  and exists(
    select 1 from pg_constraint constraint_record
    where constraint_record.conrelid=
      'app_private.superadmin_internal_institution_edit_receipts'::regclass
      and pg_get_constraintdef(constraint_record.oid)
        like '%result_management_version = (expected_version + 1)%'
  ),
  'receipt columns, non-cascading FKs, hash length and version invariants are physical'
);

select ok(
  (select count(*)=3
   from pg_indexes
   where schemaname='app_private'
     and tablename='superadmin_internal_institution_edit_receipts')
  and exists(
    select 1 from pg_indexes
    where schemaname='app_private'
      and tablename='superadmin_internal_institution_edit_receipts'
      and indexdef like '%(actor_internal_identity_id)%'
  )
  and exists(
    select 1 from pg_indexes
    where schemaname='app_private'
      and tablename='superadmin_internal_institution_edit_receipts'
      and indexdef like '%(institution_id)%'
  )
  and not exists(
    select 1 from pg_indexes
    where schemaname='app_private'
      and tablename='superadmin_internal_institution_edit_receipts'
      and indexdef like '%created_at%'
  ),
  'receipt has only PK and lookup indexes, with no temporal or purge index'
);

select is(
  app_private.superadmin_institution_edit_core_validate_v2(
    $json${
      "public_name":"  Nome sintético  ","trade_name":"  ",
      "timezone":"UTC","locale":"pt-BR",
      "institution_type_id":"71000000-0000-4000-8000-000000000001",
      "address":{"country":"  Brasil  ","city":"  Recife  ",
        "complement":"","postal_code":"50000000"}
    }$json$::jsonb
  ),
  $json${
    "public_name":"Nome sintético","trade_name":null,
    "timezone":"UTC","locale":"pt-BR",
    "institution_type_id":"71000000-0000-4000-8000-000000000001",
    "address":{"country":"Brasil","city":"Recife",
      "complement":null,"postal_code":"50000000"}
  }$json$::jsonb,
  'validator trims strings, normalizes optional blanks and preserves canonical JSONB'
);

select is(
  app_private.superadmin_institution_edit_core_request_hash_v2(
    '72000000-0000-4000-8000-000000000001',1,
    '{"public_name":"Nome sintético"}'::jsonb
  ),
  extensions.digest(pg_catalog.convert_to(pg_catalog.jsonb_build_object(
    'command_kind','institution.edit_core',
    'institution_id','72000000-0000-4000-8000-000000000001'::uuid,
    'expected_version',1,
    'payload','{"public_name":"Nome sintético"}'::jsonb
  )::text,'UTF8'),'sha256'),
  'request digest is exactly SHA-256 over the canonical manifest and excludes request_id'
);

create function pg_temp.edit_validation_error(p_payload jsonb)
returns text language plpgsql as $$
declare error_detail text;
begin
  perform app_private.superadmin_institution_edit_core_validate_v2(p_payload);
  return null;
exception when others then
  get stacked diagnostics error_detail=pg_exception_detail;
  return sqlstate||':'||coalesce(error_detail,'');
end
$$;

create temporary table edit_invalid_payloads(
  category text not null,
  payload jsonb
);
insert into edit_invalid_payloads(category,payload) values
  ('container',null),
  ('container','[]'::jsonb),
  ('container','{}'::jsonb),
  ('container',jsonb_build_object('trade_name',repeat('x',65537))),
  ('forbidden','{"contact":{"email":"x@invalid.test"}}'::jsonb),
  ('forbidden','{"status":"active"}'::jsonb),
  ('forbidden','{"slug":"forbidden"}'::jsonb),
  ('forbidden','{"document_ref":"forbidden"}'::jsonb),
  ('forbidden','{"document_type":"forbidden"}'::jsonb),
  ('forbidden','{"primary_domain":"forbidden.invalid"}'::jsonb),
  ('forbidden','{"subscription":{}}'::jsonb),
  ('forbidden','{"branding":{}}'::jsonb),
  ('scalar','{"public_name":7}'::jsonb),
  ('scalar','{"public_name":null}'::jsonb),
  ('scalar','{"public_name":"  "}'::jsonb),
  ('scalar','{"timezone":null}'::jsonb),
  ('scalar','{"locale":""}'::jsonb),
  ('scalar','{"address":{"state":true}}'::jsonb),
  ('scalar','{"address":{"country":null}}'::jsonb),
  ('scalar',jsonb_build_object('public_name',E'line\nbreak')),
  ('root_limit',jsonb_build_object('public_name',repeat('x',241))),
  ('root_limit',jsonb_build_object('trade_name',repeat('x',241))),
  ('root_limit',jsonb_build_object('timezone',repeat('x',65))),
  ('root_limit',jsonb_build_object('locale',repeat('x',36))),
  ('locale_timezone','{"timezone":"Mars/Olympus"}'::jsonb),
  ('locale_timezone','{"locale":"pt_BR"}'::jsonb),
  ('uuid','{"institution_type_id":"not-a-uuid"}'::jsonb),
  ('address_shape','{"address":[]}'::jsonb),
  ('address_shape','{"address":{}}'::jsonb),
  ('address_shape','{"address":{"unknown":"x"}}'::jsonb),
  ('address_limit',jsonb_build_object('address',
    jsonb_build_object('state',repeat('x',241)))),
  ('address_limit',jsonb_build_object('address',
    jsonb_build_object('number',repeat('x',65)))),
  ('address_limit',jsonb_build_object('address',
    jsonb_build_object('country',repeat('x',81)))),
  ('brasil_cep','{"address":{"country":"BR"}}'::jsonb),
  ('brasil_cep','{"address":{"postal_code":"12345-678"}}'::jsonb);

select ok(not exists(
  select 1 from edit_invalid_payloads
  where category='container'
    and pg_temp.edit_validation_error(payload)<>'22023:SAI_INVALID_ARGUMENT'
), 'validator rejects null, non-object, empty and payloads over 65536 bytes');
select ok(not exists(
  select 1 from edit_invalid_payloads
  where category='forbidden'
    and pg_temp.edit_validation_error(payload)<>'22023:SAI_INVALID_ARGUMENT'
), 'validator rejects contact, document, domain, status, subscription and branding keys');
select ok(not exists(
  select 1 from edit_invalid_payloads
  where category='scalar'
    and pg_temp.edit_validation_error(payload)<>'22023:SAI_INVALID_ARGUMENT'
), 'validator rejects wrong JSON scalar types and control characters');
select ok(not exists(
  select 1 from edit_invalid_payloads
  where category='root_limit'
    and pg_temp.edit_validation_error(payload)<>'22023:SAI_INVALID_ARGUMENT'
), 'validator enforces every root text byte limit');
select ok(not exists(
  select 1 from edit_invalid_payloads
  where category='locale_timezone'
    and pg_temp.edit_validation_error(payload)<>'22023:SAI_INVALID_ARGUMENT'
), 'validator requires an existing timezone and the approved basic BCP-47 locale');
select ok(not exists(
  select 1 from edit_invalid_payloads
  where category='uuid'
    and pg_temp.edit_validation_error(payload)<>'22023:SAI_INVALID_ARGUMENT'
), 'validator rejects malformed institution type UUID strings');
select ok(not exists(
  select 1 from edit_invalid_payloads
  where category='address_shape'
    and pg_temp.edit_validation_error(payload)<>'22023:SAI_INVALID_ARGUMENT'
), 'validator requires a non-empty address object with only approved keys');
select ok(not exists(
  select 1 from edit_invalid_payloads
  where category='address_limit'
    and pg_temp.edit_validation_error(payload)<>'22023:SAI_INVALID_ARGUMENT'
), 'validator enforces address text byte limits');
select ok(not exists(
  select 1 from edit_invalid_payloads
  where category='brasil_cep'
    and pg_temp.edit_validation_error(payload)<>'22023:SAI_INVALID_ARGUMENT'
), 'validator enforces country Brasil and an exact eight-digit CEP');

insert into public.institution_types(id,code,name,status) values
  ('71000000-0000-4000-8000-000000000001','synthetic-edit-active',
    'Synthetic Edit Active','active'),
  ('71000000-0000-4000-8000-000000000002','synthetic-edit-inactive',
    'Synthetic Edit Inactive','inactive');

insert into public.institutions(
  id,public_name,trade_name,legal_name,slug,status,timezone,locale,
  institution_type_id
) values
  ('72000000-0000-4000-8000-000000000001','Instituição sintética A',
    'Trade A','Legal A','synthetic-edit-a','draft','UTC','pt-BR',
    '71000000-0000-4000-8000-000000000001'),
  ('72000000-0000-4000-8000-000000000002','Instituição sintética B',
    null,null,'synthetic-edit-b','draft','UTC','pt-BR',null),
  ('72000000-0000-4000-8000-000000000003','Instituição sintética C',
    null,null,'synthetic-edit-c','draft','UTC','pt-BR',
    '71000000-0000-4000-8000-000000000001');
insert into public.institution_addresses(
  institution_id,country,state,city,district,street,number,postal_code
) values(
  '72000000-0000-4000-8000-000000000001','Brasil','PE','Recife',
  'Centro','Rua Antiga','10','50000000'
);

insert into auth.users(
  id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data
) values
  ('73000000-0000-4000-8000-000000000001','authenticated','authenticated',
    'edit-operations@invalid.test',now(),now(),now(),'{}','{}'),
  ('73000000-0000-4000-8000-000000000002','authenticated','authenticated',
    'edit-owner@invalid.test',now(),now(),now(),'{}','{}'),
  ('73000000-0000-4000-8000-000000000003','authenticated','authenticated',
    'edit-support@invalid.test',now(),now(),now(),'{}','{}'),
  ('73000000-0000-4000-8000-000000000004','authenticated','authenticated',
    'edit-content@invalid.test',now(),now(),now(),'{}','{}'),
  ('73000000-0000-4000-8000-000000000005','authenticated','authenticated',
    'edit-auditor@invalid.test',now(),now(),now(),'{}','{}'),
  ('73000000-0000-4000-8000-000000000006','authenticated','authenticated',
    'edit-cross-app@invalid.test',now(),now(),now(),'{}','{}'),
  ('73000000-0000-4000-8000-000000000007','authenticated','authenticated',
    'edit-revoked-membership@invalid.test',now(),now(),now(),'{}','{}'),
  ('73000000-0000-4000-8000-000000000008','authenticated','authenticated',
    'edit-revoked-link@invalid.test',now(),now(),now(),'{}','{}');

insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('74000000-0000-4000-8000-000000000001',
    '73000000-0000-4000-8000-000000000001',now(),now(),'aal2',now()+interval '1 hour'),
  ('74000000-0000-4000-8000-000000000002',
    '73000000-0000-4000-8000-000000000002',now(),now(),'aal2',now()+interval '1 hour'),
  ('74000000-0000-4000-8000-000000000003',
    '73000000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour'),
  ('74000000-0000-4000-8000-000000000004',
    '73000000-0000-4000-8000-000000000003',now(),now(),'aal2',now()+interval '1 hour'),
  ('74000000-0000-4000-8000-000000000005',
    '73000000-0000-4000-8000-000000000004',now(),now(),'aal2',now()+interval '1 hour'),
  ('74000000-0000-4000-8000-000000000006',
    '73000000-0000-4000-8000-000000000005',now(),now(),'aal2',now()+interval '1 hour'),
  ('74000000-0000-4000-8000-000000000007',
    '73000000-0000-4000-8000-000000000006',now(),now(),'aal2',now()+interval '1 hour'),
  ('74000000-0000-4000-8000-000000000008',
    '73000000-0000-4000-8000-000000000002',now(),now(),'aal2',now()-interval '1 minute'),
  ('74000000-0000-4000-8000-000000000009',
    '73000000-0000-4000-8000-000000000007',now(),now(),'aal2',now()+interval '1 hour'),
  ('74000000-0000-4000-8000-000000000010',
    '73000000-0000-4000-8000-000000000008',now(),now(),'aal2',now()+interval '1 hour'),
  ('74000000-0000-4000-8000-000000000011',
    '73000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour');

insert into app_private.superadmin_internal_identities(id) values
  ('75000000-0000-4000-8000-000000000001'),
  ('75000000-0000-4000-8000-000000000002'),
  ('75000000-0000-4000-8000-000000000003'),
  ('75000000-0000-4000-8000-000000000004'),
  ('75000000-0000-4000-8000-000000000005'),
  ('75000000-0000-4000-8000-000000000007'),
  ('75000000-0000-4000-8000-000000000008');
insert into app_private.superadmin_internal_auth_links(
  id,internal_identity_id,auth_user_id
) values
  ('76000000-0000-4000-8000-000000000001',
    '75000000-0000-4000-8000-000000000001',
    '73000000-0000-4000-8000-000000000001'),
  ('76000000-0000-4000-8000-000000000002',
    '75000000-0000-4000-8000-000000000002',
    '73000000-0000-4000-8000-000000000002'),
  ('76000000-0000-4000-8000-000000000003',
    '75000000-0000-4000-8000-000000000003',
    '73000000-0000-4000-8000-000000000003'),
  ('76000000-0000-4000-8000-000000000004',
    '75000000-0000-4000-8000-000000000004',
    '73000000-0000-4000-8000-000000000004'),
  ('76000000-0000-4000-8000-000000000005',
    '75000000-0000-4000-8000-000000000005',
    '73000000-0000-4000-8000-000000000005'),
  ('76000000-0000-4000-8000-000000000007',
    '75000000-0000-4000-8000-000000000007',
    '73000000-0000-4000-8000-000000000007'),
  ('76000000-0000-4000-8000-000000000008',
    '75000000-0000-4000-8000-000000000008',
    '73000000-0000-4000-8000-000000000008');

insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id
)
select '77000000-0000-4000-8000-000000000001',
  '75000000-0000-4000-8000-000000000001',role_record.id,
  'institution','72000000-0000-4000-8000-000000000001'
from public.platform_roles role_record where role_record.code='operations';
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind
)
select membership_record.id,membership_record.identity_id,role_record.id,'platform'
from (values
  ('77000000-0000-4000-8000-000000000002'::uuid,
    '75000000-0000-4000-8000-000000000002'::uuid,'owner'::text),
  ('77000000-0000-4000-8000-000000000003'::uuid,
    '75000000-0000-4000-8000-000000000003'::uuid,'support'::text),
  ('77000000-0000-4000-8000-000000000004'::uuid,
    '75000000-0000-4000-8000-000000000004'::uuid,'content'::text),
  ('77000000-0000-4000-8000-000000000005'::uuid,
    '75000000-0000-4000-8000-000000000005'::uuid,'auditor'::text),
  ('77000000-0000-4000-8000-000000000007'::uuid,
    '75000000-0000-4000-8000-000000000007'::uuid,'operations'::text),
  ('77000000-0000-4000-8000-000000000008'::uuid,
    '75000000-0000-4000-8000-000000000008'::uuid,'operations'::text)
) membership_record(id,identity_id,role_code)
join public.platform_roles role_record on role_record.code=membership_record.role_code;
update app_private.superadmin_internal_memberships
set status='revoked',revoked_at=now(),version=2
where id='77000000-0000-4000-8000-000000000007';
update app_private.superadmin_internal_auth_links
set status='revoked',revoked_at=now(),version=2
where id='76000000-0000-4000-8000-000000000008';

create temporary table edit_responses(
  sequence_number integer primary key,
  body jsonb not null
);
grant select,insert on edit_responses to authenticated;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000001',
  'session_id','74000000-0000-4000-8000-000000000001',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values(1,public.superadmin_institution_edit_core_v2(
  '78000000-0000-4000-8000-000000000001',
  '72000000-0000-4000-8000-000000000001',1,
  $json${"public_name":"  Instituição A editada  ","trade_name":" ",
    "address":{"city":" Olinda ","street":" Rua Nova ",
      "number":"20","postal_code":"53000000"}}$json$::jsonb
));
insert into edit_responses values(101,public.superadmin_institution_detail_v2(
  '72000000-0000-4000-8000-000000000001'
));
reset role;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000002',
  'session_id','74000000-0000-4000-8000-000000000002',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values(2,public.superadmin_institution_edit_core_v2(
  '78000000-0000-4000-8000-000000000002',
  '72000000-0000-4000-8000-000000000002',1,
  $json${"public_name":"Instituição B editada",
    "institution_type_id":"71000000-0000-4000-8000-000000000001"}$json$::jsonb
));
insert into edit_responses values(3,public.superadmin_institution_edit_core_v2(
  '78000000-0000-4000-8000-000000000003',
  '72000000-0000-4000-8000-000000000002',2,
  '{"institution_type_id":"71000000-0000-4000-8000-000000000002"}'::jsonb
));
insert into edit_responses values(23,public.superadmin_institution_edit_core_v2(
  '78000000-0000-4000-8000-000000000023',
  '72000000-0000-4000-8000-000000000002',2,
  '{"contact":{"email":"forbidden@invalid.test"}}'::jsonb
));
reset role;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000003',
  'session_id','74000000-0000-4000-8000-000000000004',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values(4,public.superadmin_institution_edit_core_v2(
  gen_random_uuid(),'72000000-0000-4000-8000-000000000001',2,
  '{"public_name":"Support forbidden"}'::jsonb));
reset role;
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000004',
  'session_id','74000000-0000-4000-8000-000000000005',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values(5,public.superadmin_institution_edit_core_v2(
  gen_random_uuid(),'72000000-0000-4000-8000-000000000001',2,
  '{"public_name":"Content forbidden"}'::jsonb));
reset role;
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000005',
  'session_id','74000000-0000-4000-8000-000000000006',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values(6,public.superadmin_institution_edit_core_v2(
  gen_random_uuid(),'72000000-0000-4000-8000-000000000001',2,
  '{"public_name":"Auditor forbidden"}'::jsonb));
reset role;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000002',
  'session_id','74000000-0000-4000-8000-000000000003',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values(7,public.superadmin_institution_edit_core_v2(
  gen_random_uuid(),'72000000-0000-4000-8000-000000000002',2,
  '{"public_name":"Owner AAL1 forbidden"}'::jsonb));
reset role;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000001',
  'session_id','74000000-0000-4000-8000-000000000011',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values(25,public.superadmin_institution_edit_core_v2(
  gen_random_uuid(),'72000000-0000-4000-8000-000000000001',2,
  '{"public_name":"Operations AAL1 forbidden"}'::jsonb));
reset role;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000006',
  'session_id','74000000-0000-4000-8000-000000000007',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values(8,public.superadmin_institution_edit_core_v2(
  gen_random_uuid(),'72000000-0000-4000-8000-000000000001',2,
  '{"public_name":"Cross app forbidden"}'::jsonb));
reset role;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000002',
  'session_id','74000000-0000-4000-8000-000000000008',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values(9,public.superadmin_institution_edit_core_v2(
  gen_random_uuid(),'72000000-0000-4000-8000-000000000002',2,
  '{"public_name":"Expired forbidden"}'::jsonb));
reset role;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000007',
  'session_id','74000000-0000-4000-8000-000000000009',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values(10,public.superadmin_institution_edit_core_v2(
  gen_random_uuid(),'72000000-0000-4000-8000-000000000001',2,
  '{"public_name":"Revoked forbidden"}'::jsonb));
reset role;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000008',
  'session_id','74000000-0000-4000-8000-000000000010',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values(24,public.superadmin_institution_edit_core_v2(
  gen_random_uuid(),'72000000-0000-4000-8000-000000000001',2,
  '{"public_name":"Revoked link forbidden"}'::jsonb));
reset role;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000001',
  'session_id','74000000-0000-4000-8000-000000000001',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values
  (11,public.superadmin_institution_edit_core_v2(
    gen_random_uuid(),'72000000-0000-4000-8000-000000000002',2,
    '{"public_name":"Cross scope"}'::jsonb)),
  (12,public.superadmin_institution_edit_core_v2(
    gen_random_uuid(),'72000000-0000-4000-8000-00000000ffff',1,
    '{"public_name":"Missing"}'::jsonb));
reset role;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000002',
  'session_id','74000000-0000-4000-8000-000000000002',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values
  (13,public.superadmin_institution_edit_core_v2(
    '78000000-0000-4000-8000-000000000013',
    '72000000-0000-4000-8000-000000000003',1,
    '{"address":{"city":"Recife"}}'::jsonb)),
  (14,public.superadmin_institution_edit_core_v2(
    '78000000-0000-4000-8000-000000000014',
    '72000000-0000-4000-8000-000000000003',1,
    $json${"address":{"country":"Brasil","city":"Recife",
      "postal_code":"50000000"}}$json$::jsonb));
reset role;

select ok((select (body->>'ok')::boolean is true
    and body#>>'{data,institution_id}'='72000000-0000-4000-8000-000000000001'
    and (body#>>'{data,management_version}')::bigint=2
    and (body#>>'{data,replayed}')::boolean is false
    and body->'error'='null'::jsonb
    and (select array_agg(key order by key)
      from jsonb_object_keys(body) key)=array['data','error','ok']::text[]
    and (select array_agg(key order by key)
      from jsonb_object_keys(body->'data') key)=array[
        'correlation_id','institution_id','management_version','replayed'
      ]::text[]
  from edit_responses where sequence_number=1),
  'institution-scoped Operations AAL2 receives the exact approved success ack');
select ok((select public_name='Instituição A editada'
    and trade_name is null and legal_name='Legal A'
    and management_version=2
  from public.institutions
  where id='72000000-0000-4000-8000-000000000001')
  and (select country='Brasil' and state='PE' and city='Olinda'
    and street='Rua Nova' and number='20' and postal_code='53000000'
  from public.institution_addresses
  where institution_id='72000000-0000-4000-8000-000000000001'),
  'root and address partial merge persist normalized values and preserve omissions');
select ok((select actor_internal_identity_id=
      '75000000-0000-4000-8000-000000000001'
    and institution_id='72000000-0000-4000-8000-000000000001'
    and expected_version=1 and result_management_version=2
    and octet_length(request_hash)=32
    and original_correlation_id=(select
      (body#>>'{data,correlation_id}')::uuid
      from edit_responses where sequence_number=1)
    and request_hash=
      app_private.superadmin_institution_edit_core_request_hash_v2(
        '72000000-0000-4000-8000-000000000001',1,
        $json${"public_name":"Instituição A editada","trade_name":null,
          "address":{"city":"Olinda","street":"Rua Nova",
            "number":"20","postal_code":"53000000"}}$json$::jsonb
      )
  from app_private.superadmin_internal_institution_edit_receipts
  where request_id='78000000-0000-4000-8000-000000000001'),
  'receipt stores original correlation and exact canonical command digest');
select ok((select (body->>'ok')::boolean is true
    and body#>>'{data,public_name}'='Instituição A editada'
    and (body#>>'{data,management_version}')::bigint=2
    and body#>>'{data,address,country}'='Brasil'
    and body#>>'{data,address,city}'='Olinda'
    and body#>>'{data,address,postal_code}'='53000000'
  from edit_responses where sequence_number=101),
  'detail v2 reload observes the persisted ROOT+ADDRESS mutation');
select ok((select (body->>'ok')::boolean is true
    and (body#>>'{data,management_version}')::bigint=2
  from edit_responses where sequence_number=2)
  and (select public_name='Instituição B editada'
    and institution_type_id='71000000-0000-4000-8000-000000000001'
    and management_version=2
  from public.institutions
  where id='72000000-0000-4000-8000-000000000002'),
  'platform Owner AAL2 edits root data and selects an active institution type');
select ok(not exists(
    select 1 from edit_responses where sequence_number in(3,23)
      and (body#>>'{error,code}'<>'SAI_INVALID_ARGUMENT'
        or (body#>>'{error,http_status}')::integer<>400)
  )
  and (select institution_type_id='71000000-0000-4000-8000-000000000001'
    and management_version=2
  from public.institutions
  where id='72000000-0000-4000-8000-000000000002'),
  'inactive type and forbidden contact are rejected with envelope 400 and no persistence');
select ok(not exists(
  select 1 from edit_responses where sequence_number in(4,5,6)
    and body#>>'{error,code}'<>'SAI_PERMISSION_DENIED'
), 'Support, Content and Auditor remain denied for institution.update');
select ok((select count(*)=1
    and bool_and(actor_kind='superadmin_internal')
    and bool_and(permission_code='institution.update')
    and bool_and(action_code='institution.edit_core')
    and bool_and(outcome='denied')
    and bool_and(reason_code='SAI_PERMISSION_DENIED')
    and bool_and(institution_id is null)
    and bool_and(before_json is null and after_json is null)
    and bool_and(app_private.audit_verify_entry(id))
  from audit.audit_logs
  where correlation_id=(select (body#>>'{error,correlation_id}')::uuid
    from edit_responses where sequence_number=4)),
  'Support denial appends exactly one correlated minimized digest-verifiable audit');
select ok((select body#>>'{error,code}'='SAI_MFA_REQUIRED'
    from edit_responses where sequence_number=7)
  and (select body#>>'{error,code}'='SAI_MFA_REQUIRED'
    from edit_responses where sequence_number=25),
  'Owner and Operations AAL1 are denied until MFA is satisfied');
select is((select body#>>'{error,code}' from edit_responses where sequence_number=8),
  'SAI_INTERNAL_CONTEXT_DENIED',
  'a valid cross-app session without internal identity is denied');
select ok((select body#>>'{error,code}'='SAI_SESSION_INVALID'
    from edit_responses where sequence_number=9)
  and not exists(
    select 1 from audit.audit_logs
    where correlation_id=(select (body#>>'{error,correlation_id}')::uuid
      from edit_responses where sequence_number=9)
  ),
  'expired session is denied before actor attribution and creates no audit');
select ok((select body#>>'{error,code}'='SAI_MEMBERSHIP_REVOKED'
    from edit_responses where sequence_number=10)
  and (select body#>>'{error,code}'='SAI_INTERNAL_CONTEXT_DENIED'
    from edit_responses where sequence_number=24),
  'revoked membership and revoked Auth link are denied immediately');
select ok(
  (select (body->'error')-'correlation_id'
    from edit_responses where sequence_number=11)
  =(select (body->'error')-'correlation_id'
    from edit_responses where sequence_number=12)
  and (select body#>>'{error,code}'='SAI_PERMISSION_DENIED'
    from edit_responses where sequence_number=11),
  'cross-scope and missing institution IDs are indistinguishable');
select is((select body#>>'{error,code}' from edit_responses where sequence_number=13),
  'SAI_INVALID_ARGUMENT',
  'a new address cannot be created without explicit country Brasil');
select ok((select (body->>'ok')::boolean is true
    and (body#>>'{data,management_version}')::bigint=2
  from edit_responses where sequence_number=14)
  and (select country='Brasil' and city='Recife' and postal_code='50000000'
    from public.institution_addresses
    where institution_id='72000000-0000-4000-8000-000000000003'),
  'a new Brazilian address persists only with explicit Brasil and valid CEP');

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000001',
  'session_id','74000000-0000-4000-8000-000000000001',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values
  (15,public.superadmin_institution_edit_core_v2(
    '78000000-0000-4000-8000-000000000015',
    '72000000-0000-4000-8000-000000000001',2,
    '{"public_name":"Instituição A editada"}'::jsonb)),
  (16,public.superadmin_institution_edit_core_v2(
    '78000000-0000-4000-8000-000000000016',
    '72000000-0000-4000-8000-000000000001',1,
    '{"public_name":"Stale forbidden"}'::jsonb)),
  (17,public.superadmin_institution_edit_core_v2(
    '78000000-0000-4000-8000-000000000001',
    '72000000-0000-4000-8000-000000000001',1,
    $json${"public_name":"  Instituição A editada  ","trade_name":" ",
      "address":{"city":" Olinda ","street":" Rua Nova ",
        "number":"20","postal_code":"53000000"}}$json$::jsonb)),
  (18,public.superadmin_institution_edit_core_v2(
    '78000000-0000-4000-8000-000000000001',
    '72000000-0000-4000-8000-000000000001',1,
    '{"public_name":"Different reuse"}'::jsonb));
reset role;

select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000002',
  'session_id','74000000-0000-4000-8000-000000000002',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values(19,public.superadmin_institution_edit_core_v2(
  '78000000-0000-4000-8000-000000000001',
  '72000000-0000-4000-8000-000000000001',1,
  $json${"public_name":"  Instituição A editada  ","trade_name":" ",
    "address":{"city":" Olinda ","street":" Rua Nova ",
      "number":"20","postal_code":"53000000"}}$json$::jsonb
));
reset role;

update app_private.superadmin_internal_memberships
set status='suspended',suspended_at=now(),version=2
where id='77000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000001',
  'session_id','74000000-0000-4000-8000-000000000001',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values(20,public.superadmin_institution_edit_core_v2(
  '78000000-0000-4000-8000-000000000001',
  '72000000-0000-4000-8000-000000000001',1,
  $json${"public_name":"  Instituição A editada  ","trade_name":" ",
    "address":{"city":" Olinda ","street":" Rua Nova ",
      "number":"20","postal_code":"53000000"}}$json$::jsonb
));
reset role;
update app_private.superadmin_internal_memberships
set status='active',suspended_at=null,version=3
where id='77000000-0000-4000-8000-000000000001';

update public.institutions set deleted_at=now()
where id='72000000-0000-4000-8000-000000000002';
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000002',
  'session_id','74000000-0000-4000-8000-000000000002',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into edit_responses values
  (21,public.superadmin_institution_edit_core_v2(
    '78000000-0000-4000-8000-000000000002',
    '72000000-0000-4000-8000-000000000002',1,
    $json${"public_name":"Instituição B editada",
      "institution_type_id":"71000000-0000-4000-8000-000000000001"}$json$::jsonb)),
  (22,public.superadmin_institution_detail_v2(
    '72000000-0000-4000-8000-000000000002'));
reset role;

select ok(
  (select body#>>'{error,code}'='SAI_INVALID_ARGUMENT'
    from edit_responses where sequence_number=15)
  and (select body#>>'{error,code}'='SAI_CONCURRENT_CHANGE'
    from edit_responses where sequence_number=16)
  and (select management_version=2 and public_name='Instituição A editada'
    from public.institutions
    where id='72000000-0000-4000-8000-000000000001'),
  'no-op is invalid and a stale expected_version returns the stable concurrency error'
);
select ok((select (body->>'ok')::boolean is true
    and (body#>>'{data,replayed}')::boolean is true
    and (body#>>'{data,management_version}')::bigint=2
    and body#>>'{data,correlation_id}' is distinct from
      (select body#>>'{data,correlation_id}' from edit_responses
       where sequence_number=1)
  from edit_responses where sequence_number=17)
  and (select count(*)=1
    from app_private.superadmin_internal_institution_edit_receipts
    where request_id='78000000-0000-4000-8000-000000000001')
  and (select management_version=2
    from public.institutions
    where id='72000000-0000-4000-8000-000000000001'),
  'identical replay returns the original version with a fresh correlation and no mutation');
select is((select count(*) from audit.audit_logs
  where actor_internal_identity_id='75000000-0000-4000-8000-000000000001'
    and institution_id='72000000-0000-4000-8000-000000000001'
    and action_code='institution.edit_core.replay'
    and permission_code='institution.update' and outcome='success'
    and correlation_id=(select (body#>>'{data,correlation_id}')::uuid
      from edit_responses where sequence_number=17)),1::bigint,
  'accepted replay appends exactly one audit correlated to its response');
select ok(not exists(
  select 1 from edit_responses where sequence_number in(18,19)
    and body#>>'{error,code}'<>'SAI_INVALID_ARGUMENT'
), 'request reuse with a different hash or internal identity is rejected');
select is((select body#>>'{error,code}' from edit_responses where sequence_number=20),
  'SAI_MEMBERSHIP_SUSPENDED',
  'replay reauthorizes current membership before consulting the receipt');
select ok((select (body->>'ok')::boolean is true
    and (body#>>'{data,replayed}')::boolean is true
    and (body#>>'{data,management_version}')::bigint=2
  from edit_responses where sequence_number=21)
  and (select body#>>'{error,code}'='SAI_PERMISSION_DENIED'
    from edit_responses where sequence_number=22)
  and (select count(*)=1
    from app_private.superadmin_internal_institution_edit_receipts
    where request_id='78000000-0000-4000-8000-000000000002'),
  'authorized historical replay survives soft-delete while detail reload remains fail-closed');
select ok((select count(*)=2
    and count(*) filter(
      where action_code='institution.edit_core'
        and correlation_id=(select (body#>>'{data,correlation_id}')::uuid
          from edit_responses where sequence_number=1)
    )=1
    and count(*) filter(
      where action_code='institution.edit_core.replay'
        and correlation_id=(select (body#>>'{data,correlation_id}')::uuid
          from edit_responses where sequence_number=17)
    )=1
    and bool_and(actor_kind='superadmin_internal')
    and bool_and(permission_code='institution.update')
    and bool_and(outcome='success')
    and bool_and(reason_code is null)
    and bool_and(before_json is null and after_json is null)
    and bool_and(app_private.audit_verify_entry(id))
    and bool_and(position(receipt_hash in audit_text)=0)
  from (
    select log_record.*,
      encode(receipt_record.request_hash,'hex') receipt_hash,
      log_record::text audit_text
    from audit.audit_logs log_record
    cross join app_private.superadmin_internal_institution_edit_receipts receipt_record
    where receipt_record.request_id='78000000-0000-4000-8000-000000000001'
      and log_record.actor_internal_identity_id=
        '75000000-0000-4000-8000-000000000001'
      and log_record.institution_id=
        '72000000-0000-4000-8000-000000000001'
      and log_record.outcome='success'
      and log_record.action_code in(
        'institution.edit_core','institution.edit_core.replay')
  ) minimized_events),
  'success and replay audits are 1:1 correlated, minimized, hash-private and verifiable');

create function pg_temp.fail_edit_core_denial_audit()
returns trigger language plpgsql as $$
begin
  if new.action_code='institution.edit_core' and new.outcome='denied' then
    raise exception using errcode='P0001',
      message='forced institution edit denial audit failure';
  end if;
  return new;
end
$$;
create trigger fail_edit_core_denial_audit
before insert on audit.audit_logs
for each row execute function pg_temp.fail_edit_core_denial_audit();
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000003',
  'session_id','74000000-0000-4000-8000-000000000004',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
select throws_ok(
  $$select public.superadmin_institution_edit_core_v2(
    gen_random_uuid(),'72000000-0000-4000-8000-000000000001',2,
    '{"public_name":"Denied audit must fail"}'::jsonb
  )$$,
  'P0001','forced institution edit denial audit failure',
  'validated denial cannot return when its mandatory audit append fails'
);
reset role;
drop trigger fail_edit_core_denial_audit on audit.audit_logs;

create function pg_temp.fail_edit_core_audit()
returns trigger language plpgsql as $$
begin
  if new.action_code='institution.edit_core' then
    raise exception using errcode='P0001',
      message='forced institution edit audit failure';
  end if;
  return new;
end
$$;
create temporary table edit_fail_audit_snapshot(value bigint not null);
insert into edit_fail_audit_snapshot
select count(*) from audit.audit_logs
where action_code='institution.edit_core'
  and institution_id='72000000-0000-4000-8000-000000000003';
create trigger fail_edit_core_audit
before insert on audit.audit_logs
for each row execute function pg_temp.fail_edit_core_audit();
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','73000000-0000-4000-8000-000000000002',
  'session_id','74000000-0000-4000-8000-000000000002',
  'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
select throws_ok(
  $$select public.superadmin_institution_edit_core_v2(
    '78000000-0000-4000-8000-000000000099',
    '72000000-0000-4000-8000-000000000003',2,
    '{"public_name":"Must roll back"}'::jsonb
  )$$,
  'P0001','forced institution edit audit failure',
  'mandatory success audit failure aborts the edit RPC'
);
reset role;
drop trigger fail_edit_core_audit on audit.audit_logs;
select ok((select public_name='Instituição sintética C' and management_version=2
    from public.institutions
    where id='72000000-0000-4000-8000-000000000003')
  and not exists(
    select 1 from app_private.superadmin_internal_institution_edit_receipts
    where request_id='78000000-0000-4000-8000-000000000099'
  )
  and (select value from edit_fail_audit_snapshot)=(
    select count(*) from audit.audit_logs
    where action_code='institution.edit_core'
      and institution_id='72000000-0000-4000-8000-000000000003'
  ),
  'audit failure rolls back root mutation, version and receipt atomically');

select * from finish();
rollback;
