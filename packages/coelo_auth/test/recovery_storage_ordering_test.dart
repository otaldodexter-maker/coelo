import 'dart:async';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'disabling persistence removes a recovery write that was already pending',
    () async {
      final delegate = _DeferredStorage();
      final storage = ConditionalSupabaseLocalStorage(delegate: delegate);
      final write = storage.persistSession('synthetic-recovery-session');
      await delegate.started.future;
      final disable = storage.setPersistenceEnabled(value: false);
      await storage.persistSession('later-synthetic-session');
      delegate.release.complete();
      await write;
      await disable;

      expect(delegate.value, isNull);
      expect(delegate.writes, 1);
      expect(delegate.removals, 1);
    },
  );

  test(
    'a failed pending write does not prevent the queued recovery purge',
    () async {
      final delegate = _DeferredStorage(failWrite: true);
      final storage = ConditionalSupabaseLocalStorage(delegate: delegate);
      final write = storage.persistSession('synthetic-recovery-session');
      final writeFailure = expectLater(write, throwsStateError);
      await delegate.started.future;
      final disable = storage.setPersistenceEnabled(value: false);
      delegate.release.complete();
      await writeFailure;
      await disable;

      expect(delegate.value, isNull);
      expect(delegate.removals, 1);
    },
  );
}

final class _DeferredStorage extends LocalStorage {
  _DeferredStorage({this.failWrite = false});

  final bool failWrite;
  final started = Completer<void>();
  final release = Completer<void>();
  String? value = 'previous-synthetic-session';
  int writes = 0;
  int removals = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async => value;

  @override
  Future<bool> hasAccessToken() async => value != null;

  @override
  Future<void> persistSession(String persistSessionString) async {
    writes++;
    started.complete();
    await release.future;
    if (failWrite) throw StateError('Synthetic write failure');
    value = persistSessionString;
  }

  @override
  Future<void> removePersistedSession() async {
    removals++;
    value = null;
  }
}
