-- Candidato de estrutura (R04 continuacao, 11/09/2026): criar instituicao aceita o
-- tipo pelo NOME. O assistente do Superadmin digita o tipo como texto livre
-- (InstitutionFormField.typeName) e o unico catalogo que o cliente le
-- (superadmin_institution_filter_options_v2) so lista tipos ja em uso por
-- instituicoes; com o catalogo vazio de instituicoes nenhum id chega ao cliente,
-- e superadmin_institution_create_v2 (180340, em producao) so aceitava
-- institution_type_id. Forward-only sobre 180340: substitui os dois helpers
-- privados criados la (nao sao compartilhados) para aceitar institution_type_name
-- (resolvido sem diferenciar maiusculas contra institution_types ativos; erro
-- SAI_INVALID_ARGUMENT quando nao existe). O contrato por id continua igual; os
-- dois juntos so sao aceitos quando apontam para o mesmo tipo.
begin;

do $preflight$
begin
  if current_user<>'postgres' then
    raise insufficient_privilege using
      message='institution create type-by-name migration must run as postgres';
  end if;
  if to_regprocedure('app_private.superadmin_institution_create_validate_v2(jsonb)') is null
    or to_regprocedure('app_private.superadmin_institution_create_apply_v2(uuid,jsonb,bytea,app_private.superadmin_internal_context,uuid)') is null
    or to_regprocedure('public.superadmin_institution_create_v2(uuid,jsonb)') is null
    or to_regprocedure('app_private.superadmin_institution_edit_core_validate_v2(jsonb)') is null
    or to_regclass('app_private.superadmin_internal_institution_create_receipts') is null then
    raise object_not_in_prerequisite_state using
      message='superadmin_institution_create_v2 (180340) is required';
  end if;
end
$preflight$;

create or replace function app_private.superadmin_institution_create_validate_v2(
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
  type_name text;
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

  if p_payload?'institution_type_name' then
    if pg_catalog.jsonb_typeof(p_payload->'institution_type_name')<>'string' then
      raise invalid_parameter_value using
        message='invalid institution type name',detail='SAI_INVALID_ARGUMENT';
    end if;
    type_name:=pg_catalog.btrim(p_payload->>'institution_type_name');
    if type_name='' or pg_catalog.octet_length(type_name)>120
      or type_name ~ '[[:cntrl:]]' then
      raise invalid_parameter_value using
        message='invalid institution type name',detail='SAI_INVALID_ARGUMENT';
    end if;
  end if;

  normalized_payload:=
    app_private.superadmin_institution_edit_core_validate_v2(
      p_payload-'slug'-'institution_type_name'
    );

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

  return normalized_payload
    ||pg_catalog.jsonb_build_object('slug',normalized_slug)
    ||case when type_name is null then '{}'::jsonb
      else pg_catalog.jsonb_build_object('institution_type_name',type_name) end;
end
$$;

create or replace function app_private.superadmin_institution_create_apply_v2(
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
  named_type_id uuid;
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

  if p_payload?'institution_type_name' then
    select institution_type.id into named_type_id
    from public.institution_types institution_type
    where pg_catalog.lower(institution_type.name)
        =pg_catalog.lower(p_payload->>'institution_type_name')
      and institution_type.status='active'
    order by institution_type.created_at,institution_type.id
    limit 1
    for share;
    if named_type_id is null then
      raise invalid_parameter_value using
        message='unknown or inactive institution type',detail='SAI_INVALID_ARGUMENT';
    end if;
    if requested_type_id is not null and requested_type_id<>named_type_id then
      raise invalid_parameter_value using
        message='institution type id and name disagree',detail='SAI_INVALID_ARGUMENT';
    end if;
    requested_type_id:=named_type_id;
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

-- Os REVOKEs de 180340 sobrevivem ao CREATE OR REPLACE (a ACL fica na funcao),
-- mas a pos-condicao confere para o pacote nao depender disso em silencio.
do $postcondition$
begin
  if has_function_privilege('authenticated',
      'app_private.superadmin_institution_create_validate_v2(jsonb)','execute')
    or has_function_privilege('anon',
      'app_private.superadmin_institution_create_apply_v2(uuid,jsonb,bytea,app_private.superadmin_internal_context,uuid)','execute') then
    raise object_not_in_prerequisite_state using
      message='private create helpers must not be executable by clients';
  end if;
end
$postcondition$;

commit;
