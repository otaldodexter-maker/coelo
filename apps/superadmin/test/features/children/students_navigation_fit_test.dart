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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _institutionA = '10000000-0000-0000-0000-000000000001';
const _contextA = '20000000-0000-0000-0000-000000000001';

final class _RecordingChildRead {
  final requests = <ChildDirectoryRequest>[];
  List<ChildDirectoryItem> items = const [];

  Future<ChildDirectoryPage> call(ChildDirectoryRequest request) async {
    requests.add(request);
    return ChildDirectoryPage(items: items, nextCursor: null);
  }
}

ChildDirectoryItem _item() => const ChildDirectoryItem(
  contextId: _contextA,
  personId: '30000000-0000-0000-0000-000000000001',
  personName: 'Sintética Um',
  institutionId: _institutionA,
  institutionName: 'Instituição Sintética',
);

void main() {
  testWidgets('Alunos reaches the authorized list through its normal route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final read = _RecordingChildRead()..items = [_item()];
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
    await tester.pumpAndSettle();
    router.go(SuperadminRoutes.students);
    await tester.pumpAndSettle();

    expect(read.requests, hasLength(1));
    expect(find.byKey(const Key('student-tracking-directory')), findsOneWidget);
    expect(find.text('Sintética Um'), findsOneWidget);
  });

  testWidgets('the tracking screen keeps its own states below the list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final read = _RecordingChildRead()..items = [_item()];
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
    await tester.pumpAndSettle();
    router.go(SuperadminRoutes.students);
    await tester.pumpAndSettle();

    // The unavailable tracking repository still reports honestly, and the list
    // above it is not affected by that failure.
    expect(find.byKey(const Key('student-tracking-unavailable')), findsOneWidget);
    expect(find.text('Sintética Um'), findsOneWidget);
  });

  testWidgets('without a composed read the screen renders exactly as before', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: StudentTrackingPage(
          repository: const UnavailableStudentTrackingRepository(),
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChildDirectoryPanel), findsNothing);
    expect(find.byKey(const Key('student-tracking-unavailable')), findsOneWidget);
  });

  testWidgets('a revoked session drops the list without leaving names on screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final read = _RecordingChildRead()..items = [_item()];
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
    await tester.pumpAndSettle();
    router.go(SuperadminRoutes.students);
    await tester.pumpAndSettle();
    expect(find.text('Sintética Um'), findsOneWidget);

    session.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Sintética Um'), findsNothing);
  });

  testWidgets('the embedded list lays out without overflow at 375 and 200 percent', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final read = _RecordingChildRead()..items = [_item()];
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: StudentTrackingPage(
          repository: const UnavailableStudentTrackingRepository(),
          logout: unavailableSuperadminLogout,
          childDirectoryRead: read.call,
          sessionAvailable: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('student-tracking-directory')), findsOneWidget);
  });
}
