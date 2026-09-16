import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/dev_menu/development_attendance_repository.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _fullContext = SuperadminAuthContext(
  platformRoleCode: 'owner',
  scopeKind: SuperadminAuthScopeKind.platform,
  permissionCodes: {'platform.read', 'attendance.read'},
  aal: 'aal1',
);

const _reducedContext = SuperadminAuthContext(
  platformRoleCode: 'owner',
  scopeKind: SuperadminAuthScopeKind.platform,
  permissionCodes: {'platform.read'},
  aal: 'aal1',
);

void main() {
  testWidgets('the attendance dashboard is rebuilt when authorization changes', (tester) async {
    final session = SuperadminSession()..authorize(_fullContext, sessionId: 'nominal-session');
    final repository = _TrackingAttendanceRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
      attendanceRepository: repository,
      attendancePermissions: const AttendancePermissions.owner(),
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    addTearDown(repository.dispose);

    router.go(SuperadminRoutes.attendance);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    final loadsBefore = repository.calls.where((call) => call == 'fetchDashboard').length;
    expect(loadsBefore, 1);
    final previousRevision = session.authorizationInvalidationRevision;

    session.authorize(_reducedContext, sessionId: 'nominal-session');
    await tester.pumpAndSettle();

    expect(session.authorizationInvalidationRevision, greaterThan(previousRevision));
    expect(
      repository.calls.where((call) => call == 'fetchDashboard').length,
      greaterThan(loadsBefore),
      reason: 'a snapshot read under the previous authorization must not survive it',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the history route lists calls from the production repository and opens the detail', (
    tester,
  ) async {
    // ADR 0041 B2 (spec 052): /attendance/history e a folha do menu.
    final session = SuperadminSession()..authorize(_fullContext, sessionId: 'nominal-session');
    final repository = _TrackingAttendanceRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
      attendanceRepository: repository,
      attendancePermissions: const AttendancePermissions.owner(),
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    addTearDown(repository.dispose);

    router.go(SuperadminRoutes.attendanceHistory);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(SuperadminRoutes.attendanceHistory, '/attendance/history');
    expect(repository.calls, contains('fetchHistory'));
    expect(find.text('Histórico de chamadas'), findsOneWidget);
    expect(find.text('Turma R14 S10'), findsOneWidget);
    expect(
      find.byKey(const Key('attendance-history-segments')),
      findsNothing,
      reason: 'sem repositório de rotina composto não há segmento de lançamentos',
    );

    tester
        .widget<IconButton>(find.byKey(const ValueKey('attendance-history-open-call-progress')))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/attendance/calls/call-progress');
  });

  testWidgets('the history route is unavailable when the host has no attendance source', (
    tester,
  ) async {
    final session = SuperadminSession()..authorize(_fullContext, sessionId: 'nominal-session');
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.attendanceHistory);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Histórico indisponível'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('shell exposes Histórico under Assiduidade and navigates to it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: unavailableSuperadminLogout,
          currentDestination: 'attendance-history',
          onDestinationSelected: (value) => destination = value,
          canAccessCapability: (_) => false,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Histórico é leitura: aparece mesmo sem a capacidade de criar chamada.
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.text('Nova chamada'), findsNothing);
    await tester.tap(find.text('Histórico'));
    expect(destination, 'attendance-history');
  });

  test('declares production and development attendance routes', () {
    expect(SuperadminRoutes.attendance, '/attendance');
    expect(SuperadminRoutes.attendanceCreate, '/attendance/new');
    expect(SuperadminRoutes.attendanceCall, '/attendance/calls/:callId');
    expect(SuperadminRoutes.devAttendance, '/dev/attendance');
  });

  testWidgets('exposes Attendance inside Acompanhamento', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? destination;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: unavailableSuperadminLogout,
          currentDestination: 'attendance',
          onDestinationSelected: (value) => destination = value,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acompanhamento'), findsOneWidget);
    await tester.tap(find.byKey(const Key('superadmin-navigation-attendance')));
    expect(destination, 'attendance');
  });

  testWidgets('shell hides attendance creation when capability is not proven', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: unavailableSuperadminLogout,
          currentDestination: 'attendance',
          onDestinationSelected: (_) {},
          canAccessCapability: (_) => false,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assiduidade'), findsOneWidget);
    expect(find.text('Nova chamada'), findsNothing);
  });

  testWidgets('opens local attendance routes', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final repository = DevelopmentAttendanceRepository.content();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
      attendanceRepository: repository,
      attendancePermissions: const AttendancePermissions.owner(),
      allowDevelopmentPreview: true,
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    addTearDown(repository.dispose);

    router.go(SuperadminRoutes.attendance);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Nova chamada'), findsOneWidget);

    router.go('/dev/attendance/calls/call-progress');
    await tester.pumpAndSettle();
    expect(find.text('Lançar chamada'), findsWidgets);
    expect(find.text('1 obrigatória pendente'), findsOneWidget);
    expect(find.text('Rotina demonstrativa de Lia Horizonte'), findsOneWidget);
    final routineAction = find.byKey(const Key('attendance-open-daily-routine-participant-1'));
    await tester.ensureVisible(routineAction);
    await tester.pump();
    await tester.tap(routineAction);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dev/daily-routine');

    router.go('/dev/attendance');
    await tester.pumpAndSettle();
    expect(find.text('Nova chamada'), findsOneWidget);
    expect(find.text('Ações'), findsOneWidget);
    expect(find.byKey(const ValueKey('attendance-open-call-progress')), findsOneWidget);
    tester
        .widget<IconButton>(find.byKey(const ValueKey('attendance-open-call-progress')))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dev/attendance/calls/call-progress');
  });

  testWidgets('development attendance routes never use the production repository', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final repository = _TrackingAttendanceRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      attendanceRepository: repository,
      attendancePermissions: const AttendancePermissions.owner(),
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    addTearDown(repository.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final routeCase in const [
      (path: '/dev/attendance', expectedText: 'Nova chamada'),
      (path: '/dev/attendance/new', expectedText: 'Contexto da chamada'),
      (path: '/dev/attendance/calls/call-progress', expectedText: 'Lançar chamada'),
    ]) {
      repository.calls.clear();
      router.go(routeCase.path);
      await tester.pumpAndSettle();

      expect(find.text(routeCase.expectedText), findsWidgets, reason: routeCase.path);
      expect(repository.calls, isEmpty, reason: routeCase.path);
    }
  });

  // ADR 0034 (R04): com o repositorio real composto, as rotas de mutacao de
  // Assiduidade abrem; o servidor revalida ator, capacidade e tenant.
  testWidgets('production attendance opens creation and calls from the dashboard', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final repository = _TrackingAttendanceRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      attendanceRepository: repository,
      attendancePermissions: const AttendancePermissions.owner(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    addTearDown(repository.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    repository.calls.clear();
    router.go('/attendance');
    await tester.pumpAndSettle();
    expect(repository.calls, ['fetchAccess', 'fetchDashboard']);
    final create = find.widgetWithText(FilledButton, 'Nova chamada');
    expect(create, findsOneWidget);
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/attendance/new');
    expect(repository.calls, contains('fetchContextOptions'));

    router.go('/attendance');
    await tester.pumpAndSettle();
    final open = find.byKey(const ValueKey('attendance-open-call-progress'));
    expect(open, findsOneWidget);
    tester.widget<IconButton>(open).onPressed!();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/attendance/calls/call-progress');
    expect(repository.calls, contains('fetchCall:call-progress'));

    for (final path in const ['/attendance/new', '/attendance/calls/call-progress']) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path, reason: path);
      expect(
        find.byKey(const Key('production-mutation-capability-unavailable')),
        findsNothing,
        reason: path,
      );
    }
  });
}

