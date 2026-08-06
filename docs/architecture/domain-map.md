---
title: "Coelo Mapa de Dominios Oficial v1"
source_file: "Coelo Mapa de Dominios Oficial v1.docx"
source_copy: "docs/source/originals/docx/Coelo Mapa de Dominios Oficial v1.docx"
original_path: "C:/Users/adrie/Desktop/Coelo/Mapa de Dominios e Arquitetura/Coelo Mapa de Dominios Oficial v1.docx"
supplemental_source: "decisions/0015-contextual-people-authorizations-attendance.md; specs/015-contextual-people-access-attendance.md"
status: "derived-from-official-docx"
version: "v1"
generated_at: "2026-07-24"
---

<!-- Documento derivado de fonte oficial. Edite a fonte DOCX ou registre uma decisao antes de alterar conteudo normativo. -->
| Coluna 1 | COELO<br>Mapa de Domínios Oficial v1<br>Produto completo · MVP/v1 · roadmap · bounded contexts |
| --- | --- |

Versão: v1.0 | Data: 21/06/2026 | Status: Draft oficial para validação técnica

| Visão do mapa<br>Organizar o Coelo em domínios e contextos com responsabilidades, fontes oficiais, dependências e eventos claros, preservando manutenção independente sem fragmentar a experiência do usuário. |
| --- |

| Simples como Airbnb<br>Fronteiras compreensíveis e arquitetura pragmática. | Visual como Instagram<br>Happens, Now e Moments unidos na experiência, separados no domínio. | Confiável como escola<br>Privacidade, autorização e auditoria desde o desenho. |
| --- | --- | --- |

Documento derivado do Product Vision, PRD Master, PRDs especializados, Modelo de Dados Master e decisões validadas pelo fundador.

# Resumo executivo

Este documento transforma a lista inicial de módulos do Coelo em um mapa de domínios orientado por Domain-Driven Design. Cada bounded context possui uma responsabilidade, uma fonte oficial de dados e contratos claros com os demais contextos.

A principal decisão estrutural é separar Happens, Now e Moments como contextos independentes dentro do macrodomínio Experiência Social. Eles continuam compostos na mesma tela do aplicativo, mas podem evoluir, receber manutenção e ser liberados por plano de forma independente.

| Decisão central<br>Mesma tela não significa mesmo domínio. A interface pode compor Happens, Now e Moments, enquanto cada módulo preserva seu ciclo de vida, regras, tabelas e feature entitlement. |
| --- |

O mapa cobre o produto completo e marca o estágio de cada contexto: MVP, MVP limitado, próxima fase ou futuro. A recomendação inicial não é criar dezenas de microserviços, mas construir um monólito modular/monorepo com fronteiras verificáveis, migrations organizadas e comunicação por serviços de aplicação e eventos.

## Decisões validadas

| Tema | Decisão oficial v1 |
| --- | --- |
| Escopo | Produto completo, destacando MVP e roadmap futuro. |
| Happens, Now e Moments | Contextos separados dentro do macrodomínio Experiência Social; composição conjunta no App. |
| Planos | Acesso por feature code/entitlement, permitindo combinações como Basic com Happens e Master com Happens + Now + Moments. |
| Rotina | Rotina diária separada de Saúde e Ocorrências Sensíveis. |
| Agenda | Agenda separada de Autorizações; integração por referência e eventos. |
| Futuro | Cobrança, matrícula, integrações, IA, BI e white-label aparecem como contextos futuros. |

## Como ler este documento

- Domínio: área ampla do negócio que agrupa capacidades relacionadas.

- Bounded context: limite no qual termos, regras e modelo são consistentes.

- Fonte oficial: contexto que pode criar e alterar o dado mestre.

- Evento publicado: fato ocorrido que outros contextos podem consumir sem escrever diretamente nas tabelas do dono.

- Core: diferencial estratégico; Supporting: viabiliza o core; Generic: capacidade comum de mercado.

# Sumário executivo do documento

| # | Seção |
| --- | --- |
| 1 | Objetivo, escopo e princípios |
| 2 | Mapa geral dos domínios |
| 3 | Classificação e roadmap |
| 4 | Decisão estrutural: Happens, Now e Moments |
| 5 | Context map e regras de relacionamento |
| 6 | Catálogo detalhado dos bounded contexts |
| 7 | Fonte oficial e eventos |
| 8 | Entitlements e modularidade comercial |
| 9 | Arquitetura recomendada |
| 10 | Critérios de aceite e próximos passos |
| 11 | Fontes e referências |

# 1. Objetivo, escopo e princípios

## 1.1 Objetivo

Criar uma linguagem comum entre produto, design, engenharia, dados, segurança, jurídico, operações e agentes de coding. O mapa reduz duplicidade de tabelas, regras conflitantes e dependências invisíveis entre Superadmin, Admin e App.

## 1.2 O que este mapa é

- Mapa estratégico de capacidades de negócio e bounded contexts.

- Base para Functional Specs, Technical Specs, migrations, RLS, eventos e backlog.

- Guia de ownership: cada dado possui um domínio responsável.

- Base para modularidade de planos e evolução futura.

## 1.3 O que este mapa não é

- Não é a migration final nem o diagrama físico definitivo do Postgres.

- Não obriga o Coelo a começar com microserviços.

- Não substitui threat modeling, parecer jurídico, DPIA/RIPD ou testes de RLS.

- Não transforma telas em domínios: App, Admin e Superadmin são superfícies de experiência/orquestração.

## 1.4 Princípios de desenho

| Princípio | Aplicação no Coelo |
| --- | --- |
| Fonte oficial única | Cada entidade mestre possui um único contexto autorizado a criá-la e alterá-la. |
| Pessoa global, papel contextual | Identidade não é duplicada por instituição ou papel. |
| Privado por padrão | Audiência e acesso derivam de vínculo e permissão; negar por padrão. |
| Composição sem acoplamento | Uma tela pode combinar vários contextos sem fundir seus modelos. |
| Eventos antes de acesso lateral | Integrações internas preferem eventos, serviços de aplicação e projeções. |
| Shared Kernel mínimo | Somente IDs, timestamps, códigos e contratos estáveis; regras de negócio permanecem no dono. |
| Evolução pragmática | Começar modular no mesmo deploy e extrair serviços apenas quando houver motivo operacional. |

