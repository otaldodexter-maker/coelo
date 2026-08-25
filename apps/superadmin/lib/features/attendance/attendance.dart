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
