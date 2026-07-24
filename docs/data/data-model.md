---
title: "Coelo PRD Modelo de Dados Master Oficial v1"
source_file: "Coelo PRD Modelo de Dados Master Oficial v1.docx"
source_copy: "docs/source/originals/docx/Coelo PRD Modelo de Dados Master Oficial v1.docx"
original_path: "C:/Users/adrie/Desktop/Coelo/PRD/Coelo PRD Modelo de Dados Master Oficial v1.docx"
supplemental_source: "decisions/0014-contextual-activities-and-delegated-unit-creation.md; packages/coelo_database/migrations/20260724120307_contextual_activities_foundation.sql"
contextual_access_source: "decisions/0015-contextual-people-authorizations-attendance.md; specs/015-contextual-people-access-attendance.md"
status: "derived-from-official-docx"
version: "v1"
generated_at: "2026-07-24"
---

<!-- Documento derivado de fonte oficial. Edite a fonte DOCX ou registre uma decisao antes de alterar conteudo normativo. -->
| Coluna 1 | COELO<br>PRD Modelo de Dados Master Oficial v1<br>Supabase/Postgres · modelo conceitual e governança |
| --- | --- |

Versão: v1.0 | Data: 21/06/2026 | Status: Draft para validação

| Modelo compartilhado para os PRDs de Superadmin, Admin, App, Auth e LGPD, com isolamento multi-tenant e histórico auditável. |
| --- |

Simples como Airbnb Visual como Instagram Confiável como escola

Documento derivado do Product Vision Oficial v1 e do PRD Master Oficial v1 do Coelo.

# Sumário executivo do documento

| # | Seção |
| --- | --- |
| 1 | Capa e controle de versão |
| 2 | Resumo executivo |
| 3 | Princípios de modelagem |
| 4 | Escopo |
| 5 | Nomenclatura |
| 6 | Mapa de domínios |
| 7 | Identidade e Auth |
| 8 | Multi-tenant e vínculos |
| 9 | Superadmin e planos |
| 10 | Conteúdo social |
| 11 | Mídia |
| 12 | Chat |
| 13 | Agenda |
| 14 | Rotina |
| 15 | Notificações |
| 16 | Importações |
| 17 | Auditoria e analytics |
| 18 | Relacionamentos críticos |
| 19 | Regras de integridade |
| 20 | RLS e isolamento |
| 21 | Retenção e exclusão |
| 22 | Requisitos funcionais |
| 23 | Critérios de aceite |
| 24 | Riscos e mitigação |
| 25 | Decisões oficiais |
| 26 | Perguntas em aberto |
| 27 | Próximas specs |
| 28 | Fontes e referências |

# 1. Capa e controle de versão

| Campo | Valor |
| --- | --- |
| Documento | PRD Modelo de Dados Master Oficial v1 — Coelo |
| Owner | Produto + Engenharia de Dados Coelo |
| Público interno | Produto, design, engenharia, dados, segurança, jurídico, operações e agentes de coding. |
| Status | Draft para revisão e versionamento. |
| Base interna | Product Vision Oficial v1; PRD Master Oficial v1; História da Logo e Marca Oficial v1; mapa competitivo e decisões do fundador. |
| Escopo | Modelo conceitual para Postgres/Supabase, entidades, vínculos, integridade, eventos, auditoria e preparação de migrations. |

| Versão | Data | Mudança | Responsável |
| --- | --- | --- | --- |
| v1.0 | 21/06/2026 | Criação do PRD específico alinhado ao PRD Master e às decisões oficiais do fundador. | Produto Coelo |
| v1.1 | A definir | Revisão após specs técnicas, protótipo e validação do piloto. | Produto + Engenharia |
| v2.0 | A definir | Atualização após piloto real e priorização da próxima fase. | Produto + Negócio |

# 2. Resumo executivo

