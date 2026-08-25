part of 'attendance.dart';

@immutable
class AttendanceOverview {
  const AttendanceOverview({required this.calls, required this.notices, required this.metrics});

  final List<AttendanceCall> calls;
  final List<AttendanceNotice> notices;
  final AttendanceMetrics metrics;
}

@immutable
class AttendanceBulkReceipt {
  const AttendanceBulkReceipt({
    required this.operationId,
    required this.callId,
    required this.affectedParticipantIds,
    required this.previousVersion,
    required this.currentVersion,
  });

  final String operationId;
  final String callId;
  final Set<String> affectedParticipantIds;
  final int previousVersion;
  final int currentVersion;

  bool canUndoAtVersion(int version) => version == currentVersion;
}

@immutable
class AttendanceBulkResult {
  const AttendanceBulkResult({required this.call, required this.receipt});

  final AttendanceCall call;
  final AttendanceBulkReceipt receipt;
}

class AttendanceUnauthorizedException implements Exception {
  const AttendanceUnauthorizedException();
}

class AttendanceVersionConflictException implements Exception {
  const AttendanceVersionConflictException();
}

class AttendanceUnavailableException implements Exception {
  const AttendanceUnavailableException();
}
