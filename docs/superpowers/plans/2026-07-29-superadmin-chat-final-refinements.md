---
title: "Final Refinements Of The Local Superadmin Institutional Chat"
source: "docs/superpowers/specs/2026-07-28-superadmin-chat-local-redesign-design.md"
status: "approved-for-implementation"
generated_at: "2026-07-29"
---

# Superadmin Institutional Chat Final Refinements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the approved local Superadmin chat refinements for hierarchy selection, conversation organization, menus, launcher, contextual metadata, and responsive message bubbles.

**Architecture:** Keep all behavior in `apps/superadmin/lib/features/chat/presentation/`, backed by immutable fixture objects and controller-owned in-memory state. Extend the existing private hierarchy selector and dialog frame; do not add a public package API, backend call, persistence, or production authorization.

**Tech Stack:** Flutter, Dart, `coelo_tokens`, existing `coelo_ui_core` controls, Flutter widget/golden tests.

## Global Constraints

- The experience remains a local demonstration: no backend, RLS, media upload, audit, notification, entitlement, or real delivery.
- Use `Todos | Institucional | Pessoas`; use `Grupo (Turma)`, never `Grupo/Turma`.
- Chips filter the hierarchy view and never select recipients.
- Child selection resolves only simulated authorized guardians; a child is a conversation context, not a recipient.
- New-message child selections create one thread per child; only group creation can combine several children into one collective thread.
- Manual groups are shown in `Grupos` and are not pinned automatically.
- Pin order and empty/red/yellow/green flags are personal local state and independent.
- Popup, menu, hover, focus, close, destructive, footer, spacing, and surface treatment follow the private Coelo UI interaction/form contracts already approved for this prototype.
- Preserve the outlined and rounded main workspace surface in light and dark themes.
- Do not promote, restore, or change any public Coelo UI chat API, catalog entry, or token in this phase.

---

### Task 1: Local Conversation State

**Files:**
- Modify: `apps/superadmin/lib/features/chat/presentation/chat_models.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/chat_controller.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/chat_fixtures.dart`
- Test: `apps/superadmin/test/features/chat/presentation/chat_controller_test.dart`

**Interfaces:**
- Produces: `ChatContextKind.child`, `ChatFlag`, `pinnedConversations`, `groupConversations`, `regularConversations`, `flagFor`, `setFlag`, `movePinned`, `createGroup`, and child-aware `startConversations`.
- `movePinned(String id, int newIndex)` reorders only the current pinned list.
- `setFlag(String id, ChatFlag flag)` never changes pin or conversation order.
- `startConversations(Set<String> contextIds, ...)` creates a separate local
  thread for every selected child and a single thread for any permitted
  non-child selection. `ChatContextKind.child` identifies the context of that
  thread; its `members` are the authorized simulated guardians, so the child is
  never modeled as a recipient.

- [ ] **Step 1: Write failing controller tests**

```dart
test('manual group starts in Groups and is not pinned', () {
  final controller = SuperadminChatController(superadminChatFixtures);
  controller.createGroup('Equipe', {'aurora', 'marina'});
  expect(controller.groupConversations.single.title, 'Equipe');
  expect(controller.pinnedIds, isNot(contains(controller.groupConversations.single.id)));
});

test('reorders only pinned conversations and keeps flag independent', () {
  final controller = SuperadminChatController(superadminChatFixtures);
  controller.togglePinned('girassol');
  controller.togglePinned('cambui');
  controller.movePinned('cambui', 0);
  controller.setFlag('girassol', ChatFlag.red);
  expect(controller.pinnedConversations.map((item) => item.id), ['cambui', 'girassol']);
  expect(controller.flagFor('girassol'), ChatFlag.red);
});

test('starts one guardian thread per selected child', () {
  final controller = SuperadminChatController(superadminChatFixtures);
  controller.startConversations(
    contextIds: {'child-lia', 'child-theo'},
    body: 'Olá',
    attachments: const {},
  );
  expect(controller.conversations.where((item) => item.kind == ChatContextKind.child), hasLength(2));
  expect(controller.conversations.where((item) => item.kind == ChatContextKind.child).every(
    (item) => item.messages.single.author == 'Superadmin',
  ), isTrue);
});
```

- [ ] **Step 2: Run the controller test and verify RED**

Run:
`C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/chat/presentation/chat_controller_test.dart`

Expected: compilation/test failures for the missing enum and controller APIs, plus the existing group test proving the old auto-pin behavior.

- [ ] **Step 3: Implement minimal controller-owned state**

```dart
enum ChatFlag { none, red, yellow, green }

final List<String> _pinnedOrder = [];
final Map<String, ChatFlag> _flags = {};

ChatFlag flagFor(String id) => _flags[id] ?? ChatFlag.none;

void setFlag(String id, ChatFlag flag) {
  if (!_conversations.any((item) => item.id == id)) return;
  flag == ChatFlag.none ? _flags.remove(id) : _flags[id] = flag;
  notifyListeners();
}
```

