-- Locais: provisiona as nove capacidades que a cadeia de Locais v2 exige e que
-- nunca existiram em producao (ADR 0034, Decisao 10 / P18, Owner em 10/09/2026).
--
-- Medido no espelho da baseline: platform_permissions nao tem nenhuma linha
-- 'locations.%'. Sem elas, require_superadmin_internal_context('locations....')
-- nega toda RPC de Locais mesmo com o SQL aplicado. Concessao inicial somente ao
-- Owner, AAL1 no MVP (requires_mfa=false), risco declarado por acao; a revisao
-- profunda pos-MVP decide se alguma volta a exigir MFA.
begin;

insert into public.platform_permissions(
  code, module_code, module_label, screen_code, screen_label,
  action_code, action_label, description, risk_level, requires_mfa
) values
  ('locations.read','locations','Locais','locations_directory','Locais','read','Ver',
   'Visualizar locais internos e externos e seus vinculos.','medium',false),
  ('locations.create','locations','Locais','locations_directory','Locais','create','Criar',
   'Criar local interno ou externo.','high',false),
  ('locations.update','locations','Locais','locations_directory','Locais','update','Editar',
   'Editar dados de um local.','high',false),
  ('locations.status','locations','Locais','locations_directory','Locais','status','Alterar status',
   'Ativar, inativar ou arquivar um local.','high',false),
  ('locations.copy','locations','Locais','locations_directory','Locais','copy','Copiar',
   'Copiar um local para outra instituicao ou unidade.','high',false),
  ('locations.schedule','locations','Locais','locations_detail','Detalhe do local','schedule','Agenda',
   'Definir a agenda de disponibilidade do local.','high',false),
  ('locations.reservations.read','locations','Locais','locations_reservations','Reservas','read','Ver reservas',
   'Visualizar reservas de locais.','medium',false),
  ('locations.reservations.manage','locations','Locais','locations_reservations','Reservas','manage','Gerenciar reservas',
   'Criar, alterar e cancelar reservas de locais.','high',false),
  ('locations.reservations.override','locations','Locais','locations_reservations','Reservas','override','Confirmar conflito',
   'Confirmar uma reserva mesmo com conflito de horario.','critical',false)
on conflict (code) do update set
  module_label = excluded.module_label,
  screen_label = excluded.screen_label,
  action_label = excluded.action_label,
  status = 'active',
  updated_at = now();

insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow', 'active'
from public.platform_roles role_record
cross join public.platform_permissions permission_record
where role_record.code = 'owner'
  and permission_record.code like 'locations.%'
on conflict (role_id, permission_id)
  do update set effect = 'allow', status = 'active', revoked_at = null;

commit;
