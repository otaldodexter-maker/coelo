begin;

create table app_private.activity_template_create_receipts(
  request_id uuid primary key,
  request_hash bytea not null,
  actor_person_id uuid not null references public.people(id) on delete restrict,
  result_template_id uuid not null references public.activity_templates(id) on delete cascade,
  result_json jsonb not null,
  created_at timestamptz not null default now()
);
revoke all on table app_private.activity_template_create_receipts
  from public, anon, authenticated;
grant all on table app_private.activity_template_create_receipts to service_role;

create or replace function app_private.superadmin_create_activity_template(
  p_institution_id uuid,
  p_name text,
  p_description text,
  p_taxonomy_id uuid,
  p_governance_kind text,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.current_person_id();
  normalized_name text := btrim(coalesce(p_name, ''));
  normalized_description text := btrim(coalesce(p_description, ''));
  subtype public.activity_taxonomies%rowtype;
  receipt app_private.activity_template_create_receipts%rowtype;
  request_hash bytea;
  template_id uuid;
  template_code text;
  result jsonb;
begin
  if (select auth.uid()) is null or actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  if not app_private.has_platform_permission('activities.templates.manage') then
    raise insufficient_privilege
      using message = 'activities.templates.manage required';
  end if;
  if not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message = 'MFA AAL2 required';
  end if;

  if p_institution_id is null
     or p_taxonomy_id is null
     or p_idempotency_key is null
     or normalized_name = ''
     or length(normalized_name) > 120
     or length(normalized_description) > 1000
     or p_governance_kind is null
     or p_governance_kind not in ('optional', 'mandatory')
     or not exists(
       select 1
       from public.institutions institution
       where institution.id = p_institution_id
         and institution.status = 'active'
     ) then
    raise invalid_parameter_value
      using message = 'invalid activity template request';
  end if;

  select taxonomy.*
  into subtype
  from public.activity_taxonomies taxonomy
  where taxonomy.id = p_taxonomy_id
    and taxonomy.taxonomy_kind = 'subtype'
    and taxonomy.status = 'active'
    and exists(
      select 1
      from public.activity_taxonomies category
      where category.id = taxonomy.parent_id
        and category.taxonomy_kind = 'category'
        and category.status = 'active'
    );
  if subtype.id is null then
    raise invalid_parameter_value
      using message = 'invalid activity template request';
  end if;

  request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'institution_id', p_institution_id,
        'name', normalized_name,
        'description', normalized_description,
        'taxonomy_id', p_taxonomy_id,
        'governance_kind', p_governance_kind
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_advisory_xact_lock(
    hashtextextended('activity-template-create:' || p_idempotency_key::text, 0)
  );
  select create_receipt.*
  into receipt
  from app_private.activity_template_create_receipts create_receipt
  where create_receipt.request_id = p_idempotency_key;
  if receipt.request_id is not null then
    if receipt.actor_person_id <> actor then
      raise insufficient_privilege
        using message = 'template receipt actor mismatch';
    end if;
    if receipt.request_hash <> request_hash then
      raise invalid_parameter_value using message = 'idempotency key reused';
    end if;
    return receipt.result_json;
  end if;

  template_id := app_private.activity_request_uuid(
    'activity-template-create', p_idempotency_key
  );
  template_code := coalesce(
    nullif(left(app_private.activity_slugify(normalized_name), 48), ''),
    'modelo'
  ) || '-' || replace(p_idempotency_key::text, '-', '');

  insert into public.activity_templates(
    id,
    scope_kind,
    institution_id,
    code,
    name,
    description,
    taxonomy_id,
    governance_kind,
    template_payload,
    status,
    created_by_person_id
  ) values (
    template_id,
    'institution',
    p_institution_id,
    template_code,
    normalized_name,
    nullif(normalized_description, ''),
    subtype.id,
    p_governance_kind,
    jsonb_build_object(
      'taxonomy_code', subtype.code,
      'governance_kind', p_governance_kind
    ),
    'active',
    actor
  );

  result := jsonb_build_object(
    'id', template_id,
    'code', template_code,
    'name', normalized_name,
    'description', nullif(normalized_description, ''),
    'scope_kind', 'institution',
    'institution_id', p_institution_id,
    'governance_kind', p_governance_kind,
    'taxonomy_id', subtype.parent_id,
    'subtype_id', subtype.id,
    'status', 'active'
  );

  insert into app_private.activity_template_create_receipts(
    request_id,
    request_hash,
    actor_person_id,
    result_template_id,
    result_json
  ) values (
    p_idempotency_key,
    request_hash,
    actor,
    template_id,
    result
  );

  insert into audit.audit_logs(
    actor_person_id,
    mfa_aal,
    action_code,
    object_type,
    object_id,
    institution_id,
    outcome,
    after_json
  ) values (
    actor,
    auth.jwt()->>'aal',
    'activity.template.create',
    'activity_template',
    template_id,
    p_institution_id,
    'success',
    result
  );

  return result;
end
$$;

create or replace function public.superadmin_create_activity_template(
  p_institution_id uuid,
  p_name text,
  p_description text,
  p_taxonomy_id uuid,
  p_governance_kind text,
  p_idempotency_key uuid
) returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select app_private.superadmin_create_activity_template(
    p_institution_id,
    p_name,
    p_description,
    p_taxonomy_id,
    p_governance_kind,
    p_idempotency_key
  )
$$;

revoke all on function app_private.superadmin_create_activity_template(
  uuid, text, text, uuid, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.superadmin_create_activity_template(
  uuid, text, text, uuid, text, uuid
) from public, anon, authenticated, service_role;
grant execute on function public.superadmin_create_activity_template(
  uuid, text, text, uuid, text, uuid
) to authenticated;

comment on function public.superadmin_create_activity_template(
  uuid, text, text, uuid, text, uuid
) is
  'Creates an active institution Activity template with capability, AAL2, idempotency and audit enforcement.';

notify pgrst, 'reload schema';

commit;