# 2. Mapa geral dos domínios

O landscape abaixo apresenta os macrodomínios, seus principais bounded contexts e o estágio de evolução. Os blocos laranja representam capacidades core; grafite, supporting; neutros, generic ou operacionais; os blocos tracejados pertencem às próximas fases.

Figura 1 — Landscape de domínios e bounded contexts do Coelo.

| Leitura de produto<br>O coração do Coelo está na combinação de relações contextuais seguras, experiência social privada e acompanhamento da rotina infantil. Os demais contextos sustentam, governam ou monetizam esse núcleo. |
| --- |

# 3. Classificação e roadmap

| ID | Bounded context | Tipo | Horizonte |
| --- | --- | --- | --- |
| D01 | Identidade e Autenticação | Generic | MVP |
| D02 | Tenancy e Estrutura Institucional | Supporting | MVP |
| D03 | Contexto e Autorização | Core | MVP |
| D04 | Família e Relações com a Criança | Core | MVP |
| D05 | Perfis Sociais e Audiência | Core | MVP |
| D06 | Happens | Core | MVP |
| D07 | Now | Core | MVP |
| D08 | Moments | Core | MVP |
| D09 | Engajamento Social e Leitura | Supporting | MVP |
| D10 | Rotina Diária | Core | MVP |
| D11 | Saúde e Ocorrências Sensíveis | Supporting | MVP limitado |
| D12 | Chat e Canais | Supporting | MVP |
| D13 | Agenda | Supporting | MVP |
| D14 | Autorizações | Supporting | MVP simples |
| D15 | Mídia | Supporting | MVP |
| D16 | Notificações | Generic | MVP |
| D17 | Privacidade, Consentimentos e Ciclo de Vida | Supporting | MVP |
| D18 | Auditoria e Evidências de Segurança | Supporting | MVP |
| D19 | Analytics e Uso do Produto | Supporting | MVP dados / UI futura |
| D20 | Administração do Tenant e Onboarding | Supporting | MVP |
| D21 | Operação da Plataforma e Suporte | Supporting | MVP |
| D22 | Planos e Entitlements | Supporting | MVP manual |
| D23 | Importação e Qualidade de Dados | Supporting | MVP |
| D24 | Cobrança e Pagamentos | Supporting | Próxima fase |
| D25 | Matrícula e Documentos | Supporting | Próxima fase |
| D26 | Integrações e API | Supporting | Próxima fase / futuro |
| D27 | IA e Automação | Supporting | Próxima fase / futuro |
| D28 | BI e Relatórios | Supporting | Próxima fase / futuro |
| D29 | Branding e White-label | Supporting | Futuro |

## 3.1 Core Domains

Contexto e Autorização, Família e Relações com a Criança, Perfis/Audiência, Happens, Now, Moments e Rotina Diária concentram a diferenciação do Coelo. São áreas nas quais linguagem, UX, segurança e regras devem receber maior atenção de produto e engenharia.

## 3.2 Supporting e Generic

Chat, Agenda, Autorizações, Mídia, Privacidade, Auditoria, Analytics, Administração, Operação e Entitlements viabilizam o core. Identidade/Auth e Notificações podem usar componentes maduros de mercado, mas precisam respeitar as regras contextuais do Coelo.

# 4. Decisão estrutural: Happens, Now e Moments

Para atender manutenção independente e liberação por plano, Happens, Now e Moments serão bounded contexts separados. Eles pertencem ao mesmo macrodomínio Experiência Social e compartilham contratos de perfis, audiência, mídia e autorização, mas não compartilham propriedade de tabelas de negócio.

Figura 2 — Composição conjunta na interface e independência no domínio.

## 4.1 Por que separar

- Manutenção: alteração em expiração do Now não exige mexer no ciclo de vida do Happens.

- Escalabilidade: processamento de vídeo de Moments pode evoluir sem contaminar posts e comunicados.

- Planos: feature codes independentes permitem habilitar happens, now e moments por plano.

- Métricas: cada contexto mede adoção, custo e desempenho separadamente.

- Roadmap: um módulo pode ser estabilizado, refeito ou extraído sem bloquear os demais.

## 4.2 O que permanece compartilhado por contrato

| Capacidade compartilhada | Dono | Como os três usam |
| --- | --- | --- |
| Perfil e audiência | Perfis Sociais e Audiência | Recebem profile_id e audience_id resolvidos. |
| Autorização | Contexto e Autorização | Consultam policy/decision; não recriam RBAC. |
| Mídia | Mídia | Referenciam media_asset_id e status de processamento. |
| Reações e leitura | Engajamento Social | Registram interação por content_ref tipado. |
| Planos | Planos e Entitlements | Consultam feature code antes de criar/publicar. |
| Notificação/auditoria | Contextos transversais | Consomem eventos publicados. |

## 4.3 Exemplo de plano — apenas estrutural

| Exemplo, não decisão comercial final<br>Plano Basic: feature happens=true, now=false, moments=false. Plano Master: happens=true, now=true, moments=true. A interface consulta o snapshot de entitlements e mostra ou oculta entradas sem alterar os domínios. |
| --- |

# 5. Context map e regras de relacionamento

O Context Map registra relações entre os bounded contexts. Ele não mostra todas as chamadas de tela; mostra os contratos que precisam permanecer estáveis.

Figura 3 — Context Map resumido e padrões de integração.

## 5.1 Padrões adotados

