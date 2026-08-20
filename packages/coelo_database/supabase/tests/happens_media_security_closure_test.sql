begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

select has_function(
  'public','finalize_happens_media_upload',
  array['uuid','uuid','text','bigint'],
  'finalization function remains available'
);
select has_function(
  'public','remove_happens_media',array['uuid'],
  'removal function remains available'
);
select ok(
  position('post_id=p_post_id' in replace(pg_get_functiondef(
    'public.finalize_happens_media_upload(uuid,uuid,text,bigint)'::regprocedure
  ),' ',''))>0,
  'finalization binds the asset to the requested post'
);
select ok(
  position('target.unit_id,target.group_id' in replace(pg_get_functiondef(
    'public.finalize_happens_media_upload(uuid,uuid,text,bigint)'::regprocedure
  ),' ',''))>0,
  'finalization authorizes with the post scope'
);
select ok(
  position('asset.status=''ready''' in replace(pg_get_functiondef(
    'public.finalize_happens_media_upload(uuid,uuid,text,bigint)'::regprocedure
  ),' ',''))>0,
  'finalization accepts an exact ready receipt retry'
);
select ok(
  position('target.status<>''draft''' in replace(pg_get_functiondef(
    'public.remove_happens_media(uuid)'::regprocedure
  ),' ',''))>0,
  'removal rejects media outside a draft'
);
select ok(
  position('target.unit_id,target.group_id' in replace(pg_get_functiondef(
    'public.remove_happens_media(uuid)'::regprocedure
  ),' ',''))>0,
  'removal authorizes with the owning post scope'
);

select * from finish();
rollback;
