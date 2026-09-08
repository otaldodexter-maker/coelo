import 'dart:convert';

import 'package:coelo_superadmin/features/agenda/data/supabase_agenda_read_repository.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_read_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('list uses only nominal RPC and keeps partial audience and explicit context', () async {
    final requests = <Request>[];
    final reader = _reader(_page(), requests: requests);
    final page = await reader.fetchEvents(
      from: DateTime.utc(2026, 9, 8),
      to: DateTime.utc(2026, 9, 9),
      institutionId: _id(10),
      search: ' %_ ',
      limit: 1,
      offset: 2,
    );
    expect(requests.single.url.pathSegments.last, 'superadmin_agenda_list_v2');
    expect(jsonDecode(requests.single.body), {
      'p_from': '2026-09-08T00:00:00.000Z',
      'p_to': '2026-09-09T00:00:00.000Z',
      'p_institution_id': _id(10),
      'p_search': ' %_ ',
      'p_limit': 1,
      'p_offset': 2,
    });
    expect(page.total, 3);
    expect(page.offset, 2);
    expect(page.correlationId, _id(999));
    final item = page.items.single;
    expect(item.contextId, _id(12));
    expect(item.contextKind, AgendaContextLevel.unit);
    expect(item.audience.unitIds, {_id(11)});
    expect(item.audience.individualDetailsAvailable, isFalse);
    expect(item.history, isNull);
    expect(() => item.audience.unitIds.add(_id(20)), throwsUnsupportedError);
    expect(() => page.items.clear(), throwsUnsupportedError);
  });

  test('detail parses canonical recurrence and history without a legacy RPC', () async {
    final requests = <Request>[];
    final item = _item()..['history'] = <Object?>[];
    item['recurrence'] = {
      'frequency': 'weekly',
      'interval': 2,
      'until': '2026-09-12T10:30:00+00:00',
      'exceptions': ['2026-09-10T09:00:00+00:00'],
    };
    final result = await _reader(_success({'item': item}), requests: requests).fetchEvent(_id(701));
    expect(requests.single.url.pathSegments.last, 'superadmin_agenda_get_v2');
    expect(jsonDecode(requests.single.body), {'p_event_id': _id(701)});
    expect(result.item.history, isEmpty);
    expect(result.item.recurrence!.until, DateTime.utc(2026, 9, 12, 10, 30));
    expect(result.item.recurrence!.exceptions, {DateTime.utc(2026, 9, 10, 9)});
  });

  test('preserves empty reminder strings accepted by the canonical projection', () async {
    final result = await _reader(
      _success({
        'item': {
          ..._item(),
          'history': <Object?>[],
          'reminders': ['', 'oneDayBefore'],
        },
      }),
      requests: [],
    ).fetchEvent(_id(701));
    expect(result.item.reminders, {'', 'oneDayBefore'});
  });

  test('parses projected history without requiring absent historical revisions', () async {
    final result = await _reader(
      _success({
        'item': {
          ..._item(),
          'history': [
            {
              'action': 'create',
              'occurred_at': '2026-09-07T10:00:00Z',
              'reason': null,
              'previous_revision': null,
              'next_revision': 1,
            },
          ],
        },
      }),
      requests: [],
    ).fetchEvent(_id(701));
    expect(result.item.history!.single.previousRevision, isNull);
    expect(result.item.history!.single.nextRevision, 1);
    expect(() => result.item.history!.clear(), throwsUnsupportedError);
  });

  test('contexts keep real capabilities separate from unavailable mutations', () async {
    final requests = <Request>[];
    final result = await _reader(_contexts(), requests: requests).fetchContexts();
    expect(requests.single.url.pathSegments.last, 'superadmin_agenda_contexts_v2');
    expect(result.mutationActionsAvailable, isFalse);
    expect(result.contexts.single.granted, {AgendaCapability.createAgendaItems});
    expect(
      result.contexts.single.restricted,
      AgendaCapability.values.toSet()..remove(AgendaCapability.createAgendaItems),
    );
  });

  for (final entry in {
    'SAI_AUTH_REQUIRED': (401, AgendaReadFailure.unauthorized),
    'SAI_SESSION_INVALID': (401, AgendaReadFailure.unauthorized),
    'SAI_PERMISSION_DENIED': (403, AgendaReadFailure.unauthorized),
    'SAI_MEMBERSHIP_REVOKED': (403, AgendaReadFailure.unauthorized),
    'SAI_MEMBERSHIP_SUSPENDED': (403, AgendaReadFailure.unauthorized),
    'AGENDA_NOT_FOUND': (404, AgendaReadFailure.notFound),
    'AGENDA_INVALID_ARGUMENT': (400, AgendaReadFailure.invalidArgument),
    'SAI_INTERNAL_ERROR': (500, AgendaReadFailure.unavailable),
  }.entries) {
    test('HTTP200 denial ${entry.key} returns no partial result or fallback', () async {
      final requests = <Request>[];
      final reader = _reader({
        'ok': false,
        'data': null,
        'error': {
          'code': entry.key,
          'http_status': entry.value.$1,
          'message': 'PRIVATE SQL SENTINEL',
          'correlation_id': _id(999),
        },
      }, requests: requests);
      await expectLater(
        reader.fetchEvent(_id(701)),
        throwsA(
          isA<AgendaReadException>()
              .having((error) => error.failure, 'failure', entry.value.$2)
              .having((error) => error.code, 'code', entry.key)
              .having((error) => error.correlationId, 'correlation', _id(999)),
        ),
      );
      expect(requests, hasLength(1));
    });
  }

  final malformed = <String, Object?>{
    'raw legacy result': {'item': _item()},
    'success with error': {
      'ok': true,
      'data': {'item': _item()},
      'error': {'code': 'bad'},
    },
    'denial with data': {
      'ok': false,
      'data': {'item': _item()},
      'error': null,
    },
    'missing correlation': {
      'ok': true,
      'data': {'item': _item()},
      'error': null,
    },
    'unknown item field': _success({
      'item': {..._item(), 'history': <Object?>[], 'created_by_person_id': _id(601)},
    }),
    'wrong resource': _success({
      'item': {..._item(), 'history': <Object?>[], 'id': _id(702)},
    }),
    'missing history on detail': _success({'item': _item()}),
    'personal data in partial audience': _success({
      'item': {
        ..._item(),
        'history': <Object?>[],
        'audience': {...(_item()['audience'] as Map), 'personIds': <String>[]},
      },
    }),
    'partial flag missing': _success({
      'item': {
        ..._item(),
        'history': <Object?>[],
        'audience': Map<String, Object?>.from(_item()['audience'] as Map)
          ..remove('individual_details_available'),
      },
    }),
    'partial flag falsely complete': _success({
      'item': {
        ..._item(),
        'history': <Object?>[],
        'audience': {...(_item()['audience'] as Map), 'individual_details_available': true},
      },
    }),
    'audience institution mismatch': _success({
      'item': {
        ..._item(),
        'history': <Object?>[],
        'audience': {...(_item()['audience'] as Map), 'institutionId': _id(20)},
      },
    }),
    'invalid dates': _success({
      'item': {..._item(), 'history': <Object?>[], 'ends_at': 'not-a-date'},
    }),
  };
  for (final entry in malformed.entries) {
    test('rejects malformed read: ${entry.key}', () async {
      final requests = <Request>[];
      await expectLater(
        _reader(entry.value, requests: requests).fetchEvent(_id(701)),
        throwsA(
          isA<AgendaReadException>().having(
            (e) => e.failure,
            'failure',
            AgendaReadFailure.unavailable,
          ),
        ),
      );
      expect(requests, hasLength(1));
    });
  }

  for (final entry in <String, Map<String, Object?>>{
    'wrong limit echo': {'limit': 2},
    'wrong offset echo': {'offset': 0},
    'insufficient total': {'total_items': 2},
    'unknown page field': {'next_page': 'private'},
    'noninteger total': {'total_items': 3.5},
    'wrong institution filter': {
      'items': [
        {..._item(), 'institution_id': _id(20)},
      ],
    },
  }.entries) {
    test('rejects malformed page: ${entry.key}', () async {
      final response = _page();
      (response['data'] as Map).addAll(entry.value);
      final requests = <Request>[];
      await expectLater(
        _reader(response, requests: requests).fetchEvents(
          from: DateTime.utc(2026, 9, 8),
          to: DateTime.utc(2026, 9, 9),
          institutionId: _id(10),
          limit: 1,
          offset: 2,
        ),
        throwsA(isA<AgendaReadException>()),
      );
      expect(requests, hasLength(1));
    });
  }

  for (final entry in <String, Map<String, Object?>>{
    'missing parent': {'id': _id(11), 'level': 'unit', 'parent_id': _id(10)},
    'root institution mismatch': {'institution_id': _id(20)},
    'root with parent': {'parent_id': _id(11)},
    'unknown capability': {
      'granted_capabilities': ['privateCapability'],
    },
    'duplicate capability': {
      'granted_capabilities': ['createAgendaItems', 'createAgendaItems'],
    },
    'overlapping capabilities': {
      'granted_capabilities': ['createAgendaItems', 'editOwnAgendaItems'],
    },
    'incomplete capabilities': {'restricted_capabilities': <String>[]},
    'unknown context field': {
      'people': [_id(601)],
    },
  }.entries) {
    test('rejects malformed context: ${entry.key}', () async {
      final response = _contexts();
      final data = response['data'] as Map;
      ((data['contexts'] as List).single as Map).addAll(entry.value);
      await expectLater(
        _reader(response, requests: []).fetchContexts(),
        throwsA(isA<AgendaReadException>()),
      );
    });
  }

  test('read contexts cannot announce available mutations', () async {
    final response = _contexts();
    (response['data'] as Map)['mutation_actions_available'] = true;
    await expectLater(
      _reader(response, requests: []).fetchContexts(),
      throwsA(isA<AgendaReadException>()),
    );
  });

  for (final entry in <String, Object?>{
    'unknown recurrence field': {'frequency': 'daily', 'occurrenceCount': 3, 'personId': _id(601)},
    'both recurrence endings': {
      'frequency': 'daily',
      'occurrenceCount': 3,
      'until': '2026-09-12T00:00:00Z',
    },
    'no recurrence ending': {'frequency': 'daily'},
    'nonpositive interval': {'frequency': 'daily', 'interval': 0, 'occurrenceCount': 3},
  }.entries) {
    test('rejects malformed recurrence: ${entry.key}', () async {
      await expectLater(
        _reader(
          _success({
            'item': {..._item(), 'history': <Object?>[], 'recurrence': entry.value},
          }),
          requests: [],
        ).fetchEvent(_id(701)),
        throwsA(isA<AgendaReadException>()),
      );
    });
  }

  for (final code in ['42501', 'PGRST301', 'PGRST302', 'P0001']) {
    test('PostgREST $code is mapped safely without fallback', () async {
      final requests = <Request>[];
      await expectLater(
        _reader(
          {'code': code, 'message': 'PRIVATE SQL SENTINEL', 'details': null, 'hint': null},
          requests: requests,
          status: 403,
        ).fetchContexts(),
        throwsA(
          isA<AgendaReadException>()
              .having(
                (e) => e.failure,
                'failure',
                code == 'P0001' ? AgendaReadFailure.unavailable : AgendaReadFailure.unauthorized,
              )
              .having((e) => e.toString().contains('PRIVATE'), 'no raw message', isFalse),
        ),
      );
      expect(requests, hasLength(1));
    });
  }

  test('transport failure is safe and never retries a legacy reader', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://agenda.invalid',
      'test-key',
      httpClient: MockClient((request) async {
        calls++;
        throw ClientException('PRIVATE TRANSPORT');
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseAgendaReadRepository(client).fetchContexts(),
      throwsA(
        isA<AgendaReadException>().having(
          (e) => e.failure,
          'failure',
          AgendaReadFailure.unavailable,
        ),
      ),
    );
    expect(calls, 1);
  });
}