| Padrão | Aplicação |
| --- | --- |
| Customer/Supplier | Contexto/Autorização depende de Identidade, Tenancy e Família; contratos são negociados e versionados. |
| Open Host Service / Published Language | Perfis/Audiência e Mídia expõem contratos estáveis a Happens, Now, Moments, Chat e Rotina. |
| Policy Service | Entitlements responde se a instituição pode usar uma feature; não executa a regra interna do módulo. |
| Conformist controlado | Notificações e Analytics consomem eventos padronizados, sem exigir acesso ao modelo interno. |
| Anti-Corruption Layer | ERPs, gateways, WhatsApp e parceiros futuros são traduzidos pela camada de Integrações. |
| Shared Kernel mínimo | IDs, timestamps, códigos de evento e envelope de contexto; nenhuma regra de negócio compartilhada. |

## 5.2 Regras obrigatórias entre domínios

- Um contexto não grava diretamente nas tabelas de outro contexto.

- Referências cruzadas usam IDs estáveis, contratos de aplicação ou eventos publicados.

- Leituras compostas para telas usam projeções/read models, sem transferir ownership.

- Mudanças de contrato exigem versionamento e teste de consumidores.

- Auditoria e Analytics recebem eventos; não devem copiar conteúdo sensível completo.

- Operação/Admin orquestra comandos, mas não vira dona dos dados dos módulos.

# 6. Catálogo detalhado dos bounded contexts

Cada ficha define responsabilidade, fonte oficial, limites, entidades conceituais, dependências e eventos. Os nomes físicos finais podem ser refinados na Technical Spec, preservando o ownership estabelecido aqui.

## 6.1 Identidade, contexto e relações

D01 · Identidade e Autenticação Generic · MVP

| Responsabilidade | Manter a identidade global de adultos e crianças, credenciais, contatos verificados, recuperação e perfil básico de conta. |
| --- | --- |
| Fonte oficial | Pessoa global, usuário Auth, username, contatos/identificadores verificados e estado da conta. |
| Não controla | Papéis institucionais, permissões por contexto, dados da criança em uma instituição ou audiência de conteúdo. |
| Entidades principais | people, auth.users, user_profiles, usernames, person_contacts, adult_identifiers. |
| Dependências | Provedor de autenticação/Supabase Auth; fornece person_id e user_id aos demais contextos. |
| Eventos publicados | person_created, identity_verified, username_reserved, account_recovered, account_disabled. |

D02 · Tenancy e Estrutura Institucional Supporting · MVP

| Responsabilidade | Representar instituições, unidades, grupos/turmas e configurações estruturais do tenant. |
| --- | --- |
| Fonte oficial | Instituição, unidade, grupo, tipo de grupo, status estrutural e relações hierárquicas. |
| Não controla | Credenciais, permissões efetivas, vínculos familiares, posts ou rotinas. |
| Entidades principais | institutions, units, groups, institution_settings, group_types. |
| Dependências | Identidade para owners iniciais; operado por Admin e Superadmin por serviços de aplicação. |
| Eventos publicados | institution_created, institution_status_changed, unit_created, group_created, group_inactivated. |

D03 · Contexto e Autorização Core · MVP

| Responsabilidade | Calcular quem pode fazer o quê, em qual instituição, unidade, grupo, papel e criança, com RBAC + RLS. |
| --- | --- |
| Fonte oficial | Memberships, papéis, escopos, permissões delegadas, contexto ativo e decisão de acesso. |
| Não controla | Cadastro base da pessoa, estrutura do tenant ou relação familiar global. |
| Entidades principais | memberships, roles, permissions, permission_grants, active_contexts, access_policies. |
| Dependências | Identidade, Tenancy e Família; publica contratos de autorização para todos os módulos. |
| Eventos publicados | membership_granted, role_changed, permission_changed, context_switched, access_revoked. |

D04 · Família e Relações com a Criança Core · MVP

| Responsabilidade | Representar criança global, contexto institucional da criança, responsáveis e autorização de visibilidade por instituição. |
| --- | --- |
| Fonte oficial | Vínculo responsável-criança, child_context, permissões familiares contextuais e responsáveis adicionais. |
| Não controla | Login, papel de professor, rotina diária, ocorrências ou conteúdo social. |
| Entidades principais | child_contexts, guardian_links, guardian_context_permissions, guardian_roles. |
| Dependências | Identidade e Tenancy; alimenta Contexto/Autorização e audiência dos módulos. |
| Eventos publicados | child_context_created, guardian_linked, guardian_access_granted, guardian_access_revoked. |

## 6.2 Experiência social

D05 · Perfis Sociais e Audiência Core · MVP

| Responsabilidade | Definir perfis privados de Coelo, instituição, unidade e grupo, seguidores derivados de vínculos e resolução de audiência. |
| --- | --- |
| Fonte oficial | Perfil social, regras de follow, silenciamento, audiência resolvida e identidade social contextual. |
| Não controla | Conteúdo específico de Happens, Now ou Moments; arquivos de mídia; planos comerciais. |
| Entidades principais | social_profiles, follows, audience_rules, resolved_audiences, mute_preferences. |
| Dependências | Contexto/Autorização, Tenancy e Família; fornece contratos a Happens, Now e Moments. |
| Eventos publicados | social_profile_created, audience_resolved, follow_added, follow_removed, profile_muted. |

D06 · Happens Core · MVP

| Responsabilidade | Gerenciar feed privado, posts, comunicados, agendamento, confirmação de leitura e publicação contextual. |
| --- | --- |
| Fonte oficial | Post, comunicado, versão, status, audiência referenciada e requisitos de leitura. |
| Não controla | Conteúdo temporário, vídeos Moments, arquivos físicos, reações ou regras de plano. |
| Entidades principais | flow_posts, flow_post_versions, flow_audiences, flow_schedules, flow_read_requirements. |
| Dependências | Perfis/Audiência, Mídia, Contexto/Autorização e Entitlements. |
| Eventos publicados | flow_post_drafted, flow_post_published, flow_post_updated, flow_post_archived, flow_read_required. |

D07 · Now Core · MVP

