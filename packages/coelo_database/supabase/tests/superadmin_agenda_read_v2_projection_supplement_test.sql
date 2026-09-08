-- AG-READ01 supplemental candidate: NOT executed. Eng1 owns nominal replay.
-- Independent transaction; does not include or modify the frozen a3b/114 fixture.
-- Only synthetic fixture data/grants. No helper replacement or trigger bypass.
begin;
set local time zone 'UTC';
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.ags_id(n integer) returns uuid language sql immutable as $$
 select ('8a510000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid
$$;
insert into public.platform_roles(id,code,name,status,is_system,max_scope_kind) values
 (pg_temp.ags_id(901),'ag-projection-reader','AG projection synthetic reader','active',false,'platform');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select pg_temp.ags_id(901),id,'allow','active' from public.platform_permissions where code='agenda.read';
insert into public.institution_types(id,code,name,status) values
 (pg_temp.ags_id(1),'ag-projection-type','AG projection type','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 (pg_temp.ags_id(10),'AG projection A','ag-projection-a','active',pg_temp.ags_id(1));
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
values(pg_temp.ags_id(101),'authenticated','authenticated','ag-projection@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
values(pg_temp.ags_id(201),pg_temp.ags_id(101),now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values(pg_temp.ags_id(301));
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id)
values(pg_temp.ags_id(401),pg_temp.ags_id(301),pg_temp.ags_id(101));
insert into app_private.superadmin_internal_memberships
 (id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
values(pg_temp.ags_id(501),pg_temp.ags_id(301),pg_temp.ags_id(901),'institution',pg_temp.ags_id(10));

-- Historical FK author only: no People auth bridge or platform membership.
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.ags_id(601),'adult','AG','Projection','AG projection author','active');
insert into public.agenda_events
 (id,institution_id,context_kind,context_id,title,item_type,status,starts_at,ends_at,
 description,recurrence,audience,reminders,questions,created_by_person_id,updated_by_person_id)
values
 (pg_temp.ags_id(701),pg_temp.ags_id(10),'institution',pg_temp.ags_id(10),'Evento neutro','event','published',
 '2026-09-08 12:00Z','2026-09-08 13:00Z',E'Nota código %_\\ fim',
 '{"frequency":"weekly","interval":2,"until":"2026-09-12 10:30:00 UTC","exceptions":["2026-09-10 09:00:00 UTC"]}',
 '{}','[]','[]',pg_temp.ags_id(601),pg_temp.ags_id(601)),
 (pg_temp.ags_id(702),pg_temp.ags_id(10),'institution',pg_temp.ags_id(10),'Segundo evento','event','draft',
 '2026-09-08 12:00Z','2026-09-08 13:00Z','Descrição sem marcador',null,
 '{}','[]','[]',pg_temp.ags_id(601),pg_temp.ags_id(601));
set constraints all immediate;
create temporary table ags_storage_before as
select md5(jsonb_agg(to_jsonb(e) order by e.id)::text) digest
from public.agenda_events e where e.id in (pg_temp.ags_id(701),pg_temp.ags_id(702));

create temporary table ags_results(label text primary key,body jsonb,sqlstate text,sql_role text);
grant select,insert on table ags_results to authenticated;
create function pg_temp.ags_capture(p_label text,p_query text) returns void
language plpgsql security invoker as $$
declare response jsonb;
begin
 begin
  execute p_query into response;
  insert into ags_results values(p_label,response,null,current_user);
 exception when others then
  insert into ags_results values(p_label,null,sqlstate,current_user);
 end;
end $$;
revoke all on function pg_temp.ags_id(integer),pg_temp.ags_capture(text,text) from public;
grant execute on function pg_temp.ags_id(integer),pg_temp.ags_capture(text,text) to authenticated;

select is((select count(*)::integer from public.platform_role_permissions rp
 join public.platform_permissions p on p.id=rp.permission_id
 where rp.role_id=pg_temp.ags_id(901) and p.code='agenda.read' and rp.effect='allow' and rp.status='active'),
 1,'supplement has one synthetic nominal READ grant');
select ok(not exists(select 1 from public.person_auth_links where auth_user_id=pg_temp.ags_id(101)),
 'supplement actor has no People bridge');
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.ags_id(101),
 'session_id',pg_temp.ags_id(201),'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select pg_temp.ags_capture('description_trim',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,E'  %_\\  ',100,0)$q$);
select pg_temp.ags_capture('spaces',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,'   ',100,0)$q$);
select pg_temp.ags_capture('no_match',$q$select public.superadmin_agenda_list_v2('2026-09-08','2026-09-09',null,'not-present-token',100,0)$q$);
select pg_temp.ags_capture('detail',$q$select public.superadmin_agenda_get_v2(pg_temp.ags_id(701))$q$);
reset role;

select is(sql_role,'authenticated','actual invoker role: '||label) from ags_results order by label;
select ok(sqlstate is null and body->>'ok'='true' and body->'error'='null'::jsonb,
 'successful envelope: '||label) from ags_results order by label;
select is((select body#>>'{data,total_items}' from ags_results where label='description_trim'),
 '1','trimmed literal search matches description only');
select is((select body#>>'{data,items,0,id}' from ags_results where label='description_trim'),
 pg_temp.ags_id(701)::text,'description match returns the exact event');
select is((select body#>>'{data,total_items}' from ags_results where label='spaces'),
 '2','spaces-only search is empty search');
select is((select body#>>'{data,total_items}' from ags_results where label='no_match'),
 '0','absent literal has zero total');
select is((select body#>'{data,items}' from ags_results where label='no_match'),
 '[]'::jsonb,'absent literal returns an empty page');

-- Compare JSON values directly. Casting response strings back to timestamptz
-- would falsely pass a reader that retransmits the non-Dart input unchanged.
select is(projection->>'frequency','weekly','frequency retained: '||label)
from (select label,case when label='detail' then body#>'{data,item,recurrence}'
 else body#>'{data,items,0,recurrence}' end projection from ags_results
 where label in ('detail','description_trim')) r order by label;
select is(projection->'interval','2'::jsonb,'typed interval retained: '||label)
from (select label,case when label='detail' then body#>'{data,item,recurrence}'
 else body#>'{data,items,0,recurrence}' end projection from ags_results
 where label in ('detail','description_trim')) r order by label;
select ok(not(projection ? 'occurrenceCount'),'until branch omits count: '||label)
from (select label,case when label='detail' then body#>'{data,item,recurrence}'
 else body#>'{data,items,0,recurrence}' end projection from ags_results
 where label in ('detail','description_trim')) r order by label;
select is(projection->'until',to_jsonb('2026-09-12 10:30:00+00'::timestamptz),
 'until is canonical JSON timestamp: '||label)
from (select label,case when label='detail' then body#>'{data,item,recurrence}'
 else body#>'{data,items,0,recurrence}' end projection from ags_results
 where label in ('detail','description_trim')) r order by label;
select is(projection->'exceptions',jsonb_build_array('2026-09-10 09:00:00+00'::timestamptz),
 'exceptions are canonical JSON timestamps: '||label)
from (select label,case when label='detail' then body#>'{data,item,recurrence}'
 else body#>'{data,items,0,recurrence}' end projection from ags_results
 where label in ('detail','description_trim')) r order by label;
select ok(body::text not like '%2026-09-12 10:30:00 UTC%'
 and body::text not like '%2026-09-10 09:00:00 UTC%',
 'original timestamp strings not retransmitted: '||label)
from ags_results where label in ('detail','description_trim') order by label;
select is((select md5(jsonb_agg(to_jsonb(e) order by e.id)::text)
 from public.agenda_events e where e.id in (pg_temp.ags_id(701),pg_temp.ags_id(702))),
 (select digest from ags_storage_before),'projection leaves stored domain data unchanged');
select * from finish();
rollback;
