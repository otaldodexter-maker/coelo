-- A01 local HTTP seed: PREPARATION ONLY; a separate nominal execution lease is required.
-- Fresh disposable A01DirectoryAuditGreen55 database only; target20260907222911.
-- Descriptor SHA256 CRLF: bbd606be64e366502d84389f4a66e9e32ba500f29b043c5cf21cb332a14424ba.
-- Fixture97 commit: ee212cb56e9dc18400a8d105aeeba3a5f77bbbf4.
-- Fixture blob: 3d7d25ab24a738a03a1f1f11e4a500c13706ca6a.
-- Semantic source: first institution_types INSERT through Operations write-grant removal.
-- Only new grants: platform.read for Operations/Content, explicitly authorized for102/106.
-- COMMIT makes synthetic rows visible to HTTP. Never apply to a shared database.
-- Synthetic claim metadata only: no signed token, password, key or production session.
-- Future operator: fresh connection, pinned target verified independently, stop on SQL error.
begin;

do $a01_seed$
begin
  if current_setting('coelo.local_replay',true) is distinct from 'a01-http-green55' then
    raise exception using errcode='55000',message='A01 HTTP seed requires the isolated operator opt-in';
  end if;
  if current_user <> 'postgres'
     or current_setting('session_replication_role') <> 'origin' then
    raise exception using errcode='55000',
      message='A01 HTTP seed requires postgres with normal triggers';
  end if;
  if coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}') <> '{}'
     or nullif(current_setting('app_private.activity_v2_internal_marker',true),'') is not null then
    raise exception using errcode='55000',
      message='A01 HTTP seed requires a fresh connection with empty local context';
  end if;
  if to_regclass('auth.users') is null
     or to_regclass('auth.sessions') is null
     or to_regclass('app_private.superadmin_internal_identities') is null
     or to_regprocedure('public.superadmin_auth_bootstrap_context()') is null
     or to_regprocedure('public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean)') is null
     or to_regprocedure('public.superadmin_activity_filter_options_v2()') is null then
    raise exception using errcode='55000',
      message='A01 HTTP seed requires the pinned Green55 schema and genuine Auth bootstrap';
  end if;
  if (select count(*) from public.platform_roles
      where code in ('owner','operations','content') and status='active') <> 3
     or not exists(select 1 from public.platform_permissions
                   where code='platform.read' and status='active') then
    raise exception using errcode='55000',
      message='A01 HTTP seed requires the existing nominal roles and platform.read catalog';
  end if;
