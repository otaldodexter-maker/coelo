-- R15 Bloco B' (apoio ao Bloco B) / AP-1 / ADR 0042 E2: fixture privada da massa QA R15.
--
-- A tela do superadmin criou em producao (17/09/2026, Bloco B, evidencia
-- r15-bloco-b/massa-qa-r15-20260917.md) o responsavel sintetico "QA R15 Responsavel"
-- (people da915f98, adult, status draft) e as criancas "QA R15 Crianca 1/2" com contexto na
-- instituicao sintetica QA R04 Cuidado (d0c40000-...0001), child_unit_links PENDENTES na
-- Unidade QA R04 (d0c40000-...0002) e child_group_links ativos na turma 368a5cea. A tela nao
-- cria login, nao grava guardian_links (nenhuma RPC insere nessa tabela) e nao aceita o
-- vinculo de unidade; a convencao do projeto (R06) veda insert em auth.users: a conta
-- qa-r15-responsavel@coelo.me e criada pelo Owner na Auth Admin.
--
-- Esta migration so CRIA a funcao privada app_private.seed_qa_r15_guardian_fixture_v1
-- (sem grant a anon/authenticated/service_role; invisivel ao PostgREST). A execucao e um
-- passo separado, como postgres, depois que a conta existir:
--   select app_private.seed_qa_r15_guardian_fixture_v1();
-- Idempotente por e-mail: rodar duas vezes nao duplica. Fail-closed: conta ausente, conta do
-- realm interno, pessoa/contexto fora do prefixo "QA R15" ou fora da instituicao sintetica
-- interrompem sem gravar nada (a transacao da chamada e revertida).
--
-- O que a funcao grava, seguindo as regras dos triggers e RPCs de producao:
--   * person_auth_links (pessoa <-> auth user), unico ativo por pessoa e por auth user;
--   * people.status draft -> active para o responsavel (leitores de cuidado e do Principal
--     exigem person.status = 'active': child_care_notification_recipients_v1,
--     list_my_principal_contexts);
--   * guardian_links responsavel -> cada crianca (relation_type 'responsavel', tipo de
--     relacionamento 'other' do catalogo, como normalize_guardian_relationship faria);
--   * guardian_context_permissions por contexto (can_view/can_message/can_react true), que e o
--     que now_viewer_role_class exige para a audiencia Familias do Agora;
--   * child_unit_links pending -> active com accepted_by/accepted_at (mesma transicao de
--     app_private.superadmin_student_link).
-- Nao grava guardian_context_permission_grants (capacidades nascem do fluxo de Perfis de
-- acesso, superadmin_access_profile_assignment_link) nem audit.audit_logs (cadeia com hash;
-- padrao das fixtures QA R06/R14: funcao versionada + ledger + evidencia).
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'qa r15 guardian fixture must run as postgres';
  end if;
  if to_regclass('public.person_auth_links') is null
    or to_regclass('public.guardian_links') is null
    or to_regclass('public.guardian_context_permissions') is null
    or to_regclass('public.child_unit_links') is null
    or to_regclass('public.child_contexts') is null
    or to_regclass('public.family_relationship_types') is null
    or to_regclass('app_private.superadmin_internal_auth_links') is null then
    raise object_not_in_prerequisite_state using message = 'guardian foundation tables are required';
  end if;
end
$preflight$;

