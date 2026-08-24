import 'package:coelo_superadmin/app/dev_menu/development_attendance_repository.dart';
import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('content persists created calls and edits only in the same instance', () async {
    final repository = DevelopmentAttendanceRepository.content();
    final created = await repository.createCall(
      AttendanceCallDraft(
        institutionId: 'institution-1',
        unitId: 'unit-1',
        groupId: 'group-sun',
        date: DateTime(2026, 8, 24),
      ),
    );
    await repository.setParticipantState(
      created.id,
      created.participants.first.id,
      AttendancePresenceState.present,
      expectedVersion: 1,
    );

    final persisted = await repository.fetchCall(created.id);
    expect(persisted?.participants.first.state, AttendancePresenceState.present);
    expect((await repository.fetchOverview()).calls.first.id, created.id);

    final reset = DevelopmentAttendanceRepository.content();
    expect(await reset.fetchCall(created.id), isNull);
  });

  test('empty, failure and unauthorized scenarios are deterministic', () async {
    expect((await DevelopmentAttendanceRepository.empty().fetchOverview()).calls, isEmpty);
    await expectLater(
      DevelopmentAttendanceRepository.failure().fetchOverview(),
      throwsA(isA<AttendanceUnavailableException>()),
    );
    await expectLater(
      DevelopmentAttendanceRepository.unauthorized().fetchOverview(),
      throwsA(isA<AttendanceUnauthorizedException>()),
    );
  });
}
