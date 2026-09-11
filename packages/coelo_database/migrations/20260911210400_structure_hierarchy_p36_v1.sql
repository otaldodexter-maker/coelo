-- R05 realm-interno (5): P36 no servidor — hierarquia instituicao -> unidade
-- -> turma -> atividade (ADR 0034, Decisao 15, P36).
--
-- O que a baseline ja garante (medido em 11/09 no descartavel = producao):
--   * unidade sem instituicao: units.institution_id NOT NULL + FK.
--   * turma sem unidade: groups.unit_id NOT NULL + FK composta
--     (unit_id, institution_id) -> units(id, institution_id): a turma nao
--     pode apontar para unidade de outra instituicao.
--   * atividade fora de unidade: activity_unit_links com FK composta e o
--     gatilho diferido activity_definition_requires_unit /
--     activity_unit_links_retain_one (toda atividade mantem ao menos um
--     vinculo de unidade ativo); activity_group_links com FK composta
--     (group_id, institution_id, unit_id) -> groups e (activity_id,
--     institution_id, unit_id) -> activity_unit_links: a turma vinculada e da
--     mesma unidade que a atividade.
--
-- O que faltava (este pacote): atividade ATIVA fora de turma. Rascunho pode
-- existir so com unidade (o assistente cria o rascunho com instituicao +
-- unidade e liga a turma antes de publicar); ao ficar `active`, a atividade
-- precisa de ao menos um activity_group_links ativo, e o ultimo vinculo de
-- turma ativo de uma atividade ativa nao pode ser encerrado/removido.
-- Gatilhos de restricao diferidos (mesma tecnica de requires_unit), com
-- mensagem estavel `activity must retain at least one active group link`
-- (23514) para o cliente mapear.
--
-- Linhas existentes que ja violem a regra nao bloqueiam a aplicacao: sao
-- listadas em NOTICE para a frente estrutura corrigir (producao em 11/09 so
-- tem atividades sinteticas da frente).
--
-- Reversao: drop trigger activity_definition_requires_group on
-- public.activity_definitions; drop trigger activity_group_links_retain_one
-- on public.activity_group_links; drop function
-- app_private.enforce_activity_active_group_v1().

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'P36 migration must run as postgres';
  end if;
  if to_regclass('public.activity_definitions') is null or to_regclass('public.activity_group_links') is null
    or to_regclass('public.groups') is null or to_regclass('public.units') is null
    or not exists (select 1 from pg_constraint where conname = 'groups_unit_institution_fkey')
    or not exists (select 1 from pg_constraint where conname = 'activity_group_links_group_fkey')
    or not exists (select 1 from pg_trigger where tgname = 'activity_definition_requires_unit') then
    raise object_not_in_prerequisite_state using
      message = 'structure hierarchy foundations (units, groups, activity links, requires_unit) are required';
  end if;
end
$preflight$;

create or replace function app_private.enforce_activity_active_group_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_data jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  target_activity_id uuid := coalesce((row_data ->> 'activity_id')::uuid, (row_data ->> 'id')::uuid);
begin
  if not exists (
    select 1 from public.activity_definitions activity
    where activity.id = target_activity_id and activity.status = 'active'
  ) then
    return coalesce(new, old);
  end if;
  if not exists (
    select 1 from public.activity_group_links group_link
    where group_link.activity_id = target_activity_id
      and group_link.status = 'active'
      and (group_link.ends_at is null or group_link.ends_at > pg_catalog.now())
  ) then
    raise check_violation using
      message = 'activity must retain at least one active group link',
      detail = 'P36_ACTIVITY_REQUIRES_GROUP';
  end if;
  return coalesce(new, old);
end
$$;

revoke all on function app_private.enforce_activity_active_group_v1()
  from public, anon, authenticated, service_role;
alter function app_private.enforce_activity_active_group_v1() owner to postgres;

do $violations$
declare offenders text;
begin
  select string_agg(activity.id::text, ', ') into offenders
  from public.activity_definitions activity
  where activity.status = 'active'
    and not exists (
      select 1 from public.activity_group_links group_link
      where group_link.activity_id = activity.id and group_link.status = 'active'
        and (group_link.ends_at is null or group_link.ends_at > pg_catalog.now()));
  if offenders is not null then
    raise notice 'P36: atividades ativas sem turma ativa (corrigir pela frente estrutura): %', offenders;
  end if;
end
$violations$;

drop trigger if exists activity_definition_requires_group on public.activity_definitions;
create constraint trigger activity_definition_requires_group
  after insert or update of status on public.activity_definitions
  deferrable initially deferred
  for each row execute function app_private.enforce_activity_active_group_v1();

drop trigger if exists activity_group_links_retain_one on public.activity_group_links;
create constraint trigger activity_group_links_retain_one
  after insert or delete or update on public.activity_group_links
  deferrable initially deferred
  for each row execute function app_private.enforce_activity_active_group_v1();

comment on function app_private.enforce_activity_active_group_v1() is
  'P36 (ADR 0034 Decisao 15): atividade ativa mantem ao menos um vinculo de turma ativo; rascunho pode existir so com unidade.';

commit;
