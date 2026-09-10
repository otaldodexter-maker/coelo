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
  description: 'Modelo com uma seção para renomear.',
  version: 1,
  status: RoutineModelStatus.active,
  sections: [
    RoutineSection(id: 'section-1', name: 'Acolhimento', sortOrder: 0, fields: []),
  ],
  expectedVersion: 1,
  institutionId: 'institution-1',
  canManage: true,
);

// The ordered editor numbers each section, so the rendered name is "1. <name>".
const _originalName = '1. Acolhimento';

Future<void> _openRenameDialog(WidgetTester tester) async {
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
  expect(find.text(_originalName), findsOneWidget);

  final edit = find.byTooltip('Editar seção').first;
  await tester.ensureVisible(edit);
  await tester.pump();
  await tester.tap(edit);
  await tester.pumpAndSettle();
  expect(find.text('Editar seção'), findsOneWidget);
}

/// The dialog field is the only one seeded with the current section name.
Finder _dialogField() => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.controller?.text == 'Acolhimento',
);

/// The page footer also says "Salvar"; the dialog action is the later one.
Finder _dialogSave() => find.widgetWithText(FilledButton, 'Salvar').last;

/// The editor is a ListView: bring the section row back into the built range
/// before reading it, otherwise the assertion measures nothing.
Future<void> _revealSection(WidgetTester tester) async {
  await tester.ensureVisible(find.byTooltip('Editar seção').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renaming a section applies the new name', (tester) async {
    await _openRenameDialog(tester);

    await tester.enterText(_dialogField(), 'Acolhimento e chegada');
    await tester.tap(_dialogSave());
    await tester.pumpAndSettle();
    await _revealSection(tester);

    expect(find.text('1. Acolhimento e chegada'), findsOneWidget);
    expect(find.text(_originalName), findsNothing);
  });

  testWidgets('cancelling the rename keeps the previous name', (tester) async {
    await _openRenameDialog(tester);

    await tester.enterText(_dialogField(), 'Nome descartado');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
    await tester.pumpAndSettle();
    await _revealSection(tester);

    expect(find.text('1. Nome descartado'), findsNothing);
    expect(find.text(_originalName), findsOneWidget);
  });

  testWidgets('a blank name never replaces the section name', (tester) async {
    await _openRenameDialog(tester);

    await tester.enterText(_dialogField(), '   ');
    await tester.tap(_dialogSave());
    await tester.pumpAndSettle();
    await _revealSection(tester);

    expect(find.text(_originalName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
