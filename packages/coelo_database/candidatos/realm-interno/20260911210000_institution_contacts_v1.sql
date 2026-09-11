-- R05 realm-interno (1): institution_contacts_v1
--
-- Destrava institutions.edit: o assistente do Superadmin exige documento
-- (CNPJ), contato, representantes legais e administradores, que a criacao v2
-- (180340/180360) e a edicao core v2 (230002) nao persistem. Este pacote:
--
--   * public.superadmin_institution_contacts_edit_v1(p_request_id,
--     p_institution_id, p_expected_version, p_payload): persiste documento,
--     contato da instituicao, representantes legais e administradores como
--     pessoas do realm (public.people + institution_memberships +
--     institution_legal_representatives), com recibo idempotente na mesma
--     tabela de recibos da edicao core, versao otimista
--     (management_version) e auditoria interna (13 argumentos).
--   * app_private.superadmin_institution_detail_payload_v2 passa a devolver
--     `representatives` e `administrators` (dados minimizados: nomes e
--     contatos mascarados) para o reload do assistente.
--
-- LGPD: e-mail e celular das pessoas ficam em person_contacts como hash
-- sha256 + mascara (desenho da baseline); CPF fica em
-- app_private.person_identity_identifiers como HMAC-SHA256 com chave no Vault
-- (`coelo_person_identity_hmac_v1`, criada aqui se nao existir; o valor nunca
-- sai do banco). Nenhum valor bruto e devolvido ao cliente.
--
-- Regras:
--   * representantes precisam de membership ativa na instituicao (trigger da
--     baseline); sem date_of_birth (o assistente nao pede) o vinculo nasce
--     `draft`; com data e maior de 18 anos nasce `active`.
--   * administradores viram institution_memberships com role_code
--     owner | institution_admin | coordinator (levels admin_master |
--     authorized_administrator | coordinator do cliente).
--   * semantica de substituicao: quem estiver ativo e nao vier na lista e
--     encerrado (representante -> inactive/ends_on; administrador -> role
--     rebaixada para legal_representative se continuar representante, senao
--     membership inactive/revoked_at).
--   * um mesmo request_id so repete com o mesmo ator, instituicao, versao e
--     hash; senao SAI_INVALID_ARGUMENT.
--
-- Reversao: drop function public.superadmin_institution_contacts_edit_v1,
-- app_private.superadmin_institution_contacts_*_v1, app_private.person_*_v1
-- deste arquivo e recriar superadmin_institution_detail_payload_v2 como em
-- 20260910180330.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using
      message = 'institution contacts migration must run as postgres';
  end if;
  if to_regprocedure('app_private.require_superadmin_internal_context(text)') is null
    or to_regprocedure(
      'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)'
    ) is null
    or to_regprocedure(
      'app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)'
    ) is null
    or to_regprocedure('app_private.superadmin_internal_error_envelope(text,uuid)') is null
    or to_regprocedure('app_private.institution_management_payload(uuid)') is null
    or to_regprocedure('app_private.superadmin_institution_detail_payload_v2(uuid)') is null
    or to_regclass('app_private.superadmin_internal_institution_edit_receipts') is null
    or to_regclass('public.institution_contacts') is null
    or to_regclass('public.institution_legal_representatives') is null
    or to_regclass('public.institution_memberships') is null
    or to_regclass('public.person_contacts') is null
    or to_regclass('app_private.person_identity_identifiers') is null
    or to_regclass('vault.secrets') is null then
    raise object_not_in_prerequisite_state using
      message = 'internal Auth, audit, institution and vault dependencies are required';
  end if;
end
$preflight$;

-- ---------------------------------------------------------------------------
-- Chave HMAC do catalogo de identidade (CPF). Gerada no banco; nunca impressa.
-- ---------------------------------------------------------------------------
do $vault$
begin
  if not exists (select 1 from vault.secrets where name = 'coelo_person_identity_hmac_v1') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'coelo_person_identity_hmac_v1',
      'HMAC key (versao 1) do catalogo app_private.person_identity_identifiers'
    );
  end if;
end
$vault$;

create function app_private.person_identity_hmac_v1(p_digits text)
returns bytea
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  key_value text;
begin
  select decrypted_secret into key_value
  from vault.decrypted_secrets
  where name = 'coelo_person_identity_hmac_v1'
  limit 1;
  if key_value is null then
    raise object_not_in_prerequisite_state using
      message = 'person identity hmac key is missing';
  end if;
  return extensions.hmac(pg_catalog.convert_to(p_digits, 'UTF8'),
    pg_catalog.convert_to(key_value, 'UTF8'), 'sha256');
end
$$;

revoke all on function app_private.person_identity_hmac_v1(text)
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Normalizacao e mascaras (funcoes puras)
-- ---------------------------------------------------------------------------
create function app_private.cpf_digits_valid_v1(p_digits text)
returns boolean
language plpgsql
immutable
security invoker
set search_path = ''
as $$
declare
  sum1 integer := 0;
  sum2 integer := 0;
  d integer[];
  i integer;
begin
  if p_digits is null or p_digits !~ '^[0-9]{11}$' then
    return false;
  end if;
  if p_digits ~ '^(\d)\1{10}$' then
    return false;
  end if;
  for i in 1..11 loop
    d[i] := pg_catalog.substr(p_digits, i, 1)::integer;
  end loop;
  for i in 1..9 loop
    sum1 := sum1 + d[i] * (11 - i);
  end loop;
  sum1 := (sum1 * 10) % 11;
  if sum1 = 10 then sum1 := 0; end if;
  if sum1 <> d[10] then return false; end if;
  for i in 1..10 loop
    sum2 := sum2 + d[i] * (12 - i);
  end loop;
  sum2 := (sum2 * 10) % 11;
  if sum2 = 10 then sum2 := 0; end if;
  return sum2 = d[11];
