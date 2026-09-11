-- Rodada 5 (E2-R05, frente Operacoes), gate de Back-end de support.assign
-- pela regua do MVP (ADR 0034).
--
-- O diretorio de Suporte (20260910230019 e 20260910210000) ja persiste
-- support_sessions.assigned_to_membership_id -> platform_memberships(id), mas
-- nenhuma RPC lia a equipe nem gravava o responsavel; o cliente usava uma
-- lista fixa e setAssignees nao persistia. Este pacote acrescenta:
--
-- 1. public.superadmin_support_team_members(): equipe de suporte = memberships
--    de plataforma ativas (status active, revoked_at nulo, scope_kind
--    'platform', scope_institution_id nulo, papel ativo) cujo papel concede
--    support.manage (owner e piso, ou platform_role_permissions allow ativo)
--    OU cuja pessoa e pessoa de servico da ponte 20260910220400
--    (people.person_type = 'service').
-- 2. public.superadmin_support_set_assignee(...): atribui ou limpa o
--    responsavel com recibo idempotente por request_id, revisao otimista
--    (40001), validacao da membership (22023 assignee_invalid) e evento
--    'support.assign' em audit.support_session_actions.
-- 3. public.superadmin_support_get(uuid): corpo identico ao de 20260910230019
--    acrescido da chave 'assignee_membership_id' (list ja a devolvia).
--
-- Reversao: drop function public.superadmin_support_team_members() e
-- public.superadmin_support_set_assignee(uuid,uuid,bigint,uuid); recriar
-- public.superadmin_support_get(uuid) com o corpo de 20260910230019
-- (linhas ~136-150). Nenhuma coluna ou tabela nova.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'support assignees migration must run as postgres';
  end if;
  if to_regprocedure('app_private.assert_support_permission()') is null
     or to_regprocedure('app_private.current_person_id()') is null
     or to_regprocedure('public.superadmin_support_get(uuid)') is null
     or to_regprocedure('public.superadmin_support_set_status(uuid,uuid,text,bigint)') is null
     or to_regclass('public.support_sessions') is null
     or to_regclass('public.support_messages') is null
     or to_regclass('public.support_command_receipts') is null
     or to_regclass('audit.support_session_actions') is null
     or to_regclass('public.platform_memberships') is null
     or to_regclass('public.platform_roles') is null
     or to_regclass('public.platform_role_permissions') is null
     or to_regclass('public.platform_permissions') is null
     or to_regclass('public.people') is null then
    raise object_not_in_prerequisite_state using message = 'support directory dependencies are required';
  end if;
  if (select count(*) from information_schema.columns
      where table_schema = 'public' and table_name = 'support_sessions'
        and column_name in ('assigned_to_membership_id', 'revision', 'updated_at', 'ticket_status')) <> 4 then
    raise object_not_in_prerequisite_state using message = 'support_sessions columns from 20260910230019 are required';
  end if;
end
$preflight$;

