import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/account/domain/user_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('in-memory preferences persist theme and reduced motion', () async {
    final repository = InMemoryUserPreferencesRepository();

    await repository.save(const UserPreferences(themeMode: ThemeMode.dark, reduceMotion: true));

    expect(
      await repository.load(),
      const UserPreferences(themeMode: ThemeMode.dark, reduceMotion: true),
    );
  });
}
