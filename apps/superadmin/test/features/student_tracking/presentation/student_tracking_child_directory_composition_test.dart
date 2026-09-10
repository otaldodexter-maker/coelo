import 'dart:async';

import 'package:coelo_api/children.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/children/presentation/child_directory_panel.dart';
import 'package:coelo_superadmin/features/student_tracking/domain/student_tracking.dart';
import 'package:coelo_superadmin/features/student_tracking/presentation/student_tracking_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _institutionId = '10000000-0000-0000-0000-000000000001';
const _institutionBId = '10000000-0000-0000-0000-000000000002';
const _contextAId = '20000000-0000-0000-0000-000000000001';
const _contextBId = '20000000-0000-0000-0000-000000000002';

const _contextA = SuperadminAuthContext(
  platformRoleCode: 'owner',
  scopeKind: SuperadminAuthScopeKind.institution,
  scopeInstitutionId: _institutionId,
  permissionCodes: {'platform.read', 'people.read'},
  aal: 'aal1',
);

const _contextB = SuperadminAuthContext(
  platformRoleCode: 'owner',
  scopeKind: SuperadminAuthScopeKind.institution,
  scopeInstitutionId: _institutionBId,
  permissionCodes: {'platform.read', 'people.read'},
  aal: 'aal1',
);

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

final class _PendingChildRead {
  final requests = <ChildDirectoryRequest>[];
  final responses = <Completer<ChildDirectoryPage>>[];

  Future<ChildDirectoryPage> call(ChildDirectoryRequest request) {
    requests.add(request);
    final response = Completer<ChildDirectoryPage>();
    responses.add(response);
    return response.future;
  }
}

void main() {
  testWidgets('the production composition is honest on both halves at once', (tester) async {
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

    // This is what /students composes today: a real child directory over a
    // tracking repository that has no production implementation.
    expect(find.byKey(const Key('student-tracking-directory')), findsOneWidget);
    expect(find.text('Sintética Um'), findsOneWidget);
    // The page is a ListView, so the tracking half is built only once reached.
    await tester.scrollUntilVisible(
      find.byKey(const Key('student-tracking-unavailable')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('student-tracking-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('student-tracking-unavailable')), findsOneWidget);
    expect(find.text('Acompanhamento indisponível'), findsOneWidget);

    // The unavailable half must not offer a way out that does not exist.
    final panel = tester.widget<CoeloStatePanel>(
      find.byKey(const Key('student-tracking-unavailable')),
    );
    expect(panel.onAction, isNull);
    expect(panel.actionLabel, isNull);
  });

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

  testWidgets('students route discards a pending page after authenticated context changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final read = _PendingChildRead();
    final session = SuperadminSession()
      ..authorize(_contextA, sessionId: '40000000-0000-0000-0000-000000000001');
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
    await tester.pump();
    expect(read.requests, hasLength(1));
    expect(read.requests.single.institutionId, isNull);
    expect(read.requests.single.after, isNull);

    read.responses.single.complete(
      _page(_institutionId, _contextAId, 'Aluna A', withNextPage: true),
    );
    await tester.pump();
    final nextPage = find.byKey(const Key('child-directory-next'));
    await tester.ensureVisible(nextPage);
    await tester.pumpAndSettle();
    await tester.tap(nextPage);
    await tester.pump();
    expect(read.requests, hasLength(2));
    expect(read.requests[1].after?.name, 'aluna a');
    expect(read.requests[1].after?.contextId, _contextAId);

    session.authorize(_contextB, sessionId: '40000000-0000-0000-0000-000000000002');
    await tester.pump();
    expect(read.requests, hasLength(3));
    expect(read.requests.last.institutionId, isNull);
    expect(read.requests.last.after, isNull);

    read.responses.last.complete(_page(_institutionBId, _contextBId, 'Aluna B'));
    await tester.pump();
    expect(find.text('Aluna B'), findsOneWidget);

    read.responses[1].complete(_page(_institutionId, _contextAId, 'Aluna A tardia'));
    await tester.pump();
    expect(find.text('Aluna B'), findsOneWidget);
    expect(find.text('Aluna A tardia'), findsNothing);
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

ChildDirectoryPage _page(
  String institutionId,
  String contextId,
  String personName, {
  bool withNextPage = false,
}) => ChildDirectoryPage(
  items: [
    ChildDirectoryItem(
      contextId: contextId,
      personId: '30000000-0000-0000-0000-000000000001',
      personName: personName,
      institutionId: institutionId,
      institutionName: 'Instituição sintética',
    ),
  ],
  nextCursor: withNextPage
      ? ChildDirectoryCursor(name: personName.toLowerCase(), contextId: contextId)
      : null,
);
