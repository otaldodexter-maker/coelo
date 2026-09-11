-- 20260910220700_attendance_dashboard_access_and_context_options_v1
--
-- Contrato de leitura de acesso e de opcoes de contexto da Assiduidade
-- (achado F-R04-FCR-007 do grupo formularios-cuidado-rotina, Rodada 4,
-- 11/09/2026; ADR 0034). Sobre a baseline 20260910000000 + lotes 1..21.
--
-- O cliente (apps/superadmin/lib/features/attendance/data/
-- supabase_attendance_repository.dart) abre /attendance chamando
-- public.attendance_dashboard_access() e /attendance/new chamando
-- public.superadmin_attendance_context_options(p_date date); as duas devolvem
-- PGRST202 em producao. attendance_dashboard_access existe somente no
-- historico (20260825171221) e superadmin_attendance_context_options nunca
-- teve arquivo no repositorio.
--
-- O que este pacote faz:
--   1. app_private.attendance_dashboard_access(): corpo do historico sem
--      alteracao (escopo platform > institution > unit > assignments >
--      guardian; can_read, can_create_call, can_export, assigned_group_ids,
--      assigned_activity_ids, child_ids). O ator vem de
--      app_private.current_person_id(), que desde 20260910220400 cai na
--      pessoa de servico da sessao interna v2 (ponte de ator); a capacidade
--      vem de has_platform_permission/has_context_permission
--      (attendance.read / attendance.manage, catalogo completado no 220400).
--   2. app_private.superadmin_attendance_context_options(p_date date): novo.
--      Devolve {institutions:[{id,name}], units:[{id,name,institution_id}],
--      groups:[{id,name,institution_id,unit_id}], activities:[{id,name,
--      institution_id,unit_id,group_id,attendance_required}], can_manage}
--      restrito ao escopo de attendance_dashboard_access: platform ve tudo;
--      institution/unit ve a propria instituicao/unidade; assignments ve
--      somente grupos e atividades atribuidos; guardian e negado (42501).
--      Atividades sao os vinculos ativos de atividade x grupo na data
--      (activity_group_links, starts_at <= p_date < ends_at) com a definicao
--      ativa; `id` e o activity_id (activity_definitions), o mesmo que
--      attendance_sessions.activity_id espera em superadmin_attendance_create_call.
--      attendance_required nao existe no esquema: devolvido como true.
--   3. wrappers public.* security definer com revoke de public/anon e grant
--      somente a authenticated; as funcoes app_private sem grant a cliente.
--
-- Fora deste pacote (continua aberto): attendance_dashboard_read,
-- attendance_dashboard_ranking_page, attendance_dashboard_request_export,
-- superadmin_attendance_directory, superadmin_attendance_call_detail e os
-- comandos superadmin_attendance_* (create_call etc.), tambem ausentes.
-- Sem AAL2, sem segredo. Reversao (manual, forward-only): drop das quatro
-- funcoes criadas aqui.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'attendance access migration requires postgres';
  end if;
  if to_regprocedure('app_private.current_person_id()') is null
    or to_regprocedure('app_private.has_platform_permission(text)') is null
    or to_regprocedure('app_private.has_context_permission(uuid,text,uuid,uuid,uuid,uuid,boolean)') is null
    or to_regprocedure('app_private.guardian_has_capability(uuid,text)') is null
    or to_regclass('public.institution_memberships') is null
    or to_regclass('public.institution_role_assignments') is null
    or to_regclass('public.activity_group_assignments') is null
    or to_regclass('public.activity_group_links') is null
    or to_regclass('public.activity_definitions') is null
    or to_regclass('public.guardian_links') is null
    or to_regclass('public.child_contexts') is null then
    raise object_not_in_prerequisite_state using message = 'attendance access dependencies are missing';
  end if;
  if not exists (select 1 from public.platform_permissions where code = 'attendance.read' and status = 'active')
    or not exists (select 1 from public.platform_permissions where code = 'attendance.manage' and status = 'active') then
    raise object_not_in_prerequisite_state using message = 'attendance.read/attendance.manage catalog (20260910220400) is required';
  end if;
  if to_regprocedure('public.attendance_dashboard_access()') is not null
    or to_regprocedure('public.superadmin_attendance_context_options(date)') is not null then
    raise duplicate_function using message = 'attendance access functions already exist';
  end if;
end
$preflight$;

create or replace function app_private.attendance_dashboard_access()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid:=app_private.current_person_id();
  membership_record record;
  scope_name text;
  child_ids jsonb;
  group_ids jsonb;
  activity_ids jsonb;
