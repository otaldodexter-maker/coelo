-- Somente leitura; nenhum comando de cron ou segredo e projetado.
select
  current_timestamp as measured_at,
  to_regclass('cron.job') is not null as cron_available,
  to_regprocedure('app_private.sweep_expired_now_publications(uuid,integer)') is not null as sweep_available,
  (select count(*) from cron.job where jobname = 'coelo-now-publications-expire'
    or command like '%sweep_expired_now_publications%') as existing_expiry_jobs,
  (select count(*) from supabase_migrations.schema_migrations where version = '20260912140545') as candidate_ledger_count;