end
$$;

create function app_private.cnpj_digits_valid_v1(p_digits text)
returns boolean
language plpgsql
immutable
security invoker
set search_path = ''
as $$
declare
  w1 integer[] := array[5,4,3,2,9,8,7,6,5,4,3,2];
  w2 integer[] := array[6,5,4,3,2,9,8,7,6,5,4,3,2];
  d integer[];
  s integer := 0;
  i integer;
  dv1 integer;
  dv2 integer;
begin
  if p_digits is null or p_digits !~ '^[0-9]{14}$' then
    return false;
  end if;
  if p_digits ~ '^(\d)\1{13}$' then
    return false;
  end if;
  for i in 1..14 loop
    d[i] := pg_catalog.substr(p_digits, i, 1)::integer;
  end loop;
  for i in 1..12 loop s := s + d[i] * w1[i]; end loop;
  dv1 := case when s % 11 < 2 then 0 else 11 - (s % 11) end;
  if dv1 <> d[13] then return false; end if;
  s := 0;
  for i in 1..13 loop s := s + d[i] * w2[i]; end loop;
  dv2 := case when s % 11 < 2 then 0 else 11 - (s % 11) end;
  return dv2 = d[14];
end
$$;

create function app_private.mask_email_v1(p_email text)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select case
    when p_email is null then null
    else pg_catalog.left(pg_catalog.split_part(p_email, '@', 1), 1) || '***@'
      || pg_catalog.split_part(p_email, '@', 2)
  end
$$;

create function app_private.mask_phone_v1(p_digits text)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select case
    when p_digits is null then null
    else pg_catalog.repeat('*', greatest(pg_catalog.char_length(p_digits) - 4, 0))
      || pg_catalog.right(p_digits, 4)
  end
$$;

create function app_private.mask_cpf_v1(p_digits text)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select '***.***.***-' || pg_catalog.right(p_digits, 2)
$$;

revoke all on function app_private.cpf_digits_valid_v1(text),
  app_private.cnpj_digits_valid_v1(text), app_private.mask_email_v1(text),
  app_private.mask_phone_v1(text), app_private.mask_cpf_v1(text)
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Validacao do payload (normaliza e devolve o payload canonico)
-- ---------------------------------------------------------------------------
create function app_private.superadmin_institution_contacts_validate_person_v1(
  p_person jsonb,
  p_kind text
) returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  unknown_key text;
  key_name text;
  out_person jsonb := '{}'::jsonb;
  email_value text;
  phone_digits text;
  cpf_digits text;
  level_value text;
  dob date;
