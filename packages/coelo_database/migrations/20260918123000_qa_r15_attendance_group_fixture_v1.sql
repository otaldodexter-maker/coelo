-- 20260918123000_qa_r15_attendance_group_fixture_v1
--
-- R16 Sessao RESERVA / decisao D4 do Owner em 18/09/2026 (R16-prompt-reserva-20260918.md,
-- lote 82 item c; ADR 0041 D6 revogada por D4): massa sintetica "QA R15" para a prova de
-- owner.r12-08 (attendance.mark/correct/finish com >=2 alunos em MULTIPLAS turmas).
--
-- Em producao a Turma QA R04 Estrutura (editada) ja tem 3 criancas ativas (Crianca QA R04 +
-- "QA R15 Crianca 1/2", fixture AP-1); a segunda turma do escopo de qa-r06-operacoes, Turma
-- QA R06 Transferencia (1a247741, Unidade QA R05 Transferencia cce78909), nao tem aluno. A
-- tela cria criancas mas deixa child_unit_links PENDENTES, e superadmin_attendance_create_call
-- so deriva participantes de vinculos de unidade ATIVOS: por isso a fixture.
--
-- Esta migration so CRIA a funcao privada app_private.seed_qa_r15_attendance_group_fixture_v1
-- (sem grant a anon/authenticated/service_role; invisivel ao PostgREST). A execucao e um
-- passo separado, como postgres:
--   select app_private.seed_qa_r15_attendance_group_fixture_v1();
-- Idempotente por (instituicao, display_name): rodar duas vezes nao duplica pessoa, contexto
-- nem vinculo. Fail-closed: instituicao fora de qa-r04-*, turma fora da unidade/instituicao,
-- turma sem "QA" no nome ou nome de crianca sem prefixo "QA R15" interrompem sem gravar.
-- O que grava por crianca: people (child, active, date_of_birth), child_contexts (active),
-- child_unit_links (active, accepted_by = pessoa tecnica Coelo Sistema, accepted_at = now()),
-- child_group_links (active, sem starts_at/ends_at). Nao grava responsaveis, permissoes nem
-- audit.audit_logs (padrao das fixtures QA R06/R14/R15: funcao versionada + ledger + evidencia).
-- Forward-only; reversao manual = remover as linhas com display_name 'QA R15 Crianca 3/4'.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'qa r15 attendance group fixture must run as postgres';
  end if;
  if to_regclass('public.people') is null
    or to_regclass('public.child_contexts') is null
    or to_regclass('public.child_unit_links') is null
    or to_regclass('public.child_group_links') is null
    or to_regclass('public.groups') is null then
    raise object_not_in_prerequisite_state using message = 'child foundation tables are required';
  end if;
end
$preflight$;

