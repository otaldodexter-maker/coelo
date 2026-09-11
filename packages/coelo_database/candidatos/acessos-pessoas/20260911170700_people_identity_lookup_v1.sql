-- 20260911170700_people_identity_lookup_v1
-- Abre people.create (fail-closed desde a R03): o gate de identidade do
-- cliente (PersonIdentityLookupGate) precisa resolver um identificador antes
-- de abrir o formulario, e producao nao tinha RPC para isso.
--
-- superadmin_people_identity_lookup_v1(p_kind, p_query, p_institution_id, p_unit_id)
--   * exige people.create (assert_people_permission: ator, permissao, AAL do MVP);
--   * p_kind na allowlist email|phone|cpf|handle|name; consulta normalizada no
--     servidor: e-mail em minusculas -> sha256 em person_contacts(email);
--     telefone so digitos -> sha256 em person_contacts(mobile_phone); CPF so
--     digitos (11) -> HMAC v1 em app_private.person_identity_identifiers;
--     @ -> person_handles ativo; nome (>= 3 caracteres) -> display_name/legal_name
--     ilike, no maximo 10;
--   * devolve candidatos minimamente expostos: person_id, display_name,
--     person_type, matched_by, masked_match (mascara do proprio catalogo,
--     nunca o valor cru) e access = edit_global (people.update) | link_only;
--   * o valor consultado nao e gravado nem auditado; audit_logs recebe so ator,
--     momento e contexto (o mascaramento do audit redige valores no reason).
-- Sem tabela nova, sem grant a tabela; execute so para authenticated/service_role.

create or replace function public.superadmin_people_identity_lookup_v1(
  p_kind text, p_query text, p_institution_id uuid default null, p_unit_id uuid default null)
returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare
  kind text := lower(btrim(coalesce(p_kind, '')));
  raw text := btrim(coalesce(p_query, ''));
  normalized text;
  digest_hex text;
  access_level text;
  candidates jsonb := '[]'::jsonb;
begin
  perform app_private.assert_people_permission('people.create');
  if kind not in ('email','phone','cpf','handle','name') then
    raise invalid_parameter_value using message = 'invalid identity lookup kind';
  end if;
  if raw = '' or char_length(raw) > 200 then
    raise invalid_parameter_value using message = 'identity lookup query is required';
  end if;
  access_level := case when app_private.has_platform_permission('people.update') then 'edit_global' else 'link_only' end;

  if kind = 'email' then
    normalized := lower(raw);
    if position('@' in normalized) = 0 then
      raise invalid_parameter_value using message = 'invalid email';
    end if;
    digest_hex := encode(extensions.digest(pg_catalog.convert_to(normalized, 'UTF8'), 'sha256'), 'hex');
    select coalesce(jsonb_agg(jsonb_build_object(
        'person_id', person.id, 'display_name', person.display_name, 'person_type', person.person_type,
        'matched_by', 'email', 'masked_match', coalesce(contact.masked_value, app_private.mask_email_v1(normalized)),
        'access', access_level) order by person.display_name), '[]'::jsonb)
    into candidates
    from public.person_contacts contact
    join public.people person on person.id = contact.person_id and person.deleted_at is null
    where contact.contact_type = 'email' and contact.status = 'active'
      and contact.normalized_value_hash = digest_hex;
  elsif kind = 'phone' then
    normalized := regexp_replace(raw, '\D', '', 'g');
    if char_length(normalized) < 8 then
      raise invalid_parameter_value using message = 'invalid phone';
    end if;
    digest_hex := encode(extensions.digest(pg_catalog.convert_to(normalized, 'UTF8'), 'sha256'), 'hex');
    select coalesce(jsonb_agg(jsonb_build_object(
        'person_id', person.id, 'display_name', person.display_name, 'person_type', person.person_type,
        'matched_by', 'phone', 'masked_match', coalesce(contact.masked_value, app_private.mask_phone_v1(normalized)),
        'access', access_level) order by person.display_name), '[]'::jsonb)
    into candidates
    from public.person_contacts contact
    join public.people person on person.id = contact.person_id and person.deleted_at is null
    where contact.contact_type = 'mobile_phone' and contact.status = 'active'
      and contact.normalized_value_hash = digest_hex;
  elsif kind = 'cpf' then
    normalized := regexp_replace(raw, '\D', '', 'g');
    if char_length(normalized) <> 11 then
      raise invalid_parameter_value using message = 'invalid cpf';
    end if;
    select coalesce(jsonb_agg(jsonb_build_object(
        'person_id', person.id, 'display_name', person.display_name, 'person_type', person.person_type,
        'matched_by', 'cpf', 'masked_match', identifier.masked_value,
        'access', access_level) order by person.display_name), '[]'::jsonb)
    into candidates
    from app_private.person_identity_identifiers identifier
    join public.people person on person.id = identifier.person_id and person.deleted_at is null
    where identifier.identifier_kind = 'cpf' and identifier.status = 'active'
      and identifier.normalized_value_hmac = app_private.person_identity_hmac_v1(normalized);
    digest_hex := encode(extensions.digest(pg_catalog.convert_to(normalized, 'UTF8'), 'sha256'), 'hex');
  elsif kind = 'handle' then
    normalized := app_private.normalize_person_handle(raw);
    select coalesce(jsonb_agg(jsonb_build_object(
        'person_id', person.id, 'display_name', person.display_name, 'person_type', person.person_type,
        'matched_by', 'handle', 'masked_match', '@' || handle.normalized_handle,
        'access', access_level) order by person.display_name), '[]'::jsonb)
    into candidates
    from public.person_handles handle
    join public.people person on person.id = handle.person_id and person.deleted_at is null
    where handle.normalized_handle = normalized and handle.status = 'active' and handle.revoked_at is null;
    digest_hex := encode(extensions.digest(pg_catalog.convert_to(normalized, 'UTF8'), 'sha256'), 'hex');
  else
    normalized := raw;
    if char_length(normalized) < 3 then
      raise invalid_parameter_value using message = 'name lookup needs at least 3 characters';
    end if;
    select coalesce(jsonb_agg(item order by item->>'display_name'), '[]'::jsonb)
    into candidates
    from (
      select jsonb_build_object(
        'person_id', person.id, 'display_name', person.display_name, 'person_type', person.person_type,
        'matched_by', 'name', 'masked_match', person.display_name,
        'access', access_level) as item
      from public.people person
      where person.deleted_at is null and person.person_type in ('adult','child')
        and (person.display_name ilike '%' || normalized || '%' or person.legal_name ilike '%' || normalized || '%')
      order by person.display_name
      limit 10
    ) matches;
    digest_hex := encode(extensions.digest(pg_catalog.convert_to(lower(normalized), 'UTF8'), 'sha256'), 'hex');
  end if;

  -- O mascaramento de audit_logs redige reason/after_json com valores que
  -- pareçam identificadores; a trilha guarda so quem, quando e o contexto.
  insert into audit.audit_logs(actor_person_id, mfa_aal, action_code, object_type, object_id, outcome, reason, after_json)
  values (app_private.current_person_id(), 'aal1', 'permission_changed', 'person_identity_lookup', null, 'success',
    'superadmin.people.identity-lookup',
    jsonb_build_object('institution_id', p_institution_id, 'unit_id', p_unit_id));
  return jsonb_build_object('ok', true, 'data', candidates, 'error', null);
end
$$;

revoke all on function public.superadmin_people_identity_lookup_v1(text,text,uuid,uuid) from public, anon;
grant execute on function public.superadmin_people_identity_lookup_v1(text,text,uuid,uuid) to authenticated, service_role;