begin
  if p_person is null or pg_catalog.jsonb_typeof(p_person) <> 'object' then
    raise invalid_parameter_value using
      message = 'invalid person entry', detail = 'SAI_INVALID_ARGUMENT';
  end if;
  select k into unknown_key
  from pg_catalog.jsonb_object_keys(p_person) k
  where not (k = any(array[
    'person_id','first_name','last_name','display_name','email','mobile_phone',
    'cpf','date_of_birth','is_primary','level'
  ]::text[]))
  limit 1;
  if unknown_key is not null then
    raise invalid_parameter_value using
      message = 'unknown person payload key', detail = 'SAI_INVALID_ARGUMENT';
  end if;

  if p_person ? 'person_id' and pg_catalog.jsonb_typeof(p_person -> 'person_id') <> 'null' then
    if pg_catalog.jsonb_typeof(p_person -> 'person_id') <> 'string'
      or (p_person ->> 'person_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise invalid_parameter_value using
        message = 'invalid person_id', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    out_person := out_person || pg_catalog.jsonb_build_object('person_id', p_person ->> 'person_id');
  end if;

  foreach key_name in array array['first_name','last_name','display_name']::text[] loop
    if p_person ? key_name and pg_catalog.jsonb_typeof(p_person -> key_name) <> 'null' then
      if pg_catalog.jsonb_typeof(p_person -> key_name) <> 'string'
        or pg_catalog.char_length(pg_catalog.btrim(p_person ->> key_name)) > 120
        or (p_person ->> key_name) ~ U&'[\0001-\001f\007f]' then
        raise invalid_parameter_value using
          message = 'invalid person name', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      if pg_catalog.btrim(p_person ->> key_name) <> '' then
        out_person := out_person
          || pg_catalog.jsonb_build_object(key_name, pg_catalog.btrim(p_person ->> key_name));
      end if;
    end if;
  end loop;
  if not (out_person ? 'person_id')
    and (not (out_person ? 'first_name') or not (out_person ? 'last_name')) then
    raise invalid_parameter_value using
      message = 'first_name and last_name are required for a new person',
      detail = 'SAI_INVALID_ARGUMENT';
  end if;

  if p_person ? 'email' and pg_catalog.jsonb_typeof(p_person -> 'email') <> 'null' then
    email_value := pg_catalog.lower(pg_catalog.btrim(p_person ->> 'email'));
    if email_value <> '' then
      if pg_catalog.char_length(email_value) > 254
        or email_value !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
        raise invalid_parameter_value using
          message = 'invalid person email', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      out_person := out_person || pg_catalog.jsonb_build_object('email', email_value);
    end if;
  end if;

  if p_person ? 'mobile_phone' and pg_catalog.jsonb_typeof(p_person -> 'mobile_phone') <> 'null' then
    phone_digits := pg_catalog.regexp_replace(coalesce(p_person ->> 'mobile_phone', ''), '[^0-9]', '', 'g');
    if phone_digits <> '' then
      if phone_digits !~ '^[0-9]{10,13}$' then
        raise invalid_parameter_value using
          message = 'invalid person mobile_phone', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      out_person := out_person || pg_catalog.jsonb_build_object('mobile_phone', phone_digits);
    end if;
  end if;

  if p_person ? 'cpf' and pg_catalog.jsonb_typeof(p_person -> 'cpf') <> 'null' then
    cpf_digits := pg_catalog.regexp_replace(coalesce(p_person ->> 'cpf', ''), '[^0-9]', '', 'g');
    if cpf_digits <> '' then
      if not app_private.cpf_digits_valid_v1(cpf_digits) then
        raise invalid_parameter_value using
          message = 'invalid person cpf', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      out_person := out_person || pg_catalog.jsonb_build_object('cpf', cpf_digits);
    end if;
  end if;

  if p_person ? 'date_of_birth' and pg_catalog.jsonb_typeof(p_person -> 'date_of_birth') <> 'null' then
    begin
      dob := (p_person ->> 'date_of_birth')::date;
    exception when others then
      raise invalid_parameter_value using
        message = 'invalid date_of_birth', detail = 'SAI_INVALID_ARGUMENT';
    end;
    if dob > current_date or dob < date '1900-01-01' then
      raise invalid_parameter_value using
        message = 'invalid date_of_birth', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    out_person := out_person || pg_catalog.jsonb_build_object('date_of_birth', dob);
  end if;

  if p_kind = 'representative' then
    if p_person ? 'level' then
      raise invalid_parameter_value using
        message = 'level is only for administrators', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    out_person := out_person || pg_catalog.jsonb_build_object(
      'is_primary', coalesce((p_person ->> 'is_primary')::boolean, false));
  else
    if p_person ? 'is_primary' then
      raise invalid_parameter_value using
        message = 'is_primary is only for representatives', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    level_value := coalesce(p_person ->> 'level', '');
    if level_value not in ('admin_master','authorized_administrator','coordinator') then
      raise invalid_parameter_value using
        message = 'invalid administrator level', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    out_person := out_person || pg_catalog.jsonb_build_object('level', level_value);
  end if;

  return out_person;
end
$$;

create function app_private.superadmin_institution_contacts_validate_v1(
  p_payload jsonb
) returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  unknown_key text;
  key_name text;
  out_payload jsonb := '{}'::jsonb;
  child jsonb;
  out_child jsonb;
  entry jsonb;
  items jsonb;
  text_value text;
  digits text;
  primary_count integer;
begin
  if p_payload is null
    or pg_catalog.jsonb_typeof(p_payload) <> 'object'
    or p_payload = '{}'::jsonb
    or pg_catalog.octet_length(p_payload::text) > 65536 then
    raise invalid_parameter_value using
      message = 'invalid institution contacts payload', detail = 'SAI_INVALID_ARGUMENT';
  end if;
  select k into unknown_key
  from pg_catalog.jsonb_object_keys(p_payload) k
  where not (k = any(array['document','contact','representatives','administrators']::text[]))
  limit 1;
  if unknown_key is not null then
    raise invalid_parameter_value using
      message = 'unknown institution contacts payload key', detail = 'SAI_INVALID_ARGUMENT';
  end if;

  -- documento
  if p_payload ? 'document' then
    child := p_payload -> 'document';
    if pg_catalog.jsonb_typeof(child) <> 'object' then
      raise invalid_parameter_value using
        message = 'document must be an object', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    select k into unknown_key from pg_catalog.jsonb_object_keys(child) k
    where not (k = any(array['document_type','document_ref']::text[])) limit 1;
    if unknown_key is not null then
      raise invalid_parameter_value using
        message = 'unknown document payload key', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    text_value := pg_catalog.lower(pg_catalog.btrim(coalesce(child ->> 'document_type', 'cnpj')));
    if text_value <> 'cnpj' then
      raise invalid_parameter_value using
        message = 'only cnpj documents are supported', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    digits := pg_catalog.regexp_replace(coalesce(child ->> 'document_ref', ''), '[^0-9]', '', 'g');
    if digits = '' then
      out_child := pg_catalog.jsonb_build_object('document_type', 'cnpj', 'document_ref', null);
    else
      if not app_private.cnpj_digits_valid_v1(digits) then
        raise invalid_parameter_value using
          message = 'invalid cnpj', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      out_child := pg_catalog.jsonb_build_object('document_type', 'cnpj', 'document_ref', digits);
    end if;
    out_payload := out_payload || pg_catalog.jsonb_build_object('document', out_child);
  end if;

  -- contato da instituicao
  if p_payload ? 'contact' then
    child := p_payload -> 'contact';
    if pg_catalog.jsonb_typeof(child) <> 'object' then
      raise invalid_parameter_value using
        message = 'contact must be an object', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    select k into unknown_key from pg_catalog.jsonb_object_keys(child) k
    where not (k = any(array['email','phone','mobile_phone','website_url','whatsapp_number']::text[])) limit 1;
    if unknown_key is not null then
      raise invalid_parameter_value using
        message = 'unknown contact payload key', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    out_child := '{}'::jsonb;
    foreach key_name in array array['email','phone','mobile_phone','website_url','whatsapp_number']::text[] loop
      if pg_catalog.jsonb_typeof(child -> key_name) = 'string' then
        text_value := pg_catalog.btrim(child ->> key_name);
        if text_value ~ U&'[\0001-\001f\007f]' or pg_catalog.char_length(text_value) > 2048 then
          raise invalid_parameter_value using
            message = 'invalid contact value', detail = 'SAI_INVALID_ARGUMENT';
        end if;
        if key_name = 'email' then text_value := pg_catalog.lower(text_value); end if;
        if key_name = 'email' and text_value <> ''
          and text_value !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
          raise invalid_parameter_value using
            message = 'invalid contact email', detail = 'SAI_INVALID_ARGUMENT';
        end if;
        if key_name in ('phone','mobile_phone') and text_value <> '' then
          text_value := pg_catalog.regexp_replace(text_value, '[^0-9+]', '', 'g');
          if text_value !~ '^\+?[0-9]{8,15}$' then
            raise invalid_parameter_value using
              message = 'invalid contact phone', detail = 'SAI_INVALID_ARGUMENT';
          end if;
        end if;
        if key_name = 'whatsapp_number' and text_value <> '' then
          text_value := pg_catalog.regexp_replace(text_value, '[^0-9+]', '', 'g');
          if text_value !~ '^\+' then text_value := '+' || text_value; end if;
          if text_value !~ '^\+[1-9][0-9]{7,14}$' then
            raise invalid_parameter_value using
              message = 'invalid whatsapp number', detail = 'SAI_INVALID_ARGUMENT';
          end if;
        end if;
        if key_name = 'website_url' and text_value <> ''
          and text_value !~* '^https?://[[:alnum:]]([[:alnum:].-]*[[:alnum:]])?(:[0-9]{1,5})?([/?#][^[:space:]]*)?$' then
          raise invalid_parameter_value using
            message = 'invalid website url', detail = 'SAI_INVALID_ARGUMENT';
        end if;
        out_child := out_child || pg_catalog.jsonb_build_object(key_name,
          case when text_value = '' then null else text_value end);
      elsif child ? key_name and pg_catalog.jsonb_typeof(child -> key_name) <> 'null' then
        raise invalid_parameter_value using
          message = 'invalid contact value', detail = 'SAI_INVALID_ARGUMENT';
      else
        out_child := out_child || pg_catalog.jsonb_build_object(key_name, null);
      end if;
    end loop;
    out_payload := out_payload || pg_catalog.jsonb_build_object('contact', out_child);
  end if;

  -- representantes legais
  if p_payload ? 'representatives' then
    if pg_catalog.jsonb_typeof(p_payload -> 'representatives') <> 'array'
      or pg_catalog.jsonb_array_length(p_payload -> 'representatives') > 20 then
      raise invalid_parameter_value using
        message = 'representatives must be an array of up to 20 entries',
        detail = 'SAI_INVALID_ARGUMENT';
    end if;
    items := '[]'::jsonb;
    for entry in select value from pg_catalog.jsonb_array_elements(p_payload -> 'representatives') loop
      items := items || app_private.superadmin_institution_contacts_validate_person_v1(entry, 'representative');
    end loop;
    select count(*) into primary_count
    from pg_catalog.jsonb_array_elements(items) e where (e ->> 'is_primary')::boolean;
    if primary_count > 1 then
      raise invalid_parameter_value using
        message = 'only one primary representative is allowed', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    out_payload := out_payload || pg_catalog.jsonb_build_object('representatives', items);
  end if;

  -- administradores
  if p_payload ? 'administrators' then
    if pg_catalog.jsonb_typeof(p_payload -> 'administrators') <> 'array'
      or pg_catalog.jsonb_array_length(p_payload -> 'administrators') > 20 then
      raise invalid_parameter_value using
        message = 'administrators must be an array of up to 20 entries',
        detail = 'SAI_INVALID_ARGUMENT';
    end if;
    items := '[]'::jsonb;
    for entry in select value from pg_catalog.jsonb_array_elements(p_payload -> 'administrators') loop
      items := items || app_private.superadmin_institution_contacts_validate_person_v1(entry, 'administrator');
    end loop;
    out_payload := out_payload || pg_catalog.jsonb_build_object('administrators', items);
  end if;

  return out_payload;
end
$$;

create function app_private.superadmin_institution_contacts_request_hash_v1(
  p_institution_id uuid,
  p_expected_version bigint,
  p_payload jsonb
) returns bytea
language sql
immutable
security invoker
set search_path = ''
as $$
  select extensions.digest(
    pg_catalog.convert_to(pg_catalog.jsonb_build_object(
      'command_kind', 'institution.edit_contacts',
      'institution_id', p_institution_id,
      'expected_version', p_expected_version,
      'payload', p_payload
    )::text, 'UTF8'),
    'sha256'
  )
$$;

-- ---------------------------------------------------------------------------
-- Pessoa do realm: cria ou atualiza people + contatos mascarados + CPF HMAC
-- ---------------------------------------------------------------------------
create function app_private.superadmin_institution_contacts_upsert_person_v1(
  p_person jsonb
) returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_person_id uuid;
  v_person_record public.people%rowtype;
  v_first_name text := p_person ->> 'first_name';
  v_last_name text := p_person ->> 'last_name';
  v_display_name text := p_person ->> 'display_name';
  v_email_value text := p_person ->> 'email';
  v_phone_digits text := p_person ->> 'mobile_phone';
  v_cpf_digits text := p_person ->> 'cpf';
  v_dob date := (p_person ->> 'date_of_birth')::date;
  v_new_hash text;
begin
  if p_person ? 'person_id' then
    v_person_id := (p_person ->> 'person_id')::uuid;
    select * into v_person_record from public.people where id = v_person_id for update;
    if v_person_record.id is null or v_person_record.deleted_at is not null
      or v_person_record.person_type <> 'adult' then
      raise invalid_parameter_value using
        message = 'person not found or not an adult', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    update public.people set
      first_name = coalesce(v_first_name, people.first_name),
      last_name = coalesce(v_last_name, people.last_name),
      display_name = coalesce(v_display_name,
        case when v_first_name is not null or v_last_name is not null
          then coalesce(v_first_name, people.first_name) || ' ' || coalesce(v_last_name, people.last_name)
          else people.display_name end),
      date_of_birth = coalesce(v_dob, people.date_of_birth),
      updated_at = pg_catalog.now()
    where id = v_person_id;
  else
    insert into public.people(person_type, first_name, last_name, display_name, date_of_birth, status)
    values ('adult', v_first_name, v_last_name,
      coalesce(v_display_name, v_first_name || ' ' || v_last_name), v_dob, 'active')
    returning id into v_person_id;
  end if;

  if v_email_value is not null then
    v_new_hash := encode(extensions.digest(pg_catalog.convert_to(v_email_value, 'UTF8'), 'sha256'), 'hex');
    if not exists (
      select 1 from public.person_contacts c
      where c.person_id = v_person_id and c.contact_type = 'email'
        and c.status = 'active' and c.normalized_value_hash = v_new_hash
    ) then
      update public.person_contacts set status = 'inactive'
      where person_contacts.person_id = v_person_id and contact_type = 'email' and status = 'active';
      insert into public.person_contacts(person_id, contact_type, normalized_value_hash, masked_value, status)
      values (v_person_id, 'email', v_new_hash, app_private.mask_email_v1(v_email_value), 'active');
    end if;
  end if;

  if v_phone_digits is not null then
    v_new_hash := encode(extensions.digest(pg_catalog.convert_to(v_phone_digits, 'UTF8'), 'sha256'), 'hex');
    if not exists (
      select 1 from public.person_contacts c
      where c.person_id = v_person_id and c.contact_type = 'mobile_phone'
        and c.status = 'active' and c.normalized_value_hash = v_new_hash
    ) then
      update public.person_contacts set status = 'inactive'
      where person_contacts.person_id = v_person_id and contact_type = 'mobile_phone' and status = 'active';
      insert into public.person_contacts(person_id, contact_type, normalized_value_hash, masked_value, status)
      values (v_person_id, 'mobile_phone', v_new_hash, app_private.mask_phone_v1(v_phone_digits), 'active');
    end if;
  end if;

  if v_cpf_digits is not null then
    if not exists (
      select 1 from app_private.person_identity_identifiers i
      where i.person_id = v_person_id and i.identifier_kind = 'cpf' and i.status = 'active'
        and i.normalized_value_hmac = app_private.person_identity_hmac_v1(v_cpf_digits)
    ) then
      update app_private.person_identity_identifiers
      set status = 'inactive', revoked_at = pg_catalog.now(), updated_at = pg_catalog.now()
      where person_identity_identifiers.person_id = v_person_id
        and identifier_kind = 'cpf' and status = 'active';
      insert into app_private.person_identity_identifiers(
        person_id, identifier_kind, normalized_value_hmac, hmac_key_version, masked_value, status)
      values (v_person_id, 'cpf', app_private.person_identity_hmac_v1(v_cpf_digits), 1,
        app_private.mask_cpf_v1(v_cpf_digits), 'active');
    end if;
  end if;

  return v_person_id;
end
$$;

-- ---------------------------------------------------------------------------
-- Aplicacao do comando
-- ---------------------------------------------------------------------------
create function app_private.superadmin_institution_contacts_apply_v1(
  p_request_id uuid,
  p_institution_id uuid,
  p_expected_version bigint,
  p_payload jsonb,
  p_request_hash bytea,
  p_context app_private.superadmin_internal_context,
  p_correlation_id uuid
) returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  prior_receipt app_private.superadmin_internal_institution_edit_receipts%rowtype;
  institution_record public.institutions%rowtype;
  v_contact_child jsonb;
  v_entry jsonb;
  v_person_id uuid;
  v_membership_id uuid;
  v_role_code_value text;
  v_rep_status public.record_status;
  v_dob date;
  kept_representative_ids uuid[] := '{}';
  kept_administrator_ids uuid[] := '{}';
  result_version bigint;
  admin_role_codes constant text[] := array['owner','institution_admin','coordinator'];
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text, 0));

  select receipt.* into prior_receipt
  from app_private.superadmin_internal_institution_edit_receipts receipt
  where receipt.request_id = p_request_id;
  if prior_receipt.request_id is not null then
    if prior_receipt.actor_internal_identity_id is distinct from p_context.internal_identity_id
      or prior_receipt.institution_id is distinct from p_institution_id
      or prior_receipt.expected_version is distinct from p_expected_version
      or prior_receipt.request_hash is distinct from p_request_hash then
      raise invalid_parameter_value using
        message = 'request id already used', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    return pg_catalog.jsonb_build_object(
      'institution_id', prior_receipt.institution_id,
      'management_version', prior_receipt.result_management_version,
      'correlation_id', p_correlation_id,
      'replayed', true);
  end if;

  select institution.* into institution_record
  from public.institutions institution
  where institution.id = p_institution_id and institution.deleted_at is null
  for update;
  if institution_record.id is null then
    raise insufficient_privilege using
      message = 'internal institution access denied', detail = 'SAI_PERMISSION_DENIED';
  end if;
  if institution_record.management_version is distinct from p_expected_version then
    raise serialization_failure using
      message = 'stale institution version', detail = 'SAI_CONCURRENT_CHANGE';
  end if;

  -- documento
  if p_payload ? 'document' then
    update public.institutions set
      document_type = p_payload -> 'document' ->> 'document_type',
      document_ref = p_payload -> 'document' ->> 'document_ref'
    where id = p_institution_id;
  end if;

  -- contato
  if p_payload ? 'contact' then
    v_contact_child := p_payload -> 'contact';
    if pg_catalog.num_nonnulls(v_contact_child ->> 'email', v_contact_child ->> 'phone',
        v_contact_child ->> 'mobile_phone', v_contact_child ->> 'website_url',
        v_contact_child ->> 'whatsapp_number') = 0 then
      delete from public.institution_contacts where institution_id = p_institution_id;
    else
      insert into public.institution_contacts(
        institution_id, email, phone, mobile_phone, website_url, whatsapp_number, status)
      values (p_institution_id, v_contact_child ->> 'email', v_contact_child ->> 'phone',
        v_contact_child ->> 'mobile_phone', v_contact_child ->> 'website_url',
        v_contact_child ->> 'whatsapp_number', 'active')
      on conflict (institution_id) do update set
        email = excluded.email, phone = excluded.phone, mobile_phone = excluded.mobile_phone,
        website_url = excluded.website_url, whatsapp_number = excluded.whatsapp_number,
        status = 'active', updated_at = pg_catalog.now();
    end if;
  end if;

  -- administradores primeiro (definem a role da membership)
  if p_payload ? 'administrators' then
    for v_entry in select value from pg_catalog.jsonb_array_elements(p_payload -> 'administrators') loop
      v_person_id := app_private.superadmin_institution_contacts_upsert_person_v1(v_entry);
      if v_person_id = any(kept_administrator_ids) then
        raise invalid_parameter_value using
          message = 'duplicate administrator', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      v_role_code_value := case v_entry ->> 'level'
        when 'admin_master' then 'owner'
        when 'authorized_administrator' then 'institution_admin'
        else 'coordinator' end;
      select m.id into v_membership_id from public.institution_memberships m
      where m.person_id = v_person_id and m.institution_id = p_institution_id
        and m.status = 'active' and m.revoked_at is null
      for update;
      if v_membership_id is null then
        insert into public.institution_memberships(
          person_id, institution_id, role_code, status, scope_kind, invited_by)
        values (v_person_id, p_institution_id, v_role_code_value, 'active', 'institution', null)
        returning id into v_membership_id;
      else
        update public.institution_memberships set role_code = v_role_code_value
        where id = v_membership_id and role_code is distinct from v_role_code_value;
      end if;
      kept_administrator_ids := kept_administrator_ids || v_person_id;
    end loop;
  end if;

  -- representantes legais
  if p_payload ? 'representatives' then
    for v_entry in select value from pg_catalog.jsonb_array_elements(p_payload -> 'representatives') loop
      v_person_id := app_private.superadmin_institution_contacts_upsert_person_v1(v_entry);
      if v_person_id = any(kept_representative_ids) then
        raise invalid_parameter_value using
          message = 'duplicate representative', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      select m.id into v_membership_id from public.institution_memberships m
      where m.person_id = v_person_id and m.institution_id = p_institution_id
        and m.status = 'active' and m.revoked_at is null
      for update;
      if v_membership_id is null then
        insert into public.institution_memberships(
          person_id, institution_id, role_code, status, scope_kind)
        values (v_person_id, p_institution_id, 'legal_representative', 'active', 'institution')
        returning id into v_membership_id;
      end if;
      select date_of_birth into v_dob from public.people where id = v_person_id;
      v_rep_status := case
        when v_dob is not null and v_dob <= (current_date - interval '18 years')::date then 'active'
        else 'draft' end;
      -- fecha vinculos do mesmo par em estado diferente e reaproveita o igual
      update public.institution_legal_representatives r set
        status = 'inactive', ends_on = coalesce(r.ends_on, greatest(current_date, r.starts_on))
      where r.institution_id = p_institution_id and r.person_id = v_person_id
        and r.status in ('active','draft') and r.status <> v_rep_status;
      if exists (
        select 1 from public.institution_legal_representatives r
        where r.institution_id = p_institution_id and r.person_id = v_person_id and r.status = v_rep_status
      ) then
        update public.institution_legal_representatives r set
          is_primary = coalesce((v_entry ->> 'is_primary')::boolean, false),
          membership_id = v_membership_id
        where r.institution_id = p_institution_id and r.person_id = v_person_id and r.status = v_rep_status;
      else
        insert into public.institution_legal_representatives(
          institution_id, person_id, membership_id, is_primary, starts_on, status)
        values (p_institution_id, v_person_id, v_membership_id,
          coalesce((v_entry ->> 'is_primary')::boolean, false), current_date, v_rep_status);
      end if;
      kept_representative_ids := kept_representative_ids || v_person_id;
    end loop;
    -- quem saiu da lista e encerrado
    update public.institution_legal_representatives r set
      status = 'inactive', ends_on = coalesce(r.ends_on, greatest(current_date, r.starts_on))
    where r.institution_id = p_institution_id and r.status in ('active','draft')
      and not (r.person_id = any(kept_representative_ids));
  end if;

  -- administradores que sairam da lista: rebaixa ou encerra a membership
  if p_payload ? 'administrators' then
    for v_membership_id, v_person_id in
      select m.id, m.person_id from public.institution_memberships m
      where m.institution_id = p_institution_id and m.status = 'active' and m.revoked_at is null
        and m.role_code = any(admin_role_codes)
        and not (m.person_id = any(kept_administrator_ids))
    loop
      if exists (
        select 1 from public.institution_legal_representatives r
        where r.membership_id = v_membership_id and r.status in ('active','draft')
      ) then
        update public.institution_memberships set role_code = 'legal_representative'
        where id = v_membership_id;
      else
        update public.institution_memberships set status = 'inactive', revoked_at = pg_catalog.now()
        where id = v_membership_id;
      end if;
    end loop;
  end if;

  -- representantes sem papel administrativo que sairam: encerra a membership orfa
  if p_payload ? 'representatives' then
    update public.institution_memberships m set status = 'inactive', revoked_at = pg_catalog.now()
    where m.institution_id = p_institution_id and m.status = 'active' and m.revoked_at is null
      and m.role_code = 'legal_representative'
      and not exists (
        select 1 from public.institution_legal_representatives r
        where r.membership_id = m.id and r.status in ('active','draft'));
  end if;

  update public.institutions institution set
    management_version = institution.management_version + 1,
    updated_at = greatest(pg_catalog.clock_timestamp(),
      institution.updated_at + interval '1 microsecond')
  where institution.id = p_institution_id
  returning institution.management_version into result_version;

  insert into app_private.superadmin_internal_institution_edit_receipts(
    request_id, actor_internal_identity_id, institution_id, expected_version,
    request_hash, result_management_version, original_correlation_id)
  values (p_request_id, p_context.internal_identity_id, p_institution_id,
    p_expected_version, p_request_hash, result_version, p_correlation_id);

  return pg_catalog.jsonb_build_object(
    'institution_id', p_institution_id,
    'management_version', result_version,
    'correlation_id', p_correlation_id,
    'replayed', false);
