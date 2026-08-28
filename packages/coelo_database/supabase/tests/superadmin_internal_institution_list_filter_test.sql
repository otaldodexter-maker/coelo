begin;
create extension if not exists pgtap with schema extensions;
select plan(35);

select has_function('public','superadmin_institution_directory_v2',
  array['jsonb','integer','integer','text','boolean'],
  'Institution directory v2 has the approved signature');
select has_function('public','superadmin_institution_filter_options_v2',
  array['text[]','text[]'],
  'Institution filter options v2 has the approved signature');
select ok((select bool_and(p.prosecdef and p.provolatile='v'
    and r.rolname='postgres' and coalesce(p.proconfig,'{}'::text[])
      @> array['search_path=""']::text[])
  from pg_proc p join pg_roles r on r.oid=p.proowner
  where p.oid in(
    'public.superadmin_institution_directory_v2(jsonb,integer,integer,text,boolean)'::regprocedure,
    'public.superadmin_institution_filter_options_v2(text[],text[])'::regprocedure)),
  'public wrappers are volatile postgres-owned hardened definers');
select ok(
  has_function_privilege('authenticated',
    'public.superadmin_institution_directory_v2(jsonb,integer,integer,text,boolean)','execute')
  and has_function_privilege('authenticated',
    'public.superadmin_institution_filter_options_v2(text[],text[])','execute')
  and not has_function_privilege('anon',
    'public.superadmin_institution_directory_v2(jsonb,integer,integer,text,boolean)','execute')
  and not has_function_privilege('service_role',
    'public.superadmin_institution_directory_v2(jsonb,integer,integer,text,boolean)','execute')
  and not has_function_privilege('anon',
    'public.superadmin_institution_filter_options_v2(text[],text[])','execute')
  and not has_function_privilege('service_role',
    'public.superadmin_institution_filter_options_v2(text[],text[])','execute')
  and not exists(select 1 from pg_proc p,
    lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
    where p.oid in(
      'public.superadmin_institution_directory_v2(jsonb,integer,integer,text,boolean)'::regprocedure,
      'public.superadmin_institution_filter_options_v2(text[],text[])'::regprocedure)
      and a.grantee=0 and a.privilege_type='EXECUTE'),
  'only authenticated can execute the public wrappers');
select ok(not exists(select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace,
    lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
    where n.nspname='app_private'
      and p.proname like 'superadmin_institution%v2'
      and (a.grantee=0 or a.grantee in(
        'anon'::regrole,'authenticated'::regrole,'service_role'::regrole))
      and a.privilege_type='EXECUTE')
  and pg_get_functiondef(
    'public.superadmin_institution_directory_v2(jsonb,integer,integer,text,boolean)'::regprocedure)
      like '%require_superadmin_internal_context%'
  and pg_get_functiondef(
    'public.superadmin_institution_directory_v2(jsonb,integer,integer,text,boolean)'::regprocedure)
      not like '%current_person_id%',
  'private helpers are client-inaccessible and wrappers use internal Auth context');

insert into public.institution_types(id,code,name) values
  ('71000000-0000-4000-8000-000000000001','synthetic-school','Escola'),
  ('71000000-0000-4000-8000-000000000002','synthetic-course','Curso'),
  ('71000000-0000-4000-8000-000000000003','unused-type','Invisível');
insert into public.plans(id,code,name) values
  ('71100000-0000-4000-8000-000000000001','synthetic-basic','Essencial'),
  ('71100000-0000-4000-8000-000000000002','synthetic-full','Completo'),
  ('71100000-0000-4000-8000-000000000003','unused-plan','Invisível');
