---
title: "Superadmin MVP Database e RLS"
source: "specs/010-superadmin-completo-v1-technical-spec.md; docs/data/data-model.md; docs/security/auth-multitenant-permissions.md; docs/security/lgpd-security-media.md; Supabase RLS/Auth docs consultados em 2026-06-23"
status: "approved-for-initial-migration"
generated_at: "2026-06-23"
---

# Superadmin MVP Database e RLS

## Objetivo

Definir o desenho fisico inicial de banco, RLS, funcoes administrativas e testes para o Superadmin MVP.

Esta spec e a referencia tecnica inicial que originou a migration SQL `packages/coelo_database/migrations/20260623191021_superadmin_foundation_v1.sql`, o seed `packages/coelo_database/seeds/2026-06-23-superadmin-foundation-seed.sql` e as validacoes em `packages/coelo_database/tests/2026-06-23-superadmin-foundation-validation.sql`.

Mudancas posteriores devem atualizar a spec correspondente e gerar novas migrations incrementais.

## Principios

- Banco primeiro: schema e RLS antecedem wireframe e Flutter.
- Negar por padrao: toda tabela exposta deve ter RLS habilitada antes de receber grants.
- Autorizacao vem de tabelas internas e sessoes, nunca de `user_metadata` mutavel pelo usuario.
- `service_role` nunca aparece em cliente Flutter, site publico ou codigo compartilhado.
- Acoes sensiveis do Superadmin passam por RPC/Edge Function ou funcao server-side auditada.
- Owner Coelo tem poder total por decisao de produto, mas nao deve virar bypass invisivel: MFA, motivo, audit log e revisao periodica sao obrigatorios.
- Dados de analytics e logs nao copiam conteudo sensivel quando IDs, codigos e resumos bastam.

## Schemas Postgres

| Schema | Uso | Exposicao |
| --- | --- | --- |
| `public` | Dados operacionais do produto que podem ser acessados por apps com RLS e grants explicitos. | Schema base exposto pela Data API; nenhuma tabela deve depender apenas do cliente para autorizacao. |
| `app_private` | Funcoes auxiliares, regras de autorizacao, RPCs e objetos que nao devem ser expostos. | Nao exposto; `SECURITY DEFINER` fica aqui, com `search_path` definido e `EXECUTE` restrito. |
| `audit` | Logs, evidencias e acoes sensiveis de suporte/acesso. | Nao exposto para clientes; leitura por RPC/backend ou views `security_invoker` futuras. |
| `analytics` | Eventos minimizados, contadores e snapshots para dashboard futuro. | Nao exposto diretamente para clientes; consumo por backend/RPC ou pipelines controlados. |

Decisao 2026-06-23: `public` e o schema base do dominio; `audit` e `analytics` separam fisicamente evidencias e dados agregaveis; `app_private` concentra logica privilegiada. Tabelas movidas para schemas nao expostos mantem FKs para `public` normalmente, mas nao recebem grants diretos para `anon` ou `authenticated`.

## Enums Iniciais

| Enum | Valores |
| --- | --- |
| `person_type` | `adult`, `child`, `service` |
| `record_status` | `draft`, `active`, `inactive`, `suspended`, `archived` |
| `institution_status` | `draft`, `onboarding`, `active`, `inactive`, `suspended`, `archived` |
| `platform_role` | `owner`, `operations`, `support`, `content`, `auditor` |
| `platform_membership_status` | `invited`, `active`, `suspended`, `revoked` |
| `subscription_status` | `draft`, `trial`, `active`, `paused`, `suspended`, `cancelled` |
| `notice_type` | `notice`, `critical_notice`, `popup`, `content_card` |
| `notice_status` | `draft`, `scheduled`, `published`, `expired`, `archived` |
| `notice_rule_effect` | `include`, `exclude` |
| `target_type` | `platform`, `institution`, `unit`, `group`, `role`, `plan`, `custom_segment` |
| `support_session_status` | `open`, `expired`, `closed`, `revoked` |
| `audit_outcome` | `success`, `denied`, `failed` |