SupabaseAgendaReadRepository _reader(
  Object? response, {
  required List<Request> requests,
  int status = 200,
}) {
  final client = SupabaseClient(
    'https://agenda.invalid',
    'test-key',
    httpClient: MockClient((request) async {
      requests.add(request);
      return Response(
        jsonEncode(response),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  addTearDown(client.dispose);
  return SupabaseAgendaReadRepository(client);
}

String _id(int n) => '8a500000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
Map<String, Object?> _success(Map<String, Object?> data) => {
  'ok': true,
  'data': {...data, 'correlation_id': _id(999)},
  'error': null,
};
Map<String, Object?> _page() => _success({
  'items': [_item()],
  'total_items': 3,
  'limit': 1,
  'offset': 2,
});
Map<String, Object?> _contexts() => _success({
  'mutation_actions_available': false,
  'contexts': [
    {
      'id': _id(10),
      'name': 'Instituição A',
      'institution_id': _id(10),
      'parent_id': null,
      'level': 'institution',
      'granted_capabilities': ['createAgendaItems'],
      'restricted_capabilities': AgendaCapability.values.skip(1).map((e) => e.name).toList(),
    },
  ],
});
Map<String, Object?> _item() => {
  'id': _id(701),
  'institution_id': _id(10),
  'context_kind': 'unit',
  'context_id': _id(12),
  'title': 'Evento sintético',
  'item_type': 'event',
  'priority': 'normal',
  'status': 'published',
  'origin': 'institution',
  'starts_at': '2026-09-08T12:00:00Z',
  'ends_at': '2026-09-08T13:00:00Z',
  'all_day': false,
  'time_zone_id': 'America/Sao_Paulo',
  'location': 'Sala A',
  'description': 'Descrição',
  'response_mode': 'none',
  'guardian_response_policy': 'oneIsEnough',
  'recurrence': null,
  'audience': {
    'institutionId': _id(10),
    'unitIds': [_id(11)],
    'groupIds': <String>[],
    'activityIds': <String>[],
    'individual_details_available': false,
  },
  'reminders': <String>[],
  'questions': <Object?>[],
  'revision': 1,
};
