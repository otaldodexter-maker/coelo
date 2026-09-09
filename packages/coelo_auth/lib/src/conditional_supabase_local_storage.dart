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
  Future<void> _pendingMutation = Future<void>.value();

  @override
  Future<String?> accessToken() async {
    await _pendingMutation;
    return _delegate.accessToken();
  }

  @override
  Future<bool> hasAccessToken() async {
    await _pendingMutation;
    return _delegate.hasAccessToken();
  }

  @override
  Future<void> initialize() => _delegate.initialize();

  @override
  Future<void> persistSession(String persistSessionString) {
    if (!_isPersistenceEnabled) {
      return Future<void>.value();
    }
    return _serialize(() async {
      if (_isPersistenceEnabled) {
        await _delegate.persistSession(persistSessionString);
      }
    });
  }

  @override
  Future<void> removePersistedSession() =>
      _serialize(_delegate.removePersistedSession);

  @override
  Future<void> setPersistenceEnabled({required bool value}) async {
    _isPersistenceEnabled = value;
    if (!value) {
      await removePersistedSession();
    }
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _pendingMutation.then((_) => operation());
    // Preserve errors for each caller without poisoning the next purge.
    _pendingMutation = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}
