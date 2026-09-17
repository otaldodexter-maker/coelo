-- Trechos de catalogo (inserts de nivel superior em tabelas de catalogo) extraidos das migrations
-- canonicas na ordem de ordem-de-aplicacao-producao.txt. Uso: semear o espelho schema-only.

-- >>> 20260910130000_meal_plans_owner_permission_grants_v1.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow', 'active'
from public.platform_roles role_record
cross join public.platform_permissions permission_record
where role_record.code = 'owner'
  and permission_record.code like 'meal_plans.%'
on conflict (role_id, permission_id)
  do update set effect = 'allow', status = 'active', revoked_at = null;

-- >>> 20260910130000_meal_plans_owner_permission_grants_v1.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow', 'active'
from public.platform_roles role_record
cross join public.platform_permissions permission_record
where role_record.code = 'operations'
  and permission_record.code = 'meal_plans.read'
on conflict (role_id, permission_id)
  do update set effect = 'allow', status = 'active', revoked_at = null;

-- >>> 20260910010000_daily_routine_foundation_v1.sql :: public.platform_permissions
-- ---------------------------------------------------------------------------
-- Capacidades
-- ---------------------------------------------------------------------------

insert into public.platform_permissions(
  code, module_code, module_label, screen_code, screen_label,
  action_code, action_label, description, risk_level, requires_mfa
) values
  ('routine.read','routine','Rotina diaria','daily_routine','Rotina diaria',
   'read','Ver','Visualizar modelos, aplicacoes e lancamentos de rotina diaria.','normal',false),
  ('routine.manage_models','routine','Rotina diaria','daily_routine','Rotina diaria',
   'manage_models','Gerenciar','Criar e editar modelos de rotina diaria.','high',false),
  ('routine.manage_applications','routine','Rotina diaria','daily_routine','Rotina diaria',
   'manage_applications','Gerenciar','Aplicar modelos de rotina a instituicao, unidade, turma ou atividade.','high',false),
  ('routine.record','routine','Rotina diaria','daily_routine','Rotina diaria',
   'record','Gerenciar','Registrar respostas de rotina em um lancamento em rascunho.','normal',false),
  ('routine.publish','routine','Rotina diaria','daily_routine','Rotina diaria',
   'publish','Gerenciar','Publicar um lancamento de rotina para as familias.','high',true),
  ('routine.correct','routine','Rotina diaria','daily_routine','Rotina diaria',
   'correct','Gerenciar','Corrigir um lancamento de rotina ja publicado, com justificativa.','high',true),
  ('routine.import','routine','Rotina diaria','daily_routine','Rotina diaria',
   'import','Importar','Importar modelos de rotina.','high',true),
  ('routine.export','routine','Rotina diaria','daily_routine','Rotina diaria',
   'export','Exportar','Exportar rotinas e lancamentos.','high',true)
on conflict (code) do update set
  module_code=excluded.module_code, module_label=excluded.module_label,
  screen_code=excluded.screen_code, screen_label=excluded.screen_label,
  action_code=excluded.action_code, action_label=excluded.action_label,
  description=excluded.description,
  risk_level=excluded.risk_level, requires_mfa=excluded.requires_mfa,
  status='active', updated_at=now();

-- >>> 20260910010000_daily_routine_foundation_v1.sql :: public.institution_permissions
insert into public.institution_permissions(
  code, module_code, module_label, screen_code, screen_label,
  action_code, action_label, description, risk_level, requires_mfa
) values
  ('routine.read','routine','Rotina diaria','daily_routine','Rotina diaria',
   'read','Ver','Visualizar rotina diaria dentro do escopo contextual.','normal',false),
  ('routine.manage_models','routine','Rotina diaria','daily_routine','Rotina diaria',
   'manage_models','Gerenciar','Gerenciar modelos de rotina dentro do escopo contextual.','high',false),
  ('routine.manage_applications','routine','Rotina diaria','daily_routine','Rotina diaria',
   'manage_applications','Gerenciar','Gerenciar aplicacoes de rotina dentro do escopo contextual.','high',false),
  ('routine.record','routine','Rotina diaria','daily_routine','Rotina diaria',
   'record','Gerenciar','Registrar respostas de rotina dentro do escopo contextual.','normal',false),
  ('routine.publish','routine','Rotina diaria','daily_routine','Rotina diaria',
   'publish','Gerenciar','Publicar lancamentos de rotina dentro do escopo contextual.','high',true),
  ('routine.correct','routine','Rotina diaria','daily_routine','Rotina diaria',
   'correct','Gerenciar','Corrigir lancamentos publicados dentro do escopo contextual.','high',true),
  ('routine.import','routine','Rotina diaria','daily_routine','Rotina diaria',
   'import','Importar','Importar modelos de rotina dentro do escopo contextual.','high',true),
  ('routine.export','routine','Rotina diaria','daily_routine','Rotina diaria',
   'export','Exportar','Exportar rotina dentro do escopo contextual.','high',true)
on conflict (code) do update set
  module_code=excluded.module_code, module_label=excluded.module_label,
  screen_code=excluded.screen_code, screen_label=excluded.screen_label,
  action_code=excluded.action_code, action_label=excluded.action_label,
  description=excluded.description,
  risk_level=excluded.risk_level, requires_mfa=excluded.requires_mfa,
  status='active', updated_at=now();

-- >>> 20260910010300_health_care_and_medication_plans_v1.sql :: public.platform_permissions
-- ---------------------------------------------------------------------------
-- Capacidades
-- ---------------------------------------------------------------------------

