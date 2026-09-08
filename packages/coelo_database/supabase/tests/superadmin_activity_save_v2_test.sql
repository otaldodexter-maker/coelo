begin;
create extension if not exists pgtap with schema extensions;
select plan(46);

select has_function(
  'public',
  'superadmin_activity_save_v2',
  array['uuid','uuid','bigint','boolean','jsonb'],
  'aggregate activity save v2 exists'
);
select function_privs_are(
  'public','superadmin_activity_save_v2',array['uuid','uuid','bigint','boolean','jsonb'],
  'authenticated',array['EXECUTE'],'authenticated executes aggregate save'
);
select function_privs_are(
  'public','superadmin_activity_save_v2',array['uuid','uuid','bigint','boolean','jsonb'],
  'anon',array[]::text[],'anonymous cannot execute aggregate save'
);
select function_privs_are(
  'public','superadmin_activity_save_v2',array['uuid','uuid','bigint','boolean','jsonb'],
  'service_role',array[]::text[],'service role cannot execute aggregate save'
);
select has_table(
  'app_private','superadmin_internal_activity_save_receipts',
  'aggregate save uses a dedicated private receipt table'
);
select ok((
  select table_record.relrowsecurity and table_record.relforcerowsecurity
    and not has_table_privilege('anon',table_record.oid,'SELECT')
    and not has_table_privilege('authenticated',table_record.oid,'SELECT')
    and not has_table_privilege('service_role',table_record.oid,'SELECT')
  from pg_catalog.pg_class table_record
  where table_record.oid='app_private.superadmin_internal_activity_save_receipts'::regclass
),'aggregate receipts are force-RLS and expose no direct reads');

with source as (
  select pg_catalog.lower(pg_catalog.regexp_replace(
    pg_catalog.pg_get_functiondef(
      'public.superadmin_activity_save_v2(uuid,uuid,bigint,boolean,jsonb)'::regprocedure
    ),'[[:space:]]+','','g'
  )) as function_definition
)
select ok(
  pg_catalog.strpos(function_definition,'transaction_isolation')>0
    and pg_catalog.strpos(function_definition,'readcommitted')>0,
  'aggregate rejects isolation levels that cannot refresh authorization after waits'
) from source;

with source as (
  select pg_catalog.substr(function_definition,pg_catalog.strpos(
    function_definition,'pg_catalog.pg_advisory_xact_lock'
  )) as locked_body
  from (
    select pg_catalog.lower(pg_catalog.regexp_replace(
      pg_catalog.pg_get_functiondef(
        'public.superadmin_activity_save_v2(uuid,uuid,bigint,boolean,jsonb)'::regprocedure
      ),'[[:space:]]+','','g'
    )) as function_definition
  ) definition
)
select ok(
  pg_catalog.strpos(locked_body,'select*intostrictctxfromapp_private.activity_v2_require_context')>0
    and pg_catalog.strpos(locked_body,'select*intostrictctxfromapp_private.activity_v2_require_context')
      < pg_catalog.strpos(locked_body,'select*intoreceiptfromapp_private.superadmin_internal_activity_save_receipts')
    and pg_catalog.strpos(locked_body,'isdistinctfromrow(initial_ctx.internal_identity_id')>0,
  'aggregate revalidates the same internal context after the request lock and before receipt lookup'
) from source;

with source as (
  select pg_catalog.substr(function_definition,pg_catalog.strpos(
    function_definition,'pg_catalog.pg_advisory_xact_lock'
  )) as locked_body
  from (
    select pg_catalog.lower(pg_catalog.regexp_replace(
      pg_catalog.pg_get_functiondef(
        'public.superadmin_activity_save_v2(uuid,uuid,bigint,boolean,jsonb)'::regprocedure
      ),'[[:space:]]+','','g'
    )) as function_definition
  ) definition
)
select ok(
  pg_catalog.strpos(locked_body,'pg_catalog.clock_timestamp()')>0
    and pg_catalog.strpos(locked_body,'pg_catalog.clock_timestamp()')
      < pg_catalog.strpos(locked_body,'select*intoreceiptfromapp_private.superadmin_internal_activity_save_receipts'),
  'aggregate checks session expiry against the wall clock before receipt replay'
) from source;

