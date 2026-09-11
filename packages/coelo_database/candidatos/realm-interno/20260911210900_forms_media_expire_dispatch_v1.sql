-- R05 realm-interno (10): cron de expiracao dos arquivos de Formularios (imagem de pergunta e resposta).
--
-- Dispara a Edge Function form-media (action "expire") a cada 5 minutos, no
-- mesmo padrao de app_private.notice_dispatch_publication_worker (230023):
-- URL e segredo compartilhado ficam no Vault (forms_media_worker_url,
-- forms_media_worker_secret) e a funcao devolve null enquanto faltarem, entao
-- o job pode ser agendado antes do deploy. O segredo e o mesmo valor gravado
-- como FORMS_MEDIA_WORKER_SECRET nos secrets da funcao (coordenador grava os
-- dois a partir de um arquivo local depois apagado; valor nunca em chat).
-- A funcao chat-media chama form_media_expire_question_r2_v1 + claim_cleanup + mark_purged (service_role).

create or replace function app_private.forms_media_dispatch_expire_worker()
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
    from vault.decrypted_secrets where name = 'forms_media_worker_url' limit 1;
  select decrypted_secret into worker_secret
    from vault.decrypted_secrets where name = 'forms_media_worker_secret' limit 1;
  if nullif(worker_url, '') is null or nullif(worker_secret, '') is null then
    return null;
  end if;
  select net.http_post(
    url := worker_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-worker-secret', worker_secret
    ),
    body := '{"action":"expire"}'::jsonb,
    timeout_milliseconds := 5000
  ) into request_id;
  return request_id;
end;
$$;

alter function app_private.forms_media_dispatch_expire_worker() owner to postgres;
revoke all on function app_private.forms_media_dispatch_expire_worker() from public, anon, authenticated, service_role;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'coelo-forms-media-expire') then
    perform cron.unschedule('coelo-forms-media-expire');
  end if;
  perform cron.schedule(
    'coelo-forms-media-expire',
    '*/10 * * * *',
    'select app_private.forms_media_dispatch_expire_worker();'
  );
end;
$$;
