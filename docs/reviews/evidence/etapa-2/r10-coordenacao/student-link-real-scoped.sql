-- Real scoped permission helper, role, permission and institution membership. Current person/context resolver controlled only inside rollback.
begin;
-- Adapter scoped to Turmas: delegates the actual write to the canonical
-- student-link command, which retains its authorization, hierarchy, receipt,
-- and audit guarantees. It never creates an institutional membership.
create or replace function public.superadmin_group_student_link(
  p_request_id uuid,
  p_person_id uuid,
  p_group_id uuid
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  resolved_child_context_id uuid;
  group_row public.groups%rowtype;
  receipt jsonb;
begin
  if p_request_id is null or p_person_id is null or p_group_id is null then
    raise invalid_parameter_value using message='group student link requires request, person, and group';
  end if;

  begin
    select * into group_row
    from public.groups
    where id=p_group_id and status='active';
    if group_row.id is null then
      raise no_data_found using message='student link unavailable';
    end if;

    select child_context.id into resolved_child_context_id
    from public.child_contexts child_context
    where child_context.child_person_id=p_person_id
      and child_context.institution_id=group_row.institution_id
      and child_context.status='active'
    order by child_context.created_at, child_context.id
    limit 1;
    if resolved_child_context_id is null then
      raise no_data_found using message='student link unavailable';
    end if;

    -- O comando canonico consulta recibo antes do escopo. O adaptador protege
    -- seu replay: valida a capacidade atual, serializa por contexto e aceita
    -- somente o recibo que pertence exatamente a esta crianca e turma.
    perform app_private.student_link_require_scope(
      resolved_child_context_id, group_row.unit_id, group_row.id
    );
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(resolved_child_context_id::text, 0)
    );
    receipt := app_private.student_link_receipt(p_request_id, actor, 'link');
    if receipt is not null then
      if not exists (
        select 1
        from public.child_group_links group_link
        join public.child_unit_links unit_link on unit_link.id=group_link.child_unit_link_id
        where group_link.id=(receipt->>'group_link_id')::uuid
          and group_link.group_id=group_row.id
          and unit_link.child_context_id=resolved_child_context_id
          and unit_link.unit_id=group_row.unit_id
      ) then
        raise invalid_parameter_value using message='request id reused for another link target';
      end if;
      return receipt;
    end if;

    return app_private.superadmin_student_link(
      p_request_id,
      resolved_child_context_id,
      jsonb_build_object('unit_id', group_row.unit_id, 'group_id', group_row.id)
    );
  exception when no_data_found or insufficient_privilege then
    -- Sem people.assign_children, grupo e crianca recebem a mesma negativa
    -- opaca. A escrita ainda so acontece pelo comando canonico autorizado.
    raise no_data_found using message='student link unavailable';
  end;
end
$$;

revoke all on function public.superadmin_group_student_link(uuid,uuid,uuid) from public, anon;
grant execute on function public.superadmin_group_student_link(uuid,uuid,uuid) to authenticated, service_role;


-- Read projection for Turmas. Student membership is contextual and therefore
-- never appears in effective_access, which is reserved for institutional roles.
create or replace function app_private.superadmin_group_students_payload(
  p_group_id uuid
) returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'child_context_id', child_context.id,
    'person_id', child_person.id,
    'display_name', child_person.display_name,
    'status', group_link.status
  ) order by child_person.display_name, child_context.id), '[]'::jsonb)
  from public.groups group_row
  join public.child_group_links group_link
    on group_link.group_id=group_row.id and group_link.status='active'
  join public.child_unit_links unit_link
    on unit_link.id=group_link.child_unit_link_id
    and unit_link.status='active' and unit_link.unit_id=group_row.unit_id
  join public.child_contexts child_context
    on child_context.id=unit_link.child_context_id
    and child_context.status='active'
    and child_context.institution_id=group_row.institution_id
  join public.people child_person
    on child_person.id=child_context.child_person_id and child_person.status='active'
  where group_row.id=p_group_id and group_row.status='active'
$$;

-- Both public entry points already authorize before their private command. The
-- projection remains app_private and cannot be called by a client directly.
create or replace function public.superadmin_group_get(p_group_id uuid)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select app_private.superadmin_group_get(p_group_id)
    || jsonb_build_object('students', app_private.superadmin_group_students_payload(p_group_id))
$$;

