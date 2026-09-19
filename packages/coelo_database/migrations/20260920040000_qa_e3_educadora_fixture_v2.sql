-- QA E3 educadora fixture v2 (Sessao ACESSO-PERFIL-FECHAMENTO, 20/09/2026)
-- A Escola R04 Estrutura (190dd028) esta `draft` e nao entra em list_my_principal_contexts; o segundo vinculo da
-- educadora real passa para a QA R04 Instituicao Sintetica (9f040000-...-010, slug qa-r04-chat), escopo de
-- instituicao. A propria funcao revoga vinculos antigos da pessoa fora das duas instituicoes. Idempotente.
begin;
set local statement_timeout = '60s';

create or replace function app_private.seed_qa_e3_educadora_fixture_v1(
  p_email text default 'qa-e3-educadora@coelo.me',
  p_institution_id uuid default 'd0c40000-0000-4000-8000-000000000001',
  p_unit_id uuid default 'd0c40000-0000-4000-8000-000000000002',
  -- v2: a Escola R04 Estrutura e `draft` (nao entra em list_my_principal_contexts); o segundo vinculo
  -- vai para a QA R04 Instituicao Sintetica (slug qa-r04-chat), escopo de instituicao (sem unidades).
  p_other_institution_id uuid default '9f040000-0000-4000-8000-000000000010',
  p_other_unit_id uuid default null,
  p_child_context_id uuid default '1a6158fe-6cab-427c-9496-96e4273ab184',
  p_person_name text default 'QA E3 Educadora Perfil',
  p_role_name text default 'QA E3 Educador',
  p_role_code text default 'qa-e3-educador',
  p_mirror_membership_id uuid default '571fb282-420c-40ff-a7bf-efd6d20124a8'
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
  -- teacher tem escopo maximo de unidade; sem unidade o vinculo de equipe usa coordinator (escopo de instituicao)
  v_other_role text := case when p_other_unit_id is null then 'coordinator' else 'teacher' end;
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
     or (p_other_unit_id is not null and not exists (select 1 from public.units u where u.id = p_other_unit_id and u.institution_id = p_other_institution_id)) then
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
  where m.person_id = v_person_id and m.institution_id = p_other_institution_id and m.role_code = v_other_role and m.status = 'active' and m.revoked_at is null;
  if v_other_membership_id is null then
    insert into public.institution_memberships(person_id, institution_id, role_code, status, scope_kind, scope_unit_id)
    values (v_person_id, p_other_institution_id, v_other_role, 'active',
            case when p_other_unit_id is null then 'institution' else 'unit' end, p_other_unit_id)
    returning id into v_other_membership_id;
  end if;
  insert into public.institution_role_assignments(membership_id, role_id, scope_kind, scope_unit_id, status)
  select v_other_membership_id, sys.id, case when p_other_unit_id is null then 'institution' else 'unit' end, p_other_unit_id, 'active'
  from public.institution_roles sys where sys.code = v_other_role and sys.is_system and sys.institution_id is null
    and not exists (select 1 from public.institution_role_assignments a where a.membership_id = v_other_membership_id and a.status = 'active');

  -- 4b. vinculos de equipe da pessoa fora das duas instituicoes da fixture (ex.: Escola R04 Estrutura, v1) sao revogados (inactive + revoked_at)
  update public.institution_memberships m set status = 'inactive', revoked_at = coalesce(m.revoked_at, now())
  where m.person_id = v_person_id and m.institution_id not in (p_institution_id, p_other_institution_id)
    and m.status = 'active' and m.revoked_at is null;

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

  -- 6. espelho interno de qa-r06-principal herda o mesmo perfil (prova visual no shell hospedeiro)
  if p_mirror_membership_id is not null and exists (
    select 1 from public.institution_memberships m join public.people p on p.id = m.person_id
    where m.id = p_mirror_membership_id and m.institution_id = p_institution_id and m.status = 'active' and p.person_type = 'service'
  ) and not exists (select 1 from public.institution_role_assignments a where a.membership_id = p_mirror_membership_id and a.role_id = v_role_id and a.status = 'active') then
    insert into public.institution_role_assignments(membership_id, role_id, scope_kind, scope_unit_id, status)
    values (p_mirror_membership_id, v_role_id, 'unit', p_unit_id, 'active');
  end if;

  return jsonb_build_object(
    'person_id', v_person_id, 'role_id', v_role_id,
    'membership_id', v_membership_id, 'other_membership_id', v_other_membership_id, 'guardian_link_id', v_link_id);
end
$$;
revoke all on function app_private.seed_qa_e3_educadora_fixture_v1(text, uuid, uuid, uuid, uuid, uuid, text, text, text, uuid) from public, anon, authenticated, service_role;

-- Reaplica em producao (idempotente); num espelho sem a conta QA nao faz nada.
do $$ begin
  if exists (select 1 from auth.users where lower(email) = 'qa-e3-educadora@coelo.me') then
    perform app_private.seed_qa_e3_educadora_fixture_v1();
  end if;
end $$;

commit;
