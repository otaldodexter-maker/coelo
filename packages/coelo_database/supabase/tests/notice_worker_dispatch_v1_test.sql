begin;
select plan(5);
select has_function('app_private', 'notice_dispatch_publication_worker', array[]::text[], 'funcao de dispatch existe');
select function_privs_are('app_private', 'notice_dispatch_publication_worker', array[]::text[], 'anon', array[]::text[], 'anon nao executa o dispatch');
select function_privs_are('app_private', 'notice_dispatch_publication_worker', array[]::text[], 'authenticated', array[]::text[], 'authenticated nao executa o dispatch');
select is((select count(*)::int from cron.job where jobname = 'coelo-notices-worker-dispatch' and schedule = '* * * * *'), 1, 'cron a cada minuto agendado');
select is((select command from cron.job where jobname = 'coelo-notices-worker-dispatch'), 'select app_private.notice_dispatch_publication_worker();', 'cron chama a funcao de dispatch');
select * from finish();
rollback;
