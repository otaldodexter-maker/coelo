begin; create extension if not exists pgtap with schema extensions; select plan(4);
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

-- Producao (cadeia de Atividades v2, 180020/180030) guarda a proveniencia do ator:
-- inserir definicoes de atividade direto exige o marcador interno com um contexto
-- valido, e o criador people-based fica nulo.
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8d200000-0000-4000-8000-000000000101','session_id','8d200000-0000-4000-8000-000000000201',
 'aal','aal2','role','authenticated')::text,true);
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8d200000-0000-4000-8000-000000000301','internal_auth_link_id','8d200000-0000-4000-8000-000000000401',
 'internal_membership_id','8d200000-0000-4000-8000-000000000501','auth_user_id','8d200000-0000-4000-8000-000000000101',
 'session_id','8d200000-0000-4000-8000-000000000201','permission_code','activities.create','action_code','create',
 'correlation_id',gen_random_uuid())::text,true);
insert into public.activity_definitions(
 id,institution_id,name,origin_scope_kind,created_by_person_id,status,handle_stem) values
 ('8d200000-0000-4000-8000-000000000701','8d200000-0000-4000-8000-000000000010','Activity A','institution',null,'active','assessment-activity-a'),
 ('8d200000-0000-4000-8000-000000000702','8d200000-0000-4000-8000-000000000020','Activity B','institution',null,'active','assessment-activity-b');
insert into public.groups(id,institution_id,unit_id,name,status) values
 ('8d200000-0000-4000-8000-000000000711','8d200000-0000-4000-8000-000000000010','8d200000-0000-4000-8000-000000000011','Turma A','active');
insert into public.activity_unit_links(
 id,activity_id,institution_id,unit_id,linked_by_person_id,status
) values (
 '8d200000-0000-4000-8000-000000000710','8d200000-0000-4000-8000-000000000701',
 '8d200000-0000-4000-8000-000000000010','8d200000-0000-4000-8000-000000000011',null,'active');
insert into public.activity_group_links(
 id,activity_id,institution_id,unit_id,group_id,linked_by_person_id,status
) values (
 '8d200000-0000-4000-8000-000000000712','8d200000-0000-4000-8000-000000000701',
 '8d200000-0000-4000-8000-000000000010','8d200000-0000-4000-8000-000000000011',
 '8d200000-0000-4000-8000-000000000711',null,'active');

insert into public.child_contexts(id,child_person_id,institution_id,status) values
 ('8d200000-0000-4000-8000-000000000720','8d200000-0000-4000-8000-000000000603','8d200000-0000-4000-8000-000000000010','active');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
 ('8d200000-0000-4000-8000-000000000721','8d200000-0000-4000-8000-000000000720','8d200000-0000-4000-8000-000000000011','active','8d200000-0000-4000-8000-000000000601',now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status) values
 ('8d200000-0000-4000-8000-000000000722','8d200000-0000-4000-8000-000000000721','8d200000-0000-4000-8000-000000000711','active');
insert into public.activity_group_participants(
 id,activity_group_link_id,child_group_link_id,status,added_by_person_id
) values (
 '8d200000-0000-4000-8000-000000000723','8d200000-0000-4000-8000-000000000712',
 '8d200000-0000-4000-8000-000000000722','active',null);
select set_config('app_private.activity_v2_internal_marker','',true);

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8d200000-0000-4000-8000-000000000101','session_id','8d200000-0000-4000-8000-000000000201',
 'aal','aal2','role','authenticated')::text,true);

create temporary table r11_payload as select '{"activity_id": "8d200000-0000-4000-8000-000000000701", "institution_id": "8d200000-0000-4000-8000-000000000010", "unit_id": "8d200000-0000-4000-8000-000000000011", "periodicity": "annual", "result_scale_kind": "numeric_0_10", "scale_options": {"step": 0.01}, "concepts": [], "periods": [{"name": "R08 sint\u00c3\u00a9tico", "ordinal": 1, "academic_year": 2026, "starts_on": "2026-09-12", "ends_on": "2026-12-31", "entry_closes_at": "2026-12-31T23:00:00.000Z", "family_release_at": "2026-12-31T23:00:00.000Z", "timezone": "America/Sao_Paulo", "status": "draft"}], "allow_final_override": false, "instruments": [{"name": "Instrumento R08", "weight": 100, "sort_order": 0}], "categories": []}'::jsonb as value;

