import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryAttendanceRepository', () {
    late InMemoryAttendanceRepository repository;

    setUp(() => repository = InMemoryAttendanceRepository.seeded());

    test('marks only unmarked participants as present', () {
      final call = repository.callById('call-progress')!;
      final absent = call.participants.firstWhere((item) => item.id == 'participant-2');

      repository.markRemainingPresent(call.id);

      expect(absent.state, AttendancePresenceState.absent);
      expect(
        call.participants.where((item) => item.state == AttendancePresenceState.unmarked),
        isEmpty,
      );
    });

    test('does not complete while a participant is unmarked', () {
      expect(() => repository.completeCall('call-progress'), throwsStateError);
    });

    test('pending family notice does not affect presence percentage', () {
      final before = repository.metrics.presencePercent;

      repository.addPendingNoticeForTest('call-progress');

      expect(repository.metrics.presencePercent, before);
      expect(repository.pendingNoticeCount, greaterThan(0));
    });

    test('professional confirmation creates the official attendance state', () {
      final before = repository.metrics.presencePercent;

      repository.confirmNotice('notice-1');

      final call = repository.callById('call-progress')!;
      expect(call.participants.first.state, AttendancePresenceState.late);
      expect(repository.notices.first.pending, isFalse);
      expect(repository.metrics.presencePercent, before);
    });

    test('teacher can only access assigned context', () {
      const permissions = AttendancePermissions.teacher(
        assignedGroupIds: {'group-sun'},
        assignedActivityContextIds: {'activity-music-group-sun'},
      );

      expect(permissions.canOperate(repository.callById('call-progress')!), isTrue);
      expect(permissions.canOperate(repository.callById('call-other-group')!), isFalse);
    });

    test('correction requires a reason and preserves a revision', () {
      expect(
        () => repository.correctParticipant(
          callId: 'call-completed',
          participantId: 'participant-1',
          state: AttendancePresenceState.absent,
          reason: ' ',
        ),
        throwsArgumentError,
      );

      repository.correctParticipant(
        callId: 'call-completed',
        participantId: 'participant-1',
        state: AttendancePresenceState.absent,
        reason: 'Correção conferida pelo Owner',
      );

      final corrected = repository.callById('call-completed')!;
      expect(corrected.status, AttendanceCallStatus.corrected);
      expect(corrected.revisions, hasLength(1));
      expect(corrected.revisions.single.previous, AttendancePresenceState.present);
      expect(corrected.revisions.single.current, AttendancePresenceState.absent);
    });

    test('activity without required attendance cannot create a call', () {
      expect(
        () => repository.createCall(
          AttendanceCallDraft(
            institutionId: 'institution-1',
            unitId: 'unit-1',
            groupId: 'group-sun',
            activityContextId: 'activity-art-group-sun',
            date: AttendanceFixtures.today,
          ),
        ),
        throwsStateError,
      );
    });
  });
}
