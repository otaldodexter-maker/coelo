import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/attendance/attendance_pages.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_attendance_repository.dart';

const _presenceActions = ['Presente', 'Falta', 'Atraso', 'Saída antecipada', 'Atraso + saída'];

void main() {
  for (final scenario in const [(375.0, 1.0), (768.0, 1.0), (375.0, 2.0)]) {
    final width = scenario.$1;
    final scale = scenario.$2;
    testWidgets('presence actions stay tappable at $width at ${scale}x text', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repository = FakeAttendanceRepository.seeded();
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: AttendanceCallPage(
            repository: repository,
            callId: 'call-progress',
            permissions: const AttendancePermissions.owner(),
            logout: unavailableSuperadminLogout,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      if (width < 600) {
        final compactActions = find.byType(SegmentedButton<AttendancePresenceState>);
        expect(compactActions, findsNWidgets(3));
        for (var index = 0; index < compactActions.evaluate().length; index++) {
          final action = compactActions.at(index);
          await tester.ensureVisible(action);
          await tester.pump();
          expect(
            tester.getSize(action).height,
            greaterThanOrEqualTo(CoeloSize.touchMin),
            reason: 'ações compactas em $width devem manter o alvo mínimo',
          );
        }
      } else {
        for (final label in _presenceActions) {
          final action = find.widgetWithText(OutlinedButton, label).first;
          await tester.ensureVisible(action);
          await tester.pump();
          expect(
            tester.getSize(action).height,
            greaterThanOrEqualTo(CoeloSize.touchMin),
            reason: '$label at $width must keep the minimum touch target',
          );
        }
      }
    });
  }
}
