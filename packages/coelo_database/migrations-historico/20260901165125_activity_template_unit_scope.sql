begin;

alter table public.activity_templates
  add column unit_id uuid;

alter table public.activity_templates
  drop constraint activity_templates_scope_kind_check,
  drop constraint activity_templates_check,
  add constraint activity_templates_scope_kind_check
    check (scope_kind in ('platform', 'institution', 'unit')),
  add constraint activity_templates_scope_hierarchy_check check (
    (scope_kind = 'platform' and institution_id is null and unit_id is null) or
    (scope_kind = 'institution' and institution_id is not null and unit_id is null) or
    (scope_kind = 'unit' and institution_id is not null and unit_id is not null)
  ),
  add constraint activity_templates_unit_institution_fkey
    foreign key (unit_id, institution_id)
    references public.units(id, institution_id)
    on delete cascade;

create index activity_templates_unit_status_name_idx
  on public.activity_templates(unit_id, status, name)
  where unit_id is not null;

create table app_private.superadmin_internal_activity_template_create_receipts(
  request_id uuid primary key,
  internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete restrict,
  institution_id uuid not null references public.institutions(id) on delete restrict,
  unit_id uuid,
  request_hash bytea not null check(octet_length(request_hash)=32),
  result_template_id uuid not null
    references public.activity_templates(id) on delete cascade,
  result_json jsonb not null check(jsonb_typeof(result_json)='object'),
  correlation_id uuid not null,
  created_at timestamptz not null default now(),
  constraint superadmin_internal_activity_template_receipts_unit_fkey
    foreign key(unit_id,institution_id)
    references public.units(id,institution_id) on delete restrict
);
create index superadmin_internal_activity_template_receipts_identity_idx
  on app_private.superadmin_internal_activity_template_create_receipts(internal_identity_id);
create index superadmin_internal_activity_template_receipts_institution_idx
  on app_private.superadmin_internal_activity_template_create_receipts(institution_id);
alter table app_private.superadmin_internal_activity_template_create_receipts
  enable row level security;
alter table app_private.superadmin_internal_activity_template_create_receipts
  force row level security;
revoke all on table app_private.superadmin_internal_activity_template_create_receipts
  from public,anon,authenticated,service_role;

drop policy activity_templates_authorized_read on public.activity_templates;
create policy activity_templates_authorized_read
on public.activity_templates for select to authenticated
using (
  (select app_private.has_platform_permission('activities.read'))
  or (
    institution_id is not null
    and app_private.has_institution_permission(
      institution_id,
      'activities.read',
      case when scope_kind = 'unit' then unit_id else null end,
      null,
      scope_kind = 'institution'
    )
  )
);

create or replace function app_private.superadmin_activity_template_options(
  p_institution_id uuid
) returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare
  ctx app_private.superadmin_internal_context;
  effective_institution_id uuid;
  result jsonb;
