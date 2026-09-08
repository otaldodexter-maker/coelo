-- C02 / I008: local candidate; synthetic fixtures, full rollback.
-- Executes public response RPCs as authenticated; no replacement auth functions.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
create function pg_temp.edit_id(n integer) returns uuid language sql immutable as $$
  select ('8c023000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
insert into public.institution_types(id,code,name,status)
values(pg_temp.edit_id(1),'c02-edit-test','Synthetic edit type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status)
values(pg_temp.edit_id(10),pg_temp.edit_id(1),'Synthetic edit institution','c02-edit-test','active');
insert into auth.users(id,aud,role,email,created_at,updated_at)
select pg_temp.edit_id(n),'authenticated','authenticated','c02-edit-'||n||'@invalid.test',now(),now()
from unnest(array[101,102]) n;
insert into public.people(id,person_type,first_name,last_name,display_name,status)
select pg_temp.edit_id(n),'adult','Synthetic','Responder','Synthetic responder '||n,'active'
from unnest(array[201,202]) n;
insert into public.person_auth_links(person_id,auth_user_id,status)
select pg_temp.edit_id(n+100),pg_temp.edit_id(n),'active' from unnest(array[101,102]) n;
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select pg_temp.edit_id(n),r.id,'active','platform',false
from unnest(array[201,202]) n cross join public.platform_roles r where r.code='owner';
insert into public.institution_memberships(person_id,institution_id,role_code,status)
select pg_temp.edit_id(n),pg_temp.edit_id(10),'owner','active' from unnest(array[201,202]) n;
create temporary table edit_results(key text primary key,value jsonb not null);
grant select,insert,update on edit_results to authenticated;
create function pg_temp.edit_snapshot(response_uuid uuid) returns jsonb language sql as $$
  select jsonb_build_object(
    'response',(select to_jsonb(r) from public.form_responses r where id=response_uuid),
    'answers',coalesce((select jsonb_agg(to_jsonb(a) order by a.id) from public.form_answers a where response_id=response_uuid),'[]'),
    'revisions',coalesce((select jsonb_agg(to_jsonb(r) order by r.id) from public.form_response_revisions r where response_id=response_uuid),'[]'));
$$;


insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_person_id,updated_by_person_id)
values(pg_temp.edit_id(1000),pg_temp.edit_id(10),'form','identified','person','Synthetic identified revision',pg_temp.edit_id(201),pg_temp.edit_id(201));
insert into public.form_versions(id,form_id,version_number,created_by_person_id)
values(pg_temp.edit_id(1001),pg_temp.edit_id(1000),1,pg_temp.edit_id(201));
insert into public.form_sections(id,form_version_id,title,position)
values(pg_temp.edit_id(1002),pg_temp.edit_id(1001),'Synthetic section',0);
insert into public.form_items(id,form_version_id,section_id,kind,label,is_required,position,config_jsonb) values
(pg_temp.edit_id(1003),pg_temp.edit_id(1001),pg_temp.edit_id(1002),'short_text','Required text',true,0,'{"max_length":100}'),
(pg_temp.edit_id(1004),pg_temp.edit_id(1001),pg_temp.edit_id(1002),'integer','Required number',true,1,'{"min_value":1,"max_value":10}'),
(pg_temp.edit_id(1010),pg_temp.edit_id(1001),pg_temp.edit_id(1002),'yes_no','Show dependent',false,2,'{}'),
(pg_temp.edit_id(1011),pg_temp.edit_id(1001),pg_temp.edit_id(1002),'short_text','Required dependent',true,3,'{}');
insert into public.form_question_conditions(form_version_id,target_item_id,source_item_id,condition_kind,expected_yes_no)
values(pg_temp.edit_id(1001),pg_temp.edit_id(1011),pg_temp.edit_id(1010),'yes_no',true);
update public.form_versions set state='published',published_at=now() where id=pg_temp.edit_id(1001);
update public.forms set status='published',published_version_id=pg_temp.edit_id(1001),first_published_at=now() where id=pg_temp.edit_id(1000);
insert into public.form_applications(id,form_id,institution_id,name,created_by_person_id)
values(pg_temp.edit_id(1005),pg_temp.edit_id(1000),pg_temp.edit_id(10),'Synthetic application',pg_temp.edit_id(201));
insert into public.form_schedules(id,application_id,time_zone,starts_at_local,recurrence_kind)
values(pg_temp.edit_id(1006),pg_temp.edit_id(1005),'America/Sao_Paulo',localtimestamp,'once');
insert into public.form_occurrences(id,application_id,schedule_id,institution_id,form_id,form_version_id,scheduled_local,time_zone,opens_at,closes_at,status,opened_at)
values(pg_temp.edit_id(1007),pg_temp.edit_id(1005),pg_temp.edit_id(1006),pg_temp.edit_id(10),pg_temp.edit_id(1000),pg_temp.edit_id(1001),localtimestamp,'America/Sao_Paulo',now()-interval '1 hour',now()+interval '1 day','open',now()-interval '1 hour');
insert into public.form_participations(id,occurrence_id,institution_id,person_id,response_unit_key,eligibility_state,response_state)
values(pg_temp.edit_id(1008),pg_temp.edit_id(1007),pg_temp.edit_id(10),pg_temp.edit_id(201),'person:'||pg_temp.edit_id(201)::text,'eligible','draft');
insert into public.form_responses(id,occurrence_id,institution_id,form_id,form_version_id,identity_mode,respondent_person_id,anonymous_edit_secret_hash)
values(pg_temp.edit_id(1009),pg_temp.edit_id(1007),pg_temp.edit_id(10),pg_temp.edit_id(1000),pg_temp.edit_id(1001),'identified',
pg_temp.edit_id(201),
null);

set local role authenticated;
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000101","aal":"aal1","role":"authenticated"}',true);

select lives_ok($$select public.form_save_response_draft('8c023000-0000-4000-8000-000000001100',1,'{"response_id":"8c023000-0000-4000-8000-000000001009","participation_id":"8c023000-0000-4000-8000-000000001008","answers":[]}'::jsonb)$$,'identified: incomplete draft remains saveable');
insert into edit_results values('identified-submitted',public.form_submit_response('8c023000-0000-4000-8000-000000001101',2,'{"response_id":"8c023000-0000-4000-8000-000000001009","participation_id":"8c023000-0000-4000-8000-000000001008","answers":[{"item_id":"8c023000-0000-4000-8000-000000001003","kind":"short_text","text_value":"Confirmed"},{"item_id":"8c023000-0000-4000-8000-000000001004","kind":"integer","integer_value":5},{"item_id":"8c023000-0000-4000-8000-000000001010","kind":"yes_no","yes_no_value":false}]}'::jsonb));
reset role;
select is((select status from public.form_responses where id=pg_temp.edit_id(1009)),'submitted','identified: valid submit fixture reaches submitted');
update public.form_responses set submitted_at=now()-interval '10 minutes' where id=pg_temp.edit_id(1009); -- make timestamp preservation observable within this transaction
insert into edit_results values('identified-before',pg_temp.edit_snapshot(pg_temp.edit_id(1009)));
set local role authenticated;
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000101","aal":"aal1","role":"authenticated"}',true);

select throws_ok($$select public.form_edit_response('8c023000-0000-4000-8000-000000001110',3,'{"response_id":"8c023000-0000-4000-8000-000000001009","participation_id":"8c023000-0000-4000-8000-000000001008","answers":[]}'::jsonb)$$,'23514','required visible form answers are missing','identified: omitted edit rejected');
reset role;
select is(pg_temp.edit_snapshot(pg_temp.edit_id(1009)),(select value from edit_results where key='identified-before'),'identified: omitted rolls back answers/version/revisions');
select is((select count(*) from app_private.form_command_receipts where request_id='8c023000-0000-4000-8000-000000001110'),0::bigint,'identified: omitted does not reserve idempotency receipt');
set local role authenticated;
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000101","aal":"aal1","role":"authenticated"}',true);

select throws_ok($$select public.form_edit_response('8c023000-0000-4000-8000-000000001111',3,'{"response_id":"8c023000-0000-4000-8000-000000001009","participation_id":"8c023000-0000-4000-8000-000000001008","answers":[{"item_id":"8c023000-0000-4000-8000-000000001003","kind":"short_text","text_value":"   "},{"item_id":"8c023000-0000-4000-8000-000000001004","kind":"integer","integer_value":5},{"item_id":"8c023000-0000-4000-8000-000000001010","kind":"yes_no","yes_no_value":false}]}'::jsonb)$$,'23514','required visible form answers are missing','identified: blank edit rejected');
reset role;
select is(pg_temp.edit_snapshot(pg_temp.edit_id(1009)),(select value from edit_results where key='identified-before'),'identified: blank rolls back answers/version/revisions');
select is((select count(*) from app_private.form_command_receipts where request_id='8c023000-0000-4000-8000-000000001111'),0::bigint,'identified: blank does not reserve idempotency receipt');
set local role authenticated;
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000101","aal":"aal1","role":"authenticated"}',true);

select throws_ok($$select public.form_edit_response('8c023000-0000-4000-8000-000000001112',3,'{"response_id":"8c023000-0000-4000-8000-000000001009","participation_id":"8c023000-0000-4000-8000-000000001008","answers":[{"item_id":"8c023000-0000-4000-8000-000000001003","kind":"short_text","text_value":"Confirmed"},{"item_id":"8c023000-0000-4000-8000-000000001004","kind":"integer","integer_value":11},{"item_id":"8c023000-0000-4000-8000-000000001010","kind":"yes_no","yes_no_value":false}]}'::jsonb)$$,'23514','numeric form answer is out of range','identified: out-of-range edit rejected');
reset role;
select is(pg_temp.edit_snapshot(pg_temp.edit_id(1009)),(select value from edit_results where key='identified-before'),'identified: out-of-range rolls back answers/version/revisions');
select is((select count(*) from app_private.form_command_receipts where request_id='8c023000-0000-4000-8000-000000001112'),0::bigint,'identified: out-of-range does not reserve idempotency receipt');
set local role authenticated;
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000101","aal":"aal1","role":"authenticated"}',true);

select throws_ok($$select public.form_edit_response('8c023000-0000-4000-8000-000000001113',3,'{"response_id":"8c023000-0000-4000-8000-000000001009","participation_id":"8c023000-0000-4000-8000-000000001008","answers":[{"item_id":"8c023000-0000-4000-8000-000000001003","kind":"short_text","text_value":"Confirmed"},{"item_id":"8c023000-0000-4000-8000-000000001004","kind":"integer","integer_value":null},{"item_id":"8c023000-0000-4000-8000-000000001010","kind":"yes_no","yes_no_value":false}]}'::jsonb)$$,'23514',null,'identified: null-number edit rejected');
reset role;
select is(pg_temp.edit_snapshot(pg_temp.edit_id(1009)),(select value from edit_results where key='identified-before'),'identified: null-number rolls back answers/version/revisions');
select is((select count(*) from app_private.form_command_receipts where request_id='8c023000-0000-4000-8000-000000001113'),0::bigint,'identified: null-number does not reserve idempotency receipt');
set local role authenticated;
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000101","aal":"aal1","role":"authenticated"}',true);

select throws_ok($$select public.form_edit_response('8c023000-0000-4000-8000-000000001114',3,'{"response_id":"8c023000-0000-4000-8000-000000001009","participation_id":"8c023000-0000-4000-8000-000000001008","answers":[{"item_id":"8c023000-0000-4000-8000-000000001003","kind":"short_text","text_value":"Confirmed"},{"item_id":"8c023000-0000-4000-8000-000000001004","kind":"integer","integer_value":5},{"item_id":"8c023000-0000-4000-8000-000000001010","kind":"yes_no","yes_no_value":true}]}'::jsonb)$$,'23514','required visible form answers are missing','identified: new-visible-dependent-omitted edit rejected');
reset role;
select is(pg_temp.edit_snapshot(pg_temp.edit_id(1009)),(select value from edit_results where key='identified-before'),'identified: new-visible-dependent-omitted rolls back answers/version/revisions');
select is((select count(*) from app_private.form_command_receipts where request_id='8c023000-0000-4000-8000-000000001114'),0::bigint,'identified: new-visible-dependent-omitted does not reserve idempotency receipt');
set local role authenticated;
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000101","aal":"aal1","role":"authenticated"}',true);

insert into edit_results values('identified-edited',public.form_edit_response('8c023000-0000-4000-8000-000000001110',3,'{"response_id":"8c023000-0000-4000-8000-000000001009","participation_id":"8c023000-0000-4000-8000-000000001008","answers":[{"item_id":"8c023000-0000-4000-8000-000000001003","kind":"short_text","text_value":"Revised"},{"item_id":"8c023000-0000-4000-8000-000000001004","kind":"integer","integer_value":7},{"item_id":"8c023000-0000-4000-8000-000000001010","kind":"yes_no","yes_no_value":false}]}'::jsonb));
select is(public.form_edit_response('8c023000-0000-4000-8000-000000001110',3,'{"response_id":"8c023000-0000-4000-8000-000000001009","participation_id":"8c023000-0000-4000-8000-000000001008","answers":[{"item_id":"8c023000-0000-4000-8000-000000001003","kind":"short_text","text_value":"Revised"},{"item_id":"8c023000-0000-4000-8000-000000001004","kind":"integer","integer_value":7},{"item_id":"8c023000-0000-4000-8000-000000001010","kind":"yes_no","yes_no_value":false}]}'::jsonb),(select value from edit_results where key='identified-edited'),'identified: exact edit retry returns original receipt');
reset role;
select ok((select status='submitted' and management_version=4 from public.form_responses where id=pg_temp.edit_id(1009)),'identified: successful edit remains submitted at one new version');
select is((select text_value from public.form_answers where response_id=pg_temp.edit_id(1009) and item_id=pg_temp.edit_id(1003)),'Revised','identified: revised answer persisted');
select is((select count(*) from public.form_response_revisions where response_id=pg_temp.edit_id(1009) and action='edited'),1::bigint,'identified: retry adds no revision');
select ok((select submitted_at=(select (value->'response'->>'submitted_at')::timestamptz from edit_results where key='identified-before') from public.form_responses where id=pg_temp.edit_id(1009)),'identified: original submission timestamp preserved');
select is((select count(*) from app_private.form_command_receipts where request_id='8c023000-0000-4000-8000-000000001110'),1::bigint,'identified successful edit owns one receipt');

insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_person_id,updated_by_person_id)
values(pg_temp.edit_id(2000),pg_temp.edit_id(10),'form','anonymous','person','Synthetic anonymous revision',pg_temp.edit_id(201),pg_temp.edit_id(201));
insert into public.form_versions(id,form_id,version_number,created_by_person_id)
values(pg_temp.edit_id(2001),pg_temp.edit_id(2000),1,pg_temp.edit_id(201));
insert into public.form_sections(id,form_version_id,title,position)
values(pg_temp.edit_id(2002),pg_temp.edit_id(2001),'Synthetic section',0);
insert into public.form_items(id,form_version_id,section_id,kind,label,is_required,position,config_jsonb) values
(pg_temp.edit_id(2003),pg_temp.edit_id(2001),pg_temp.edit_id(2002),'short_text','Required text',true,0,'{"max_length":100}'),
(pg_temp.edit_id(2004),pg_temp.edit_id(2001),pg_temp.edit_id(2002),'integer','Required number',true,1,'{"min_value":1,"max_value":10}'),
(pg_temp.edit_id(2010),pg_temp.edit_id(2001),pg_temp.edit_id(2002),'yes_no','Show dependent',false,2,'{}'),
(pg_temp.edit_id(2011),pg_temp.edit_id(2001),pg_temp.edit_id(2002),'short_text','Required dependent',true,3,'{}');
insert into public.form_question_conditions(form_version_id,target_item_id,source_item_id,condition_kind,expected_yes_no)
values(pg_temp.edit_id(2001),pg_temp.edit_id(2011),pg_temp.edit_id(2010),'yes_no',true);
update public.form_versions set state='published',published_at=now() where id=pg_temp.edit_id(2001);
update public.forms set status='published',published_version_id=pg_temp.edit_id(2001),first_published_at=now() where id=pg_temp.edit_id(2000);
insert into public.form_applications(id,form_id,institution_id,name,created_by_person_id)
values(pg_temp.edit_id(2005),pg_temp.edit_id(2000),pg_temp.edit_id(10),'Synthetic application',pg_temp.edit_id(201));
insert into public.form_schedules(id,application_id,time_zone,starts_at_local,recurrence_kind)
values(pg_temp.edit_id(2006),pg_temp.edit_id(2005),'America/Sao_Paulo',localtimestamp,'once');
insert into public.form_occurrences(id,application_id,schedule_id,institution_id,form_id,form_version_id,scheduled_local,time_zone,opens_at,closes_at,status,opened_at)
values(pg_temp.edit_id(2007),pg_temp.edit_id(2005),pg_temp.edit_id(2006),pg_temp.edit_id(10),pg_temp.edit_id(2000),pg_temp.edit_id(2001),localtimestamp,'America/Sao_Paulo',now()-interval '1 hour',now()+interval '1 day','open',now()-interval '1 hour');
insert into public.form_participations(id,occurrence_id,institution_id,person_id,response_unit_key,eligibility_state,response_state)
values(pg_temp.edit_id(2008),pg_temp.edit_id(2007),pg_temp.edit_id(10),pg_temp.edit_id(201),'person:'||pg_temp.edit_id(201)::text,'eligible','draft');
insert into public.form_responses(id,occurrence_id,institution_id,form_id,form_version_id,identity_mode,respondent_person_id,anonymous_edit_secret_hash)
values(pg_temp.edit_id(2009),pg_temp.edit_id(2007),pg_temp.edit_id(10),pg_temp.edit_id(2000),pg_temp.edit_id(2001),'anonymous',
null,
app_private.form_hash_anonymous_edit_secret('c02-synthetic-edit-secret-abcdefghijklmnopqrstuvwxyz012345'));

