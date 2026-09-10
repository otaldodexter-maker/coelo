import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_routine_repository.dart';

RoutineLaunch _launch(RoutineLaunchStatus status) => RoutineLaunch(
  id: 'launch-1',
  applicationId: 'application-1',
  applicationRevisionId: 'application-revision-1',
  institutionId: 'institution-1',
  unitId: 'unit-1',
  groupId: 'group-1',
  authorMembershipId: 'membership-1',
  serviceDate: DateTime(2026, 8, 3),
  status: status,
  expectedVersion: 4,
);

Future<void> _open(WidgetTester tester, RoutineLaunch launch) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: DailyRoutineEditorPage(
        repository: FakeRoutineRepository(launches: [launch]),
        logout: unavailableSuperadminLogout,
        modelId: launch.id,
        entryType: RoutineEntryKind.launch,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('launch summary states the service date as a civil date', (tester) async {
    await _open(tester, _launch(RoutineLaunchStatus.draft));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('daily-routine-launch-editor')), findsOneWidget);
    expect(find.text('Data: 03/08/2026'), findsOneWidget);
    expect(find.textContaining('00:00:00'), findsNothing);
  });

  testWidgets('launch summary states the status in the product language', (tester) async {
    await _open(tester, _launch(RoutineLaunchStatus.published));

    expect(find.text('Status: Publicado'), findsOneWidget);
    expect(find.textContaining('published'), findsNothing);
  });

  testWidgets('every launch status reaches its own label', (tester) async {
    const expected = {
      RoutineLaunchStatus.draft: 'Rascunho',
      RoutineLaunchStatus.published: 'Publicado',
      RoutineLaunchStatus.corrected: 'Corrigido',
      RoutineLaunchStatus.cancelled: 'Cancelado',
    };
    for (final entry in expected.entries) {
      await _open(tester, _launch(entry.key));
      expect(find.text('Status: ${entry.value}'), findsOneWidget, reason: entry.key.name);
    }
  });
}
