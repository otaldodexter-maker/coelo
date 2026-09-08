-- AG-READ01 candidate fixture. NOT executed or approved for replay yet.
-- Synthetic roles and grants exist only in this transaction. Eng1 owns replay.
-- No domain wrapper/helper replacement, trigger bypass, or product-role grant.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.ag_id(n integer) returns uuid language sql immutable as $$
 select ('8a500000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid
$$;

insert into public.platform_roles(id,code,name,status,is_system,max_scope_kind) values
 (pg_temp.ag_id(901),'ag-read01-reader','AG READ01 synthetic reader','active',false,'platform'),
 (pg_temp.ag_id(902),'ag-read01-denied','AG READ01 synthetic denied','active',false,'platform');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,
 case when role_record.id=pg_temp.ag_id(902) then 'deny'::public.permission_effect
 else 'allow'::public.permission_effect end,'active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.id in (pg_temp.ag_id(901),pg_temp.ag_id(902))
 and permission_record.code='agenda.read';

insert into public.institution_types(id,code,name,status) values
 (pg_temp.ag_id(1),'ag-read01-type','AG READ01 type','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 (pg_temp.ag_id(10),'AG Tenant A','ag-read01-a','active',pg_temp.ag_id(1)),
 (pg_temp.ag_id(20),'AG Tenant B','ag-read01-b','active',pg_temp.ag_id(1));
insert into public.units(id,institution_id,institution_type_id,name,slug,status) values
 (pg_temp.ag_id(11),pg_temp.ag_id(10),pg_temp.ag_id(1),'A Norte','ag-read01-a-norte','active'),
 (pg_temp.ag_id(12),pg_temp.ag_id(10),pg_temp.ag_id(1),'A Sul','ag-read01-a-sul','active'),
 (pg_temp.ag_id(18),pg_temp.ag_id(10),pg_temp.ag_id(1),'A Arquivada','ag-read01-a-archived','archived'),
 (pg_temp.ag_id(21),pg_temp.ag_id(20),pg_temp.ag_id(1),'B Norte','ag-read01-b-norte','active');
insert into public.groups(id,institution_id,unit_id,name,status) values
 (pg_temp.ag_id(13),pg_temp.ag_id(10),pg_temp.ag_id(11),'Turma A Norte','active'),
 (pg_temp.ag_id(14),pg_temp.ag_id(10),pg_temp.ag_id(12),'Turma A Sul','active'),
 (pg_temp.ag_id(19),pg_temp.ag_id(10),pg_temp.ag_id(18),'Turma unidade arquivada','active'),
 (pg_temp.ag_id(22),pg_temp.ag_id(20),pg_temp.ag_id(21),'Turma B','active');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select pg_temp.ag_id(100+n),'authenticated','authenticated','ag-read01-'||n||'@invalid.test',
 now(),now(),now(),'{}','{}' from generate_series(1,6) n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
select pg_temp.ag_id(200+n),pg_temp.ag_id(100+n),now(),now(),
 case when n=3 then 'aal1'::auth.aal_level else 'aal2'::auth.aal_level end,
 now()+interval '1 hour' from generate_series(1,6) n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 (pg_temp.ag_id(209),pg_temp.ag_id(101),now(),now(),'aal2',now()-interval '1 minute');
insert into app_private.superadmin_internal_identities(id)
select pg_temp.ag_id(300+n) from generate_series(1,6) n where n<>5;
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
select pg_temp.ag_id(400+n),pg_temp.ag_id(300+n),pg_temp.ag_id(100+n)
from generate_series(1,6) n where n<>5;
insert into app_private.superadmin_internal_memberships
 (id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select pg_temp.ag_id(500+n),pg_temp.ag_id(300+n),pg_temp.ag_id(case when n=6 then 902 else 901 end),
 (case when n in (2,4) then 'institution' else 'platform' end)::app_private.superadmin_internal_scope_kind,
 case when n in (2,4) then pg_temp.ag_id(10) else null end
from generate_series(1,6) n where n<>5;
update app_private.superadmin_internal_memberships
 set status='revoked',revoked_at=now(),version=2 where id=pg_temp.ag_id(504);

-- Historical authors are synthetic People, DISTINCT from all internal actors.
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.ag_id(601),'adult','AG','Author','AG historical author','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 (pg_temp.ag_id(601),pg_temp.ag_id(105),'active');

-- Seed existing activity context using its genuine historical People author.
-- Auth105 is not an internal reader. No Activities capability or marker is added.
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.ag_id(105),
 'session_id',pg_temp.ag_id(205),'aal','aal2','role','authenticated')::text,true);
insert into public.activity_definitions
 (id,institution_id,name,origin_scope_kind,origin_unit_id,created_by_person_id,status,handle_stem)
values
 (pg_temp.ag_id(31),pg_temp.ag_id(10),'Atividade A Sul','unit',pg_temp.ag_id(12),pg_temp.ag_id(601),'active','ag-read01-a'),
 (pg_temp.ag_id(32),pg_temp.ag_id(20),'Atividade B','unit',pg_temp.ag_id(21),pg_temp.ag_id(601),'active','ag-read01-b'),
 (pg_temp.ag_id(38),pg_temp.ag_id(10),'Atividade origem arquivada','unit',pg_temp.ag_id(18),pg_temp.ag_id(601),'active','ag-read01-archived-origin');
insert into public.activity_unit_links(id,activity_id,institution_id,unit_id,linked_by_person_id,status)
values
 (pg_temp.ag_id(41),pg_temp.ag_id(31),pg_temp.ag_id(10),pg_temp.ag_id(12),pg_temp.ag_id(601),'active'),
 (pg_temp.ag_id(42),pg_temp.ag_id(32),pg_temp.ag_id(20),pg_temp.ag_id(21),pg_temp.ag_id(601),'active'),
 (pg_temp.ag_id(48),pg_temp.ag_id(38),pg_temp.ag_id(10),pg_temp.ag_id(18),pg_temp.ag_id(601),'active');
set constraints all immediate;
select set_config('request.jwt.claims','{}',true);

insert into public.agenda_events
 (id,institution_id,context_kind,context_id,title,item_type,status,starts_at,ends_at,
 location,description,recurrence,audience,reminders,questions,created_by_person_id,updated_by_person_id)
values
 (pg_temp.ag_id(701),pg_temp.ag_id(10),'unit',pg_temp.ag_id(11),E'Reunião literal %_\\','event','published',
 '2026-09-08 12:00Z','2026-09-08 13:00Z','Sala A','Descrição A',
 '{"frequency":"weekly","interval":1,"occurrenceCount":3,"exceptions":[],"sentinel":"RECURRENCE_PRIVATE"}',
 jsonb_build_object('institutionId',pg_temp.ag_id(20),'unitIds',jsonb_build_array(pg_temp.ag_id(11),pg_temp.ag_id(21)),
   'groupIds',jsonb_build_array(pg_temp.ag_id(13),pg_temp.ag_id(22)),'activityIds',jsonb_build_array(pg_temp.ag_id(31),pg_temp.ag_id(32)),
   'personIds',jsonb_build_array(pg_temp.ag_id(601)),'labels',jsonb_build_array('PERSON_LABEL_PRIVATE'),
   'sentinel','AUDIENCE_PRIVATE'),
 '["oneDayBefore"]','[{"id":"q1","title":"Confirmar?","type":"yesNo","sentinel":"QUESTION_PRIVATE"}]',
 pg_temp.ag_id(601),pg_temp.ag_id(601)),
 (pg_temp.ag_id(702),pg_temp.ag_id(10),'unit',pg_temp.ag_id(12),'Outro evento A','event','draft',
 '2026-09-08 12:00Z','2026-09-08 13:00Z','','',null,
 jsonb_build_object('institutionId',pg_temp.ag_id(10),'unitIds',jsonb_build_array(pg_temp.ag_id(12)),
   'groupIds',jsonb_build_array(pg_temp.ag_id(14)),'activityIds','[]'::jsonb,'personIds','[]'::jsonb,'labels','[]'::jsonb),
 '[]','[]',pg_temp.ag_id(601),pg_temp.ag_id(601)),
 (pg_temp.ag_id(703),pg_temp.ag_id(20),'unit',pg_temp.ag_id(21),'EVENT_B_PRIVATE','event','published',
 '2026-09-08 12:00Z','2026-09-08 13:00Z','','',null,
 jsonb_build_object('institutionId',pg_temp.ag_id(20),'unitIds',jsonb_build_array(pg_temp.ag_id(21))),
 '[]','[]',pg_temp.ag_id(601),pg_temp.ag_id(601)),
 (pg_temp.ag_id(704),pg_temp.ag_id(10),'unit',pg_temp.ag_id(21),'CROSS_CONTEXT_PRIVATE','event','published',
 '2026-09-08 12:00Z','2026-09-08 13:00Z','','',null,'{}','[]','[]',pg_temp.ag_id(601),pg_temp.ag_id(601));
insert into public.agenda_history_receipts
 (id,request_id,event_id,institution_id,actor_person_id,action,previous_revision,next_revision,reason,occurred_at)
values
 (pg_temp.ag_id(801),pg_temp.ag_id(811),pg_temp.ag_id(701),pg_temp.ag_id(10),pg_temp.ag_id(601),
 'restore',1,2,'Retomada autorizada','2026-09-07 12:00Z'),
 (pg_temp.ag_id(802),pg_temp.ag_id(812),pg_temp.ag_id(701),pg_temp.ag_id(20),pg_temp.ag_id(601),
 'cancel',2,3,'HISTORY_B_PRIVATE','2026-09-07 13:00Z');
insert into public.agenda_responses(event_id,institution_id,responder_person_id,response_value,answers)
values(pg_temp.ag_id(701),pg_temp.ag_id(20),pg_temp.ag_id(601),'yes','{"sentinel":"RESPONSE_PRIVATE"}');
create temporary table ag_read01_storage_before as
select 'events'::text label,md5(jsonb_agg(to_jsonb(e) order by e.id)::text) digest
from public.agenda_events e where e.id between pg_temp.ag_id(701) and pg_temp.ag_id(704)
union all
select 'history',md5(jsonb_agg(to_jsonb(h) order by h.id)::text)
from public.agenda_history_receipts h where h.id in (pg_temp.ag_id(801),pg_temp.ag_id(802));

-- Captures real invoker results/errors, including undefined-function RED.
-- This helper neither implements the missing RPC nor elevates privileges.
create temporary table ag_read01_results(label text primary key,body jsonb,sqlstate text,message text,sql_role text);
grant select,insert on table ag_read01_results to authenticated;
create function pg_temp.ag_capture(p_label text,p_query text) returns void
language plpgsql security invoker as $$
declare response jsonb;
begin
 begin
  execute p_query into response;
  insert into ag_read01_results values(p_label,response,null,null,current_user);
 exception when others then
  insert into ag_read01_results values(p_label,null,sqlstate,sqlerrm,current_user);
 end;
end $$;
create function pg_temp.ag_claims(n integer,session_number integer default null,aal_value text default 'aal2')
returns void language plpgsql security invoker as $$
begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.ag_id(100+n),
 'session_id',pg_temp.ag_id(coalesce(session_number,200+n)),'aal',aal_value,'role','authenticated')::text,true);
