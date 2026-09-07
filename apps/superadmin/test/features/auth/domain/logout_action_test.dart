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

  test('keeps the session state and returns a safe message when logout fails', () async {
    final auth = _FakeCoeloAuthGateway(signOutException: Exception('network details'));
    final session = SuperadminSession()..signInForTesting();
    addTearDown(session.dispose);
    final logout = createCoeloAuthLogoutAction(auth: auth, session: session);

    final result = await logout();

    expect(result.isSuccess, isFalse);
    expect(result.message, LogoutResult.genericFailureMessage);
    expect(result.message, isNot(contains('network details')));
    expect(session.isAuthenticated, isTrue);
  });

  test('does not clear a newer authorization while logout is pending', () async {
    final auth = _FakeCoeloAuthGateway(
      signOutStarted: Completer<void>(),
      signOutRelease: Completer<void>(),
    );
    final session = SuperadminSession()..signInForTesting();
    addTearDown(session.dispose);
    final logout = createCoeloAuthLogoutAction(auth: auth, session: session);

    final resultFuture = logout();
    await auth.signOutStarted!.future;
    session.authorize(
      const SuperadminAuthContext(
        platformRoleCode: 'newer-role',
        scopeKind: SuperadminAuthScopeKind.platform,
        permissionCodes: {'platform.read'},
        aal: 'aal1',
      ),
      sessionId: 'new-session',
    );
    auth.signOutRelease!.complete();
    final result = await resultFuture;

    expect(result.isSuccess, isTrue);
    expect(session.isAuthenticated, isTrue);
    expect(session.sessionId, 'new-session');
  });
}

final class _FakeCoeloAuthGateway extends CoeloAuthLifecycleGateway {
  _FakeCoeloAuthGateway({this.signOutException, this.signOutStarted, this.signOutRelease});

  final Exception? signOutException;
  final Completer<void>? signOutStarted;
  final Completer<void>? signOutRelease;
  bool didSignOut = false;

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
    if (signOutException case final exception?) {
      throw exception;
    }
    didSignOut = true;
    signOutStarted?.complete();
    if (signOutRelease case final release?) {
      await release.future;
    }
  }
}
