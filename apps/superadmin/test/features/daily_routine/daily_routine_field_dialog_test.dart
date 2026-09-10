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
  description: 'Modelo com um campo para configurar.',
  version: 1,
  status: RoutineModelStatus.active,
  sections: [
    RoutineSection(
      id: 'section-1',
      name: 'Acolhimento',
      sortOrder: 0,
      fields: [
        RoutineField(
          id: 'field-1',
          label: 'Como chegou',
          kind: RoutineFieldKind.number,
          sortOrder: 0,
          minimumValue: 1,
          maximumValue: 5,
        ),
      ],
    ),
  ],
  expectedVersion: 1,
  institutionId: 'institution-1',
  canManage: true,
);

Future<void> _openFieldDialog(WidgetTester tester) async {
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

  final edit = find.byTooltip('Editar campo').first;
  await tester.ensureVisible(edit);
  await tester.pump();
  await tester.tap(edit);
  await tester.pumpAndSettle();
  expect(find.text('Configurar campo'), findsOneWidget);
}

Future<void> _typeInDialog(WidgetTester tester, Key fieldKey, String value) async {
  final field = find.descendant(of: find.byKey(fieldKey), matching: find.byType(TextField));
  await tester.ensureVisible(field);
  await tester.pump();
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('saving the field dialog applies the new label', (tester) async {
    await _openFieldDialog(tester);

    await _typeInDialog(tester, const Key('daily-routine-field-label'), 'Como a criança chegou');
    await tester.tap(find.byKey(const Key('daily-routine-field-save')));
    await tester.pumpAndSettle();

    expect(find.text('Configurar campo'), findsNothing);
    expect(find.textContaining('Como a criança chegou'), findsWidgets);
  });

  testWidgets('an invalid range keeps the field dialog open and says why', (tester) async {
    await _openFieldDialog(tester);

    await _typeInDialog(tester, const Key('daily-routine-number-min'), '9');
    await tester.tap(find.byKey(const Key('daily-routine-field-save')));
    await tester.pumpAndSettle();

    expect(find.text('Configurar campo'), findsOneWidget);
    expect(find.text('O valor mínimo não pode superar o valor máximo.'), findsOneWidget);
  });

  testWidgets('cancelling the field dialog changes nothing', (tester) async {
    await _openFieldDialog(tester);

    await _typeInDialog(tester, const Key('daily-routine-field-label'), 'Rótulo descartado');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Configurar campo'), findsNothing);
    expect(find.textContaining('Rótulo descartado'), findsNothing);
  });
}
