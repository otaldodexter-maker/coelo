-- Product contract: specs/050-superadmin-agenda-backend.md

insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status,
  module_label,screen_label,action_label
)
values
  ('agenda.read','agenda','agenda','read','Consultar Agenda institucional.','normal',false,'active','Agenda','Agenda','Ver'),
  ('agenda.create','agenda','agenda','create','Criar eventos na Agenda.','normal',false,'active','Agenda','Agenda','Criar'),
  ('agenda.edit_own','agenda','agenda','edit_own','Editar eventos próprios.','normal',false,'active','Agenda','Agenda','Editar próprios'),
  ('agenda.edit_all','agenda','agenda','edit_all','Editar qualquer evento autorizado.','high',false,'active','Agenda','Agenda','Editar todos'),
  ('agenda.publish','agenda','agenda','publish','Publicar ou decidir publicação.','high',false,'active','Agenda','Agenda','Publicar'),
  ('agenda.cancel_restore','agenda','agenda','cancel_restore','Cancelar ou restaurar eventos.','high',false,'active','Agenda','Agenda','Cancelar ou restaurar'),
  ('agenda.manage_responses','agenda','agenda','manage_responses','Gerenciar respostas e solicitações.','high',false,'active','Agenda','Agenda','Gerenciar respostas'),
  ('agenda.override_reservation','agenda','agenda','override_reservation','Sobrescrever conflito de reserva com justificativa.','critical',true,'active','Agenda','Agenda','Sobrescrever conflito')
on conflict (code) do update set
  description=excluded.description,risk_level=excluded.risk_level,
  requires_mfa=excluded.requires_mfa,status='active',updated_at=now(),
  module_label=excluded.module_label,screen_label=excluded.screen_label,
  action_label=excluded.action_label;

