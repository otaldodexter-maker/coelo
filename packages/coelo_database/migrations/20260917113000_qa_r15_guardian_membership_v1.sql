-- R15 Bloco B' (apoio ao Bloco B) / AP-2 (achado D1 da coordenadora, 17/09/2026): o Principal abre
-- contextos SOMENTE por public.list_my_principal_contexts, que exige uma institution_memberships
-- ativa (join obrigatorio, instituicao active, person.status active). O responsavel sintetico QA R15
-- (people da915f98, conta qa-r15-responsavel@coelo.me ligada pelo AP-1, lote 80) tem 0 memberships:
-- o Principal nao abre para ele, o que bloqueia agora.publish (audiencia Familias) e
-- forms.location-answer. O cliente ja espera membership de familia com role_code 'guardian'
-- (PrincipalRuntimeContext.isGuardianRole => roleCode == 'guardian' || 'student'); nao existe papel
-- de sistema de responsavel em institution_roles (role_code e texto livre; so 'owner' e
-- 'legal_representative' sao tratados nas funcoes de producao).
--
-- Esta migration so CRIA a funcao privada app_private.seed_qa_r15_guardian_membership_v1 (sem grant a
-- anon/authenticated/service_role). Execucao a parte, como postgres, apos o AP-1:
--   select app_private.seed_qa_r15_guardian_membership_v1();
-- Cria UMA membership ativa (person, instituicao) com role_code 'guardian', scope_kind 'group' na turma
-- 368a5cea (scope_unit_id = unidade da turma), sem institution_role_assignments (nenhuma permissao de
-- equipe: em now_viewer_role_class o vinculo de responsavel prevalece e staff_effects fica vazio).
-- Idempotente por e-mail; fail-closed: conta ausente/realm interno, pessoa sem vinculo de conta ou sem
-- prefixo "QA R15", instituicao fora de qa-r04-*, turma fora da unidade, responsavel sem guardian_link
-- ativo para crianca com contexto nessa turma, ou membership ativa divergente ja existente.
--
-- Efeito colateral conhecido (registrado para o Owner/B): child_care_notification_recipients_v1 e
-- medication_notification_recipients_v1 contam memberships de escopo institution/unit como equipe da
-- unidade e de escopo group como educadores da turma; com esta membership o responsavel passa a
-- receber os eventos de cuidado tambem por esse caminho, alem do de responsavel (E7). A funcao nao
-- altera essas RPCs.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'qa r15 guardian membership fixture must run as postgres';
  end if;
  if to_regclass('public.institution_memberships') is null
    or to_regclass('public.person_auth_links') is null
    or to_regclass('public.guardian_links') is null
    or to_regprocedure('public.list_my_principal_contexts()') is null
    or to_regprocedure('app_private.seed_qa_r15_guardian_fixture_v1(text,uuid,uuid[],uuid,uuid,text)') is null then
    raise object_not_in_prerequisite_state using message = 'guardian fixture v1 (AP-1) and principal contexts reader are required';
  end if;
end
$preflight$;