Remove the `_pinnedIds.add(id)` side effect from `createGroup`, derive the three
sections without duplication, and add child fixtures with guardian membership
and actual author names in their messages. Add local group membership state:
the Superadmin creator is automatically an accepted admin; other invited
members may be pending; admins can promote; common members can leave; the last
admin cannot leave before promoting another member; and an admin can
promote-and-leave or delete the group. Cover creator/admin, pending invite,
accept, promote, leave, last-admin guard, promote-and-leave, and delete with
controller tests.

- [ ] **Step 4: Run controller tests and verify GREEN**

Run the command from Step 2.

Expected: all controller tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/superadmin/lib/features/chat/presentation/chat_models.dart apps/superadmin/lib/features/chat/presentation/chat_controller.dart apps/superadmin/lib/features/chat/presentation/chat_fixtures.dart apps/superadmin/test/features/chat/presentation/chat_controller_test.dart
git commit -m "feat(superadmin): refine local chat state"
```

### Task 2: Hierarchy Selection And Grouped Review

**Files:**
- Modify: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_hierarchy_selector.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_flow_dialog.dart`
- Test: `apps/superadmin/test/features/chat/presentation/superadmin_chat_hierarchy_selector_test.dart`
- Test: `apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart`

**Interfaces:**
- Consumes: `ChatContextKind.child` and fixture child nodes from Task 1.
- Produces: category-as-view-filter behavior, contextual bulk labels, tri-state parents, persistent per-category selection summary, ancestor-preserving search, and grouped review ordered by hierarchy.

- [ ] **Step 1: Write failing hierarchy tests**

```dart
testWidgets('category chips filter only and contextual action selects visible kind', (tester) async {
  final selected = <String>{};
  await pumpSelector(tester, selected: selected);
  await tester.tap(find.text('Unidades'));
  await tester.pump();
  expect(selected, isEmpty);
  expect(find.text('Selecionar todas as unidades'), findsOneWidget);
});

testWidgets('children remain contexts and selected summary survives view changes', (tester) async {
  final selected = <String>{};
  await pumpSelector(tester, selected: selected);
  await tester.tap(find.text('Crianças'));
  await tester.pump();
  await tester.tap(find.text('Lia'));
  await tester.pump();
  await tester.tap(find.text('Instituições'));
  await tester.pump();
  expect(find.textContaining('1 criança'), findsOneWidget);
});
```

Add a page test asserting review section headings appear in the exact order:
`Instituições`, `Unidades`, `Grupos`, `Atividades`, `Pessoas`, `Responsáveis`, `Crianças`.

- [ ] **Step 2: Run focused tests and verify RED**

Run:
`C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/chat/presentation/superadmin_chat_hierarchy_selector_test.dart test/features/chat/presentation/superadmin_chat_page_test.dart`

Expected: failures for missing child filter, contextual copy, persistent summary, or grouped review.

- [ ] **Step 3: Implement the shared private selector**

Use `ChatContextKind? _kind` strictly as a view filter. Compute the bulk label from the active category:

```dart
String _bulkLabel(ChatContextKind? kind, bool guardiansOnly) {
  if (guardiansOnly) return 'Selecionar todos os responsáveis';
  return switch (kind) {
    ChatContextKind.institution => 'Selecionar todas as instituições',
    ChatContextKind.unit => 'Selecionar todas as unidades',
    ChatContextKind.group => 'Selecionar todos os grupos',
    ChatContextKind.activity => 'Selecionar todas as atividades',
    ChatContextKind.person => 'Selecionar todas as pessoas',
    ChatContextKind.child => 'Selecionar todas as crianças',
    _ => 'Selecionar todos',
  };
}
```

Keep selected IDs outside the filtered tree, derive partial parent state from
all descendants, and render a compact `Wrap` summary by selected kind. Use
explicit `isGuardian`/`guardianIds` metadata from Task 1; never infer responsible
people from a substring in `subtitle`. The test host must use a
`StatefulBuilder` that writes `onChanged` values back to `selectedIds`, and the
bulk button and summary must have stable keys
`superadmin-chat-hierarchy-select-visible` and
`superadmin-chat-hierarchy-selection-summary`. Preserve each selected item's
structured path in the review view-model, then render a flat list only inside
each hierarchy section.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the command from Step 2.

Expected: both files pass with no overflow/error output.

- [ ] **Step 5: Commit**

```powershell
git add apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_hierarchy_selector.dart apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_flow_dialog.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_hierarchy_selector_test.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart
git commit -m "feat(superadmin): improve chat hierarchy selection"
```

### Task 3: Inbox Sections, Menus, Flags And Accessible Ordering