insert into public.platform_permissions(
  code, module_code, module_label, screen_code, screen_label,
  action_code, action_label, description, risk_level, requires_mfa
) values
  ('health_care.read','health_care','Saude e cuidado','health_care_profiles',
   'Perfis de cuidado','read','Ver',
   'Visualizar perfis de cuidado no escopo autorizado.','critical',false),
  ('health_care.manage','health_care','Saude e cuidado','health_care_profiles',
   'Perfis de cuidado','manage','Gerenciar',
   'Criar e editar perfis de cuidado no escopo autorizado.','critical',true),
  ('medication.read','health_care','Saude e cuidado','medication_plans',
   'Planos de medicacao','read','Ver',
   'Visualizar planos de medicacao no escopo autorizado.','critical',false),
  ('medication.manage','health_care','Saude e cuidado','medication_plans',
   'Planos de medicacao','manage','Gerenciar',
   'Criar e editar planos de medicacao no escopo autorizado.','critical',true),
  ('medication.record_evidence','health_care','Saude e cuidado','medication_plans',
   'Planos de medicacao','record_evidence','Gerenciar',
   'Registrar evidencia de administracao de medicamento.','critical',true)
on conflict (code) do update set
  module_code=excluded.module_code, module_label=excluded.module_label,
  screen_code=excluded.screen_code, screen_label=excluded.screen_label,
  action_code=excluded.action_code, action_label=excluded.action_label,
  description=excluded.description, risk_level=excluded.risk_level,
  requires_mfa=excluded.requires_mfa, status='active', updated_at=now();

-- >>> 20260910010300_health_care_and_medication_plans_v1.sql :: public.institution_permissions
insert into public.institution_permissions(
  code, module_code, module_label, screen_code, screen_label,
  action_code, action_label, description, risk_level, requires_mfa
) values
  ('health_care.read','health_care','Saude e cuidado','health_care_profiles',
   'Perfis de cuidado','read','Ver',
   'Visualizar perfis de cuidado dentro do escopo contextual.','critical',false),
  ('health_care.manage','health_care','Saude e cuidado','health_care_profiles',
   'Perfis de cuidado','manage','Gerenciar',
   'Gerenciar perfis de cuidado dentro do escopo contextual.','critical',true),
  ('medication.read','health_care','Saude e cuidado','medication_plans',
   'Planos de medicacao','read','Ver',
   'Visualizar planos de medicacao dentro do escopo contextual.','critical',false),
  ('medication.manage','health_care','Saude e cuidado','medication_plans',
   'Planos de medicacao','manage','Gerenciar',
   'Gerenciar planos de medicacao dentro do escopo contextual.','critical',true),
  ('medication.record_evidence','health_care','Saude e cuidado','medication_plans',
   'Planos de medicacao','record_evidence','Gerenciar',
   'Registrar evidencia de administracao dentro do escopo contextual.','critical',true)
on conflict (code) do update set
  module_code=excluded.module_code, module_label=excluded.module_label,
  screen_code=excluded.screen_code, screen_label=excluded.screen_label,
  action_code=excluded.action_code, action_label=excluded.action_label,
  description=excluded.description, risk_level=excluded.risk_level,
  requires_mfa=excluded.requires_mfa, status='active', updated_at=now();

-- >>> 20260910220000_health_care_guardian_read_v1.sql :: public.guardian_permission_capabilities
insert into public.guardian_permission_capabilities(
  code, name, description, module_code, module_label,
  screen_code, screen_label, action_code, action_label, risk_level, requires_mfa
) values (
  'view_health_care',
  'Ver saude e cuidado',
  'Ler o perfil de cuidado e os planos de medicacao da propria crianca.',
  'principal', 'Principal', 'health_care', 'Saude e cuidado',
  'view', 'Ver', 'high', false
)
on conflict (code) do update set
  name=excluded.name, description=excluded.description,
  module_code=excluded.module_code, module_label=excluded.module_label,
  screen_code=excluded.screen_code, screen_label=excluded.screen_label,
  action_code=excluded.action_code, action_label=excluded.action_label,
  risk_level=excluded.risk_level, status='active', updated_at=now();

-- >>> 20260910170200_superadmin_internal_invites_v2.sql :: public.platform_permissions
insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,
  requires_mfa,status,module_label,screen_label,action_label
) values
  ('platform.invites.read','platform','invites','read',
    'Read the internal Superadmin invitation directory.','normal',false,'active',
    'Plataforma','Convites','Visualizar'),
  ('platform.invites.manage','platform','invites','manage',
    'Issue, resend and revoke invitations through the internal gateway.',
    'high',true,'active','Plataforma','Convites','Gerenciar')
on conflict(code) do update set
  module_code=excluded.module_code,
  screen_code=excluded.screen_code,
  action_code=excluded.action_code,
  description=excluded.description,
  risk_level=excluded.risk_level,
  requires_mfa=excluded.requires_mfa,
  status='active',
  module_label=excluded.module_label,
  screen_label=excluded.screen_label,
  action_label=excluded.action_label,
  updated_at=now();

-- >>> 20260910170200_superadmin_internal_invites_v2.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(
  role_id,permission_id,effect,conditions_json,status,revoked_at
)
select role_record.id,permission_record.id,'allow','{}'::jsonb,'active',null
from public.platform_roles role_record
cross join public.platform_permissions permission_record
where role_record.code='owner'
  and role_record.status='active'
  and permission_record.code in('platform.invites.read','platform.invites.manage')
on conflict(role_id,permission_id) do update set
  effect='allow',conditions_json='{}'::jsonb,status='active',revoked_at=null;

