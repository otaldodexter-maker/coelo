import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/attendance/attendance_pages.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in const [375.0, 768.0, 1024.0, 1440.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('prototypes fit at ${width.toInt()} px in ${brightness.name}', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final theme = brightness == Brightness.light ? CoeloTheme.light : CoeloTheme.dark;

        final attendance = InMemoryAttendanceRepository.seeded();
        addTearDown(attendance.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: AttendanceDashboardPage(
              repository: attendance,
              permissions: const AttendancePermissions.owner(),
              logout: unavailableSuperadminLogout,
              onCreate: () {},
              onOpenCall: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: DailyRoutineDirectoryPage(
              repository: InMemoryDailyRoutineRepository.seeded(),
              permissions: DailyRoutinePermissions.owner,
              logout: unavailableSuperadminLogout,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('supports keyboard, semantics, reduced motion and 200% text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 900),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: DailyRoutineDirectoryPage(
            repository: InMemoryDailyRoutineRepository.seeded(),
            permissions: DailyRoutinePermissions.owner,
            logout: unavailableSuperadminLogout,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
