begin;

create extension if not exists pgtap with schema extensions;

select plan(23);

-- Contracts exist with the expected signatures.
select has_function(
  'public', 'list_visible_moments',
  array['uuid', 'uuid', 'uuid', 'integer', 'timestamp with time zone'],
  'Momentos consumer feed exists'
);
select has_function(
  'public', 'withdraw_moment',
  array['uuid', 'uuid', 'bigint', 'text'],
  'Momentos withdrawal command exists'
);
select has_function(
  'app_private', 'moments_audience_matches_role',
  array['text', 'public.moments_audience_kind'],
  'Momentos audience matcher exists'
);

-- Both new contracts are definer-owned with a pinned empty search_path.
select ok(
  (select prosecdef from pg_proc
   where oid = 'public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)'::regprocedure),
  'feed runs as security definer'
);
select ok(
  (select prosecdef from pg_proc
   where oid = 'public.withdraw_moment(uuid,uuid,bigint,text)'::regprocedure),
  'withdrawal runs as security definer'
);
select ok(
  (select proconfig::text like '%search_path=%'
   from pg_proc
   where oid = 'public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)'::regprocedure),
  'feed pins an empty search_path'
);
select ok(
  (select proconfig::text like '%search_path=%'
   from pg_proc
   where oid = 'public.withdraw_moment(uuid,uuid,bigint,text)'::regprocedure),
  'withdrawal pins an empty search_path'
);

-- Withdrawal state columns.
select has_column('public', 'moments_publications', 'withdrawn_at', 'withdrawal timestamp exists');
select has_column(
  'public', 'moments_publications', 'withdrawn_by_person_id', 'withdrawal author exists'
);
select has_column(
  'public', 'moments_publications', 'withdrawal_reason', 'withdrawal reason exists'
);
select col_is_null(
  'public', 'moments_publications', 'withdrawn_at', 'withdrawal timestamp stays optional'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.moments_publications'::regclass
      and pg_get_constraintdef(oid) ilike '%withdrawn_at is null%'
      and pg_get_constraintdef(oid) ilike '%published%'
  ),
  'only published moments may carry a withdrawal'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.moments_publications'::regclass
      and pg_get_constraintdef(oid) ilike '%withdrawal_reason%'
      and pg_get_constraintdef(oid) ilike '%280%'
  ),
  'withdrawal reason is bounded to 280 characters'
);

-- Catalogued permission for removal.
select ok(
  exists (
    select 1 from public.institution_permissions
    where code = 'moments.publications.remove'
      and module_code = 'moments'
      and screen_code = 'publications'
      and action_code = 'remove'
      and status = 'active'
  ),
  'removal permission is catalogued and active'
);

-- Authorization and audit are wired inside the withdrawal command.
select ok(
  position('moments.publications.remove' in pg_get_functiondef(
    'public.withdraw_moment(uuid,uuid,bigint,text)'::regprocedure
  )) > 0,
  'withdrawal authorizes against the removal permission'
);
select ok(
  position('app_private.moments_publication_audit' in pg_get_functiondef(
    'public.withdraw_moment(uuid,uuid,bigint,text)'::regprocedure
  )) > 0
  and position('publication_withdrawn' in pg_get_functiondef(
    'public.withdraw_moment(uuid,uuid,bigint,text)'::regprocedure
  )) > 0,
  'withdrawal records the publication_withdrawn audit event'
);
select ok(
  position('for update' in pg_get_functiondef(
    'public.withdraw_moment(uuid,uuid,bigint,text)'::regprocedure
  )) > 0,
  'withdrawal locks the target row'
);
select ok(
  position('delete from public.moments_publications' in pg_get_functiondef(
    'public.withdraw_moment(uuid,uuid,bigint,text)'::regprocedure
  )) = 0
  and position('delete from public.moments_media' in pg_get_functiondef(
    'public.withdraw_moment(uuid,uuid,bigint,text)'::regprocedure
  )) = 0,
  'withdrawal is soft and never deletes publications or media'
);
select ok(
  position('moments.publications.read' in pg_get_functiondef(
    'public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)'::regprocedure
  )) > 0,
  'feed authorizes against the read permission'
);
select ok(
  position('withdrawn_at is null' in pg_get_functiondef(
    'public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)'::regprocedure
  )) > 0,
  'feed excludes withdrawn moments'
);
select ok(
  position('object_key' in pg_get_functiondef(
    'public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)'::regprocedure
  )) = 0
  and position('bucket_id' in pg_get_functiondef(
    'public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)'::regprocedure
  )) = 0,
  'feed never projects storage keys or buckets'
);

-- Grants stay minimal.
select ok(
  has_function_privilege(
    'authenticated',
    'public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated', 'public.withdraw_moment(uuid,uuid,bigint,text)', 'EXECUTE'
  ),
  'authenticated actors may call both contracts'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.list_visible_moments(uuid,uuid,uuid,integer,timestamptz)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon', 'public.withdraw_moment(uuid,uuid,bigint,text)', 'EXECUTE'
  ),
  'anonymous callers are denied both contracts'
);

select * from finish();
rollback;