insert into public.institutions(
  id,public_name,trade_name,legal_name,slug,primary_domain,document_ref,status,
  institution_type_id) values
  ('71200000-0000-4000-8000-000000000001','Literal % Escola','Alfa','Alfa Legal',
    'synthetic-list-a','a.invalid.test','secret-a','active',
    '71000000-0000-4000-8000-000000000001'),
  ('71200000-0000-4000-8000-000000000002','Literal _ Escola','Beta','Beta Legal',
    'synthetic-list-b','b.invalid.test','secret-b','draft',
    '71000000-0000-4000-8000-000000000002'),
  ('71200000-0000-4000-8000-000000000003',E'Literal \\ Escola','Gama','Gama Legal',
    'synthetic-list-c',null,'secret-c','suspended',null),
  ('71200000-0000-4000-8000-000000000004','Empate','Delta','Delta Legal',
    'synthetic-list-d',null,'secret-d','active',
    '71000000-0000-4000-8000-000000000001');
insert into public.institution_addresses(
  institution_id,state,city,district,street,number,complement,postal_code) values
  ('71200000-0000-4000-8000-000000000001',' SP ',' São Paulo ',' Centro ','Rua A','1','Sala A','01000-000'),
  ('71200000-0000-4000-8000-000000000002','RJ','Rio de Janeiro','Copacabana','Rua B','2',null,'22000-000'),
  ('71200000-0000-4000-8000-000000000004','SP','Campinas','Centro','Rua D','4',null,'13000-000');
insert into public.institution_contacts(institution_id,email,phone,mobile_phone) values
  ('71200000-0000-4000-8000-000000000001','a@invalid.test','1100000000','11900000000'),
  ('71200000-0000-4000-8000-000000000002','b@invalid.test','2100000000','21900000000');
insert into public.institution_subscriptions(id,institution_id,plan_id,status,created_at) values
  ('71300000-0000-4000-8000-000000000001','71200000-0000-4000-8000-000000000001',
    '71100000-0000-4000-8000-000000000001','active',now()),
  ('71300000-0000-4000-8000-000000000002','71200000-0000-4000-8000-000000000002',
    '71100000-0000-4000-8000-000000000002','active',now()),
  ('71300000-0000-4000-8000-000000000004','71200000-0000-4000-8000-000000000004',
    '71100000-0000-4000-8000-000000000001','active',now());
insert into public.units(id,institution_id,name,slug,status,institution_type_id) values
  ('71400000-0000-4000-8000-000000000001','71200000-0000-4000-8000-000000000001','Ativa','active-a','active','71000000-0000-4000-8000-000000000001'),
  ('71400000-0000-4000-8000-000000000002','71200000-0000-4000-8000-000000000001','Arquivada','archived-a','archived','71000000-0000-4000-8000-000000000001');
