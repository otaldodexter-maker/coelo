import 'dart:convert';

import 'package:coelo_superadmin/features/people/data/supabase_person_directory_repository.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final mutations = <String, void Function(Map<String, dynamic>)>{
    'different resource id': (data) => data['id'] = 'other-person',
    'legacy person_type alias': (data) => data['person_type'] = data.remove('type'),
    'extra email PII': (data) => data['email'] = 'synthetic@example.test',
    'legacy auth flag': (data) => data['has_active_login'] = true,
    'platform summary': (data) => data['platform_membership_summary'] = 'legacy',
    'guardian summary': (data) => data['guardian_links_summary'] = 'legacy',
    'missing auth': (data) => data.remove('auth_link'),
    'missing memberships': (data) => data.remove('memberships'),
    'missing child contexts': (data) => data.remove('child_contexts'),
    'missing first name': (data) => data.remove('first_name'),
    'missing last name': (data) => data.remove('last_name'),
    'missing nullable legal name': (data) => data.remove('legal_name'),
    'null first name': (data) => data['first_name'] = null,
    'null last name': (data) => data['last_name'] = null,
    'null memberships': (data) => data['memberships'] = null,
    'null child contexts': (data) => data['child_contexts'] = null,
    'null platform flag': (data) => (data['memberships'] as List).single['is_platform'] = null,
    'null institution label': (data) =>
        (data['memberships'] as List).single['institution_name'] = null,
    'malformed UUID': (data) => data['id'] = 'not-a-uuid',
    'unknown type': (data) => data['type'] = 'unknown',
    'unknown status': (data) => data['status'] = 'unknown',
    'unknown auth classification': (data) => data['auth_link'] = 'unknown',
    'timestamp without zone': (data) => data['updated_at'] = '2026-09-07T12:00:00',
    'impossible calendar date': (data) => data['updated_at'] = '2026-02-30T12:00:00Z',
    'impossible clock time': (data) => data['updated_at'] = '2026-09-07T25:00:00Z',
    'impossible zone offset': (data) => data['updated_at'] = '2026-09-07T12:00:00+25:00',
    'membership legacy assignment alias': (data) {
      final item = (data['memberships'] as List).single as Map;
      item['assignment_id'] = item.remove('id');
    },
    'membership platform flag': (data) =>
        (data['memberships'] as List).single['is_platform'] = true,
    'membership missing institution label': (data) =>
        ((data['memberships'] as List).single as Map).remove('institution_name'),
    'membership activity extra': (data) =>
        (data['memberships'] as List).single['activity_id'] = 'activity',
    'adult child contexts': (data) => data['child_contexts'] = [_context()],
    'child legacy context alias': (data) {
      data['type'] = 'child';
      final context = _context();
      context['child_context_id'] = context.remove('id');
      data['child_contexts'] = [context];
    },
    'child nested unit links': (data) {
      data['type'] = 'child';
      data['child_contexts'] = [_context()..['unit_links'] = <Object>[]];
    },
  };
  for (final entry in mutations.entries) {
    test('v2 rejects ${entry.key}', () async {
      final data = _data();
      entry.value(data);
      final repository = _repository({'ok': true, 'data': data, 'error': null});
      await expectLater(
        repository.fetchDetail(_personId),
        throwsA(isA<PersonDirectoryUnavailableException>()),
      );
    });
  }

  test('v2 rejects inconsistent success envelope', () async {
    final repository = _repository({
      'ok': true,
      'data': _data(),
      'error': {'code': 'SAI_PERMISSION_DENIED'},
    });
    await expectLater(
      repository.fetchDetail(_personId),
      throwsA(isA<PersonDirectoryUnavailableException>()),
    );
  });

  test('valid suspended status is represented by the model bridge', () async {
    final repository = _repository({
      'ok': true,
      'data': _data()..['status'] = 'suspended',
      'error': null,
    });
    expect((await repository.fetchDetail(_personId)).status, PersonStatus.suspended);
  });

  for (final code in [
    'SAI_AUTH_REQUIRED',
    'SAI_SESSION_INVALID',
    'SAI_INTERNAL_CONTEXT_DENIED',
    'SAI_MEMBERSHIP_SUSPENDED',
    'SAI_MEMBERSHIP_REVOKED',
    'SAI_PERMISSION_DENIED',
    'SAI_MFA_REQUIRED',
  ]) {
    test('v2 maps exact denial $code without message leakage', () async {
      final repository = _repository({
        'ok': false,
        'data': null,
        'error': {
          'code': code,
          'message': 'Synthetic private diagnostic',
          'correlation_id': _personId,
          'http_status': 403,
        },
      });
      await expectLater(
        repository.fetchDetail(_personId),
        throwsA(isA<PersonDirectoryUnauthorizedException>()),
      );
    });
  }

  test('v2 rejects a denial carrying data', () async {
    final repository = _repository({
      'ok': false,
      'data': _data(),
      'error': {
        'code': 'SAI_PERMISSION_DENIED',
        'message': 'Denied',
        'correlation_id': _personId,
        'http_status': 403,
      },
    });
    await expectLater(
      repository.fetchDetail(_personId),
      throwsA(isA<PersonDirectoryUnavailableException>()),
    );
  });

  test('v2 preserves populated flat child paths and legal name', () async {
    const unit = '60000000-0000-4000-8000-000000000001';
    const group = '70000000-0000-4000-8000-000000000001';
    const unitLink = '80000000-0000-4000-8000-000000000001';
    const groupLink = '90000000-0000-4000-8000-000000000001';
    final context = _context()
      ..addAll({
        'unit_id': unit,
        'unit_name': 'Unit',
        'group_id': group,
        'group_name': 'Group',
        'child_unit_link_id': unitLink,
        'child_group_link_id': groupLink,
      });
    final data = _data()
      ..addAll({
        'type': 'child',
        'legal_name': 'Synthetic legal',
        'child_contexts': [context],
      });
    ((data['memberships'] as List).single as Map).addAll(<String, Object?>{
      'id': _contextId,
      'membership_id': null,
      'role': 'student',
      'unit_id': unit,
      'unit_name': 'Unit',
      'group_id': group,
      'group_name': 'Group',
    });
    final person = await _repository({
      'ok': true,
      'data': data,
      'error': null,
    }).fetchDetail(_personId.toUpperCase());
    expect(person.legalName, 'Synthetic legal');
    expect(person.childContexts.single.childUnitLinkId, unitLink);
    expect(person.childContexts.single.childGroupLinkId, groupLink);
    expect(person.memberships.single.unitId, unit);
    expect(person.memberships.single.groupId, group);
    expect(() => person.childContexts.clear(), throwsUnsupportedError);
    expect(() => person.memberships.clear(), throwsUnsupportedError);
  });

  test('v2 preserves a valid leap date, fractional seconds and offset', () async {
    final data = _data()..['updated_at'] = '2024-02-29T23:59:59.123456-03:00';
    final person = await _repository({
      'ok': true,
      'data': data,
      'error': null,
    }).fetchDetail(_personId);
    expect(person.updatedAt, DateTime.utc(2024, 3, 1, 2, 59, 59, 123, 456));
  });

  test('v2 rejects extra envelope keys', () async {
    final repository = _repository({
      'ok': true,
      'data': _data(),
      'error': null,
      'internal_debug': 'synthetic',
    });
    await expectLater(
      repository.fetchDetail(_personId),
      throwsA(isA<PersonDirectoryUnavailableException>()),
    );
  });

  test('v2 normalizes unexpected transport error without raw message', () async {
    final repository = _repository({
      'code': 'XX000',
      'message': 'synthetic internal table detail',
      'details': 'synthetic detail',
      'hint': null,
    }, status: 500);
    await expectLater(
      repository.fetchDetail(_personId),
      throwsA(isA<PersonDirectoryUnavailableException>()),
    );
  });

  for (final type in PersonType.values) {
    test('v2 accepts exact ${type.name} shape with nullable fields', () async {
      final data = _data()..['type'] = type.databaseValue;
      if (type == PersonType.child) {
        data['child_contexts'] = [_context()];
        (data['memberships'] as List).single['role'] = 'student';
        (data['memberships'] as List).single['membership_id'] = null;
        (data['memberships'] as List).single['id'] = _contextId;
      }
      if (type == PersonType.service) data['memberships'] = <Object>[];
      final person = await _repository({
        'ok': true,
        'data': data,
        'error': null,
      }).fetchDetail(_personId);
      expect(person.id, _personId);
      expect(person.type, type);
      expect(person.legalName, isNull);
      expect(person.platformMembershipSummary, isNull);
      expect(person.guardianLinksSummary, isNull);
    });
  }
}

