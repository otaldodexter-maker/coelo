-- SOMENTE espelho local. Reconciliacao focal com ACLs medidas em producao.
-- Os jobs preexistentes em producao ficam DESATIVADOS no espelho: nenhum
-- dispatcher remoto, segredo ou chamada de rede e necessario para este gate.
begin;
revoke execute on function public.form_worker_export_snapshot(uuid,uuid,integer) from authenticated;
revoke execute on function public.form_worker_begin_multipart(uuid,text,uuid,text,text,text) from authenticated;
revoke execute on function public.form_worker_record_multipart_part(uuid,text,uuid,text,integer,text,bigint,text) from authenticated;
revoke execute on function public.form_worker_complete_multipart(uuid,text,uuid,text) from authenticated;
revoke execute on function public.form_worker_abort_multipart(uuid,text,uuid,text) from authenticated;
revoke execute on function public.form_worker_multipart_snapshot(uuid,text,uuid) from authenticated;
revoke execute on function public.form_worker_claim_notification(text,integer) from authenticated;
revoke update on public.context_notification_recipients from authenticated;
grant update(read_at) on public.context_notification_recipients to authenticated;
select cron.schedule('coelo-forms-occurrences','*/5 * * * *','select app_private.form_run_periodic_maintenance();');
select cron.schedule('coelo-forms-reminders','2-59/5 * * * *','select app_private.form_enqueue_due_reminders(interval ''24 hours'');');
select cron.schedule('coelo-forms-worker-dispatch','* * * * *','select app_private.form_dispatch_operations_worker();');
do $$declare job_row record; begin
 for job_row in select jobid from cron.job where jobname like 'coelo-forms-%' loop
  perform cron.alter_job(job_row.jobid,active:=false);
 end loop;
end $$;
commit;