Enums podem virar lookup tables se a Technical Spec de billing, notificacao ou analytics exigir configuracao por ambiente.

## Tabelas Obrigatorias

### Identidade Minima

| Tabela | Campos-chave | Constraints e indices |
| --- | --- | --- |
| `people` | `id`, `person_type`, `first_name`, `last_name`, `display_name`, `legal_name`, `date_of_birth`, `status`, `created_at`, `updated_at`, `deleted_at` | `id` UUID PK; `person_type` obrigatorio; `first_name` e `last_name` para nome basico separado; `date_of_birth` opcional; index parcial em ativos. |
| `person_profile_details` | `person_id`, `preferred_name`, `middle_name`, `gender`, `marital_status`, `nationality`, `naturality`, `mother_name`, `father_name`, `locale`, `timezone`, `status`, `created_at`, `updated_at` | Dados pessoais complementares e opcionais; `date_of_birth` fica em `people`; nao misturar com identidade base; pode crescer sem quebrar `people`. |
| `person_professional_details` | `person_id`, `employment_type`, `job_title`, `company_name`, `industry`, `status`, `created_at`, `updated_at` | Dados profissionais basicos; suporta CLT, PJ, empresario, freelancer, estudante e outros; `job_title` cobre o cargo. |
| `person_education_details` | `person_id`, `education_level`, `education_status`, `institution_name`, `course_name`, `field_of_study`, `start_year`, `end_year`, `is_current`, `status`, `created_at`, `updated_at` | Dados basicos de escolaridade; permite cadastrar formacao e situacao de estudo sem obrigatoriedade no MVP. |
| `person_addresses` | `person_id`, `country`, `state`, `city`, `district`, `street`, `number`, `complement`, `postal_code`, `reference`, `status`, `created_at`, `updated_at` | Endereco residencial opcional; uma linha ativa por pessoa no MVP; sem flags de cobranca/correspondencia. |
| `person_auth_links` | `person_id`, `auth_user_id`, `status`, `linked_at`, `revoked_at` | `auth_user_id` unico quando ativo; FK para `people`; FK logica para `auth.users`. |
| `person_contacts` | `person_id`, `contact_type`, `normalized_value_hash`, `masked_value`, `verified_at`, `status` | Nunca guardar contato sensivel em claro quando hash/mascara bastam; index por hash. |
| `invitations` | `scope_kind`, `institution_id`, `target_person_id`, `role_code`, `token_hash`, `expires_at`, `accepted_at`, `revoked_at`, `status` | `token_hash` unico; index por `scope_kind`, `institution_id`, `status`; convite ativo nao deve duplicar mesmo alvo/escopo. |
| `schema_tables` | `id`, `schema_name`, `table_name`, `table_label`, `table_description`, `domain`, `status`, `version`, `created_at`, `updated_at` | Catálogo oficial das tabelas suportadas; uma linha por tabela; `table_label` pode exibir o nome humano em portugues e depois em outros idiomas. |
| `schema_columns` | `id`, `schema_table_id`, `column_name`, `column_label`, `column_description`, `column_type`, `is_required`, `is_nullable`, `is_unique`, `is_filterable`, `is_importable`, `is_active`, `position`, `allowed_locales_json`, `aliases_json`, `examples_json`, `created_at`, `updated_at` | Uma linha por coluna de tabela; `column_name` e o nome canonico interno em ingles; `column_label` e o nome exibido ao usuario; `column_description` explica de forma curta o que a coluna faz; `allowed_locales_json` permite portugues hoje e outros idiomas depois; `aliases_json` guarda variantes aceitas de cabeçalho. |

### Instituicoes

