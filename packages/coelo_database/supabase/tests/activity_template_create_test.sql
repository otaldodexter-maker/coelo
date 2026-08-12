begin;
select plan(20);

select has_function(
  'public', 'superadmin_create_activity_template',
  array['uuid', 'text', 'text', 'uuid', 'text', 'uuid'],
  'institution template create RPC exists'
);
select function_privs_are(
  'public', 'superadmin_create_activity_template',
  array['uuid', 'text', 'text', 'uuid', 'text', 'uuid'],
  'authenticated', array['EXECUTE'],
  'authenticated receives only RPC execution privilege'
);
select function_privs_are(
  'public', 'superadmin_create_activity_template',
  array['uuid', 'text', 'text', 'uuid', 'text', 'uuid'],
  'anon', array[]::text[],
  'anon cannot execute template create RPC'
);
select table_privs_are(
  'public', 'activity_templates', 'authenticated', array['SELECT'],
  'authenticated cannot mutate templates directly'
);
select ok(
  pg_get_functiondef(
    'app_private.superadmin_create_activity_template(uuid,text,text,uuid,text,uuid)'::regprocedure
  ) like '%activities.templates.manage%'
  and pg_get_functiondef(
    'app_private.superadmin_create_activity_template(uuid,text,text,uuid,text,uuid)'::regprocedure
  ) like '%has_mfa_aal2%',
  'private command recalculates capability and AAL2'
);
select ok(
  pg_get_functiondef(
    'app_private.superadmin_create_activity_template(uuid,text,text,uuid,text,uuid)'::regprocedure
  ) like '%taxonomy_kind = ''subtype''%'
  and pg_get_functiondef(
    'app_private.superadmin_create_activity_template(uuid,text,text,uuid,text,uuid)'::regprocedure
  ) like '%status = ''active''%',
  'private command validates an active subtype'
);

create or replace function app_private.current_person_id()
returns uuid language sql stable security definer set search_path = ''
as $$select '33000000-0000-4000-8000-000000000001'::uuid$$;
create or replace function app_private.has_platform_permission(permission_code text)
returns boolean language sql stable security definer set search_path = ''
as $$select permission_code = 'activities.templates.manage'$$;
create or replace function app_private.has_mfa_aal2()
returns boolean language sql stable security definer set search_path = ''
as $$select true$$;

insert into public.people(id, person_type, first_name, last_name, display_name)
values (
  '33000000-0000-4000-8000-000000000001', 'adult',
  'Template', 'Creator', 'Template Creator'
);
insert into public.institutions(id, public_name, slug, status, created_by)
values (
  '33000000-0000-4000-8000-000000000002',
  'Template Creator Institution', 'template-creator-institution', 'active',
  '33000000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '33000000-0000-4000-8000-000000000099', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"33000000-0000-4000-8000-000000000099","aal":"aal2","role":"authenticated"}',
  true
);

