-- 20260911170100_person_handles_v1
-- Regra do @ para pessoas (ADR 0034, Decisao 16; complemento do Owner de 11/09 12:15).
--
-- Producao ja tem public.person_handles (um @ ativo por pessoa, unico
-- globalmente, ledger app_private.person_identity_correction_ledger com quem
-- mudou e o motivo) mas nada escreve nela e a trava era de 15 dias.
-- Este pacote:
--   1. trava de 30 dias (Decisao 16) em app_private.enforce_person_handle_rules;
--   2. reservados (coelo, coelo.me e afins) e validacao de formato;
--   3. geracao do @ padrao a partir do nome (nome.sobrenome, sufixo numerico
--      em colisao) e trigger que da o @ a toda pessoa adulta ou crianca ao
--      nascer, mais backfill idempotente das pessoas existentes;
--   4. RPCs publicas: superadmin_person_handle_availability (verificacao
--      enquanto digita), superadmin_person_handle_get (le o @ e quando pode
--      trocar) e superadmin_person_handle_set (troca com motivo).
-- Quem pode ver/editar: quem tem people.read/people.update na plataforma
-- (Superadmin), a propria pessoa e os responsaveis ativos de uma crianca
-- (guardian_links). Instituicao editando o @ do funcionario pelo app Admin
-- fica para quando o Admin existir (pendencia registrada no JSON do grupo).
-- Auditoria: ledger person_identity_correction_ledger (quem, quando, motivo),
-- gravado pelo trigger person_handles_record_correction que ja existe.
-- Idempotente: create or replace / if not exists em tudo.

-- 1. trava de 30 dias --------------------------------------------------------
create or replace function app_private.enforce_person_handle_rules() returns trigger
language plpgsql security definer set search_path=''
as $$
declare
  person_kind public.person_type;
begin
  new.normalized_handle := app_private.normalize_person_handle(new.normalized_handle);

  select person.person_type into person_kind
  from public.people person
  where person.id = new.person_id and person.deleted_at is null;

  if person_kind is null then
    raise foreign_key_violation using message = 'active person required';
  end if;
  if person_kind not in ('adult', 'child') then
    raise check_violation using message = 'handles belong only to adults or children';
  end if;
  if person_kind = 'child' and new.visibility <> 'private' then
    raise check_violation using message = 'child handles must remain private';
  end if;
  if tg_op = 'UPDATE' and old.revoked_at is not null then
    raise check_violation using message = 'revoked handles are immutable';
  end if;

  if tg_op = 'INSERT' or new.normalized_handle is distinct from old.normalized_handle then
    -- O @ inicial (linha do ledger sem old_value) nao conta como troca.
    if tg_op = 'UPDATE' and exists (
         select 1 from app_private.person_identity_correction_ledger ledger
         where ledger.person_id = new.person_id and ledger.correction_kind = 'handle'
           and ledger.old_value is not null
           and ledger.changed_at > clock_timestamp() - interval '30 days'
       ) then
      raise check_violation using
        message = 'person handle can be changed only once every 30 days';
    end if;
    new.last_changed_at := clock_timestamp();
  else
    new.last_changed_at := old.last_changed_at;
  end if;

  new.updated_at := clock_timestamp();
  return new;
end
$$;

-- 2. reservados e formato -----------------------------------------------------
create or replace function app_private.person_handle_is_reserved(p_normalized text) returns boolean
language sql immutable set search_path=''
as $$
  select p_normalized = any (array[
    'coelo','coelo.me','coelome','coelo_me','admin','superadmin','suporte','support',
    'sistema','system','root','owner','api','app','www'
  ]) or p_normalized like 'coelo.%' or p_normalized like 'coelo\_%';
$$;

create or replace function app_private.person_handle_is_valid(p_normalized text) returns boolean
language sql immutable set search_path=''
as $$
  select p_normalized is not null
    and p_normalized = lower(p_normalized)
    and p_normalized ~ '^[a-z0-9._]{3,30}$'
    and p_normalized !~ '\..*\.'  -- no maximo um ponto (constraint da tabela)
    and p_normalized !~ '\.$'
    and p_normalized !~ '^\.';
$$;

-- 3. geracao do @ padrao e trigger de nascimento ------------------------------
create or replace function app_private.person_handle_slug(p_text text) returns text
language sql immutable set search_path=''
as $$
  -- minusculas, sem acentos comuns, so [a-z0-9]
  select regexp_replace(
    translate(lower(coalesce(p_text,'')),
      'áàãâäéèêëíìîïóòõôöúùûüçñ', 'aaaaaeeeeiiiiooooouuuucn'),
    '[^a-z0-9]', '', 'g');