end
$$;

-- ---------------------------------------------------------------------------
-- RPC publica
-- ---------------------------------------------------------------------------
create function public.superadmin_institution_contacts_edit_v1(
  p_request_id uuid,
  p_institution_id uuid,
  p_expected_version bigint,
  p_payload jsonb
) returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  context_record app_private.superadmin_internal_context;
  correlation_id uuid := gen_random_uuid();
  normalized_payload jsonb;
  request_hash bytea;
  response_data jsonb;
  error_code text;
  error_detail text;
begin
  begin
    select * into strict context_record
    from app_private.require_superadmin_internal_context('institution.update');

    if context_record.platform_role_code not in ('owner','operations') then
      raise insufficient_privilege using
        message = 'internal institution access denied', detail = 'SAI_PERMISSION_DENIED';
    end if;
    if p_institution_id is null
      or (context_record.scope_kind = 'institution'
        and context_record.scope_institution_id is distinct from p_institution_id) then
      raise insufficient_privilege using
        message = 'internal institution access denied', detail = 'SAI_PERMISSION_DENIED';
    end if;
    if p_request_id is null or p_expected_version is null or p_expected_version <= 0 then
      raise invalid_parameter_value using
        message = 'invalid institution contacts request', detail = 'SAI_INVALID_ARGUMENT';
    end if;

    normalized_payload := app_private.superadmin_institution_contacts_validate_v1(p_payload);
    request_hash := app_private.superadmin_institution_contacts_request_hash_v1(
      p_institution_id, p_expected_version, normalized_payload);
    response_data := app_private.superadmin_institution_contacts_apply_v1(
      p_request_id, p_institution_id, p_expected_version, normalized_payload,
      request_hash, context_record, correlation_id);
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail in (
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED',
        'SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED'
      ) then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation or unique_violation
      or foreign_key_violation or not_null_violation or invalid_text_representation then
      error_code := 'SAI_INVALID_ARGUMENT';
    when serialization_failure then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail = 'SAI_CONCURRENT_CHANGE'
        then error_detail else 'SAI_INTERNAL_ERROR' end;
    when others then
      error_code := 'SAI_INTERNAL_ERROR';
  end;

  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified(
      'institution.update', 'institution.edit_contacts', error_code, correlation_id,
      case when context_record.scope_kind = 'institution'
        then context_record.scope_institution_id end);
    return app_private.superadmin_internal_error_envelope(error_code, correlation_id);
  end if;

  perform app_private.audit_append_superadmin_internal(
    context_record.internal_identity_id,
    context_record.internal_auth_link_id,
    context_record.internal_membership_id,
    context_record.session_id,
    'institution.update',
    context_record.aal,
    case when (response_data ->> 'replayed')::boolean
      then 'institution.edit_contacts.replay' else 'institution.edit_contacts' end,
    'success',
    null,
    correlation_id,
    p_institution_id,
    'institution',
    p_institution_id
  );

  return pg_catalog.jsonb_build_object('ok', true, 'data', response_data, 'error', null);
