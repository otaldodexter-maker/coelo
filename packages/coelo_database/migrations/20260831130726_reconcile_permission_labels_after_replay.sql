-- Normalize replay-only label sentinels and restore the canonical no-default
-- contract. On environments that never used the replay bridge this is a no-op.

alter table public.platform_role_permissions
  add column if not exists updated_at timestamptz not null default now();

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
