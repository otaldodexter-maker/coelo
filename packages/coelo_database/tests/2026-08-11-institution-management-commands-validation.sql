-- Transactional behavior validation for Superadmin institution commands.
-- All synthetic records are rolled back and use reserved invalid domains.

begin;

do $$
#variable_conflict use_variable
declare
  owner_person_id uuid;
  owner_auth_id uuid := gen_random_uuid();
  operations_person_id uuid;
  operations_auth_id uuid := gen_random_uuid();
  editor_person_id uuid;
  editor_auth_id uuid := gen_random_uuid();
  denied_person_id uuid;
  denied_auth_id uuid := gen_random_uuid();
  editor_membership_id uuid;
  institution_id uuid;
  other_institution_id uuid;
  other_institution_version bigint;
  initial_version bigint;
  updated_version bigint;
  create_request_id uuid := gen_random_uuid();
  update_request_id uuid := gen_random_uuid();
  child_update_request_id uuid := gen_random_uuid();
  result jsonb;
  replay jsonb;
  create_payload jsonb;
  original_name text;
  before_count bigint;
  audit_count bigint;
  rejected boolean;
  observed_state text;
begin
  insert into auth.users(id, aud, role, email, created_at, updated_at)
  values
    (
      owner_auth_id, 'authenticated', 'authenticated',
      'owner-institution-command@example.invalid', now(), now()
    ),
    (
      operations_auth_id, 'authenticated', 'authenticated',
      'operations-institution-command@example.invalid', now(), now()
    ),
    (
      editor_auth_id, 'authenticated', 'authenticated',
      'editor-institution-command@example.invalid', now(), now()
    ),
    (
      denied_auth_id, 'authenticated', 'authenticated',
      'denied-institution-command@example.invalid', now(), now()
    );

  insert into public.people(
    person_type, first_name, last_name, display_name, status
  )
  values ('adult', 'Owner', 'Instituicoes', 'Owner Instituicoes', 'active')
  returning id into owner_person_id;

  insert into public.people(
    person_type, first_name, last_name, display_name, status
  )
  values (
    'adult', 'Operations', 'Instituicoes', 'Operations Instituicoes', 'active'
  )
  returning id into operations_person_id;

  insert into public.people(
    person_type, first_name, last_name, display_name, status
  )
  values ('adult', 'Editor', 'Instituicoes', 'Editor Instituicoes', 'active')
  returning id into editor_person_id;

  insert into public.people(
    person_type, first_name, last_name, display_name, status
  )
  values ('adult', 'Denied', 'Instituicoes', 'Denied Instituicoes', 'active')
  returning id into denied_person_id;

  insert into public.person_auth_links(person_id, auth_user_id)
  values
    (owner_person_id, owner_auth_id),
    (operations_person_id, operations_auth_id),
    (editor_person_id, editor_auth_id),
    (denied_person_id, denied_auth_id);

  insert into public.platform_memberships(person_id, role_id, status)
  select owner_person_id, id, 'active'
  from public.platform_roles where code = 'owner';

  insert into public.platform_memberships(person_id, role_id, status)
  select operations_person_id, id, 'active'
  from public.platform_roles where code = 'operations';

  insert into public.platform_memberships(person_id, role_id, status)
  select editor_person_id, id, 'active'
  from public.platform_roles where code = 'content'
  returning id into editor_membership_id;

  insert into public.platform_memberships(person_id, role_id, status)
  select denied_person_id, id, 'active'
  from public.platform_roles where code = 'content';

  insert into public.platform_member_permission_overrides(
    membership_id, permission_id, effect, status
  )
  select editor_membership_id, permission_record.id, 'allow', 'active'
  from public.platform_permissions permission_record
  where permission_record.code in (
    'platform.read', 'institution.update', 'institution.activate'
  );

  insert into public.institution_types(code, name, status)
  values ('institution-command-school', 'Escola de teste de comandos', 'active');

  insert into public.plans(code, name, status)
  values
    ('institution-command-basic', 'Plano Basico de Teste', 'active'),
    ('institution-command-plus', 'Plano Plus de Teste', 'active');

  execute 'set local role anon';
  begin
    perform public.get_institution_for_superadmin(gen_random_uuid());
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  if not rejected then
    raise exception 'anon executed institution read RPC';
  end if;

  execute 'reset role';
  perform set_config('request.jwt.claim.sub', denied_auth_id::text, true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', denied_auth_id, 'aal', 'aal2')::text,
    true
  );
  execute 'set local role authenticated';
  begin
    perform public.get_institution_for_superadmin(gen_random_uuid());
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  if not rejected then
    raise exception 'permission denial happened after institution lookup';
  end if;

  execute 'reset role';
  perform set_config('request.jwt.claim.sub', operations_auth_id::text, true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', operations_auth_id, 'aal', 'aal1')::text,
    true
  );
  execute 'set local role authenticated';
  begin
    perform public.create_institution_for_superadmin(
      gen_random_uuid(),
      jsonb_build_object(
        'public_name', 'MFA negado',
        'slug', 'institution-command-mfa-denied',
        'institution_type_name', 'Escola de teste de comandos'
      )
    );
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  if not rejected then
    raise exception 'AAL1 created an institution';
  end if;

  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', operations_auth_id, 'aal', 'aal2')::text,
    true
  );

  create_payload := jsonb_build_object(
    'public_name', 'Instituicao Comando',
    'trade_name', '',
    'legal_name', 'Instituicao Comando LTDA',
    'slug', 'institution-command-created',
    'primary_domain', '',
    'document_ref', 'synthetic-document-value',
    'document_type', 'cnpj',
    'status', 'draft',
    'timezone', 'America/Sao_Paulo',
    'locale', 'pt-BR',
    'institution_type_name', 'Escola de teste de comandos',
    'address', jsonb_build_object(
      'country', 'BR', 'state', 'SP', 'city', 'Sao Paulo',
      'district', 'Centro', 'street', 'Rua Transacional',
      'number', '10', 'complement', '', 'postal_code', '01000-000'
    ),
    'contact', jsonb_build_object(
      'email', 'institution-command@example.invalid',
      'phone', '', 'mobile_phone', '', 'website_url', '',
      'whatsapp_number', ''
    ),
    'branding', jsonb_build_object(
      'display_name', '', 'accent_color', '#D63C00',
      'secondary_color', '#3F4549', 'tertiary_color', null,
      'text_color', '#FFFFFF', 'secondary_text_color', null,
      'tertiary_text_color', null, 'surface_color', '#FFFFFF',
      'approval_status', 'draft', 'profile_bio', '',
      'profile_links', jsonb_build_array()
    ),
    'subscription', jsonb_build_object(
      'plan_code', 'institution-command-basic', 'status', 'trial',
      'starts_at', '2026-08-11T00:00:00Z',
      'trial_ends_at', '2026-09-11T00:00:00Z',
      'manual_reason', 'synthetic setup',
      'paused_at', null, 'cancelled_at', null
    )
  );

  result := public.create_institution_for_superadmin(
    create_request_id, create_payload
  );
  institution_id := (result ->> 'id')::uuid;
  initial_version := (result ->> 'management_version')::bigint;

  if initial_version <> 1
     or result -> 'institution_type' ->> 'name'
          <> 'Escola de teste de comandos'
     or result -> 'address' ->> 'city' <> 'Sao Paulo'
     or result -> 'contact' ->> 'email'
          <> 'institution-command@example.invalid'
     or result -> 'branding' ->> 'accent_color' <> '#D63C00'
     or result -> 'subscription' ->> 'plan_code'
          <> 'institution-command-basic'
     or result -> 'subscription' ->> 'plan_name'
          <> 'Plano Basico de Teste'
     or result -> 'subscription' ->> 'justification' <> 'synthetic setup'
     or result ->> 'trade_name' is not null
     or not (result ? 'updated_at') then
    raise exception 'create did not return the complete normalized record: %', result;
  end if;

  execute 'reset role';
  if (
       select count(*) from public.institutions institution_record
       where institution_record.id = institution_id
     ) <> 1
     or (
       select count(*) from public.institution_addresses address_record
       where address_record.institution_id = institution_id
     ) <> 1
     or (
       select count(*) from public.institution_contacts contact_record
       where contact_record.institution_id = institution_id
     ) <> 1
     or (
       select count(*) from public.institution_branding branding_record
       where branding_record.institution_id = institution_id
     ) <> 1
     or (
       select count(*) from public.institution_subscriptions subscription_record
       where subscription_record.institution_id = institution_id
     ) <> 1 then
    raise exception 'create was not atomic across the approved aggregate';
  end if;

  select count(*) into audit_count
  from audit.audit_logs
  where object_type = 'institution' and object_id = institution_id;

  execute 'set local role authenticated';
  replay := public.create_institution_for_superadmin(
    create_request_id, create_payload
  );
  if replay is distinct from result then
    raise exception 'identical create retry did not return receipt result';
  end if;

  execute 'reset role';
  perform set_config('request.jwt.claim.sub', owner_auth_id::text, true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', owner_auth_id, 'aal', 'aal2')::text,
    true
  );
  execute 'set local role authenticated';
  begin
    perform public.create_institution_for_superadmin(
      create_request_id, create_payload
    );
    rejected := false;
  exception when sqlstate '22023' then
    rejected := true;
  end;
  if not rejected then
    raise exception 'cross-actor create request_id reuse was accepted';
  end if;

  execute 'reset role';
  perform set_config('request.jwt.claim.sub', operations_auth_id::text, true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', operations_auth_id, 'aal', 'aal2')::text,
    true
  );

  if (
       select count(*) from public.institutions institution_record
       where institution_record.id = institution_id
     ) <> 1
     or (
       select count(*) from audit.audit_logs audit_record
       where audit_record.object_type = 'institution'
         and audit_record.object_id = institution_id
     ) <> audit_count then
    raise exception 'identical create retry repeated side effects';
  end if;

  execute 'set local role authenticated';
  begin
    perform public.create_institution_for_superadmin(
      create_request_id,
      create_payload || jsonb_build_object('public_name', 'Payload diferente')
    );
    rejected := false;
  exception when sqlstate '22023' then
    rejected := true;
  end;
  if not rejected then
    raise exception 'create request_id accepted a different payload';
  end if;

  execute 'reset role';
  select count(*) into before_count from public.institutions;
  execute 'set local role authenticated';
  begin
    perform public.create_institution_for_superadmin(
      gen_random_uuid(),
      create_payload || jsonb_build_object(
        'slug', 'institution-command-invalid-contact',
        'contact', jsonb_build_object('email', 'invalid-email')
      )
    );
    rejected := false;
  exception when sqlstate '22023' then
    rejected := true;
  end;
  if not rejected then
    raise exception 'invalid create payload was accepted';
  end if;
  execute 'reset role';
  if (select count(*) from public.institutions) <> before_count then
    raise exception 'failed create left a partial institution';
  end if;

  execute 'set local role authenticated';
  begin
    perform public.create_institution_for_superadmin(
      gen_random_uuid(), create_payload || jsonb_build_object('unknown', true)
    );
    rejected := false;
  exception when sqlstate '22023' then
    rejected := true;
  end;
  if not rejected then
    raise exception 'unknown create payload key was accepted';
  end if;

  execute 'set local role authenticated';
  begin
    perform public.create_institution_for_superadmin(
      gen_random_uuid(),
      create_payload || jsonb_build_object(
        'slug', 'institution-command-invalid-link',
        'branding', jsonb_build_object(
          'profile_links', jsonb_build_array(
            jsonb_build_object('label', 'Inseguro', 'url', 'javascript:alert(1)')
          )
        )
      )
    );
    rejected := false;
  exception when sqlstate '22023' then
    rejected := true;
  end;
  if not rejected then
    raise exception 'unsafe profile link was accepted';
  end if;

  result := public.create_institution_for_superadmin(
    gen_random_uuid(),
    create_payload || jsonb_build_object(
      'public_name', 'Instituicao Fora do Escopo',
      'slug', 'institution-command-other',
      'primary_domain', 'institution-command-other.example.invalid',
      'document_ref', 'institution-command-other-document',
      'address', jsonb_build_object(
        'country', 'BR',
        'state', 'RJ',
        'city', 'Rio de Janeiro'
      )
    )
  );
  other_institution_id := (result ->> 'id')::uuid;
  other_institution_version := (result ->> 'management_version')::bigint;

  execute 'reset role';
  update public.platform_memberships
  set scope_kind = 'institution',
      scope_institution_id = institution_id
  where id = editor_membership_id;

  perform set_config('request.jwt.claim.sub', editor_auth_id::text, true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', editor_auth_id, 'aal', 'aal2')::text,
    true
  );
  execute 'set local role authenticated';
  begin
    perform public.create_institution_for_superadmin(
      gen_random_uuid(),
      (create_payload - 'subscription') || jsonb_build_object(
        'slug', 'institution-command-status-denied',
        'status', 'active'
      )
    );
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  if not rejected then
    raise exception 'institution.activate changed initial status without permission';
  end if;

  execute 'set local role authenticated';
  begin
    perform public.get_institution_for_superadmin(other_institution_id);
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  if not rejected then
    raise exception 'institution-scoped membership read another institution';
  end if;

  begin
    perform public.update_institution_for_superadmin(
      gen_random_uuid(),
      other_institution_id,
      other_institution_version,
      jsonb_build_object('public_name', 'IDOR')
    );
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  if not rejected then
    raise exception 'institution-scoped membership updated another institution';
  end if;

  if exists (
    select 1
    from public.institution_directory directory_record
    where directory_record.id = other_institution_id
  ) then
    raise exception 'institution directory leaked another institution';
  end if;
  if exists (
    select 1
    from public.institution_directory_locations location_record
    where location_record.state = 'RJ'
  ) then
    raise exception 'institution location directory leaked another institution';
  end if;
  if not exists (
    select 1
    from public.institution_directory directory_record
    where directory_record.id = institution_id
  ) then
    raise exception 'institution directory hid the authorized institution';
  end if;

  execute 'reset role';
  update public.platform_memberships
  set mfa_required = true
  where id = editor_membership_id;
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', editor_auth_id, 'aal', 'aal1')::text,
    true
  );
  execute 'set local role authenticated';
  begin
    perform public.get_institution_for_superadmin(institution_id);
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  if not rejected then
    raise exception 'membership-required MFA accepted AAL1';
  end if;

  execute 'reset role';
  update public.platform_memberships
  set mfa_required = false
  where id = editor_membership_id;
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', editor_auth_id, 'aal', 'aal2')::text,
    true
  );
  execute 'set local role authenticated';

  result := public.update_institution_for_superadmin(
    update_request_id,
    institution_id,
    initial_version,
    jsonb_build_object(
      'public_name', 'Instituicao Atualizada',
      'subscription', create_payload -> 'subscription'
    )
  );
  updated_version := (result ->> 'management_version')::bigint;
  if updated_version <> initial_version + 1
     or result ->> 'public_name' <> 'Instituicao Atualizada' then
    raise exception 'institution.update did not update and increment version';
  end if;

  replay := public.update_institution_for_superadmin(
    update_request_id,
    institution_id,
    initial_version,
    jsonb_build_object(
      'public_name', 'Instituicao Atualizada',
      'subscription', create_payload -> 'subscription'
    )
  );
  if replay is distinct from result then
    raise exception 'identical update retry did not return receipt result';
  end if;

  execute 'reset role';
  if (
    select count(*) from public.institution_subscriptions subscription_record
    where subscription_record.institution_id = institution_id
  ) <> 1 then
    raise exception 'unchanged full subscription payload created duplicate history';
  end if;
  execute 'set local role authenticated';

  result := public.update_institution_for_superadmin(
    gen_random_uuid(), institution_id, updated_version,
    jsonb_build_object('legal_name', 'Instituicao Atualizada LTDA')
  );
  updated_version := (result ->> 'management_version')::bigint;
  begin
    perform public.update_institution_for_superadmin(
      update_request_id,
      institution_id,
      initial_version,
      jsonb_build_object(
        'public_name', 'Instituicao Atualizada',
        'subscription', create_payload -> 'subscription'
      )
    );
    rejected := false;
  exception when serialization_failure then
    rejected := true;
  end;
  if not rejected then
    raise exception 'old receipt replay returned a newer aggregate state';
  end if;

  begin
    perform public.update_institution_for_superadmin(
      update_request_id,
      institution_id,
      initial_version,
      jsonb_build_object('public_name', 'Payload diferente')
    );
    rejected := false;
  exception when sqlstate '22023' then
    rejected := true;
  end;
  if not rejected then
    raise exception 'update request_id accepted a different payload';
  end if;

  begin
    perform public.update_institution_for_superadmin(
      gen_random_uuid(), institution_id, updated_version,
      jsonb_build_object('status', 'active')
    );
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  if not rejected then
    raise exception 'institution.update changed protected status';
  end if;

  begin
    perform public.update_institution_for_superadmin(
      gen_random_uuid(), institution_id, updated_version,
      jsonb_build_object(
        'subscription', jsonb_build_object(
          'plan_code', 'institution-command-plus', 'status', 'active'
        )
      )
    );
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  if not rejected then
    raise exception 'institution.update changed protected plan';
  end if;

  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', editor_auth_id, 'aal', 'aal1')::text,
    true
  );
  begin
    perform public.update_institution_for_superadmin(
      gen_random_uuid(), institution_id, updated_version,
      jsonb_build_object('public_name', 'MFA negado')
    );
    rejected := false;
  exception when insufficient_privilege then
    rejected := true;
  end;
  if not rejected then
    raise exception 'AAL1 updated an institution';
  end if;

  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', editor_auth_id, 'aal', 'aal2')::text,
    true
  );
  begin
    perform public.update_institution_for_superadmin(
      gen_random_uuid(), institution_id, initial_version,
      jsonb_build_object('public_name', 'Conflito')
    );
    rejected := false;
  exception when serialization_failure then
    rejected := true;
  end;
  if not rejected then
    raise exception 'stale expected_version did not conflict';
  end if;

  begin
    perform public.update_institution_for_superadmin(
      gen_random_uuid(), gen_random_uuid(), 1,
      jsonb_build_object('public_name', 'Ausente')
    );
    rejected := false;
  exception when no_data_found then
    rejected := true;
  end;
  if not rejected then
    raise exception 'missing institution did not return P0002';
  end if;

  execute 'reset role';
  select public_name into original_name
  from public.institutions where id = institution_id;
  execute 'set local role authenticated';
  begin
    perform public.update_institution_for_superadmin(
      gen_random_uuid(), institution_id, updated_version,
      jsonb_build_object(
        'public_name', 'Nao pode persistir',
        'contact', jsonb_build_object('email', 'invalid-email')
      )
    );
    rejected := false;
  exception when sqlstate '22023' then
    rejected := true;
  end;
  if not rejected then
    raise exception 'invalid update payload was accepted';
  end if;
  execute 'reset role';
  if (select public_name from public.institutions where id = institution_id)
       is distinct from original_name
     or (select management_version from public.institutions where id = institution_id)
       <> updated_version then
    raise exception 'failed update left partial aggregate changes';
  end if;

  perform set_config('request.jwt.claim.sub', operations_auth_id::text, true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', operations_auth_id, 'aal', 'aal2')::text,
    true
  );
  result := public.update_institution_for_superadmin(
    child_update_request_id,
    institution_id,
    updated_version,
    jsonb_build_object(
      'address', jsonb_build_object('city', 'Campinas'),
      'contact', jsonb_build_object(
        'email', 'institution-command-updated@example.invalid'
      ),
      'branding', jsonb_build_object('profile_bio', 'Bio sintetica'),
      'subscription', jsonb_build_object(
        'plan_code', 'institution-command-plus', 'status', 'active',
        'starts_at', '2026-08-12T00:00:00Z',
        'trial_ends_at', null, 'manual_reason', 'synthetic upgrade',
        'paused_at', null, 'cancelled_at', null
      )
    )
  );
  if (result ->> 'management_version')::bigint <> updated_version + 1
     or result -> 'address' ->> 'city' <> 'Campinas'
     or result -> 'contact' ->> 'email'
          <> 'institution-command-updated@example.invalid'
     or result -> 'branding' ->> 'profile_bio' <> 'Bio sintetica'
     or result -> 'subscription' ->> 'plan_code'
          <> 'institution-command-plus' then
    raise exception 'child-only update did not increment and return aggregate version';
  end if;

  begin
    perform public.get_institution_for_superadmin(gen_random_uuid());
    rejected := false;
  exception when no_data_found then
    rejected := true;
  end;
  if not rejected then
    raise exception 'read missing institution did not return P0002';
  end if;

  result := public.get_institution_for_superadmin(institution_id);
  if result ->> 'management_version'
       <> (updated_version + 1)::text
     or result -> 'subscription' ->> 'plan_code'
       <> 'institution-command-plus' then
    raise exception 'read did not return latest complete aggregate';
  end if;

  execute 'reset role';
  if exists (
    select 1
    from audit.audit_logs audit_record
    where audit_record.object_type = 'institution'
      and audit_record.object_id = institution_id
      and (
        coalesce(audit_record.before_json, '{}'::jsonb)
          ?| array[
            'document_ref', 'address', 'contact', 'branding',
            'public_name', 'legal_name', 'trade_name'
          ]
        or coalesce(audit_record.after_json, '{}'::jsonb)
          ?| array[
            'document_ref', 'address', 'contact', 'branding',
            'public_name', 'legal_name', 'trade_name'
          ]
      )
  ) then
    raise exception 'institution audit contains PII or contact/address data';
  end if;

  if not exists (
    select 1
    from audit.audit_logs audit_record
    where audit_record.object_type = 'institution'
      and audit_record.object_id = institution_id
      and audit_record.action_code = 'institution.update'
      and audit_record.after_json ? 'changed_fields'
      and audit_record.after_json ? 'status'
      and audit_record.after_json ? 'plan_id'
  ) then
    raise exception 'minimized institution audit evidence is missing';
  end if;

  if exists (
    select 1
    from app_private.institution_management_command_receipts receipt_record
    where octet_length(receipt_record.request_hash) <> 32
       or receipt_record.result_management_version < 1
  ) or exists (
    select 1
    from information_schema.columns column_record
    where column_record.table_schema = 'app_private'
      and column_record.table_name = 'institution_management_command_receipts'
      and column_record.column_name in ('request_json', 'result_json')
  ) then
    raise exception 'institution receipts are not minimized';
  end if;

  if exists (
    select 1
    from information_schema.role_table_grants grant_record
    where grant_record.grantee = 'authenticated'
      and grant_record.table_schema = 'public'
      and grant_record.table_name in (
        'institutions', 'institution_addresses', 'institution_contacts',
        'institution_branding', 'institution_subscriptions'
      )
      and grant_record.privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  ) then
    raise exception 'authenticated has direct institution write grants';
  end if;
end;
$$;

rollback;
