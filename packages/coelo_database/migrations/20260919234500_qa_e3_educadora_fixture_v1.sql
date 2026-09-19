-- 20260919234500_qa_e3_educadora_fixture_v1
--
-- Etapa 3 F7 / Sessao ACESSO-PERFIL (19/09/2026): fixture QA para a prova na rota real do horario por
-- PERFIL (lote 86) — educadora COM CONTA DE LOGIN (conta criada pela Auth Admin API, nunca por insert em
-- auth.users; credencial em Coelo-backups/qa-e3-educadora.env, nunca impressa).
--
-- So CRIA a funcao privada app_private.seed_qa_e3_educadora_fixture_v1 (sem grant a anon/authenticated/
-- service_role). Execucao como postgres: select app_private.seed_qa_e3_educadora_fixture_v1();
-- Cria, idempotente e fail-closed (tenant qa-r04-*, prefixo "QA E3"):
--   * perfil "QA E3 Educador" (institution_roles, instituicao QA R04 Cuidado, max_scope unit) com as
--     permissoes do papel de sistema teacher;
--   * pessoa adulta "QA E3 Educadora Perfil" ligada a conta p_email (person_auth_links);
--   * membership teacher (scope unit, Unidade QA R04) em QA R04 Cuidado + institution_role_assignments
--     no perfil "QA E3 Educador" (herda o horario do perfil);
--   * membership teacher (scope unit, Unidade Centro R04) em Escola R04 Estrutura, sem perfil com horario;
--   * guardian_links + guardian_context_permissions(can_view) para "QA R15 Crianca 1" (contexto em QA R04
--     Cuidado): a educadora tambem e responsavel na mesma instituicao (ADR 0035).
-- Nao grava audit.audit_logs (padrao das fixtures QA). Reversao manual.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create or replace function app_private.seed_qa_e3_educadora_fixture_v1(
  p_email text default 'qa-e3-educadora@coelo.me',
  p_institution_id uuid default 'd0c40000-0000-4000-8000-000000000001',
  p_unit_id uuid default 'd0c40000-0000-4000-8000-000000000002',
  p_other_institution_id uuid default '190dd028-3125-452d-8502-612bfa1029de',
  p_other_unit_id uuid default 'f5284f2f-b487-4100-bc0b-ffbcbb7d3db3',
  p_child_context_id uuid default '1a6158fe-6cab-427c-9496-96e4273ab184',
  p_person_name text default 'QA E3 Educadora Perfil',
  p_role_name text default 'QA E3 Educador',
  p_role_code text default 'qa-e3-educador'
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_auth_user_id uuid;
  v_person_id uuid;
  v_role_id uuid;
  v_membership_id uuid;
  v_other_membership_id uuid;
  v_context public.child_contexts%rowtype;
  v_link_id uuid;
  v_relationship_type_id uuid;
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'qa e3 fixture must run as postgres';
  end if;
  if v_email !~ '^qa-e3-[a-z0-9.-]+@coelo\.me$' or p_person_name not like 'QA E3%' or p_role_name not like 'QA E3%' then
    raise invalid_parameter_value using message = 'invalid_qa_fixture_input';
  end if;
  select u.id into v_auth_user_id from auth.users u where lower(u.email) = v_email;
  if v_auth_user_id is null then
    raise no_data_found using message = 'qa_auth_user_missing', detail = v_email;
  end if;
  if exists (select 1 from app_private.superadmin_internal_auth_links l where l.auth_user_id = v_auth_user_id) then
    raise unique_violation using message = 'qa_auth_user_internal_realm';
  end if;
  if not exists (select 1 from public.institutions i where i.id = p_institution_id and i.deleted_at is null and i.slug like 'qa-r04-%')
     or not exists (select 1 from public.institutions i where i.id = p_other_institution_id and i.deleted_at is null and i.slug like 'qa-r04-%') then
    raise no_data_found using message = 'qa_institution_missing_or_not_synthetic';
  end if;
  if not exists (select 1 from public.units u where u.id = p_unit_id and u.institution_id = p_institution_id)
     or not exists (select 1 from public.units u where u.id = p_other_unit_id and u.institution_id = p_other_institution_id) then
    raise no_data_found using message = 'qa_unit_missing';
  end if;
  select * into v_context from public.child_contexts c where c.id = p_child_context_id and c.institution_id = p_institution_id and c.status = 'active';
  if v_context.id is null then
    raise no_data_found using message = 'qa_child_context_missing';
  end if;
  if not exists (select 1 from public.people p where p.id = v_context.child_person_id and p.display_name like 'QA R15%') then
    raise no_data_found using message = 'qa_child_not_synthetic';
  end if;

  -- 1. perfil da instituicao com as permissoes do teacher de sistema
  select r.id into v_role_id from public.institution_roles r where r.institution_id = p_institution_id and r.code = p_role_code;
  if v_role_id is null then
    insert into public.institution_roles(institution_id, code, name, description, is_system, status, max_scope_kind)
    values (p_institution_id, p_role_code, p_role_name, 'Perfil QA E3 para a prova do horario por perfil (ADR 0035).', false, 'active', 'unit')
    returning id into v_role_id;
  end if;
  insert into public.institution_role_permissions(role_id, permission_id, effect, status)
  select v_role_id, rp.permission_id, 'allow', 'active'
  from public.institution_role_permissions rp
  join public.institution_roles sys on sys.id = rp.role_id and sys.code = 'teacher' and sys.is_system and sys.institution_id is null
  where rp.status = 'active'
  on conflict (role_id, permission_id) do update set effect = 'allow', status = 'active', revoked_at = null;

  -- 2. pessoa + conta
  select p.id into v_person_id from public.people p where p.display_name = p_person_name and p.person_type = 'adult' and p.deleted_at is null;
  if v_person_id is null then
    insert into public.people(person_type, first_name, last_name, display_name, status)
    values ('adult', 'QA E3', 'Educadora Perfil', p_person_name, 'active')
    returning id into v_person_id;
  end if;
  if exists (select 1 from public.person_auth_links l where l.auth_user_id = v_auth_user_id and l.status = 'active' and l.person_id <> v_person_id) then
    raise unique_violation using message = 'qa_auth_user_linked_elsewhere';
  end if;
  if not exists (select 1 from public.person_auth_links l where l.person_id = v_person_id and l.auth_user_id = v_auth_user_id and l.status = 'active') then
    insert into public.person_auth_links(person_id, auth_user_id, status) values (v_person_id, v_auth_user_id, 'active');
  end if;

  -- 3. vinculo teacher em QA R04 Cuidado (unidade) com o perfil QA E3 Educador
  select m.id into v_membership_id from public.institution_memberships m
  where m.person_id = v_person_id and m.institution_id = p_institution_id and m.role_code = 'teacher' and m.status = 'active' and m.revoked_at is null;
  if v_membership_id is null then
    insert into public.institution_memberships(person_id, institution_id, role_code, status, scope_kind, scope_unit_id)
    values (v_person_id, p_institution_id, 'teacher', 'active', 'unit', p_unit_id)
    returning id into v_membership_id;
  end if;
  if not exists (select 1 from public.institution_role_assignments a where a.membership_id = v_membership_id and a.role_id = v_role_id and a.status = 'active') then
    insert into public.institution_role_assignments(membership_id, role_id, scope_kind, scope_unit_id, status)
    values (v_membership_id, v_role_id, 'unit', p_unit_id, 'active');
  end if;

  -- 4. vinculo teacher em outra instituicao QA, sem horario
  select m.id into v_other_membership_id from public.institution_memberships m
  where m.person_id = v_person_id and m.institution_id = p_other_institution_id and m.role_code = 'teacher' and m.status = 'active' and m.revoked_at is null;
  if v_other_membership_id is null then
    insert into public.institution_memberships(person_id, institution_id, role_code, status, scope_kind, scope_unit_id)
    values (v_person_id, p_other_institution_id, 'teacher', 'active', 'unit', p_other_unit_id)
    returning id into v_other_membership_id;
  end if;
  insert into public.institution_role_assignments(membership_id, role_id, scope_kind, scope_unit_id, status)
  select v_other_membership_id, sys.id, 'unit', p_other_unit_id, 'active'
  from public.institution_roles sys where sys.code = 'teacher' and sys.is_system and sys.institution_id is null
    and not exists (select 1 from public.institution_role_assignments a where a.membership_id = v_other_membership_id and a.status = 'active');

  -- 5. familia: responsavel da QA R15 Crianca 1 em QA R04 Cuidado
  select r.id into v_relationship_type_id from public.family_relationship_types r where r.code = 'other' and r.status = 'active' limit 1;
  if v_relationship_type_id is null then
    select r.id into v_relationship_type_id from public.family_relationship_types r where r.status = 'active' order by r.code limit 1;
  end if;
  select g.id into v_link_id from public.guardian_links g
  where g.guardian_person_id = v_person_id and g.child_person_id = v_context.child_person_id and g.status = 'active';
  if v_link_id is null then
    insert into public.guardian_links(guardian_person_id, child_person_id, relation_type, relationship_type_id, status)
    values (v_person_id, v_context.child_person_id, 'responsavel', v_relationship_type_id, 'active')
    returning id into v_link_id;
  end if;
  if not exists (select 1 from public.guardian_context_permissions gp where gp.guardian_link_id = v_link_id and gp.child_context_id = v_context.id) then
    insert into public.guardian_context_permissions(guardian_link_id, child_context_id, can_view, can_message, can_react, status)
    values (v_link_id, v_context.id, true, true, true, 'active');
  end if;

  return jsonb_build_object(
    'person_id', v_person_id, 'role_id', v_role_id,
    'membership_id', v_membership_id, 'other_membership_id', v_other_membership_id, 'guardian_link_id', v_link_id);
end
$$;
revoke all on function app_private.seed_qa_e3_educadora_fixture_v1(text, uuid, uuid, uuid, uuid, uuid, text, text, text) from public, anon, authenticated, service_role;

commit;
