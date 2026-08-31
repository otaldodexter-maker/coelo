-- Normalize replay-only label sentinels and restore the canonical no-default
-- contract. On environments that never used the replay bridge this is a no-op.

begin;

do $$
begin
  if (
    select count(*) <> 3
    from pg_catalog.pg_class relation
    join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname in (
        'platform_permissions',
        'institution_permissions',
        'platform_role_permissions'
      )
      and relation.relkind in ('r', 'p')
      and pg_catalog.pg_get_userbyid(relation.relowner) = 'postgres'
  ) or (
    select count(*) <> 6
    from pg_catalog.pg_attribute attribute
    join pg_catalog.pg_class relation on relation.oid = attribute.attrelid
    join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname in ('platform_permissions', 'institution_permissions')
      and attribute.attname in ('module_label', 'screen_label', 'action_label')
      and attribute.attnum > 0
      and not attribute.attisdropped
      and attribute.atttypid = 'pg_catalog.text'::pg_catalog.regtype
      and attribute.attnotnull
  ) or exists (
    select 1
    from pg_catalog.pg_attribute attribute
    join pg_catalog.pg_class relation on relation.oid = attribute.attrelid
    join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
    join pg_catalog.pg_attrdef definition
      on definition.adrelid = attribute.attrelid
     and definition.adnum = attribute.attnum
    where namespace.nspname = 'public'
      and relation.relname in ('platform_permissions', 'institution_permissions')
      and attribute.attname in ('module_label', 'screen_label', 'action_label')
      and pg_catalog.pg_get_expr(definition.adbin, definition.adrelid)
          <> '''__replay_legacy__''::text'
  ) or exists (
    select 1
    from pg_catalog.pg_attribute attribute
    join pg_catalog.pg_class relation on relation.oid = attribute.attrelid
    join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
    left join pg_catalog.pg_attrdef definition
      on definition.adrelid = attribute.attrelid
     and definition.adnum = attribute.attnum
    where namespace.nspname = 'public'
      and relation.relname = 'platform_role_permissions'
      and attribute.attname = 'updated_at'
      and (
        attribute.attnum <= 0
        or attribute.attisdropped
        or attribute.atttypid <> 'timestamp with time zone'::pg_catalog.regtype
        or not attribute.attnotnull
        or definition.oid is null
        or pg_catalog.pg_get_expr(definition.adbin, definition.adrelid) <> 'now()'
      )
  ) or pg_catalog.to_regprocedure(
    'app_private.assert_permission_label_replay_contract()'
  ) is not null then
    raise exception using
      errcode = '55000',
      message = 'unexpected permission label replay contract';
  end if;
end;
$$;

alter table public.platform_role_permissions
  add column if not exists updated_at timestamptz not null default now();

create or replace function app_private.assert_permission_label_replay_contract()
returns void
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if (
    select count(*) <> 3
    from pg_catalog.pg_class relation
    join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname in (
        'platform_permissions',
        'institution_permissions',
        'platform_role_permissions'
      )
      and relation.relkind in ('r', 'p')
      and pg_catalog.pg_get_userbyid(relation.relowner) = 'postgres'
  ) then
    raise exception using
      errcode = '55000',
      message = 'unexpected permission label replay contract';
  end if;

  if (
    select count(*) <> 6
    from pg_catalog.pg_attribute attribute
    join pg_catalog.pg_class relation on relation.oid = attribute.attrelid
    join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname in ('platform_permissions', 'institution_permissions')
      and attribute.attname in ('module_label', 'screen_label', 'action_label')
      and attribute.attnum > 0
      and not attribute.attisdropped
      and attribute.atttypid = 'pg_catalog.text'::pg_catalog.regtype
      and attribute.attnotnull
  ) then
    raise exception using
      errcode = '55000',
      message = 'unexpected permission label replay contract';
  end if;

  if exists (
    select 1
    from pg_catalog.pg_attribute attribute
    join pg_catalog.pg_class relation on relation.oid = attribute.attrelid
    join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
    join pg_catalog.pg_attrdef definition
      on definition.adrelid = attribute.attrelid
     and definition.adnum = attribute.attnum
    where namespace.nspname = 'public'
      and relation.relname in ('platform_permissions', 'institution_permissions')
      and attribute.attname in ('module_label', 'screen_label', 'action_label')
      and pg_catalog.pg_get_expr(definition.adbin, definition.adrelid)
          <> '''__replay_legacy__''::text'
  ) then
    raise exception using
      errcode = '55000',
      message = 'unexpected permission label replay contract';
  end if;

  if (
    select count(*) <> 1
    from pg_catalog.pg_attribute attribute
    join pg_catalog.pg_class relation on relation.oid = attribute.attrelid
    join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
    join pg_catalog.pg_attrdef definition
      on definition.adrelid = attribute.attrelid
     and definition.adnum = attribute.attnum
    where namespace.nspname = 'public'
      and relation.relname = 'platform_role_permissions'
      and attribute.attname = 'updated_at'
      and attribute.attnum > 0
      and not attribute.attisdropped
      and attribute.atttypid = 'timestamp with time zone'::pg_catalog.regtype
      and attribute.attnotnull
      and pg_catalog.pg_get_expr(definition.adbin, definition.adrelid) = 'now()'
  ) then
    raise exception using
      errcode = '55000',
      message = 'unexpected permission label replay contract';
  end if;
