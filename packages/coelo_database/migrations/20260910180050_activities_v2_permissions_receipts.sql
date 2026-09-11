begin;

do $$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using
      message='activities v2 permissions receipts migration must run as postgres';
  end if;
  if to_regprocedure('app_private.guard_activity_v2_actor_provenance()') is null
     or to_regprocedure('app_private.set_activity_updated_at()') is null
     or to_regclass('app_private.superadmin_internal_identities') is null then
    raise exception using
      errcode='55000',
      message='activities v2 permissions receipts dependencies are unavailable';
  end if;
end
$$;

create table public.activity_admin_capability_actions (
  id uuid primary key default gen_random_uuid(),
  activity_admin_assignment_id uuid not null
    references public.activity_admin_assignments(id) on delete cascade,
  capability_id uuid not null
    references public.activity_capabilities(id) on delete restrict,
  can_view boolean not null,
  can_edit boolean not null,
  changed_by_person_id uuid
    references public.people(id) on delete restrict,
  changed_by_actor_kind text generated always as
    (case when changed_by_person_id is null then 'superadmin_internal' else 'person' end) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(activity_admin_assignment_id,capability_id)
);

create index activity_admin_capability_actions_assignment_idx
  on public.activity_admin_capability_actions(activity_admin_assignment_id);
create index activity_admin_capability_actions_capability_idx
  on public.activity_admin_capability_actions(capability_id);
create index activity_admin_capability_actions_changed_by_person_idx
  on public.activity_admin_capability_actions(changed_by_person_id);

create trigger activity_admin_capability_actions_actor_provenance_guard
before insert or update on public.activity_admin_capability_actions
for each row execute function app_private.guard_activity_v2_actor_provenance(
  'changed_by_person_id','change'
);
create trigger activity_admin_capability_actions_updated_at
before update on public.activity_admin_capability_actions
for each row execute function app_private.set_activity_updated_at();

alter table public.activity_admin_capability_actions enable row level security;
alter table public.activity_admin_capability_actions force row level security;
revoke all on table public.activity_admin_capability_actions
  from public,anon,authenticated,service_role;

create table app_private.superadmin_internal_activity_command_receipts (
  request_id uuid primary key,
  internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete restrict,
  institution_id uuid not null references public.institutions(id) on delete restrict,
  activity_id uuid,
  command_kind text not null check(command_kind in (
    'activity.create','activity.update','activity.publish','activity.set_units',
    'activity.set_groups','activity.set_participants','activity.set_professionals',
    'activity.set_permissions'
  )),
  request_hash bytea not null check(octet_length(request_hash)=32),
  resulting_version bigint,
  resulting_status text,
  correlation_id uuid not null,
  result_counts jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

comment on column app_private.superadmin_internal_activity_command_receipts.request_hash is
  'Derived pseudonymous command hash; private, non-exportable and without stored payload';

create index superadmin_internal_activity_command_receipts_identity_idx
  on app_private.superadmin_internal_activity_command_receipts(internal_identity_id);
create index superadmin_internal_activity_command_receipts_institution_idx
  on app_private.superadmin_internal_activity_command_receipts(institution_id);
create index superadmin_internal_activity_command_receipts_activity_idx
  on app_private.superadmin_internal_activity_command_receipts(activity_id);

alter table app_private.superadmin_internal_activity_command_receipts
  enable row level security;
alter table app_private.superadmin_internal_activity_command_receipts
  force row level security;
revoke all on table app_private.superadmin_internal_activity_command_receipts
  from public,anon,authenticated,service_role;

create function app_private.activity_v2_command_request_hash(
  p_command_kind text,
  p_institution_id uuid,
  p_activity_id uuid,
  p_expected_version bigint,
  p_normalized_payload jsonb
) returns bytea
language sql
immutable
security invoker
set search_path=''
as $$
  select extensions.digest(
    pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'command_kind',p_command_kind,
        'institution_id',p_institution_id,
        'activity_id',p_activity_id,
        'expected_version',p_expected_version,
        'payload',coalesce(p_normalized_payload,'null'::jsonb)
      )::text,
      'UTF8'
    ),
    'sha256'
  )
$$;

create function app_private.activity_v2_error_envelope(
  p_code text,
  p_correlation_id uuid
) returns jsonb
language sql
stable
security invoker
set search_path=''
as $$
  with normalized as (
    select case when p_code in (
      'ACTIVITY_INVALID_INPUT','ACTIVITY_INVALID_REFERENCE','ACTIVITY_NOT_FOUND',
      'ACTIVITY_INVALID_STATE','ACTIVITY_DEPENDENCIES_ACTIVE',
      'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED','SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE',
      'SAI_INTERNAL_ERROR'
    ) then p_code else 'SAI_INTERNAL_ERROR' end as code
  )
  select pg_catalog.jsonb_build_object(
    'ok',false,
    'data',null,
    'error',pg_catalog.jsonb_build_object(
      'code',code,
      'message',case
        when code in ('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID')
          then 'Autenticação necessária.'
        when code='SAI_MFA_REQUIRED' then 'Confirme o segundo fator.'
        when code in ('ACTIVITY_INVALID_INPUT','ACTIVITY_INVALID_REFERENCE')
          then 'Revise os dados enviados.'
        when code='ACTIVITY_NOT_FOUND' then 'Atividade não encontrada.'
        when code in (
          'ACTIVITY_INVALID_STATE','ACTIVITY_DEPENDENCIES_ACTIVE',
          'SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE'
        ) then 'O estado mudou. Recarregue e tente novamente.'
        when code in ('SAI_INTERNAL_ERROR') then 'Não foi possível concluir a operação.'
        else 'Acesso não autorizado.'
      end,
      'http_status',case
        when code in ('ACTIVITY_INVALID_INPUT','ACTIVITY_INVALID_REFERENCE') then 422
        when code='ACTIVITY_NOT_FOUND' then 404
        when code in (
          'ACTIVITY_INVALID_STATE','ACTIVITY_DEPENDENCIES_ACTIVE',
          'SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE'
        ) then 409
        when code in ('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when code in (
          'SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED'
        ) then 403
        else 500
      end,
      'correlation_id',p_correlation_id
    )
  ) from normalized
$$;

alter table public.activity_admin_capability_actions owner to postgres;
alter table app_private.superadmin_internal_activity_command_receipts owner to postgres;
alter function app_private.activity_v2_command_request_hash(text,uuid,uuid,bigint,jsonb)
  owner to postgres;
alter function app_private.activity_v2_error_envelope(text,uuid) owner to postgres;
revoke all on function app_private.activity_v2_command_request_hash(text,uuid,uuid,bigint,jsonb)
  from public,anon,authenticated,service_role;
revoke all on function app_private.activity_v2_error_envelope(text,uuid)
  from public,anon,authenticated,service_role;

commit;
