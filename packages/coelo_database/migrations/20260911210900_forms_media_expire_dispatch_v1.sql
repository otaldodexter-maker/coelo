-- R05 realm-interno (10): cron de expiracao e limpeza dos arquivos de
-- Formularios no R2 (imagem de pergunta hoje; respostas quando
-- COELO_FORMS_MEDIA_PROVIDER=r2 for ligada).
--
-- Dispara a Edge Function form-media com action "cleanup" (expira pendentes,
-- reivindica a fila de limpeza, apaga no R2 e baixa) a cada 10 minutos, no
-- mesmo padrao de app_private.form_dispatch_operations_worker: a funcao
-- autentica o worker por `Authorization: Bearer <FORMS_OPERATIONS_BEARER_TOKEN>`
-- (o mesmo token compartilhado que ja esta no Vault como
-- forms_worker_bearer_token) e a URL entra no Vault como
-- forms_media_worker_url (o coordenador grava no deploy). Sem URL ou token a
-- funcao devolve null e nada e chamado.

create or replace function app_private.forms_media_dispatch_cleanup_worker()
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
    from vault.decrypted_secrets where name = 'forms_media_worker_url' limit 1;
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

alter function app_private.forms_media_dispatch_cleanup_worker() owner to postgres;
revoke all on function app_private.forms_media_dispatch_cleanup_worker() from public, anon, authenticated, service_role;
drop function if exists app_private.forms_media_dispatch_expire_worker();

do $$
begin
  if exists (select 1 from cron.job where jobname = 'coelo-forms-media-expire') then
    perform cron.unschedule('coelo-forms-media-expire');
  end if;
  perform cron.schedule(
    'coelo-forms-media-expire',
    '*/10 * * * *',
    'select app_private.forms_media_dispatch_cleanup_worker();'
  );
end;
$$;
