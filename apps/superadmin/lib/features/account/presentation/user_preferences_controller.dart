import 'package:flutter/material.dart';

import '../data/user_preferences_repository.dart';
import '../domain/user_preferences.dart';

final class UserPreferencesController extends ChangeNotifier {
  UserPreferencesController(this.repository);

  final UserPreferencesRepository repository;
  UserPreferences _preferences = const UserPreferences();
  bool _loaded = false;

  UserPreferences get preferences => _preferences;
  bool get loaded => _loaded;

  Future<void> load() async {
    _preferences = await repository.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _preferences = _preferences.copyWith(themeMode: mode);
    notifyListeners();
    await repository.save(_preferences);
  }

  Future<void> setReduceMotion(bool value) async {
    _preferences = _preferences.copyWith(reduceMotion: value);
    notifyListeners();
    await repository.save(_preferences);
  }
}