begin
  select * into strict ctx
  from app_private.require_superadmin_internal_context('activities.read');
  if p_institution_id is not null and not exists(
    select 1 from public.institutions institution
    where institution.id=p_institution_id
  ) then
    raise no_data_found using message='institution not found';
  end if;
  if p_institution_id is not null
     and ctx.scope_kind='institution'
     and ctx.scope_institution_id is distinct from p_institution_id then
    raise insufficient_privilege using message='institution scope denied',detail='SAI_PERMISSION_DENIED';
  end if;
  effective_institution_id:=coalesce(
    p_institution_id,
    case when ctx.scope_kind='institution' then ctx.scope_institution_id end
  );
  select jsonb_build_object(
    'institutions',coalesce((select jsonb_agg(jsonb_build_object(
      'id',institution.id,'name',institution.public_name) order by institution.public_name)
      from public.institutions institution
      where effective_institution_id is null
         or institution.id=effective_institution_id),'[]'::jsonb),
    'units',coalesce((select jsonb_agg(jsonb_build_object(
      'id',unit.id,'institution_id',unit.institution_id,'name',unit.name) order by unit.name)
      from public.units unit
      where unit.status<>'archived'
       and (effective_institution_id is null
        or unit.institution_id=effective_institution_id)),'[]'::jsonb),
    'taxonomy',coalesce((select jsonb_agg(jsonb_build_object(
      'id',category.id,'label',category.name,'is_other',category.code='outros',
      'subtypes',coalesce((select jsonb_agg(jsonb_build_object(
        'id',subtype.id,'label',subtype.name) order by subtype.sort_order,subtype.name)
        from public.activity_taxonomies subtype
        where subtype.parent_id=category.id and subtype.status='active'),'[]'::jsonb))
      order by category.sort_order,category.name)
      from public.activity_taxonomies category
      where category.taxonomy_kind='category' and category.status='active'),'[]'::jsonb),
    'templates',coalesce((select jsonb_agg(jsonb_build_object(
      'id',template.id,'name',template.name,'description',template.description,
      'scope_kind',template.scope_kind,'institution_id',template.institution_id,
      'unit_id',template.unit_id,'governance_kind',template.governance_kind,
      'taxonomy_id',coalesce(taxonomy.parent_id,taxonomy.id),
      'subtype_id',case when taxonomy.taxonomy_kind='subtype' then taxonomy.id end,
      'status',template.status) order by template.scope_kind desc,template.name)
      from public.activity_templates template
      join public.activity_taxonomies taxonomy on taxonomy.id=template.taxonomy_id
      where template.status='active'
       and (template.scope_kind='platform'
        or (effective_institution_id is not null
         and template.institution_id=effective_institution_id))),
      '[]'::jsonb)
  ) into result;
  return result;
end $$;