SupabasePersonDirectoryRepository _repository(Object payload, {int status = 200}) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'publishable-key',
    httpClient: MockClient(
      (request) async => Response(
        jsonEncode(payload),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    ),
  );
  addTearDown(client.dispose);
  return SupabasePersonDirectoryRepository(client);
}

Map<String, dynamic> _data() => {
  'id': _personId,
  'first_name': 'First',
  'last_name': 'Last',
  'display_name': 'Synthetic',
  'legal_name': null,
  'type': 'adult',
  'status': 'active',
  'auth_link': 'unlinked',
  'memberships': [
    {
      'id': '20000000-0000-4000-8000-000000000001',
      'membership_id': '30000000-0000-4000-8000-000000000001',
      'institution_id': '40000000-0000-4000-8000-000000000001',
      'institution_name': 'Synthetic institution',
      'unit_id': null,
      'unit_name': null,
      'group_id': null,
      'group_name': null,
      'role': 'guardian',
      'is_platform': false,
    },
  ],
  'child_contexts': <Object>[],
  'updated_at': '2026-09-07T12:00:00Z',
};

Map<String, dynamic> _context() => {
  'id': _contextId,
  'institution_id': '40000000-0000-4000-8000-000000000001',
  'institution_name': 'Synthetic institution',
  'unit_id': null,
  'unit_name': null,
  'group_id': null,
  'group_name': null,
  'child_unit_link_id': null,
  'child_group_link_id': null,
};

const _personId = '10000000-0000-4000-8000-000000000001';
const _contextId = '50000000-0000-4000-8000-000000000001';