create or replace function app_private.seed_qa_r15_guardian_fixture_v1(
  p_email text default 'qa-r15-responsavel@coelo.me',
  p_guardian_person_id uuid default 'da915f98-bfad-49f6-9914-fe57a30584c9',
  p_child_context_ids uuid[] default array[
    '1a6158fe-6cab-427c-9496-96e4273ab184'::uuid,
    '519ef941-3edb-41b6-94c4-55ed4638aefd'::uuid],
  p_institution_id uuid default 'd0c40000-0000-4000-8000-000000000001',
  p_unit_id uuid default 'd0c40000-0000-4000-8000-000000000002',
  p_relation_type text default 'responsavel'
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_auth_user_id uuid;
  v_guardian public.people%rowtype;
  v_relationship_type_id uuid;
  v_context public.child_contexts%rowtype;
  v_child public.people%rowtype;
  v_link_id uuid;
  v_context_id uuid;
  v_guardian_status_before text;
  v_auth_link text := 'existing';
  v_links_created integer := 0;
  v_links_existing integer := 0;
  v_permissions_created integer := 0;
  v_permissions_existing integer := 0;
  v_unit_links_accepted integer := 0;
  v_unit_links_already_active integer := 0;
  v_contexts jsonb := '[]'::jsonb;
begin
  -- 1. Entrada e conta Auth (criada pelo Owner; nunca por insert em auth.users).
  if v_email = '' or v_email !~ '^qa-r15-[a-z0-9.-]+@coelo\.me$'
     or p_guardian_person_id is null or p_institution_id is null or p_unit_id is null
     or p_child_context_ids is null or cardinality(p_child_context_ids) = 0
     or nullif(btrim(coalesce(p_relation_type, '')), '') is null then
    raise invalid_parameter_value using message = 'invalid_qa_fixture_input';
  end if;
  select u.id into v_auth_user_id from auth.users u where lower(u.email) = v_email;
  if v_auth_user_id is null then
    raise no_data_found using message = 'qa_auth_user_missing', detail = v_email;
  end if;
  if exists (select 1 from app_private.superadmin_internal_auth_links l where l.auth_user_id = v_auth_user_id) then
    raise unique_violation using message = 'qa_auth_user_internal_realm', detail = v_email;
  end if;

  -- 2. Guardas sinteticas: instituicao qa-r04-*, pessoa e criancas com prefixo "QA R15".
  if not exists (
    select 1 from public.institutions i
    where i.id = p_institution_id and i.deleted_at is null and i.slug like 'qa-r04-%'
  ) then
    raise no_data_found using message = 'qa_institution_missing_or_not_synthetic';
  end if;
  if not exists (select 1 from public.units u where u.id = p_unit_id and u.institution_id = p_institution_id) then
    raise no_data_found using message = 'qa_unit_missing';
  end if;
  select * into v_guardian from public.people p where p.id = p_guardian_person_id and p.deleted_at is null;
  if v_guardian.id is null or v_guardian.person_type <> 'adult' or v_guardian.display_name not like 'QA R15%' then
    raise no_data_found using message = 'qa_guardian_person_missing_or_not_synthetic';
  end if;
  select r.id into v_relationship_type_id
  from public.family_relationship_types r where r.code = 'other' and r.status = 'active'
  order by r.created_at limit 1;
  if v_relationship_type_id is null then
    raise no_data_found using message = 'qa_relationship_type_other_missing';
  end if;
  foreach v_context_id in array p_child_context_ids loop
    select * into v_context from public.child_contexts c where c.id = v_context_id;
    if v_context.id is null or v_context.institution_id <> p_institution_id or v_context.status <> 'active' then
      raise no_data_found using message = 'qa_child_context_missing_or_not_synthetic', detail = v_context_id::text;
    end if;
    select * into v_child from public.people p where p.id = v_context.child_person_id and p.deleted_at is null;
    if v_child.id is null or v_child.person_type <> 'child' or v_child.display_name not like 'QA R15%' then
      raise no_data_found using message = 'qa_child_person_missing_or_not_synthetic', detail = v_context_id::text;
    end if;
  end loop;

  -- 3. person_auth_links: um vinculo ativo por pessoa e por auth user.
  perform pg_advisory_xact_lock(hashtextextended('qa-r15-guardian-fixture:' || v_email, 0));
  if exists (
    select 1 from public.person_auth_links l
    where l.person_id = v_guardian.id and l.auth_user_id = v_auth_user_id
      and l.status = 'active' and l.revoked_at is null
  ) then
    v_auth_link := 'existing';
  elsif exists (
    select 1 from public.person_auth_links l
    where l.person_id = v_guardian.id and l.status = 'active' and l.revoked_at is null
  ) then
    raise unique_violation using message = 'qa_guardian_person_already_linked_to_other_auth_user';
  elsif exists (
    select 1 from public.person_auth_links l
    where l.auth_user_id = v_auth_user_id and l.status = 'active'
  ) then
    raise unique_violation using message = 'qa_auth_user_already_linked_to_other_person';
  else
    insert into public.person_auth_links(person_id, auth_user_id, status)
    values (v_guardian.id, v_auth_user_id, 'active');
    v_auth_link := 'created';
  end if;

  -- 4. Pessoa com conta fica ativa (leitores exigem person.status = 'active').
  v_guardian_status_before := v_guardian.status::text;
  if v_guardian.status = 'draft' then
    update public.people set status = 'active', updated_at = now() where id = v_guardian.id;
  end if;

  -- 5. guardian_links + guardian_context_permissions por contexto; aceite do vinculo de unidade.
  foreach v_context_id in array p_child_context_ids loop
    select * into v_context from public.child_contexts c where c.id = v_context_id;
    select g.id into v_link_id from public.guardian_links g
    where g.guardian_person_id = v_guardian.id and g.child_person_id = v_context.child_person_id
      and g.status = 'active' and g.revoked_at is null;
    if v_link_id is null then
      insert into public.guardian_links(
        guardian_person_id, child_person_id, relation_type, relationship_type_id, relationship_detail, status
      ) values (
        v_guardian.id, v_context.child_person_id, btrim(p_relation_type), v_relationship_type_id,
        'Responsável (QA R15)', 'active'
      ) returning id into v_link_id;
      v_links_created := v_links_created + 1;
    else
      v_links_existing := v_links_existing + 1;
    end if;

    if exists (
      select 1 from public.guardian_context_permissions gp
      where gp.guardian_link_id = v_link_id and gp.child_context_id = v_context.id
    ) then
      update public.guardian_context_permissions
         set status = 'active', can_view = true, updated_at = now()
       where guardian_link_id = v_link_id and child_context_id = v_context.id
         and (status <> 'active' or can_view is not true);
      v_permissions_existing := v_permissions_existing + 1;
    else
      insert into public.guardian_context_permissions(
        guardian_link_id, child_context_id, can_view, can_message, can_react, status
      ) values (v_link_id, v_context.id, true, true, true, 'active');
      v_permissions_created := v_permissions_created + 1;
    end if;

    -- mesma transicao de superadmin_student_link: pending -> active com aceite.
    update public.child_unit_links
       set status = 'active', accepted_by = v_guardian.id, accepted_at = coalesce(accepted_at, now()),
           updated_at = now()
     where child_context_id = v_context.id and unit_id = p_unit_id
       and status = 'pending' and revoked_at is null;
    if found then
      v_unit_links_accepted := v_unit_links_accepted + 1;
    elsif exists (
      select 1 from public.child_unit_links l
      where l.child_context_id = v_context.id and l.unit_id = p_unit_id
        and l.status = 'active' and l.revoked_at is null
    ) then
      v_unit_links_already_active := v_unit_links_already_active + 1;
    else
      raise no_data_found using message = 'qa_child_unit_link_missing_or_not_pending', detail = v_context.id::text;
    end if;

    v_contexts := v_contexts || jsonb_build_object(
      'child_context_id', v_context.id, 'child_person_id', v_context.child_person_id,
      'guardian_link_id', v_link_id);
  end loop;

  return jsonb_build_object(
    'email', v_email,
    'auth_user_id', v_auth_user_id,
    'guardian_person_id', v_guardian.id,
    'person_auth_link', v_auth_link,
    'guardian_status_before', v_guardian_status_before,
    'guardian_status_after', 'active',
    'guardian_links_created', v_links_created,
    'guardian_links_existing', v_links_existing,
    'context_permissions_created', v_permissions_created,
    'context_permissions_existing', v_permissions_existing,
    'unit_links_accepted', v_unit_links_accepted,
    'unit_links_already_active', v_unit_links_already_active,
    'contexts', v_contexts
  );
end
$$;

alter function app_private.seed_qa_r15_guardian_fixture_v1(text, uuid, uuid[], uuid, uuid, text) owner to postgres;
revoke all on function app_private.seed_qa_r15_guardian_fixture_v1(text, uuid, uuid[], uuid, uuid, text)
  from public, anon, authenticated, service_role;

do $postcheck$
begin
  if to_regprocedure('app_private.seed_qa_r15_guardian_fixture_v1(text,uuid,uuid[],uuid,uuid,text)') is null then
    raise object_not_in_prerequisite_state using message = 'qa r15 guardian fixture was not created';
  end if;
  if has_function_privilege('anon', 'app_private.seed_qa_r15_guardian_fixture_v1(text,uuid,uuid[],uuid,uuid,text)', 'execute')
     or has_function_privilege('authenticated', 'app_private.seed_qa_r15_guardian_fixture_v1(text,uuid,uuid[],uuid,uuid,text)', 'execute')
     or has_function_privilege('service_role', 'app_private.seed_qa_r15_guardian_fixture_v1(text,uuid,uuid[],uuid,uuid,text)', 'execute') then
    raise object_not_in_prerequisite_state using message = 'qa r15 guardian fixture must not be exposed';
  end if;
end
$postcheck$;

commit;
