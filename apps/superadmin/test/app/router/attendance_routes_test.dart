import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/dev_menu/development_attendance_repository.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  testWidgets('opens local attendance routes', (tester) async {
    final session = SuperadminSession()..signIn();
    final repository = DevelopmentAttendanceRepository.content();
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
    expect(find.text('Nova chamada'), findsOneWidget);

    router.go('/attendance/calls/call-progress');
    await tester.pumpAndSettle();
    expect(find.text('Lançar chamada'), findsWidgets);

    router.go('/dev/attendance');
    await tester.pumpAndSettle();
    expect(find.text('Nova chamada'), findsOneWidget);
  });

  testWidgets('development attendance routes never use the production repository', (tester) async {
    final session = SuperadminSession()..signIn();
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

  testWidgets('production attendance routes use the injected repository', (tester) async {
    final session = SuperadminSession()..signIn();
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

    for (final routeCase in const [
      (path: '/attendance', expectedCalls: ['fetchAccess', 'fetchDashboard']),
      (path: '/attendance/new', expectedCalls: ['fetchContextOptions']),
      (path: '/attendance/calls/call-progress', expectedCalls: ['fetchCall:call-progress']),
    ]) {
      repository.calls.clear();
      router.go(routeCase.path);
      await tester.pumpAndSettle();

      expect(repository.calls, routeCase.expectedCalls, reason: routeCase.path);
    }
  });
}

final class _TrackingAttendanceRepository
    implements AttendanceRepository, AttendanceDashboardRepository {
  final _delegate = DevelopmentAttendanceRepository.content();
  final calls = <String>[];

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
