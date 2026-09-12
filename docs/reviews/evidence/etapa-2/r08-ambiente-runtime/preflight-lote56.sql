begin;

create extension if not exists pgtap with schema extensions;
select plan(20);

select ok(
  to_regprocedure('app_private.has_platform_permission(text,uuid)') is not null,
  'has_platform_permission(text,uuid) existe'
);

select ok(
  lower(pg_get_functiondef('app_private.has_platform_permission(text,uuid)'::regprocedure)) like '%institution_id is null and not internal_actor.is_internal%'
  and lower(pg_get_functiondef('app_private.has_platform_permission(text,uuid)'::regprocedure)) like '%not internal_actor.is_internal%',
  'has_platform_permission preserva o ramo final de plataforma do lote 50'
);

select ok(
  to_regprocedure('app_private.superadmin_internal_actor_scope_targets()') is not null
  and pg_get_function_result('app_private.superadmin_internal_actor_scope_targets()'::regprocedure)
    = 'TABLE(person_id uuid, institution_id uuid, institution_status text)',
  'scope_targets tem a assinatura final do hotfix lote 52'
);

select ok(
  lower(pg_get_functiondef('app_private.superadmin_internal_actor_scope_targets()'::regprocedure)) like '%inst.deleted_at is null%'
  and lower(pg_get_functiondef('app_private.superadmin_internal_actor_scope_targets()'::regprocedure)) not like '%inst.status = ''active''%',
  'scope_targets inclui instituicao nao apagada sem restringir o alvo a active'
);

select ok(
  to_regprocedure('app_private.superadmin_internal_actor_scope_reactivate_v1()') is not null,
  'reativador final do lote 52 existe'
);

select is(
  has_function_privilege('anon', 'app_private.superadmin_internal_actor_scope_reactivate_v1()', 'execute'),
  false,
  'anon nao executa o reativador'
);

select is(
  has_function_privilege('authenticated', 'app_private.superadmin_internal_actor_scope_reactivate_v1()', 'execute'),
  false,
  'authenticated nao executa o reativador'
);

select is(
  has_function_privilege('service_role', 'app_private.superadmin_internal_actor_scope_reactivate_v1()', 'execute'),
  false,
  'service_role nao executa o reativador'
);

select ok(
  to_regprocedure('app_private.superadmin_internal_actor_institution_access_sync()') is not null,
  'sincronizador compartilhado existe'
);

select ok(
  lower(pg_get_functiondef('app_private.superadmin_internal_actor_institution_access_sync()'::regprocedure)) like '%create temp table internal_actor_targets%'
  and lower(pg_get_functiondef('app_private.superadmin_internal_actor_institution_access_sync()'::regprocedure)) like '%superadmin_internal_actor_scope_targets()%'
  and lower(pg_get_functiondef('app_private.superadmin_internal_actor_institution_access_sync()'::regprocedure)) like '%when ''owner'' then ''owner''%'
  and lower(pg_get_functiondef('app_private.superadmin_internal_actor_institution_access_sync()'::regprocedure)) like '%when ''operations'' then ''professional''%'
  and lower(pg_get_functiondef('app_private.superadmin_internal_actor_institution_access_sync()'::regprocedure)) like '%when ''owner'' then admin_role_id%'
  and lower(pg_get_functiondef('app_private.superadmin_internal_actor_institution_access_sync()'::regprocedure)) like '%when ''operations'' then reader_role_id%',
  'sincronizador e a forma final do lote 55 sobre scope_targets'
);

select is(
  (
    select count(*)::integer
    from pg_proc p
    where p.oid in (
      'app_private.has_platform_permission(text,uuid)'::regprocedure,
      'app_private.superadmin_internal_actor_scope_targets()'::regprocedure,
      'app_private.superadmin_internal_actor_scope_reactivate_v1()'::regprocedure,
      'app_private.superadmin_internal_actor_institution_access_sync()'::regprocedure
    )
      and p.prosecdef
  ),
  4,
  'as quatro funcoes usam security definer'
);

select is(
  (
    select count(*)::integer
    from pg_proc p
    where p.oid in (
      'app_private.has_platform_permission(text,uuid)'::regprocedure,
      'app_private.superadmin_internal_actor_scope_targets()'::regprocedure,
      'app_private.superadmin_internal_actor_scope_reactivate_v1()'::regprocedure,
      'app_private.superadmin_internal_actor_institution_access_sync()'::regprocedure
    )
      and exists (
        select 1 from unnest(p.proconfig) setting where setting like 'search_path=%'
      )
  ),
  4,
  'as quatro funcoes fixam search_path'
);

select is(
  has_function_privilege('anon', 'app_private.superadmin_internal_actor_institution_access_sync()', 'execute'),
  false,
  'anon nao executa o sincronizador'
);

select is(
  has_function_privilege('authenticated', 'app_private.superadmin_internal_actor_institution_access_sync()', 'execute'),
  false,
  'authenticated nao executa o sincronizador'
);

select is(
  (
    select count(*)::integer
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = 'app_private.superadmin_internal_actor_institution_access_sync()'::regprocedure
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  0,
  'PUBLIC nao executa o sincronizador'
);

select cmp_ok(
  (
    select count(*)::integer
    from public.institution_role_permissions rp
    join public.institution_roles r on r.id = rp.role_id
      and r.code = 'institution_reader' and r.is_system and r.institution_id is null
    join public.institution_permissions p on p.id = rp.permission_id
    where rp.status = 'active' and rp.revoked_at is null and p.code like '%.read'
  ),
  '>',
  5,
  'institution_reader tem permissoes de leitura ativas'
);

select is(
  (
    select count(*)::integer
    from public.institution_role_permissions rp
    join public.institution_roles r on r.id = rp.role_id
      and r.code = 'institution_reader' and r.is_system and r.institution_id is null
    join public.institution_permissions p on p.id = rp.permission_id
    where rp.status = 'active' and rp.revoked_at is null and p.code not like '%.read'
  ),
  0,
  'institution_reader nao tem permissao ativa fora de leitura'
);

select ok(to_regclass('cron.job') is not null, 'pg_cron e cron.job estao disponiveis para o lote 56');

select ok(
  to_regprocedure('app_private.sweep_expired_now_publications(uuid,integer)') is not null,
  'sweep de publicacoes Agora exigido pelo candidato do lote 56 existe'
);

select is(
  (
    select count(*)::integer
    from cron.job
    where jobname = 'coelo-now-publications-expire'
       or command like '%sweep_expired_now_publications%'
  ),
  0,
  'estado preflight: nenhum job de expiracao Agora preexistente no espelho'
);

select * from finish();
rollback;
