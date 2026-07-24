---
title: "Contextual Domains Supabase Implementation Plan"
source: "decisions/0015-contextual-people-authorizations-attendance.md; specs/014-atividade-contextual.md; specs/015-contextual-people-access-attendance.md; remote project evvbomzejfijozbtgvpt inspected 2026-07-24"
status: "completed"
generated_at: "2026-07-24"
---

# Contextual Domains Supabase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preparar o Supabase do Coelo para autorização contextual, família, atividades, chat e assiduidade com integridade, RLS, RPCs e auditoria.

**Architecture:** A implementação usa cinco migrations incrementais. Identidade permanece em `people`, tenancy em instituição/unidade/grupo, e autorização é calculada server-side por membership, papel, grant/override e vínculo contextual. Tabelas expostas usam RLS e grants explícitos; helpers privilegiados ficam em `app_private` com `search_path = ''`.

**Tech Stack:** Supabase hosted, PostgreSQL 17, Supabase CLI 2.109.1, SQL/PLpgSQL, RLS, MCP de Supabase.

**Completion:** Implementado e validado no remoto em 2026-07-24. A execucao
incluiu migrations adicionais de compatibilidade, advisors e ciclo de vida do
chat descobertas durante os testes. Onze scripts SQL passaram com rollback.

## Global Constraints

- Projeto remoto: `coelo`, ref `evvbomzejfijozbtgvpt`.
- Não confiar em `user_metadata` ou dados enviados pelo cliente para autorização.
- Toda FK contextual deve impedir cruzamento de instituição.
- Novas tabelas em `public` recebem grants explícitos e RLS.
- Funções `security definer` ficam em `app_private`, usam `search_path = ''` e têm execução revogada do público.
- RPCs públicas são wrappers `security invoker` com grants mínimos.
- Auditoria registra ator, objeto, ação e antes/depois em alterações sensíveis.
- Testes escrevem dentro de transação e terminam com `rollback`.
- Migrations são criadas pelo Supabase CLI; timestamps não são inventados.

---

### Task 1: Autorização Contextual

**Files:**
- Modify: `packages/coelo_database/migrations/20260724152628_contextual_authorization_core.sql`
- Create: `packages/coelo_database/tests/2026-07-24-contextual-authorization-core-validation.sql`

**Produces:** `institution_member_permission_overrides`, `professional_child_assignments`, `app_private.has_context_permission(...)` e policies operacionais básicas.

- [ ] Criar primeiro o teste que exige unidade em todo grupo, deny individual, escopo descendente e assignment por criança.
- [ ] Executar os asserts no remoto e confirmar falha pela ausência das estruturas.
- [ ] Tornar `groups.unit_id` obrigatório, pois o remoto possui zero grupos.
- [ ] Declarar a fonte canônica: role assignments + role permissions + grants diretos + overrides individuais; manter colunas legadas apenas para compatibilidade.
- [ ] Criar helpers, índices, triggers de coerência, auditoria, catálogo de permissões, grants e RLS.
- [ ] Aplicar a migration e executar o teste até passar.

### Task 2: Família, Pessoas Autorizadas E Transferências

**Files:**
- Modify: `packages/coelo_database/migrations/20260724152707_family_authorizations_and_transfers.sql`
- Create: `packages/coelo_database/tests/2026-07-24-family-authorizations-transfers-validation.sql`

**Produces:** catálogo de vínculos, matriz familiar normalizada, autorizações operacionais, notificações contextuais e transferências aceitas pelo destino.

- [ ] Escrever testes para vínculo + detalhe, permissões por criança, criação imediata, suspensão com motivo/notificação e transferência cross-unit.
- [ ] Confirmar RED no remoto.
- [ ] Criar `family_relationship_types`, grants normalizados e RPCs de convite/configuração por instituição ou unidade.
- [ ] Criar pessoa autorizada com documento cifrado pelo chamador, fingerprint, capacidades, validade e suspensão auditada.
- [ ] Criar outbox/recipients de notificação sem conteúdo sensível.
- [ ] Criar solicitação de transferência em lote e RPC transacional de decisão pelo destino.
- [ ] Aplicar e validar RLS cross-tenant, cross-unit e invisibilidade sem capacidade.

