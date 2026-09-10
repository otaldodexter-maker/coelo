-- Schema Boundaries and Catalog v1
-- Source: specs/011-superadmin-database-rls.md
-- Applied migration version: 20260623203230

create schema if not exists audit;
create schema if not exists analytics;

do $$
begin
  if to_regclass('public.audit_logs') is not null and to_regclass('audit.audit_logs') is null then
    alter table public.audit_logs set schema audit;
  end if;

  if to_regclass('public.support_session_actions') is not null and to_regclass('audit.support_session_actions') is null then
    alter table public.support_session_actions set schema audit;
  end if;

  if to_regclass('public.analytics_events') is not null and to_regclass('analytics.analytics_events') is null then
    alter table public.analytics_events set schema analytics;
  end if;

  if to_regclass('public.notice_events') is not null and to_regclass('analytics.notice_events') is null then
    alter table public.notice_events set schema analytics;
  end if;

  if to_regclass('public.usage_counters') is not null and to_regclass('analytics.usage_counters') is null then
    alter table public.usage_counters set schema analytics;
  end if;

  if to_regclass('public.usage_snapshots') is not null and to_regclass('analytics.usage_snapshots') is null then
    alter table public.usage_snapshots set schema analytics;
  end if;
end $$;

revoke all on schema audit from public;
revoke all on schema analytics from public;
revoke all on schema audit from anon, authenticated;
revoke all on schema analytics from anon, authenticated;
revoke all privileges on all tables in schema audit from anon, authenticated;
revoke all privileges on all tables in schema analytics from anon, authenticated;
revoke all privileges on all sequences in schema audit from anon, authenticated;
revoke all privileges on all sequences in schema analytics from anon, authenticated;
revoke execute on all routines in schema audit from public, anon, authenticated;
revoke execute on all routines in schema analytics from public, anon, authenticated;

grant usage on schema audit to service_role;
grant usage on schema analytics to service_role;
grant all privileges on all tables in schema audit to service_role;
grant all privileges on all tables in schema analytics to service_role;
grant all privileges on all sequences in schema audit to service_role;
grant all privileges on all sequences in schema analytics to service_role;

alter default privileges for role postgres in schema audit
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema analytics
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema audit
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema analytics
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema audit
  revoke execute on routines from public, anon, authenticated;
alter default privileges for role postgres in schema analytics
  revoke execute on routines from public, anon, authenticated;
alter default privileges for role postgres in schema audit
  grant all on tables to service_role;
alter default privileges for role postgres in schema analytics
  grant all on tables to service_role;

alter table if exists audit.audit_logs enable row level security;
alter table if exists audit.support_session_actions enable row level security;
alter table if exists analytics.analytics_events enable row level security;
alter table if exists analytics.notice_events enable row level security;
alter table if exists analytics.usage_counters enable row level security;
alter table if exists analytics.usage_snapshots enable row level security;

insert into public.platform_permissions(code, module_code, screen_code, action_code, description, risk_level, requires_mfa)
values
  ('analytics.read', 'analytics', 'dashboard', 'read', 'Ler eventos, contadores e snapshots agregados para dashboards internos.', 'normal', false)
on conflict (code) do update set
  module_code = excluded.module_code,
  screen_code = excluded.screen_code,
  action_code = excluded.action_code,
  description = excluded.description,
  risk_level = excluded.risk_level,
  requires_mfa = excluded.requires_mfa,
  updated_at = now();

insert into public.platform_role_permissions(role_id, permission_id, effect)
select pr.id, pp.id, 'allow'
from public.platform_roles pr
join public.platform_permissions pp on pp.code = 'analytics.read'
where pr.code in ('owner', 'operations', 'auditor')
on conflict (role_id, permission_id) do nothing;

drop policy if exists audit_logs_platform_read on audit.audit_logs;
drop policy if exists support_session_actions_platform_read on audit.support_session_actions;
drop policy if exists analytics_events_platform_read on analytics.analytics_events;
drop policy if exists notice_events_platform_read on analytics.notice_events;
drop policy if exists usage_counters_platform_read on analytics.usage_counters;
drop policy if exists usage_snapshots_platform_read on analytics.usage_snapshots;

create policy audit_logs_audit_read on audit.audit_logs
  for select to authenticated
  using ((select app_private.has_platform_permission('audit.read')));