-- >>> 20260910170300_superadmin_internal_users_directory.sql :: public.platform_permissions
insert into public.platform_permissions(
  code,module_code,module_label,screen_code,screen_label,action_code,action_label,
  description,risk_level,requires_mfa
) values
  ('platform.member.read','platform','Superadmin','members','Usuários internos','read','Ver',
   'Consultar o diretório privado de usuários internos Coelo.','high',true),
  ('platform.member.update','platform','Superadmin','members','Usuários internos','update','Editar',
   'Editar cadastro, perfil e alcance de usuários internos Coelo.','high',true),
  ('platform.member.suspend','platform','Superadmin','members','Usuários internos','status','Gerenciar',
   'Suspender, reativar ou revogar vínculos internos Coelo.','high',true)
on conflict(code) do update set
  module_code=excluded.module_code,
  module_label=excluded.module_label,
  screen_code=excluded.screen_code,
  screen_label=excluded.screen_label,
  action_code=excluded.action_code,
  action_label=excluded.action_label,
  description=excluded.description,
  risk_level=excluded.risk_level,
  requires_mfa=excluded.requires_mfa,
  status='active';

-- >>> 20260910170300_superadmin_internal_users_directory.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record
join public.platform_permissions permission_record
  on permission_record.code in(
    'platform.member.read','platform.member.update','platform.member.suspend')
where role_record.code='owner'
on conflict(role_id,permission_id) do update set
  effect='allow',status='active',revoked_at=null;

-- >>> 20260910170300_superadmin_internal_users_directory.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record
join public.platform_permissions permission_record
  on permission_record.code='platform.member.read'
where role_record.code='auditor'
on conflict(role_id,permission_id) do update set
  effect='allow',status='active',revoked_at=null;

-- >>> 20260910170500_child_safety_schema.sql :: public.platform_permissions
-- Rotulos obrigatorios desde 20260811215451 e sem default desde 20260831130726.
-- Na cadeia antiga esta migration corria ANTES da remocao dos defaults, entao o
-- vazio passava. Sobre a baseline de producao os defaults ja nao existem e o
-- insert falha com 23502. Os tres rotulos entram tambem no do update, senao uma
-- linha preexistente continuaria nula.
insert into public.platform_permissions(
  code,module_code,module_label,screen_code,screen_label,action_code,action_label,
  description,risk_level,requires_mfa,status
) values
  ('child_safety.read','child_safety','Segurança infantil','directory','Diretório','read','Ver',
   'Visualizar segurança da criança no escopo autorizado.','critical',true,'active'),
  ('child_safety.manage','child_safety','Segurança infantil','management','Gestão','manage','Gerenciar',
   'Gerenciar autorizações, restrições e alertas infantis.','critical',true,'active'),
  ('child_safety.export','child_safety','Segurança infantil','files','Arquivos','export','Exportar',
   'Exportar dados minimizados de segurança da criança.','critical',true,'active')
on conflict (code) do update set
  module_code=excluded.module_code,module_label=excluded.module_label,
  screen_code=excluded.screen_code,screen_label=excluded.screen_label,
  action_code=excluded.action_code,action_label=excluded.action_label,
  description=excluded.description,
  risk_level=excluded.risk_level,requires_mfa=true,status='active',updated_at=now();

-- >>> 20260910170500_child_safety_schema.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record
join public.platform_permissions permission_record
  on permission_record.code in ('child_safety.read','child_safety.manage','child_safety.export')
