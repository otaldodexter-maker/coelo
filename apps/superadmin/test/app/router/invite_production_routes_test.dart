import 'dart:io';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('declares production invitation paths and names', () {
    final routes = File('lib/app/router/superadmin_routes.dart').readAsStringSync();

    expect(routes, contains("static const invites = '/invites';"));
    expect(routes, contains("static const invitesName = 'invites';"));
    expect(routes, contains("static const inviteCreate = '/invites/new';"));
    expect(routes, contains("static const inviteCreateName = 'invite-create';"));
    expect(routes, contains("static const inviteDetail = '/invites/:inviteId';"));
    expect(routes, contains("static const inviteDetailName = 'invite-detail';"));
  });

  test('router has no fake invitation repository production fallback', () {
    final router = File('lib/app/router/superadmin_router.dart').readAsStringSync();

    expect(router, isNot(contains('fake_invite_repository.dart')));
    expect(router, isNot(contains('FakeInviteRepository(')));
    expect(
      router,
      contains('InviteRepository inviteRepository = const UnavailableInviteRepository()'),
    );
  });

  for (final (legacyPath, productionPath) in const [
    ('/dev/invites', '/invites'),
    ('/dev/invites/new', '/invites/new'),
    ('/dev/invites/invite-123', '/invites/invite-123'),
  ]) {
    testWidgets('redirects $legacyPath to $productionPath', (tester) async {
      final session = SuperadminSession()..signIn();
      final router = _router(session);
      addTearDown(router.dispose);
      addTearDown(session.dispose);

      router.go(legacyPath);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, productionPath);
    });
  }

  testWidgets('production invitation directory uses the injected repository', (tester) async {
    final session = SuperadminSession()..signIn();
    final repository = _TrackingInviteRepository();
    final router = _router(session, inviteRepository: repository);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go('/invites');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(repository.fetchPageCalls, greaterThan(0));
    expect(router.routeInformationProvider.value.uri.path, '/invites');
  });

  test('persistent shell invitation navigation targets production', () {
    final source = File('lib/app/router/superadmin_router.dart').readAsStringSync();
    expect(source, contains('case \'invites\':'));
    expect(source, contains('context.goNamed(SuperadminRoutes.invitesName)'));
  });
}

GoRouter _router(
  SuperadminSession session, {
  InviteRepository inviteRepository = const UnavailableInviteRepository(),
}) => createSuperadminRouter(
  session: session,
  login: (_) async => const LoginResult.success(),
  logout: unavailableSuperadminLogout,
  requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
  inviteRepository: inviteRepository,
  onThemeModeChanged: (_) {},
);

final class _TrackingInviteRepository implements InviteRepository {
  int fetchPageCalls = 0;

  @override
  Future<InviteDirectoryResult> fetchPage(InviteDirectoryQuery query) async {
    fetchPageCalls++;
    return InviteDirectoryResult(
      items: const [],
      totalCount: 0,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
