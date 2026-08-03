import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/attendance/attendance_pages.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Owner sees attendance write actions', (tester) async {
    final repository = InMemoryAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceDashboardPage(
          repository: repository,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCreate: () {},
          onOpenCall: (_) {},
        ),
      ),
    );

    expect(find.text('Nova chamada'), findsOneWidget);
    expect(find.textContaining('Dados locais'), findsOneWidget);
  });

  testWidgets('read-only administrator has no write action', (tester) async {
    final repository = InMemoryAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceDashboardPage(
          repository: repository,
          permissions: const AttendancePermissions.readOnly(),
          logout: unavailableSuperadminLogout,
          onCreate: () {},
          onOpenCall: (_) {},
        ),
      ),
    );

    expect(find.text('Nova chamada'), findsNothing);
    expect(find.textContaining('somente leitura'), findsOneWidget);
  });

  testWidgets('call page marks remaining and then completes', (tester) async {
    final repository = InMemoryAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          repository: repository,
          callId: 'call-progress',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
          onPreview: () {},
        ),
      ),
    );

    expect(find.text('Concluir chamada'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Concluir chamada')).onPressed,
      isNull,
    );

    await tester.tap(find.text('Marcar restantes como presentes'));
    await tester.pump();

    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Concluir chamada')).onPressed,
      isNotNull,
    );
  });

  testWidgets('teacher preview rejects a call outside assigned context', (tester) async {
    final repository = InMemoryAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceTeacherPreviewPage(
          repository: repository,
          callId: 'call-other-group',
          permissions: const AttendancePermissions.teacher(assignedGroupIds: {'group-sun'}),
          onBack: () {},
        ),
      ),
    );

    expect(find.textContaining('fora do vínculo'), findsOneWidget);
    expect(find.text('Marcar restantes como presentes'), findsNothing);
  });
}

Widget _app(Widget child) => MaterialApp(
  theme: CoeloTheme.light,
  home: MediaQuery(
    data: const MediaQueryData(size: Size(1440, 900)),
    child: child,
  ),
);
