enum AttendanceDashboardGranularity { daily, weekly, monthly }

enum AttendanceDashboardScope { platform, institution, unit, assignments, guardian }

enum AttendanceRankingKind { institutions, units, groups, activities, students, teachers }

enum AttendanceRankingDirection { highest, lowest }

enum AttendanceDashboardCallStatus { pending, completed, inReview }

enum AttendanceDashboardCallSort { context, date, responsible, presence, status }

enum AttendanceDashboardExportKind { overview, table }

enum AttendanceDashboardExportFormat { csv, xlsx }

enum AttendanceDashboardExportState { processing, succeeded, failed }

final class AttendanceRate {
  const AttendanceRate._({required this.officialRecords, required this.percent});

  factory AttendanceRate.fromCounts({
    required int present,
    required int late,
    required int earlyDeparture,
    required int lateAndEarly,
    required int absent,
  }) {
    final officialRecords = present + late + earlyDeparture + lateAndEarly + absent;
    return AttendanceRate._(
      officialRecords: officialRecords,
      percent: officialRecords == 0
          ? null
          : (present + late + earlyDeparture + lateAndEarly) / officialRecords * 100,
    );
  }

  factory AttendanceRate.fromJson(Map<String, Object?> json) => AttendanceRate._(
    officialRecords: (json['official_records'] as num?)?.toInt() ?? 0,
    percent: (json['percent'] as num?)?.toDouble(),
  );

  final int officialRecords;
  final double? percent;

  bool get isSufficient => officialRecords > 0 && percent != null;
}

final class AttendanceDashboardAccess {
  const AttendanceDashboardAccess({
    required this.scope,
    required this.canRead,
    this.institutionId,
    this.unitId,
    this.assignedGroupIds = const {},
    this.assignedActivityIds = const {},
    this.childIds = const {},
    this.canCreateCall = false,
    this.canExport = false,
  });

  final AttendanceDashboardScope scope;
  final bool canRead;
  final String? institutionId;
  final String? unitId;
  final Set<String> assignedGroupIds;
  final Set<String> assignedActivityIds;
  final Set<String> childIds;
  final bool canCreateCall;
  final bool canExport;
}