### Task 3: Governança E Participação Em Atividades

**Files:**
- Modify: `packages/coelo_database/migrations/20260724152713_activity_governance_and_participation.sql`
- Create: `packages/coelo_database/tests/2026-07-24-activity-governance-participation-validation.sql`

**Produces:** distribuição, política, promoção sem duplicação, participação por criança e política institucional de capacidades.

- [ ] Escrever testes de promoção preservando ID, política fixa e participação `all`/`selected`.
- [ ] Confirmar RED no remoto.
- [ ] Evoluir `activity_definitions` sem substituir origem histórica.
- [ ] Criar políticas e settings normalizados por capacidade.
- [ ] Criar participantes por `child_group_link` e impedir outra instituição/unidade.
- [ ] Criar RPCs de promoção e configuração.
- [ ] Aplicar e validar RLS, auditoria e compatibilidade com a fundação existente.

### Task 4: Chat Contextual

**Files:**
- Modify: `packages/coelo_database/migrations/20260724152722_contextual_chat_foundation.sql`
- Create: `packages/coelo_database/tests/2026-07-24-contextual-chat-validation.sql`

**Produces:** configuração de canais, equipes, participantes contextuais, crianças relacionadas e snapshots de autoria.

- [ ] Escrever testes de chat institucional/unidade/grupo/atividade, equipe e professor restrito.
- [ ] Confirmar RED no remoto.
- [ ] Materializar FKs de escopo e configurações de chat institucional/unidade.
- [ ] Criar equipes e membros roteadores.
- [ ] Evoluir participantes e mensagens para preservar pessoa, papel, experiência e crianças relacionadas.
- [ ] Bloquear escrita quando o vínculo institucional terminar, preservando leitura histórica autorizada.
- [ ] Aplicar e validar isolamento e autoria histórica.

### Task 5: Presença E Assiduidade

**Files:**
- Modify: `packages/coelo_database/migrations/20260724152731_attendance_assiduity_foundation.sql`
- Create: `packages/coelo_database/tests/2026-07-24-attendance-assiduity-validation.sql`

**Produces:** catálogo de motivos, sessões, participantes esperados, avisos familiares, registros oficiais, revisões, lembretes e agregação.

- [ ] Escrever testes de aviso familiar pendente, ausência futura, D-1, confirmação, correção, desfazer e separação grupo/atividade.
- [ ] Confirmar RED no remoto.
- [ ] Criar entidades e constraints contextuais.
- [ ] Criar RPC familiar para aviso e RPC profissional para confirmar/corrigir/desfazer.
- [ ] Garantir que pendência nunca vire oficial automaticamente.
- [ ] Criar eventos agendados de notificação e view de agregados com `security_invoker`.
- [ ] Aplicar e validar RLS e dashboards sem mistura de pendências.

### Task 6: Catálogo, Advisors E Entrega

**Files:**
- Modify: `packages/coelo_database/README.md`
- Modify: `docs/data/data-model.md`
- Modify: `specs/011-superadmin-database-rls.md`
- Modify: `specs/014-atividade-contextual.md`
- Modify: `specs/015-contextual-people-access-attendance.md`

- [ ] Atualizar `schema_tables` e `schema_columns` em cada migration.
- [ ] Comparar migrations locais/remotas e registrar a divergência histórica sem reparar versões antigas destrutivamente.
- [ ] Executar todos os testes SQL/RLS.
- [ ] Executar advisors de segurança e performance e corrigir achados introduzidos.
- [ ] Consultar diretamente tabelas, funções, policies e histórico remoto.
- [ ] Atualizar documentação somente com fatos verificados.
- [ ] Fazer staging explícito e commit isolado da implementação.
