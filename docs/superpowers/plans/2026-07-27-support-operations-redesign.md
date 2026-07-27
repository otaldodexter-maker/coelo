---
source: "docs/superpowers/specs/2026-07-27-support-operations-redesign-design.md"
status: "approved-for-execution"
generated_at: "2026-07-27"
---

# Support Operations Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reformular a tela local de Suporte do Superadmin com filtros e tabela canônicos, Kanban operacional, contexto do solicitante e atribuição de responsável principal e colaboradores.

**Architecture:** `SupportPrototypeController` permanece a única fonte de estado em memória. O domínio recebe snapshots imutáveis de contexto e equipe; a apresentação é dividida em toolbar, Kanban, tabela e detalhe, todos consumindo o mesmo controller. Componentes administrativos públicos existentes são reutilizados; o Kanban e a pilha de responsáveis continuam locais à feature e são registrados como padrão, não como API pública.

**Tech Stack:** Flutter, Dart, `ChangeNotifier`, `coelo_tokens`, `coelo_ui_core`, `coelo_ui_admin`, `flutter_test`, testes golden.

## Global Constraints

- A gestão de Suporte existe somente em `apps/superadmin`.
- Todo estado reinicia ao recarregar o app.
- Não adicionar Supabase, migration, RLS, R2, upload, Realtime, notificações, auditoria, repository ou dependência.
- Coleções de tickets, mensagens, anexos, contexto e equipe permanecem imutáveis.
- Um ticket pode ter um responsável principal e colaboradores opcionais.
- A transição para `SupportTicketStatus.inProgress` exige responsável principal.
- Filtros e tabela seguem Instituições como referência canônica.
- Kanban e pilha de responsáveis permanecem composições locais da feature.
- Preservar e não sobrescrever alterações não relacionadas já presentes na árvore.
- Usar tokens semânticos; não introduzir HEX ou cores literais na feature.
- Garantir alvos de 48 px, foco visível, `Esc`, retorno de foco, light/dark e texto a 200%.

---

## File Map

### Domain and state

- Create `apps/superadmin/lib/features/support/domain/support_requester_context.dart`: snapshot e breadcrumb do contexto institucional.
- Create `apps/superadmin/lib/features/support/domain/support_team_member.dart`: função e identidade local dos executores.
- Modify `apps/superadmin/lib/features/support/domain/support_ticket.dart`: owner, colaboradores e novos filtros.
- Modify `apps/superadmin/lib/features/support/presentation/view_models/support_prototype_controller.dart`: fixtures, atribuição, transição validada e filtro.
- Modify `apps/superadmin/test/features/support/presentation/view_models/support_prototype_controller_test.dart`: cobertura do novo estado.

### Presentation

- Modify `apps/superadmin/lib/features/support/presentation/screens/support_page.dart`: orquestração, seleção e layout responsivo.
- Create `apps/superadmin/lib/features/support/presentation/widgets/support_filter_toolbar.dart`: composição canônica dos filtros e toggle.
- Create `apps/superadmin/lib/features/support/presentation/widgets/support_assignee_view.dart`: responsável e colaboradores.
- Create `apps/superadmin/lib/features/support/presentation/widgets/support_kanban.dart`: colunas, cards, drag e menus.
- Create `apps/superadmin/lib/features/support/presentation/widgets/support_ticket_table.dart`: tabela canônica.
- Create `apps/superadmin/lib/features/support/presentation/widgets/support_ticket_detail.dart`: relatório, contexto, evidências e conversa.
- Modify `apps/superadmin/test/features/support/presentation/screens/support_page_test.dart`: interações e sincronização.
- Modify `apps/superadmin/test/features/support/presentation/screens/support_page_golden_test.dart`: estados visuais.
- Replace `apps/superadmin/test/features/support/presentation/screens/goldens/support_*.png`: referências aprovadas.

### Shared UI and documentation

- Modify `packages/coelo_ui_admin/lib/src/filter/coelo_admin_multi_select_filter.dart`: estado aberto/foco já contratado.
- Modify `packages/coelo_ui_admin/test/filter/coelo_admin_multi_select_filter_test.dart`: regressões do gatilho.
- Modify `docs/design/design-system.md`: contrato do Kanban administrativo.
- Modify `apps/catalog/assets/coelo-ui.index.jsonl`: entrada `pattern.admin-kanban`.
- Modify `apps/catalog/assets/catalog-sync-report.json`: relatório regenerado pelo validador.
- Modify `apps/catalog/lib/catalog/surface_interaction_catalog_foundations.dart`: foundation do padrão.
- Modify `apps/catalog/test/catalog/surface_interaction_catalog_test.dart`: cobertura da foundation.
- Modify `.agents/skills/coelo-ui/references/surface-interaction-contracts.md`: roteamento durável para o novo padrão.
- Modify `.agents/skills/coelo-ui/tests/surface-interaction-contracts.tests.ps1`: presença das regras.
- Modify `specs/016-superadmin-support-prototype.md`: registrar equipe como extensão local aprovada.
- Modify `apps/superadmin/lib/features/support/README.md`: limites e comandos da feature.

