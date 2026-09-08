-- F-READ01: synthetic, rollback-only. Execute only in the nominal local runner.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_function('public','superadmin_forms_directory_v2',array['jsonb'],'internal directory public boundary exists');
select has_function('app_private','superadmin_forms_directory_v2',array['jsonb'],'internal directory private implementation exists');
select ok(has_function_privilege('authenticated','public.superadmin_forms_directory_v2(jsonb)','execute'),'authenticated can invoke the public boundary');
select ok(not has_function_privilege('anon','public.superadmin_forms_directory_v2(jsonb)','execute'),'anon cannot invoke public boundary');
select ok(not has_function_privilege('service_role','public.superadmin_forms_directory_v2(jsonb)','execute'),'service role is not an application reader');
select ok(not has_function_privilege('authenticated','app_private.superadmin_forms_directory_v2(jsonb)','execute'),'authenticated cannot invoke private implementation');
select ok(not has_function_privilege('anon','app_private.superadmin_forms_directory_v2(jsonb)','execute'),'anon cannot invoke private implementation');
select ok(not has_table_privilege('authenticated','public.forms','select'),'forms remain RPC-only');
select ok(not has_table_privilege('authenticated','public.form_occurrences','select'),'occurrences remain RPC-only');
select ok((select bool_and(p.prosecdef and 'search_path=""'=any(p.proconfig))
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where p.proname='superadmin_forms_directory_v2' and n.nspname in('public','app_private')),
  'both functions have explicit definer and empty search path');

