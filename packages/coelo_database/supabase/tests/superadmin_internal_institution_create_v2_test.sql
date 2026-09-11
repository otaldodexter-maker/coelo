begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

select has_function(
  'public','superadmin_institution_create_v2',array['uuid','jsonb'],
  'Institution CREATE v2 has the approved public signature'
);
select has_table(
  'app_private','superadmin_internal_institution_create_receipts',
  'Institution CREATE v2 has a separate internal-identity receipt'
);

select ok(
  pg_get_functiondef('public.superadmin_institution_create_v2(uuid,jsonb)'::regprocedure)
    like '%require_superadmin_internal_context%'
  and pg_get_functiondef('public.superadmin_institution_create_v2(uuid,jsonb)'::regprocedure)
    not like '%current_person_id%'
  and pg_get_functiondef('app_private.superadmin_institution_create_validate_v2(jsonb)'::regprocedure)
    like '%superadmin_institution_edit_core_validate_v2%',
  'the wrapper uses only internal authority and the validator reuses the EDIT CORE validator'
);

with expected(procedure_oid,security_definer) as(values
  ('public.superadmin_institution_create_v2(uuid,jsonb)'::regprocedure,true),
  ('app_private.superadmin_institution_create_validate_v2(jsonb)'::regprocedure,false),
  ('app_private.superadmin_institution_create_request_hash_v2(jsonb)'::regprocedure,false),
  ('app_private.superadmin_institution_create_apply_v2(uuid,jsonb,bytea,app_private.superadmin_internal_context,uuid)'::regprocedure,true)
)
select ok(
  not exists(
    select 1 from expected
    join pg_proc procedure_record on procedure_record.oid=expected.procedure_oid
    join pg_roles owner_role on owner_role.oid=procedure_record.proowner
    where owner_role.rolname<>'postgres'
      or procedure_record.prosecdef is distinct from expected.security_definer
      or not(coalesce(procedure_record.proconfig,'{}'::text[])
        @> array['search_path=""']::text[])
  ),
  'all create objects have the approved owners, security mode and empty search_path'
);

select ok(
  has_function_privilege('authenticated',
    'public.superadmin_institution_create_v2(uuid,jsonb)','execute')
  and not has_function_privilege('anon',
    'public.superadmin_institution_create_v2(uuid,jsonb)','execute')
  and not has_function_privilege('service_role',
    'public.superadmin_institution_create_v2(uuid,jsonb)','execute')
  and not exists(
    select 1 from pg_proc procedure_record,
      lateral aclexplode(coalesce(procedure_record.proacl,
        acldefault('f',procedure_record.proowner))) acl
    where procedure_record.oid='public.superadmin_institution_create_v2(uuid,jsonb)'::regprocedure
      and acl.grantee=0 and acl.privilege_type='EXECUTE'
  ),
  'only authenticated executes the public create wrapper'
);

with helpers(procedure_oid) as(values
  ('app_private.superadmin_institution_create_validate_v2(jsonb)'::regprocedure),
  ('app_private.superadmin_institution_create_request_hash_v2(jsonb)'::regprocedure),
  ('app_private.superadmin_institution_create_apply_v2(uuid,jsonb,bytea,app_private.superadmin_internal_context,uuid)'::regprocedure)
),client_roles(role_name) as(values('anon'),('authenticated'),('service_role'))
select ok(
  not exists(
    select 1 from helpers cross join client_roles
    where has_function_privilege(role_name,procedure_oid,'execute')
  ),
  'no client or service role executes private create helpers'
);

select ok(
  (select table_record.relrowsecurity and table_record.relforcerowsecurity
   from pg_class table_record
   join pg_namespace namespace_record on namespace_record.oid=table_record.relnamespace
   where namespace_record.nspname='app_private'
     and table_record.relname='superadmin_internal_institution_create_receipts')
  and not exists(
    select 1 from information_schema.role_table_grants
    where table_schema='app_private'
      and table_name='superadmin_internal_institution_create_receipts'
      and grantee in('PUBLIC','anon','authenticated','service_role')
  ),
  'the create receipt enables and forces deny-by-default RLS with zero client grants'
);

-- Validador ---------------------------------------------------------------
create function pg_temp.create_validation_error(p_payload jsonb)
returns text language plpgsql as $$
declare error_detail text;
begin
  perform app_private.superadmin_institution_create_validate_v2(p_payload);
  return null;
