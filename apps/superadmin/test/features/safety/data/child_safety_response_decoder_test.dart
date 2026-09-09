import 'package:coelo_superadmin/features/safety/data/child_safety_response_decoder.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final field in ['internal_id', 'child_context_id', 'institution_id', 'unit_id']) {
    test('child option rejects malformed nullable $field with a typed failure', () {
      for (final invalid in <Object>[42, true, <Object>[], <String, Object>{}]) {
        final context = <String, Object?>{
          'child_context_id': 'context-1',
          'institution_id': 'institution-1',
          'unit_id': 'unit-1',
          if (field != 'internal_id') field: invalid,
        };
        expect(
          () => decodeChildSafetyOptions([
            {
              'id': 'child-1',
              'display_name': 'Ana',
              'internal_id': field == 'internal_id' ? invalid : 'RA 1',
              'contexts': [context],
            },
          ]),
          throwsA(isA<ChildSafetyUnavailableException>()),
          reason: '$field must reject ${invalid.runtimeType}',
        );
      }
    });
    test('child record rejects malformed context $field with a typed failure', () {
      for (final invalid in <Object>[42, true, <Object>[], <String, Object>{}]) {
        expect(
          () => decodeChildSafetyRecord({
            'child_id': 'child-1',
            'child_name': 'Ana',
            'contexts': [
              {field: invalid},
            ],
          }),
          throwsA(isA<ChildSafetyUnavailableException>()),
          reason: '$field must reject ${invalid.runtimeType}',
        );
      }
    });
  }

  test('child options preserve valid strings and accept null or absent optional fields', () {
    for (final fields in <Map<String, Object?>>[
      {},
      {'internal_id': null, 'child_context_id': null, 'institution_id': null, 'unit_id': null},
      {
        'internal_id': 'RA 1',
        'child_context_id': 'context-1',
        'institution_id': 'institution-1',
        'unit_id': 'unit-1',
      },
    ]) {
      final option = decodeChildSafetyOptions([
        {
          'id': 'child-1',
          'display_name': 'Ana',
          ...fields,
          'contexts': [fields],
        },
      ]).single;
      expect(option.internalId, fields['internal_id']);
      expect(option.childContextId, fields['child_context_id']);
      expect(option.institutionId, fields['institution_id']);
      expect(option.unitId, fields['unit_id']);
    }
  });

  test('child records preserve valid strings and accept null or absent context fields', () {
    for (final fields in <Map<String, Object?>>[
      {},
      {'internal_id': null, 'child_context_id': null, 'institution_id': null, 'unit_id': null},
      {
        'internal_id': 'RA 1',
        'child_context_id': 'context-1',
        'institution_id': 'institution-1',
        'unit_id': 'unit-1',
      },
    ]) {
      final record = decodeChildSafetyRecord({
        'child_id': 'child-1',
        'child_name': 'Ana',
        'contexts': [fields],
      });
      expect(record.internalId, fields['internal_id'] ?? '');
      expect(record.childContextId, fields['child_context_id']);
      expect(record.institutionId, fields['institution_id']);
      expect(record.unitId, fields['unit_id']);
    }
  });

  test('decodes the exclusive directory counts and child identity', () {
    final page = decodeChildSafetyDirectory({
      'items': [
        {
          'child_id': '11111111-1111-4111-8111-111111111111',
          'child_name': 'Ana',
          'internal_id': 'RA 1',
          'institution_name': 'Aurora',
          'unit_name': 'Centro',
        },
      ],
      'total_count': 4,
      'segment_counts': {
        'all': 4,
        'awaiting_approval': 1,
        'attention': 1,
        'authorized': 1,
        'without_authorization': 1,
      },
      'can_create': true,
      'next_cursor': 'opaque',
    });

    expect(page.records.single.childName, 'Ana');
    expect(page.segmentCounts[ChildSafetyDirectorySegment.attention], 1);
    expect(page.nextCursor, 'opaque');
  });

  test('decodes decision and lifecycle as separate statuses', () {
    final record = decodeChildSafetyRecord({
      'child_id': '11111111-1111-4111-8111-111111111111',
      'child_name': 'Ana',
      'contexts': [
        {'internal_id': 'RA 1', 'institution_name': 'Aurora', 'unit_name': 'Centro'},
      ],
      'authorizations': [
        {
          'id': '22222222-2222-4222-8222-222222222222',
          'name': 'Maria',
          'relationship_code': 'mother',
          'decision_status': 'approved',
          'lifecycle_status': 'suspended',
          'valid_from': '2026-08-12T12:00:00Z',
        },
      ],
    });

    expect(record.authorizations.single.status, PickupAuthorizationStatus.approved);
    expect(
      record.authorizations.single.lifecycleStatus,
      PickupAuthorizationLifecycleStatus.suspended,
    );
  });

  test('directory preserves the authoritative exclusive segment and counts', () {
    final page = decodeChildSafetyDirectory({
      'items': [
        {
          'child_id': 'child-1',
          'child_context_id': 'context-1',
          'child_name': 'Ana',
          'institution_id': 'institution-1',
          'institution_name': 'Aurora',
          'unit_id': 'unit-1',
          'unit_name': 'Centro',
          'authorization_count': 2,
          'segment': 'authorized',
        },
      ],
      'total_count': 1,
      'segment_counts': {'all': 1, 'authorized': 1},
      'can_create': true,
    });

    expect(page.records.single.directorySegment, ChildSafetyDirectorySegment.authorized);
    expect(page.records.single.authorizationCount, 2);
    expect(page.records.single.childContextId, 'context-1');
  });

  test('detail keeps each authorization in its own institution and unit context', () {
    final record = decodeChildSafetyRecord({
      'child_id': 'child-1',
      'child_name': 'Ana',
      'contexts': [
        {
          'child_context_id': 'context-a',
          'institution_id': 'institution-a',
          'institution_name': 'Aurora',
          'unit_id': 'unit-a',
          'unit_name': 'Centro',
        },
        {
          'child_context_id': 'context-b',
          'institution_id': 'institution-b',
          'institution_name': 'Horizonte',
          'unit_id': 'unit-b',
          'unit_name': 'Sul',
        },
      ],
      'authorizations': [
        {
          'id': 'authorization-b',
          'child_context_id': 'context-b',
          'unit_id': 'unit-b',
          'person_id': 'person-b',
          'name': 'Maria',
          'relationship_code': 'mother',
          'capability_codes': ['pickup'],
          'decision_status': 'approved',
          'lifecycle_status': 'archived',
          'request_reason': 'Autorização solicitada pela família',
        },
      ],
    });

    final authorization = record.authorizations.single;
    expect(authorization.institutionName, 'Horizonte');
    expect(authorization.unitName, 'Sul');
    expect(authorization.lifecycleStatus, PickupAuthorizationLifecycleStatus.revoked);
    expect(authorization.personId, 'person-b');
    expect(authorization.capabilityCodes, {'pickup'});
  });
}