O Modelo de Dados Master define a linguagem comum dos seis PRDs. Ele não é uma migration final, mas fixa entidades, responsabilidades e relacionamentos para evitar que Superadmin, Admin e App criem modelos incompatíveis.

O ponto central é separar pessoa global de dados contextuais. Uma criança pode estar em várias instituições, unidades e grupos sem ser duplicada. Responsáveis são relacionados à criança, mas a visibilidade é concedida por instituição. Todas as tabelas de tenant devem possuir institution_id direto ou derivável por caminho seguro.

| Regra estrutural<br>Pessoa global + contexto institucional + memberships/permissões. Nunca duplicar uma pessoa apenas para representar outro papel ou outra instituição. |
| --- |

# 3. Princípios de modelagem

- Multi-tenant compartilhado com institution_id.

- Pessoa global; usuário Auth opcional.

- Papéis e vínculos como tabelas próprias, não colunas fixas na pessoa.

- Dados infantis mínimos e separados por finalidade/contexto.

- Histórico e soft delete quando necessário à auditoria.

- RLS e integridade por FK, não por convenção de front-end.

- Eventos de produto separados de audit logs.

- Nomes físicos finais e tipos SQL serão fechados na Technical Spec.

# 4. Escopo

| Incluído | Não incluído nesta versão |
| --- | --- |
| Entidades conceituais e relacionamentos. | DDL/migrations finais. |
| Chaves e escopos esperados. | Índices e planos de execução detalhados. |
| Regras de tenant, pessoa e contexto. | Políticas de retenção com prazos fechados. |
| Objetos de mídia, chat, agenda e rotina. | Integrações financeiras e matrícula digital completas. |
| Importação, auditoria e analytics. | Warehouse e dashboards finais. |

# 5. Nomenclatura

| Termo de produto | Termo lógico sugerido | Observação |
| --- | --- | --- |
| Instituição | institutions | Tenant principal. |
| Unidade | units | Campus, sede ou operação local. |
| Grupo/turma | groups | Tipo diferencia turma, equipe ou atendimento. |
| Pessoa | people | Adulto ou criança, com ou sem login. |
| Usuário | auth.users + user_profiles | Pessoa com Auth ativo. |
| Criança contextual | child_contexts | Pessoa dentro de uma instituição. |
| Responsável | guardian_links + permissions | Relação global e autorização contextual. |
| Papel/vínculo | memberships | Escopo e datas. |
| Perfil social | social_profiles | Instituição, unidade, grupo ou Coelo. |

# 6. Mapa de domínios

| Domínio | Entidades principais |
| --- | --- |
| Identidade | people, person_profile_details, person_professional_details, person_education_details, person_addresses, auth.users, user_profiles, usernames, contacts/identities, schema_tables, schema_columns. |
| Tenancy | institutions, units, groups, memberships, child_contexts. |
| Família | guardian_links, guardian_context_permissions. |
| Superadmin | platform_memberships, plans, institution_subscriptions, platform_notices, support_sessions, import_jobs. |
| Social | social_profiles, follows, posts, post_audiences, reactions, read_receipts, stories/now, moments. |
| Mídia | media_assets, media_variants, media_consents/access policies. |
| Chat | conversations, conversation_members, messages, message_receipts. |
| Agenda | agenda_events, agenda_audiences, agenda_responses, authorizations. |
| Rotina | routine_templates, routine_entries, routine_items, occurrences. |
| Notificações | notifications, notification_preferences, device_tokens. |
| Importação | import_jobs, import_files, import_rows/errors. |
| Dados | audit.audit_logs, audit.support_session_actions, analytics.analytics_events, analytics.notice_events, analytics.usage_counters, analytics.usage_snapshots. |

# 7. Identidade e Auth

