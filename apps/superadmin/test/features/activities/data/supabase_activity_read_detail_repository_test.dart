import 'dart:async';
import 'dart:convert';

import 'package:coelo_superadmin/features/activities/data/supabase_activity_read_detail_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_read_detail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _id = '11111111-1111-4111-8111-111111111111';
const _unit = '22222222-2222-4222-8222-222222222222';
const _group = '33333333-3333-4333-8333-333333333333';

void main() {
  test('requests only base sections and preserves physical facts on reload', () async {
    var calls = 0;
    final repo = _repository((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/rpc/superadmin_activity_detail_v2');
      expect(jsonDecode(request.body), {'p_activity_id': _id, 'p_sections': <String>[]});
      final data = _data();
      (data['activity']! as Map)['name'] = 'Activity $calls';
      return _json(_success(data));
    });
    final first = await repo.fetchById(_id);
    final second = await repo.fetchById(_id);
    expect(first.name, 'Activity 1');
    expect(second.name, 'Activity 2');
    expect(second.id, _id);
    expect(second.institutionId, _id);
    expect(second.managementVersion, 3);
    expect(second.units.single.unitId, _unit);
    expect(second.groups.single.groupId, _group);
    expect(second.groups.single.unitId, _unit);
    expect(second.groups.single.participationMode, 'selected');
    expect(second.counts.participants, 5);
    expect(second.counts.instructors, 2);
    expect(second.counts.activityAdmins, 1);
    expect(second.createdAt.isUtc, isTrue);
    expect(() => second.units.clear(), throwsUnsupportedError);
    expect(() => second.groups.clear(), throwsUnsupportedError);
  });
  test('nullable source fields remain null and empty draft stays empty', () async {
    final data = _data();
    final activity = data['activity']! as Map;
    for (final key in ['description', 'taxonomy_id', 'taxonomy_name', 'icon_key', 'initials']) {
      activity[key] = null;
    }
    activity['status'] = 'draft';
    data['units'] = [];
    data['groups'] = [];
    data['counts'] = {
      'units': 0,
      'groups': 0,
      'participants': 0,
      'instructors': 0,
      'activity_admins': 0,
    };
    final result = await _repository((_) async => _json(_success(data))).fetchById(_id);
    expect(result.taxonomyId, isNull);
    expect(result.taxonomyName, isNull);
    expect(result.description, isNull);
    expect(result.iconKey, isNull);
    expect(result.initials, isNull);
    expect(result.groups, isEmpty);
  });
  test('invalid input never reaches transport', () async {
    final repo = _repository((_) async => throw StateError('unexpected request'));
    await expectLater(repo.fetchById('invalid'), _failure(ActivityReadDetailFailure.invalidId));
  });
  final corruptions = <String, void Function(Map<String, Object?>)>{
    'missing counts': (d) => d.remove('counts'),
    'wrong activity id': (d) => (d['activity']! as Map)['activity_id'] = _group,
    'invalid institution': (d) => (d['activity']! as Map)['institution_id'] = 'bad',
    'unknown status': (d) => (d['activity']! as Map)['status'] = 'deleted',
    'zero version': (d) => (d['activity']! as Map)['management_version'] = 0,
    'unsafe version': (d) => (d['activity']! as Map)['management_version'] = 9007199254740992,
    'empty name': (d) => (d['activity']! as Map)['name'] = ' ',
    'bad timestamp': (d) => (d['activity']! as Map)['created_at'] = '2026-02-30T10:00:00Z',
    'naive timestamp': (d) => (d['activity']! as Map)['created_at'] = '2026-09-01T10:00:00',
    'negative count': (d) => (d['counts']! as Map)['participants'] = -1,
    'fractional count': (d) => (d['counts']! as Map)['instructors'] = 1.5,
    'inconsistent count': (d) => (d['counts']! as Map)['units'] = 2,
    'duplicate unit': (d) => (d['units']! as List).add((d['units']! as List).first),
    'duplicate group': (d) => (d['groups']! as List).add((d['groups']! as List).first),
    'unknown group unit': (d) => ((d['groups']! as List).first as Map)['unit_id'] = _id,
    'invalid participation': (d) =>
        ((d['groups']! as List).first as Map)['participation_mode'] = 'none',
    'inactive returned link': (d) => ((d['units']! as List).first as Map)['status'] = 'inactive',
  };
  for (final entry in corruptions.entries) {
    test('rejects ${entry.key}', () async {
      final data = _data();
      entry.value(data);
      await expectLater(
        _repository((_) async => _json(_success(data))).fetchById(_id),
        _failure(ActivityReadDetailFailure.unavailable),
      );
    });
  }
  for (final envelope in [
    null,
    <Object?>[],
    <String, Object?>{},
    {'ok': true, 'data': _data()},
    {
      'ok': true,
      'data': _data(),
      'error': {'code': 'SAI_PERMISSION_DENIED'},
    },
    {
      'ok': false,
      'data': _data(),
      'error': {'code': 'UNKNOWN', 'message': 'secret'},
    },
  ]) {
    test('malformed or contradictory envelope fails closed ${jsonEncode(envelope)}', () async {
      await expectLater(
        _repository((_) async => _json(envelope)).fetchById(_id),
        _failure(ActivityReadDetailFailure.unavailable),
      );
    });
  }
  for (final code in [
    'SAI_AUTH_REQUIRED',
    'SAI_SESSION_INVALID',
    'SAI_INTERNAL_CONTEXT_DENIED',
    'SAI_MEMBERSHIP_SUSPENDED',
    'SAI_MEMBERSHIP_REVOKED',
    'SAI_PERMISSION_DENIED',
    'SAI_MFA_REQUIRED',
    'ACTIVITY_NOT_FOUND',
  ]) {
    test('denial $code discards previously read data', () async {
      var calls = 0;
      final repo = _repository(
        (_) async => _json(
          calls++ == 0
              ? _success(_data())
              : {
                  'ok': false,
                  'data': null,
                  'error': {
                    'code': code,
                    'message': 'secret',
                    'correlation_id': _id,
                    'http_status': 403,
                  },
                },
        ),
      );
      await repo.fetchById(_id);
      await expectLater(repo.fetchById(_id), _failure(ActivityReadDetailFailure.denied));
    });
  }
  for (final change in <void Function(Map<String, Object?>)>[
    (e) => e.remove('message'),
    (e) => e['extra'] = 'secret',
    (e) => e['code'] = 3,
    (e) => e['message'] = [],
    (e) => e['correlation_id'] = 'bad',
    (e) => e['http_status'] = 399,
    (e) => e['http_status'] = 600,
    (e) => e['http_status'] = '403',
  ]) {
    test('malformed denial fails unavailable ${change.hashCode}', () async {
      final error = <String, Object?>{
        'code': 'SAI_PERMISSION_DENIED',
        'message': 'secret',
        'correlation_id': _id,
        'http_status': 403,
      };
      change(error);
      await expectLater(
        _repository((_) async => _json({'ok': false, 'data': null, 'error': error})).fetchById(_id),
        _failure(ActivityReadDetailFailure.unavailable),
      );
    });
  }
  for (final error in [
    ClientException('secret'),
    TimeoutException('secret'),
    StateError('secret'),
  ]) {
    test('sanitizes ${error.runtimeType}', () async {
      await expectLater(
        _repository((_) async => throw error).fetchById(_id),
        _failure(ActivityReadDetailFailure.unavailable),
      );
    });
  }
}

