import 'dart:async';
import 'dart:convert';

import 'package:coelo_superadmin/features/agenda/data/supabase_agenda_repository.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('estados de leitura isolam calendário de falha em solicitações', () async {
    final client = _client(
      (request) async => request.url.path.endsWith('superadmin_agenda_list')
          ? _json(request, {
              'items': [_eventJson(id: _eventId, revision: 1)],
            })
          : _json(request, 'invalid'),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    expect(repository.eventsRead, AgendaReadStatus.idle);
    expect(repository.requestsRead, AgendaReadStatus.idle);
    await repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));
    await repository.loadRequests();
    expect(repository.eventsRead, AgendaReadStatus.ready);
    expect(repository.requestsRead, AgendaReadStatus.failure);
    expect(repository.contextsRead, AgendaReadStatus.idle);
  });

  test('detalhes simultâneos mantêm estados independentes', () async {
    final delayed = Completer<Response>();
    Request? pending;
    final client = _client((request) async {
      final id = (jsonDecode(request.body) as Map<String, dynamic>)['p_event_id'] as String;
      if (id == _eventId) {
        pending = request;
        return delayed.future;
      }
      return _json(request, _eventJson(id: id, revision: 1));
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    final first = repository.loadItem(_eventId);
    await repository.loadItem(_secondEventId);
    expect(repository.itemRead(_eventId), AgendaReadStatus.loading);
    expect(repository.itemRead(_secondEventId), AgendaReadStatus.ready);
    delayed.complete(_json(pending!, _eventJson(id: _eventId, revision: 1)));
    await first;
    expect(repository.itemRead(_eventId), AgendaReadStatus.ready);
  });

  test('detalhe não encontrado mantém estado final após invalidar leituras', () async {
    final client = _client(
      (request) async => Response(
        '{"code":"P0002","message":"not found"}',
        404,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    await repository.loadItem(_eventId);
    expect(repository.itemRead(_eventId), AgendaReadStatus.notFound);
    expect(repository.isLoading, isFalse);
  });

  test('negação marca canais conhecidos e futuros; retry libera somente seu canal', () async {
    var deny = true;
    final client = _client(
      (request) async => deny ? _denied(request) : _json(request, {'contexts': <Object?>[]}),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    await repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));
    expect(repository.eventsRead, AgendaReadStatus.unauthorized);
    expect(repository.contextsRead, AgendaReadStatus.unauthorized);
    expect(repository.requestsRead, AgendaReadStatus.unauthorized);
    expect(repository.itemRead(_eventId), AgendaReadStatus.unauthorized);
    deny = false;
    await repository.loadContexts();
    expect(repository.contextsRead, AgendaReadStatus.ready);
    expect(repository.eventsRead, AgendaReadStatus.unauthorized);
    expect(repository.itemRead(_eventId), AgendaReadStatus.unauthorized);
  });

  test('recorrência preserva intervalo explícito, término e timezone das exceções', () async {
    final client = _client(
      (request) async => _json(request, {
        'items': [
          {
            ..._eventJson(id: _eventId, revision: 1),
            'recurrence': {
              'frequency': 'weekly',
              'interval': 2,
              'until': '2026-11-30T23:00:00Z',
              'occurrenceCount': null,
              'exceptions': ['2026-09-17T00:00:00Z'],
            },
          },
        ],
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    await repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 12));
    expect(repository.errorMessage, isNull);
    final recurrence = repository.items.single.recurrence!;
    expect(recurrence.interval, 2);
    expect(recurrence.until!.toUtc(), DateTime.utc(2026, 11, 30, 23));
    expect(recurrence.exceptions.single, DateTime.utc(2026, 9, 17));
    expect(recurrence.exceptions.single.isUtc, isTrue);
  });

  for (final frequency in AgendaRecurrenceFrequency.values) {
    test(
      'recorrência válida preserva frequência, quantidade e default: ${frequency.name}',
      () async {
        final client = _client(
          (request) async => _json(request, {
            'items': [
              {
                ..._eventJson(id: _eventId, revision: 1),
                'recurrence': {
                  'frequency': frequency.name,
                  'occurrenceCount': 3,
                  'until': null,
                  'exceptions': <String>[],
                },
              },
            ],
          }),
        );
        addTearDown(client.dispose);
        final repository = SupabaseAgendaRepository(client);
        await repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2027, 3));
        expect(repository.errorMessage, isNull);
        expect(repository.items.single.recurrence!.interval, 1);
        expect(repository.items.single.recurrence!.frequency, frequency);
        expect(
          repository.occurrencesBetween(DateTime.utc(2026, 9), DateTime.utc(2027, 3)),
          hasLength(3),
        );
      },
    );
  }

  for (final invalid in <String, Map<String, Object?>>{
    'interval zero': {'frequency': 'daily', 'interval': 0, 'occurrenceCount': 3},
    'interval negative': {'frequency': 'daily', 'interval': -1, 'occurrenceCount': 3},
    'interval text': {'frequency': 'daily', 'interval': 'invalid', 'occurrenceCount': 3},
    'interval numeric string': {'frequency': 'daily', 'interval': '2', 'occurrenceCount': 3},
    'count zero': {'frequency': 'daily', 'interval': 1, 'occurrenceCount': 0},
    'count negative': {'frequency': 'daily', 'interval': 1, 'occurrenceCount': -2},
    'invalid until and count': {'frequency': 'daily', 'until': 'invalid', 'occurrenceCount': 3},
    'exceptions object': {'frequency': 'daily', 'occurrenceCount': 3, 'exceptions': {}},
  }.entries) {
    test('recorrência inválida preserva snapshot sem expansão: ${invalid.key}', () async {
      var corrupt = false;
      final client = _client(
        (request) async => _json(request, {
          'items': [
            {
              ..._eventJson(id: _eventId, revision: corrupt ? 2 : 1),
              if (corrupt) 'recurrence': invalid.value,
            },
          ],
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseAgendaRepository(client);
      await repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));
      corrupt = true;
      // Do not expand an invalid recurrence: debug asserts/release loops are the bug.
      await repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));
      expect(repository.errorMessage, 'A Agenda retornou dados inválidos.');
      expect(repository.items.single.revision, 1);
      expect(repository.isLoading, isFalse);
    });
  }

  test('comando malformado preserva leitura pendente e suas notificações', () async {
    var delayedRead = false;
    final delayed = Completer<Response>();
    Request? pending;
    final client = _client((request) async {
      if (request.url.path.endsWith('superadmin_agenda_command')) {
        return _json(request, <String, Object?>{});
      }
      if (delayedRead) {
        pending = request;
        return delayed.future;
      }
      return _json(request, {
        'items': [_eventJson(id: _eventId, revision: 1)],
      });
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    await repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));
    delayedRead = true;
    var notifications = 0;
    repository.addListener(() => notifications++);
    final loading = repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));
    expect(await repository.deleteDraft(_eventId), AgendaMutationResult.unavailable);
    expect(repository.isLoading, isTrue);
    final notificationsBeforeReply = notifications;
    delayed.complete(
      _json(pending!, {
        'items': [_eventJson(id: _eventId, revision: 2)],
      }),
    );
    await loading;
    expect(repository.items.single.revision, 2);
    expect(repository.isLoading, isFalse);
    expect(notifications, greaterThan(notificationsBeforeReply));
  });

  test('resposta de escrita anterior à revogação não repopula o cache', () async {
    final delayed = Completer<Response>();
    Request? pending;
    final client = _client((request) async {
      if (request.url.path.endsWith('superadmin_agenda_save')) {
        pending = request;
        return delayed.future;
      }
      return _denied(request);
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    final saving = repository.saveItem(
      AgendaItem.fixture(
        id: 'local',
        title: 'Evento',
        audience: const AgendaAudience(institutionId: _institutionId),
        startsAt: DateTime.utc(2026, 9, 3),
        endsAt: DateTime.utc(2026, 9, 4),
      ),
      actorContextId: _institutionId,
    );
    await repository.loadContexts();
    delayed.complete(_json(pending!, _eventJson(id: _eventId, revision: 1)));
    expect(await saving, AgendaMutationResult.notAuthorized);
    expect(repository.items, isEmpty);
    expect(repository.lastSavedItemId, isNull);
  });

  test('negação obsoleta do mesmo canal não apaga leitura autorizada mais recente', () async {
    final delayed = Completer<Response>();
    Request? pending;
    var calls = 0;
    final client = _client((request) async {
      if (++calls == 1) {
        pending = request;
        return delayed.future;
      }
      return _json(request, {
        'items': [_eventJson(id: _eventId, revision: 2)],
      });
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    final old = repository.loadEvents(from: DateTime.utc(2026, 8), to: DateTime.utc(2026, 9));
    await repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));
    delayed.complete(_denied(pending!));
    await old;
    expect(repository.items.single.revision, 2);
    expect(repository.errorMessage, isNull);
  });

  test('solicitações aplicam ambas as coleções somente após validar as duas', () async {
    var corrupt = false;
    final client = _client((request) async {
      final kind = (jsonDecode(request.body) as Map<String, dynamic>)['p_kind'];
      if (kind == 'guardian') return _json(request, corrupt ? 'invalid' : <Object?>[]);
      return _json(request, [
        {
          'id': _publicationRequestId,
          'event_id': _eventId,
          'institution_id': _institutionId,
          'requested_at': '2026-09-03T10:00:00Z',
          'status': corrupt ? 'approved' : 'pending',
        },
      ]);
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    await repository.loadRequests();
    corrupt = true;
    await repository.loadRequests();
    expect(repository.publicationRequests.single.status, AgendaPublicationRequestStatus.pending);
    expect(repository.requests, isEmpty);
    expect(repository.errorMessage, 'A Agenda retornou dados inválidos.');
  });

  test('leitura anterior ao comando não ressuscita evento excluído', () async {
    var delayedRead = false;
    final delayed = Completer<Response>();
    Request? pending;
    final client = _client((request) async {
      if (request.url.path.endsWith('superadmin_agenda_command')) {
        return _json(request, {'deleted': true});
      }
      if (delayedRead) {
        pending = request;
        return delayed.future;
      }
      return _json(request, {
        'items': [_eventJson(id: _eventId, revision: 1)],
      });
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    await repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));
    delayedRead = true;
    final loading = repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));
    expect(repository.eventsRead, AgendaReadStatus.loading);
    expect(await repository.deleteDraft(_eventId), AgendaMutationResult.success);
    expect(repository.eventsRead, AgendaReadStatus.idle);
    expect(repository.itemRead(_eventId), AgendaReadStatus.notFound);
    delayed.complete(
      _json(pending!, {
        'items': [_eventJson(id: _eventId, revision: 1)],
      }),
    );
    await loading;
    expect(repository.items, isEmpty);
    expect(repository.isLoading, isFalse);
    expect(repository.eventsRead, AgendaReadStatus.idle);
    expect(repository.itemRead(_eventId), AgendaReadStatus.notFound);
  });

  test('detalhe não revelável remove a cópia previamente autorizada', () async {
    var deny = false;
    final client = _client(
      (request) async => deny
          ? Response(
              '{"code":"P0002","message":"not found"}',
              404,
              headers: {'content-type': 'application/json'},
              request: request,
            )
          : _json(request, _eventJson(id: _eventId, revision: 1)),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    await repository.loadItem(_eventId);
    expect(repository.itemById(_eventId), isNotNull);
    deny = true;
    await repository.loadItem(_eventId);
    expect(repository.itemById(_eventId), isNull);
  });

  test('resposta antiga não substitui o período mais recente nem seu erro', () async {
    final requests = <Request>[];
    final replies = [Completer<Response>(), Completer<Response>()];
    final client = _client((request) {
      requests.add(request);
      return replies[requests.length - 1].future;
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    final first = repository.loadEvents(from: DateTime.utc(2026, 8), to: DateTime.utc(2026, 9));
    final second = repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));
    await Future<void>.delayed(Duration.zero);
    replies[1].complete(
      _json(requests[1], {
        'items': [_eventJson(id: _secondEventId, revision: 2)],
      }),
    );
    await second;
    expect(repository.isLoading, isFalse);
    replies[0].complete(
      _json(requests[0], {
        'items': [_eventJson(id: _eventId, revision: 1)],
      }),
    );
    await first;
    expect(repository.items.single.id, _secondEventId);
    expect(repository.errorMessage, isNull);
  });

  test('negação limpa dados e capacidades e invalida outra leitura em trânsito', () async {
    var deny = false;
    final delayed = Completer<Response>();
    Request? pending;
    final client = _client((request) async {
      if (!deny) {
        return _json(request, {
          'items': [_eventJson(id: _eventId, revision: 1)],
        });
      }
      if (request.url.path.endsWith('superadmin_agenda_get')) {
        pending = request;
        return delayed.future;
      }
      return _denied(request);
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(
      client,
      contexts: [
        const AgendaContext(
          id: _institutionId,
          name: 'Contexto sintético',
          level: AgendaContextLevel.institution,
          institutionId: _institutionId,
          grantedCapabilities: {AgendaCapability.createAgendaItems},
        ),
      ],
    );
    await repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));
    deny = true;
    final detail = repository.loadItem(_eventId);
    await repository.loadContexts();
    expect(repository.items, isEmpty);
    expect(repository.contexts, isEmpty);
    expect(repository.errorMessage, contains('permissão'));
    delayed.complete(_json(pending!, _eventJson(id: _eventId, revision: 2)));
    await detail;
    expect(repository.items, isEmpty);
    expect(repository.errorMessage, contains('permissão'));
  });

  test('erro de transporte preserva snapshot, mas payload inválido não vira lista vazia', () async {
    var phase = 0;
    final client = _client((request) async {
      if (phase == 0) {
        return _json(request, {
          'items': [_eventJson(id: _eventId, revision: 1)],
        });
      }
      if (phase == 1) {
        return Response(
          '{"code":"XX000","message":"untrusted"}',
          500,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      return _json(request, {'items': 'invalid'});
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    Future<void> reload() =>
        repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));
    await reload();
    phase = 1;
    await reload();
    expect(repository.items.single.id, _eventId);
    expect(repository.errorMessage, 'Não foi possível carregar a Agenda.');
    phase = 2;
    await reload();
    expect(repository.items.single.id, _eventId);
    expect(repository.errorMessage, 'A Agenda retornou dados inválidos.');
  });

  test('leituras independentes mantêm loading até ambas terminarem', () async {
    final delayed = Completer<Response>();
    Request? pending;
    final client = _client((request) async {
      if (request.url.path.endsWith('superadmin_agenda_contexts')) {
        pending = request;
        return delayed.future;
      }
      return _json(request, {'items': <Object?>[]});
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    final contexts = repository.loadContexts();
    await repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));
    expect(repository.isLoading, isTrue);
    delayed.complete(_json(pending!, {'contexts': <Object?>[]}));
    await contexts;
    expect(repository.isLoading, isFalse);
  });

  test('dispose durante leitura não notifica nem repopula o repository', () async {
    final delayed = Completer<Response>();
    Request? pending;
    final client = _client((request) {
      pending = request;
      return delayed.future;
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    final loading = repository.loadEvents(from: DateTime.utc(2026, 9), to: DateTime.utc(2026, 10));
    await Future<void>.delayed(Duration.zero);
    repository.dispose();
    delayed.complete(
      _json(pending!, {
        'items': [_eventJson(id: _eventId, revision: 1)],
      }),
    );
    await loading;
    expect(repository.items, isEmpty);
  });

  test('negação de comando remove evento e último ID salvo do cache', () async {
    var deny = false;
    final client = _client(
      (request) async =>
          deny ? _denied(request) : _json(request, _eventJson(id: _eventId, revision: 1)),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);
    await repository.saveItem(
      AgendaItem.fixture(
        id: 'local-agenda',
        title: 'Evento',
        audience: const AgendaAudience(institutionId: _institutionId),
        startsAt: DateTime.utc(2026, 9, 3),
        endsAt: DateTime.utc(2026, 9, 4),
      ),
      actorContextId: _institutionId,
    );
    expect(repository.lastSavedItemId, _eventId);
    deny = true;
    expect(
      await repository.cancelItem(_eventId, actorName: 'Ator'),
      AgendaMutationResult.notAuthorized,
    );
    expect(repository.items, isEmpty);
    expect(repository.lastSavedItemId, isNull);
  });

  test('carrega apenas contextos devolvidos pelo gateway autorizado', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json(request, {
        'contexts': [
          {
            'id': _institutionId,
            'name': 'Colégio Horizonte',
            'level': 'institution',
            'institution_id': _institutionId,
            'parent_id': null,
            'granted_capabilities': ['createAgendaItems', 'publishAgendaItems'],
            'restricted_capabilities': <String>[],
          },
          {
            'id': _unitId,
            'name': 'Unidade Centro',
            'level': 'unit',
            'institution_id': _institutionId,
            'parent_id': _institutionId,
            'granted_capabilities': ['createAgendaItems'],
            'restricted_capabilities': <String>[],
          },
        ],
      });
    });
    addTearDown(client.dispose);
    final repository = SupabaseAgendaRepository(client);

    await repository.loadContexts();

    expect(captured!.url.path, endsWith('/rpc/superadmin_agenda_contexts'));
    expect(repository.contexts, hasLength(2));
    expect(repository.contexts.last.level, AgendaContextLevel.unit);
    expect(repository.contexts.last.parentId, _institutionId);
    expect(
      repository.contexts.first.grantedCapabilities,
      containsAll(<AgendaCapability>[
        AgendaCapability.createAgendaItems,
        AgendaCapability.publishAgendaItems,
      ]),
    );
  });

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

Response _denied(Request request) => Response(
  '{"code":"42501","message":"untrusted"}',
  403,
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
