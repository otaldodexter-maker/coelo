---
source: "docs/superpowers/specs/2026-09-01-superadmin-communication-finish-design.md"
status: "active"
generated_at: "2026-09-01"
---

# Superadmin Communication Finish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar as superfícies de Comunicação do Superadmin funcionais, responsivas, coerentes em `/dev` e protegidas pelos contratos Supabase existentes.

**Architecture:** Cada feature mantém domínio e repository próprios; a UI compõe componentes canônicos de `coelo_ui_admin` e widgets compartilhados do Superadmin. Produção permanece fail-closed por RPC/RLS e `/dev` usa repositories locais determinísticos.

**Tech Stack:** Flutter, Dart, Supabase/Postgres, `coelo_ui_admin`, `coelo_tokens`, Flutter widget tests e pgTAP/SQL.

## Global Constraints

- Orçamento máximo: seis horas.
- Não implementar processamento real de importação/exportação neste pacote.
- Não importar componentes do Principal no Superadmin.
- Não declarar conclusão ponta a ponta com evidência apenas de `/dev` ou teste isolado.
- Usar `rtk` em todos os comandos shell.

---

### Task 1: Crash responsivo de Comunicações

**Files:**
- Modify: `apps/superadmin/lib/features/notices/presentation/notice_directory_page.dart`
- Test: `apps/superadmin/test/features/notices/notice_directory_page_test.dart`

**Interfaces:**
- Consumes: `CoeloAdminPagination` e `SuperadminListingPaginationFooter`.
- Produces: uma única decisão de layout que fornece `pageSize` e `pageSizeOptions` compatíveis.

- [ ] Adicionar teste que redimensiona a largura útil de ampla para compacta e verifica ausência de exceção com paginação visível.
- [ ] Executar `rtk flutter test test/features/notices/notice_directory_page_test.dart` em `apps/superadmin` e confirmar falha na asserção de `pageSizeOptions.contains(pageSize)`.
- [ ] Mover a sincronização do tamanho de página para a mesma decisão de breakpoint usada no `LayoutBuilder`, mantendo `11` para cards compactos e `8` para tabela.
- [ ] Executar novamente o teste focado e confirmar sucesso.

### Task 2: Conversas e detalhe de Convite

**Files:**
- Modify: `apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart`
- Modify: `apps/superadmin/lib/features/chat/data/supabase_chat_repository.dart`
- Modify: `apps/superadmin/lib/features/invites/presentation/invite_detail_page.dart`
- Test: `apps/superadmin/test/features/chat/presentation/superadmin_chat_page_data_test.dart`
- Test: `apps/superadmin/test/features/invites/invite_detail_page_test.dart`

**Interfaces:**
- Consumes: `ChatRepository`, `PlatformInvite` e os componentes administrativos já exportados.
- Produces: estados de chat distinguíveis e detalhe de convite com hierarquia canônica.

- [ ] Escrever teste reproduzindo o carregamento que atualmente cai no painel genérico e identificar a exceção segura produzida pelo repository.
- [ ] Corrigir apenas a causa identificada, preservando fail-closed e autorização server-side.
- [ ] Escrever teste do detalhe com retorno, resumo, ações, dados e linha do tempo em 375 e 1440.
- [ ] Compor o detalhe com superfícies e espaçamentos tokenizados, mantendo reenviar e revogar intactos.
- [ ] Executar os dois arquivos de teste focados.

### Task 3: Diretórios, arquivos e paginação

**Files:**
- Modify: `apps/superadmin/lib/features/invites/presentation/invite_directory_page.dart`
- Modify: `apps/superadmin/lib/features/notices/presentation/notice_directory_page.dart`
- Modify: `apps/superadmin/lib/features/circulars/presentation/circular_directory_page.dart`
- Test: `apps/superadmin/test/features/invites/invite_directory_page_test.dart`
- Test: `apps/superadmin/test/features/notices/notice_directory_page_test.dart`
- Test: `apps/superadmin/test/features/circulars/presentation/circular_directory_page_test.dart`

