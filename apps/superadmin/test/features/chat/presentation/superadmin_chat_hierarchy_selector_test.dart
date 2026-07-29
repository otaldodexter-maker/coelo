import 'package:coelo_superadmin/features/chat/presentation/chat_fixtures.dart';
import 'package:coelo_superadmin/features/chat/presentation/chat_models.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_hierarchy_selector.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('category chips filter the view without changing retained selections', (
    tester,
  ) async {
    await _pumpSelector(tester, initialSelection: {'centro-horizonte'});

    expect(find.textContaining('1 instituição'), findsOneWidget);
    await tester.tap(find.text('Unidades'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 instituição'), findsOneWidget);
    expect(find.text('Selecionar todas as unidades'), findsOneWidget);
    await tester.tap(find.byKey(const Key('superadmin-chat-hierarchy-select-visible')));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 instituição'), findsOneWidget);
    expect(find.textContaining('2 unidades'), findsOneWidget);
  });

  testWidgets('child selection keeps mixed branches and reports tri-state from all descendants', (
    tester,
  ) async {
    await _pumpSelector(tester);

    await tester.tap(find.text('Crianças'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(CheckboxListTile, 'Lia'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Lia'));
    await tester.pumpAndSettle();

    final guardian = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Paula Souza'),
    );
    expect(guardian.value, isNull);
    expect(find.byKey(const Key('superadmin-chat-hierarchy-selection-summary')), findsOneWidget);
    expect(find.textContaining('1 criança'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('superadmin-chat-hierarchy-search')), 'Aurora');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Instituições'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 criança'), findsOneWidget);
  });

  testWidgets('guardian filter uses explicit metadata instead of subtitle text', (tester) async {
    const options = [
      SuperadminChatContextOption(
        id: 'metadata-root',
        label: 'Instituição de teste',
        kind: ChatContextKind.institution,
        children: [
          SuperadminChatContextOption(
            id: 'subtitle-only',
            label: 'Texto enganoso',
            kind: ChatContextKind.person,
            subtitle: 'Responsável',
          ),
          SuperadminChatContextOption(
            id: 'guardian-metadata',
            label: 'Contato autorizado',
            kind: ChatContextKind.person,
            isGuardian: true,
          ),
        ],
      ),
    ];
    await _pumpSelector(tester, options: options);

    await tester.tap(find.text('Responsáveis'));
    await tester.pumpAndSettle();

    expect(find.text('Contato autorizado'), findsOneWidget);
    expect(find.text('Texto enganoso'), findsNothing);
  });
}

Future<void> _pumpSelector(
  WidgetTester tester, {
  List<SuperadminChatContextOption> options = superadminChatContextOptions,
  Set<String> initialSelection = const {},
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 520,
            child: _SelectorHarness(options: options, initialSelection: initialSelection),
          ),
        ),
      ),
    ),
  );
}

final class _SelectorHarness extends StatefulWidget {
  const _SelectorHarness({required this.options, required this.initialSelection});

  final List<SuperadminChatContextOption> options;
  final Set<String> initialSelection;

  @override
  State<_SelectorHarness> createState() => _SelectorHarnessState();
}

final class _SelectorHarnessState extends State<_SelectorHarness> {
  late Set<String> _selected = Set<String>.of(widget.initialSelection);

  @override
  Widget build(BuildContext context) {
    return SuperadminChatHierarchySelector(
      options: widget.options,
      selectedIds: _selected,
      onChanged: (value) => setState(() => _selected = value),
    );
  }
}
