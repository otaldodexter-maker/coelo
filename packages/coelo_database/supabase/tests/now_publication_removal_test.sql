begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select extensions.plan(15);

select extensions.has_type('public', 'now_publication_status', 'the Agora status type exists');
select ok(
  exists(
    select 1
    from pg_enum
    where enumtypid='public.now_publication_status'::regtype
      and enumlabel='removed'
  ),
  'the Agora status includes immediate removal'
);
select extensions.has_column(
  'public', 'now_publications', 'removed_at',
  'Agora publications record the immediate removal time'
);
select extensions.has_column(
  'public', 'now_publications', 'removed_by_person_id',
  'Agora publications record the remover'
);
select extensions.has_column(
  'public', 'now_publications', 'removal_reason',
  'Agora publications record the sanitized removal reason'
);
select extensions.has_function(
  'public', 'remove_now_publication',
  array['uuid','uuid','bigint','text'],
  'the Agora immediate removal RPC exists'
);
select ok(
  (select prosecdef from pg_proc
   where oid='public.remove_now_publication(uuid,uuid,bigint,text)'::regprocedure),
  'the removal RPC runs with a closed security boundary'
);
select ok(
  (select coalesce(proconfig,'{}'::text[]) @> array['search_path=""']::text[]
   from pg_proc
   where oid='public.remove_now_publication(uuid,uuid,bigint,text)'::regprocedure),
  'the removal RPC pins an empty search_path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.remove_now_publication(uuid,uuid,bigint,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.remove_now_publication(uuid,uuid,bigint,text)',
    'EXECUTE'
  ),
  'only authenticated actors can request immediate removal'
);
select ok(
  position('now.publications.remove' in
    pg_get_functiondef('public.remove_now_publication(uuid,uuid,bigint,text)'::regprocedure)
  )>0,
  'the removal RPC checks the official action capability'
);
select ok(
  position('removed_at' in
    pg_get_functiondef('public.remove_now_publication(uuid,uuid,bigint,text)'::regprocedure)
  )>0
  and position('now_publication_audit' in
    pg_get_functiondef('public.remove_now_publication(uuid,uuid,bigint,text)'::regprocedure)
  )>0,
  'the removal RPC materializes state and writes audit'
);
select ok(
  position('now_media_read_tickets' in
    pg_get_functiondef('public.remove_now_publication(uuid,uuid,bigint,text)'::regprocedure)
  )>0
  and position('now_media_purge_jobs' in
    pg_get_functiondef('public.remove_now_publication(uuid,uuid,bigint,text)'::regprocedure)
  )>0,
  'the removal RPC invalidates tickets and queues media purge'
);
select extensions.has_function(
  'public', 'claim_now_media_purge_jobs', array['text','integer'],
  'the server-only purge claim RPC exists'
);
select extensions.has_function(
  'public', 'record_now_media_purge_result', array['bigint','boolean','text'],
  'the server-only purge result RPC exists'
);
select ok(
  (select relrowsecurity and relforcerowsecurity
   from pg_class where oid='app_private.now_media_purge_jobs'::regclass)
  and has_function_privilege(
    'service_role', 'public.claim_now_media_purge_jobs(text,integer)', 'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated', 'public.claim_now_media_purge_jobs(text,integer)', 'EXECUTE'
  ),
  'purge descriptors are private and service-only'
);

select * from extensions.finish();
rollback;