$$;

create or replace function app_private.generate_person_handle(p_first_name text, p_last_name text, p_display_name text) returns text
language plpgsql stable set search_path=''
as $$
declare
  first_part text := app_private.person_handle_slug(coalesce(nullif(p_first_name,''), split_part(coalesce(p_display_name,''), ' ', 1)));
  last_part text := app_private.person_handle_slug(coalesce(nullif(p_last_name,''),
    nullif(regexp_replace(coalesce(p_display_name,''), '^\S+\s*', ''), '')));
  base text;
  candidate text;
  suffix integer := 0;
begin
  base := case
    when first_part <> '' and last_part <> '' then left(first_part, 14) || '.' || left(last_part, 15)
    when first_part <> '' then left(first_part, 30)
    when last_part <> '' then left(last_part, 30)
    else 'pessoa' end;
  if length(base) < 3 then base := rpad(base, 3, '0'); end if;
  candidate := base;
  while app_private.person_handle_is_reserved(candidate)
     or exists (select 1 from public.person_handles h
                where h.normalized_handle = candidate and h.status = 'active' and h.revoked_at is null) loop
    suffix := suffix + 1;
    candidate := left(base, 30 - length(suffix::text)) || suffix::text;
    if suffix > 9999 then
      candidate := left('pessoa' || replace(gen_random_uuid()::text, '-', ''), 30);
    end if;
  end loop;
  return candidate;
end
$$;

create or replace function app_private.ensure_person_handle(p_person_id uuid) returns text
language plpgsql volatile security definer set search_path=''
as $$
declare
  person_record public.people%rowtype;
  existing text;
  generated text;
begin
  select * into person_record from public.people where id = p_person_id and deleted_at is null;
  if not found or person_record.person_type not in ('adult','child') then
    return null;
  end if;
  select h.normalized_handle into existing from public.person_handles h
  where h.person_id = p_person_id and h.status = 'active' and h.revoked_at is null;
  if existing is not null then
    return existing;
  end if;
  generated := app_private.generate_person_handle(
    person_record.first_name, person_record.last_name, person_record.display_name);
  insert into public.person_handles(person_id, normalized_handle, visibility, status)
  values (p_person_id, generated, 'private', 'active');
  return generated;
end
$$;

create or replace function app_private.people_assign_initial_handle() returns trigger
language plpgsql security definer set search_path=''
as $$
begin
  begin
    perform app_private.ensure_person_handle(new.id);
  exception when others then
    -- O @ nunca impede o cadastro da pessoa; fica para o backfill/set.
    raise warning 'person handle not assigned for %: %', new.id, sqlerrm;
  end;
  return new;
end
$$;

drop trigger if exists people_assign_initial_handle on public.people;
create trigger people_assign_initial_handle
  after insert on public.people
  for each row execute function app_private.people_assign_initial_handle();

-- backfill idempotente
select app_private.ensure_person_handle(person.id)
from public.people person
where person.deleted_at is null and person.person_type in ('adult','child')
  and not exists (select 1 from public.person_handles h
                  where h.person_id = person.id and h.status = 'active' and h.revoked_at is null);

-- 4. autorizacao e RPCs --------------------------------------------------------
create or replace function app_private.person_handle_actor_can(p_person_id uuid, p_write boolean) returns boolean
language sql stable security definer set search_path=''
as $$
  select (select auth.uid()) is not null and (
    app_private.has_platform_permission(case when p_write then 'people.update' else 'people.read' end)
    or app_private.current_person_id() = p_person_id
    or exists (
      select 1 from public.guardian_links gl
      where gl.child_person_id = p_person_id
        and gl.guardian_person_id = app_private.current_person_id()
        and gl.status = 'active' and gl.revoked_at is null)
  );
$$;

