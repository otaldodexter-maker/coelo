import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'conditional_supabase_local_storage.dart';
import 'coelo_auth_gateway.dart';

abstract interface class CoeloSupabaseAuthApi {
  Stream<CoeloAuthSessionState> get authStateChanges;
  CoeloAuthSessionState get currentSessionState;

  Future<bool> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> requestPasswordRecovery({
    required String email,
    Uri? redirectTo,
  });

  Future<void> updatePassword({required String password});

  Future<void> signOut();
}

final class SupabaseCoeloAuthGateway extends CoeloAuthLifecycleGateway {
  SupabaseCoeloAuthGateway(
    SupabaseClient client, {
    required CoeloAuthSessionPersistence sessionPersistence,
    String? initialRecoveryAccessToken,
  }) : this.test(
         _SupabaseAuthApi(
           client,
           initialRecoveryAccessToken: initialRecoveryAccessToken,
           sessionPersistence: sessionPersistence,
         ),
         sessionPersistence: sessionPersistence,
       );

  @visibleForTesting
  SupabaseCoeloAuthGateway.test(
    this._api, {
    required CoeloAuthSessionPersistence sessionPersistence,
  }) : _sessionPersistence = sessionPersistence;

  final CoeloSupabaseAuthApi _api;
  final CoeloAuthSessionPersistence _sessionPersistence;
  // Credential changes share the SDK session across screen remounts.
  bool _credentialOperationInProgress = false;

  @override
  Stream<CoeloAuthSessionState> get authSessionStateChanges =>
      _api.authStateChanges;

  @override
  CoeloAuthSessionState get currentSessionState => _api.currentSessionState;

  Future<CoeloAuthSignInResult> signInWithPassword({
    required String email,
    required String password,
    required bool persistSession,
  }) async {
    if (_credentialOperationInProgress) {
      return const CoeloAuthSignInResult.failure(
        CoeloAuthSignInResult.genericFailureMessage,
      );
    }
    _credentialOperationInProgress = true;
    try {
      await _sessionPersistence.setPersistenceEnabled(value: persistSession);
      final didAuthenticate = await _api.signInWithPassword(
        email: email,
        password: password,
      );
      if (didAuthenticate) {
        return const CoeloAuthSignInResult.success();
      }
      return const CoeloAuthSignInResult.failure(
        CoeloAuthSignInResult.genericFailureMessage,
      );
    } catch (_) {
      return const CoeloAuthSignInResult.failure(
        CoeloAuthSignInResult.genericFailureMessage,
      );
    } finally {
      _credentialOperationInProgress = false;
    }
  }

  @override
  Future<CoeloAuthPasswordRecoveryResult> requestPasswordRecovery({
    required String email,
  }) => _requestPasswordRecovery(email: email);

  @override
  Future<CoeloAuthPasswordRecoveryResult> requestPasswordRecoveryWithRedirect({
    required String email,
    required Uri redirectTo,
  }) => _requestPasswordRecovery(email: email, redirectTo: redirectTo);

  Future<CoeloAuthPasswordRecoveryResult> _requestPasswordRecovery({
    required String email,
    Uri? redirectTo,
  }) async {
    try {
      await _api.requestPasswordRecovery(email: email, redirectTo: redirectTo);
      return const CoeloAuthPasswordRecoveryResult.success();
    } catch (_) {
      return const CoeloAuthPasswordRecoveryResult.failure(
        CoeloAuthPasswordRecoveryResult.genericFailureMessage,
      );
    }
  }