| Entidade | Responsabilidade | Chaves/observações |
| --- | --- | --- |
| people | Pessoa global. | id; tipo; primeiro nome; sobrenome; nome público; nome legal; data de nascimento opcional; status; soft delete; referência de dedupe. |
| person_profile_details | Dados pessoais complementares. | preferred_name, middle_name, gender, marital_status, nationality, naturality, parents, locale, timezone. |
| person_professional_details | Vida profissional. | employment_type, job_title, company_name, industry. |
| person_education_details | Escolaridade. | education_level, education_status, institution_name, course_name, field_of_study, start_year, end_year. |
| person_addresses | Endereço residencial. | geografia básica, número, complemento, CEP, referência e status. |
| auth.users | Credencial Supabase. | Vínculo 1:1 opcional com people. |
| person_auth_links | Vínculo pessoa-auth. | person_id, auth_user_id, status, linked_at, revoked_at. |
| user_profiles | Configuração de conta. | person_id/user_id; avatar; preferências; exibido separado da identidade global. |
| usernames | @username global. | Único; owner_person_id ou owner_context; tipo e status. |
| person_contacts | E-mail/celular verificados ou de contato. | Não duplicar segredos; separar verificação. |
| adult_identifiers | CPF de adultos. | Armazenamento protegido; hash/normalização conforme Technical Spec. |
| invitations | Convites. | Target, contexto, papel, token hash, status e expiração. |
| schema_tables | Catálogo de tabelas. | Nome, rótulo, domínio, versão e status. |
| schema_columns | Catálogo de colunas. | Nome canonico, nome exibido, descrição, tipo, imports e localidades. |

# 8. Multi-tenant e vínculos

| Entidade | Responsabilidade | Campos/relacionamentos |
| --- | --- | --- |
| institutions | Tenant. | id, status, settings, plan reference, branding, document_ref. |
| units | Unidade. | institution_id. |
| groups | Grupo/turma/equipe. | institution_id, unit_id, type. |
| memberships | Pessoa–contexto–papel. | person_id, institution_id, unit_id/group_id opcionais, role, status, dates. |
| child_contexts | Criança dentro do tenant. | person_id + institution_id; dados locais e status. |
| child_group_links | Criança em grupos. | child_context_id, group_id, status/dates. |
| guardian_links | Relação familiar global. | guardian_person_id, child_person_id, relation, status. |
| guardian_context_permissions | Acesso familiar por tenant. | guardian_link_id, child_context_id, permissions/status. |

Interpretação oficial de D1: a criança é uma pessoa global. Cada instituição cria ou vincula um child_context próprio e conecta esse contexto às unidades, grupos e responsáveis autorizados. O responsável enxerga os contextos em que guardian_context_permissions estiver ativo.

# 9. Superadmin e planos

| Entidade | Uso |
| --- | --- |
| platform_roles | Perfis do Superadmin. |
| platform_permissions | Permissões por módulo, tela e ação. |
| platform_role_permissions | Permissões liberadas por perfil. |
| platform_memberships | Pessoas vinculadas a perfis internos Coelo. |
| platform_member_permission_overrides | Exceções de permissão por usuário. |
| institution_memberships | Perfis contextuais do Admin institucional. |
| plans | Catálogo de planos e limites preparados para futuro. |
| institution_subscriptions | Plano/status/datas por instituição; operação manual no MVP. |
| usage_limits/analytics.usage_counters | Limites e consumo, inicialmente informativos. |
| platform_notices | Avisos globais/segmentados. |
| notice_audiences/receipts | Audiência e leitura. |
| support_sessions | Canal de atendimento Coelo aberto por instituição ou unidade. |
| support_messages | Mensagens do atendimento Coelo. |

- Registrar estrutura para adicional após dois responsáveis por criança/contexto, sem calcular cobrança no MVP.

- Nenhum status de pagamento deve ser tratado como fonte financeira definitiva nesta versão.

# 10. Conteúdo social

