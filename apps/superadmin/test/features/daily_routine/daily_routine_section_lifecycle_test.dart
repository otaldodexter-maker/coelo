import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_routine_repository.dart';

const _model = RoutineModel(
  id: 'model-1',
  name: 'Chegada e acolhimento',
  description: 'Modelo com duas seções.',
  version: 1,
  status: RoutineModelStatus.active,
  sections: [
    RoutineSection(id: 'section-1', name: 'Acolhimento', sortOrder: 0, fields: []),
    RoutineSection(id: 'section-2', name: 'Alimentação', sortOrder: 1, fields: []),
  ],
  expectedVersion: 1,
  institutionId: 'institution-1',
  canManage: true,
);

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: DailyRoutineEditorPage(
        repository: FakeRoutineRepository(models: const [_model], canManage: true),
        logout: unavailableSuperadminLogout,
        modelId: _model.id,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapByTooltip(WidgetTester tester, String tooltip, {int index = 0}) async {
  final action = find.byTooltip(tooltip).at(index);
  await tester.ensureVisible(action);
  await tester.pump();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('removing a section drops it and renumbers the rest', (tester) async {
    await _open(tester);
    expect(find.text('1. Acolhimento'), findsOneWidget);
    expect(find.text('2. Alimentação'), findsOneWidget);

    await _tapByTooltip(tester, 'Remover seção');

    expect(find.textContaining('Acolhimento'), findsNothing);
    expect(
      find.text('1. Alimentação'),
      findsOneWidget,
      reason: 'the surviving section becomes the first one',
    );
  });

  testWidgets('removing a section takes no confirmation today', (tester) async {
    await _open(tester);

    await _tapByTooltip(tester, 'Remover seção');

    // Pinned as current behaviour, not endorsed: the destructive action applies
    // straight away. A confirmation is a UX decision, raised with the owner.
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('1. Alimentação'), findsOneWidget);
  });

  testWidgets('adding a section appends an empty one to the draft', (tester) async {
    await _open(tester);

    final add = find.byKey(const Key('daily-routine-add-section'));
    await tester.ensureVisible(add);
    await tester.pump();
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(find.textContaining('3. '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
