-- R15 Bloco C2 / ADR 0041 B5 (owner.r12-17): busca de pessoa autorizada para o
-- wizard de Seguranca da crianca. Contrato em specs/061-superadmin-child-safety-person-search.md.
--
-- Um leitor unico (superadmin_person_search_v1) detecta o tipo da consulta
-- (nome, @handle, e-mail, digitos de celular/CPF), exige o minimo de caracteres
-- por tipo, restringe o resultado ao escopo do ator (has_platform_permission
-- 'child_safety.read' por instituicao), audita cada busca sem gravar o texto,
-- aplica limite de taxa por ator (30/min; a 31a responde SQLSTATE PT422 com
-- detail PERSON_SEARCH_RATE_LIMIT) e devolve resultado minimizado: nome,
-- iniciais, @handle, ultimos 4 do celular e as criancas vinculadas ao
-- responsavel dentro do escopo. CPF nunca entra no payload; ele so existe como
-- HMAC (person_identity_identifiers), logo apenas o numero completo encontra.
--
-- Nenhum objeto existente e alterado. Forward-only e idempotente. Versao
-- defasada nao se aplica (leitor); nenhum SQLSTATE 40001.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'person search v1 must run as postgres';
  end if;
  if to_regprocedure('app_private.assert_child_safety_platform(text)') is null
    or to_regprocedure('app_private.has_platform_permission(text,uuid)') is null
    or to_regprocedure('app_private.person_identity_hmac_v1(text)') is null
    or to_regprocedure('app_private.cpf_digits_valid_v1(text)') is null
    or to_regprocedure('app_private.normalize_person_handle(text)') is null
    or to_regclass('public.person_handles') is null
    or to_regclass('public.person_contacts') is null
    or to_regclass('app_private.person_identity_identifiers') is null
    or to_regclass('public.guardian_links') is null
    or to_regclass('public.authorized_people') is null then
    raise object_not_in_prerequisite_state using message = 'child safety and people identity objects are required';
  end if;
end
$preflight$;

-- Limite de taxa por ator: uma linha por busca bem-sucedida, janela de 1 min,
-- limpeza oportunista de linhas com mais de 10 min. Tabela privada, RLS
-- forcada, sem grants: so a funcao (security definer) escreve e le.
create table if not exists app_private.person_search_hits (
  id bigint generated always as identity primary key,
  actor_person_id uuid not null,
  occurred_at timestamptz not null default now()
);
create index if not exists person_search_hits_actor_occurred_idx
  on app_private.person_search_hits (actor_person_id, occurred_at desc);
alter table app_private.person_search_hits enable row level security;
alter table app_private.person_search_hits force row level security;
revoke all on table app_private.person_search_hits from public, anon, authenticated;