end
$$;
revoke all on function pg_temp.ag_id(integer),pg_temp.ag_capture(text,text),pg_temp.ag_claims(integer,integer,text) from public;
grant execute on function pg_temp.ag_id(integer),pg_temp.ag_capture(text,text),pg_temp.ag_claims(integer,integer,text) to authenticated;

select has_function('public','superadmin_agenda_list_v2',array['timestamp with time zone','timestamp with time zone','uuid','text','integer','integer'],'AG list v2 exists');
select has_function('public','superadmin_agenda_get_v2',array['uuid'],'AG get v2 exists');
select has_function('public','superadmin_agenda_contexts_v2',array[]::text[],'AG contexts v2 exists');
select is((select count(*)::integer from public.platform_role_permissions rp join public.platform_permissions p on p.id=rp.permission_id
 where rp.role_id=pg_temp.ag_id(901) and p.code='agenda.read' and rp.effect='allow' and rp.status='active'),1,
 'positive grant is synthetic and nominal, not a product role');
select ok(not exists(select 1 from public.person_auth_links where auth_user_id in
 (select auth_user_id from app_private.superadmin_internal_auth_links where internal_identity_id between pg_temp.ag_id(301) and pg_temp.ag_id(306))),
 'internal fixture actors have no People bridge');

set local role authenticated;
select pg_temp.ag_claims(2);
select pg_temp.ag_capture('list',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,'',100,0)$q$);
select pg_temp.ag_capture('first',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,'',1,0)$q$);
select pg_temp.ag_capture('second',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,'',1,1)$q$);
select pg_temp.ag_capture('beyond',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,'',1,99)$q$);
select pg_temp.ag_capture('filter_b',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',pg_temp.ag_id(20),'',100,0)$q$);
select pg_temp.ag_capture('literal',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,E'%_\\',100,0)$q$);
select pg_temp.ag_capture('get',$q$select public.superadmin_agenda_get_v2(pg_temp.ag_id(701))$q$);
select pg_temp.ag_capture('get_b',$q$select public.superadmin_agenda_get_v2(pg_temp.ag_id(703))$q$);
select pg_temp.ag_capture('missing',$q$select public.superadmin_agenda_get_v2(pg_temp.ag_id(799))$q$);
select pg_temp.ag_capture('cross_context',$q$select public.superadmin_agenda_get_v2(pg_temp.ag_id(704))$q$);
select pg_temp.ag_capture('contexts',$q$select public.superadmin_agenda_contexts_v2()$q$);
select pg_temp.ag_capture('direct_table',$q$select to_jsonb(e) from public.agenda_events e limit 1$q$);
reset role;

