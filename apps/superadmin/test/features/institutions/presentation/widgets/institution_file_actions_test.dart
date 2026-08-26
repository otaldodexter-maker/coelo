import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/institutions/presentation/widgets/institution_file_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final compact in [false, true]) {
    testWidgets(
      'does not expose institution file actions without a production gateway ($compact)',
      (tester) async {
        final controller = SuperadminActivityController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InstitutionFileActions(activityController: controller, compact: compact),
            ),
          ),
        );

        expect(find.byKey(const Key('institution-files-action')), findsNothing);
        expect(find.text('Arquivos'), findsNothing);
        expect(find.text('Importar'), findsNothing);
        expect(find.textContaining('24 linhas'), findsNothing);
        expect(find.textContaining('2 linhas'), findsNothing);
        expect(controller.activities, isEmpty);
      },
    );
  }
}
