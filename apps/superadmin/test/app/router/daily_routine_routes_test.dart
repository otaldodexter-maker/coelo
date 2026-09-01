import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/dev_menu/development_routine_repository.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_superadmin/features/daily_routine/domain/routine_contract.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares production and development daily routine routes', () {
    expect(SuperadminRoutes.dailyRoutine, '/daily-routine');
    expect(SuperadminRoutes.dailyRoutineCreate, '/daily-routine/new');
    expect(SuperadminRoutes.dailyRoutineEdit, '/daily-routine/:modelId/edit');
    expect(SuperadminRoutes.devDailyRoutine, '/dev/daily-routine');
  });

  testWidgets('development routes use one local fixture and never call production', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final repository = _TrackingRoutineRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
      routineRepository: repository,
      allowDevelopmentPreview: true,
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go('/dev/daily-routine');
    await tester.pumpAndSettle();
    final directory = tester.widget<DailyRoutineDirectoryPage>(
      find.byType(DailyRoutineDirectoryPage),
    );
    expect(directory.repository, isA<DevelopmentRoutineRepository>());
    expect(find.text('Modelos'), findsOneWidget);
    expect(repository.calls, isEmpty);

    router.go('/dev/daily-routine/new');
    await tester.pumpAndSettle();
    final create = tester.widget<DailyRoutineEditorPage>(find.byType(DailyRoutineEditorPage));
    expect(create.repository, same(directory.repository));
    expect(find.byKey(const Key('daily-routine-model-editor')), findsOneWidget);
    expect(repository.calls, isEmpty);

    router.go('/dev/daily-routine/application-1/edit?kind=application');
    await tester.pumpAndSettle();
    final edit = tester.widget<DailyRoutineEditorPage>(find.byType(DailyRoutineEditorPage));
    expect(edit.repository, same(directory.repository));
    expect(find.byKey(const Key('daily-routine-application-editor')), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets('development model actions open seeded duplicate and application editors', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
      allowDevelopmentPreview: true,
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    router.go('/dev/daily-routine');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('daily-routine-duplicate-model-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-routine-model-editor')), findsOneWidget);
    final duplicateName = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('daily-routine-name')),
        matching: find.byType(TextField),
      ),
    );
    expect(duplicateName.controller?.text, 'Rotina diária (cópia)');

    router.go('/dev/daily-routine');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily-routine-apply-model-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-routine-application-editor')), findsOneWidget);
    final application = tester.widget<DailyRoutineEditorPage>(find.byType(DailyRoutineEditorPage));
    expect(application.entryType, RoutineEntryKind.application);
    expect(application.applicationFromModelId, 'model-1');
  });

  testWidgets('production routes preserve the injected repository', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final repository = _TrackingRoutineRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
      routineRepository: repository,
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go('/daily-routine');
    await tester.pumpAndSettle();
    final directory = tester.widget<DailyRoutineDirectoryPage>(
      find.byType(DailyRoutineDirectoryPage),
    );
    expect(directory.repository, same(repository));
    expect(repository.calls, contains('fetchPage:model'));

    repository.calls.clear();
    router.go('/daily-routine/new');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsOneWidget);
    expect(repository.calls, isEmpty);

    repository.calls.clear();
    router.go('/daily-routine/application-1/edit?kind=application');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsOneWidget);
    expect(repository.calls, isEmpty);
  });
}

final class _TrackingRoutineRepository implements RoutineRepository {
  final _delegate = DevelopmentRoutineRepository.content();
  final calls = <String>[];

  @override
  Future<RoutineDirectoryPage> fetchPage(RoutineDirectoryQuery query) {
    calls.add('fetchPage:${query.kind.name}');
    return _delegate.fetchPage(query);
  }

  @override
  Future<RoutineModel> fetchModel(String id) {
    calls.add('fetchModel:$id');
    return _delegate.fetchModel(id);
  }

  @override
  Future<RoutineApplication> fetchApplication(String id) {
    calls.add('fetchApplication:$id');
    return _delegate.fetchApplication(id);
  }

  @override
  Future<RoutineLaunch> fetchLaunch(String id) {
    calls.add('fetchLaunch:$id');
    return _delegate.fetchLaunch(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
