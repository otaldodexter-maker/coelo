---
source: "docs/superpowers/specs/2026-07-27-superadmin-chat-adjustments-design.md; decisão aprovada em 2026-07-28"
status: "ready"
generated_at: "2026-07-28"
---

# Superadmin Chat Adjustments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajustar o chat do Superadmin com launcher global, filtros contextuais, inbox e painel recolhíveis, compositor por teclado e envio em massa local simulado; promover `pattern.chat-admin` como padrão institucional administrativo com a API pública mínima aprovada.

**Architecture:** Reutilizar os componentes e fixtures existentes. Manter regras e composição específicas no feature de chat; alterar `CoeloChatComposer` apenas para o comportamento neutro reutilizável de teclado, contexto e destaque do envio. Adaptar a composição com `LayoutBuilder`, sem dependências novas ou persistência. Promover somente `CoeloAdminChatMetric`, `CoeloAdminChatContextSummary` e `CoeloSize.avatarXl`; filtros, destinatários, envio e layout completo permanecem locais.

**Tech Stack:** Flutter, Dart, `flutter_test`, `coelo_tokens`, `coelo_ui_core`, `coelo_ui_admin`.

## Global Constraints

- O Design System Coelo prevalece sobre recomendações genéricas.
- Usar somente tokens semânticos; não adicionar HEX, `Color(0x...)` ou tipografia local.
- Nenhuma persistência, integração, autorização ou auditoria real.
- Nenhuma dependência nova; a promoção pública limita-se à API aprovada na
  spec, sem criar um `CoeloAdminChatLayout` monolítico.
- `Enter` envia; `Shift+Enter` insere nova linha.
- Layouts-alvo: 375, 768, 1024 e 1440 px, além de texto a 200%.
- Preservar mudanças preexistentes não relacionadas no worktree.

---

### Task 1: Compositor acessível por teclado

**Files:**
- Modify: `packages/coelo_ui_core/lib/src/chat/coelo_chat_composer.dart`
- Test: `packages/coelo_ui_core/test/chat/coelo_chat_components_test.dart`

**Interfaces:**
- Consumes: `TextEditingController`, `VoidCallback onSend`.
- Produces: `String? contextLabel`, `VoidCallback? onEmojiPressed` e envio por `Enter`.

- [ ] **Step 1: Escrever testes falhando**

Adicionar widget tests que:

```dart
await tester.enterText(find.byType(TextField), 'Olá');
await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
expect(sends, 1);
```

e que confirmem `Shift+Enter` sem envio, presença de `contextLabel` e botão
habilitado com `backgroundColor == colorScheme.primary`.

- [ ] **Step 2: Confirmar RED**

Run:

```powershell
flutter test test/chat/coelo_chat_components_test.dart
```

Working directory: `packages/coelo_ui_core`.

Expected: FAIL porque Enter, contexto e estilo ativo ainda não existem.

- [ ] **Step 3: Implementar o mínimo**

Usar `Focus.onKeyEvent` para consumir somente `Enter` sem Shift:

```dart
if (event is KeyDownEvent &&
    event.logicalKey == LogicalKeyboardKey.enter &&
    !HardwareKeyboard.instance.isShiftPressed &&
    _canSend) {
  widget.onSend();
  return KeyEventResult.handled;
}
return KeyEventResult.ignored;
```

Remover a borda superior do compositor, manter `maxLines`, acrescentar a ação
de emoji opcional e renderizar o contexto em uma segunda linha alinhada à
direita. Aplicar `IconButton.styleFrom(backgroundColor: colors.primary,
foregroundColor: colors.onPrimary)` somente quando `_canSend`.

- [ ] **Step 4: Confirmar GREEN**

Run: `flutter test test/chat/coelo_chat_components_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add packages/coelo_ui_core/lib/src/chat/coelo_chat_composer.dart packages/coelo_ui_core/test/chat/coelo_chat_components_test.dart
git commit -m "feat(ui): improve chat composer interactions"
```

### Task 2: Filtros separados e menus canônicos

**Files:**
- Modify: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_scope_filters.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/chat_fixtures.dart`
- Test: `apps/superadmin/test/features/chat/presentation/superadmin_chat_scope_filters_test.dart`
- Test: `apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart`

**Interfaces:**
- Consumes: `SuperadminChatConversation`.
- Produces: `SuperadminChatScopeDomain { contexts, people }`, opções UF e pessoa, cascata e agrupamento.

- [ ] **Step 1: Escrever testes falhando**

Cobrir:

```dart
expect(
  updatedSuperadminChatScope(current, SuperadminChatScopeKind.state, 'CE'),
  {SuperadminChatScopeKind.state: 'CE'},
);
expect(superadminChatScopeOptions(SuperadminChatScopeKind.personRole, selections),
    containsAll(['Responsáveis', 'Crianças', 'Professores', 'Outros']));
