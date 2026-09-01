import 'dart:convert';

import 'package:coelo_superadmin/features/agenda/data/supabase_agenda_repository.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('lista eventos pelo RPC e substitui o cache no reload real', () async {
    final captured = <Request>[];
    var call = 0;
    final client = _client((request) async {
      captured.add(request);
      call++;
      return _json(request, {
        'items': [_eventJson(id: call == 1 ? _eventId : _secondEventId, revision: call)],
        'total_items': 1,
      });
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);

    await repository.loadEvents(
      from: DateTime.utc(2026, 9),
      to: DateTime.utc(2026, 10),
      institutionId: _institutionId,
      search: 'reunião',
    );

    expect(captured.single.url.path, endsWith('/rpc/superadmin_agenda_list'));
    final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
    expect(body['p_from'], '2026-09-01T00:00:00.000Z');
    expect(body['p_to'], '2026-10-01T00:00:00.000Z');
    expect(body['p_institution_id'], _institutionId);
    expect(body['p_search'], 'reunião');
    expect(body['p_limit'], 200);
    expect(repository.items.single.id, _eventId);
    expect(repository.items.single.revision, 1);
    expect(repository.items.single.type, AgendaItemType.event);

    await repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));

    expect(repository.items, hasLength(1));
    expect(repository.items.single.id, _secondEventId);
    expect(repository.items.single.revision, 2);
  });

  test('cria evento sem IDs de fixture e conserva a identidade gerada pelo servidor', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json(request, _eventJson(id: _eventId, revision: 1));
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client, requestId: () => _requestId);
    final item = AgendaItem.fixture(
      id: 'local-agenda-1',
      title: 'Reunião pedagógica',
      audience: const AgendaAudience(institutionId: _institutionId, unitIds: {_unitId}),
      startsAt: DateTime.utc(2026, 9, 3, 13),
      endsAt: DateTime.utc(2026, 9, 3, 14),
      status: AgendaItemStatus.draft,
      reminders: const {'30 minutos antes'},
      questions: const [
        AgendaQuestion(
          id: 'confirmacao',
          title: 'Poderá participar?',
          type: AgendaQuestionType.yesNo,
        ),
      ],
    );

    final result = await repository.saveItem(item, actorContextId: _unitId);

    expect(result, AgendaMutationResult.success);
    expect(captured!.url.path, endsWith('/rpc/superadmin_agenda_save'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_request_id'], _requestId);
    expect(body['p_event_id'], isNull);
    expect(body['p_expected_revision'], isNull);
    final payload = body['p_payload'] as Map<String, dynamic>;
    expect(payload['institutionId'], _institutionId);
    expect(payload['contextKind'], 'unit');
    expect(payload['contextId'], _unitId);
    expect(payload['origin'], 'institution');
    expect(jsonEncode(payload), isNot(contains('local-agenda-1')));
    expect(repository.lastSavedItemId, _eventId);
    expect(repository.items.single.id, _eventId);
  });

  test('comando envia revisão otimista e atualiza o cache com a resposta remota', () async {
    final captured = <Request>[];
    final client = _client((request) async {
      captured.add(request);
      if (request.url.path.endsWith('/rpc/superadmin_agenda_list')) {
        return _json(request, {
          'items': [_eventJson(id: _eventId, revision: 7)],
          'total_items': 1,
        });
      }
      return _json(request, {
        'request_id': _requestId,
        'event': _eventJson(id: _eventId, revision: 8, status: 'canceled'),
      });
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client, requestId: () => _requestId);
    await repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));

    final result = await repository.cancelItem(_eventId, actorName: 'Owner Coelo');

    expect(result, AgendaMutationResult.success);
    final body = jsonDecode(captured.last.body) as Map<String, dynamic>;
    expect(body['p_request_id'], _requestId);
    expect(body['p_event_id'], _eventId);
    expect(body['p_expected_revision'], 7);
    expect(body['p_action'], 'cancel');
    expect(repository.itemById(_eventId)!.revision, 8);
    expect(repository.itemById(_eventId)!.status, AgendaItemStatus.canceled);
  });

  test('carrega solicitações reais dos dois tipos sem inserir fixtures', () async {
    final kinds = <String>[];
    final client = _client((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final kind = body['p_kind'] as String;
      kinds.add(kind);
      if (kind == 'publication') {
        return _json(request, [
          {
            'id': _publicationRequestId,
            'event_id': _eventId,
            'institution_id': _institutionId,
            'requested_by_person_id': _personId,
            'requested_at': '2026-09-03T10:00:00Z',
            'status': 'pending',
          },
        ]);
      }
      return _json(request, [
        {
          'id': _guardianRequestId,
          'institution_id': _institutionId,
          'context_id': _unitId,
          'child_person_id': _childId,
          'guardian_person_id': _personId,
          'title': 'Aniversário da criança',
          'starts_at': '2026-09-08T15:00:00Z',
          'ends_at': '2026-09-08T16:00:00Z',
          'status': 'sent',
          'details': 'Solicitação enviada pela família',
          'decided_at': null,
          'linked_event_id': null,
        },
      ]);
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);

    await repository.loadRequests();

    expect(kinds, containsAll(<String>['publication', 'guardian']));
    expect(repository.publicationRequests.single.id, _publicationRequestId);
    expect(repository.requests.single.id, _guardianRequestId);
    expect(repository.requests.single.title, 'Aniversário da criança');
    expect(repository.requests.map((request) => request.id), isNot(contains(contains('fixture'))));
  });

  test('falha fechada para escopo de recorrência não suportado pelo backend', () async {
    final client = _client((request) async => _json(request, const {}));
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);

    expect(repository.supportsOccurrenceScopedEdits, isFalse);
    expect(
      await repository.recordOccurrenceEdit(
        itemId: _eventId,
        occurrenceStartsAt: DateTime.utc(2026, 9, 3, 13),
        scope: AgendaOccurrenceEditScope.occurrence,
        actorName: 'Owner Coelo',
      ),
      AgendaMutationResult.unavailable,
    );
  });
}

