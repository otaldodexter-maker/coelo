-- Prova pgTAP da migration 20260919231500_staff_access_legacy_readers_v1 (varredura dos leitores).
-- Fixture sintetica com rollback total (prefixo f9): instituicao A com unidade A1 e turma; educadoras
-- E e F (unidade A1, institution_admin p/ ter people.read), crianca com contexto em A. E afastada hoje.
-- Negativas por familia: destinatarios de cuidado e medicacao (v1/v2) excluem E e mantem F; classe do
-- leitor do Agora nega E como equipe; feed proprio do Principal de E nao traz A; estrutural nas 8.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

create function pg_temp.f9(n integer) returns uuid language sql immutable as $$
  select ('f9000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
grant execute on function pg_temp.f9(integer) to authenticated;
create function pg_temp.as_user(n integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', pg_temp.f9(n)::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.f9(n)::text, 'role', 'authenticated', 'aal', 'aal1')::text, true);
end $$;

-- estrutural: as 8 funcoes consultam staff_access_blocked ----------------------------------------
select ok((select bool_and(p.prosrc like '%staff_access_blocked%')
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where (n.nspname='app_private' and p.proname in ('child_care_notification_recipients_v1','medication_notification_recipients_v1',
    'medication_notification_recipients_v2','child_safety_add_unit_review_recipients','materialize_notice_publication_job','now_viewer_role_class'))
     or (n.nspname='public' and p.proname in ('list_my_principal_for_you','redeem_now_media_read_ticket'))),
  'all 8 legacy readers consult staff_access_blocked');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where (n.nspname='app_private' and p.proname in ('child_care_notification_recipients_v1','medication_notification_recipients_v1',
    'medication_notification_recipients_v2','child_safety_add_unit_review_recipients','materialize_notice_publication_job','now_viewer_role_class'))
     or (n.nspname='public' and p.proname in ('list_my_principal_for_you','redeem_now_media_read_ticket'))),8,'the 8 functions still exist (no signature lost)');

-- fixture ---------------------------------------------------------------------------------------
insert into public.institution_types(id,code,name,status) values (pg_temp.f9(1),'f9-type','F9 type','active');
insert into public.unit_types(id,code,name,status) values (pg_temp.f9(2),'f9-unit','F9 unit','active');
insert into public.people(id,person_type,first_name,last_name,display_name)
select 'c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema'
where not exists (select 1 from public.people where id='c0e10000-0000-4000-8000-000000000001');
insert into public.institutions(id,institution_type_id,public_name,slug,status,timezone) values
 (pg_temp.f9(10),pg_temp.f9(1),'F9 Instituicao A','f9-a','active','America/Sao_Paulo');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status,timezone) values
 (pg_temp.f9(11),pg_temp.f9(10),'F9 Unidade A1','f9-unidade-a1','f9unidade.a1',pg_temp.f9(2),'active','America/Sao_Paulo');
insert into public.groups(id,institution_id,unit_id,name,status) values (pg_temp.f9(12),pg_temp.f9(10),pg_temp.f9(11),'F9 Turma','active');
insert into auth.users(id) values (pg_temp.f9(101)),(pg_temp.f9(102)),(pg_temp.f9(103));
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 (pg_temp.f9(201),'adult','F9','Educadora E','F9 Educadora E','active'),
 (pg_temp.f9(202),'adult','F9','Educadora F','F9 Educadora F','active'),
 (pg_temp.f9(203),'adult','F9','Admin D','F9 Admin D','active'),
 (pg_temp.f9(401),'child','F9','Crianca','F9 Crianca','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 (pg_temp.f9(201),pg_temp.f9(101),'active'),(pg_temp.f9(202),pg_temp.f9(102),'active'),(pg_temp.f9(203),pg_temp.f9(103),'active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind,scope_unit_id,scope_group_id) values
 (pg_temp.f9(301),pg_temp.f9(201),pg_temp.f9(10),'teacher','active','unit',pg_temp.f9(11),null),
 (pg_temp.f9(302),pg_temp.f9(202),pg_temp.f9(10),'teacher','active','unit',pg_temp.f9(11),null),
 (pg_temp.f9(303),pg_temp.f9(203),pg_temp.f9(10),'institution_admin','active','institution',null,null);
insert into public.institution_role_assignments(membership_id,role_id,scope_kind,scope_unit_id)
select m, r.id,'unit',pg_temp.f9(11) from (values (pg_temp.f9(301)),(pg_temp.f9(302))) v(m), public.institution_roles r where r.code='institution_admin' and r.is_system;
insert into public.institution_role_assignments(membership_id,role_id,scope_kind)
select pg_temp.f9(303),r.id,'institution' from public.institution_roles r where r.code='institution_admin' and r.is_system;
insert into public.child_contexts(id,child_person_id,institution_id,status) values (pg_temp.f9(411),pg_temp.f9(401),pg_temp.f9(10),'active');

-- antes do afastamento: E e F sao destinatarias -------------------------------------------------
select ok(pg_temp.f9(201) in (select * from app_private.child_care_notification_recipients_v1(pg_temp.f9(10),pg_temp.f9(11),pg_temp.f9(411),pg_temp.f9(203))),'care: E is a recipient while free');
select ok(pg_temp.f9(201) in (select * from app_private.medication_notification_recipients_v2(pg_temp.f9(10),pg_temp.f9(11),pg_temp.f9(411),pg_temp.f9(203))),'medication v2: E is a recipient while free');
select is(app_private.now_viewer_role_class(pg_temp.f9(201),pg_temp.f9(301),pg_temp.f9(10),pg_temp.f9(11),null),'school_staff','now: E classified as school_staff while free');

-- E afastada hoje (bloqueada agora) ----------------------------------------------------------------
select pg_temp.as_user(103);
set local role authenticated;
select lives_ok($$select public.staff_leave_save_v1(null,pg_temp.f9(301),null,jsonb_build_object('starts_on',(current_date - 1)::text,'ends_on',(current_date + 1)::text,'popup_enabled',true))$$,'leave covering today for E');
reset role;
select is(app_private.staff_access_state(pg_temp.f9(301)),'blocked_now','E blocked now');

select ok(pg_temp.f9(201) not in (select * from app_private.child_care_notification_recipients_v1(pg_temp.f9(10),pg_temp.f9(11),pg_temp.f9(411),pg_temp.f9(203))),'care: blocked E is no longer a recipient');
select ok(pg_temp.f9(202) in (select * from app_private.child_care_notification_recipients_v1(pg_temp.f9(10),pg_temp.f9(11),pg_temp.f9(411),pg_temp.f9(203))),'care: F still a recipient');
select ok(pg_temp.f9(201) not in (select * from app_private.medication_notification_recipients_v1(pg_temp.f9(10),pg_temp.f9(11),pg_temp.f9(411),pg_temp.f9(203))),'medication v1: blocked E excluded');
select ok(pg_temp.f9(201) not in (select * from app_private.medication_notification_recipients_v2(pg_temp.f9(10),pg_temp.f9(11),pg_temp.f9(411),pg_temp.f9(203))),'medication v2: blocked E excluded');
select is(app_private.now_viewer_role_class(pg_temp.f9(201),pg_temp.f9(301),pg_temp.f9(10),pg_temp.f9(11),null),null,'now: blocked E is not school_staff');

select pg_temp.as_user(101);
set local role authenticated;
select is(jsonb_array_length(public.list_my_principal_for_you('web',pg_temp.f9(301),50)->'data'->'items'),0,'for-you feed of the blocked vinculo is empty (no data from the blocked context)');
reset role;

select * from finish();
rollback;
