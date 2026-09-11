-- Candidato de estrutura (R04, 11/09/2026): criar instituicao pelo realm interno v2.
-- Producao so tem create_institution_for_superadmin (people-based: current_person_id,
-- has_scoped_platform_permission, MFA AAL2), que nega o usuario do realm interno.
-- Este pacote segue o contrato de superadmin_institution_edit_core_v2 (lote 3):
-- validador ROOT+ADDRESS reutilizado, recibo por request_id, envelope e auditoria
-- internos. Cria sempre em status 'draft'; status, contato, documento, dominio,
-- assinatura e marca continuam fora deste fluxo. Capacidade: institution.activate
-- (ja existe no catalogo: "Ativar instituicoes e criar configuracao inicial").
begin;

do $preflight$
begin
  if current_user<>'postgres' then
    raise insufficient_privilege using
      message='internal institution create migration must run as postgres';
  end if;
  if to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or to_regprocedure(
      'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)'
    ) is null
    or to_regprocedure(
      'app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)'
    ) is null
    or to_regprocedure('app_private.superadmin_internal_error_envelope(text,uuid)') is null
    or to_regprocedure('app_private.superadmin_institution_edit_core_validate_v2(jsonb)') is null
    or to_regprocedure('app_private.normalize_institution_handle(text)') is null
    or to_regclass('app_private.superadmin_internal_identities') is null
    or to_regclass('public.institutions') is null
    or to_regclass('public.institution_types') is null
    or to_regclass('public.institution_addresses') is null then
    raise object_not_in_prerequisite_state using
      message='internal Auth, audit, edit core validator and institution dependencies are required';
  end if;
  if not exists(
    select 1 from public.platform_permissions permission_record
    where permission_record.code='institution.activate'
      and permission_record.status='active'
  ) then
    raise object_not_in_prerequisite_state using
      message='active institution.activate capability is required';
  end if;
  if to_regprocedure('public.superadmin_institution_create_v2(uuid,jsonb)') is not null
    or to_regclass('app_private.superadmin_internal_institution_create_receipts') is not null then
    raise duplicate_object using
      message='institution create v2 objects already exist';
  end if;
end
$preflight$;

create table app_private.superadmin_internal_institution_create_receipts(
  request_id uuid primary key,
  actor_internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id),
  institution_id uuid not null references public.institutions(id),
  request_hash bytea not null check(pg_catalog.octet_length(request_hash)=32),
  original_correlation_id uuid not null,
  created_at timestamptz not null default pg_catalog.now()
);

comment on column
  app_private.superadmin_internal_institution_create_receipts.request_hash is
  'Derived pseudonymous command hash; private, non-exportable and without retention automation';

create index superadmin_internal_institution_create_receipts_actor_idx
  on app_private.superadmin_internal_institution_create_receipts(
    actor_internal_identity_id
  );
create index superadmin_internal_institution_create_receipts_institution_idx
  on app_private.superadmin_internal_institution_create_receipts(institution_id);

alter table app_private.superadmin_internal_institution_create_receipts
  enable row level security;
alter table app_private.superadmin_internal_institution_create_receipts
  force row level security;
revoke all on table
  app_private.superadmin_internal_institution_create_receipts
  from public,anon,authenticated,service_role;

-- Valida o payload de criacao: as chaves ROOT+ADDRESS passam pelo validador do
-- EDIT CORE (mesmos limites, timezone, locale, CEP e pais); 'slug' e a unica
-- chave extra e segue a regra do trigger institutions_enforce_handle.
create function app_private.superadmin_institution_create_validate_v2(
  p_payload jsonb
) returns jsonb
language plpgsql
stable
security invoker
set search_path=''
as $$
declare
  normalized_payload jsonb;
  normalized_slug text;
