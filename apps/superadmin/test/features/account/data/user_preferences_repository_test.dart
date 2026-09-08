import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/account/domain/user_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('missing device store cannot masquerade as a successful read', () async {
    expect(SharedPreferencesAsync.new, throwsStateError);
    final repository = SharedPreferencesUserPreferencesRepository();
    await expectLater(repository.load(), throwsStateError);
  });

  test('missing device store cannot acknowledge a write that never persisted', () async {
    expect(SharedPreferencesAsync.new, throwsStateError);
    final repository = SharedPreferencesUserPreferencesRepository();
    await expectLater(
      repository.save(const UserPreferences(themeMode: ThemeMode.dark)),
      throwsStateError,
    );
  });

  test('device adapter reloads stored theme and motion through a fresh repository', () async {
    final store = _DeviceStore();
    await SharedPreferencesUserPreferencesRepository(
      preferences: store,
    ).save(const UserPreferences(themeMode: ThemeMode.dark, reduceMotion: true));
    expect(
      await SharedPreferencesUserPreferencesRepository(preferences: store).load(),
      const UserPreferences(themeMode: ThemeMode.dark, reduceMotion: true),
    );
  });

  test('available empty or unknown theme storage uses supported defaults', () async {
    final store = _DeviceStore();
    final repository = SharedPreferencesUserPreferencesRepository(preferences: store);
    expect(await repository.load(), const UserPreferences());
    store.values['coelo.superadmin.theme-mode'] = 'unknown';
    expect(await repository.load(), const UserPreferences());
  });

  test('in-memory preferences persist theme and reduced motion', () async {
    final repository = InMemoryUserPreferencesRepository();

    await repository.save(const UserPreferences(themeMode: ThemeMode.dark, reduceMotion: true));

    expect(
      await repository.load(),
      const UserPreferences(themeMode: ThemeMode.dark, reduceMotion: true),
    );
  });
}

final class _DeviceStore implements SharedPreferencesAsync {
  final values = <String, Object>{};

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