where role_record.code='owner'
-- public.platform_role_permissions NAO tem updated_at em producao; a coluna so
-- existia na cadeia antiga. Manter updated_at=now() aqui quebra com 42703.
on conflict (role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

-- >>> 20260910170700_child_safety_security_closure.sql :: public.platform_permissions
-- Recarimbada em 2026-09-10 para a faixa 2026091017xxxx do grupo acessos-pessoas.
-- Origem: migrations-historico/20260812002200_child_safety_security_closure.sql
-- Pacote: AP-CHILD-SAFETY-INTERNAL-READS
-- Motivo: com a baseline de producao 20260910000000_baseline_producao.sql, a
-- cadeia antiga virou historico. Este pacote nunca chegou a producao, entao
-- volta como migration forward-only SOBRE a baseline. Conteudo inalterado em
-- relacao ao historico, salvo correcoes ja registradas nos commits do grupo.

-- Child safety security closure. Commands are server-authorized, idempotent and audited.

-- SECURITY MODEL: direct browser writes are denied. Public RPCs are SECURITY
-- INVOKER wrappers over narrowly granted functions in the unexposed app_private schema.

-- Mesmos rotulos obrigatorios do 20260910170500; ver a nota la.
insert into public.platform_permissions(
  code,module_code,module_label,screen_code,screen_label,action_code,action_label,
  description,risk_level,requires_mfa,status
) values (
  'child_safety.review','child_safety','Segurança infantil','approvals','Aprovações','review','Revisar',
  'Revisar decisões de segurança da criança no escopo exato da unidade.',
  'critical',true,'active'
) on conflict (code) do update set
  module_label=excluded.module_label,screen_label=excluded.screen_label,
  action_label=excluded.action_label,
  description=excluded.description,risk_level='critical',requires_mfa=true,
  status='active',updated_at=now();

-- >>> 20260910230012_locations_capabilities_v1.sql :: public.platform_permissions
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

-- >>> 20260910230012_locations_capabilities_v1.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow', 'active'
from public.platform_roles role_record
cross join public.platform_permissions permission_record
where role_record.code = 'owner'
  and permission_record.code like 'locations.%'
on conflict (role_id, permission_id)
  do update set effect = 'allow', status = 'active', revoked_at = null;

-- >>> 20260910230017_moments_publication_mvp.sql :: public.institution_permissions
insert into public.institution_permissions (
  code, module_code, screen_code, action_code, description, status,
  module_label, screen_label, action_label
)
values
  (
    'moments.publications.create', 'moments', 'publications', 'create',
    'Criar e manter rascunhos de Momentos no contexto autorizado.',
    'active', 'Momentos', 'Publicações', 'Criar'
  ),
  (
    'moments.publications.publish', 'moments', 'publications', 'publish',
    'Publicar Momentos no contexto autorizado.',
    'active', 'Momentos', 'Publicações', 'Publicar'
  ),
  (
    'moments.publications.read', 'moments', 'publications', 'read',
    'Ler Momentos disponíveis no contexto autorizado.',
    'active', 'Momentos', 'Publicações', 'Ler'
  )
on conflict (code) do update set
  module_code = excluded.module_code,
  screen_code = excluded.screen_code,
  action_code = excluded.action_code,
  description = excluded.description,
  status = 'active',
  module_label = excluded.module_label,
  screen_label = excluded.screen_label,
  action_label = excluded.action_label;

-- >>> 20260910190300_now_publication_mvp_baseline.sql :: public.institution_permissions
insert into public.institution_permissions(
  code,module_code,screen_code,action_code,description,risk_level,
  requires_mfa,status,module_label,screen_label,action_label
)
values
 ('now.publications.create','now','publications','create','Criar e manter rascunhos do Agora no contexto autorizado.','high',false,'active','Agora','Publicações','Criar'),
 ('now.publications.publish','now','publications','publish','Publicar ou agendar no Agora no contexto autorizado.','critical',false,'active','Agora','Publicações','Publicar'),
 ('now.publications.read','now','publications','read','Ler publicações privadas do Agora no contexto autorizado.','normal',false,'active','Agora','Publicações','Ler')
on conflict(code) do update set
  module_code=excluded.module_code,
  screen_code=excluded.screen_code,
  action_code=excluded.action_code,
  description=excluded.description,
  risk_level=excluded.risk_level,
  requires_mfa=excluded.requires_mfa,
  status='active',
  module_label=excluded.module_label,
  screen_label=excluded.screen_label,
  action_label=excluded.action_label,
  updated_at=now();

-- >>> 20260910190800_happens_post_withdrawal_baseline.sql :: public.institution_permissions
insert into public.institution_permissions(
  code,module_code,screen_code,action_code,description,status,
  module_label,screen_label,action_label
)
values
 ('happens.posts.remove','happens','posts','remove','Retirar do feed uma publicacao propria ja publicada ou agendada.','active','Acontece','Publicacoes','Remover')
on conflict(code) do update set
  module_code=excluded.module_code,
  screen_code=excluded.screen_code,
  action_code=excluded.action_code,
  description=excluded.description,
  status='active',
  module_label=excluded.module_label,
  screen_label=excluded.screen_label,
  action_label=excluded.action_label;

-- >>> 20260910240100_superadmin_internal_chat_v2.sql :: public.platform_permissions
-- 1. Capacidades do realm interno (labels obrigatorios; sem MFA no MVP).
insert into public.platform_permissions(
  code,module_code,module_label,screen_code,screen_label,action_code,action_label,
  description,risk_level,requires_mfa,status,updated_at
) values
 ('chat.internal.read','communication','Comunicação','chat','Chat','read','Ver',
  'Ler conversas institucionais pelo realm interno do Superadmin.','high',false,'active',now()),
 ('chat.internal.send','communication','Comunicação','chat','Chat','send','Enviar',
  'Enviar mensagens institucionais pelo realm interno do Superadmin.','critical',false,'active',now())
on conflict(code) do update set module_code=excluded.module_code,
 module_label=excluded.module_label,screen_code=excluded.screen_code,
 screen_label=excluded.screen_label,action_code=excluded.action_code,
 action_label=excluded.action_label,description=excluded.description,
 risk_level=excluded.risk_level,requires_mfa=excluded.requires_mfa,status='active',updated_at=now();

-- >>> 20260910240100_superadmin_internal_chat_v2.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='owner' and permission_record.code in('chat.internal.read','chat.internal.send')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

-- >>> 20260910240100_superadmin_internal_chat_v2.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='operations' and permission_record.code='chat.internal.read'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

-- >>> 20260910240200_superadmin_internal_chat_receipts_edit_revoke_v2.sql :: public.platform_permissions
-- 1. Capacidade dedicada as acoes de gestao da propria mensagem.
insert into public.platform_permissions(
  code,module_code,module_label,screen_code,screen_label,action_code,action_label,
  description,risk_level,requires_mfa,status,updated_at
) values
 ('chat.internal.manage','communication','Comunicação','chat','Chat','manage','Gerenciar',
  'Editar e revogar mensagens proprias enviadas pelo realm interno do Superadmin.',
  'critical',false,'active',now())
on conflict(code) do update set module_code=excluded.module_code,
 module_label=excluded.module_label,screen_code=excluded.screen_code,
 screen_label=excluded.screen_label,action_code=excluded.action_code,
 action_label=excluded.action_label,description=excluded.description,
 risk_level=excluded.risk_level,
 requires_mfa=excluded.requires_mfa,status='active',updated_at=now();

-- >>> 20260910240200_superadmin_internal_chat_receipts_edit_revoke_v2.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='owner' and permission_record.code='chat.internal.manage'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

-- >>> 20260910200000_superadmin_internal_notices_v2_baseline.sql :: public.platform_permissions
insert into public.platform_permissions(
  code, module_code, screen_code, action_code, description, risk_level,
  requires_mfa, status, module_label, screen_label, action_label
)
values
  ('notices.read', 'communication', 'notices', 'read',
   'Ler comunicações administrativas.', 'normal', false, 'active',
   'Comunicação', 'Avisos', 'Ler'),
  ('notices.manage', 'communication', 'notices', 'manage',
   'Criar e alterar comunicações administrativas.', 'high', false, 'active',
   'Comunicação', 'Avisos', 'Gerenciar'),
  ('notices.publish', 'communication', 'notices', 'publish',
   'Publicar e alterar o ciclo de comunicações administrativas.', 'critical', false, 'active',
   'Comunicação', 'Avisos', 'Publicar')
on conflict (code) do update set
  module_code = excluded.module_code,
  screen_code = excluded.screen_code,
  action_code = excluded.action_code,
  description = excluded.description,
  risk_level = excluded.risk_level,
  requires_mfa = false,
  status = 'active',
  module_label = excluded.module_label,
  screen_label = excluded.screen_label,
  action_label = excluded.action_label;

-- >>> 20260910200000_superadmin_internal_notices_v2_baseline.sql :: public.platform_role_permissions
-- Owner is the only mutation principal in this cutover. Content and Operations
-- receive only the minimized directory/detail read capability.
insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow'::public.permission_effect, 'active'
from public.platform_roles role_record
join public.platform_permissions permission_record
  on permission_record.code = 'notices.read'
where role_record.code in ('owner', 'content', 'operations')
on conflict (role_id, permission_id) do update set
  effect = 'allow', status = 'active', revoked_at = null;

-- >>> 20260910200000_superadmin_internal_notices_v2_baseline.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow'::public.permission_effect, 'active'
from public.platform_roles role_record
join public.platform_permissions permission_record
  on permission_record.code in ('notices.manage', 'notices.publish')
where role_record.code = 'owner'
on conflict (role_id, permission_id) do update set
  effect = 'allow', status = 'active', revoked_at = null;

-- >>> 20260910200100_superadmin_internal_circulars_v2_baseline.sql :: public.platform_permissions
insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status,
  module_label,screen_label,action_label
) values
 ('circulars.read','communication','circulars','read',
  'Ler Circulares administrativas no escopo autorizado.','normal',false,'active',
  'Comunicação','Circulares','Ler'),
 ('circulars.manage','communication','circulars','manage',
  'Criar, alterar e encerrar Circulares administrativas.','high',false,'active',
  'Comunicação','Circulares','Gerenciar'),
 ('circulars.publish','communication','circulars','publish',
  'Publicar ou agendar Circulares administrativas.','critical',false,'active',
  'Comunicação','Circulares','Publicar')