SupabaseClient _client(Future<Response> Function(Request request) handler) => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient(handler),
);

Response _json(Request request, Object value) => Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);

Map<String, Object?> _eventJson({
  required String id,
  required int revision,
  String status = 'draft',
}) => {
  'id': id,
  'institution_id': _institutionId,
  'context_kind': 'unit',
  'context_id': _unitId,
  'title': 'Reunião pedagógica',
  'item_type': 'event',
  'priority': 'important',
  'status': status,
  'origin': 'institution',
  'starts_at': '2026-09-03T13:00:00Z',
  'ends_at': '2026-09-03T14:00:00Z',
  'all_day': false,
  'time_zone_id': 'America/Sao_Paulo',
  'location': 'Sala multiuso',
  'description': 'Alinhamento mensal',
  'response_mode': 'none',
  'guardian_response_policy': 'oneIsEnough',
  'recurrence': null,
  'audience': {
    'institutionId': _institutionId,
    'unitIds': [_unitId],
    'groupIds': <String>[],
    'activityIds': <String>[],
    'personIds': <String>[],
  },
  'reminders': ['30 minutos antes'],
  'questions': <Object?>[],
  'history': <Object?>[],
  'revision': revision,
};

const _institutionId = '10000000-0000-4000-8000-000000000001';
const _unitId = '20000000-0000-4000-8000-000000000001';
const _eventId = '30000000-0000-4000-8000-000000000001';
const _secondEventId = '30000000-0000-4000-8000-000000000002';
const _requestId = '40000000-0000-4000-8000-000000000001';
const _publicationRequestId = '50000000-0000-4000-8000-000000000001';
const _guardianRequestId = '60000000-0000-4000-8000-000000000001';
const _personId = '70000000-0000-4000-8000-000000000001';
const _childId = '80000000-0000-4000-8000-000000000001';
