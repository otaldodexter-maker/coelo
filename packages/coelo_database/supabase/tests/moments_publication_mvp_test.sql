begin;

create extension if not exists pgtap with schema extensions;

select plan(30);

select has_table('public', 'moments_publications', 'Momentos publications exist');
select has_table('public', 'moments_publication_audiences', 'Momentos audiences exist');
select has_table('public', 'moments_media_assets', 'Momentos R2 metadata exists');
select has_table('public', 'moments_media_links', 'Momentos media links exist');
select has_table('app_private', 'moments_command_receipts', 'Momentos receipts exist');
select has_table('app_private', 'moments_media_finalize_tickets', 'private finalize tickets exist');
select has_table('app_private', 'moments_publication_audit', 'Momentos audit exists');

select has_function('public', 'load_moments_draft', array['uuid', 'uuid', 'uuid'], 'draft query exists');
select has_function('public', 'save_moments_draft', array['uuid', 'jsonb', 'uuid', 'bigint'], 'draft save exists');
select has_function(
  'public', 'prepare_moments_media_upload',
  array['uuid', 'uuid', 'uuid', 'text', 'text', 'bigint', 'bigint'],
  'R2 upload preparation exists'
);
select has_function('public', 'authorize_moments_media_finalize', array['uuid'], 'user finalize authorization exists');
select has_function(
  'public', 'finalize_moments_media_upload',
  array['uuid', 'uuid', 'uuid', 'bigint', 'text', 'text', 'text', 'bigint'],
  'service finalize exists'
);
select has_function('public', 'authorize_moments_media_read', array['uuid'], 'author read authorization exists');
select has_function('public', 'publish_moment', array['uuid', 'uuid', 'bigint'], 'publish command exists');
select has_function('public', 'claim_stale_moments_media', array['integer'], 'cleanup claim wrapper exists');
select has_function('public', 'mark_moments_media_deleted', array['uuid'], 'cleanup completion wrapper exists');

select ok(
  (select relrowsecurity and relforcerowsecurity
   from pg_class where oid = 'public.moments_publications'::regclass),
  'publications force RLS'
);
select ok(
  (select relrowsecurity and relforcerowsecurity
   from pg_class where oid = 'public.moments_publication_audiences'::regclass),
  'audiences force RLS'
);
select ok(
  (select relrowsecurity and relforcerowsecurity
   from pg_class where oid = 'public.moments_media_assets'::regclass),
  'assets force RLS'
);
select ok(
  (select relrowsecurity and relforcerowsecurity
   from pg_class where oid = 'public.moments_media_links'::regclass),
  'links force RLS'
);

select ok(
  has_function_privilege('authenticated', 'public.authorize_moments_media_finalize(uuid)', 'EXECUTE'),
  'authenticated author may request a finalize ticket'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.finalize_moments_media_upload(uuid,uuid,uuid,bigint,text,text,text,bigint)',
    'EXECUTE'
  ),
  'authenticated client cannot finalize metadata directly'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.finalize_moments_media_upload(uuid,uuid,uuid,bigint,text,text,text,bigint)',
    'EXECUTE'
  ),
  'only the Edge service can finalize metadata'
);
select ok(
  has_function_privilege('service_role', 'public.claim_stale_moments_media(integer)', 'EXECUTE'),
  'service role can claim stale R2 objects'
);
select ok(
  not has_function_privilege('authenticated', 'public.claim_stale_moments_media(integer)', 'EXECUTE'),
  'authenticated client cannot claim cleanup jobs'
);
select ok(
  position('2 minutes' in pg_get_functiondef(
    'public.authorize_moments_media_finalize(uuid)'::regprocedure
  )) > 0,
  'finalize ticket expires after two minutes'
);
select ok(
  position('delete from app_private.moments_media_finalize_tickets' in pg_get_functiondef(
    'public.finalize_moments_media_upload(uuid,uuid,uuid,bigint,text,text,text,bigint)'::regprocedure
  )) > 0,
  'finalize consumes the authorization ticket'
);
select ok(
  position('p_actor_auth_user_id' in pg_get_function_arguments(
    'public.finalize_moments_media_upload(uuid,uuid,uuid,bigint,text,text,text,bigint)'::regprocedure
  )) = 0,
  'service finalize never trusts a caller-supplied actor id'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.moments_media_assets'::regclass
      and pg_get_constraintdef(oid) like '%storage_provider%cloudflare_r2%'
  ),
  'Momentos operational media metadata is bound to private R2'
);
select ok(
  position('storage.buckets' in pg_get_functiondef(
    'public.prepare_moments_media_upload(uuid,uuid,uuid,text,text,bigint,bigint)'::regprocedure
  )) = 0,
  'Momentos upload never provisions Supabase Storage'
);

select * from finish();
rollback;