insert into public.institution_types(id,code,name,status) values
 ('8f010000-0000-4000-8000-000000000001','fread01-type','F-READ01 type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 ('8f010000-0000-4000-8000-000000000010','8f010000-0000-4000-8000-000000000001','F-READ01 A','fread01-a','active'),
 ('8f010000-0000-4000-8000-000000000020','8f010000-0000-4000-8000-000000000001','F-READ01 B','fread01-b','active');

-- Readers 101/102/104 have NO People identity. Only 103 is People-only.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select ('8f010000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'authenticated','authenticated','fread01-'||n||'@invalid.test',now(),now(),now(),'{}','{}'
from generate_series(101,104) n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
select ('8f010000-0000-4000-8000-'||lpad((n+100)::text,12,'0'))::uuid,
 ('8f010000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 now(),now(),'aal2',now()+interval '1 hour' from generate_series(101,104) n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('8f010000-0000-4000-8000-000000000209','8f010000-0000-4000-8000-000000000101',now(),now(),'aal2',now()-interval '1 minute');

insert into app_private.superadmin_internal_identities(id) values
 ('8f010000-0000-4000-8000-000000000301'),('8f010000-0000-4000-8000-000000000302'),('8f010000-0000-4000-8000-000000000304');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
select ('8f010000-0000-4000-8000-'||lpad((n+300)::text,12,'0'))::uuid,
 ('8f010000-0000-4000-8000-'||lpad((n+200)::text,12,'0'))::uuid,
 ('8f010000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid
from unnest(array[101,102,104]) n;
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,r.id,fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 ('8f010000-0000-4000-8000-000000000501'::uuid,'8f010000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('8f010000-0000-4000-8000-000000000502'::uuid,'8f010000-0000-4000-8000-000000000302'::uuid,'operations','institution','8f010000-0000-4000-8000-000000000010'::uuid),
 ('8f010000-0000-4000-8000-000000000504'::uuid,'8f010000-0000-4000-8000-000000000304'::uuid,'content','platform',null::uuid)
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles r on r.code=fixture.role_code;
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,case when r.code='content' then 'deny'::public.permission_effect else 'allow'::public.permission_effect end,'active'
from public.platform_roles r cross join public.platform_permissions p
where r.code in('owner','operations','content') and p.code='forms.read'
on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null;

-- Historical author is separate from every internal reader, without an Auth link.
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('8f010000-0000-4000-8000-000000000601','adult','Historical','Author','Historical synthetic author','active'),
 ('8f010000-0000-4000-8000-000000000603','adult','People','Only','People only synthetic','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('8f010000-0000-4000-8000-000000000603','8f010000-0000-4000-8000-000000000103','active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select '8f010000-0000-4000-8000-000000000603',id,'active','platform',false
from public.platform_roles where code='owner';

create temporary table fread_fixture(id uuid primary key,institution_id uuid,status text,title text,stamp timestamptz);
insert into fread_fixture values
 ('8f010000-0000-4000-8000-000000000701','8f010000-0000-4000-8000-000000000010','draft','F-READ01 100%_literal\','2026-09-07T12:00:00.123456Z'),
 ('8f010000-0000-4000-8000-000000000704','8f010000-0000-4000-8000-000000000010','published','F-READ01 active','2026-09-07T11:00:00Z'),
 ('8f010000-0000-4000-8000-000000000703','8f010000-0000-4000-8000-000000000010','published','F-READ01 scheduled','2026-09-07T11:00:00Z'),
 ('8f010000-0000-4000-8000-000000000702','8f010000-0000-4000-8000-000000000010','published','F-READ01 closed','2026-09-07T10:00:00Z'),
 ('8f010000-0000-4000-8000-000000000705','8f010000-0000-4000-8000-000000000010','archived','F-READ01 archived','2026-09-07T09:00:00Z'),
 ('8f010000-0000-4000-8000-000000000799','8f010000-0000-4000-8000-000000000020','published','F-READ01 B private title','2026-09-08T12:00:00Z');
insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,status,created_by_person_id,updated_by_person_id,updated_at)
select id,institution_id,'form','identified','person',title,status,
 '8f010000-0000-4000-8000-000000000601','8f010000-0000-4000-8000-000000000601',stamp from fread_fixture;
insert into public.form_versions(id,form_id,version_number,state,created_by_person_id,published_at)
select id,id,1,case when status='draft' then 'working' else 'published' end,
 '8f010000-0000-4000-8000-000000000601',case when status='draft' then null else now()-interval '2 days' end
from fread_fixture;
update public.forms f set
 working_version_id=case when x.status='draft' then x.id else null end,
 published_version_id=case when x.status='draft' then null else x.id end,
 first_published_at=case when x.status='draft' then null else now()-interval '2 days' end
from fread_fixture x where f.id=x.id;
insert into public.form_applications(id,form_id,institution_id,name,created_by_person_id)
select id,id,institution_id,'Synthetic application','8f010000-0000-4000-8000-000000000601' from fread_fixture;
insert into public.form_schedules(id,application_id,time_zone,starts_at_local,recurrence_kind)
select id,id,'UTC',now() at time zone 'UTC','once' from fread_fixture;
insert into public.form_occurrences(id,application_id,schedule_id,institution_id,form_id,form_version_id,scheduled_local,time_zone,opens_at,closes_at,status)
select id,id,id,institution_id,id,id,now() at time zone 'UTC','UTC',
 case when title like '%scheduled' then now()+interval '1 day' else now()-interval '1 day' end,
 case when title like '%closed' then now()-interval '1 hour' else now()+interval '2 days' end,
 case when title like '%closed' then 'closed' else 'scheduled' end
from fread_fixture where status<>'draft';

create temporary table fread_results(label text primary key,body jsonb not null);
grant select,insert on fread_results to authenticated;
create temporary table fread_invalid(label text primary key,query jsonb);
insert into fread_invalid values
 ('null',null),('json_null','null'),('array','[]'),('scalar','1'),('unknown','{"actor_id":"forged"}'),
 ('limit_zero','{"limit":0}'),('limit_high','{"limit":101}'),('limit_negative','{"limit":-1}'),
 ('limit_decimal','{"limit":1.5}'),('limit_string','{"limit":"2"}'),('limit_null','{"limit":null}'),
 ('limit_huge','{"limit":9999999999999999999999}'),('search_type','{"search":7}'),
 ('search_long',jsonb_build_object('search',repeat('x',501))),
 ('payload_large',jsonb_build_object('search',repeat('x',17000))),
 ('institution_invalid','{"institution_id":"bad"}'),('institution_type','{"institution_id":true}'),
 ('statuses_type','{"statuses":"draft"}'),('statuses_null','{"statuses":null}'),
 ('statuses_invalid','{"statuses":["future"]}'),('statuses_element','{"statuses":[7]}'),
 ('operational_invalid','{"operational_statuses":["future"]}'),('kinds_invalid','{"kinds":["future"]}'),
 ('cursor_partial_stamp','{"cursor_updated_at":"2026-09-07T12:00:00Z"}'),
 ('cursor_partial_id','{"cursor_id":"8f010000-0000-4000-8000-000000000701"}'),
 ('cursor_id_invalid','{"cursor_updated_at":"2026-09-07T12:00:00Z","cursor_id":"bad"}'),
 ('cursor_infinite','{"cursor_updated_at":"infinity","cursor_id":"8f010000-0000-4000-8000-000000000701"}'),
 ('cursor_relative','{"cursor_updated_at":"now","cursor_id":"8f010000-0000-4000-8000-000000000701"}'),
 ('cursor_bad_date','{"cursor_updated_at":"2026-02-30T12:00:00Z","cursor_id":"8f010000-0000-4000-8000-000000000701"}'),
 ('cursor_bad_offset','{"cursor_updated_at":"2026-09-07T12:00:00+99:99","cursor_id":"8f010000-0000-4000-8000-000000000701"}'),
 ('cursor_long',jsonb_build_object('cursor_updated_at',repeat('x',1000),'cursor_id','8f010000-0000-4000-8000-000000000701')),
 ('date_invalid','{"starts_on_or_after":"2026-02-30"}'),('date_infinite','{"ends_on_or_before":"infinity"}'),
 ('date_relative','{"starts_on_or_after":"today"}'),('date_order','{"starts_on_or_after":"2026-09-08","ends_on_or_before":"2026-09-07"}');
grant select on fread_invalid to authenticated;

select set_config('request.jwt.claims','{"sub":"8f010000-0000-4000-8000-000000000102","session_id":"8f010000-0000-4000-8000-000000000202","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into fread_results values
 ('scope_a',public.superadmin_forms_directory_v2('{}')),
 ('scope_b_filter',public.superadmin_forms_directory_v2('{"institution_id":"8f010000-0000-4000-8000-000000000020"}')),
 ('cursor_b',public.superadmin_forms_directory_v2('{"cursor_id":"8f010000-0000-4000-8000-000000000799","cursor_updated_at":"2026-09-08T12:00:00Z"}')),
 ('page1',public.superadmin_forms_directory_v2('{"limit":2}')),
 ('cursor_offset',public.superadmin_forms_directory_v2('{"limit":2,"cursor_updated_at":"2026-09-07T08:00:00-03:00","cursor_id":"8f010000-0000-4000-8000-000000000704"}')),
 ('literal',public.superadmin_forms_directory_v2(jsonb_build_object('search','100%_literal\'))),
 ('draft',public.superadmin_forms_directory_v2('{"statuses":["draft"]}')),
 ('active',public.superadmin_forms_directory_v2('{"operational_statuses":["active"]}')),
 ('scheduled',public.superadmin_forms_directory_v2('{"operational_statuses":["scheduled"]}')),
 ('closed',public.superadmin_forms_directory_v2('{"operational_statuses":["closed"]}')),
 ('archived',public.superadmin_forms_directory_v2('{"operational_statuses":["archived"]}')),
 ('quick_poll',public.superadmin_forms_directory_v2('{"kinds":["quick_poll"]}')),
 ('future_start',public.superadmin_forms_directory_v2(jsonb_build_object('starts_on_or_after',(current_date+1)::text))),
 ('past_end',public.superadmin_forms_directory_v2(jsonb_build_object('ends_on_or_before',current_date::text)));
insert into fread_results select 'page2',public.superadmin_forms_directory_v2(jsonb_build_object(
 'limit',2,'cursor_updated_at',body#>>'{data,next_cursor,updated_at}','cursor_id',body#>>'{data,next_cursor,id}'))
from fread_results where label='page1';
insert into fread_results select 'page3',public.superadmin_forms_directory_v2(jsonb_build_object(
 'limit',2,'cursor_updated_at',body#>>'{data,next_cursor,updated_at}','cursor_id',body#>>'{data,next_cursor,id}'))
from fread_results where label='page2';
insert into fread_results select 'invalid_'||label,public.superadmin_forms_directory_v2(query) from fread_invalid;
reset role;

select is((select jsonb_array_length(body#>'{data,items}') from fread_results where label='scope_a'),5,'scope A has exactly its five forms without client filter');
select is((select body#>'{data,items}' from fread_results where label='scope_b_filter'),'[]'::jsonb,'client institution B cannot widen scope');
select ok(not exists(select 1 from fread_results where label in('scope_a','cursor_b','page1','page2','page3')
  and body::text like '%B private title%'),'cursor from B never authorizes B');
select is((select body#>>'{data,items,0,id}' from fread_results where label='page1'),'8f010000-0000-4000-8000-000000000701','newest first');
select is((select body#>>'{data,items,1,id}' from fread_results where label='page1'),'8f010000-0000-4000-8000-000000000704','tie uses descending UUID');
select is((select body#>>'{data,items,0,id}' from fread_results where label='page2'),'8f010000-0000-4000-8000-000000000703','next page resumes below tied UUID');
select is((select body#>'{data,items}' from fread_results where label='cursor_offset'),(select body#>'{data,items}' from fread_results where label='page2'),'offset cursor identifies the same instant');
select ok((select body#>>'{data,has_more}'='true' and body#>>'{data,next_cursor,id}'='8f010000-0000-4000-8000-000000000704' from fread_results where label='page1'),'first-page cursor is the last visible row');
select is((select body#>>'{data,items,1,id}' from fread_results where label='page2'),'8f010000-0000-4000-8000-000000000702','second page retains order');
select is((select body#>>'{data,items,0,id}' from fread_results where label='page3'),'8f010000-0000-4000-8000-000000000705','last page contains oldest');
select ok((select body#>'{data,next_cursor}'='null'::jsonb and body#>>'{data,has_more}'='false' from fread_results where label='page3'),'last page has no cursor');
select is((select jsonb_array_length(body#>'{data,items}') from fread_results where label='literal'),1,'percent underscore and backslash are literal search characters');
select is((select body#>>'{data,items,0,operational_status}' from fread_results where label='draft'),'draft','draft precedence retained');
select is((select body#>>'{data,items,0,id}' from fread_results where label='active'),'8f010000-0000-4000-8000-000000000704','active projection filter');
select is((select body#>>'{data,items,0,id}' from fread_results where label='scheduled'),'8f010000-0000-4000-8000-000000000703','scheduled projection filter');
select is((select body#>>'{data,items,0,id}' from fread_results where label='closed'),'8f010000-0000-4000-8000-000000000702','closed projection filter');
select is((select body#>>'{data,items,0,operational_status}' from fread_results where label='archived'),'archived','archived precedence over open window');
select is((select body#>'{data,items}' from fread_results where label='quick_poll'),'[]'::jsonb,'kind filter yields honest empty page');
select is((select jsonb_array_length(body#>'{data,items}') from fread_results where label='future_start'),1,'start date filter selects only the future occurrence');
select is((select body#>>'{data,items,0,id}' from fread_results where label='past_end'),'8f010000-0000-4000-8000-000000000702','end date filter selects the closed occurrence');
select is(body#>>'{error,code}','SAI_INVALID_ARGUMENT','rejects '||label) from fread_results where label like 'invalid_%' order by label;
select ok(not exists(select 1 from fread_results where label like 'invalid_%' and body#>>'{error,http_status}' is distinct from '400'),'all invalid inputs have controlled status 400');

-- Auth precedes payload validation, including malformed cursor and limit.
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
insert into fread_results values ('no_auth',public.superadmin_forms_directory_v2('{"limit":"bad","cursor_id":"bad"}'));
reset role;
select set_config('request.jwt.claims','{"sub":"8f010000-0000-4000-8000-000000000103","session_id":"8f010000-0000-4000-8000-000000000203","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into fread_results values ('people_only',public.superadmin_forms_directory_v2('{}'));
reset role;
select set_config('request.jwt.claims','{"sub":"8f010000-0000-4000-8000-000000000104","session_id":"8f010000-0000-4000-8000-000000000204","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into fread_results values ('denied',public.superadmin_forms_directory_v2('{}'));
reset role;
select set_config('request.jwt.claims','{"sub":"8f010000-0000-4000-8000-000000000101","session_id":"8f010000-0000-4000-8000-000000000209","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into fread_results values ('expired',public.superadmin_forms_directory_v2('{}'));
reset role;
select set_config('request.jwt.claims','{"sub":"8f010000-0000-4000-8000-000000000101","session_id":"8f010000-0000-4000-8000-000000000201","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into fread_results values ('owner_aal1',public.superadmin_forms_directory_v2('{}'));
reset role;
select set_config('request.jwt.claims','{"sub":"8f010000-0000-4000-8000-000000000101","session_id":"8f010000-0000-4000-8000-000000000201","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into fread_results values ('owner',public.superadmin_forms_directory_v2('{"search":"F-READ01 "}'));
reset role;
select is((select jsonb_array_length(body#>'{data,items}') from fread_results where label='owner'),6,'platform Owner reads A and B with no PersonAuthLink');
select is((select body#>>'{error,code}' from fread_results where label='no_auth'),'SAI_AUTH_REQUIRED','auth guard runs before payload casts');
select is((select body#>>'{error,code}' from fread_results where label='people_only'),'SAI_INTERNAL_CONTEXT_DENIED','People-only actor remains denied despite legacy Owner role');
select is((select body#>>'{error,code}' from fread_results where label='denied'),'SAI_PERMISSION_DENIED','explicit deny checked');
select is((select body#>>'{error,code}' from fread_results where label='expired'),'SAI_SESSION_INVALID','expired session denied');
select is((select body#>>'{error,code}' from fread_results where label='owner_aal1'),'SAI_MFA_REQUIRED','Owner still requires AAL2');

select set_config('request.jwt.claims','{"sub":"8f010000-0000-4000-8000-000000000102","session_id":"8f010000-0000-4000-8000-000000000202","role":"authenticated"}',true);
set local role authenticated;
insert into fread_results values ('missing_aal',public.superadmin_forms_directory_v2('{}'));
reset role;
select is((select body#>>'{error,code}' from fread_results where label='missing_aal'),'SAI_INTERNAL_CONTEXT_DENIED','missing assurance cannot pass the internal read boundary');

select set_config('request.jwt.claims','{"sub":"8f010000-0000-4000-8000-000000000102","session_id":"8f010000-0000-4000-8000-000000000201","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into fread_results values ('foreign_session',public.superadmin_forms_directory_v2('{}'));
reset role;
select is((select body#>>'{error,code}' from fread_results where label='foreign_session'),'SAI_SESSION_INVALID','a real session belonging to another user is denied');

update public.platform_role_permissions rp set effect='allow'
from public.platform_roles r,public.platform_permissions p
where rp.role_id=r.id and rp.permission_id=p.id and r.code='content' and p.code='forms.read';
select set_config('request.jwt.claims','{"sub":"8f010000-0000-4000-8000-000000000104","session_id":"8f010000-0000-4000-8000-000000000204","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into fread_results values ('auth_link_before_revocation',public.superadmin_forms_directory_v2('{"search":"F-READ01 "}'));
reset role;
select is((select body#>>'{ok}' from fread_results where label='auth_link_before_revocation'),'true','internal reader is allowed before AuthLink revocation');
update app_private.superadmin_internal_auth_links set status='revoked',revoked_at=now(),version=version+1
where id='8f010000-0000-4000-8000-000000000404';
set local role authenticated;
insert into fread_results values ('auth_link_revoked',public.superadmin_forms_directory_v2('{}'));
reset role;
select is((select body#>>'{error,code}' from fread_results where label='auth_link_revoked'),'SAI_INTERNAL_CONTEXT_DENIED','revoked AuthLink denies an otherwise active membership and grant');

-- Revocation is effective on a subsequent request, not just first-page login.
select set_config('request.jwt.claims','{"sub":"8f010000-0000-4000-8000-000000000102","session_id":"8f010000-0000-4000-8000-000000000202","aal":"aal2","role":"authenticated"}',true);
update public.platform_role_permissions rp set effect='deny'
from public.platform_roles r,public.platform_permissions p
where rp.role_id=r.id and rp.permission_id=p.id and r.code='operations' and p.code='forms.read';
set local role authenticated;
insert into fread_results select 'grant_revoked',public.superadmin_forms_directory_v2(jsonb_build_object(
 'limit',2,'cursor_updated_at',body#>>'{data,next_cursor,updated_at}','cursor_id',body#>>'{data,next_cursor,id}')) from fread_results where label='page1';
reset role;
update public.platform_role_permissions rp set effect='allow'
from public.platform_roles r,public.platform_permissions p
where rp.role_id=r.id and rp.permission_id=p.id and r.code='operations' and p.code='forms.read';
update app_private.superadmin_internal_memberships set status='suspended',suspended_at=now(),version=version+1 where id='8f010000-0000-4000-8000-000000000502';
set local role authenticated;
insert into fread_results values ('membership_suspended',public.superadmin_forms_directory_v2('{}'));
reset role;
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now(),version=version+1 where id='8f010000-0000-4000-8000-000000000502';
set local role authenticated;
insert into fread_results values ('membership_revoked',public.superadmin_forms_directory_v2('{}'));
reset role;
update auth.sessions set not_after=now()-interval '1 second' where id='8f010000-0000-4000-8000-000000000202';
set local role authenticated;
insert into fread_results values ('session_revoked',public.superadmin_forms_directory_v2('{}'));
reset role;
select is((select body#>>'{error,code}' from fread_results where label='grant_revoked'),'SAI_PERMISSION_DENIED','grant revoked between pages denied');
select is((select body#>>'{error,code}' from fread_results where label='membership_suspended'),'SAI_MEMBERSHIP_SUSPENDED','suspended membership denied');
select is((select body#>>'{error,code}' from fread_results where label='membership_revoked'),'SAI_MEMBERSHIP_REVOKED','revoked membership denied');
select is((select body#>>'{error,code}' from fread_results where label='session_revoked'),'SAI_SESSION_INVALID','revoked session denied before membership');

select ok(not exists(select 1 from fread_results where body#>>'{ok}'='false' and body->'data' is distinct from 'null'::jsonb),'all errors discard data');
select ok(not exists(select 1 from fread_results where
 (select array_agg(key order by key) from jsonb_object_keys(body) key) is distinct from array['data','error','ok']::text[]),'exact envelope keys');
select ok(not exists(select 1 from fread_results cross join lateral jsonb_array_elements(body#>'{data,items}') item where
 (select array_agg(key order by key) from jsonb_object_keys(item) key) is distinct from
 array['id','identity_mode','kind','management_version','operational_status','status','title','updated_at']::text[]),'only eight allowlisted item fields');
select ok(not exists(select 1 from fread_results where body::text like '%@invalid.test%' or body::text like '%created_by_person_id%' or body::text like '%participation_id%'),'no email authorship or response identity in projection');
select is((select count(*)::integer from public.person_auth_links where auth_user_id in('8f010000-0000-4000-8000-000000000101','8f010000-0000-4000-8000-000000000102')),0,'internal readers never gain manufactured People links');
select * from finish();
rollback;
