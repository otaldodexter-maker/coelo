import 'dart:async';

import 'dart:convert';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final boundaryFailures = <String, Object>{
    'Exception': Exception('synthetic provider detail'),
    'StateError': StateError('synthetic provider detail'),
    'TypeError': TypeError(),
    'Error': AssertionError('synthetic provider detail'),
  };
  for (final entry in boundaryFailures.entries) {
    test('login persistence contains ${entry.key} and releases lock', () async {
      final events = <String>[];
      final persistence = _FakeSessionPersistence(
        events: events,
        failure: entry.value,
      );
      final gateway = SupabaseCoeloAuthGateway.test(
        _FakeSupabaseAuthApi(signInSucceeds: true, events: events),
        sessionPersistence: persistence,
      );
      final result = await gateway.signInWithPassword(
        email: 'synthetic@example.invalid',
        password: 'synthetic-password',
        persistSession: false,
      );
      expect(result.isSuccess, isFalse);
      expect(result.message, CoeloAuthSignInResult.genericFailureMessage);
      expect(events, ['persistence:false']);
      persistence.failure = null;
      expect(
        (await gateway.signInWithPassword(
          email: 'synthetic@example.invalid',
          password: 'synthetic-password',
          persistSession: false,
        )).isSuccess,
        isTrue,
      );
    });

    test('login API contains ${entry.key} and releases lock', () async {
      final api = _FakeSupabaseAuthApi(
        signInSucceeds: true,
        signInException: entry.value,
      );
      final gateway = SupabaseCoeloAuthGateway.test(
        api,
        sessionPersistence: _FakeSessionPersistence(),
      );
      final result = await gateway.signInWithPassword(
        email: 'synthetic@example.invalid',
        password: 'synthetic-password',
        persistSession: false,
      );
      expect(result.isSuccess, isFalse);
      expect(result.message, CoeloAuthSignInResult.genericFailureMessage);
      api.signInException = null;
      expect(
        (await gateway.signInWithPassword(
          email: 'synthetic@example.invalid',
          password: 'synthetic-password',
          persistSession: false,
        )).isSuccess,
        isTrue,
      );
    });

    test('recovery contains ${entry.key} with and without redirect', () async {
      final gateway = SupabaseCoeloAuthGateway.test(
        _FakeSupabaseAuthApi(passwordRecoveryException: entry.value),
        sessionPersistence: _FakeSessionPersistence(),
      );
      for (final result in [
        await gateway.requestPasswordRecovery(
          email: 'synthetic@example.invalid',
        ),
        await gateway.requestPasswordRecoveryWithRedirect(
          email: 'synthetic@example.invalid',
          redirectTo: Uri.parse('http://127.0.0.1/reset-password'),
        ),
      ]) {
        expect(result.isSuccess, isFalse);
        expect(
          result.message,
          CoeloAuthPasswordRecoveryResult.genericFailureMessage,
        );
      }
    });

    test(
      'password write contains ${entry.key} without cleanup or retry',
      () async {
        final events = <String>[];
        final api = _FakeSupabaseAuthApi(
          sessionState: const CoeloAuthSessionState.passwordRecovery(),
          passwordUpdateException: entry.value,
          events: events,
        );
        final gateway = SupabaseCoeloAuthGateway.test(
          api,
          sessionPersistence: _FakeSessionPersistence(),
        );
        final result = await gateway.updatePassword(
          password: 'synthetic-password',
        );
        expect(result.isSuccess, isFalse);
        expect(
          result.message,
          CoeloAuthPasswordUpdateResult.genericFailureMessage,
        );
        expect(events, ['update-password']);
        expect(api.didSignOut, isFalse);
        api.passwordUpdateException = null;
        expect(
          (await gateway.updatePassword(
            password: 'new-synthetic-password',
          )).isSuccess,
          isTrue,
        );
      },
    );

    test('confirmed password distinguishes cleanup ${entry.key}', () async {
      final events = <String>[];
      final gateway = SupabaseCoeloAuthGateway.test(
        _FakeSupabaseAuthApi(
          sessionState: const CoeloAuthSessionState.passwordRecovery(),
          signOutException: entry.value,
          events: events,
        ),
        sessionPersistence: _FakeSessionPersistence(),
      );
      final result = await gateway.updatePassword(
        password: 'synthetic-password',
      );
      expect(result.isSuccess, isFalse);
      expect(
        result.message,
        'A senha foi alterada, mas não foi possível confirmar o encerramento da sessão.',
      );
      expect(events, ['update-password', 'sign-out']);
    });
  }

  test(
    'password update preserves a replacement session without cleanup',
    () async {
      final events = <String>[];
      const replacement = CoeloAuthSessionState.authenticated(
        sessionId: 'new-session',
      );
      late final _FakeSupabaseAuthApi api;
      api = _FakeSupabaseAuthApi(
        sessionState: const CoeloAuthSessionState.passwordRecovery(
          sessionId: 'recovery-session',
        ),
        events: events,
        beforePasswordUpdate: () async {
          api.currentSessionState = replacement;
        },
      );
      final gateway = SupabaseCoeloAuthGateway.test(
        api,
        sessionPersistence: _FakeSessionPersistence(),
      );
      final result = await gateway.updatePassword(
        password: 'synthetic-password',
      );
      expect(result.isSuccess, isFalse);
      expect(api.currentSessionState, replacement);
      expect(events, ['update-password']);
      expect(api.didSignOut, isFalse);
    },
  );

  test(
    'cleanup error preserves a concurrently replaced session and releases lock',
    () async {
      final events = <String>[];
      const replacement = CoeloAuthSessionState.authenticated(
        sessionId: 'new-session',
      );
      late final _FakeSupabaseAuthApi api;
      api = _FakeSupabaseAuthApi(
        sessionState: const CoeloAuthSessionState.passwordRecovery(
          sessionId: 'recovery-session',
        ),
        events: events,
        signInSucceeds: true,
        beforeSignOut: () async {
          api.currentSessionState = replacement;
          throw StateError('synthetic cleanup detail');
        },
      );
      final gateway = SupabaseCoeloAuthGateway.test(
        api,
        sessionPersistence: _FakeSessionPersistence(),
      );
      final result = await gateway.updatePassword(
        password: 'synthetic-password',
      );
      expect(result.isSuccess, isFalse);
      expect(
        result.message,
        'A senha foi alterada, mas não foi possível confirmar o encerramento da sessão.',
      );
      expect(api.currentSessionState, replacement);
      expect(events, ['update-password', 'sign-out']);
      expect(
        (await gateway.signInWithPassword(
          email: 'synthetic@example.invalid',
          password: 'synthetic-password',
          persistSession: false,
        )).isSuccess,
        isTrue,
      );
    },
  );

  for (final fails in [false, true]) {
    test(
      'password update is single-flight and releases after failure=$fails',
      () async {
        final started = Completer<void>();
        final finish = Completer<void>();
        final events = <String>[];
        final api = _FakeSupabaseAuthApi(
          sessionState: const CoeloAuthSessionState.passwordRecovery(),
          events: events,
          beforePasswordUpdate: () async {
            if (!started.isCompleted) started.complete();
            await finish.future;
            if (fails) throw Exception('synthetic failure');
          },
        );
        final gateway = SupabaseCoeloAuthGateway.test(
          api,
          sessionPersistence: _FakeSessionPersistence(),
        );
        final first = gateway.updatePassword(
          password: 'first-synthetic-password',
        );
        await started.future;
        final second = gateway.updatePassword(
          password: 'second-synthetic-password',
        );
        finish.complete();
        expect((await first).isSuccess, !fails);
        expect((await second).isSuccess, isFalse);
        expect(
          events.where((event) => event == 'update-password'),
          hasLength(1),
        );
        expect(api.lastUpdatedPassword, 'first-synthetic-password');
        if (fails) {
          await gateway.updatePassword(password: 'retry-synthetic-password');
          expect(
            events.where((event) => event == 'update-password'),
            hasLength(2),
          );
        }
      },
    );
  }

  test('extracts only a valid session_id from the access token payload', () {
    String token(Object payload) =>
        'header.${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}.signature';

    expect(
      coeloAuthSessionIdFromAccessToken(
        token({'session_id': '11111111-1111-4111-8111-111111111111'}),
      ),
      '11111111-1111-4111-8111-111111111111',
    );
    expect(
      coeloAuthSessionIdFromAccessToken(token({'session_id': 'not-a-uuid'})),
      isNull,
    );
    expect(coeloAuthSessionIdFromAccessToken('malformed'), isNull);
  });

  test(
    'maps a successful password sign-in to a reusable success result',
    () async {
      final persistence = _FakeSessionPersistence();
      final gateway = SupabaseCoeloAuthGateway.test(
        _FakeSupabaseAuthApi(isAuthenticated: false, signInSucceeds: true),
        sessionPersistence: persistence,
      );

      final result = await gateway.signInWithPassword(
        email: 'owner@coelo.me',
        password: 'secret-password',
        persistSession: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.message, isNull);
      expect(persistence.isEnabled, isTrue);
    },
  );

  test(
    'disables persistence before a non-persistent password sign-in',
    () async {
      final events = <String>[];
      final persistence = _FakeSessionPersistence(events: events);
      final gateway = SupabaseCoeloAuthGateway.test(
        _FakeSupabaseAuthApi(
          isAuthenticated: false,
          signInSucceeds: true,
          events: events,
        ),
        sessionPersistence: persistence,
      );

      final result = await gateway.signInWithPassword(
        email: 'owner@coelo.me',
        password: 'secret-password',
        persistSession: false,
      );

      expect(result.isSuccess, isTrue);
      expect(persistence.isEnabled, isFalse);
      expect(events, <String>['persistence:false', 'sign-in']);
    },
  );

  test('converts auth failures into a safe generic login message', () async {
    final gateway = SupabaseCoeloAuthGateway.test(
      _FakeSupabaseAuthApi(
        isAuthenticated: false,
        signInException: Exception('bad credentials'),
      ),
      sessionPersistence: _FakeSessionPersistence(),
    );

    final result = await gateway.signInWithPassword(
      email: 'owner@coelo.me',
      password: 'wrong-password',
      persistSession: false,
    );

    expect(result.isSuccess, isFalse);
    expect(result.message, CoeloAuthSignInResult.genericFailureMessage);
    expect(result.message, isNot(contains('wrong-password')));
  });

  test(
    'rejects a password response without an authenticated session',
    () async {
      final gateway = SupabaseCoeloAuthGateway.test(
        _FakeSupabaseAuthApi(isAuthenticated: false, signInSucceeds: false),
        sessionPersistence: _FakeSessionPersistence(),
      );

      final result = await gateway.signInWithPassword(
        email: 'owner@coelo.me',
        password: 'secret-password',
        persistSession: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.message, CoeloAuthSignInResult.genericFailureMessage);
    },
  );

  test(
    'exposes auth state changes as an authentication boolean stream',
    () async {
      final controller = StreamController<CoeloAuthSessionState>();
      addTearDown(controller.close);
      final gateway = SupabaseCoeloAuthGateway.test(
        _FakeSupabaseAuthApi(
          isAuthenticated: false,
          authStateChanges: controller.stream,
        ),
        sessionPersistence: _FakeSessionPersistence(),
      );

      expect(gateway.isAuthenticated, isFalse);
      expectLater(
        gateway.authStateChanges,
        emitsInOrder(const <bool>[true, false]),
      );

      controller.add(const CoeloAuthSessionState.authenticated());
      controller.add(const CoeloAuthSessionState.passwordRecovery());
      controller.add(const CoeloAuthSessionState.signedOut());
    },
  );

  test(
    'keeps the legacy gateway contract independently implementable',
    () async {
      final CoeloAuthGateway gateway = _LegacyCoeloAuthGateway();

      expect(gateway.isAuthenticated, isFalse);
      expect(await gateway.authStateChanges.toList(), isEmpty);
      expect(
        (await gateway.requestPasswordRecovery(
          email: 'owner@coelo.me',
        )).isSuccess,
        isTrue,
      );
    },
  );

  test('keeps an unavailable environment safe and explicit', () async {
    const gateway = UnavailableCoeloAuthGateway();

    final result = await gateway.signInWithPassword(
      email: 'owner@coelo.me',
      password: 'secret-password',
      persistSession: false,
    );

    expect(gateway.isAuthenticated, isFalse);
    expect(result.isSuccess, isFalse);
    expect(result.message, UnavailableCoeloAuthGateway.defaultMessage);
  });

  test('delegates sign-out to the Supabase auth API', () async {
    final api = _FakeSupabaseAuthApi(isAuthenticated: true);
    final gateway = SupabaseCoeloAuthGateway.test(
      api,
      sessionPersistence: _FakeSessionPersistence(),
    );

    await gateway.signOut();

    expect(api.didSignOut, isTrue);
  });

  test('requests password recovery without exposing account state', () async {
    final api = _FakeSupabaseAuthApi(isAuthenticated: false);
    final gateway = SupabaseCoeloAuthGateway.test(
      api,
      sessionPersistence: _FakeSessionPersistence(),
    );

    final result = await gateway.requestPasswordRecoveryWithRedirect(
      email: 'owner@coelo.me',
      redirectTo: Uri.parse('http://127.0.0.1:8766/reset-password'),
    );

    expect(result.isSuccess, isTrue);
    expect(result.message, isNull);
    expect(api.lastRecoveryEmail, 'owner@coelo.me');
    expect(
      api.lastRecoveryRedirect,
      Uri.parse('http://127.0.0.1:8766/reset-password'),
    );
  });

  test(
    'preserves password recovery without redirect for legacy consumers',
    () async {
      final api = _FakeSupabaseAuthApi(isAuthenticated: false);
      final CoeloAuthGateway gateway = SupabaseCoeloAuthGateway.test(
        api,
        sessionPersistence: _FakeSessionPersistence(),
      );

      final result = await gateway.requestPasswordRecovery(
        email: 'catalogo@coelo.me',
      );

      expect(result.isSuccess, isTrue);
      expect(api.lastRecoveryEmail, 'catalogo@coelo.me');
      expect(api.lastRecoveryRedirect, isNull);
    },
  );

  test('maps password recovery failures to a safe generic message', () async {
    final gateway = SupabaseCoeloAuthGateway.test(
      _FakeSupabaseAuthApi(
        isAuthenticated: false,
        passwordRecoveryException: Exception('sensitive provider detail'),
      ),
      sessionPersistence: _FakeSessionPersistence(),
    );

    final result = await gateway.requestPasswordRecoveryWithRedirect(
      email: 'owner@coelo.me',
      redirectTo: Uri.parse('http://127.0.0.1:8766/reset-password'),
    );

    expect(result.isSuccess, isFalse);
    expect(
      result.message,
      CoeloAuthPasswordRecoveryResult.genericFailureMessage,
    );
    expect(result.message, isNot(contains('sensitive provider detail')));
  });

  test('keeps password recovery unavailable without Supabase config', () async {
    const gateway = UnavailableCoeloAuthGateway();

    final result = await gateway.requestPasswordRecoveryWithRedirect(
      email: 'owner@coelo.me',
      redirectTo: Uri.parse('http://127.0.0.1:8766/reset-password'),
    );

    expect(result.isSuccess, isFalse);
    expect(result.message, UnavailableCoeloAuthGateway.defaultMessage);
  });

  test(
    'preserves password recovery as a distinct authenticated state',
    () async {
      final controller = StreamController<CoeloAuthSessionState>();
      addTearDown(controller.close);
      final gateway = SupabaseCoeloAuthGateway.test(
        _FakeSupabaseAuthApi(
          sessionState: const CoeloAuthSessionState.passwordRecovery(),
          authStateChanges: controller.stream,
        ),
        sessionPersistence: _FakeSessionPersistence(),
      );

      expect(gateway.currentSessionState.isAuthenticated, isTrue);
      expect(gateway.currentSessionState.isPasswordRecovery, isTrue);
      expect(gateway.isAuthenticated, isFalse);
      expectLater(
        gateway.authSessionStateChanges,
        emitsInOrder(const <CoeloAuthSessionState>[
          CoeloAuthSessionState.passwordRecovery(),
          CoeloAuthSessionState.signedOut(),
        ]),
      );

      controller
        ..add(const CoeloAuthSessionState.passwordRecovery())
        ..add(const CoeloAuthSessionState.signedOut());
    },
  );

  test('updates the password then revokes the recovery session', () async {
    final events = <String>[];
    final api = _FakeSupabaseAuthApi(
      sessionState: const CoeloAuthSessionState.passwordRecovery(),
      events: events,
    );
    final gateway = SupabaseCoeloAuthGateway.test(
      api,
      sessionPersistence: _FakeSessionPersistence(),
    );

    final result = await gateway.updatePassword(
      password: 'new-secret-password',
    );

    expect(result.isSuccess, isTrue);
    expect(result.message, isNull);
    expect(events, <String>['update-password', 'sign-out']);
    expect(api.lastUpdatedPassword, 'new-secret-password');
  });

  test('rejects password updates outside a recovery session', () async {
    final events = <String>[];
    final gateway = SupabaseCoeloAuthGateway.test(
      _FakeSupabaseAuthApi(
        sessionState: const CoeloAuthSessionState.authenticated(),
        events: events,
      ),
      sessionPersistence: _FakeSessionPersistence(),
    );

    final result = await gateway.updatePassword(
      password: 'new-secret-password',
    );

    expect(result.isSuccess, isFalse);
    expect(events, isEmpty);
  });

  test(
    'fails closed locally when revocation fails after password update',
    () async {
      final events = <String>[];
      final api = _FakeSupabaseAuthApi(
        sessionState: const CoeloAuthSessionState.passwordRecovery(),
        signOutException: Exception('network unavailable'),
        events: events,
      );
      final gateway = SupabaseCoeloAuthGateway.test(
        api,
        sessionPersistence: _FakeSessionPersistence(),
      );

      final result = await gateway.updatePassword(
        password: 'new-secret-password',
      );

      expect(result.isSuccess, isFalse);
      expect(events, <String>['update-password', 'sign-out']);
      expect(gateway.currentSessionState.isAuthenticated, isFalse);
    },
  );

  test(
    'maps password update failures without exposing provider detail or password',
    () async {
      final gateway = SupabaseCoeloAuthGateway.test(
        _FakeSupabaseAuthApi(
          sessionState: const CoeloAuthSessionState.passwordRecovery(),
          passwordUpdateException: Exception(
            'provider said new-secret-password',
          ),
        ),
        sessionPersistence: _FakeSessionPersistence(),
      );

      final result = await gateway.updatePassword(
        password: 'new-secret-password',
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.message,
        CoeloAuthPasswordUpdateResult.genericFailureMessage,
      );
      expect(result.message, isNot(contains('new-secret-password')));
      expect(result.message, isNot(contains('provider')));
    },
  );
}