| Entidade | Uso | Observação |
| --- | --- | --- |
| social_profiles | Perfil de Coelo/instituição/unidade/grupo. | owner_context e visibility. |
| follows | Seguimento automático/manual. | reason, mute settings. |
| posts | Flow/comunicados. | author, profile, body, type, status, requires_read. |
| post_audiences | Segmentação. | institution/unit/group/role/child opcional. |
| post_reactions | Reações simples. | MVP. |
| post_comments | Comentários. | Preparar somente; desativado no MVP. |
| read_receipts | Leitura confirmada. | Usuário/pessoa, objeto e timestamp. |
| now_items | Conteúdo temporário. | expires_at padrão 24h. |
| moments | Vídeos privados. | Até 2 minutos; validação de duração. |

# 11. Mídia

| Entidade | Uso |
| --- | --- |
| media_assets | Registro lógico do arquivo, owner, contexto, classificação e status. |
| media_variants | Thumbnail, versão comprimida e transformações. |
| media_links | Liga mídia a post, Now, Moment, rotina, chat ou agenda. |
| media_access_classification | Privada por tenant, grupo, criança ou sensível. |
| media_consent_records | Autorização/restrição de imagem quando aplicável. |
| media_download_policy | Bloqueio por padrão e eventuais exceções futuras. |

Prazos de retenção de mídia não estão definidos. O modelo deve possuir campos de classificação, criação, expiração/remoção futura e estado de exclusão sem fixar datas neste PRD.

# 12. Chat

| Entidade | Uso |
| --- | --- |
| conversations | Chat por instituição, unidade ou grupo/turma. |
| conversation_members | Membros autorizados e papel no canal. |
| messages | Autor, conteúdo, status, soft delete e futura mídia. |
| message_receipts | Entrega/leitura. |
| message_edits | Histórico de edição quando habilitado. |
| channel_policies | Regras por instituição, unidade ou grupo: horários, anexos, respostas e histórico. |

- Professor–responsável depende de vínculo válido com criança/grupo.

- Responsável–responsável fica fora do MVP.

- Admin autorizado pode ter acesso conforme escopo de grupos e auditoria.

# 13. Agenda

| Entidade | Uso |
| --- | --- |
| agenda_events | Evento, contexto, datas e conteúdo. |
| agenda_audiences | Instituição, unidade, grupo, papel ou criança. |
| agenda_responses | Sim/Não/Talvez e ator. |
| agenda_authorizations | Ciência/autorização simples por responsável. |
| agenda_attachments | Mídia/PDF privado. |
| agenda_reminders | Agendamentos de notificação. |

# 14. Rotina

| Entidade | Uso |
| --- | --- |
| routine_templates | Schema de itens por instituição/unidade/grupo. |
| routine_template_items | Alimentação, sono, higiene, saúde, humor, atividades e ocorrências. |
| routine_entries | Registro por criança/data/grupo/autor/status. |
| routine_values/items | Valores estruturados e observações. |
| routine_media_links | Mídia autorizada. |
| routine_edits | Histórico de correções com motivo. |
| occurrences | Ocorrências que podem exigir fluxo específico. |

# 15. Notificações

| Entidade | Uso |
| --- | --- |
| notifications | Mensagem in-app e estado. |
| notification_preferences | Preferências por tipo e usuário. |
| device_tokens | Tokens de push por dispositivo. |
| notification_deliveries | Tentativas, canal, status e erro. |
| notification_templates | Textos com payload mínimo. |

# 16. Importações

| Entidade | Uso |
| --- | --- |
| import_jobs | Instituição, tipo, ator, status e resumo. |
| import_files | Metadados de CSV/XLSX e localização temporária. |
| import_mappings | Coluna → campo. |
| import_rows | Staging e estado por linha. |
| import_errors | Código, campo, linha e mensagem. |
| import_results | Criados, atualizados, vinculados, ignorados e rejeitados. |

- Arquivos não devem ser fonte permanente de dados após processamento.

- Prazos de exclusão dos arquivos temporários ainda serão definidos no PRD LGPD/Technical Spec.

# 17. Auditoria e analytics

