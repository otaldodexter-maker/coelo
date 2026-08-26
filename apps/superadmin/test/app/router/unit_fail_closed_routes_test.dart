import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/data/unavailable_unit_composition.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_directory_page.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('production unit routes receive only unavailable composition', (tester) async {
    final session = SuperadminSession()..signIn();
    final router = _router(session, allowDevelopmentPreview: true);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go('/units');
    await tester.pumpAndSettle();

    final directory = tester.widget<UnitDirectoryPage>(find.byType(UnitDirectoryPage));
    expect(directory.repository, isA<UnavailableUnitDirectoryRepository>());
    expect(directory.repository, isNot(isA<FakeUnitDirectoryRepository>()));
    expect(directory.backendCommands, isA<UnavailableUnitBackendCommandsGateway>());

    for (final path in const ['/units/new', '/units/unit-1/edit']) {
      router.go(path);
      await tester.pumpAndSettle();

      final form = tester.widget<UnitFormPage>(find.byType(UnitFormPage));
      expect(form.repository, isA<UnavailableUnitDirectoryRepository>(), reason: path);
      expect(form.repository, isNot(isA<FakeUnitDirectoryRepository>()), reason: path);
    }
  });

  testWidgets('development unit routes receive cached fake repository and null gateway', (
    tester,
  ) async {
    final session = SuperadminSession()..signIn();
    final router = _router(session, allowDevelopmentPreview: true);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    Object? cachedRepository;

    router.go('/dev/units');
    await tester.pumpAndSettle();

    final directory = tester.widget<UnitDirectoryPage>(find.byType(UnitDirectoryPage));
    expect(directory.repository, isA<FakeUnitDirectoryRepository>());
    expect(directory.backendCommands, isNull);
    cachedRepository = directory.repository;

    for (final path in const ['/dev/units/new', '/dev/units/unit-1/edit']) {
      router.go(path);
      await tester.pumpAndSettle();

      final form = tester.widget<UnitFormPage>(find.byType(UnitFormPage));
      expect(form.repository, isA<FakeUnitDirectoryRepository>(), reason: path);
      expect(identical(form.repository, cachedRepository), isTrue, reason: path);
    }
  });

  testWidgets('release guard keeps development unit routes unreachable', (tester) async {
    final session = SuperadminSession()..signIn();
    final router = _router(session, allowDevelopmentPreview: false);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devUnits);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.home);
    expect(find.byType(UnitDirectoryPage), findsNothing);
    expect(find.byType(UnitFormPage), findsNothing);
  });
}

GoRouter _router(SuperadminSession session, {required bool allowDevelopmentPreview}) {
  return createSuperadminRouter(
    session: session,
    login: unavailableSuperadminLogin,
    logout: unavailableSuperadminLogout,
    requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
    allowDevelopmentPreview: allowDevelopmentPreview,
    onThemeModeChanged: (_) {},
  );
}
