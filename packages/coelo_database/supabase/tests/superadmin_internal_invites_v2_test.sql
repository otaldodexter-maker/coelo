begin;
create extension if not exists pgtap with schema extensions;
select plan(33);

select has_function('public','superadmin_invite_directory_v2',array[
  'text','text[]','text[]','uuid[]','uuid[]','uuid[]','uuid[]',
  'timestamp with time zone','timestamp with time zone','integer','integer','boolean']);
select has_function('public','superadmin_invite_options_v2',array['text','uuid','uuid','uuid','integer']);
select has_function('public','superadmin_invite_detail_v2',array['uuid']);
select has_function('public','superadmin_invite_issue_v2',array[
  'uuid','uuid','uuid','uuid','uuid','uuid','text','text[]','integer']);
select has_function('public','superadmin_invite_resend_v2',array['uuid','uuid','bigint']);
select has_function('public','superadmin_invite_revoke_v2',array['uuid','uuid','bigint','text']);

select ok((select requires_mfa is false and status='active'
 from public.platform_permissions where code='platform.invites.read'),
 'read capability is active without forcing aal2');
select ok((select requires_mfa is true and status='active'
 from public.platform_permissions where code='platform.invites.manage'),
 'manage capability is active and requires aal2');
select is((select array_agg(role_record.code order by role_record.code)
 from public.platform_role_permissions grant_record
 join public.platform_permissions permission_record on permission_record.id=grant_record.permission_id
 join public.platform_roles role_record on role_record.id=grant_record.role_id
 where permission_record.code in('platform.invites.read','platform.invites.manage')
   and grant_record.status='active' and grant_record.effect='allow'),
 array['owner','owner']::text[],'invitation capabilities default to Owner only');

insert into public.institution_types(id,code,name,status) values
 ('9d100000-0000-4000-8000-000000000001','internal-invites-v2','Internal invites v2','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9d100000-0000-4000-8000-000000000010','Colégio Horizonte','invites-v2-a','active','9d100000-0000-4000-8000-000000000001'),
 ('9d100000-0000-4000-8000-000000000020','Escola Aurora','invites-v2-b','active','9d100000-0000-4000-8000-000000000001');
insert into public.institution_roles(id,institution_id,code,name,status,max_scope_kind) values
 ('9d100000-0000-4000-8000-000000000030','9d100000-0000-4000-8000-000000000010','guardian-horizonte','Responsável Horizonte','active','institution'),
 ('9d100000-0000-4000-8000-000000000031','9d100000-0000-4000-8000-000000000020','guardian-aurora','Responsável Aurora','active','institution');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9d100000-0000-4000-8000-000000000040','adult','Helena','Costa','Helena Costa','active'),
 ('9d100000-0000-4000-8000-000000000041','adult','Paulo','Nunes','Paulo Nunes','active');
insert into public.invitations(
 id,scope_kind,institution_id,target_person_id,role_code,token_hash,expires_at,
 invited_by,invitation_state,status,created_at
) values(
 '9d100000-0000-4000-8000-000000000050','institution',
 '9d100000-0000-4000-8000-000000000010','9d100000-0000-4000-8000-000000000041',
 'guardian-horizonte',repeat('a',64),now()+interval '2 days',
 '9d100000-0000-4000-8000-000000000040','pending','active',now()-interval '1 day');

select ok((select invited_by_internal_identity_id is null and profile_id is null
 and channels is null and version is null and updated_at is null
 from public.invitations where id='9d100000-0000-4000-8000-000000000050'),
 'additive columns do not synthesize a legacy backfill');