**Files:**
- Modify: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_inbox.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_surface_primitives.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart`
- Test: `apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart`

**Interfaces:**
- Consumes: section lists, pin-order, and flag APIs from Task 1; existing group/new-message dialog entry points.
- Produces: `Fixados`, `Grupos`, and audience sections; exact contextual menu; orange focus/hover; personal flag chooser; pointer drag and keyboard reordering.

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('conversation menu exposes group actions and pin for an academic context', (tester) async {
  await pumpChat(tester);
  await tester.tap(find.byTooltip('Ações de Turma Girassol'));
  await tester.pumpAndSettle();
  expect(find.text('Criar grupo com…'), findsOneWidget);
  expect(find.text('Convidar para grupo'), findsOneWidget);
  expect(find.text('Fixar'), findsOneWidget);
  expect(find.text('Excluir conversa'), findsNothing);
});

testWidgets('new groups stay in Groups and flags do not pin them', (tester) async {
  await createReviewedGroup(tester, name: 'Equipe');
  expect(find.text('Grupos'), findsOneWidget);
  expect(find.text('Fixados'), findsNothing);
});

testWidgets('keyboard reorder changes pinned visual order', (tester) async {
  await pumpChatWithTwoPins(tester);
  await tester.tap(find.byKey(const Key('superadmin-chat-pinned-cambui')));
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
  expect(pinnedTitles(tester), ['Unidade Cambuí', 'Turma Girassol']);
});
```

- [ ] **Step 2: Run the page test and verify RED**

Run:
`C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/chat/presentation/superadmin_chat_page_test.dart`

Expected: missing menu actions/sections/flag/reorder behaviors.

- [ ] **Step 3: Implement inbox behavior**

Render sections in order: `Fixados`, `Grupos`, then the current audience. Give each row a `Focus`/`MouseRegion` state using the same orange `primaryContainer`, rounded `CoeloRadius.md`, and existing spacing. Use `ReorderableListView` behavior only for pinned rows, and expose keyboard actions mapped to:

```dart
SingleActivator(LogicalKeyboardKey.arrowUp, control: true)
SingleActivator(LogicalKeyboardKey.arrowDown, control: true)
```

The menu order is exact. `Criar grupo com…` opens the existing group flow with
current participants preselected; `Convidar para grupo` is disabled or omitted
when no eligible manual group exists and otherwise lists only groups where the
local current user can invite. `Excluir conversa`/`Excluir grupo` is present
only for locally removable manual conversations/groups, never for the
read-only academic `Turma Girassol` fixture. Add separate REDs for pointer
reorder, Ctrl+Arrow keyboard reorder, and every personal flag option using
stable keys. Add a flag submenu/chooser with none, red, yellow, and green
semantic labels. The destructive confirmation copy is:

`O grupo e todo o histórico desta demonstração serão excluídos. Esta ação não pode ser desfeita.`

- [ ] **Step 4: Run the page test and verify GREEN**

Run the command from Step 2.

Expected: all page tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_inbox.dart apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_surface_primitives.dart apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart
git commit -m "feat(superadmin): organize chat inbox actions"
```

### Task 4: Launcher, Message Bubbles And Context Metadata

**Files:**
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_launcher.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_message_bubble.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_context_panel.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/chat_controller.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_hierarchy_selector.dart`
- Modify: `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_flow_dialog.dart`
- Test: `apps/superadmin/test/features/chat/presentation/superadmin_chat_launcher_test.dart`
- Test: `apps/superadmin/test/features/chat/presentation/superadmin_chat_context_panel_test.dart`
- Test: `apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart`

**Interfaces:**
- Consumes: existing new-message flow and model nomenclature.
- Produces: canonical bottom launcher spacing, compact `Nova conversa`, content-sized responsive bubbles, bold labels/normal values for `Tipo` and `Plano`, and `Grupo (Turma)` copy.

- [ ] **Step 1: Write failing visual-behavior tests**

```dart
testWidgets('compact inbox exposes Nova conversa beside the facets', (tester) async {
  await pumpOpenLauncher(tester);
  expect(find.text('Nova conversa'), findsOneWidget);
});

testWidgets('short bubbles shrink and long unbroken content stays inside viewport', (tester) async {
  await pumpMessages(tester);
  final short = tester.getRect(find.byKey(const Key('superadmin-chat-message-m1')));
  final long = tester.getRect(find.byKey(const Key('superadmin-chat-message-m2')));
  final history = tester.getRect(find.byKey(const Key('superadmin-chat-thread-history')));
  expect(short.width, lessThan(long.width));
  expect(long.width, lessThanOrEqualTo(CoeloSize.touchMin * 11));
  expect(history.contains(long.topLeft) && history.contains(long.bottomRight), isTrue);
  expect(tester.takeException(), isNull);
});

testWidgets('context uses approved label weight and group terminology', (tester) async {
  await pumpContext(tester, conversationId: 'girassol');
  expect(find.text('Grupo (Turma)'), findsOneWidget);
  final type = tester.widget<Text>(find.byKey(const Key('superadmin-chat-context-type')));
  final spans = (type.textSpan! as TextSpan).children!.cast<TextSpan>();
  expect(spans.first.text, 'Tipo: ');
  expect(spans.first.style?.fontWeight, FontWeight.w600);
  expect(spans.last.style?.fontWeight, isNot(FontWeight.w600));
});
```

