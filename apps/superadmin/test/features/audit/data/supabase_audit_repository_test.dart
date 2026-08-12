import 'dart:convert';

import 'package:coelo_superadmin/features/audit/data/supabase_audit_repository.dart';
import 'package:coelo_superadmin/features/audit/domain/audit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
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

  test('startExport sends the same server-side query and idempotency id', () async {
    late Request capturedRequest;
    final repository = SupabaseAuditRepository(
      _client((request) async {
        capturedRequest = request;
        return Response(
          jsonEncode({
            'job_id': '77777777-7777-7777-7777-777777777777',
            'state': 'SUCESSO',
            'format': 'csv',
            'row_count': 8,
            'download_url': 'https://private.example.test/generated',
            'expires_in': 300,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    final job = await repository.startExport(
      AuditExportRequest(
        idempotencyKey: '66666666-6666-6666-6666-666666666666',
        format: AuditExportFormat.csv,
        query: AuditQuery(
          search: 'perfil',
          cursor: AuditCursor(
            occurredAt: DateTime.utc(2026, 8, 10),
            eventId: '55555555-5555-5555-5555-555555555555',
          ),
        ),
      ),
    );

    expect(capturedRequest.url.path, endsWith('/functions/v1/audit-export'));
    final body = Map<String, Object?>.from(jsonDecode(capturedRequest.body) as Map);
    expect(body['action'], 'generate');
    expect(body['idempotency_key'], '66666666-6666-6666-6666-666666666666');
    expect(body['format'], 'csv');
    expect(body['filters'], {'search': 'perfil'});
    expect(job.id, '77777777-7777-7777-7777-777777777777');
    expect(job.status, AuditExportStatus.completed);
    expect(job.rowCount, 8);
    expect(job.downloadExpiresInSeconds, 300);
  });

  test('fetchExportStatus maps safe progress and a temporary HTTPS download', () async {
    late Request capturedRequest;
    final repository = SupabaseAuditRepository(
      _client((request) async {
        capturedRequest = request;
        return Response(
          jsonEncode({
            'job_id': '77777777-7777-7777-7777-777777777777',
            'state': 'SUCESSO',
            'format': 'xlsx',
            'created_at': '2026-08-11T12:00:00Z',
            'summary': {
              'phase': 'complete',
              'row_count': 42,
              'retention_expires_at': '2026-08-12T12:00:00Z',
            },
            'download_url': 'https://private.example.test/signed',
            'expires_in': 300,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    final job = await repository.fetchExportStatus('77777777-7777-7777-7777-777777777777');

    expect(capturedRequest.url.path, endsWith('/functions/v1/audit-export'));
    expect(jsonDecode(capturedRequest.body), {
      'action': 'status',
      'job_id': '77777777-7777-7777-7777-777777777777',
    });
    expect(job.status, AuditExportStatus.completed);
    expect(job.phase, 'complete');
    expect(job.rowCount, 42);
    expect(job.downloadUrl, Uri.https('private.example.test', '/signed'));
    expect(job.downloadExpiresInSeconds, 300);
  });

  test('rejects non-HTTPS export download URLs', () async {
    final repository = SupabaseAuditRepository(
      _client(
        (request) async => Response(
          jsonEncode({
            'job_id': '77777777-7777-7777-7777-777777777777',
            'state': 'SUCESSO',
            'format': 'csv',
            'created_at': '2026-08-11T12:00:00Z',
            'summary': {'phase': 'complete', 'row_count': 1, 'retention_expires_at': null},
            'download_url': 'javascript:alert(1)',
            'expires_in': 300,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );

    await expectLater(
      repository.fetchExportStatus('77777777-7777-7777-7777-777777777777'),
      throwsA(isA<AuditUnavailableException>()),
    );
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

SupabaseClient _client(Future<Response> Function(Request request) handler) => SupabaseClient(
  'https://project.supabase.co',
  'sb_publishable_test',
  httpClient: MockClient((request) => handler(request)),
);
