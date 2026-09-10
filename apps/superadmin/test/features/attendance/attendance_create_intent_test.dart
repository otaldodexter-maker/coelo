import 'dart:convert';

import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/attendance/data/supabase_attendance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _draft = AttendanceCallDraft(
  institutionId: 'institution-1',
  unitId: 'unit-1',
  groupId: 'group-1',
  activityContextId: 'activity-1',
  date: DateTime(2026, 8, 10),
);

void main() {
  test('retrying a failed call creation repeats the same idempotency key', () async {
    final keys = <String>[];
    var attempt = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/rpc/superadmin_attendance_create_call'));
        keys.add((jsonDecode(request.body) as Map<String, Object?>)['p_idempotency_key']! as String);
        if (attempt++ == 0) {
          return Response('{"message":"boom"}', 500, request: request);
        }
        return Response(
          jsonEncode({
            'id': 'call-1',
            'institution_id': 'institution-1',
            'unit_id': 'unit-1',
            'group_id': 'group-1',
            'session_date': '2026-08-10',
            'status': 'open',
            'version': 1,
            'participants': <Object?>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAttendanceRepository(client);

    await expectLater(repository.createCall(_draft), throwsA(isA<Object>()));
    await repository.createCall(_draft);

    expect(keys, hasLength(2));
    expect(
      keys.first,
      keys.last,
      reason: 'creating the same call twice is one intent retried, not two calls',
    );
  });

  test('a call for another group is a different intent', () async {
    final keys = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        keys.add((jsonDecode(request.body) as Map<String, Object?>)['p_idempotency_key']! as String);
        return Response(
          jsonEncode({
            'id': 'call-1',
            'institution_id': 'institution-1',
            'unit_id': 'unit-1',
            'group_id': 'group-1',
            'session_date': '2026-08-10',
            'status': 'open',
            'version': 1,
            'participants': <Object?>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAttendanceRepository(client);

    await repository.createCall(_draft);
    await repository.createCall(
      AttendanceCallDraft(
        institutionId: _draft.institutionId,
        unitId: _draft.unitId,
        groupId: 'group-2',
        activityContextId: _draft.activityContextId,
        date: _draft.date,
      ),
    );
    await repository.createCall(
      AttendanceCallDraft(
        institutionId: _draft.institutionId,
        unitId: _draft.unitId,
        groupId: _draft.groupId,
        activityContextId: _draft.activityContextId,
        date: DateTime(2026, 8, 11),
      ),
    );

    expect(keys.toSet(), hasLength(3), reason: 'another group or another day is another call');
  });
}
