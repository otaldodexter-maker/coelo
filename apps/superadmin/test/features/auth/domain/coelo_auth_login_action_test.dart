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

  test('authorization waits for media purge before committing the session', () async {
    final auth = _FakeCoeloAuthGateway();
    final session = SuperadminSession();
    addTearDown(session.dispose);
    final started = Completer<void>();
    final purge = Completer<bool>();
    var committed = false;
    final action = createCoeloAuthLoginAction(
      auth: auth,
      authContext: _FakeSuperadminAuthContextGateway(),
      session: session,
      prepareAuthorization: () {
        started.complete();
        return purge.future;
      },
      onAuthorizationCommitted: () {
        expect(session.isAuthenticated, isTrue);
        committed = true;
      },
    );
    final pending = action(request);
    await started.future;
    expect(session.isAuthenticated, isFalse);
    expect(committed, isFalse);
    purge.complete(true);
    expect((await pending).isSuccess, isTrue);
    expect(committed, isTrue);
  });

  test('credential replacement during media purge cannot authorize old bootstrap', () async {
    final auth = _FakeCoeloAuthGateway();
    final session = SuperadminSession();
    addTearDown(session.dispose);
    final started = Completer<void>();
    final purge = Completer<bool>();
    var committed = false;
    final action = createCoeloAuthLoginAction(
      auth: auth,
      authContext: _FakeSuperadminAuthContextGateway(),
      session: session,
      prepareAuthorization: () {
        started.complete();
        return purge.future;
      },
      onAuthorizationCommitted: () => committed = true,
    );
    final pending = action(request);
    await started.future;
    auth.sessionId = _sessionB;
    purge.complete(true);
    expect((await pending).isSuccess, isFalse);
    expect(session.isAuthenticated, isFalse);
    expect(committed, isFalse);
    expect(auth.signOutCalls, 0);
    expect(auth.currentSessionState.sessionId, _sessionB);
  });

  for (final throwsError in [false, true]) {
    test('failed media purge denies authorization safely (throws=$throwsError)', () async {
      final auth = _FakeCoeloAuthGateway();
      final session = SuperadminSession();
      addTearDown(session.dispose);
      var committed = false;
      final action = createCoeloAuthLoginAction(
        auth: auth,
        authContext: _FakeSuperadminAuthContextGateway(),
        session: session,
        prepareAuthorization: () async {
          if (throwsError) throw StateError('private capability');
          return false;
        },
        onAuthorizationCommitted: () => committed = true,
      );
      final result = await action(request);
      expect(result.isSuccess, isFalse);
      expect(result.message, CoeloAuthSignInResult.genericFailureMessage);
      expect(session.isAuthenticated, isFalse);
      expect(committed, isFalse);
      expect(auth.signOutCalls, 1);
    });
  }

  test('obsolete bootstrap cannot purge the winning authorization', () async {
    final auth = _FakeCoeloAuthGateway();
    final session = SuperadminSession();
    addTearDown(session.dispose);
    final context = _PendingSuperadminAuthContextGateway();
    var purgeCalls = 0;
    final action = createCoeloAuthLoginAction(
      auth: auth,
      authContext: context,
      session: session,
      prepareAuthorization: () async {
        purgeCalls++;
        return true;
      },
    );
    final pending = action(request);
    await context.started.future;
    auth.sessionId = _sessionB;
    session.authorize(_context, sessionId: _sessionB);
    context.completeAuthorized();
    expect((await pending).isSuccess, isFalse);
    expect(purgeCalls, 0);
    expect(auth.signOutCalls, 0);
    expect(session.sessionId, _sessionB);
  });

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

  test('preserves replacement credentials still awaiting internal bootstrap', () async {
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
    expect(auth.signOutCalls, 0);
    expect(auth.currentSessionState.sessionId, _sessionB);
    expect(session.isAuthenticated, isFalse);
  });

  for (final recoveryId in [_sessionA, _sessionB, null]) {
    test('login cleanup respects observed recovery callback $recoveryId', () async {
      final states = StreamController<CoeloAuthSessionState>(sync: true);
      final auth = _FakeCoeloAuthGateway();
      final session = SuperadminSession(authSessionStateChanges: states.stream);
      addTearDown(states.close);
      addTearDown(session.dispose);
      final context = _PendingSuperadminAuthContextGateway();
      final action = createCoeloAuthLoginAction(auth: auth, authContext: context, session: session);
      final pending = action(request);
      await context.started.future;
      final recovery = CoeloAuthSessionState.passwordRecovery(sessionId: recoveryId);
      auth.stateOverride = recovery;
      states.add(recovery);
      context.completeDenied();
      final result = await pending;

      expect(result.isSuccess, isFalse);
      expect(session.isAuthenticated, isFalse);
      expect(auth.signOutCalls, recoveryId == null ? 1 : 0);
      expect(session.isPasswordRecovery, recoveryId != null);
    });
  }

  test('does not sign out a newer winning session after stale bootstrap', () async {
    final auth = _FakeCoeloAuthGateway();
    final session = SuperadminSession();
    final context = _PendingSuperadminAuthContextGateway();
    addTearDown(session.dispose);
    final action = createCoeloAuthLoginAction(auth: auth, authContext: context, session: session);

    final resultFuture = action(request);
    await context.started.future;
    auth.sessionId = _sessionB;
    session.authorize(_context, sessionId: _sessionB);
    context.completeAuthorized();
    final result = await resultFuture;

    expect(result.isSuccess, isFalse);
    expect(auth.signOutCalls, 0);
    expect(session.isAuthenticated, isTrue);
    expect(session.authContext, _context);
  });

  test('does not sign out a reauthorized same session after stale bootstrap', () async {
    final auth = _FakeCoeloAuthGateway();
    final session = SuperadminSession();
    final context = _PendingSuperadminAuthContextGateway();
    addTearDown(session.dispose);
    final action = createCoeloAuthLoginAction(auth: auth, authContext: context, session: session);

    final resultFuture = action(request);
    await context.started.future;
    session.authorize(
      const SuperadminAuthContext(
        platformRoleCode: 'newer-role',
        scopeKind: SuperadminAuthScopeKind.platform,
        permissionCodes: {'platform.read'},
        aal: 'aal1',
      ),
      sessionId: _sessionA,
    );
    context.completeAuthorized();
    final result = await resultFuture;

    expect(result.isSuccess, isFalse);
    expect(auth.signOutCalls, 0);
    expect(session.isAuthenticated, isTrue);
    expect(session.sessionId, _sessionA);
  });

  test('revokes a previously authorized session when current bootstrap is denied', () async {
    final auth = _FakeCoeloAuthGateway();
    final session = SuperadminSession()..authorize(_context, sessionId: _sessionA);
    addTearDown(session.dispose);
    final action = createCoeloAuthLoginAction(
      auth: auth,
      authContext: _FakeSuperadminAuthContextGateway(isAuthorized: false),
      session: session,
    );

    final result = await action(request);

    expect(result.isSuccess, isFalse);
    expect(auth.signOutCalls, 1);
    expect(session.isAuthenticated, isFalse);
  });

  test('does not clear a winner authorized while sign out is pending', () async {
    final auth = _FakeCoeloAuthGateway(
      signOutStarted: Completer<void>(),
      signOutRelease: Completer<void>(),
    );
    final session = SuperadminSession();
    addTearDown(session.dispose);
    final action = createCoeloAuthLoginAction(
      auth: auth,
      authContext: _FakeSuperadminAuthContextGateway(isAuthorized: false),
      session: session,
    );

    final resultFuture = action(request);
    await auth.signOutStarted!.future;
    auth.sessionId = _sessionB;
    session.authorize(_context, sessionId: _sessionB);
    auth.signOutRelease!.complete();
    final result = await resultFuture;

    expect(result.isSuccess, isFalse);
    expect(session.isAuthenticated, isTrue);
    expect(session.sessionId, _sessionB);
  });

  test('clears a divergent authorization created before sign out began', () async {
    final auth = _FakeCoeloAuthGateway();
    final session = SuperadminSession();
    final context = _PendingSuperadminAuthContextGateway();
    addTearDown(session.dispose);
    final action = createCoeloAuthLoginAction(auth: auth, authContext: context, session: session);

    final resultFuture = action(request);
    await context.started.future;
    session.authorize(_context, sessionId: _sessionB);
    context.completeAuthorized();
    final result = await resultFuture;

    expect(result.isSuccess, isFalse);
    expect(session.isAuthenticated, isFalse);
  });

  final cleanupFailures = <String, Object Function()>{
    'Exception': () => Exception('synthetic cleanup failure'),
    'Error': Error.new,
    'StateError': () => StateError('synthetic cleanup failure'),
    'TypeError': TypeError.new,
  };
  for (final failure in cleanupFailures.entries) {
    for (final clearedCredentialSession in [false, true]) {
      test(
        'denied login sanitizes ${failure.key} after credential cleanup=$clearedCredentialSession',
        () async {
          final auth = _FakeCoeloAuthGateway(
            signOutError: failure.value(),
            clearCredentialSessionOnSignOut: clearedCredentialSession,
          );
          final session = SuperadminSession()..authorize(_context, sessionId: _sessionA);
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
          expect(session.sessionId, isNull);
          expect(
            auth.currentSessionState.kind,
            clearedCredentialSession
                ? CoeloAuthSessionKind.signedOut
                : CoeloAuthSessionKind.authenticated,
          );
        },
      );
    }

    for (final winnerSessionId in [_sessionA, _sessionB]) {
      test(
        'denied login preserves winner $winnerSessionId when cleanup throws ${failure.key}',
        () async {
          final auth = _FakeCoeloAuthGateway(
            signOutStarted: Completer<void>(),
            signOutRelease: Completer<void>(),
            signOutError: failure.value(),
          );
          final session = SuperadminSession();
          addTearDown(session.dispose);
          final action = createCoeloAuthLoginAction(
            auth: auth,
            authContext: _FakeSuperadminAuthContextGateway(isAuthorized: false),
            session: session,
          );

          final pending = action(request);
          await auth.signOutStarted!.future;
          auth.stateOverride = CoeloAuthSessionState.authenticated(sessionId: winnerSessionId);
          session.authorize(_context, sessionId: winnerSessionId);
          final winnerRevision = session.authorizationInvalidationRevision;
          auth.signOutRelease!.complete();
          final result = await pending;

          expect(result.isSuccess, isFalse);
          expect(result.message, CoeloAuthSignInResult.genericFailureMessage);
          expect(auth.signOutCalls, 1);
          expect(session.isAuthenticated, isTrue);
          expect(session.sessionId, winnerSessionId);
          expect(session.authContext, same(_context));
          expect(session.authorizationInvalidationRevision, winnerRevision);
        },
      );
    }
  }

  test(
    'a denied login cleanup Error releases single-flight for a later authorized login',
    () async {
      final auth = _FakeCoeloAuthGateway(signOutError: StateError('synthetic cleanup failure'));
      final context = _FakeSuperadminAuthContextGateway(isAuthorized: false);
      final session = SuperadminSession();
      addTearDown(session.dispose);
      final action = createCoeloAuthLoginAction(auth: auth, authContext: context, session: session);

      final denied = await action(request);
      expect(denied.isSuccess, isFalse);
      auth.signOutError = null;
      context.isAuthorized = true;
      final authorized = await action(request);

      expect(authorized.isSuccess, isTrue);
      expect(context.bootstrapCalls, 2);
      expect(auth.signOutCalls, 1);
      expect(session.isAuthenticated, isTrue);
      expect(session.sessionId, _sessionA);
    },
  );
}