select throws_ok($$update public.invitations
 set invited_by_internal_identity_id='9d100000-0000-4000-8000-000000000301'
 where id='9d100000-0000-4000-8000-000000000050'$$,
 '23514',null,'one invitation cannot mix legacy and internal issuer realms');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9d100000-0000-4000-8000-000000000101','authenticated','authenticated','invites-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('9d100000-0000-4000-8000-000000000102','authenticated','authenticated','invites-owner2@invalid.test',now(),now(),now(),'{}','{}'),
 ('9d100000-0000-4000-8000-000000000103','authenticated','authenticated','invites-scoped@invalid.test',now(),now(),now(),'{}','{}'),
 ('9d100000-0000-4000-8000-000000000104','authenticated','authenticated','invites-app@invalid.test',now(),now(),now(),'{}','{}'),
 ('9d100000-0000-4000-8000-000000000105','authenticated','authenticated','invites-legacy@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9d100000-0000-4000-8000-000000000201','9d100000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('9d100000-0000-4000-8000-000000000202','9d100000-0000-4000-8000-000000000102',now(),now(),'aal2',now()+interval '1 hour'),
 ('9d100000-0000-4000-8000-000000000203','9d100000-0000-4000-8000-000000000103',now(),now(),'aal2',now()+interval '1 hour'),
 ('9d100000-0000-4000-8000-000000000204','9d100000-0000-4000-8000-000000000104',now(),now(),'aal2',now()+interval '1 hour'),
 ('9d100000-0000-4000-8000-000000000205','9d100000-0000-4000-8000-000000000105',now(),now(),'aal1',now()+interval '1 hour');
insert into public.person_auth_links(id,person_id,auth_user_id) values
 ('9d100000-0000-4000-8000-000000000250','9d100000-0000-4000-8000-000000000041','9d100000-0000-4000-8000-000000000105');
insert into app_private.superadmin_internal_identities(id) values
 ('9d100000-0000-4000-8000-000000000301'),
 ('9d100000-0000-4000-8000-000000000302'),
 ('9d100000-0000-4000-8000-000000000303');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9d100000-0000-4000-8000-000000000401','9d100000-0000-4000-8000-000000000301','9d100000-0000-4000-8000-000000000101'),
 ('9d100000-0000-4000-8000-000000000402','9d100000-0000-4000-8000-000000000302','9d100000-0000-4000-8000-000000000102'),
 ('9d100000-0000-4000-8000-000000000403','9d100000-0000-4000-8000-000000000303','9d100000-0000-4000-8000-000000000103');
insert into app_private.superadmin_internal_memberships(
 id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id
)
select fixture.id,fixture.identity_id,role_record.id,
 fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from(values
 ('9d100000-0000-4000-8000-000000000501'::uuid,'9d100000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('9d100000-0000-4000-8000-000000000502'::uuid,'9d100000-0000-4000-8000-000000000302'::uuid,'owner','platform',null::uuid),
 ('9d100000-0000-4000-8000-000000000503'::uuid,'9d100000-0000-4000-8000-000000000303'::uuid,'operations','institution','9d100000-0000-4000-8000-000000000010'::uuid)
)fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;

insert into public.platform_role_permissions(role_id,permission_id,effect,conditions_json,status,revoked_at)
select role_record.id,permission_record.id,'allow','{}'::jsonb,'active',null
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='operations'
 and permission_record.code in('platform.invites.read','platform.invites.manage')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

create temporary table invite_results(label text primary key,body jsonb not null);

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9d100000-0000-4000-8000-000000000101','session_id','9d100000-0000-4000-8000-000000000201',
 'aal','aal2','role','authenticated')::text,true);
insert into invite_results values
 ('owner_directory',public.superadmin_invite_directory_v2(null,null,null,null,null,null,null,null,null,8,0,false)),
 ('legacy_detail',public.superadmin_invite_detail_v2('9d100000-0000-4000-8000-000000000050')),
 ('owner_issue',public.superadmin_invite_issue_v2(
   '9d100000-0000-4000-8000-000000000601','9d100000-0000-4000-8000-000000000010',null,null,
   '9d100000-0000-4000-8000-000000000030',null,'familia.horizonte@example.test',array['link','email'],48));
insert into invite_results values
 ('owner_issue_replay',public.superadmin_invite_issue_v2(
   '9d100000-0000-4000-8000-000000000601','9d100000-0000-4000-8000-000000000010',null,null,
   '9d100000-0000-4000-8000-000000000030',null,'familia.horizonte@example.test',array['email','link'],48)),
 ('legacy_resend',public.superadmin_invite_resend_v2(
   '9d100000-0000-4000-8000-000000000050','9d100000-0000-4000-8000-000000000602',1)),
 ('missing_detail',public.superadmin_invite_detail_v2('9d100000-0000-4000-8000-000000009999'));

