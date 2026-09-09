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
  description: 'Modelo carregado para edição.',
  version: 1,
  status: RoutineModelStatus.active,
  sections: [],
  expectedVersion: 1,
  institutionId: 'institution-1',
  canManage: true,
);

Future<void> _open(WidgetTester tester, FakeRoutineRepository repository) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: DailyRoutineEditorPage(
        repository: repository,
        logout: unavailableSuperadminLogout,
        modelId: _model.id,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  // A previous failure leaves a SnackBar over the footer; let it expire first.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  final save = find.byKey(const Key('daily-routine-save'));
  await tester.ensureVisible(save);
  await tester.pump();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Future<void> _typeName(WidgetTester tester, String value) async {
  await tester.enterText(find.byKey(const Key('daily-routine-name')), value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('retrying a failed save repeats the same intent', (tester) async {
    final repository = FakeRoutineRepository(models: const [_model], canManage: true)
      ..failSaveModelTimes = 1;
    await _open(tester, repository);

    await _save(tester);
    await _save(tester);

    expect(repository.saveModelRequestIds, hasLength(2));
    expect(
      repository.saveModelRequestIds.first,
      repository.saveModelRequestIds.last,
      reason: 'a retry of the same draft is the same intent, not a new one',
    );
  });

  testWidgets('editing the draft after a failure starts a new intent', (tester) async {
    final repository = FakeRoutineRepository(models: const [_model], canManage: true)
      ..failSaveModelTimes = 1;
    await _open(tester, repository);

    await _save(tester);
    await _typeName(tester, 'Chegada e acolhimento revisado');
    await _save(tester);

    expect(repository.saveModelRequestIds, hasLength(2));
    expect(
      repository.saveModelRequestIds.first,
      isNot(repository.saveModelRequestIds.last),
      reason: 'a changed draft is a different intent',
    );
  });
}
