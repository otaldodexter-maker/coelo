import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import '../support/health_care_fixture_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_controller.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses profile tabs, canonical cards and no status or dose filters', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = HealthCareController(FixtureHealthCareRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthCareProfileDirectoryPage(
          controller: controller,
          logout: unavailableSuperadminLogout,
          onCreate: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Ativos'), findsOneWidget);
    expect(find.text('Em Implanta\u00e7\u00e3o'), findsOneWidget);
    expect(find.text('Inativos'), findsOneWidget);
    expect(find.byType(CoeloAdminMultiSelectFilter<HealthCareOperationalStatus>), findsNothing);
    expect(find.byType(CoeloAdminMultiSelectFilter<HealthMedicationDoseSituation>), findsNothing);
    expect(find.byType(CoeloAdminInteractiveCard), findsWidgets);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);

    await tester.tap(find.text('Em Implanta\u00e7\u00e3o'));
    await tester.pumpAndSettle();
    expect(controller.query.operationalStatuses, {HealthCareOperationalStatus.implementation});
  });
}
