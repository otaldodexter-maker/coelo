import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/data/demo_health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_controller.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_plan_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lists medication plans as a sibling directory', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = HealthCareController(DemoHealthCareRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthMedicationPlanDirectoryPage(
          controller: controller,
          logout: unavailableSuperadminLogout,
          onCreate: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    expect(find.byType(CoeloAdminInteractiveCard), findsWidgets);
    expect(find.byType(CoeloAdminExpandableStatusIndicator), findsWidgets);
    expect(find.text('Vigência'), findsWidgets);
    expect(find.text('Horários'), findsWidgets);
    expect(find.text('Contexto responsável'), findsWidgets);
    expect(find.textContaining('Professor Demo'), findsWidgets);

    await tester.tap(find.byKey(const Key('health-medication-plans-view-table')));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminResizableTable<HealthMedicationPlanListItem>), findsOneWidget);
    expect(find.text('Contexto responsável'), findsOneWidget);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('medication directory has no overflow at $width with 200% text', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = HealthCareController(DemoHealthCareRepository());
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: HealthMedicationPlanDirectoryPage(
            controller: controller,
            logout: unavailableSuperadminLogout,
            onCreate: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
