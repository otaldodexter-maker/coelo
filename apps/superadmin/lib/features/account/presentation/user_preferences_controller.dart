import 'package:flutter/material.dart';

import '../data/user_preferences_repository.dart';
import '../domain/user_preferences.dart';

final class UserPreferencesController extends ChangeNotifier {
  UserPreferencesController(this.repository);

  final UserPreferencesRepository repository;
  UserPreferences _preferences = const UserPreferences();
  bool _loaded = false;
  bool _disposed = false;
  Future<void>? _loading;
  Future<void> _saving = Future<void>.value();

  UserPreferences get preferences => _preferences;
  bool get loaded => _loaded;

  Future<void> load() {
    if (_disposed) return Future<void>.value();
    return _loading ??= _load().onError<Object>((error, stackTrace) {
      _loading = null;
      if (!_disposed) Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<void> _load() async {
    final preferences = await repository.load();
    if (_disposed) return;
    _preferences = preferences;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await load();
    if (_disposed) return;
    _preferences = _preferences.copyWith(themeMode: mode);
    notifyListeners();
    await _save(_preferences);
  }

  Future<void> setReduceMotion(bool value) async {
    await load();
    if (_disposed) return;
    _preferences = _preferences.copyWith(reduceMotion: value);
    notifyListeners();
    await _save(_preferences);
  }

  Future<void> _save(UserPreferences preferences) {
    final saving = _saving.then((_) => repository.save(preferences));
    // Keep the queue usable after failure; the initiating caller still receives it.
    _saving = saving.onError<Object>((error, stackTrace) {});
    return saving;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
