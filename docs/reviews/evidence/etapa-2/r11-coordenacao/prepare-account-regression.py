from pathlib import Path
root=Path('C:/Users/adrie/Documents/Coelo')
source=(root/'packages/coelo_database/supabase/tests/superadmin_assessments_internal_v2_test.sql').read_text(encoding='utf-8-sig')
fixture=source[source.index('-- Synthetic tenant'):source.index('-- Producao (cadeia de Atividades')]
sql="begin; create extension if not exists pgtap with schema extensions; select plan(9);\n"+fixture
sql+='''
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
'''
(root/'packages/coelo_database/candidatos/r11-conta/account-avatar-access-test.sql').write_text(sql,encoding='utf-8')
