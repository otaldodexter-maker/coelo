-- R15 Bloco C2 / ADR 0041 B6 (owner.r12-18): pessoa autorizada sem conta.
-- Contrato em specs/062-superadmin-child-safety-person-without-account.md.
--
-- (1) public.authorized_people: pessoa sem conta = linha com person_id nulo,
--     document_type 'cpf', document_fingerprint = HMAC do CPF (mesma chave
--     person_identity_hmac_v1 das identidades com conta) e document_last4.
--     CPF nunca em claro nem reversivel: a restricao de documento deixa de
--     exigir ciphertext. Dedupe pela unique existente
--     authorized_people_document_fingerprint_uidx (instituicao, fingerprint).
--     Contato opcional minimizado (hash + ultimos 4 / mascara).
-- (2) public.authorized_person_documents: imagem/PDF do documento em R2 privado
--     (coelo-documents-prod, chave opaca da ADR 0032), RLS forcada, sem grants.
-- (3) RPCs: register_person_without_account_v1, person_document_prepare_v1,
--     person_document_authorize_finalize_v1 (bilhete), person_document_finalize_v1
--     (service_role, gateway), person_document_read_v1 (descritor, sem URL).
-- (4) child_safety_request_authorization: corpo do dump de producao de 17/09
--     (SHA-256 c87f4d67) + ramo authorized_person_id (pessoa sem conta com
--     documento ready). Versao defasada nao existe aqui; nenhum 40001.
-- Forward-only e idempotente.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'person without account v1 must run as postgres';
  end if;
  if to_regclass('public.authorized_people') is null
    or to_regclass('app_private.child_safety_command_receipts') is null
    or to_regprocedure('app_private.child_safety_receipt(uuid,uuid,text,bytea)') is null
    or to_regprocedure('app_private.child_safety_store_receipt(uuid,uuid,text,bytea,uuid,jsonb)') is null
    or to_regprocedure('app_private.child_safety_can_administer(uuid,uuid,uuid)') is null
    or to_regprocedure('app_private.guardian_has_capability(uuid,text)') is null
    or to_regprocedure('app_private.person_identity_hmac_v1(text)') is null
    or to_regprocedure('app_private.cpf_digits_valid_v1(text)') is null
    or to_regprocedure('app_private.mask_email_v1(text)') is null
    or to_regprocedure('app_private.child_safety_request_authorization(uuid,jsonb)') is null then
    raise object_not_in_prerequisite_state using message = 'child safety objects are required';
  end if;
end
$preflight$;

-- (1) authorized_people: documento sem ciphertext + contato minimizado.
alter table public.authorized_people drop constraint if exists authorized_people_document_check;
alter table public.authorized_people add constraint authorized_people_document_check check (
  (document_ciphertext is null and document_fingerprint is null and document_type is null and document_last4 is null)
  or (document_fingerprint is not null and document_type is not null)
);
alter table public.authorized_people
  add column if not exists contact_phone_hash text,
  add column if not exists contact_phone_last4 text,
  add column if not exists contact_email_hash text,
  add column if not exists contact_email_masked text;
alter table public.authorized_people drop constraint if exists authorized_people_contact_shape_check;
alter table public.authorized_people add constraint authorized_people_contact_shape_check check (
  (contact_phone_last4 is null or contact_phone_last4 ~ '^[0-9]{4}$')
  and ((contact_phone_hash is null) = (contact_phone_last4 is null))
  and ((contact_email_hash is null) = (contact_email_masked is null))
  and (contact_phone_hash is null or contact_phone_hash ~ '^[0-9a-f]{64}$')
  and (contact_email_hash is null or contact_email_hash ~ '^[0-9a-f]{64}$')
);

