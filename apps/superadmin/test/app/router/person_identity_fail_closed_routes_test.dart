import 'dart:io';

import 'package:coelo_superadmin/app/dev_menu/development_person_identity_repository.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/people/domain/person_identity.dart';
import 'package:coelo_superadmin/features/people/presentation/person_identity_lookup_gate.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final authScope = File('lib/core/config/superadmin_auth_scope.dart').readAsStringSync();
  final app = File('lib/app/superadmin_app.dart').readAsStringSync();
  final mainSource = File('lib/main.dart').readAsStringSync();
  final routerSource = File('lib/app/router/superadmin_router.dart').readAsStringSync();

  test('composition roots never import or construct the unavailable Supabase adapter', () {
    for (final source in [authScope, app, mainSource, routerSource]) {
      expect(source, isNot(contains('supabase_person_identity_repository.dart')));
      expect(source, isNot(contains('SupabasePersonIdentityRepository(')));
    }
    expect(
      authScope,
      contains('personIdentityRepository: const UnavailablePersonIdentityRepository()'),
    );
    expect(
      app,
      contains('this.personIdentityRepository = const UnavailablePersonIdentityRepository()'),
    );
    expect(app, contains('personIdentityRepository: widget.personIdentityRepository'));
    expect(mainSource, contains('personIdentityRepository: authScope.personIdentityRepository'));
    expect(routerSource, contains('repository: const DevelopmentPersonIdentityRepository()'));
  });

  testWidgets('production blocks identity lookup while dev stays isolated', (
    tester,
  ) async {
    final session = SuperadminSession()..signIn();
    final repository = _TrackingUnavailablePersonIdentityRepository();
    final router = _router(session, repository: repository, allowDevelopmentPreview: true);
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go(SuperadminRoutes.personCreate);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('production-mutation-capability-unavailable')),
      findsOneWidget,
    );
    expect(find.byType(PersonIdentityLookupGate), findsNothing);
    expect(repository.calls, 0);

    router.go(SuperadminRoutes.devPersonCreate);
    await tester.pumpAndSettle();

    final developmentGate = tester.widget<PersonIdentityLookupGate>(
      find.byType(PersonIdentityLookupGate),
    );
    expect(developmentGate.repository, isA<DevelopmentPersonIdentityRepository>());
    expect(identical(developmentGate.repository, repository), isFalse);
    expect(repository.calls, 0);
  });

  testWidgets('release guard keeps the development identity lookup unreachable', (tester) async {
    final session = SuperadminSession()..signIn();
    final repository = _TrackingUnavailablePersonIdentityRepository();
    final router = _router(session, repository: repository, allowDevelopmentPreview: false);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devPersonCreate);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.home);
    expect(find.byType(PersonIdentityLookupGate), findsNothing);
    expect(repository.calls, 0);
  });
}

GoRouter _router(
  SuperadminSession session, {
  required PersonIdentityRepository repository,
  required bool allowDevelopmentPreview,
}) => createSuperadminRouter(
  session: session,
  login: unavailableSuperadminLogin,
  logout: unavailableSuperadminLogout,
  requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
  personIdentityRepository: repository,
  allowDevelopmentPreview: allowDevelopmentPreview,
  onThemeModeChanged: (_) {},
);

final class _TrackingUnavailablePersonIdentityRepository implements PersonIdentityRepository {
  var calls = 0;

  Never _unexpectedCall() {
    calls += 1;
    throw const PersonIdentityUnavailableException();
  }

  @override
  Future<PersonHandleCheck> checkHandle({required String handle, String? personId}) async =>
      _unexpectedCall();

  @override
  Future<List<PersonIdentityCandidate>> resolve({
    required PersonIdentityLookupKind kind,
    required String query,
    String? institutionId,
    String? unitId,
    String? childContextId,
  }) async => _unexpectedCall();
}