```

No widget test, abrir um filtro e verificar superfície neutra, item com altura
mínima de 48 px e hover `primaryContainer`.

- [ ] **Step 2: Confirmar RED**

Run:

```powershell
flutter test test/features/chat/presentation/superadmin_chat_scope_filters_test.dart test/features/chat/presentation/superadmin_chat_page_test.dart
```

Working directory: `apps/superadmin`.

Expected: FAIL porque UF, domínio de pessoa e grupos visuais não existem.

- [ ] **Step 3: Implementar o mínimo**

Acrescentar campos simulados opcionais às fixtures (`state`, `personRole`) e
organizar a toolbar em:

```dart
Column(
  children: [
    SegmentedButton<SuperadminChatScopeDomain>(...),
    Wrap(children: visibleFilters),
  ],
)
```

Reutilizar a lógica atual de descendentes. Manter `MenuAnchor`, mas envolver
seus itens em painel com superfície, borda, raio e elevação canônicos, abertura
a 4 px e overlay transparente.

- [ ] **Step 4: Confirmar GREEN**

Run: mesmo comando do Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_scope_filters.dart apps/superadmin/lib/features/chat/presentation/chat_fixtures.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_scope_filters_test.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart
git commit -m "feat(superadmin): refine contextual chat filters"
```

### Task 3: Inbox agrupada e launcher global

**Files:**
- Modify: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_launcher.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart`
- Modify carefully: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Test: `apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart`
- Test carefully: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`

**Interfaces:**
- Consumes: `SuperadminChatConversation.targetKind`, `SuperadminShell.showChatLauncher`.
- Produces: seções recolhíveis e controle `Inbox recolhida/expandida`.

- [ ] **Step 1: Escrever testes falhando**

Cobrir launcher em shell mesmo quando a página não fornece callback de
navegação, hover primário com conteúdo `onPrimary`, cabeçalho maior e seções:

```dart
expect(find.text('Grupos'), findsOne);
expect(find.text('Pessoas'), findsOne);
await tester.tap(find.byTooltip('Recolher conversas'));
expect(find.byKey(const Key('superadmin-chat-inbox-rail')), findsOne);
```

- [ ] **Step 2: Confirmar RED**

Run:

```powershell
flutter test test/app/shell/superadmin_shell_test.dart test/features/chat/presentation/superadmin_chat_page_test.dart
```

Working directory: `apps/superadmin`.

Expected: FAIL nos novos estados.

- [ ] **Step 3: Implementar o mínimo**

No launcher, trocar o hover para `primary` e resolver todos os conteúdos
internos com `onPrimary`. Renderizar seções com `ExpansionTile`, preservando
estado no widget. No shell, não condicionar a presença do launcher ao callback;
o callback ausente apenas desabilita a expansão para página completa.

No desktop, guardar `_inboxCollapsed` em `SuperadminChatPage` e alternar entre
inbox e rail usando a árvore já existente, sem criar controller global.

- [ ] **Step 4: Confirmar GREEN**

Run: mesmo comando do Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

Antes de adicionar o shell, revisar `git diff` para preservar as alterações
preexistentes da animação da sidebar.

```powershell
git add apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_launcher.dart apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart apps/superadmin/lib/app/shell/superadmin_shell.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart apps/superadmin/test/app/shell/superadmin_shell_test.dart
git commit -m "feat(superadmin): make chat navigation collapsible"
```

### Task 4: Painel contextual responsivo