on conflict(code) do update set
  module_code=excluded.module_code,screen_code=excluded.screen_code,
  action_code=excluded.action_code,description=excluded.description,
  risk_level=excluded.risk_level,requires_mfa=false,status='active',
  module_label=excluded.module_label,screen_label=excluded.screen_label,
  action_label=excluded.action_label;

-- >>> 20260910200100_superadmin_internal_circulars_v2_baseline.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id, permission_record.id, 'allow'::public.permission_effect, 'active'
from public.platform_roles role_record
join public.platform_permissions permission_record on permission_record.code='circulars.read'
where role_record.code in ('owner','content','operations')
on conflict(role_id,permission_id) do update set
  effect='allow',status='active',revoked_at=null;

-- >>> 20260910200100_superadmin_internal_circulars_v2_baseline.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id, permission_record.id, 'allow'::public.permission_effect, 'active'
from public.platform_roles role_record
join public.platform_permissions permission_record
  on permission_record.code in ('circulars.manage','circulars.publish')
where role_record.code='owner'
on conflict(role_id,permission_id) do update set
  effect='allow',status='active',revoked_at=null;

-- >>> 20260910200300_agenda_internal_realm_compat_v1.sql :: public.platform_role_permissions
-- Producao nao tinha nenhuma concessao de agenda.* a papel algum (nem ao Owner):
-- leitura para owner/content/operations e mutacoes ao owner, como Avisos e
-- Circulares v2. Perfis e permissoes continuam mandando (Decisao 12).
insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow'::public.permission_effect, 'active'
from public.platform_roles role_record
join public.platform_permissions permission_record on permission_record.code = 'agenda.read'
where role_record.code in ('owner', 'content', 'operations')
on conflict (role_id, permission_id) do update set effect = 'allow', status = 'active', revoked_at = null;

-- >>> 20260910200300_agenda_internal_realm_compat_v1.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_record.id, permission_record.id, 'allow'::public.permission_effect, 'active'
from public.platform_roles role_record
join public.platform_permissions permission_record on permission_record.code in (
  'agenda.create', 'agenda.edit_own', 'agenda.edit_all', 'agenda.publish',
  'agenda.cancel_restore', 'agenda.manage_responses', 'agenda.override_reservation')
where role_record.code = 'owner'
on conflict (role_id, permission_id) do update set effect = 'allow', status = 'active', revoked_at = null;

-- >>> 20260910180320_structure_type_catalog_seed_v1.sql :: public.institution_types
insert into public.institution_types(id,code,name,description,status)
select seed.id,seed.code,seed.name,seed.description,'active'
from (values
  ('a0000000-0000-4000-8000-000000000101'::uuid,'escola','Escola',
    'Escola de educacao basica.'),
  ('a0000000-0000-4000-8000-000000000102'::uuid,'colegio','Colégio',
    'Colegio com mais de uma etapa de ensino.'),
  ('a0000000-0000-4000-8000-000000000103'::uuid,'creche','Creche',
    'Creche e educacao infantil.')
) seed(id,code,name,description)
where not exists(
  select 1 from public.institution_types existing
  where lower(existing.code)=seed.code or lower(existing.name)=lower(seed.name)
);

