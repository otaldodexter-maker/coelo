import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/institutions/presentation/widgets/institution_file_actions.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final compact in [false, true]) {
    testWidgets('keeps institution file actions visible with honest unavailability ($compact)', (
      tester,
    ) async {
      final controller = SuperadminActivityController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: Scaffold(
            body: InstitutionFileActions(activityController: controller, compact: compact),
          ),
        ),
      );

      expect(find.byKey(const Key('coelo-admin-files-action')), findsOneWidget);
      await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
      await tester.pumpAndSettle();
      expect(find.text('Importar'), findsOneWidget);
      expect(find.text('Exportar CSV'), findsOneWidget);
      expect(find.text('Exportar XLSX'), findsOneWidget);
      await tester.tap(find.text('Exportar CSV'));
      await tester.pumpAndSettle();
      expect(find.text('Indisponível nesta etapa'), findsOneWidget);
      expect(find.textContaining('24 linhas'), findsNothing);
      expect(find.textContaining('2 linhas'), findsNothing);
      expect(controller.activities, isEmpty);
    });
  }
}
