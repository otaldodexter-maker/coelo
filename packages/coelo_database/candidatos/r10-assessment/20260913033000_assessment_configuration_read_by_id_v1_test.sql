begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

select has_function(
  'public', 'superadmin_assessment_configuration_read_by_id', array['uuid'],
  'configuration read-by-id RPC exists'
);
select function_privs_are(
  'public', 'superadmin_assessment_configuration_read_by_id', array['uuid'],
  'anon', array[]::text[], 'anon cannot execute configuration read-by-id'
);
select function_privs_are(
  'public', 'superadmin_assessment_configuration_read_by_id', array['uuid'],
  'authenticated', array['EXECUTE']::text[], 'authenticated can execute configuration read-by-id'
);
select ok(
  pg_get_functiondef('public.superadmin_assessment_configuration_read_by_id(uuid)'::regprocedure)
    like '%assessment_v2_require_context(''activities.read'', null)%'
  and pg_get_functiondef('public.superadmin_assessment_configuration_read_by_id(uuid)'::regprocedure)
    like '%assessment_v2_require_context(''activities.read'', target_institution)%',
  'read-by-id authenticates globally and reauthorizes the configuration institution'
);
select ok(
  pg_get_functiondef('public.superadmin_assessment_configuration_read_by_id(uuid)'::regprocedure)
    like '%assessment_v2_configuration_snapshot(target_configuration)%'
  and pg_get_functiondef('public.superadmin_assessment_configuration_read_by_id(uuid)'::regprocedure)
    not like '%superadmin_assessment_configuration_read(%',
  'read-by-id returns the requested snapshot and does not fall back to activity/unit selection'
);

-- Isola o contrato de autorizacao do gateway: a fixture nao usa dados remotos
-- e o helper temporario desaparece no rollback.
set local session_replication_role = replica;
insert into public.activity_assessment_configurations(
  id, activity_id, institution_id, periodicity, result_scale_kind, scale_options, status
) values (
  'a9100000-0000-4000-8000-000000000001',
  'a9100000-0000-4000-8000-000000000011',
  'a9100000-0000-4000-8000-000000000021',
  'annual', 'numeric_0_10', '{}'::jsonb, 'draft'
);
set local session_replication_role = origin;

create or replace function app_private.assessment_v2_require_context(
  p_permission_code text, p_institution_id uuid default null
) returns app_private.superadmin_internal_context
language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('test.r10_assessment_allow', true) <> 'true' then
    raise insufficient_privilege using message = 'assessment access denied', detail = 'SAI_PERMISSION_DENIED';
  end if;
  return (
    'a9100000-0000-4000-8000-000000000031'::uuid,
    'a9100000-0000-4000-8000-000000000032'::uuid,
    'a9100000-0000-4000-8000-000000000033'::uuid,
    'a9100000-0000-4000-8000-000000000034'::uuid,
    'a9100000-0000-4000-8000-000000000035'::uuid,
    'a9100000-0000-4000-8000-000000000036'::uuid,
    'owner', 'institution', current_setting('test.r10_assessment_scope', true)::uuid,
    p_institution_id, 'aal1', p_permission_code, false
  )::app_private.superadmin_internal_context;
end $$;

select set_config('test.r10_assessment_allow', 'true', true);
select set_config('test.r10_assessment_scope', 'a9100000-0000-4000-8000-000000000021', true);
select is(
  public.superadmin_assessment_configuration_read_by_id('a9100000-0000-4000-8000-000000000001')#>>'{data,configuration,id}',
  'a9100000-0000-4000-8000-000000000001', 'authorized institution reader receives only its requested snapshot'
);
select set_config('test.r10_assessment_scope', 'a9100000-0000-4000-8000-000000000022', true);
select is(
  public.superadmin_assessment_configuration_read_by_id('a9100000-0000-4000-8000-000000000001'),
  public.superadmin_assessment_configuration_read_by_id('a9100000-0000-4000-8000-0000000000ff'),
  'foreign-tenant and nonexistent configuration IDs return the same opaque response'
);
select set_config('test.r10_assessment_allow', 'false', true);
select ok(
  public.superadmin_assessment_configuration_read_by_id('a9100000-0000-4000-8000-000000000001')->'data' = 'null'::jsonb,
  'actor without activities.read receives no configuration snapshot'
);

select * from finish();
rollback;
