import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares production and development unit routes', () {
    expect(SuperadminRoutes.units, '/units');
    expect(SuperadminRoutes.unitCreate, '/units/new');
    expect(SuperadminRoutes.unitEdit, '/units/:unitId/edit');
    expect(SuperadminRoutes.devUnits, '/dev/units');
    expect(SuperadminRoutes.devUnitCreate, '/dev/units/new');
    expect(SuperadminRoutes.devUnitEdit, '/dev/units/:unitId/edit');
  });

  testWidgets('protects production and exposes the development unit directory', (tester) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.units);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);

    router.go(SuperadminRoutes.devUnits);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devUnits);
    expect(find.text('Gerencie as unidades da plataforma.'), findsOneWidget);
    expect(find.byKey(const Key('create-unit-card')), findsOneWidget);
  });

  testWidgets('opens unit creation and editing from the development directory', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final repository = FakeInstitutionDirectoryRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      institutionDirectoryRepository: repository,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devUnits);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-unit-card')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devUnitCreate);
    expect(find.text('Criar unidade'), findsWidgets);

    router.go(SuperadminRoutes.devUnits);
    await tester.pumpAndSettle();
    final firstUnitCard = find
        .byWidgetPredicate((widget) => widget.key.toString().contains('unit-card-'))
        .first;
    await tester.tap(firstUnitCard);
    await tester.pumpAndSettle();
    final editPath = router.routeInformationProvider.value.uri.path;
    expect(editPath, startsWith('/dev/units/'));
    expect(editPath, endsWith('/edit'));
    expect(find.text('Editar unidade'), findsWidgets);
  });
}
