import 'dart:async';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/coelo_auth_login_action.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = LoginRequest(
    email: 'owner@coelo.me',
    password: 'secret-password',
    keepSessionOpen: false,
  );

  test('forwards credentials to Coelo auth and signs the session in on success', () async {
    final auth = _FakeCoeloAuthGateway();
    final session = SuperadminSession();
    addTearDown(session.dispose);

    final context = _FakeSuperadminAuthContextGateway();
    final action = createCoeloAuthLoginAction(auth: auth, authContext: context, session: session);
    final result = await action(request);

    expect(auth.lastEmail, request.email);
    expect(auth.lastPassword, request.password);
    expect(auth.persistSession, isFalse);
    expect(result.isSuccess, isTrue);
    expect(session.isAuthenticated, isTrue);
    expect(session.authContext?.platformRoleCode, 'operations');
    expect(context.bootstrapCalls, 1);
  });

  test('requests persistent storage when keep session open is selected', () async {
    final auth = _FakeCoeloAuthGateway();
    final session = SuperadminSession();
    addTearDown(session.dispose);

    final action = createCoeloAuthLoginAction(
      auth: auth,
      authContext: _FakeSuperadminAuthContextGateway(),
      session: session,
    );
    final result = await action(
      const LoginRequest(
        email: 'owner@coelo.me',
        password: 'secret-password',
        keepSessionOpen: true,
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(auth.persistSession, isTrue);
  });

  test('keeps the session signed out and returns a safe failure from Coelo auth', () async {
    final auth = _FakeCoeloAuthGateway(
      nextResult: const CoeloAuthSignInResult.failure(CoeloAuthSignInResult.genericFailureMessage),
    );
    final session = SuperadminSession();
    addTearDown(session.dispose);

    final action = createCoeloAuthLoginAction(
      auth: auth,
      authContext: _FakeSuperadminAuthContextGateway(),
      session: session,
    );
    final result = await action(request);

    expect(result.isSuccess, isFalse);
    expect(result.message, CoeloAuthSignInResult.genericFailureMessage);
    expect(session.isAuthenticated, isFalse);
  });

  test('revokes the credential session when internal bootstrap is denied', () async {
    final auth = _FakeCoeloAuthGateway();
    final session = SuperadminSession();
    addTearDown(session.dispose);
    final action = createCoeloAuthLoginAction(
      auth: auth,
      authContext: _FakeSuperadminAuthContextGateway(isAuthorized: false),
      session: session,
    );

    final result = await action(request);

    expect(result.isSuccess, isFalse);
    expect(result.message, CoeloAuthSignInResult.genericFailureMessage);
    expect(auth.signOutCalls, 1);
    expect(session.isAuthenticated, isFalse);
    expect(session.authContext, isNull);
  });

  test('revokes when the credential session changes during internal bootstrap', () async {
    final auth = _FakeCoeloAuthGateway();
    final session = SuperadminSession();
    final context = _PendingSuperadminAuthContextGateway();
    addTearDown(session.dispose);
    final action = createCoeloAuthLoginAction(auth: auth, authContext: context, session: session);

    final resultFuture = action(request);
    await context.started.future;
    auth.sessionId = _sessionB;
    context.completeAuthorized();
    final result = await resultFuture;

    expect(result.isSuccess, isFalse);
    expect(auth.signOutCalls, 1);
    expect(session.isAuthenticated, isFalse);
  });
}

const _context = SuperadminAuthContext(
  platformRoleCode: 'operations',
  scopeKind: SuperadminAuthScopeKind.platform,
  permissionCodes: {'platform.read'},
  aal: 'aal1',
);

final class _FakeSuperadminAuthContextGateway implements SuperadminAuthContextGateway {
  _FakeSuperadminAuthContextGateway({this.isAuthorized = true});

  final bool isAuthorized;
  int bootstrapCalls = 0;

  @override
  Future<SuperadminAuthContext?> bootstrap() async {
    bootstrapCalls++;
    return isAuthorized ? _context : null;
  }
}

final class _PendingSuperadminAuthContextGateway implements SuperadminAuthContextGateway {
  final started = Completer<void>();
  final _result = Completer<SuperadminAuthContext?>();

  void completeAuthorized() => _result.complete(_context);

  @override
  Future<SuperadminAuthContext?> bootstrap() {
    started.complete();
    return _result.future;
  }
}

final class _FakeCoeloAuthGateway extends CoeloAuthLifecycleGateway {
  _FakeCoeloAuthGateway({this.nextResult = const CoeloAuthSignInResult.success()});

  String? lastEmail;
  String? lastPassword;
  bool? persistSession;
  final CoeloAuthSignInResult nextResult;
  int signOutCalls = 0;
  String sessionId = _sessionA;
  bool _isSignedOut = false;

  @override
  Stream<CoeloAuthSessionState> get authSessionStateChanges =>
      const Stream<CoeloAuthSessionState>.empty();

  @override
  CoeloAuthSessionState get currentSessionState => nextResult.isSuccess && !_isSignedOut
      ? CoeloAuthSessionState.authenticated(sessionId: sessionId)
      : const CoeloAuthSessionState.signedOut();

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
    lastEmail = email;
    lastPassword = password;
    this.persistSession = persistSession;
    return nextResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _isSignedOut = true;
  }
}

const _sessionA = '11111111-1111-4111-8111-111111111111';
const _sessionB = '22222222-2222-4222-8222-222222222222';
