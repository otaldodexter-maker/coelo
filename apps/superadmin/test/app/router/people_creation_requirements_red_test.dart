import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/people/data/supabase_person_directory_repository.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/people/fake_person_directory_repository.dart';

GoRouter _router(
  SuperadminSession session, {
  PersonDirectoryRepository? personDirectoryRepository,
}) => createSuperadminRouter(
  session: session,
  login: unavailableSuperadminLogin,
  logout: unavailableSuperadminLogout,
  requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
  allowDevelopmentPreview: true,
  personDirectoryRepository:
      personDirectoryRepository ?? const UnavailablePersonDirectoryRepository(),
  onThemeModeChanged: (_) {},
);

void main() {
  testWidgets('production create stays blocked without a composed people repository', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    final router = _router(session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.personCreate);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('person-identity-lookup-dialog')), findsNothing);
    expect(find.byKey(const Key('person-first-name-field')), findsNothing);
  });

  testWidgets('create requires identity lookup in production and development', (tester) async {
    // people.create destravado pela capacidade composta (2891e6977) e pelo
    // resolvedor de identidade 170700 em producao (lote 54).
    final session = SuperadminSession()..signInForTesting();
    final router = _router(session, personDirectoryRepository: FakePersonDirectoryRepository());
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.personCreate);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsNothing);
    expect(find.byKey(const Key('person-identity-lookup-dialog')), findsOneWidget);
    expect(find.byKey(const Key('person-first-name-field')), findsNothing);

    router.go(SuperadminRoutes.devPersonCreate);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('person-identity-lookup-dialog')), findsOneWidget);
    expect(find.byKey(const Key('person-identity-lookup-field')), findsOneWidget);
    expect(find.byKey(const Key('person-first-name-field')), findsNothing);
  });
}
