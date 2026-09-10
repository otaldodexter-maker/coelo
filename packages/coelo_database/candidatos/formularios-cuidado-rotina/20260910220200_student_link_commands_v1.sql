-- Alunos: vincular, transferir, editar e revogar.
--
-- Contexto: as quatro acoes (students.link, students.transfer, students.edit e
-- students.revoke) estao no MVP e o adiamento nao foi autorizado, mas nao
-- existia comando nenhum para elas. A leitura do diretorio ja estava
-- qualificada (SupabaseChildDirectoryReader); as escritas nunca sairam do
-- papel, e a rota /students/:childContextId/manage abre uma tela de
-- indisponivel.
--
-- As tabelas ja existem desde 20260720180000: child_contexts, child_unit_links
-- e child_group_links. Este pacote nao cria estrutura nova; cria os quatro
-- comandos que faltavam, com autorizacao, hierarquia, transacao, recibo e
-- auditoria.
--
-- Tres regras que valem em todos eles, e que sao o motivo de existirem como
-- RPC e nao como escrita direta:
--
--   1. A instituicao nunca vem do payload. Ela e derivada do contexto infantil,
--      porque aceitar a instituicao enviada pelo cliente permitiria mover a
--      crianca de um tenant para outro.
--   2. Unidade e turma sao conferidas contra essa instituicao antes de
--      qualquer escrita. Um id de turma de outro tenant e recusado com a mesma
--      negativa opaca de um id que nao existe.
--   3. Revogar nao apaga. O vinculo passa a revoked com carimbo e motivo, e o
--      historico continua legivel para auditoria; presenca, rotina e cuidado
--      passados continuam apontando para um vinculo que existiu.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '600s';
select pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('coelo.students.link-commands', 0)
);

do $preflight$
begin
  if current_user <> 'postgres' then
    raise exception using errcode='42501',
      message='student link commands must run as postgres';
  end if;
  if pg_catalog.to_regclass('public.child_unit_links') is null
    or pg_catalog.to_regclass('public.child_group_links') is null
    or pg_catalog.to_regclass('audit.audit_logs') is null then
    raise exception using errcode='55000',
      message='student link commands require the contextual core';
  end if;
end
$preflight$;

create table if not exists app_private.student_link_command_receipts (
  request_id uuid primary key,
  actor_person_id uuid not null references public.people(id) on delete restrict,
  command text not null check (btrim(command) <> ''),
  aggregate_id uuid,
  response jsonb not null,
  created_at timestamptz not null default now()
);
alter table app_private.student_link_command_receipts enable row level security;
alter table app_private.student_link_command_receipts force row level security;
revoke all on app_private.student_link_command_receipts
  from public, anon, authenticated;
grant all on app_private.student_link_command_receipts to service_role;

-- ---------------------------------------------------------------------------
-- Auxiliares
-- ---------------------------------------------------------------------------

