import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/attendance/attendance_pages.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_attendance_repository.dart';

/// Detalhe da chamada mostra a rotina diária conforme a origem (ADR 0041 B3,
/// spec 052 §5): snapshot gravado na conclusão, rotina vigente numa chamada
/// aberta, indicação "rotina atual (não registrada na época)" no legado e
/// "Sem rotina vinculada" quando não há rotina. O servidor decide a origem.
Future<void> _pump(WidgetTester tester, FakeAttendanceRepository repository, String callId) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1024));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: AttendanceCallPage(
        repository: repository,
        callId: callId,
        permissions: const AttendancePermissions.owner(),
        logout: unavailableSuperadminLogout,
        onBack: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('completed call shows the snapshot with its revision', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    await _pump(tester, repository, 'call-completed');

    expect(find.byKey(const Key('attendance-call-routine')), findsWidgets);
    expect(find.text('Rotina demonstrativa Lua · v1'), findsWidgets);
    expect(find.text('registrada na conclusão'), findsWidgets);
    expect(find.text('rotina atual (não registrada na época)'), findsNothing);
  });

  testWidgets('open call follows the effective routine without the legacy hint', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    await _pump(tester, repository, 'call-progress');

    expect(find.text('Rotina demonstrativa Sol · v2'), findsWidgets);
    expect(find.text('rotina vigente'), findsWidgets);
    expect(find.text('rotina atual (não registrada na época)'), findsNothing);
  });

  testWidgets('call without routine says so', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    await _pump(tester, repository, 'call-other-group');

    expect(find.text('Sem rotina vinculada'), findsWidgets);
  });

  test('legacy completed call without snapshot gets the Owner wording', () {
    const legacy = AttendanceRoutineRef(
      source: AttendanceRoutineSource.current,
      applicationId: 'app-1',
      revisionNo: 3,
      name: 'Rotina Berçário',
    );
    expect(legacy.isLegacyFor(AttendanceCallStatus.completed), isTrue);
    expect(legacy.isLegacyFor(AttendanceCallStatus.reopened), isTrue);
    expect(legacy.isLegacyFor(AttendanceCallStatus.inProgress), isFalse);
    expect(legacy.sourceLabel(concluded: true), 'rotina atual (não registrada na época)');
    expect(legacy.label, 'Rotina Berçário · v3');
    const snapshot = AttendanceRoutineRef(
      source: AttendanceRoutineSource.snapshot,
      applicationId: 'app-1',
      revisionNo: 0,
      name: 'Rotina Berçário',
    );
    expect(snapshot.label, 'Rotina Berçário', reason: 'revisão 0 não vira "v0"');
    expect(snapshot.isLegacyFor(AttendanceCallStatus.completed), isFalse);
    expect(const AttendanceRoutineRef.none().label, 'Sem rotina vinculada');
  });
}
