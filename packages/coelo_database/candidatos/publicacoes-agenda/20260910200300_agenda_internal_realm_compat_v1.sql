-- Agenda (Superadmin): compatibilidade com o realm interno v2 sobre a baseline de
-- producao (ADR 0034, Decisao 8/P12; pendencia "contexto interno 039").
-- As RPCs superadmin_agenda_* em producao sao people-based: assert_agenda_permission
-- exige app_private.current_person_id() e as tabelas gravam *_person_id NOT NULL com
-- FK para public.people. O operador do Superadmin vive em
-- app_private.superadmin_internal_identities e, por desenho (ADR 0019/spec 039),
-- nunca ganha uma linha em public.people. Este pacote:
--   * torna as colunas de ator opcionais e acrescenta *_internal_identity_id (FK) em
--     agenda_events, agenda_history_receipts e agenda_publication_requests, com
--     check de exatamente um realm por coluna de ator;
--   * roteia por trigger BEFORE INSERT/UPDATE o ator gravado em *_person_id para a
--     coluna interna quando o uuid e uma identidade interna (as RPCs nao mudam);
--   * agenda_actor_id() resolve pessoa ou identidade interna; agenda_has_permission()
--     soma ao has_platform_permission (intocado: pertence ao grupo acessos-pessoas)
--     a concessao do papel do membership interno ativo com escopo de plataforma;
--   * assert_agenda_permission usa os dois helpers (mesma assinatura); MFA fora do
--     MVP: has_mfa_aal2 ja aceita aal1 desde 20260910230021;
--   * recria as sete RPCs com o texto exato de producao trocando somente
--     has_platform_permission -> agenda_has_permission, ocultando as colunas
--     internas no JSON de saida e, em superadmin_agenda_contexts, incluindo as
--     instituicoes do membership interno ativo. Grants e assinaturas preservados.
--   * concede agenda.read a owner/content/operations e as demais capacidades ao
--     owner: producao nao tinha nenhuma concessao de agenda.* (nem ao Owner).
--   * fecha grants medidos na baseline: tabelas sem acesso direto de anon/authenticated
--     e RPCs executaveis so por authenticated (anon e service_role tinham EXECUTE).
-- Membership interno com escopo de instituicao continua sem Agenda (deny-by-default),
-- como o realm people-based ja exigia escopo de plataforma. Producao tem zero linhas.
-- Grupo publicacoes-agenda, Rodada 4 (E2-R04-20260911).
begin;

do $preflight$
begin
  if current_user <> 'postgres'
    or to_regprocedure('app_private.assert_agenda_permission(text,boolean)') is null
    or to_regprocedure('app_private.has_platform_permission(text)') is null
    or to_regprocedure('app_private.current_person_id()') is null
    or to_regprocedure('public.superadmin_agenda_save(uuid,uuid,bigint,jsonb,text,boolean)') is null
    or to_regclass('public.agenda_events') is null
    or to_regclass('public.agenda_history_receipts') is null
    or to_regclass('public.agenda_publication_requests') is null
    or to_regclass('app_private.superadmin_internal_identities') is null
    or to_regclass('app_private.superadmin_internal_auth_links') is null
    or to_regclass('app_private.superadmin_internal_memberships') is null then
    raise object_not_in_prerequisite_state using
      message = 'agenda internal realm compat prerequisites missing';
  end if;
  if exists (select 1 from information_schema.columns
    where table_schema='public' and table_name='agenda_events'
      and column_name='created_by_internal_identity_id') then
    raise object_not_in_prerequisite_state using
      message = 'agenda internal realm compat already present; forward-only package must not be replayed';
  end if;
end
$preflight$;

-- Producao nao tinha nenhuma concessao de agenda.* a papel algum (nem ao Owner):
-- leitura para owner/content/operations e mutacoes ao owner, como Avisos e
-- Circulares v2. Perfis e permissoes continuam mandando (Decisao 12).
insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow'::public.permission_effect, 'active'
from public.platform_roles role_record
join public.platform_permissions permission_record on permission_record.code = 'agenda.read'
where role_record.code in ('owner', 'content', 'operations')
on conflict (role_id, permission_id) do update set effect = 'allow', status = 'active', revoked_at = null;
insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow'::public.permission_effect, 'active'
from public.platform_roles role_record
join public.platform_permissions permission_record on permission_record.code in (
  'agenda.create', 'agenda.edit_own', 'agenda.edit_all', 'agenda.publish',
  'agenda.cancel_restore', 'agenda.manage_responses', 'agenda.override_reservation')
