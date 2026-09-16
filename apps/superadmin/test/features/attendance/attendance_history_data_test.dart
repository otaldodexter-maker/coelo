import 'dart:convert';

import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/attendance/data/supabase_attendance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Contrato do cliente com `superadmin_attendance_call_history_v1` e com as
/// chaves `routine_*` do detalhe (spec 052 §4). O envelope enviado, o cursor,
/// os agregados e a origem da rotina são o que a tela lê; escopo e negativas
/// são provados no pgTAP.
SupabaseClient _client(Future<Response> Function(Request request) handler) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'publishable-key',
    httpClient: MockClient(handler),
  );
  addTearDown(client.dispose);
  return client;
}

Response _json(Object body, Request request, {int status = 200}) => Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
  request: request,
);

void main() {
  test('history sends the filters, period, cursor and page size the server expects', () async {
    Map<String, dynamic>? sent;
    final client = _client((request) async {
      expect(request.url.path, endsWith('/rpc/superadmin_attendance_call_history_v1'));
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return _json({'items': <Object?>[], 'has_more': false, 'next_cursor': null}, request);
    });

    final page = await SupabaseAttendanceRepository(client).fetchHistory(
      AttendanceHistoryQuery(
        periodStart: DateTime(2026, 8, 17),
        periodEnd: DateTime(2026, 9, 16),
        institutionId: 'inst-1',
        unitId: 'unit-1',
        groupId: 'group-1',
        status: AttendanceHistoryStatusFilter.completed,
        cursor: 'abc=',
        pageSize: 25,
      ),
    );

    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
    expect(sent, {
      'p_institution_id': 'inst-1',
      'p_unit_id': 'unit-1',
      'p_group_id': 'group-1',
      'p_activity_id': null,
      'p_start': '2026-08-17',
      'p_end': '2026-09-16',
      'p_status': 'completed',
      'p_cursor': 'abc=',
      'p_page_size': 25,
    });
  });

  test('history decodes aggregates, status, cursor and routine origin', () async {
    final client = _client(
      (request) async => _json({
        'items': [
          {
            'id': 'call-1',
            'session_date': '2026-09-15',
            'institution_id': 'inst-1',
            'institution_name': 'Escola',
            'unit_id': 'unit-1',
            'unit_name': 'Unidade',
            'group_id': 'group-1',
            'group_name': 'Turma A',
            'activity_id': null,
            'activity_name': null,
            'context': 'Escola · Unidade · Turma A',
            'responsible': 'Ana',
            'status': 'corrected',
            'expected': 12,
            'official_records': 11,
            'present': 9,
            'absent': 2,
            'late': 1,
            'early_departures': 0,
            'can_open': true,
            'routine': {
              'source': 'snapshot',
              'application_id': 'app-1',
              'revision_no': 3,
              'name': 'Rotina Berçário',
              'recorded_at': '2026-09-15T18:00:00Z',
            },
          },
          {
            'id': 'call-2',
            'session_date': '2026-09-14',
            'institution_id': 'inst-1',
            'unit_id': 'unit-1',
            'group_id': 'group-1',
            'activity_id': 'activity-1',
            'activity_name': 'Música',
            'status': 'reopened',
            'routine': {'source': 'current', 'application_id': 'app-1', 'revision_no': 4, 'name': 'Rotina Berçário'},
          },
          {
            'id': 'call-3',
            'session_date': '2026-09-13',
            'institution_id': 'inst-1',
            'unit_id': 'unit-1',
            'group_id': 'group-1',
            'status': 'open',
            'routine': null,
          },
        ],
        'has_more': true,
        'next_cursor': 'MjAyNi0wOS0xM3w=',
      }, request),
    );

    final page = await SupabaseAttendanceRepository(client).fetchHistory(
      AttendanceHistoryQuery(periodStart: DateTime(2026, 9), periodEnd: DateTime(2026, 9, 16)),
    );

    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'MjAyNi0wOS0xM3w=');
    final first = page.items[0];
    expect(first.date, DateTime(2026, 9, 15));
    expect(first.status, AttendanceCallStatus.completed, reason: 'corrigida conta como concluída');
    expect(first.expected, 12);
    expect(first.present, 9);
    expect(first.absent, 2);
    expect(first.contextName, 'Turma A');
    expect(first.routine.source, AttendanceRoutineSource.snapshot);
    expect(first.routine.label, 'Rotina Berçário · v3');
    expect(first.routine.sourceLabel(concluded: true), 'registrada na conclusão');
    expect(first.routine.recordedAt, DateTime.utc(2026, 9, 15, 18));

    final second = page.items[1];
    expect(second.status, AttendanceCallStatus.reopened);
    expect(second.contextName, 'Música');
    expect(second.routine.source, AttendanceRoutineSource.current);
    expect(second.routine.sourceLabel(concluded: true), 'rotina atual (não registrada na época)');
    expect(second.routine.sourceLabel(concluded: false), 'rotina vigente');

    final third = page.items[2];
    expect(third.routine.source, AttendanceRoutineSource.none);
    expect(third.routine.hasRoutine, isFalse);
    expect(third.routine.label, 'Sem rotina vinculada');
    expect(third.expected, 0);
  });

  test('call detail decodes routine_source, snapshot and current routine', () async {
    Map<String, dynamic> call(Map<String, Object?> extra) => {
      'id': 'call-1',
      'institution_id': 'inst-1',
      'unit_id': 'unit-1',
      'group_id': 'group-1',
      'session_date': '2026-09-15',
      'status': 'closed',
      'version': 3,
      'participants': <Object?>[],
      ...extra,
    };
    Future<AttendanceCall> decode(Map<String, Object?> extra) async {
      final client = _client((request) async => _json(call(extra), request));
      return (await SupabaseAttendanceRepository(client).fetchCall('call-1'))!;
    }

    final snapshot = await decode({
      'routine_source': 'snapshot',
      'routine_snapshot': {
        'application_id': 'app-1',
        'revision_no': 2,
        'name': 'Rotina Maternal',
        'recorded_at': '2026-09-15T18:00:00Z',
      },
      'routine_current': {'application_id': 'app-1', 'revision_no': 5, 'name': 'Rotina Maternal'},
    });
    expect(snapshot.routine.source, AttendanceRoutineSource.snapshot);
    expect(snapshot.routine.revisionNo, 2, reason: 'o detalhe mostra o snapshot, não a vigente');

    final legacy = await decode({
      'routine_source': 'current',
      'routine_snapshot': null,
      'routine_current': {'application_id': 'app-1', 'revision_no': 5, 'name': 'Rotina Maternal'},
    });
    expect(legacy.routine.source, AttendanceRoutineSource.current);
    expect(legacy.routine.label, 'Rotina Maternal · v5');

    final none = await decode({'routine_source': 'none', 'routine_snapshot': null, 'routine_current': null});
    expect(none.routine.source, AttendanceRoutineSource.none);

    final beforeMigration = await decode({});
    expect(beforeMigration.routine.source, AttendanceRoutineSource.none);
  });

  test('PT409 from the server is a version conflict, like the legacy 40001', () async {
    for (final code in ['PT409', '40001']) {
      final client = _client(
        (request) async => _json({
          'code': code,
          'message': 'attendance call version conflict',
          'details': null,
          'hint': null,
        }, request, status: 409),
      );
      await expectLater(
        SupabaseAttendanceRepository(client).completeCall('call-1', expectedVersion: 1),
        throwsA(isA<AttendanceVersionConflictException>()),
        reason: 'código $code',
      );
    }
  });

  test('unauthorized history reads surface as the typed exception', () async {
    final client = _client(
      (request) async => _json({
        'code': '42501',
        'message': 'attendance.read required',
        'details': null,
        'hint': null,
      }, request, status: 403),
    );
    await expectLater(
      SupabaseAttendanceRepository(client).fetchHistory(
        AttendanceHistoryQuery(periodStart: DateTime(2026, 9), periodEnd: DateTime(2026, 9, 16)),
      ),
      throwsA(isA<AttendanceUnauthorizedException>()),
    );
  });
}