with source as (
  select function_definition,pg_catalog.substr(
    locked_body,1,pg_catalog.strpos(
      locked_body,'select*intoreceiptfromapp_private.superadmin_internal_activity_save_receipts'
    )-1
  ) as before_receipt
  from (
    select function_definition,pg_catalog.substr(function_definition,pg_catalog.strpos(
      function_definition,'pg_catalog.pg_advisory_xact_lock'
    )) as locked_body
    from (
      select pg_catalog.lower(pg_catalog.regexp_replace(
        pg_catalog.pg_get_functiondef(
          'public.superadmin_activity_save_v2(uuid,uuid,bigint,boolean,jsonb)'::regprocedure
        ),'[[:space:]]+','','g'
      )) as function_definition
    ) definition
  ) locked
)
select ok(
  function_definition like '%activities.link_units%'
    and function_definition like '%activities.link_groups%'
    and function_definition like '%activities.assign_people%'
    and function_definition like '%activities.manage_permissions%'
    and function_definition like '%activities.manage%'
    and pg_catalog.strpos(
      before_receipt,'foreachrequired_capabilityinarrayrequired_capabilitiesloop'
    )>0
    and pg_catalog.strpos(
      before_receipt,'select*intostrictcapability_ctxfromapp_private.activity_v2_require_context'
    )>0,
  'aggregate refreshes every applicable capability before receipt replay or mutation'
) from source;

