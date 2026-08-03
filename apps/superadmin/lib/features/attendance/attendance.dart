import 'package:flutter/foundation.dart';

import '../../app/activity/superadmin_activity.dart';

enum AttendancePresenceState { unmarked, present, absent, late, earlyDeparture }

enum AttendanceJustificationState { pending, accepted, rejected }

enum AttendanceCallStatus { notStarted, inProgress, completed, corrected }

enum AttendanceExpectationState {
  notRequired,
  noneExpected,
  notStarted,
  inProgress,
  completed,
  corrected,
}

enum AttendanceNoticeIntent { absence, expectedPresence, lateArrival, earlyDeparture }

@immutable
class AttendancePermissions {
  const AttendancePermissions.owner()
    : canManage = true,
      assignedGroupIds = const {},
      assignedActivityContextIds = const {};

  const AttendancePermissions.readOnly()
    : canManage = false,
      assignedGroupIds = const {},
      assignedActivityContextIds = const {};

  const AttendancePermissions.teacher({
    this.assignedGroupIds = const {},
    this.assignedActivityContextIds = const {},
  }) : canManage = false;

  final bool canManage;
  final Set<String> assignedGroupIds;
  final Set<String> assignedActivityContextIds;

  bool canOperate(AttendanceCall call) =>
      assignedGroupIds.contains(call.groupId) ||
      (call.activityContextId != null &&
          assignedActivityContextIds.contains(call.activityContextId));
}

class AttendanceParticipant {
  AttendanceParticipant({
    required this.id,
    required this.name,
    this.state = AttendancePresenceState.unmarked,
    this.note = '',
    this.justification,
  });

  final String id;
  final String name;
  AttendancePresenceState state;
  String note;
  AttendanceJustificationState? justification;
}

@immutable
class AttendanceRevision {
  const AttendanceRevision({
    required this.participantId,
    required this.previous,
    required this.current,
    required this.reason,
    required this.author,
    required this.changedAt,
  });

  final String participantId;
  final AttendancePresenceState previous;
  final AttendancePresenceState current;
  final String reason;
  final String author;
  final DateTime changedAt;
}

class AttendanceCall {
  AttendanceCall({
    required this.id,
    required this.institutionId,
    required this.institutionName,
    required this.unitId,
    required this.unitName,
    required this.groupId,
    required this.groupName,
    required this.date,
    required this.status,
    required this.participants,
    this.activityContextId,
    this.activityName,
    this.responsible = 'Equipe Coelo',
    DateTime? updatedAt,
    List<AttendanceRevision>? revisions,
  }) : revisions = revisions ?? [],
       updatedAt = updatedAt ?? date;

  final String id;
  final String institutionId;
  final String institutionName;
  final String unitId;
  final String unitName;
  final String groupId;
  final String groupName;
  final String? activityContextId;
  final String? activityName;
  final DateTime date;
  AttendanceCallStatus status;
  final List<AttendanceParticipant> participants;
  final String responsible;
  DateTime updatedAt;
  final List<AttendanceRevision> revisions;

  int get markedCount =>
      participants.where((item) => item.state != AttendancePresenceState.unmarked).length;
  bool get hasUnmarked => markedCount != participants.length;
  String get contextName => activityName ?? groupName;
}

class AttendanceNotice {
  AttendanceNotice({
    required this.id,
    required this.callId,
    required this.participantId,
    required this.participantName,
    required this.intent,
    required this.reason,
    required this.startDate,
    this.endDate,
    this.note = '',
    this.pending = true,
  });

  final String id;
  final String callId;
  final String participantId;
  final String participantName;
  final AttendanceNoticeIntent intent;
  final String reason;
  final DateTime startDate;
  final DateTime? endDate;
  final String note;
  bool pending;
}

@immutable
class AttendanceCallDraft {
  const AttendanceCallDraft({
    required this.institutionId,
    required this.unitId,
    required this.groupId,
    required this.date,
    this.activityContextId,
  });

  final String institutionId;
  final String unitId;
  final String groupId;
  final String? activityContextId;
  final DateTime date;
}

@immutable
class AttendanceMetrics {
  const AttendanceMetrics({
    required this.presencePercent,
    required this.justifiedAbsences,
    required this.unjustifiedAbsences,
    required this.late,
    required this.earlyDepartures,
  });

  final double presencePercent;
  final int justifiedAbsences;
  final int unjustifiedAbsences;
  final int late;
  final int earlyDepartures;
}

abstract interface class AttendanceRepository {
  List<AttendanceCall> get calls;
  List<AttendanceNotice> get notices;
  AttendanceMetrics get metrics;
  AttendanceCall? callById(String id);
  AttendanceCall createCall(AttendanceCallDraft draft);
  void markRemainingPresent(String callId);
  void setParticipantState(String callId, String participantId, AttendancePresenceState state);
  void completeCall(String callId);
  void confirmNotice(String noticeId);
  void correctParticipant({
    required String callId,
    required String participantId,
    required AttendancePresenceState state,
    required String reason,
  });
}

abstract final class AttendanceFixtures {
  static final today = DateTime(2026, 8, 3);
}

