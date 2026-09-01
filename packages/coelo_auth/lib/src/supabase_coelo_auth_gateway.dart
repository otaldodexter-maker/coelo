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
    } on AuthException {
      return const CoeloAuthSignInResult.failure(
        CoeloAuthSignInResult.genericFailureMessage,
      );
    } on Exception {
      return const CoeloAuthSignInResult.failure(
        CoeloAuthSignInResult.genericFailureMessage,
      );
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
    } on AuthException {
      return const CoeloAuthPasswordRecoveryResult.failure(
        CoeloAuthPasswordRecoveryResult.genericFailureMessage,
      );
    } on Exception {
      return const CoeloAuthPasswordRecoveryResult.failure(
        CoeloAuthPasswordRecoveryResult.genericFailureMessage,
      );
    }
  }

  @override
  Future<CoeloAuthPasswordUpdateResult> updatePassword({
    required String password,
  }) async {
    if (!_api.currentSessionState.isPasswordRecovery) {
      return const CoeloAuthPasswordUpdateResult.failure(
        CoeloAuthPasswordUpdateResult.genericFailureMessage,
      );
    }
    try {
      await _api.updatePassword(password: password);
      await _api.signOut();
      return const CoeloAuthPasswordUpdateResult.success();
    } on AuthException {
      return const CoeloAuthPasswordUpdateResult.failure(
        CoeloAuthPasswordUpdateResult.genericFailureMessage,
      );
    } on Exception {
      return const CoeloAuthPasswordUpdateResult.failure(
        CoeloAuthPasswordUpdateResult.genericFailureMessage,
      );
    }
  }

  @override
  Future<void> signOut() {
    return _api.signOut();
  }
}

final class _SupabaseAuthApi implements CoeloSupabaseAuthApi {
  _SupabaseAuthApi(this._client, {required this.initialRecoveryAccessToken});

  final SupabaseClient _client;
  final String? initialRecoveryAccessToken;

  @override
  Stream<CoeloAuthSessionState> get authStateChanges =>
      _client.auth.onAuthStateChange.map((data) {
        if (data.session == null) {
          return const CoeloAuthSessionState.signedOut();
        }
        if (data.event == AuthChangeEvent.passwordRecovery) {
          return CoeloAuthSessionState.passwordRecovery(
            sessionId: _validatedSessionId(data.session!),
          );
        }
        return CoeloAuthSessionState.authenticated(
          sessionId: _validatedSessionId(data.session!),
        );
      });

  @override
  CoeloAuthSessionState get currentSessionState {
    final session = _client.auth.currentSession;
    if (session == null) {
      return const CoeloAuthSessionState.signedOut();
    }
    return initialRecoveryAccessToken != null &&
            session.accessToken == initialRecoveryAccessToken
        ? CoeloAuthSessionState.passwordRecovery(
            sessionId: _validatedSessionId(session),
          )
        : CoeloAuthSessionState.authenticated(
            sessionId: _validatedSessionId(session),
          );
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
    await _client.auth.updateUser(UserAttributes(password: password));
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