create or replace function public.superadmin_group_save(
  p_request_id uuid, p_group_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb
language sql
volatile
security definer
set search_path=''
as $$
  with saved as (
    select app_private.superadmin_group_save(
      p_request_id, p_group_id, p_expected_version, p_payload
    ) as value
  )
  select value || jsonb_build_object(
    'students', app_private.superadmin_group_students_payload((value->>'id')::uuid)
  ) from saved
$$;

revoke all on function app_private.superadmin_group_students_payload(uuid) from public, anon, authenticated;
revoke all on function public.superadmin_group_get(uuid) from public, anon;
grant execute on function public.superadmin_group_get(uuid) to authenticated;
revoke all on function public.superadmin_group_save(uuid,uuid,bigint,jsonb) from public, anon;
grant execute on function public.superadmin_group_save(uuid,uuid,bigint,jsonb) to authenticated;


-- Desvincula uma crianca de uma unica turma. O vinculo com a unidade e as
-- demais turmas ficam ativos; para estes ha comandos canonicos distintos.
create or replace function public.superadmin_group_student_unlink(
  p_request_id uuid,
  p_child_context_id uuid,
  p_group_id uuid
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  institution uuid;
  group_row public.groups%rowtype;
  target_group_link public.child_group_links%rowtype;
  before_state jsonb;
  response jsonb;
begin
  if p_group_id is null or p_child_context_id is null then
    raise invalid_parameter_value using message='group student unlink requires request, child context, and group';
  end if;

  select * into group_row
  from public.groups
  where id = p_group_id and status = 'active';
  if group_row.id is null then
    raise no_data_found using message='student link unavailable';
  end if;

  institution := app_private.student_link_require_scope(
    p_child_context_id, group_row.unit_id, group_row.id
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_child_context_id::text, 0)
  );
  -- Um replay precisa passar pela autorizacao atual. O recibo tambem e preso
  -- ao contexto e turma, para que o mesmo request id nao aceite outro alvo.
  response := app_private.student_link_receipt(p_request_id, actor, 'unlink');
  if response is not null then
    if response->>'child_context_id' is distinct from p_child_context_id::text
      or response->>'group_id' is distinct from p_group_id::text then
      raise invalid_parameter_value using message='request id reused for another unlink target';
    end if;
    return response;
  end if;
  select child_group_link_row.* into target_group_link
  from public.child_group_links child_group_link_row
  join public.child_unit_links unit_link on unit_link.id = child_group_link_row.child_unit_link_id
  where child_group_link_row.group_id = group_row.id
    and child_group_link_row.status = 'active'
    and unit_link.child_context_id = p_child_context_id
    and unit_link.unit_id = group_row.unit_id
    and unit_link.status = 'active'
  for update of child_group_link_row;
  if target_group_link.id is null then
    raise no_data_found using message='student link unavailable';
  end if;

  before_state := to_jsonb(target_group_link);
  update public.child_group_links set
    status = 'inactive',
    ends_at = coalesce(ends_at, now()),
    updated_at = now()
  where id = target_group_link.id
  returning * into target_group_link;

  response := jsonb_build_object(
    'child_context_id', p_child_context_id,
    'unit_link_id', target_group_link.child_unit_link_id,
    'group_link_id', target_group_link.id,
    'group_id', group_row.id,
    'status', target_group_link.status
  );
  insert into app_private.student_link_command_receipts
    values (p_request_id, actor, 'unlink', target_group_link.id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, before_json, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'student.unlink', 'child_group_link', target_group_link.id,
    institution, 'success', before_state, response
  );
  return response;
end
$$;

revoke all on function public.superadmin_group_student_unlink(uuid,uuid,uuid)
  from public, anon;
grant execute on function public.superadmin_group_student_unlink(uuid,uuid,uuid)
  to authenticated, service_role;


-- R10 assessments: reload an explicitly selected configuration without
-- changing the activity/unit reader consumed by daily assessment flows.
create or replace function public.superadmin_assessment_configuration_read_by_id(
  target_configuration uuid
) returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  ctx app_private.superadmin_internal_context;
  correlation uuid := gen_random_uuid();
  target_institution uuid;
  result jsonb;
  code text;
begin
  begin
    select * into strict ctx
    from app_private.assessment_v2_require_context('activities.read', null);
    select c.institution_id into target_institution
    from public.activity_assessment_configurations c
    where c.id = target_configuration
      and (ctx.scope_kind <> 'institution' or c.institution_id = ctx.scope_institution_id);
    if target_institution is null then return app_private.assessment_v2_ok(null); end if;
    select * into strict ctx
    from app_private.assessment_v2_require_context('activities.read', target_institution);
    result := app_private.assessment_v2_configuration_snapshot(target_configuration);
    return app_private.assessment_v2_ok(result);
  exception when others then get stacked diagnostics code = pg_exception_detail; end;
  return app_private.assessment_v2_denied(
    'activities.read', 'assessment.configuration.read_by_id',
    coalesce(nullif(code, ''), 'SAI_INTERNAL_ERROR'), correlation, target_institution
  );
end $$;

alter function public.superadmin_assessment_configuration_read_by_id(uuid) owner to postgres;
revoke all on function public.superadmin_assessment_configuration_read_by_id(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_assessment_configuration_read_by_id(uuid) to authenticated;


-- R10 chat video: private MP4 only, same 10 MiB ceiling as Chat PDF.
-- No bucket, credential, retention, permission or read-path change.
create or replace function app_private.chat_attachment_limit_v1(p_content_type text)
returns bigint language sql immutable security invoker set search_path='' as $$
  select case p_content_type
    when 'image/jpeg' then 4194304::bigint
    when 'image/png' then 4194304::bigint
    when 'image/webp' then 4194304::bigint
    when 'application/pdf' then 10485760::bigint
    when 'video/mp4' then 10485760::bigint
    else null end
$$;
create or replace function app_private.chat_attachment_extension_v1(p_content_type text)
returns text language sql immutable security invoker set search_path='' as $$
  select case p_content_type
    when 'image/jpeg' then 'jpg' when 'image/png' then 'png'
    when 'image/webp' then 'webp' when 'application/pdf' then 'pdf'
    when 'video/mp4' then 'mp4' end
$$;
alter function app_private.chat_attachment_limit_v1(text) owner to postgres;
alter function app_private.chat_attachment_extension_v1(text) owner to postgres;
revoke all on function app_private.chat_attachment_limit_v1(text),
  app_private.chat_attachment_extension_v1(text) from public, anon, authenticated, service_role;

-- The internal Superadmin service person has a platform role rather than an
-- institution membership. Keep institution-scoped actors authorized by their
-- contextual role, and let a platform role act only inside its granted scope.
create or replace function app_private.student_link_require_scope(
  p_child_context_id uuid,
  p_unit_id uuid,
  p_group_id uuid
) returns uuid
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  institution uuid;
begin
  if actor is null then
    raise insufficient_privilege using message='authentication required';
  end if;
  select child_row.institution_id into institution
  from public.child_contexts child_row
  where child_row.id = p_child_context_id
    and child_row.status = 'active';
  if institution is null then
    raise no_data_found using message='student link unavailable';
  end if;
  if not (
    app_private.has_scoped_platform_permission('people.assign_children', institution)
    or app_private.has_context_permission(
      institution, 'people.assign_children', p_unit_id, p_group_id, null,
      p_child_context_id, false
    )
  ) then
    raise insufficient_privilege using message='people.assign_children required';
  end if;
  if p_unit_id is not null and not exists (
    select 1 from public.units unit_row
    where unit_row.id = p_unit_id and unit_row.institution_id = institution
  ) then
    raise no_data_found using message='student link unavailable';
  end if;
  if p_group_id is not null and not exists (
    select 1 from public.groups group_row
    where group_row.id = p_group_id
      and group_row.unit_id = p_unit_id
      and group_row.institution_id = institution
  ) then
    raise no_data_found using message='student link unavailable';
  end if;
  return institution;
end
$$;


create extension if not exists pgtap with schema extensions;
select plan(23);

select ok(
  pg_get_functiondef('app_private.student_link_require_scope(uuid,uuid,uuid)'::regprocedure)
    like '%has_scoped_platform_permission(''people.assign_children'', institution)%'
  and pg_get_functiondef('app_private.student_link_require_scope(uuid,uuid,uuid)'::regprocedure)
    like '%or app_private.has_context_permission(%',
  'student-link gate keeps contextual authorization and adds a scoped platform path'
);

select has_function(
  'public','superadmin_group_student_link',array['uuid','uuid','uuid'],
  'Turmas exposes a scoped student-link adapter'
);
select ok(
  not has_function_privilege('anon','public.superadmin_group_student_link(uuid,uuid,uuid)','EXECUTE')
  and has_function_privilege('authenticated','public.superadmin_group_student_link(uuid,uuid,uuid)','EXECUTE'),
  'only authenticated sessions can call the adapter'
);
select ok(
  pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    like '%app_private.superadmin_student_link(%',
  'the adapter delegates the write to the canonical student command'
);
select ok(
  pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    like '%child_context.child_person_id=p_person_id%'
  and pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    like '%child_context.institution_id=group_row.institution_id%',
  'the child context is resolved only inside the group institution'
);
select ok(
  pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    like '%where id=p_group_id and status=''active''%',
  'inactive or foreign group IDs do not become allocation targets'
);
select ok(
  pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    not like '%institution_memberships%'
  and pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    not like '%institution_role_assignments%',
  'student allocation never manufactures a professional membership or profile'
);
select ok(
  pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    not like '%guardian_links%'
  and pg_get_functiondef('public.superadmin_group_student_link(uuid,uuid,uuid)'::regprocedure)
    not like '%guardian_context_permissions%',
  'guardian access remains derived and is not written as a group membership'
);

-- Fixture minima: o adaptador recebe uma crianca real em um contexto ativo e
-- delega a escrita para o comando que cria child_unit_links e child_group_links.
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('f6100000-0000-4000-8000-000000000001','adult','R10','Actor','R10 actor','active'),
  ('f6100000-0000-4000-8000-000000000002','child','R10','Child','R10 child','active'),
  ('f6100000-0000-4000-8000-000000000003','child','R10','Foreign','R10 foreign child','active'),
  ('f6100000-0000-4000-8000-000000000004','child','R10','Other','R10 other child','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('f6200000-0000-4000-8000-000000000001','R10 Institution A','R10 Institution A','r10-members-a','active'),
  ('f6200000-0000-4000-8000-000000000002','R10 Institution B','R10 Institution B','r10-members-b','active');
insert into public.unit_types(id,code,name,status) values
  ('f6250000-0000-4000-8000-000000000001','r10-members-unit','R10 members unit','active');
insert into public.units(id,institution_id,name,slug,status,unit_type_id,handle) values
  ('f6300000-0000-4000-8000-000000000001','f6200000-0000-4000-8000-000000000001','R10 Unit A','r10-members-unit-a','active','f6250000-0000-4000-8000-000000000001','r10.members.unit.a'),
  ('f6300000-0000-4000-8000-000000000002','f6200000-0000-4000-8000-000000000002','R10 Unit B','r10-members-unit-b','active','f6250000-0000-4000-8000-000000000001','r10.members.unit.b');
insert into public.groups(id,institution_id,unit_id,name,handle,status) values
  ('f6400000-0000-4000-8000-000000000001','f6200000-0000-4000-8000-000000000001','f6300000-0000-4000-8000-000000000001','R10 Group A','r10.group.a','active'),
  ('f6400000-0000-4000-8000-000000000002','f6200000-0000-4000-8000-000000000002','f6300000-0000-4000-8000-000000000002','R10 Group B','r10.group.b','active');
insert into public.child_contexts(id,child_person_id,institution_id,status) values
  ('f6500000-0000-4000-8000-000000000001','f6100000-0000-4000-8000-000000000002','f6200000-0000-4000-8000-000000000001','active'),
  ('f6500000-0000-4000-8000-000000000002','f6100000-0000-4000-8000-000000000003','f6200000-0000-4000-8000-000000000002','active'),
  ('f6500000-0000-4000-8000-000000000003','f6100000-0000-4000-8000-000000000004','f6200000-0000-4000-8000-000000000001','active');
insert into public.child_unit_links(id,child_context_id,unit_id,status) values
  ('f6550000-0000-4000-8000-000000000001','f6500000-0000-4000-8000-000000000001','f6300000-0000-4000-8000-000000000001','pending');

-- Sobrescritas locais exercitam o comando autenticado com e sem a capacidade,
-- sem enfraquecer helpers fora desta transacao.
create or replace function app_private.current_person_id() returns uuid
language sql stable security definer set search_path='' as $$
  select 'f6100000-0000-4000-8000-000000000001'::uuid
$$;
create or replace function app_private.has_context_permission(
  target_institution_id uuid, target_permission_code text, target_unit_id uuid default null,
  target_group_id uuid default null, target_activity_id uuid default null,
  target_child_context_id uuid default null, require_institution_scope boolean default false
) returns boolean language sql stable security definer set search_path='' as $$
  select target_permission_code = 'people.assign_children'
    and current_setting('test.r10_members_allow', true) = 'true'
$$;


select set_config('test.r10_members_allow','true',true);
set local role authenticated;
select lives_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000001',
    'f6100000-0000-4000-8000-000000000002',
    'f6400000-0000-4000-8000-000000000001')$$,
  'active child context creates the canonical group link'
);
reset role;
select ok(exists(
  select 1 from public.child_group_links group_link
  join public.child_unit_links unit_link on unit_link.id=group_link.child_unit_link_id
  where group_link.group_id='f6400000-0000-4000-8000-000000000001'
    and group_link.status='active' and unit_link.status='active'
    and unit_link.child_context_id='f6500000-0000-4000-8000-000000000001'
), 'positive write persists active child_unit_link and child_group_link');
select is(
  (select status::text from public.child_unit_links
   where id='f6550000-0000-4000-8000-000000000001'),
  'active',
  'canonical link activates the pending unit link before creating the group link'
);
select is(
  (select count(*)::integer from public.child_unit_links
   where child_context_id='f6500000-0000-4000-8000-000000000001'
     and unit_id='f6300000-0000-4000-8000-000000000001'),
  1,
  'canonical link reuses the pending unit link without duplication'
);

-- A platform grant is scoped to the child context institution. It is an
-- additional path, never a global bypass of the contextual authorization.
set local role authenticated;
select set_config('test.r10_members_allow','false',true);
reset role;
insert into public.platform_roles(id,code,name,status,max_scope_kind) values ('f6700000-0000-4000-8000-000000000001','r10-scoped-proof','R10 scoped proof','active','institution');
insert into public.platform_role_permissions(role_id,permission_id) select 'f6700000-0000-4000-8000-000000000001',id from public.platform_permissions where code='people.assign_children';
insert into public.platform_memberships(id,person_id,role_id,status,scope_kind,scope_institution_id) values ('f6800000-0000-4000-8000-000000000001','f6100000-0000-4000-8000-000000000001','f6700000-0000-4000-8000-000000000001','active','institution','f6200000-0000-4000-8000-000000000001');
set local role authenticated;
select lives_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000010',
    'f6100000-0000-4000-8000-000000000004',
    'f6400000-0000-4000-8000-000000000001')$$,
  'platform actor scoped to institution A can link a child in institution A'
);
select throws_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000011',
    'f6100000-0000-4000-8000-000000000003',
    'f6400000-0000-4000-8000-000000000002')$$,
  'P0002','student link unavailable','platform actor scoped to institution A cannot link a child in institution B'
);
reset role;
select is(
  (select count(*)::integer from public.child_group_links
   where group_id='f6400000-0000-4000-8000-000000000001' and status='active'),
  2,
  'platform-scoped link creates only the authorized group A link'
);

