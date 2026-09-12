begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select ok(
  to_regprocedure(
    'app_private.sweep_expired_now_publications(uuid,integer)'
  ) is not null,
  'the Agora expiry sweep dependency exists'
);

select is(
  (select count(*) from cron.job
   where jobname = 'coelo-now-publications-expire'),
  1::bigint,
  'exactly one Agora expiry job is scheduled'
);

select is(
  (select schedule from cron.job
   where jobname = 'coelo-now-publications-expire'),
  '*/5 * * * *',
  'the Agora expiry job runs every five minutes'
);

select is(
  (select command from cron.job
   where jobname = 'coelo-now-publications-expire'),
  'select app_private.sweep_expired_now_publications(null::uuid, 500);',
  'the job invokes only the bounded internal sweep'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.sweep_expired_now_publications(uuid,integer)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'app_private.sweep_expired_now_publications(uuid,integer)',
    'EXECUTE'
  ),
  'clients cannot execute the system-wide sweep'
);

select ok(
  position(
    'delete' in lower(pg_get_functiondef(
      'app_private.sweep_expired_now_publications(uuid,integer)'::regprocedure
    ))
  ) = 0,
  'the scheduled sweep never deletes publication or media rows'
);

select * from finish();
rollback;