set local role authenticated;
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000101","aal":"aal1","role":"authenticated"}',true);

select lives_ok($$select public.form_save_response_draft('8c023000-0000-4000-8000-000000002100',1,'{"response_id":"8c023000-0000-4000-8000-000000002009","participation_id":"8c023000-0000-4000-8000-000000002008","answers":[],"edit_secret":"c02-synthetic-edit-secret-abcdefghijklmnopqrstuvwxyz012345"}'::jsonb)$$,'anonymous: incomplete draft remains saveable');
insert into edit_results values('anonymous-submitted',public.form_submit_response('8c023000-0000-4000-8000-000000002101',2,'{"response_id":"8c023000-0000-4000-8000-000000002009","participation_id":"8c023000-0000-4000-8000-000000002008","answers":[{"item_id":"8c023000-0000-4000-8000-000000002003","kind":"short_text","text_value":"Confirmed"},{"item_id":"8c023000-0000-4000-8000-000000002004","kind":"integer","integer_value":5},{"item_id":"8c023000-0000-4000-8000-000000002010","kind":"yes_no","yes_no_value":false}],"edit_secret":"c02-synthetic-edit-secret-abcdefghijklmnopqrstuvwxyz012345"}'::jsonb));
reset role;
select is((select status from public.form_responses where id=pg_temp.edit_id(2009)),'submitted','anonymous: valid submit fixture reaches submitted');
update public.form_responses set submitted_at=now()-interval '10 minutes' where id=pg_temp.edit_id(2009); -- make timestamp preservation observable within this transaction
insert into edit_results values('anonymous-before',pg_temp.edit_snapshot(pg_temp.edit_id(2009)));
set local role authenticated;
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000101","aal":"aal1","role":"authenticated"}',true);

