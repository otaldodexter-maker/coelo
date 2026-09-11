begin;

create extension if not exists pgtap with schema extensions;

select plan(24);

-- Fixtures na forma de producao (ids com prefixo 8d/8e/8f desta suite).
insert into public.institution_types(id,code,name,status) values
  ('8d000000-0000-4000-8000-000000000201','structure-handles-school','Structure Handles School','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
  ('8d000000-0000-4000-8000-000000000101','Structure Handles A','structure-handles-a','active','8d000000-0000-4000-8000-000000000201'),
  ('8d000000-0000-4000-8000-000000000102','Structure Handles B','structure-handles-b','active','8d000000-0000-4000-8000-000000000201');
insert into public.unit_types(id,code,name,status) values
  ('8d0000f0-0000-4000-8000-000000000201','structure-handles-u0','Tipo de unidade da fixture','active');
insert into public.units(id,institution_id,name,slug,status,unit_type_id,handle) values
  ('8d000000-0000-4000-8000-000000000011','8d000000-0000-4000-8000-000000000101','Unidade Centro','structure-handles-unit-a','active','8d0000f0-0000-4000-8000-000000000201','centro.structurehandlesa'),
  ('8d000000-0000-4000-8000-000000000013','8d000000-0000-4000-8000-000000000102','Unidade B','structure-handles-unit-b','active','8d0000f0-0000-4000-8000-000000000201','unidadeb.structurehandlesb');
insert into public.groups(id,institution_id,unit_id,name,group_type,status,management_version) values
  ('8d000000-0000-4000-8000-000000000001','8d000000-0000-4000-8000-000000000101','8d000000-0000-4000-8000-000000000011','Turma Azul','class','active',1),
  ('8d000000-0000-4000-8000-000000000002','8d000000-0000-4000-8000-000000000101','8d000000-0000-4000-8000-000000000011','Turma Azul','class','active',1),
  ('8d000000-0000-4000-8000-000000000003','8d000000-0000-4000-8000-000000000102','8d000000-0000-4000-8000-000000000013','Turma Beta','class','active',1);

select is(
  (select handle from public.groups where id='8d000000-0000-4000-8000-000000000001'),
  'turmaazul.centro.structurehandlesa',
  'a turma nasce com @nomedaturma.nomedaunidade gerado pelo gatilho');
select ok(
  (select handle from public.groups where id='8d000000-0000-4000-8000-000000000002')
    ~ '^turmaazul\.centro\.structurehandlesa_[0-9a-f]{8}$',
  'turma homonima na mesma unidade recebe sufixo do id');
select is(
  (select handle_last_changed_at from public.groups where id='8d000000-0000-4000-8000-000000000001'),
  null,
  'handle gerado nao conta como troca');

-- identidades internas: owner de plataforma (1) e operations escopado em B (2)
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
values
  ('8e000000-0000-4000-8000-000000000001','authenticated','authenticated','structure-handles-owner@invalid.test',now(),now(),now(),'{}','{}'),
  ('8e000000-0000-4000-8000-000000000002','authenticated','authenticated','structure-handles-scope-b@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('8f000000-0000-4000-8000-000000000001','8e000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
  ('8f000000-0000-4000-8000-000000000002','8e000000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
  ('8e100000-0000-4000-8000-000000000001'),('8e100000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id,status,suspended_at,revoked_at) values
  ('8e200000-0000-4000-8000-000000000001','8e100000-0000-4000-8000-000000000001','8e000000-0000-4000-8000-000000000001','active',null,null),
  ('8e200000-0000-4000-8000-000000000002','8e100000-0000-4000-8000-000000000002','8e000000-0000-4000-8000-000000000002','active',null,null);
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id,status)
select m.id,m.identity_id,r.id,m.scope_kind::app_private.superadmin_internal_scope_kind,m.scope_institution_id,'active'
from (values
  ('8e300000-0000-4000-8000-000000000001'::uuid,'8e100000-0000-4000-8000-000000000001'::uuid,'owner','platform',null::uuid),
  ('8e300000-0000-4000-8000-000000000002'::uuid,'8e100000-0000-4000-8000-000000000002'::uuid,'operations','institution','8d000000-0000-4000-8000-000000000102'::uuid)
) m(id,identity_id,role_code,scope_kind,scope_institution_id)
join public.platform_roles r on r.code=m.role_code;

create temporary table sh_responses(seq integer primary key, body jsonb not null);
grant select,insert on sh_responses to authenticated;

-- 1) sem sessao: negativa unificada
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
insert into sh_responses values(1, public.superadmin_structure_handle_availability_v1('group','turma.nova',null));
insert into sh_responses values(2, public.superadmin_structure_handle_set_v1(gen_random_uuid(),'group','8d000000-0000-4000-8000-000000000001',1,'turma.nova'));
reset role;
select is((select body#>>'{error,code}' from sh_responses where seq=1),'SAI_AUTH_REQUIRED','disponibilidade sem sessao nega');
select is((select body#>>'{error,code}' from sh_responses where seq=2),'SAI_AUTH_REQUIRED','troca sem sessao nega');

-- 2) owner de plataforma: disponibilidade
select set_config('request.jwt.claims',jsonb_build_object('sub','8e000000-0000-4000-8000-000000000001','session_id','8f000000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into sh_responses values(3, public.superadmin_structure_handle_availability_v1('group','@Turma.Nova',null));
insert into sh_responses values(4, public.superadmin_structure_handle_availability_v1('group','turmaazul.centro.structurehandlesa',null));
insert into sh_responses values(5, public.superadmin_structure_handle_availability_v1('group','turmaazul.centro.structurehandlesa','8d000000-0000-4000-8000-000000000001'));
insert into sh_responses values(6, public.superadmin_structure_handle_availability_v1('unit','coelo',null));
insert into sh_responses values(7, public.superadmin_structure_handle_availability_v1('unit','structure-handles-a',null));
insert into sh_responses values(8, public.superadmin_structure_handle_availability_v1('unit','a',null));
insert into sh_responses values(9, public.superadmin_structure_handle_availability_v1('planet','x',null));
reset role;
select is((select body->'data' from sh_responses where seq=3) - 'correlation_id',
  '{"kind":"group","normalized":"turma.nova","available":true,"reason":null}'::jsonb,
  'disponibilidade normaliza @ e maiusculas e responde disponivel');
select is((select body#>>'{data,reason}' from sh_responses where seq=4),'HANDLE_TAKEN','@ de turma existente esta em uso');
select is((select body#>>'{data,available}' from sh_responses where seq=5),'true','a propria entidade e excluida da checagem');
select is((select body#>>'{data,reason}' from sh_responses where seq=6),'HANDLE_TAKEN','coelo e reservado');
select is((select body#>>'{data,reason}' from sh_responses where seq=7),'HANDLE_INVALID','hifen nao vale em unidade (CHECK de producao)');
select is((select body#>>'{data,reason}' from sh_responses where seq=8),'HANDLE_INVALID','handle curto demais e invalido');
select is((select body#>>'{error,code}' from sh_responses where seq=9),'SAI_INVALID_ARGUMENT','kind desconhecido e argumento invalido');

-- 3) troca do @ da turma, replay, cooldown e conflito de versao
select set_config('request.jwt.claims',jsonb_build_object('sub','8e000000-0000-4000-8000-000000000001','session_id','8f000000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into sh_responses values(10, public.superadmin_structure_handle_set_v1('8d900000-0000-4000-8000-000000000001','group','8d000000-0000-4000-8000-000000000001',1,'@Turma.Azul.Nova'));
insert into sh_responses values(11, public.superadmin_structure_handle_set_v1('8d900000-0000-4000-8000-000000000001','group','8d000000-0000-4000-8000-000000000001',1,'turma.azul.nova'));
insert into sh_responses values(12, public.superadmin_structure_handle_set_v1('8d900000-0000-4000-8000-000000000002','group','8d000000-0000-4000-8000-000000000001',2,'turma.azul.outra'));
insert into sh_responses values(13, public.superadmin_structure_handle_set_v1('8d900000-0000-4000-8000-000000000003','group','8d000000-0000-4000-8000-000000000003',7,'turma.beta.nova'));
insert into sh_responses values(14, public.superadmin_structure_handle_set_v1('8d900000-0000-4000-8000-000000000004','unit','8d000000-0000-4000-8000-000000000011',1,'turma.azul.nova'));
reset role;
select is((select body->'data' from sh_responses where seq=10) - 'correlation_id',
  '{"kind":"group","entity_id":"8d000000-0000-4000-8000-000000000001","handle":"turma.azul.nova","management_version":2,"replayed":false}'::jsonb,
  'owner troca o @ da turma e a versao avanca');
select is((select handle||'|'||management_version from public.groups where id='8d000000-0000-4000-8000-000000000001'),
  'turma.azul.nova|2','a turma persiste o @ novo e a versao 2');
select ok((select handle_last_changed_at from public.groups where id='8d000000-0000-4000-8000-000000000001') is not null,
  'handle_last_changed_at e gravado na troca');
select is((select body#>>'{data,replayed}' from sh_responses where seq=11),'true','replay do mesmo request_id devolve o recibo');
select is((select body#>>'{error,code}' from sh_responses where seq=12),'SAI_HANDLE_COOLDOWN','segunda troca em 30 dias e bloqueada');
select ok((select body#>>'{error,next_allowed_at}' from sh_responses where seq=12) is not null,'cooldown informa next_allowed_at');
select is((select body#>>'{error,code}' from sh_responses where seq=13),'SAI_CONCURRENT_CHANGE','versao errada e conflito');
select is((select body#>>'{error,code}' from sh_responses where seq=14),'SAI_HANDLE_TAKEN','@ usado por turma nao pode ir para unidade (unicidade global)');
select is((select count(*) from audit.audit_logs where action_code='group.handle.change' and outcome='success'),1::bigint,
  'a troca gera exatamente um evento de auditoria de sucesso');

-- 4) operador escopado na instituicao B nao alcanca a turma de A
select set_config('request.jwt.claims',jsonb_build_object('sub','8e000000-0000-4000-8000-000000000002','session_id','8f000000-0000-4000-8000-000000000002','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into sh_responses values(20, public.superadmin_structure_handle_set_v1('8d900000-0000-4000-8000-000000000020','group','8d000000-0000-4000-8000-000000000002',1,'turma.cross'));
insert into sh_responses values(21, public.superadmin_structure_handle_set_v1('8d900000-0000-4000-8000-000000000021','group','8d000000-0000-4000-8000-000000000003',1,'turma.beta.propria'));
reset role;
select is((select body#>>'{error,code}' from sh_responses where seq=20),'SAI_NOT_FOUND','outro tenant e indistinguivel de id inexistente');
select is((select handle from public.groups where id='8d000000-0000-4000-8000-000000000002') ~ '^turmaazul', true,
  'a turma de A nao mudou');
select is((select body#>>'{data,handle}' from sh_responses where seq=21),'turma.beta.propria',
  'operations escopado em B troca o @ de turma da propria instituicao');

select * from finish();
rollback;