---

### Task 1: Requester context and support team domain

**Files:**
- Create: `apps/superadmin/lib/features/support/domain/support_requester_context.dart`
- Create: `apps/superadmin/lib/features/support/domain/support_team_member.dart`
- Modify: `apps/superadmin/lib/features/support/domain/support_ticket.dart`
- Test: `apps/superadmin/test/features/support/presentation/view_models/support_prototype_controller_test.dart`

**Interfaces:**
- Produces: `SupportRequesterContext`, `SupportTeamRole`, `SupportTeamMember`.
- Produces: `SupportTicket.ownerId`, `SupportTicket.collaboratorIds`, `SupportTicket.requesterContext`.
- Produces: `SupportFilters.assigneeIds`.

- [ ] **Step 1: Write failing immutable-domain tests**

Add tests that construct a full context, omit intermediate-free suffixes, and
verify owner/collaborator/filter collections:

```dart
test('builds requester context without empty breadcrumb levels', () {
  const context = SupportRequesterContext(
    institution: 'Centro Horizonte',
    unit: 'Unidade Cambuí',
    group: 'Turma Girassol',
  );

  expect(
    context.labels,
    ['Centro Horizonte', 'Unidade Cambuí', 'Turma Girassol'],
  );
  expect(
    context.breadcrumb,
    'Centro Horizonte > Unidade Cambuí > Turma Girassol',
  );
});

test('keeps support collaborators and assignee filters immutable', () {
  final item = ticket(
    id: 'SUP-1',
    status: SupportTicketStatus.newRequest,
    ownerId: 'member-support',
    collaboratorIds: {'member-qa'},
  );
  final filters = SupportFilters(assigneeIds: {'member-support'});

  expect(() => item.collaboratorIds.add('member-dev'), throwsUnsupportedError);
  expect(() => filters.assigneeIds.add('member-dev'), throwsUnsupportedError);
});
```

- [ ] **Step 2: Run the focused test and verify failure**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/support/presentation/view_models/support_prototype_controller_test.dart
```

Working directory: `apps/superadmin`.

Expected: compilation fails because the context/team types and new parameters
do not exist.

- [ ] **Step 3: Implement the immutable domain**

Create the context with ordered optional labels:

```dart
final class SupportRequesterContext {
  const SupportRequesterContext({
    this.institution,
    this.unit,
    this.group,
    this.activity,
  });

  final String? institution;
  final String? unit;
  final String? group;
  final String? activity;

  List<String> get labels => List.unmodifiable([
    if (institution case final value?) value,
    if (unit case final value?) value,
    if (group case final value?) value,
    if (activity case final value?) value,
  ]);

  String get breadcrumb => labels.join(' > ');
}
```

Create team types:

```dart
enum SupportTeamRole { support, development, customerSuccess, qualityAssurance }

final class SupportTeamMember {
  const SupportTeamMember({
    required this.id,
    required this.name,
    required this.initials,
    required this.role,
  });

