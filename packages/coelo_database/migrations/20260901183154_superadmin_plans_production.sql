-- Product contract: specs/051-superadmin-plans-production.md

alter table public.plans
  add column if not exists description text not null default '',
  add column if not exists revision bigint not null default 1,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists created_by_person_id uuid references public.people(id) on delete restrict,
  add column if not exists updated_by_person_id uuid references public.people(id) on delete restrict;

alter table public.plans
  drop constraint if exists plans_revision_positive,
  add constraint plans_revision_positive check (revision > 0),
  drop constraint if exists plans_description_length,
  add constraint plans_description_length check (char_length(description) between 1 and 2000),
  drop constraint if exists plans_code_format,
  add constraint plans_code_format check (code ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' and char_length(code) <= 80),
  drop constraint if exists plans_name_length,
  add constraint plans_name_length check (char_length(name) between 1 and 160),
  force row level security;

create index if not exists plans_created_by_person_id_idx
  on public.plans(created_by_person_id) where created_by_person_id is not null;
create index if not exists plans_updated_by_person_id_idx
  on public.plans(updated_by_person_id) where updated_by_person_id is not null;
create index if not exists plans_status_name_id_idx on public.plans(status, name, id);
create index if not exists plan_entitlements_plan_key_idx
  on public.plan_entitlements(plan_id, entitlement_key);

alter table public.plan_entitlements force row level security;

revoke all on table public.plans, public.plan_entitlements from anon, authenticated;

create table if not exists public.plan_change_receipts (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique,
  plan_id uuid not null references public.plans(id) on delete restrict,
  actor_person_id uuid not null references public.people(id) on delete restrict,
  action text not null check (action in ('create', 'update', 'archive', 'restore')),
  previous_revision bigint,
  next_revision bigint not null check (next_revision > 0),
  reason text not null check (char_length(reason) between 1 and 1000),
  occurred_at timestamptz not null default now()
);

alter table public.plan_change_receipts enable row level security;
alter table public.plan_change_receipts force row level security;
revoke all on table public.plan_change_receipts from public, anon, authenticated;
create index if not exists plan_change_receipts_plan_occurred_idx
  on public.plan_change_receipts(plan_id, occurred_at desc);
create index if not exists plan_change_receipts_actor_idx
  on public.plan_change_receipts(actor_person_id);

create or replace function app_private.assert_plan_permission(
  p_permission text,
  p_require_aal2 boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;
  v_actor := app_private.current_person_id();
  if v_actor is null then
    raise exception using errcode = '42501', message = 'internal_actor_required';
  end if;
  if not app_private.has_platform_permission(p_permission) then
    raise exception using errcode = '42501', message = 'permission_denied';
  end if;
  if p_require_aal2 and not app_private.has_mfa_aal2() then
    raise exception using errcode = '42501', message = 'mfa_aal2_required';
  end if;
  return v_actor;
end;
$$;

revoke execute on function app_private.assert_plan_permission(text, boolean)
  from public, anon, authenticated;

create or replace function public.superadmin_plans_list(
  p_search text default '',
  p_status text default null,
  p_feature text default null,
  p_page integer default 1,
  p_page_size integer default 11
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_offset integer;
  v_result jsonb;
begin
  perform app_private.assert_plan_permission('platform.read', false);
  if p_page < 1 or p_page_size < 1 or p_page_size > 100 then
    raise exception using errcode = '22023', message = 'invalid_pagination';
  end if;
  if p_status is not null and p_status not in ('active', 'archived') then
    raise exception using errcode = '22023', message = 'invalid_status';
  end if;
  if p_feature is not null and p_feature not in (
    'communication','agenda','invitations','chat','notices','routine','happens','now','moments'
  ) then
    raise exception using errcode = '22023', message = 'invalid_feature';
  end if;
  v_offset := (p_page - 1) * p_page_size;

  with filtered as (
    select p.*
    from public.plans p
    where (coalesce(trim(p_search), '') = '' or
      p.name ilike '%' || trim(p_search) || '%' or
      p.code ilike '%' || trim(p_search) || '%')
      and (p_status is null or p.status::text = p_status)
      and (p_feature is null or exists (
        select 1 from public.plan_entitlements pe
        where pe.plan_id = p.id
          and pe.entitlement_key = 'feature.' || p_feature
          and pe.status = 'active'
          and coalesce((pe.value_json->>'enabled')::boolean, false)
      ))
  ), page_rows as (
    select * from filtered order by name, id limit p_page_size offset v_offset
  )
  select jsonb_build_object(
    'items', coalesce(jsonb_agg(
      jsonb_build_object(
        'id', pr.id,
        'name', pr.name,
        'code', pr.code,
        'description', pr.description,
        'status', pr.status::text,
        'revision', pr.revision,
        'used_by_institution_count', (
          select count(*) from public.institution_subscriptions s
          where s.plan_id = pr.id and s.status in ('active','draft')
        ),
        'entitlements', coalesce((
          select jsonb_object_agg(pe.entitlement_key, pe.value_json)
          from public.plan_entitlements pe
          where pe.plan_id = pr.id and pe.status = 'active'
        ), '{}'::jsonb)
      ) order by pr.name, pr.id
    ), '[]'::jsonb),
    'total_items', (select count(*) from filtered),
    'page', p_page,
    'page_size', p_page_size
  ) into v_result
  from page_rows pr;
  return v_result;
end;
$$;

create or replace function public.superadmin_plan_get(p_plan_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_result jsonb;
begin
  perform app_private.assert_plan_permission('platform.read', false);
  select jsonb_build_object(
    'id', p.id, 'name', p.name, 'code', p.code,
    'description', p.description, 'status', p.status::text,
    'revision', p.revision,
    'used_by_institution_count', (
      select count(*) from public.institution_subscriptions s
      where s.plan_id = p.id and s.status in ('active','draft')
    ),
    'entitlements', coalesce((
      select jsonb_object_agg(pe.entitlement_key, pe.value_json)
      from public.plan_entitlements pe
      where pe.plan_id = p.id and pe.status = 'active'
    ), '{}'::jsonb),
    'linked_institutions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id, 'name', i.legal_name, 'subscription_status', s.status::text,
        'starts_at', s.starts_at, 'units_with_override', 0
      ) order by i.legal_name, i.id)
      from public.institution_subscriptions s
      join public.institutions i on i.id = s.institution_id
      where s.plan_id = p.id
    ), '[]'::jsonb)
  ) into v_result
  from public.plans p where p.id = p_plan_id;
  if v_result is null then
    raise exception using errcode = 'P0002', message = 'plan_not_found';
  end if;
  return v_result;
