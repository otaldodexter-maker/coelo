import 'dart:async';

import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/attendance/attendance_dashboard_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final initialQuery = AttendanceDashboardQuery(
    periodStart: DateTime(2026, 8, 1),
    periodEnd: DateTime(2026, 8, 25),
  );

  test('loads access and dashboard into a ready state', () async {
    final repository = _DashboardRepository();
    final controller = AttendanceDashboardController(
      repository: repository,
      initialQuery: initialQuery,
    );

    await controller.load();

    expect(controller.state, isA<AttendanceDashboardReady>());
    expect(repository.dashboardQueries, hasLength(1));
  });

  test('changing a parent clears descendants before one reload', () async {
    final repository = _DashboardRepository();
    final controller = AttendanceDashboardController(
      repository: repository,
      initialQuery: initialQuery.copyWith(
        institutionId: 'institution-a',
        unitId: 'unit-a',
        groupId: 'group-a',
        activityId: 'activity-a',
      ),
    );
    await controller.load();

    await controller.selectInstitution('institution-b');

    final query = repository.dashboardQueries.last;
    expect(query.institutionId, 'institution-b');
    expect(query.unitId, isNull);
    expect(query.groupId, isNull);
    expect(query.activityId, isNull);
    expect(repository.dashboardQueries, hasLength(2));
  });

  test('ignores an obsolete response', () async {
    final first = Completer<AttendanceDashboardSnapshot>();
    final second = Completer<AttendanceDashboardSnapshot>();
    final repository = _DashboardRepository(responses: [first.future, second.future]);
    final controller = AttendanceDashboardController(
      repository: repository,
      initialQuery: initialQuery,
    );

    final firstLoad = controller.load();
    final secondLoad = controller.changeGranularity(AttendanceDashboardGranularity.weekly);
    second.complete(
      _snapshot(initialQuery.copyWith(granularity: AttendanceDashboardGranularity.weekly)),
    );
    await secondLoad;
    first.complete(_snapshot(initialQuery));
    await firstLoad;

    final ready = controller.state as AttendanceDashboardReady;
    expect(ready.snapshot.query.granularity, AttendanceDashboardGranularity.weekly);
  });

  test('status, sort and page size reset pagination and reload once each', () async {
    final repository = _DashboardRepository();
    final controller = AttendanceDashboardController(
      repository: repository,
      initialQuery: initialQuery.copyWith(page: 3),
    );
    await controller.load();

    await controller.changeStatuses({AttendanceDashboardCallStatus.pending});
    expect(repository.dashboardQueries.last.statuses, {AttendanceDashboardCallStatus.pending});
    expect(repository.dashboardQueries.last.page, 1);
    await controller.changeSort(AttendanceDashboardCallSort.presence);
    expect(repository.dashboardQueries.last.sort, AttendanceDashboardCallSort.presence);
    await controller.changePageSize(50);
    expect(repository.dashboardQueries.last.pageSize, 50);
    expect(repository.dashboardQueries, hasLength(4));
  });

  test('exposes unauthorized and retryable failure states', () async {
    final unauthorized = _DashboardRepository(error: const AttendanceDashboardUnauthorized());
    final unauthorizedController = AttendanceDashboardController(
      repository: unauthorized,
      initialQuery: initialQuery,
    );
    await unauthorizedController.load();
    expect(unauthorizedController.state, isA<AttendanceDashboardUnauthorizedState>());

    final failed = _DashboardRepository(error: StateError('offline'));
    final failedController = AttendanceDashboardController(
      repository: failed,
      initialQuery: initialQuery,
    );
    await failedController.load();
    expect(failedController.state, isA<AttendanceDashboardFailure>());
  });
}

final class _DashboardRepository implements AttendanceDashboardRepository {
  _DashboardRepository({this.error, this.responses = const []});

  final Object? error;
  final List<Future<AttendanceDashboardSnapshot>> responses;
  final dashboardQueries = <AttendanceDashboardQuery>[];

  @override
  Future<AttendanceDashboardAccess> fetchAccess() async => const AttendanceDashboardAccess(
    scope: AttendanceDashboardScope.platform,
    canRead: true,
    canCreateCall: true,
    canExport: true,
  );

  @override
  Future<AttendanceDashboardSnapshot> fetchDashboard(AttendanceDashboardQuery query) {
    dashboardQueries.add(query);
    if (error != null) return Future.error(error!);
    final index = dashboardQueries.length - 1;
    if (index < responses.length) return responses[index];
    return Future.value(_snapshot(query));
  }

  @override
  Future<AttendanceDashboardExportJob> fetchExportJob(String id) => throw UnimplementedError();

  @override
  Future<AttendanceRanking> fetchRanking({
    required AttendanceDashboardQuery query,
    required AttendanceRankingKind kind,
    required int page,
    required int pageSize,
  }) => throw UnimplementedError();

  @override
  Future<AttendanceDashboardExportJob> requestExport({
    required AttendanceDashboardQuery query,
    required AttendanceDashboardExportKind kind,
    required AttendanceDashboardExportFormat format,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

AttendanceDashboardSnapshot _snapshot(AttendanceDashboardQuery query) =>
    AttendanceDashboardSnapshot(
      access: const AttendanceDashboardAccess(
        scope: AttendanceDashboardScope.platform,
        canRead: true,
        canCreateCall: true,
        canExport: true,
      ),
      query: query,
      kpis: AttendanceDashboardKpis(
        presence: AttendanceRate.fromCounts(
          present: 9,
          late: 1,
          earlyDeparture: 0,
          lateAndEarly: 0,
          absent: 0,
        ),
        pendingCalls: 1,
        absences: 0,
        inReview: 0,
      ),
      attention: const [],
      rankings: [
        AttendanceRanking(
          kind: AttendanceRankingKind.institutions,
          total: 1,
          direction: AttendanceRankingDirection.highest,
          items: [
            AttendanceRankingItem(
              id: 'institution-a',
              label: 'Instituição A',
              rate: AttendanceRate.fromCounts(
                present: 9,
                late: 1,
                earlyDeparture: 0,
                lateAndEarly: 0,
                absent: 0,
              ),
            ),
          ],
        ),
      ],
      series: const [],
      calls: const AttendanceDashboardCallPage(items: [], page: 1, pageSize: 20, totalItems: 0),
      contextLabel: 'Todas as instituições',
    );