final class _LegacyCoeloAuthGateway implements CoeloAuthGateway {
  @override
  bool get isAuthenticated => false;

  @override
  Stream<bool> get authStateChanges => const Stream<bool>.empty();

  @override
  Future<CoeloAuthSignInResult> signInWithPassword({
    required String email,
    required String password,
    required bool persistSession,
  }) async => const CoeloAuthSignInResult.failure(
    CoeloAuthSignInResult.genericFailureMessage,
  );

  @override
  Future<CoeloAuthPasswordRecoveryResult> requestPasswordRecovery({
    required String email,
  }) async => const CoeloAuthPasswordRecoveryResult.success();

  @override
  Future<void> signOut() async {}
}

final class _FakeSupabaseAuthApi implements CoeloSupabaseAuthApi {
  _FakeSupabaseAuthApi({
    bool isAuthenticated = false,
    CoeloAuthSessionState? sessionState,
    this.signInSucceeds = false,
    this.signInException,
    this.passwordRecoveryException,
    Stream<CoeloAuthSessionState>? authStateChanges,
    this.events,
    this.passwordUpdateException,
    this.signOutException,
    this.beforePasswordUpdate,
    this.beforeSignOut,
  }) : currentSessionState =
           sessionState ??
           (isAuthenticated
               ? const CoeloAuthSessionState.authenticated()
               : const CoeloAuthSessionState.signedOut()),
       authStateChanges =
           authStateChanges ?? const Stream<CoeloAuthSessionState>.empty();

