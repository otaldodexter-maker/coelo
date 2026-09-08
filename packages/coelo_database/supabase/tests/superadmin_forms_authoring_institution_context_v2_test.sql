-- F-AUTHOR02: independent rollback-only fixture. Eng1 alone executes SQL.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
select has_function('public','superadmin_forms_authoring_institutions_v2',array['jsonb'],'nominal authoring institution reader exists');
select ok(has_function_privilege('authenticated','public.superadmin_forms_authoring_institutions_v2(jsonb)','execute'),'authenticated can invoke public reader');
select ok(not has_function_privilege('anon','public.superadmin_forms_authoring_institutions_v2(jsonb)','execute'),'anon cannot invoke reader');
select ok(not has_function_privilege('service_role','public.superadmin_forms_authoring_institutions_v2(jsonb)','execute'),'service role is not a client');
select ok(not has_function_privilege('authenticated','app_private.superadmin_forms_authoring_institutions_v2(jsonb)','execute'),'private reader has no client grant');

insert into public.institution_types(id,code,name,status) values
 ('8f032000-0000-4000-8000-000000000001','fauthor02-type','F-AUTHOR02 type','active');
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 ('8f032000-0000-4000-8000-000000000010','8f032000-0000-4000-8000-000000000001','F-AUTHOR02 A','fauthor02-a','active'),
 ('8f032000-0000-4000-8000-000000000020','8f032000-0000-4000-8000-000000000001','F-AUTHOR02 B','fauthor02-b','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select ('8f032000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'authenticated','authenticated','fauthor02-'||n||'@invalid.test',now(),now(),now(),'{}','{}'
from generate_series(101,105) n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
select ('8f032000-0000-4000-8000-'||lpad((n+100)::text,12,'0'))::uuid,
 ('8f032000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 now(),now(),'aal2',now()+interval '1 hour' from generate_series(101,105) n;
insert into app_private.superadmin_internal_identities(id)
select ('8f032000-0000-4000-8000-'||lpad((n+200)::text,12,'0'))::uuid from unnest(array[101,102,104,105]) n;
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
select ('8f032000-0000-4000-8000-'||lpad((n+300)::text,12,'0'))::uuid,
 ('8f032000-0000-4000-8000-'||lpad((n+200)::text,12,'0'))::uuid,
 ('8f032000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid from unnest(array[101,102,104,105]) n;
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,r.id,fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 ('8f032000-0000-4000-8000-000000000501'::uuid,'8f032000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('8f032000-0000-4000-8000-000000000502'::uuid,'8f032000-0000-4000-8000-000000000302'::uuid,'operations','institution','8f032000-0000-4000-8000-000000000010'::uuid),
 ('8f032000-0000-4000-8000-000000000504'::uuid,'8f032000-0000-4000-8000-000000000304'::uuid,'content','platform',null::uuid),
 ('8f032000-0000-4000-8000-000000000505'::uuid,'8f032000-0000-4000-8000-000000000305'::uuid,'owner','platform',null::uuid)
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles r on r.code=fixture.role_code;
-- 102 is manage-only, 104 read-only; 105 is the second real internal Owner so
-- revocation tests preserve last-owner protection instead of disabling it.
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,case
 when r.code='operations' and p.code='forms.read' then 'deny'::public.permission_effect
 when r.code='content' and p.code='forms.manage' then 'deny'::public.permission_effect
 else 'allow'::public.permission_effect end,'active'
from public.platform_roles r cross join public.platform_permissions p
where r.code in('owner','operations','content') and p.code in('forms.read','forms.manage')
on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null;

-- Own searchable 21-row population; unrelated baseline institutions do not enter
-- these assertions. Scope checks below use the institution-scoped actor directly.
insert into public.institutions(id,institution_type_id,public_name,slug,status)
select ('8f032000-0000-4000-8000-'||lpad((1000+n)::text,12,'0'))::uuid,
 '8f032000-0000-4000-8000-000000000001',
 'F-AUTHOR02 Page '||lpad(n::text,2,'0'),'fauthor02-page-'||n,'active'
from generate_series(1,21) n;
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 ('8f032000-0000-4000-8000-000000001101','8f032000-0000-4000-8000-000000000001','F-AUTHOR02 % literal','fauthor02-percent','active'),
 ('8f032000-0000-4000-8000-000000001102','8f032000-0000-4000-8000-000000000001','F-AUTHOR02 _ literal','fauthor02-underscore','active'),
 ('8f032000-0000-4000-8000-000000001103','8f032000-0000-4000-8000-000000000001',E'F-AUTHOR02 \\ literal','fauthor02-backslash','active');
-- Minimal capability test explicitly denies unrelated catalog permission.
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'deny','active' from public.platform_roles r cross join public.platform_permissions p
where r.code='operations' and p.code='platform.read'
on conflict(role_id,permission_id) do update set effect='deny',status='active',revoked_at=null;

create temporary table fauthor02_results(label text primary key,body jsonb,executed_as text);
create temporary table fauthor02_audit_capture(correlation_id uuid primary key,operation_label text);
create function pg_temp.fauthor02_capture_audit() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.action_code in ('superadmin.forms.editor','superadmin.forms.draft.save','superadmin.forms.authoring.institutions') and new.outcome='success' then
  insert into pg_temp.fauthor02_audit_capture values (new.correlation_id,null);
 end if;
 return new;
end$$;
create function pg_temp.fauthor02_bind_success() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.body->>'ok'='true' then
  update pg_temp.fauthor02_audit_capture set operation_label=new.label where operation_label is null;
 end if;
 return new;
end$$;
revoke all on function pg_temp.fauthor02_capture_audit() from public,anon,authenticated,service_role;
revoke all on function pg_temp.fauthor02_bind_success() from public,anon,authenticated,service_role;
create trigger fauthor02_capture_success after insert on audit.audit_logs for each row execute function pg_temp.fauthor02_capture_audit();
create trigger fauthor02_bind_success before insert on fauthor02_results for each row execute function pg_temp.fauthor02_bind_success();
grant select,insert on fauthor02_results to authenticated;
create temporary table fauthor02_invalid(label text primary key,query jsonb);
insert into fauthor02_invalid values
 ('null',null),('array','[]'),('unknown','{"scope_institution_id":"forged"}'),
 ('null_search','{"search":null}'),('number_search','{"search":1}'),
 ('long_search',jsonb_build_object('search',repeat('x',161))),
 ('zero_limit','{"limit":0}'),('large_limit','{"limit":51}'),('fractional_limit','{"limit":1.5}'),
 ('null_limit','{"limit":null}'),('string_limit','{"limit":"20"}'),
 ('cursor_array','{"cursor":[]}'),('cursor_partial','{"cursor":{"id":"8f032000-0000-4000-8000-000000000010"}}'),
 ('cursor_uuid','{"cursor":{"name_key":"a","id":"bad"}}'),
 ('cursor_null_name','{"cursor":{"name_key":null,"id":"8f032000-0000-4000-8000-000000000010"}}'),
 ('cursor_extra','{"cursor":{"name_key":"a","id":"8f032000-0000-4000-8000-000000000010","scope":"forged"}}'),
 ('cursor_long',jsonb_build_object('cursor',jsonb_build_object('name_key',repeat('x',1025),'id','8f032000-0000-4000-8000-000000000010'))),
 ('bytes',jsonb_build_object('padding',repeat('x',8193)));
grant select on fauthor02_invalid to authenticated;

select set_config('request.jwt.claims','{"sub":"8f032000-0000-4000-8000-000000000101","session_id":"8f032000-0000-4000-8000-000000000201","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
insert into fauthor02_results values ('page1',public.superadmin_forms_authoring_institutions_v2('{"search":"F-AUTHOR02 Page"}'),current_user);
insert into fauthor02_results
select 'page2',public.superadmin_forms_authoring_institutions_v2(jsonb_build_object('search','F-AUTHOR02 Page','cursor',body#>'{data,next_cursor}')),current_user
from fauthor02_results where label='page1';
insert into fauthor02_results values ('empty',public.superadmin_forms_authoring_institutions_v2('{"search":"F-AUTHOR02 absent"}'),current_user);
insert into fauthor02_results values ('percent',public.superadmin_forms_authoring_institutions_v2('{"search":"F-AUTHOR02 %"}'),current_user);
insert into fauthor02_results values ('underscore',public.superadmin_forms_authoring_institutions_v2('{"search":"F-AUTHOR02 _"}'),current_user);
insert into fauthor02_results values ('backslash',public.superadmin_forms_authoring_institutions_v2(jsonb_build_object('search',E'F-AUTHOR02 \\')),current_user);
insert into fauthor02_results select 'invalid_'||label,public.superadmin_forms_authoring_institutions_v2(query),current_user from fauthor02_invalid;
insert into fauthor02_results values ('created',public.superadmin_forms_save_draft_v2(
 '8f032000-0000-4000-8000-000000002001',0,
 '{"id":"8f032000-0000-4000-8000-000000002101","institution_id":"8f032000-0000-4000-8000-000000000010","kind":"form","identity_mode":"identified","response_unit":"person","title":"Author02 draft","sections":[]}'),current_user);
reset role;
select is((select jsonb_array_length(body#>'{data,items}') from fauthor02_results where label='page1'),20,'page one has 20 candidates');
select is((select body#>>'{data,has_more}' from fauthor02_results where label='page1'),'true','page one signals more');
select is((select body#>>'{data,next_cursor,id}' from fauthor02_results where label='page1'),
 '8f032000-0000-4000-8000-000000001020','cursor identifies last returned item, not lookahead');
select is((select body#>>'{data,next_cursor,name_key}' from fauthor02_results where label='page1'),
 'f-author02 page 20','cursor carries the exact ordered name key');
select is((select jsonb_array_length(body#>'{data,items}') from fauthor02_results where label='page2'),1,'second page preserves candidate 21');
select is((select body#>>'{data,items,0,id}' from fauthor02_results where label='page2'),
 '8f032000-0000-4000-8000-000000001021','second page contains the remaining ID');
select is((select body#>'{data,next_cursor}' from fauthor02_results where label='page2'),'null'::jsonb,'last page has explicit null cursor');
select is((select body#>>'{data,has_more}' from fauthor02_results where label='page2'),'false','last page has no more');
select is((select body#>'{data,items}' from fauthor02_results where label='empty'),'[]'::jsonb,'empty search result remains authorized');
select is(jsonb_array_length(body#>'{data,items}'),1,label||' search is literal') from fauthor02_results where label in('percent','underscore','backslash');
select is(body#>>'{error,code}','SAI_INVALID_ARGUMENT',label||' rejected') from fauthor02_results where label like 'invalid_%';

select set_config('request.jwt.claims','{"sub":"8f032000-0000-4000-8000-000000000102","session_id":"8f032000-0000-4000-8000-000000000202","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into fauthor02_results values ('scoped',public.superadmin_forms_authoring_institutions_v2('{}'),current_user);
insert into fauthor02_results values ('foreign_cursor',public.superadmin_forms_authoring_institutions_v2('{"cursor":{"name_key":"","id":"8f032000-0000-4000-8000-000000000020"}}'),current_user);
insert into fauthor02_results values ('manage_editor',public.superadmin_forms_editor_v2('8f032000-0000-4000-8000-000000002101'),current_user);
reset role;
select is((select jsonb_array_length(body#>'{data,items}') from fauthor02_results where label='scoped'),1,'manage-only actor sees only own institution with empty search');
select is((select body#>>'{data,items,0,id}' from fauthor02_results where label='scoped'),'8f032000-0000-4000-8000-000000000010','scope comes from identity, not query');
select is((select body#>'{data,items}' from fauthor02_results where label='foreign_cursor'),(select body#>'{data,items}' from fauthor02_results where label='scoped'),'foreign cursor does not expand scope');
select is((select body#>'{data,capabilities}' from fauthor02_results where label='manage_editor'),'{"manage":true}'::jsonb,'manage-only editor reports only effective manage');
select is((select body#>'{data,institution}' from fauthor02_results where label='manage_editor'),'{"id":"8f032000-0000-4000-8000-000000000010","public_name":"F-AUTHOR02 A"}'::jsonb,'editor institution is linked to the locked form');

update public.institutions set status='inactive' where id='8f032000-0000-4000-8000-000000000010';
set local role authenticated;
insert into fauthor02_results values ('inactive_catalog',public.superadmin_forms_authoring_institutions_v2('{}'),current_user);
insert into fauthor02_results values ('inactive_editor',public.superadmin_forms_editor_v2('8f032000-0000-4000-8000-000000002101'),current_user);
reset role;
select is((select body#>'{data,items}' from fauthor02_results where label='inactive_catalog'),'[]'::jsonb,'inactive institution cannot be a creation candidate');
select is((select body->>'ok' from fauthor02_results where label='inactive_editor'),'true','existing editor does not invent an active-only read rule');
update public.institutions set status='active' where id='8f032000-0000-4000-8000-000000000010';

select set_config('request.jwt.claims','{"sub":"8f032000-0000-4000-8000-000000000104","session_id":"8f032000-0000-4000-8000-000000000204","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into fauthor02_results values ('readonly_catalog',public.superadmin_forms_authoring_institutions_v2('{}'),current_user);
insert into fauthor02_results values ('readonly_editor',public.superadmin_forms_editor_v2('8f032000-0000-4000-8000-000000002101'),current_user);
reset role;
select is((select body#>>'{error,code}' from fauthor02_results where label='readonly_catalog'),'SAI_PERMISSION_DENIED','read-only cannot list creation candidates');
select is((select body#>'{data,capabilities}' from fauthor02_results where label='readonly_editor'),'{"manage":false}'::jsonb,'read-only editor needs no catalog and reports effective manage false');
select is((select body#>'{data,definition}' from fauthor02_results where label='readonly_editor'),(select body->'data' from fauthor02_results where label='created'),'context extension does not change saved definition projection');

update public.institutions set deleted_at=now() where id='8f032000-0000-4000-8000-000000000010';
set local role authenticated;
insert into fauthor02_results values ('deleted_editor',public.superadmin_forms_editor_v2('8f032000-0000-4000-8000-000000002101'),current_user);
reset role;
select is((select body#>>'{error,code}' from fauthor02_results where label='deleted_editor'),'SAI_PERMISSION_DENIED','deleted institution editor remains denied');

select set_config('request.jwt.claims','{"sub":"8f032000-0000-4000-8000-000000000101","session_id":"8f032000-0000-4000-8000-000000000201","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
insert into fauthor02_results values ('deleted_catalog',public.superadmin_forms_authoring_institutions_v2('{"search":"F-AUTHOR02 A"}'),current_user);
reset role;
select is((select body#>'{data,items}' from fauthor02_results where label='deleted_catalog'),'[]'::jsonb,'deleted institution is not a creation candidate');
update public.institutions set deleted_at=null where id='8f032000-0000-4000-8000-000000000010';

-- Equal normalized names must use the UUID tie-breaker, with no skip/duplicate.
insert into public.institutions(id,institution_type_id,public_name,slug,status) values
 ('8f032000-0000-4000-8000-000000001201','8f032000-0000-4000-8000-000000000001','F-AUTHOR02 Tie','fauthor02-tie-a','active'),
 ('8f032000-0000-4000-8000-000000001202','8f032000-0000-4000-8000-000000000001','f-author02 tie','fauthor02-tie-b','active');
set local role authenticated;
insert into fauthor02_results values ('tie1',public.superadmin_forms_authoring_institutions_v2('{"search":"F-AUTHOR02 Tie","limit":1}'),current_user);
insert into fauthor02_results select 'tie2',public.superadmin_forms_authoring_institutions_v2(
 jsonb_build_object('search','F-AUTHOR02 Tie','limit',1,'cursor',body#>'{data,next_cursor}')),current_user
from fauthor02_results where label='tie1';
reset role;
select is((select body#>>'{data,items,0,id}' from fauthor02_results where label='tie1'),'8f032000-0000-4000-8000-000000001201','normalized name tie starts at lower UUID');
select is((select body#>>'{data,items,0,id}' from fauthor02_results where label='tie2'),'8f032000-0000-4000-8000-000000001202','tie second page seeks by UUID');

-- The shared Auth helper uses transaction time; nominal readers must also
-- reject a session that expired according to the actual clock during this txn.
update auth.sessions set not_after=now()+(clock_timestamp()-now())/2
where id='8f032000-0000-4000-8000-000000000201';
select ok((select not_after>now() and not_after<clock_timestamp() from auth.sessions where id='8f032000-0000-4000-8000-000000000201'),'session fixture is valid at transaction start but expired now');
set local role authenticated;
insert into fauthor02_results values ('expired_catalog',public.superadmin_forms_authoring_institutions_v2('{}'),current_user);
insert into fauthor02_results values ('expired_editor',public.superadmin_forms_editor_v2('8f032000-0000-4000-8000-000000002101'),current_user);
reset role;
select is(body#>>'{error,code}','SAI_SESSION_INVALID',label||' checks real clock') from fauthor02_results where label in ('expired_catalog','expired_editor');
update auth.sessions set not_after=null where id='8f032000-0000-4000-8000-000000000201';
set local role authenticated;
insert into fauthor02_results values ('no_expiry_catalog',public.superadmin_forms_authoring_institutions_v2('{"search":"F-AUTHOR02 absent"}'),current_user);
reset role;
select is((select body->>'ok' from fauthor02_results where label='no_expiry_catalog'),'true','NULL not_after is still valid');

select set_config('request.jwt.claims','{"sub":"8f032000-0000-4000-8000-000000000102","session_id":"8f032000-0000-4000-8000-000000000202","aal":"aal2","role":"authenticated"}',true);
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now() where id='8f032000-0000-4000-8000-000000000502';
set local role authenticated;
insert into fauthor02_results values ('revoked_cursor',public.superadmin_forms_authoring_institutions_v2('{"cursor":{"name_key":"","id":"8f032000-0000-4000-8000-000000000020"}}'),current_user);
reset role;
select is((select body#>>'{error,code}' from fauthor02_results where label='revoked_cursor'),'SAI_MEMBERSHIP_REVOKED','cursor never preserves a revoked capability');
update app_private.superadmin_internal_memberships set status='active',revoked_at=null where id='8f032000-0000-4000-8000-000000000502';

select is((select count(*) from fauthor02_audit_capture c where c.operation_label=r.label),1::bigint,'one correlated success audit for '||r.label)
from fauthor02_results r where r.body->>'ok'='true';
select ok(not exists(select 1 from fauthor02_audit_capture where operation_label is null),'no unbound successful audit');
select is((select count(*) from audit.audit_logs a where a.correlation_id=(r.body#>>'{error,correlation_id}')::uuid
 and a.outcome='denied' and a.reason_code=r.body#>>'{error,code}'),1::bigint,'one correlated denial audit for '||r.label)
from fauthor02_results r where r.body->>'ok'='false';
select ok(not exists(select 1 from audit.audit_logs a where a.action_code in('superadmin.forms.editor','superadmin.forms.authoring.institutions')
 and (a.before_json is not null or a.after_json is not null or a.actor_person_id is not null
 or to_jsonb(a)::text like '%F-AUTHOR02%' or to_jsonb(a)::text like '%Author02 draft%' or to_jsonb(a)::text like '%name_key%')),
 'audit excludes names, search, cursors, definition graph and legacy People');
select ok((select bool_and(app_private.audit_verify_entry(id)) from audit.audit_logs where action_code in('superadmin.forms.editor','superadmin.forms.authoring.institutions')),'audit digests verify');

create temporary table fauthor02_faults(label text,sqlstate text,message text,executed_as text);
grant insert on fauthor02_faults to authenticated;
create function pg_temp.fauthor02_reject_audit() returns trigger language plpgsql as $$begin
 if new.action_code in('superadmin.forms.editor','superadmin.forms.authoring.institutions') then
  raise exception using errcode='P0001',message='forced FAUTHOR02 audit failure';
 end if;
 return new;
end$$;
create trigger fauthor02_forced_audit_failure before insert on audit.audit_logs for each row execute function pg_temp.fauthor02_reject_audit();
set local role authenticated;
do $$declare label text; fault text; msg text; begin
 foreach label in array array['catalog','denial','editor'] loop
  begin
   if label='catalog' then perform public.superadmin_forms_authoring_institutions_v2('{}');
   elsif label='denial' then perform public.superadmin_forms_authoring_institutions_v2('{"limit":0}');
   else perform public.superadmin_forms_editor_v2('8f032000-0000-4000-8000-000000002101'); end if;
   insert into fauthor02_faults values(label,'NO_EXCEPTION',null,current_user);
  exception when others then
   get stacked diagnostics fault=returned_sqlstate,msg=message_text;
   insert into fauthor02_faults values(label,fault,msg,current_user);
  end;
 end loop;
end$$;
reset role;
drop trigger fauthor02_forced_audit_failure on audit.audit_logs;
drop trigger fauthor02_capture_success on audit.audit_logs;
select is(sqlstate,'P0001',label||' audit failure escapes envelope') from fauthor02_faults;
select is(message,'forced FAUTHOR02 audit failure',label||' preserves audit fault') from fauthor02_faults;
select ok(not exists(select 1 from fauthor02_faults where executed_as<>'authenticated'),'fault calls also execute as authenticated');

select ok(not exists(select 1 from fauthor02_results where executed_as<>'authenticated'),'all RPCs execute as authenticated');
select ok(not exists(
 select 1 from fauthor02_results r cross join lateral jsonb_array_elements(r.body#>'{data,items}') item
 where (select array_agg(k order by k) from jsonb_object_keys(item) k)<>array['id','public_name']
),'candidate projections expose only id and public_name');
select * from finish();
rollback;