| Tabela | Campos-chave | Constraints e indices |
| --- | --- | --- |
| `institutions` | `id`, `public_name`, `trade_name`, `legal_name`, `slug`, `primary_domain`, `document_ref`, `document_type`, `status`, `timezone`, `locale`, `primary_contact_person_id`, `created_by`, `created_at`, `updated_at`, `deleted_at` | `slug` unico; `primary_domain` unico quando presente; `document_ref` armazena o CNPJ/documento principal; `timezone` default `America/Sao_Paulo`; index por `status`; soft delete sem apagar auditoria; a instituicao pode existir como raiz de perfil, enquanto unidade e grupo recebem perfis operacionais/subperfis no futuro. |
| `institution_settings` | `institution_id`, `enabled_modules`, `invite_policy`, `media_limits`, `notification_policy`, `feature_flags`, `created_at`, `updated_at` | `institution_id` unico; JSONB validado por RPC antes de gravar; `enabled_modules` funciona como snapshot operativo de modulos e recursos liberados, nao como unica fonte comercial; GIN apenas quando houver query real. |
| `institution_branding` | `institution_id`, `display_name`, `logo_media_asset_id`, `cover_media_asset_id`, `accent_color`, `secondary_color`, `text_color`, `surface_color`, `approval_status`, `updated_by` | `institution_id` unico; `display_name` pode herdar `public_name` por padrao; cores opcionais validadas por design tokens; midia aponta para metadata, nao URL publica. |
| `unit_branding` | `unit_id`, `display_name`, `logo_media_asset_id`, `cover_media_asset_id`, `accent_color`, `secondary_color`, `text_color`, `surface_color`, `inherit_institution_branding`, `approval_status`, `updated_by` | Permite override por unidade; por padrao herda a instituicao; usado quando a instituicao liberar personalizacao para a unidade. |

### Planos E Limites

| Tabela | Campos-chave | Constraints e indices |
| --- | --- | --- |
| `plans` | `id`, `code`, `name`, `status`, `billing_mode`, `created_at` | `code` unico; billing automatico fora do MVP. |
| `plan_entitlements` | `plan_id`, `entitlement_key`, `value_kind`, `value_json`, `status`, `source_kind` | Unico por `plan_id + entitlement_key`; aqui ficam modulos, limites, features e regras do plano. |
| `institution_subscriptions` | `institution_id`, `plan_id`, `status`, `starts_at`, `trial_ends_at`, `manual_reason`, `changed_by`, `paused_at`, `cancelled_at` | Index por `institution_id`, `status`; `ends_at` permanece opcional e nao e obrigado para cancelar. |
| `usage_limits` | `institution_id`, `limit_key`, `limit_value`, `period_kind`, `source`, `status` | Unico por instituicao/chave/fonte ativa. |

### Plataforma Interna

| Tabela | Campos-chave | Constraints e indices |
| --- | --- | --- |
| `platform_roles` | `id`, `code`, `name`, `description`, `status`, `is_system`, `created_by`, `created_at`, `updated_at` | Catalogo de perfis do Superadmin; nasce com Owner, Operations, Support, Content e Auditor; permite criar perfis customizados depois. |
| `platform_permissions` | `id`, `code`, `module_code`, `screen_code`, `action_code`, `description`, `risk_level`, `requires_mfa`, `status`, `created_at`, `updated_at` | Catalogo do que pode ser feito no Superadmin, por modulo, tela e acao; usado por RLS/RPCs e pela UI. |
| `platform_role_permissions` | `role_id`, `permission_id`, `effect`, `conditions_json`, `granted_by`, `created_at`, `revoked_at`, `status` | Liga perfil a permissoes; `effect` permite liberar ou negar; Owner pode ter regra total, mas auditada. |
| `platform_memberships` | `person_id`, `role_id`, `status`, `scope_kind`, `scope_institution_id`, `mfa_required`, `invited_by`, `last_reviewed_at`, `created_at`, `revoked_at` | Index por `person_id`, `role_id`, `status`; Owner sempre `mfa_required = true`; vincula uma pessoa a um perfil do Superadmin. |
| `platform_member_permission_overrides` | `membership_id`, `permission_id`, `effect`, `conditions_json`, `granted_by`, `starts_at`, `expires_at`, `status` | Excecoes por usuario especifico, quando o perfil nao basta; uso deve ser raro e auditado. |
| `institution_memberships` | `person_id`, `institution_id`, `role`, `status`, `scope_kind`, `scope_unit_id`, `scope_group_id`, `mfa_required`, `invited_by`, `created_at`, `revoked_at` | Espaco equivalente para Admin; controla o perfil contextual dentro da instituicao, unidade ou grupo; pode coexistir com memberships do Superadmin. |
| `institution_role_grants` | `membership_id`, `permission_code`, `scope_kind`, `scope_id`, `granted_by`, `starts_at`, `expires_at`, `status` | Permissoes finas do Admin institucional; separadas das permissoes do Superadmin para nao misturar governanca interna com operacao da instituicao. |

