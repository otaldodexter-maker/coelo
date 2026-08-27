import 'dart:io';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_form_pages.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_plan_directory_page.dart';
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

  testWidgets('legacy detail URLs redirect directly to edit forms', (tester) async {
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    for (final entry in <String, String>{
      '/health-care/profiles/child-demo-a': '/health-care/profiles/child-demo-a/edit',
    }.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, entry.value);
    }
  });

  testWidgets('medication plan production routes stay unavailable without repository calls', (
    tester,
  ) async {
    final session = SuperadminSession()..signIn();
    final repository = _TrackingMedicationPlanRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      medicationPlanRepository: repository,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final path in const [
      '/health-care/medication-plans',
      '/health-care/medication-plans/new',
      '/health-care/medication-plans/medication-demo-a',
      '/health-care/medication-plans/medication-demo-a/edit',
    ]) {
      router.go(path);
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, path, reason: path);
      expect(find.byType(SuperadminErrorScreen), findsOneWidget, reason: path);
      expect(
        tester.widget<SuperadminErrorScreen>(find.byType(SuperadminErrorScreen)).kind,
        SuperadminErrorKind.unavailable,
        reason: path,
      );
      expect(
        find.bySemanticsLabel('Erro 503. O Coelo está temporariamente indisponível.'),
        findsOneWidget,
        reason: path,
      );
      expect(find.byType(HealthMedicationPlanDirectoryPage), findsNothing, reason: path);
      expect(find.byType(HealthMedicationPlanFormPage), findsNothing, reason: path);
      expect(repository.calls, 0, reason: path);
    }
  });

  testWidgets('medication plan development routes remain demonstrative', (tester) async {
    final session = SuperadminSession()..signIn();
    final repository = _TrackingMedicationPlanRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      medicationPlanRepository: repository,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final routeCase in <({String path, String expectedPath, Type page})>[
      (
        path: '/dev/health-care/medication-plans',
        expectedPath: '/dev/health-care/medication-plans',
        page: HealthMedicationPlanDirectoryPage,
      ),
      (
        path: '/dev/health-care/medication-plans/new',
        expectedPath: '/dev/health-care/medication-plans/new',
        page: HealthMedicationPlanFormPage,
      ),
      (
        path: '/dev/health-care/medication-plans/medication-demo-a',
        expectedPath: '/dev/health-care/medication-plans/medication-demo-a/edit',
        page: HealthMedicationPlanFormPage,
      ),
      (
        path: '/dev/health-care/medication-plans/medication-demo-a/edit',
        expectedPath: '/dev/health-care/medication-plans/medication-demo-a/edit',
        page: HealthMedicationPlanFormPage,
      ),
    ]) {
      router.go(routeCase.path);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        routeCase.expectedPath,
        reason: routeCase.path,
      );
      expect(find.byType(SuperadminErrorScreen), findsNothing, reason: routeCase.path);
      expect(find.byType(routeCase.page), findsOneWidget, reason: routeCase.path);
      expect(repository.calls, 0, reason: routeCase.path);
    }
  });

  testWidgets('care profile fixtures are injected only by development routes', (tester) async {
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go('/health-care/profiles/new');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('health-care-profile-form-unavailable')), findsOneWidget);

    router.go('/dev/health-care/profiles/new');
    await tester.pumpAndSettle();
    expect(find.byType(HealthCareProfileFormPage), findsOneWidget);
    expect(find.byKey(const Key('health-care-profile-form-unavailable')), findsNothing);
  });

  test('router source wires directories and forms without detail pages', () {
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
      'HealthMedicationPlanDirectoryPage',
      'HealthMedicationPlanFormPage',
    ]) {
      expect(source, contains(page));
    }
    expect(source, isNot(contains('HealthCareProfileDetailPage')));
    expect(source, isNot(contains('HealthMedicationPlanDetailPage')));
  });
}

final class _TrackingMedicationPlanRepository implements MedicationPlanRepository {
  var calls = 0;

  Never _unexpectedCall() {
    calls += 1;
    throw StateError('MedicationPlanRepository must stay unused while fail-closed.');
  }

  @override
  Future<MedicationPlanDetail> fetchDetail(String planId) async => _unexpectedCall();

  @override
  Future<MedicationPlanPage> fetchPage(MedicationPlanQuery query) async => _unexpectedCall();

  @override
  Future<MedicationPlanDetail> save(MedicationPlanSaveCommand command) async => _unexpectedCall();
}