end;
$$;

create or replace function public.superadmin_plan_save(
  p_request_id uuid,
  p_plan_id uuid,
  p_expected_revision bigint,
  p_payload jsonb,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_plan public.plans%rowtype;
  v_existing public.plans%rowtype;
  v_key text;
  v_value jsonb;
  v_action text;
begin
  v_actor := app_private.assert_plan_permission('plan.change', true);
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'request_id_required';
  end if;
  if coalesce(char_length(trim(p_reason)), 0) not between 1 and 1000 then
    raise exception using errcode = '22023', message = 'reason_required';
  end if;
  if coalesce(char_length(trim(p_payload->>'name')), 0) not between 1 and 160 or
     coalesce(char_length(trim(p_payload->>'description')), 0) not between 1 and 2000 then
    raise exception using errcode = '22023', message = 'invalid_plan_identity';
  end if;
  if coalesce(p_payload->>'status', 'active') not in ('active','archived') then
    raise exception using errcode = '22023', message = 'invalid_status';
  end if;

  select p.* into v_existing
  from public.plans p
  join public.plan_change_receipts r on r.plan_id = p.id
  where r.request_id = p_request_id;
  if found then
    return public.superadmin_plan_get(v_existing.id);
  end if;

  if p_plan_id is null then
    if coalesce(p_payload->>'code','') !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
      raise exception using errcode = '22023', message = 'invalid_plan_code';
    end if;
    insert into public.plans(
      code, name, description, status, billing_mode, revision,
      created_by_person_id, updated_by_person_id
    ) values (
      p_payload->>'code', trim(p_payload->>'name'), trim(p_payload->>'description'),
      (p_payload->>'status')::public.record_status, 'manual', 1, v_actor, v_actor
    ) returning * into v_plan;
    v_action := 'create';
  else
    select * into v_existing from public.plans where id = p_plan_id for update;
    if not found then raise exception using errcode='P0002', message='plan_not_found'; end if;
    if p_expected_revision is null or p_expected_revision <> v_existing.revision then
      raise exception using errcode='40001', message='plan_revision_conflict';
    end if;
    if p_payload ? 'code' and p_payload->>'code' <> v_existing.code then
      raise exception using errcode='22023', message='plan_code_immutable';
    end if;
    update public.plans set
      name = trim(p_payload->>'name'),
      description = trim(p_payload->>'description'),
      status = (p_payload->>'status')::public.record_status,
      revision = revision + 1,
      updated_at = now(),
      updated_by_person_id = v_actor
    where id = p_plan_id returning * into v_plan;
    v_action := case
      when v_existing.status = 'active' and v_plan.status = 'archived' then 'archive'
      when v_existing.status = 'archived' and v_plan.status = 'active' then 'restore'
      else 'update'
    end;
  end if;

  delete from public.plan_entitlements where plan_id = v_plan.id;
  for v_key, v_value in select key, value from jsonb_each(coalesce(p_payload->'entitlements','{}'::jsonb))
  loop
    if v_key not in (
      'feature.communication','feature.agenda','feature.invitations','feature.chat',
      'feature.notices','feature.routine','feature.happens','feature.now','feature.moments',
      'limit.units','limit.memberships','limit.storage_gb','limit.media_gb'
    ) then raise exception using errcode='22023', message='invalid_entitlement'; end if;
    if v_key like 'feature.%' and jsonb_typeof(v_value->'enabled') <> 'boolean' then
      raise exception using errcode='22023', message='invalid_feature_value';
    end if;
    if v_key like 'limit.%' and (
      jsonb_typeof(v_value->'value') <> 'number' or (v_value->>'value')::numeric < 0 or
      (v_value->>'value')::numeric > 100000000
    ) then raise exception using errcode='22023', message='invalid_limit_value'; end if;
    insert into public.plan_entitlements(plan_id, entitlement_key, value_kind, value_json, status)
    values (v_plan.id, v_key, case when v_key like 'feature.%' then 'boolean' else 'integer' end,
      v_value, 'active');
  end loop;

  insert into public.plan_change_receipts(
    request_id, plan_id, actor_person_id, action, previous_revision, next_revision, reason
  ) values (
    p_request_id, v_plan.id, v_actor, v_action, v_existing.revision, v_plan.revision, trim(p_reason)
  );
  return public.superadmin_plan_get(v_plan.id);
exception
  when unique_violation then
    raise exception using errcode='23505', message='plan_code_or_request_conflict';
end;
$$;

revoke execute on function public.superadmin_plans_list(text,text,text,integer,integer)
  from public, anon;
revoke execute on function public.superadmin_plan_get(uuid) from public, anon;
revoke execute on function public.superadmin_plan_save(uuid,uuid,bigint,jsonb,text)
  from public, anon;
grant execute on function public.superadmin_plans_list(text,text,text,integer,integer)
  to authenticated;
grant execute on function public.superadmin_plan_get(uuid) to authenticated;
grant execute on function public.superadmin_plan_save(uuid,uuid,bigint,jsonb,text)
  to authenticated;