  final String id;
  final String name;
  final String initials;
  final SupportTeamRole role;
}
```

Extend `SupportTicket` and `SupportFilters` with nullable `ownerId`,
unmodifiable `collaboratorIds`, optional `requesterContext` and unmodifiable
`assigneeIds`. Preserve all fields through `copyWith`; include
`clearOwner = false` so callers can distinguish “preserve” from “remove”:

```dart
SupportTicket copyWith({
  DateTime? updatedAt,
  SupportTicketStatus? status,
  SupportRequesterContext? requesterContext,
  String? ownerId,
  bool clearOwner = false,
  Set<String>? collaboratorIds,
  List<SupportAttachment>? attachments,
  List<SupportMessage>? messages,
}) {
  return SupportTicket(
    id: id,
    subject: subject,
    menu: menu,
    screen: screen,
    description: description,
    requester: requester,
    requesterContext: requesterContext ?? this.requesterContext,
    ownerId: clearOwner ? null : ownerId ?? this.ownerId,
    collaboratorIds: collaboratorIds ?? this.collaboratorIds,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    status: status ?? this.status,
    attachments: attachments ?? this.attachments,
    messages: messages ?? this.messages,
  );
}
```

- [ ] **Step 4: Run domain tests**

Run the same command.

Expected: all controller tests pass after updating the local `ticket` test
factory with optional owner, collaborator and context arguments.

- [ ] **Step 5: Review and commit only domain files**

```powershell
git diff --check -- apps/superadmin/lib/features/support/domain apps/superadmin/test/features/support/presentation/view_models/support_prototype_controller_test.dart
git add apps/superadmin/lib/features/support/domain/support_requester_context.dart apps/superadmin/lib/features/support/domain/support_team_member.dart apps/superadmin/lib/features/support/domain/support_ticket.dart apps/superadmin/test/features/support/presentation/view_models/support_prototype_controller_test.dart
git commit -m "feat(superadmin): model support ownership and requester context"
```

---

### Task 2: Controller assignments, validated transitions, filters and fixtures

**Files:**
- Modify: `apps/superadmin/lib/features/support/presentation/view_models/support_prototype_controller.dart`
- Modify: `apps/superadmin/test/features/support/presentation/view_models/support_prototype_controller_test.dart`

**Interfaces:**
- Consumes: domain types from Task 1.
- Produces: `teamMembers`, `assignOwner`, `setCollaborators`.
- Produces: `bool changeStatus(String ticketId, SupportTicketStatus status)`.
- Produces: demonstrative `sessionRequesterContext` copied by `submitReport`.

- [ ] **Step 1: Write failing controller tests**

Add:

```dart
test('requires an owner before moving a ticket to in progress', () {
  final controller = SupportPrototypeController(
    initialTickets: [ticket(id: 'SUP-1', status: SupportTicketStatus.newRequest)],
    clock: () => fixedNow,
  );
  addTearDown(controller.dispose);

  expect(
    controller.changeStatus('SUP-1', SupportTicketStatus.inProgress),
    isFalse,
  );
  controller.assignOwner('SUP-1', 'member-support');
  expect(
    controller.changeStatus('SUP-1', SupportTicketStatus.inProgress),
    isTrue,
  );
});

test('assigns one owner and immutable collaborators', () {
  final controller = SupportPrototypeController(
    initialTickets: [ticket(id: 'SUP-1', status: SupportTicketStatus.newRequest)],
    clock: () => fixedNow,
  );
  addTearDown(controller.dispose);

  controller.assignOwner('SUP-1', 'member-dev');
  controller.setCollaborators('SUP-1', {'member-qa', 'member-support'});

  expect(controller.tickets.single.ownerId, 'member-dev');
  expect(
    controller.tickets.single.collaboratorIds,
    {'member-qa', 'member-support'},
  );
});

test('filters tickets by owner or collaborator', () {
  final controller = SupportPrototypeController(
    initialTickets: [
      ticket(
        id: 'SUP-1',
        status: SupportTicketStatus.inProgress,
        ownerId: 'member-dev',
      ),
      ticket(
        id: 'SUP-2',
        status: SupportTicketStatus.waitingRequester,
        collaboratorIds: {'member-qa'},
      ),
    ],
  );
  addTearDown(controller.dispose);

  controller.updateFilters(SupportFilters(assigneeIds: {'member-qa'}));
  expect(controller.filteredTickets.map((ticket) => ticket.id), ['SUP-2']);
});

test('copies the demonstrative session context into a submitted report', () {
  const sessionContext = SupportRequesterContext(
    institution: 'Centro Horizonte',
    unit: 'Unidade Cambuí',
  );
  final controller = SupportPrototypeController(
    initialTickets: const [],
    clock: () => fixedNow,
    sessionRequesterContext: sessionContext,
  );
  addTearDown(controller.dispose);

  final created = controller.submitReport(
    const SupportReportDraft(
      menu: 'Instituições',
      screen: 'Diretório',
      subject: 'Erro ao salvar',
      description: 'O botão não conclui a ação.',
      requester: 'Camila Rocha',
    ),
  );

  expect(created.requesterContext, same(sessionContext));
});
```

- [ ] **Step 2: Run and verify failure**

Run the controller test command from Task 1.

Expected: compilation fails for missing controller members or return type.

- [ ] **Step 3: Implement controller behavior**

Expose immutable fixtures:

```dart
static const defaultTeamMembers = <SupportTeamMember>[
  SupportTeamMember(
    id: 'member-support',
    name: 'Ana Souza',
    initials: 'AS',
    role: SupportTeamRole.support,
  ),
  SupportTeamMember(
    id: 'member-dev',
    name: 'Caio Lima',
    initials: 'CL',
    role: SupportTeamRole.development,
  ),
  SupportTeamMember(
    id: 'member-cs',
    name: 'Bia Nunes',
    initials: 'BN',
    role: SupportTeamRole.customerSuccess,
  ),
  SupportTeamMember(
    id: 'member-qa',
    name: 'Davi Reis',
    initials: 'DR',
    role: SupportTeamRole.qualityAssurance,
  ),
];
```

Implement assignment and transition validation:

```dart
void assignOwner(String ticketId, String? memberId) {
  _replaceTicket(
    ticketId,
    (ticket) => ticket.copyWith(ownerId: memberId, clearOwner: memberId == null),
  );
}