end
$$;

-- ---------------------------------------------------------------------------
-- Detalhe: representatives e administrators (minimizados)
-- ---------------------------------------------------------------------------
create or replace function app_private.superadmin_institution_detail_payload_v2(
  p_institution_id uuid
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select app_private.institution_management_payload(p_institution_id)
    || pg_catalog.jsonb_build_object(
      'representatives', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', r.id,
          'person_id', p.id,
          'membership_id', r.membership_id,
          'is_primary', r.is_primary,
          'status', r.status::text,
          'starts_on', r.starts_on,
          'first_name', p.first_name,
          'last_name', p.last_name,
          'display_name', p.display_name,
          'date_of_birth', p.date_of_birth,
          'email_masked', (select c.masked_value from public.person_contacts c
            where c.person_id = p.id and c.contact_type = 'email' and c.status = 'active'
            order by c.created_at desc limit 1),
          'mobile_phone_masked', (select c.masked_value from public.person_contacts c
            where c.person_id = p.id and c.contact_type = 'mobile_phone' and c.status = 'active'
            order by c.created_at desc limit 1),
          'cpf_masked', (select i.masked_value from app_private.person_identity_identifiers i
            where i.person_id = p.id and i.identifier_kind = 'cpf' and i.status = 'active'
            order by i.created_at desc limit 1)
        ) order by r.is_primary desc, r.starts_on, r.id)
        from public.institution_legal_representatives r
        join public.people p on p.id = r.person_id and p.deleted_at is null
        where r.institution_id = p_institution_id and r.status in ('active','draft')
      ), '[]'::jsonb),
      'administrators', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'membership_id', m.id,
          'person_id', p.id,
          'role_code', m.role_code,
          'level', case m.role_code
            when 'owner' then 'admin_master'
            when 'institution_admin' then 'authorized_administrator'
            else 'coordinator' end,
          'status', m.status::text,
          'first_name', p.first_name,
          'last_name', p.last_name,
          'display_name', p.display_name,
          'handle', null,
          'has_active_login', exists (select 1 from public.person_auth_links l
            where l.person_id = p.id and l.status = 'active' and l.revoked_at is null),
          'invitation_status', case when exists (select 1 from public.person_auth_links l
            where l.person_id = p.id and l.status = 'active' and l.revoked_at is null)
            then 'accepted' else 'not_sent' end,
          'email_masked', (select c.masked_value from public.person_contacts c
            where c.person_id = p.id and c.contact_type = 'email' and c.status = 'active'
            order by c.created_at desc limit 1),
          'mobile_phone_masked', (select c.masked_value from public.person_contacts c
            where c.person_id = p.id and c.contact_type = 'mobile_phone' and c.status = 'active'
            order by c.created_at desc limit 1),
          'cpf_masked', (select i.masked_value from app_private.person_identity_identifiers i
            where i.person_id = p.id and i.identifier_kind = 'cpf' and i.status = 'active'
            order by i.created_at desc limit 1),
          'source_representative_id', (select r.id from public.institution_legal_representatives r
            where r.membership_id = m.id and r.status in ('active','draft')
            order by r.starts_on limit 1)
        ) order by m.created_at, m.id)
        from public.institution_memberships m
        join public.people p on p.id = m.person_id and p.deleted_at is null
        where m.institution_id = p_institution_id and m.status = 'active' and m.revoked_at is null
          and m.role_code in ('owner','institution_admin','coordinator')
          and p.person_type = 'adult'
      ), '[]'::jsonb)
    )
  from public.institutions i
  where i.id = p_institution_id and i.deleted_at is null