**Files:**
- Create: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_context_panel.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/chat_fixtures.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart`
- Test: `apps/superadmin/test/features/chat/presentation/superadmin_chat_context_panel_test.dart`
- Test: `apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart`

**Interfaces:**
- Consumes: `SuperadminChatConversation`.
- Produces: `SuperadminChatContextPanel(conversation, collapsed, onToggle)`.

- [ ] **Step 1: Escrever testes falhando**

Para instituição, unidade, grupo e pessoa, exigir de dois a seis cards e rótulos
compatíveis. Exemplo:

```dart
expect(find.byKey(const Key('chat-context-metric')), findsNWidgets(4));
expect(find.text('Unidades'), findsOne);
expect(find.text('Grupos'), findsOne);
```

Testar composição em 1440, 1024, 768 e 375 px sem exceção de layout.

- [ ] **Step 2: Confirmar RED**

Run:

```powershell
flutter test test/features/chat/presentation/superadmin_chat_context_panel_test.dart test/features/chat/presentation/superadmin_chat_page_test.dart
```

Working directory: `apps/superadmin`.

Expected: FAIL porque o painel não existe.

- [ ] **Step 3: Implementar o mínimo**

Adicionar fixtures simples:

```dart
final class SuperadminChatMetric {
  const SuperadminChatMetric(this.label, this.value);
  final String label;
  final int value;
}
```

O painel usa `GridView.builder` com
`SliverGridDelegateWithMaxCrossAxisExtent`; a página usa `LayoutBuilder`:
três áreas em largura expandida, painel recolhido em 1024, detalhes sob demanda
em 768 e navegação empilhada em 375.

- [ ] **Step 4: Confirmar GREEN**

Run: mesmo comando do Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_context_panel.dart apps/superadmin/lib/features/chat/presentation/chat_fixtures.dart apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_context_panel_test.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart
git commit -m "feat(superadmin): add contextual chat summary"
```

### Task 5: Seleção e envio em massa local

**Files:**
- Create: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_recipient_picker.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart`
- Test: `apps/superadmin/test/features/chat/presentation/superadmin_chat_recipient_picker_test.dart`
- Test: `apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart`

**Interfaces:**
- Consumes: `CoeloAdminContextOption` e fixtures locais.
- Produces: `SuperadminChatRecipientPicker`, seleção local e resultado revisado.

- [ ] **Step 1: Escrever testes falhando**

Cobrir seleção individual, `Selecionar todos`, quantidade, revisão, cancelamento
e confirmação com texto `Demonstração local`:

```dart
await tester.tap(find.text('Selecionar todos'));
expect(find.text('4 destinatários selecionados'), findsOne);
await tester.tap(find.text('Revisar envio'));
expect(find.text('Demonstração local'), findsOne);
```

- [ ] **Step 2: Confirmar RED**

Run:

```powershell
flutter test test/features/chat/presentation/superadmin_chat_recipient_picker_test.dart test/features/chat/presentation/superadmin_chat_page_test.dart
```

Working directory: `apps/superadmin`.

Expected: FAIL porque o picker múltiplo e a revisão não existem.

- [ ] **Step 3: Implementar o mínimo**

Usar `Set<String>` local para IDs selecionados, `CheckboxListTile` com alvo
mínimo, e diálogo de revisão. Não criar repository ou ViewModel. O resultado
confirmado acrescenta apenas uma conversa/mensagem na lista em memória e mostra
um `SnackBar` de demonstração.

Aplicar superfície neutra, fechar canônico e restauração de foco nos diálogos.

- [ ] **Step 4: Confirmar GREEN**

Run: mesmo comando do Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_recipient_picker.dart apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_recipient_picker_test.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart
git commit -m "feat(superadmin): simulate bulk chat recipients"
```

### Task 6: Promover o padrão institucional de chat

**Files:**
- Modify: `packages/coelo_tokens/lib/src/coelo_scales.dart`
- Modify: `packages/coelo_ui_admin/lib/coelo_ui_admin.dart`
- Create: `packages/coelo_ui_admin/lib/src/chat/coelo_admin_chat_context_summary.dart`
- Create: `packages/coelo_ui_admin/test/chat/coelo_admin_chat_context_summary_test.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_context_panel.dart`
- Modify: `apps/superadmin/test/features/chat/presentation/superadmin_chat_context_panel_test.dart`
- Modify: `docs/design/design-system.md`
- Modify: `apps/catalog/assets/coelo-ui.index.jsonl`
- Modify: `apps/catalog/lib/catalog/chat_catalog_foundations.dart`
- Modify: `apps/catalog/test/catalog/chat_catalog_test.dart`
- Modify/Create: goldens de chat administrativo no catálogo
- Modify if durable and approved: `docs/knowledge/team/chat.md`

**Interfaces:**
- Produces: `CoeloSize.avatarXl = 64`, `CoeloAdminChatMetric(label, value)` e
  `CoeloAdminChatContextSummary`.
- Does not produce: `CoeloAdminChatLayout`, filtro, recipient picker ou regra
  de envio públicos.

