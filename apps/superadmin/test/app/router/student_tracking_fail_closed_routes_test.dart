import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_superadmin/features/student_tracking/domain/student_tracking.dart';
import 'package:coelo_superadmin/features/student_tracking/presentation/student_tracking_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('development students use local examples while manage routes stay fail-closed', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    final repository = _TripwireStudentTrackingRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      studentTrackingRepository: repository,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go(SuperadminRoutes.devStudents);
    await tester.pumpAndSettle();

    expect(find.byType(StudentTrackingPage), findsOneWidget);
    expect(find.byKey(const Key('student-tracking-unavailable')), findsNothing);
    expect(find.text('Lia Martins'), findsWidgets);
    expect(find.text('2 itens'), findsOneWidget);
    expect(find.text('8.8/10'), findsOneWidget);
    expect(repository.calls, 0);

    for (final path in const ['/students/child-1/manage', '/dev/students/child-1/manage']) {
      router.go(path);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        path.startsWith('/dev/') ? path : '/errors/mutation-capability-unavailable',
        reason: path,
      );
      expect(find.byType(SuperadminErrorScreen), findsOneWidget, reason: path);
      expect(
        tester.widget<SuperadminErrorScreen>(find.byType(SuperadminErrorScreen)).kind,
        SuperadminErrorKind.unavailable,
        reason: path,
      );
      expect(find.byType(StudentTrackingPage), findsNothing, reason: path);
      expect(repository.calls, 0, reason: path);
    }
  });

  testWidgets('release guard keeps development students unreachable', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final repository = _TripwireStudentTrackingRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      studentTrackingRepository: repository,
      allowDevelopmentPreview: false,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.devStudents);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.home);
    expect(find.byType(StudentTrackingPage), findsNothing);
    expect(repository.calls, 0);
  });
}

final class _TripwireStudentTrackingRepository implements StudentTrackingRepository {
  var calls = 0;

  Never _unexpectedCall() {
    calls += 1;
    throw StateError('The production StudentTrackingRepository must stay unused.');
  }

  @override
  Future<StudentTrackingChildPage> fetchChildren({
    String? query,
    StudentTrackingCursor? after,
    int limit = 20,
  }) async => _unexpectedCall();

  @override
  Future<StudentTrackingSnapshot> fetchSnapshot({
    required String childContextId,
    String? activityId,
    String? periodId,
    StudentTrackingAgendaCursor? agendaAfter,
    int agendaLimit = 20,
  }) async => _unexpectedCall();
}
