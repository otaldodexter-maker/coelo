-- RETIDO ate a decisao P31 do Owner (papeis padrao de instituicao).
-- Renomear sem o sufixo RETIDO-P31 quando aprovado; o coordenador aplica.
--
-- Problema: producao tem 0 public.institution_roles. Sem papel de instituicao,
-- Convites (superadmin_invite_options_v2 devolve profiles=[]) e o dominio
-- Admin de Perfis e permissoes nao tem o que atribuir. A tabela exige
-- institution_id OU is_system (institution_roles_global_system_check): os
-- papeis de sistema (institution_id nulo, is_system true) sao os modelos
-- globais que toda instituicao recebe.
--
-- Proposta (quatro papeis de sistema, idempotente por code):
--   institution_admin   Administrador: todas as permissoes institucionais ativas
--   coordinator         Coordenacao: leitura geral + gestao pedagogica e de rotina
--   teacher             Professor(a): leitura + registro de rotina/assiduidade
--   secretary           Secretaria: pessoas, familias, transferencias, circulares
-- A concessao usa public.institution_role_permissions (effect allow) sobre o
-- catalogo public.institution_permissions vigente; codigos ausentes no
-- catalogo sao ignorados (nao falham) para o pacote valer em qualquer base.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'institution role templates must run as postgres';
  end if;
  if to_regclass('public.institution_roles') is null
     or to_regclass('public.institution_role_permissions') is null
     or to_regclass('public.institution_permissions') is null then
    raise object_not_in_prerequisite_state using message = 'institution role catalog is required';
  end if;
end
$preflight$;

create or replace function app_private.seed_institution_role_system_templates()
returns integer
language plpgsql
security definer
set search_path to ''
as $$
declare
  role_spec record;
  target_role_id uuid;
  granted integer := 0;
  inserted integer;
begin
  for role_spec in
    select * from (values
      ('institution_admin', 'Administrador da instituicao', 'Acesso completo a instituicao, unidades e turmas.', 'institution', null::text[]),
      ('coordinator', 'Coordenacao', 'Leitura geral e gestao pedagogica, de rotina e de atividades.', 'institution',
        array['activities.assign_people','activities.create','activities.link_groups','activities.link_units','activities.manage','activities.read',
              'attendance.manage','attendance.read','circulars.circulars.create','circulars.circulars.manage','circulars.circulars.publish','circulars.circulars.read',
              'family.read','groups.manage','groups.read','happens.posts.create','happens.posts.publish','happens.posts.read','happens.posts.remove',
              'health_care.read','medication.read','moments.publications.create','moments.publications.publish','moments.publications.read',
              'now.publications.create','now.publications.publish','now.publications.read','people.read','profiles.about.read',
              'routine.correct','routine.manage_applications','routine.manage_models','routine.publish','routine.read','routine.record']),
      ('teacher', 'Professor(a)', 'Leitura da turma e registro de rotina, assiduidade e momentos.', 'unit',
        array['activities.read','attendance.manage','attendance.read','circulars.circulars.read','circulars.circulars.respond','family.read','groups.read',
              'happens.posts.create','happens.posts.read','health_care.read','medication.read','medication.record_evidence',
              'moments.publications.create','moments.publications.read','now.publications.create','now.publications.read','people.read',
              'routine.read','routine.record']),
      ('secretary', 'Secretaria', 'Pessoas, familias, transferencias e circulares.', 'institution',
        array['activities.read','circulars.circulars.create','circulars.circulars.manage','circulars.circulars.read','family.manage','family.read',
              'groups.read','people.assign_children','people.manage','people.read','transfers.manage','authorized_people.manage'])
    ) as spec(code, name, description, max_scope_kind, permission_codes)
  loop
    -- Sem unique em institution_roles: idempotencia por existencia explicita.
    insert into public.institution_roles (institution_id, code, name, description, is_system, status, max_scope_kind)
    select null, role_spec.code, role_spec.name, role_spec.description, true, 'active', role_spec.max_scope_kind
    where not exists (
      select 1 from public.institution_roles existing
      where existing.institution_id is null and existing.code = role_spec.code and existing.is_system
    );
    select existing.id into target_role_id from public.institution_roles existing
    where existing.institution_id is null and existing.code = role_spec.code and existing.is_system
    order by existing.created_at limit 1;
    if target_role_id is null then continue; end if;

    insert into public.institution_role_permissions (role_id, permission_id, effect, status)
    select target_role_id, permission_record.id, 'allow', 'active'
    from public.institution_permissions permission_record
    where permission_record.status = 'active'
      and (role_spec.permission_codes is null or permission_record.code = any(role_spec.permission_codes))
      and not exists (
        select 1 from public.institution_role_permissions existing
        where existing.role_id = target_role_id and existing.permission_id = permission_record.id
          and existing.status = 'active' and existing.revoked_at is null
      );
    get diagnostics inserted = row_count;
    granted := granted + inserted;
  end loop;
  return granted;
end
$$;

revoke all on function app_private.seed_institution_role_system_templates() from public, anon, authenticated;

select app_private.seed_institution_role_system_templates();

commit;