select throws_ok($$select public.form_edit_response('8c023000-0000-4000-8000-000000002110',3,'{"response_id":"8c023000-0000-4000-8000-000000002009","participation_id":"8c023000-0000-4000-8000-000000002008","answers":[],"edit_secret":"c02-synthetic-edit-secret-abcdefghijklmnopqrstuvwxyz012345"}'::jsonb)$$,'23514','required visible form answers are missing','anonymous: omitted edit rejected');
reset role;
select is(pg_temp.edit_snapshot(pg_temp.edit_id(2009)),(select value from edit_results where key='anonymous-before'),'anonymous: omitted rolls back answers/version/revisions');
select is((select count(*) from app_private.form_command_receipts where request_id='8c023000-0000-4000-8000-000000002110'),0::bigint,'anonymous: omitted does not reserve idempotency receipt');
set local role authenticated;
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000101","aal":"aal1","role":"authenticated"}',true);

select throws_ok($$select public.form_edit_response('8c023000-0000-4000-8000-000000002111',3,'{"response_id":"8c023000-0000-4000-8000-000000002009","participation_id":"8c023000-0000-4000-8000-000000002008","answers":[{"item_id":"8c023000-0000-4000-8000-000000002003","kind":"short_text","text_value":"   "},{"item_id":"8c023000-0000-4000-8000-000000002004","kind":"integer","integer_value":5},{"item_id":"8c023000-0000-4000-8000-000000002010","kind":"yes_no","yes_no_value":false}],"edit_secret":"c02-synthetic-edit-secret-abcdefghijklmnopqrstuvwxyz012345"}'::jsonb)$$,'23514','required visible form answers are missing','anonymous: blank edit rejected');
reset role;
select is(pg_temp.edit_snapshot(pg_temp.edit_id(2009)),(select value from edit_results where key='anonymous-before'),'anonymous: blank rolls back answers/version/revisions');
select is((select count(*) from app_private.form_command_receipts where request_id='8c023000-0000-4000-8000-000000002111'),0::bigint,'anonymous: blank does not reserve idempotency receipt');
set local role authenticated;
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000101","aal":"aal1","role":"authenticated"}',true);