### Avisos E Popups

| Tabela | Campos-chave | Constraints e indices |
| --- | --- | --- |
| `audience_segments` | `id`, `name`, `description`, `expression_json`, `version`, `status`, `created_by` | Segmentos reutilizaveis; expressao versionada e avaliada server-side; suporta qualquer filtro combinado de envio. |
| `platform_notices` | `id`, `notice_type`, `status`, `priority`, `title`, `body_text`, `cta_label`, `cta_url`, `starts_at`, `ends_at`, `created_by`, `approved_by`, `published_at`, `silencing_policy` | Index por `status`, `notice_type`, `starts_at`, `ends_at`; `body_text` suporta texto curto e `content_kind` pode diferenciar aviso visual de popup de imagem. |
| `notice_rules` | `notice_id`, `segment_id`, `effect`, `target_type`, `target_id`, `role_filter`, `conditions_json`, `rule_version`, `position` | Index por `notice_id`; index por `target_type + target_id`; `exclude` vence `include` em conflitos; aqui fica a segmentacao forte. |
| `notice_media` | `notice_id`, `media_asset_id`, `media_kind`, `expected_width`, `expected_height`, `max_bytes`, `alt_text`, `processing_status` | Uma midia principal por popup no MVP; URL publica permanente proibida; texto e midia podem coexistir. |
| `notice_receipts` | `notice_id`, `person_id`, `institution_id`, `delivered_at`, `opened_at`, `dismissed_at`, `acted_at` | Unico por `notice_id + person_id + institution_id`; index por notice e pessoa. |
| `analytics.notice_events` | `notice_id`, `event_name`, `person_id`, `institution_id`, `occurred_at`, `properties_json` | Eventos minimizados; sem conteudo infantil ou mensagem completa. |

### Importacao

| Tabela | Campos-chave | Constraints e indices |
| --- | --- | --- |
| `import_jobs` | `institution_id`, `target_domain`, `target_table`, `source_format`, `source_locale`, `target_locale`, `status`, `summary`, `created_by` | Registra a importacao inteira; `target_table` diz qual tabela sera preenchida; `target_domain` separa Superadmin, Admin, principal ou outros dominios; suporta importar qualquer entidade permitida, nao apenas um fluxo fixo. |
| `import_files` | `import_job_id`, `storage_path`, `file_name`, `mime_type`, `size_bytes`, `source_locale`, `uploaded_at` | Arquivo original e staging temporario. |
| `import_mappings` | `import_job_id`, `target_table`, `target_column`, `source_column`, `source_label`, `source_locale`, `source_aliases_json`, `transformation_json`, `position`, `description` | Mapeia linha a linha cada coluna da tabela alvo; guarda nome correto da coluna interna, nome em portugues, nomes equivalentes em outros idiomas, alias possiveis e o que a coluna faz; prepara o mesmo esquema para futuros idiomas. |
| `import_rows` | `import_job_id`, `row_number`, `payload_json`, `status`, `error_code` | Linha a linha, com processamento e validacao. |
| `import_errors` | `import_job_id`, `row_number`, `column_name`, `error_code`, `message` | Erros por linha/coluna. |
| `import_results` | `import_job_id`, `created_count`, `updated_count`, `linked_count`, `ignored_count`, `rejected_count` | Resumo final da importacao. |

Modelo funcional da importacao:

