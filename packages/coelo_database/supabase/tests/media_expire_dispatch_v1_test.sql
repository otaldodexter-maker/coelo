-- crons de expiracao de midia (chat-media e form-media): job agendado e funcao
-- que devolve null enquanto o Vault nao tiver URL/segredo (nada e chamado).
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);
select ok(exists (select 1 from cron.job where jobname='coelo-chat-media-expire' and schedule='*/5 * * * *'),'cron do chat-media agendado a cada 5 min');
select ok(exists (select 1 from cron.job where jobname='coelo-forms-media-expire' and schedule='*/10 * * * *'),'cron do form-media agendado a cada 10 min');
select is(app_private.chat_media_dispatch_expire_worker(),null,'sem Vault o dispatch do chat-media devolve null');
select is(app_private.forms_media_dispatch_cleanup_worker(),null,'sem Vault o dispatch do form-media devolve null');
select ok(not has_function_privilege('authenticated','app_private.chat_media_dispatch_expire_worker()','execute')
  and not has_function_privilege('anon','app_private.chat_media_dispatch_expire_worker()','execute'),'dispatch do chat-media sem grant a cliente');
select ok(not has_function_privilege('authenticated','app_private.forms_media_dispatch_cleanup_worker()','execute')
  and not has_function_privilege('service_role','app_private.forms_media_dispatch_cleanup_worker()','execute'),'dispatch do form-media sem grant a cliente');
select * from finish();
rollback;
