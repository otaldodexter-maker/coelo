begin;
create extension if not exists pgtap with schema extensions;
select plan(38);

-- 1. objetos e privilegios ----------------------------------------------------
select has_function('public','superadmin_institution_contacts_edit_v1',
  array['uuid','uuid','bigint','jsonb'],'RPC publica de contatos existe');
select ok(
  has_function_privilege('authenticated',
    'public.superadmin_institution_contacts_edit_v1(uuid,uuid,bigint,jsonb)','execute')
  and not has_function_privilege('anon',
    'public.superadmin_institution_contacts_edit_v1(uuid,uuid,bigint,jsonb)','execute')
  and not has_function_privilege('service_role',
    'public.superadmin_institution_contacts_edit_v1(uuid,uuid,bigint,jsonb)','execute'),
  'so authenticated executa a RPC publica');
with helpers(p) as (values
  ('app_private.superadmin_institution_contacts_validate_v1(jsonb)'::regprocedure),
  ('app_private.superadmin_institution_contacts_validate_person_v1(jsonb,text)'::regprocedure),
  ('app_private.superadmin_institution_contacts_upsert_person_v1(jsonb)'::regprocedure),
  ('app_private.person_identity_hmac_v1(text)'::regprocedure),
  ('app_private.superadmin_institution_detail_payload_v2(uuid)'::regprocedure)),
roles(r) as (values ('anon'),('authenticated'),('service_role'))
select ok(not exists (select 1 from helpers cross join roles where has_function_privilege(r,p,'execute'))
  and not exists (select 1 from helpers join pg_proc pr on pr.oid=p
    cross join lateral aclexplode(coalesce(pr.proacl,acldefault('f',pr.proowner))) a
    where a.grantee=0 and a.privilege_type='EXECUTE'),
  'nenhum papel de cliente executa os helpers privados');
select ok(exists (select 1 from vault.secrets where name='coelo_person_identity_hmac_v1'),
  'chave HMAC do catalogo de identidade existe no Vault');
select ok(app_private.cpf_digits_valid_v1('52998224725') and not app_private.cpf_digits_valid_v1('52998224726')
  and not app_private.cpf_digits_valid_v1('11111111111'),'validador de CPF confere digitos');
select ok(app_private.cnpj_digits_valid_v1('11222333000181') and not app_private.cnpj_digits_valid_v1('11222333000182'),
  'validador de CNPJ confere digitos');