  @override
  final Stream<CoeloAuthSessionState> authStateChanges;

  @override
  CoeloAuthSessionState currentSessionState;

  final bool signInSucceeds;
  Object? signInException;
  final Object? passwordRecoveryException;
  Object? passwordUpdateException;
  final Object? signOutException;
  final Future<void> Function()? beforePasswordUpdate;
  final Future<void> Function()? beforeSignOut;
  final List<String>? events;
  bool didSignOut = false;
  String? lastRecoveryEmail;
  Uri? lastRecoveryRedirect;
  String? lastUpdatedPassword;

  @override
  Future<void> requestPasswordRecovery({
    required String email,
    Uri? redirectTo,
  }) async {
    lastRecoveryEmail = email;
    lastRecoveryRedirect = redirectTo;
    if (passwordRecoveryException case final exception?) {
      throw exception;
    }
  }

  @override
  Future<void> updatePassword({required String password}) async {
    events?.add('update-password');
    lastUpdatedPassword = password;
    await beforePasswordUpdate?.call();
    if (passwordUpdateException case final exception?) {
      throw exception;
    }
  }

  @override
  Future<bool> signInWithPassword({
    required String email,
    required String password,
  }) async {
    events?.add('sign-in');
    if (signInException case final exception?) {
      throw exception;
    }
    return signInSucceeds;
  }

  @override
  Future<void> signOut() async {
    events?.add('sign-out');
    didSignOut = true;
    await beforeSignOut?.call();
    currentSessionState = const CoeloAuthSessionState.signedOut();
    if (signOutException case final exception?) {
      throw exception;
    }
  }
}

final class _FakeSessionPersistence implements CoeloAuthSessionPersistence {
  _FakeSessionPersistence({this.events, this.failure});

  final List<String>? events;
  bool? isEnabled;
  Object? failure;

  @override
  Future<void> setPersistenceEnabled({required bool value}) async {
    isEnabled = value;
    events?.add('persistence:$value');
    if (failure case final error?) throw error;
  }
}
