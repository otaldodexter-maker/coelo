import 'dart:math';

import 'package:coelo_domain/coelo_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../attendance.dart';

final class SupabaseAttendanceRepository
    implements AttendanceRepository, AttendanceDashboardRepository {
  const SupabaseAttendanceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AttendanceDashboardAccess> fetchAccess() async =>
      _dashboardAccess(_map(await _dashboardRpc('attendance_dashboard_access', const {})));

  @override
  Future<AttendanceDashboardSnapshot> fetchDashboard(AttendanceDashboardQuery query) async {
    final payload = _map(
      await _dashboardRpc('attendance_dashboard_read', {
        'p_start': _dateOnly(query.periodStart),
        'p_end': _dateOnly(query.periodEnd),
        'p_granularity': query.granularity.name,
        'p_institution_id': query.institutionId,
        'p_unit_id': query.unitId,
        'p_group_id': query.groupId,
        'p_activity_id': query.activityId,
        'p_child_id': query.childId,
        'p_search': query.search,
        'p_statuses': query.statuses.map(_dashboardStatusName).toList(growable: false),
        'p_responsible_id': query.responsibleId,
        'p_sort': query.sort.name,
        'p_desc': query.descending,
        'p_page': query.page,
        'p_page_size': query.pageSize,
        'p_ranking_direction': query.rankingDirection.name,
      }),
    );
    return _dashboardSnapshot(payload, query);
  }

  @override
  Future<AttendanceRanking> fetchRanking({
    required AttendanceDashboardQuery query,
    required AttendanceRankingKind kind,
    required int page,
    required int pageSize,
  }) async => _dashboardRanking(
    _map(
      await _dashboardRpc('attendance_dashboard_ranking_page', {
        'p_start': _dateOnly(query.periodStart),
        'p_end': _dateOnly(query.periodEnd),
        'p_institution_id': query.institutionId,
        'p_unit_id': query.unitId,
        'p_group_id': query.groupId,
        'p_activity_id': query.activityId,
        'p_child_id': query.childId,
        'p_kind': kind.name,
        'p_direction': query.rankingDirection.name,
        'p_page': page,
        'p_page_size': pageSize,
      }),
    ),
  );

  @override
  Future<AttendanceDashboardExportJob> requestExport({
    required AttendanceDashboardQuery query,
    required AttendanceDashboardExportKind kind,
    required AttendanceDashboardExportFormat format,
    required String idempotencyKey,
  }) async {
    final access = await fetchAccess();
    if (!query.isValidExportScope(access)) {
      throw const AttendanceDashboardUnauthorized();
    }
    return _dashboardExportJob(
      _map(
        await _dashboardRpc('attendance_dashboard_request_export', {
          'p_request_id': idempotencyKey,
          'p_kind': kind.name,
          'p_format': format.name,
          'p_filters': _dashboardQueryJson(query),
        }),
      ),
    );
  }

  @override
  Future<AttendanceDashboardExportJob> fetchExportJob(String id) async {
    final response = await _client.functions.invoke(
      'attendance-export',
      body: {'action': 'status', 'job_id': id},
    );
    return _dashboardExportJob(_map(response.data));
  }

  @override
  Future<AttendanceContextOptions> fetchContextOptions({required DateTime date}) async {
    final payload = _map(
      await _rpc('superadmin_attendance_context_options', {'p_date': _dateOnly(date)}),
    );
    return AttendanceContextOptions(
      institutions: _contextOptions(payload['institutions']),
      units: _contextOptions(payload['units']),
      groups: _contextOptions(payload['groups']),
      activities: _contextOptions(payload['activities']),
      canManage: payload['can_manage'] as bool? ?? false,
    );
  }

  @override
  Future<AttendanceOverview> fetchOverview({DateTime? date}) async {
    final payload = _map(
      await _rpc('superadmin_attendance_directory', {
        'p_date': date == null ? null : _dateOnly(date),
      }),
    );
    return AttendanceOverview(
      calls: _rows(payload['calls']).map(_call).toList(growable: false),
      notices: _rows(payload['notices']).map(_notice).toList(growable: false),
      metrics: _metrics(_map(payload['metrics'])),
    );
  }

  @override
  Future<AttendanceCall?> fetchCall(String id) async {
    final payload = await _rpc('superadmin_attendance_call_detail', {'p_call_id': id});
    return payload == null ? null : _call(_map(payload));
  }

  @override
  Future<AttendanceCall> createCall(AttendanceCallDraft draft) async => _call(
    _map(
      await _rpc('superadmin_attendance_create_call', {
        'p_institution_id': draft.institutionId,
        'p_unit_id': draft.unitId,
        'p_group_id': draft.groupId,
        'p_activity_id': draft.activityContextId,
        'p_session_date': _dateOnly(draft.date),
        'p_idempotency_key': _newUuid(),
      }),
    ),
  );

  @override
  Future<AttendanceBulkResult> markRemainingPresent(
    String callId, {
    required int expectedVersion,
  }) => _bulk('superadmin_attendance_mark_remaining_present', callId, expectedVersion);

  @override
  Future<AttendanceBulkResult> clearPresenceMarks(String callId, {required int expectedVersion}) =>
      _bulk('superadmin_attendance_clear_presence_marks', callId, expectedVersion);

  Future<AttendanceBulkResult> _bulk(String function, String callId, int version) async {
    final payload = _map(
      await _rpc(function, {
        'p_call_id': callId,
        'p_expected_version': version,
        'p_idempotency_key': _newUuid(),
      }),
    );
    final receipt = _map(payload['receipt']);
    return AttendanceBulkResult(
      call: _call(_map(payload['call'])),
      receipt: AttendanceBulkReceipt(
        operationId: receipt['operation_id'] as String,
        callId: receipt['call_id'] as String,
        affectedParticipantIds: _strings(receipt['affected_participant_ids']).toSet(),
        previousVersion: (receipt['previous_version'] as num).toInt(),
        currentVersion: (receipt['current_version'] as num).toInt(),
      ),
    );
  }

  @override
  Future<AttendanceCall> undoBulk(AttendanceBulkReceipt receipt) async => _call(
    _map(
      await _rpc('superadmin_attendance_undo_bulk', {
        'p_operation_id': receipt.operationId,
        'p_call_id': receipt.callId,
        'p_expected_version': receipt.currentVersion,
      }),
    ),
  );

  @override
  Future<AttendanceCall> setParticipantState(
    String callId,
    String participantId,
    AttendancePresenceState state, {
    required int expectedVersion,
  }) => _callCommand('superadmin_attendance_set_participant', {
    'p_idempotency_key': _newUuid(),
    'p_call_id': callId,
    'p_participant_id': participantId,
    'p_state': _presenceToDatabase(state),
    'p_expected_version': expectedVersion,
  });

  @override
  Future<AttendanceCall> completeCall(String callId, {required int expectedVersion}) =>
      _callCommand('superadmin_attendance_complete_call', {
        'p_call_id': callId,
        'p_expected_version': expectedVersion,
        'p_idempotency_key': _newUuid(),
      });

  @override
  Future<AttendanceCall> reopenCall(
    String callId, {
    required int expectedVersion,
    required String reason,
  }) => _callCommand('superadmin_attendance_reopen_call', {
    'p_call_id': callId,
    'p_expected_version': expectedVersion,
    'p_reason': reason.trim(),
  });

  @override
  Future<AttendanceCall> confirmNotice(String noticeId, {required int expectedVersion}) =>
      _callCommand('superadmin_attendance_confirm_notice', {
        'p_notice_id': noticeId,
        'p_expected_version': expectedVersion,
      });

  @override
  Future<AttendanceCall> correctParticipant({
    required String callId,
    required String participantId,
    required AttendancePresenceState state,
    required String reason,
    required int expectedVersion,
  }) => _callCommand('superadmin_attendance_correct_participant', {
    'p_call_id': callId,
    'p_participant_id': participantId,
    'p_state': _presenceToDatabase(state),
    'p_reason': reason.trim(),
    'p_expected_version': expectedVersion,
  });

  Future<AttendanceCall> _callCommand(String function, Map<String, Object?> params) async =>
      _call(_map(await _rpc(function, params)));

  Future<Object?> _rpc(String function, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(function, params: params);
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        throw const AttendanceUnauthorizedException();
      }
      if (error.code == '40001' || error.code == 'P0001' && error.message.contains('version')) {
        throw const AttendanceVersionConflictException();
      }
      rethrow;
    }
  }

  Future<Object?> _dashboardRpc(String function, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(function, params: params);
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        throw const AttendanceDashboardUnauthorized();
      }
      rethrow;
    }
  }
}