begin
  if actor is null then
    raise insufficient_privilege using message='authentication required';
  end if;

  if app_private.has_platform_permission('attendance.read')
     or app_private.has_platform_permission('attendance.manage') then
    return jsonb_build_object(
      'scope','platform','can_read',true,
      'can_create_call',app_private.has_platform_permission('attendance.manage'),
      'can_export',app_private.has_platform_permission('attendance.export'),
      'assigned_group_ids','[]'::jsonb,'assigned_activity_ids','[]'::jsonb,
      'child_ids','[]'::jsonb
    );
  end if;

  select membership.id,membership.institution_id,
         case
           when bool_or(assignment.scope_kind='institution') then 'institution'
           when bool_or(assignment.scope_kind='unit') then 'unit'
           else 'assignments'
         end as scope_kind,
         min(assignment.scope_unit_id::text)::uuid as unit_id
    into membership_record
  from public.institution_memberships membership
  join public.institution_role_assignments assignment
    on assignment.membership_id=membership.id
   and assignment.status='active'
   and (assignment.starts_at is null or assignment.starts_at<=now())
   and (assignment.expires_at is null or assignment.expires_at>now())
  where membership.person_id=actor and membership.status='active'
    and membership.revoked_at is null
    and (
      app_private.has_context_permission(membership.institution_id,'attendance.read',
        assignment.scope_unit_id,assignment.scope_group_id,null,null,false)
      or app_private.has_context_permission(membership.institution_id,'attendance.manage',
        assignment.scope_unit_id,assignment.scope_group_id,null,null,false)
    )
  group by membership.id,membership.institution_id
  order by case when bool_or(assignment.scope_kind='institution') then 0
                when bool_or(assignment.scope_kind='unit') then 1 else 2 end
  limit 1;

  if membership_record.id is not null then
    scope_name:=membership_record.scope_kind;
    select
      coalesce(jsonb_agg(distinct link.group_id)
        filter(where link.group_id is not null),'[]'::jsonb),
      coalesce(jsonb_agg(distinct link.activity_id)
        filter(where link.activity_id is not null),'[]'::jsonb)
      into group_ids,activity_ids
    from public.activity_group_assignments assignment
    join public.activity_group_links link
      on link.id=assignment.activity_group_link_id
     and link.institution_id=assignment.institution_id
    where assignment.membership_id=membership_record.id
      and assignment.person_id=actor
      and assignment.institution_id=membership_record.institution_id
      and assignment.status='active' and assignment.revoked_at is null
      and link.status='active' and link.starts_at<=now()
      and (link.ends_at is null or link.ends_at>now());

    return jsonb_build_object(
      'scope',scope_name,'can_read',true,
      'institution_id',membership_record.institution_id,
      'unit_id',case when scope_name='unit' then membership_record.unit_id else null end,
      'can_create_call',app_private.has_context_permission(
        membership_record.institution_id,'attendance.manage',membership_record.unit_id,null,null,null,false),
      'can_export',case when scope_name='assignments' then exists(
        select 1
        from public.groups authorized_group
        where authorized_group.institution_id=membership_record.institution_id
          and authorized_group.status='active'
          and group_ids ? authorized_group.id::text
          and app_private.has_context_permission(
            membership_record.institution_id,'attendance.export',
            authorized_group.unit_id,authorized_group.id,null,null,false)
      ) else app_private.has_context_permission(
        membership_record.institution_id,'attendance.export',membership_record.unit_id,null,null,null,false)
      end,
      'assigned_group_ids',coalesce(group_ids,'[]'::jsonb),
      'assigned_activity_ids',coalesce(activity_ids,'[]'::jsonb),
      'child_ids','[]'::jsonb
    );
  end if;

  select coalesce(jsonb_agg(distinct child_context.id),'[]'::jsonb)
    into child_ids
  from public.guardian_links guardian
  join public.child_contexts child_context on child_context.child_person_id=guardian.child_person_id
  where guardian.guardian_person_id=actor and guardian.status='active'
    and guardian.revoked_at is null and child_context.status='active'
    and app_private.guardian_has_capability(child_context.id,'manage_attendance_notices');

  if jsonb_array_length(child_ids)>0 then
    return jsonb_build_object(
      'scope','guardian','can_read',true,'can_create_call',false,'can_export',false,
      'assigned_group_ids','[]'::jsonb,'assigned_activity_ids','[]'::jsonb,
      'child_ids',child_ids
    );
  end if;

  raise insufficient_privilege using message='attendance.read required';
end $$;