create policy support_session_actions_audit_read on audit.support_session_actions
  for select to authenticated
  using ((select app_private.has_platform_permission('audit.read')));

create policy analytics_events_dashboard_read on analytics.analytics_events
  for select to authenticated
  using ((select app_private.has_platform_permission('analytics.read')));

create policy notice_events_dashboard_read on analytics.notice_events
  for select to authenticated
  using ((select app_private.has_platform_permission('analytics.read')));

create policy usage_counters_dashboard_read on analytics.usage_counters
  for select to authenticated
  using ((select app_private.has_platform_permission('analytics.read')));

create policy usage_snapshots_dashboard_read on analytics.usage_snapshots
  for select to authenticated
  using ((select app_private.has_platform_permission('analytics.read')));

with table_catalog(schema_name, table_name, table_label, table_description, domain) as (
  values
    ('public', 'people', 'Pessoas', 'Pessoa global com ou sem login.', 'identity'),
    ('public', 'person_profile_details', 'Dados pessoais', 'Dados pessoais complementares opcionais.', 'identity'),
    ('public', 'person_professional_details', 'Dados profissionais', 'Dados profissionais basicos.', 'identity'),
    ('public', 'person_education_details', 'Escolaridade', 'Historico ou situacao educacional basica.', 'identity'),
    ('public', 'person_addresses', 'Enderecos', 'Endereco residencial opcional.', 'identity'),
    ('public', 'person_auth_links', 'Vinculos Auth', 'Ligacao entre pessoa global e usuario Supabase Auth.', 'identity'),
    ('public', 'person_contacts', 'Contatos', 'Contatos mascarados e verificacoes de pessoa.', 'identity'),
    ('public', 'invitations', 'Convites', 'Convites por escopo, papel e token hash.', 'identity'),
    ('public', 'schema_tables', 'Catalogo de tabelas', 'Catalogo das tabelas suportadas pelo Coelo.', 'catalog'),
    ('public', 'schema_columns', 'Catalogo de colunas', 'Catalogo das colunas suportadas pelo Coelo.', 'catalog'),
    ('public', 'institutions', 'Instituicoes', 'Tenant principal do Coelo.', 'tenancy'),
    ('public', 'units', 'Unidades', 'Unidades operacionais de uma instituicao.', 'tenancy'),
    ('public', 'groups', 'Grupos', 'Turmas, equipes ou grupos de atendimento.', 'tenancy'),
    ('public', 'institution_settings', 'Configuracoes da instituicao', 'Configuracoes operacionais e feature flags por instituicao.', 'tenancy'),
    ('public', 'institution_branding', 'Marca da instituicao', 'Branding leve por instituicao.', 'tenancy'),
    ('public', 'unit_branding', 'Marca da unidade', 'Branding leve por unidade.', 'tenancy'),
    ('public', 'plans', 'Planos', 'Catalogo de planos do Coelo.', 'plans'),
    ('public', 'plan_entitlements', 'Direitos do plano', 'Limites, modulos e features por plano.', 'plans'),
    ('public', 'institution_subscriptions', 'Assinaturas institucionais', 'Plano e status manual por instituicao.', 'plans'),
    ('public', 'usage_limits', 'Limites de uso', 'Limites manuais e informativos por instituicao.', 'plans'),
    ('public', 'platform_roles', 'Perfis Superadmin', 'Catalogo de perfis internos Coelo.', 'superadmin'),
    ('public', 'platform_permissions', 'Permissoes Superadmin', 'Catalogo de permissoes por modulo, tela e acao.', 'superadmin'),
    ('public', 'platform_role_permissions', 'Permissoes por perfil', 'Ligacao entre perfil interno e permissoes.', 'superadmin'),
    ('public', 'platform_memberships', 'Membros Superadmin', 'Pessoas vinculadas a perfis internos Coelo.', 'superadmin'),
    ('public', 'platform_member_permission_overrides', 'Excecoes de permissao', 'Excecoes de permissao por membro interno.', 'superadmin'),
    ('public', 'institution_memberships', 'Membros institucionais', 'Pessoas vinculadas a papeis dentro de instituicoes.', 'admin'),
    ('public', 'institution_role_grants', 'Permissoes institucionais', 'Permissoes finas do Admin institucional.', 'admin'),
    ('public', 'audience_segments', 'Segmentos de audiencia', 'Segmentos reutilizaveis para avisos e popups.', 'superadmin'),
    ('public', 'platform_notices', 'Avisos e popups', 'Avisos globais ou segmentados da plataforma.', 'superadmin'),
    ('public', 'notice_rules', 'Regras de aviso', 'Regras de audiencia versionadas para avisos.', 'superadmin'),
    ('public', 'notice_media', 'Midia de aviso', 'Midia principal de avisos e popups.', 'superadmin'),
    ('public', 'notice_receipts', 'Recibos de aviso', 'Entrega, abertura e acao por pessoa e instituicao.', 'superadmin'),
    ('public', 'import_jobs', 'Importacoes', 'Execucao de importacoes por dominio e tabela.', 'imports'),
    ('public', 'import_files', 'Arquivos de importacao', 'Arquivos temporarios associados a uma importacao.', 'imports'),
    ('public', 'import_mappings', 'Mapeamentos de importacao', 'Mapeamento entre colunas de origem e destino.', 'imports'),
    ('public', 'import_rows', 'Linhas de importacao', 'Staging e estado por linha importada.', 'imports'),
    ('public', 'import_errors', 'Erros de importacao', 'Erros por linha e coluna.', 'imports'),
    ('public', 'import_results', 'Resultados de importacao', 'Resumo final de uma importacao.', 'imports'),
    ('public', 'support_sessions', 'Atendimentos', 'Sessoes de suporte Coelo.', 'support'),
    ('public', 'support_messages', 'Mensagens de suporte', 'Historico de mensagens do atendimento.', 'support'),
    ('public', 'conversations', 'Conversas', 'Chat institucional por escopo.', 'chat'),
    ('public', 'conversation_members', 'Membros de conversa', 'Participantes e papeis em uma conversa.', 'chat'),
    ('public', 'messages', 'Mensagens', 'Mensagens de chat.', 'chat'),
    ('public', 'message_receipts', 'Recibos de mensagem', 'Entrega, leitura e visualizacao de mensagens.', 'chat'),
    ('public', 'message_edits', 'Edicoes de mensagem', 'Historico de edicao de mensagens.', 'chat'),
    ('public', 'channel_policies', 'Politicas de canal', 'Regras de chat por instituicao, unidade ou grupo.', 'chat'),
    ('audit', 'audit_logs', 'Logs de auditoria', 'Trilha append-only de acoes sensiveis.', 'audit'),
    ('audit', 'support_session_actions', 'Acoes de suporte', 'Acoes sensiveis realizadas em sessoes de suporte.', 'audit'),
    ('analytics', 'analytics_events', 'Eventos analiticos', 'Eventos minimizados para produto e dashboard.', 'analytics'),
    ('analytics', 'notice_events', 'Eventos de aviso', 'Eventos minimizados de entrega e interacao com avisos.', 'analytics'),
    ('analytics', 'usage_counters', 'Contadores de uso', 'Contadores agregados por periodo e dimensoes.', 'analytics'),
    ('analytics', 'usage_snapshots', 'Snapshots de uso', 'Snapshots agregados para dashboard futuro.', 'analytics')
),
existing_tables as (
  select tc.*
  from table_catalog tc
  join information_schema.tables t
    on t.table_schema = tc.schema_name
   and t.table_name = tc.table_name
   and t.table_type = 'BASE TABLE'
)
insert into public.schema_tables(schema_name, table_name, table_label, table_description, domain, status, version, updated_at)
select schema_name, table_name, table_label, table_description, domain, 'active', 1, now()
from existing_tables
on conflict (schema_name, table_name, version) do update set
  table_label = excluded.table_label,
  table_description = excluded.table_description,
  domain = excluded.domain,
  status = 'active',
  updated_at = now();

