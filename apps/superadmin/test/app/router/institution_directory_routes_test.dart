import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('production composition isolates its repository while dev uses preview data', (
    tester,
  ) async {
    final session = SuperadminSession()..signIn();
    final repository = _ProductionInstitutionRepository();
    final router = createSuperadminRouter(
      session: session,
      login: (_) async => const LoginResult.success(),
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      institutionDirectoryRepository: repository,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devInstitutions);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(repository.calls, 0);
    expect(find.text('Instituto Aurora'), findsOneWidget);
  });
  testWidgets('protects the real institution directory without a session', (tester) async {
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

    router.go(SuperadminRoutes.institutions);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
  });

  testWidgets('opens the dev institution preview without a session using fake data', (
    tester,
  ) async {
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

    router.go(SuperadminRoutes.devInstitutions);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devInstitutions);
    expect(find.text('Instituto Aurora'), findsOneWidget);
  });

  testWidgets('redirects an authenticated session to the protected home', (tester) async {
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: (_) async => const LoginResult.success(),
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.home);
    expect(find.text('Como podemos ajudar?'), findsOneWidget);
  });

  testWidgets('opens create and edit routes from the dev institution directory', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
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

    router.go(SuperadminRoutes.devInstitutions);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-institution-card')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devInstitutionCreate);
    expect(find.text('Criar instituição'), findsOneWidget);

    router.go(SuperadminRoutes.devInstitutions);
    await tester.pumpAndSettle();
    final institutionCard = find.byKey(const Key('institution-card-demo-institution-aurora'));
    final institutionCardTap = find.descendant(of: institutionCard, matching: find.byType(InkWell));
    tester.widget<InkWell>(institutionCardTap).onTap!.call();
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/dev/institutions/demo-institution-aurora/edit',
    );
    expect(find.text('Editar instituição'), findsOneWidget);
  });

  testWidgets('shows a not-found state for an unknown institution', (tester) async {
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

    router.go('/dev/institutions/unknown/edit');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('institution-form-not-found')), findsOneWidget);
  });

  testWidgets('starts local creation with branding and profile data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
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

    router.go(SuperadminRoutes.devInstitutionCreate);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    await _enter(tester, 'brandDisplayName', 'Instituição Navegável');
    await _continue(tester);
    await _enter(tester, 'publicName', 'Instituição Navegável');

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devInstitutionCreate);
    expect(repository.records, hasLength(12));
    expect(find.text('Instituição Navegável'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('updates the isolated preview and keeps the current edit route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
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

    router.go('/dev/institutions/demo-institution-aurora/edit');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    await _enter(tester, 'brandDisplayName', 'Aurora atualizado');
    tester
        .widget<FilledButton>(find.byKey(const Key('institution-form-save-current')))
        .onPressed!
        .call();
    await tester.pumpAndSettle();
    final confirmAdministrators = find.byKey(
      const Key('institution-confirm-representative-administrators'),
    );
    tester.widget<FilledButton>(confirmAdministrators).onPressed!.call();
    await tester.pumpAndSettle();

    tester
        .widget<FilledButton>(find.byKey(const Key('institution-form-save-current')))
        .onPressed!
        .call();
    await tester.pumpAndSettle();

    expect(find.text('Alterações salvas.'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, contains('/edit'));
  });
}

Future<void> _enter(WidgetTester tester, String field, String value) async {
  await tester.enterText(find.byKey(Key('institution-field-$field')), value);
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('institution-form-continue')));
  await tester.pumpAndSettle();
}

final class _ProductionInstitutionRepository implements InstitutionDirectoryRepository {
  int calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('production repository must not be used by dev institution routes');
  }
}
