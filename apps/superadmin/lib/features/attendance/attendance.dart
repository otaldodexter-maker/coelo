import 'package:flutter/foundation.dart';

part 'attendance_contract.dart';

enum AttendancePresenceState { unmarked, present, absent, late, earlyDeparture, lateAndEarly }

enum AttendanceJustificationState { pending, accepted, rejected }

enum AttendanceCallStatus { notStarted, inProgress, completed, reopened }

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
      backendResolved = false,
      assignedGroupIds = const {},
      assignedActivityContextIds = const {};

  const AttendancePermissions.manager()
    : canManage = true,
      backendResolved = false,
      assignedGroupIds = const {},
      assignedActivityContextIds = const {};

  const AttendancePermissions.readOnly()
    : canManage = false,
      backendResolved = false,
      assignedGroupIds = const {},
      assignedActivityContextIds = const {};

  /// Preview-only permission set. Inject exclusively from `/dev` composition.
  const AttendancePermissions.development()
    : canManage = true,
      backendResolved = false,
      assignedGroupIds = const {},
      assignedActivityContextIds = const {};

  const AttendancePermissions.teacher({
    this.assignedGroupIds = const {},
    this.assignedActivityContextIds = const {},
  }) : canManage = false,
       backendResolved = false;

  const AttendancePermissions.backend()
    : canManage = false,
      backendResolved = true,
      assignedGroupIds = const {},
      assignedActivityContextIds = const {};

  final bool canManage;
  final bool backendResolved;
  final Set<String> assignedGroupIds;
  final Set<String> assignedActivityContextIds;

  bool canOperate(AttendanceCall call) =>
      canManage ||
      (backendResolved && call.canManage) ||
      assignedGroupIds.contains(call.groupId) ||
      (call.activityContextId != null &&
          assignedActivityContextIds.contains(call.activityContextId));

  bool canCreate({required bool backendCanManage}) =>
      backendResolved ? backendCanManage : canManage;
}

class AttendanceParticipant {
  AttendanceParticipant({
    required this.id,
    required this.name,
    this.state = AttendancePresenceState.unmarked,
    this.note = '',
    this.justification,
    this.notice,
  });

  final String id;
  final String name;
  AttendancePresenceState state;
  String note;
  AttendanceJustificationState? justification;
  final AttendanceNotice? notice;
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
    this.canManage = false,
    this.version = 1,
    this.routine = const AttendanceRoutineRef.none(),
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
  final bool canManage;
  final int version;

  /// Rotina diária da chamada (ADR 0041 B3): snapshot gravado na conclusão ou
  /// rotina vigente, conforme [AttendanceRoutineRef.source].
  final AttendanceRoutineRef routine;
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
class AttendanceContextOption {
  const AttendanceContextOption({
    required this.id,
    required this.name,
    this.institutionId,
    this.unitId,
    this.groupId,
    this.attendanceRequired = true,
  });

  final String id;
  final String name;
  final String? institutionId;
  final String? unitId;
  final String? groupId;
  final bool attendanceRequired;
}

@immutable
class AttendanceContextOptions {
  const AttendanceContextOptions({
    required this.institutions,
    required this.units,
    required this.groups,
    required this.activities,
    this.canManage = false,
  });

  final List<AttendanceContextOption> institutions;
  final List<AttendanceContextOption> units;
  final List<AttendanceContextOption> groups;
  final List<AttendanceContextOption> activities;
  final bool canManage;
  bool get isEmpty => institutions.isEmpty || units.isEmpty || groups.isEmpty;
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
  Future<AttendanceOverview> fetchOverview({DateTime? date});
  Future<AttendanceContextOptions> fetchContextOptions({required DateTime date});
  Future<AttendanceCall?> fetchCall(String id);
  Future<AttendanceCall> createCall(AttendanceCallDraft draft);
  Future<AttendanceBulkResult> markRemainingPresent(String callId, {required int expectedVersion});
  Future<AttendanceBulkResult> clearPresenceMarks(String callId, {required int expectedVersion});
  Future<AttendanceCall> undoBulk(AttendanceBulkReceipt receipt);
  Future<AttendanceCall> setParticipantState(
    String callId,
    String participantId,
    AttendancePresenceState state, {
    required int expectedVersion,
  });
  Future<AttendanceCall> completeCall(String callId, {required int expectedVersion});
  Future<AttendanceCall> reopenCall(
    String callId, {
    required int expectedVersion,
    required String reason,
  });
  Future<AttendanceCall> confirmNotice(String noticeId, {required int expectedVersion});
  Future<AttendanceCall> correctParticipant({
    required String callId,
    required String participantId,
    required AttendancePresenceState state,
    required String reason,
    required int expectedVersion,
  });
}

/// Origem da rotina exibida numa chamada (ADR 0041 B3, spec 052).
///
/// `snapshot`: registrada na conclusão; `current`: rotina vigente hoje (chamada
/// aberta ou concluída antes do snapshot existir); `none`: nenhuma rotina.
enum AttendanceRoutineSource { snapshot, current, none }

@immutable
class AttendanceRoutineRef {
  const AttendanceRoutineRef({
    required this.source,
    this.applicationId,
    this.revisionNo,
    this.name,
    this.recordedAt,
  });

