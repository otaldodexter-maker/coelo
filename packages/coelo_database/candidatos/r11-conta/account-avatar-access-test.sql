begin; create extension if not exists pgtap with schema extensions; select plan(9);
-- Synthetic tenant and identity fixtures. Everything rolls back.
insert into public.institution_types(id,code,name,status) values
 ('8d200000-0000-4000-8000-000000000001','assessment-v2','Assessment v2','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('8d200000-0000-4000-8000-000000000010','Assessment Tenant A','assessment-v2-a','active','8d200000-0000-4000-8000-000000000001'),
 ('8d200000-0000-4000-8000-000000000020','Assessment Tenant B','assessment-v2-b','active','8d200000-0000-4000-8000-000000000001');
-- Forma de producao: units.unit_type_id -> public.unit_types e handle NOT NULL.
insert into public.unit_types(id,code,name,status) values ('7c0000f0-0000-4000-8000-000000000901','superadmin-assessments-v2-test-u0','Tipo de unidade da fixture','active');
insert into public.units(id,institution_id,unit_type_id,name,slug,status,handle) values
 ('8d200000-0000-4000-8000-000000000011','8d200000-0000-4000-8000-000000000010','7c0000f0-0000-4000-8000-000000000901','Unidade A','assessment-v2-a-unit','active','u.000000000011'),
 ('8d200000-0000-4000-8000-000000000021','8d200000-0000-4000-8000-000000000020','7c0000f0-0000-4000-8000-000000000901','Unidade B','assessment-v2-b-unit','active','u.000000000021');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('8d200000-0000-4000-8000-000000000601','adult','Fixture','Creator','Fixture Creator','active'),
 ('8d200000-0000-4000-8000-000000000602','adult','People','Only','People Only','active'),
 ('8d200000-0000-4000-8000-000000000603','child','Aluno','Sintético','Aluno Sintético','active');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('8d200000-0000-4000-8000-000000000101','authenticated','authenticated','assessment-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('8d200000-0000-4000-8000-000000000102','authenticated','authenticated','assessment-scoped@invalid.test',now(),now(),now(),'{}','{}'),
 ('8d200000-0000-4000-8000-000000000103','authenticated','authenticated','assessment-people@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('8d200000-0000-4000-8000-000000000201','8d200000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('8d200000-0000-4000-8000-000000000202','8d200000-0000-4000-8000-000000000102',now(),now(),'aal2',now()+interval '1 hour'),
 ('8d200000-0000-4000-8000-000000000203','8d200000-0000-4000-8000-000000000103',now(),now(),'aal2',now()+interval '1 hour'),
 ('8d200000-0000-4000-8000-000000000209','8d200000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('8d200000-0000-4000-8000-000000000301'),('8d200000-0000-4000-8000-000000000302');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('8d200000-0000-4000-8000-000000000401','8d200000-0000-4000-8000-000000000301','8d200000-0000-4000-8000-000000000101'),
 ('8d200000-0000-4000-8000-000000000402','8d200000-0000-4000-8000-000000000302','8d200000-0000-4000-8000-000000000102');
insert into app_private.superadmin_internal_memberships(
 id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,role_record.id,
 fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 ('8d200000-0000-4000-8000-000000000501'::uuid,'8d200000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('8d200000-0000-4000-8000-000000000502'::uuid,'8d200000-0000-4000-8000-000000000302'::uuid,'owner','institution','8d200000-0000-4000-8000-000000000010'::uuid)
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('8d200000-0000-4000-8000-000000000602','8d200000-0000-4000-8000-000000000103','active');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='owner' and permission_record.code in('activities.read','activities.manage','activities.create')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;


insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r cross join public.platform_permissions p where r.code='owner' and p.code='platform.read'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
select set_config('request.jwt.claims',jsonb_build_object('sub','8d200000-0000-4000-8000-000000000101','session_id','8d200000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);
create temporary table r11_legacy_profile as select public.superadmin_account_profile_save('8d200000-0000-4000-8000-000000000901','Conta','Sintetica','11999990000',null,'QZ') body;
select is((select body#>>'{avatar,initials}' from r11_legacy_profile),'QZ','legacy save persists custom initials');
select is(public.superadmin_account_profile_get()#>>'{avatar,initials}','QZ','reload returns saved initials');
create function pg_temp.r11_save_color(color text) returns jsonb language plpgsql as $$
begin
 if to_regprocedure('public.superadmin_account_profile_save_v2(uuid,text,text,text,text,text,text)') is null then
   return public.superadmin_account_profile_save(gen_random_uuid(),'Conta','Sintetica','11999990000',null,'QZ');
 end if;
 return public.superadmin_account_profile_save_v2(gen_random_uuid(),'Conta','Sintetica','11999990000',null,'QZ',color);
end $$;
select is(pg_temp.r11_save_color('#336699')#>>'{avatar,background_color}','#336699','color save returns persisted server value');
select is(public.superadmin_account_profile_get()#>>'{avatar,background_color}','#336699','color survives independent reload');
select ok(jsonb_array_length(public.superadmin_account_profile_get()#>'{access,capability_details}')>0,'real module and scope details are projected');
select ok(not exists(select 1 from jsonb_array_elements(public.superadmin_account_profile_get()#>'{access,capability_details}') d where d->>'scope_kind'<>'platform' or nullif(d->>'module_code','') is null),'platform membership metadata has real scope and module');
select throws_ok($$select pg_temp.r11_save_color('javascript:bad')$$,'22023','invalid_account_profile','invalid color rejected server-side');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select '8d200000-0000-4000-8000-000000000602',id,'active','platform',false from public.platform_roles where code='owner';
select set_config('request.jwt.claims',jsonb_build_object('sub','8d200000-0000-4000-8000-000000000103','session_id','8d200000-0000-4000-8000-000000000203','aal','aal2','role','authenticated')::text,true);
select throws_ok($$select public.superadmin_account_profile_save('8d200000-0000-4000-8000-000000000901','Outra','Conta','11999990000',null,'OC')$$,'42501','account_request_not_owned','other session cannot replay first account receipt');
select set_config('request.jwt.claims','{}',true);
select throws_ok($$select public.superadmin_account_profile_get()$$,'28000','authentication_required','anonymous session cannot read previous account');
select * from finish(); rollback;
