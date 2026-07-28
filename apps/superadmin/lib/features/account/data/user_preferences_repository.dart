import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/user_preferences.dart';

abstract interface class UserPreferencesRepository {
  Future<UserPreferences> load();
  Future<void> save(UserPreferences preferences);
}

final class InMemoryUserPreferencesRepository implements UserPreferencesRepository {
  UserPreferences _preferences = const UserPreferences();

  @override
  Future<UserPreferences> load() async => _preferences;

  @override
  Future<void> save(UserPreferences preferences) async => _preferences = preferences;
}

final class SharedPreferencesUserPreferencesRepository implements UserPreferencesRepository {
  SharedPreferencesUserPreferencesRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences;

  static const _themeKey = 'coelo.superadmin.theme-mode';
  static const _reduceMotionKey = 'coelo.superadmin.reduce-motion';
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync? get _store {
    final existing = _preferences;
    if (existing != null) return existing;
    try {
      return _preferences = SharedPreferencesAsync();
    } on StateError {
      return null;
    }
  }

  @override
  Future<UserPreferences> load() async {
    final preferences = _store;
    if (preferences == null) return const UserPreferences();
    final themeName = await preferences.getString(_themeKey);
    final themeMode = ThemeMode.values.where((mode) => mode.name == themeName).firstOrNull;
    return UserPreferences(
      themeMode: themeMode ?? ThemeMode.system,
      reduceMotion: await preferences.getBool(_reduceMotionKey) ?? false,
    );
  }

  @override
  Future<void> save(UserPreferences preferences) async {
    final store = _store;
    if (store == null) return;
    await Future.wait([
      store.setString(_themeKey, preferences.themeMode.name),
      store.setBool(_reduceMotionKey, preferences.reduceMotion),
    ]);
  }
}