const _context = SuperadminAuthContext(
  platformRoleCode: 'operations',
  scopeKind: SuperadminAuthScopeKind.platform,
  permissionCodes: {'platform.read'},
  aal: 'aal1',
);

final class _FakeSuperadminAuthContextGateway implements SuperadminAuthContextGateway {
  _FakeSuperadminAuthContextGateway({this.isAuthorized = true});

  bool isAuthorized;
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
  void completeDenied() => _result.complete(null);

  @override
  Future<SuperadminAuthContext?> bootstrap() {
    started.complete();
    return _result.future;
  }
}

final class _FakeCoeloAuthGateway extends CoeloAuthLifecycleGateway {
  _FakeCoeloAuthGateway({
    this.nextResult = const CoeloAuthSignInResult.success(),
    this.signOutStarted,
    this.signOutRelease,
    this.signOutError,
    this.clearCredentialSessionOnSignOut = true,
  });

  String? lastEmail;
  String? lastPassword;
  bool? persistSession;
  final CoeloAuthSignInResult nextResult;
  int signOutCalls = 0;
  final Completer<void>? signOutStarted;
  final Completer<void>? signOutRelease;
  Object? signOutError;
  final bool clearCredentialSessionOnSignOut;
  String sessionId = _sessionA;
  CoeloAuthSessionState? stateOverride;
  bool _isSignedOut = false;

  @override
  Stream<CoeloAuthSessionState> get authSessionStateChanges =>
      const Stream<CoeloAuthSessionState>.empty();

  @override
  CoeloAuthSessionState get currentSessionState =>
      stateOverride ??
      (nextResult.isSuccess && !_isSignedOut
          ? CoeloAuthSessionState.authenticated(sessionId: sessionId)
          : const CoeloAuthSessionState.signedOut());

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
    _isSignedOut = false;
    return nextResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (clearCredentialSessionOnSignOut) {
      stateOverride = null;
      _isSignedOut = true;
    }
    signOutStarted?.complete();
    if (signOutRelease case final release?) {
      await release.future;
    }
    if (signOutError case final error?) {
      throw error;
    }
  }
}

const _sessionA = '11111111-1111-4111-8111-111111111111';
const _sessionB = '22222222-2222-4222-8222-222222222222';