| Entidade | Finalidade | Conteúdo |
| --- | --- | --- |
| audit.audit_logs | Evidência de ação sensível. | Ator, contexto, ação, objeto, timestamp e resumo before/after minimizado. |
| analytics.analytics_events | Uso do produto. | event_name, ator pseudonimizado/contexto, timestamp, properties mínimas. |
| analytics.usage_counters | Leitura rápida futura. | Agregados por instituição e período. |
| error_logs | Saúde técnica. | Código, contexto técnico e correlação, sem conteúdo sensível desnecessário. |

# 18. Relacionamentos críticos

| Relacionamento | Cardinalidade lógica | Regra |
| --- | --- | --- |
| people ↔ auth.users | 1 ↔ 0..1 | Pessoa pode existir sem login. |
| people ↔ memberships | 1 ↔ N | Vários papéis/contextos. |
| people(child) ↔ child_contexts | 1 ↔ N | Uma criança em várias instituições. |
| guardian_links ↔ child_contexts | N ↔ N via permissions | Autorização por tenant. |
| institutions ↔ units ↔ groups | 1:N:N | Hierarquia operacional. |
| social_profiles ↔ posts | 1:N | Conteúdo privado. |
| conversations ↔ members/messages | 1:N | Membros controlam visibilidade. |
| routine_entries ↔ child_contexts | N:1 | Rotina é contextual. |

# 19. Regras de integridade

- FKs devem impedir vínculo de unidade/grupo a instituição incorreta.

- Guardian permission deve apontar para criança e instituição coerentes.

- Membership de grupo deve ser compatível com unit/institution do grupo.

- Username é globalmente único e possui estado de reserva/alteração definido na spec.

- CPF adulto é normalizado e protegido; unicidade e exceções serão definidas tecnicamente.

- Soft delete não remove trilha de auditoria.

- Mídia não pode existir sem owner/contexto e classificação.

- Eventos e logs não substituem dados transacionais.

# 20. RLS e isolamento

- Todas as tabelas tenant-data têm institution_id direto ou derivável por FK segura.

- Policies devem negar acesso sem membership/guardian permission válido.

- Funções auxiliares de autorização devem ser pequenas, versionadas e testadas.

- Storage usa policies equivalentes aos dados associados.

- Realtime usa autorização específica de canais.

- Service role somente no backend/Edge Functions.

- Seeds de teste incluem dois tenants, responsável multi-instituição, professor/responsável e coordenador multi-unidade.

## Aditivo 2026-06-23 - Schemas Postgres

A decisao tecnica inicial de schemas para o Coelo e:

- `public`: schema base do dominio operacional, com tabelas acessadas pelas aplicacoes via RLS e grants explicitos.
- `app_private`: funcoes auxiliares, RPCs e logica privilegiada; nao deve ser exposto ao cliente.
- `audit`: logs, evidencias e acoes sensiveis de suporte/acesso; sem grants diretos para `anon` ou `authenticated`.
- `analytics`: eventos minimizados, contadores e snapshots para dashboard futuro; sem grants diretos para `anon` ou `authenticated`.

`schema_tables` e `schema_columns` continuam em `public` como catalogo tecnico do produto, mas passam a registrar tambem tabelas de `audit` e `analytics` por `schema_name`.

# 21. Retenção e exclusão

| Decisão pendente<br>Prazos de retenção de mídia, rotina e chat não serão definidos nesta versão. As entidades devem possuir estados e timestamps que permitam aplicar a política quando aprovada. |
| --- |

- Separar exclusão lógica, anonimização e remoção física.

- Preservar audit logs quando houver base e necessidade legítima definida juridicamente.

- Solicitações de titular exigem mapeamento de dependências e exportação futura.

- Backups e arquivos temporários devem entrar na política futura.

# 22. Requisitos funcionais

