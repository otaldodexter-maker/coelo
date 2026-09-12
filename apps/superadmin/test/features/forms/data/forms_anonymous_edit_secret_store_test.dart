import 'dart:async';
import 'dart:convert';

import 'package:coelo_superadmin/features/forms/data/forms_anonymous_edit_secret_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  SharedPreferencesFormsAnonymousEditSecretStore store(
    _Preferences preferences, {
    String project = 'project-a',
    String account = 'account-a',
  }) => SharedPreferencesFormsAnonymousEditSecretStore(
    projectId: project,
    accountId: account,
    preferences: preferences,
  );

  test('32 random bytes are persisted before return and survive a new store', () async {
    final preferences = _Preferences();
    final value = await store(preferences).loadOrCreate('occurrence-a');
    expect(value.length, 43);
    expect(base64Url.decode(base64Url.normalize(value)).length, 32);
    expect(await store(preferences).loadOrCreate('occurrence-a'), value);
    expect(preferences.writes, 1);
    expect(preferences.values.keys.single.contains('account-a'), isFalse);
    expect(preferences.values.keys.single.contains('occurrence-a'), isFalse);
  });

  test('account, project and occurrence partitions never reuse a capability', () async {
    final preferences = _Preferences();
    final values = {
      await store(preferences).loadOrCreate('occurrence-a'),
      await store(preferences, account: 'account-b').loadOrCreate('occurrence-a'),
      await store(preferences, project: 'project-b').loadOrCreate('occurrence-a'),
      await store(preferences).loadOrCreate('occurrence-b'),
    };
    expect(values.length, 4);
    expect(preferences.values.length, 4);
  });

  test('concurrent opens await one confirmed write', () async {
    final preferences = _Preferences()..writeGate = Completer<void>();
    final first = store(preferences).loadOrCreate('occurrence-concurrent');
    final second = store(preferences).loadOrCreate('occurrence-concurrent');
    await Future<void>.delayed(Duration.zero);
    expect(preferences.writes, 1);
    preferences.writeGate!.complete();
    expect(await first, await second);
  });

  for (final failure in ['read', 'write', 'lost-write', 'malformed']) {
    test('storage $failure fails safely without an ephemeral or replacement secret', () async {
      final preferences = _Preferences()..failure = failure;
      final subject = store(preferences);
      await expectLater(
        subject.loadOrCreate('failure-$failure'),
        throwsA(isA<FormsAnonymousEditSecretException>()),
      );
      if (failure == 'malformed' || failure == 'read') expect(preferences.writes, 0);
      preferences.failure = null;
      final recovered = await subject.loadOrCreate('failure-$failure');
      expect(recovered.length, 43);
    });
  }

  test('account resolver is stable and drops the previous account context', () {
    final created = <String, _SecretStore>{};
    final resolver = FormsAnonymousEditSecretStoreResolver(
      projectId: 'project-a',
      create: (projectId, accountId) =>
          created.putIfAbsent('$projectId/$accountId', _SecretStore.new),
    );

    final first = resolver.resolve('account-a');
    expect(resolver.resolve('account-a'), same(first));
    expect(resolver.resolve(null), isNull);
    final second = resolver.resolve('account-b');
    expect(second, isNot(same(first)));
    expect(resolver.resolve('account-b'), same(second));
    expect(created.keys, unorderedEquals(['project-a/account-a', 'project-a/account-b']));
  });
}

final class _SecretStore implements FormsAnonymousEditSecretStore {
  @override
  Future<String> loadOrCreate(String occurrenceId) async => occurrenceId;
}

final class _Preferences implements SharedPreferencesAsync {
  final values = <String, String>{};
  final _state = _PreferenceState();
  int get writes => _state.writes;
  String? get failure => _state.failure;
  set failure(String? value) => _state.failure = value;
  Completer<void>? get writeGate => _state.writeGate;
  set writeGate(Completer<void>? value) => _state.writeGate = value;

  @override
  Future<String?> getString(String key) async {
    if (failure == 'read') throw StateError('synthetic private platform detail');
    if (failure == 'malformed') return 'invalid stored capability';
    return values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    _state.writes++;
    if (failure == 'write') throw StateError('synthetic private platform detail');
    await writeGate?.future;
    if (failure != 'lost-write') values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _PreferenceState {
  int writes = 0;
  String? failure;
  Completer<void>? writeGate;
}
