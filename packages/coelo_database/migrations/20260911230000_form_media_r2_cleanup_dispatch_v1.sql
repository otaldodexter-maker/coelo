-- 20260911230000_form_media_r2_cleanup_dispatch_v1
-- Frente R05 · Formulários, Cuidado e Rotina. Sugestão para o coordenador.
--
-- Dispara o worker de expiração/limpeza das imagens de pergunta no R2
-- (Edge Function form-media, ação `cleanup`: form_media_expire_question_r2_v1
-- + form_media_claim_cleanup_r2_v1 + DELETE no R2 + form_media_mark_purged_r2_v1,
-- lote 33) a cada 5 minutos, no mesmo padrão de
-- app_private.notice_dispatch_publication_worker e form_dispatch_operations_worker.
--
-- Nenhum segredo entra aqui. A função lê do Vault:
--   * form_media_worker_url    -> URL da Edge Function form-media
--                                 (https://<ref>.supabase.co/functions/v1/form-media)
--   * forms_worker_bearer_token -> o MESMO bearer já usado por form-operations;
--                                 form-media compara em tempo constante com
--                                 FORMS_OPERATIONS_BEARER_TOKEN (secret já
--                                 existente nas Edge Functions).
-- Sem os dois valores a função devolve null e o cron não faz nada.
--
-- Pré-requisito: `supabase functions deploy form-media` com o índice migrado e
-- o segredo `form_media_worker_url` criado no Vault (sem custo; regra de
-- 11/09/2026 do Owner: criar sem perguntar). Reversão: cron.unschedule e drop
-- da função.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if to_regprocedure('public.form_media_claim_cleanup_r2_v1(integer)') is null
    or to_regprocedure('public.form_media_expire_question_r2_v1(integer)') is null then
    raise exception 'preflight: lote 33 (forms_question_media_r2_v1) nao aplicado';
  end if;
end
$preflight$;

create or replace function app_private.form_media_dispatch_cleanup_worker()
returns bigint
language plpgsql
security definer
set search_path to ''
as $$
declare worker_url text;
declare bearer_token text;
declare request_id bigint;
begin
  select decrypted_secret into worker_url
    from vault.decrypted_secrets where name = 'form_media_worker_url' limit 1;
  select decrypted_secret into bearer_token
    from vault.decrypted_secrets where name = 'forms_worker_bearer_token' limit 1;
  if nullif(worker_url, '') is null or nullif(bearer_token, '') is null then
    return null;
  end if;
  select net.http_post(
    url := worker_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || bearer_token
    ),
    body := '{"action":"cleanup"}'::jsonb,
    timeout_milliseconds := 5000
  ) into request_id;
  return request_id;
end;
$$;

alter function app_private.form_media_dispatch_cleanup_worker() owner to postgres;
revoke all on function app_private.form_media_dispatch_cleanup_worker()
  from public, anon, authenticated, service_role;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'coelo-form-media-r2-cleanup') then
    perform cron.unschedule('coelo-form-media-r2-cleanup');
  end if;
  perform cron.schedule(
    'coelo-form-media-r2-cleanup',
    '*/5 * * * *',
    'select app_private.form_media_dispatch_cleanup_worker();'
  );
end;
$$;

commit;
