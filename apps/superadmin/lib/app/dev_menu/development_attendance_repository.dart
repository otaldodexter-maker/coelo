import '../../features/attendance/attendance.dart';
import 'package:flutter/foundation.dart';

/// Stateful attendance fixture used only by the local development preview.
final class DevelopmentAttendanceRepository extends ChangeNotifier implements AttendanceRepository {
  DevelopmentAttendanceRepository.content()
    : _mode = _DevelopmentAttendanceMode.content,
      _calls = _seedCalls(),
      _notices = [
        AttendanceNotice(
          id: 'notice-1',
          callId: 'call-progress',
          participantId: 'participant-1',
          participantName: 'Lia Horizonte',
          intent: AttendanceNoticeIntent.lateArrival,
          reason: 'Consulta marcada',
          startDate: today,
          note: 'Chegada prevista para 9h.',
        ),
      ];

  DevelopmentAttendanceRepository.empty()
    : _mode = _DevelopmentAttendanceMode.empty,
      _calls = [],
      _notices = [];

  DevelopmentAttendanceRepository.failure()
    : _mode = _DevelopmentAttendanceMode.failure,
      _calls = [],
      _notices = [];

  DevelopmentAttendanceRepository.unauthorized()
    : _mode = _DevelopmentAttendanceMode.unauthorized,
      _calls = [],
      _notices = [];

  static final today = DateTime(2026, 8, 3);

  final _DevelopmentAttendanceMode _mode;
  final List<AttendanceCall> _calls;
  final List<AttendanceNotice> _notices;
  final Map<String, Map<String, AttendancePresenceState>> _bulkPrevious = {};
  var _nextCall = 1;
  var _nextNotice = 1;
  var _nextOperation = 1;

  List<AttendanceCall> get calls => List.unmodifiable(_calls);
  List<AttendanceNotice> get notices => List.unmodifiable(_notices);
  int get pendingNoticeCount => _notices.where((item) => item.pending).length;

  AttendanceMetrics get metrics {
    final official = _calls
        .where((call) => call.status == AttendanceCallStatus.completed)
        .expand((call) => call.participants)
        .where((item) => item.state != AttendancePresenceState.unmarked)
        .toList();
    final present = official.where(
      (item) => const {
        AttendancePresenceState.present,
        AttendancePresenceState.late,
        AttendancePresenceState.earlyDeparture,
        AttendancePresenceState.lateAndEarly,
      }.contains(item.state),
    );
    final absent = official.where((item) => item.state == AttendancePresenceState.absent);
    return AttendanceMetrics(
      presencePercent: official.isEmpty ? 0 : present.length / official.length * 100,
      justifiedAbsences: absent
          .where((item) => item.justification == AttendanceJustificationState.accepted)
          .length,
      unjustifiedAbsences: absent
          .where((item) => item.justification != AttendanceJustificationState.accepted)
          .length,
      late: official.where((item) => item.state == AttendancePresenceState.late).length,
      earlyDepartures: official
          .where((item) => item.state == AttendancePresenceState.earlyDeparture)
          .length,
    );
  }

  @override
  Future<AttendanceOverview> fetchOverview({DateTime? date}) async {
    _guard();
    final calls = date == null
        ? this.calls
        : this.calls.where((call) => _sameDate(call.date, date)).toList();
    return AttendanceOverview(calls: calls, notices: notices, metrics: metrics);
  }

