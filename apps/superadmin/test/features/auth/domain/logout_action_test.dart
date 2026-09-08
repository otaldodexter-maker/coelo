import 'dart:async';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signs out through the gateway and clears the local session', () async {
    final auth = _FakeCoeloAuthGateway();
    final session = SuperadminSession()..signInForTesting();
    addTearDown(session.dispose);
    final logout = createCoeloAuthLogoutAction(auth: auth, session: session);

    final result = await logout();

    expect(result.isSuccess, isTrue);
    expect(result.message, isNull);
    expect(auth.didSignOut, isTrue);
    expect(session.isAuthenticated, isFalse);
  });

  for (final error in [
    Exception('network details'),
    Error(),
    StateError('network details'),
    TypeError(),
  ]) {
    test('keeps the current session and sanitizes ${error.runtimeType} from logout', () async {
      final auth = _FakeCoeloAuthGateway(signOutException: error);
      final session = SuperadminSession()..signInForTesting();
      addTearDown(session.dispose);
      final logout = createCoeloAuthLogoutAction(auth: auth, session: session);
      final revision = session.authorizationInvalidationRevision;

      final result = await logout();

      expect(result.isSuccess, isFalse);
      expect(result.message, LogoutResult.genericFailureMessage);
      expect(result.message, isNot(contains('network details')));
      expect(session.isAuthenticated, isTrue);
      expect(session.authorizationInvalidationRevision, revision);
      expect(auth.signOutCalls, 1);
    });

    test('does not restore a session already cleared before ${error.runtimeType}', () async {
      final session = SuperadminSession()..signInForTesting();
      addTearDown(session.dispose);
      final auth = _FakeCoeloAuthGateway(signOutException: error, onSignOut: session.signOut);
      final logout = createCoeloAuthLogoutAction(auth: auth, session: session);

      final result = await logout();

      expect(result.isSuccess, isFalse);
      expect(result.message, LogoutResult.genericFailureMessage);
      expect(session.isAuthenticated, isFalse);
      expect(session.authContext, isNull);
      expect(session.sessionId, isNull);
      expect(auth.signOutCalls, 1);
    });

    test(
      'keeps a newer authorization when the pending gateway fails with ${error.runtimeType}',
      () async {
        final auth = _FakeCoeloAuthGateway(
          signOutException: error,
          signOutStarted: Completer<void>(),
          signOutRelease: Completer<void>(),
        );
        final session = SuperadminSession()..signInForTesting();
        addTearDown(session.dispose);
        final logout = createCoeloAuthLogoutAction(auth: auth, session: session);
        final pending = logout();
        await auth.signOutStarted!.future;
        session.authorize(
          const SuperadminAuthContext(
            platformRoleCode: 'newer-role',
            scopeKind: SuperadminAuthScopeKind.platform,
            permissionCodes: {'platform.read', 'audit.read'},
            aal: 'aal1',
          ),
          sessionId: 'new-session',
        );
        final revision = session.authorizationInvalidationRevision;
        auth.signOutRelease!.complete();
        final result = await pending;

        expect(result.isSuccess, isFalse);
        expect(result.message, LogoutResult.genericFailureMessage);
        expect(session.isAuthenticated, isTrue);
        expect(session.sessionId, 'new-session');
        expect(session.authContext!.platformRoleCode, 'newer-role');
        expect(session.authorizationInvalidationRevision, revision);
        expect(auth.signOutCalls, 1);
      },
    );
  }

  for (final changeSessionId in [true, false]) {
    test(
      'does not clear a newer authorization when session ID changes: $changeSessionId',
      () async {
        final auth = _FakeCoeloAuthGateway(
          signOutStarted: Completer<void>(),
          signOutRelease: Completer<void>(),
        );
        final session = SuperadminSession()..signInForTesting();
        addTearDown(session.dispose);
        final logout = createCoeloAuthLogoutAction(auth: auth, session: session);

        final resultFuture = logout();
        await auth.signOutStarted!.future;
        final newerSessionId = changeSessionId ? 'new-session' : session.sessionId!;
        session.authorize(
          const SuperadminAuthContext(
            platformRoleCode: 'newer-role',
            scopeKind: SuperadminAuthScopeKind.platform,
            permissionCodes: {'platform.read'},
            aal: 'aal1',
          ),
          sessionId: newerSessionId,
        );
        auth.signOutRelease!.complete();
        final result = await resultFuture;

        expect(result.isSuccess, isTrue);
        expect(session.isAuthenticated, isTrue);
        expect(session.sessionId, newerSessionId);
        expect(session.authContext!.platformRoleCode, 'newer-role');
        expect(auth.signOutCalls, 1);
      },
    );
  }

  test(
    'reports failed local teardown after a completed gateway logout without leaking Error',
    () async {
      final auth = _FakeCoeloAuthGateway(
        signOutStarted: Completer<void>(),
        signOutRelease: Completer<void>(),
      );
      final session = SuperadminSession()..signInForTesting();
      addTearDown(session.dispose);
      final logout = createCoeloAuthLogoutAction(auth: auth, session: session);
      final pending = logout();
      await auth.signOutStarted!.future;
      session.dispose();
      auth.signOutRelease!.complete();

      final result = await pending;

      expect(result.isSuccess, isFalse);
      expect(result.message, LogoutResult.genericFailureMessage);
      expect(auth.didSignOut, isTrue);
      expect(auth.signOutCalls, 1);
      expect(session.isAuthenticated, isFalse);
    },
  );
}

final class _FakeCoeloAuthGateway extends CoeloAuthLifecycleGateway {
  _FakeCoeloAuthGateway({
    this.signOutException,
    this.signOutStarted,
    this.signOutRelease,
    this.onSignOut,
  });

  final Object? signOutException;
  final Completer<void>? signOutStarted;
  final Completer<void>? signOutRelease;
  final void Function()? onSignOut;
  bool didSignOut = false;
  int signOutCalls = 0;

  @override
  Stream<CoeloAuthSessionState> get authSessionStateChanges =>
      const Stream<CoeloAuthSessionState>.empty();

  @override
  CoeloAuthSessionState get currentSessionState => const CoeloAuthSessionState.signedOut();

  @override
  Future<CoeloAuthPasswordRecoveryResult> requestPasswordRecoveryWithRedirect({
    required String email,
    required Uri redirectTo,
  }) async {
    return const CoeloAuthPasswordRecoveryResult.success();
  }

  @override
  Future<CoeloAuthPasswordUpdateResult> updatePassword({required String password}) async =>
      const CoeloAuthPasswordUpdateResult.success();

  @override
  Future<CoeloAuthSignInResult> signInWithPassword({
    required String email,
    required String password,
    required bool persistSession,
  }) async {
    return const CoeloAuthSignInResult.success();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    signOutStarted?.complete();
    if (signOutRelease case final release?) {
      await release.future;
    }
    onSignOut?.call();
    if (signOutException case final exception?) {
      throw exception;
    }
    didSignOut = true;
  }
}
