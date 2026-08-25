import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_attendance_repository.dart';

void main() {
  group('FakeAttendanceRepository', () {
    late FakeAttendanceRepository repository;

    setUp(() => repository = FakeAttendanceRepository.seeded());
    tearDown(() => repository.dispose());

    test('marks only unmarked participants as present', () async {
      final call = (await repository.fetchCall('call-progress'))!;
      final absent = call.participants.firstWhere((item) => item.id == 'participant-2');

      await repository.markRemainingPresent(call.id, expectedVersion: call.version);

      expect(absent.state, AttendancePresenceState.absent);
      expect(
        call.participants.where((item) => item.state == AttendancePresenceState.unmarked),
        isEmpty,
      );
    });

    test('undoes only participants affected by the recorded bulk operation', () async {
      final call = (await repository.fetchCall('call-progress'))!;
      final result = await repository.markRemainingPresent(call.id, expectedVersion: call.version);

      await repository.setParticipantState(
        call.id,
        'participant-1',
        AttendancePresenceState.absent,
        expectedVersion: call.version,
      );
      await repository.undoBulk(result.receipt);

      expect(call.participants[0].state, AttendancePresenceState.absent);
      expect(call.participants[1].state, AttendancePresenceState.absent);
      expect(call.participants[2].state, AttendancePresenceState.unmarked);
    });

    test('does not complete while a participant is unmarked', () async {
      final call = (await repository.fetchCall('call-progress'))!;

      await expectLater(
        repository.completeCall(call.id, expectedVersion: call.version),
        throwsStateError,
      );
    });

    test('pending family notice does not affect presence percentage', () {
      final before = repository.metrics.presencePercent;

      repository.addPendingNoticeForTest('call-progress');

      expect(repository.metrics.presencePercent, before);
      expect(repository.pendingNoticeCount, greaterThan(0));
    });

    test('professional confirmation creates the official attendance state', () async {
      final before = repository.metrics.presencePercent;
      final call = (await repository.fetchCall('call-progress'))!;

      await repository.confirmNotice('notice-1', expectedVersion: call.version);

      expect(call.participants.first.state, AttendancePresenceState.late);
      expect(repository.notices.first.pending, isFalse);
      expect(repository.metrics.presencePercent, before);
    });

    test('teacher can only access assigned context', () async {
      const permissions = AttendancePermissions.teacher(
        assignedGroupIds: {'group-sun'},
        assignedActivityContextIds: {'activity-music-group-sun'},
      );
      final assigned = (await repository.fetchCall('call-progress'))!;
      final other = (await repository.fetchCall('call-other-group'))!;

      expect(permissions.canOperate(assigned), isTrue);
      expect(permissions.canOperate(other), isFalse);
    });

    test('correction requires a reason and preserves a revision', () async {
      final call = (await repository.fetchCall('call-completed'))!;
      await expectLater(
        repository.correctParticipant(
          callId: call.id,
          participantId: 'participant-1',
          state: AttendancePresenceState.absent,
          reason: ' ',
          expectedVersion: call.version,
        ),
        throwsArgumentError,
      );

      final corrected = await repository.correctParticipant(
        callId: call.id,
        participantId: 'participant-1',
        state: AttendancePresenceState.absent,
        reason: 'Correção conferida pelo Owner',
        expectedVersion: call.version,
      );

      expect(corrected.status, AttendanceCallStatus.completed);
      expect(corrected.revisions, hasLength(1));
      expect(corrected.revisions.single.previous, AttendancePresenceState.present);
      expect(corrected.revisions.single.current, AttendancePresenceState.absent);
    });

    test('activity without required attendance cannot create a call', () async {
      await expectLater(
        repository.createCall(
          AttendanceCallDraft(
            institutionId: 'institution-1',
            unitId: 'unit-1',
            groupId: 'group-sun',
            activityContextId: 'activity-art-group-sun',
            date: FakeAttendanceRepository.today,
          ),
        ),
        throwsStateError,
      );
    });
  });
}