exception when others then
  get stacked diagnostics error_detail=pg_exception_detail;
  return sqlstate||':'||coalesce(error_detail,'');
end
$$;

select is(
  app_private.superadmin_institution_create_validate_v2(
    $json${"slug":"  @Escola.Nova ","public_name":"  Escola Nova  ","trade_name":" ",
      "address":{"country":"Brasil","city":"Recife","postal_code":"50000000"}}$json$::jsonb
  ),
  $json${"slug":"escola.nova","public_name":"Escola Nova","trade_name":null,
    "address":{"country":"Brasil","city":"Recife","postal_code":"50000000"}}$json$::jsonb,
  'validator normalizes the handle and delegates ROOT+ADDRESS to the EDIT CORE validator'
);

select ok(
  pg_temp.create_validation_error('{"public_name":"Sem handle"}'::jsonb)='22023:SAI_INVALID_ARGUMENT'
  and pg_temp.create_validation_error('{"slug":"so-handle"}'::jsonb)='22023:SAI_INVALID_ARGUMENT'
  and pg_temp.create_validation_error('{"slug":"ab","public_name":"Curto"}'::jsonb)='22023:SAI_INVALID_ARGUMENT'
  and pg_temp.create_validation_error('{"slug":"ok-handle","public_name":"X","status":"active"}'::jsonb)='22023:SAI_INVALID_ARGUMENT'
  and pg_temp.create_validation_error('{"slug":"ok-handle","public_name":"X","contact":{"email":"a@invalid.test"}}'::jsonb)='22023:SAI_INVALID_ARGUMENT'
  and pg_temp.create_validation_error('{"slug":"ok-handle","public_name":"X","address":{"city":"Recife"}}'::jsonb)='22023:SAI_INVALID_ARGUMENT'
  and pg_temp.create_validation_error('[]'::jsonb)='22023:SAI_INVALID_ARGUMENT',
  'validator rejects missing handle or name, short handle, status, contact, address without Brasil and non-objects'
);

-- Fixtures -----------------------------------------------------------------
insert into public.institution_types(id,code,name,status) values
  ('91000000-0000-4000-8000-000000000001','synthetic-create-active','Synthetic Create Active','active'),
  ('91000000-0000-4000-8000-000000000002','synthetic-create-inactive','Synthetic Create Inactive','inactive');
