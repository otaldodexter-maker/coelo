-- Prova do candidato 20260911170700_people_identity_lookup_v1 (people.create: resolvedor de identidade).
-- Projeto descartavel LOCAL: fixtures sinteticas em transacao com rollback.
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

create function pg_temp.pil_session(auth_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    case when auth_user is null then ''
      else jsonb_build_object('sub',auth_user,'role','authenticated','aal','aal1')::text end, true)
$$;

-- Operador com people.create+people.update; operador so com people.create; terceiro sem nada.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
  ('a0800000-0000-4000-8000-000000000001','authenticated','authenticated','pil-full@invalid.test',now(),now(),now(),'{}','{}'),
  ('a0800000-0000-4000-8000-000000000002','authenticated','authenticated','pil-create@invalid.test',now(),now(),now(),'{}','{}'),
  ('a0800000-0000-4000-8000-000000000003','authenticated','authenticated','pil-none@invalid.test',now(),now(),now(),'{}','{}');
insert into public.people(id,person_type,first_name,last_name,display_name) values
  ('a0800000-0000-4000-8000-000000000011','adult','Operador','Completo','Operador Completo'),
  ('a0800000-0000-4000-8000-000000000012','adult','Operador','Cria','Operador Cria'),
  ('a0800000-0000-4000-8000-000000000013','adult','Terceiro','Nada','Terceiro Nada'),
  ('a0800000-0000-4000-8000-000000000021','adult','Maria','Procurada','Maria Procurada'),
  ('a0800000-0000-4000-8000-000000000022','child','Joao','Procurado','Joao Procurado');
insert into public.person_auth_links(person_id,auth_user_id) values
  ('a0800000-0000-4000-8000-000000000011','a0800000-0000-4000-8000-000000000001'),
  ('a0800000-0000-4000-8000-000000000012','a0800000-0000-4000-8000-000000000002'),
  ('a0800000-0000-4000-8000-000000000013','a0800000-0000-4000-8000-000000000003');
insert into public.platform_roles(id,code,name,max_scope_kind) values
  ('a0800000-0000-4000-8000-000000000101','pil_full','PIL completo','platform'),
  ('a0800000-0000-4000-8000-000000000102','pil_create','PIL cria','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect)
  select 'a0800000-0000-4000-8000-000000000101',id,'allow' from public.platform_permissions where code in ('people.create','people.update','people.read');
insert into public.platform_role_permissions(role_id,permission_id,effect)
  select 'a0800000-0000-4000-8000-000000000102',id,'allow' from public.platform_permissions where code in ('people.create');
insert into public.platform_memberships(person_id,role_id,status,scope_kind) values
  ('a0800000-0000-4000-8000-000000000011','a0800000-0000-4000-8000-000000000101','active','platform'),
  ('a0800000-0000-4000-8000-000000000012','a0800000-0000-4000-8000-000000000102','active','platform');
-- contatos e CPF de Maria, no formato do catalogo (210000)
insert into public.person_contacts(person_id,contact_type,normalized_value_hash,masked_value,status) values
  ('a0800000-0000-4000-8000-000000000021','email',encode(extensions.digest(convert_to('maria.procurada@invalid.test','UTF8'),'sha256'),'hex'),'m***@invalid.test','active'),
  ('a0800000-0000-4000-8000-000000000021','mobile_phone',encode(extensions.digest(convert_to('11987654321','UTF8'),'sha256'),'hex'),'*******4321','active');
insert into app_private.person_identity_identifiers(person_id,identifier_kind,normalized_value_hmac,hmac_key_version,masked_value,status) values
  ('a0800000-0000-4000-8000-000000000021','cpf',app_private.person_identity_hmac_v1('52998224725'),1,'***.***.***-25','active');

-- 1-2. anonimo e terceiro sem people.create nao consultam
select pg_temp.pil_session(null);
select throws_ok($$select public.superadmin_people_identity_lookup_v1('email','x@y.z')$$, '42501',
  'people permission denied', 'anonimo nao resolve identidade');
select pg_temp.pil_session('a0800000-0000-4000-8000-000000000003');
select throws_ok($$select public.superadmin_people_identity_lookup_v1('email','x@y.z')$$, '42501',
  'people permission denied', 'sem people.create nao resolve identidade');

-- 3-7. operador completo: e-mail (maiusculas), telefone (mascara), CPF (formatado), @ e nome
select pg_temp.pil_session('a0800000-0000-4000-8000-000000000001');
select is(public.superadmin_people_identity_lookup_v1('email','Maria.Procurada@INVALID.test')->'data'->0->>'person_id',
  'a0800000-0000-4000-8000-000000000021', 'e-mail normalizado encontra a pessoa');
select is(public.superadmin_people_identity_lookup_v1('phone','(11) 98765-4321')->'data'->0->>'masked_match',
  '*******4321', 'telefone so com digitos encontra e devolve a mascara do catalogo');
select is(public.superadmin_people_identity_lookup_v1('cpf','529.982.247-25')->'data'->0->>'access',
  'edit_global', 'CPF formatado encontra; operador com people.update recebe edit_global');
select is(public.superadmin_people_identity_lookup_v1('handle','@Maria.Procurada')->'data'->0->>'matched_by',
  'handle', '@ normalizado encontra a pessoa');
select is(jsonb_array_length(public.superadmin_people_identity_lookup_v1('name','procurad')->'data'), 2,
  'nome parcial devolve adulto e crianca');

-- 8. sem correspondencia: lista vazia (o cliente libera o formulario)
select is(public.superadmin_people_identity_lookup_v1('email','ninguem@invalid.test')->'data', '[]'::jsonb,
  'sem correspondencia devolve lista vazia');

-- 9. kind fora da allowlist
select throws_ok($$select public.superadmin_people_identity_lookup_v1('sql','x')$$, '22023',
  'invalid identity lookup kind', 'kind fora da allowlist e recusado');

-- 10. operador so com people.create recebe link_only
select pg_temp.pil_session('a0800000-0000-4000-8000-000000000002');
select is(public.superadmin_people_identity_lookup_v1('cpf','52998224725')->'data'->0->>'access',
  'link_only', 'operador sem people.update recebe link_only');

-- 11. cada consulta e auditada (7 acima) e nenhuma linha carrega o valor consultado
select is((select count(*) from audit.audit_logs where object_type='person_identity_lookup'
  and coalesce(reason,'') not ilike '%maria.procurada@%' and coalesce(after_json::text,'') not ilike '%maria.procurada@%'
  and coalesce(after_json::text,'') not like '%52998224725%'), 7::bigint,
  'consultas auditadas sem o valor em claro');

select * from finish();
rollback;