set local role authenticated;
reset role;
update public.platform_memberships set revoked_at=now() where id='f6800000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('test.r10_members_allow','false',true);
select throws_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000001',
    'f6100000-0000-4000-8000-000000000002',
    'f6400000-0000-4000-8000-000000000001')$$,
  'P0002','student link unavailable','link receipt replay requires current capability'
);
select set_config('test.r10_members_allow','true',true);
select throws_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000001',
    'f6100000-0000-4000-8000-000000000004',
    'f6400000-0000-4000-8000-000000000001')$$,
  '22023','request id reused for another link target','link receipt cannot be replayed for another child'
);
select throws_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000002',
    'f6100000-0000-4000-8000-000000000003',
    'f6400000-0000-4000-8000-000000000001')$$,
  'P0002','student link unavailable','cross-tenant child cannot be linked to group A'
);
select throws_ok(
  $$select public.superadmin_student_link(
    'f6600000-0000-4000-8000-000000000003',
    'f6500000-0000-4000-8000-000000000001',
    jsonb_build_object('unit_id','f6300000-0000-4000-8000-000000000002','group_id','f6400000-0000-4000-8000-000000000002'))$$,
  'P0002','student link unavailable','canonical delegation rejects an invalid unit/group hierarchy'
);
select set_config('test.r10_members_allow','false',true);
select throws_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000004',
    'f6100000-0000-4000-8000-000000000002',
    'f6400000-0000-4000-8000-000000000001')$$,
  'P0002','student link unavailable','missing capability receives the same opaque denial'
);
select throws_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000005',
    'f6100000-0000-4000-8000-000000000002',
    'f6400000-0000-4000-8000-000000000099')$$,
  'P0002','student link unavailable','missing capability cannot distinguish a nonexistent group'
);
select throws_ok(
  $$select public.superadmin_group_student_link(
    'f6600000-0000-4000-8000-000000000006',
    'f6100000-0000-4000-8000-000000000003',
    'f6400000-0000-4000-8000-000000000001')$$,
  'P0002','student link unavailable','missing capability cannot distinguish a cross-tenant child'
);
reset role;
select is((select count(*)::integer from public.child_group_links),2,
  'negative paths create no cross-tenant, invalid-hierarchy, or unauthorized group link');

select * from finish();
rollback;