- `import_jobs` define o contexto da operacao.
- `target_table` define a tabela alvo.
- `import_mappings` descreve cada coluna da tabela alvo em nivel de linha.
- `source_column` guarda a coluna de entrada como veio no arquivo.
- `target_column` guarda o nome canonico interno em ingles.
- `source_label` guarda o nome amigavel exibido ao usuario, como portugues hoje e outros idiomas depois.
- `source_aliases_json` guarda variações aceitas do mesmo cabeçalho.
- `description` explica rapidamente a funcao daquela coluna.
- `import_rows` processa os valores linha a linha.
- `import_errors` registra problemas por linha e por coluna.
- `import_results` consolida o resultado final.

Isso permite dois modos no futuro:

1. importar um template conhecido com colunas já previstas;
2. importar qualquer tabela suportada pelo sistema, desde que exista mapeamento de colunas e validação server-side.

### Suporte, Auditoria E Analytics

| Tabela | Campos-chave | Constraints e indices |
| --- | --- | --- |
| `support_sessions` | `id`, `opened_by_person_id`, `opened_by_membership_id`, `institution_id`, `unit_id`, `reason_code`, `subreason_code`, `reported_issue`, `scope_kind`, `scope_id`, `status`, `priority`, `assigned_to_membership_id`, `resolution_summary`, `resolved_by_membership_id`, `resolved_at`, `opened_at`, `expires_at`, `closed_at` | Canal de atendimento Coelo; instituicao ou unidade podem abrir; guarda motivo, submotivo, texto enviado, responsavel interno e resolucao. |
| `support_messages` | `support_session_id`, `author_person_id`, `author_membership_id`, `message_text`, `message_kind`, `visibility`, `created_at`, `deleted_at` | Historico de mensagens do atendimento; separa conversa de suporte da permissao de acesso interno. |
| `audit.support_session_actions` | `support_session_id`, `action_code`, `object_type`, `object_id`, `sensitivity`, `outcome`, `occurred_at`, `metadata_json` | FK para sessao; toda acao sensivel tambem gera audit log. |
| `audit.audit_logs` | `actor_person_id`, `actor_membership_id`, `support_session_id`, `mfa_aal`, `action_code`, `object_type`, `object_id`, `institution_id`, `outcome`, `reason`, `before_json`, `after_json`, `occurred_at` | Append-only; index por instituicao, ator, objeto e data; resumos minimizados. |
| `analytics.analytics_events` | `event_name`, `institution_id`, `actor_pseudonym`, `context_kind`, `context_id`, `properties_json`, `occurred_at` | Index por instituicao/evento/data; sem nomes, mensagens, rotina ou dados de saude. |
| `analytics.usage_counters` | `institution_id`, `counter_name`, `period_start`, `period_end`, `dimensions_json`, `value`, `updated_at` | Unico por instituicao/contador/periodo/dimensoes. |
| `analytics.usage_snapshots` | `institution_id`, `snapshot_name`, `period_start`, `period_end`, `payload_json`, `source_cursor`, `generated_at` | Snapshot para dashboard futuro; nao vira fonte transacional. |

### Atividades Contextuais

| Tabela | Campos-chave | Constraints e indices |
| --- | --- | --- |
| `activity_definitions` | `id`, `institution_id`, `name`, `description`, `origin_scope_kind`, `origin_unit_id`, `created_by_person_id`, `status`, `created_at`, `updated_at`, `archived_at` | Definicao reutilizavel da atividade dentro da mesma instituicao; `origin_scope_kind` distingue criacao institucional ou por unidade, sem transferir a propriedade do tenant. |
| `activity_unit_links` | `activity_id`, `unit_id`, `status`, `starts_at`, `ends_at`, `created_at` | Disponibilidade da atividade por unidade; o cadastro inicial exige ao menos uma unidade e impede uso cruzado entre instituicoes. |
| `activity_group_links` | `activity_id`, `group_id`, `status`, `default_policy_json`, `created_at`, `updated_at` | Vínculo da atividade com a turma; a atividade opera sempre dentro do grupo. |
| `activity_group_assignments` | `activity_group_link_id`, `person_id`, `membership_id`, `assignment_role`, `permissions_json`, `status`, `assigned_at`, `revoked_at` | Professor/coordenador vinculado a atividade naquela turma; pode haver mais de um professor por turma, com permissoes por turma e heranca de padroes. |
| `activity_suggestions` | `institution_id`, `unit_id`, `template_code`, `seed_json`, `status`, `created_at` | Seeds sugeridos na criacao de instituicao ou unidade; nao sao catalogo global. |