insert into public.institution_types(id,code,name,status) values
 ('8b200000-0000-4000-8000-000000000001','activity-save-v2','Activity save v2','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('8b200000-0000-4000-8000-000000000010','Save Tenant A','activity-save-v2-a','active','8b200000-0000-4000-8000-000000000001'),
 ('8b200000-0000-4000-8000-000000000020','Save Tenant B','activity-save-v2-b','active','8b200000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,institution_type_id,name,slug,status) values
 ('8b200000-0000-4000-8000-000000000011','8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000001','Unidade A','activity-save-v2-unit-a','active'),
 ('8b200000-0000-4000-8000-000000000013','8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000001','Unidade A2','activity-save-v2-unit-a2','active'),
 ('8b200000-0000-4000-8000-000000000021','8b200000-0000-4000-8000-000000000020','8b200000-0000-4000-8000-000000000001','Unidade B','activity-save-v2-unit-b','active');
insert into public.groups(id,institution_id,unit_id,name,status) values
 ('8b200000-0000-4000-8000-000000000012','8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011','Turma A','active'),
 ('8b200000-0000-4000-8000-000000000014','8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000013','Turma A2','active'),
 ('8b200000-0000-4000-8000-000000000022','8b200000-0000-4000-8000-000000000020','8b200000-0000-4000-8000-000000000021','Turma B','active');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('8b200000-0000-4000-8000-000000000101','authenticated','authenticated','save-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('8b200000-0000-4000-8000-000000000102','authenticated','authenticated','save-scoped@invalid.test',now(),now(),now(),'{}','{}'),
 ('8b200000-0000-4000-8000-000000000103','authenticated','authenticated','save-revoked@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('8b200000-0000-4000-8000-000000000201','8b200000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('8b200000-0000-4000-8000-000000000202','8b200000-0000-4000-8000-000000000102',now(),now(),'aal2',now()+interval '1 hour'),
 ('8b200000-0000-4000-8000-000000000203','8b200000-0000-4000-8000-000000000103',now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('8b200000-0000-4000-8000-000000000301'),
 ('8b200000-0000-4000-8000-000000000302'),
 ('8b200000-0000-4000-8000-000000000303');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('8b200000-0000-4000-8000-000000000401','8b200000-0000-4000-8000-000000000301','8b200000-0000-4000-8000-000000000101'),
 ('8b200000-0000-4000-8000-000000000402','8b200000-0000-4000-8000-000000000302','8b200000-0000-4000-8000-000000000102'),
 ('8b200000-0000-4000-8000-000000000403','8b200000-0000-4000-8000-000000000303','8b200000-0000-4000-8000-000000000103');
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id
)
select fixture.id,fixture.identity_id,role_record.id,
 fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 ('8b200000-0000-4000-8000-000000000501'::uuid,'8b200000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('8b200000-0000-4000-8000-000000000502'::uuid,'8b200000-0000-4000-8000-000000000302'::uuid,'operations','institution','8b200000-0000-4000-8000-000000000010'::uuid),
 ('8b200000-0000-4000-8000-000000000503'::uuid,'8b200000-0000-4000-8000-000000000303'::uuid,'operations','institution','8b200000-0000-4000-8000-000000000010'::uuid)
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;
update app_private.superadmin_internal_memberships
set status='revoked',revoked_at=now(),version=2
where id='8b200000-0000-4000-8000-000000000503';

insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('8b200000-0000-4000-8000-000000000601','adult','Pessoa','Instrutora','Pessoa Instrutora','active'),
 ('8b200000-0000-4000-8000-000000000602','child','Crianca','A','Crianca A','active'),
 ('8b200000-0000-4000-8000-000000000603','child','Crianca','B','Crianca B','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status) values
 ('8b200000-0000-4000-8000-000000000611','8b200000-0000-4000-8000-000000000601','8b200000-0000-4000-8000-000000000010','teacher','active');
insert into public.child_contexts(id,child_person_id,institution_id,status) values
 ('8b200000-0000-4000-8000-000000000621','8b200000-0000-4000-8000-000000000602','8b200000-0000-4000-8000-000000000010','active'),
 ('8b200000-0000-4000-8000-000000000622','8b200000-0000-4000-8000-000000000603','8b200000-0000-4000-8000-000000000020','active');
insert into public.child_unit_links(
 id,child_context_id,unit_id,status,accepted_by,accepted_at
) values
 ('8b200000-0000-4000-8000-000000000631','8b200000-0000-4000-8000-000000000621','8b200000-0000-4000-8000-000000000011','active','8b200000-0000-4000-8000-000000000601',now()),
 ('8b200000-0000-4000-8000-000000000632','8b200000-0000-4000-8000-000000000622','8b200000-0000-4000-8000-000000000021','active','8b200000-0000-4000-8000-000000000601',now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status) values
 ('8b200000-0000-4000-8000-000000000641','8b200000-0000-4000-8000-000000000631','8b200000-0000-4000-8000-000000000012','active'),
 ('8b200000-0000-4000-8000-000000000642','8b200000-0000-4000-8000-000000000632','8b200000-0000-4000-8000-000000000022','active');

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow'::public.permission_effect,'active'
from public.platform_roles role_record
cross join public.platform_permissions permission_record
where role_record.code in('owner','operations') and permission_record.code in(
 'activities.read','activities.create','activities.manage','activities.link_units',
 'activities.link_groups','activities.assign_people','activities.manage_permissions'
)
on conflict(role_id,permission_id) do update
set effect=excluded.effect,status='active',revoked_at=null;

create function pg_temp.activity_save_payload(
  target_institution uuid,
  target_unit uuid,
  target_group uuid,
  target_membership uuid,
  target_name text,
  target_participation text default 'all',
  target_child_group_link uuid default null
) returns jsonb language sql stable set search_path='' as $$
 select pg_catalog.jsonb_build_object(
  'institution_id',target_institution,
  'definition',pg_catalog.jsonb_build_object(
    'name',target_name,
    'description','Contrato agregado',
    'taxonomy_id',(select id from public.activity_taxonomies where code='robotica' and status='active' limit 1),
    'icon_key','science','initials','AG'
  ),
  'unit_ids',pg_catalog.jsonb_build_array(target_unit),
  'group_ids',pg_catalog.jsonb_build_array(target_group),
  'group_participation',pg_catalog.jsonb_build_object(target_group::text,target_participation),
  'participants',case when target_child_group_link is null then '[]'::jsonb else
    pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'group_id',target_group,'child_group_link_id',target_child_group_link,'belongs',true
    )) end,
  'professional_assignments',case when target_membership is null then '[]'::jsonb else pg_catalog.jsonb_build_array(
    pg_catalog.jsonb_build_object('membership_id',target_membership,'role','instructor','group_id',target_group)
  ) end,
  'capability_policies',case when target_membership is null then
    '{"attendance":null,"chat":null,"happens":null,"moments":null,"now":null}'::jsonb
   else '{"attendance":"required","chat":"required","happens":"required","moments":"required","now":"required"}'::jsonb end,
  'group_capability_settings',case when target_membership is null then '[]'::jsonb else pg_catalog.jsonb_build_array(
    pg_catalog.jsonb_build_object('group_id',target_group,'capabilities',
      '{"attendance":true,"chat":true,"happens":true,"moments":true,"now":true}'::jsonb)
  ) end,
  'professional_capability_actions',case when target_membership is null then '[]'::jsonb else pg_catalog.jsonb_build_array(
    pg_catalog.jsonb_build_object('membership_id',target_membership,'role','instructor','group_id',target_group,
      'actions','{"attendance":"both","chat":"both","happens":"both","moments":"both","now":"both"}'::jsonb)
  ) end
 )
$$;

create temporary table save_results(label text primary key,body jsonb not null);
grant select,insert on save_results to authenticated;
create temporary table activity_auth_payload(body jsonb not null);
insert into activity_auth_payload
select pg_temp.activity_save_payload(
 '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011',
 '8b200000-0000-4000-8000-000000000012',null,'Operador institucional AAL1'
);
grant select on activity_auth_payload to authenticated;
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8b200000-0000-4000-8000-000000000101','session_id','8b200000-0000-4000-8000-000000000201',
 'aal','aal2','role','authenticated')::text,true);

insert into save_results
select 'create_publish',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000801',null,0,true,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011',
  '8b200000-0000-4000-8000-000000000012','8b200000-0000-4000-8000-000000000611','Robotica agregada')
);
insert into save_results
select 'create_replay',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000801',null,0,true,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011',
  '8b200000-0000-4000-8000-000000000012','8b200000-0000-4000-8000-000000000611','Robotica agregada')
);
insert into save_results
select 'request_conflict',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000801',null,0,true,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011',
  '8b200000-0000-4000-8000-000000000012','8b200000-0000-4000-8000-000000000611','Payload divergente')
);
insert into save_results
select 'edit',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000802',
 (select (body#>>'{data,activity_id}')::uuid from save_results where label='create_publish'),6,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011',
  '8b200000-0000-4000-8000-000000000012','8b200000-0000-4000-8000-000000000611','Robotica editada')
);
insert into save_results
select 'stale_edit',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000803',
 (select (body#>>'{data,activity_id}')::uuid from save_results where label='create_publish'),6,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011',
  '8b200000-0000-4000-8000-000000000012','8b200000-0000-4000-8000-000000000611','Stale')
);
insert into save_results
select 'late_failure',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000804',null,0,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011',
  '8b200000-0000-4000-8000-000000000022',null,'Deve reverter')
);
insert into save_results
select 'tenant_b',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000805',null,0,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000020','8b200000-0000-4000-8000-000000000021',
  '8b200000-0000-4000-8000-000000000022',null,'Tenant B')
);
insert into save_results
select 'tenant_b_intent_conflict',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000805',null,0,true,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000020','8b200000-0000-4000-8000-000000000021',
  '8b200000-0000-4000-8000-000000000022',null,'Tenant B')
);

