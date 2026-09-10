begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

-- Existência das funções de expiração do Agora.
select has_function(
  'app_private','sweep_expired_now_publications',array['uuid','integer'],
  'the Agora expiry sweep exists'
);
select has_function(
  'public','expire_due_now_publications',array['uuid'],
  'the authorized Agora expiry trigger exists'
);

-- Contrato de execução: security definer com search_path fechado.
select ok(
  (select prosecdef from pg_proc
   where oid='app_private.sweep_expired_now_publications(uuid,integer)'::regprocedure),
  'the Agora expiry sweep runs as security definer'
);
select ok(
  (select prosecdef from pg_proc
   where oid='public.expire_due_now_publications(uuid)'::regprocedure),
  'the authorized Agora expiry trigger runs as security definer'
);
select ok(
  (select coalesce(proconfig,'{}'::text[]) @> array['search_path=""']::text[]
   from pg_proc
   where oid='app_private.sweep_expired_now_publications(uuid,integer)'::regprocedure),
  'the Agora expiry sweep pins an empty search_path'
);
select ok(
  (select coalesce(proconfig,'{}'::text[]) @> array['search_path=""']::text[]
   from pg_proc
   where oid='public.expire_due_now_publications(uuid)'::regprocedure),
  'the authorized Agora expiry trigger pins an empty search_path'
);

-- Grants: a varredura é de sistema, o acionamento é de ator autorizado.
select ok(
  has_function_privilege(
    'service_role',
    'app_private.sweep_expired_now_publications(uuid,integer)',
    'EXECUTE'
  ),
  'only the service role drives the system-wide Agora expiry sweep'
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
  'clients never call the global Agora expiry sweep'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.expire_due_now_publications(uuid)',
    'EXECUTE'
  ),
  'authenticated actors may trigger the scoped Agora expiry'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.expire_due_now_publications(uuid)',
    'EXECUTE'
  ),
  'anonymous callers never trigger the Agora expiry'
);

-- O acionamento público exige a permissão de publicação do módulo.
select ok(
  position(
    'now.publications.publish' in
    pg_get_functiondef('public.expire_due_now_publications(uuid)'::regprocedure)
  )>0,
  'the scoped Agora expiry trigger demands the module publish permission'
);
select ok(
  position(
    'sweep_expired_now_publications' in
    pg_get_functiondef('public.expire_due_now_publications(uuid)'::regprocedure)
  )>0,
  'the scoped Agora expiry trigger delegates to the audited sweep'
);

-- A varredura transiciona estado; nunca apaga publicação nem mídia.
select ok(
  position(
    'delete' in
    lower(pg_get_functiondef(
      'app_private.sweep_expired_now_publications(uuid,integer)'::regprocedure
    ))
  )=0
  and position(
    'now_media_assets' in
    pg_get_functiondef(
      'app_private.sweep_expired_now_publications(uuid,integer)'::regprocedure
    )
  )=0,
  'the Agora expiry sweep never deletes publications or media'
);
select ok(
  position(
    'publication_expired' in
    pg_get_functiondef(
      'app_private.sweep_expired_now_publications(uuid,integer)'::regprocedure
    )
  )>0,
  'the Agora expiry sweep writes one audit event per transitioned publication'
);

-- Leitura consistente com o estado material.
select ok(
  position(
    'publication.status<>''expired''' in
    pg_get_functiondef('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure)
  )>0
  and position(
    'publication.expires_at>now()' in
    pg_get_functiondef('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure)
  )>0,
  'the Agora feed excludes expired state and keeps the temporal window'
);
select ok(
  position(
    'publication.status<>''expired''' in
    pg_get_functiondef('public.redeem_now_media_read_ticket(uuid,uuid)'::regprocedure)
  )>0
  and position(
    'publication.expires_at>now()' in
    pg_get_functiondef('public.redeem_now_media_read_ticket(uuid,uuid)'::regprocedure)
  )>0,
  'ticket redemption excludes expired state and keeps the temporal window'
);

select * from finish();
rollback;