- [ ] **Step 1: Escrever testes RED para token e API pública**

Adicionar cobertura do token e da API exportada pelo barrel público. O widget
deve aceitar duas a seis métricas, expor foco e semântica equivalentes e manter
foto contextual 1:1 com máximo de 64 px. Cobrir também tema claro/escuro,
texto a 200% e as variantes compact, medium e expanded/large em
375/768/1024/1440 px.

- [ ] **Step 2: Implementar o mínimo e confirmar GREEN**

Adicionar somente `CoeloSize.avatarXl = 64`,
`CoeloAdminChatMetric(label, value)` e
`CoeloAdminChatContextSummary` a `coelo_ui_admin`; não criar um layout
monolítico. Executar os testes focados de `coelo_tokens` e
`coelo_ui_admin` até ficarem verdes.

- [ ] **Step 3: Migrar o painel local do Superadmin**

Substituir a apresentação neutra local por
`CoeloAdminChatContextSummary`, preservando no feature a resolução de
domínio, fixtures, filtros, destinatários e envio. Confirmar que as métricas
continuam entre duas e seis, que recolhimento preserva seleção/foco e que não
há importação de catálogo pelo Superadmin.

- [ ] **Step 4: Evoluir Design System, índice e catálogo**

Documentar a anatomia (launcher global, toolbar/filtros, inbox/rail, fio,
resumo e compositor), medidas e variantes aprovadas no Design System. Atualizar
o índice e tornar `pattern.chat-admin` a referência executável de composição
no catálogo, com testes e goldens mobile claro e desktop escuro. Não registrar
as medidas como tokens globais além de `avatarXl`.

- [ ] **Step 5: Executar o gate de conhecimento**

Atualizar primeiro esta spec e o Design System; somente então projetar para
`docs/knowledge/team/chat.md` conhecimento durável, aprovado e sem dados
identificáveis. Executar `Test-CoeloKnowledge.ps1` e seus testes. Registrar
`no-op` se não houver conteúdo adicional reutilizável.

- [ ] **Step 6: Formatar os artefatos da promoção**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format packages/coelo_tokens/lib/src/coelo_scales.dart packages/coelo_ui_admin/lib/coelo_ui_admin.dart packages/coelo_ui_admin/lib/src/chat/coelo_admin_chat_context_summary.dart packages/coelo_ui_admin/test/chat/coelo_admin_chat_context_summary_test.dart apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_context_panel.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_context_panel_test.dart apps/catalog/lib/catalog/chat_catalog_foundations.dart apps/catalog/test/catalog/chat_catalog_test.dart
```

Expected: exit 0.

- [ ] **Step 7: Executar análise, testes e goldens da promoção**

Run `dart analyze` e os testes focados em `coelo_tokens`,
`coelo_ui_admin`, `apps/superadmin` e `apps/catalog`. Atualizar e verificar
os goldens mobile claro e desktop escuro. Executar também:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test
& '.agents\skills\coelo-ui\scripts\validate-index.ps1'
& '.agents\skills\coelo-knowledge\scripts\Test-CoeloKnowledge.ps1'
& '.agents\skills\coelo-knowledge\tests\Test-CoeloKnowledge.ps1'
```

Expected: zero diagnostics, testes e goldens verdes, índice e conhecimento
válidos. Executar análise e testes no diretório de cada pacote/app listado.

- [ ] **Step 8: Revisar diff e commitar seletivamente a promoção**

```powershell
git diff --check
git status --short
git add packages/coelo_tokens/lib/src/coelo_scales.dart packages/coelo_tokens/test packages/coelo_ui_admin/lib/coelo_ui_admin.dart packages/coelo_ui_admin/lib/src/chat packages/coelo_ui_admin/test/chat apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_context_panel.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_context_panel_test.dart apps/catalog/assets/coelo-ui.index.jsonl apps/catalog/lib/catalog/chat_catalog_foundations.dart apps/catalog/test/catalog/chat_catalog_test.dart apps/catalog/test/goldens docs/design/design-system.md
if (git status --short docs/knowledge/team/chat.md) { git add docs/knowledge/team/chat.md }
git commit -m "feat(ui): promote institutional chat pattern"
```

Adicionar `docs/knowledge/team/chat.md` somente se ele tiver sido alterado;
não incluir arquivos não relacionados. Confirmar que o diff contém o token, a
API de `coelo_ui_admin`, a migração do Superadmin, catálogo, Design System,
índice, testes/goldens e memória quando aplicável.