where role_record.code = 'owner'
on conflict (role_id, permission_id) do update set effect = 'allow', status = 'active', revoked_at = null;

alter table public.agenda_events
  alter column created_by_person_id drop not null,
  alter column updated_by_person_id drop not null,
  add column created_by_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id),
  add column updated_by_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id),
  add constraint agenda_events_created_actor_realm_ck check (
    (created_by_person_id is not null) <> (created_by_internal_identity_id is not null)),
  add constraint agenda_events_updated_actor_realm_ck check (
    (updated_by_person_id is not null) <> (updated_by_internal_identity_id is not null));
create index if not exists agenda_events_created_internal_fk_idx
  on public.agenda_events(created_by_internal_identity_id)
  where created_by_internal_identity_id is not null;
create index if not exists agenda_events_updated_internal_fk_idx
  on public.agenda_events(updated_by_internal_identity_id)
  where updated_by_internal_identity_id is not null;

alter table public.agenda_history_receipts
  alter column actor_person_id drop not null,
  add column actor_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id),
  add constraint agenda_history_receipts_actor_realm_ck check (
    (actor_person_id is not null) <> (actor_internal_identity_id is not null));
create index if not exists agenda_history_receipts_actor_internal_fk_idx
  on public.agenda_history_receipts(actor_internal_identity_id)
  where actor_internal_identity_id is not null;

alter table public.agenda_publication_requests
  alter column requested_by_person_id drop not null,
  add column requested_by_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id),
  add column decided_by_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id),
  add constraint agenda_publication_requests_requested_actor_realm_ck check (
    (requested_by_person_id is not null) <> (requested_by_internal_identity_id is not null)),
  add constraint agenda_publication_requests_decided_actor_realm_ck check (
    not (decided_by_person_id is not null and decided_by_internal_identity_id is not null));
create index if not exists agenda_publication_requests_requested_internal_fk_idx
  on public.agenda_publication_requests(requested_by_internal_identity_id)
  where requested_by_internal_identity_id is not null;
create index if not exists agenda_publication_requests_decided_internal_fk_idx
  on public.agenda_publication_requests(decided_by_internal_identity_id)
  where decided_by_internal_identity_id is not null;

-- Roteia o ator: cada argumento do trigger e a base de um par
-- <base>_person_id / <base>_internal_identity_id.
create or replace function app_private.agenda_route_internal_actor()
returns trigger language plpgsql security definer set search_path = '' as $$
declare row_json jsonb := to_jsonb(new); base text; actor uuid;
begin
  foreach base in array tg_argv loop
    actor := (row_json ->> (base || '_person_id'))::uuid;
    if actor is not null and exists (
      select 1 from app_private.superadmin_internal_identities identity_record
      where identity_record.id = actor
    ) then
      row_json := row_json || jsonb_build_object(
        base || '_person_id', null, base || '_internal_identity_id', actor);
    elsif actor is not null then
      row_json := row_json || jsonb_build_object(base || '_internal_identity_id', null);
    end if;
  end loop;
  new := jsonb_populate_record(new, row_json);
  return new;
end
$$;
revoke all on function app_private.agenda_route_internal_actor() from public, anon, authenticated, service_role;

drop trigger if exists agenda_events_route_internal_actor on public.agenda_events;
create trigger agenda_events_route_internal_actor
  before insert or update on public.agenda_events
  for each row execute function app_private.agenda_route_internal_actor('created_by', 'updated_by');
drop trigger if exists agenda_history_receipts_route_internal_actor on public.agenda_history_receipts;
create trigger agenda_history_receipts_route_internal_actor
  before insert or update on public.agenda_history_receipts
  for each row execute function app_private.agenda_route_internal_actor('actor');
drop trigger if exists agenda_publication_requests_route_internal_actor on public.agenda_publication_requests;
create trigger agenda_publication_requests_route_internal_actor
  before insert or update on public.agenda_publication_requests
  for each row execute function app_private.agenda_route_internal_actor('requested_by', 'decided_by');