-- >>> 20260910180320_structure_type_catalog_seed_v1.sql :: public.unit_types
insert into public.unit_types(id,code,name,description,status)
select seed.id,seed.code,seed.name,seed.description,'active'
from (values
  ('a0000000-0000-4000-8000-000000000201'::uuid,'sede','Sede',
    'Unidade principal da instituicao.'),
  ('a0000000-0000-4000-8000-000000000202'::uuid,'filial','Filial',
    'Unidade secundaria ou anexa.')
) seed(id,code,name,description)
where not exists(
  select 1 from public.unit_types existing
  where lower(existing.code)=seed.code or lower(existing.name)=lower(seed.name)
);

-- >>> 20260910220400_internal_actor_service_person_v1.sql :: public.platform_permissions
-- 20260910220400_internal_actor_service_person_v1
--
-- Ator do realm interno v2 nas familias people-based (ADR 0034; achado
-- F-R04-FCR-002 do grupo formularios-cuidado-rotina, 10/09/2026).
--
-- O que estava errado: a sessao interna do Superadmin (realm interno v2,
-- app_private.superadmin_internal_*) nao tem person_auth_link nem
-- platform_membership. As RPCs de Cuidado, Medicacao, Rotina, Assiduidade,
-- Alunos e Formularios resolvem o ator por app_private.current_person_id() e a
-- capacidade por app_private.has_platform_permission(), que so olham o realm
-- people-based; para elas a sessao interna e "nao autenticada". Alem disso, o
-- catalogo de producao nao tem os codigos attendance.read, attendance.manage
-- e people.assign_children, e nenhum papel de plataforma concede health_care,
-- medication, routine ou attendance.
--
-- O que este pacote faz, sem reescrever RPC alguma:
--   1. completa o catalogo (attendance.read, attendance.manage,
--      people.assign_children) e concede ao papel owner as permissoes das
--      familias do recorte (Decisao 12/P7: tudo passa por perfil e permissao;
--      owner e o piso, nada e Owner-only por desenho);
--   2. espelha cada identidade interna numa pessoa de servico
--      (people.person_type = 'service') e a membership interna ativa numa
--      platform_membership no MESMO papel de plataforma; mantido por gatilho;
--   3. app_private.current_person_id() passa a cair no espelho quando o auth
--      user nao tem person_auth_link (o realm people-based continua tendo
--      precedencia e nada muda para quem ja tem pessoa).
--
-- Nao cria person_auth_link (o guard do realm interno impede e nao e preciso).
-- Nao afrouxa RLS: a tabela nova fica em app_private sem grant a cliente.

-- ---------------------------------------------------------------------------
-- 1. Catalogo e concessoes ao papel owner
-- ---------------------------------------------------------------------------

insert into public.platform_permissions(
  code, module_code, module_label, screen_code, screen_label,
  action_code, action_label, description, risk_level, requires_mfa
) values
  ('attendance.read','attendance','Assiduidade','attendance_calls',
   'Chamadas','read','Ver',
   'Visualizar chamadas e presencas no escopo autorizado.','high',false),
  ('attendance.manage','attendance','Assiduidade','attendance_calls',
   'Chamadas','manage','Gerenciar',
   'Abrir, marcar, corrigir e concluir chamadas no escopo autorizado.','high',false),
  ('people.assign_children','people','Pessoas','students',
   'Alunos','assign_children','Vincular',
   'Vincular, transferir, editar e revogar vinculos de crianca com unidades e turmas.','critical',false)
on conflict (code) do nothing;

-- >>> 20260910220400_internal_actor_service_person_v1.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(role_id, permission_id, effect, status)
select role_row.id, permission_row.id, 'allow', 'active'
from public.platform_roles role_row
cross join public.platform_permissions permission_row
where role_row.code = 'owner'
  and permission_row.status = 'active'
  and (permission_row.code like 'health_care.%'
    or permission_row.code like 'medication.%'
    or permission_row.code like 'routine.%'
    or permission_row.code like 'attendance.%'
    or permission_row.code in ('people.assign_children', 'people.read'))
  and not exists (
    select 1 from public.platform_role_permissions existing
    where existing.role_id = role_row.id
      and existing.permission_id = permission_row.id
  );

-- >>> 20260910171300_access_profile_models_catalog_v2_baseline.sql :: public.platform_permissions
-- 4. Permissoes *.role_models.* (rotulos obrigatorios; requires_mfa false no MVP)
--    e concessao inicial somente ao Owner.
insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,requires_mfa,
  status,module_label,screen_label,action_label,application_code
)
select definition.code,'access','access_profile_models',definition.action_code,
  definition.description,definition.risk_level,false,'active',
  'Acessos','Modelos de perfil',definition.action_label,'superadmin'