| Responsabilidade | Gerenciar conteúdos temporários privados com expiração padrão de 24 horas e audiência contextual. |
| --- | --- |
| Fonte oficial | Item Now, sequência, status de publicação, expiração e visualização agregada. |
| Não controla | Posts permanentes, vídeos Moments, arquivo físico ou política comercial. |
| Entidades principais | now_items, now_sequences, now_audiences, now_views, now_expirations. |
| Dependências | Perfis/Audiência, Mídia, Contexto/Autorização e Entitlements. |
| Eventos publicados | now_published, now_viewed, now_expired, now_removed. |

D08 · Moments Core · MVP

| Responsabilidade | Gerenciar vídeos privados de até dois minutos, publicação, processamento e consumo contextual. |
| --- | --- |
| Fonte oficial | Moment, metadados de duração, status editorial e audiência referenciada. |
| Não controla | Arquivo bruto/transcodificação, posts do Happens, itens Now ou cobrança. |
| Entidades principais | moments, moment_audiences, moment_publication_status, moment_play_events. |
| Dependências | Perfis/Audiência, Mídia, Contexto/Autorização e Entitlements. |
| Eventos publicados | moment_submitted, moment_published, moment_played, moment_archived, moment_rejected. |

D09 · Engajamento Social e Leitura Supporting · MVP

| Responsabilidade | Registrar reações simples, leituras, confirmações e métricas operacionais comuns aos conteúdos sociais. |
| --- | --- |
| Fonte oficial | Reação, read receipt, confirmação explícita e contadores derivados. |
| Não controla | Conteúdo, audiência, perfil social ou dados analíticos agregados de BI. |
| Entidades principais | reactions, read_receipts, acknowledgements, engagement_counters. |
| Dependências | Happens, Now e Moments por IDs e eventos; Contexto/Autorização para validar ação. |
| Eventos publicados | reaction_added, reaction_removed, content_read, read_confirmed. |

## 6.3 Cuidado e rotina

D10 · Rotina Diária Core · MVP

| Responsabilidade | Registrar alimentação, sono, higiene, humor, atividades e demais itens cotidianos com lote por grupo e ajuste individual. |
| --- | --- |
| Fonte oficial | Templates de rotina, entradas, itens, rascunhos, publicação e histórico de alterações. |
| Não controla | Ocorrências sensíveis, medicação, diagnóstico, evento de agenda ou mídia física. |
| Entidades principais | routine_templates, routine_entries, routine_items, routine_drafts, routine_change_history. |
| Dependências | Família, Contexto/Autorização, Tenancy e Mídia; pode referenciar ocorrência sensível por ID. |
| Eventos publicados | routine_draft_saved, routine_entry_published, routine_entry_corrected, routine_pending_detected. |

D11 · Saúde e Ocorrências Sensíveis Supporting · MVP limitado

| Responsabilidade | Tratar sintomas observados, temperatura, incidentes, encaminhamentos e registros de maior sensibilidade com acesso reforçado. |
| --- | --- |
| Fonte oficial | Ocorrência sensível, classificação, encaminhamento, acesso restrito e trilha de alterações. |
| Não controla | Rotina cotidiana comum, prontuário médico, diagnóstico ou prescrição. |
| Entidades principais | sensitive_occurrences, health_observations, occurrence_actions, restricted_access_records. |
| Dependências | Família, Contexto/Autorização, Privacidade e Auditoria; fornece projeção mínima à Rotina. |
| Eventos publicados | sensitive_occurrence_recorded, occurrence_escalated, occurrence_acknowledged, restricted_record_accessed. |

## 6.4 Comunicação, agenda e decisão

D12 · Chat e Canais Supporting · MVP

| Responsabilidade | Gerenciar conversas contextuais, canais por unidade/grupo, membros autorizados, mensagens e recibos. |
| --- | --- |
| Fonte oficial | Conversa, canal, membro, mensagem, anexo referenciado, leitura e políticas de resposta. |
| Não controla | Relação responsável-criança, arquivo físico, push ou integração direta com WhatsApp. |
| Entidades principais | conversations, conversation_members, messages, message_receipts, channel_policies. |
| Dependências | Contexto/Autorização, Família, Tenancy, Mídia e Notificações. |
| Eventos publicados | conversation_created, message_sent, message_read, member_added, conversation_closed. |

D13 · Agenda Supporting · MVP

| Responsabilidade | Gerenciar eventos, lembretes, recorrências, audiência, RSVP e agenda visual da instituição/família. |
| --- | --- |
| Fonte oficial | Evento, data/horário, recorrência, audiência e resposta de presença quando não exige autorização formal. |
| Não controla | Decisão formal de autorização, documento assinado, pagamento ou notificação entregue. |
| Entidades principais | agenda_events, agenda_recurrences, agenda_audiences, agenda_responses, reminders. |
| Dependências | Tenancy, Contexto/Autorização, Família e Notificações. |
| Eventos publicados | agenda_event_created, agenda_event_published, agenda_response_recorded, agenda_event_cancelled. |

D14 · Autorizações Supporting · MVP simples

| Responsabilidade | Gerenciar solicitações de decisão do responsável, evidência de resposta, validade, revogação e relação com evento/atividade. |
| --- | --- |
| Fonte oficial | Solicitação, versão do texto, destinatários, decisão, evidência e revogação. |
| Não controla | Data do evento, consentimento jurídico geral de imagem/termos ou assinatura contratual de matrícula. |
| Entidades principais | authorization_requests, authorization_versions, authorization_recipients, authorization_decisions, revocations. |
| Dependências | Agenda quando ligada a evento; Família, Contexto/Autorização, Notificações e Auditoria. |
| Eventos publicados | authorization_requested, authorization_approved, authorization_denied, authorization_revoked, authorization_expired. |

D15 · Mídia Supporting · MVP

| Responsabilidade | Controlar upload, metadados, variantes, processamento, classificação de acesso e ligação com objetos de negócio. |
| --- | --- |
| Fonte oficial | Asset lógico, variante, estado de processamento, classificação e link para objeto de negócio. |
| Não controla | Post, rotina, mensagem, consentimento jurídico ou regra de audiência do domínio consumidor. |
| Entidades principais | media_assets, media_variants, media_links, media_processing_jobs, media_access_classification. |
| Dependências | Storage privado e políticas de acesso; recebe autorização contextual dos domínios consumidores. |
| Eventos publicados | media_uploaded, media_processed, media_linked, media_restricted, media_deleted. |

