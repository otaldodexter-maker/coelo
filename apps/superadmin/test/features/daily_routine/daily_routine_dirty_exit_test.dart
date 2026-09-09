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
  description: 'Modelo carregado para edicao.',
  version: 1,
  status: RoutineModelStatus.active,
  sections: [],
  expectedVersion: 1,
  institutionId: 'institution-1',
  canManage: true,
);

final _home = GlobalKey();

Future<void> _openEditor(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(key: _home, body: const SizedBox.shrink()),
    ),
  );
  final navigator = Navigator.of(_home.currentContext!);
  unawaited(
    navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => DailyRoutineEditorPage(
          repository: FakeRoutineRepository(models: const [_model], canManage: true),
          logout: unavailableSuperadminLogout,
          modelId: _model.id,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void unawaited(Future<void> future) {}

Future<void> _typeName(WidgetTester tester, String value) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('daily-routine-name')),
      matching: find.byType(TextField),
    ),
    value,
  );
  await tester.pumpAndSettle();
}

Future<void> _requestExit(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('leaving an untouched routine editor needs no confirmation', (tester) async {
    await _openEditor(tester);
    expect(find.byKey(const Key('daily-routine-model-editor')), findsOneWidget);

    await _requestExit(tester);

    expect(find.byKey(const Key('daily-routine-exit-dialog')), findsNothing);
    expect(find.byKey(const Key('daily-routine-model-editor')), findsNothing);
  });

  testWidgets('an edited routine asks before discarding the draft', (tester) async {
    await _openEditor(tester);
    await _typeName(tester, 'Chegada e acolhimento revisado');

    await _requestExit(tester);

    expect(find.byKey(const Key('daily-routine-exit-dialog')), findsOneWidget);
    expect(find.text('Sair sem salvar?'), findsOneWidget);

    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-routine-exit-dialog')), findsNothing);
    expect(find.byKey(const Key('daily-routine-model-editor')), findsOneWidget);
  });

  testWidgets('confirming the discard leaves the routine editor', (tester) async {
    await _openEditor(tester);
    await _typeName(tester, 'Chegada e acolhimento revisado');
    await _requestExit(tester);

    await tester.tap(find.text('Sair sem salvar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-routine-model-editor')), findsNothing);
  });
}