insert into public.institution_types(id,code,name,status) values
 ('8a200000-0000-4000-8000-000000000001','activities-v2-directory','Activities v2 read','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('8a200000-0000-4000-8000-000000000010','Tenant A','activities-v2-directory-a','active','8a200000-0000-4000-8000-000000000001'),
 ('8a200000-0000-4000-8000-000000000020','Tenant B','activities-v2-directory-b','active','8a200000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,institution_type_id,name,slug,status) values
 ('8a200000-0000-4000-8000-000000000011','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000001','A Norte','activities-v2-directory-a-norte','active'),
 ('8a200000-0000-4000-8000-000000000012','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000001','A Sul','activities-v2-directory-a-sul','active'),
 ('8a200000-0000-4000-8000-000000000021','8a200000-0000-4000-8000-000000000020','8a200000-0000-4000-8000-000000000001','B Única','activities-v2-directory-b-unica','active');
insert into public.groups(id,institution_id,unit_id,name,status) values
 ('8a200000-0000-4000-8000-000000000013','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000011','Turma A1','active'),
 ('8a200000-0000-4000-8000-000000000014','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000012','Turma A2 irmã','active'),
 ('8a200000-0000-4000-8000-000000000015','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000011','Turma A3','active'),
 ('8a200000-0000-4000-8000-000000000016','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000012','Turma A4','active'),
 ('8a200000-0000-4000-8000-000000000017','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000012','Turma A5 sem atividade','active'),
 ('8a200000-0000-4000-8000-000000000022','8a200000-0000-4000-8000-000000000020','8a200000-0000-4000-8000-000000000021','Turma B','active');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('8a200000-0000-4000-8000-000000000101','authenticated','authenticated','read-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('8a200000-0000-4000-8000-000000000102','authenticated','authenticated','read-scoped@invalid.test',now(),now(),now(),'{}','{}'),
 ('8a200000-0000-4000-8000-000000000103','authenticated','authenticated','read-aal1@invalid.test',now(),now(),now(),'{}','{}'),
 ('8a200000-0000-4000-8000-000000000104','authenticated','authenticated','read-revoked@invalid.test',now(),now(),now(),'{}','{}'),
 ('8a200000-0000-4000-8000-000000000105','authenticated','authenticated','read-people-only@invalid.test',now(),now(),now(),'{}','{}'),
 ('8a200000-0000-4000-8000-000000000106','authenticated','authenticated','read-denied-cap@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('8a200000-0000-4000-8000-000000000201','8a200000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('8a200000-0000-4000-8000-000000000202','8a200000-0000-4000-8000-000000000102',now(),now(),'aal2',now()+interval '1 hour'),
 ('8a200000-0000-4000-8000-000000000203','8a200000-0000-4000-8000-000000000103',now(),now(),'aal1',now()+interval '1 hour'),
 ('8a200000-0000-4000-8000-000000000204','8a200000-0000-4000-8000-000000000104',now(),now(),'aal2',now()+interval '1 hour'),
 ('8a200000-0000-4000-8000-000000000205','8a200000-0000-4000-8000-000000000105',now(),now(),'aal2',now()+interval '1 hour'),
 ('8a200000-0000-4000-8000-000000000206','8a200000-0000-4000-8000-000000000106',now(),now(),'aal2',now()+interval '1 hour'),
 ('8a200000-0000-4000-8000-000000000209','8a200000-0000-4000-8000-000000000101',now(),now(),'aal2',now()-interval '1 minute');
insert into app_private.superadmin_internal_identities(id) values
 ('8a200000-0000-4000-8000-000000000301'),('8a200000-0000-4000-8000-000000000302'),
 ('8a200000-0000-4000-8000-000000000303'),('8a200000-0000-4000-8000-000000000304'),
 ('8a200000-0000-4000-8000-000000000306');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('8a200000-0000-4000-8000-000000000401','8a200000-0000-4000-8000-000000000301','8a200000-0000-4000-8000-000000000101'),
 ('8a200000-0000-4000-8000-000000000402','8a200000-0000-4000-8000-000000000302','8a200000-0000-4000-8000-000000000102'),
 ('8a200000-0000-4000-8000-000000000403','8a200000-0000-4000-8000-000000000303','8a200000-0000-4000-8000-000000000103'),
 ('8a200000-0000-4000-8000-000000000404','8a200000-0000-4000-8000-000000000304','8a200000-0000-4000-8000-000000000104'),
 ('8a200000-0000-4000-8000-000000000406','8a200000-0000-4000-8000-000000000306','8a200000-0000-4000-8000-000000000106');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,role_record.id,fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 ('8a200000-0000-4000-8000-000000000501'::uuid,'8a200000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('8a200000-0000-4000-8000-000000000502'::uuid,'8a200000-0000-4000-8000-000000000302'::uuid,'operations','institution','8a200000-0000-4000-8000-000000000010'::uuid),
 ('8a200000-0000-4000-8000-000000000503'::uuid,'8a200000-0000-4000-8000-000000000303'::uuid,'owner','platform',null::uuid),
 ('8a200000-0000-4000-8000-000000000504'::uuid,'8a200000-0000-4000-8000-000000000304'::uuid,'operations','institution','8a200000-0000-4000-8000-000000000010'::uuid),
 ('8a200000-0000-4000-8000-000000000506'::uuid,'8a200000-0000-4000-8000-000000000306'::uuid,'content','platform',null::uuid)
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now(),version=2 where id='8a200000-0000-4000-8000-000000000504';
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('8a200000-0000-4000-8000-000000000601','adult','People','Only','People Only','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('8a200000-0000-4000-8000-000000000601','8a200000-0000-4000-8000-000000000105','active');

-- Explicit grants/deny keep the test independent from profile seed drift.
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,
 case when role_record.code='content' and permission_record.code='activities.read' then 'deny'::public.permission_effect else 'allow'::public.permission_effect end,'active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code in('owner','operations','content') and permission_record.code in(
 'activities.read','activities.assign_people','activities.manage_permissions','activities.manage','activities.link_units','activities.link_groups')
 and not(role_record.code='operations' and permission_record.code in(
   'activities.assign_people','activities.manage_permissions'))
on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null;
delete from public.platform_role_permissions role_permission
using public.platform_roles role_record,public.platform_permissions permission_record
where role_permission.role_id=role_record.id
  and role_permission.permission_id=permission_record.id
  and role_record.code='operations'
  and permission_record.code in('activities.assign_people','activities.manage_permissions');

-- Seed one activity in each tenant through a genuine validated internal marker.
perform set_config('request.jwt.claims',jsonb_build_object('sub','8a200000-0000-4000-8000-000000000101','session_id','8a200000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);
perform set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8a200000-0000-4000-8000-000000000301','internal_auth_link_id','8a200000-0000-4000-8000-000000000401','internal_membership_id','8a200000-0000-4000-8000-000000000501',
 'auth_user_id','8a200000-0000-4000-8000-000000000101','session_id','8a200000-0000-4000-8000-000000000201','permission_code','activities.manage','action_code','manage','correlation_id',gen_random_uuid())::text,true);
insert into public.activity_definitions(id,institution_id,name,description,handle_stem,origin_scope_kind,distribution_scope,created_by_person_id,status,management_version) values
 ('8a200000-0000-4000-8000-000000000701','8a200000-0000-4000-8000-000000000010','Robótica A','Somente tenant A','robotica-a-v2','institution','institution_standard',null,'draft',1),
 ('8a200000-0000-4000-8000-000000000702','8a200000-0000-4000-8000-000000000020','Robótica B','Somente tenant B','robotica-b-v2','institution','institution_standard',null,'draft',1);
perform set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8a200000-0000-4000-8000-000000000301','internal_auth_link_id','8a200000-0000-4000-8000-000000000401','internal_membership_id','8a200000-0000-4000-8000-000000000501','auth_user_id','8a200000-0000-4000-8000-000000000101','session_id','8a200000-0000-4000-8000-000000000201','permission_code','activities.link_units','action_code','link_units','correlation_id',gen_random_uuid())::text,true);
insert into public.activity_unit_links(id,activity_id,institution_id,unit_id,linked_by_person_id) values
 ('8a200000-0000-4000-8000-000000000711','8a200000-0000-4000-8000-000000000701','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000011',null),
 ('8a200000-0000-4000-8000-000000000713','8a200000-0000-4000-8000-000000000701','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000012',null),
 ('8a200000-0000-4000-8000-000000000721','8a200000-0000-4000-8000-000000000702','8a200000-0000-4000-8000-000000000020','8a200000-0000-4000-8000-000000000021',null);
perform set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8a200000-0000-4000-8000-000000000301','internal_auth_link_id','8a200000-0000-4000-8000-000000000401','internal_membership_id','8a200000-0000-4000-8000-000000000501','auth_user_id','8a200000-0000-4000-8000-000000000101','session_id','8a200000-0000-4000-8000-000000000201','permission_code','activities.link_groups','action_code','link_groups','correlation_id',gen_random_uuid())::text,true);
insert into public.activity_group_links(id,activity_id,institution_id,unit_id,group_id,linked_by_person_id,participation_mode) values
 ('8a200000-0000-4000-8000-000000000712','8a200000-0000-4000-8000-000000000701','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000011','8a200000-0000-4000-8000-000000000013',null,'all'),
 ('8a200000-0000-4000-8000-000000000714','8a200000-0000-4000-8000-000000000701','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000011','8a200000-0000-4000-8000-000000000015',null,'all'),
 ('8a200000-0000-4000-8000-000000000715','8a200000-0000-4000-8000-000000000701','8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000012','8a200000-0000-4000-8000-000000000016',null,'all'),
 ('8a200000-0000-4000-8000-000000000722','8a200000-0000-4000-8000-000000000702','8a200000-0000-4000-8000-000000000020','8a200000-0000-4000-8000-000000000021','8a200000-0000-4000-8000-000000000022',null,'all');


-- A second activity in A exercises multiselects, ties and unit-origin projection.
perform set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8a200000-0000-4000-8000-000000000301','internal_auth_link_id','8a200000-0000-4000-8000-000000000401','internal_membership_id','8a200000-0000-4000-8000-000000000501',
 'auth_user_id','8a200000-0000-4000-8000-000000000101','session_id','8a200000-0000-4000-8000-000000000201','permission_code','activities.manage','action_code','manage','correlation_id',gen_random_uuid())::text,true);
insert into public.activity_definitions(id,institution_id,name,description,handle_stem,
 origin_scope_kind,origin_unit_id,distribution_scope,governance_kind,created_by_person_id,status,management_version)
values ('8a200000-0000-4000-8000-000000000703','8a200000-0000-4000-8000-000000000010',
 'Robótica Local A','Descrição exclusiva para busca','robotica-a-local-v2','unit',
 '8a200000-0000-4000-8000-000000000012','unit_local','mandatory',null,'active',3);
perform set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8a200000-0000-4000-8000-000000000301','internal_auth_link_id','8a200000-0000-4000-8000-000000000401','internal_membership_id','8a200000-0000-4000-8000-000000000501',
 'auth_user_id','8a200000-0000-4000-8000-000000000101','session_id','8a200000-0000-4000-8000-000000000201','permission_code','activities.link_units','action_code','link_units','correlation_id',gen_random_uuid())::text,true);
insert into public.activity_unit_links(id,activity_id,institution_id,unit_id,linked_by_person_id)
values ('8a200000-0000-4000-8000-000000000731','8a200000-0000-4000-8000-000000000703',
 '8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000012',null);
perform set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8a200000-0000-4000-8000-000000000301','internal_auth_link_id','8a200000-0000-4000-8000-000000000401','internal_membership_id','8a200000-0000-4000-8000-000000000501',
 'auth_user_id','8a200000-0000-4000-8000-000000000101','session_id','8a200000-0000-4000-8000-000000000201','permission_code','activities.link_groups','action_code','link_groups','correlation_id',gen_random_uuid())::text,true);