update public.invitations set expires_at=now()-interval '1 minute'
where id=(select (body#>>'{data,invite,id}')::uuid from invite_results where label='owner_issue');
insert into invite_results
select 'owner_resend',public.superadmin_invite_resend_v2(
 (select (body#>>'{data,invite,id}')::uuid from invite_results where label='owner_issue'),
 '9d100000-0000-4000-8000-000000000603',1);
insert into invite_results
select 'stale_revoke',public.superadmin_invite_revoke_v2(
 (select (body#>>'{data,invite,id}')::uuid from invite_results where label='owner_issue'),
 '9d100000-0000-4000-8000-000000000604',1,'Destinatário incorreto');
insert into invite_results
select 'owner_revoke',public.superadmin_invite_revoke_v2(
 (select (body#>>'{data,invite,id}')::uuid from invite_results where label='owner_issue'),
 '9d100000-0000-4000-8000-000000000605',2,'Destinatário incorreto');

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9d100000-0000-4000-8000-000000000103','session_id','9d100000-0000-4000-8000-000000000203',
 'aal','aal2','role','authenticated')::text,true);
insert into invite_results values
 ('scoped_directory',public.superadmin_invite_directory_v2(null,null,null,
   array['9d100000-0000-4000-8000-000000000010'::uuid],null,null,null,null,null,8,0,false)),
 ('scoped_cross_tenant',public.superadmin_invite_detail_v2('9d100000-0000-4000-8000-000000000050'));

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9d100000-0000-4000-8000-000000000104','session_id','9d100000-0000-4000-8000-000000000204',
 'aal','aal2','role','authenticated')::text,true);
insert into invite_results values('cross_app',public.superadmin_invite_detail_v2('9d100000-0000-4000-8000-000000000050'));

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9d100000-0000-4000-8000-000000000101','session_id','9d100000-0000-4000-8000-000000000201',
 'aal','aal1','role','authenticated')::text,true);
insert into invite_results values('owner_aal1_issue',public.superadmin_invite_issue_v2(
 '9d100000-0000-4000-8000-000000000606','9d100000-0000-4000-8000-000000000010',null,null,
 '9d100000-0000-4000-8000-000000000030','9d100000-0000-4000-8000-000000000041',null,array['link'],48));

select ok((select body#>>'{ok}'='true' and body#>>'{data,total_count}'='1'
 from invite_results where label='owner_directory'),'Owner reads the RPC-only directory');
select ok((select body#>>'{data,channels}'='[]'
 and body#>>'{data,profile_id}'='legacy'
 and body#>>'{data,issuer,kind}'='legacy_person'
 and (select array_agg(key order by key) from jsonb_object_keys(body#>'{data,issuer}') key)=array['display','kind']::text[]
 and not(body#>'{data,issuer}' ?| array['id','person_id','internal_identity_id'])
 from invite_results where label='legacy_detail'),
 'legacy detail is explicit, minimized and contains no issuer identifiers');
select ok((select body#>>'{ok}'='true' and body#>>'{data,replayed}'='false'
 and body#>>'{data,invite,issuer,kind}'='superadmin_internal'
 and body#>>'{data,link}'~'^https://app[.]coelo[.]me/convites/[0-9a-f]{64}$'
 from invite_results where label='owner_issue'),'aal2 Owner issues through the internal realm');
select ok((select body#>>'{data,replayed}'='true' and body#>'{data,link}'='null'::jsonb
 from invite_results where label='owner_issue_replay'),'issue replay is idempotent and never replays the clear link');
select ok((select invited_by is null and invited_by_internal_identity_id='9d100000-0000-4000-8000-000000000301'
 and profile_id='9d100000-0000-4000-8000-000000000030' and channels=array['email','link']
 and version=3 and token_hash~'^[0-9a-f]{64}$'
 from public.invitations where id=(select (body#>>'{data,invite,id}')::uuid
 from invite_results where label='owner_issue')),
 'internal invitation persists provenance, normalized channels, hash-only token and optimistic version');
select is((select body#>>'{error,code}' from invite_results where label='legacy_resend'),
 'SAI_PERMISSION_DENIED','legacy invitation remains read-only');
select ok((select body#>>'{ok}'='true' and body#>>'{data,invite,management_version}'='2'
 from invite_results where label='owner_resend'),'expired internal invitation can be resent');
select is((select body#>>'{error,code}' from invite_results where label='stale_revoke'),
 'SAI_CONCURRENT_CHANGE','stale mutation is rejected');
select ok((select body#>>'{ok}'='true' and body#>>'{data,invite,status}'='revoked'
 from invite_results where label='owner_revoke'),'current internal invitation can be revoked');
select is((select body#>>'{error,code}' from invite_results where label='missing_detail'),
 'SAI_PERMISSION_DENIED','missing identifiers are non-enumerating');
select is((select body#>>'{error,code}' from invite_results where label='scoped_directory'),
 'SAI_PERMISSION_DENIED','institution-scoped operator is denied even with a capability grant');
select is((select body#>>'{error,code}' from invite_results where label='scoped_cross_tenant'),
 'SAI_PERMISSION_DENIED','cross-tenant detail is indistinguishable for a scoped operator');
select is((select body#>>'{error,code}' from invite_results where label='cross_app'),
 'SAI_INTERNAL_CONTEXT_DENIED','a Principal-style global identity cannot enter the internal realm');
select is((select body#>>'{error,code}' from invite_results where label='owner_aal1_issue'),
 'SAI_MFA_REQUIRED','mutations require aal2');
select ok(not exists(select 1 from invite_results where
 (select array_agg(key order by key) from jsonb_object_keys(body) key)<>array['data','error','ok']::text[]),
 'all gateway responses use the spec-039 envelope');
select ok(not has_table_privilege('authenticated','public.invitations','insert')
 and has_table_privilege('authenticated','public.invitations','select')
 and not has_table_privilege('anon','public.invitations','select')
 and not has_table_privilege('authenticated','app_private.superadmin_internal_invite_receipts','select'),
 'Superadmin writes are RPC-only while legacy authenticated self-read remains available');
select ok(has_function_privilege('authenticated','public.superadmin_invite_detail_v2(uuid)','execute')
 and not has_function_privilege('anon','public.superadmin_invite_detail_v2(uuid)','execute')
 and not has_function_privilege('authenticated','app_private.superadmin_invite_payload_v2(uuid)','execute'),
 'only authenticated clients can invoke guarded public wrappers');

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9d100000-0000-4000-8000-000000000101','session_id','9d100000-0000-4000-8000-000000000201',
 'aal','aal2','role','authenticated')::text,true);
set local role authenticated;
select is((select count(*) from public.invitations),0::bigint,
 'internal identity has no direct invitation rows through legacy RLS');
reset role;
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9d100000-0000-4000-8000-000000000105','session_id','9d100000-0000-4000-8000-000000000205',
 'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select is((select count(*) from public.invitations),1::bigint,
 'legacy person self-read policy remains intact');
reset role;

update public.platform_role_permissions grant_record set status='inactive',revoked_at=now()
from public.platform_permissions permission_record,public.platform_roles role_record
where grant_record.permission_id=permission_record.id and grant_record.role_id=role_record.id
 and permission_record.code='platform.invites.read' and role_record.code='owner';
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9d100000-0000-4000-8000-000000000101','session_id','9d100000-0000-4000-8000-000000000201',
 'aal','aal2','role','authenticated')::text,true);
insert into invite_results values('capability_revoked',public.superadmin_invite_directory_v2(
 null,null,null,null,null,null,null,null,null,8,0,false));
select is((select body#>>'{error,code}' from invite_results where label='capability_revoked'),
 'SAI_PERMISSION_DENIED','capability revocation is effective immediately');

update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now(),version=2
where id='9d100000-0000-4000-8000-000000000501';
insert into invite_results values('membership_revoked',public.superadmin_invite_directory_v2(
 null,null,null,null,null,null,null,null,null,8,0,false));
select is((select body#>>'{error,code}' from invite_results where label='membership_revoked'),
 'SAI_MEMBERSHIP_REVOKED','membership revocation is effective immediately');
select ok((select bool_and(app_private.audit_verify_entry(id))
 from audit.audit_logs where action_code like 'invite.%'),
 'success and denial audit entries keep a valid tamper-evident chain');

select * from finish();
rollback;
