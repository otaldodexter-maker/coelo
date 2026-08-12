import 'package:coelo_superadmin/features/daily_routine/domain/routine_contract.dart';
import 'package:coelo_superadmin/features/daily_routine/widgets/daily_routine_field_configuration_editor.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const field = RoutineField(
    id: 'status',
    label: 'Status do dia',
    kind: RoutineFieldKind.singleChoice,
    sortOrder: 0,
    isRequired: true,
    initialValue: 'calm',
    options: [
      RoutineFieldOption(id: 'calm', label: 'Tranquilo', sortOrder: 0),
      RoutineFieldOption(id: 'agitated', label: 'Agitado', sortOrder: 1),
    ],
  );

  for (final brightness in Brightness.values) {
    testWidgets('field editor ${brightness.name} follows the Coelo visual contract', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(768, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          darkTheme: CoeloTheme.dark,
          themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: DailyRoutineFieldConfigurationEditor(
                    field: field,
                    availableParents: const [],
                    enabled: true,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DailyRoutineFieldConfigurationEditor), findsOneWidget);
      expect(find.text('Status do dia'), findsWidgets);
      expect(find.text('Tranquilo'), findsWidgets);
      expect(find.text('Agitado'), findsWidgets);
      final context = tester.element(find.byType(DailyRoutineFieldConfigurationEditor));
      expect(Theme.of(context).brightness, brightness);
      expect(tester.takeException(), isNull);
    });
  }
}