  @override
  Future<CoeloAuthPasswordUpdateResult> updatePassword({
    required String password,
  }) async {
    final recoveryState = _api.currentSessionState;
    if (_credentialOperationInProgress || !recoveryState.isPasswordRecovery) {
      return const CoeloAuthPasswordUpdateResult.failure(
        CoeloAuthPasswordUpdateResult.genericFailureMessage,
      );
    }
    _credentialOperationInProgress = true;
    var passwordUpdated = false;
    const cleanupFailure = CoeloAuthPasswordUpdateResult.failure(
      'A senha foi alterada, mas não foi possível confirmar o encerramento da sessão.',
    );
    try {
      await _api.updatePassword(password: password);
      passwordUpdated = true;
      if (_api.currentSessionState != recoveryState) {
        return cleanupFailure;
      }
      await _api.signOut();
      return const CoeloAuthPasswordUpdateResult.success();
    } catch (_) {
      // A confirmed write and an unconfirmed cleanup are separate outcomes.
      // Never retry the write or clear a replacement session from this catch.
      if (passwordUpdated) return cleanupFailure;
      return const CoeloAuthPasswordUpdateResult.failure(
        CoeloAuthPasswordUpdateResult.genericFailureMessage,
      );
    } finally {
      _credentialOperationInProgress = false;
    }
  }

  @override
  Future<void> signOut() {
    return _api.signOut();
  }

  /// Releases only this adapter's event subscription, never the shared client
  /// or its authenticated session.
  Future<void> dispose() async {
    final api = _api;
    if (api is _SupabaseAuthApi) await api.dispose();
  }
}

final class _SupabaseAuthApi implements CoeloSupabaseAuthApi {
  _SupabaseAuthApi(
    this._client, {
    required String? initialRecoveryAccessToken,
    required CoeloAuthSessionPersistence sessionPersistence,
  }) : _sessionPersistence = sessionPersistence {
    _recoverySessionId = initialRecoveryAccessToken == null
        ? null
        : coeloAuthSessionIdFromAccessToken(initialRecoveryAccessToken);
    _isRecovery = _recoverySessionId != null;
    _initialStateObserved = _client.auth.currentSession == null;
    _disableRecoveryPersistence(_client.auth.currentSession);
    _subscription = _client.auth.onAuthStateChange.listen(
      _handleAuthState,
      onError: _states.addError,
    );
  }

  final SupabaseClient _client;
  final CoeloAuthSessionPersistence _sessionPersistence;
  final _states = StreamController<CoeloAuthSessionState>.broadcast(sync: true);
  late final StreamSubscription<AuthState> _subscription;
  String? _recoverySessionId;
  String? _persistenceDisabledForRecoverySessionId;
  bool _isRecovery = false;
  bool _disposed = false;
  bool _initialStateObserved = false;

  void _handleAuthState(AuthState data) {
    if (_disposed) return;
    _initialStateObserved = true;
    final session = data.session;
    final sessionId = session == null ? null : _validatedSessionId(session);
    if (session == null) {
      _isRecovery = false;
      _recoverySessionId = null;
      _persistenceDisabledForRecoverySessionId = null;
    } else if (data.event == AuthChangeEvent.passwordRecovery) {
      _isRecovery = true;
      _recoverySessionId = sessionId;
    } else if (sessionId != _recoverySessionId) {
      _isRecovery = false;
      _recoverySessionId = null;
      _persistenceDisabledForRecoverySessionId = null;
    }
    _disableRecoveryPersistence(session);
    _states.add(_stateFor(session));
  }

  void _disableRecoveryPersistence(Session? session) {
    final sessionId = session == null ? null : _validatedSessionId(session);
    if (!_isRecovery ||
        sessionId == null ||
        sessionId != _recoverySessionId ||
        sessionId == _persistenceDisabledForRecoverySessionId) {
      return;
    }
    _persistenceDisabledForRecoverySessionId = sessionId;
    // Recovery remains usable in memory. A cold restart must require another
    // recovery link instead of restoring this credential as normal login.
    unawaited(
      Future<void>.sync(
        () => _sessionPersistence.setPersistenceEnabled(value: false),
      ).catchError((Object _, StackTrace stack) {
        if (!_disposed) {
          _states.addError(
            StateError('Recovery persistence cleanup failed.'),
            stack,
          );
        }
      }),
    );
  }