final class InMemoryAttendanceRepository extends ChangeNotifier implements AttendanceRepository {
  InMemoryAttendanceRepository.seeded({SuperadminActivityController? activities})
    : _calls = _seedCalls(),
      _notices = [
        AttendanceNotice(
          id: 'notice-1',
          callId: 'call-progress',
          participantId: 'participant-1',
          participantName: 'Lia Horizonte',
          intent: AttendanceNoticeIntent.lateArrival,
          reason: 'Consulta marcada',
          startDate: AttendanceFixtures.today,
          note: 'Chegada prevista para 9h.',
        ),
      ] {
    activities?.addActivity(
      SuperadminActivity.attendanceNotice(
        id: 'attendance-notice-1',
        subject: 'Lia Horizonte',
        summary: 'Chegada atrasada · aguardando confirmação',
        destination: '/attendance/calls/call-progress?participant=participant-1',
        createdAt: DateTime(2026, 8, 3, 8, 15),
      ),
    );
  }

  final List<AttendanceCall> _calls;
  final List<AttendanceNotice> _notices;
  var _nextCall = 1;
  var _nextNotice = 1;

  @override
  List<AttendanceCall> get calls => List.unmodifiable(_calls);

  @override
  List<AttendanceNotice> get notices => List.unmodifiable(_notices);

  int get pendingNoticeCount => _notices.where((item) => item.pending).length;

  @override
  AttendanceCall? callById(String id) => _calls.where((item) => item.id == id).firstOrNull;

  @override
  AttendanceMetrics get metrics {
    final official = _calls
        .where(
          (call) =>
              call.status == AttendanceCallStatus.completed ||
              call.status == AttendanceCallStatus.corrected,
        )
        .expand((call) => call.participants)
        .where((item) => item.state != AttendancePresenceState.unmarked)
        .toList();
    final present = official.where(
      (item) => const {
        AttendancePresenceState.present,
        AttendancePresenceState.late,
        AttendancePresenceState.earlyDeparture,
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
  AttendanceCall createCall(AttendanceCallDraft draft) {
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
      groupName: draft.groupId == 'group-sun' ? 'Grupo Sol' : 'Grupo Lua',
      activityContextId: draft.activityContextId,
      activityName: draft.activityContextId == null ? null : 'Música',
      date: draft.date,
      status: AttendanceCallStatus.inProgress,
      participants: _participants(),
    );
    _calls.insert(0, call);
    notifyListeners();
    return call;
  }

  @override
  void markRemainingPresent(String callId) {
    final call = _requiredCall(callId);
    for (final participant in call.participants) {
      if (participant.state == AttendancePresenceState.unmarked) {
        participant.state = AttendancePresenceState.present;
      }
    }
    call.status = AttendanceCallStatus.inProgress;
    call.updatedAt = DateTime(2026, 8, 3, 9, 10);
    notifyListeners();
  }

  @override
  void setParticipantState(String callId, String participantId, AttendancePresenceState state) {
    final call = _requiredCall(callId);
    _requiredParticipant(call, participantId).state = state;
    call.status = AttendanceCallStatus.inProgress;
    notifyListeners();
  }

  @override
  void completeCall(String callId) {
    final call = _requiredCall(callId);
    if (call.hasUnmarked) throw StateError('Marque todos os participantes antes de concluir.');
    call.status = AttendanceCallStatus.completed;
    call.updatedAt = DateTime(2026, 8, 3, 9, 20);
    notifyListeners();
  }

  @override
  void confirmNotice(String noticeId) {
    final notice = _notices.where((item) => item.id == noticeId).firstOrNull;
    if (notice == null) throw StateError('Aviso não encontrado.');
    if (!notice.pending) return;
    final call = _requiredCall(notice.callId);
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
  }

  @override
  void correctParticipant({
    required String callId,
    required String participantId,
    required AttendancePresenceState state,
    required String reason,
  }) {
    if (reason.trim().isEmpty) throw ArgumentError.value(reason, 'reason');
    final call = _requiredCall(callId);
    if (call.status != AttendanceCallStatus.completed &&
        call.status != AttendanceCallStatus.corrected) {
      throw StateError('Somente chamadas concluídas podem ser corrigidas.');
    }
    final participant = _requiredParticipant(call, participantId);
    final previous = participant.state;
    participant.state = state;
    call.status = AttendanceCallStatus.corrected;
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
  }

  void addPendingNoticeForTest(String callId) {
    _notices.add(
      AttendanceNotice(
        id: 'notice-test-${_nextNotice++}',
        callId: callId,
        participantId: 'participant-3',
        participantName: 'Noa Vale',
        intent: AttendanceNoticeIntent.absence,
        reason: 'Aviso familiar',
        startDate: AttendanceFixtures.today,
      ),
    );
    notifyListeners();
  }

  AttendanceCall _requiredCall(String id) =>
      callById(id) ?? (throw StateError('Chamada não encontrada.'));

  AttendanceParticipant _requiredParticipant(AttendanceCall call, String id) =>
      call.participants.where((item) => item.id == id).firstOrNull ??
      (throw StateError('Participante não encontrado.'));
}

List<AttendanceCall> _seedCalls() => [
  AttendanceCall(
    id: 'call-progress',
    institutionId: 'institution-1',
    institutionName: 'Instituto Horizonte',
    unitId: 'unit-1',
    unitName: 'Unidade Centro',
    groupId: 'group-sun',
    groupName: 'Grupo Sol',
    activityContextId: 'activity-music-group-sun',
    activityName: 'Música · Grupo Sol',
    date: AttendanceFixtures.today,
    status: AttendanceCallStatus.inProgress,
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
    groupName: 'Grupo Lua',
    date: DateTime(2026, 8, 2),
    status: AttendanceCallStatus.completed,
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
    groupName: 'Grupo Ipê',
    date: AttendanceFixtures.today,
    status: AttendanceCallStatus.notStarted,
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