update public.schema_tables st
set status = 'archived',
    updated_at = now()
where st.status = 'active'
  and st.schema_name in ('public', 'audit', 'analytics')
  and not exists (
    select 1
    from information_schema.tables t
    where t.table_schema = st.schema_name
      and t.table_name = st.table_name
      and t.table_type = 'BASE TABLE'
  );

with unique_columns as (
  select ns.nspname as table_schema,
         rel.relname as table_name,
         att.attname as column_name
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_namespace ns on ns.oid = rel.relnamespace
  join pg_attribute att on att.attrelid = rel.oid and att.attnum = any(con.conkey)
  where con.contype in ('p', 'u')
    and array_length(con.conkey, 1) = 1
),
column_catalog as (
  select c.table_schema,
         c.table_name,
         c.column_name,
         case c.column_name
           when 'id' then 'ID'
           when 'person_id' then 'Pessoa'
           when 'institution_id' then 'Instituicao'
           when 'unit_id' then 'Unidade'
           when 'group_id' then 'Grupo'
           when 'created_at' then 'Criado em'
           when 'updated_at' then 'Atualizado em'
           when 'deleted_at' then 'Excluido em'
           when 'status' then 'Status'
           when 'code' then 'Codigo'
           when 'name' then 'Nome'
           when 'description' then 'Descricao'
           when 'first_name' then 'Nome'
           when 'last_name' then 'Sobrenome'
           when 'display_name' then 'Nome de exibicao'
           when 'legal_name' then 'Razao social'
           when 'trade_name' then 'Nome fantasia'
           when 'document_ref' then 'Documento'
           when 'document_type' then 'Tipo de documento'
           when 'slug' then 'Slug'
           when 'primary_domain' then 'Dominio principal'
           when 'timezone' then 'Fuso horario'
           when 'locale' then 'Idioma'
           else initcap(replace(c.column_name, '_', ' '))
         end as column_label,
         'Campo ' || c.column_name || ' da tabela ' || st.table_label || '.' as column_description,
         case
           when c.data_type = 'USER-DEFINED' then c.udt_schema || '.' || c.udt_name
           when c.data_type = 'ARRAY' then c.udt_name
           else c.data_type
         end as column_type,
         (c.is_nullable = 'NO' and c.column_default is null) as is_required,
         (c.is_nullable = 'YES') as is_nullable,
         (uc.column_name is not null) as is_unique,
         (
           c.column_name = 'id'
           or c.column_name like '%\_id' escape '\'
           or c.column_name in ('status', 'code', 'slug', 'scope_kind', 'target_table', 'target_domain', 'event_name', 'counter_name')
           or c.column_name like '%\_at' escape '\'
         ) as is_filterable,
         coalesce(existing.is_importable, false) as is_importable,
         c.ordinal_position as position
  from information_schema.columns c
  join public.schema_tables st
    on st.schema_name = c.table_schema
   and st.table_name = c.table_name
   and st.status = 'active'
  left join unique_columns uc
    on uc.table_schema = c.table_schema
   and uc.table_name = c.table_name
   and uc.column_name = c.column_name
  left join public.schema_columns existing
    on existing.schema_table_id = st.id
   and existing.column_name = c.column_name
  where c.table_schema in ('public', 'audit', 'analytics')
    and c.table_name <> 'schema_migrations'
)
insert into public.schema_columns(
  schema_table_id,
  column_name,
  column_label,
  column_description,
  column_type,
  is_required,
  is_nullable,
  is_unique,
  is_filterable,
  is_importable,
  is_active,
  position,
  updated_at
)
select st.id,
       cc.column_name,
       cc.column_label,
       cc.column_description,
       cc.column_type,
       cc.is_required,
       cc.is_nullable,
       cc.is_unique,
       cc.is_filterable,
       cc.is_importable,
       true,
       cc.position,
       now()
from column_catalog cc
join public.schema_tables st
  on st.schema_name = cc.table_schema
 and st.table_name = cc.table_name
 and st.status = 'active'
on conflict (schema_table_id, column_name) do update set
  column_label = excluded.column_label,
  column_description = excluded.column_description,
  column_type = excluded.column_type,
  is_required = excluded.is_required,
  is_nullable = excluded.is_nullable,
  is_unique = excluded.is_unique,
  is_filterable = excluded.is_filterable,
  is_active = true,
  position = excluded.position,
  updated_at = now();

update public.schema_columns sc
set is_active = false,
    updated_at = now()
where sc.is_active = true
  and not exists (
    select 1
    from public.schema_tables st
    join information_schema.columns c
      on c.table_schema = st.schema_name
     and c.table_name = st.table_name
     and c.column_name = sc.column_name
    where st.id = sc.schema_table_id
      and st.status = 'active'
  );