create or replace function app_private.student_link_receipt(
  p_request_id uuid,
  p_actor uuid,
  p_command text
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  receipt app_private.student_link_command_receipts%rowtype;
begin
  if p_request_id is null then
    raise invalid_parameter_value using message='request id required';
  end if;
  select * into receipt
  from app_private.student_link_command_receipts
  where request_id = p_request_id;
  if receipt.request_id is null then
    return null;
  end if;
  if receipt.actor_person_id is distinct from p_actor
    or receipt.command is distinct from p_command then
    raise invalid_parameter_value using message='request id reused for another command';
  end if;
  return receipt.response;
end
$$;

-- Devolve a instituicao do contexto infantil ativo e recusa qualquer outra
-- coisa. Toda a autorizacao dos quatro comandos comeca por aqui.
create or replace function app_private.student_link_require_scope(
  p_child_context_id uuid,
  p_unit_id uuid,
  p_group_id uuid
) returns uuid
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  institution uuid;
begin
  if actor is null then
    raise insufficient_privilege using message='authentication required';
  end if;
  select child_row.institution_id into institution
  from public.child_contexts child_row
  where child_row.id = p_child_context_id
    and child_row.status = 'active';
  if institution is null then
    raise no_data_found using message='student link unavailable';
  end if;
  if not app_private.has_context_permission(
    institution, 'people.assign_children', p_unit_id, p_group_id, null,
    p_child_context_id, false
  ) then
    raise insufficient_privilege using message='people.assign_children required';
  end if;
  -- Hierarquia: a unidade pertence a instituicao da crianca e a turma pertence
  -- aquela unidade. Sem esta conferencia, um id de outro tenant entraria pelo
  -- payload e o vinculo nasceria no lugar errado.
  if p_unit_id is not null and not exists (
    select 1 from public.units unit_row
    where unit_row.id = p_unit_id and unit_row.institution_id = institution
  ) then
    raise no_data_found using message='student link unavailable';
  end if;
  if p_group_id is not null and not exists (
    select 1 from public.groups group_row
    where group_row.id = p_group_id
      and group_row.unit_id = p_unit_id
      and group_row.institution_id = institution
  ) then
    raise no_data_found using message='student link unavailable';
  end if;
  return institution;
end
$$;

-- ---------------------------------------------------------------------------
-- Vincular
-- ---------------------------------------------------------------------------

create or replace function app_private.superadmin_student_link(
  p_request_id uuid,
  p_child_context_id uuid,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  institution uuid;
  target_unit uuid := (p_payload->>'unit_id')::uuid;
  target_group uuid := (p_payload->>'group_id')::uuid;
  unit_link public.child_unit_links;
  group_link_id uuid;
  response jsonb;
begin
  response := app_private.student_link_receipt(p_request_id, actor, 'link');
  if response is not null then return response; end if;
  if target_unit is null then
    raise invalid_parameter_value using message='student link requires a unit';
  end if;
  institution := app_private.student_link_require_scope(
    p_child_context_id, target_unit, target_group);
  perform pg_advisory_xact_lock(hashtextextended(p_child_context_id::text, 0));

  -- Vincular a mesma crianca a mesma unidade de novo nao cria um segundo
  -- vinculo: reativa o que existe. A unicidade (child_context_id, unit_id) ja
  -- diz isso no schema; aqui a intencao vira reativacao explicita em vez de
  -- erro de chave.
  insert into public.child_unit_links(
    child_context_id, unit_id, status, accepted_by, accepted_at
  ) values (
    p_child_context_id, target_unit, 'active', actor, now()
  )
  on conflict (child_context_id, unit_id) do update set
    status = 'active',
    accepted_by = excluded.accepted_by,
    accepted_at = excluded.accepted_at,
    revoked_at = null,
    updated_at = now()
  returning * into unit_link;

  if target_group is not null then
    insert into public.child_group_links(
      child_unit_link_id, group_id, status, starts_at
    ) values (
      unit_link.id, target_group, 'active',
      coalesce((p_payload->>'starts_at')::timestamptz, now())
    )
    on conflict (child_unit_link_id, group_id) do update set
      status = 'active',
      starts_at = coalesce(excluded.starts_at, public.child_group_links.starts_at),
      ends_at = null,
      updated_at = now()
    returning id into group_link_id;
  end if;

  response := jsonb_build_object(
    'child_context_id', p_child_context_id,
    'unit_link_id', unit_link.id,
    'group_link_id', group_link_id,
    'status', unit_link.status
  );
  insert into app_private.student_link_command_receipts
    values (p_request_id, actor, 'link', unit_link.id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'student.link', 'child_unit_link',
    unit_link.id, institution, 'success', response
  );
  return response;
end
$$;

-- ---------------------------------------------------------------------------
-- Transferir
-- ---------------------------------------------------------------------------

create or replace function app_private.superadmin_student_transfer(
  p_request_id uuid,
  p_child_context_id uuid,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  institution uuid;
  origin_unit uuid := (p_payload->>'from_unit_id')::uuid;
  target_unit uuid := (p_payload->>'to_unit_id')::uuid;
  target_group uuid := (p_payload->>'to_group_id')::uuid;
  reason text := nullif(btrim(coalesce(p_payload->>'reason','')), '');
  origin_link public.child_unit_links;
  target_link public.child_unit_links;
  response jsonb;
begin
  response := app_private.student_link_receipt(p_request_id, actor, 'transfer');
  if response is not null then return response; end if;
  if origin_unit is null or target_unit is null then
    raise invalid_parameter_value using message='student transfer requires both units';
  end if;
  if origin_unit = target_unit then
    raise invalid_parameter_value using message='student transfer requires a different unit';
  end if;
  if reason is null then
    raise check_violation using message='transfer reason required';
  end if;
  -- Autoriza os DOIS lados: quem so pode gerir a unidade de destino nao pode
  -- retirar a crianca da unidade de origem.
  institution := app_private.student_link_require_scope(
    p_child_context_id, origin_unit, null);
  perform app_private.student_link_require_scope(
    p_child_context_id, target_unit, target_group);
  perform pg_advisory_xact_lock(hashtextextended(p_child_context_id::text, 0));

  select * into origin_link from public.child_unit_links
  where child_context_id = p_child_context_id and unit_id = origin_unit
  for update;
  if origin_link.id is null or origin_link.status not in ('active','awaiting_allocation') then
    raise no_data_found using message='student link unavailable';
  end if;

  -- As turmas da origem encerram junto: uma crianca transferida deixa de
  -- pertencer as turmas da unidade que deixou, senao continuaria aparecendo em
  -- chamada e rotina de uma unidade onde ja nao esta.
  update public.child_group_links set
    status = 'inactive', ends_at = coalesce(ends_at, now()), updated_at = now()
  where child_unit_link_id = origin_link.id and status = 'active';

  update public.child_unit_links set
    status = 'inactive', updated_at = now()
  where id = origin_link.id;

  insert into public.child_unit_links(
    child_context_id, unit_id, status, accepted_by, accepted_at
  ) values (
    p_child_context_id, target_unit, 'active', actor, now()
  )
  on conflict (child_context_id, unit_id) do update set
    status = 'active',
    accepted_by = excluded.accepted_by,
    accepted_at = excluded.accepted_at,
    revoked_at = null,
    updated_at = now()
  returning * into target_link;

  if target_group is not null then
    insert into public.child_group_links(
      child_unit_link_id, group_id, status, starts_at
    ) values (target_link.id, target_group, 'active', now())
    on conflict (child_unit_link_id, group_id) do update set
      status = 'active', ends_at = null, updated_at = now();
  end if;

  response := jsonb_build_object(
    'child_context_id', p_child_context_id,
    'from_unit_link_id', origin_link.id,
    'unit_link_id', target_link.id,
    'status', target_link.status
  );
  insert into app_private.student_link_command_receipts
    values (p_request_id, actor, 'transfer', target_link.id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, reason, before_json, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'student.transfer', 'child_unit_link',
    target_link.id, institution, 'success', reason,
    to_jsonb(origin_link), response
  );
  return response;
end
$$;

-- ---------------------------------------------------------------------------
-- Editar
-- ---------------------------------------------------------------------------

create or replace function app_private.superadmin_student_edit(
  p_request_id uuid,
  p_child_context_id uuid,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  institution uuid;
  target_unit uuid := (p_payload->>'unit_id')::uuid;
  target_group uuid := (p_payload->>'group_id')::uuid;
  unit_link public.child_unit_links;
  group_link public.child_group_links;
  before_state jsonb;
  response jsonb;
begin
  response := app_private.student_link_receipt(p_request_id, actor, 'edit');
  if response is not null then return response; end if;
  if target_unit is null or target_group is null then
    raise invalid_parameter_value using message='student edit requires unit and group';
  end if;
  institution := app_private.student_link_require_scope(
    p_child_context_id, target_unit, target_group);
  perform pg_advisory_xact_lock(hashtextextended(p_child_context_id::text, 0));

  select * into unit_link from public.child_unit_links
  where child_context_id = p_child_context_id and unit_id = target_unit;
  if unit_link.id is null then
    raise no_data_found using message='student link unavailable';
  end if;
  select * into group_link from public.child_group_links
  where child_unit_link_id = unit_link.id and group_id = target_group
  for update;
  if group_link.id is null then
    raise no_data_found using message='student link unavailable';
  end if;
  before_state := to_jsonb(group_link);

  update public.child_group_links set
    starts_at = coalesce((p_payload->>'starts_at')::timestamptz, starts_at),
    ends_at = case
      when p_payload ? 'ends_at' then (p_payload->>'ends_at')::timestamptz
      else ends_at end,
    updated_at = now()
  where id = group_link.id returning * into group_link;

  response := jsonb_build_object(
    'child_context_id', p_child_context_id,
    'unit_link_id', unit_link.id,
    'group_link_id', group_link.id,
    'starts_at', group_link.starts_at,
    'ends_at', group_link.ends_at
  );
  insert into app_private.student_link_command_receipts
    values (p_request_id, actor, 'edit', group_link.id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, before_json, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'student.edit', 'child_group_link',
    group_link.id, institution, 'success', before_state, response
  );
  return response;
end
$$;

-- ---------------------------------------------------------------------------
-- Revogar
-- ---------------------------------------------------------------------------

create or replace function app_private.superadmin_student_revoke(
  p_request_id uuid,
  p_child_context_id uuid,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  institution uuid;
  target_unit uuid := (p_payload->>'unit_id')::uuid;
  reason text := nullif(btrim(coalesce(p_payload->>'reason','')), '');
  unit_link public.child_unit_links;
  before_state jsonb;
  response jsonb;
begin
  response := app_private.student_link_receipt(p_request_id, actor, 'revoke');
  if response is not null then return response; end if;
  if target_unit is null then
    raise invalid_parameter_value using message='student revoke requires a unit';
  end if;
  if reason is null then
    raise check_violation using message='revoke reason required';
  end if;
  institution := app_private.student_link_require_scope(
    p_child_context_id, target_unit, null);
  perform pg_advisory_xact_lock(hashtextextended(p_child_context_id::text, 0));

  select * into unit_link from public.child_unit_links
  where child_context_id = p_child_context_id and unit_id = target_unit
  for update;
  if unit_link.id is null or unit_link.status = 'revoked' then
    raise no_data_found using message='student link unavailable';
  end if;
  before_state := to_jsonb(unit_link);

  -- Revogar nao apaga: encerra as turmas e marca o vinculo, preservando o
  -- historico. Presenca, rotina e cuidado passados continuam apontando para um
  -- vinculo que existiu.
  update public.child_group_links set
    status = 'inactive', ends_at = coalesce(ends_at, now()), updated_at = now()
  where child_unit_link_id = unit_link.id and status = 'active';

  update public.child_unit_links set
    status = 'revoked', revoked_at = now(), updated_at = now()
  where id = unit_link.id returning * into unit_link;

  response := jsonb_build_object(
    'child_context_id', p_child_context_id,
    'unit_link_id', unit_link.id,
    'status', unit_link.status,
    'revoked_at', unit_link.revoked_at
  );
  insert into app_private.student_link_command_receipts
    values (p_request_id, actor, 'revoke', unit_link.id, response, now());
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id,
    institution_id, outcome, reason, before_json, after_json
  ) values (
    actor, auth.jwt()->>'aal', 'student.revoke', 'child_unit_link',
    unit_link.id, institution, 'success', reason, before_state, response
  );
  return response;
end
$$;

-- ---------------------------------------------------------------------------
-- Superficie publica
-- ---------------------------------------------------------------------------

create or replace function public.superadmin_student_link(
  request_id uuid, child_context_id uuid, payload jsonb
) returns jsonb language sql volatile security invoker set search_path='' as $$
  select app_private.superadmin_student_link(request_id, child_context_id, payload)
$$;

create or replace function public.superadmin_student_transfer(
  request_id uuid, child_context_id uuid, payload jsonb
) returns jsonb language sql volatile security invoker set search_path='' as $$
  select app_private.superadmin_student_transfer(request_id, child_context_id, payload)
$$;

create or replace function public.superadmin_student_edit(
  request_id uuid, child_context_id uuid, payload jsonb
) returns jsonb language sql volatile security invoker set search_path='' as $$
  select app_private.superadmin_student_edit(request_id, child_context_id, payload)
$$;

create or replace function public.superadmin_student_revoke(
  request_id uuid, child_context_id uuid, payload jsonb
) returns jsonb language sql volatile security invoker set search_path='' as $$
  select app_private.superadmin_student_revoke(request_id, child_context_id, payload)
$$;

do $grants$
declare current_signature text;
begin
  foreach current_signature in array array[
    'app_private.student_link_receipt(uuid,uuid,text)',
    'app_private.student_link_require_scope(uuid,uuid,uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated',
      current_signature);
  end loop;

  foreach current_signature in array array[
    'app_private.superadmin_student_link(uuid,uuid,jsonb)',
    'app_private.superadmin_student_transfer(uuid,uuid,jsonb)',
    'app_private.superadmin_student_edit(uuid,uuid,jsonb)',
    'app_private.superadmin_student_revoke(uuid,uuid,jsonb)',
    'public.superadmin_student_link(uuid,uuid,jsonb)',
    'public.superadmin_student_transfer(uuid,uuid,jsonb)',
    'public.superadmin_student_edit(uuid,uuid,jsonb)',
    'public.superadmin_student_revoke(uuid,uuid,jsonb)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated',
      current_signature);
    execute format('grant execute on function %s to authenticated, service_role',
      current_signature);
  end loop;
end
$grants$;

commit;