| ID | Área | Requisito |
| --- | --- | --- |
| DM-RF-001 | Pessoa | Manter pessoa global. |
| DM-RF-002 | Contexto infantil | Permitir child_context por instituição. |
| DM-RF-003 | Família | Separar relação global e autorização contextual. |
| DM-RF-004 | Multi-papel | Modelar memberships com escopo. |
| DM-RF-005 | Planos | Preparar plano/limites sem cobrança automática. |
| DM-RF-006 | Responsáveis adicionais | Preparar medição após dois responsáveis. |
| DM-RF-007 | Social | Modelar Flow, reações, Now e Moments. |
| DM-RF-008 | Comentários | Preparar entidade sem habilitar no MVP. |
| DM-RF-009 | Mídia | Classificar e ligar a objetos privados. |
| DM-RF-010 | Chat | Modelar membros, mensagens e recibos. |
| DM-RF-011 | Agenda | Modelar respostas e autorizações. |
| DM-RF-012 | Rotina | Modelar templates, entradas e edições. |
| DM-RF-013 | Importação | Modelar staging e erros CSV/XLSX. |
| DM-RF-014 | Dados | Separar audit logs e analytics. |

# 23. Critérios de aceite

- O modelo representa uma criança em duas instituições sem duplicar people.

- Dois responsáveis podem ter permissões diferentes no mesmo child_context.

- Revogar acesso em um tenant não afeta outro tenant.

- Posts, chat, agenda e rotina possuem caminho inequívoco até institution_id.

- Comentários podem permanecer desabilitados sem alterar posts/reactions.

- Planos e contagem de responsáveis existem sem cobrança automática.

- Importação guarda resultado por linha e não mistura tenants.

- Policies RLS podem ser testadas com o seed recomendado.

# 24. Riscos e mitigação

| Risco | Impacto | Mitigação |
| --- | --- | --- |
| Modelo excessivamente genérico | Alto | Domínios claros e tipos contextuais. |
| Duplicar pessoa por tenant | Alto | people global + child_contexts/memberships. |
| RLS com joins caros | Alto | FKs, índices e funções analisadas na Technical Spec. |
| Logs com dados sensíveis | Crítico | Resumos minimizados e classificação. |
| Retenção indefinida | Alto | Campos preparados e decisão jurídica pendente explícita. |
| Importação quebrar integridade | Alto | Staging, validação e transação/rollback conforme spec. |

# 25. Decisões oficiais

| Decisão | Valor oficial v1 |
| --- | --- |
| Pessoa | Global. |
| Criança | Pessoa global com contextos por instituição. |
| Hierarquia | Instituição → unidade → grupo; criança pode estar em múltiplos níveis/contextos. |
| Responsável | Relação + autorização por contexto. |
| CPF adultos | Obrigatório. |
| Username infantil | Global, pesquisa restrita. |
| Importação | CSV/XLSX para entidades aplicáveis. |
| Planos | Manual no MVP, preparado para automação. |
| Responsáveis adicionais | Preparar regra após dois, sem cobrança. |
| Retenção | Prazos não definidos. |
| Download mídia | Bloqueado por padrão. |

# 26. Atividades Contextuais

- `Atividade` e um conceito reutilizavel por turma dentro da mesma instituicao.
- A atividade pertence a instituicao, mas pode ser criada pela propria instituicao ou por uma unidade autorizada.
- Quando criada por uma unidade, herda automaticamente a instituicao-mae, registra a unidade de origem e nasce vinculada a ela.
- A instituicao pode ajustar, ampliar, restringir, arquivar ou desativar uma atividade criada por qualquer unidade filha.
- A criacao por unidade depende de uma capacidade especifica habilitada na gestao do perfil do ator; a autorizacao deve ser validada no servidor.
- Um ator limitado a unidade nao pode vincular a atividade a unidades irmas ou grupos fora do seu escopo sem permissao institucional adicional.
- Toda atividade nasce vinculada a pelo menos uma unidade e pode ser expandida para outras depois.
- A atividade pode ser vinculada a uma ou mais turmas da mesma instituicao.
- O professor ou coordenador atua no contexto da atividade naquela turma, com permissoes herdadas e overrides contextuais.
- Uma mesma atividade pode ter mais de um professor na mesma turma.
- O banco deve tratar o dominio como entidade propria, nao como mero atributo da turma.

