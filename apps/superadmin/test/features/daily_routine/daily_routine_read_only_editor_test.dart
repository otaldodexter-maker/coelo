import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_routine_repository.dart';

void main() {
  testWidgets('read-only model renders without an empty action footer', (tester) async {
    const model = RoutineModel(
      id: 'read-only-model',
      name: 'Modelo Coelo de referência',
      description: 'Disponível somente para consulta neste escopo.',
      version: 7,
      status: RoutineModelStatus.active,
      sections: [],
      expectedVersion: 7,
      institutionId: 'instituto-horizonte',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineEditorPage(
          repository: FakeRoutineRepository(models: const [model]),
          logout: unavailableSuperadminLogout,
          modelId: model.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('daily-routine-model-editor')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-form-footer')), findsNothing);
    expect(find.byKey(const Key('daily-routine-save')), findsNothing);
  });
}