  @override
  Stream<CoeloAuthSessionState> get authStateChanges =>
      Stream<CoeloAuthSessionState>.multi((controller) {
        if (_disposed) {
          controller.closeSync();
          return;
        }
        final subscription = _states.stream.listen(
          controller.addSync,
          onError: controller.addErrorSync,
          onDone: controller.closeSync,
        );
        controller.onCancel = subscription.cancel;
        if (_initialStateObserved) controller.addSync(currentSessionState);
      }, isBroadcast: true);

  @override
  CoeloAuthSessionState get currentSessionState =>
      _stateFor(_client.auth.currentSession);

  CoeloAuthSessionState _stateFor(Session? session) {
    if (_disposed || session == null) {
      return const CoeloAuthSessionState.signedOut();
    }
    final sessionId = _validatedSessionId(session);
    final isCurrentRecovery = _isRecovery && sessionId == _recoverySessionId;
    if (!_initialStateObserved && !isCurrentRecovery) {
      return const CoeloAuthSessionState.signedOut();
    }
    return isCurrentRecovery
        ? CoeloAuthSessionState.passwordRecovery(sessionId: sessionId)
        : CoeloAuthSessionState.authenticated(sessionId: sessionId);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _isRecovery = false;
    _recoverySessionId = null;
    await _subscription.cancel();
    await _states.close();
  }

  @override
  Future<bool> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.session != null && response.user != null;
  }

  @override
  Future<void> requestPasswordRecovery({
    required String email,
    Uri? redirectTo,
  }) {
    if (redirectTo == null) {
      return _client.auth.resetPasswordForEmail(email);
    }
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: redirectTo.toString(),
    );
  }

  @override
  Future<void> updatePassword({required String password}) async {
    final session = _client.auth.currentSession;
    final recoveryState = currentSessionState;
    final transport = _client.rest.httpClient;
    final restUri = Uri.parse(_client.rest.url);
    const restSuffix = '/rest/v1';
    if (session == null ||
        !recoveryState.isPasswordRecovery ||
        transport == null ||
        !restUri.path.endsWith(restSuffix)) {
      throw const AuthException('Password recovery is unavailable.');
    }

    // Supabase derives both paths from the same configured project URL.
    // Reuse its transport, but pin the recovery token: SDK updateUser writes
    // its response into whichever session is current after the network await.
    final endpoint = restUri.replace(
      path:
          '${restUri.path.substring(0, restUri.path.length - restSuffix.length)}/auth/v1/user',
    );
    final headers = Map<String, String>.from(_client.auth.headers)
      ..removeWhere((key, _) => key.toLowerCase() == 'authorization')
      ..['Authorization'] = 'Bearer ${session.accessToken}'
      ..['Content-Type'] = 'application/json';
    final response = await transport.put(
      endpoint,
      headers: headers,
      body: jsonEncode(UserAttributes(password: password).toJson()),
    );
    if (response.statusCode != 200 ||
        currentSessionState != recoveryState ||
        _client.auth.currentUser?.id != session.user.id) {
      throw const AuthException('Password recovery could not be confirmed.');
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> || payload['id'] != session.user.id) {
      throw const AuthException('Password recovery could not be confirmed.');
    }
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

String? _validatedSessionId(Session session) {
  return coeloAuthSessionIdFromAccessToken(session.accessToken);
}

@visibleForTesting
String? coeloAuthSessionIdFromAccessToken(String accessToken) {
  try {
    final segments = accessToken.split('.');
    if (segments.length != 3) return null;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
    );
    final sessionId = payload is Map<String, dynamic>
        ? payload['session_id']
        : null;
    return sessionId is String && _uuidPattern.hasMatch(sessionId)
        ? sessionId
        : null;
  } on FormatException {
    return null;
  }
}