## 26.1 Modelo fisico implementado

| Tabela | Responsabilidade |
| --- | --- |
| `activity_definitions` | Definicao pertencente a instituicao, origem institucional/unidade, criador, status e arquivamento. |
| `activity_unit_links` | Unidades em que a atividade esta disponivel; ao menos um vinculo ativo e obrigatorio. |
| `activity_group_links` | Reutilizacao da atividade em uma turma da mesma instituicao e unidade. |
| `activity_group_assignments` | Pessoas/memberships associados a atividade naquela turma, permitindo varios professores. |
| `activity_capabilities` | Catalogo extensivel de capacidades contextuais. |
| `activity_permission_profiles` | Perfil institucional ou de unidade aplicavel ao vinculo com turma. |
| `activity_permission_profile_capabilities` | Allow/deny normalizado por perfil e capacidade. |
| `activity_assignment_permission_overrides` | Allow/deny final por atribuicao de pessoa, sem extrapolar o vinculo. |
| `activity_suggestions` | Sugestoes institucionais ou de unidade; o seed de produto permanece pendente. |

FKs compostas preservam instituicao e unidade em definicoes, vinculos, grupos e memberships. A criacao pela unidade nao aceita `institution_id` do cliente: `create_activity_for_unit` deriva o owner institucional e grava definicao e primeiro vinculo em uma unica transacao. Todas as tabelas expostas possuem RLS e grants explicitos.

# 27. Perguntas em aberto

- Resolvido em 2026-06-23: `public`, `app_private`, `audit` e `analytics` sao os schemas iniciais. Novos schemas exigem spec ou ADR.

- CPF será armazenado cifrado, tokenizado ou com hash auxiliar para busca?

- Quais flags compõem guardian_context_permissions?

- Como provar autorização institucional para pesquisa de username infantil?

- Quais entidades terão soft delete obrigatório?

- Quais prazos de retenção serão aprovados?

- Qual estratégia de particionamento/arquivamento após escala?

# 28. Próximas specs

- ERD físico com cardinalidades e constraints.

- Migration plan Supabase/Postgres.

- Catálogo de enums/status e dicionário de dados.

- Policies RLS por tabela e testes automatizados.

- Seed de dois tenants e cenários multi-papel.

- Plano de importação CSV/XLSX e reconciliação.

# 29. Aditivo 2026-07-24 — Pessoas, Autorizações E Assiduidade

Este aditivo projeta o modelo físico aprovado para a próxima etapa. Ele não declara essas estruturas como já migradas.

## 29.1 Autorização profissional

- A identidade continua global em `people`; o acesso nasce de vínculo contextual.
- Papéis profissionais padrão ou customizados devem ser atribuídos por instituição, unidade, grupo, atividade e, quando necessário, criança.
- A autorização efetiva combina concessões do papel, concessões diretas, negações explícitas e escopo. Uma negação explícita da pessoa prevalece.
- O escopo pode incluir descendentes automaticamente ou somente itens selecionados. Acesso a uma unidade não inclui unidades irmãs.
- O vínculo profissional com criança deve existir como entidade própria; não deve ser inferido apenas do grupo.

## 29.2 Família E Pessoas Autorizadas

- O vínculo responsável–criança deve guardar um código de catálogo (`pai`, `mae`, `avo`, `ava`, `irmao`, `irma`, `padrasto`, `madrasta`, `primo`, `prima`, `tio`, `tia`, `outro`) e um detalhe livre separado.
- Convites de responsáveis são emitidos apenas por instituição ou unidade. Um mesmo convite pode relacionar várias crianças, com vínculo e permissões próprios por criança.
- Permissões familiares devem ser flags normalizadas por responsável, criança e contexto. Nascem habilitadas no convite, mas instituição ou unidade pode alterá-las.
- Pessoas autorizadas para emergência, retirada ou transporte não possuem login por esse cadastro. Seus dados, tipos de autorização, crianças e contextos devem ser modelados separadamente do responsável usuário.
- Autorizações criadas por responsável habilitado tornam-se ativas imediatamente; suspensão institucional ou da unidade exige motivo, auditoria e notificação.