-- ---------------------------------------------------------------------------
-- 3. superadmin_support_get: corpo de 20260910230019 + assignee_membership_id
-- ---------------------------------------------------------------------------
create or replace function public.superadmin_support_get(p_session_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare result jsonb;
begin
  perform app_private.assert_support_permission();
  select jsonb_build_object(
    'id', s.id, 'subject', s.subject, 'menu', s.menu_code, 'screen', s.screen_code,
    'description', s.reported_issue, 'requester', s.requester_label,
    'institution_id', s.institution_id, 'unit_id', s.unit_id,
    'status', s.ticket_status, 'priority', s.priority, 'revision', s.revision,
    'created_at', s.opened_at, 'updated_at', s.updated_at,
    'assignee_membership_id', s.assigned_to_membership_id,
    'messages', coalesce((select jsonb_agg(jsonb_build_object(
      'id', m.id, 'text', m.message_text,
      'author', case when m.author_membership_id is null then 'requester' else 'support' end,
      'created_at', m.created_at, 'read', m.deleted_at is not null
    ) order by m.created_at, m.id) from public.support_messages m
      where m.support_session_id = s.id and m.deleted_at is null), '[]'::jsonb),
      'activities', coalesce((select jsonb_agg(jsonb_build_object(
      'id', a.id, 'action', a.action_code, 'outcome', a.outcome::text,
      'occurred_at', a.occurred_at, 'metadata', a.metadata_json
    ) order by a.occurred_at, a.id) from audit.support_session_actions a
      where a.support_session_id = s.id), '[]'::jsonb)
  ) into result
  from public.support_sessions s where s.id = p_session_id;
  if result is null then raise exception using errcode = 'P0002', message = 'support_session_not_found'; end if;
  return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. Equipe de suporte
-- ---------------------------------------------------------------------------
create or replace function public.superadmin_support_team_members()
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare result jsonb;
begin
  perform app_private.assert_support_permission();
  with support_permission as (
    select p.id from public.platform_permissions p
    where p.code = 'support.manage' and p.status = 'active'
  ), team as (
    select m.id as membership_id, m.person_id, r.code as role_code,
      trim(coalesce(nullif(trim(p.display_name), ''),
        concat_ws(' ', nullif(trim(p.first_name), ''), nullif(trim(p.last_name), '')))) as display_name,
      m.created_at
    from public.platform_memberships m
    join public.platform_roles r on r.id = m.role_id and r.status = 'active'
    join public.people p on p.id = m.person_id and p.deleted_at is null and p.status = 'active'
    where m.status = 'active' and m.revoked_at is null
      and m.scope_kind = 'platform' and m.scope_institution_id is null
      and (
        p.person_type = 'service'
        or r.code = 'owner'
        or exists (
          select 1 from public.platform_role_permissions rp
          cross join support_permission sp
          where rp.role_id = r.id and rp.permission_id = sp.id
            and rp.status = 'active' and rp.revoked_at is null and rp.effect = 'allow'
        )
      )
  ), named as (
    select t.*,
      (select array_agg(u.w order by u.ord)
       from unnest(regexp_split_to_array(
         regexp_replace(t.display_name, '[^[:alpha:][:space:]]', '', 'g'), '\s+'))
         with ordinality as u(w, ord)
       where u.w <> '') as words
    from team t
  ), shaped as (
    select membership_id, person_id, display_name, role_code,
      case when words is null or cardinality(words) = 0 then 'EQ'
        when cardinality(words) = 1 then upper(left(words[1], 1))
        else upper(left(words[1], 1) || left(words[cardinality(words)], 1)) end as initials,
      created_at
    from named
  )
  select jsonb_build_object(
    'items', coalesce(jsonb_agg(jsonb_build_object(
      'membership_id', membership_id, 'person_id', person_id,
      'display_name', display_name, 'initials', initials, 'role', role_code
    ) order by display_name, created_at, membership_id), '[]'::jsonb),
    'total', count(*)
  ) into result from shaped;
  return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Atribuir / limpar responsavel
-- ---------------------------------------------------------------------------
create or replace function public.superadmin_support_set_assignee(
  p_request_id uuid, p_session_id uuid, p_expected_revision bigint, p_assignee_membership_id uuid
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare actor_id uuid; current_revision bigint; previous_assignee uuid; result jsonb;
begin
  actor_id := app_private.assert_support_permission();
  if p_request_id is null or p_session_id is null then
    raise exception using errcode = '22023', message = 'invalid_support_request';
  end if;
  if exists(select 1 from public.support_command_receipts where request_id = p_request_id) then
    select response_json into result from public.support_command_receipts where request_id = p_request_id;
    return result;
  end if;
  if p_assignee_membership_id is not null and not exists (
    select 1 from public.platform_memberships m
    where m.id = p_assignee_membership_id and m.status = 'active' and m.revoked_at is null
      and m.scope_kind = 'platform' and m.scope_institution_id is null
  ) then
    raise exception using errcode = '22023', message = 'assignee_invalid';
  end if;
  select revision, assigned_to_membership_id into current_revision, previous_assignee
    from public.support_sessions where id = p_session_id for update;
  if current_revision is null then raise exception using errcode = 'P0002', message = 'support_session_not_found'; end if;
  if p_expected_revision is null or p_expected_revision <> current_revision then
    raise exception using errcode = '40001', message = 'support_revision_conflict';
  end if;
  update public.support_sessions set assigned_to_membership_id = p_assignee_membership_id,
    revision = revision + 1, updated_at = now() where id = p_session_id;
  insert into audit.support_session_actions(support_session_id, action_code, object_type, object_id, metadata_json)
    values (p_session_id, 'support.assign', 'support_session', p_session_id,
      jsonb_build_object('actor_person_id', actor_id,
        'assignee_membership_id', p_assignee_membership_id,
        'previous_assignee_membership_id', previous_assignee));
  result := public.superadmin_support_get(p_session_id);
  insert into public.support_command_receipts(request_id, support_session_id, actor_person_id, action_code, response_json)
    values (p_request_id, p_session_id, actor_id, 'assign', result);
  return result;
end;
$$;

-- ACL igual as demais RPCs de Suporte: authenticated e service_role executam; anon nao.
revoke all on function public.superadmin_support_get(uuid) from public, anon, authenticated, service_role;
revoke all on function public.superadmin_support_team_members() from public, anon, authenticated, service_role;
revoke all on function public.superadmin_support_set_assignee(uuid,uuid,bigint,uuid) from public, anon, authenticated, service_role;
grant execute on function public.superadmin_support_get(uuid) to authenticated, service_role;
grant execute on function public.superadmin_support_team_members() to authenticated, service_role;
grant execute on function public.superadmin_support_set_assignee(uuid,uuid,bigint,uuid) to authenticated, service_role;

comment on function public.superadmin_support_team_members() is
  'Equipe de suporte do Superadmin: memberships de plataforma ativas cujo papel concede support.manage ou cuja pessoa e pessoa de servico da ponte interna. Exige sessao e support.manage.';
comment on function public.superadmin_support_set_assignee(uuid,uuid,bigint,uuid) is
  'Atribui (ou limpa, com nulo) o responsavel de um chamado de Suporte. Recibo idempotente por request_id, revisao otimista (40001), membership de plataforma ativa obrigatoria (22023 assignee_invalid), evento support.assign auditado.';

commit;
