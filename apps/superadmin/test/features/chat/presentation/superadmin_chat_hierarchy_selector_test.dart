import 'package:coelo_superadmin/features/chat/presentation/chat_fixtures.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_hierarchy_selector.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selects only the active hierarchy level with the bulk action', (tester) async {
    var selected = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 520,
            child: SuperadminChatHierarchySelector(
              options: superadminChatContextOptions,
              selectedIds: selected,
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Unidades'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecionar todos'));
    await tester.pump();

    expect(selected, {'cambui', 'jardins'});
    expect(selected, isNot(contains('centro-horizonte')));
    expect(selected, isNot(contains('instituto-aurora')));
  });

  testWidgets('offers activities and guardians as explicit hierarchy filters', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 520,
            child: SuperadminChatHierarchySelector(
              options: superadminChatContextOptions,
              selectedIds: const {},
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Responsáveis'), findsOne);
    await tester.tap(find.text('Atividades'));
    await tester.pumpAndSettle();
    expect(find.text('Atividade Natação'), findsOne);
    await tester.tap(find.text('Responsáveis'));
    await tester.pumpAndSettle();
    expect(find.text('Paula Souza'), findsOne);
    expect(find.text('Marina Alves'), findsNothing);
  });
}