final class UnavailableAttendanceRepository
    implements AttendanceRepository, AttendanceDashboardRepository {
  const UnavailableAttendanceRepository();

  Future<T> _unavailable<T>() => Future<T>.error(const AttendanceUnavailableException());

  @override
  Future<AttendanceDashboardAccess> fetchAccess() => _unavailable();
  @override
  Future<AttendanceDashboardSnapshot> fetchDashboard(AttendanceDashboardQuery query) =>
      _unavailable();
  @override
  Future<AttendanceRanking> fetchRanking({
    required AttendanceDashboardQuery query,
    required AttendanceRankingKind kind,
    required int page,
    required int pageSize,
  }) => _unavailable();
  @override
  Future<AttendanceDashboardExportJob> requestExport({
    required AttendanceDashboardQuery query,
    required AttendanceDashboardExportKind kind,
    required AttendanceDashboardExportFormat format,
    required String idempotencyKey,
  }) => _unavailable();
  @override
  Future<AttendanceDashboardExportJob> fetchExportJob(String id) => _unavailable();

  @override
  Future<AttendanceContextOptions> fetchContextOptions({required DateTime date}) => _unavailable();

  @override
  Future<AttendanceOverview> fetchOverview({DateTime? date}) => _unavailable();
  @override
  Future<AttendanceCall?> fetchCall(String id) => _unavailable();
  @override
  Future<AttendanceCall> createCall(AttendanceCallDraft draft) => _unavailable();
  @override
  Future<AttendanceBulkResult> markRemainingPresent(
    String callId, {
    required int expectedVersion,
  }) => _unavailable();
  @override
  Future<AttendanceBulkResult> clearPresenceMarks(String callId, {required int expectedVersion}) =>
      _unavailable();
  @override
  Future<AttendanceCall> undoBulk(AttendanceBulkReceipt receipt) => _unavailable();
  @override
  Future<AttendanceCall> setParticipantState(
    String callId,
    String participantId,
    AttendancePresenceState state, {
    required int expectedVersion,
  }) => _unavailable();
  @override
  Future<AttendanceCall> completeCall(String callId, {required int expectedVersion}) =>
      _unavailable();
  @override
  Future<AttendanceCall> reopenCall(
    String callId, {
    required int expectedVersion,
    required String reason,
  }) => _unavailable();
  @override
  Future<AttendanceCall> confirmNotice(String noticeId, {required int expectedVersion}) =>
      _unavailable();
  @override
  Future<AttendanceCall> correctParticipant({
    required String callId,
    required String participantId,
    required AttendancePresenceState state,
    required String reason,
    required int expectedVersion,
  }) => _unavailable();
}