## 29.3 Atividade

- `activity_definitions` permanece como identidade única pertencente à instituição.
- Origem (`institution` ou `unit`), distribuição (`institution_standard` ou `unit_local`) e política (`optional`, `mandatory`, `fixed`) são dimensões distintas.
- Promover uma atividade local a padrão institucional altera sua governança sem criar outra definição.
- Participação pode abranger todo o grupo ou crianças selecionadas.
- Cada capacidade da atividade deve admitir política institucional `required`, `default_on`, `default_off` ou `prohibited`; quando não estiver bloqueada, a unidade administra o valor efetivo.

## 29.4 Conversa

- Conversas devem guardar escopo institucional, de unidade, grupo ou atividade.
- Participantes são pessoas reais; o contexto de exibição deve preservar nome, papel exercido e zero, uma ou várias crianças relacionadas no momento da mensagem.
- Encerrado o vínculo institucional da criança, módulos operacionais desaparecem e conversas históricas ficam somente leitura conforme retenção aplicável.

## 29.5 Assiduidade

O domínio de presença deve ser independente e referenciar instituição, unidade, grupo, atividade opcional, criança e período/aula. A implementação física deverá separar ocorrência/lista oficial, aviso do responsável, catálogo e detalhe do motivo, anexos privados, revisão, correção, lembretes e agregados.

Avisos abrangem ausência, presença esperada, chegada tardia, saída antecipada e períodos. Eles preenchem a lista como pendência, nunca se tornam registro oficial automaticamente e não equivalem a falta justificada.

## 29.6 Integridade Obrigatória

- Grupos novos devem pertencer obrigatoriamente a uma unidade; a migration deverá tratar registros legados antes de tornar `groups.unit_id` não nulo.
- Toda FK contextual deve impedir cruzamento de instituição por constraint composta ou validação server-side.
- CPF e outros documentos de pessoas autorizadas exigem estratégia de minimização, cifragem/tokenização e retenção antes de produção.
- Alterações de permissão, suspensão, transferência, presença oficial e contexto histórico devem ser auditadas.

# Fontes e referências

## Fontes internas

- Coelo — Product Vision Oficial v1.

- Coelo — PRD Master Oficial v1.

- Coelo — História da Logo e Marca Oficial v1.

- Mapa competitivo de apps de agenda e comunicação escolar no Brasil.

- Decisões do fundador registradas em 21/06/2026 para os seis PRDs.

## Fontes externas oficiais

- Supabase — Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security

- Supabase — Auth: https://supabase.com/docs/guides/auth

- Supabase — Storage Access Control: https://supabase.com/docs/guides/storage/security/access-control

- Supabase — Realtime Authorization: https://supabase.com/docs/guides/realtime/authorization

- Supabase — Edge Functions e secrets: https://supabase.com/docs/guides/functions e https://supabase.com/docs/guides/functions/secrets

- Flutter — App architecture: https://docs.flutter.dev/app-architecture

- ANPD — Enunciado sobre dados de crianças e adolescentes: https://www.gov.br/anpd/pt-br/assuntos/noticias/anpd-divulga-enunciado-sobre-o-tratamento-de-dados-pessoais-de-criancas-e-adolescentes

- ANPD — Comunicação de incidentes de segurança: https://www.gov.br/anpd/pt-br/assuntos/comunicacao-de-incidentes-de-seguranca-cis

- OWASP — ASVS: https://owasp.org/www-project-application-security-verification-standard/

- OWASP — MASVS: https://mas.owasp.org/MASVS/

Acesso às fontes externas: 21/06/2026. As referências jurídicas não substituem revisão por profissional habilitado.