select throws_ok($$select public.form_edit_response('8c023000-0000-4000-8000-000000002112',3,'{"response_id":"8c023000-0000-4000-8000-000000002009","participation_id":"8c023000-0000-4000-8000-000000002008","answers":[{"item_id":"8c023000-0000-4000-8000-000000002003","kind":"short_text","text_value":"Confirmed"},{"item_id":"8c023000-0000-4000-8000-000000002004","kind":"integer","integer_value":11},{"item_id":"8c023000-0000-4000-8000-000000002010","kind":"yes_no","yes_no_value":false}],"edit_secret":"c02-synthetic-edit-secret-abcdefghijklmnopqrstuvwxyz012345"}'::jsonb)$$,'23514','numeric form answer is out of range','anonymous: out-of-range edit rejected');
reset role;
select is(pg_temp.edit_snapshot(pg_temp.edit_id(2009)),(select value from edit_results where key='anonymous-before'),'anonymous: out-of-range rolls back answers/version/revisions');
select is((select count(*) from app_private.form_command_receipts where request_id='8c023000-0000-4000-8000-000000002112'),0::bigint,'anonymous: out-of-range does not reserve idempotency receipt');
set local role authenticated;
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000101","aal":"aal1","role":"authenticated"}',true);

select throws_ok($$select public.form_edit_response('8c023000-0000-4000-8000-000000002113',3,'{"response_id":"8c023000-0000-4000-8000-000000002009","participation_id":"8c023000-0000-4000-8000-000000002008","answers":[{"item_id":"8c023000-0000-4000-8000-000000002003","kind":"short_text","text_value":"Confirmed"},{"item_id":"8c023000-0000-4000-8000-000000002004","kind":"integer","integer_value":null},{"item_id":"8c023000-0000-4000-8000-000000002010","kind":"yes_no","yes_no_value":false}],"edit_secret":"c02-synthetic-edit-secret-abcdefghijklmnopqrstuvwxyz012345"}'::jsonb)$$,'23514',null,'anonymous: null-number edit rejected');
reset role;
select is(pg_temp.edit_snapshot(pg_temp.edit_id(2009)),(select value from edit_results where key='anonymous-before'),'anonymous: null-number rolls back answers/version/revisions');
select is((select count(*) from app_private.form_command_receipts where request_id='8c023000-0000-4000-8000-000000002113'),0::bigint,'anonymous: null-number does not reserve idempotency receipt');
set local role authenticated;
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000101","aal":"aal1","role":"authenticated"}',true);