AttendanceCall _call(Map<String, dynamic> json) => AttendanceCall(
  id: json['id'] as String,
  institutionId: json['institution_id'] as String,
  institutionName: json['institution_name'] as String? ?? '',
  unitId: json['unit_id'] as String,
  unitName: json['unit_name'] as String? ?? '',
  groupId: json['group_id'] as String,
  groupName: json['group_name'] as String? ?? '',
  activityContextId: json['activity_id'] as String?,
  activityName: json['activity_name'] as String?,
  date: DateTime.parse(json['session_date'] as String),
  status: _callStatus(json['status']),
  participants: _rows(json['participants']).map(_participant).toList(growable: false),
  responsible: json['responsible'] as String? ?? '',
  canManage: json['can_manage'] as bool? ?? false,
  updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
  version: (json['version'] as num?)?.toInt() ?? 1,
  revisions: _rows(json['revisions']).map(_revision).toList(growable: false),
);

AttendanceParticipant _participant(Map<String, dynamic> json) => AttendanceParticipant(
  id: (json['participant_id'] ?? json['id']) as String,
  name: json['name'] as String? ?? '',
  state: _presence(json['state'] ?? json['outcome']),
  note: json['note'] as String? ?? '',
  justification: _justification(json['justification']),
  notice: json['notice'] == null ? null : _notice(_map(json['notice'])),
);