create or replace function app_private.seed_qa_r15_attendance_group_fixture_v1(
  p_institution_id uuid default 'd0c40000-0000-4000-8000-000000000001',
  p_unit_id uuid default 'cce78909-0745-4b2e-9baf-24681080c22d',
  p_group_id uuid default '1a247741-1bc8-4bbd-bf81-a0787d57f77a',
  p_child_names text[] default array['QA R15 Crianca 3', 'QA R15 Crianca 4'],
  p_accepted_by uuid default 'c0e10000-0000-4000-8000-000000000001'
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_group public.groups%rowtype;
  v_name text;
  v_first text;
  v_last text;
  v_person_id uuid;
  v_context_id uuid;
  v_unit_link_id uuid;
  v_group_link_id uuid;
  v_people_created integer := 0;
  v_people_existing integer := 0;
  v_contexts_created integer := 0;
  v_unit_links_created integer := 0;
  v_unit_links_activated integer := 0;
  v_group_links_created integer := 0;
  v_children jsonb := '[]'::jsonb;
  v_index integer := 0;
begin
  -- 1. Entrada.
  if p_institution_id is null or p_unit_id is null or p_group_id is null
     or p_child_names is null or cardinality(p_child_names) = 0 or p_accepted_by is null then
    raise invalid_parameter_value using message = 'invalid_qa_fixture_input';
  end if;
  foreach v_name in array p_child_names loop
    if nullif(btrim(coalesce(v_name, '')), '') is null or btrim(v_name) not like 'QA R15%' then
      raise invalid_parameter_value using message = 'qa_child_name_not_synthetic', detail = coalesce(v_name, '<null>');
    end if;
  end loop;

  -- 2. Guardas sinteticas: instituicao qa-r04-*, unidade da instituicao, turma "QA" da unidade.
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
     or v_group.status <> 'active' or v_group.name not ilike '%QA%' then
    raise no_data_found using message = 'qa_group_missing_or_not_synthetic';
  end if;
  if not exists (select 1 from public.people p where p.id = p_accepted_by and p.deleted_at is null) then
    raise no_data_found using message = 'qa_accepted_by_person_missing';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('qa-r15-attendance-group-fixture:' || p_group_id::text, 0));

  -- 3. Por crianca: pessoa -> contexto -> vinculo de unidade ativo -> vinculo de turma ativo.
  foreach v_name in array p_child_names loop
    v_index := v_index + 1;
    v_name := btrim(v_name);
    v_first := split_part(v_name, ' ', 1) || ' ' || split_part(v_name, ' ', 2);
    v_last := nullif(btrim(substr(v_name, length(v_first) + 1)), '');

    select p.id into v_person_id from public.people p
    where p.person_type = 'child' and p.deleted_at is null and p.display_name = v_name
      and exists (select 1 from public.child_contexts c where c.child_person_id = p.id and c.institution_id = p_institution_id)
    order by p.created_at limit 1;
    if v_person_id is null then
      insert into public.people(person_type, first_name, last_name, display_name, status, date_of_birth)
      values ('child', v_first, coalesce(v_last, 'QA'), v_name, 'active', date '2021-03-01' + (v_index * interval '1 month'))
      returning id into v_person_id;
      v_people_created := v_people_created + 1;
    else
      v_people_existing := v_people_existing + 1;
      update public.people set status = 'active', updated_at = now()
      where id = v_person_id and status <> 'active';
    end if;

    select c.id into v_context_id from public.child_contexts c
    where c.child_person_id = v_person_id and c.institution_id = p_institution_id
    order by c.created_at limit 1;
    if v_context_id is null then
      insert into public.child_contexts(child_person_id, institution_id, status)
      values (v_person_id, p_institution_id, 'active')
      returning id into v_context_id;
      v_contexts_created := v_contexts_created + 1;
    else
      update public.child_contexts set status = 'active', archived_at = null, updated_at = now()
      where id = v_context_id and status <> 'active';
    end if;

    select l.id into v_unit_link_id from public.child_unit_links l
    where l.child_context_id = v_context_id and l.unit_id = p_unit_id and l.revoked_at is null
    order by l.created_at limit 1;
    if v_unit_link_id is null then
      insert into public.child_unit_links(child_context_id, unit_id, status, accepted_by, accepted_at)
      values (v_context_id, p_unit_id, 'active', p_accepted_by, now())
      returning id into v_unit_link_id;
      v_unit_links_created := v_unit_links_created + 1;
    elsif exists (select 1 from public.child_unit_links l where l.id = v_unit_link_id and l.status <> 'active') then
      update public.child_unit_links
        set status = 'active', accepted_by = coalesce(accepted_by, p_accepted_by),
            accepted_at = coalesce(accepted_at, now()), updated_at = now()
      where id = v_unit_link_id;
      v_unit_links_activated := v_unit_links_activated + 1;
    end if;

    select g.id into v_group_link_id from public.child_group_links g
    where g.child_unit_link_id = v_unit_link_id and g.group_id = p_group_id
    order by g.created_at limit 1;
    if v_group_link_id is null then
      insert into public.child_group_links(child_unit_link_id, group_id, status)
      values (v_unit_link_id, p_group_id, 'active')
      returning id into v_group_link_id;
      v_group_links_created := v_group_links_created + 1;
    else
      update public.child_group_links set status = 'active', ends_at = null, updated_at = now()
      where id = v_group_link_id and (status <> 'active' or ends_at is not null);
    end if;

    v_children := v_children || jsonb_build_object(
      'display_name', v_name, 'person_id', v_person_id, 'child_context_id', v_context_id,
      'child_unit_link_id', v_unit_link_id, 'child_group_link_id', v_group_link_id);
  end loop;

  return jsonb_build_object(
    'group_id', p_group_id, 'unit_id', p_unit_id, 'institution_id', p_institution_id,
    'people_created', v_people_created, 'people_existing', v_people_existing,
    'contexts_created', v_contexts_created,
    'unit_links_created', v_unit_links_created, 'unit_links_activated', v_unit_links_activated,
    'group_links_created', v_group_links_created,
    'active_children_in_group', (
      select count(*) from public.child_group_links cg
      join public.child_unit_links cu on cu.id = cg.child_unit_link_id and cu.status = 'active' and cu.revoked_at is null
      join public.child_contexts cc on cc.id = cu.child_context_id and cc.status = 'active'
      where cg.group_id = p_group_id and cg.status = 'active'),
    'children', v_children);
end $$;

alter function app_private.seed_qa_r15_attendance_group_fixture_v1(uuid,uuid,uuid,text[],uuid) owner to postgres;
revoke all on function app_private.seed_qa_r15_attendance_group_fixture_v1(uuid,uuid,uuid,text[],uuid)
  from public, anon, authenticated, service_role;

do $postcheck$
begin
  if to_regprocedure('app_private.seed_qa_r15_attendance_group_fixture_v1(uuid,uuid,uuid,text[],uuid)') is null then
    raise object_not_in_prerequisite_state using message = 'seed_qa_r15_attendance_group_fixture_v1 was not created';
  end if;
end
$postcheck$;

commit;
