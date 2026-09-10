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
  description: 'Modelo com identificação, origem e seções para medir a largura.',
  version: 3,
  status: RoutineModelStatus.active,
  sections: [
    RoutineSection(
      id: 'section-1',
      name: 'Acolhimento e primeiros cuidados do turno',
      sortOrder: 0,
      fields: [
        RoutineField(
          id: 'field-1',
          label: 'Como a criança chegou hoje',
          kind: RoutineFieldKind.shortText,
          sortOrder: 0,
        ),
      ],
    ),
  ],
  expectedVersion: 3,
  institutionId: 'institution-1',
  canManage: true,
);

RoutineLaunch _launch() => RoutineLaunch(
  id: 'launch-1',
  applicationId: 'application-1',
  applicationRevisionId: 'application-revision-1',
  institutionId: 'institution-1',
  unitId: 'unit-1',
  groupId: 'group-1',
  authorMembershipId: 'membership-1',
  serviceDate: DateTime(2026, 8, 3),
  status: RoutineLaunchStatus.published,
  expectedVersion: 4,
);

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  required double width,
  required double textScale,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in const [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('the routine editor holds $width at 200 percent text', (tester) async {
      await _pump(
        tester,
        DailyRoutineEditorPage(
          repository: FakeRoutineRepository(models: const [_model], canManage: true),
          logout: unavailableSuperadminLogout,
          modelId: _model.id,
        ),
        width: width,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('daily-routine-model-editor')), findsOneWidget);
      expect(find.byKey(const Key('daily-routine-save')), findsOneWidget);
    });
  }

  for (final width in const [375.0, 1440.0]) {
    testWidgets('the launch summary holds $width at 200 percent text', (tester) async {
      await _pump(
        tester,
        DailyRoutineEditorPage(
          repository: FakeRoutineRepository(launches: [_launch()]),
          logout: unavailableSuperadminLogout,
          modelId: 'launch-1',
          entryType: RoutineEntryKind.launch,
        ),
        width: width,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('daily-routine-launch-editor')), findsOneWidget);
      expect(find.text('Status: Publicado'), findsOneWidget);
    });
  }
}