create or replace function public.superadmin_person_handle_availability(p_handle text, p_person_id uuid default null)
returns jsonb
language plpgsql stable security definer set search_path=''
as $$
declare
  normalized text := app_private.normalize_person_handle(p_handle);
  reason text := 'ok';
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'person handle permission denied';
  end if;
  if not app_private.person_handle_is_valid(normalized) then
    reason := 'invalid_format';
  elsif app_private.person_handle_is_reserved(normalized) then
    reason := 'reserved';
  elsif exists (select 1 from public.person_handles h
                where h.normalized_handle = normalized and h.status = 'active' and h.revoked_at is null
                  and (p_person_id is null or h.person_id <> p_person_id)) then
    reason := 'taken';
  end if;
  return jsonb_build_object('ok', true, 'data', jsonb_build_object(
    'handle', normalized, 'available', reason = 'ok', 'reason', reason), 'error', null);
end
$$;

create or replace function public.superadmin_person_handle_get(p_person_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=''
as $$
declare
  handle_record public.person_handles%rowtype;
  last_change timestamptz;
begin
  if not app_private.person_handle_actor_can(p_person_id, false) then
    raise insufficient_privilege using message = 'person handle permission denied';
  end if;
  select * into handle_record from public.person_handles h
  where h.person_id = p_person_id and h.status = 'active' and h.revoked_at is null;
  if not found then
    return jsonb_build_object('ok', true, 'data', null, 'error', null);
  end if;
  select max(l.changed_at) into last_change
  from app_private.person_identity_correction_ledger l
  where l.person_id = p_person_id and l.correction_kind = 'handle' and l.old_value is not null;
  return jsonb_build_object('ok', true, 'data', jsonb_build_object(
    'person_id', p_person_id,
    'handle', handle_record.normalized_handle,
    'last_changed_at', last_change,
    'can_change_at', case when last_change is null then now() else last_change + interval '30 days' end,
    'can_edit', app_private.person_handle_actor_can(p_person_id, true)), 'error', null);
end
$$;

create or replace function public.superadmin_person_handle_set(p_request_id uuid, p_person_id uuid, p_handle text, p_reason text)
returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare
  normalized text := app_private.normalize_person_handle(p_handle);
  availability jsonb;
  current_handle text;
begin
  if not app_private.person_handle_actor_can(p_person_id, true) then
    raise insufficient_privilege using message = 'person handle permission denied';
  end if;
  if p_request_id is null or nullif(btrim(coalesce(p_reason,'')),'') is null then
    raise invalid_parameter_value using message = 'request id and reason are required';
  end if;
  select h.normalized_handle into current_handle from public.person_handles h
  where h.person_id = p_person_id and h.status = 'active' and h.revoked_at is null;
  if current_handle = normalized then
    return public.superadmin_person_handle_get(p_person_id);
  end if;
  availability := public.superadmin_person_handle_availability(normalized, p_person_id);
  if not (availability->'data'->>'available')::boolean then
    raise invalid_parameter_value using
      message = 'person handle unavailable', detail = availability->'data'->>'reason';
  end if;
  perform set_config('coelo.identity_change_reason', btrim(p_reason), true);
  if current_handle is null then
    insert into public.person_handles(person_id, normalized_handle, visibility, status)
    values (p_person_id, normalized, 'private', 'active');
  else
    begin
      update public.person_handles set normalized_handle = normalized
      where person_id = p_person_id and status = 'active' and revoked_at is null;
    exception when check_violation then
      raise invalid_parameter_value using
        message = 'person handle unavailable', detail = 'cooldown';
    end;
  end if;
  return public.superadmin_person_handle_get(p_person_id);
end
$$;

revoke all on function app_private.person_handle_is_reserved(text) from public, anon, authenticated;
revoke all on function app_private.person_handle_is_valid(text) from public, anon, authenticated;
revoke all on function app_private.person_handle_slug(text) from public, anon, authenticated;
revoke all on function app_private.generate_person_handle(text, text, text) from public, anon, authenticated;
revoke all on function app_private.ensure_person_handle(uuid) from public, anon, authenticated;
revoke all on function app_private.people_assign_initial_handle() from public, anon, authenticated;
revoke all on function app_private.person_handle_actor_can(uuid, boolean) from public, anon, authenticated;
revoke all on function public.superadmin_person_handle_availability(text, uuid) from public, anon;
revoke all on function public.superadmin_person_handle_get(uuid) from public, anon;
revoke all on function public.superadmin_person_handle_set(uuid, uuid, text, text) from public, anon;
grant execute on function public.superadmin_person_handle_availability(text, uuid) to authenticated, service_role;
grant execute on function public.superadmin_person_handle_get(uuid) to authenticated, service_role;
grant execute on function public.superadmin_person_handle_set(uuid, uuid, text, text) to authenticated, service_role;