insert into public.institutions(id,public_name,slug,status,timezone,locale) values
  ('92000000-0000-4000-8000-000000000001','Instituição existente','synthetic-create-taken','draft','UTC','pt-BR');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
  ('93000000-0000-4000-8000-000000000001','authenticated','authenticated','create-owner@invalid.test',now(),now(),now(),'{}','{}'),
  ('93000000-0000-4000-8000-000000000002','authenticated','authenticated','create-support@invalid.test',now(),now(),now(),'{}','{}'),
  ('93000000-0000-4000-8000-000000000003','authenticated','authenticated','create-scoped@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('94000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
  ('94000000-0000-4000-8000-000000000002','93000000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour'),
  ('94000000-0000-4000-8000-000000000003','93000000-0000-4000-8000-000000000003',now(),now(),'aal1',now()+interval '1 hour'),
  ('94000000-0000-4000-8000-000000000004','93000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()-interval '1 minute');
insert into app_private.superadmin_internal_identities(id) values
  ('95000000-0000-4000-8000-000000000001'),
  ('95000000-0000-4000-8000-000000000002'),
  ('95000000-0000-4000-8000-000000000003');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
  ('96000000-0000-4000-8000-000000000001','95000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001'),
  ('96000000-0000-4000-8000-000000000002','95000000-0000-4000-8000-000000000002','93000000-0000-4000-8000-000000000002'),
  ('96000000-0000-4000-8000-000000000003','95000000-0000-4000-8000-000000000003','93000000-0000-4000-8000-000000000003');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select membership_record.id,membership_record.identity_id,role_record.id,'platform'
from (values
  ('97000000-0000-4000-8000-000000000001'::uuid,'95000000-0000-4000-8000-000000000001'::uuid,'owner'::text),
  ('97000000-0000-4000-8000-000000000002'::uuid,'95000000-0000-4000-8000-000000000002'::uuid,'support'::text)
) membership_record(id,identity_id,role_code)
join public.platform_roles role_record on role_record.code=membership_record.role_code;
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select '97000000-0000-4000-8000-000000000003','95000000-0000-4000-8000-000000000003',role_record.id,
  'institution','92000000-0000-4000-8000-000000000001'
from public.platform_roles role_record where role_record.code='operations';

create temporary table create_responses(label text primary key,body jsonb not null);
grant select,insert on create_responses to authenticated,anon;

create function pg_temp.create_payload(p_slug text,p_name text) returns jsonb language sql immutable as $$
  select jsonb_build_object('slug',p_slug,'public_name',p_name,'timezone','America/Sao_Paulo','locale','pt-BR',
    'institution_type_id','91000000-0000-4000-8000-000000000001',
    'address',jsonb_build_object('country','Brasil','state','PE','city','Recife','district','Centro',
      'street','Rua Sintética','number','10','postal_code','50000000'))
$$;
grant execute on function pg_temp.create_payload(text,text) to authenticated,anon;

-- Owner de plataforma em AAL1 (MVP, ADR 0034 Decisao 12) --------------------
select set_config('request.jwt.claims',jsonb_build_object('sub','93000000-0000-4000-8000-000000000001',
  'session_id','94000000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into create_responses values
  ('create',public.superadmin_institution_create_v2('98000000-0000-4000-8000-000000000001',pg_temp.create_payload('Escola.Sintetica','Escola Sintética'))),
  ('replay',public.superadmin_institution_create_v2('98000000-0000-4000-8000-000000000001',pg_temp.create_payload('Escola.Sintetica','Escola Sintética'))),
  ('reused_id',public.superadmin_institution_create_v2('98000000-0000-4000-8000-000000000001',pg_temp.create_payload('outra.escola','Outra Escola'))),
  ('taken_slug',public.superadmin_institution_create_v2('98000000-0000-4000-8000-000000000002',pg_temp.create_payload('synthetic-create-taken','Repetida'))),
  ('inactive_type',public.superadmin_institution_create_v2('98000000-0000-4000-8000-000000000003',
    pg_temp.create_payload('escola.tipo','Tipo inativo')||'{"institution_type_id":"91000000-0000-4000-8000-000000000002"}'::jsonb)),
  ('invalid',public.superadmin_institution_create_v2('98000000-0000-4000-8000-000000000004','{"public_name":"Sem handle"}'::jsonb)),
  ('minimal',public.superadmin_institution_create_v2('98000000-0000-4000-8000-000000000005','{"slug":"minima","public_name":"Mínima"}'::jsonb));
reset role;

select ok(
  (select (body->>'ok')::boolean and (body#>>'{data,replayed}')='false'
    and (body#>>'{data,management_version}')='1' from create_responses where label='create'),
  'Owner at AAL1 creates an Institution with version 1'
);
select ok(
  exists(select 1 from public.institutions institution
    where institution.id=(select (body#>>'{data,institution_id}')::uuid from create_responses where label='create')
      and institution.slug='escola.sintetica' and institution.status='draft'
      and institution.public_name='Escola Sintética'
      and institution.institution_type_id='91000000-0000-4000-8000-000000000001'
      and institution.timezone='America/Sao_Paulo' and institution.locale='pt-BR'
      and institution.handle_last_changed_at is not null),
  'the new Institution is a draft with the normalized handle, type, timezone and locale'
);
select ok(
  exists(select 1 from public.institution_addresses address
    where address.institution_id=(select (body#>>'{data,institution_id}')::uuid from create_responses where label='create')
      and address.country='Brasil' and address.city='Recife' and address.postal_code='50000000' and address.status='active'),
  'the address is persisted with the Institution'
);
select ok(
  (select (body->>'ok')::boolean and (body#>>'{data,replayed}')='true'
    and body#>>'{data,institution_id}'=(select body#>>'{data,institution_id}' from create_responses where label='create')
    from create_responses where label='replay')
  and (select count(*)=1 from public.institutions where slug='escola.sintetica'),
  'replaying the same request id returns the receipt without a second Institution'
);
select is((select body#>>'{error,code}' from create_responses where label='reused_id'),'SAI_INVALID_ARGUMENT',
  'the same request id with another payload is rejected');
select is((select body#>>'{error,code}' from create_responses where label='taken_slug'),'SAI_INVALID_ARGUMENT',
  'a handle already in use is rejected');
select is((select body#>>'{error,code}' from create_responses where label='inactive_type'),'SAI_INVALID_ARGUMENT',
  'an inactive Institution type is rejected');
select is((select body#>>'{error,code}' from create_responses where label='invalid'),'SAI_INVALID_ARGUMENT',
  'an invalid payload is rejected with the envelope');
select ok(
  (select (body->>'ok')::boolean from create_responses where label='minimal')
  and exists(select 1 from public.institutions where slug='minima' and institution_type_id is null
    and timezone='America/Sao_Paulo' and locale='pt-BR')
  and not exists(select 1 from public.institution_addresses address
    join public.institutions institution on institution.id=address.institution_id where institution.slug='minima'),
  'a minimal payload creates a draft with defaults and no address'
);
select is(
  (select count(*) from audit.audit_logs log_record
   where log_record.action_code='institution.create' and log_record.outcome='success'
     and log_record.actor_kind='superadmin_internal' and log_record.hash_version=2
     and log_record.permission_code='institution.activate' and log_record.object_type='institution'
     and log_record.institution_id=log_record.object_id and log_record.after_json is null),
  2::bigint,
  'each accepted create appends exactly one minimized v2 audit event and replays append none'
);
select is(
  (select count(*) from app_private.superadmin_internal_institution_create_receipts
   where actor_internal_identity_id='95000000-0000-4000-8000-000000000001'),
  2::bigint,
  'accepted creates leave one receipt each'
);

-- Negativas -----------------------------------------------------------------
select set_config('request.jwt.claims',jsonb_build_object('sub','93000000-0000-4000-8000-000000000002',
  'session_id','94000000-0000-4000-8000-000000000002','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into create_responses values
  ('support',public.superadmin_institution_create_v2('98000000-0000-4000-8000-000000000011',pg_temp.create_payload('suporte.cria','Suporte cria')));
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','93000000-0000-4000-8000-000000000003',
  'session_id','94000000-0000-4000-8000-000000000003','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into create_responses values
  ('scoped',public.superadmin_institution_create_v2('98000000-0000-4000-8000-000000000012',pg_temp.create_payload('escopo.cria','Escopo cria')));
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub','93000000-0000-4000-8000-000000000001',
  'session_id','94000000-0000-4000-8000-000000000004','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into create_responses values
  ('expired',public.superadmin_institution_create_v2('98000000-0000-4000-8000-000000000013',pg_temp.create_payload('expirada.cria','Expirada cria')));
reset role;
-- anon nem executa o wrapper (asserção de privilégio acima); a sessão
-- autenticada sem claims validas e o caminho que chega ao envelope.
select set_config('request.jwt.claims','',true);
set local role authenticated;
insert into create_responses values
  ('anonymous',public.superadmin_institution_create_v2('98000000-0000-4000-8000-000000000014',pg_temp.create_payload('anonimo.cria','Anônimo cria')));
reset role;

select is((select body#>>'{error,code}' from create_responses where label='support'),'SAI_PERMISSION_DENIED',
  'support is denied');
select is((select body#>>'{error,code}' from create_responses where label='scoped'),'SAI_PERMISSION_DENIED',
  'an institution-scoped membership cannot create another Institution');
select is((select body#>>'{error,code}' from create_responses where label='expired'),'SAI_SESSION_INVALID',
  'an expired session is denied');
select is((select body#>>'{error,code}' from create_responses where label='anonymous'),'SAI_AUTH_REQUIRED',
  'missing Auth fails closed');
select ok(
  not exists(select 1 from public.institutions where slug in('suporte.cria','escopo.cria','expirada.cria','anonimo.cria')),
  'denied attempts create nothing'
);
select is(
  (select count(*) from audit.audit_logs log_record
   where log_record.action_code='institution.create' and log_record.outcome='denied'
     and log_record.actor_kind='superadmin_internal' and log_record.hash_version=2
     and log_record.reason_code in('SAI_PERMISSION_DENIED','SAI_SESSION_INVALID','SAI_INVALID_ARGUMENT')),
  -- sessao expirada e sem claims nao identificam ator: sem evento, por desenho.
  (select count(*) from create_responses where label in('support','scoped','reused_id','taken_slug','inactive_type','invalid')),
  'identified denials append one correlated v2 audit event each'
);

select * from finish();
rollback;