insert into save_results
select 'selected_seed',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000808',null,0,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011',
  '8b200000-0000-4000-8000-000000000012',null,'Participacao selecionada','selected',
  '8b200000-0000-4000-8000-000000000641')
);
insert into save_results
select 'selected_to_all',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000809',
 (select (body#>>'{data,activity_id}')::uuid from save_results where label='selected_seed'),5,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011',
  '8b200000-0000-4000-8000-000000000012',null,'Participacao integral','all',null)
);

insert into save_results
select 'swap_seed',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000810',null,0,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011',
  '8b200000-0000-4000-8000-000000000012','8b200000-0000-4000-8000-000000000611',
  'Troca de unidade')
);
insert into save_results
select 'swap_edit',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000811',
 (select (body#>>'{data,activity_id}')::uuid from save_results where label='swap_seed'),5,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000013',
  '8b200000-0000-4000-8000-000000000014',null,'Troca de unidade concluida')
);
insert into save_results
select 'swap_replay',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000811',
 (select (body#>>'{data,activity_id}')::uuid from save_results where label='swap_seed'),5,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000013',
  '8b200000-0000-4000-8000-000000000014',null,'Troca de unidade concluida')
);
insert into save_results
select 'swap_conflict',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000811',
 (select (body#>>'{data,activity_id}')::uuid from save_results where label='swap_seed'),5,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000013',
  '8b200000-0000-4000-8000-000000000014',null,'Payload de troca divergente')
);

insert into save_results
select 'rollback_seed',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000812',null,0,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011',
  '8b200000-0000-4000-8000-000000000012','8b200000-0000-4000-8000-000000000611',
  'Rollback estrutural')
);
insert into save_results
select 'rollback_edit',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000813',
 (select (body#>>'{data,activity_id}')::uuid from save_results where label='rollback_seed'),5,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000013',
  '8b200000-0000-4000-8000-000000000014',null,'Nao deve persistir','selected',
  '8b200000-0000-4000-8000-000000000642')
);

