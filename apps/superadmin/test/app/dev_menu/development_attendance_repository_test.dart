import 'package:coelo_superadmin/app/dev_menu/development_attendance_repository.dart';
import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('content persists created calls and edits only in the same instance', () async {
    final repository = DevelopmentAttendanceRepository.content();
    final created = await repository.createCall(
      AttendanceCallDraft(
        institutionId: 'institution-1',
        unitId: 'unit-1',
        groupId: 'group-sun',
        date: DateTime(2026, 8, 24),
      ),
    );
    await repository.setParticipantState(
      created.id,
      created.participants.first.id,
      AttendancePresenceState.present,
      expectedVersion: 1,
    );

    final persisted = await repository.fetchCall(created.id);
    expect(persisted?.participants.first.state, AttendancePresenceState.present);
    expect((await repository.fetchOverview()).calls.first.id, created.id);

    final reset = DevelopmentAttendanceRepository.content();
    expect(await reset.fetchCall(created.id), isNull);
  });

  test('empty, failure and unauthorized scenarios are deterministic', () async {
    expect((await DevelopmentAttendanceRepository.empty().fetchOverview()).calls, isEmpty);
    await expectLater(
      DevelopmentAttendanceRepository.failure().fetchOverview(),
      throwsA(isA<AttendanceUnavailableException>()),
    );
    await expectLater(
      DevelopmentAttendanceRepository.unauthorized().fetchOverview(),
      throwsA(isA<AttendanceUnauthorizedException>()),
    );
  });

  test('dashboard content is deterministic and export stays fail-closed', () async {
    final repository = DevelopmentAttendanceRepository.content();
    final query = _dashboardQuery();

    final access = await repository.fetchAccess();
    final snapshot = await repository.fetchDashboard(query);

    expect(access.canRead, isTrue);
    expect(access.canCreateCall, isTrue);
    expect(access.canExport, isFalse);
    expect(snapshot.query.periodStart, query.periodStart);
    expect(snapshot.query.periodEnd, query.periodEnd);
    expect(snapshot.contextLabel, 'Todas as instituições');
    expect(snapshot.rankings, isNotEmpty);
    expect(snapshot.series.map((point) => point.label), ['01/08', '02/08', '03/08']);
    expect(snapshot.series.every((point) => point.previous != null), isTrue);
    expect(snapshot.calls.items.map((call) => call.id), [
      'call-progress',
      'call-completed',
      'call-other-group',
    ]);
    await expectLater(
      repository.requestExport(
        query: query,
        kind: AttendanceDashboardExportKind.overview,
        format: AttendanceDashboardExportFormat.csv,
        idempotencyKey: 'dev-export',
      ),
      throwsA(isA<AttendanceUnavailableException>()),
    );
    await expectLater(
      repository.fetchExportJob('dev-export'),
      throwsA(isA<AttendanceUnavailableException>()),
    );
  });

  test('dashboard empty, failure and unauthorized modes are deterministic', () async {
    final query = _dashboardQuery();
    final empty = DevelopmentAttendanceRepository.empty();

    expect((await empty.fetchDashboard(query)).isEmpty, isTrue);
    expect(
      await empty.fetchRanking(
        query: query,
        kind: AttendanceRankingKind.groups,
        page: 1,
        pageSize: 10,
      ),
      isA<AttendanceRanking>().having((ranking) => ranking.items, 'items', isEmpty),
    );
    await expectLater(
      DevelopmentAttendanceRepository.failure().fetchAccess(),
      throwsA(isA<AttendanceUnavailableException>()),
    );
    await expectLater(
      DevelopmentAttendanceRepository.unauthorized().fetchAccess(),
      throwsA(isA<AttendanceDashboardUnauthorized>()),
    );
  });
}

AttendanceDashboardQuery _dashboardQuery() => AttendanceDashboardQuery(
  periodStart: DateTime(2026, 8),
  periodEnd: DevelopmentAttendanceRepository.today,
);