void setCollaborators(String ticketId, Set<String> memberIds) {
  _replaceTicket(
    ticketId,
    (ticket) => ticket.copyWith(collaboratorIds: memberIds),
  );
}

bool changeStatus(String ticketId, SupportTicketStatus status) {
  final ticket = _ticketById(ticketId);
  if (ticket == null ||
      status == SupportTicketStatus.inProgress && ticket.ownerId == null) {
    return false;
  }
  _replaceTicket(
    ticketId,
    (current) => current.copyWith(status: status, updatedAt: _clock()),
  );
  return true;
}
```

Accept an optional `SupportRequesterContext sessionRequesterContext` in the
controller constructor, default it to a demonstrative current-session context
and copy it in `submitReport`. Include owner and collaborator IDs in
`_matchesFilters`, requester context labels in searchable text,
complete/institution-only/no-context fixture coverage, and valid owners for
existing `inProgress` fixtures.

- [ ] **Step 4: Run controller tests**

Expected: all tests pass, including existing creation/read/reply tests.

- [ ] **Step 5: Commit controller slice**

```powershell
git diff --check -- apps/superadmin/lib/features/support/presentation/view_models/support_prototype_controller.dart apps/superadmin/test/features/support/presentation/view_models/support_prototype_controller_test.dart
git add apps/superadmin/lib/features/support/presentation/view_models/support_prototype_controller.dart apps/superadmin/test/features/support/presentation/view_models/support_prototype_controller_test.dart
git commit -m "feat(superadmin): manage support ticket assignments"
```

---

### Task 3: Canonical multi-select open and focus states

**Files:**
- Modify: `packages/coelo_ui_admin/lib/src/filter/coelo_admin_multi_select_filter.dart`
- Modify: `packages/coelo_ui_admin/test/filter/coelo_admin_multi_select_filter_test.dart`

**Interfaces:**
- Preserves the existing public constructor.
- Produces no new public API.

- [ ] **Step 1: Add failing visual-state widget tests**

Add tests using a `GlobalKey` on the filter trigger. Open the menu and assert:

```dart
await tester.tap(find.text('Todos os status'));
await tester.pumpAndSettle();

final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
final openStates = <WidgetState>{};
expect(
  button.style?.backgroundColor?.resolve(openStates),
  theme.colorScheme.primaryContainer,
);
expect(
  button.style?.foregroundColor?.resolve(openStates),
  theme.colorScheme.primary,
);
expect(
  button.style?.side?.resolve(openStates)?.width,
  2,
);
```

Also retain the existing `Esc` draft-discard and focus-return assertions.

- [ ] **Step 2: Run package test and verify failure**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/filter/coelo_admin_multi_select_filter_test.dart
```

Working directory: `packages/coelo_ui_admin`.

Expected: open-state styling assertion fails.

- [ ] **Step 3: Implement open-state styling without changing the API**

Use `_menuController.isOpen` while building the trigger and merge it with widget
states:

```dart
final menuOpen = controller.isOpen;
final active = menuOpen ||
    states.contains(WidgetState.hovered) ||
    states.contains(WidgetState.focused) ||
    states.contains(WidgetState.pressed);
```

Resolve background to `primaryContainer` only while open, foreground to
`primary` while active, and side to `BorderSide(color: primary, width: 2)` for
focus/open. Keep overlay and splash transparent.