  @override
  Future<AttendanceContextOptions> fetchContextOptions({
    required DateTime date,
  }) async {
    _guard();
    return const AttendanceContextOptions(
    institutions: [
      AttendanceContextOption(id: 'institution-1', name: 'Instituto Horizonte'),
      AttendanceContextOption(id: 'institution-2', name: 'Colégio Aurora'),
      AttendanceContextOption(id: 'institution-3', name: 'Espaço Ipê'),
    ],
    units: [
      AttendanceContextOption(id: 'unit-1', name: 'Unidade Centro', institutionId: 'institution-1'),
      AttendanceContextOption(id: 'unit-2', name: 'Unidade Norte', institutionId: 'institution-2'),
    ],
    groups: [
      AttendanceContextOption(
        id: 'group-sun',
        name: 'Turma Sol',
        institutionId: 'institution-1',
        unitId: 'unit-1',
      ),
      AttendanceContextOption(
        id: 'group-moon',
        name: 'Turma Lua',
        institutionId: 'institution-2',
        unitId: 'unit-2',
      ),
    ],
    canManage: true,
    activities: [
      AttendanceContextOption(
        id: 'activity-music-group-sun',
        name: 'Música',
        institutionId: 'institution-1',
        unitId: 'unit-1',
        groupId: 'group-sun',
      ),
      AttendanceContextOption(
        id: 'activity-art-group-sun',
        name: 'Arte',
        institutionId: 'institution-1',
        unitId: 'unit-1',
        groupId: 'group-sun',
        attendanceRequired: false,
      ),
    ],
    );
  }

  @override
  Future<AttendanceCall?> fetchCall(String id) async {
    _guard();
    return _callById(id);
  }

  @override
  Future<AttendanceCall> createCall(AttendanceCallDraft draft) async {
    _guard();
    if (draft.activityContextId == 'activity-art-group-sun') {
      throw StateError('Chamada não exigida para esta atividade.');
    }
    final call = AttendanceCall(
      id: 'call-created-${_nextCall++}',
      institutionId: draft.institutionId,
      institutionName: _institutionName(draft.institutionId),
      unitId: draft.unitId,
      unitName: draft.unitId == 'unit-1' ? 'Unidade Centro' : 'Unidade Norte',
      groupId: draft.groupId,
      groupName: draft.groupId == 'group-sun' ? 'Turma Sol' : 'Turma Lua',
      activityContextId: draft.activityContextId,
      activityName: draft.activityContextId == null ? null : 'Música',
      date: draft.date,
      status: AttendanceCallStatus.inProgress,
      canManage: true,
      participants: _participants(),
    );
    _calls.insert(0, call);
    notifyListeners();
    return call;
  }

  @override
  Future<AttendanceBulkResult> markRemainingPresent(
    String callId, {
    required int expectedVersion,
  }) async {
    _guard();
    final call = _requiredCall(callId);
    final previous = <String, AttendancePresenceState>{};
    for (final participant in call.participants) {
      if (participant.state == AttendancePresenceState.unmarked) {
        previous[participant.id] = participant.state;
        participant.state = AttendancePresenceState.present;
      }
    }
    call.status = AttendanceCallStatus.inProgress;
    call.updatedAt = DateTime(2026, 8, 3, 9, 10);
    final operationId = 'operation-${_nextOperation++}';
    _bulkPrevious[operationId] = previous;
    notifyListeners();
    return AttendanceBulkResult(
      call: call,
      receipt: AttendanceBulkReceipt(
        operationId: operationId,
        callId: callId,
        affectedParticipantIds: previous.keys.toSet(),
        previousVersion: expectedVersion,
        currentVersion: expectedVersion,
      ),
    );
  }

  @override
  Future<AttendanceBulkResult> clearPresenceMarks(
    String callId, {
    required int expectedVersion,
  }) async {
    _guard();
    final call = _requiredCall(callId);
    final previous = <String, AttendancePresenceState>{};
    for (final participant in call.participants) {
      if (participant.state == AttendancePresenceState.present) {
        previous[participant.id] = participant.state;
        participant.state = AttendancePresenceState.unmarked;
      }
    }
    final operationId = 'operation-${_nextOperation++}';
    _bulkPrevious[operationId] = previous;
    notifyListeners();
    return AttendanceBulkResult(
      call: call,
      receipt: AttendanceBulkReceipt(
        operationId: operationId,
        callId: callId,
        affectedParticipantIds: previous.keys.toSet(),
        previousVersion: expectedVersion,
        currentVersion: expectedVersion,
      ),
    );
  }