AttendanceRevision _revision(Map<String, dynamic> json) => AttendanceRevision(
  participantId: json['participant_id'] as String,
  previous: _presence(json['previous']),
  current: _presence(json['current']),
  reason: json['reason'] as String? ?? '',
  author: json['author'] as String? ?? '',
  changedAt: DateTime.parse(json['changed_at'] as String),
);

AttendanceNotice _notice(Map<String, dynamic> json) => AttendanceNotice(
  id: json['id'] as String,
  callId: (json['call_id'] ?? json['attendance_session_id']) as String,
  participantId: (json['participant_id'] ?? json['child_context_id']) as String,
  participantName: json['participant_name'] as String? ?? '',
  intent: _intent(json['intent'] ?? json['notice_type']),
  reason: json['reason'] as String? ?? json['reason_detail'] as String? ?? '',
  startDate: DateTime.parse((json['start_date'] ?? json['starts_at']) as String),
  endDate: DateTime.tryParse((json['end_date'] ?? json['ends_at']) as String? ?? ''),
  note: json['note'] as String? ?? '',
  pending: (json['pending'] as bool?) ?? json['review_status'] == 'pending',
);

AttendanceMetrics _metrics(Map<String, dynamic> json) => AttendanceMetrics(
  presencePercent: (json['presence_percent'] as num?)?.toDouble() ?? 0,
  justifiedAbsences: (json['justified_absences'] as num?)?.toInt() ?? 0,
  unjustifiedAbsences: (json['unjustified_absences'] as num?)?.toInt() ?? 0,
  late: (json['late'] as num?)?.toInt() ?? 0,
  earlyDepartures: (json['early_departures'] as num?)?.toInt() ?? 0,
);

AttendancePresenceState _presence(Object? value) => switch (value) {
  'present' => AttendancePresenceState.present,
  'absent' => AttendancePresenceState.absent,
  'late' || 'late_arrival' => AttendancePresenceState.late,
  'late_and_early' => AttendancePresenceState.lateAndEarly,
  'early_departure' => AttendancePresenceState.earlyDeparture,
  _ => AttendancePresenceState.unmarked,
};

String _presenceToDatabase(AttendancePresenceState value) => switch (value) {
  AttendancePresenceState.unmarked => 'unmarked',
  AttendancePresenceState.present => 'present',
  AttendancePresenceState.absent => 'absent',
  AttendancePresenceState.late => 'late_arrival',
  AttendancePresenceState.lateAndEarly => 'late_and_early',
  AttendancePresenceState.earlyDeparture => 'early_departure',
};

AttendanceCallStatus _callStatus(Object? value) => switch (value) {
  'open' || 'in_progress' => AttendanceCallStatus.inProgress,
  'closed' || 'completed' => AttendanceCallStatus.completed,
  'corrected' => AttendanceCallStatus.completed,
  'reopened' => AttendanceCallStatus.reopened,
  _ => AttendanceCallStatus.notStarted,
};

AttendanceNoticeIntent _intent(Object? value) => switch (value) {
  'expected_presence' => AttendanceNoticeIntent.expectedPresence,
  'late_arrival' => AttendanceNoticeIntent.lateArrival,
  'early_departure' => AttendanceNoticeIntent.earlyDeparture,
  _ => AttendanceNoticeIntent.absence,
};

