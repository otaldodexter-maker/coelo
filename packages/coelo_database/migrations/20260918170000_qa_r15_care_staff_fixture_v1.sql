-- 20260918170000_qa_r15_care_staff_fixture_v1
--
-- R16 Sessao RESERVA / autorizacao do Owner em 18/09/2026 (resposta ao bloqueio de owner.r12-33 no
-- R16-handoff-reserva.md: "autorizar a fixture"). Lote 83.
--
-- Por que: o tenant sintetico QA R04 Cuidado (d0c40000-...0001) so tem memberships de pessoas de
-- servico (Operador interno ..., Dextec SaaS), que por regra nunca sao destinatarias de sino
-- (child_care_notification_recipients_v1 / medication_notification_recipients_v2 exigem
-- person_type = 'adult'). Sem uma pessoa humana de equipe, o caminho "admin da unidade e educador da
-- turma recebem plano atualizado / dose registrada" (spec 053, ADR 0041 B8) nao pode ser observado em
-- producao.
--
-- Esta migration so CRIA a funcao privada app_private.seed_qa_r15_care_staff_fixture_v1 (sem grant a
-- anon/authenticated/service_role; invisivel ao PostgREST). A execucao e um passo separado, como postgres:
--   select app_private.seed_qa_r15_care_staff_fixture_v1();
-- Cria duas pessoas adultas ativas com prefixo "QA R15" e uma membership ativa cada, sem conta de login
-- (a convencao do projeto veda insert em auth.users; contas sao criadas pelo Owner na Auth Admin):
--   * "QA R15 Admin Unidade"   -> role_code 'institution_admin', scope 'unit'  na Unidade QA R04;
--   * "QA R15 Educadora Turma" -> role_code 'teacher',           scope 'group' na Turma QA R04 Estrutura.
-- Sem institution_role_assignments (a audiencia do sino deriva da membership, nao de capacidades).
-- Idempotente por (display_name, instituicao). Fail-closed: instituicao fora de qa-r04-*, unidade/turma
-- fora da instituicao ou nomes sem prefixo "QA R15" interrompem sem gravar. Nao grava audit.audit_logs
-- (padrao das fixtures QA R06/R14/R15: funcao versionada + ledger + evidencia).
-- Forward-only; reversao manual = revogar as duas memberships e apagar as duas pessoas.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'qa r15 care staff fixture must run as postgres';
  end if;
  if to_regclass('public.people') is null or to_regclass('public.institution_memberships') is null
    or to_regclass('public.units') is null or to_regclass('public.groups') is null then
    raise object_not_in_prerequisite_state using message = 'membership foundation tables are required';
  end if;
end
$preflight$;