create or replace function app_private.agenda_actor_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select coalesce(
    app_private.current_person_id(),
    (select auth_link.internal_identity_id
     from app_private.superadmin_internal_auth_links auth_link
     where auth_link.auth_user_id = (select auth.uid())
       and auth_link.status = 'active'
     order by auth_link.created_at desc limit 1))
$$;
revoke all on function app_private.agenda_actor_id() from public, anon, authenticated, service_role;

create or replace function app_private.agenda_has_permission(p_permission_code text)
returns boolean language sql stable security definer set search_path = '' as $$
  select app_private.has_platform_permission(p_permission_code)
  or (
    exists (
      select 1
      from app_private.superadmin_internal_auth_links auth_link
      join app_private.superadmin_internal_memberships membership
        on membership.internal_identity_id = auth_link.internal_identity_id
       and membership.status = 'active'
       and membership.scope_kind::text = 'platform'
      join public.platform_roles role_record
        on role_record.id = membership.platform_role_id and role_record.status = 'active'
      join public.platform_role_permissions grant_record
        on grant_record.role_id = role_record.id
       and grant_record.status = 'active' and grant_record.revoked_at is null
       and grant_record.effect = 'allow'
      join public.platform_permissions permission_record
        on permission_record.id = grant_record.permission_id
       and permission_record.code = p_permission_code and permission_record.status = 'active'
      where auth_link.auth_user_id = (select auth.uid()) and auth_link.status = 'active'
    )
    and not exists (
      select 1
      from app_private.superadmin_internal_auth_links auth_link
      join app_private.superadmin_internal_memberships membership
        on membership.internal_identity_id = auth_link.internal_identity_id
       and membership.status = 'active'
      join public.platform_role_permissions grant_record
        on grant_record.role_id = membership.platform_role_id
       and grant_record.status = 'active' and grant_record.revoked_at is null
       and grant_record.effect = 'deny'
      join public.platform_permissions permission_record
        on permission_record.id = grant_record.permission_id
       and permission_record.code = p_permission_code
      where auth_link.auth_user_id = (select auth.uid()) and auth_link.status = 'active'
    )
  )
$$;
revoke all on function app_private.agenda_has_permission(text) from public, anon, authenticated, service_role;

create or replace function app_private.assert_agenda_permission(p_permission text, p_require_aal2 boolean default false)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_actor uuid;
begin
  if (select auth.uid()) is null then raise exception using errcode='28000',message='authentication_required'; end if;
  v_actor := app_private.agenda_actor_id();
  if v_actor is null then raise exception using errcode='42501',message='internal_actor_required'; end if;
  if not app_private.agenda_has_permission(p_permission) then raise exception using errcode='42501',message='agenda_permission_denied'; end if;
  if p_require_aal2 and not app_private.has_mfa_aal2() then raise exception using errcode='42501',message='mfa_aal2_required'; end if;
  return v_actor;
end; $$;

-- superadmin_agenda_list: texto de producao; 0 chamada(s) de has_platform_permission -> agenda_has_permission
CREATE OR REPLACE FUNCTION "public"."superadmin_agenda_list"("p_from" timestamp with time zone, "p_to" timestamp with time zone, "p_institution_id" "uuid" DEFAULT NULL::"uuid", "p_search" "text" DEFAULT ''::"text", "p_limit" integer DEFAULT 100, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare v_result jsonb;
begin
  perform app_private.assert_agenda_permission('agenda.read',false);
  if p_from is null or p_to is null or p_to<=p_from or p_to-p_from>interval '400 days' or p_limit<1 or p_limit>200 or p_offset<0 then raise exception using errcode='22023',message='invalid_agenda_query'; end if;
  with filtered as (
    select e.* from public.agenda_events e where e.starts_at<p_to and e.ends_at>p_from
      and (p_institution_id is null or e.institution_id=p_institution_id)
      and (coalesce(trim(p_search),'')='' or e.title ilike '%'||trim(p_search)||'%' or e.description ilike '%'||trim(p_search)||'%')
  ), page_rows as (select * from filtered order by starts_at,id limit p_limit offset p_offset)
  select jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(p)-'created_by_person_id'-'updated_by_person_id'-'created_by_internal_identity_id'-'updated_by_internal_identity_id' order by p.starts_at,p.id),'[]'::jsonb),'total_items',(select count(*) from filtered)) into v_result from page_rows p;
  return v_result;