select throws_ok($$select public.form_edit_response('8c023000-0000-4000-8000-000000002114',3,'{"response_id":"8c023000-0000-4000-8000-000000002009","participation_id":"8c023000-0000-4000-8000-000000002008","answers":[{"item_id":"8c023000-0000-4000-8000-000000002003","kind":"short_text","text_value":"Confirmed"},{"item_id":"8c023000-0000-4000-8000-000000002004","kind":"integer","integer_value":5},{"item_id":"8c023000-0000-4000-8000-000000002010","kind":"yes_no","yes_no_value":true}],"edit_secret":"c02-synthetic-edit-secret-abcdefghijklmnopqrstuvwxyz012345"}'::jsonb)$$,'23514','required visible form answers are missing','anonymous: new-visible-dependent-omitted edit rejected');
reset role;
select is(pg_temp.edit_snapshot(pg_temp.edit_id(2009)),(select value from edit_results where key='anonymous-before'),'anonymous: new-visible-dependent-omitted rolls back answers/version/revisions');
select is((select count(*) from app_private.form_command_receipts where request_id='8c023000-0000-4000-8000-000000002114'),0::bigint,'anonymous: new-visible-dependent-omitted does not reserve idempotency receipt');
set local role authenticated;
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000101","aal":"aal1","role":"authenticated"}',true);

