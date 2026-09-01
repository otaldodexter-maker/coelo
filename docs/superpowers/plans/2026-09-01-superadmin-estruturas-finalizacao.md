# Superadmin Estruturas Finalização Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finalizar Instituições, Unidades, Turmas, Atividades, Avaliações e Chat em `/dev` e preservar a composição produtiva Supabase fail-closed.

**Architecture:** Reutilizar páginas e componentes existentes, concentrando padrões transversais no shell e nos widgets compartilhados. Fixtures entram apenas pelas rotas `/dev`; repositories produtivos continuam usando Supabase/RPC/RLS.

**Tech Stack:** Flutter, Dart, GoRouter, Supabase/Postgres, flutter_test.

## Global Constraints

- Orçamento máximo de execução: 6 horas; checkpoint interno em 3 horas.
- Testes focados e proporcionais; não regenerar a suíte completa de goldens.
- Importar/Exportar pode permanecer visual e desabilitado onde não houver contrato.
- Produção nunca usa fixtures como fallback.
- Handles aceitam `^[a-z0-9]+(?:-[a-z0-9]+)*$`.

---

### Task 1: Contratos regressivos e fixtures `/dev`

**Files:**
- Modify: `apps/superadmin/lib/app/dev_menu/development_fixture_catalog.dart`
- Modify: `apps/superadmin/lib/app/dev_menu/development_activity_fixture_repository.dart`
- Modify: `apps/superadmin/lib/app/router/README.md`
- Test: `apps/superadmin/test/app/router/development_fixture_composition_test.dart`

**Interfaces:** Consome os repositories fake existentes; produz hierarquia determinística dentro das quantidades aprovadas e 12 modelos/30 atividades.

- [ ] Escrever assertions RED para limites de instituições, unidades, turmas, modelos, atividades e turmas com/sem atividades.
- [ ] Executar o teste focal e confirmar RED nas quantidades antigas.
- [ ] Ajustar somente os geradores e a documentação canônica.
- [ ] Executar o teste e confirmar GREEN.

### Task 2: Shell mobile e ações compartilhadas de diretório

**Files:**
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Modify: widgets de toolbar/paginação dos seis diretórios do recorte
- Test: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`

**Interfaces:** Produz acionador de marca com chevron/drawer e mantém Bug acessível; diretórios recebem Arquivos e rodapé paginado canônicos.

- [ ] Adicionar testes RED para ausência de hambúrguer, marca/chevron, estado aberto e Bug mobile.
- [ ] Implementar o acionador mobile acessível e respiro de safe area.
- [ ] Completar Arquivos e paginação nas superfícies que ainda não os expõem.
- [ ] Rodar testes focados de shell e diretórios.

### Task 3: Instituições, Unidades e Turmas

**Files:**
- Modify: formulários e diretórios em `features/institutions`, `features/units` e `features/groups`
- Test: testes focados correspondentes em `apps/superadmin/test/features`

**Interfaces:** Preserva repositories atuais; produz mapa de localização, cards de Turmas no grid canônico e métrica `Professores` numérica.

- [ ] Escrever/reparar testes RED para mapa e card de Turma.
- [ ] Reutilizar o componente/serviço de localização sem chave secreta no cliente.
- [ ] Ajustar cards/tabela e corrigir as três regressões atuais de Turmas.
- [ ] Rodar testes focados dos três domínios.

### Task 4: Atividades e modelos

**Files:**
- Modify: `apps/superadmin/lib/features/activities/presentation/activity_directory_page.dart`
- Modify: `apps/superadmin/lib/features/activities/presentation/activity_form_page.dart`
- Modify: controllers/drafts/repositories de Atividades quando exigido pelos testes
- Test: testes focados de Atividades

**Interfaces:** Produz navegação full-page create/edit, abas de status, filtros pesquisáveis, duplicação escopada com sufixo e handle ASCII.

- [ ] Cobrir cada comportamento solicitado com assertions focadas RED.
- [ ] Implementar mudanças mínimas preservando contratos Supabase.
- [ ] Corrigir título edit/create e duplicação incremental por instituição/unidade.
- [ ] Rodar testes de controller, repository e páginas.

### Task 5: Avaliações

**Files:**
- Modify: `apps/superadmin/lib/features/activities/presentation/activity_form_sections.dart`
- Modify: `apps/superadmin/lib/features/activities/presentation/activity_pedagogical_configuration_draft.dart`
- Modify: `apps/superadmin/lib/features/assessments/assessment_pages.dart`
- Test: testes focados de configuração e Avaliações

**Interfaces:** Produz validação cronológica única, labels inequívocos, reorder acessível e tabelas/paginação canônicas.

- [ ] Escrever REDs para datas invertidas e labels duplicados.
- [ ] Centralizar validação da ordem cronológica no draft/controller.
- [ ] Alinhar lançamento/fechamento ao padrão de diretório e rodapé.
- [ ] Rodar testes focados.

### Task 6: Chat, integração, documentação e verificação

**Files:**
- Create: `apps/superadmin/lib/app/dev_menu/development_chat_repository.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_router.dart`
- Modify: testes de rota e Chat
- Modify: `docs/reviews/coelo-flutter-pendencias.md`
- Modify: `docs/reviews/coelo-supabase-pendencias.md`
- Modify: `docs/reviews/coelo-flutter-integrado-supabase-pendencias.md`
- Modify: projeções aplicáveis em `docs/knowledge/team`

**Interfaces:** `/dev/conversations` recebe repository determinístico; produção permanece Supabase/fail-closed.

- [ ] Escrever RED de composição `/dev` que exige conteúdo carregado sem Supabase.
- [ ] Implementar repository local e injetá-lo somente na rota `/dev`.
- [ ] Rodar testes de Chat, rotas, analyzer focado e `git diff --check`.
- [ ] Inspecionar desktop/mobile no navegador, atualizar rastreadores e memória, e revisar o diff final.