- [ ] **Step 4: Run all package tests**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test
```

Working directory: `packages/coelo_ui_admin`.

Expected: package suite passes.

- [ ] **Step 5: Commit the shared-component correction**

Before staging, inspect the existing user diff and stage only the two paths:

```powershell
git diff -- packages/coelo_ui_admin/lib/src/filter/coelo_admin_multi_select_filter.dart packages/coelo_ui_admin/test/filter/coelo_admin_multi_select_filter_test.dart
git add packages/coelo_ui_admin/lib/src/filter/coelo_admin_multi_select_filter.dart packages/coelo_ui_admin/test/filter/coelo_admin_multi_select_filter_test.dart
git commit -m "fix(ui): align admin filter open states"
```

---

### Task 4: Canonical support toolbar and table

**Files:**
- Create: `apps/superadmin/lib/features/support/presentation/widgets/support_filter_toolbar.dart`
- Create: `apps/superadmin/lib/features/support/presentation/widgets/support_assignee_view.dart`
- Create: `apps/superadmin/lib/features/support/presentation/widgets/support_ticket_table.dart`
- Modify: `apps/superadmin/lib/features/support/presentation/screens/support_page.dart`
- Modify: `apps/superadmin/test/features/support/presentation/screens/support_page_test.dart`

**Interfaces:**
- Consumes: controller and domain interfaces from Tasks 1–2.
- Produces: `SupportDisplayMode`, `SupportFilterToolbar`,
  `SupportAssigneeView`, `SupportTicketTable`.

- [ ] **Step 1: Replace old toolbar/table expectations with failing tests**

Assert the canonical keys and progressive screen filter:

```dart
expect(find.byKey(const Key('support-search')), findsOneWidget);
expect(find.byKey(const Key('support-status-filter')), findsOneWidget);
expect(find.byKey(const Key('support-menu-filter')), findsOneWidget);
expect(find.byKey(const Key('support-assignee-filter')), findsOneWidget);
expect(find.byKey(const Key('support-read-filter')), findsOneWidget);
expect(find.byKey(const Key('support-screen-filter')), findsNothing);

await tester.tap(find.byKey(const Key('support-menu-filter')));
await tester.tap(find.text('Instituições').last);
await tester.tap(find.text('Aplicar').last);
await tester.pumpAndSettle();
expect(find.byKey(const Key('support-screen-filter')), findsOneWidget);
```

Switch to the table through tooltip and assert headers:

```dart
await tester.tap(find.byTooltip('Exibir como tabela'));
await tester.pumpAndSettle();
for (final label in [
  'Chamado',
  'Origem',
  'Solicitante / contexto',
  'Responsável',
  'Status',
  'Anexos',
  'Não lidas',
  'Atualizado em',
]) {
  expect(find.text(label), findsWidgets);
}
```

- [ ] **Step 2: Run the support widget test and verify failure**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/support/presentation/screens/support_page_test.dart
```

Working directory: `apps/superadmin`.

Expected: keys, tooltips and columns are absent.

- [ ] **Step 3: Implement toolbar composition**

Build `SupportFilterToolbar` with `LayoutBuilder`,
`CoeloAdminListingToolbar`, explicit search/filter widths, and:

```dart
enum SupportDisplayMode { kanban, table }
```

Use `CoeloSearchField` and `CoeloAdminMultiSelectFilter` for Status, Menu,
Responsável, Leitura and conditional Tela. Represent reading as:

```dart
enum SupportReadFilter { unread }
```

Map `{SupportReadFilter.unread}` to `SupportFilters.unreadOnly`. Use an icon-only
`SegmentedButton<SupportDisplayMode>` matching Institutions.

- [ ] **Step 4: Implement canonical table and assignee view**

Configure:

```dart
CoeloAdminResizableTable<SupportTicket>(
  items: tickets,
  rowKey: (ticket) => ticket.id,
  headerHeight: 56,
  rowHeight: 64,
  pinnedColumn: ticketColumn,
  columns: columns,
  onRowPressed: onTicketPressed,
  isSelected: (ticket) => ticket.id == selectedTicketId,
)
```

`SupportAssigneeView` resolves IDs against `teamMembers`, renders the principal
first and collaborators as overlapping tokenized 32 px circles, and exposes
text semantics containing name and role. Do not use chat presence/Now avatar.

- [ ] **Step 5: Run the support widget tests**

Expected: toolbar, progressive filter, table columns and status synchronization
pass.

- [ ] **Step 6: Commit presentation slice**

```powershell
git diff --check -- apps/superadmin/lib/features/support/presentation apps/superadmin/test/features/support/presentation/screens/support_page_test.dart
git add apps/superadmin/lib/features/support/presentation/screens/support_page.dart apps/superadmin/lib/features/support/presentation/widgets/support_filter_toolbar.dart apps/superadmin/lib/features/support/presentation/widgets/support_assignee_view.dart apps/superadmin/lib/features/support/presentation/widgets/support_ticket_table.dart apps/superadmin/test/features/support/presentation/screens/support_page_test.dart
git commit -m "feat(superadmin): align support filters and table"
```