create or replace function app_private.seed_qa_r15_guardian_membership_v1(
  p_email text default 'qa-r15-responsavel@coelo.me',
  p_institution_id uuid default 'd0c40000-0000-4000-8000-000000000001',
  p_unit_id uuid default 'd0c40000-0000-4000-8000-000000000002',
  p_group_id uuid default '368a5cea-2bcf-4fa4-ad1f-18da58694551',
  p_role_code text default 'guardian'
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_auth_user_id uuid;
  v_person public.people%rowtype;
  v_membership public.institution_memberships%rowtype;
  v_result text;
begin
  if v_email = '' or v_email !~ '^qa-r15-[a-z0-9.-]+@coelo\.me$'
     or p_institution_id is null or p_unit_id is null or p_group_id is null
     or coalesce(btrim(p_role_code), '') !~ '^[a-z][a-z0-9_]{1,39}$' then
    raise invalid_parameter_value using message = 'invalid_qa_fixture_input';
  end if;
  select u.id into v_auth_user_id from auth.users u where lower(u.email) = v_email;
  if v_auth_user_id is null then
    raise no_data_found using message = 'qa_auth_user_missing', detail = v_email;
  end if;
  if exists (select 1 from app_private.superadmin_internal_auth_links l where l.auth_user_id = v_auth_user_id) then
    raise unique_violation using message = 'qa_auth_user_internal_realm', detail = v_email;
  end if;

  -- pessoa ligada a conta pelo AP-1; guardas sinteticas
  select p.* into v_person
  from public.person_auth_links l
  join public.people p on p.id = l.person_id
  where l.auth_user_id = v_auth_user_id and l.status = 'active' and l.revoked_at is null
    and p.deleted_at is null
  order by l.linked_at desc limit 1;
  if v_person.id is null or v_person.person_type <> 'adult' or v_person.display_name not like 'QA R15%' then
    raise no_data_found using message = 'qa_guardian_person_missing_or_not_synthetic', detail = v_email;
  end if;
  if not exists (
    select 1 from public.institutions i
    where i.id = p_institution_id and i.deleted_at is null and i.status = 'active' and i.slug like 'qa-r04-%'
  ) then
    raise no_data_found using message = 'qa_institution_missing_or_not_synthetic';
  end if;
  if not exists (select 1 from public.units u where u.id = p_unit_id and u.institution_id = p_institution_id and u.status = 'active') then
    raise no_data_found using message = 'qa_unit_missing';
  end if;
  if not exists (select 1 from public.groups g where g.id = p_group_id and g.unit_id = p_unit_id
                   and g.institution_id = p_institution_id and g.status = 'active') then
    raise no_data_found using message = 'qa_group_missing_or_outside_unit';
  end if;
  -- so faz sentido para quem ja e responsavel (AP-1) de crianca com contexto ativo nessa turma
  if not exists (
    select 1
    from public.guardian_links g
    join public.child_contexts c on c.child_person_id = g.child_person_id
      and c.institution_id = p_institution_id and c.status = 'active' and c.archived_at is null
    join public.child_unit_links ul on ul.child_context_id = c.id and ul.unit_id = p_unit_id
      and ul.status = 'active' and ul.revoked_at is null
    join public.child_group_links gl on gl.child_unit_link_id = ul.id and gl.group_id = p_group_id
      and gl.status = 'active'
    where g.guardian_person_id = v_person.id and g.status = 'active' and g.revoked_at is null
  ) then
    raise no_data_found using message = 'qa_guardian_link_missing_for_group', detail = p_group_id::text;
  end if;

  perform pg_advisory_xact_lock(hashtextextended('qa-r15-guardian-membership:' || v_email, 0));
  select m.* into v_membership
  from public.institution_memberships m
  where m.person_id = v_person.id and m.institution_id = p_institution_id
    and m.status = 'active' and m.revoked_at is null;
  if v_membership.id is not null then
    if v_membership.role_code = btrim(p_role_code) and v_membership.scope_kind = 'group'
       and v_membership.scope_group_id = p_group_id
       and v_membership.scope_unit_id is not distinct from p_unit_id then
      v_result := 'existing';
    else
      raise unique_violation using message = 'qa_person_has_other_active_membership',
        detail = v_membership.role_code || '/' || v_membership.scope_kind;
    end if;
  else
    insert into public.institution_memberships(
      person_id, institution_id, role_code, status, scope_kind, scope_unit_id, scope_group_id, mfa_required
    ) values (
      v_person.id, p_institution_id, btrim(p_role_code), 'active', 'group', p_unit_id, p_group_id, false
    ) returning * into v_membership;
    v_result := 'created';
  end if;

  return jsonb_build_object(
    'email', v_email,
    'auth_user_id', v_auth_user_id,
    'person_id', v_person.id,
    'membership', v_result,
    'membership_id', v_membership.id,
    'role_code', v_membership.role_code,
    'scope_kind', v_membership.scope_kind,
    'scope_unit_id', v_membership.scope_unit_id,
    'scope_group_id', v_membership.scope_group_id
  );
end
$$;

alter function app_private.seed_qa_r15_guardian_membership_v1(text, uuid, uuid, uuid, text) owner to postgres;
revoke all on function app_private.seed_qa_r15_guardian_membership_v1(text, uuid, uuid, uuid, text)
  from public, anon, authenticated, service_role;

do $postcheck$
begin
  if to_regprocedure('app_private.seed_qa_r15_guardian_membership_v1(text,uuid,uuid,uuid,text)') is null then
    raise object_not_in_prerequisite_state using message = 'qa r15 guardian membership fixture was not created';
  end if;
  if has_function_privilege('anon', 'app_private.seed_qa_r15_guardian_membership_v1(text,uuid,uuid,uuid,text)', 'execute')
     or has_function_privilege('authenticated', 'app_private.seed_qa_r15_guardian_membership_v1(text,uuid,uuid,uuid,text)', 'execute')
     or has_function_privilege('service_role', 'app_private.seed_qa_r15_guardian_membership_v1(text,uuid,uuid,uuid,text)', 'execute') then
    raise object_not_in_prerequisite_state using message = 'qa r15 guardian membership fixture must not be exposed';
  end if;
end
$postcheck$;

commit;