D16 · Notificações Generic · MVP

| Responsabilidade | Orquestrar central in-app, push e preferências de entrega com payload mínimo e rastreamento. |
| --- | --- |
| Fonte oficial | Solicitação de notificação, entrega, preferência, device token e falha/retry. |
| Não controla | Conteúdo completo da mensagem, decisão de audiência ou evento de negócio original. |
| Entidades principais | notifications, notification_deliveries, notification_preferences, device_tokens, delivery_attempts. |
| Dependências | Consome eventos publicados por todos os módulos; integra FCM/APNs/serviço de envio. |
| Eventos publicados | notification_requested, notification_sent, notification_delivered, notification_failed, preference_changed. |

## 6.5 Governança e dados

D17 · Privacidade, Consentimentos e Ciclo de Vida Supporting · MVP

| Responsabilidade | Versionar termos, consentimentos, autorizações de imagem, solicitações de titulares, retenção e exclusão/anonymização. |
| --- | --- |
| Fonte oficial | Termo, consentimento, finalidade, status, revogação, solicitação de titular e política de retenção. |
| Não controla | Autorização operacional de evento, post, asset de mídia ou decisão jurídica definitiva controlador/operador. |
| Entidades principais | terms, consent_records, media_consent_records, data_subject_requests, retention_policies, deletion_jobs. |
| Dependências | Identidade, Família, Mídia, Auditoria e jurídico/contratos. |
| Eventos publicados | consent_granted, consent_revoked, terms_accepted, data_request_opened, retention_action_executed. |

D18 · Auditoria e Evidências de Segurança Supporting · MVP

| Responsabilidade | Registrar ações sensíveis, mudanças de permissão, acesso interno, suporte e evidências para investigação. |
| --- | --- |
| Fonte oficial | Audit log imutável, sessão de suporte, motivo, ator, escopo, objeto e ação sensível. |
| Não controla | Evento analítico de produto, conteúdo sensível completo ou regra de negócio do módulo origem. |
| Entidades principais | audit.audit_logs, support_sessions, audit.support_session_actions, sensitive_access_logs, security_events, incident_records. |
| Dependências | Recebe eventos/commands de todos os domínios; acesso restrito à equipe autorizada. |
| Eventos publicados | audit_recorded, support_session_opened, support_session_closed, security_incident_opened. |

D19 · Analytics e Uso do Produto Supporting · MVP dados / UI futura

| Responsabilidade | Registrar eventos de uso pseudonimizados, contadores e projeções para métricas e dashboards futuros. |
| --- | --- |
| Fonte oficial | Evento analítico, esquema/versionamento, contador de uso e projeção de métricas. |
| Não controla | Audit log, dado financeiro definitivo ou conteúdo pessoal desnecessário. |
| Entidades principais | analytics.analytics_events, event_schemas, analytics.usage_counters, analytics.usage_snapshots, metric_projections. |
| Dependências | Consome eventos publicados; fornece dados a Planos/Entitlements e BI/Relatórios. |
| Eventos publicados | analytics_event_ingested, usage_counter_updated, metric_projection_refreshed. |

## 6.6 Administração e operação

D20 · Administração do Tenant e Onboarding Supporting · MVP

| Responsabilidade | Orquestrar configuração da instituição, unidades, grupos, pessoas, vínculos, conteúdo e políticas sem assumir propriedade dos dados. |
| --- | --- |
| Fonte oficial | Fluxos de onboarding, checklist, configurações administrativas e comandos compostos. |
| Não controla | Pessoa, instituição, permissão, post ou rotina: chama os respectivos contextos. |
| Entidades principais | onboarding_checklists, admin_preferences, configuration_workflows, bulk_operation_requests. |
| Dependências | Identidade, Tenancy, Contexto/Autorização, Família, Importação e módulos operacionais. |
| Eventos publicados | onboarding_started, onboarding_step_completed, tenant_configuration_changed. |

D21 · Operação da Plataforma e Suporte Supporting · MVP

| Responsabilidade | Gerenciar tenants, usuários internos, avisos de plataforma, suporte autorizado e saúde operacional. |
| --- | --- |
| Fonte oficial | Membership interno Coelo, aviso de plataforma, status operacional e sessão de suporte. |
| Não controla | Operação cotidiana da instituição ou edição silenciosa de dados privados. |
| Entidades principais | platform_memberships, platform_notices, notice_audiences, support_sessions, operational_status. |
| Dependências | Tenancy, Entitlements, Auditoria e Identidade; executa por backend seguro. |
| Eventos publicados | platform_user_invited, platform_notice_published, support_session_opened, tenant_suspended. |

D22 · Planos e Entitlements Supporting · MVP manual

| Responsabilidade | Definir catálogo de planos, recursos liberados, limites e snapshot de acesso por instituição. |
| --- | --- |
| Fonte oficial | Plano, feature code, entitlement, limite, período, status e atribuição ao tenant. |
| Não controla | Cobrança, pagamento, nota fiscal ou regra interna de Happens/Now/Moments. |
| Entidades principais | plans, features, plan_entitlements, institution_subscriptions, usage_limits, entitlement_snapshots. |
| Dependências | Operação da Plataforma e Analytics; no futuro recebe estado de Billing. |
| Eventos publicados | plan_changed, entitlement_granted, entitlement_revoked, usage_limit_reached, subscription_status_changed. |

D23 · Importação e Qualidade de Dados Supporting · MVP