AttendanceJustificationState? _justification(Object? value) => switch (value) {
  'pending' => AttendanceJustificationState.pending,
  'accepted' => AttendanceJustificationState.accepted,
  'rejected' => AttendanceJustificationState.rejected,
  _ => null,
};

Map<String, dynamic> _map(Object? value) => Map<String, dynamic>.from(value as Map);
List<Map<String, dynamic>> _rows(Object? value) =>
    (value as List<dynamic>? ?? const []).map(_map).toList(growable: false);
List<String> _strings(Object? value) => List<String>.from(value as List<dynamic>? ?? const []);
String _dateOnly(DateTime value) => value.toIso8601String().split('T').first;
List<AttendanceContextOption> _contextOptions(Object? value) => _rows(value)
    .map(
      (row) => AttendanceContextOption(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        institutionId: row['institution_id'] as String?,
        unitId: row['unit_id'] as String?,
        groupId: row['group_id'] as String?,
        attendanceRequired: row['attendance_required'] as bool? ?? true,
      ),
    )
    .toList(growable: false);

AttendanceDashboardAccess _dashboardAccess(Map<String, dynamic> json) => AttendanceDashboardAccess(
  scope: switch (json['scope']) {
    'platform' => AttendanceDashboardScope.platform,
    'institution' => AttendanceDashboardScope.institution,
    'unit' => AttendanceDashboardScope.unit,
    'assignments' => AttendanceDashboardScope.assignments,
    'guardian' => AttendanceDashboardScope.guardian,
    final value => throw FormatException('Escopo de assiduidade inválido: $value'),
  },
  canRead: json['can_read'] as bool? ?? false,
  institutionId: json['institution_id'] as String?,
  unitId: json['unit_id'] as String?,
  assignedGroupIds: _strings(json['assigned_group_ids']).toSet(),
  assignedActivityIds: _strings(json['assigned_activity_ids']).toSet(),
  childIds: _strings(json['child_ids']).toSet(),
  canCreateCall: json['can_create_call'] as bool? ?? false,
  canExport: json['can_export'] as bool? ?? false,
);