create or replace function app_private.seed_qa_r15_care_staff_fixture_v1(
  p_institution_id uuid default 'd0c40000-0000-4000-8000-000000000001',
  p_unit_id uuid default 'd0c40000-0000-4000-8000-000000000002',
  p_group_id uuid default '368a5cea-2bcf-4fa4-ad1f-18da58694551',
  p_admin_name text default 'QA R15 Admin Unidade',
  p_teacher_name text default 'QA R15 Educadora Turma'
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_group public.groups%rowtype;
  v_spec record;
  v_person_id uuid;
  v_membership_id uuid;
  v_people_created integer := 0;
  v_people_existing integer := 0;
  v_memberships_created integer := 0;
  v_memberships_reactivated integer := 0;
  v_staff jsonb := '[]'::jsonb;
begin
  if p_institution_id is null or p_unit_id is null or p_group_id is null
     or nullif(btrim(coalesce(p_admin_name, '')), '') is null
     or nullif(btrim(coalesce(p_teacher_name, '')), '') is null then
    raise invalid_parameter_value using message = 'invalid_qa_fixture_input';
  end if;
  if btrim(p_admin_name) not like 'QA R15%' or btrim(p_teacher_name) not like 'QA R15%' then
    raise invalid_parameter_value using message = 'qa_staff_name_not_synthetic';
  end if;
  if not exists (
    select 1 from public.institutions i
    where i.id = p_institution_id and i.deleted_at is null and i.slug like 'qa-r04-%'
  ) then
    raise no_data_found using message = 'qa_institution_missing_or_not_synthetic';
  end if;
  if not exists (select 1 from public.units u where u.id = p_unit_id and u.institution_id = p_institution_id) then
    raise no_data_found using message = 'qa_unit_missing';
  end if;
  select * into v_group from public.groups g where g.id = p_group_id;
  if v_group.id is null or v_group.institution_id <> p_institution_id or v_group.unit_id <> p_unit_id
     or v_group.status <> 'active' then
    raise no_data_found using message = 'qa_group_missing_or_not_synthetic';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('qa-r15-care-staff-fixture:' || p_institution_id::text, 0));

  for v_spec in
    select * from (values
      (btrim(p_admin_name), 'institution_admin', 'unit', p_unit_id, null::uuid, 1),
      (btrim(p_teacher_name), 'teacher', 'group', p_unit_id, p_group_id, 2)
    ) as t(display_name, role_code, scope_kind, scope_unit_id, scope_group_id, ord)
    order by ord
  loop
    select p.id into v_person_id from public.people p
    where p.person_type = 'adult' and p.deleted_at is null and p.display_name = v_spec.display_name
      and exists (select 1 from public.institution_memberships m
                  where m.person_id = p.id and m.institution_id = p_institution_id)
    order by p.created_at limit 1;
    if v_person_id is null then
      -- pessoa nova: sem membership previa nesta instituicao com esse nome
      select p.id into v_person_id from public.people p
      where p.person_type = 'adult' and p.deleted_at is null and p.display_name = v_spec.display_name
        and p.display_name like 'QA R15%'
      order by p.created_at limit 1;
    end if;
    if v_person_id is null then
      insert into public.people(person_type, first_name, last_name, display_name, status)
      values ('adult', split_part(v_spec.display_name, ' ', 1) || ' ' || split_part(v_spec.display_name, ' ', 2),
              btrim(substr(v_spec.display_name, length(split_part(v_spec.display_name, ' ', 1) || ' ' || split_part(v_spec.display_name, ' ', 2)) + 1)),
              v_spec.display_name, 'active')
      returning id into v_person_id;
      v_people_created := v_people_created + 1;
    else
      v_people_existing := v_people_existing + 1;
      update public.people set status = 'active', updated_at = now() where id = v_person_id and status <> 'active';
    end if;

    select m.id into v_membership_id from public.institution_memberships m
    where m.person_id = v_person_id and m.institution_id = p_institution_id
      and m.role_code = v_spec.role_code and m.scope_kind = v_spec.scope_kind
      and m.scope_unit_id is not distinct from v_spec.scope_unit_id
      and m.scope_group_id is not distinct from v_spec.scope_group_id
    order by m.created_at limit 1;
    if v_membership_id is null then
      insert into public.institution_memberships(person_id, institution_id, role_code, scope_kind, scope_unit_id, scope_group_id, status)
      values (v_person_id, p_institution_id, v_spec.role_code, v_spec.scope_kind, v_spec.scope_unit_id, v_spec.scope_group_id, 'active')
      returning id into v_membership_id;
      v_memberships_created := v_memberships_created + 1;
    elsif exists (select 1 from public.institution_memberships m where m.id = v_membership_id and (m.status <> 'active' or m.revoked_at is not null)) then
      update public.institution_memberships set status = 'active', revoked_at = null where id = v_membership_id;
      v_memberships_reactivated := v_memberships_reactivated + 1;
    end if;

    v_staff := v_staff || jsonb_build_object(
      'display_name', v_spec.display_name, 'person_id', v_person_id, 'membership_id', v_membership_id,
      'role_code', v_spec.role_code, 'scope_kind', v_spec.scope_kind);
  end loop;

  return jsonb_build_object(
    'institution_id', p_institution_id, 'unit_id', p_unit_id, 'group_id', p_group_id,
    'people_created', v_people_created, 'people_existing', v_people_existing,
    'memberships_created', v_memberships_created, 'memberships_reactivated', v_memberships_reactivated,
    'staff', v_staff);
end $$;

alter function app_private.seed_qa_r15_care_staff_fixture_v1(uuid,uuid,uuid,text,text) owner to postgres;
revoke all on function app_private.seed_qa_r15_care_staff_fixture_v1(uuid,uuid,uuid,text,text)
  from public, anon, authenticated, service_role;

do $postcheck$
begin
  if to_regprocedure('app_private.seed_qa_r15_care_staff_fixture_v1(uuid,uuid,uuid,text,text)') is null then
    raise object_not_in_prerequisite_state using message = 'seed_qa_r15_care_staff_fixture_v1 was not created';
  end if;
end
$postcheck$;

commit;
