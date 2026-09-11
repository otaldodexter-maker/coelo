-- Rodada 4 (E2-R04-20260911), P30 decidido pelo Owner em 11/09/2026.
-- Dispara o worker de publicacao de notices (Edge Function notice-publication-worker)
-- a cada minuto, no mesmo padrao de app_private.form_dispatch_operations_worker.
-- Nenhum segredo entra aqui: URL e segredo compartilhado ficam no Vault
-- (notices_worker_url, notices_worker_secret) e a funcao devolve null se faltarem.

create or replace function app_private.notice_dispatch_publication_worker()
returns bigint
language plpgsql
security definer
set search_path to ''
as $$
declare worker_url text;
declare worker_secret text;
declare request_id bigint;
begin
  select decrypted_secret into worker_url
    from vault.decrypted_secrets where name = 'notices_worker_url' limit 1;
  select decrypted_secret into worker_secret
    from vault.decrypted_secrets where name = 'notices_worker_secret' limit 1;
  if nullif(worker_url, '') is null or nullif(worker_secret, '') is null then
    return null;
  end if;
  select net.http_post(
    url := worker_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-coelo-worker-secret', worker_secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 5000
  ) into request_id;
  return request_id;
end;
$$;

alter function app_private.notice_dispatch_publication_worker() owner to postgres;
revoke all on function app_private.notice_dispatch_publication_worker() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'coelo-notices-worker-dispatch') then
    perform cron.unschedule('coelo-notices-worker-dispatch');
  end if;
  perform cron.schedule(
    'coelo-notices-worker-dispatch',
    '* * * * *',
    'select app_private.notice_dispatch_publication_worker();'
  );
end;
$$;