$$;

-- ---------------------------------------------------------------------------
-- Donos e privilegios
-- ---------------------------------------------------------------------------
alter function app_private.person_identity_hmac_v1(text) owner to postgres;
alter function app_private.cpf_digits_valid_v1(text) owner to postgres;
alter function app_private.cnpj_digits_valid_v1(text) owner to postgres;
alter function app_private.mask_email_v1(text) owner to postgres;
alter function app_private.mask_phone_v1(text) owner to postgres;
alter function app_private.mask_cpf_v1(text) owner to postgres;
alter function app_private.superadmin_institution_contacts_validate_person_v1(jsonb, text) owner to postgres;
alter function app_private.superadmin_institution_contacts_validate_v1(jsonb) owner to postgres;
alter function app_private.superadmin_institution_contacts_request_hash_v1(uuid, bigint, jsonb) owner to postgres;
alter function app_private.superadmin_institution_contacts_upsert_person_v1(jsonb) owner to postgres;
alter function app_private.superadmin_institution_contacts_apply_v1(
  uuid, uuid, bigint, jsonb, bytea, app_private.superadmin_internal_context, uuid) owner to postgres;
alter function public.superadmin_institution_contacts_edit_v1(uuid, uuid, bigint, jsonb) owner to postgres;
alter function app_private.superadmin_institution_detail_payload_v2(uuid) owner to postgres;

revoke all on function
  app_private.superadmin_institution_contacts_validate_person_v1(jsonb, text),
  app_private.superadmin_institution_contacts_validate_v1(jsonb),
  app_private.superadmin_institution_contacts_request_hash_v1(uuid, bigint, jsonb),
  app_private.superadmin_institution_contacts_upsert_person_v1(jsonb),
  app_private.superadmin_institution_contacts_apply_v1(
    uuid, uuid, bigint, jsonb, bytea, app_private.superadmin_internal_context, uuid),
  app_private.superadmin_institution_detail_payload_v2(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.superadmin_institution_contacts_edit_v1(uuid, uuid, bigint, jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_institution_contacts_edit_v1(uuid, uuid, bigint, jsonb)
  to authenticated;

comment on function public.superadmin_institution_contacts_edit_v1(uuid, uuid, bigint, jsonb) is
  'R05 realm-interno: documento, contato, representantes legais e administradores da instituicao (institution.update; owner/operations; escopo por instituicao).';

commit;