insert into edit_results values('anonymous-edited',public.form_edit_response('8c023000-0000-4000-8000-000000002110',3,'{"response_id":"8c023000-0000-4000-8000-000000002009","participation_id":"8c023000-0000-4000-8000-000000002008","answers":[{"item_id":"8c023000-0000-4000-8000-000000002003","kind":"short_text","text_value":"Revised"},{"item_id":"8c023000-0000-4000-8000-000000002004","kind":"integer","integer_value":7},{"item_id":"8c023000-0000-4000-8000-000000002010","kind":"yes_no","yes_no_value":false}],"edit_secret":"c02-synthetic-edit-secret-abcdefghijklmnopqrstuvwxyz012345"}'::jsonb));
select is(public.form_edit_response('8c023000-0000-4000-8000-000000002110',3,'{"response_id":"8c023000-0000-4000-8000-000000002009","participation_id":"8c023000-0000-4000-8000-000000002008","answers":[{"item_id":"8c023000-0000-4000-8000-000000002003","kind":"short_text","text_value":"Revised"},{"item_id":"8c023000-0000-4000-8000-000000002004","kind":"integer","integer_value":7},{"item_id":"8c023000-0000-4000-8000-000000002010","kind":"yes_no","yes_no_value":false}],"edit_secret":"c02-synthetic-edit-secret-abcdefghijklmnopqrstuvwxyz012345"}'::jsonb),(select value from edit_results where key='anonymous-edited'),'anonymous: exact edit retry returns original receipt');
reset role;
select ok((select status='submitted' and management_version=4 from public.form_responses where id=pg_temp.edit_id(2009)),'anonymous: successful edit remains submitted at one new version');
select is((select text_value from public.form_answers where response_id=pg_temp.edit_id(2009) and item_id=pg_temp.edit_id(2003)),'Revised','anonymous: revised answer persisted');
select is((select count(*) from public.form_response_revisions where response_id=pg_temp.edit_id(2009) and action='edited'),1::bigint,'anonymous: retry adds no revision');
select ok((select submitted_at=(select (value->'response'->>'submitted_at')::timestamptz from edit_results where key='anonymous-before') from public.form_responses where id=pg_temp.edit_id(2009)),'anonymous: original submission timestamp preserved');
select ok(not exists(select 1 from public.form_response_revisions where response_id=pg_temp.edit_id(2009) and changed_by_person_id is not null),'anonymous revisions remain unlinked to actor');
select is((select count(*) from app_private.form_command_receipts where request_id='8c023000-0000-4000-8000-000000002110'),0::bigint,'anonymous edit creates no actor-linked command receipt');
select ok(not has_function_privilege('authenticated','app_private.form_mutate_response(text,uuid,bigint,jsonb,boolean)','execute'),'private mutation cannot be called directly');
insert into edit_results values('identified-final',pg_temp.edit_snapshot(pg_temp.edit_id(1009))),
  ('anonymous-final',pg_temp.edit_snapshot(pg_temp.edit_id(2009)));
