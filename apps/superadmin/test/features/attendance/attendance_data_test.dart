import 'dart:convert';

import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/attendance/data/supabase_attendance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('unavailable adapter fails asynchronously with a typed error', () async {
    const repository = UnavailableAttendanceRepository();
    await expectLater(repository.fetchOverview(), throwsA(isA<AttendanceUnavailableException>()));
  });

  test('call detail preserves the authorized participant notice', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/rpc/superadmin_attendance_call_detail'));
        return Response(
          jsonEncode({
            'id': 'call-1',
            'institution_id': 'institution-1',
            'unit_id': 'unit-1',
            'group_id': 'group-1',
            'session_date': '2026-08-10',
            'status': 'open',
            'version': 2,
            'participants': [
              {
                'participant_id': 'participant-1',
                'name': 'Pessoa',
                'state': 'late_arrival',
                'notice': {
                  'id': 'notice-1',
                  'call_id': 'call-1',
                  'participant_id': 'participant-1',
                  'participant_name': 'Pessoa',
                  'intent': 'late_arrival',
                  'reason': 'Consulta',
                  'start_date': '2026-08-10T08:00:00Z',
                  'pending': true,
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final call = await SupabaseAttendanceRepository(client).fetchCall('call-1');

    expect(call!.participants.single.notice!.reason, 'Consulta');
    expect(call.participants.single.notice!.intent, AttendanceNoticeIntent.lateArrival);
  });

  test('dashboard adapter rejects an unknown access scope', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({'scope': 'unexpected-scope', 'can_read': true, 'can_create_call': true}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseAttendanceRepository(client).fetchAccess(),
      throwsA(isA<FormatException>()),
    );
  });

  test('dashboard adapter decodes access, insufficient data and server pagination', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rpc/attendance_dashboard_access')) {
          return Response(
            jsonEncode({
              'scope': 'platform',
              'can_read': true,
              'can_create_call': true,
              'can_export': true,
              'assigned_group_ids': <String>[],
              'assigned_activity_ids': <String>[],
              'child_ids': <String>[],
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        expect(request.url.path, endsWith('/rpc/attendance_dashboard_read'));
        return Response(
          jsonEncode({
            'access': {
              'scope': 'platform',
              'can_read': true,
              'can_create_call': true,
              'can_export': true,
              'assigned_group_ids': <String>[],
              'assigned_activity_ids': <String>[],
              'child_ids': <String>[],
            },
            'context_label': 'Todas as instituições',
            'kpis': {
              'presence': {'official_records': 0, 'percent': null},
              'pending_calls': 2,
              'absences': 0,
              'in_review': 1,
            },
            'attention': <Object?>[],
            'rankings': <Object?>[],
            'series': <Object?>[],
            'calls': {'page': 2, 'page_size': 20, 'total_items': 41, 'items': <Object?>[]},
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAttendanceRepository(client);
    final dashboardRepository = repository as AttendanceDashboardRepository;

    final access = await dashboardRepository.fetchAccess();
    final snapshot = await dashboardRepository.fetchDashboard(
      AttendanceDashboardQuery(
        periodStart: DateTime(2026, 8, 1),
        periodEnd: DateTime(2026, 8, 25),
        page: 2,
      ),
    );

    expect(access.canExport, isTrue);
    expect(snapshot.kpis.presence.isSufficient, isFalse);
    expect(snapshot.calls.totalPages, 3);
  });

  test('dashboard adapter rejects broad assignment export before the request RPC', () async {
    var exportRequests = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rpc/attendance_dashboard_access')) {
          return Response(
            jsonEncode({
              'scope': 'assignments',
              'institution_id': 'institution-1',
              'can_read': true,
              'can_export': true,
              'assigned_group_ids': ['group-1'],
              'assigned_activity_ids': ['activity-1'],
              'child_ids': <String>[],
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        exportRequests++;
        expect(request.url.path, endsWith('/rpc/attendance_dashboard_request_export'));
        return Response(
          jsonEncode({'id': 'job-1', 'state': 'processing'}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAttendanceRepository(client);
    final base = AttendanceDashboardQuery(
      periodStart: DateTime(2026, 8, 1),
      periodEnd: DateTime(2026, 8, 25),
      institutionId: 'institution-1',
    );

    await expectLater(
      repository.requestExport(
        query: base,
        kind: AttendanceDashboardExportKind.table,
        format: AttendanceDashboardExportFormat.csv,
        idempotencyKey: 'request-1',
      ),
      throwsA(isA<AttendanceDashboardUnauthorized>()),
    );
    expect(exportRequests, 0);

    await repository.requestExport(
      query: base.copyWith(groupId: 'group-1'),
      kind: AttendanceDashboardExportKind.table,
      format: AttendanceDashboardExportFormat.csv,
      idempotencyKey: 'request-2',
    );
    expect(exportRequests, 1);

    await repository.requestExport(
      query: base.copyWith(activityId: 'activity-1'),
      kind: AttendanceDashboardExportKind.table,
      format: AttendanceDashboardExportFormat.csv,
      idempotencyKey: 'request-3',
    );
    expect(exportRequests, 2);
    await expectLater(
      repository.requestExport(
        query: base.copyWith(groupId: 'group-other', activityId: 'activity-1'),
        kind: AttendanceDashboardExportKind.table,
        format: AttendanceDashboardExportFormat.csv,
        idempotencyKey: 'request-4',
      ),
      throwsA(isA<AttendanceDashboardUnauthorized>()),
    );
    expect(exportRequests, 2);
  });
}