begin
  if p_payload is null
    or pg_catalog.jsonb_typeof(p_payload)<>'object'
    or pg_catalog.octet_length(p_payload::text)>65536 then
    raise invalid_parameter_value using
      message='invalid institution create payload',detail='SAI_INVALID_ARGUMENT';
  end if;
  if not(p_payload?'slug') or pg_catalog.jsonb_typeof(p_payload->'slug')<>'string'
    or not(p_payload?'public_name') then
    raise invalid_parameter_value using
      message='slug and public_name are required',detail='SAI_INVALID_ARGUMENT';
  end if;

  normalized_payload:=
    app_private.superadmin_institution_edit_core_validate_v2(p_payload-'slug');

  if pg_catalog.jsonb_typeof(normalized_payload->'public_name') is distinct from 'string' then
    raise invalid_parameter_value using
      message='public_name is required',detail='SAI_INVALID_ARGUMENT';
  end if;
  if normalized_payload?'address'
    and (
      not((normalized_payload->'address')?'country')
      or normalized_payload->'address'->>'country' is distinct from 'Brasil'
    ) then
    raise invalid_parameter_value using
      message='country Brasil is required for a new institution address',
      detail='SAI_INVALID_ARGUMENT';
  end if;

  normalized_slug:=app_private.normalize_institution_handle(p_payload->>'slug');
  if normalized_slug !~ '^[a-z0-9][a-z0-9._-]{2,29}$' then
    raise invalid_parameter_value using
      message='institution handle must have 3 to 30 allowed characters',
      detail='SAI_INVALID_ARGUMENT';
  end if;

  return normalized_payload||pg_catalog.jsonb_build_object('slug',normalized_slug);
end
$$;

create function app_private.superadmin_institution_create_request_hash_v2(
  p_payload jsonb
) returns bytea
language sql
immutable
security invoker
set search_path=''
as $$
  select extensions.digest(
    pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'command_kind','institution.create',
        'payload',p_payload
      )::text,
      'UTF8'
    ),
    'sha256'
  )
$$;

create function app_private.superadmin_institution_create_apply_v2(
  p_request_id uuid,
  p_payload jsonb,
  p_request_hash bytea,
  p_context app_private.superadmin_internal_context,
  p_correlation_id uuid
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  prior_receipt app_private.superadmin_internal_institution_create_receipts%rowtype;
  requested_type_id uuid;
  new_institution_id uuid;
  result_version bigint;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_request_id::text,0)
  );

  select receipt.* into prior_receipt
  from app_private.superadmin_internal_institution_create_receipts receipt
  where receipt.request_id=p_request_id;

  if prior_receipt.request_id is not null then
    if prior_receipt.actor_internal_identity_id
         is distinct from p_context.internal_identity_id
      or prior_receipt.request_hash is distinct from p_request_hash then
      raise invalid_parameter_value using
        message='request id already used',detail='SAI_INVALID_ARGUMENT';
    end if;
    select institution.management_version into result_version
    from public.institutions institution
    where institution.id=prior_receipt.institution_id;
    return pg_catalog.jsonb_build_object(
      'institution_id',prior_receipt.institution_id,
      'management_version',result_version,
      'correlation_id',p_correlation_id,
      'replayed',true
    );
  end if;

  if p_payload?'institution_type_id' then
    select institution_type.id into requested_type_id
    from public.institution_types institution_type
    where institution_type.id=(p_payload->>'institution_type_id')::uuid
      and institution_type.status='active'
    for share;
    if not found then
      raise invalid_parameter_value using
        message='invalid institution type',detail='SAI_INVALID_ARGUMENT';
    end if;
  end if;

  if exists(
    select 1 from public.institutions institution
    where institution.slug=p_payload->>'slug'
  ) then
    raise unique_violation using
      message='institution handle already in use',detail='SAI_INVALID_ARGUMENT';
  end if;

  insert into public.institutions(
    public_name,trade_name,legal_name,slug,status,timezone,locale,
    institution_type_id
  ) values(
    p_payload->>'public_name',
    p_payload->>'trade_name',
    p_payload->>'legal_name',
    p_payload->>'slug',
    'draft',
    coalesce(p_payload->>'timezone','America/Sao_Paulo'),
    coalesce(p_payload->>'locale','pt-BR'),
    requested_type_id
  )
  returning id,management_version into new_institution_id,result_version;

  if p_payload?'address' then
    insert into public.institution_addresses(
      institution_id,country,state,city,district,street,number,complement,
      postal_code,status,created_at,updated_at
    ) values(
      new_institution_id,
      p_payload->'address'->>'country',
      p_payload->'address'->>'state',
      p_payload->'address'->>'city',
      p_payload->'address'->>'district',
      p_payload->'address'->>'street',
      p_payload->'address'->>'number',
      p_payload->'address'->>'complement',
      p_payload->'address'->>'postal_code',
      'active',pg_catalog.now(),pg_catalog.now()
    );
  end if;

  insert into app_private.superadmin_internal_institution_create_receipts(
    request_id,actor_internal_identity_id,institution_id,request_hash,
    original_correlation_id
  ) values(
    p_request_id,p_context.internal_identity_id,new_institution_id,
    p_request_hash,p_correlation_id
  );

  return pg_catalog.jsonb_build_object(
    'institution_id',new_institution_id,
    'management_version',result_version,
    'correlation_id',p_correlation_id,
    'replayed',false
  );
