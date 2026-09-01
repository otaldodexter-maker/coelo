import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_command.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/activities/fake_activity_directory_repository.dart';

void main() {
  test('declares production and development activity routes', () {
    expect(SuperadminRoutes.activities, '/activities');
    expect(SuperadminRoutes.activityCreate, '/activities/new');
    expect(SuperadminRoutes.activityDetail, '/activities/:activityId');
    expect(SuperadminRoutes.activityEdit, '/activities/:activityId/edit');
    expect(
      SuperadminRoutes.activityAssessmentSettings,
      '/activities/:activityId/assessment-settings',
    );
    expect(SuperadminRoutes.devActivities, '/dev/activities');
    expect(SuperadminRoutes.devActivityCreate, '/dev/activities/new');
    expect(SuperadminRoutes.devActivityDetail, '/dev/activities/:activityId');
    expect(SuperadminRoutes.devActivityEdit, '/dev/activities/:activityId/edit');
    expect(
      SuperadminRoutes.devActivityAssessmentSettings,
      '/dev/activities/:activityId/assessment-settings',
    );
  });

  testWidgets('exposes Activities as an active navigation destination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? selectedDestination;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: unavailableSuperadminLogout,
          currentDestination: 'activities',
          onDestinationSelected: (destination) => selectedDestination = destination,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-navigation-activities')));
    await tester.pump();
    expect(selectedDestination, 'activities');
  });

  testWidgets('protects production and exposes development list and detail', (tester) async {
    final session = SuperadminSession();
    final productionDirectory = _TrackingActivityDirectoryRepository();
    final productionCommands = _TripwireActivityCommandRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      activityDirectoryRepository: productionDirectory,
      activityCommandRepository: productionCommands,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.activities);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);

    router.go(SuperadminRoutes.devActivities);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devActivities);
    expect(find.text('Consulte as atividades da plataforma.'), findsOneWidget);

    router.go(SuperadminRoutes.devActivityCreate);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-form-scroll')), findsOneWidget);
    expect(find.text('Criar atividade'), findsWidgets);

    router.go(
      '${SuperadminRoutes.devActivityCreate}?templateId=template-robotics-institution'
      '&institutionId=institution-1',
    );
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.queryParameters,
      containsPair('templateId', 'template-robotics-institution'),
    );
    expect(
      router.routeInformationProvider.value.uri.queryParameters,
      containsPair('institutionId', 'institution-1'),
    );

    router.go('/dev/activities/activity-1');
    await tester.pumpAndSettle();
    expect(find.text('Visualizar atividade'), findsOneWidget);
    expect(find.text('Editar atividade'), findsOneWidget);

    router.go('/dev/activities/activity-1/edit');
    await tester.pumpAndSettle();
    expect(find.text('Editar atividade'), findsOneWidget);
    expect(productionDirectory.calls, 0);
    expect(productionCommands.calls, 0);
  });

  testWidgets('production hides create actions when commands are unavailable', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      activityDirectoryRepository: FakeActivityDirectoryRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.activities);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Consulte as atividades da plataforma.'), findsOneWidget);
    expect(find.text('Criar atividade'), findsNothing);
  });

  testWidgets('production mutation deep links render fullscreen 503 without repository access', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    final directory = _TrackingActivityDirectoryRepository();
    final commands = _TripwireActivityCommandRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      activityDirectoryRepository: directory,
      activityCommandRepository: commands,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.activityCreate);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('503'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-persistent-shell')), findsNothing);
    expect(directory.calls, 0);
    expect(commands.calls, 0);

    router.go('/activities/activity-1/edit');
    await tester.pumpAndSettle();
    expect(find.text('503'), findsOneWidget);
    expect(directory.calls, 0);
    expect(commands.calls, 0);
  });

  testWidgets('production routes use only the injected directory repository', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final directory = _TrackingActivityDirectoryRepository();
    final commands = _TripwireActivityCommandRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      activityDirectoryRepository: directory,
      activityCommandRepository: commands,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.activities);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(directory.calls, greaterThan(0));

    final beforeDetail = directory.calls;
    router.go('/activities/activity-1');
    await tester.pumpAndSettle();
    expect(directory.calls, greaterThan(beforeDetail));
    await tester.tap(find.text('Configuração avaliativa'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/errors/mutation-capability-unavailable',
    );
    expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsOneWidget);
    expect(commands.calls, 0);
  });
}

final class _TrackingActivityDirectoryRepository implements ActivityDirectoryRepository {
  final FakeActivityDirectoryRepository _delegate = FakeActivityDirectoryRepository();
  int calls = 0;

  @override
  Future<ActivityDetail?> fetchById(String activityId) {
    calls++;
    return _delegate.fetchById(activityId);
  }

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() {
    calls++;
    return _delegate.fetchFilterOptions();
  }

  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) {
    calls++;
    return _delegate.fetchFormOptions(institutionId: institutionId);
  }

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) {
    calls++;
    return _delegate.fetchPage(query);
  }

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) {
    calls++;
    return _delegate.fetchTemplateOptions(institutionId: institutionId);
  }

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) {
    calls++;
    return _delegate.searchProfessionals(institutionId: institutionId, query: query, limit: limit);
  }
}

final class _TripwireActivityCommandRepository implements ActivityCommandRepository {
  int calls = 0;

  Future<T> _tripwire<T>() {
    calls++;
    return Future.error(StateError('Production Activity command called.'));
  }

  @override
  Future<ActivityTemplateCopyResult> copyTemplate(ActivityTemplateCopyCommand command) =>
      _tripwire();

  @override
  Future<ActivityTemplateCreateResult> createTemplate(ActivityTemplateCreateCommand command) =>
      _tripwire();

  @override
  Future<List<ActivityLocationResult>> createLocations(ActivityLocationCommand command) =>
      _tripwire();

  @override
  Future<ActivityExportResult> requestExport(
    ActivityDirectoryQuery query, {
    required ActivityCommandExportFormat format,
  }) => _tripwire();

  @override
  Future<ActivitySaveResult> save(ActivitySaveCommand command) => _tripwire();
}