end; $$;

-- superadmin_agenda_get: texto de producao; 0 chamada(s) de has_platform_permission -> agenda_has_permission
CREATE OR REPLACE FUNCTION "public"."superadmin_agenda_get"("p_event_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare v_result jsonb;
begin
  perform app_private.assert_agenda_permission('agenda.read',false);
  select (to_jsonb(e)-'created_by_person_id'-'updated_by_person_id'-'created_by_internal_identity_id'-'updated_by_internal_identity_id')||jsonb_build_object(
    'history',coalesce((select jsonb_agg(jsonb_build_object('action',h.action,'reason',h.reason,'occurred_at',h.occurred_at,'previous_revision',h.previous_revision,'next_revision',h.next_revision) order by h.occurred_at,h.id) from public.agenda_history_receipts h where h.event_id=e.id),'[]'::jsonb),
    'responses',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'response_value',r.response_value,'responded_at',r.responded_at,'revision',r.revision) order by r.responded_at,r.id) from public.agenda_responses r where r.event_id=e.id),'[]'::jsonb)
  ) into v_result from public.agenda_events e where e.id=p_event_id;
  if v_result is null then raise exception using errcode='P0002',message='agenda_event_not_found'; end if;
  return v_result;
end; $$;

-- superadmin_agenda_contexts: texto de producao; 7 chamada(s) de has_platform_permission -> agenda_has_permission
CREATE OR REPLACE FUNCTION "public"."superadmin_agenda_contexts"() RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_actor uuid;
  v_capabilities jsonb;
  v_granted_capabilities jsonb;
  v_restricted_capabilities jsonb;
  v_contexts jsonb;