| Responsabilidade | Processar CSV/XLSX com upload, mapeamento, prévia, validação, deduplicação, erros e confirmação explícita. |
| --- | --- |
| Fonte oficial | Job de importação, arquivo temporário, linha, mapeamento, erro e resultado. |
| Não controla | Pessoa, unidade, grupo ou vínculo definitivo; envia comandos aos contextos donos. |
| Entidades principais | import_jobs, import_files, import_mappings, import_rows, import_errors, import_results. |
| Dependências | Admin/Onboarding, Identidade, Tenancy, Família e Contexto/Autorização. |
| Eventos publicados | import_validated, import_failed, import_confirmed, import_completed, duplicate_detected. |

## 6.7 Próximas fases e futuro

D24 · Cobrança e Pagamentos Supporting · Próxima fase

| Responsabilidade | Gerenciar cobrança, assinatura, transações, conciliação, inadimplência e eventos financeiros. |
| --- | --- |
| Fonte oficial | Customer financeiro, invoice, charge, payment, refund, reconciliation e status financeiro. |
| Não controla | Plano funcional ou feature liberada; comunica estado ao domínio Entitlements. |
| Entidades principais | billing_customers, invoices, charges, payments, refunds, reconciliation_records. |
| Dependências | Gateway externo via camada anticorrupção; Planos/Entitlements e Auditoria. |
| Eventos publicados | invoice_issued, payment_confirmed, payment_failed, refund_processed, delinquency_changed. |

D25 · Matrícula e Documentos Supporting · Próxima fase

| Responsabilidade | Gerenciar inscrição/matrícula digital, documentos, versões, assinatura e status contratual. |
| --- | --- |
| Fonte oficial | Processo de matrícula, documento, checklist, assinatura e evidência contratual. |
| Não controla | Identidade global, vínculo familiar permanente ou autorização operacional de agenda. |
| Entidades principais | enrollment_processes, enrollment_forms, documents, document_versions, signatures. |
| Dependências | Identidade, Família, Tenancy, Privacidade e integrações de assinatura. |
| Eventos publicados | enrollment_started, document_requested, document_signed, enrollment_approved. |

D26 · Integrações e API Supporting · Próxima fase / futuro

| Responsabilidade | Isolar ERPs, gateways, mensageria e parceiros por APIs, webhooks, sincronização e camada anticorrupção. |
| --- | --- |
| Fonte oficial | Conector, credencial protegida, mapeamento externo, job de sync, webhook e dead letter. |
| Não controla | Modelo de negócio interno nem dados mestres dos demais domínios. |
| Entidades principais | integrations, external_mappings, sync_jobs, webhook_endpoints, webhook_deliveries, dead_letters. |
| Dependências | Todos os contextos via contratos publicados; nunca acesso irrestrito ao banco. |
| Eventos publicados | integration_connected, sync_completed, sync_failed, webhook_received, mapping_conflict_detected. |

D27 · IA e Automação Supporting · Próxima fase / futuro

| Responsabilidade | Oferecer assistência para comunicados, relatórios, classificação e automações com governança e revisão humana. |
| --- | --- |
| Fonte oficial | Caso de uso de IA, versão de prompt, execução, política, aprovação e evidência de saída. |
| Não controla | Dado mestre, decisão sensível automática ou acesso direto irrestrito a dados infantis. |
| Entidades principais | ai_use_cases, prompt_versions, ai_runs, automation_rules, human_reviews, policy_checks. |
| Dependências | Integrações, Privacidade, Auditoria e domínios que solicitam assistência. |
| Eventos publicados | ai_run_requested, ai_output_generated, human_review_completed, automation_executed. |

D28 · BI e Relatórios Supporting · Próxima fase / futuro

| Responsabilidade | Produzir dashboards, relatórios operacionais, exportações e modelos analíticos governados. |
| --- | --- |
| Fonte oficial | Definição de métrica, dataset analítico, relatório, dashboard e exportação. |
| Não controla | Evento bruto de produto, audit log ou dado operacional transacional. |
| Entidades principais | metric_definitions, analytical_datasets, reports, dashboards, exports. |
| Dependências | Analytics, Billing futuro e projeções dos domínios; acesso conforme contexto. |
| Eventos publicados | report_generated, dashboard_refreshed, export_requested, export_completed. |

D29 · Branding e White-label Supporting · Futuro

| Responsabilidade | Gerenciar branding leve, temas por instituição e, futuramente, distribuição de apps dedicados. |
| --- | --- |
| Fonte oficial | Configuração visual, assets de marca, domínio customizado e variante de distribuição. |
| Não controla | Design system global, plano comercial ou conteúdo institucional. |
| Entidades principais | tenant_branding, brand_assets, custom_domains, app_variants, store_release_configs. |
| Dependências | Tenancy, Planos/Entitlements, Mídia e pipeline de release. |
| Eventos publicados | branding_updated, custom_domain_verified, app_variant_requested, release_published. |

D30 · Atividades Contextuais Core · MVP

| Responsabilidade | Definir atividades reutilizáveis dentro da instituição e especializar sua operação por unidade e grupo/turma. |
| --- | --- |
| Fonte oficial | Definição da atividade, origem institucional ou unidade autorizada, vínculos com unidades e turmas, professores e permissões contextuais. |
| Não controla | A turma, a identidade da pessoa, o conteúdo físico de mídia, o evento de agenda, a conversa ou o registro de presença. |
| Entidades principais | activity_definitions, activity_unit_links, activity_group_links, activity_group_assignments, activity_permission_profiles. |
| Dependências | Tenancy, Contexto/Autorização, Perfis/Audiência, Chat, Agenda, Mídia, Rotina e Auditoria. |
| Eventos publicados | activity_created, activity_created_by_unit, activity_linked_to_unit, activity_linked_to_group, activity_member_assigned, activity_permission_changed. |

# 7. Fonte oficial e eventos

## 7.1 Matriz de source of truth

