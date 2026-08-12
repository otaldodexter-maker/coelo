import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import '../support/health_care_fixture_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
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
    final controller = HealthCareController(FixtureHealthCareRepository());
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
    expect(find.text('Status do plano'), findsOneWidget);
    expect(find.text('Situação da dose'), findsOneWidget);
    expect(find.byType(CoeloAdminPagination), findsOneWidget);
    expect(find.text('Vigência'), findsWidgets);
    expect(find.text('Horários'), findsWidgets);
    expect(find.text('Contexto responsável'), findsWidgets);
    expect(find.textContaining('Professor Demo'), findsWidgets);

    final statusFilter = tester.widget<CoeloAdminMultiSelectFilter<HealthMedicationReviewStatus>>(
      find.byType(CoeloAdminMultiSelectFilter<HealthMedicationReviewStatus>),
    );
    statusFilter.onChanged({HealthMedicationReviewStatus.ended});
    await tester.pumpAndSettle();
    expect(find.text('Nenhum plano'), findsOneWidget);
    statusFilter.onChanged({});
    await tester.pumpAndSettle();

    final doseFilter = tester.widget<CoeloAdminMultiSelectFilter<HealthMedicationDoseSituation>>(
      find.byType(CoeloAdminMultiSelectFilter<HealthMedicationDoseSituation>),
    );
    doseFilter.onChanged({HealthMedicationDoseSituation.notAdministered});
    await tester.pumpAndSettle();
    expect(find.text('Nenhum plano'), findsOneWidget);
    doseFilter.onChanged({});
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('health-medication-plans-view-table')));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminResizableTable<HealthMedicationPlanListItem>), findsOneWidget);
    expect(find.text('Contexto responsável'), findsOneWidget);
  });

  testWidgets('shows the minimized permission state without leaking plan data', (tester) async {
    final controller = HealthCareController(
      FixtureHealthCareRepository(),
      actor: HealthCareActor(
        id: 'minimized-demo',
        profile: HealthCareAccessProfile.minimized,
        authorizedChildIds: const {'child-demo-a', 'child-demo-b'},
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthMedicationPlanDirectoryPage(
          controller: controller,
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Resumo minimizado'), findsOneWidget);
    expect(find.text('Medicamento Demo'), findsNothing);
  });

  testWidgets('loads only medication plans authorized for the active context', (tester) async {
    final controller = HealthCareController(
      FixtureHealthCareRepository(),
      actor: HealthCareActor(
        id: 'reader-demo',
        profile: HealthCareAccessProfile.sensitiveReader,
        institutionId: 'institution-demo-a',
        authorizedChildIds: const {'child-demo-a'},
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthMedicationPlanDirectoryPage(
          controller: controller,
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Medicamento Demo'), findsOneWidget);
    expect(find.text('Não foi possível carregar'), findsNothing);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('medication directory has no overflow at $width with 200% text', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = HealthCareController(FixtureHealthCareRepository());
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