select is(sql_role,'authenticated','real SQL role: '||label) from ag_read01_results order by label;
select ok(sqlstate is null and body->>'ok'='true' and body->'error'='null'::jsonb,'successful envelope: '||label)
from ag_read01_results where label in ('list','first','second','beyond','filter_b','literal','get','contexts') order by label;
select is((select sqlstate from ag_read01_results where label='direct_table'),'42501','direct event table read denied');
select is(body#>>'{data,total_items}','2','total independent of page: '||label)
from ag_read01_results where label in ('list','first','second','beyond') order by label;
select is((select body#>>'{data,items,0,id}' from ag_read01_results where label='first'),pg_temp.ag_id(701)::text,'stable first ID');
select is((select body#>>'{data,items,0,id}' from ag_read01_results where label='second'),pg_temp.ag_id(702)::text,'stable next ID, same start time');
select is(body#>>'{data,limit}','1','requested limit preserved: '||label)
from ag_read01_results where label in ('first','second','beyond') order by label;
select is(r.body#>>'{data,offset}',expected.value,'actual offset preserved: '||r.label)
from ag_read01_results r join (values('first','0'),('second','1'),('beyond','99')) expected(label,value)
on expected.label=r.label order by r.label;
select is((select jsonb_array_length(body#>'{data,items}') from ag_read01_results where label='beyond'),0,'page beyond total is empty');
select is((select body#>>'{data,total_items}' from ag_read01_results where label='filter_b'),'0','cross-tenant filter only narrows');
select is((select body#>>'{data,total_items}' from ag_read01_results where label='literal'),'1','search metacharacters are literal');
select is((select body#>>'{data,items,0,id}' from ag_read01_results where label='literal'),pg_temp.ag_id(701)::text,'literal search matches exact text');
select ok(body->'data'='null'::jsonb and body#>>'{error,code}'='AGENDA_NOT_FOUND'
 and body#>>'{error,http_status}'='404','indistinguishable not-found: '||label)
from ag_read01_results where label in ('get_b','missing','cross_context') order by label;
select is((select (body->'error')-'correlation_id' from ag_read01_results where label='get_b'),
 (select (body->'error')-'correlation_id' from ag_read01_results where label='missing'),'B and nonexistent have identical public error');

select ok((select bool_and(body->>'ok'='true') from ag_read01_results where label in ('list','get','contexts'))
 and not exists(select 1 from ag_read01_results where body::text ~
 'EVENT_B_PRIVATE|CROSS_CONTEXT_PRIVATE|HISTORY_B_PRIVATE|RESPONSE_PRIVATE|PERSON_LABEL_PRIVATE|QUESTION_PRIVATE|RECURRENCE_PRIVATE|AUDIENCE_PRIVATE'),
 'no cross-scope or unknown nested sentinel leaks');
select ok((select not(body#>'{data,item}' ?| array['created_by_person_id','updated_by_person_id','responses','created_at','updated_at'])
 from ag_read01_results where label='get'),'get omits authors, raw response collection and storage metadata');
select ok((select not(body#>'{data,item,audience}' ?| array['personIds','labels'])
 and body#>>'{data,item,audience,individual_details_available}'='false' from ag_read01_results where label='get'),
 'individual audience details omitted, explicitly unavailable, never synthesized empty');
select is((select body#>>'{data,item,audience,institutionId}' from ag_read01_results where label='get'),pg_temp.ag_id(10)::text,'audience institution is validated');
select ok((select body#>'{data,item,audience,unitIds}'=jsonb_build_array(pg_temp.ag_id(11))
 and body#>'{data,item,audience,groupIds}'=jsonb_build_array(pg_temp.ag_id(13))
 and body#>'{data,item,audience,activityIds}'=jsonb_build_array(pg_temp.ag_id(31))
 from ag_read01_results where label='get'),'audience projects only structurally validated references, not embedded tenant B IDs');
select ok((select body->>'ok'='true' and position(pg_temp.ag_id(601)::text in body::text)=0
 from ag_read01_results where label='get'),'individual person ID is absent from the read DTO');
select ok((select body->>'ok'='true' and not exists(select 1 from jsonb_array_elements(body#>'{data,items}') item
 where item->'audience' ?| array['personIds','labels']
 or item#>>'{audience,individual_details_available}' is distinct from 'false')
 from ag_read01_results where label='list'),'list also explicitly omits unavailable individual audience details');
select ok((select item#>>'{audience,institutionId}'=pg_temp.ag_id(10)::text
 and item#>'{audience,unitIds}'=jsonb_build_array(pg_temp.ag_id(11))
 and item#>'{audience,groupIds}'=jsonb_build_array(pg_temp.ag_id(13))
 and item#>'{audience,activityIds}'=jsonb_build_array(pg_temp.ag_id(31))
 from ag_read01_results cross join lateral jsonb_array_elements(body#>'{data,items}') item
 where label='list' and item->>'id'=pg_temp.ag_id(701)::text),
 'list also projects only validated A audience references');
select is((select jsonb_array_length(body#>'{data,item,history}') from ag_read01_results where label='get'),1,'history intersects event and institution');
select is((select body#>>'{data,item,history,0,action}' from ag_read01_results where label='get'),'restore','same-scope history remains');
select is((select body#>>'{data,item,questions,0,type}' from ag_read01_results where label='get'),'yesNo','question type matches Dart contract');
select is((select body#>>'{data,mutation_actions_available}' from ag_read01_results where label='contexts'),'false','context read does not enable legacy commands');
select ok((select body#>'{data,contexts}' @> jsonb_build_array(jsonb_build_object('id',pg_temp.ag_id(14),
 'parent_id',pg_temp.ag_id(12),'institution_id',pg_temp.ag_id(10),'level','group')) from ag_read01_results where label='contexts'),
 'sibling A2 group retains its actual parent');
select ok((select not exists(select 1 from jsonb_array_elements(body#>'{data,contexts}') c
 where not(c ?& array['id','name','institution_id','parent_id','level','granted_capabilities','restricted_capabilities'])
 or c->>'institution_id' is distinct from pg_temp.ag_id(10)::text
 or c->>'id' in (pg_temp.ag_id(18)::text,pg_temp.ag_id(19)::text,pg_temp.ag_id(38)::text))
 from ag_read01_results where label='contexts'),'contexts exclude B and inactive parent hierarchy');
select is((select jsonb_array_length(body#>'{data,contexts}') from ag_read01_results where label='contexts'),6,
 'contexts contain one institution, two units, two groups and one activity');
select ok((select body#>'{data,contexts}' @> jsonb_build_array(jsonb_build_object('id',pg_temp.ag_id(31),
 'parent_id',pg_temp.ag_id(12),'institution_id',pg_temp.ag_id(10),'level','activity')) from ag_read01_results where label='contexts'),
 'activity has its actual active origin unit');
select ok((select jsonb_array_length(body#>'{data,contexts}')>0 and not exists(
 select 1 from jsonb_array_elements(body#>'{data,contexts}') c where
 c->'granted_capabilities' is distinct from '[]'::jsonb or c->'restricted_capabilities' is distinct from
 '["createAgendaItems","editOwnAgendaItems","editAllAgendaItems","publishAgendaItems","cancelOrRestoreAgendaItems","manageResponsesAndAuthorizations","overrideReservationConflict"]'::jsonb)
 from ag_read01_results where label='contexts'),'read-only synthetic role has seven genuinely unavailable capabilities');

-- Nominal control authorized by coordination: ONLY agenda.create, synthetic
-- role, grant then explicit deny; never invoke a mutation RPC.
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select pg_temp.ag_id(901),id,'allow','active' from public.platform_permissions where code='agenda.create';
set local role authenticated;
select pg_temp.ag_claims(2);
select pg_temp.ag_capture('capability_allow',$q$select public.superadmin_agenda_contexts_v2()$q$);
reset role;
update public.platform_role_permissions rp set effect='deny'
from public.platform_permissions p where p.id=rp.permission_id
 and rp.role_id=pg_temp.ag_id(901) and p.code='agenda.create';
set local role authenticated;
select pg_temp.ag_capture('capability_deny',$q$select public.superadmin_agenda_contexts_v2()$q$);
reset role;
select ok((select sql_role='authenticated' and body->>'ok'='true'
 and body#>>'{data,mutation_actions_available}'='false'
 and jsonb_array_length(body#>'{data,contexts}')=6
 and not exists(select 1 from jsonb_array_elements(body#>'{data,contexts}') c
 where c->'granted_capabilities' is distinct from '["createAgendaItems"]'::jsonb
 or c->'restricted_capabilities' is distinct from '["editOwnAgendaItems","editAllAgendaItems","publishAgendaItems","cancelOrRestoreAgendaItems","manageResponsesAndAuthorizations","overrideReservationConflict"]'::jsonb)
 from ag_read01_results where label='capability_allow'),'real synthetic grant is reflected without enabling mutation integration');
select ok((select sql_role='authenticated' and body->>'ok'='true'
 and body#>>'{data,mutation_actions_available}'='false'
 and jsonb_array_length(body#>'{data,contexts}')=6
 and not exists(select 1 from jsonb_array_elements(body#>'{data,contexts}') c
 where c->'granted_capabilities' is distinct from '[]'::jsonb or c->'restricted_capabilities' is distinct from
 '["createAgendaItems","editOwnAgendaItems","editAllAgendaItems","publishAgendaItems","cancelOrRestoreAgendaItems","manageResponsesAndAuthorizations","overrideReservationConflict"]'::jsonb)
 from ag_read01_results where label='capability_deny'),'explicit capability deny is effective without denying read');

update app_private.superadmin_internal_memberships set status='suspended',suspended_at=now(),version=2
where id=pg_temp.ag_id(502);
set local role authenticated;
select pg_temp.ag_capture('suspended',$q$select public.superadmin_agenda_contexts_v2()$q$);
reset role;
select ok((select sql_role='authenticated' and body->'data'='null'::jsonb
 and body#>>'{error,code}'='SAI_MEMBERSHIP_SUSPENDED' from ag_read01_results where label='suspended'),
 'membership suspension immediately invalidates previous authorized context');
update app_private.superadmin_internal_memberships set status='active',suspended_at=null,version=3
where id=pg_temp.ag_id(502);

set local role authenticated;
select pg_temp.ag_claims(2);
select pg_temp.ag_capture('invalid_null_from',$q$select public.superadmin_agenda_list_v2(null,'2026-09-09',null,'',100,0)$q$);
select pg_temp.ag_capture('invalid_null_to',$q$select public.superadmin_agenda_list_v2('2026-09-08',null,null,'',100,0)$q$);
select pg_temp.ag_capture('invalid_period',$q$select public.superadmin_agenda_list_v2('2026-09-09','2026-09-08',null,'',100,0)$q$);
select pg_temp.ag_capture('invalid_long_period',$q$select public.superadmin_agenda_list_v2('2026-01-01','2028-01-01',null,'',100,0)$q$);
select pg_temp.ag_capture('invalid_limit',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,'',201,0)$q$);
select pg_temp.ag_capture('invalid_zero_limit',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,'',0,0)$q$);
select pg_temp.ag_capture('invalid_null_limit',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,'',null,0)$q$);
select pg_temp.ag_capture('invalid_offset',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,'',100,-1)$q$);
select pg_temp.ag_capture('invalid_null_offset',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,'',100,null)$q$);
select pg_temp.ag_capture('invalid_search',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,repeat('a',121),100,0)$q$);
select pg_temp.ag_capture('invalid_null_id',$q$select public.superadmin_agenda_get_v2(null)$q$);
select pg_temp.ag_claims(1);
select pg_temp.ag_capture('platform',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,'',100,0)$q$);
select pg_temp.ag_claims(3,null,'aal1');
select pg_temp.ag_capture('aal1',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,'',100,0)$q$);
select pg_temp.ag_claims(4);
select pg_temp.ag_capture('revoked',$q$select public.superadmin_agenda_contexts_v2()$q$);
select pg_temp.ag_claims(5);
select pg_temp.ag_capture('people_only',$q$select public.superadmin_agenda_contexts_v2()$q$);
select pg_temp.ag_claims(6);
select pg_temp.ag_capture('denied_capability',$q$select public.superadmin_agenda_contexts_v2()$q$);
select pg_temp.ag_claims(2,201);
select pg_temp.ag_capture('wrong_session',$q$select public.superadmin_agenda_contexts_v2()$q$);
select pg_temp.ag_claims(1,209);
select pg_temp.ag_capture('expired',$q$select public.superadmin_agenda_contexts_v2()$q$);
select set_config('request.jwt.claims','{}',true);
select pg_temp.ag_capture('no_auth',$q$select public.superadmin_agenda_contexts_v2()$q$);
reset role;

select ok(sql_role='authenticated' and sqlstate is null and body->'data'='null'::jsonb
 and body#>>'{error,code}'='AGENDA_INVALID_ARGUMENT' and body#>>'{error,http_status}'='400',
 'invalid arguments use nominal envelope: '||label)
from ag_read01_results where label like 'invalid_%' order by label;
select is(body#>>'{data,total_items}','3','platform scope sees A and B without invalid contextual row: '||label)
from ag_read01_results where label in ('platform','aal1') order by label;
select ok(sql_role='authenticated' and sqlstate is null and body->'data'='null'::jsonb and body->>'ok'='false'
 and body#>>'{error,code}'=expected.code,'internal denial: '||r.label)
from ag_read01_results r join (values
 ('revoked','SAI_MEMBERSHIP_REVOKED'),('people_only','SAI_INTERNAL_CONTEXT_DENIED'),
 ('denied_capability','SAI_PERMISSION_DENIED'),('wrong_session','SAI_SESSION_INVALID'),
 ('expired','SAI_SESSION_INVALID'),('no_auth','SAI_AUTH_REQUIRED')
) expected(label,code) on expected.label=r.label order by r.label;

-- Allowlist checks intentionally require success separately; absence is not a pass.
select ok((select (body#>'{data,item}') - array['id','institution_id','context_kind','context_id','title',
 'item_type','priority','status','origin','starts_at','ends_at','all_day','time_zone_id','location',
 'description','response_mode','guardian_response_policy','recurrence','audience','reminders','questions','revision','history']='{}'::jsonb
 from ag_read01_results where label='get'),'closed top-level item allowlist');
select ok((select (body#>'{data,item,recurrence}')-array['frequency','interval','until','occurrenceCount','exceptions']='{}'::jsonb
 and (body#>'{data,item,questions,0}')-array['id','title','type']='{}'::jsonb
 and (body#>'{data,item,audience}')-array['institutionId','unitIds','groupIds','activityIds','individual_details_available']='{}'::jsonb
 from ag_read01_results where label='get'),'closed nested allowlists');
select ok((select (body#>'{data,item,history,0}')-array['action','occurred_at','reason','previous_revision','next_revision']='{}'::jsonb
 from ag_read01_results where label='get'),'history does not disclose person or request IDs');

select ok(not coalesce(has_function_privilege('anon',to_regprocedure(signature),'EXECUTE'),true),
 'anon cannot execute '||signature)
from (values('public.superadmin_agenda_list_v2(timestamptz,timestamptz,uuid,text,integer,integer)'),
 ('public.superadmin_agenda_get_v2(uuid)'),('public.superadmin_agenda_contexts_v2()')) f(signature);
select ok(not coalesce(has_function_privilege('service_role',to_regprocedure(signature),'EXECUTE'),true),
 'service_role is not a reader login: '||signature)
from (values('public.superadmin_agenda_list_v2(timestamptz,timestamptz,uuid,text,integer,integer)'),
 ('public.superadmin_agenda_get_v2(uuid)'),('public.superadmin_agenda_contexts_v2()')) f(signature);
select ok(coalesce(has_function_privilege('authenticated',to_regprocedure(signature),'EXECUTE'),false),
 'authenticated can enter nominal wrapper: '||signature)
from (values('public.superadmin_agenda_list_v2(timestamptz,timestamptz,uuid,text,integer,integer)'),
 ('public.superadmin_agenda_get_v2(uuid)'),('public.superadmin_agenda_contexts_v2()')) f(signature);

select ok(r.body->>'ok'='true' and exists(select 1 from audit.audit_logs a
 where a.correlation_id::text=r.body#>>'{data,correlation_id}'
 and a.permission_code='agenda.read' and a.action_code='agenda.'||r.label and a.outcome='success'
 and a.actor_kind='superadmin_internal' and a.actor_internal_identity_id=pg_temp.ag_id(302)
 and a.actor_internal_auth_link_id=pg_temp.ag_id(402) and a.actor_internal_membership_id=pg_temp.ag_id(502)
 and a.institution_id=pg_temp.ag_id(10) and a.session_id_hash is not null),
 'real correlated internal audit: '||r.label)
from ag_read01_results r where label in ('list','get','contexts') order by label;
select ok(exists(select 1 from audit.audit_logs a
 where a.correlation_id::text=r.body#>>'{data,correlation_id}'
 and a.before_json is null and a.object_id is null
 and a.after_json=jsonb_build_object('row_count',case r.label when 'list' then 2 when 'get' then 1
 else jsonb_array_length(r.body#>'{data,contexts}') end)),
 'audit contains only exact row_count: '||r.label)
from ag_read01_results r where label in ('list','get','contexts') order by label;
select ok(exists(select 1 from audit.audit_logs a where a.permission_code='agenda.read'
 and a.outcome='denied' and a.correlation_id::text=r.body#>>'{error,correlation_id}'),
 'identified domain denial has correlated audit: '||label)
from ag_read01_results r where label in ('get_b','missing','invalid_null_id','denied_capability') order by label;

create function pg_temp.ag_reject_success_audit() returns trigger language plpgsql as $$
begin
 if new.permission_code='agenda.read' and new.outcome='success'
 and new.action_code in ('agenda.list','agenda.get','agenda.contexts') then
  raise exception using errcode='P0001',message='AG_READ01_AUDIT_FAILURE';
 end if;
 return new;
end $$;
create trigger ag_read01_reject_success_audit before insert on audit.audit_logs
for each row execute function pg_temp.ag_reject_success_audit();
set local role authenticated;
select pg_temp.ag_claims(2);
select pg_temp.ag_capture('audit_fail_list',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,'',100,0)$q$);
select pg_temp.ag_capture('audit_fail_get',$q$select public.superadmin_agenda_get_v2(pg_temp.ag_id(701))$q$);
select pg_temp.ag_capture('audit_fail_contexts',$q$select public.superadmin_agenda_contexts_v2()$q$);
reset role;
select ok(body is null and sqlstate='P0001' and message='AG_READ01_AUDIT_FAILURE' and sql_role='authenticated',
 'append failure propagates, never returns success: '||label)
from ag_read01_results where label like 'audit_fail_%' order by label;
drop trigger ag_read01_reject_success_audit on audit.audit_logs;

select is((select md5(jsonb_agg(to_jsonb(e) order by e.id)::text) from public.agenda_events e
 where e.id between pg_temp.ag_id(701) and pg_temp.ag_id(704)),
 (select digest from ag_read01_storage_before where label='events'),'reader did not mutate event rows');
select is((select md5(jsonb_agg(to_jsonb(h) order by h.id)::text) from public.agenda_history_receipts h
 where h.id in (pg_temp.ag_id(801),pg_temp.ag_id(802))),
 (select digest from ag_read01_storage_before where label='history'),'reader did not mutate original command receipts');
select is((select count(*)::integer from public.agenda_history_receipts where event_id between pg_temp.ag_id(701) and pg_temp.ag_id(704)),2,
 'reader did not append command receipts');
select is((select audience->>'labels' from public.agenda_events where id=pg_temp.ag_id(701)),
 '["PERSON_LABEL_PRIVATE"]','audience minimization did not rewrite storage');
select * from finish();
rollback;