end
$$;

create function public.superadmin_institution_create_v2(
  p_request_id uuid,
  p_payload jsonb
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  context_record app_private.superadmin_internal_context;
  correlation_id uuid:=gen_random_uuid();
  normalized_payload jsonb;
  request_hash bytea;
  response_data jsonb;
  error_code text;
  error_detail text;
begin
  begin
    select * into strict context_record
    from app_private.require_superadmin_internal_context('institution.activate');

    if context_record.platform_role_code not in('owner','operations') then
      raise insufficient_privilege using
        message='internal institution access denied',detail='SAI_PERMISSION_DENIED';
    end if;
    -- Criar instituicao e ato de plataforma: membership com escopo de
    -- instituicao nao cria outra instituicao.
    if context_record.scope_kind is distinct from 'platform' then
      raise insufficient_privilege using
        message='internal institution access denied',detail='SAI_PERMISSION_DENIED';
    end if;

    if p_request_id is null then
      raise invalid_parameter_value using
        message='invalid institution create request',detail='SAI_INVALID_ARGUMENT';
    end if;
    normalized_payload:=
      app_private.superadmin_institution_create_validate_v2(p_payload);
    request_hash:=app_private.superadmin_institution_create_request_hash_v2(
      normalized_payload
    );
    response_data:=app_private.superadmin_institution_create_apply_v2(
      p_request_id,normalized_payload,request_hash,context_record,correlation_id
    );
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail=pg_exception_detail;
      error_code:=case when error_detail in(
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED',
        'SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED'
      ) then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation or unique_violation
      or foreign_key_violation or invalid_text_representation then
      error_code:='SAI_INVALID_ARGUMENT';
    when others then
      error_code:='SAI_INTERNAL_ERROR';
  end;

  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'institution.activate','institution.create',error_code,correlation_id,null
    );
    return app_private.superadmin_internal_error_envelope(
      error_code,correlation_id
    );
  end if;

  -- Replay idempotente nao muda estado: devolve o recibo sem novo evento.
  if (response_data->>'replayed')::boolean is not true then
    perform app_private.audit_append_superadmin_internal(
      context_record.internal_identity_id,
      context_record.internal_auth_link_id,
      context_record.internal_membership_id,
      context_record.session_id,
      'institution.activate',
      context_record.aal,
      'institution.create',
      'success',
      null,
      correlation_id,
      (response_data->>'institution_id')::uuid,
      'institution',
      (response_data->>'institution_id')::uuid
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'ok',true,
    'data',response_data,
    'error',null
  );
end
$$;

revoke all on function
  app_private.superadmin_institution_create_validate_v2(jsonb),
  app_private.superadmin_institution_create_request_hash_v2(jsonb),
  app_private.superadmin_institution_create_apply_v2(
    uuid,jsonb,bytea,app_private.superadmin_internal_context,uuid
  )
  from public,anon,authenticated,service_role;
revoke all on function public.superadmin_institution_create_v2(uuid,jsonb)
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_institution_create_v2(uuid,jsonb)
  to authenticated;

comment on function public.superadmin_institution_create_v2(uuid,jsonb) is
  'Internal realm v2 institution create: ROOT+ADDRESS only, always draft, idempotent by request_id, audited.';

commit;