  @override
  Future<AttendanceCall> undoBulk(AttendanceBulkReceipt receipt) async {
    _guard();
    final call = _requiredCall(receipt.callId);
    final previous = _bulkPrevious.remove(receipt.operationId);
    if (previous == null) throw StateError('Operação em lote não encontrada.');
    for (final entry in previous.entries) {
      final participant = _requiredParticipant(call, entry.key);
      final appliedState = entry.value == AttendancePresenceState.unmarked
          ? AttendancePresenceState.present
          : AttendancePresenceState.unmarked;
      if (participant.state == appliedState) {
        participant.state = entry.value;
      }
    }
    notifyListeners();
    return call;
  }

  @override
  Future<AttendanceCall> setParticipantState(
    String callId,
    String participantId,
    AttendancePresenceState state, {
    required int expectedVersion,
  }) async {
    _guard();
    final call = _requiredCall(callId);
    _requiredParticipant(call, participantId).state = state;
    call.status = AttendanceCallStatus.inProgress;
    notifyListeners();
    return call;
  }

  @override
  Future<AttendanceCall> completeCall(String callId, {required int expectedVersion}) async {
    _guard();
    final call = _requiredCall(callId);
    if (call.hasUnmarked) {
      throw StateError('Marque todos os participantes antes de concluir.');
    }
    call.status = AttendanceCallStatus.completed;
    call.updatedAt = DateTime(2026, 8, 3, 9, 20);
    notifyListeners();
    return call;
  }

  @override
  Future<AttendanceCall> reopenCall(
    String callId, {
    required int expectedVersion,
    required String reason,
  }) async {
    _guard();
    if (reason.trim().isEmpty) throw ArgumentError.value(reason, 'reason');
    final call = _requiredCall(callId);
    call.status = AttendanceCallStatus.reopened;
    notifyListeners();
    return call;
  }

  @override
  Future<AttendanceCall> confirmNotice(String noticeId, {required int expectedVersion}) async {
    _guard();
    final notice = _notices.where((item) => item.id == noticeId).firstOrNull;
    if (notice == null) throw StateError('Aviso não encontrado.');
    final call = _requiredCall(notice.callId);
    if (!notice.pending) return call;
    final participant = _requiredParticipant(call, notice.participantId);
    participant.state = switch (notice.intent) {
      AttendanceNoticeIntent.absence => AttendancePresenceState.absent,
      AttendanceNoticeIntent.expectedPresence => AttendancePresenceState.present,
      AttendanceNoticeIntent.lateArrival => AttendancePresenceState.late,
      AttendanceNoticeIntent.earlyDeparture => AttendancePresenceState.earlyDeparture,
    };
    notice.pending = false;
    call.status = AttendanceCallStatus.inProgress;
    notifyListeners();
    return call;
  }

  @override
  Future<AttendanceCall> correctParticipant({
    required String callId,
    required String participantId,
    required AttendancePresenceState state,
    required String reason,
    required int expectedVersion,
  }) async {
    _guard();
    if (reason.trim().isEmpty) throw ArgumentError.value(reason, 'reason');
    final call = _requiredCall(callId);
    if (call.status != AttendanceCallStatus.completed) {
      throw StateError('Somente chamadas concluídas podem ser corrigidas.');
    }
    final participant = _requiredParticipant(call, participantId);
    final previous = participant.state;
    participant.state = state;
    call.revisions.add(
      AttendanceRevision(
        participantId: participantId,
        previous: previous,
        current: state,
        reason: reason.trim(),
        author: 'Owner Coelo',
        changedAt: DateTime(2026, 8, 3, 10, 30),
      ),
    );
    notifyListeners();
    return call;
  }

