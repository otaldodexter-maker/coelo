import 'package:coelo_superadmin/features/chat/presentation/chat_models.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_hierarchy_selector.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('directory hierarchy selection works with isolated test data', (tester) async {
    await _pumpSelector(tester, initialSelection: {'centro-horizonte'});

    expect(find.byKey(const Key('superadmin-chat-hierarchy-selection-summary')), findsOneWidget);
    await tester.tap(find.byType(ChoiceChip).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-chat-hierarchy-select-visible')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('guardian filter uses explicit metadata rather than subtitle text', (tester) async {
    const options = [
      SuperadminChatContextOption(
        id: 'root',
        label: 'Directory root',
        kind: ChatContextKind.institution,
        children: [
          SuperadminChatContextOption(
            id: 'subtitle-only',
            label: 'Misleading text',
            kind: ChatContextKind.person,
            subtitle: 'Guardian',
          ),
          SuperadminChatContextOption(
            id: 'guardian-metadata',
            label: 'Authorized contact',
            kind: ChatContextKind.person,
            isGuardian: true,
          ),
        ],
      ),
    ];
    await _pumpSelector(tester, options: options);

    await tester.tap(find.byType(ChoiceChip).at(6));
    await tester.pumpAndSettle();

    expect(find.text('Authorized contact'), findsOneWidget);
    expect(find.text('Misleading text'), findsNothing);
  });
}

Future<void> _pumpSelector(
  WidgetTester tester, {
  List<SuperadminChatContextOption> options = _options,
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

const _options = [
  SuperadminChatContextOption(
    id: 'centro-horizonte',
    label: 'Centro Horizonte',
    kind: ChatContextKind.institution,
    children: [
      SuperadminChatContextOption(id: 'cambui', label: 'Unit Cambui', kind: ChatContextKind.unit),
      SuperadminChatContextOption(id: 'jardins', label: 'Unit Jardins', kind: ChatContextKind.unit),
    ],
  ),
];

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