- [ ] **Step 2: Run launcher/context/page tests and verify RED**

Run:
`C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/chat/presentation/superadmin_chat_launcher_test.dart test/features/chat/presentation/superadmin_chat_context_panel_test.dart test/features/chat/presentation/superadmin_chat_page_test.dart`

Expected: missing launcher action/copy and typography/geometry assertions.

- [ ] **Step 3: Implement the approved refinements**

Change the shell host anchor from
`CoeloSize.touchMin * 2 + CoeloSpacing.space5` (116 px) to the approved
prototype viewport spacing `CoeloSpacing.space4` (16 px), matching the existing
golden stage. Keep the full launcher pill unchanged otherwise. Add only `Nova
conversa` to compact inbox, reuse the existing new-message dialog, and use
`Wrap`/constraint-aware composition so facets plus the action do not overflow
at 375/768 or 200% text.

For bubbles, keep `Align` and use a responsive maximum from local constraints:

```dart
final maxBubbleWidth = constraints.maxWidth.clamp(
  CoeloSize.touchMin * 4,
  CoeloSize.touchMin * 11,
);
```

Allow wrapping of long content without giving short messages a fixed width. In
context metadata, render the label in semibold and value in normal body weight.
Replace all visible `Grupo/Turma` text in the controller, hierarchy selector,
flow dialog, and context panel with `Grupo (Turma)`.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the command from Step 2.

Expected: all focused tests pass with no Flutter assertion or overflow.

- [ ] **Step 5: Commit**

```powershell
git add apps/superadmin/lib/app/shell/superadmin_shell.dart apps/superadmin/lib/features/chat/presentation/chat_controller.dart apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_launcher.dart apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_message_bubble.dart apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_context_panel.dart apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_hierarchy_selector.dart apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_flow_dialog.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_launcher_test.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_context_panel_test.dart apps/superadmin/test/features/chat/presentation/superadmin_chat_page_test.dart
git commit -m "fix(superadmin): polish chat launcher and content"
```

### Task 5: Responsive And Visual Verification

**Files:**
- Modify: `apps/superadmin/test/features/chat/presentation/superadmin_chat_page_golden_test.dart`
- Modify: `apps/superadmin/test/features/chat/presentation/superadmin_chat_launcher_golden_test.dart`
- Modify: `apps/superadmin/test/features/chat/presentation/goldens/*.png`
- Modify: `docs/knowledge/team/superadmin-chat-groups.md`

**Interfaces:**
- Consumes: completed Tasks 1–4.
- Produces: verified light/dark layouts at 375, 768, 1024, and 1440; verified launcher states; clean static analysis; explicit knowledge no-op or validated projection.

- [ ] **Step 1: Run all focused chat tests before updating goldens**

Run:
`C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/chat`

Expected: only golden mismatches may fail; no behavior, overflow, semantics, or focus failures.

- [ ] **Step 2: Update explicit goldens**

Run:
`C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test --update-goldens test/features/chat/presentation/superadmin_chat_page_golden_test.dart test/features/chat/presentation/superadmin_chat_launcher_golden_test.dart`

Expected: the named light/dark golden files update.

Add launcher states at 375, 768, 1024, and 1440 where they are not currently
covered, including compact dark, open inbox/thread, and dark hover/focus.

- [ ] **Step 3: Inspect every generated image**

Inspect all updated golden PNGs at original resolution. Confirm main outline/clip, orange hover/focus, compact launcher anchoring, three-section inbox, content-sized bubbles, context-card contrast, modal spacing, and no clipped 200% text.

- [ ] **Step 4: Run full focused verification**

Run:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed lib/features/chat test/features/chat
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart test test/features/chat
```

Expected: formatting, analysis, and all focused tests pass without warnings.

- [ ] **Step 5: Repair and run the Coelo Knowledge gate**

Remove the stale claim that `Institucional` is globally official while OQ-030
is open, cite every canonical source used by the projection, and update its
OQ-029 gate to include invitation/acceptance, group administration,
guardian-from-child derivation, and notifications. Do not project the local
visual refinements as durable knowledge. Run both project knowledge validators.

- [ ] **Step 6: Commit final verification artifacts**

```powershell
git add apps/superadmin/test/features/chat docs/knowledge
git commit -m "test(superadmin): verify final chat refinements"
```