create temporary table r11_active as select public.superadmin_assessment_save_configuration(gen_random_uuid(),null,0,value) body from r11_payload;
select is((select body->>'ok' from r11_active),'true','create first configuration');
select public.superadmin_assessment_activate_configuration(gen_random_uuid(),(select (body#>>'{data,id}')::uuid from r11_active),1);
create temporary table r11_book as select public.superadmin_assessment_save_gradebook(gen_random_uuid(),null,0,jsonb_build_object(
 'activity_group_link_id','8d200000-0000-4000-8000-000000000712',
 'period_id',(select id from public.assessment_periods where configuration_id=(select (body#>>'{data,id}')::uuid from r11_active)),
 'configuration_id',(select body#>>'{data,id}' from r11_active),'students','[]'::jsonb),null) body;
select is((select body->>'ok' from r11_book),'true','retained gradebook references active configuration');
create temporary table r11_draft as select public.superadmin_assessment_save_configuration(gen_random_uuid(),null,0,value) body from r11_payload;
select is((select body->>'ok' from r11_draft),'true','create second retained draft');

create or replace function app_private.assessment_v2_save_configuration(
  request_id uuid, configuration_id uuid, expected_version bigint, payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
-- Correcao R04: as consultas qualificam colunas por alias e usam as variaveis
-- institution_id/unit_id/activity_id sem qualificar; sem esta diretiva o
-- Postgres 17 aborta com 'column reference is ambiguous'.
#variable_conflict use_variable
declare
  ctx app_private.superadmin_internal_context; saved public.activity_assessment_configurations%rowtype;
  institution_id uuid; unit_id uuid; activity_id uuid; request_hash bytea; replay jsonb;
  instrument jsonb; concept jsonb; category jsonb; competency jsonb; period jsonb;
  v_category_id uuid; v_competency_id uuid; instrument_total numeric;
begin
  if payload is null or jsonb_typeof(payload) <> 'object'
    or exists (select 1 from jsonb_object_keys(payload) k where k not in (
      'activity_id','institution_id','unit_id','periodicity','result_scale_kind',
      'scale_options','concepts','periods','allow_final_override','instruments','categories'))
    or not (payload ?& array['activity_id','institution_id','periodicity','result_scale_kind',
      'scale_options','periods','allow_final_override','instruments','categories'])
    or jsonb_typeof(payload->'scale_options') <> 'object'
    or jsonb_typeof(payload->'periods') <> 'array'
    or jsonb_typeof(payload->'instruments') <> 'array'
    or jsonb_typeof(payload->'categories') <> 'array'
    or coalesce(jsonb_typeof(payload->'concepts'), 'array') <> 'array'
    or jsonb_array_length(payload->'periods') not between 1 and 12
    or jsonb_array_length(payload->'instruments') not between 1 and 30
    or jsonb_array_length(payload->'categories') > 30 then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;
  begin
    activity_id := (payload->>'activity_id')::uuid;
    institution_id := (payload->>'institution_id')::uuid;
    unit_id := nullif(payload->>'unit_id', '')::uuid;
  exception when others then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
  end;
  select * into strict ctx
  from app_private.assessment_v2_require_context('activities.manage', institution_id);
  if not exists (select 1 from public.activity_definitions a
    where a.id = activity_id and a.institution_id = institution_id
      and a.status in ('draft','active'))
    or (unit_id is not null and not exists (select 1 from public.units u
      where u.id = unit_id and u.institution_id = institution_id and u.status = 'active'))
    or payload->>'periodicity' not in ('bimonthly','trimester','semester','annual')
    or payload->>'result_scale_kind' not in (
      'numeric_0_10','numeric_0_100','concept','numeric_1_5','binary','stars_0_5') then
    raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_REFERENCE';
  end if;
  request_hash := app_private.assessment_v2_hash(jsonb_build_object(
    'configuration_id', configuration_id, 'expected_version', expected_version, 'payload', payload));
  replay := app_private.assessment_v2_replay(ctx, request_id, 'configuration.save', request_hash);
  if replay is not null then return replay; end if;

  if configuration_id is null then
    if expected_version <> 0 then raise serialization_failure using detail = 'SAI_CONCURRENT_CHANGE'; end if;
    insert into public.activity_assessment_configurations(
      activity_id, institution_id, unit_id, periodicity, result_scale_kind,
      scale_options, allow_final_override)
    values (activity_id, institution_id, unit_id, payload->>'periodicity',
      payload->>'result_scale_kind', payload->'scale_options',
      coalesce((payload->>'allow_final_override')::boolean, false))
    returning * into saved;
  else
    select * into saved from public.activity_assessment_configurations c
    where c.id = configuration_id and c.institution_id = institution_id for update;
    if not found then raise no_data_found using detail = 'ASSESSMENT_NOT_FOUND'; end if;
    if saved.management_version <> expected_version then
      raise serialization_failure using detail = 'SAI_CONCURRENT_CHANGE';
    end if;
    if saved.status <> 'draft' or saved.activity_id <> activity_id
      or saved.unit_id is distinct from unit_id then
      raise check_violation using detail = 'ASSESSMENT_INVALID_STATE';
    end if;
    update public.activity_assessment_configurations c set
      periodicity = payload->>'periodicity', result_scale_kind = payload->>'result_scale_kind',
      scale_options = payload->'scale_options',
      allow_final_override = coalesce((payload->>'allow_final_override')::boolean, false),
      management_version = c.management_version + 1, updated_at = now()
    where c.id = saved.id returning * into saved;
    delete from public.assessment_instruments where configuration_id = saved.id;
    delete from public.assessment_categories where configuration_id = saved.id;
    delete from public.assessment_scale_concepts where configuration_id = saved.id;
    delete from public.assessment_periods where configuration_id = saved.id;
  end if;

  for instrument in select value from jsonb_array_elements(payload->'instruments') loop
    if jsonb_typeof(instrument) <> 'object'
      or not (instrument ?& array['name','weight','sort_order'])
      or exists (select 1 from jsonb_object_keys(instrument) k
        where k not in ('name','weight','sort_order')) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_instruments(configuration_id, name, weight, sort_order)
    values (saved.id, btrim(instrument->>'name'), (instrument->>'weight')::numeric,
      (instrument->>'sort_order')::integer);
  end loop;
  select sum(i.weight) into instrument_total from public.assessment_instruments i
  where i.configuration_id = saved.id;
  if instrument_total <> 100 then
    raise check_violation using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;

  for concept in select value from jsonb_array_elements(coalesce(payload->'concepts','[]'::jsonb)) loop
    if jsonb_typeof(concept) <> 'object' or not (concept ?& array['code','label','sort_order']) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_scale_concepts(configuration_id, code, label, sort_order)
    values (saved.id, btrim(concept->>'code'), btrim(concept->>'label'),
      (concept->>'sort_order')::integer);
  end loop;
  if saved.result_scale_kind = 'concept'
    and not exists (select 1 from public.assessment_scale_concepts s where s.configuration_id = saved.id) then
    raise check_violation using detail = 'ASSESSMENT_INVALID_INPUT';
  end if;

  for category in select value from jsonb_array_elements(payload->'categories') loop
    if jsonb_typeof(category) <> 'object' or not (category ?& array['name','competencies'])
      or jsonb_typeof(category->'competencies') <> 'array' then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_categories(configuration_id, name, sort_order)
    values (saved.id, btrim(category->>'name'),
      coalesce((category->>'sort_order')::integer,
        (select count(*) from public.assessment_categories c where c.configuration_id = saved.id)))
    returning id into v_category_id;
    for competency in select value from jsonb_array_elements(category->'competencies') loop
      insert into public.assessment_competencies(category_id, configuration_id, name, sort_order)
      values (v_category_id, saved.id, btrim(competency->>'name'),
        coalesce((competency->>'sort_order')::integer, 0))
      returning id into v_competency_id;
      insert into public.assessment_configuration_competencies(configuration_id, competency_id, sort_order)
      values (saved.id, v_competency_id, coalesce((competency->>'sort_order')::integer, 0));
    end loop;
  end loop;

  for period in select value from jsonb_array_elements(payload->'periods') loop
    if jsonb_typeof(period) <> 'object'
      or not (period ?& array['name','ordinal','academic_year','starts_on','ends_on',
        'entry_closes_at','family_release_at']) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    if not exists (select 1 from pg_catalog.pg_timezone_names z
      where z.name = coalesce(nullif(period->>'timezone',''), 'America/Sao_Paulo')) then
      raise invalid_parameter_value using detail = 'ASSESSMENT_INVALID_INPUT';
    end if;
    insert into public.assessment_periods(
      configuration_id, institution_id, unit_id, name, periodicity, ordinal,
      academic_year, starts_on, ends_on, entry_closes_at, family_release_at,
      timezone, status)
    values (saved.id, saved.institution_id, saved.unit_id, btrim(period->>'name'),
      saved.periodicity, (period->>'ordinal')::smallint, (period->>'academic_year')::integer,
      (period->>'starts_on')::date, (period->>'ends_on')::date,
      (period->>'entry_closes_at')::timestamptz, (period->>'family_release_at')::timestamptz,
      coalesce(nullif(period->>'timezone',''), 'America/Sao_Paulo'), 'draft');
  end loop;
  return app_private.assessment_v2_finish(ctx, request_id, saved.institution_id,
    saved.id, 'configuration.save', request_hash, saved.management_version,
    saved.status, null);
end $$;

create function pg_temp.r11_original_error() returns text language plpgsql as $$
declare v_state text; v_constraint text;
begin
  perform app_private.assessment_v2_save_configuration(gen_random_uuid(),
    (select (body#>>'{data,id}')::uuid from r11_draft),1,
    (select value from r11_payload));
  return 'UNEXPECTED_SUCCESS';
exception when others then
  get stacked diagnostics v_state = returned_sqlstate, v_constraint = constraint_name;
  return v_state || ':' || coalesce(v_constraint,'');
end $$;
select alike(pg_temp.r11_original_error(), '23503:%', 'original update fails on a foreign key of another configuration');
select pg_temp.r11_original_error() as sanitized_local_sqlstate;
select * from finish(); rollback;