begin
  v_actor := app_private.assert_agenda_permission('agenda.read', false);

  v_capabilities := pg_catalog.jsonb_build_object(
    'createAgendaItems', app_private.agenda_has_permission('agenda.create'),
    'editOwnAgendaItems', app_private.agenda_has_permission('agenda.edit_own'),
    'editAllAgendaItems', app_private.agenda_has_permission('agenda.edit_all'),
    'publishAgendaItems', app_private.agenda_has_permission('agenda.publish'),
    'cancelOrRestoreAgendaItems', app_private.agenda_has_permission('agenda.cancel_restore'),
    'manageResponsesAndAuthorizations', app_private.agenda_has_permission('agenda.manage_responses'),
    'overrideReservationConflict', app_private.agenda_has_permission('agenda.override_reservation')
  );

  select
    coalesce(
      pg_catalog.jsonb_agg(capability.name order by capability.position)
        filter (where capability.allowed),
      '[]'::jsonb
    ),
    coalesce(
      pg_catalog.jsonb_agg(capability.name order by capability.position)
        filter (where not capability.allowed),
      '[]'::jsonb
    )
  into v_granted_capabilities, v_restricted_capabilities
  from (
    values
      (1, 'createAgendaItems', (v_capabilities ->> 'createAgendaItems')::boolean),
      (2, 'editOwnAgendaItems', (v_capabilities ->> 'editOwnAgendaItems')::boolean),
      (3, 'editAllAgendaItems', (v_capabilities ->> 'editAllAgendaItems')::boolean),
      (4, 'publishAgendaItems', (v_capabilities ->> 'publishAgendaItems')::boolean),
      (5, 'cancelOrRestoreAgendaItems', (v_capabilities ->> 'cancelOrRestoreAgendaItems')::boolean),
      (6, 'manageResponsesAndAuthorizations', (v_capabilities ->> 'manageResponsesAndAuthorizations')::boolean),
      (7, 'overrideReservationConflict', (v_capabilities ->> 'overrideReservationConflict')::boolean)
  ) as capability(position, name, allowed);

  with authorized_institutions as (
    select institution.id, institution.public_name
    from public.institutions institution
    where institution.status = 'active'
      and institution.deleted_at is null
      and (exists (
        select 1
        from app_private.superadmin_internal_memberships internal_membership
        join public.platform_roles internal_role
          on internal_role.id = internal_membership.platform_role_id
         and internal_role.status = 'active'
        where internal_membership.internal_identity_id = v_actor
          and internal_membership.status = 'active'
          and (
            internal_membership.scope_kind::text = 'platform'
            or (internal_membership.scope_kind::text = 'institution'
              and internal_membership.scope_institution_id = institution.id)
          )
      ) or exists (
        select 1
        from public.platform_memberships membership
        join public.platform_roles role_record
          on role_record.id = membership.role_id
         and role_record.status = 'active'
        where membership.person_id = v_actor
          and membership.status = 'active'
          and membership.revoked_at is null
          and (
            (membership.scope_kind = 'platform' and membership.scope_institution_id is null)
            or
            (membership.scope_kind = 'institution' and membership.scope_institution_id = institution.id)
          )
      ))
  ), context_rows as (
    select
      institution.id,
      institution.public_name as name,
      institution.id as institution_id,
      null::uuid as parent_id,
      'institution'::text as level,
      1 as level_order
    from authorized_institutions institution

    union all

    select
      unit_record.id,
      unit_record.name,
      unit_record.institution_id,
      unit_record.institution_id as parent_id,
      'unit'::text as level,
      2 as level_order
    from public.units unit_record
    join authorized_institutions institution
      on institution.id = unit_record.institution_id
    where unit_record.status = 'active'

    union all

    select
      group_record.id,
      group_record.name,
      unit_record.institution_id,
      unit_record.id as parent_id,
      'group'::text as level,
      3 as level_order
    from public.groups group_record
    join public.units unit_record
      on unit_record.id = group_record.unit_id
     and unit_record.institution_id = group_record.institution_id
     and unit_record.status = 'active'
    join authorized_institutions institution
      on institution.id = unit_record.institution_id
    where group_record.status = 'active'

    union all

    select
      activity.id,
      activity.name,
      activity.institution_id,
      coalesce(activity.origin_unit_id, activity.institution_id) as parent_id,
      'activity'::text as level,
      4 as level_order
    from public.activity_definitions activity
    join authorized_institutions institution
      on institution.id = activity.institution_id
    left join public.units origin_unit
      on origin_unit.id = activity.origin_unit_id
     and origin_unit.institution_id = activity.institution_id
     and origin_unit.status = 'active'
    where activity.status = 'active'
      and (activity.origin_unit_id is null or origin_unit.id is not null)
  )
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'id', context_record.id,
        'name', context_record.name,
        'institution_id', context_record.institution_id,
        'parent_id', context_record.parent_id,
        'level', context_record.level,
        'granted_capabilities', v_granted_capabilities,
        'restricted_capabilities', v_restricted_capabilities
      )
      order by context_record.institution_id, context_record.level_order,
        pg_catalog.lower(context_record.name), context_record.id
    ),
    '[]'::jsonb
  )
  into v_contexts
  from context_rows context_record;

  return pg_catalog.jsonb_build_object(
    'contexts', v_contexts,
    'capabilities', v_capabilities
  );
end;
$$;