### Task 7: Integração visual, catálogo e verificação

**Files:**
- Modify: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_thread_body.dart`
- Verify: `packages/coelo_tokens/lib/src/coelo_scales.dart` e seus testes
- Verify: `packages/coelo_ui_admin/lib/coelo_ui_admin.dart`,
  `packages/coelo_ui_admin/lib/src/chat/` e seus testes
- Verify: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_context_panel.dart`
  e seus testes
- Verify: `docs/design/design-system.md`
- Verify: `apps/catalog/assets/coelo-ui.index.jsonl`
- Modify: `apps/catalog/lib/catalog/chat_catalog_foundations.dart`
- Modify: `apps/catalog/test/catalog/chat_catalog_test.dart`
- Verify: goldens de chat administrativo no catálogo
- Verify if altered: `docs/knowledge/team/chat.md`

**Interfaces:**
- Consumes: APIs implementadas nas Tasks 1–6, incluindo
  `CoeloChatComposer`, `CoeloSize.avatarXl`,
  `CoeloAdminChatMetric` e `CoeloAdminChatContextSummary`.
- Produces: integração final e evidência de verificação.

- [ ] **Step 1: Integrar compositor e remover divisores redundantes**

Passar:

```dart
CoeloChatComposer(
  controller: _composerController,
  onSend: _sendText,
  contextLabel: widget.conversation.context,
  onEmojiPressed: _openEmojiPicker,
  ...
)
```

Usar um menu local curto de emojis somente se puder ser feito com widgets
Flutter existentes; caso contrário, manter o ícone desabilitado com tooltip,
sem adicionar dependência.

- [ ] **Step 2: Atualizar integração final do catálogo e testes**

Integrar os estados amplo, recolhido e envio local à referência executável já
promovida na Task 6, sem promover componente público adicional.

- [ ] **Step 3: Formatar arquivos afetados**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format packages/coelo_tokens/lib/src/coelo_scales.dart packages/coelo_ui_admin/lib/coelo_ui_admin.dart packages/coelo_ui_admin/lib/src/chat packages/coelo_ui_admin/test/chat packages/coelo_ui_core/lib/src/chat packages/coelo_ui_core/test/chat apps/superadmin/lib/features/chat apps/superadmin/test/features/chat apps/catalog/lib/catalog/chat_catalog_foundations.dart apps/catalog/test/catalog/chat_catalog_test.dart
```

Expected: exit 0.

- [ ] **Step 4: Executar testes e análise**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test
```

Working directories: `packages/coelo_tokens`, `packages/coelo_ui_admin`,
`packages/coelo_ui_core`, `apps/superadmin` e `apps/catalog`.

Expected: zero diagnostics e todos os testes passando.

- [ ] **Step 5: Validar UI e memória**

Validar light/dark, 375/768/1024/1440, texto a 200%, hover, foco, teclado e
semântica. Executar:

```powershell
& '.agents\skills\coelo-ui\scripts\validate-index.ps1'
& '.agents\skills\coelo-knowledge\scripts\Test-CoeloKnowledge.ps1'
& '.agents\skills\coelo-knowledge\tests\Test-CoeloKnowledge.ps1'
```

Atualizar primeiro uma fonte canônica apenas se surgir conhecimento durável
além desta spec. Caso contrário, registrar gate de memória como `no-op`.

- [ ] **Step 6: Revisar diff e commit final**

```powershell
git diff --check
git status --short
git add packages/coelo_tokens/lib/src/coelo_scales.dart packages/coelo_tokens/test packages/coelo_ui_admin/lib/coelo_ui_admin.dart packages/coelo_ui_admin/lib/src/chat packages/coelo_ui_admin/test/chat apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_context_panel.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_context_panel_test.dart apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_thread_body.dart apps/catalog/assets/coelo-ui.index.jsonl apps/catalog/lib/catalog/chat_catalog_foundations.dart apps/catalog/test/catalog/chat_catalog_test.dart apps/catalog/test/goldens docs/design/design-system.md
if (git status --short docs/knowledge/team/chat.md) { git add docs/knowledge/team/chat.md }
git commit -m "test(superadmin): verify responsive chat experience"
```

Adicionar `docs/knowledge/team/chat.md` somente se alterado. Reconfirmar que
o commit não absorve mudanças não relacionadas e que a verificação cobre todos
os artefatos promovidos na Task 6.
