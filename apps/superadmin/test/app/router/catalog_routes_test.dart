import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/catalog/presentation/catalog_host_page.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('protects the catalog route without a session', (tester) async {
    final session = SuperadminSession();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.governanceCatalog);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
    expect(find.byType(CatalogHostPage), findsNothing);
  });

  testWidgets('opens the protected catalog and never adds a dev bypass', (tester) async {
    final session = SuperadminSession()..signIn();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.governanceCatalog);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogHostPage), findsOneWidget);

    router.go('/dev/catalog');
    await tester.pumpAndSettle();
    expect(find.byType(CatalogHostPage), findsNothing);
  });

  testWidgets('keeps institutions open when catalog launches externally', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final openedCatalogs = <Uri>[];
    final router = _router(session, openExternalCatalog: openedCatalogs.add);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devInstitutions);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Governança'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devInstitutions);
    expect(find.byType(CatalogHostPage), findsNothing);
    expect(openedCatalogs, [Uri.parse('https://catalog.coelo.me/')]);
  });

  testWidgets('keeps the authenticated institutions page when catalog launches externally', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.institutions);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Governança'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.institutions);
    expect(find.byType(CatalogHostPage), findsNothing);
    expect(find.byKey(const Key('superadmin-floating-content')), findsOneWidget);
  });
}

GoRouter _router(SuperadminSession session, {ValueChanged<Uri>? openExternalCatalog}) {
  return createSuperadminRouter(
    session: session,
    login: (_) async => const LoginResult.success(),
    logout: unavailableSuperadminLogout,
    requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
    institutionDirectoryRepository: const FakeInstitutionDirectoryRepository(),
    catalogUrl: 'https://catalog.coelo.me',
    openExternalCatalog: openExternalCatalog,
    onThemeModeChanged: (_) {},
  );
}