-- 2. fixture -----------------------------------------------------------------
insert into public.institutions(id,public_name,slug,status,timezone,locale) values
  ('82000000-0000-4000-8000-000000000001','Inst contatos A','contacts-a','draft','UTC','pt-BR'),
  ('82000000-0000-4000-8000-000000000002','Inst contatos B','contacts-b','draft','UTC','pt-BR');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
  ('83000000-0000-4000-8000-000000000001','authenticated','authenticated','contacts-owner@invalid.test',now(),now(),now(),'{}','{}'),
  ('83000000-0000-4000-8000-000000000002','authenticated','authenticated','contacts-ops-b@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('84000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
  ('84000000-0000-4000-8000-000000000002','83000000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
  ('85000000-0000-4000-8000-000000000001'),('85000000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
  ('86000000-0000-4000-8000-000000000001','85000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000001'),
  ('86000000-0000-4000-8000-000000000002','85000000-0000-4000-8000-000000000002','83000000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '87000000-0000-4000-8000-000000000001','85000000-0000-4000-8000-000000000001',r.id,'platform'
from public.platform_roles r where r.code='owner';
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select '87000000-0000-4000-8000-000000000002','85000000-0000-4000-8000-000000000002',r.id,'institution','82000000-0000-4000-8000-000000000002'
from public.platform_roles r where r.code='operations';

create temporary table responses(k text primary key, body jsonb not null);
grant select,insert on responses to authenticated;

-- 3. escrita pelo owner de plataforma ---------------------------------------------
select set_config('request.jwt.claims',jsonb_build_object('sub','83000000-0000-4000-8000-000000000001',
  'session_id','84000000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;

insert into responses values('write1',public.superadmin_institution_contacts_edit_v1(
  '88000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000001',1,
  $j${"document":{"document_type":"CNPJ","document_ref":"11.222.333/0001-81"},
      "contact":{"email":"Escola@Exemplo.com","phone":"(81) 3333-4444","website_url":"https://escola.exemplo.com","whatsapp_number":"5581999990000"},
      "representatives":[{"first_name":"Ana","last_name":"Rep","email":"ana@exemplo.com","mobile_phone":"(81) 99999-1234","cpf":"529.982.247-25","date_of_birth":"1980-05-01","is_primary":true}],
      "administrators":[{"first_name":"Beto","last_name":"Admin","email":"beto@exemplo.com","level":"admin_master"},
                        {"first_name":"Carla","last_name":"Coord","level":"coordinator"}]}$j$));
select is((select body->>'ok' from responses where k='write1'),'true','escrita completa aceita');
select is((select (body->'data'->>'management_version')::int from responses where k='write1'),2,'versao avancou para 2');

-- replay idempotente
insert into responses values('replay',public.superadmin_institution_contacts_edit_v1(
  '88000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000001',1,
  $j${"document":{"document_type":"CNPJ","document_ref":"11.222.333/0001-81"},
      "contact":{"email":"Escola@Exemplo.com","phone":"(81) 3333-4444","website_url":"https://escola.exemplo.com","whatsapp_number":"5581999990000"},
      "representatives":[{"first_name":"Ana","last_name":"Rep","email":"ana@exemplo.com","mobile_phone":"(81) 99999-1234","cpf":"529.982.247-25","date_of_birth":"1980-05-01","is_primary":true}],
      "administrators":[{"first_name":"Beto","last_name":"Admin","email":"beto@exemplo.com","level":"admin_master"},
                        {"first_name":"Carla","last_name":"Coord","level":"coordinator"}]}$j$));
select ok((select body->>'ok'='true' and (body->'data'->>'replayed')::boolean from responses where k='replay'),
  'mesmo request_id devolve replay sem escrever de novo');

-- mesmo request_id com payload diferente
insert into responses values('reuse',public.superadmin_institution_contacts_edit_v1(
  '88000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000001',1,
  $j${"contact":{"email":"outro@exemplo.com"}}$j$));
select is((select body->'error'->>'code' from responses where k='reuse'),'SAI_INVALID_ARGUMENT',
  'request_id reutilizado com outro payload e recusado');

-- versao obsoleta
insert into responses values('stale',public.superadmin_institution_contacts_edit_v1(
  '88000000-0000-4000-8000-000000000002','82000000-0000-4000-8000-000000000001',1,
  $j${"contact":{"email":"outro@exemplo.com"}}$j$));
select is((select body->'error'->>'code' from responses where k='stale'),'SAI_CONCURRENT_CHANGE',
  'expected_version obsoleta responde SAI_CONCURRENT_CHANGE');

-- reload pelo detalhe
insert into responses values('detail1',public.superadmin_institution_detail_v2('82000000-0000-4000-8000-000000000001'));
select is((select body->'data'->>'document_ref' from responses where k='detail1'),'11222333000181','CNPJ persistido em digitos');
select is((select body->'data'->'contact'->>'email' from responses where k='detail1'),'escola@exemplo.com','contato da instituicao persistido e normalizado');
select is((select body->'data'->'contact'->>'whatsapp_number' from responses where k='detail1'),'+5581999990000','whatsapp em E.164');
select is((select jsonb_array_length(body->'data'->'representatives') from responses where k='detail1'),1,'um representante no detalhe');
select ok((select r->>'status'='active' and (r->>'is_primary')::boolean and r->>'display_name'='Ana Rep'
  and r->>'cpf_masked'='***.***.***-25' and r->>'email_masked'='a***@exemplo.com' and r->>'mobile_phone_masked'='*******1234'
  from responses, jsonb_array_elements(body->'data'->'representatives') r where k='detail1' limit 1),
  'representante ativo (maior de idade), primario e com contatos mascarados');
select is((select jsonb_array_length(body->'data'->'administrators') from responses where k='detail1'),2,'dois administradores no detalhe');
select ok((select bool_and((a->>'level') in ('admin_master','coordinator') and a->>'invitation_status'='not_sent')
  from responses, jsonb_array_elements(body->'data'->'administrators') a where k='detail1'),
  'administradores com level mapeado e sem login (o @ vem de person_handles quando 170100/210600 existem)');
select ok(not exists (select 1 from jsonb_each_text((select body->'data' from responses where k='detail1')) e
  where e.value like '%529982247%' or e.value like '%ana@exemplo.com%'),
  'nenhum CPF ou e-mail bruto de pessoa sai no detalhe');

-- 4. substituicao: remove Carla, rebaixa Beto para coordenador, Ana vira tambem admin ---
insert into responses values('write2',public.superadmin_institution_contacts_edit_v1(
  '88000000-0000-4000-8000-000000000003','82000000-0000-4000-8000-000000000001',2,
  ('{"administrators":[{"person_id":"'||(select a->>'person_id' from responses, jsonb_array_elements(body->'data'->'administrators') a where k='detail1' and a->>'display_name'='Beto Admin')||'","level":"coordinator"},'
   ||'{"person_id":"'||(select r->>'person_id' from responses, jsonb_array_elements(body->'data'->'representatives') r where k='detail1')||'","level":"authorized_administrator"}]}')::jsonb));
select is((select body->>'ok' from responses where k='write2'),'true','substituicao aceita');
insert into responses values('detail2',public.superadmin_institution_detail_v2('82000000-0000-4000-8000-000000000001'));
select is((select jsonb_array_length(body->'data'->'administrators') from responses where k='detail2'),2,'Carla saiu, Ana entrou como administradora');
select ok((select bool_and(case a->>'display_name' when 'Beto Admin' then a->>'level'='coordinator'
  when 'Ana Rep' then a->>'level'='authorized_administrator' and a->>'source_representative_id' is not null else false end)
  from responses, jsonb_array_elements(body->'data'->'administrators') a where k='detail2'),
  'levels atualizados e Ana ligada ao vinculo de representante');
select is((select jsonb_array_length(body->'data'->'representatives') from responses where k='detail2'),1,'representante preservado quando so administrators e enviado');

-- remove Ana das representantes: membership dela continua (e admin)
insert into responses values('write3',public.superadmin_institution_contacts_edit_v1(
  '88000000-0000-4000-8000-000000000004','82000000-0000-4000-8000-000000000001',3,
  $j${"representatives":[{"first_name":"Dora","last_name":"Nova"}]}$j$));
select is((select body->>'ok' from responses where k='write3'),'true','troca de representante aceita');
insert into responses values('detail3',public.superadmin_institution_detail_v2('82000000-0000-4000-8000-000000000001'));
select ok((select r->>'display_name'='Dora Nova' and r->>'status'='draft' and r->>'cpf_masked' is null
  from responses, jsonb_array_elements(body->'data'->'representatives') r where k='detail3'),
  'representante sem data de nascimento nasce draft');
select is((select jsonb_array_length(body->'data'->'administrators') from responses where k='detail3'),2,'Ana continua administradora depois de sair das representantes');

-- 5. validacao ----------------------------------------------------------------
create temporary table bad(k text primary key, payload jsonb not null);
insert into bad values
  ('cnpj',$j${"document":{"document_ref":"11.222.333/0001-82"}}$j$),
  ('cpf',$j${"representatives":[{"first_name":"X","last_name":"Y","cpf":"111.111.111-11"}]}$j$),
  ('level',$j${"administrators":[{"first_name":"X","last_name":"Y","level":"owner"}]}$j$),
  ('key',$j${"branding":{"display_name":"x"}}$j$),
  ('email',$j${"contact":{"email":"sem-arroba"}}$j$),
  ('twoprimary',$j${"representatives":[{"first_name":"A","last_name":"B","is_primary":true},{"first_name":"C","last_name":"D","is_primary":true}]}$j$),
  ('noname',$j${"administrators":[{"first_name":"So","level":"coordinator"}]}$j$),
  ('empty',$j${}$j$);
grant select on bad to authenticated;
select ok((select bool_and((public.superadmin_institution_contacts_edit_v1(gen_random_uuid(),
  '82000000-0000-4000-8000-000000000001',4,payload))->'error'->>'code'='SAI_INVALID_ARGUMENT') from bad),
  'CNPJ, CPF, level, chave, e-mail, dois primarios, nome faltando e payload vazio sao SAI_INVALID_ARGUMENT');
select is((select management_version from public.institutions where id='82000000-0000-4000-8000-000000000001'),4::bigint,
  'payloads invalidos nao avancam a versao');

-- 6. cross-tenant: operations escopado a B ---------------------------------------
select set_config('request.jwt.claims',jsonb_build_object('sub','83000000-0000-4000-8000-000000000002',
  'session_id','84000000-0000-4000-8000-000000000002','aal','aal1','role','authenticated')::text,true);
insert into responses values('xt_write',public.superadmin_institution_contacts_edit_v1(
  '88000000-0000-4000-8000-000000000009','82000000-0000-4000-8000-000000000001',4,
  $j${"contact":{"email":"invasor@exemplo.com"}}$j$));
select is((select body->'error'->>'code' from responses where k='xt_write'),'SAI_PERMISSION_DENIED','outro tenant nao edita contatos de A');
insert into responses values('xt_detail',public.superadmin_institution_detail_v2('82000000-0000-4000-8000-000000000001'));
select is((select body->'error'->>'code' from responses where k='xt_detail'),'SAI_PERMISSION_DENIED','outro tenant nao le representantes de A');
insert into responses values('own_write',public.superadmin_institution_contacts_edit_v1(
  '88000000-0000-4000-8000-000000000010','82000000-0000-4000-8000-000000000002',1,
  $j${"contact":{"email":"b@exemplo.com"},"administrators":[{"first_name":"Eva","last_name":"B","level":"admin_master"}]}$j$));
select is((select body->>'ok' from responses where k='own_write'),'true','operations escopado edita a propria instituicao');

-- 7. persistencia e auditoria -----------------------------------------------------
reset role;
select is((select email from public.institution_contacts where institution_id='82000000-0000-4000-8000-000000000001'),'escola@exemplo.com',
  'contato de A intacto apos a tentativa cruzada');
select is((select count(*) from public.institution_memberships where institution_id='82000000-0000-4000-8000-000000000001'
  and status='active' and revoked_at is null),3::bigint,'A tem 3 memberships ativas (Beto, Ana, Dora)');
select is((select role_code from public.institution_memberships m join public.people p on p.id=m.person_id
  where m.institution_id='82000000-0000-4000-8000-000000000001' and p.display_name='Dora Nova' and m.status='active'),
  'legal_representative','representante sem papel administrativo recebe role legal_representative');
select is((select count(*) from public.institution_memberships m join public.people p on p.id=m.person_id
  where m.institution_id='82000000-0000-4000-8000-000000000001' and p.display_name='Carla Coord' and m.status='inactive' and m.revoked_at is not null),
  1::bigint,'administradora removida fica inactive com revoked_at');
select is((select count(*) from app_private.person_identity_identifiers i join public.people p on p.id=i.person_id
  where p.display_name='Ana Rep' and i.status='active' and i.hmac_key_version=1 and octet_length(i.normalized_value_hmac)=32),
  1::bigint,'CPF guardado como HMAC de 32 bytes com versao de chave 1');
select is((select count(*) from audit.audit_logs where action_code in ('institution.edit_contacts','institution.edit_contacts.replay')
  and institution_id in ('82000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000002') and outcome='success'),5::bigint,
  'auditoria interna registra as 4 escritas e o replay');
select ok(exists (select 1 from audit.audit_logs where action_code='institution.edit_contacts' and outcome='denied'
  and reason_code='SAI_PERMISSION_DENIED'),'negativa cross-tenant auditada');

select * from finish();
rollback;