---

### Task 5: Operational Kanban, assignment menus and detail

**Files:**
- Create: `apps/superadmin/lib/features/support/presentation/widgets/support_kanban.dart`
- Create: `apps/superadmin/lib/features/support/presentation/widgets/support_ticket_detail.dart`
- Modify: `apps/superadmin/lib/features/support/presentation/screens/support_page.dart`
- Modify: `apps/superadmin/test/features/support/presentation/screens/support_page_test.dart`

**Interfaces:**
- Consumes: `SupportAssigneeView`, controller assignment/status methods.
- Produces: `SupportKanban`, `SupportTicketDetail`.

- [ ] **Step 1: Add failing Kanban, assignment and detail tests**

Cover column/card anatomy and owner-required transition:

```dart
expect(find.byKey(const Key('support-kanban-newRequest')), findsOneWidget);
expect(find.byKey(const Key('support-card-SUP-001')), findsOneWidget);
expect(find.text('Camila Rocha'), findsWidgets);
expect(find.text('Centro Horizonte > Unidade Cambuí'), findsWidgets);

await tester.tap(find.byKey(const Key('support-card-menu-SUP-001')));
await tester.tap(find.text('Atribuir responsável').last);
await tester.tap(find.text('Ana Souza · Suporte').last);
await tester.pumpAndSettle();
expect(controller.tickets.first.ownerId, 'member-support');
```

Cover status menu and drag:

```dart
final card = find.byKey(const Key('support-card-SUP-001'));
final target = find.byKey(const Key('support-kanban-inProgress'));
await tester.drag(card, tester.getCenter(target) - tester.getCenter(card));
await tester.pumpAndSettle();
expect(
  controller.tickets.first.status,
  SupportTicketStatus.inProgress,
);
```

Cover detail context, collaborators, evidence, read state and composer.

- [ ] **Step 2: Run the widget test and verify failure**

Run the support widget command from Task 4.

Expected: new card keys, assignment menu and context are absent.

- [ ] **Step 3: Implement Kanban**

Use a horizontally scrollable row at medium/large widths and one selected lane
at compact width. Each `DragTarget<SupportTicket>` has a low-emphasis semantic
surface, text label and count. Cards use `LongPressDraggable` plus a contextual
menu, with `CoeloSpacing.space2` or greater between cards.

When a drop requests `inProgress` without owner, open the owner picker; after a
choice, call `assignOwner` and then `changeStatus`. For all other statuses call
`changeStatus` directly.

Use tokens from `CoeloStatusColors` for accents and `colorScheme.surface`,
`surfaceContainerLow`, `outlineVariant`, `primaryContainer` and `primary`.

- [ ] **Step 4: Implement detail and focus restoration**

Move the current detail composition into `SupportTicketDetail`. Add:

- owner selector;
- collaborator multi-select;
- full requester breadcrumb;
- canonical `Icons.close_rounded` 48 px action;
- `Shortcuts`/`Actions` for `Escape`;
- callback that restores focus to the originating card/row.

Keep `CoeloMessageBubble` and `CoeloChatComposer` unchanged.