create table if not exists public.agenda_events (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete restrict,
  context_kind text not null check (context_kind in ('institution','unit','group','activity')),
  context_id uuid not null,
  title text not null check (char_length(title) between 1 and 240),
  item_type text not null check (item_type in ('event','recurringRoutine','birthday','holidayOrBreak','appointment','deadline','operationalChange','resourceReservation','other')),
  priority text not null default 'normal' check (priority in ('normal','important','urgent')),
  status text not null default 'draft' check (status in ('draft','scheduled','published','canceled')),
  origin text not null default 'institution' check (origin in ('institution','guardianRequest')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  all_day boolean not null default false,
  time_zone_id text not null default 'America/Sao_Paulo' check (char_length(time_zone_id) between 1 and 100),
  location text not null default '' check (char_length(location) <= 500),
  description text not null default '' check (char_length(description) <= 10000),
  response_mode text not null default 'none' check (response_mode in ('none','rsvp','acknowledgement','authorization')),
  guardian_response_policy text not null default 'oneIsEnough' check (guardian_response_policy in ('oneIsEnough','allMustRespond')),
  recurrence jsonb,
  audience jsonb not null default '{}'::jsonb,
  reminders jsonb not null default '[]'::jsonb,
  questions jsonb not null default '[]'::jsonb,
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  updated_by_person_id uuid not null references public.people(id) on delete restrict,
  revision bigint not null default 1 check (revision > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  check (jsonb_typeof(audience)='object'),
  check (jsonb_typeof(reminders)='array'),
  check (jsonb_typeof(questions)='array'),
  check (recurrence is null or jsonb_typeof(recurrence)='object')
);

create table if not exists public.agenda_publication_requests (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.agenda_events(id) on delete restrict,
  institution_id uuid not null references public.institutions(id) on delete restrict,
  requested_by_person_id uuid not null references public.people(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  requested_at timestamptz not null default now(),
  decided_by_person_id uuid references public.people(id) on delete restrict,
  decided_at timestamptz,
  reason text check (reason is null or char_length(reason) between 1 and 1000)
);
create unique index if not exists agenda_publication_requests_one_pending_idx
  on public.agenda_publication_requests(event_id) where status='pending';

create table if not exists public.agenda_guardian_requests (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete restrict,
  child_person_id uuid not null references public.people(id) on delete restrict,
  guardian_person_id uuid not null references public.people(id) on delete restrict,
  context_kind text not null check (context_kind in ('institution','unit','group','activity')),
  context_id uuid not null,
  title text not null check (char_length(title) between 1 and 240),
  details text not null default '' check (char_length(details) <= 4000),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'sent' check (status in ('sent','underReview','approved','rejected','convertedToDraft')),
  decision_reason text check (decision_reason is null or char_length(decision_reason) between 1 and 1000),
  decided_by_person_id uuid references public.people(id) on delete restrict,
  decided_at timestamptz,
  linked_event_id uuid references public.agenda_events(id) on delete restrict,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table if not exists public.agenda_responses (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.agenda_events(id) on delete restrict,
  institution_id uuid not null references public.institutions(id) on delete restrict,
  responder_person_id uuid not null references public.people(id) on delete restrict,
  child_person_id uuid references public.people(id) on delete restrict,
  response_value text not null check (response_value in ('yes','no','maybe','acknowledged','authorized','not_authorized')),
  answers jsonb not null default '{}'::jsonb check (jsonb_typeof(answers)='object'),
  responded_at timestamptz not null default now(),
  revision bigint not null default 1 check (revision > 0),
  unique(event_id,responder_person_id,child_person_id)
);

create table if not exists public.agenda_history_receipts (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique,
  event_id uuid references public.agenda_events(id) on delete set null,
  institution_id uuid not null references public.institutions(id) on delete restrict,
  actor_person_id uuid not null references public.people(id) on delete restrict,
  action text not null check (action in ('create','update','cancel','restore','delete_draft','request_publication','approve_publication','reject_publication','approve_guardian_request','reject_guardian_request','override_reservation')),
  previous_revision bigint,
  next_revision bigint,
  reason text check (reason is null or char_length(reason) between 1 and 1000),
  occurred_at timestamptz not null default now()
);

do $$ declare v_table text; begin
  foreach v_table in array array['agenda_events','agenda_publication_requests','agenda_guardian_requests','agenda_responses','agenda_history_receipts'] loop
    execute format('alter table public.%I enable row level security',v_table);
    execute format('alter table public.%I force row level security',v_table);
    execute format('revoke all on table public.%I from public, anon, authenticated',v_table);
  end loop;
end $$;

create index if not exists agenda_events_institution_period_idx on public.agenda_events(institution_id,starts_at,ends_at,id);
create index if not exists agenda_events_context_period_idx on public.agenda_events(institution_id,context_kind,context_id,starts_at,id);
create index if not exists agenda_events_created_by_idx on public.agenda_events(created_by_person_id);
create index if not exists agenda_publication_requests_institution_status_idx on public.agenda_publication_requests(institution_id,status,requested_at desc,id);
create index if not exists agenda_guardian_requests_institution_status_idx on public.agenda_guardian_requests(institution_id,status,created_at desc,id);
create index if not exists agenda_guardian_requests_child_idx on public.agenda_guardian_requests(child_person_id);
create index if not exists agenda_guardian_requests_guardian_idx on public.agenda_guardian_requests(guardian_person_id);
create index if not exists agenda_responses_event_idx on public.agenda_responses(event_id,responded_at desc,id);
create index if not exists agenda_responses_responder_idx on public.agenda_responses(responder_person_id);
create index if not exists agenda_responses_child_idx on public.agenda_responses(child_person_id) where child_person_id is not null;
create index if not exists agenda_history_event_idx on public.agenda_history_receipts(event_id,occurred_at desc,id);
create index if not exists agenda_history_actor_idx on public.agenda_history_receipts(actor_person_id);

create or replace function app_private.assert_agenda_permission(p_permission text,p_require_aal2 boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_actor uuid;
begin
  if (select auth.uid()) is null then raise exception using errcode='28000',message='authentication_required'; end if;
  v_actor:=app_private.current_person_id();
  if v_actor is null then raise exception using errcode='42501',message='internal_actor_required'; end if;
  if not app_private.has_platform_permission(p_permission) then raise exception using errcode='42501',message='agenda_permission_denied'; end if;
  if p_require_aal2 and not app_private.has_mfa_aal2() then raise exception using errcode='42501',message='mfa_aal2_required'; end if;
  return v_actor;
end; $$;
revoke execute on function app_private.assert_agenda_permission(text,boolean) from public,anon,authenticated;

create or replace function app_private.assert_agenda_context(p_institution_id uuid,p_kind text,p_context_id uuid,p_audience jsonb)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_kind='institution' and p_context_id<>p_institution_id then raise exception using errcode='22023',message='invalid_institution_context'; end if;
  if p_kind='unit' and not exists(select 1 from public.units u where u.id=p_context_id and u.institution_id=p_institution_id) then raise exception using errcode='22023',message='invalid_unit_context'; end if;
  if p_kind='group' and not exists(select 1 from public.groups g join public.units u on u.id=g.unit_id where g.id=p_context_id and u.institution_id=p_institution_id) then raise exception using errcode='22023',message='invalid_group_context'; end if;
  if p_kind='activity' and not exists(select 1 from public.activity_definitions a where a.id=p_context_id and a.institution_id=p_institution_id) then raise exception using errcode='22023',message='invalid_activity_context'; end if;
  if exists(select 1 from jsonb_array_elements_text(coalesce(p_audience->'unitIds','[]'::jsonb)) x where not exists(select 1 from public.units u where u.id=x.value::uuid and u.institution_id=p_institution_id)) then raise exception using errcode='22023',message='cross_tenant_unit_audience'; end if;
  if exists(select 1 from jsonb_array_elements_text(coalesce(p_audience->'groupIds','[]'::jsonb)) x where not exists(select 1 from public.groups g join public.units u on u.id=g.unit_id where g.id=x.value::uuid and u.institution_id=p_institution_id)) then raise exception using errcode='22023',message='cross_tenant_group_audience'; end if;
  if exists(select 1 from jsonb_array_elements_text(coalesce(p_audience->'activityIds','[]'::jsonb)) x where not exists(select 1 from public.activity_definitions a where a.id=x.value::uuid and a.institution_id=p_institution_id)) then raise exception using errcode='22023',message='cross_tenant_activity_audience'; end if;
end; $$;
revoke execute on function app_private.assert_agenda_context(uuid,text,uuid,jsonb) from public,anon,authenticated;

create or replace function app_private.assert_agenda_questions(p_questions jsonb)
returns void language plpgsql immutable set search_path='' as $$
declare v_question jsonb;
begin
  if jsonb_typeof(p_questions)<>'array' or jsonb_array_length(p_questions)>30 then raise exception using errcode='22023',message='invalid_questions'; end if;
  for v_question in select value from jsonb_array_elements(p_questions) loop
    if v_question->>'type' not in ('shortText','yesNo') or coalesce(char_length(trim(v_question->>'title')),0) not between 1 and 240 then raise exception using errcode='22023',message='invalid_question'; end if;
    if lower(v_question->>'title') ~ '(cpf|rg|diagn[oó]stico|medica[cç][aã]o|senha|biometria|cart[aã]o|conta banc[aá]ria)' then raise exception using errcode='22023',message='sensitive_question_not_allowed'; end if;
  end loop;
end; $$;
revoke execute on function app_private.assert_agenda_questions(jsonb) from public,anon,authenticated;

create or replace function public.superadmin_agenda_list(p_from timestamptz,p_to timestamptz,p_institution_id uuid default null,p_search text default '',p_limit integer default 100,p_offset integer default 0)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_result jsonb;
begin
  perform app_private.assert_agenda_permission('agenda.read',false);
  if p_from is null or p_to is null or p_to<=p_from or p_to-p_from>interval '400 days' or p_limit<1 or p_limit>200 or p_offset<0 then raise exception using errcode='22023',message='invalid_agenda_query'; end if;
  with filtered as (
    select e.* from public.agenda_events e where e.starts_at<p_to and e.ends_at>p_from
      and (p_institution_id is null or e.institution_id=p_institution_id)
      and (coalesce(trim(p_search),'')='' or e.title ilike '%'||trim(p_search)||'%' or e.description ilike '%'||trim(p_search)||'%')
  ), page_rows as (select * from filtered order by starts_at,id limit p_limit offset p_offset)
  select jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(p)-'created_by_person_id'-'updated_by_person_id' order by p.starts_at,p.id),'[]'::jsonb),'total_items',(select count(*) from filtered)) into v_result from page_rows p;
  return v_result;
end; $$;

create or replace function public.superadmin_agenda_get(p_event_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_result jsonb;
begin
  perform app_private.assert_agenda_permission('agenda.read',false);
  select (to_jsonb(e)-'created_by_person_id'-'updated_by_person_id')||jsonb_build_object(
    'history',coalesce((select jsonb_agg(jsonb_build_object('action',h.action,'reason',h.reason,'occurred_at',h.occurred_at,'previous_revision',h.previous_revision,'next_revision',h.next_revision) order by h.occurred_at,h.id) from public.agenda_history_receipts h where h.event_id=e.id),'[]'::jsonb),
    'responses',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'response_value',r.response_value,'responded_at',r.responded_at,'revision',r.revision) order by r.responded_at,r.id) from public.agenda_responses r where r.event_id=e.id),'[]'::jsonb)
  ) into v_result from public.agenda_events e where e.id=p_event_id;
  if v_result is null then raise exception using errcode='P0002',message='agenda_event_not_found'; end if;
  return v_result;