insert into public.activity_group_links(id,activity_id,institution_id,unit_id,group_id,linked_by_person_id,participation_mode)
values ('8a200000-0000-4000-8000-000000000732','8a200000-0000-4000-8000-000000000703',
 '8a200000-0000-4000-8000-000000000010','8a200000-0000-4000-8000-000000000012',
 '8a200000-0000-4000-8000-000000000014',null,'all');

-- A reader must not need write permissions merely to obtain directory filters.
delete from public.platform_role_permissions rp using public.platform_roles r, public.platform_permissions p
where rp.role_id=r.id and rp.permission_id=p.id and r.code='operations'
 and p.code in ('activities.manage','activities.link_units','activities.link_groups');

-- Explicit HTTP bootstrap addition: only the two authorized existing roles.
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow'::public.permission_effect,'active'
from public.platform_roles role_record
cross join public.platform_permissions permission_record
where role_record.code in ('operations','content')
  and permission_record.code='platform.read'
on conflict(role_id,permission_id) do update
set effect=excluded.effect,status='active',revoked_at=null;

-- Structural gates only. HTTP and correlated audit remain separate operator checks.
if (select count(*) from public.platform_role_permissions rp
    join public.platform_roles r on r.id=rp.role_id
    join public.platform_permissions p on p.id=rp.permission_id
    where r.code in ('operations','content') and p.code='platform.read'
      and rp.effect='allow' and rp.status='active' and rp.revoked_at is null) <> 2 then
  raise exception using errcode='55000',message='A01 HTTP bootstrap grants are incomplete';