create or replace function app_private.superadmin_create_scoped_activity_template(
  p_institution_id uuid,
  p_unit_id uuid,
  p_name text,
  p_description text,
  p_taxonomy_id uuid,
  p_governance_kind text,
  p_idempotency_key uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  ctx app_private.superadmin_internal_context;
  normalized_name text:=btrim(coalesce(p_name,''));
  normalized_description text:=btrim(coalesce(p_description,''));
  subtype public.activity_taxonomies%rowtype;
  receipt app_private.superadmin_internal_activity_template_create_receipts%rowtype;
  request_hash bytea;
  template_id uuid;
  template_code text;
  result jsonb;
  target_scope text:=case when p_unit_id is null then 'institution' else 'unit' end;
  correlation_id uuid:=gen_random_uuid();
begin
  select * into strict ctx
  from app_private.require_superadmin_internal_context('activities.templates.manage');
  if p_institution_id is null or p_taxonomy_id is null or p_idempotency_key is null
     or normalized_name='' or length(normalized_name)>120
     or length(normalized_description)>1000
     or p_governance_kind is null
     or p_governance_kind not in ('optional','mandatory')
     or not exists(select 1 from public.institutions institution
       where institution.id=p_institution_id and institution.status='active')
     or (p_unit_id is not null and not exists(select 1 from public.units unit
       where unit.id=p_unit_id and unit.institution_id=p_institution_id
        and unit.status<>'archived')) then
    raise invalid_parameter_value using message='invalid activity template request';
  end if;
  if ctx.scope_kind='institution'
     and ctx.scope_institution_id is distinct from p_institution_id then
    raise insufficient_privilege using message='institution scope denied',detail='SAI_PERMISSION_DENIED';
  end if;
  select taxonomy.* into subtype from public.activity_taxonomies taxonomy
  where taxonomy.id=p_taxonomy_id and taxonomy.taxonomy_kind='subtype'
   and taxonomy.status='active'
   and exists(select 1 from public.activity_taxonomies category
     where category.id=taxonomy.parent_id and category.taxonomy_kind='category'
      and category.status='active');
  if subtype.id is null then
    raise invalid_parameter_value using message='invalid activity template request';
  end if;
  request_hash:=extensions.digest(convert_to(jsonb_build_object(
    'institution_id',p_institution_id,'unit_id',p_unit_id,'name',normalized_name,
    'description',normalized_description,'taxonomy_id',p_taxonomy_id,
    'governance_kind',p_governance_kind)::text,'UTF8'),'sha256');
  perform pg_advisory_xact_lock(hashtextextended(
    'activity-template-create:'||p_idempotency_key::text,0));
  select create_receipt.* into receipt
  from app_private.superadmin_internal_activity_template_create_receipts create_receipt
  where create_receipt.request_id=p_idempotency_key;
  if receipt.request_id is not null then
    if receipt.internal_identity_id<>ctx.internal_identity_id then
      raise insufficient_privilege using message='template receipt actor mismatch';
    end if;
    if receipt.request_hash<>request_hash then
      raise invalid_parameter_value using message='idempotency key reused';
    end if;
    return receipt.result_json;
  end if;
  template_id:=app_private.activity_request_uuid('activity-template-create',p_idempotency_key);
  template_code:=coalesce(nullif(left(app_private.activity_slugify(normalized_name),48),''),'modelo')
    ||'-'||replace(p_idempotency_key::text,'-','');
  insert into public.activity_templates(
    id,scope_kind,institution_id,unit_id,code,name,description,taxonomy_id,
    governance_kind,template_payload,status,created_by_person_id
  ) values(
    template_id,target_scope,p_institution_id,p_unit_id,template_code,normalized_name,
    nullif(normalized_description,''),subtype.id,p_governance_kind,
    jsonb_build_object('taxonomy_code',subtype.code,'governance_kind',p_governance_kind),
    'active',null
  );
  result:=jsonb_build_object(
    'id',template_id,'code',template_code,'name',normalized_name,
    'description',nullif(normalized_description,''),'scope_kind',target_scope,
    'institution_id',p_institution_id,'unit_id',p_unit_id,
    'governance_kind',p_governance_kind,'taxonomy_id',subtype.parent_id,
    'subtype_id',subtype.id,'status','active');
  perform app_private.audit_append_superadmin_internal(
    ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
    ctx.session_id,'activities.templates.manage',ctx.aal,
    'activity.template.create','success',null,correlation_id,p_institution_id,
    'activity_template',template_id,jsonb_build_object(
      'id',template_id,'institution_id',p_institution_id,'unit_id',p_unit_id,
      'scope_kind',target_scope,'status','active'
    )
  );
  insert into app_private.superadmin_internal_activity_template_create_receipts(
    request_id,internal_identity_id,institution_id,unit_id,request_hash,
    result_template_id,result_json,correlation_id
  ) values(
    p_idempotency_key,ctx.internal_identity_id,p_institution_id,p_unit_id,
    request_hash,template_id,result,correlation_id
  );
  return result;
end $$;

create or replace function public.superadmin_create_scoped_activity_template(
  p_institution_id uuid,p_unit_id uuid,p_name text,p_description text,
  p_taxonomy_id uuid,p_governance_kind text,p_idempotency_key uuid
) returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.superadmin_create_scoped_activity_template(
  p_institution_id,p_unit_id,p_name,p_description,p_taxonomy_id,
  p_governance_kind,p_idempotency_key)$$;

revoke all on function app_private.superadmin_create_scoped_activity_template(
  uuid,uuid,text,text,uuid,text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.superadmin_create_scoped_activity_template(
  uuid,uuid,text,text,uuid,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.superadmin_create_scoped_activity_template(
  uuid,uuid,text,text,uuid,text,uuid) to authenticated;

alter table app_private.superadmin_internal_activity_template_create_receipts
  owner to postgres;
alter function app_private.superadmin_activity_template_options(uuid)
  owner to postgres;
alter function app_private.superadmin_create_scoped_activity_template(
  uuid,uuid,text,text,uuid,text,uuid) owner to postgres;
alter function public.superadmin_create_scoped_activity_template(
  uuid,uuid,text,text,uuid,text,uuid) owner to postgres;

comment on function public.superadmin_create_scoped_activity_template(
  uuid,uuid,text,text,uuid,text,uuid) is
  'Creates an institution or unit-scoped Activity template with hierarchy, capability, AAL2, idempotency and audit enforcement.';

notify pgrst, 'reload schema';

commit;
