-- Alunos: leitura dos vinculos atuais de uma crianca.
--
-- O pacote 20260910220200 entregou os quatro comandos (vincular, transferir,
-- editar e revogar) e nenhuma leitura. Sem ela a tela de gestao so consegue
-- escrever no escuro: nao da para mostrar em que unidade e turma a crianca
-- esta hoje, nem oferecer transferir e revogar sobre um vinculo concreto.
--
-- A leitura segue as mesmas tres regras dos comandos:
--
--   1. A instituicao vem do contexto infantil, nunca de argumento.
--   2. A capacidade e conferida contra essa instituicao.
--   3. A negativa e opaca: crianca inexistente e crianca fora do escopo
--      respondem a mesma coisa.
--
-- Diferenca proposital em relacao aos comandos: aqui basta `people.read`. Ver
-- onde a crianca esta e leitura de diretorio; mover exige `assign_children`.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '600s';
select pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('coelo.students.links-read', 0)
);

do $preflight$
begin
  if current_user <> 'postgres' then
    raise exception using errcode='42501',
      message='student links read must run as postgres';
  end if;
  if pg_catalog.to_regclass('public.child_unit_links') is null then
    raise exception using errcode='55000',
      message='student links read requires the contextual core';
  end if;
end
$preflight$;

create or replace function app_private.superadmin_student_links(
  p_child_context_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid := app_private.current_person_id();
  child_row public.child_contexts;
  child_name text;
begin
  if actor is null then
    raise insufficient_privilege using message='authentication required';
  end if;
  select * into child_row from public.child_contexts
  where id = p_child_context_id and status = 'active';
  if child_row.id is null then
    raise no_data_found using message='student link unavailable';
  end if;
  if not app_private.has_platform_permission('people.read')
    and not app_private.has_context_permission(
      child_row.institution_id, 'people.read', null, null, null,
      child_row.id, false
    ) then
    -- Mesma negativa da crianca ausente: distinguir confirmaria que ela existe
    -- em outra instituicao.
    raise no_data_found using message='student link unavailable';
  end if;
  select person_row.display_name into child_name
  from public.people person_row where person_row.id = child_row.child_person_id;

  return jsonb_build_object(
    'child_context_id', child_row.id,
    'child_person_id', child_row.child_person_id,
    'display_name', child_name,
    'institution_id', child_row.institution_id,
    'can_manage', app_private.has_platform_permission('people.assign_children')
      or app_private.has_context_permission(
        child_row.institution_id, 'people.assign_children', null, null, null,
        child_row.id, false),
    'unit_links', coalesce((
      select jsonb_agg(jsonb_build_object(
        'unit_link_id', unit_link.id,
        'unit_id', unit_link.unit_id,
        'unit_name', unit_row.name,
        'status', unit_link.status,
        'accepted_at', unit_link.accepted_at,
        'revoked_at', unit_link.revoked_at,
        'group_links', coalesce((
          select jsonb_agg(jsonb_build_object(
            'group_link_id', group_link.id,
            'group_id', group_link.group_id,
            'group_name', group_row.name,
            'status', group_link.status,
            'starts_at', group_link.starts_at,
            'ends_at', group_link.ends_at
          ) order by group_row.name)
          from public.child_group_links group_link
          join public.groups group_row on group_row.id = group_link.group_id
          where group_link.child_unit_link_id = unit_link.id), '[]'::jsonb)
      ) order by unit_row.name)
      from public.child_unit_links unit_link
      join public.units unit_row on unit_row.id = unit_link.unit_id
      where unit_link.child_context_id = child_row.id), '[]'::jsonb)
  );
end
$$;

create or replace function public.superadmin_student_links(child_context_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select app_private.superadmin_student_links(child_context_id)
$$;

revoke all on function app_private.superadmin_student_links(uuid)
  from public, anon, authenticated;
grant execute on function app_private.superadmin_student_links(uuid)
  to authenticated, service_role;
revoke all on function public.superadmin_student_links(uuid)
  from public, anon, authenticated;
grant execute on function public.superadmin_student_links(uuid)
  to authenticated, service_role;

commit;