  void addPendingNotice(String callId) {
    _guard();
    _notices.add(
      AttendanceNotice(
        id: 'notice-test-${_nextNotice++}',
        callId: callId,
        participantId: 'participant-3',
        participantName: 'Noa Vale',
        intent: AttendanceNoticeIntent.absence,
        reason: 'Aviso familiar',
        startDate: today,
      ),
    );
    notifyListeners();
  }

  AttendanceCall? _callById(String id) => _calls.where((item) => item.id == id).firstOrNull;

  AttendanceCall _requiredCall(String id) =>
      _callById(id) ?? (throw StateError('Chamada não encontrada.'));

  AttendanceParticipant _requiredParticipant(AttendanceCall call, String id) =>
      call.participants.where((item) => item.id == id).firstOrNull ??
      (throw StateError('Participante não encontrado.'));

  void _guard() {
    switch (_mode) {
      case _DevelopmentAttendanceMode.content || _DevelopmentAttendanceMode.empty:
        return;
      case _DevelopmentAttendanceMode.failure:
        throw const AttendanceUnavailableException();
      case _DevelopmentAttendanceMode.unauthorized:
        throw const AttendanceUnauthorizedException();
    }
  }
}

enum _DevelopmentAttendanceMode { content, empty, failure, unauthorized }

List<AttendanceCall> _seedCalls() => [
  AttendanceCall(
    id: 'call-progress',
    institutionId: 'institution-1',
    institutionName: 'Instituto Horizonte',
    unitId: 'unit-1',
    unitName: 'Unidade Centro',
    groupId: 'group-sun',
    groupName: 'Turma Sol',
    activityContextId: 'activity-music-group-sun',
    activityName: 'Música · Turma Sol',
    date: DevelopmentAttendanceRepository.today,
    status: AttendanceCallStatus.inProgress,
    canManage: true,
    participants: _participants(secondState: AttendancePresenceState.absent),
    responsible: 'Prof. Marina',
  ),
  AttendanceCall(
    id: 'call-completed',
    institutionId: 'institution-2',
    institutionName: 'Colégio Aurora',
    unitId: 'unit-2',
    unitName: 'Unidade Norte',
    groupId: 'group-moon',
    groupName: 'Turma Lua',
    date: DateTime(2026, 8, 2),
    status: AttendanceCallStatus.completed,
    canManage: true,
    participants: _participants(
      firstState: AttendancePresenceState.present,
      secondState: AttendancePresenceState.absent,
      thirdState: AttendancePresenceState.late,
    )..[1].justification = AttendanceJustificationState.accepted,
    responsible: 'Prof. Caio',
  ),
  AttendanceCall(
    id: 'call-other-group',
    institutionId: 'institution-3',
    institutionName: 'Espaço Ipê',
    unitId: 'unit-3',
    unitName: 'Unidade Jardim',
    groupId: 'group-ipe',
    groupName: 'Turma Ipê',
    date: DevelopmentAttendanceRepository.today,
    status: AttendanceCallStatus.notStarted,
    canManage: true,
    participants: _participants(),
  ),
];

List<AttendanceParticipant> _participants({
  AttendancePresenceState firstState = AttendancePresenceState.unmarked,
  AttendancePresenceState secondState = AttendancePresenceState.unmarked,
  AttendancePresenceState thirdState = AttendancePresenceState.unmarked,
}) => [
  AttendanceParticipant(id: 'participant-1', name: 'Lia Horizonte', state: firstState),
  AttendanceParticipant(id: 'participant-2', name: 'Tom Vale', state: secondState),
  AttendanceParticipant(id: 'participant-3', name: 'Noa Jardim', state: thirdState),
];

String _institutionName(String id) => switch (id) {
  'institution-2' => 'Colégio Aurora',
  'institution-3' => 'Espaço Ipê',
  _ => 'Instituto Horizonte',
};

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year && left.month == right.month && left.day == right.day;