insert into save_results
select 'invalid_participation_key',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000815',null,0,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011',
  '8b200000-0000-4000-8000-000000000012',null,'Mapa de participacao invalido'
 ) || pg_catalog.jsonb_build_object(
  'group_participation',
  pg_catalog.jsonb_build_object('8b200000-0000-4000-8000-000000000014','all')
 )
);
insert into save_results
select 'invalid_participation_null',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000816',null,0,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011',
  '8b200000-0000-4000-8000-000000000012',null,'Modo de participacao nulo'
 ) || pg_catalog.jsonb_build_object(
  'group_participation',
  pg_catalog.jsonb_build_object('8b200000-0000-4000-8000-000000000012',null)
 )
);

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8b200000-0000-4000-8000-000000000102','session_id','8b200000-0000-4000-8000-000000000202',
 'aal','aal1','role','authenticated')::text,true);
update auth.sessions set aal='aal1'
where id='8b200000-0000-4000-8000-000000000202';
set local role authenticated;
insert into save_results
select 'operator_aal1',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000814',null,0,false,(select body from activity_auth_payload)
);
reset role;

update auth.sessions
set not_after=now()-interval '1 second'
where id='8b200000-0000-4000-8000-000000000202';
set local role authenticated;
insert into save_results
select 'operator_expired_replay',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000814',null,0,false,(select body from activity_auth_payload)
);
reset role;
update auth.sessions
set not_after=now()+interval '1 hour'
where id='8b200000-0000-4000-8000-000000000202';

update public.platform_role_permissions grant_record
set status='inactive',revoked_at=now()
from public.platform_roles role_record,public.platform_permissions permission_record
where grant_record.role_id=role_record.id
  and grant_record.permission_id=permission_record.id
  and role_record.code='operations'
  and permission_record.code='activities.link_units';
set local role authenticated;
insert into save_results
select 'operator_revoked_capability_replay',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000814',null,0,false,(select body from activity_auth_payload)
);
reset role;
update public.platform_role_permissions grant_record
set status='active',revoked_at=null
from public.platform_roles role_record,public.platform_permissions permission_record
where grant_record.role_id=role_record.id
  and grant_record.permission_id=permission_record.id
  and role_record.code='operations'
  and permission_record.code='activities.link_units';
update auth.sessions set aal='aal2'
where id='8b200000-0000-4000-8000-000000000202';

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8b200000-0000-4000-8000-000000000102','session_id','8b200000-0000-4000-8000-000000000202',
 'aal','aal2','role','authenticated')::text,true);
insert into save_results
select 'cross_tenant_edit',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000806',
 (select (body#>>'{data,activity_id}')::uuid from save_results where label='tenant_b'),5,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011',
  '8b200000-0000-4000-8000-000000000012',null,'ID adulterado')
);

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8b200000-0000-4000-8000-000000000103','session_id','8b200000-0000-4000-8000-000000000203',
 'aal','aal2','role','authenticated')::text,true);
insert into save_results
select 'revoked',public.superadmin_activity_save_v2(
 '8b200000-0000-4000-8000-000000000807',null,0,false,
 pg_temp.activity_save_payload(
  '8b200000-0000-4000-8000-000000000010','8b200000-0000-4000-8000-000000000011',
 '8b200000-0000-4000-8000-000000000012',null,'Revogado')
);