create or replace function app_private.superadmin_person_search_v1(p_query text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid;
  raw text := btrim(coalesce(p_query, ''));
  digits text;
  kind text;
  needle text;
  email_hash text;
  phone_hash text;
  cpf_hmac bytea;
  hits integer;
  results jsonb;
begin
  -- Mesma guarda do diretorio e da busca de criancas: capacidade de
  -- plataforma child_safety.read no realm de pessoas (42501 se ausente).
  actor := app_private.assert_child_safety_platform('child_safety.read');
  if char_length(raw) > 120 then
    raise invalid_parameter_value using message = 'invalid person search',
      detail = 'PERSON_SEARCH_INVALID';
  end if;
  digits := regexp_replace(raw, '\D', '', 'g');

  if left(raw, 1) = '@' then
    kind := 'handle';
    needle := app_private.normalize_person_handle(raw);
    if char_length(needle) < 3 then
      raise invalid_parameter_value using message = 'person search needs more characters',
        detail = 'PERSON_SEARCH_MIN_LENGTH';
    end if;
  elsif position('@' in raw) > 0 then
    kind := 'email';
    needle := lower(raw);
    if char_length(needle) < 3 then
      raise invalid_parameter_value using message = 'person search needs more characters',
        detail = 'PERSON_SEARCH_MIN_LENGTH';
    end if;
    -- E-mail so existe como hash (person_contacts): apenas o endereco completo
    -- encontra; nenhum prefixo de e-mail e comparado nem devolvido.
    email_hash := encode(extensions.digest(pg_catalog.convert_to(needle, 'UTF8'), 'sha256'), 'hex');
  elsif raw ~ '^[0-9\s().+-]+$' and digits <> '' then
    kind := 'digits';
    needle := digits;
    if char_length(digits) < 4 then
      raise invalid_parameter_value using message = 'person search needs more characters',
        detail = 'PERSON_SEARCH_MIN_LENGTH';
    end if;
    if char_length(digits) >= 8 then
      phone_hash := encode(extensions.digest(pg_catalog.convert_to(digits, 'UTF8'), 'sha256'), 'hex');
    end if;
    -- CPF: nunca em claro no banco; so o numero completo e valido produz HMAC.
    if char_length(digits) = 11 and app_private.cpf_digits_valid_v1(digits) then
      cpf_hmac := app_private.person_identity_hmac_v1(digits);
    end if;
  else
    kind := 'name';
    needle := lower(raw);
    if char_length(needle) < 3 then
      raise invalid_parameter_value using message = 'person search needs more characters',
        detail = 'PERSON_SEARCH_MIN_LENGTH';
    end if;
  end if;

  -- Limite de taxa por ator (30 buscas por minuto). A excecao PT422 desfaz a
  -- propria linha, mas as 30 anteriores permanecem ate sairem da janela.
  delete from app_private.person_search_hits where occurred_at < now() - interval '10 minutes';
  select count(*) into hits from app_private.person_search_hits h
  where h.actor_person_id = actor and h.occurred_at > now() - interval '1 minute';
  if hits >= 30 then
    raise exception using errcode = 'PT422', message = 'person search rate limit',
      detail = 'PERSON_SEARCH_RATE_LIMIT';
  end if;
  insert into app_private.person_search_hits (actor_person_id) values (actor);

  with scope as (
    select i.id
    from public.institutions i
    where i.deleted_at is null
      and app_private.has_platform_permission('child_safety.read', i.id)
  ), candidates as (
    select p.id, p.display_name, p.first_name, p.last_name, p.account_avatar_initials, p.mobile_phone,
      case
        when kind = 'digits' and cpf_hmac is not null and exists (
          select 1 from app_private.person_identity_identifiers ii
          where ii.person_id = p.id and ii.identifier_kind = 'cpf' and ii.status = 'active'
            and ii.normalized_value_hmac = cpf_hmac) then 'document'
        when kind = 'digits' then 'phone'
        else kind
      end as matched_by
    from public.people p
    where p.person_type = 'adult' and p.status = 'active' and p.deleted_at is null
      and exists (
        select 1 from scope s
        where exists (
            select 1 from public.guardian_links gl
            join public.child_contexts cc on cc.child_person_id = gl.child_person_id
              and cc.status = 'active' and cc.institution_id = s.id
            where gl.guardian_person_id = p.id and gl.status = 'active' and gl.revoked_at is null)
          or exists (
            select 1 from public.authorized_people ap
            where ap.person_id = p.id and ap.institution_id = s.id and ap.status = 'active')
          or exists (
            select 1 from public.institution_memberships im
            where im.person_id = p.id and im.institution_id = s.id
              and im.status = 'active' and im.revoked_at is null))
      and (
        (kind = 'name' and (
          lower(p.display_name) like '%' || needle || '%'
          or lower(coalesce(p.legal_name, '')) like '%' || needle || '%'
          or lower(p.first_name || ' ' || p.last_name) like '%' || needle || '%'))
        or (kind = 'handle' and exists (
          select 1 from public.person_handles h
          where h.person_id = p.id and h.status = 'active' and h.revoked_at is null
            and h.normalized_handle like needle || '%'))
        or (kind = 'email' and exists (
          select 1 from public.person_contacts c
          where c.person_id = p.id and c.contact_type = 'email' and c.status = 'active'
            and c.normalized_value_hash = email_hash))
        or (kind = 'digits' and (
          regexp_replace(coalesce(p.mobile_phone, ''), '\D', '', 'g') like '%' || needle || '%'
          or (phone_hash is not null and exists (
            select 1 from public.person_contacts c
            where c.person_id = p.id and c.contact_type = 'mobile_phone' and c.status = 'active'
              and c.normalized_value_hash = phone_hash))
          or (cpf_hmac is not null and exists (
            select 1 from app_private.person_identity_identifiers ii
            where ii.person_id = p.id and ii.identifier_kind = 'cpf' and ii.status = 'active'
              and ii.normalized_value_hmac = cpf_hmac))))
      )
    order by p.display_name, p.id
    limit 10
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'person_id', c.id,
      'display_name', c.display_name,
      'initials', coalesce(c.account_avatar_initials,
        upper(left(c.first_name, 1) || left(c.last_name, 1))),
      'handle', (select '@' || h.normalized_handle from public.person_handles h
        where h.person_id = c.id and h.status = 'active' and h.revoked_at is null
        order by h.created_at limit 1),
      'phone_last4', nullif(right(regexp_replace(coalesce(c.mobile_phone, ''), '\D', '', 'g'), 4), ''),
      'matched_by', c.matched_by,
      'has_account', exists (select 1 from public.person_auth_links l
        where l.person_id = c.id and l.status = 'active' and l.revoked_at is null),
      'children', coalesce((
        select jsonb_agg(jsonb_build_object(
            'child_id', ch.id, 'child_name', ch.display_name, 'child_context_id', cc.id,
            'institution_id', i.id, 'institution_name', i.public_name,
            'unit_id', u.id, 'unit_name', u.name)
          order by ch.display_name, i.public_name, u.name)
        from public.guardian_links gl
        join public.people ch on ch.id = gl.child_person_id and ch.person_type = 'child'
          and ch.status = 'active' and ch.deleted_at is null
        join public.child_contexts cc on cc.child_person_id = ch.id and cc.status = 'active'
        join scope s on s.id = cc.institution_id
        join public.institutions i on i.id = cc.institution_id
        join public.child_unit_links l on l.child_context_id = cc.id
          and l.status in ('active', 'awaiting_allocation')
        join public.units u on u.id = l.unit_id and u.institution_id = cc.institution_id
        where gl.guardian_person_id = c.id and gl.status = 'active' and gl.revoked_at is null
      ), '[]'::jsonb)
    ) order by c.display_name, c.id), '[]'::jsonb)
  into results
  from candidates c;

  -- Auditoria: quem, quando, tipo detectado e contagem; nunca o texto buscado.
  insert into audit.audit_logs (actor_person_id, mfa_aal, action_code, object_type, object_id,
    outcome, reason, after_json)
  values (actor, coalesce(auth.jwt() ->> 'aal', 'aal1'), 'child_safety.person_search', 'person_search', null,
    'success', 'superadmin.child-safety.person-search',
    jsonb_build_object('kind', kind, 'result_count', jsonb_array_length(results)));

  return jsonb_build_object('ok', true, 'kind', kind, 'results', results);
end
$$;
revoke all on function app_private.superadmin_person_search_v1(text) from public, anon;

create or replace function public.superadmin_person_search_v1(p_query text)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select app_private.superadmin_person_search_v1(p_query) $$;
revoke all on function public.superadmin_person_search_v1(text) from public, anon;
grant execute on function public.superadmin_person_search_v1(text) to authenticated, service_role;

do $postcheck$
begin
  if to_regprocedure('public.superadmin_person_search_v1(text)') is null
    or exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'app_private' and p.proname = 'superadmin_person_search_v1'
        and p.prosrc like '%serialization_failure%') then
    raise object_not_in_prerequisite_state using message = 'person search v1 postcheck failed';
  end if;
end
$postcheck$;

commit;
