-- R14 Sessao 8 / ADR 0041 D3 (owner.r12-05): contexto Atividade em
-- superadmin_attendance_context_options.
--
-- Divergencia observada em producao (leitura D1, 16/09/2026): as listas
-- institutions/units/groups exigem instituicao ativa e nao excluida e unidade
-- ativa, mas a lista activities so exigia turma ativa. A atividade elegivel
-- 95b98978 ("Atividade R05 Estrutura (editada)") pertence a "Escola R04
-- Estrutura" (190dd028, status draft): aparecia em activities com um escopo
-- (190dd028/f5284f2f/4214106c) ausente das outras listas e a cascata do cliente
-- nunca oferecia "Atividade". Decisao do Owner (D3): alinhar o escopo de
-- activities ao de groups.
--
-- Correcao forward-only: a CTE de activities passa a juntar units e
-- institutions com os mesmos filtros de groups (u.status='active',
-- i.status='active', i.deleted_at is null) e a exigir coerencia
-- link.unit_id = g.unit_id e link.institution_id = g.institution_id. O restante
-- do corpo, a assinatura, o wrapper public.superadmin_attendance_context_options(date)
-- e os grants permanecem identicos ao dump de producao de 16/09 (SHA-256 f1f677ca).
-- Idempotente: create or replace com o mesmo corpo.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'attendance context options fix must run as postgres';
  end if;
  if to_regprocedure('app_private.superadmin_attendance_context_options(date)') is null
    or to_regprocedure('public.superadmin_attendance_context_options(date)') is null
    or to_regprocedure('app_private.attendance_dashboard_access()') is null
    or to_regclass('public.activity_group_links') is null
    or to_regclass('public.activity_definitions') is null then
    raise object_not_in_prerequisite_state using message = 'attendance context options v1 is required';
  end if;
end
$preflight$;

create or replace function app_private.superadmin_attendance_context_options(p_date date)
returns jsonb language plpgsql stable security definer set search_path='' as $$
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
      -- ADR 0041 D3: mesmo escopo de groups (turma, unidade e instituicao ativas,
      -- instituicao nao excluida, vinculo coerente com a turma).
      join public.groups g on g.id=link.group_id and g.status='active'
        and g.unit_id=link.unit_id and g.institution_id=link.institution_id
      join public.units u on u.id=link.unit_id and u.status='active'
      join public.institutions i on i.id=link.institution_id and i.status='active' and i.deleted_at is null
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

do $postcheck$
begin
  if (select prosrc from pg_proc where oid='app_private.superadmin_attendance_context_options(date)'::regprocedure)
     not like '%join public.institutions i on i.id=link.institution_id and i.status=''active'' and i.deleted_at is null%' then
    raise object_not_in_prerequisite_state using message = 'activities scope was not aligned to groups';
  end if;
  if not (select prosecdef and coalesce(array_to_string(proconfig,','),'')='search_path=""'
          from pg_proc where oid='app_private.superadmin_attendance_context_options(date)'::regprocedure) then
    raise object_not_in_prerequisite_state using message = 'security definer / search_path drift';
  end if;
end
$postcheck$;

commit;