select ok((select body#>>'{ok}'='true' and body#>>'{data,status}'='active'
 and body#>>'{data,management_version}'='6' from save_results where label='create_publish'),
 'create and publish commit as one aggregate operation');
select ok((select count(*)=1 from public.activity_definitions where
 id=(select (body#>>'{data,activity_id}')::uuid from save_results where label='create_publish')
 and institution_id='8b200000-0000-4000-8000-000000000010' and name='Robotica editada'),
 'aggregate persists the authorized definition in tenant A');
select ok((select count(*)=1 from public.activity_group_links where
 activity_id=(select (body#>>'{data,activity_id}')::uuid from save_results where label='create_publish')
 and group_id='8b200000-0000-4000-8000-000000000012' and status='active'),
 'aggregate persists the group snapshot');
select ok((select count(*)=1 from public.activity_group_assignments assignment
 join public.activity_group_links link on link.id=assignment.activity_group_link_id
 where link.activity_id=(select (body#>>'{data,activity_id}')::uuid from save_results where label='create_publish')
 and assignment.membership_id='8b200000-0000-4000-8000-000000000611' and assignment.status='active'),
 'aggregate persists the professional snapshot');
select ok((select count(*)=5 from public.activity_assignment_capability_actions action
 join public.activity_group_assignments assignment on assignment.id=action.assignment_id
 join public.activity_group_links link on link.id=assignment.activity_group_link_id
 where link.activity_id=(select (body#>>'{data,activity_id}')::uuid from save_results where label='create_publish')),
 'aggregate persists all approved professional capabilities');
select ok((select body#>>'{data,replayed}'='true' and body#>>'{data,activity_id}'=
 (select body#>>'{data,activity_id}' from save_results where label='create_publish')
 from save_results where label='create_replay'),'same aggregate request replays every child command');
select is((select body#>>'{error,code}' from save_results where label='request_conflict'),
 'SAI_CONCURRENT_CHANGE','same request with a changed payload conflicts');
select is((select body#>>'{error,code}' from save_results where label='tenant_b_intent_conflict'),
 'SAI_CONCURRENT_CHANGE','same request cannot change save intent');
select ok((select body#>>'{ok}'='true' and body#>>'{data,management_version}'='12'
 from save_results where label='edit'),'edit commits its complete snapshot and final version');
select is((select body#>>'{error,code}' from save_results where label='stale_edit'),
 'SAI_CONCURRENT_CHANGE','obsolete edit version fails closed');
select is((select body#>>'{error,code}' from save_results where label='late_failure'),
 'ACTIVITY_INVALID_REFERENCE','late cross-tenant group failure keeps the child error');
select ok(not exists(select 1 from public.activity_definitions where name='Deve reverter'),
 'late failure rolls back the created definition');
select ok(not exists(select 1 from app_private.superadmin_internal_activity_command_receipts where request_id in(
 app_private.activity_request_uuid('activity-save-create','8b200000-0000-4000-8000-000000000804'),
 app_private.activity_request_uuid('activity-save-groups','8b200000-0000-4000-8000-000000000804')
)) and not exists(select 1 from app_private.superadmin_internal_activity_save_receipts
 where request_id='8b200000-0000-4000-8000-000000000804'),
 'late failure rolls back child and aggregate receipts');
select is((select body#>>'{error,code}' from save_results where label='cross_tenant_edit'),
 'ACTIVITY_NOT_FOUND','institution-scoped actor cannot enumerate tenant B by activity id');
select is((select body#>>'{error,code}' from save_results where label='revoked'),
 'SAI_MEMBERSHIP_REVOKED','revoked internal membership fails closed');
select ok((select body#>>'{ok}'='true' and body#>>'{data,management_version}'='5'
 from save_results where label='operator_aal1'),
 'authenticated institution operator can save with AAL1 during the approved MVP deferral');
select ok((select body#>>'{error,code}'='SAI_SESSION_INVALID'
  and body#>>'{data,replayed}' is null
 from save_results where label='operator_expired_replay'),
 'expired session is revalidated before an aggregate receipt can replay');
select ok((select body#>>'{error,code}'='SAI_PERMISSION_DENIED'
  and body#>>'{data,replayed}' is null
 from save_results where label='operator_revoked_capability_replay'),
 'revoked capability is revalidated before an aggregate receipt can replay');
select ok((select count(*)=5 and bool_and(audit_log.outcome='success')
  and bool_and(audit_log.mfa_aal='aal1')
 from audit.audit_logs audit_log
 where audit_log.actor_kind='superadmin_internal'
   and audit_log.actor_internal_identity_id='8b200000-0000-4000-8000-000000000302'
   and audit_log.object_type='activity'
   and audit_log.object_id=(select (body#>>'{data,activity_id}')::uuid
     from save_results where label='operator_aal1'))
 and (select count(*)=1
 from audit.audit_logs audit_log
 where audit_log.actor_kind='superadmin_internal'
   and audit_log.actor_internal_identity_id='8b200000-0000-4000-8000-000000000302'
   and audit_log.permission_code='activities.link_units'
   and audit_log.action_code='activity.save'
   and audit_log.outcome='denied'
   and audit_log.reason_code='SAI_PERMISSION_DENIED'
   and audit_log.mfa_aal='aal1'
   and audit_log.institution_id='8b200000-0000-4000-8000-000000000010'
   and audit_log.context_kind='institution'
   and audit_log.context_id='8b200000-0000-4000-8000-000000000010'
   and audit_log.object_type='institution'
   and audit_log.object_id='8b200000-0000-4000-8000-000000000010'
   and audit_log.correlation_id=(select (body#>>'{error,correlation_id}')::uuid
     from save_results where label='operator_revoked_capability_replay'))
 and not exists(
  select 1 from audit.audit_logs audit_log
  where audit_log.correlation_id=(select (body#>>'{error,correlation_id}')::uuid
    from save_results where label='operator_expired_replay')
 )
 and (select count(*)=1
 from app_private.superadmin_internal_activity_save_receipts receipt
 where receipt.request_id='8b200000-0000-4000-8000-000000000814'
   and receipt.internal_identity_id='8b200000-0000-4000-8000-000000000302'
   and receipt.institution_id='8b200000-0000-4000-8000-000000000010'
   and receipt.resulting_version=5),
 'denied replays add no success audit or duplicate aggregate receipt');
select ok((select body#>>'{ok}'='true' and body#>>'{data,management_version}'='12'
 from save_results where label='selected_to_all'),
 'selected to all prunes participants before changing the group mode');
select ok((select body#>>'{error,code}'='ACTIVITY_INVALID_INPUT'
 from save_results where label='invalid_participation_key')
 and not exists(
  select 1 from app_private.superadmin_internal_activity_command_receipts
  where request_id=app_private.activity_request_uuid(
   'activity-save-create','8b200000-0000-4000-8000-000000000815'
  )
 ) and not exists(
  select 1 from app_private.superadmin_internal_activity_save_receipts
  where request_id='8b200000-0000-4000-8000-000000000815'
 ),'group participation keys must match the requested group snapshot');
select ok((select body#>>'{error,code}'='ACTIVITY_INVALID_INPUT'
 from save_results where label='invalid_participation_null')
 and not exists(
  select 1 from app_private.superadmin_internal_activity_command_receipts
  where request_id=app_private.activity_request_uuid(
   'activity-save-create','8b200000-0000-4000-8000-000000000816'
  )
 ) and not exists(
  select 1 from app_private.superadmin_internal_activity_save_receipts
  where request_id='8b200000-0000-4000-8000-000000000816'
 ),'group participation mode rejects JSON null before creating a child receipt');
select ok(not exists(
 select 1
 from public.activity_group_participants participant
 join public.activity_group_links link on link.id=participant.activity_group_link_id
 where link.activity_id=(select (body#>>'{data,activity_id}')::uuid
   from save_results where label='selected_seed')
   and participant.status='active' and participant.removed_at is null
),'selected to all leaves no active explicit participant');
select ok((select count(*)=1
 from public.activity_group_links link
 where link.activity_id=(select (body#>>'{data,activity_id}')::uuid
   from save_results where label='selected_seed')
   and link.group_id='8b200000-0000-4000-8000-000000000012'
   and link.status='active' and link.participation_mode='all'),
 'selected to all persists the explicit final participation mode');
select ok((select body#>>'{ok}'='true' and body#>>'{data,management_version}'='14'
 from save_results where label='swap_edit'),
 'unit and group swap prunes blockers and reports the child-derived final version');
select ok((select count(*)=2
 from public.activity_unit_links unit_link
 join public.activity_group_links group_link
   on group_link.activity_id=unit_link.activity_id
  and group_link.unit_id=unit_link.unit_id
 where unit_link.activity_id=(select (body#>>'{data,activity_id}')::uuid
   from save_results where label='swap_seed')
   and (
    unit_link.unit_id='8b200000-0000-4000-8000-000000000011'
      and unit_link.status='inactive'
      and group_link.group_id='8b200000-0000-4000-8000-000000000012'
      and group_link.status='inactive'
    or unit_link.unit_id='8b200000-0000-4000-8000-000000000013'
      and unit_link.status='active'
      and group_link.group_id='8b200000-0000-4000-8000-000000000014'
      and group_link.status='active'
   )
),'unit and group swap removes old parents before adding the new chain');
select ok(not exists(
 select 1 from public.activity_group_assignments assignment
 join public.activity_group_links link on link.id=assignment.activity_group_link_id
 where link.activity_id=(select (body#>>'{data,activity_id}')::uuid
   from save_results where label='swap_seed')
   and assignment.status='active'
) and not exists(
 select 1 from public.activity_group_capability_settings setting
 join public.activity_group_links link on link.id=setting.activity_group_link_id
 where link.activity_id=(select (body#>>'{data,activity_id}')::uuid
   from save_results where label='swap_seed')
),'unit and group swap removes old professionals and settings');
select ok((select replay.body#>>'{data,replayed}'='true'
  and replay.body#>>'{data,management_version}'=saved.body#>>'{data,management_version}'
  and replay.body#>>'{data,correlation_id}'=saved.body#>>'{data,correlation_id}'
 from save_results replay cross join save_results saved
 where replay.label='swap_replay' and saved.label='swap_edit'),
 'complex swap replays without rerunning prune stages');
select is((select body#>>'{error,code}' from save_results where label='swap_conflict'),
 'SAI_CONCURRENT_CHANGE','complex swap request cannot be reused with another payload');
select is((select body#>>'{error,code}' from save_results where label='rollback_edit'),
 'ACTIVITY_INVALID_INPUT','late invalid participant fails after structural staging');
select ok((select count(*)=1
 from public.activity_definitions definition
 where definition.id=(select (body#>>'{data,activity_id}')::uuid
   from save_results where label='rollback_seed')
   and definition.management_version=5 and definition.name='Rollback estrutural'),
 'late structural failure restores the definition version and values');
select ok((select count(*)=1
 from public.activity_unit_links unit_link
 join public.activity_group_links group_link
   on group_link.activity_id=unit_link.activity_id
  and group_link.unit_id=unit_link.unit_id
 join public.activity_group_assignments assignment
   on assignment.activity_group_link_id=group_link.id
 where unit_link.activity_id=(select (body#>>'{data,activity_id}')::uuid
   from save_results where label='rollback_seed')
   and unit_link.unit_id='8b200000-0000-4000-8000-000000000011'
   and unit_link.status='active'
   and group_link.group_id='8b200000-0000-4000-8000-000000000012'
   and group_link.status='active'
   and assignment.status='active'
 ) and (select count(*)=5
 from public.activity_group_capability_settings setting
 join public.activity_group_links link on link.id=setting.activity_group_link_id
 where link.activity_id=(select (body#>>'{data,activity_id}')::uuid
   from save_results where label='rollback_seed'))
 and (select count(*)=5
 from public.activity_capability_policies policy
 where policy.activity_id=(select (body#>>'{data,activity_id}')::uuid
   from save_results where label='rollback_seed'))
 and (select count(*)=5
 from public.activity_assignment_capability_actions action
 join public.activity_group_assignments assignment on assignment.id=action.assignment_id
 join public.activity_group_links link on link.id=assignment.activity_group_link_id
 where link.activity_id=(select (body#>>'{data,activity_id}')::uuid
   from save_results where label='rollback_seed'))
 and not exists(
  select 1 from public.activity_unit_links link
  where link.activity_id=(select (body#>>'{data,activity_id}')::uuid
    from save_results where label='rollback_seed')
    and link.unit_id='8b200000-0000-4000-8000-000000000013'
    and link.status='active'
 ),'late structural failure restores parents, children and permissions');
select ok(not exists(
 select 1 from app_private.superadmin_internal_activity_command_receipts receipt
 where receipt.request_id in(
  app_private.activity_request_uuid('activity-save-update','8b200000-0000-4000-8000-000000000813'),
  app_private.activity_request_uuid('activity-save-professionals-prune','8b200000-0000-4000-8000-000000000813'),
  app_private.activity_request_uuid('activity-save-permissions-prune','8b200000-0000-4000-8000-000000000813'),
  app_private.activity_request_uuid('activity-save-groups-prune','8b200000-0000-4000-8000-000000000813'),
  app_private.activity_request_uuid('activity-save-units','8b200000-0000-4000-8000-000000000813'),
  app_private.activity_request_uuid('activity-save-groups','8b200000-0000-4000-8000-000000000813'),
  app_private.activity_request_uuid('activity-save-participants','8b200000-0000-4000-8000-000000000813')
 )
) and not exists(
 select 1 from app_private.superadmin_internal_activity_save_receipts
 where request_id='8b200000-0000-4000-8000-000000000813'
),'late structural failure rolls back prune, final and aggregate receipts');
select ok((select count(*)=5 and bool_and(audit_log.outcome='success')
 from audit.audit_logs audit_log
 where audit_log.actor_kind='superadmin_internal'
   and audit_log.object_type='activity'
   and audit_log.object_id=(select (body#>>'{data,activity_id}')::uuid
     from save_results where label='rollback_seed')
),'late structural failure rolls back every staged audit event');
select ok(not exists(select 1 from save_results where
 (select array_agg(key order by key) from jsonb_object_keys(body) key)<>array['data','error','ok']::text[]),
 'aggregate save keeps the stable v2 envelope');
select ok((select count(*)=1 from public.activity_definitions where
 id=(select (body#>>'{data,activity_id}')::uuid from save_results where label='tenant_b')
 and institution_id='8b200000-0000-4000-8000-000000000020'),
 'platform owner can create an isolated tenant B draft');

select * from finish();
rollback;