select lives_ok(
  $call$
    select public.superadmin_create_activity_template(
      '33000000-0000-4000-8000-000000000002',
      '  Física avançada  ', '  Modelo institucional editável.  ',
      (select id from public.activity_taxonomies where code = 'fisica'),
      'mandatory', '33000000-0000-4000-8000-000000000003'
    )
  $call$,
  'authorized AAL2 actor creates an institution template'
);
select results_eq(
  $$select count(*)::bigint from public.activity_templates
    where institution_id = '33000000-0000-4000-8000-000000000002'
      and name = 'Física avançada' and governance_kind = 'mandatory'$$,
  array[1::bigint],
  'command trims and persists allowlisted fields'
);
select results_eq(
  $$select count(*)::bigint from app_private.activity_template_create_receipts
    where request_id = '33000000-0000-4000-8000-000000000003'$$,
  array[1::bigint],
  'command persists one private idempotency receipt'
);
select results_eq(
  $$select count(*)::bigint from audit.audit_logs
    where action_code = 'activity.template.create'
      and institution_id = '33000000-0000-4000-8000-000000000002'$$,
  array[1::bigint],
  'command writes one successful audit event'
);
select results_eq(
  $$select public.superadmin_create_activity_template(
      '33000000-0000-4000-8000-000000000002',
      'Física avançada', 'Modelo institucional editável.',
      (select id from public.activity_taxonomies where code = 'fisica'),
      'mandatory', '33000000-0000-4000-8000-000000000003'
    )->>'id'$$,
  $$select id::text from public.activity_templates
    where institution_id = '33000000-0000-4000-8000-000000000002'
      and name = 'Física avançada'$$,
  'same normalized request returns the same template'
);
select results_eq(
  $$select count(*)::bigint from public.activity_templates
    where institution_id = '33000000-0000-4000-8000-000000000002'
      and name = 'Física avançada'$$,
  array[1::bigint],
  'idempotency replay does not duplicate the template'
);
select throws_ok(
  $call$
    select public.superadmin_create_activity_template(
      '33000000-0000-4000-8000-000000000002',
      'Outro nome', 'Modelo institucional editável.',
      (select id from public.activity_taxonomies where code = 'fisica'),
      'mandatory', '33000000-0000-4000-8000-000000000003'
    )
  $call$,
  '22023', 'idempotency key reused',
  'same key cannot be reused with a different payload'
);
select throws_ok(
  $call$
    select public.superadmin_create_activity_template(
      '33000000-0000-4000-8000-000000000002', '', '',
      (select id from public.activity_taxonomies where code = 'fisica'),
      'optional', '33000000-0000-4000-8000-000000000004'
    )
  $call$,
  '22023', 'invalid activity template request',
  'blank name is rejected server-side'
);
select throws_ok(
  $call$
    select public.superadmin_create_activity_template(
      '33000000-0000-4000-8000-000000000002', 'Categoria inválida', '',
      (select id from public.activity_taxonomies where code = 'ciencias-exatas'),
      'optional', '33000000-0000-4000-8000-000000000005'
    )
  $call$,
  '22023', 'invalid activity template request',
  'category cannot be substituted for a subtype'
);
select throws_ok(
  $call$
    select public.superadmin_create_activity_template(
      '33000000-0000-4000-8000-000000000002', 'Governança inválida', '',
      (select id from public.activity_taxonomies where code = 'fisica'),
      'fixed', '33000000-0000-4000-8000-000000000006'
    )
  $call$,
  '22023', 'invalid activity template request',
  'governance is allowlisted to optional or mandatory'
);
select throws_ok(
  $call$
    select public.superadmin_create_activity_template(
      '33000000-0000-4000-8000-000000000002', 'Governança ausente', '',
      (select id from public.activity_taxonomies where code = 'fisica'),
      null, '33000000-0000-4000-8000-000000000010'
    )
  $call$,
  '22023', 'invalid activity template request',
  'null governance is rejected by the command boundary'
);

reset role;
create or replace function app_private.has_platform_permission(permission_code text)
returns boolean language sql stable security definer set search_path = ''
as $$select false$$;
set local role authenticated;
select throws_ok(
  $call$
    select public.superadmin_create_activity_template(
      '33000000-0000-4000-8000-000000000002', 'Sem capability', '',
      (select id from public.activity_taxonomies where code = 'fisica'),
      'optional', '33000000-0000-4000-8000-000000000007'
    )
  $call$,
  '42501', 'activities.templates.manage required',
  'authenticated actor without capability is denied'
);
reset role;
create or replace function app_private.has_platform_permission(permission_code text)
returns boolean language sql stable security definer set search_path = ''
as $$select permission_code = 'activities.templates.manage'$$;
create or replace function app_private.has_mfa_aal2()
returns boolean language sql stable security definer set search_path = ''
as $$select false$$;
set local role authenticated;
select throws_ok(
  $call$
    select public.superadmin_create_activity_template(
      '33000000-0000-4000-8000-000000000002', 'Sem MFA', '',
      (select id from public.activity_taxonomies where code = 'fisica'),
      'optional', '33000000-0000-4000-8000-000000000008'
    )
  $call$,
  '42501', 'MFA AAL2 required',
  'AAL1 actor is denied'
);
reset role;
set local role anon;
select throws_ok(
  $call$
    select public.superadmin_create_activity_template(
      '33000000-0000-4000-8000-000000000002', 'Anon', '',
      (select id from public.activity_taxonomies where code = 'fisica'),
      'optional', '33000000-0000-4000-8000-000000000009'
    )
  $call$,
  '42501', null,
  'anon cannot invoke the template create RPC'
);
reset role;

select * from finish();
rollback;