- [ ] **Step 5: Run support widget and controller tests**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/support
```

Working directory: `apps/superadmin`.

Expected: all support tests pass.

- [ ] **Step 6: Commit operational UI**

```powershell
git diff --check -- apps/superadmin/lib/features/support/presentation apps/superadmin/test/features/support
git add apps/superadmin/lib/features/support/presentation/screens/support_page.dart apps/superadmin/lib/features/support/presentation/widgets/support_kanban.dart apps/superadmin/lib/features/support/presentation/widgets/support_ticket_detail.dart apps/superadmin/test/features/support/presentation/screens/support_page_test.dart
git commit -m "feat(superadmin): add operational support kanban"
```

---

### Task 6: Design system, catalog, skill and feature documentation

**Files:**
- Modify: `docs/design/design-system.md`
- Modify: `apps/catalog/assets/coelo-ui.index.jsonl`
- Modify: `apps/catalog/assets/catalog-sync-report.json`
- Modify: `apps/catalog/lib/catalog/surface_interaction_catalog_foundations.dart`
- Modify: `apps/catalog/test/catalog/surface_interaction_catalog_test.dart`
- Modify: `.agents/skills/coelo-ui/references/surface-interaction-contracts.md`
- Modify: `.agents/skills/coelo-ui/tests/surface-interaction-contracts.tests.ps1`
- Modify: `specs/016-superadmin-support-prototype.md`
- Modify: `apps/superadmin/lib/features/support/README.md`

**Interfaces:**
- Produces: catalog ID `pattern.admin-kanban`.
- Does not produce a public Dart widget.

- [ ] **Step 1: Add failing skill/catalog assertions**

Extend the PowerShell contract test to require:

```powershell
Assert-Contains $contracts 'pattern.admin-kanban'
Assert-Contains $contracts 'responsável principal'
Assert-Contains $contracts 'alternativa por menu'
Assert-Contains $contracts 'não é uma API pública'
```

Extend `apps/catalog/test/catalog/surface_interaction_catalog_test.dart` to
build `buildSurfaceInteractionFoundationRegistry()`, find
`pattern.admin-kanban`, and assert its referenced IDs include
`core.status-chip` and `admin.multi-select-filter`. Extend the catalog index
validator test fixture to assert category `pattern`, status `implemented`,
consumer `superadmin`, local example path and accessibility text mentioning
keyboard/touch alternatives.

- [ ] **Step 2: Run validators and verify failure**

```powershell
powershell -ExecutionPolicy Bypass -File .agents/skills/coelo-ui/tests/surface-interaction-contracts.tests.ps1
```

Expected: missing Kanban contract assertions.

Run the catalog test command used by `apps/catalog`; expected: missing catalog
entry/foundation.

- [ ] **Step 3: Add the durable Kanban contract**

Document:

- four-part anatomy: board, lane, card, assignment;
- semantic status label/count independent of color;
- 8 px or greater card separation;
- desktop drag/drop;
- keyboard/touch status menu;
- principal owner plus collaborators;
- horizontal board at medium/large and one lane at compact;
- local-first implementation and no public API until a second validated use.

- [ ] **Step 4: Register catalog pattern**

Add one JSONL object:

```json
{"id":"pattern.admin-kanban","name":"Kanban administrativo","category":"pattern","status":"implemented","ownerPackage":"superadmin","consumers":["superadmin"],"purpose":"Organizar trabalho operacional por status com responsável principal e colaboradores.","useWhen":"Itens administrativos precisam mudar de etapa e manter responsabilidade explícita.","doNotUseWhen":"Uma lista ou tabela comunica melhor o fluxo, ou quando arrastar é a única forma de alterar status.","variants":["desktop","tablet","mobile"],"states":["default","empty-lane","dragging","valid-drop","selected","unassigned"],"tokens":["spacing.2","spacing.3","radius.lg","color.surface","color.surface-container","color.outline-variant","color.primary-container"],"accessibility":"Status combina label e contador; toda ação de arrastar possui alternativa por menu para teclado e toque; responsável principal e colaboradores têm nomes acessíveis.","publicFile":"apps/superadmin/lib/features/support/presentation/widgets/support_kanban.dart","tests":["apps/superadmin/test/features/support/presentation/screens/support_page_test.dart"],"example":"SupportKanban(tickets: tickets, teamMembers: teamMembers, onOpen: open, onStatusChanged: changeStatus)","replacement":null}
```

Add a foundation pointing to `pattern.admin-kanban`, `core.status-chip` and
`admin.multi-select-filter`. It is composed by
`buildSurfaceInteractionFoundationRegistry()` and therefore requires no entry
in the public component registry. Preserve all user edits around the
foundation file.

- [ ] **Step 5: Update spec and README**

Record that team attribution is a local approved extension, that owner is
required for `Em andamento`, and list focused test/preview commands. Do not
rewrite unrelated frontmatter or open questions.

- [ ] **Step 6: Run documentation/catalog validators**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .agents/skills/coelo-ui/tests/surface-interaction-contracts.tests.ps1
powershell -ExecutionPolicy Bypass -File .agents/skills/coelo-ui/scripts/query-index.ps1 -Query "kanban administrativo"
```

Expected: contract tests pass and query returns `pattern.admin-kanban`.