-- superadmin_agenda_save: texto de producao; 4 chamada(s) de has_platform_permission -> agenda_has_permission
CREATE OR REPLACE FUNCTION "public"."superadmin_agenda_save"("p_request_id" "uuid", "p_event_id" "uuid", "p_expected_revision" bigint, "p_payload" "jsonb", "p_reason" "text" DEFAULT NULL::"text", "p_override_reservation" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare v_actor uuid; v_existing public.agenda_events%rowtype; v_event public.agenda_events%rowtype; v_action text; v_status text; v_conflict boolean;
begin
  if p_request_id is null then raise exception using errcode='22023',message='request_id_required'; end if;
  select e.* into v_existing from public.agenda_events e join public.agenda_history_receipts h on h.event_id=e.id where h.request_id=p_request_id;
  if found then return public.superadmin_agenda_get(v_existing.id); end if;
  v_actor:=app_private.assert_agenda_permission(case when p_event_id is null then 'agenda.create' else 'agenda.read' end,false);
  if coalesce(char_length(trim(p_payload->>'title')),0) not between 1 and 240 or (p_payload->>'startsAt')::timestamptz >= (p_payload->>'endsAt')::timestamptz then raise exception using errcode='22023',message='invalid_agenda_event'; end if;
  perform app_private.assert_agenda_context((p_payload->>'institutionId')::uuid,p_payload->>'contextKind',(p_payload->>'contextId')::uuid,coalesce(p_payload->'audience','{}'::jsonb));
  perform app_private.assert_agenda_questions(coalesce(p_payload->'questions','[]'::jsonb));
  v_status:=coalesce(p_payload->>'status','draft');
  if v_status not in ('draft','scheduled','published') then raise exception using errcode='22023',message='invalid_status'; end if;
  if v_status='published' and not app_private.agenda_has_permission('agenda.publish') then raise exception using errcode='42501',message='publish_permission_denied'; end if;
  select exists(select 1 from public.agenda_events e where e.id<>coalesce(p_event_id,gen_random_uuid()) and e.institution_id=(p_payload->>'institutionId')::uuid and e.item_type='resourceReservation' and e.status<>'canceled' and lower(trim(e.location))=lower(trim(p_payload->>'location')) and e.starts_at<(p_payload->>'endsAt')::timestamptz and e.ends_at>(p_payload->>'startsAt')::timestamptz) into v_conflict;
  if v_conflict and not p_override_reservation then raise exception using errcode='23P01',message='reservation_conflict'; end if;
  if v_conflict and (not app_private.agenda_has_permission('agenda.override_reservation') or not app_private.has_mfa_aal2() or coalesce(char_length(trim(p_reason)),0)<1) then raise exception using errcode='42501',message='reservation_override_denied'; end if;
  if p_event_id is null then
    insert into public.agenda_events(institution_id,context_kind,context_id,title,item_type,priority,status,origin,starts_at,ends_at,all_day,time_zone_id,location,description,response_mode,guardian_response_policy,recurrence,audience,reminders,questions,created_by_person_id,updated_by_person_id)
    values((p_payload->>'institutionId')::uuid,p_payload->>'contextKind',(p_payload->>'contextId')::uuid,trim(p_payload->>'title'),p_payload->>'type',coalesce(p_payload->>'priority','normal'),v_status,coalesce(p_payload->>'origin','institution'),(p_payload->>'startsAt')::timestamptz,(p_payload->>'endsAt')::timestamptz,coalesce((p_payload->>'allDay')::boolean,false),coalesce(p_payload->>'timeZoneId','America/Sao_Paulo'),coalesce(p_payload->>'location',''),coalesce(p_payload->>'description',''),coalesce(p_payload->>'responseMode','none'),coalesce(p_payload->>'guardianResponsePolicy','oneIsEnough'),p_payload->'recurrence',coalesce(p_payload->'audience','{}'::jsonb),coalesce(p_payload->'reminders','[]'::jsonb),coalesce(p_payload->'questions','[]'::jsonb),v_actor,v_actor) returning * into v_event;
    v_action:=case when v_conflict then 'override_reservation' else 'create' end;
  else
    select * into v_existing from public.agenda_events where id=p_event_id for update;
    if not found then raise exception using errcode='P0002',message='agenda_event_not_found'; end if;
    if not app_private.agenda_has_permission('agenda.edit_all') and not (v_existing.created_by_person_id=v_actor and app_private.agenda_has_permission('agenda.edit_own')) then raise exception using errcode='42501',message='edit_permission_denied'; end if;
    if p_expected_revision is null or p_expected_revision<>v_existing.revision then raise exception using errcode='40001',message='agenda_revision_conflict'; end if;
    update public.agenda_events set institution_id=(p_payload->>'institutionId')::uuid,context_kind=p_payload->>'contextKind',context_id=(p_payload->>'contextId')::uuid,title=trim(p_payload->>'title'),item_type=p_payload->>'type',priority=coalesce(p_payload->>'priority','normal'),status=v_status,starts_at=(p_payload->>'startsAt')::timestamptz,ends_at=(p_payload->>'endsAt')::timestamptz,all_day=coalesce((p_payload->>'allDay')::boolean,false),time_zone_id=coalesce(p_payload->>'timeZoneId','America/Sao_Paulo'),location=coalesce(p_payload->>'location',''),description=coalesce(p_payload->>'description',''),response_mode=coalesce(p_payload->>'responseMode','none'),guardian_response_policy=coalesce(p_payload->>'guardianResponsePolicy','oneIsEnough'),recurrence=p_payload->'recurrence',audience=coalesce(p_payload->'audience','{}'::jsonb),reminders=coalesce(p_payload->'reminders','[]'::jsonb),questions=coalesce(p_payload->'questions','[]'::jsonb),updated_by_person_id=v_actor,revision=revision+1,updated_at=now() where id=p_event_id returning * into v_event;
    v_action:=case when v_conflict then 'override_reservation' else 'update' end;
  end if;
  insert into public.agenda_history_receipts(request_id,event_id,institution_id,actor_person_id,action,previous_revision,next_revision,reason) values(p_request_id,v_event.id,v_event.institution_id,v_actor,v_action,v_existing.revision,v_event.revision,nullif(trim(p_reason),''));
  return public.superadmin_agenda_get(v_event.id);
end; $$;

-- superadmin_agenda_command: texto de producao; 0 chamada(s) de has_platform_permission -> agenda_has_permission
CREATE OR REPLACE FUNCTION "public"."superadmin_agenda_command"("p_request_id" "uuid", "p_event_id" "uuid", "p_expected_revision" bigint, "p_action" "text", "p_reason" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare v_actor uuid; v_event public.agenda_events%rowtype; v_next text; v_request uuid;
begin
  if p_action not in ('cancel','restore','delete_draft','request_publication') then raise exception using errcode='22023',message='invalid_agenda_action'; end if;
  if exists(select 1 from public.agenda_history_receipts where request_id=p_request_id and action='delete_draft') then
    return jsonb_build_object('deleted',true,'id',p_event_id);
  end if;
  if exists(select 1 from public.agenda_history_receipts where request_id=p_request_id) then
    return public.superadmin_agenda_get(p_event_id);
  end if;
  v_actor:=app_private.assert_agenda_permission(case when p_action='request_publication' then 'agenda.edit_own' else 'agenda.cancel_restore' end,false);
  select * into v_event from public.agenda_events where id=p_event_id for update;
  if not found then raise exception using errcode='P0002',message='agenda_event_not_found'; end if;
  if p_expected_revision<>v_event.revision then raise exception using errcode='40001',message='agenda_revision_conflict'; end if;
  if p_action='delete_draft' then
    if v_event.status<>'draft' then raise exception using errcode='22023',message='only_draft_can_be_deleted'; end if;
    insert into public.agenda_history_receipts(request_id,event_id,institution_id,actor_person_id,action,previous_revision,next_revision,reason) values(p_request_id,null,v_event.institution_id,v_actor,'delete_draft',v_event.revision,null,nullif(trim(p_reason),''));
    delete from public.agenda_events where id=v_event.id; return jsonb_build_object('deleted',true,'id',p_event_id);
  elsif p_action='request_publication' then
    if v_event.status<>'draft' then raise exception using errcode='22023',message='only_draft_can_request_publication'; end if;
    insert into public.agenda_publication_requests(event_id,institution_id,requested_by_person_id) values(v_event.id,v_event.institution_id,v_actor) returning id into v_request;
    insert into public.agenda_history_receipts(request_id,event_id,institution_id,actor_person_id,action,previous_revision,next_revision,reason) values(p_request_id,v_event.id,v_event.institution_id,v_actor,'request_publication',v_event.revision,v_event.revision,null);
    return jsonb_build_object('request_id',v_request,'event',public.superadmin_agenda_get(v_event.id));
  else
    if p_action='cancel' and v_event.status not in ('scheduled','published') then raise exception using errcode='22023',message='invalid_cancel_transition'; end if;
    if p_action='restore' and v_event.status<>'canceled' then raise exception using errcode='22023',message='invalid_restore_transition'; end if;
    v_next:=case when p_action='cancel' then 'canceled' else 'published' end;
    update public.agenda_events set status=v_next,revision=revision+1,updated_by_person_id=v_actor,updated_at=now() where id=v_event.id returning * into v_event;
    insert into public.agenda_history_receipts(request_id,event_id,institution_id,actor_person_id,action,previous_revision,next_revision,reason) values(p_request_id,v_event.id,v_event.institution_id,v_actor,p_action,v_event.revision-1,v_event.revision,nullif(trim(p_reason),''));
    return public.superadmin_agenda_get(v_event.id);
  end if;
end; $$;

-- superadmin_agenda_requests: texto de producao; 0 chamada(s) de has_platform_permission -> agenda_has_permission
CREATE OR REPLACE FUNCTION "public"."superadmin_agenda_requests"("p_kind" "text" DEFAULT 'publication'::"text", "p_status" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare v_result jsonb;
begin
  perform app_private.assert_agenda_permission('agenda.manage_responses',false);
  if p_kind='publication' then select coalesce(jsonb_agg(to_jsonb(r) order by r.requested_at desc,r.id),'[]'::jsonb) into v_result from (select * from public.agenda_publication_requests where p_status is null or status=p_status limit p_limit offset p_offset) r;
  elsif p_kind='guardian' then select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id),'[]'::jsonb) into v_result from (select * from public.agenda_guardian_requests where p_status is null or status=p_status limit p_limit offset p_offset) r;
  else raise exception using errcode='22023',message='invalid_request_kind'; end if;
  return v_result;
end; $$;

-- superadmin_agenda_decide_publication: texto de producao; 0 chamada(s) de has_platform_permission -> agenda_has_permission
CREATE OR REPLACE FUNCTION "public"."superadmin_agenda_decide_publication"("p_request_id" "uuid", "p_publication_request_id" "uuid", "p_approve" boolean, "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare v_actor uuid; v_request public.agenda_publication_requests%rowtype; v_event public.agenda_events%rowtype; v_action text;
begin
  v_actor:=app_private.assert_agenda_permission('agenda.publish',false);
  if coalesce(char_length(trim(p_reason)),0) not between 1 and 1000 then raise exception using errcode='22023',message='reason_required'; end if;
  if exists(select 1 from public.agenda_history_receipts where request_id=p_request_id) then select * into v_request from public.agenda_publication_requests where id=p_publication_request_id; return to_jsonb(v_request); end if;
  select * into v_request from public.agenda_publication_requests where id=p_publication_request_id for update;
  if not found or v_request.status<>'pending' then raise exception using errcode='22023',message='publication_request_not_pending'; end if;
  update public.agenda_publication_requests set status=case when p_approve then 'approved' else 'rejected' end,decided_by_person_id=v_actor,decided_at=now(),reason=trim(p_reason) where id=v_request.id returning * into v_request;
  select * into v_event from public.agenda_events where id=v_request.event_id for update;
  if p_approve then update public.agenda_events set status='published',revision=revision+1,updated_by_person_id=v_actor,updated_at=now() where id=v_event.id returning * into v_event; end if;
  v_action:=case when p_approve then 'approve_publication' else 'reject_publication' end;
  insert into public.agenda_history_receipts(request_id,event_id,institution_id,actor_person_id,action,previous_revision,next_revision,reason) values(p_request_id,v_event.id,v_event.institution_id,v_actor,v_action,v_event.revision-case when p_approve then 1 else 0 end,v_event.revision,trim(p_reason));
  return to_jsonb(v_request);
end; $$;

-- Deny-by-default medido na baseline: as cinco tabelas tinham SELECT/INSERT
-- concedidos a anon/authenticated (RLS forcado sem policy) e as sete RPCs tinham
-- EXECUTE para PUBLIC (anon/service_role). Fecha os grants; somente authenticated
-- executa os wrappers.
revoke all on table public.agenda_events, public.agenda_guardian_requests,
  public.agenda_history_receipts, public.agenda_publication_requests, public.agenda_responses
from public, anon, authenticated, service_role;
do $acl$
declare function_record regprocedure;
begin
  for function_record in
    select procedure_record.oid::regprocedure
    from pg_proc procedure_record
    join pg_namespace namespace_record on namespace_record.oid = procedure_record.pronamespace
    where namespace_record.nspname = 'public' and procedure_record.proname like 'superadmin_agenda_%'
  loop
    execute format('revoke all on function %s from public, anon, service_role', function_record);
    execute format('grant execute on function %s to authenticated', function_record);
  end loop;
end
$acl$;

commit;
