import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'conditional_supabase_local_storage.dart';
import 'coelo_auth_gateway.dart';

abstract interface class CoeloSupabaseAuthApi {
  Stream<bool> get authStateChanges;
  bool get isAuthenticated;

  Future<bool> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> requestPasswordRecovery({required String email});

  Future<void> signOut();
}

final class SupabaseCoeloAuthGateway implements CoeloAuthGateway {
  SupabaseCoeloAuthGateway(
    SupabaseClient client, {
    required CoeloAuthSessionPersistence sessionPersistence,
  }) : this.test(
         _SupabaseAuthApi(client),
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
  Stream<bool> get authStateChanges => _api.authStateChanges;

  @override
  bool get isAuthenticated => _api.isAuthenticated;

  @override
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
  }) async {
    try {
      await _api.requestPasswordRecovery(email: email);
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
  Future<void> signOut() {
    return _api.signOut();
  }
}

final class _SupabaseAuthApi implements CoeloSupabaseAuthApi {
  _SupabaseAuthApi(this._client);

  final SupabaseClient _client;

  @override
  Stream<bool> get authStateChanges =>
      _client.auth.onAuthStateChange.map((data) => data.session != null);

  @override
  bool get isAuthenticated => _client.auth.currentSession != null;

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
  Future<void> requestPasswordRecovery({required String email}) {
    return _client.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }
}