### Chat Institucional

| Tabela | Campos-chave | Constraints e indices |
| --- | --- | --- |
| `conversations` | `id`, `institution_id`, `scope_kind`, `scope_id`, `conversation_type`, `title`, `status`, `policy_json`, `created_by`, `created_at`, `updated_at`, `closed_at` | Conversa unica com escopo de instituicao, unidade ou grupo/turma; permite que o responsavel veja canais como perfis sem duplicar mecanismo de chat. |
| `conversation_members` | `conversation_id`, `person_id`, `membership_id`, `member_role`, `status`, `joined_at`, `left_at`, `muted_until` | Controla quem participa e com qual papel; visibilidade depende deste vinculo e do escopo. |
| `messages` | `id`, `conversation_id`, `author_person_id`, `body_text`, `body_json`, `message_type`, `status`, `created_at`, `updated_at`, `deleted_at` | Mensagens do chat; pode receber texto, estrutura e midia via `media_links` no futuro. |
| `message_receipts` | `message_id`, `person_id`, `delivered_at`, `read_at`, `seen_at` | Entrega, leitura e visualizacao por pessoa. |
| `message_edits` | `message_id`, `edited_by`, `old_body_text`, `new_body_text`, `edited_at` | Historico de edicao quando habilitado por politica. |
| `channel_policies` | `id`, `institution_id`, `scope_kind`, `scope_id`, `channel_kind`, `policy_json`, `status`, `created_at`, `updated_at` | Regras por instituicao, unidade ou grupo: horario, resposta, historico, anexos e permissoes. |

## Funcoes E RPCs

Funcoes auxiliares em `app_private`:

| Funcao | Responsabilidade | Guardrail |
| --- | --- | --- |
| `current_person_id()` | Resolve `auth.uid()` para `people.id`. | Nao usa `user_metadata`. |
| `current_platform_membership()` | Retorna membership ativo do usuario atual. | Considera status e revogacao. |
| `is_platform_role(role)` | Verifica role interno ativo. | Usada em policies simples. |
| `has_platform_permission(permission_code, scope_kind, scope_id)` | Verifica grant direto ou Owner. | Owner retorna true, mas a acao ainda audita. |
| `has_mfa_aal2()` | Verifica `(auth.jwt()->>'aal') = 'aal2'`. | Obrigatoria para Owner em acoes sensiveis. Se a acao exigir MFA recente por janela de tempo, a Technical Spec de Auth deve confirmar uso de `amr`/timestamp ou step-up no app/RPC. |
| `has_active_support_session(institution_id)` | Confirma sessao aberta, nao expirada e com escopo. | Necessaria para Support acessar privado. |

RPCs server-side iniciais:

| RPC | Uso | Requisitos |
| --- | --- | --- |
| `create_institution_activation` | Cria instituicao, settings, plano/status, owner institucional, convite e logs. | Owner ou Operations com grant; audit log; idempotency key. |
| `change_institution_status` | Ativa, inativa ou suspende instituicao. | Motivo obrigatorio; MFA para Owner; audit log. |
| `change_institution_plan` | Altera plano/status manual. | Motivo obrigatorio; audit log; sem billing automatico. |
| `invite_platform_member` | Convida Operations, Support, Content, Auditor ou outro Owner. | Apenas Owner; novo Owner exige MFA. |
| `publish_platform_notice` | Publica aviso/popup e congela regras de audiencia. | Owner, Operations ou Content com grant; auditoria. |
| `open_support_session` | Abre suporte auditado. | Support/Owner com motivo e escopo. |
| `record_usage_snapshot` | Consolida contadores/snapshots. | Server-side; nao chamado diretamente por cliente comum. |