  const AttendanceRoutineRef.none() : this(source: AttendanceRoutineSource.none);

  final AttendanceRoutineSource source;
  final String? applicationId;
  final int? revisionNo;
  final String? name;
  final DateTime? recordedAt;

  bool get hasRoutine => source != AttendanceRoutineSource.none && (name ?? '').isNotEmpty;

  /// "Nome · v3" ou "Sem rotina vinculada".
  String get label => hasRoutine
      ? (revisionNo == null || revisionNo == 0 ? name! : '$name · v$revisionNo')
      : 'Sem rotina vinculada';

  /// Qualificador da origem. Para chamadas já concluídas/reabertas sem
  /// snapshot vale a indicação exigida pelo Owner ("rotina atual (não
  /// registrada na época)"); numa chamada ainda aberta a rotina é só a vigente.
  String? sourceLabel({required bool concluded}) => switch (source) {
    AttendanceRoutineSource.snapshot => 'registrada na conclusão',
    AttendanceRoutineSource.current =>
      concluded ? 'rotina atual (não registrada na época)' : 'rotina vigente',
    AttendanceRoutineSource.none => null,
  };

  /// Verdadeiro quando a chamada concluída não tem snapshot (legado).
  bool isLegacyFor(AttendanceCallStatus status) =>
      source == AttendanceRoutineSource.current && statusConcluded(status);

  static bool statusConcluded(AttendanceCallStatus status) =>
      status == AttendanceCallStatus.completed || status == AttendanceCallStatus.reopened;
}

/// Filtros do Histórico de chamadas (ADR 0041 B2, spec 052).
@immutable
class AttendanceHistoryQuery {
  const AttendanceHistoryQuery({
    required this.periodStart,
    required this.periodEnd,
    this.institutionId,
    this.unitId,
    this.groupId,
    this.activityId,
    this.status,
    this.cursor,
    this.pageSize = 20,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final String? institutionId;
  final String? unitId;
  final String? groupId;
  final String? activityId;

  /// `pending` (aberta/reaberta/rascunho) ou `completed` (concluída/corrigida).
  final AttendanceHistoryStatusFilter? status;
  final String? cursor;
  final int pageSize;

  bool get hasContextFilter =>
      institutionId != null || unitId != null || groupId != null || activityId != null;

  AttendanceHistoryQuery copyWith({
    DateTime? periodStart,
    DateTime? periodEnd,
    Object? institutionId = _unset,
    Object? unitId = _unset,
    Object? groupId = _unset,
    Object? activityId = _unset,
    Object? status = _unset,
    Object? cursor = _unset,
    int? pageSize,
  }) => AttendanceHistoryQuery(
    periodStart: periodStart ?? this.periodStart,
    periodEnd: periodEnd ?? this.periodEnd,
    institutionId: identical(institutionId, _unset) ? this.institutionId : institutionId as String?,
    unitId: identical(unitId, _unset) ? this.unitId : unitId as String?,
    groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    activityId: identical(activityId, _unset) ? this.activityId : activityId as String?,
    status: identical(status, _unset) ? this.status : status as AttendanceHistoryStatusFilter?,
    cursor: identical(cursor, _unset) ? this.cursor : cursor as String?,
    pageSize: pageSize ?? this.pageSize,
  );

  static const _unset = Object();
}

enum AttendanceHistoryStatusFilter { pending, completed }

@immutable
class AttendanceHistoryItem {
  const AttendanceHistoryItem({
    required this.id,
    required this.date,
    required this.institutionId,
    required this.institutionName,
    required this.unitId,
    required this.unitName,
    required this.groupId,
    required this.groupName,
    required this.status,
    required this.responsible,
    required this.expected,
    required this.present,
    required this.absent,
    required this.late,
    required this.earlyDepartures,
    required this.officialRecords,
    this.activityId,
    this.activityName,
    this.canOpen = true,
    this.routine = const AttendanceRoutineRef.none(),
  });

  final String id;
  final DateTime date;
  final String institutionId;
  final String institutionName;
  final String unitId;
  final String unitName;
  final String groupId;
  final String groupName;
  final String? activityId;
  final String? activityName;
  final AttendanceCallStatus status;
  final String responsible;
  final int expected;
  final int present;
  final int absent;
  final int late;
  final int earlyDepartures;
  final int officialRecords;
  final bool canOpen;
  final AttendanceRoutineRef routine;

  String get contextName => activityName ?? groupName;
}

@immutable
class AttendanceHistoryPageResult {
  const AttendanceHistoryPageResult({required this.items, required this.hasMore, this.nextCursor});

  final List<AttendanceHistoryItem> items;
  final bool hasMore;
  final String? nextCursor;
}

/// Leitor do Histórico; separado de [AttendanceRepository] para não obrigar
/// as composições de preview a implementá-lo.
abstract interface class AttendanceHistoryRepository {
  Future<AttendanceHistoryPageResult> fetchHistory(AttendanceHistoryQuery query);
  Future<AttendanceContextOptions> fetchContextOptions({required DateTime date});
}