end; $$;

create or replace function public.superadmin_agenda_save(p_request_id uuid,p_event_id uuid,p_expected_revision bigint,p_payload jsonb,p_reason text default null,p_override_reservation boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
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
  if v_status='published' and not app_private.has_platform_permission('agenda.publish') then raise exception using errcode='42501',message='publish_permission_denied'; end if;
  select exists(select 1 from public.agenda_events e where e.id<>coalesce(p_event_id,gen_random_uuid()) and e.institution_id=(p_payload->>'institutionId')::uuid and e.item_type='resourceReservation' and e.status<>'canceled' and lower(trim(e.location))=lower(trim(p_payload->>'location')) and e.starts_at<(p_payload->>'endsAt')::timestamptz and e.ends_at>(p_payload->>'startsAt')::timestamptz) into v_conflict;
  if v_conflict and not p_override_reservation then raise exception using errcode='23P01',message='reservation_conflict'; end if;
  if v_conflict and (not app_private.has_platform_permission('agenda.override_reservation') or not app_private.has_mfa_aal2() or coalesce(char_length(trim(p_reason)),0)<1) then raise exception using errcode='42501',message='reservation_override_denied'; end if;
  if p_event_id is null then
    insert into public.agenda_events(institution_id,context_kind,context_id,title,item_type,priority,status,origin,starts_at,ends_at,all_day,time_zone_id,location,description,response_mode,guardian_response_policy,recurrence,audience,reminders,questions,created_by_person_id,updated_by_person_id)
    values((p_payload->>'institutionId')::uuid,p_payload->>'contextKind',(p_payload->>'contextId')::uuid,trim(p_payload->>'title'),p_payload->>'type',coalesce(p_payload->>'priority','normal'),v_status,coalesce(p_payload->>'origin','institution'),(p_payload->>'startsAt')::timestamptz,(p_payload->>'endsAt')::timestamptz,coalesce((p_payload->>'allDay')::boolean,false),coalesce(p_payload->>'timeZoneId','America/Sao_Paulo'),coalesce(p_payload->>'location',''),coalesce(p_payload->>'description',''),coalesce(p_payload->>'responseMode','none'),coalesce(p_payload->>'guardianResponsePolicy','oneIsEnough'),p_payload->'recurrence',coalesce(p_payload->'audience','{}'::jsonb),coalesce(p_payload->'reminders','[]'::jsonb),coalesce(p_payload->'questions','[]'::jsonb),v_actor,v_actor) returning * into v_event;
    v_action:=case when v_conflict then 'override_reservation' else 'create' end;
  else
    select * into v_existing from public.agenda_events where id=p_event_id for update;
    if not found then raise exception using errcode='P0002',message='agenda_event_not_found'; end if;
    if not app_private.has_platform_permission('agenda.edit_all') and not (v_existing.created_by_person_id=v_actor and app_private.has_platform_permission('agenda.edit_own')) then raise exception using errcode='42501',message='edit_permission_denied'; end if;
    if p_expected_revision is null or p_expected_revision<>v_existing.revision then raise exception using errcode='40001',message='agenda_revision_conflict'; end if;
    update public.agenda_events set institution_id=(p_payload->>'institutionId')::uuid,context_kind=p_payload->>'contextKind',context_id=(p_payload->>'contextId')::uuid,title=trim(p_payload->>'title'),item_type=p_payload->>'type',priority=coalesce(p_payload->>'priority','normal'),status=v_status,starts_at=(p_payload->>'startsAt')::timestamptz,ends_at=(p_payload->>'endsAt')::timestamptz,all_day=coalesce((p_payload->>'allDay')::boolean,false),time_zone_id=coalesce(p_payload->>'timeZoneId','America/Sao_Paulo'),location=coalesce(p_payload->>'location',''),description=coalesce(p_payload->>'description',''),response_mode=coalesce(p_payload->>'responseMode','none'),guardian_response_policy=coalesce(p_payload->>'guardianResponsePolicy','oneIsEnough'),recurrence=p_payload->'recurrence',audience=coalesce(p_payload->'audience','{}'::jsonb),reminders=coalesce(p_payload->'reminders','[]'::jsonb),questions=coalesce(p_payload->'questions','[]'::jsonb),updated_by_person_id=v_actor,revision=revision+1,updated_at=now() where id=p_event_id returning * into v_event;
    v_action:=case when v_conflict then 'override_reservation' else 'update' end;
  end if;
  insert into public.agenda_history_receipts(request_id,event_id,institution_id,actor_person_id,action,previous_revision,next_revision,reason) values(p_request_id,v_event.id,v_event.institution_id,v_actor,v_action,v_existing.revision,v_event.revision,nullif(trim(p_reason),''));
  return public.superadmin_agenda_get(v_event.id);
end; $$;

create or replace function public.superadmin_agenda_command(p_request_id uuid,p_event_id uuid,p_expected_revision bigint,p_action text,p_reason text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
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

create or replace function public.superadmin_agenda_requests(p_kind text default 'publication',p_status text default null,p_limit integer default 50,p_offset integer default 0)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_result jsonb;
begin
  perform app_private.assert_agenda_permission('agenda.manage_responses',false);
  if p_kind='publication' then select coalesce(jsonb_agg(to_jsonb(r) order by r.requested_at desc,r.id),'[]'::jsonb) into v_result from (select * from public.agenda_publication_requests where p_status is null or status=p_status limit p_limit offset p_offset) r;
  elsif p_kind='guardian' then select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id),'[]'::jsonb) into v_result from (select * from public.agenda_guardian_requests where p_status is null or status=p_status limit p_limit offset p_offset) r;
  else raise exception using errcode='22023',message='invalid_request_kind'; end if;
  return v_result;
end; $$;

create or replace function public.superadmin_agenda_decide_publication(p_request_id uuid,p_publication_request_id uuid,p_approve boolean,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
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

do $$ declare v_signature regprocedure; begin
  foreach v_signature in array array[
    'public.superadmin_agenda_list(timestamptz,timestamptz,uuid,text,integer,integer)'::regprocedure,
    'public.superadmin_agenda_get(uuid)'::regprocedure,
    'public.superadmin_agenda_save(uuid,uuid,bigint,jsonb,text,boolean)'::regprocedure,
    'public.superadmin_agenda_command(uuid,uuid,bigint,text,text)'::regprocedure,
    'public.superadmin_agenda_requests(text,text,integer,integer)'::regprocedure,
    'public.superadmin_agenda_decide_publication(uuid,uuid,boolean,text)'::regprocedure
  ] loop
    execute format('revoke execute on function %s from public, anon',v_signature);
    execute format('grant execute on function %s to authenticated',v_signature);
  end loop;
end $$;
