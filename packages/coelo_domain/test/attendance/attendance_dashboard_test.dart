import 'package:coelo_domain/coelo_domain.dart';
import 'package:test/test.dart';

void main() {
  group('AttendanceRate', () {
    test('uses every official record in the denominator', () {
      final rate = AttendanceRate.fromCounts(
        present: 7,
        late: 1,
        earlyDeparture: 1,
        lateAndEarly: 1,
        absent: 2,
      );

      expect(rate.isSufficient, isTrue);
      expect(rate.officialRecords, 12);
      expect(rate.percent, closeTo(83.333, 0.001));
    });

    test('reports insufficient data instead of zero percent', () {
      final rate = AttendanceRate.fromCounts(
        present: 0,
        late: 0,
        earlyDeparture: 0,
        lateAndEarly: 0,
        absent: 0,
      );

      expect(rate.isSufficient, isFalse);
      expect(rate.percent, isNull);
    });
  });

  test('changing an institution clears every descendant selection', () {
    final query = AttendanceDashboardQuery(
      periodStart: DateTime(2026, 8, 1),
      periodEnd: DateTime(2026, 8, 25),
      institutionId: 'institution-a',
      unitId: 'unit-a',
      groupId: 'group-a',
      activityId: 'activity-a',
      childId: 'child-a',
    );

    final changed = query.selectInstitution('institution-b');

    expect(changed.institutionId, 'institution-b');
    expect(changed.unitId, isNull);
    expect(changed.groupId, isNull);
    expect(changed.activityId, isNull);
    expect(changed.childId, isNull);
    expect(changed.page, 1);
  });

  test('fixed access scope cannot be removed from a query', () {
    const access = AttendanceDashboardAccess(
      scope: AttendanceDashboardScope.institution,
      institutionId: 'institution-a',
      canRead: true,
    );
    final query = AttendanceDashboardQuery(
      periodStart: DateTime(2026, 8, 1),
      periodEnd: DateTime(2026, 8, 25),
    );

    final scoped = query.enforce(access);

    expect(scoped.institutionId, 'institution-a');
    expect(scoped.unitId, isNull);
  });

  test('assignment export requires and validates an assigned group or activity', () {
    const access = AttendanceDashboardAccess(
      scope: AttendanceDashboardScope.assignments,
      institutionId: 'institution-a',
      canRead: true,
      canExport: true,
      assignedGroupIds: {'group-a'},
      assignedActivityIds: {'activity-a'},
    );
    final base = AttendanceDashboardQuery(
      periodStart: DateTime(2026, 8, 1),
      periodEnd: DateTime(2026, 8, 25),
      institutionId: 'institution-a',
    );

    expect(base.isValidExportScope(access), isFalse);
    expect(base.copyWith(groupId: 'group-a').isValidExportScope(access), isTrue);
    expect(base.copyWith(groupId: 'group-other').isValidExportScope(access), isFalse);
    expect(base.copyWith(activityId: 'activity-a').isValidExportScope(access), isTrue);
    expect(
      base
          .copyWith(groupId: 'group-for-activity', activityId: 'activity-a')
          .isValidExportScope(access),
      isFalse,
    );
    expect(
      base.copyWith(groupId: 'group-a', activityId: 'activity-a').isValidExportScope(access),
      isTrue,
    );
    expect(
      base
          .copyWith(groupId: 'group-for-activity', activityId: 'activity-other')
          .isValidExportScope(access),
      isFalse,
    );
  });
}
