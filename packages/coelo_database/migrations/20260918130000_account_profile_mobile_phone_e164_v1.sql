-- 20260918130000_account_profile_mobile_phone_e164_v1
--
-- R16 Sessao RESERVA / decisao D5 do Owner em 18/09/2026 (R16-prompt-reserva-20260918.md,
-- lote 82 item b; owner.r12-46 / divida celular-mascara): o Celular da Conta e gravado em
-- E.164 brasileiro (+55DDD9NNNNNNNN, 11 digitos nacionais) e o servidor valida o formato.
--
-- O que muda:
--   * app_private.normalize_mobile_phone_e164(text): funcao pura; aceita digitos com ou sem
--     mascara, com ou sem +55 (ou 55 na frente de 11 digitos); devolve '+55' || 11 digitos
--     ou NULL quando invalido (DDD 11-99 sem zero, terceiro digito 9 = celular; outro codigo
--     de pais e recusado). Sem grants a clientes.
--   * public.superadmin_account_profile_save_v2 (mesma assinatura e grants): normaliza
--     p_mobile_phone antes de gravar e responde 22023 'invalid_account_mobile_phone' quando
--     invalido (codigo de familia; nunca 40001). A validacao antiga "7 a 40 caracteres" cai.
--     Idempotencia por request_id, receipts, avatar e troca de e-mail inalterados.
--   * superadmin_account_profile_save (v1) continua delegando a v2.
-- Leitura (superadmin_account_profile_get / account_profile_projection) devolve o valor
-- gravado; o cliente exibe com mascara. Valores antigos gravados "como digitado" continuam
-- legiveis e sao normalizados no proximo salvar.
-- Forward-only, idempotente (create or replace).
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'account mobile phone e164 migration requires postgres';
  end if;
  if to_regprocedure('public.superadmin_account_profile_save_v2(uuid,text,text,text,text,text,text)') is null
    or to_regprocedure('app_private.assert_account_actor()') is null
    or to_regprocedure('app_private.account_profile_projection(uuid)') is null then
    raise object_not_in_prerequisite_state using message = 'account profile v2 is required';
  end if;
end
$preflight$;

create or replace function app_private.normalize_mobile_phone_e164(p_value text)
returns text
language plpgsql immutable
set search_path = ''
as $$
declare
  raw text := btrim(coalesce(p_value, ''));
  digits text;
begin
  if raw = '' then
    return null;
  end if;
  -- outro codigo de pais explicito e recusado
  if left(raw, 1) = '+' and left(raw, 3) <> '+55' then
    return null;
  end if;
  digits := regexp_replace(raw, '\D', '', 'g');
  if (left(raw, 3) = '+55' or char_length(digits) = 13) and left(digits, 2) = '55' then
    digits := substr(digits, 3);
  end if;
  if digits !~ '^[1-9][1-9]9[0-9]{8}$' then
    return null;
  end if;
  return '+55' || digits;
end $$;

alter function app_private.normalize_mobile_phone_e164(text) owner to postgres;
revoke all on function app_private.normalize_mobile_phone_e164(text) from public, anon, authenticated, service_role;

create or replace function public.superadmin_account_profile_save_v2(
  p_request_id uuid, p_first_name text, p_last_name text, p_mobile_phone text,
  p_requested_email text default null, p_avatar_initials text default null,
  p_avatar_background_color text default null
) returns jsonb language plpgsql security definer set search_path = ''
as $$
declare actor_id uuid; result jsonb; current_email text; normalized_email text; normalized_phone text;
begin
  actor_id := app_private.assert_account_actor();
  if p_request_id is null or char_length(trim(coalesce(p_first_name,''))) not between 1 and 80
    or char_length(trim(coalesce(p_last_name,''))) not between 1 and 120
    or (p_avatar_background_color is not null and p_avatar_background_color !~ '^#[0-9A-Fa-f]{6}$')
    or (p_avatar_initials is not null and p_avatar_initials !~ '^[[:alpha:]]{1,2}$') then
    raise exception using errcode = '22023', message = 'invalid_account_profile';
  end if;
  normalized_phone := app_private.normalize_mobile_phone_e164(p_mobile_phone);
  if normalized_phone is null then
    raise exception using errcode = '22023', message = 'invalid_account_mobile_phone',
      detail = 'ACCOUNT_MOBILE_PHONE_E164_REQUIRED';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
  if exists (select 1 from public.account_profile_command_receipts where request_id=p_request_id and (person_id<>actor_id or action_code<>'save')) then
    raise exception using errcode='42501',message='account_request_not_owned';
  end if;
  select response_json into result from public.account_profile_command_receipts where request_id=p_request_id and person_id=actor_id and action_code='save';
  if result is not null then return result; end if;
  select u.email into current_email
  from auth.users u join public.person_auth_links link on link.auth_user_id = u.id
  where link.person_id = actor_id and link.status = 'active'
  order by link.linked_at desc limit 1;
  if current_email is null then select email into current_email from auth.users where id=auth.uid(); end if;
  update public.people set account_avatar_initials=coalesce(upper(p_avatar_initials),account_avatar_initials),
    account_avatar_background_color=coalesce(upper(p_avatar_background_color),account_avatar_background_color), first_name = trim(p_first_name), last_name = trim(p_last_name),
    display_name = trim(p_first_name) || ' ' || trim(p_last_name), mobile_phone = normalized_phone, updated_at = now()
  where id = actor_id and deleted_at is null;
  if not found then raise exception using errcode = 'P0002', message = 'account_profile_not_found'; end if;
  normalized_email := lower(trim(coalesce(p_requested_email, '')));
  if normalized_email <> '' and normalized_email <> lower(coalesce(current_email, '')) then
    insert into public.account_email_change_requests(person_id, requested_email)
      values (actor_id, normalized_email)
      on conflict (person_id) where status = 'pending'
      do update set requested_email = excluded.requested_email, requested_at = now();
  end if;
  result := app_private.account_profile_projection(actor_id);
  insert into public.account_profile_command_receipts(request_id, person_id, action_code, response_json)
    values (p_request_id, actor_id, 'save', result);
  return result;
end;
$$;
revoke all on function public.superadmin_account_profile_save_v2(uuid,text,text,text,text,text,text) from public,anon;
grant execute on function public.superadmin_account_profile_save_v2(uuid,text,text,text,text,text,text) to authenticated;

do $postcheck$
begin
  if app_private.normalize_mobile_phone_e164('(11) 91234-5678') <> '+5511912345678'
    or app_private.normalize_mobile_phone_e164('11 1234-5678') is not null then
    raise object_not_in_prerequisite_state using message = 'normalize_mobile_phone_e164 self-check failed';
  end if;
  if position('normalize_mobile_phone_e164' in
      pg_get_functiondef('public.superadmin_account_profile_save_v2(uuid,text,text,text,text,text,text)'::regprocedure)) = 0 then
    raise object_not_in_prerequisite_state using message = 'save_v2 does not normalize the mobile phone';
  end if;
end
$postcheck$;

commit;