set local role authenticated;
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000102',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000102","aal":"aal1","role":"authenticated"}',true);
select throws_ok($$select public.form_edit_response(
  '8c023000-0000-4000-8000-000000009001',4,
  '{"response_id":"8c023000-0000-4000-8000-000000001009","participation_id":"8c023000-0000-4000-8000-000000001008","answers":[]}'
)$$,'P0002','form response unavailable','another actor cannot edit identified response');
select set_config('request.jwt.claim.sub','8c023000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"sub":"8c023000-0000-4000-8000-000000000101","aal":"aal1","role":"authenticated"}',true);
select throws_ok($$select public.form_edit_response(
  '8c023000-0000-4000-8000-000000009002',3,
  '{"response_id":"8c023000-0000-4000-8000-000000001009","participation_id":"8c023000-0000-4000-8000-000000001008","answers":[]}'
)$$,'40001','expected_version mismatch','stale edit version is rejected before replacing answers');
select throws_ok($$select public.form_edit_response(
  '8c023000-0000-4000-8000-000000009003',4,
  '{"response_id":"8c023000-0000-4000-8000-000000002009","participation_id":"8c023000-0000-4000-8000-000000002008","edit_secret":"incorrect-synthetic-secret","answers":[]}'
)$$,'P0002','form response unavailable','anonymous edit still requires the original edit secret');
select throws_ok($$select public.form_edit_response(
  '8c023000-0000-4000-8000-000000009004',4,
  '{"response_id":"8c023000-0000-4000-8000-000000001009","participation_id":"8c023000-0000-4000-8000-000000002008","answers":[]}'
)$$,'P0002','form participation unavailable','participation from another occurrence cannot authorize edit');
reset role;
update public.form_occurrences set closes_at=now()-interval '1 second' where id=pg_temp.edit_id(1007);
set local role authenticated;
select throws_ok($$select public.form_edit_response(
  '8c023000-0000-4000-8000-000000009005',4,
  '{"response_id":"8c023000-0000-4000-8000-000000001009","participation_id":"8c023000-0000-4000-8000-000000001008","answers":[]}'
)$$,'P0002','form occurrence unavailable','closed response window still rejects edits');
reset role;
select is(pg_temp.edit_snapshot(pg_temp.edit_id(1009)),(select value from edit_results where key='identified-final'),'all identified authorization failures preserve confirmed content and revisions');
select is(pg_temp.edit_snapshot(pg_temp.edit_id(2009)),(select value from edit_results where key='anonymous-final'),'anonymous secret failure preserves confirmed content and revisions');
select is((select count(*) from app_private.form_command_receipts where request_id between pg_temp.edit_id(9001) and pg_temp.edit_id(9005)),0::bigint,'authorization and concurrency failures leave no receipts');
select * from finish();
rollback;
