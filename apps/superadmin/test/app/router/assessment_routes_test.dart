import 'dart:io';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/dev_menu/development_assessment_repository.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/activities/fake_activity_directory_repository.dart';

void main() {
  test('declares production and development assessment routes', () {
    expect(
      SuperadminRoutes.activityAssessmentSettings,
      '/activities/:activityId/assessment-settings',
    );
    expect(SuperadminRoutes.assessmentEntry, '/assessments/entry');
    expect(SuperadminRoutes.assessmentGradebookEdit, '/assessments/gradebooks/:gradebookId/edit');
    expect(SuperadminRoutes.assessmentClosing, '/assessments/closing');
    expect(SuperadminRoutes.assessmentClosingDetail, '/assessments/closing/:gradebookId');
    expect(
      SuperadminRoutes.devActivityAssessmentSettings,
      '/dev/activities/:activityId/assessment-settings',
    );
    expect(SuperadminRoutes.devAssessmentEntry, '/dev/assessments/entry');
    expect(
      SuperadminRoutes.devAssessmentGradebookEdit,
      '/dev/assessments/gradebooks/:gradebookId/edit',
    );
    expect(SuperadminRoutes.devAssessmentClosing, '/dev/assessments/closing');
    expect(SuperadminRoutes.devAssessmentClosingDetail, '/dev/assessments/closing/:gradebookId');
  });

  test('registers every named route constant in the router tree', () {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    final source = File('lib/app/router/superadmin_routes.dart').readAsStringSync();
    final declared = RegExp(
      r"static const\s+\w+Name\s*=\s*'([^']+)'",
    ).allMatches(source).map((match) => match.group(1)!).toSet();
    final registered = _routeNames(router.configuration.routes).toSet();

    expect(registered, containsAll(declared));
  });

  testWidgets('opens all production and development assessment routes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      activityDirectoryRepository: FakeActivityDirectoryRepository(),
      assessmentRepository: DevelopmentAssessmentRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final route in [
      SuperadminRoutes.assessmentEntry,
      SuperadminRoutes.devAssessmentEntry,
      '/assessments/gradebooks/dev-gradebook-1/edit',
      '/dev/assessments/gradebooks/dev-gradebook-1/edit',
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(find.text('Lançar avaliações'), findsWidgets, reason: route);
      expect(tester.takeException(), isNull, reason: route);
    }

    for (final route in [
      SuperadminRoutes.assessmentClosing,
      SuperadminRoutes.devAssessmentClosing,
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(find.text('Fechamento de avaliações'), findsWidgets, reason: route);
      expect(tester.takeException(), isNull, reason: route);
    }

    for (final route in [
      '/assessments/closing/dev-gradebook-1',
      '/dev/assessments/closing/dev-gradebook-1',
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(find.text('Revisar fechamento'), findsOneWidget, reason: route);
      expect(tester.takeException(), isNull, reason: route);
    }

    for (final route in [
      '/activities/activity-1/assessment-settings',
      '/dev/activities/activity-1/assessment-settings',
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(find.text('Configuração avaliativa'), findsOneWidget, reason: route);
      expect(
        find.byKey(const Key('assessment-configuration-footer')),
        findsOneWidget,
        reason: route,
      );
      expect(tester.takeException(), isNull, reason: route);
    }

    router.go('/assessments/gradebooks/invalid/edit');
    await tester.pumpAndSettle();
    expect(find.text('Diário não encontrado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the unavailable dependency state without crashing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

    router.go(SuperadminRoutes.assessmentEntry);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Iterable<String> _routeNames(List<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      final name = route.name;
      if (name != null) yield name;
    }
    yield* _routeNames(route.routes);
  }
}
