import 'dart:convert';

import 'package:coelo_superadmin/features/audit/data/supabase_audit_repository.dart';
import 'package:coelo_superadmin/features/audit/domain/audit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final actor in <Map<String, Object?>>[
    {'kind': 'person', 'id': 'person', 'display_name': 'Ator', 'role_code': null},
    {'kind': 'superadmin_internal', 'id': 'internal', 'display_name': 'Ator', 'role_code': null},
    {
      'kind': 'auth_session',
      'id': null,
      'display_name': 'Sessão autenticada',
      'role_code': 'owner',
    },
    {
      'kind': 'auth_session',
      'id': 'raw-session',
      'display_name': 'Sessão autenticada',
      'role_code': null,
    },
  ]) {
    test('rejects inconsistent actor projection $actor', () async {
      final repository = SupabaseAuditRepository(
        _client(
          (request) async => Response(
            jsonEncode({..._sessionEvent(), 'actor': actor}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      await expectLater(
        repository.fetchDetail('event-session'),
        throwsA(isA<AuditUnavailableException>()),
      );
    });
  }

  for (final detail in [false, true]) {
    test('reads minimized auth-session event with null role detail=$detail', () async {
      final repository = SupabaseAuditRepository(
        _client(
          (request) async => Response(
            jsonEncode(
              detail
                  ? _sessionEvent()
                  : {
                      'items': [_sessionEvent()],
                      'has_more': false,
                      'next_cursor': null,
                      'total_count': 1,
                      'can_export': false,
                    },
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      final event = detail
          ? (await repository.fetchDetail('event-session')).event
          : (await repository.fetchPage(AuditQuery())).events.single;
      expect(event.actor.id, isNull);
      expect(event.actor.roleCode, isNull);
      expect(event.actor.displayName, 'Sessão autenticada');
    });
  }

  test('fetchPage sends cursor and filters to the authorised list RPC', () async {
    late Map<String, Object?> body;
    late Uri requestUrl;
    final repository = SupabaseAuditRepository(
      _client((request) async {
        requestUrl = request.url;
        body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
        return Response(
          jsonEncode({
            'items': [
              {
                'id': '11111111-1111-1111-1111-111111111111',
                'actor': {'id': null, 'display_name': 'Sistema', 'role_code': 'system'},
                'institution': {
                  'id': '33333333-3333-3333-3333-333333333333',
                  'name': 'Instituição protegida',
                },
                'action_code': 'institution.updated',
                'object_type': null,
                'object_id': null,
                'outcome': 'success',
                'correlation_id': '44444444-4444-4444-4444-444444444444',
                'origin': 'admin_ui',
                'context': {'kind': 'global', 'id': null},
                'occurred_at': '2026-08-11T12:00:00Z',
              },
            ],
            'has_more': true,
            'can_export': true,
            'next_cursor': {
              'occurred_at': '2026-08-11T12:00:00Z',
              'event_id': '11111111-1111-1111-1111-111111111111',
            },
            'total_count': 1,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    final page = await repository.fetchPage(
      AuditQuery(
        search: '  instituição  ',
        actorIds: const {'22222222-2222-2222-2222-222222222222'},
        contextKinds: const {'global'},
        actionCodes: const {'institution.updated'},
        resourceTypes: const {'institution'},
        outcomes: const {AuditOutcome.success},
        origins: const {'admin_ui'},
        institutionId: '33333333-3333-3333-3333-333333333333',
        from: DateTime.utc(2026, 8, 1),
        to: DateTime.utc(2026, 8, 12),
        cursor: AuditCursor(
          occurredAt: DateTime.utc(2026, 8, 10),
          eventId: '55555555-5555-5555-5555-555555555555',
        ),
        pageSize: 20,
      ),
    );

    expect(requestUrl.path, endsWith('/rpc/audit_list_events_for_superadmin'));
    expect(body, {
      'p_search': 'instituição',
      'p_actor_ids': ['22222222-2222-2222-2222-222222222222'],
      'p_context_kinds': ['global'],
      'p_action_codes': ['institution.updated'],
      'p_resource_types': ['institution'],
      'p_outcomes': ['success'],
      'p_origins': ['admin_ui'],
      'p_institution_id': '33333333-3333-3333-3333-333333333333',
      'p_from': '2026-08-01T00:00:00.000Z',
      'p_to': '2026-08-12T00:00:00.000Z',
      'p_cursor_occurred_at': '2026-08-10T00:00:00.000Z',
      'p_cursor_id': '55555555-5555-5555-5555-555555555555',
      'p_limit': 20,
    });
    expect(page.events.single.id, '11111111-1111-1111-1111-111111111111');
    expect(page.events.single.actor.id, isNull);
    expect(page.events.single.actor.displayName, 'Sistema');
    expect(page.events.single.resourceType, isNull);
    expect(page.events.single.resourceId, isNull);
    expect(page.nextCursor?.eventId, '11111111-1111-1111-1111-111111111111');
    expect(page.hasMore, isTrue);
    expect(page.canExport, isTrue);
    expect(page.totalCount, 1);
  });

  test('fetchDetail maps minimized detail and never reconstructs missing data', () async {
    late Request capturedRequest;
    final repository = SupabaseAuditRepository(
      _client((request) async {
        capturedRequest = request;
        return Response(
          jsonEncode({
            'id': '11111111-1111-1111-1111-111111111111',
            'actor': {
              'id': '22222222-2222-2222-2222-222222222222',
              'display_name': 'Operador protegido',
              'role_code': 'owner',
            },
            'institution': null,
            'action_code': 'profile.updated',
            'object_type': 'profile',
            'object_id': '55555555-5555-5555-5555-555555555555',
            'outcome': 'success',
            'occurred_at': '2026-08-11T12:00:00Z',
            'correlation_id': null,
            'origin': 'admin_ui',
            'context': {'kind': 'global', 'id': null},
            'before': {'status': 'active'},
            'after': {'status': 'inactive'},
            'reason': 'Revisão autorizada',
            'integrity': {
              'position': 8,
              'previous_hash': 'previous',
              'hash': 'current',
              'verified': true,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    final detail = await repository.fetchDetail('11111111-1111-1111-1111-111111111111');

    expect(capturedRequest.url.path, endsWith('/rpc/audit_get_event_for_superadmin'));
    expect(jsonDecode(capturedRequest.body), {
      'p_event_id': '11111111-1111-1111-1111-111111111111',
    });
    expect(detail.event.actor.roleCode, 'owner');
    expect(detail.before, {'status': 'active'});
    expect(detail.integrity.verified, isTrue);
  });

  test('fetchDetail rejects a response for a different event id', () async {
    final repository = SupabaseAuditRepository(
      _client(
        (request) async => Response(
          jsonEncode(_sessionEvent()),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );

    await expectLater(
      repository.fetchDetail('event-requested'),
      throwsA(isA<AuditValidationException>()),
    );
  });

  test('productive repository keeps general exports deferred without Edge calls', () async {
    var requestCount = 0;
    final repository = SupabaseAuditRepository(
      _client((request) async {
        requestCount += 1;
        return Response(
          jsonEncode({'unexpected': true}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    for (final format in AuditExportFormat.values) {
      await expectLater(
        repository.startExport(
          AuditExportRequest(
            idempotencyKey: '66666666-6666-4666-8666-666666666666',
            format: format,
            query: AuditQuery(
              search: 'perfil',
              cursor: AuditCursor(
                occurredAt: DateTime.utc(2026, 8, 10),
                eventId: '55555555-5555-5555-5555-555555555555',
              ),
            ),
          ),
        ),
        throwsA(isA<AuditUnavailableException>()),
      );
    }
    await expectLater(
      repository.fetchExportStatus('77777777-7777-7777-7777-777777777777'),
      throwsA(isA<AuditUnavailableException>()),
    );
    expect(requestCount, 0);
  });

  test('maps authorization, not-found and malformed payloads to safe errors', () async {
    Future<Response> forbidden(Request request) async => Response(
      jsonEncode({
        'code': '42501',
        'message': 'internal policy detail',
        'details': null,
        'hint': null,
      }),
      403,
      headers: {'content-type': 'application/json'},
      request: request,
    );
    Future<Response> missing(Request request) async => Response(
      jsonEncode({'code': 'P0002', 'message': 'hidden resource', 'details': null, 'hint': null}),
      404,
      headers: {'content-type': 'application/json'},
      request: request,
    );
    Future<Response> malformed(Request request) async => Response(
      jsonEncode({'items': 'not-a-list'}),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );

    await expectLater(
      SupabaseAuditRepository(_client(forbidden)).fetchPage(AuditQuery()),
      throwsA(isA<AuditUnauthorizedException>()),
    );
    await expectLater(
      SupabaseAuditRepository(_client(missing)).fetchDetail('11111111-1111-1111-1111-111111111111'),
      throwsA(isA<AuditNotFoundException>()),
    );
    await expectLater(
      SupabaseAuditRepository(_client(malformed)).fetchPage(AuditQuery()),
      throwsA(isA<AuditUnavailableException>()),
    );
  });

  test('uses the exact export states and unavailable repository fails closed', () async {
    expect(AuditExportStatus.fromDatabase('PENDENTE'), AuditExportStatus.queued);
    expect(AuditExportStatus.fromDatabase('PROCESSANDO'), AuditExportStatus.processing);
    expect(AuditExportStatus.fromDatabase('SUCESSO'), AuditExportStatus.completed);
    expect(AuditExportStatus.fromDatabase('ERRO'), AuditExportStatus.failed);
    expect(() => AuditExportStatus.fromDatabase('queued'), throwsFormatException);

    const repository = UnavailableAuditRepository();
    await expectLater(
      repository.fetchPage(AuditQuery()),
      throwsA(isA<AuditUnavailableException>()),
    );
    await expectLater(repository.fetchDetail('event-1'), throwsA(isA<AuditUnavailableException>()));
    await expectLater(
      repository.startExport(
        AuditExportRequest(
          idempotencyKey: '88888888-8888-4888-8888-888888888888',
          format: AuditExportFormat.csv,
          query: AuditQuery(),
        ),
      ),
      throwsA(isA<AuditUnavailableException>()),
    );
    await expectLater(
      repository.fetchExportStatus('job-1'),
      throwsA(isA<AuditUnavailableException>()),
    );
  });
}

Map<String, Object?> _sessionEvent() => {
  'id': 'event-session',
  'actor': {
    'kind': 'auth_session',
    'id': null,
    'display_name': 'Sessão autenticada',
    'role_code': null,
  },
  'institution': null,
  'action_code': 'auth.bootstrap',
  'object_type': null,
  'object_id': null,
  'outcome': 'denied',
  'correlation_id': 'correlation-session',
  'origin': 'admin_ui',
  'context': {'kind': 'platform', 'id': null},
  'occurred_at': '2026-09-07T23:00:00Z',
  'before': null,
  'after': null,
  'reason': 'SAI_INTERNAL_ACTOR_REQUIRED',
  'integrity': {
    'version': 3,
    'position': 1,
    'previous_hash': null,
    'hash': 'entry',
    'verified': true,
  },
};

SupabaseClient _client(Future<Response> Function(Request request) handler) => SupabaseClient(
  'https://project.supabase.co',
  'sb_publishable_test',
  httpClient: MockClient((request) => handler(request)),
);