insert into public.groups(id,institution_id,unit_id,name,status) values
  ('71500000-0000-4000-8000-000000000001','71200000-0000-4000-8000-000000000001','71400000-0000-4000-8000-000000000001','Ativo','active'),
  ('71500000-0000-4000-8000-000000000002','71200000-0000-4000-8000-000000000001','71400000-0000-4000-8000-000000000002','Arquivado','archived');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data) values
  ('72000000-0000-4000-8000-000000000001','authenticated','authenticated','list-ops@invalid.test',now(),now(),now(),'{}','{}'),
  ('72000000-0000-4000-8000-000000000002','authenticated','authenticated','list-scoped@invalid.test',now(),now(),now(),'{}','{}'),
  ('72000000-0000-4000-8000-000000000003','authenticated','authenticated','list-owner@invalid.test',now(),now(),now(),'{}','{}'),
  ('72000000-0000-4000-8000-000000000004','authenticated','authenticated','list-auditor@invalid.test',now(),now(),now(),'{}','{}'),
  ('72000000-0000-4000-8000-000000000005','authenticated','authenticated','list-support@invalid.test',now(),now(),now(),'{}','{}'),
  ('72000000-0000-4000-8000-000000000006','authenticated','authenticated','list-content@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('72100000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
  ('72100000-0000-4000-8000-000000000002','72000000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour'),
  ('72100000-0000-4000-8000-000000000003','72000000-0000-4000-8000-000000000003',now(),now(),'aal1',now()+interval '1 hour'),
  ('72100000-0000-4000-8000-000000000004','72000000-0000-4000-8000-000000000003',now(),now(),'aal2',now()+interval '1 hour'),
  ('72100000-0000-4000-8000-000000000005','72000000-0000-4000-8000-000000000004',now(),now(),'aal1',now()+interval '1 hour'),
  ('72100000-0000-4000-8000-000000000006','72000000-0000-4000-8000-000000000005',now(),now(),'aal1',now()+interval '1 hour'),
  ('72100000-0000-4000-8000-000000000007','72000000-0000-4000-8000-000000000006',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
  ('72200000-0000-4000-8000-000000000001'),('72200000-0000-4000-8000-000000000002'),
  ('72200000-0000-4000-8000-000000000003'),('72200000-0000-4000-8000-000000000004'),
  ('72200000-0000-4000-8000-000000000005'),('72200000-0000-4000-8000-000000000006');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
select ('72400000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
  ('72200000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
  ('72000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid
from generate_series(1,6) n;
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select ('72300000-0000-4000-8000-'||lpad(v.n::text,12,'0'))::uuid,
  ('72200000-0000-4000-8000-'||lpad(v.n::text,12,'0'))::uuid,r.id,
  v.scope_kind::app_private.superadmin_internal_scope_kind,case when v.scope_kind='institution'
    then '71200000-0000-4000-8000-000000000001'::uuid end
from (values (1,'operations','platform'),(2,'operations','institution'),
  (3,'owner','platform'),(4,'auditor','platform'),(5,'support','platform'),
  (6,'content','platform')) v(n,role_code,scope_kind)
join public.platform_roles r on r.code=v.role_code;

create temporary table institution_list_responses(case_name text primary key,body jsonb not null);
grant select,insert on institution_list_responses to authenticated;

select set_config('request.jwt.claims',jsonb_build_object('sub',
  '72000000-0000-4000-8000-000000000001','session_id',
  '72100000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_list_responses values
  ('default',public.superadmin_institution_directory_v2()),
  ('empty-type-ids',public.superadmin_institution_directory_v2('{"type_ids":[]}')),
  ('percent',public.superadmin_institution_directory_v2('{"search":"%"}')),
  ('underscore',public.superadmin_institution_directory_v2('{"search":"_"}')),
  ('backslash',public.superadmin_institution_directory_v2(jsonb_build_object('search',E'\\'))),
  ('combined',public.superadmin_institution_directory_v2(
    '{"statuses":["active"],"states":["SP"],"cities":["São Paulo"],"districts":["Centro"],"type_ids":["71000000-0000-4000-8000-000000000001"],"plan_id":"71100000-0000-4000-8000-000000000001"}')),
  ('missing',public.superadmin_institution_directory_v2(
    '{"type_ids":["71000000-0000-4000-8000-00000000ffff"],"plan_id":"71100000-0000-4000-8000-00000000ffff"}')),
  ('page',public.superadmin_institution_directory_v2('{}',1,1,'public_name',true)),
  ('null-last',public.superadmin_institution_directory_v2('{}',50,0,'plan_name',true)),
  ('options',public.superadmin_institution_filter_options_v2()),
  ('options-sp',public.superadmin_institution_filter_options_v2(array['SP'],array[]::text[])),
  ('options-city',public.superadmin_institution_filter_options_v2(array['SP'],array['São Paulo']));
reset role;

select ok((select (body->>'ok')::boolean and body#>>'{data,total_count}'='4'
    and body#>>'{data,limit}'='50' and body#>>'{data,offset}'='0'
  from institution_list_responses where case_name='default')
  and (select body#>>'{data,total_count}'='4'
    from institution_list_responses where case_name='empty-type-ids'),
  'platform Operations receives defaults and empty type_ids does not filter');

select set_config('request.jwt.claims',jsonb_build_object('sub',
  '72000000-0000-4000-8000-000000000002','session_id',
  '72100000-0000-4000-8000-000000000002','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_list_responses values
  ('scoped-list',public.superadmin_institution_directory_v2()),
  ('scoped-options',public.superadmin_institution_filter_options_v2());
reset role;
select ok((select body#>>'{data,total_count}'='1'
    and body#>>'{data,items,0,id}'='71200000-0000-4000-8000-000000000001'
  from institution_list_responses where case_name='scoped-list'),
  'institution-scoped Operations sees only its institution');
select ok((select jsonb_array_length(body#>'{data,plans}')=1
    and body#>>'{data,plans,0,id}'='71100000-0000-4000-8000-000000000001'
  from institution_list_responses where case_name='scoped-options'),
  'institution-scoped options disclose only visible values');

select set_config('request.jwt.claims',jsonb_build_object('sub',
  '72000000-0000-4000-8000-000000000003','session_id',
  '72100000-0000-4000-8000-000000000004','aal','aal2','role','authenticated')::text,true);
set local role authenticated;
insert into institution_list_responses values
  ('owner',public.superadmin_institution_directory_v2());
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',
  '72000000-0000-4000-8000-000000000004','session_id',
  '72100000-0000-4000-8000-000000000005','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_list_responses values
  ('auditor',public.superadmin_institution_directory_v2());
reset role;
select ok(not exists(select 1 from institution_list_responses
  where case_name in('owner','auditor') and (body->>'ok')::boolean is distinct from true),
  'platform Owner at AAL2 and Auditor are allowlisted');

select set_config('request.jwt.claims',jsonb_build_object('sub',
  '72000000-0000-4000-8000-000000000003','session_id',
  '72100000-0000-4000-8000-000000000003','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_list_responses values ('owner-aal1',public.superadmin_institution_directory_v2());
reset role;
select is((select body#>>'{error,code}' from institution_list_responses where case_name='owner-aal1'),
  'SAI_MFA_REQUIRED','Owner at AAL1 is denied');

select set_config('request.jwt.claims',jsonb_build_object('sub',
  '72000000-0000-4000-8000-000000000005','session_id',
  '72100000-0000-4000-8000-000000000006','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_list_responses values ('support',public.superadmin_institution_directory_v2());
reset role;
select is((select body#>>'{error,code}' from institution_list_responses where case_name='support'),
  'SAI_PERMISSION_DENIED','Support is denied');
select set_config('request.jwt.claims',jsonb_build_object('sub',
  '72000000-0000-4000-8000-000000000006','session_id',
  '72100000-0000-4000-8000-000000000007','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_list_responses values ('content',public.superadmin_institution_filter_options_v2());
reset role;
select is((select body#>>'{error,code}' from institution_list_responses where case_name='content'),
  'SAI_PERMISSION_DENIED','Content is denied');

select ok((select (select array_agg(key order by key) from jsonb_object_keys(body) key)
    =array['data','error','ok']::text[]
    and (select array_agg(key order by key) from jsonb_object_keys(body->'data') key)
      =array['items','limit','offset','total_count']::text[]
  from institution_list_responses where case_name='default'),
  'list returns the exact root envelope');
select ok((select (select array_agg(key order by key)
    from jsonb_object_keys(body#>'{data,items,0}') key)=array[
      'city','complement','contact_email','contact_mobile_phone','contact_phone',
      'district','groups_count','id','institution_type_id','legal_name','number',
      'plan_id','plan_name','postal_code','primary_domain','public_name','state',
      'status','street','trade_name','type_name','units_count']::text[]
  from institution_list_responses where case_name='default'),
  'list item exposes only the approved fields');
select ok((select (select array_agg(key order by key) from jsonb_object_keys(body->'data') key)
    =array['cities','districts','plans','states','types']::text[]
    and (select array_agg(key order by key) from jsonb_object_keys(body) key)
      =array['data','error','ok']::text[]
  from institution_list_responses where case_name='options'),
  'options returns the exact data envelope');
select ok(not exists(select 1 from institution_list_responses r,
    lateral jsonb_array_elements(r.body#>'{data,plans}') item
    where r.case_name='options' and
      (select array_agg(key order by key) from jsonb_object_keys(item) key)
        <>array['id','label']::text[]),
  'option objects expose exactly id and label');
select ok((select body#>>'{data,total_count}'='1'
    and body#>>'{data,items,0,id}'='71200000-0000-4000-8000-000000000001'
  from institution_list_responses where case_name='percent'),
  'percent is searched literally');
select ok((select body#>>'{data,total_count}'='1'
    and body#>>'{data,items,0,id}'='71200000-0000-4000-8000-000000000002'
  from institution_list_responses where case_name='underscore'),
  'underscore is searched literally');
select ok((select body#>>'{data,total_count}'='1'
    and body#>>'{data,items,0,id}'='71200000-0000-4000-8000-000000000003'
  from institution_list_responses where case_name='backslash'),
  'backslash is searched literally');
select ok((select body#>>'{data,total_count}'='1'
    and body#>>'{data,items,0,id}'='71200000-0000-4000-8000-000000000001'
    and body#>>'{data,items,0,units_count}'='1'
    and body#>>'{data,items,0,groups_count}'='1'
  from institution_list_responses where case_name='combined'),
  'filters intersect and archived units/groups are not counted');
select ok((select body#>>'{data,total_count}'='0' and body#>'{data,items}'='[]'::jsonb
  from institution_list_responses where case_name='missing'),
  'well-formed missing plan and type IDs return an empty success');

select set_config('request.jwt.claims',jsonb_build_object('sub',
  '72000000-0000-4000-8000-000000000001','session_id',
  '72100000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into institution_list_responses values
  ('bad-shapes',public.superadmin_institution_directory_v2('[]')),
  ('extra-key',public.superadmin_institution_directory_v2('{"unknown":true}')),
  ('bad-uuid',public.superadmin_institution_directory_v2('{"type_ids":["bad"]}')),
  ('empty-search',public.superadmin_institution_directory_v2('{"search":" "}')),
  ('empty-state',public.superadmin_institution_directory_v2('{"states":[" "]}')),
  ('duplicates',public.superadmin_institution_directory_v2('{"states":["SP","sp"]}')),
  ('uuid-duplicates',public.superadmin_institution_directory_v2(
    '{"type_ids":["71000000-0000-4000-8000-000000000001","{71000000-0000-4000-8000-000000000001}"]}')),
  ('options-duplicates',public.superadmin_institution_filter_options_v2(array['SP','sp'],array[]::text[])),
  ('options-empty',public.superadmin_institution_filter_options_v2(array[' '],array[]::text[])),
  ('status-cardinality',public.superadmin_institution_directory_v2(
    '{"statuses":["draft","onboarding","active","inactive","suspended","archived","active"]}')),
  ('state-cardinality',public.superadmin_institution_directory_v2(jsonb_build_object(
    'states',(select jsonb_agg('S'||n) from generate_series(1,21)n)))),
  ('options-cardinality',public.superadmin_institution_filter_options_v2(
    (select array_agg('S'||n) from generate_series(1,21)n),array[]::text[])),
  ('oversize-filter',public.superadmin_institution_directory_v2(
    jsonb_build_object('states',jsonb_build_array(repeat('S',241))))),
  ('oversize-total',public.superadmin_institution_directory_v2(jsonb_build_object(
    'states',(select jsonb_agg(repeat('s',190)||n) from generate_series(1,20)n),
    'cities',(select jsonb_agg(repeat('c',190)||n) from generate_series(1,20)n),
    'districts',(select jsonb_agg(repeat('d',190)||n) from generate_series(1,20)n)))) ,
  ('oversize-options',public.superadmin_institution_filter_options_v2(
    array[repeat('S',241)],array[]::text[])),
  ('null-filter',public.superadmin_institution_directory_v2(null)),
  ('null-limit',public.superadmin_institution_directory_v2('{}',null)),
  ('null-offset',public.superadmin_institution_directory_v2('{}',50,null)),
  ('null-sort',public.superadmin_institution_directory_v2('{}',50,0,null)),
  ('null-direction',public.superadmin_institution_directory_v2('{}',50,0,'public_name',null)),
  ('null-states',public.superadmin_institution_filter_options_v2(null,array[]::text[])),
  ('null-cities',public.superadmin_institution_filter_options_v2(array[]::text[],null)),
  ('limit-zero',public.superadmin_institution_directory_v2('{}',0)),
  ('limit-high',public.superadmin_institution_directory_v2('{}',101)),
  ('offset-negative',public.superadmin_institution_directory_v2('{}',50,-1)),
  ('offset-high',public.superadmin_institution_directory_v2('{}',50,10001)),
  ('bad-sort',public.superadmin_institution_directory_v2('{}',50,0,'id;drop table public.institutions'));
reset role;
select ok(not exists(select 1 from institution_list_responses
  where case_name in('bad-shapes','extra-key','bad-uuid','empty-search','empty-state',
      'options-empty','oversize-filter','oversize-total','oversize-options')
    and (body#>>'{error,code}' is distinct from 'SAI_INVALID_ARGUMENT'
      or body#>>'{error,http_status}' is distinct from '400')),
  'wrong filter shapes, extra keys and malformed UUIDs are rejected');
select ok(not exists(select 1 from institution_list_responses
  where case_name in('duplicates','uuid-duplicates','options-duplicates')
    and body#>>'{error,code}' is distinct from 'SAI_INVALID_ARGUMENT'),
  'case-insensitive duplicate filters are rejected');
select ok(not exists(select 1 from institution_list_responses
  where case_name in('status-cardinality','state-cardinality','options-cardinality')
    and body#>>'{error,code}' is distinct from 'SAI_INVALID_ARGUMENT'),
  'filter cardinality limits are enforced');
select ok(not exists(select 1 from institution_list_responses
  where case_name like 'null-%' and case_name<>'null-last'
    and body#>>'{error,code}' is distinct from 'SAI_INVALID_ARGUMENT'),
  'explicit NULL is invalid for every public argument');
select ok(not exists(select 1 from institution_list_responses
  where case_name in('limit-zero','limit-high','offset-negative','offset-high')
    and body#>>'{error,code}' is distinct from 'SAI_INVALID_ARGUMENT'),
  'limit 1..100 and offset 0..10000 boundaries are enforced');
select is((select body#>>'{error,code}' from institution_list_responses where case_name='bad-sort'),
  'SAI_INVALID_ARGUMENT','sort is allowlisted and injection-shaped input is rejected');

set local role authenticated;
do $sorts$
declare sort_name text;
begin
  foreach sort_name in array array['public_name','type_name','units_count','groups_count',
    'plan_name','status','contact_email','contact_phone','contact_mobile_phone',
    'primary_domain','street','postal_code','number','complement','district','city','state']
  loop
    if (public.superadmin_institution_directory_v2('{}',50,0,sort_name,true)->>'ok')::boolean
      is distinct from true
      or (public.superadmin_institution_directory_v2('{}',50,0,sort_name,false)->>'ok')::boolean
        is distinct from true then
      raise exception 'approved sort failed: %',sort_name;
    end if;
  end loop;
end
$sorts$;
reset role;
select ok((select body#>>'{data,total_count}'='4' and jsonb_array_length(body#>'{data,items}')=1
    and body#>>'{data,limit}'='1' and body#>>'{data,offset}'='1'
  from institution_list_responses where case_name='page'),
  'pagination preserves total_count and exact limit/offset');
select ok((select body#>>'{data,items,1,id}'='71200000-0000-4000-8000-000000000001'
    and body#>>'{data,items,2,id}'='71200000-0000-4000-8000-000000000004'
    and body#>>'{data,items,3,id}'='71200000-0000-4000-8000-000000000003'
  from institution_list_responses where case_name='null-last'),
  'sorting is NULLS LAST with deterministic id tie-break semantics');
select ok((select not ((body#>'{data,plans}') @>
      '[{"id":"71100000-0000-4000-8000-000000000003"}]'::jsonb)
    and not ((body#>'{data,types}') @>
      '[{"id":"71000000-0000-4000-8000-000000000003"}]'::jsonb)
    and body#>>'{data,states,0,id}'='RJ' and body#>>'{data,states,1,id}'='SP'
    and body#>>'{data,plans,0,label}'='Completo'
    and body#>>'{data,plans,1,label}'='Essencial'
    and body#>'{data,cities}'='[]'::jsonb and body#>'{data,districts}'='[]'::jsonb
  from institution_list_responses where case_name='options')
  and (select body#>>'{data,cities,0,id}'='Campinas'
      and body#>>'{data,cities,1,id}'='São Paulo'
    from institution_list_responses where case_name='options-sp')
  and (select body#>>'{data,districts,0,id}'='Centro'
    from institution_list_responses where case_name='options-city'),
  'options are visible-only, ordered, and honor state/city dependencies');

create temporary table institution_list_audit_baseline(action_code text primary key,value bigint not null);
insert into institution_list_audit_baseline values
  ('institution.list',(select count(*) from audit.audit_logs where action_code='institution.list')),
  ('institution.filter_options',(select count(*) from audit.audit_logs
    where action_code='institution.filter_options'));
set local role authenticated;
insert into institution_list_responses values
  ('audit-list-probe',public.superadmin_institution_directory_v2()),
  ('audit-options-probe',public.superadmin_institution_filter_options_v2());
reset role;
select ok((select count(*)=(select value+1 from institution_list_audit_baseline
      where action_code='institution.list')
    from audit.audit_logs where action_code='institution.list')
  and (select count(*)=(select value+1 from institution_list_audit_baseline
      where action_code='institution.filter_options')
    from audit.audit_logs where action_code='institution.filter_options'),
  'each successful probe appends exactly one list or options audit event');
select ok(not exists(select 1 from institution_list_responses r
    left join audit.audit_logs a on a.correlation_id=(r.body#>>'{error,correlation_id}')::uuid
    where r.case_name in('owner-aal1','support','content','bad-sort')
    group by r.case_name having count(a.id)<>1),
  'identified denials append exactly one correlated audit event');

create function pg_temp.fail_institution_list_audit()
returns trigger language plpgsql as $$begin
  raise exception using message='forced institution list audit failure';
end$$;
create trigger fail_institution_list_audit before insert on audit.audit_logs
for each row when(new.action_code in('institution.list','institution.filter_options'))
execute function pg_temp.fail_institution_list_audit();
select set_config('request.jwt.claims',jsonb_build_object('sub',
  '72000000-0000-4000-8000-000000000001','session_id',
  '72100000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_ok($$select public.superadmin_institution_directory_v2()$$,
  'P0001','forced institution list audit failure','list fails closed when audit append fails');
select throws_ok($$select public.superadmin_institution_filter_options_v2()$$,
  'P0001','forced institution list audit failure','options fail closed when audit append fails');
reset role;
drop trigger fail_institution_list_audit on audit.audit_logs;
select ok((select bool_and(app_private.audit_verify_entry(id)) from audit.audit_logs
  where action_code in('institution.list','institution.filter_options')),
  'all list and options events remain in the verified audit chain');

select * from finish();
rollback;