-- (2) Documento em R2 privado.
create table if not exists public.authorized_person_documents (
  id uuid primary key default gen_random_uuid(),
  authorized_person_id uuid not null references public.authorized_people(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  upload_request_id uuid not null,
  storage_provider text not null default 'r2',
  bucket_id text not null default 'coelo-documents-prod',
  object_key text not null,
  mime_type text not null,
  byte_size bigint not null,
  checksum_sha256 text,
  status text not null default 'pending',
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  finalized_at timestamptz,
  constraint authorized_person_documents_provider_ck check (storage_provider = 'r2'),
  constraint authorized_person_documents_bucket_ck check (bucket_id = 'coelo-documents-prod'),
  constraint authorized_person_documents_mime_ck check (
    mime_type in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')),
  constraint authorized_person_documents_size_ck check (byte_size between 1 and 10485760),
  constraint authorized_person_documents_status_ck check (status in ('pending', 'ready', 'superseded')),
  constraint authorized_person_documents_checksum_ck check (
    checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$'),
  constraint authorized_person_documents_ready_ck check (
    status <> 'ready' or (checksum_sha256 is not null and finalized_at is not null)),
  constraint authorized_person_documents_key_shape_ck check (
    object_key ~ ('^tenants/' || institution_id::text || '/child_safety/authorized_person/'
      || authorized_person_id::text || '/identity-document/' || id::text
      || '/original/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
      || case mime_type when 'image/jpeg' then '[.]jpg$' when 'image/png' then '[.]png$'
           when 'image/webp' then '[.]webp$' when 'application/pdf' then '[.]pdf$' else '$a' end))
);
create index if not exists authorized_person_documents_person_status_idx
  on public.authorized_person_documents (authorized_person_id, status);
create unique index if not exists authorized_person_documents_request_uidx
  on public.authorized_person_documents (upload_request_id);
alter table public.authorized_person_documents enable row level security;
alter table public.authorized_person_documents force row level security;
revoke all on table public.authorized_person_documents from public, anon, authenticated;

create table if not exists app_private.child_safety_person_document_finalize_tickets (
  token_hash text primary key check (token_hash ~ '^[0-9a-f]{64}$'),
  document_id uuid not null references public.authorized_person_documents(id) on delete cascade,
  actor_person_id uuid not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
alter table app_private.child_safety_person_document_finalize_tickets enable row level security;
alter table app_private.child_safety_person_document_finalize_tickets force row level security;
revoke all on table app_private.child_safety_person_document_finalize_tickets from public, anon, authenticated;

-- Quem pode registrar/gerir uma pessoa sem conta de uma instituicao: plataforma
-- com child_safety.manage escopado na instituicao, gestao de pessoas autorizadas
-- no contexto, ou o responsavel dono da linha.
create or replace function app_private.child_safety_person_without_account_visible(
  p_person public.authorized_people, p_actor uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  -- coalesce: owner_guardian_person_id nulo nao pode virar NULL (que um IF trataria como "nao negado").
  select coalesce(p_person.id is not null and p_person.person_id is null and p_person.status = 'active' and (
    app_private.has_platform_permission('child_safety.manage', p_person.institution_id)
    or app_private.has_context_permission(p_person.institution_id, 'authorized_people.manage')
    or p_person.owner_guardian_person_id = p_actor), false)
$$;
revoke all on function app_private.child_safety_person_without_account_visible(public.authorized_people, uuid) from public, anon, authenticated;

-- (3a) Registro.
create or replace function app_private.child_safety_register_person_without_account_v1(
  p_request_id uuid, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.current_person_id();
  request_hash bytea; replay jsonb;
  target_context uuid; target_unit uuid; target_institution uuid;
  full_name text; cpf text; phone text; email text;
  fingerprint text;
  guardian_request boolean; administrative_request boolean;
  existing public.authorized_people%rowtype;
  person_id uuid; result jsonb; existing_flag boolean := false;
begin
  if (select auth.uid()) is null or actor is null or p_request_id is null
    or not app_private.has_mfa_aal2() or jsonb_typeof(p_payload) <> 'object' then
    raise insufficient_privilege using message = 'child safety request unavailable';
  end if;
  request_hash := extensions.digest(convert_to(p_payload::text, 'utf8'), 'sha256');
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text, 0));
  replay := app_private.child_safety_receipt(p_request_id, actor, 'register_person_without_account', request_hash);
  if replay is not null then return replay; end if;
  begin
    target_context := (p_payload ->> 'child_context_id')::uuid;
    target_unit := (p_payload ->> 'unit_id')::uuid;
  exception when others then
    raise invalid_parameter_value using message = 'invalid person registration';
  end;
  full_name := regexp_replace(btrim(coalesce(p_payload ->> 'full_name', '')), '\s+', ' ', 'g');
  cpf := regexp_replace(coalesce(p_payload ->> 'cpf', ''), '\D', '', 'g');
  phone := nullif(regexp_replace(coalesce(p_payload ->> 'mobile_phone', ''), '\D', '', 'g'), '');
  email := nullif(lower(btrim(coalesce(p_payload ->> 'email', ''))), '');
  if char_length(full_name) not between 3 and 120 then
    raise invalid_parameter_value using message = 'invalid person registration', detail = 'PERSON_NAME_INVALID';
  end if;
  if not app_private.cpf_digits_valid_v1(cpf) then
    raise invalid_parameter_value using message = 'invalid person registration', detail = 'PERSON_CPF_INVALID';
  end if;
  if phone is not null and char_length(phone) not between 10 and 13 then
    raise invalid_parameter_value using message = 'invalid person registration', detail = 'PERSON_PHONE_INVALID';
  end if;
  if email is not null and (position('@' in email) < 2 or char_length(email) > 200) then
    raise invalid_parameter_value using message = 'invalid person registration', detail = 'PERSON_EMAIL_INVALID';
  end if;
  select c.institution_id into target_institution
  from public.child_contexts c
  join public.child_unit_links l on l.child_context_id = c.id and l.unit_id = target_unit
    and l.status in ('active', 'awaiting_allocation')
  join public.units u on u.id = target_unit and u.institution_id = c.institution_id
  where c.id = target_context and c.status = 'active';
  guardian_request := app_private.guardian_has_capability(target_context, 'manage_authorized_people');
  administrative_request := app_private.child_safety_can_administer(target_institution, target_unit, target_context);
  if target_institution is null or not (administrative_request or guardian_request) then
    raise no_data_found using message = 'child safety record unavailable';
  end if;
  fingerprint := encode(app_private.person_identity_hmac_v1(cpf), 'hex');
  -- Pessoa com conta com este CPF: o cadastro sem conta nao substitui a busca B5.
  if exists (
    select 1 from app_private.person_identity_identifiers ii
    join public.people p on p.id = ii.person_id and p.status = 'active' and p.deleted_at is null
    where ii.identifier_kind = 'cpf' and ii.status = 'active'
      and ii.normalized_value_hmac = app_private.person_identity_hmac_v1(cpf)) then
    raise invalid_parameter_value using message = 'person already has an account', detail = 'PERSON_HAS_ACCOUNT';
  end if;
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(target_institution::text || fingerprint, 0));
  select * into existing from public.authorized_people ap
  where ap.institution_id = target_institution and ap.document_fingerprint = fingerprint
    and ap.status <> 'archived'
  order by ap.created_at limit 1 for update;
  if existing.id is not null then
    if existing.person_id is not null then
      raise invalid_parameter_value using message = 'person already has an account', detail = 'PERSON_HAS_ACCOUNT';
    end if;
    if not (administrative_request or existing.owner_guardian_person_id = actor) then
      raise no_data_found using message = 'child safety record unavailable';
    end if;
    person_id := existing.id;
    existing_flag := true;
  else
    insert into public.authorized_people (
      institution_id, display_name, document_type, document_fingerprint, document_last4,
      owner_guardian_person_id, contact_phone_hash, contact_phone_last4,
      contact_email_hash, contact_email_masked, status)
    values (
      target_institution, full_name, 'cpf', fingerprint, right(cpf, 4),
      case when guardian_request and not administrative_request then actor end,
      case when phone is null then null else encode(extensions.digest(convert_to(phone, 'UTF8'), 'sha256'), 'hex') end,
      case when phone is null then null else right(phone, 4) end,
      case when email is null then null else encode(extensions.digest(convert_to(email, 'UTF8'), 'sha256'), 'hex') end,
      case when email is null then null else app_private.mask_email_v1(email) end,
      'active')
    returning * into existing;
    person_id := existing.id;
  end if;
  insert into audit.audit_logs (actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json)
  values (actor, auth.jwt() ->> 'aal', 'child_safety.person_without_account.register', 'authorized_person',
    person_id, target_institution, 'success',
    jsonb_build_object('existing', existing_flag, 'unit_id', target_unit, 'child_context_id', target_context,
      'has_phone', phone is not null, 'has_email', email is not null));
  result := jsonb_build_object(
    'authorized_person_id', person_id,
    'display_name', existing.display_name,
    'cpf_masked', '***.***.***-' || right(existing.document_last4, 2),
    'has_account', false,
    'existing', existing_flag,
    'document_status', coalesce((select d.status from public.authorized_person_documents d
      where d.authorized_person_id = person_id and d.status = 'ready' limit 1), 'missing'));
  return app_private.child_safety_store_receipt(
    p_request_id, actor, 'register_person_without_account', request_hash, person_id, result);
end
$$;
revoke all on function app_private.child_safety_register_person_without_account_v1(uuid, jsonb) from public, anon;
create or replace function public.child_safety_register_person_without_account_v1(p_request_id uuid, p_payload jsonb)
returns jsonb language sql security definer set search_path = ''
as $$ select app_private.child_safety_register_person_without_account_v1(p_request_id, p_payload) $$;
revoke all on function public.child_safety_register_person_without_account_v1(uuid, jsonb) from public, anon;
grant execute on function public.child_safety_register_person_without_account_v1(uuid, jsonb) to authenticated, service_role;

-- (3b) Prepare do documento (JWT do usuario, via gateway).
create or replace function app_private.child_safety_person_document_prepare_v1(
  p_request_id uuid, p_authorized_person_id uuid, p_mime_type text, p_byte_size bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.current_person_id();
  request_hash bytea; replay jsonb;
  person public.authorized_people%rowtype;
  doc public.authorized_person_documents%rowtype;
  document_id uuid := gen_random_uuid();
  extension text; result jsonb;
begin
  if (select auth.uid()) is null or actor is null or p_request_id is null or not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message = 'child safety document unavailable';
  end if;
  extension := case p_mime_type when 'image/jpeg' then 'jpg' when 'image/png' then 'png'
    when 'image/webp' then 'webp' when 'application/pdf' then 'pdf' end;
  if extension is null or p_byte_size is null or p_byte_size not between 1 and 10485760 then
    raise invalid_parameter_value using message = 'invalid person document';
  end if;
  request_hash := extensions.digest(convert_to(jsonb_build_object('authorized_person_id', p_authorized_person_id,
    'mime_type', p_mime_type, 'byte_size', p_byte_size)::text, 'utf8'), 'sha256');
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text, 0));
  replay := app_private.child_safety_receipt(p_request_id, actor, 'person_document_prepare', request_hash);
  if replay is not null then return replay; end if;
  select * into person from public.authorized_people ap where ap.id = p_authorized_person_id;
  if not app_private.child_safety_person_without_account_visible(person, actor) then
    raise no_data_found using message = 'child safety record unavailable';
  end if;
  insert into public.authorized_person_documents (
    id, authorized_person_id, institution_id, upload_request_id, object_key, mime_type, byte_size,
    created_by_person_id)
  values (
    document_id, person.id, person.institution_id, p_request_id,
    'tenants/' || person.institution_id::text || '/child_safety/authorized_person/' || person.id::text
      || '/identity-document/' || document_id::text || '/original/' || gen_random_uuid()::text || '.' || extension,
    p_mime_type, p_byte_size, actor)
  returning * into doc;
  insert into audit.audit_logs (actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json)
  values (actor, auth.jwt() ->> 'aal', 'child_safety.person_document.prepare', 'authorized_person_document',
    doc.id, doc.institution_id, 'success',
    jsonb_build_object('authorized_person_id', person.id, 'mime_type', p_mime_type, 'byte_size', p_byte_size));
  result := jsonb_build_object('document_id', doc.id, 'storage_provider', doc.storage_provider,
    'bucket_id', doc.bucket_id, 'object_key', doc.object_key, 'mime_type', doc.mime_type,
    'byte_size', doc.byte_size);
  return app_private.child_safety_store_receipt(
    p_request_id, actor, 'person_document_prepare', request_hash, doc.id, result);
end
$$;
revoke all on function app_private.child_safety_person_document_prepare_v1(uuid, uuid, text, bigint) from public, anon;
create or replace function public.child_safety_person_document_prepare_v1(
  p_request_id uuid, p_authorized_person_id uuid, p_mime_type text, p_byte_size bigint)
returns jsonb language sql security definer set search_path = ''
as $$ select app_private.child_safety_person_document_prepare_v1(p_request_id, p_authorized_person_id, p_mime_type, p_byte_size) $$;
revoke all on function public.child_safety_person_document_prepare_v1(uuid, uuid, text, bigint) from public, anon;
grant execute on function public.child_safety_person_document_prepare_v1(uuid, uuid, text, bigint) to authenticated, service_role;

-- (3c) Bilhete de finalize (JWT do usuario).
create or replace function app_private.child_safety_person_document_authorize_finalize_v1(p_document_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.current_person_id();
  doc public.authorized_person_documents%rowtype;
  ticket uuid := gen_random_uuid();
  ticket_expires timestamptz := now() + interval '2 minutes';
begin
  if (select auth.uid()) is null or actor is null then
    raise insufficient_privilege using message = 'child safety document unavailable';
  end if;
  select * into doc from public.authorized_person_documents d
  where d.id = p_document_id and d.status = 'pending' and d.created_by_person_id = actor;
  if doc.id is null then raise no_data_found using message = 'child safety record unavailable'; end if;
  delete from app_private.child_safety_person_document_finalize_tickets t where t.expires_at <= now();
  delete from app_private.child_safety_person_document_finalize_tickets t where t.document_id = doc.id;
  insert into app_private.child_safety_person_document_finalize_tickets (token_hash, document_id, actor_person_id, expires_at)
  values (encode(extensions.digest(convert_to(ticket::text, 'UTF8'), 'sha256'), 'hex'), doc.id, actor, ticket_expires);
  return jsonb_build_object('finalize_ticket', ticket, 'expires_at', ticket_expires,
    'document_id', doc.id, 'bucket_id', doc.bucket_id, 'object_key', doc.object_key,
    'mime_type', doc.mime_type, 'byte_size', doc.byte_size);
end
$$;
revoke all on function app_private.child_safety_person_document_authorize_finalize_v1(uuid) from public, anon;
create or replace function public.child_safety_person_document_authorize_finalize_v1(p_document_id uuid)
returns jsonb language sql security definer set search_path = ''
as $$ select app_private.child_safety_person_document_authorize_finalize_v1(p_document_id) $$;
revoke all on function public.child_safety_person_document_authorize_finalize_v1(uuid) from public, anon;
grant execute on function public.child_safety_person_document_authorize_finalize_v1(uuid) to authenticated, service_role;

-- (3d) Finalize (service_role, depois de o gateway verificar os bytes no R2).
create or replace function public.child_safety_person_document_finalize_v1(
  p_document_id uuid, p_finalize_ticket uuid, p_byte_size bigint, p_mime_type text, p_checksum_sha256 text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  doc public.authorized_person_documents%rowtype;
  consumed app_private.child_safety_person_document_finalize_tickets%rowtype;
begin
  if auth.role() <> 'service_role' then
    raise insufficient_privilege using message = 'service role required';
  end if;
  select * into doc from public.authorized_person_documents d where d.id = p_document_id for update;
  if doc.id is null then raise no_data_found using message = 'child safety record unavailable'; end if;
  delete from app_private.child_safety_person_document_finalize_tickets t
  where t.token_hash = encode(extensions.digest(convert_to(p_finalize_ticket::text, 'UTF8'), 'sha256'), 'hex')
    and t.document_id = doc.id and t.expires_at > now()
  returning t.* into consumed;
  if consumed.document_id is null then
    raise insufficient_privilege using message = 'finalize ticket invalid';
  end if;
  if doc.status <> 'pending' then
    raise object_not_in_prerequisite_state using message = 'document not pending';
  end if;
  if p_byte_size <> doc.byte_size or p_mime_type <> doc.mime_type
    or p_checksum_sha256 !~ '^[0-9a-f]{64}$' then
    raise check_violation using message = 'uploaded document mismatch';
  end if;
  update public.authorized_person_documents set status = 'superseded'
  where authorized_person_id = doc.authorized_person_id and status = 'ready' and id <> doc.id;
  update public.authorized_person_documents
  set status = 'ready', checksum_sha256 = p_checksum_sha256, finalized_at = now()
  where id = doc.id returning * into doc;
  insert into audit.audit_logs (actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json)
  values (consumed.actor_person_id, 'aal1', 'child_safety.person_document.finalize', 'authorized_person_document',
    doc.id, doc.institution_id, 'success',
    jsonb_build_object('authorized_person_id', doc.authorized_person_id, 'byte_size', doc.byte_size,
      'mime_type', doc.mime_type));
  return jsonb_build_object('document_id', doc.id, 'status', doc.status,
    'authorized_person_id', doc.authorized_person_id, 'finalized_at', doc.finalized_at);
end
$$;
revoke all on function public.child_safety_person_document_finalize_v1(uuid, uuid, bigint, text, text) from public, anon, authenticated;
grant execute on function public.child_safety_person_document_finalize_v1(uuid, uuid, bigint, text, text) to service_role;

-- (3e) Leitura: descritor para URL assinada curta, nunca URL publica.
create or replace function app_private.child_safety_person_document_read_v1(p_document_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.current_person_id();
  doc public.authorized_person_documents%rowtype;
  person public.authorized_people%rowtype;
begin
  if (select auth.uid()) is null or actor is null or not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message = 'child safety document unavailable';
  end if;
  select * into doc from public.authorized_person_documents d where d.id = p_document_id and d.status = 'ready';
  if doc.id is null then raise no_data_found using message = 'child safety record unavailable'; end if;
  select * into person from public.authorized_people ap where ap.id = doc.authorized_person_id;
  if (
    app_private.has_platform_permission('child_safety.read', doc.institution_id)
    or app_private.has_context_permission(doc.institution_id, 'authorized_people.manage')
    or person.owner_guardian_person_id = actor) is not true then
    raise no_data_found using message = 'child safety record unavailable';
  end if;
  insert into audit.audit_logs (actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json)
  values (actor, auth.jwt() ->> 'aal', 'child_safety.person_document.read', 'authorized_person_document',
    doc.id, doc.institution_id, 'success', jsonb_build_object('authorized_person_id', doc.authorized_person_id));
  return jsonb_build_object('document_id', doc.id, 'storage_provider', doc.storage_provider,
    'bucket_id', doc.bucket_id, 'object_key', doc.object_key, 'mime_type', doc.mime_type,
    'byte_size', doc.byte_size, 'expires_in_seconds', 60);
end
$$;
revoke all on function app_private.child_safety_person_document_read_v1(uuid) from public, anon;
create or replace function public.child_safety_person_document_read_v1(p_document_id uuid)
returns jsonb language sql security definer set search_path = ''
as $$ select app_private.child_safety_person_document_read_v1(p_document_id) $$;
revoke all on function public.child_safety_person_document_read_v1(uuid) from public, anon;
grant execute on function public.child_safety_person_document_read_v1(uuid) to authenticated, service_role;

-- (4) child_safety_request_authorization: corpo de producao + ramo authorized_person_id.
-- Corpo de producao (dump 20260917, SHA-256 c87f4d67) com o ramo authorized_person_id; demais linhas inalteradas.
CREATE OR REPLACE FUNCTION "app_private"."child_safety_request_authorization"("p_request_id" "uuid", "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$ declare
  actor uuid:=app_private.current_person_id(); request_hash bytea; replay jsonb;
  target_context uuid; target_unit uuid; target_person uuid; target_institution uuid;
  relation_id uuid; requested_relation_code text; relation_detail text; authorization_id uuid;
  authorized_person_id uuid; capabilities text[]; guardian_request boolean;
  administrative_request boolean; platform_request boolean; result jsonb; notification_id uuid;
  starts date; ends date; request_reason text;
  target_authorized_person uuid; no_account boolean:=false;
begin
  if (select auth.uid()) is null or actor is null or p_request_id is null
     or jsonb_typeof(p_payload)<>'object' then
    raise insufficient_privilege using message='child safety request unavailable';
  end if;
  request_hash:=extensions.digest(convert_to(p_payload::text,'utf8'),'sha256');
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,0));
  replay:=app_private.child_safety_receipt(p_request_id,actor,'request_authorization',request_hash);
  if replay is not null then return replay; end if;
  begin
    target_context:=(p_payload->>'child_context_id')::uuid;
    target_unit:=(p_payload->>'unit_id')::uuid;
    target_person:=nullif(p_payload->>'person_id','')::uuid;
    target_authorized_person:=nullif(p_payload->>'authorized_person_id','')::uuid;
    starts:=coalesce(nullif(p_payload->>'valid_from','')::date,current_date);
    ends:=nullif(p_payload->>'valid_until','')::date;
  exception when others then raise invalid_parameter_value using message='invalid authorization request'; end;
  request_reason:=btrim(coalesce(p_payload->>'request_reason',''));
  requested_relation_code:=btrim(coalesce(p_payload->>'relationship_code',''));
  relation_detail:=nullif(btrim(coalesce(p_payload->>'relationship_detail','')),'');
  if jsonb_typeof(coalesce(p_payload->'capability_codes','[]'))<>'array' then
    raise invalid_parameter_value using message='invalid authorization request';
  end if;
  select array_agg(distinct value order by value) into capabilities
  from jsonb_array_elements_text(coalesce(p_payload->'capability_codes','[]')) value;
  if char_length(request_reason) not between 3 and 500
     or (ends is not null and ends<starts) or capabilities is null
     or not capabilities<@array['emergency_contact','pickup','transport']::text[]
     or cardinality(capabilities)=0 then
    raise invalid_parameter_value using message='invalid authorization request';
  end if;
  select c.institution_id into target_institution
  from public.child_contexts c join public.child_unit_links l
    on l.child_context_id=c.id and l.unit_id=target_unit
   and l.status in ('active','awaiting_allocation')
  join public.units u on u.id=target_unit and u.institution_id=c.institution_id
  where c.id=target_context and c.status='active';
  guardian_request:=app_private.guardian_has_capability(target_context,'manage_authorized_people');
  platform_request:=app_private.has_platform_permission('child_safety.manage');
  administrative_request:=app_private.child_safety_can_administer(
    target_institution,target_unit,target_context
  );
  if target_institution is null or not (administrative_request or guardian_request) then
    raise no_data_found using message='child safety record unavailable';
  end if;
  -- B6 (spec 062): pessoa autorizada sem conta, identificada por authorized_person_id.
  if target_authorized_person is not null then
    if target_person is not null then
      raise invalid_parameter_value using message='invalid authorization request';
    end if;
    perform pg_advisory_xact_lock(
      pg_catalog.hashtextextended(target_institution::text||target_authorized_person::text,0)
    );
    select ap.id into authorized_person_id from public.authorized_people ap
    where ap.id=target_authorized_person and ap.institution_id=target_institution
      and ap.status='active' and ap.person_id is null
      and (administrative_request or ap.owner_guardian_person_id=actor)
    for update;
    if authorized_person_id is null then
      raise no_data_found using message='child safety record unavailable';
    end if;
    if not exists(select 1 from public.authorized_person_documents d
      where d.authorized_person_id=target_authorized_person and d.status='ready') then
      raise invalid_parameter_value using message='person document required',
        detail='PERSON_DOCUMENT_REQUIRED';
    end if;
    no_account:=true;
  end if;
  if not no_account then
  if not exists(select 1 from public.people p where p.id=target_person
    and p.person_type='adult' and p.status='active') then
    raise no_data_found using message='child safety record unavailable';
  end if;
  -- Guardians may only reuse an adult identity they already own in this
  -- institution. Creating/linking a new global identity is an administrative
  -- operation or must go through the separately verified invitation flow.
  if not platform_request and not exists (
    select 1 from public.authorized_people ap
    where ap.institution_id=target_institution and ap.person_id=target_person
      and ap.status='active'
      and (administrative_request or ap.owner_guardian_person_id=actor)
  ) then
    raise no_data_found using message='child safety record unavailable';
  end if;
  end if;
  select id into relation_id from public.family_relationship_types
    where code=requested_relation_code and status='active';
  if relation_id is null or (lower(requested_relation_code) in ('other','others','outros')
    and relation_detail is null) then
    raise invalid_parameter_value using message='invalid relationship';
  end if;
  if not no_account then
  perform pg_advisory_xact_lock(
    pg_catalog.hashtextextended(target_institution::text||target_person::text,0)
  );
  select id into authorized_person_id from public.authorized_people
  where institution_id=target_institution and person_id=target_person and status<>'archived'
    and (administrative_request or owner_guardian_person_id=actor)
  order by created_at limit 1 for update;
  if authorized_person_id is null and platform_request then
    insert into public.authorized_people(
      institution_id,person_id,owner_guardian_person_id,display_name,status
    ) select target_institution,target_person,case when guardian_request then actor end,
      p.display_name,'active' from public.people p where p.id=target_person
    returning id into authorized_person_id;
  end if;
  if authorized_person_id is null then
    raise no_data_found using message='child safety record unavailable';
  end if;
  end if;
  insert into public.authorized_person_authorizations(
    authorized_person_id,institution_id,child_context_id,unit_id,relationship_type_id,
    relationship_detail,created_by_person_id,status,valid_from,valid_until,
    decision_status,request_reason,version
  ) values(
    authorized_person_id,target_institution,target_context,target_unit,relation_id,
    relation_detail,actor,'inactive',starts,ends,'pending',request_reason,1
  ) returning id into authorization_id;
  insert into public.authorized_person_authorization_capabilities(authorization_id,capability_code)
  select authorization_id,unnest(capabilities);
  insert into public.context_notification_events(
    institution_id,unit_id,child_context_id,event_code,object_type,object_id,payload_json,
    created_by_person_id
  ) values(target_institution,target_unit,target_context,
    'child_safety.authorization_requested','authorized_person_authorization',authorization_id,
    jsonb_build_object('authorization_id',authorization_id,'decision_status','pending'),actor)
  returning id into notification_id;
  perform app_private.child_safety_add_unit_review_recipients(
    notification_id,target_institution,target_unit
  );
  insert into audit.audit_logs(
    actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json
  ) values(actor,auth.jwt()->>'aal','child_safety.authorization.request',
    'authorized_person_authorization',authorization_id,target_institution,'success',
    jsonb_build_object('decision_status','pending','lifecycle_status','inactive','unit_id',target_unit,
      'authorized_person_without_account',no_account));
  result:=jsonb_build_object('authorization_id',authorization_id,'decision_status','pending',
    'lifecycle_status','inactive','version',1);
  return app_private.child_safety_store_receipt(
    p_request_id,actor,'request_authorization',request_hash,authorization_id,result
  );
end $$;
revoke all on function app_private.child_safety_request_authorization(uuid, jsonb) from public, anon;

do $postcheck$
begin
  if to_regclass('public.authorized_person_documents') is null
    or to_regprocedure('public.child_safety_register_person_without_account_v1(uuid,jsonb)') is null
    or to_regprocedure('public.child_safety_person_document_finalize_v1(uuid,uuid,bigint,text,text)') is null
    or not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'app_private' and p.proname = 'child_safety_request_authorization'
        and p.prosrc like '%PERSON_DOCUMENT_REQUIRED%')
    or exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'app_private' and p.proname like 'child_safety_%person%'
        and p.prosrc like '%serialization_failure%') then
    raise object_not_in_prerequisite_state using message = 'person without account v1 postcheck failed';
  end if;
end
$postcheck$;

commit;
