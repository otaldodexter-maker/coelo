-- Cardapios: conceder as permissoes de Cardapios ao papel Owner.
--
-- A migration 20260813120000 inseriu meal_plans.read, meal_plans.manage e
-- meal_plans.publish no catalogo de permissoes, mas nenhuma migration jamais as
-- concedeu a papel nenhum em platform_role_permissions. A 20260729144440 ja
-- havia removido o bypass implicito do Owner em
-- app_private.has_platform_permission. Somados, os dois fatos deixam toda a
-- familia Cardapios inalcancavel: todas as RPCs e policies exigem
-- has_platform_permission('meal_plans.manage'), que retorna falso ate para o
-- Owner. Medido em replay local nesta data: as tres permissoes existem, o
-- bypass nao existe e platform_role_permissions nao tem nenhuma linha para
-- elas.
--
-- Este pacote segue o padrao ja usado por Atividades em 20260811192514.
-- Operacao recebe apenas a leitura; gerenciar e publicar ficam com o Owner,
-- como manda o risco 'high' declarado no proprio catalogo.
begin;

insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow', 'active'
from public.platform_roles role_record
cross join public.platform_permissions permission_record
where role_record.code = 'owner'
  and permission_record.code like 'meal_plans.%'
on conflict (role_id, permission_id)
  do update set effect = 'allow', status = 'active', revoked_at = null;

insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow', 'active'
from public.platform_roles role_record
cross join public.platform_permissions permission_record
where role_record.code = 'operations'
  and permission_record.code = 'meal_plans.read'
on conflict (role_id, permission_id)
  do update set effect = 'allow', status = 'active', revoked_at = null;

commit;
