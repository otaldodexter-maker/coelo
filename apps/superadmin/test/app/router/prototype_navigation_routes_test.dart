import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('prototype destinations navigate from any development shell page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    router.go(SuperadminRoutes.devInstitutions);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    const destinations = <(String, String)>[
      ('health-care-profiles', '/dev/health-care/profiles'),
      ('health-medication-plans', '/dev/health-care/medication-plans'),
      ('plans', '/dev/plans'),
      ('import', '/dev/imports'),
      ('invites', '/dev/invites'),
      ('notices', '/dev/notices'),
      ('audit', '/dev/audit'),
      ('catalog', '/dev/catalog'),
    ];

    for (final (id, expectedPath) in destinations) {
      router.go(SuperadminRoutes.devInstitutions);
      await tester.pumpAndSettle();
      final section = switch (id) {
        'health-care-profiles' || 'health-medication-plans' => 'health-care',
        'plans' || 'import' => 'operations',
        'invites' || 'notices' => 'communication',
        'audit' || 'catalog' => 'governance',
        _ => throw StateError('Missing navigation section for $id'),
      };
      var item = find.byKey(Key('superadmin-navigation-$id'));
      if (item.evaluate().isEmpty) {
        final sectionItem = find.byKey(Key('superadmin-navigation-section-$section'));
        await Scrollable.ensureVisible(tester.element(sectionItem), alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(sectionItem.hitTestable());
        await tester.pumpAndSettle();
        item = find.byKey(Key('superadmin-navigation-$id'));
      }
      await Scrollable.ensureVisible(tester.element(item), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(item.hitTestable());
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, expectedPath);
    }
  });
}
