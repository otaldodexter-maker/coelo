import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/support/presentation/view_models/support_prototype_controller.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final development in [true, false]) {
    testWidgets(
      'mobile header routes report to ${development ? 'preview' : 'provided production'} controller',
      (tester) async {
        tester.view.physicalSize = const Size(375, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final session = SuperadminSession()..signInForTesting();
        final provided = SupportPrototypeController(initialTickets: []);
        addTearDown(session.dispose);
        addTearDown(provided.dispose);
        final router = createSuperadminRouter(
          allowDevelopmentPreview: true,
          session: session,
          login: (_) async => const LoginResult.success(),
          logout: unavailableSuperadminLogout,
          requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
          institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
          supportController: provided,
          onThemeModeChanged: (_) {},
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
        await tester.pumpAndSettle();
        router.go(development ? SuperadminRoutes.devInstitutions : SuperadminRoutes.institutions);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          development ? SuperadminRoutes.devInstitutions : SuperadminRoutes.institutions,
        );
        final report = find.byKey(const Key('superadmin-report-bug'));
        expect(report, findsOneWidget);
        await tester.tap(report);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('superadmin-bug-other-subject')), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const Key('superadmin-bug-screen')),
            matching: find.text('Instituições'),
          ),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('superadmin-bug-description')),
          'Relato sintético de isolamento do cabeçalho.',
        );
        final otherSubject = find.byKey(const Key('superadmin-bug-other-subject'));
        if (otherSubject.evaluate().isNotEmpty) {
          await tester.enterText(otherSubject, 'Cabeçalho sintético');
        }
        await tester.pump();
        final submit = find.byKey(const Key('superadmin-bug-submit'));
        expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('superadmin-bug-report-dialog')), findsNothing);
        expect(provided.tickets, hasLength(development ? 0 : 1));
        if (!development) {
          expect(provided.tickets.single.menu, 'Estrutura');
          expect(provided.tickets.single.screen, 'Instituições');
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('preview mobile report remains available without production support', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = SuperadminSession();
    addTearDown(session.dispose);
    final router = createSuperadminRouter(
      allowDevelopmentPreview: true,
      session: session,
      login: (_) async => const LoginResult.success(),
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    router.go(SuperadminRoutes.devInstitutions);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devInstitutions);
    expect(find.byKey(const Key('superadmin-report-bug')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