end if;
if exists(select 1 from public.platform_role_permissions rp
          join public.platform_roles r on r.id=rp.role_id
          join public.platform_permissions p on p.id=rp.permission_id
          where r.code='operations' and p.code in (
            'activities.create','activities.manage','activities.link_units',
            'activities.link_groups','activities.assign_people','activities.manage_permissions')
            and rp.effect='allow' and rp.status='active' and rp.revoked_at is null) then
  raise exception using errcode='55000',message='A01 Operations reader still has an active write capability';
end if;
if not exists(select 1 from public.platform_role_permissions rp
              join public.platform_roles r on r.id=rp.role_id
              join public.platform_permissions p on p.id=rp.permission_id
              where r.code='content' and p.code='activities.read' and rp.effect='deny'
                and rp.status='active' and rp.revoked_at is null)
   or not exists(select 1 from app_private.superadmin_internal_memberships
                 where id='8a200000-0000-4000-8000-000000000504'
                   and status='revoked' and revoked_at is not null) then
  raise exception using errcode='55000',message='A01 denied/revoked actor state is incomplete';
end if;
if exists(select 1 from public.person_auth_links
          where auth_user_id in ('8a200000-0000-4000-8000-000000000102',
            '8a200000-0000-4000-8000-000000000104','8a200000-0000-4000-8000-000000000106')) then
  raise exception using errcode='55000',message='A01 internal HTTP actors must not have a People bridge';
end if;
end;
$a01_seed$;

-- Validate genuine deferred constraints while the validated seed context still exists.
set constraints all immediate;

do $a01_clear_context$
begin
  perform set_config('app_private.activity_v2_internal_marker','',true);
  perform set_config('request.jwt.claims','{}',true);
  if nullif(current_setting('app_private.activity_v2_internal_marker',true),'') is not null
     or current_setting('request.jwt.claims',true) <> '{}' then
    raise exception using errcode='55000',message='A01 local seed context was not cleared';
  end if;
end;
$a01_clear_context$;

commit;
