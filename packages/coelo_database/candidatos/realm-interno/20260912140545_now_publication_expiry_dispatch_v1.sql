-- R08 realm-interno: dispara a transicao material de publicacoes Agora
-- vencidas. As leituras ja falham fechadas por expires_at; este job apenas
-- materializa status/auditoria pelo sweep existente, sem apagar midia R2.

do $$
begin
  if to_regnamespace('cron') is null then
    raise exception using
      errcode = '55000',
      message = 'pg_cron is required for Agora expiry dispatch';
  end if;

  if to_regprocedure(
    'app_private.sweep_expired_now_publications(uuid,integer)'
  ) is null then
    raise exception using
      errcode = '55000',
      message = 'Agora expiry sweep must exist before its dispatch';
  end if;

  if exists (
    select 1 from cron.job
    where jobname = 'coelo-now-publications-expire'
  ) then
    perform cron.unschedule('coelo-now-publications-expire');
  end if;

  perform cron.schedule(
    'coelo-now-publications-expire',
    '*/5 * * * *',
    'select app_private.sweep_expired_now_publications(null::uuid, 500);'
  );
end;
$$;