final class _TrackingAttendanceRepository
    implements AttendanceRepository, AttendanceDashboardRepository, AttendanceHistoryRepository {
  final _delegate = DevelopmentAttendanceRepository.content();
  final calls = <String>[];

  @override
  Future<AttendanceHistoryPageResult> fetchHistory(AttendanceHistoryQuery query) async {
    calls.add('fetchHistory');
    return AttendanceHistoryPageResult(
      items: [
        AttendanceHistoryItem(
          id: 'call-progress',
          date: DateTime(2026, 9, 15),
          institutionId: 'inst-1',
          institutionName: 'Escola',
          unitId: 'unit-1',
          unitName: 'Unidade',
          groupId: 'group-1',
          groupName: 'Turma R14 S10',
          status: AttendanceCallStatus.completed,
          responsible: 'Ana',
          expected: 3,
          present: 2,
          absent: 1,
          late: 0,
          earlyDepartures: 0,
          officialRecords: 3,
        ),
      ],
      hasMore: false,
    );
  }

  void dispose() => _delegate.dispose();

  @override
  Future<AttendanceDashboardAccess> fetchAccess() {
    calls.add('fetchAccess');
    return _delegate.fetchAccess();
  }

  @override
  Future<AttendanceDashboardSnapshot> fetchDashboard(AttendanceDashboardQuery query) {
    calls.add('fetchDashboard');
    return _delegate.fetchDashboard(query);
  }

  @override
  Future<AttendanceContextOptions> fetchContextOptions({required DateTime date}) {
    calls.add('fetchContextOptions');
    return _delegate.fetchContextOptions(date: date);
  }

  @override
  Future<AttendanceCall?> fetchCall(String id) {
    calls.add('fetchCall:$id');
    return _delegate.fetchCall(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