from (values
  ('platform.role_models.read','read','Consultar modelos Superadmin.','normal','Visualizar'),
  ('platform.role_models.create','create','Criar modelos Superadmin.','high','Criar'),
  ('platform.role_models.update','update','Editar modelos Superadmin.','high','Editar'),
  ('platform.role_models.delete','delete','Inativar modelos Superadmin.','critical','Excluir'),
  ('platform.role_models.import','import','Importar modelos Superadmin.','critical','Importar'),
  ('platform.role_models.export','export','Exportar modelos Superadmin.','high','Exportar'),
  ('institution.role_models.read','read','Consultar modelos Admin.','normal','Visualizar'),
  ('institution.role_models.create','create','Criar modelos Admin.','high','Criar'),
  ('institution.role_models.update','update','Editar modelos Admin.','high','Editar'),
  ('institution.role_models.delete','delete','Inativar modelos Admin.','critical','Excluir'),
  ('institution.role_models.import','import','Importar modelos Admin.','critical','Importar'),
  ('institution.role_models.export','export','Exportar modelos Admin.','high','Exportar'),
  ('principal.role_models.read','read','Consultar modelos Principal.','high','Visualizar'),
  ('principal.role_models.create','create','Criar modelos Principal.','critical','Criar'),
  ('principal.role_models.update','update','Editar modelos Principal.','critical','Editar'),
  ('principal.role_models.delete','delete','Inativar modelos Principal.','critical','Excluir'),
  ('principal.role_models.import','import','Importar modelos Principal.','critical','Importar'),
  ('principal.role_models.export','export','Exportar modelos Principal.','high','Exportar')
) as definition(code,action_code,description,risk_level,action_label)
on conflict(code) do update set
  module_code=excluded.module_code,
  screen_code=excluded.screen_code,
  action_code=excluded.action_code,
  description=excluded.description,
  risk_level=excluded.risk_level,
  requires_mfa=false,
  status='active',
  module_label=excluded.module_label,
  screen_label=excluded.screen_label,
  action_label=excluded.action_label,
  application_code=excluded.application_code,
  updated_at=now();

-- >>> 20260910171300_access_profile_models_catalog_v2_baseline.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(
  role_id,permission_id,effect,conditions_json,status
)
select role_record.id,permission_record.id,'allow','{}'::jsonb,'active'
from public.platform_roles role_record
join public.platform_permissions permission_record
  on (permission_record.code like 'platform.role_models.%'
    or permission_record.code like 'institution.role_models.%'
    or permission_record.code like 'principal.role_models.%')
where role_record.code='owner'
on conflict(role_id,permission_id) do update set
  effect='allow',status='active',revoked_at=null;

-- >>> 20260910172000_owner_child_safety_review_grant_v1.sql :: public.platform_role_permissions
insert into public.platform_role_permissions (role_id, permission_id, effect, conditions_json, status)
select role_record.id, permission_record.id, 'allow', '{}'::jsonb, 'active'
from public.platform_roles role_record
join public.platform_permissions permission_record on permission_record.code = 'child_safety.review'
where role_record.code = 'owner' and role_record.status = 'active'
  and not exists (
    select 1 from public.platform_role_permissions existing
    where existing.role_id = role_record.id and existing.permission_id = permission_record.id
      and existing.status = 'active' and existing.revoked_at is null
  );

-- >>> 20260911130300_moments_feed_and_withdrawal_baseline.sql :: public.institution_permissions
insert into public.institution_permissions (
  code, module_code, screen_code, action_code, description, status,
  module_label, screen_label, action_label
)
values
  (
    'moments.publications.remove', 'moments', 'publications', 'remove',
    'Retirar do feed Momentos publicados de própria autoria no contexto autorizado.',
    'active', 'Momentos', 'Publicações', 'Remover'
  )
on conflict (code) do update set
  module_code = excluded.module_code,
  screen_code = excluded.screen_code,
  action_code = excluded.action_code,
  description = excluded.description,
  status = 'active',
  module_label = excluded.module_label,
  screen_label = excluded.screen_label,
  action_label = excluded.action_label;

-- >>> 20260912140550_moments_withdraw_permission_v1.sql :: public.institution_role_permissions
insert into public.institution_role_permissions (
  role_id, permission_id, effect, status
)
select role_record.id, permission_record.id, 'allow', 'active'
from public.institution_roles role_record
join public.institution_permissions permission_record
  on permission_record.code = 'moments.publications.remove'
 and permission_record.status = 'active'
where role_record.institution_id is null
  and role_record.code = 'institution_admin'
  and role_record.is_system
  and role_record.status = 'active'
on conflict (role_id, permission_id) do update set
  effect = 'allow',
  status = 'active',
  revoked_at = null;

-- >>> 20260914140000_r13_care_policies_manage_capability_v1.sql :: public.platform_permissions
-- R13 / ADR 0038 H17 (P23): politicas de cuidado por capacidade, nao por papel fixo.
-- Cria `care_policies.manage` no catalogo do Superadmin (nasce no perfil de sistema
-- Owner) e no catalogo de instituicao (nasce em Administrador da instituicao) e
-- troca o guard de superadmin_unit_care_policy_set_v1 de units.update + papel
-- owner/operations para a capacidade propria. Leitura (get_v1) continua units.read.
insert into public.platform_permissions(
  code,module_code,module_label,screen_code,screen_label,action_code,action_label,
  description,risk_level,requires_mfa,status,updated_at
) values
 ('care_policies.manage','units','Unidades','care_policies','Politicas de cuidado','manage','Gerenciar',
  'Definir politicas de seguranca infantil, medicacao e notificacao de cuidado por unidade.',
  'high',false,'active',now())
on conflict(code) do update set module_code=excluded.module_code,
 module_label=excluded.module_label,screen_code=excluded.screen_code,
 screen_label=excluded.screen_label,action_code=excluded.action_code,
 action_label=excluded.action_label,description=excluded.description,
 risk_level=excluded.risk_level,requires_mfa=excluded.requires_mfa,status='active',updated_at=now();

-- >>> 20260914140000_r13_care_policies_manage_capability_v1.sql :: public.platform_role_permissions
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='owner' and permission_record.code='care_policies.manage'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

