import 'dart:async';

import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/account/domain/user_preferences.dart';
import 'package:coelo_superadmin/features/account/presentation/user_preferences_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('late device load cannot overwrite a theme selected while loading', () async {
    final repository = _PendingRepository();
    final controller = UserPreferencesController(repository);
    addTearDown(controller.dispose);
    final loading = controller.load();
    final changing = controller.setThemeMode(ThemeMode.dark);
    repository.loaded.complete(
      const UserPreferences(themeMode: ThemeMode.light, reduceMotion: true),
    );
    await Future.wait([loading, changing]);
    expect(controller.preferences.themeMode, ThemeMode.dark);
    expect(controller.preferences.reduceMotion, isTrue);
    expect(repository.saved, controller.preferences);
  });

  test('late device load does not notify a disposed controller', () async {
    final repository = _PendingRepository();
    final controller = UserPreferencesController(repository);
    final loading = controller.load();
    controller.dispose();
    repository.loaded.complete(const UserPreferences());
    await expectLater(loading, completes);
  });
}

final class _PendingRepository implements UserPreferencesRepository {
  final loaded = Completer<UserPreferences>();
  UserPreferences? saved;

  @override
  Future<UserPreferences> load() => loaded.future;

  @override
  Future<void> save(UserPreferences preferences) async => saved = preferences;
}
