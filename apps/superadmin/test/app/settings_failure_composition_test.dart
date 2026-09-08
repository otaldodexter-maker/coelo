import 'dart:async';

import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/app/theme/superadmin_theme_mode_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/account/domain/user_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('an obsolete theme write failure does not report failure for a newer choice', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    addTearDown(session.dispose);
    final repository = _DelayedFailRepository();
    await tester.pumpWidget(SuperadminApp(session: session, userPreferencesRepository: repository));
    await tester.pumpAndSettle();
    tester
        .widget<SuperadminThemeModeScope>(find.byType(SuperadminThemeModeScope))
        .onChanged(ThemeMode.dark);
    await tester.pump();
    tester
        .widget<SuperadminThemeModeScope>(find.byType(SuperadminThemeModeScope))
        .onChanged(ThemeMode.light);
    await tester.pump();
    repository.firstRelease.completeError(Exception('synthetic old write failure'));
    await tester.pumpAndSettle();
    expect(repository.stored.themeMode, ThemeMode.light);
    expect(find.text('Não foi possível salvar as preferências neste dispositivo.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app theme callback reports a failed save instead of an unhandled future', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      SuperadminApp(
        session: session,
        userPreferencesRepository: _FailTwiceRepository(failedLoads: 0, failSave: true),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<SuperadminThemeModeScope>(find.byType(SuperadminThemeModeScope))
        .onChanged(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível salvar as preferências neste dispositivo.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app and normal route consume load failures while Settings offers retry', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    addTearDown(session.dispose);
    final repository = _FailTwiceRepository();
    await tester.pumpWidget(SuperadminApp(session: session, userPreferencesRepository: repository));
    await tester.pumpAndSettle();
    final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
    (material.routerConfig! as GoRouter).go('/settings');
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar as preferências deste dispositivo.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-theme-dark')), findsOneWidget);
    expect(repository.loads, 3);
    expect(tester.takeException(), isNull);
  });
}

final class _DelayedFailRepository implements UserPreferencesRepository {
  final firstRelease = Completer<void>();
  int writes = 0;
  UserPreferences stored = const UserPreferences();
  @override
  Future<UserPreferences> load() async => stored;
  @override
  Future<void> save(UserPreferences preferences) async {
    if (++writes == 1) await firstRelease.future;
    stored = preferences;
  }
}

final class _FailTwiceRepository implements UserPreferencesRepository {
  _FailTwiceRepository({this.failedLoads = 2, this.failSave = false});
  final int failedLoads;
  final bool failSave;
  int loads = 0;
  @override
  Future<UserPreferences> load() async {
    if (++loads <= failedLoads) throw Exception('synthetic load failure');
    return const UserPreferences();
  }

  @override
  Future<void> save(UserPreferences preferences) async {
    if (failSave) throw Exception('synthetic save failure');
  }
}