Matcher _failure(ActivityReadDetailFailure failure) => throwsA(
  isA<ActivityReadDetailException>()
      .having((e) => e.failure, 'failure', failure)
      .having((e) => e.toString().contains('secret'), 'contains internal message', isFalse),
);

SupabaseActivityReadDetailRepository _repository(Future<Response> Function(Request) handler) {
  final client = SupabaseClient(
    'https://example.test',
    'public-test-key',
    httpClient: MockClient((request) async {
      final response = await handler(request);
      return Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }),
  );
  addTearDown(client.dispose);
  return SupabaseActivityReadDetailRepository(client);
}

Response _json(Object? value) =>
    Response(jsonEncode(value), 200, headers: {'content-type': 'application/json'});
Map<String, Object?> _success(Object data) => {'ok': true, 'data': data, 'error': null};
Map<String, Object?> _data() => {
  'activity': <String, Object?>{
    'activity_id': _id,
    'institution_id': _id,
    'name': 'Activity',
    'description': 'Description',
    'taxonomy_id': _group,
    'taxonomy_name': 'Music',
    'status': 'active',
    'management_version': 3,
    'icon_key': 'music_note',
    'initials': 'MU',
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-02T10:00:00+00:00',
  },
  'units': [
    {'unit_id': _unit, 'name': 'Unit', 'status': 'active'},
  ],
  'groups': [
    {
      'group_id': _group,
      'unit_id': _unit,
      'name': 'Group',
      'status': 'active',
      'participation_mode': 'selected',
    },
  ],
  'counts': <String, Object?>{
    'units': 1,
    'groups': 1,
    'participants': 5,
    'instructors': 2,
    'activity_admins': 1,
  },
};
