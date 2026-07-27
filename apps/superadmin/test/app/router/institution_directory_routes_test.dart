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
    await tester.drag(
      find.byKey(const Key('institution-directory-content-scroll')),
      const Offset(0, -1400),
    );
    await tester.pumpAndSettle();
    await tester.tap(institutionCard);
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

  testWidgets('creates locally and shows the new institution in the directory', (tester) async {
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

    await _enter(tester, 'publicName', 'Instituição Navegável');
    await _enter(tester, 'legalName', 'Instituição Navegável LTDA');
    await _enter(tester, 'typeName', 'Escola');
    await _enter(tester, 'document', '12.345.678/0001-90');
    await _continue(tester);

    await _enter(tester, 'postalCode', '01310-100');
    await _enter(tester, 'state', 'SP');
    await _enter(tester, 'city', 'São Paulo');
    await _enter(tester, 'street', 'Rua do Protótipo');
    await _enter(tester, 'addressNumber', '48');
    await _enter(tester, 'contactEmail', 'contato@navegavel.coelo.me');
    await _enter(tester, 'contactMobilePhone', '+55 11 99999-4848');
    await _continue(tester);

    await _enter(tester, 'ownerFirstName', 'Ana');
    await _enter(tester, 'ownerLastName', 'Souza');
    await _enter(tester, 'ownerEmail', 'ana@navegavel.coelo.me');
    await _enter(tester, 'ownerMobilePhone', '+55 11 98888-4848');
    await _continue(tester);
    await _continue(tester);
    await _continue(tester);

    await tester.tap(find.byKey(const Key('institution-form-save')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devInstitutions);
    expect(repository.records, hasLength(16));
    expect(find.text('Instituição Navegável'), findsOneWidget);
    expect(find.text('Instituição criada com sucesso.'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-transient-notice')), findsOneWidget);
  });

  testWidgets('updates locally and reflects the edited name in the directory', (tester) async {
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
    await _enter(tester, 'publicName', 'Instituto Aurora Atualizado');
    for (var step = 0; step < 5; step++) {
      await _continue(tester);
    }

    await tester.tap(find.byKey(const Key('institution-form-save')));
    await tester.pumpAndSettle();

    expect(repository.records, hasLength(15));
    expect(
      repository.findById('demo-institution-aurora')!.publicName,
      'Instituto Aurora Atualizado',
    );
    expect(find.text('Instituto Aurora Atualizado'), findsOneWidget);
    expect(find.text('Alterações salvas com sucesso.'), findsOneWidget);
  });
}

Future<void> _enter(WidgetTester tester, String field, String value) async {
  await tester.enterText(find.byKey(Key('institution-field-$field')), value);
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('institution-form-continue')));
  await tester.pumpAndSettle();
}