end;
$$;

alter function app_private.assert_permission_label_replay_contract() owner to postgres;
revoke all on function app_private.assert_permission_label_replay_contract() from public;
revoke all on function app_private.assert_permission_label_replay_contract() from anon;
revoke all on function app_private.assert_permission_label_replay_contract() from authenticated;
revoke all on function app_private.assert_permission_label_replay_contract() from service_role;

select app_private.assert_permission_label_replay_contract();

update public.platform_permissions permission_record
set module_label = case permission_record.module_code
      when 'activities' then 'Atividades'
      when 'analytics' then 'Indicadores'
      when 'audit' then 'Auditoria'
      when 'child_safety' then 'Segurança da criança'
      when 'groups' then 'Turmas'
      when 'imports' then 'Importações'
      when 'institutions' then 'Instituições'
      when 'notices' then 'Avisos'
      when 'people' then 'Pessoas'
      when 'plans' then 'Planos'
      when 'platform' then 'Superadmin'
      when 'support' then 'Suporte'
      when 'units' then 'Unidades'
      else initcap(replace(permission_record.module_code, '_', ' '))
    end,
    screen_label = initcap(replace(
      coalesce(permission_record.screen_code, permission_record.module_code), '_', ' '
    )),
    action_label = case permission_record.action_code
      when 'read' then 'Ver'
      when 'export' then 'Exportar'
      when 'import' then 'Importar'
      when 'update' then 'Editar'
      when 'create' then 'Criar'
      when 'delete' then 'Excluir'
      else 'Gerenciar'
    end,
    updated_at = now()
where permission_record.module_label = '__replay_legacy__'
   or permission_record.screen_label = '__replay_legacy__'
   or permission_record.action_label = '__replay_legacy__';

update public.institution_permissions permission_record
set module_label = case permission_record.module_code
      when 'activities' then 'Atividades'
      when 'attendance' then 'Presença'
      when 'authorization' then 'Perfis e permissões'
      when 'chat' then 'Chat'
      when 'family' then 'Famílias'
      when 'groups' then 'Turmas'
      when 'people' then 'Pessoas'
      else initcap(replace(permission_record.module_code, '_', ' '))
    end,
    screen_label = initcap(replace(
      coalesce(permission_record.screen_code, permission_record.module_code), '_', ' '
    )),
    action_label = case permission_record.action_code
      when 'read' then 'Ver'
      when 'export' then 'Exportar'
      when 'import' then 'Importar'
      when 'update' then 'Editar'
      when 'create' then 'Criar'
      when 'delete' then 'Excluir'
      else 'Gerenciar'
    end,
    updated_at = now()
where permission_record.module_label = '__replay_legacy__'
   or permission_record.screen_label = '__replay_legacy__'
   or permission_record.action_label = '__replay_legacy__';

alter table public.platform_permissions
  alter column module_label drop default,
  alter column screen_label drop default,
  alter column action_label drop default;

alter table public.institution_permissions
  alter column module_label drop default,
  alter column screen_label drop default,
  alter column action_label drop default;

select app_private.assert_permission_label_replay_contract();

commit;