Qualquer `SECURITY DEFINER` deve ficar em `app_private`, definir `search_path`, validar `auth.uid()`, revogar `EXECUTE` de `PUBLIC` e conceder execucao apenas aos roles necessarios. Se uma funcao puder ser `SECURITY INVOKER`, preferir essa opcao.

## RLS Por Grupo De Tabelas

| Grupo | Select | Insert/Update/Delete |
| --- | --- | --- |
| Instituicoes | Owner, Operations, Auditor; Support apenas com sessao ativa; Admin institucional por policies futuras fora desta spec. | Via RPC; Owner/Operations com grant; suspensao exige motivo. |
| Planos e limites | Owner, Operations, Auditor. | Via RPC; Owner/Operations com grant; sempre auditado. |
| Platform memberships/grants | Owner full; Auditor leitura; usuario pode ler o proprio membership. | Via RPC; apenas Owner; novo Owner exige MFA. |
| Avisos/popups | Equipe Coelo autorizada ve configuracao; destinatarios veem apenas recibos/avisos calculados para si. | Via RPC; Owner/Operations/Content com grant; publish congela regras. |
| Atividades contextuais | Owner, Operations e Admin institucional autorizado; unidade pode inserir apenas quando a capacidade específica estiver habilitada no perfil; professor/coordenador le apenas o que estiver vinculado ao grupo. | Via RPC transacional e RLS; atividade, unidade e turma mantêm o mesmo `institution_id`; criação pela unidade herda a instituição, força a unidade de origem como primeiro vínculo e não autoriza unidades irmãs. A instituição pode atualizar ou desativar atividades originadas em suas unidades. |
| Suporte | Owner, Auditor e Support veem sessoes conforme papel; Support ve as proprias sessoes. | Abrir/fechar por RPC; acoes sensiveis exigem sessao ativa. |
| Audit logs | Owner e Auditor leem por permissao `audit.read`; Support le logs das proprias sessoes somente via RPC especifica quando necessario. | Schema `audit`; append-only por RPC/trigger; sem grants diretos para cliente. |
| Analytics/counters/snapshots | Owner, Operations e Auditor leem por permissao `analytics.read`; raw limitado. | Schema `analytics`; escrita server-side; cliente comum nao insere raw events sensiveis. |

Policies devem usar `TO authenticated` com predicate de autorizacao; nunca `TO authenticated` sozinho. `UPDATE` deve ter `USING` e `WITH CHECK`.

## Indices Minimos

- `institutions(slug)` unique.
- `institutions(lower(primary_domain))` unique parcial quando `primary_domain is not null`.
- `institutions(status, created_at)`.
- `person_auth_links(auth_user_id)` unique ativo.
- `platform_roles(code)` unique.
- `platform_permissions(code)` unique.
- `platform_role_permissions(role_id, permission_id, status)` unique ativo.
- `platform_memberships(person_id, role_id, status)`.
- `platform_member_permission_overrides(membership_id, permission_id, status)` unique ativo.
- `institution_subscriptions(institution_id, status, starts_at desc)`.
- `activity_definitions(institution_id, status, created_at)`.
- `activity_unit_links(activity_id, unit_id, status)`; ao menos um vínculo ativo por atividade.
- `activity_group_links(activity_id, group_id, status)`.
- `activity_group_assignments(activity_group_link_id, person_id, status)`; múltiplas linhas por turma são permitidas para professores diferentes.
- Criacao de `activity_definitions` e do primeiro `activity_unit_links` deve ocorrer na mesma RPC transacional, impedindo atividade sem unidade ou com `institution_id` informado livremente pelo cliente.
- `notice_rules(notice_id, position)`.
- `notice_rules(target_type, target_id)` quando `target_id is not null`.
- `notice_receipts(notice_id, person_id, institution_id)` unique.
- `support_sessions(institution_id, status, expires_at)`.
- `audit.audit_logs(institution_id, occurred_at desc)`.
- `audit.audit_logs(actor_person_id, occurred_at desc)`.
- `audit.audit_logs(object_type, object_id, occurred_at desc)`.
- `analytics.analytics_events(institution_id, event_name, occurred_at desc)`.
- `analytics.usage_counters(institution_id, counter_name, period_start, period_end)` unique.

