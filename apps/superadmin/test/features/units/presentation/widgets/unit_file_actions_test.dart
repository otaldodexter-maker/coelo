import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/units/presentation/widgets/unit_file_actions.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('names the current unit view in the export preview', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: UnitFileActions(activityController: controller, viewLabel: 'Por grupos'),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit-files-export-csv')));
    await tester.pump();

    expect(controller.activities.single.subject, 'Unidades · Por grupos');
    expect(controller.activities.single.fileName, 'unidades-por-grupos.csv');
  });
}
