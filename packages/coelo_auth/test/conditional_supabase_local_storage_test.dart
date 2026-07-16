import 'package:coelo_auth/coelo_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'delegates initialization and restores an existing session by default',
    () async {
      final delegate = _MemoryLocalStorage('persisted-session');
      final storage = ConditionalSupabaseLocalStorage(delegate: delegate);

      await storage.initialize();

      expect(delegate.didInitialize, isTrue);
      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), 'persisted-session');
    },
  );

  test('persists auth changes while persistence is enabled', () async {
    final delegate = _MemoryLocalStorage();
    final storage = ConditionalSupabaseLocalStorage(delegate: delegate);

    await storage.persistSession('kept-session');

    expect(delegate.persistedSession, 'kept-session');
  });

  test(
    'removes an old session and blocks writes when persistence is disabled',
    () async {
      final delegate = _MemoryLocalStorage('old-session');
      final storage = ConditionalSupabaseLocalStorage(delegate: delegate);

      await storage.setPersistenceEnabled(value: false);
      await storage.persistSession('new-session');

      expect(delegate.persistedSession, isNull);
      expect(delegate.removeCount, 1);
    },
  );

  test('persists auth changes again after persistence is re-enabled', () async {
    final delegate = _MemoryLocalStorage();
    final storage = ConditionalSupabaseLocalStorage(delegate: delegate);

    await storage.setPersistenceEnabled(value: false);
    await storage.setPersistenceEnabled(value: true);
    await storage.persistSession('kept-session');

    expect(delegate.persistedSession, 'kept-session');
  });

  test('always delegates explicit session removal', () async {
    final delegate = _MemoryLocalStorage('persisted-session');
    final storage = ConditionalSupabaseLocalStorage(delegate: delegate);

    await storage.removePersistedSession();

    expect(delegate.persistedSession, isNull);
    expect(delegate.removeCount, 1);
  });
}

final class _MemoryLocalStorage extends LocalStorage {
  _MemoryLocalStorage([this.persistedSession]);

  String? persistedSession;
  bool didInitialize = false;
  int removeCount = 0;

  @override
  Future<String?> accessToken() async => persistedSession;

  @override
  Future<bool> hasAccessToken() async => persistedSession != null;

  @override
  Future<void> initialize() async {
    didInitialize = true;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    persistedSession = persistSessionString;
  }

  @override
  Future<void> removePersistedSession() async {
    removeCount += 1;
    persistedSession = null;
  }
}