create function app_private.superadmin_attendance_context_options(p_date date)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  access_payload jsonb;
  scope_name text;
  scope_institution uuid;
  scope_unit uuid;
  group_ids jsonb;
  activity_ids jsonb;
  effective_date date := coalesce(p_date, current_date);
begin
  access_payload := app_private.attendance_dashboard_access();
  scope_name := access_payload->>'scope';
  if scope_name is null or scope_name = 'guardian' or coalesce((access_payload->>'can_read')::boolean, false) is not true then
    raise insufficient_privilege using message='attendance.read required';
  end if;
  scope_institution := (access_payload->>'institution_id')::uuid;
  scope_unit := (access_payload->>'unit_id')::uuid;
  group_ids := coalesce(access_payload->'assigned_group_ids','[]'::jsonb);
  activity_ids := coalesce(access_payload->'assigned_activity_ids','[]'::jsonb);

  return jsonb_build_object(
    'institutions', coalesce((
      select jsonb_agg(jsonb_build_object('id',i.id,'name',i.public_name) order by lower(i.public_name), i.id)
      from public.institutions i
      where i.status='active' and i.deleted_at is null
        and (scope_name='platform' or i.id=scope_institution)
    ),'[]'::jsonb),
    'units', coalesce((
      select jsonb_agg(jsonb_build_object('id',u.id,'name',u.name,'institution_id',u.institution_id) order by lower(u.name), u.id)
      from public.units u join public.institutions i on i.id=u.institution_id
      where u.status='active' and i.status='active' and i.deleted_at is null
        and (scope_name='platform' or u.institution_id=scope_institution)
        and (scope_name<>'unit' or u.id=scope_unit)
        and (scope_name<>'assignments' or exists(
          select 1 from public.groups g where g.unit_id=u.id and group_ids ? g.id::text))
    ),'[]'::jsonb),
    'groups', coalesce((
      select jsonb_agg(jsonb_build_object('id',g.id,'name',g.name,'institution_id',g.institution_id,'unit_id',g.unit_id) order by lower(g.name), g.id)
      from public.groups g join public.units u on u.id=g.unit_id join public.institutions i on i.id=g.institution_id
      where g.status='active' and u.status='active' and i.status='active' and i.deleted_at is null
        and (scope_name='platform' or g.institution_id=scope_institution)
        and (scope_name<>'unit' or g.unit_id=scope_unit)
        and (scope_name<>'assignments' or group_ids ? g.id::text)
    ),'[]'::jsonb),
    'activities', coalesce((
      select jsonb_agg(jsonb_build_object('id',link.activity_id,'name',def.name,'institution_id',link.institution_id,
        'unit_id',link.unit_id,'group_id',link.group_id,'attendance_required',true) order by lower(def.name), link.group_id, link.activity_id)
      from public.activity_group_links link
      join public.activity_definitions def on def.id=link.activity_id and def.institution_id=link.institution_id
      join public.groups g on g.id=link.group_id and g.status='active'
      where link.status='active' and def.status='active'
        and link.starts_at::date <= effective_date
        and (link.ends_at is null or link.ends_at::date > effective_date)
        and (scope_name='platform' or link.institution_id=scope_institution)
        and (scope_name<>'unit' or link.unit_id=scope_unit)
        and (scope_name<>'assignments' or (group_ids ? link.group_id::text and activity_ids ? link.activity_id::text))
    ),'[]'::jsonb),
    'can_manage', coalesce((access_payload->>'can_create_call')::boolean, false)
  );
end $$;

create function public.attendance_dashboard_access()
returns jsonb language sql stable security definer set search_path=''
as $$select app_private.attendance_dashboard_access()$$;

create function public.superadmin_attendance_context_options(p_date date default null)
returns jsonb language sql stable security definer set search_path=''
as $$select app_private.superadmin_attendance_context_options($1)$$;

alter function app_private.attendance_dashboard_access() owner to postgres;
alter function app_private.superadmin_attendance_context_options(date) owner to postgres;
alter function public.attendance_dashboard_access() owner to postgres;
alter function public.superadmin_attendance_context_options(date) owner to postgres;
revoke all on function app_private.attendance_dashboard_access() from public, anon, authenticated, service_role;
revoke all on function app_private.superadmin_attendance_context_options(date) from public, anon, authenticated, service_role;
revoke all on function public.attendance_dashboard_access() from public, anon, service_role;
revoke all on function public.superadmin_attendance_context_options(date) from public, anon, service_role;
grant execute on function public.attendance_dashboard_access() to authenticated;
grant execute on function public.superadmin_attendance_context_options(date) to authenticated;
commit;
