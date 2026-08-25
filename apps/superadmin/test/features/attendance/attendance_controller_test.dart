import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/attendance/attendance_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller exposes empty as a real loaded state', () async {
    final controller = AttendanceController(
      repository: _FakeAttendanceRepository(),
      permissions: const AttendancePermissions.readOnly(),
    );

    await controller.load();

    expect(controller.state, isA<AttendanceEmpty>());
  });

  test('bulk receipt can be undone only through the recorded operation', () async {
    final repository = _FakeAttendanceRepository(call: _call());
    final controller = AttendanceController(
      repository: repository,
      permissions: const AttendancePermissions.owner(),
    );

    final result = await controller.markRemainingPresent(repository.call!);
    await controller.undoLastBulk();

    expect(result.receipt.affectedParticipantIds, {'participant-1'});
    expect(repository.undoneOperationId, 'operation-1');
    expect(controller.lastBulkReceipt, isNull);
  });
}

AttendanceCall _call() => AttendanceCall(
  id: 'call-1',
  institutionId: 'institution-1',
  institutionName: 'Instituição',
  unitId: 'unit-1',
  unitName: 'Unidade',
  groupId: 'group-1',
  groupName: 'Turma',
  date: DateTime(2026, 8, 10),
  status: AttendanceCallStatus.inProgress,
  participants: [AttendanceParticipant(id: 'participant-1', name: 'Pessoa')],
  version: 1,
);

final class _FakeAttendanceRepository implements AttendanceRepository {
  _FakeAttendanceRepository({this.call});
  AttendanceCall? call;
  String? undoneOperationId;

  @override
  Future<AttendanceOverview> fetchOverview({DateTime? date}) async => AttendanceOverview(
    calls: call == null ? const [] : [call!],
    notices: const [],
    metrics: const AttendanceMetrics(
      presencePercent: 0,
      justifiedAbsences: 0,
      unjustifiedAbsences: 0,
      late: 0,
      earlyDepartures: 0,
    ),
  );
  @override
  Future<AttendanceContextOptions> fetchContextOptions({required DateTime date}) async =>
      const AttendanceContextOptions(institutions: [], units: [], groups: [], activities: []);

  @override
  Future<AttendanceBulkResult> markRemainingPresent(
    String callId, {
    required int expectedVersion,
  }) async {
    final receipt = AttendanceBulkReceipt(
      operationId: 'operation-1',
      callId: callId,
      affectedParticipantIds: const {'participant-1'},
      previousVersion: expectedVersion,
      currentVersion: expectedVersion + 1,
    );
    return AttendanceBulkResult(call: call!, receipt: receipt);
  }

  @override
  Future<AttendanceCall> undoBulk(AttendanceBulkReceipt receipt) async {
    undoneOperationId = receipt.operationId;
    return call!;
  }

  @override
  Future<AttendanceCall> completeCall(String callId, {required int expectedVersion}) async => call!;
  @override
  Future<AttendanceBulkResult> clearPresenceMarks(String callId, {required int expectedVersion}) =>
      throw UnimplementedError();
  @override
  Future<AttendanceCall> confirmNotice(String noticeId, {required int expectedVersion}) async =>
      call!;
  @override
  Future<AttendanceCall> correctParticipant({
    required String callId,
    required String participantId,
    required AttendancePresenceState state,
    required String reason,
    required int expectedVersion,
  }) async => call!;
  @override
  Future<AttendanceCall> createCall(AttendanceCallDraft draft) async => call!;
  @override
  Future<AttendanceCall?> fetchCall(String id) async => call;
  @override
  Future<AttendanceCall> reopenCall(
    String callId, {
    required int expectedVersion,
    required String reason,
  }) async => call!;
  @override
  Future<AttendanceCall> setParticipantState(
    String callId,
    String participantId,
    AttendancePresenceState state, {
    required int expectedVersion,
  }) async => call!;
}