**Interfaces:**
- Consumes: `CoeloAdminListingToolbar`, `CoeloAdminFileActions`, `CoeloAdminResizableTable`, `CoeloAdminCreateAction` e `CoeloAdminPagination`.
- Produces: diretórios com a anatomia de Instituições e ações de arquivo explicitamente indisponíveis.

- [ ] Adicionar expectativas focadas para ações de arquivo, criação, tabela/lista e paginação depois do conteúdo.
- [ ] Reorganizar cada diretório na ordem toolbar, tabs, criação, conteúdo e rodapé de paginação.
- [ ] Ajustar larguras naturais de coluna e habilitar rolagem somente quando o conteúdo exigir.
- [ ] Executar os três testes focados.

### Task 4: Formulários de Comunicações e Circulares

**Files:**
- Modify: `apps/superadmin/lib/features/notices/presentation/notice_form_page.dart`
- Modify: `apps/superadmin/lib/features/circulars/presentation/circular_directory_page.dart`
- Create only if the existing route has no focused surface: `apps/superadmin/lib/features/circulars/presentation/circular_form_page.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_router.dart`
- Test: `apps/superadmin/test/features/notices/notice_form_page_test.dart`
- Test: `apps/superadmin/test/features/circulars/presentation/circular_directory_page_test.dart`

**Interfaces:**
- Consumes: `SuperadminFormStepNavigation`, `SuperadminFormActionFooter`, campos Coelo e contratos de circular existentes.
- Produces: formulário de aviso canônico e editor de circular com prévia responsiva.

- [ ] Escrever expectativas para a hierarquia do rodapé e para o editor/preview nos breakpoints críticos.
- [ ] Substituir o rodapé vertical local do aviso pelo rodapé compartilhado.
- [ ] Compor circular com título, corpo, mídia, perguntas, público/contexto, agendamento e publicação; a prévia aparece apenas quando houver largura útil.
- [ ] Ligar criar, editar e detalhe às rotas existentes sem alterar autorização.
- [ ] Executar os testes focados de formulários e rotas.

### Task 5: Fixtures e Supabase

**Files:**
- Modify: `apps/superadmin/lib/features/notices/data/development_notice_repository.dart`
- Modify: repositories `/dev` de chat, convites e circulares encontrados no wiring do router.
- Modify only if a gap is demonstrated: migrations/tests de Comunicação em `packages/coelo_database`.
- Test: testes dos repositories afetados e SQL específico da migration alterada.

**Interfaces:**
- Consumes: contratos de repository atuais e RPCs existentes.
- Produces: fixtures determinísticas e operações autorizadas sem acesso direto privilegiado no cliente.

- [ ] Escrever testes que comprovem quantidades maiores que uma página e vínculos coerentes por instituição, unidade, grupo, autor e público.
- [ ] Substituir fixtures numeradas por entidades plausíveis e datas relacionadas.
- [ ] Conferir CRUD/RLS de chat, convites, avisos e circulares por ator, tenant e escopo; alterar banco apenas quando o teste demonstrar lacuna.
- [ ] Executar testes Dart e SQL focados.

### Task 6: Gates e rastreadores

**Files:**
- Modify: `docs/reviews/coelo-flutter-pendencias.md`
- Modify: `docs/reviews/coelo-supabase-pendencias.md`
- Modify: `docs/reviews/coelo-flutter-integrado-supabase-pendencias.md`
- Modify durable canonical/knowledge documentation only when observable behavior changed.

**Interfaces:**
- Consumes: resultados das cinco tarefas anteriores.
- Produces: evidência rastreável sem ampliar a declaração de conclusão.

- [ ] Formatar somente Dart afetado e executar análise focada.
- [ ] Executar `rtk dart run apps/catalog/tool/validate_admin_visual_contracts.dart` na raiz.
- [ ] Executar testes focados e inspecionar 375/768/1024/1440 sem atualizar goldens para esconder regressões.
- [ ] Atualizar os três rastreadores com estados `local-green`, `blocked-supabase` ou `done` conforme a evidência real.
- [ ] Revisar `rtk git diff --check`, segredos e mudanças não relacionadas antes do commit final.