final class AttendanceDashboardQuery {
  const AttendanceDashboardQuery({
    required this.periodStart,
    required this.periodEnd,
    this.granularity = AttendanceDashboardGranularity.daily,
    this.institutionId,
    this.unitId,
    this.groupId,
    this.activityId,
    this.childId,
    this.search = '',
    this.statuses = const {},
    this.responsibleId,
    this.sort = AttendanceDashboardCallSort.date,
    this.descending = true,
    this.page = 1,
    this.pageSize = 20,
    this.rankingDirection = AttendanceRankingDirection.highest,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final AttendanceDashboardGranularity granularity;
  final String? institutionId;
  final String? unitId;
  final String? groupId;
  final String? activityId;
  final String? childId;
  final String search;
  final Set<AttendanceDashboardCallStatus> statuses;
  final String? responsibleId;
  final AttendanceDashboardCallSort sort;
  final bool descending;
  final int page;
  final int pageSize;
  final AttendanceRankingDirection rankingDirection;

  AttendanceDashboardQuery enforce(AttendanceDashboardAccess access) => copyWith(
    institutionId: switch (access.scope) {
      AttendanceDashboardScope.platform => institutionId,
      _ => access.institutionId,
    },
    unitId: switch (access.scope) {
      AttendanceDashboardScope.unit => access.unitId,
      _ => unitId,
    },
    childId: access.scope == AttendanceDashboardScope.guardian
        ? (childId != null && access.childIds.contains(childId) ? childId : null)
        : childId,
  );

  bool isValidExportScope(AttendanceDashboardAccess access) {
    if (!access.canExport) return false;
    if (access.scope != AttendanceDashboardScope.assignments) return true;
    if (groupId == null && activityId == null) return false;
    if (activityId != null && !access.assignedActivityIds.contains(activityId)) return false;
    if (groupId != null && !access.assignedGroupIds.contains(groupId)) return false;
    return true;
  }

  AttendanceDashboardQuery selectInstitution(String? value) => copyWith(
    institutionId: value,
    unitId: null,
    groupId: null,
    activityId: null,
    childId: null,
    page: 1,
  );

  AttendanceDashboardQuery selectUnit(String? value) =>
      copyWith(unitId: value, groupId: null, activityId: null, childId: null, page: 1);

  AttendanceDashboardQuery selectGroup(String? value) =>
      copyWith(groupId: value, activityId: null, childId: null, page: 1);

  AttendanceDashboardQuery selectActivity(String? value) =>
      copyWith(activityId: value, childId: null, page: 1);

  AttendanceDashboardQuery selectChild(String? value) => copyWith(childId: value, page: 1);

  AttendanceDashboardQuery copyWith({
    DateTime? periodStart,
    DateTime? periodEnd,
    AttendanceDashboardGranularity? granularity,
    Object? institutionId = _unset,
    Object? unitId = _unset,
    Object? groupId = _unset,
    Object? activityId = _unset,
    Object? childId = _unset,
    String? search,
    Set<AttendanceDashboardCallStatus>? statuses,
    Object? responsibleId = _unset,
    AttendanceDashboardCallSort? sort,
    bool? descending,
    int? page,
    int? pageSize,
    AttendanceRankingDirection? rankingDirection,
  }) => AttendanceDashboardQuery(
    periodStart: periodStart ?? this.periodStart,
    periodEnd: periodEnd ?? this.periodEnd,
    granularity: granularity ?? this.granularity,
    institutionId: identical(institutionId, _unset) ? this.institutionId : institutionId as String?,
    unitId: identical(unitId, _unset) ? this.unitId : unitId as String?,
    groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    activityId: identical(activityId, _unset) ? this.activityId : activityId as String?,
    childId: identical(childId, _unset) ? this.childId : childId as String?,
    search: search ?? this.search,
    statuses: statuses ?? this.statuses,
    responsibleId: identical(responsibleId, _unset) ? this.responsibleId : responsibleId as String?,
    sort: sort ?? this.sort,
    descending: descending ?? this.descending,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    rankingDirection: rankingDirection ?? this.rankingDirection,
  );
}

const _unset = Object();

final class AttendanceDashboardKpis {
  const AttendanceDashboardKpis({
    required this.presence,
    required this.pendingCalls,
    required this.absences,
    required this.inReview,
  });

  final AttendanceRate presence;
  final int pendingCalls;
  final int absences;
  final int inReview;
}

final class AttendanceAttentionItem {
  const AttendanceAttentionItem({
    required this.id,
    required this.label,
    required this.detail,
    required this.count,
    this.callId,
  });

  final String id;
  final String label;
  final String detail;
  final int count;
  final String? callId;
}

final class AttendanceRankingItem {
  const AttendanceRankingItem({
    required this.id,
    required this.label,
    required this.rate,
    this.trendPercent,
    this.auxiliaryLabel,
  });

  final String id;
  final String label;
  final AttendanceRate rate;
  final double? trendPercent;
  final String? auxiliaryLabel;
}

final class AttendanceRanking {
  const AttendanceRanking({
    required this.kind,
    required this.total,
    required this.direction,
    required this.items,
  });

  final AttendanceRankingKind kind;
  final int total;
  final AttendanceRankingDirection direction;
  final List<AttendanceRankingItem> items;
}

final class AttendanceSeriesPoint {
  const AttendanceSeriesPoint({
    required this.start,
    required this.label,
    required this.current,
    required this.absences,
    required this.late,
    this.previous,
  });

  final DateTime start;
  final String label;
  final AttendanceRate current;
  final AttendanceRate? previous;
  final int absences;
  final int late;
}

final class AttendanceDashboardCallRow {
  const AttendanceDashboardCallRow({
    required this.id,
    required this.context,
    required this.date,
    required this.responsible,
    required this.present,
    required this.absent,
    required this.late,
    required this.presence,
    required this.status,
    required this.canOpen,
  });

  final String id;
  final String context;
  final DateTime date;
  final String responsible;
  final int present;
  final int absent;
  final int late;
  final AttendanceRate presence;
  final AttendanceDashboardCallStatus status;
  final bool canOpen;
}

final class AttendanceDashboardCallPage {
  const AttendanceDashboardCallPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalItems,
  });

  final List<AttendanceDashboardCallRow> items;
  final int page;
  final int pageSize;
  final int totalItems;

  int get totalPages => totalItems == 0 ? 1 : (totalItems / pageSize).ceil();
}

final class AttendanceDashboardSnapshot {
  const AttendanceDashboardSnapshot({
    required this.access,
    required this.query,
    required this.kpis,
    required this.attention,
    required this.rankings,
    required this.series,
    required this.calls,
    required this.contextLabel,
  });

  final AttendanceDashboardAccess access;
  final AttendanceDashboardQuery query;
  final AttendanceDashboardKpis kpis;
  final List<AttendanceAttentionItem> attention;
  final List<AttendanceRanking> rankings;
  final List<AttendanceSeriesPoint> series;
  final AttendanceDashboardCallPage calls;
  final String contextLabel;

  bool get isEmpty => rankings.every((ranking) => ranking.items.isEmpty) && calls.items.isEmpty;
}

final class AttendanceDashboardExportJob {
  const AttendanceDashboardExportJob({
    required this.id,
    required this.state,
    this.fileName,
    this.downloadUrl,
    this.errorCode,
  });

  final String id;
  final AttendanceDashboardExportState state;
  final String? fileName;
  final Uri? downloadUrl;
  final String? errorCode;
}

abstract interface class AttendanceDashboardRepository {
  Future<AttendanceDashboardAccess> fetchAccess();

  Future<AttendanceDashboardSnapshot> fetchDashboard(AttendanceDashboardQuery query);

  Future<AttendanceRanking> fetchRanking({
    required AttendanceDashboardQuery query,
    required AttendanceRankingKind kind,
    required int page,
    required int pageSize,
  });

  Future<AttendanceDashboardExportJob> requestExport({
    required AttendanceDashboardQuery query,
    required AttendanceDashboardExportKind kind,
    required AttendanceDashboardExportFormat format,
    required String idempotencyKey,
  });

  Future<AttendanceDashboardExportJob> fetchExportJob(String id);
}

final class AttendanceDashboardUnauthorized implements Exception {
  const AttendanceDashboardUnauthorized();
}
