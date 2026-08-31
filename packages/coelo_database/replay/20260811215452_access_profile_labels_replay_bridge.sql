-- Replay-only bridge for historical local migrations that were authored before
-- access-profile labels became NOT NULL. This file is not a deploy candidate.

alter table public.platform_permissions
  alter column module_label set default '__replay_legacy__',
  alter column screen_label set default '__replay_legacy__',
  alter column action_label set default '__replay_legacy__';

alter table public.institution_permissions
  alter column module_label set default '__replay_legacy__',
  alter column screen_label set default '__replay_legacy__',
  alter column action_label set default '__replay_legacy__';

alter table public.platform_role_permissions
  add column if not exists updated_at timestamptz not null default now();
