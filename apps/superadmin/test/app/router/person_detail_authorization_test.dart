import 'dart:async';
import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/domain/person_detail_reader.dart';
import 'package:coelo_superadmin/features/people/presentation/person_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = '11111111-1111-4111-8111-111111111111';
SuperadminAuthContext _context(String institution) => SuperadminAuthContext(
  platformRoleCode: 'operations',
  scopeKind: SuperadminAuthScopeKind.institution,
  scopeInstitutionId: institution,
  permissionCodes: const {'people.read'},
  aal: 'aal1',
);

void main() {
  testWidgets('unauthenticated deep link never invokes the detail reader', (tester) async {
    final session = SuperadminSession();
    final reader = _Reader();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
      personDetailReader: reader,
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go('/people/$_id');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(reader.calls, isEmpty);
    expect(find.byType(PersonDetailPage), findsNothing);
  });
  for (final path in ['/people/new', '/people/$_id/edit']) {
    testWidgets('read route does not intercept existing mutation path $path', (tester) async {
      final session = SuperadminSession()..authorize(_context('institution-a'), sessionId: 'a');
      final reader = _Reader();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        onThemeModeChanged: (_) {},
        personDetailReader: reader,
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);
      router.go(path);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.byType(PersonDetailPage), findsNothing);
      expect(reader.calls, isEmpty);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/errors/mutation-capability-unavailable',
      );
    });
  }
  for (final pending in [false, true]) {
    for (final change in ['scope', 'session', 'logout', 'recovery']) {
      testWidgets('person removes prior data on $change pending=$pending', (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final authStates = StreamController<CoeloAuthSessionState>(sync: true);
        addTearDown(authStates.close);
        final session = SuperadminSession(authSessionStateChanges: authStates.stream)
          ..authorize(_context('institution-a'), sessionId: 'session-a');
        final reader = _Reader();
        final router = createSuperadminRouter(
          session: session,
          login: unavailableSuperadminLogin,
          logout: unavailableSuperadminLogout,
          requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
          onThemeModeChanged: (_) {},
          personDetailReader: reader,
        );
        addTearDown(router.dispose);
        addTearDown(session.dispose);
        router.go('/people/$_id');
        await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
        await tester.pump();
        expect(reader.calls, hasLength(1));
        if (!pending) {
          reader.calls.first.complete(_person);
          await tester.pumpAndSettle();
          expect(find.text('Dados do contexto A'), findsOneWidget);
        }
        switch (change) {
          case 'scope':
            session.authorize(_context('institution-b'), sessionId: 'session-a');
          case 'session':
            session.authorize(_context('institution-a'), sessionId: 'session-b');
          case 'logout':
            session.signOut();
          case 'recovery':
            authStates.add(const CoeloAuthSessionState.passwordRecovery());
        }
        await tester.pump();
        expect(find.text('Dados do contexto A'), findsNothing);
        final stillAuthenticated = change == 'scope' || change == 'session';
        expect(reader.calls, hasLength(stillAuthenticated ? 2 : 1));
        if (stillAuthenticated) {
          expect(find.byKey(const Key('person-detail-loading')), findsOneWidget);
          reader.calls.last.completeError(const PersonDirectoryUnauthorizedException());
        }
        await tester.pumpAndSettle();
        if (pending) {
          reader.calls.first.complete(_person);
          await tester.pumpAndSettle();
        }
        expect(find.text('Dados do contexto A'), findsNothing);
        if (stillAuthenticated) {
          expect(find.byKey(const Key('person-detail-denied')), findsOneWidget);
          expect(router.routeInformationProvider.value.uri.path, '/people/$_id');
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _Reader implements PersonDetailReader {
  final calls = <Completer<PersonDirectoryItem>>[];
  @override
  Future<PersonDirectoryItem> fetchDetail(String id) {
    final call = Completer<PersonDirectoryItem>();
    calls.add(call);
    return call.future;
  }
}

final _person = PersonDirectoryItem(
  id: _id,
  displayName: 'Dados do contexto A',
  type: PersonType.adult,
  status: PersonStatus.active,
  updatedAt: DateTime.utc(2026, 9, 7),
);