| Informação | Contexto proprietário |
| --- | --- |
| Pessoa, credencial e username | Identidade e Autenticação |
| Instituição, unidade e grupo | Tenancy e Estrutura Institucional |
| Definição de atividade e vínculos com unidades, turmas e professores | Atividades Contextuais |
| Papel, escopo e permissão | Contexto e Autorização |
| Vínculo responsável-criança | Família e Relações com a Criança |
| Perfil social e audiência | Perfis Sociais e Audiência |
| Post/comunicado | Happens |
| Conteúdo temporário | Now |
| Vídeo de até 2 minutos | Moments |
| Reação e confirmação de leitura | Engajamento Social e Leitura |
| Registro cotidiano | Rotina Diária |
| Ocorrência sensível | Saúde e Ocorrências Sensíveis |
| Conversa e mensagem | Chat e Canais |
| Evento | Agenda |
| Decisão do responsável | Autorizações |
| Arquivo e variante | Mídia |
| Termo e consentimento | Privacidade, Consentimentos e Ciclo de Vida |
| Evidência de ação sensível | Auditoria e Evidências |
| Uso e métrica bruta | Analytics e Uso |
| Feature liberada | Planos e Entitlements |
| Pagamento | Cobrança e Pagamentos — futuro |

## 7.2 Eventos prioritários do MVP

| Família de eventos | Eventos |
| --- | --- |
| Acesso | membership_granted, permission_changed, guardian_access_granted |
| Social | flow_post_published, now_published, now_expired, moment_published, reaction_added, read_confirmed |
| Rotina | routine_entry_published, routine_entry_corrected, sensitive_occurrence_recorded |
| Comunicação | message_sent, agenda_event_published, authorization_requested, authorization_approved/denied |
| Mídia | media_uploaded, media_processed, media_restricted |
| Plataforma | plan_changed, entitlement_granted/revoked, import_completed, support_session_opened/closed |
| Transversais | notification_delivered, audit_recorded, analytics_event_ingested |

| Envelope mínimo de evento<br>event_id, event_type, event_version, occurred_at, actor_person_id quando aplicável, institution_id/context_id, aggregate_type, aggregate_id, correlation_id e payload minimizado. |
| --- |

# 8. Entitlements e modularidade comercial

Planos e Entitlements é a camada que permite vender combinações de funcionalidades sem misturar cobrança com regras de produto. Cada módulo conhece seu feature code, mas não conhece preço, gateway ou fatura.

## 8.1 Feature codes iniciais sugeridos

| Feature code | Capacidade |
| --- | --- |
| social.happens | Criar e consumir Happens. |
| social.now | Criar e consumir Now. |
| social.moments | Criar e consumir Moments. |
| communication.chat | Chat e canais. |
| care.routine | Rotina diária. |
| care.sensitive_occurrences | Saúde/ocorrências sensíveis. |
| time.agenda | Agenda. |
| decision.authorizations | Autorizações. |
| admin.import | Importação CSV/XLSX. |
| analytics.dashboard | Dashboard visual futuro. |
| branding.white_label | White-label futuro. |

## 8.2 Regra de avaliação

1. A instituição recebe um entitlement_snapshot versionado.

2. O front-end usa o snapshot para navegação e UX, mas o backend valida novamente.

3. O módulo valida feature + limite + contexto antes de aceitar o comando.

4. Mudança de plano publica entitlement_changed e invalida caches.

5. Bloqueio não apaga dados; muda criação/uso conforme política definida.

6. Billing futuro informa estado financeiro a Entitlements, sem editar features diretamente.

# 9. Arquitetura recomendada

| Recomendação v1<br>Monólito modular/monorepo por bounded context, com deploy simples e fronteiras rígidas. Microserviços somente quando custo, escala, segurança, equipe ou ciclo de release justificarem. |
| --- |

## 9.1 Organização lógica

| Camada | Decisão |
| --- | --- |
| Flutter/Dart | Packages/features separados por contexto; UI composition consome application services/read models. |
| Supabase/Postgres | Migrations agrupadas por contexto; ownership documentado; RLS aplicada no banco. |
| Edge Functions/backend | Comandos sensíveis, integração externa, suporte e operações com privilégios. |
| Realtime | Somente eventos/objetos autorizados; nenhum canal global com dados privados. |
| Storage | Buckets privados; Mídia mantém metadados e regras de acesso. |
| Eventos | Outbox/event table ou mecanismo equivalente para publicação confiável e consumidores idempotentes. |
| Analytics/Auditoria | Pipelines separados: produto não substitui evidência de segurança. |

## 9.2 Estrutura de código sugerida

| apps/app_mobile<br>apps/admin_web<br>apps/superadmin_web<br>packages/shared_kernel<br>packages/identity<br>packages/tenancy<br>packages/authorization<br>packages/family<br>packages/social_profiles<br>packages/happens<br>packages/now<br>packages/moments<br>packages/routine<br>packages/sensitive_occurrences<br>packages/chat<br>packages/agenda<br>packages/authorizations<br>packages/media<br>packages/notifications<br>packages/entitlements<br>packages/audit_analytics |
| --- |

## 9.3 Gatilhos para extrair um serviço

- Moments exige pipeline de vídeo e escala operacional muito diferente.

- Chat exige disponibilidade/throughput independente do restante da plataforma.

- Billing exige isolamento de compliance e integrações financeiras.

- Um contexto precisa de ciclo de deploy próprio e equipe dedicada.

- A separação reduz risco ou custo comprovado; não apenas preferência estética.

# 10. Critérios de aceite e próximos passos

## 10.1 Critérios de aceite do mapa

| Critério | Aceite |
| --- | --- |
| Ownership | Toda entidade crítica possui exatamente um contexto proprietário. |
| Limites | Cada contexto declara o que controla e o que não controla. |
| Modularidade social | Happens, Now e Moments são independentes e compostos na interface. |
| Entitlements | Feature access é validado no backend e pode variar por plano. |
| Separação sensível | Rotina comum não incorpora o modelo completo de saúde/ocorrência. |
| Agenda/autorizações | Evento e decisão formal possuem ownership separado. |
| Segurança | Contexto, RLS, mídia privada e auditoria são requisitos transversais. |
| Roadmap | Domínios futuros estão visíveis sem contaminar o MVP. |
| Integração | Nenhum contexto exige escrita direta nas tabelas de outro. |