AttendanceDashboardSnapshot _dashboardSnapshot(
  Map<String, dynamic> json,
  AttendanceDashboardQuery query,
) {
  final kpis = _map(json['kpis']);
  final calls = _map(json['calls']);
  return AttendanceDashboardSnapshot(
    access: _dashboardAccess(_map(json['access'])),
    query: query,
    kpis: AttendanceDashboardKpis(
      presence: AttendanceRate.fromJson(_map(kpis['presence'])),
      pendingCalls: (kpis['pending_calls'] as num?)?.toInt() ?? 0,
      absences: (kpis['absences'] as num?)?.toInt() ?? 0,
      inReview: (kpis['in_review'] as num?)?.toInt() ?? 0,
    ),
    attention: _rows(json['attention'])
        .map(
          (row) => AttendanceAttentionItem(
            id: row['id'] as String,
            label: row['label'] as String? ?? '',
            detail: row['detail'] as String? ?? '',
            count: (row['count'] as num?)?.toInt() ?? 0,
            callId: row['call_id'] as String?,
          ),
        )
        .toList(growable: false),
    rankings: _rows(json['rankings']).map(_dashboardRanking).toList(growable: false),
    series: _rows(json['series'])
        .map(
          (row) => AttendanceSeriesPoint(
            start: DateTime.parse(row['start'] as String),
            label: row['label'] as String? ?? '',
            current: AttendanceRate.fromJson(row),
            previous: row['previous_official_records'] == null
                ? null
                : AttendanceRate.fromJson({
                    'official_records': row['previous_official_records'],
                    'percent': row['previous_percent'],
                  }),
            absences: (row['absences'] as num?)?.toInt() ?? 0,
            late: (row['late'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false),
    calls: AttendanceDashboardCallPage(
      items: _rows(calls['items']).map(_dashboardCallRow).toList(growable: false),
      page: (calls['page'] as num?)?.toInt() ?? 1,
      pageSize: (calls['page_size'] as num?)?.toInt() ?? query.pageSize,
      totalItems: (calls['total_items'] as num?)?.toInt() ?? 0,
    ),
    contextLabel: json['context_label'] as String? ?? 'Assiduidade',
  );
}

AttendanceRanking _dashboardRanking(Map<String, dynamic> json) => AttendanceRanking(
  kind: switch (json['kind']) {
    'units' => AttendanceRankingKind.units,
    'groups' => AttendanceRankingKind.groups,
    'activities' => AttendanceRankingKind.activities,
    'students' => AttendanceRankingKind.students,
    'teachers' => AttendanceRankingKind.teachers,
    _ => AttendanceRankingKind.institutions,
  },
  total: (json['total'] as num?)?.toInt() ?? 0,
  direction: json['direction'] == 'lowest'
      ? AttendanceRankingDirection.lowest
      : AttendanceRankingDirection.highest,
  items: _rows(json['items'])
      .map(
        (row) => AttendanceRankingItem(
          id: row['id'] as String,
          label: row['label'] as String? ?? '',
          rate: AttendanceRate.fromJson(row),
          trendPercent: (row['trend_percent'] as num?)?.toDouble(),
          auxiliaryLabel: row['auxiliary_label'] as String?,
        ),
      )
      .toList(growable: false),
);

AttendanceDashboardCallRow _dashboardCallRow(Map<String, dynamic> row) =>
    AttendanceDashboardCallRow(
      id: row['id'] as String,
      context: row['context'] as String? ?? '',
      date: DateTime.parse(row['date'] as String),
      responsible: row['responsible'] as String? ?? '',
      present: (row['present'] as num?)?.toInt() ?? 0,
      absent: (row['absent'] as num?)?.toInt() ?? 0,
      late: (row['late'] as num?)?.toInt() ?? 0,
      presence: AttendanceRate.fromJson({
        'official_records': row['official_records'],
        'percent': row['presence_percent'],
      }),
      status: switch (row['status']) {
        'completed' => AttendanceDashboardCallStatus.completed,
        'inReview' => AttendanceDashboardCallStatus.inReview,
        _ => AttendanceDashboardCallStatus.pending,
      },
      canOpen: row['can_open'] as bool? ?? false,
    );

AttendanceDashboardExportJob _dashboardExportJob(Map<String, dynamic> json) =>
    AttendanceDashboardExportJob(
      id: (json['id'] ?? json['job_id']) as String,
      state: switch (json['state'] ?? json['processing_state']) {
        'succeeded' ||
        'success' ||
        'sucesso' ||
        'SUCESSO' => AttendanceDashboardExportState.succeeded,
        'failed' || 'error' || 'erro' || 'ERRO' => AttendanceDashboardExportState.failed,
        _ => AttendanceDashboardExportState.processing,
      },
      fileName: json['file_name'] as String?,
      downloadUrl: Uri.tryParse(json['download_url'] as String? ?? ''),
      errorCode: json['error_code'] as String?,
    );

Map<String, Object?> _dashboardQueryJson(AttendanceDashboardQuery query) => {
  'period_start': _dateOnly(query.periodStart),
  'period_end': _dateOnly(query.periodEnd),
  'granularity': query.granularity.name,
  'institution_id': query.institutionId,
  'unit_id': query.unitId,
  'group_id': query.groupId,
  'activity_id': query.activityId,
  'child_id': query.childId,
  'search': query.search,
  'statuses': query.statuses.map(_dashboardStatusName).toList(growable: false),
  'responsible_id': query.responsibleId,
  'sort': query.sort.name,
  'descending': query.descending,
  'page': query.page,
  'page_size': query.pageSize,
  'ranking_direction': query.rankingDirection.name,
};

String _dashboardStatusName(AttendanceDashboardCallStatus value) => switch (value) {
  AttendanceDashboardCallStatus.pending => 'pending',
  AttendanceDashboardCallStatus.completed => 'completed',
  AttendanceDashboardCallStatus.inReview => 'inReview',
};

String _newUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
