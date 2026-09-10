-- Cardapios: excluir cardapio, com recibo e revisao otimista.
--
-- O Owner pediu em 10/09/2026, ao decidir os goldens do diretorio, que o menu
-- de acoes tenha editar, duplicar, arquivar e excluir. Arquivar ja tinha
-- caminho de servidor desde 20260820230000; excluir nao tinha nenhum: existia
-- a policy meal_plans_delete, mas nenhuma RPC, e a tela abria um dialogo que
-- dizia "a exclusao de cardapio nao esta disponivel nesta versao".
--
-- A exclusao segue o mesmo contrato das demais escritas da familia: recibo por
-- ator e request_id, revisao otimista e escopo revalidado no servidor.
--
-- Regra de estado adotada aqui, e ainda sujeita a confirmacao do Owner: so sai
-- do banco o que nunca chegou ao publico -- rascunho e em revisao -- ou o que
-- ja foi arquivado. Um cardapio publicado ou agendado precisa ser arquivado
-- antes, que e exatamente o proposito de arquivar; apagar direto sumiria com o
-- historico de algo que familias ja viram.
begin;

-- O recibo apontava para o cardapio com `not null` e `on delete restrict`, o
-- que tornava a exclusao impossivel mesmo com policy: a propria trilha de
-- auditoria segurava a linha. A referencia passa a aceitar nulo e a se anular
-- quando o cardapio sai, de modo que o recibo do comando sobrevive ao objeto
-- que ele descreve -- que e justamente o que uma trilha precisa fazer.
alter table app_private.meal_plan_command_receipts
  drop constraint if exists meal_plan_command_receipts_meal_plan_id_fkey;
alter table app_private.meal_plan_command_receipts
  alter column meal_plan_id drop not null;
alter table app_private.meal_plan_command_receipts
  add constraint meal_plan_command_receipts_meal_plan_id_fkey
  foreign key (meal_plan_id) references public.meal_plans(id) on delete set null;

create or replace function public.meal_plan_delete(
  p_request_id text,
  p_meal_plan_id uuid,
  p_expected_revision integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := app_private.current_person_id();
  stored_plan public.meal_plans%rowtype;
  request_hash text;
  receipt app_private.meal_plan_command_receipts%rowtype;
  result_payload jsonb;
begin
  if auth.uid() is null or actor_id is null
      or not app_private.has_platform_permission('meal_plans.manage') then
    raise insufficient_privilege using message = 'meal_plans.manage required';
  end if;
  if nullif(btrim(coalesce(p_request_id, '')), '') is null
      or length(p_request_id) > 200 then
    raise invalid_parameter_value using message = 'invalid meal plan request id';
  end if;
  select candidate.* into stored_plan
  from public.meal_plans candidate
  where candidate.id = p_meal_plan_id
    and app_private.meal_plan_scope_allowed(
      candidate.tenant_id, candidate.institution_id
    )
  for update;
  if not found then raise no_data_found using message = 'meal plan not found'; end if;

  request_hash := app_private.meal_plan_request_hash(jsonb_build_object(
    'command', 'delete',
    'meal_plan_id', p_meal_plan_id,
    'expected_revision', p_expected_revision
  ));
  perform pg_advisory_xact_lock(
    hashtextextended(actor_id::text || ':' || p_request_id, 0)
  );
  select candidate.* into receipt
  from app_private.meal_plan_command_receipts candidate
  where candidate.actor_person_id = actor_id
    and candidate.request_id = p_request_id;
  if found then
    if receipt.command_name <> 'delete'
        or receipt.payload_hash <> request_hash then
      raise invalid_parameter_value using message = 'idempotency key reused';
    end if;
    return receipt.result_json;
  end if;

  -- O recibo e gravado ANTES do delete: a linha some, entao meal_plan_json
  -- precisa do estado que existia, e o recibo nao pode depender de uma FK para
  -- um cardapio que deixou de existir.
  if stored_plan.revision <> p_expected_revision then
    raise exception 'meal plan revision or status conflict' using errcode = 'P0003';
  end if;
  if stored_plan.status not in ('draft', 'inReview', 'archived') then
    raise exception 'meal plan must be archived before deletion' using errcode = 'P0003';
  end if;
  result_payload := public.meal_plan_json(stored_plan) || jsonb_build_object('deleted', true);
  insert into app_private.meal_plan_command_receipts (
    actor_person_id, request_id, command_name, meal_plan_id,
    payload_hash, result_json
  ) values (
    actor_id, p_request_id, 'delete', null,
    request_hash, result_payload
  );

  delete from public.meal_plans where id = p_meal_plan_id;
  return result_payload;
end;
$function$;

revoke all on function public.meal_plan_delete(text, uuid, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.meal_plan_delete(text, uuid, integer)
  to authenticated;

commit;