## 10.2 Próximas entregas recomendadas

1. Criar Functional Specs individuais para D03 Contexto/Autorização, D05 Perfis/Audiência, D06 Happens, D07 Now, D08 Moments, D10 Rotina, D12 Chat, D13 Agenda, D14 Autorizações e D30 Atividades Contextuais.

2. Revisar o PRD Modelo de Dados Master para refletir os novos owners e a separação de tabelas de Happens, Now e Moments.

3. Criar diagrama ER conceitual por bounded context e contratos entre contextos.

4. Definir catálogo inicial de feature codes, limites e comportamento de downgrade.

5. Criar padrão de eventos v1 e matriz produtor/consumidor.

6. Criar Test Plan de isolamento multi-tenant, múltiplos papéis, entitlements e mídia privada.

7. Validar Saúde/Ocorrências, consentimentos e retenção com jurídico antes do piloto real.

## 10.3 Decisões ainda abertas

| Tema | Decisão pendente |
| --- | --- |
| Arquitetura física do banco | Schemas separados, prefixes ou combinação; fechar na Technical Spec. |
| Medicamentos | Regras formais, autorização e responsabilidade antes de entrar em produção. |
| Retenção | Prazos por mídia, chat, rotina, ocorrência, importação, logs e backups. |
| Downgrade | Leitura, criação e exportação quando uma feature deixa de estar ativa. |
| Planos comerciais | Nomes, preços e combinações finais; o mapa apenas prepara a estrutura. |
| Comentários | Preparados no futuro; desativados no MVP. |

# 11. Aditivo 2026-07-24 — Dominios Contextuais

## 11.1 Identity

Mantem pessoa global, Auth opcional e perfil. Crianca permanece sem login no
MVP, com estrutura preparada para experiencia infantil futura. Identity nao
decide papel, tenant ou visibilidade.

## 11.2 Tenancy

Mantem instituicao, unidade e grupo. Grupo pertence obrigatoriamente a unidade.
Tenancy fornece a arvore de ownership, mas nao concede capacidades sozinho.

## 11.3 Family Authorization

Mantem:

- relacao familiar global;
- acesso do responsavel por crianca e escopo;
- capacidades familiares;
- pessoas autorizadas sem login;
- autorizacoes por crianca/unidade;
- transferencias entre unidades.

`Guardian Access` e `Authorized Contacts` sao conceitos distintos. Somente o
primeiro oferece experiencia no Principal.

## 11.4 Professional Authorization

Mantem memberships, papeis padrao/personalizados, capacidades, atribuicoes por
escopo e overrides. Permite abrangencia dinamica de descendentes ou selecoes
fixas e atribuicao direta a criancas.

## 11.5 Activities

Mantem definicao institucional, origem, disponibilidade, politica,
unidades/grupos, participantes e atribuicoes profissionais. Atividade local
pode ser promovida sem duplicar a definicao. Conversa, presenca, rotina, agenda
e midia apenas consomem o contexto de atividade.

## 11.6 Chat

Mantem conversas e historico por instituicao, unidade, grupo ou atividade.
Preserva pessoa autora, papel, contexto e criancas relacionadas. Equipes de
atendimento controlam chats institucionais e de unidade.

## 11.7 Attendance

Mantem sessoes, participantes, avisos familiares, registro oficial,
justificativas, revisoes e assiduidade. Aviso familiar e intencao; confirmacao
profissional e o registro oficial.

## 11.8 Context Map Atualizado

| Upstream | Downstream | Contrato |
| --- | --- | --- |
| Identity | Todos | Pessoa e Auth opcional. |
| Tenancy | Family/Professional Authorization | Instituicao, unidade e grupo coerentes. |
| Family Authorization | Principal, Chat, Attendance | Crianca representada e capacidades familiares. |
| Professional Authorization | Admin, Chat, Attendance, Activities | Papel, escopo e capacidades efetivas. |
| Activities | Chat, Attendance, Routine, Agenda, Media | Contexto e participantes autorizados. |
| Attendance | Notifications, Analytics | Pendencias, registros oficiais e eventos minimizados. |
| Chat | Notifications | Mensagens contextuais; nunca fonte de presenca. |
| Todos | Audit | Antes/depois, ator, sujeito, contexto e motivo. |

## 11.9 Estado Fisico Em 2026-07-24

Os contextos `Family Authorization`, `Professional Authorization`,
`Activities`, `Chat` e `Attendance` possuem fundacao aplicada no Supabase
`coelo`. As fronteiras acima sao reforcadas por FKs/validadores de tenant,
helpers de permissao contextual, RPCs transacionais, auditoria, grants
explicitos e RLS. O proximo passo de produto e expor primeiro a navegacao de
Atividades no Superadmin e depois a gestao operacional no Admin.

# 12. Fontes e referências

## 11.1 Fontes internas do Coelo

- Product Vision Oficial v1 — Coelo.

- História da Logo e Marca Oficial v1 — Coelo.

- Mapa competitivo de apps de agenda e comunicação escolar no Brasil.

- PRD Master Oficial v1 — Coelo.

- PRD App Oficial v1 — Coelo.

- PRD LGPD, Segurança e Mídia Oficial v1 — Coelo.

- PRD Auth, Multi-tenant e Permissões Oficial v1 — Coelo.

- PRD Superadmin Oficial v1 — Coelo.

- PRD Admin Oficial v1 — Coelo.

- PRD Modelo de Dados Master Oficial v1 — Coelo.

- Design System Oficial v1 — Coelo.

## 11.2 Referências externas

- Microsoft Azure Architecture Center — Use Domain Analysis to Model Microservices

- Martin Fowler — Bounded Context

- AWS Prescriptive Guidance — Decompose by subdomain

| Nota de arquitetura<br>Este mapa usa DDD estratégico para definir fronteiras e ownership. Ele não transforma automaticamente cada bounded context em microserviço; a decisão de deploy permanece arquitetural e evolutiva. |
| --- |

COELO · SIMPLES, VISUAL E CONFIÁVEL
