import 'dart:io';

import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares the clean health care route tree', () {
    expect(SuperadminRoutes.healthCareProfiles, '/health-care/profiles');
    expect(SuperadminRoutes.healthCareProfileCreate, '/health-care/profiles/new');
    expect(SuperadminRoutes.healthCareProfileDetail, '/health-care/profiles/:childId');
    expect(SuperadminRoutes.healthCareProfileEdit, '/health-care/profiles/:childId/edit');
    expect(SuperadminRoutes.healthMedicationPlans, '/health-care/medication-plans');
    expect(SuperadminRoutes.healthMedicationPlanCreate, '/health-care/medication-plans/new');
    expect(
      SuperadminRoutes.healthMedicationPlanDetail,
      '/health-care/medication-plans/:medicationId',
    );
    expect(
      SuperadminRoutes.healthMedicationPlanEdit,
      '/health-care/medication-plans/:medicationId/edit',
    );
  });

  testWidgets('exposes both Health and Care sibling destinations', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final selected = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: unavailableSuperadminLogout,
          currentDestination: 'health-care-profiles',
          onDestinationSelected: selected.add,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sa\u00fade e Cuidado'), findsOneWidget);
    expect(find.text('Perfis de cuidado'), findsOneWidget);
    expect(find.text('Planos de medica\u00e7\u00e3o'), findsOneWidget);

    await tester.tap(find.byKey(const Key('superadmin-navigation-health-medication-plans')));
    expect(selected, ['health-medication-plans']);
  });

  test('router source wires all eight routes to the sibling pages', () {
    final source = File('lib/app/router/superadmin_router.dart').readAsStringSync();

    for (final routeName in [
      'healthCareProfilesName',
      'healthCareProfileCreateName',
      'healthCareProfileDetailName',
      'healthCareProfileEditName',
      'healthMedicationPlansName',
      'healthMedicationPlanCreateName',
      'healthMedicationPlanDetailName',
      'healthMedicationPlanEditName',
    ]) {
      expect(source, contains('SuperadminRoutes.$routeName'));
    }
    for (final page in [
      'HealthCareProfileDirectoryPage',
      'HealthCareProfileFormPage',
      'HealthCareProfileDetailPage',
      'HealthMedicationPlanDirectoryPage',
      'HealthMedicationPlanFormPage',
      'HealthMedicationPlanDetailPage',
    ]) {
      expect(source, contains(page));
    }
  });
}
