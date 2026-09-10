// Mapeamento nominal dos cinco action_ids da familia `shell`.
//
// A suite de shell e navegacao ja passava com 134 casos, mas nenhum deles
// dizia a qual acao pertencia: o rastreador registrava, com razao, que "134
// PASS" nao promove `shell.load`, `shell.navigate`, `shell.switch-context`,
// `shell.unauthorized` nem `shell.reload`, porque nao havia como saber qual
// caso provava qual acao. Este arquivo fecha essa lacuna com um caso por
// action_id, sobre o router e a sessao reais, sem fixture de rota.
//
// A regua do MVP (ADR 0034) e aplicada na parte que pertence ao cliente: a
// rota normal abre, a navegacao preserva o shell, a troca de contexto invalida
// a autorizacao anterior, a rota protegida sem sessao nao entrega conteudo e o
// reload volta na mesma rota.
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/support/presentation/view_models/support_prototype_controller.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/activities/fake_activity_directory_repository.dart';

const _shell = Key('superadmin-persistent-shell');

void main() {
  testWidgets('shell.load: a rota protegida real monta o shell com o conteudo dentro', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.institutions);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.byKey(_shell), findsOneWidget);
    expect(find.byKey(const Key('superadmin-sidebar')), findsOneWidget);
    expect(_location(router), SuperadminRoutes.institutions);
  });

  testWidgets('shell.navigate: trocar de destino preserva a mesma instancia do shell', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.institutions);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    final mounted = tester.state(find.byKey(_shell));

    router.go(SuperadminRoutes.support);
    await tester.pumpAndSettle();

    expect(tester.state(find.byKey(_shell)), same(mounted));
    expect(_location(router), SuperadminRoutes.support);
    expect(find.byKey(const Key('support-page-content')), findsOneWidget);
  });

  testWidgets('shell.switch-context: trocar o contexto invalida a autorizacao anterior', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.institutions);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    final before = session.authorizationInvalidationRevision;

    session.authorize(
      const SuperadminAuthContext(
        platformRoleCode: 'test-role',
        scopeKind: SuperadminAuthScopeKind.institution,
        scopeInstitutionId: '00000000-0000-4000-8000-0000000000aa',
        permissionCodes: {'platform.read'},
        aal: 'aal1',
      ),
      sessionId: '00000000-0000-4000-8000-000000000002',
    );
    await tester.pumpAndSettle();

    // Sem esta invalidacao, uma tela aberta sob o contexto anterior seguiria
    // exibindo dados que o novo contexto pode nao ter direito de ver.
    expect(session.authorizationInvalidationRevision, greaterThan(before));
    expect(session.authContext?.scopeInstitutionId, '00000000-0000-4000-8000-0000000000aa');
    expect(find.byKey(_shell), findsOneWidget);
  });

  testWidgets('shell.unauthorized: rota protegida sem sessao nao entrega conteudo protegido', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.institutions);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(_location(router), SuperadminRoutes.login);
    expect(find.byKey(_shell), findsNothing);
    expect(find.byKey(const Key('superadmin-sidebar')), findsNothing);
  });

  testWidgets('shell.reload: recarregar a rota protegida volta na mesma tela', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.support);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-page-content')), findsOneWidget);

    // Reload do navegador: a arvore inteira e recriada e o router remonta a
    // partir da mesma URI.
    final reloaded = _router(session);
    addTearDown(reloaded.dispose);
    reloaded.go(SuperadminRoutes.support);
    await tester.pumpWidget(_app(reloaded));
    await tester.pumpAndSettle();

    expect(_location(reloaded), SuperadminRoutes.support);
    expect(find.byKey(_shell), findsOneWidget);
    expect(find.byKey(const Key('support-page-content')), findsOneWidget);
  });
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

GoRouter _router(SuperadminSession session) => createSuperadminRouter(
  session: session,
  login: (_) async => const LoginResult.success(),
  logout: unavailableSuperadminLogout,
  requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
  institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
  activityDirectoryRepository: FakeActivityDirectoryRepository(),
  supportController: SupportPrototypeController(),
  onThemeModeChanged: (_) {},
);

Widget _app(GoRouter router) =>
    MaterialApp.router(theme: CoeloTheme.light, routerConfig: router);
