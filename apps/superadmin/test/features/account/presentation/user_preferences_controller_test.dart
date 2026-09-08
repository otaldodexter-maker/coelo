import 'dart:async';

import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/account/domain/user_preferences.dart';
import 'package:coelo_superadmin/features/account/presentation/user_preferences_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('failed device write reaches its caller without poisoning later writes', () async {
    final repository = _OrderedWritesRepository();
    final controller = UserPreferencesController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    final first = controller.setThemeMode(ThemeMode.dark);
    final failed = expectLater(first, throwsA(isA<Exception>()));
    await repository.firstStarted.future;
    final second = controller.setReduceMotion(true);
    repository.firstRelease.completeError(Exception('synthetic write failure'));
    await failed;
    await second;
    expect(repository.writes, hasLength(2));
    expect(
      await repository.load(),
      const UserPreferences(themeMode: ThemeMode.dark, reduceMotion: true),
    );
  });

  test('device writes preserve edit order across overlapping setters', () async {
    final repository = _OrderedWritesRepository();
    final controller = UserPreferencesController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    final first = controller.setThemeMode(ThemeMode.dark);
    await repository.firstStarted.future;
    final second = controller.setReduceMotion(true);
    await Future<void>.delayed(Duration.zero);
    expect(repository.writes, hasLength(1));
    repository.firstRelease.complete();
    await Future.wait([first, second]);
    final reloaded = UserPreferencesController(repository);
    addTearDown(reloaded.dispose);
    await reloaded.load();
    expect(
      reloaded.preferences,
      const UserPreferences(themeMode: ThemeMode.dark, reduceMotion: true),
    );
  });

  test('failed initial load can retry and then save an edit', () async {
    final repository = _RetryRepository();
    final controller = UserPreferencesController(repository);
    addTearDown(controller.dispose);
    await expectLater(controller.load(), throwsA(isA<Exception>()));
    expect(controller.loaded, isFalse);
    await controller.load();
    await controller.setThemeMode(ThemeMode.dark);
    await controller.setReduceMotion(false);
    expect(repository.loads, 2);
    expect(controller.loaded, isTrue);
    expect(repository.saved, const UserPreferences(themeMode: ThemeMode.dark, reduceMotion: false));
  });

  test('failure after disposal completes quietly and cannot reopen a load', () async {
    final repository = _PendingRepository();
    final controller = UserPreferencesController(repository);
    final loading = controller.load();
    final completion = expectLater(loading, completes);
    controller.dispose();
    repository.loaded.completeError(Exception('synthetic read failure'));
    await completion;
    await controller.load();
    await controller.setThemeMode(ThemeMode.dark);
    expect(repository.saved, isNull);
    expect(repository.loads, 1);
  });

  test('pending loads share one read and successful load remains cached', () async {
    final repository = _PendingRepository();
    final controller = UserPreferencesController(repository);
    addTearDown(controller.dispose);
    final first = controller.load();
    final second = controller.load();
    expect(second, same(first));
    repository.loaded.complete(const UserPreferences());
    await Future.wait([first, second]);
    await controller.load();
    expect(repository.loads, 1);
  });

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
  int loads = 0;
  UserPreferences? saved;

  @override
  Future<UserPreferences> load() {
    loads++;
    return loaded.future;
  }

  @override
  Future<void> save(UserPreferences preferences) async => saved = preferences;
}

final class _RetryRepository implements UserPreferencesRepository {
  int loads = 0;
  UserPreferences? saved;
  @override
  Future<UserPreferences> load() async {
    if (++loads == 1) throw Exception('synthetic transient read failure');
    return const UserPreferences(themeMode: ThemeMode.light, reduceMotion: true);
  }

  @override
  Future<void> save(UserPreferences preferences) async => saved = preferences;
}

final class _OrderedWritesRepository implements UserPreferencesRepository {
  final firstStarted = Completer<void>();
  final firstRelease = Completer<void>();
  final writes = <UserPreferences>[];
  UserPreferences stored = const UserPreferences();

  @override
  Future<UserPreferences> load() async => stored;

  @override
  Future<void> save(UserPreferences preferences) async {
    writes.add(preferences);
    if (writes.length == 1) {
      firstStarted.complete();
      await firstRelease.future;
    }
    stored = preferences;
  }
}
