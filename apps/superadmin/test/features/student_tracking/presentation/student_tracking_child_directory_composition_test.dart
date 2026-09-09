import 'package:coelo_api/children.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/children/presentation/child_directory_panel.dart';
import 'package:coelo_superadmin/features/student_tracking/domain/student_tracking.dart';
import 'package:coelo_superadmin/features/student_tracking/presentation/student_tracking_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _institutionId = '10000000-0000-0000-0000-000000000001';

final class _RecordingChildRead {
  final requests = <ChildDirectoryRequest>[];

  Future<ChildDirectoryPage> call(ChildDirectoryRequest request) async {
    requests.add(request);
    return ChildDirectoryPage(
      items: const [
        ChildDirectoryItem(
          contextId: '20000000-0000-0000-0000-000000000001',
          personId: '30000000-0000-0000-0000-000000000001',
          personName: 'Sintética Um',
          institutionId: _institutionId,
          institutionName: 'Instituição Sintética',
        ),
      ],
    );
  }
}

void main() {
  testWidgets('composes the authorized child list above tracking', (tester) async {
    final read = _RecordingChildRead();

    await tester.pumpWidget(
      _app(
        StudentTrackingPage(
          repository: const UnavailableStudentTrackingRepository(),
          logout: unavailableSuperadminLogout,
          childDirectoryRead: read.call,
          sessionAvailable: true,
          institutionId: _institutionId,
          revision: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(read.requests, hasLength(1));
    expect(read.requests.single.institutionId, _institutionId);
    expect(find.byKey(const Key('student-tracking-directory')), findsOneWidget);
    expect(find.text('Sintética Um'), findsOneWidget);
    final card = tester.widget<CoeloAdminInteractiveCard>(
      find.byKey(const Key('child-card-20000000-0000-0000-0000-000000000001')),
    );
    expect(card.onPressed, isNull);
    expect(card.minHeight, 216);
  });

  testWidgets('without an injected child read keeps the tracking page unchanged', (tester) async {
    await tester.pumpWidget(
      _app(
        const StudentTrackingPage(
          repository: UnavailableStudentTrackingRepository(),
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChildDirectoryPanel), findsNothing);
    expect(find.byKey(const Key('student-tracking-unavailable')), findsOneWidget);
  });

  testWidgets('revoked session clears the authorized child list', (tester) async {
    final read = _RecordingChildRead();

    await tester.pumpWidget(
      _app(
        StudentTrackingPage(
          repository: const UnavailableStudentTrackingRepository(),
          logout: unavailableSuperadminLogout,
          childDirectoryRead: read.call,
          sessionAvailable: true,
          institutionId: _institutionId,
          revision: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sintética Um'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        StudentTrackingPage(
          repository: const UnavailableStudentTrackingRepository(),
          logout: unavailableSuperadminLogout,
          childDirectoryRead: read.call,
          sessionAvailable: false,
          institutionId: _institutionId,
          revision: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sintética Um'), findsNothing);
    expect(find.byKey(const Key('child-directory-denied')), findsOneWidget);
  });

  testWidgets('students route consumes the authorized read and clears it on sign out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final read = _RecordingChildRead();
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      childDirectoryRead: read.call,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    router.go(SuperadminRoutes.students);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.students);
    expect(read.requests, hasLength(1));
    expect(find.text('Sintética Um'), findsOneWidget);

    session.signOut();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
    expect(find.text('Sintética Um'), findsNothing);
  });

  testWidgets('embedded child list has no overflow at 375 and 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final read = _RecordingChildRead();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: StudentTrackingPage(
            repository: const UnavailableStudentTrackingRepository(),
            logout: unavailableSuperadminLogout,
            childDirectoryRead: read.call,
            sessionAvailable: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('student-tracking-directory')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child) => MaterialApp(theme: CoeloTheme.light, home: child);
