import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class CoeloAuthSessionPersistence {
  Future<void> setPersistenceEnabled({required bool value});
}

final class ConditionalSupabaseLocalStorage extends LocalStorage
    implements CoeloAuthSessionPersistence {
  ConditionalSupabaseLocalStorage({required LocalStorage delegate})
    : _delegate = delegate;

  final LocalStorage _delegate;
  bool _isPersistenceEnabled = true;

  @override
  Future<String?> accessToken() => _delegate.accessToken();

  @override
  Future<bool> hasAccessToken() => _delegate.hasAccessToken();

  @override
  Future<void> initialize() => _delegate.initialize();

  @override
  Future<void> persistSession(String persistSessionString) {
    if (!_isPersistenceEnabled) {
      return Future<void>.value();
    }
    return _delegate.persistSession(persistSessionString);
  }

  @override
  Future<void> removePersistedSession() => _delegate.removePersistedSession();

  @override
  Future<void> setPersistenceEnabled({required bool value}) async {
    _isPersistenceEnabled = value;
    if (!value) {
      await _delegate.removePersistedSession();
    }
  }
}