JSONB so recebe GIN quando houver query real em producao ou teste de performance que justifique.

## Seed De Teste

O seed minimo deve criar:

- `owner_coelo`: pessoa adulta, auth link e platform membership `owner` ativo com MFA exigida.
- `ops_coelo`: Operations ativo.
- `support_coelo`: Support ativo.
- `content_coelo`: Content ativo.
- `auditor_coelo`: Auditor ativo.
- `tenant_a` e `tenant_b` com planos/status diferentes.
- Owner institucional para `tenant_a` e `tenant_b`.
- Uma unidade e um grupo por tenant para validar segmentacao.
- Um aviso/popup com regra para `tenant_a` e exclusao de `tenant_b`.
- Uma support session aberta para `tenant_a`.
- Eventos e contadores iniciais para validar snapshots.

## Testes Obrigatorios

| ID | Cenario | Resultado esperado |
| --- | --- | --- |
| DB-RLS-001 | Usuario sem platform membership tenta ler `institutions`. | Negado ou vazio. |
| DB-RLS-002 | Operations cria instituicao via RPC. | Instituicao, settings, subscription, convite e audit log criados. |
| DB-RLS-003 | Operations tenta criar Owner Coelo. | Negado. |
| DB-RLS-004 | Owner sem `aal2` tenta acao sensivel. | Negado. |
| DB-RLS-005 | Owner com `aal2` convida novo Owner. | Convite criado e auditado. |
| DB-RLS-006 | Support sem sessao ativa tenta acessar dados privados. | Negado. |
| DB-RLS-007 | Support com sessao ativa de `tenant_a` tenta acessar `tenant_b`. | Negado. |
| DB-RLS-008 | Content publica popup para segmento de `tenant_a`. | Recibos/eventos apenas para audiencia calculada. |
| DB-RLS-009 | Auditor tenta alterar plano/status. | Negado; leitura permitida. |
| DB-RLS-010 | Evento raw alimenta contador/snapshot. | Agregado criado sem conteudo sensivel. |
| DB-RLS-011 | Acesso direto por ID de outro tenant. | Negado por RLS. |
| DB-RLS-012 | Audit log e append-only. | Insert server-side permitido; update/delete pelo cliente negado. |

## Ordem Da Foundation Executada

1. Tipos/enums e schemas.
2. Identidade minima e convites.
3. Instituicoes, settings e branding.
4. Planos, entitlements, subscriptions e limits.
5. Platform memberships e grants.
6. Avisos/popups e audiencia.
7. Suporte, auditoria e analytics.
8. Funcoes auxiliares e RPCs.
9. RLS, grants e seeds.
10. Testes SQL de isolamento.

## Migration Incremental 2026-06-23

`packages/coelo_database/migrations/20260623203230_schema_boundaries_catalog_v1.sql` consolida a decisao de schemas:

- cria `analytics`;
- move `audit_logs` e `support_session_actions` para `audit`;
- move `analytics_events`, `notice_events`, `usage_counters` e `usage_snapshots` para `analytics`;
- revoga grants diretos de `anon` e `authenticated` nos schemas `audit` e `analytics`;
- adiciona permissao `analytics.read` para Owner, Operations e Auditor;
- troca policies amplas baseadas em `platform.read` por `audit.read` e `analytics.read`;
- popula `schema_tables` e `schema_columns` a partir de `information_schema` para cobrir todas as tabelas/colunas ativas em `public`, `audit` e `analytics`.

## Pendencias Para Proximas Migrations

- Confirmar estrategia final de CPF/documentos legais adultos e institucionais.
- Validar juridicamente o poder total do Owner Coelo antes de dados reais.
- Escolher ferramenta de teste SQL/RLS em `packages/coelo_database`.
- Refinar RPCs finais, policies completas e convencoes de migration Supabase conforme os proximos fluxos do Superadmin forem implementados.
