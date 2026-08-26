import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final routes = File('lib/app/router/superadmin_routes.dart').readAsStringSync();
  final router = File('lib/app/router/superadmin_router.dart').readAsStringSync();
  final authScope = File('lib/core/config/superadmin_auth_scope.dart').readAsStringSync();
  final app = File('lib/app/superadmin_app.dart').readAsStringSync();
  final mainSource = File('lib/main.dart').readAsStringSync();

  test('declares production and development invitation paths and names', () {
    for (final declaration in const [
      "static const invites = '/invites';",
      "static const invitesName = 'invites';",
      "static const inviteCreate = '/invites/new';",
      "static const inviteCreateName = 'invite-create';",
      "static const inviteDetail = '/invites/:inviteId';",
      "static const inviteDetailName = 'invite-detail';",
      "static const devInvites = '/dev/invites';",
      "static const devInvitesName = 'dev-invites';",
      "static const devInviteCreate = '/dev/invites/new';",
      "static const devInviteCreateName = 'dev-invite-create';",
      "static const devInviteDetail = '/dev/invites/:inviteId';",
      "static const devInviteDetailName = 'dev-invite-detail';",
    ]) {
      expect(routes, contains(declaration), reason: declaration);
    }
  });

  test('production invitation routes use only the injected repository', () {
    expect(
      router,
      contains('InviteRepository inviteRepository = const UnavailableInviteRepository()'),
    );
    expect(RegExp(r'repository:\s*inviteRepository,').allMatches(router), hasLength(3));

    for (final route in const ['invites', 'inviteCreate', 'inviteDetail']) {
      final block = _routeBlock(router, route);
      expect(block, contains('repository: inviteRepository,'), reason: route);
      expect(block, contains('logout: logout,'), reason: route);
      expect(block, contains('onDestinationSelected:'), reason: route);
      expect(block, isNot(contains('invitePreviewRepository')), reason: route);
    }
  });

  test('development invitation routes use one local lazy repository cache', () {
    expect(router, contains("import '../dev_menu/development_invite_repository.dart';"));
    expect(
      RegExp(r'DevelopmentInviteRepository\?\s+cachedInvitePreviewRepository;').allMatches(router),
      hasLength(1),
    );
    expect(
      RegExp(
        r'cachedInvitePreviewRepository\s*\?\?=\s*DevelopmentInviteRepository\(\)',
      ).allMatches(router),
      hasLength(1),
    );
    expect(RegExp(r'repository:\s*invitePreviewRepository\(\),').allMatches(router), hasLength(3));

    for (final route in const ['devInvites', 'devInviteCreate', 'devInviteDetail']) {
      final block = _routeBlock(router, route);
      expect(block, contains('repository: invitePreviewRepository(),'), reason: route);
      expect(block, contains('logout: _previewLogout,'), reason: route);
      expect(block, contains('onDestinationSelected:'), reason: route);
      expect(block, isNot(contains('repository: inviteRepository,')), reason: route);
    }
  });

  test('composition roots contain no fake, Supabase or development invite repository', () {
    final productionRoots = '$authScope\n$app\n$mainSource';
    for (final forbidden in const [
      'FakeInviteRepository',
      'fake_invite_repository.dart',
      'SupabaseInviteRepository',
      'supabase_invite_repository.dart',
      'DevelopmentInviteRepository',
      'development_invite_repository.dart',
    ]) {
      expect(productionRoots, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(router, isNot(contains('FakeInviteRepository')));
    expect(router, isNot(contains('fake_invite_repository.dart')));
    expect(router, isNot(contains('SupabaseInviteRepository')));
    expect(router, isNot(contains('supabase_invite_repository.dart')));
  });

  test('persistent shell invitation navigation targets production', () {
    expect(router, contains("case 'invites':"));
    expect(router, contains('context.goNamed(SuperadminRoutes.invitesName)'));
  });
}

String _routeBlock(String source, String route) {
  final start = source.indexOf('path: SuperadminRoutes.$route,');
  expect(start, greaterThanOrEqualTo(0), reason: route);
  final nextRoute = source.indexOf('GoRoute(', start + 1);
  return source.substring(start, nextRoute < 0 ? source.length : nextRoute);
}