Run from `apps/catalog`:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool/validate_catalog_index.dart assets/coelo-ui.index.jsonl ..\..
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool/validate_package_boundaries.dart assets/coelo-ui.index.jsonl ..\..
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool/validate_catalog_sync.dart assets/coelo-ui.index.jsonl lib/catalog/catalog_registry.dart assets/catalog-sync-report.json ..\..
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/tool/validate_catalog_index_test.dart test/tool/validate_package_boundaries_test.dart test/tool/validate_catalog_sync_test.dart
```

Expected: índice, fronteiras e sincronização sem diagnósticos; testes passam.

- [ ] **Step 7: Commit only reviewed documentation/catalog hunks**

Because these paths already contain user changes, use interactive staging or
create a patch containing only this task’s hunks:

```powershell
git diff -- docs/design/design-system.md apps/catalog .agents/skills/coelo-ui specs/016-superadmin-support-prototype.md apps/superadmin/lib/features/support/README.md
git add -p docs/design/design-system.md apps/catalog/assets/coelo-ui.index.jsonl apps/catalog/assets/catalog-sync-report.json apps/catalog/lib/catalog/surface_interaction_catalog_foundations.dart apps/catalog/test/catalog/surface_interaction_catalog_test.dart .agents/skills/coelo-ui/references/surface-interaction-contracts.md .agents/skills/coelo-ui/tests/surface-interaction-contracts.tests.ps1 specs/016-superadmin-support-prototype.md apps/superadmin/lib/features/support/README.md
git commit -m "docs(ui): define administrative kanban pattern"
```

Confirm `git diff --cached --name-only` and the cached patch before committing.

---

### Task 7: Goldens, full verification and localhost preview

**Files:**
- Modify: `apps/superadmin/test/features/support/presentation/screens/support_page_golden_test.dart`
- Replace: `apps/superadmin/test/features/support/presentation/screens/goldens/support_*.png`
- Modify only if test evidence requires it: files from Tasks 1–6.

**Interfaces:**
- Consumes all previous tasks.
- Produces verified visual references and running preview.

- [ ] **Step 1: Extend golden scenarios**

Keep widths `375`, `768`, `1024`, `1440`, both themes, and three surfaces:
Kanban, table and detail. Stabilize time, fixtures and disabled animations.
Use tooltips rather than visible `Kanban`/`Tabela` labels when toggling.

- [ ] **Step 2: Run non-updating golden test**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/support/presentation/screens/support_page_golden_test.dart
```

Working directory: `apps/superadmin`.

Expected: golden mismatches reflecting the intentional redesign, with no
exceptions, overflows or missing fonts.

- [ ] **Step 3: Generate new goldens**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test --update-goldens test/features/support/presentation/screens/support_page_golden_test.dart
```

Expected: 24 references updated.

- [ ] **Step 4: Inspect representative images**

Inspect at minimum:

- `support_kanban_light_1440.png`;
- `support_table_light_1440.png`;
- `support_detail_dark_1024.png`;
- `support_kanban_light_375.png`;
- `support_detail_dark_375.png`.

Reject and fix any overflow, clipped action, illegible status, inconsistent
filter width, missing assignee, or divergence from Institution table geometry.

- [ ] **Step 5: Format and analyze focused files**

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format apps/superadmin/lib/features/support apps/superadmin/test/features/support packages/coelo_ui_admin/lib/src/filter/coelo_admin_multi_select_filter.dart packages/coelo_ui_admin/test/filter/coelo_admin_multi_select_filter_test.dart
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze apps/superadmin/lib/features/support apps/superadmin/test/features/support packages/coelo_ui_admin/lib/src/filter/coelo_admin_multi_select_filter.dart packages/coelo_ui_admin/test/filter/coelo_admin_multi_select_filter_test.dart
```

Expected: no formatting changes after the final pass and no diagnostics.

- [ ] **Step 6: Run relevant suites**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/support test/app/router/support_routes_test.dart test/app/router/superadmin_router_test.dart test/app/shell/superadmin_shell_test.dart
```

Working directory: `apps/superadmin`.

Run the full `coelo_ui_admin` suite and repeat exactly the four catalog commands
and the two skill commands from Tasks 3 and 6.

Expected: all tests and validators pass.

- [ ] **Step 7: Restart or hot-reload localhost 8769**

Check the owner of port 8769 and the current Flutter web log. If hot reload is
not sufficient, stop only that verified process and start the Superadmin web
server on:

```text
http://127.0.0.1:8769/dev/support
```

Use the existing project `--dart-define` values from the running command or
repository launch configuration.

- [ ] **Step 8: Validate live UI**

Inspect Kanban, table, detail, filter popup, status menu and assignment menu at
1440 and 375. Confirm no runtime errors in the browser and Flutter logs.

- [ ] **Step 9: Commit goldens and final fixes**

```powershell
git diff --check
git add apps/superadmin/test/features/support/presentation/screens/support_page_golden_test.dart apps/superadmin/test/features/support/presentation/screens/goldens
git commit -m "test(superadmin): update support operations goldens"
```

Do not stage unrelated dirty files. Finish with `git status --short` and report
remaining user-owned changes separately.
