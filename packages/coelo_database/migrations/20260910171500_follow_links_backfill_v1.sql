-- D1, complemento: o 171100 (em producao no lote 12) so materializa o
-- acompanhamento automatico por gatilho, isto e, para vinculos criados
-- DEPOIS dele. Contextos de crianca que ja existiam (a crianca sintetica
-- 'Crianca QA R04' foi cadastrada antes do lote 12) ficaram sem linhas:
-- follow_summary devolve 0 seguidores para a instituicao dela.
--
-- Este pacote recalcula, uma vez e de forma idempotente, o automatico de
-- todos os contextos de crianca existentes usando a mesma funcao de
-- sincronizacao dos gatilhos. Rodar de novo nao duplica (a funcao insere so
-- o que falta e revoga so o que sobra). Linhas manuais nunca sao tocadas.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '300s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'follow_links backfill must run as postgres';
  end if;
  if to_regclass('public.follow_links') is null
     or to_regprocedure('app_private.follow_links_sync_child_context(uuid)') is null then
    raise object_not_in_prerequisite_state using
      message = 'follow_links (20260910171100) is required before the backfill';
  end if;
end
$preflight$;

create or replace function app_private.follow_links_backfill_all()
returns integer
language plpgsql
security definer
set search_path to ''
as $$
declare
  synced integer := 0;
  context_id uuid;
begin
  for context_id in select ctx.id from public.child_contexts ctx order by ctx.created_at, ctx.id loop
    perform app_private.follow_links_sync_child_context(context_id);
    synced := synced + 1;
  end loop;
  return synced;
end
$$;

revoke all on function app_private.follow_links_backfill_all() from public, anon, authenticated;

select app_private.follow_links_backfill_all();

commit;
