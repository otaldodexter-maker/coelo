import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_routine_repository.dart';

void main() {
  testWidgets('a duplicated section is named like every other copy in the product', (
    tester,
  ) async {
    const model = RoutineModel(
      id: 'model-with-sections',
      name: 'Chegada e acolhimento',
      description: 'Modelo com uma seção para duplicar.',
      version: 1,
      status: RoutineModelStatus.active,
      sections: [
        RoutineSection(
          id: 'section-1',
          name: 'Acolhimento',
          sortOrder: 0,
          fields: [],
        ),
      ],
      expectedVersion: 1,
      institutionId: 'institution-1',
      canManage: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineEditorPage(
          repository: FakeRoutineRepository(models: const [model], canManage: true),
          logout: unavailableSuperadminLogout,
          modelId: model.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final duplicate = find.byTooltip('Duplicar seção');
    await tester.ensureVisible(duplicate);
    await tester.pump();
    await tester.tap(duplicate);
    await tester.pumpAndSettle();

    expect(find.textContaining('Acolhimento (cópia)'), findsOneWidget);
    expect(find.textContaining('(copia)'), findsNothing);
  });
}