-- >>> 20260914140000_r13_care_policies_manage_capability_v1.sql :: public.institution_permissions
insert into public.institution_permissions(
  code,module_code,module_label,screen_code,screen_label,action_code,action_label,
  description,risk_level,requires_mfa,status,updated_at,application_code
) values
 ('care_policies.manage','units','Unidades','care_policies','Politicas de cuidado','manage','Gerenciar',
  'Definir politicas de seguranca infantil, medicacao e notificacao de cuidado nas unidades do contexto autorizado.',
  'high',false,'active',now(),'admin')
on conflict(code) do update set module_code=excluded.module_code,
 module_label=excluded.module_label,screen_code=excluded.screen_code,
 screen_label=excluded.screen_label,action_code=excluded.action_code,
 action_label=excluded.action_label,description=excluded.description,
 risk_level=excluded.risk_level,requires_mfa=excluded.requires_mfa,status='active',updated_at=now();

-- >>> 20260914140000_r13_care_policies_manage_capability_v1.sql :: public.institution_role_permissions
insert into public.institution_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.institution_roles role_record
join public.institution_permissions permission_record
  on permission_record.code='care_policies.manage' and permission_record.status='active'
where role_record.institution_id is null and role_record.code='institution_admin'
  and role_record.is_system and role_record.status='active'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

-- >>> 20260915131500_global_type_catalogs_v1.sql :: public.global_type_catalogs
insert into public.global_type_catalogs(
  code,entity_type,label,sort_order,is_other,requires_free_text)
values
  ('institution.basic_education_school','institution','Escola (educação básica)',10,false,false),
  ('institution.early_childhood_center','institution','Creche / educação infantil',20,false,false),
  ('institution.therapy_center','institution','Centro de terapias',30,false,false),
  ('institution.sports_club','institution','Clube / escola esportiva',40,false,false),
  ('institution.language_school','institution','Escola de idiomas / cursos',50,false,false),
  ('institution.faith_community','institution','Igreja / comunidade',60,false,false),
  ('institution.hybrid','institution','Híbrida',70,false,false),
  ('institution.other','institution','Outros',80,true,true),
  ('unit.school','unit','Escolar',10,false,false),
  ('unit.early_childhood','unit','Educação infantil',20,false,false),
  ('unit.therapy','unit','Terapias',30,false,false),
  ('unit.sports','unit','Esportes / futebol',40,false,false),
  ('unit.children_academy','unit','Academia infantil',50,false,false),
  ('unit.languages_courses','unit','Idiomas / cursos',60,false,false),
  ('unit.faith_community','unit','Igreja / comunidade',70,false,false),
  ('unit.other','unit','Outros',80,true,true),
  ('group.school_class','group','Turma escolar (ano/série)',10,false,false),
  ('group.early_childhood_class','group','Turma de educação infantil',20,false,false),
  ('group.therapy_group','group','Grupo de terapia',30,false,false),
  ('group.individual_service','group','Atendimento individual',40,false,false),
  ('group.sports_class','group','Turma esportiva',50,false,false),
  ('group.course_workshop','group','Turma de curso / oficina',60,false,false),
  ('group.community_group','group','Grupo de comunidade',70,false,false),
  ('group.other','group','Outros',80,true,true),
  ('activity.regular_class','activity','Aula regular',10,false,false),
  ('activity.extracurricular_class','activity','Aula extracurricular',20,false,false),
  ('activity.therapy_session','activity','Sessão de terapia',30,false,false),
  ('activity.training','activity','Treino',40,false,false),
  ('activity.course_workshop','activity','Oficina / curso',50,false,false),
  ('activity.event_trip','activity','Evento / passeio',60,false,false),
  ('activity.reinforcement_followup','activity','Reforço / acompanhamento',70,false,false),
  ('activity.other','activity','Outros',80,true,true)
on conflict (code) do update set
  entity_type=excluded.entity_type,
  label=excluded.label,
  description=excluded.description,
  sort_order=excluded.sort_order,
  is_other=excluded.is_other,
  requires_free_text=excluded.requires_free_text,
  status='active',
  updated_at=now();

-- >>> 20260915195203_agora_immediate_removal_contract_v1.sql :: public.institution_permissions
insert into public.institution_permissions(
  code,module_code,screen_code,action_code,description,risk_level,
  requires_mfa,status,module_label,screen_label,action_label
)
values (
  'now.publications.remove','now','publications','remove',
  'Remover imediatamente uma publicacao do Agora no contexto autorizado.',
  'critical',false,'active','Agora','Publicacoes','Remover'
)
on conflict(code) do update set
  module_code=excluded.module_code,
  screen_code=excluded.screen_code,
  action_code=excluded.action_code,
  description=excluded.description,
  risk_level=excluded.risk_level,
  requires_mfa=excluded.requires_mfa,
  status='active',
  module_label=excluded.module_label,
  screen_label=excluded.screen_label,
  action_label=excluded.action_label,
  updated_at=now();

-- >>> 20260915200003_agora_immediate_removal_role_seed_v1.sql :: public.institution_role_permissions
-- R14 Bloco E / ADR 0040 / action_id agora.remove.
-- A permissao entrou depois do seed historico de papeis; atualiza somente o
-- papel sistemico institution_admin, sem ampliar teacher/reader/coordinator.
insert into public.institution_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.institution_roles role_record
cross join public.institution_permissions permission_record
where role_record.institution_id is null
  and role_record.is_system
  and role_record.code='institution_admin'
  and permission_record.code='now.publications.remove'
  and permission_record.status='active'
  and not exists(
    select 1 from public.institution_role_permissions existing
    where existing.role_id=role_record.id and existing.permission_id=permission_record.id
      and existing.status='active' and existing.revoked_at is null
  );
