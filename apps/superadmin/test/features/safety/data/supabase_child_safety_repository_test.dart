import 'dart:convert';

import 'package:coelo_superadmin/features/safety/data/supabase_child_safety_repository.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final operation in ['read', 'command']) {
    test('$operation normalizes a transport failure as unavailable', () async {
      final client = _client((_) async => throw ClientException('Connection interrupted'));
      addTearDown(client.dispose);
      final repository = SupabaseChildSafetyRepository(client);

      await expectLater(
        operation == 'read'
            ? repository.fetchChild('child-1')
            : repository.saveAuthorization(_command()),
        throwsA(isA<ChildSafetyUnavailableException>()),
      );
    });
  }

  for (final code in ['42501', '40001', '23505']) {
    test('transport boundary preserves database error $code', () async {
      final client = _client(
        (request) async => Response(
          jsonEncode({'code': code, 'message': 'Denied or changed'}),
          code == '42501' ? 403 : 409,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      );
      addTearDown(client.dispose);
      final repository = SupabaseChildSafetyRepository(client);

      await expectLater(
        repository.fetchChild('child-1'),
        throwsA(
          code == '42501'
              ? isA<ChildSafetyUnauthorizedException>()
              : isA<ChildSafetyConflictException>(),
        ),
      );
    });
  }

  test('create sends the mandatory audited request reason', () async {
    late Request captured;
    final client = _client((request) async {
      captured = request;
      return _ok(request);
    });
    addTearDown(client.dispose);
    final repository = SupabaseChildSafetyRepository(client);

    await repository.saveAuthorization(_command());

    expect(captured.url.pathSegments.last, 'child_safety_request_authorization');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect((body['p_payload'] as Map<String, dynamic>)['request_reason'], 'Solicitação familiar');
  });

  test('edit uses optimistic version and the dedicated pending RPC', () async {
    late Request captured;
    final client = _client((request) async {
      captured = request;
      return _ok(request);
    });
    addTearDown(client.dispose);
    final repository = SupabaseChildSafetyRepository(client);

    await repository.saveAuthorization(
      _command(authorizationId: 'authorization-1', expectedVersion: 7),
    );

    expect(captured.url.pathSegments.last, 'child_safety_edit_pending_authorization');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['p_authorization_id'], 'authorization-1');
    expect(body['p_expected_version'], 7);
  });

  test('suspension maps to the suspended database lifecycle', () async {
    late Request captured;
    final client = _client((request) async {
      captured = request;
      return _ok(request);
    });
    addTearDown(client.dispose);
    final repository = SupabaseChildSafetyRepository(client);

    await repository.suspendAuthorization(
      const SuspendPickupAuthorizationCommand(
        requestId: 'request-1',
        childId: 'child-1',
        authorizationId: 'authorization-1',
        reason: 'Documento precisa ser revisto',
        expectedVersion: 4,
      ),
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['p_lifecycle_status'], 'suspended');
    expect(body, isNot(contains('p_lifecycle')));
  });

  test('export creates an audited server job with the active filters', () async {
    late Request captured;
    final client = _client((request) async {
      captured = request;
      return _ok(request);
    });
    addTearDown(client.dispose);
    final repository = SupabaseChildSafetyRepository(client);

    await repository.requestExport(
      const ChildSafetyExportCommand(requestId: 'request-1', filters: {'segment': 'attention'}),
    );

    expect(captured.url.pathSegments.last, 'superadmin_request_child_safety_export');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['p_format'], 'csv');
    expect(body['p_filters'], {'segment': 'attention'});
  });
}

SavePickupAuthorizationCommand _command({String? authorizationId, int expectedVersion = 1}) =>
    SavePickupAuthorizationCommand(
      requestId: 'request-1',
      childId: 'child-1',
      childContextId: 'context-1',
      unitId: 'unit-1',
      personId: 'person-1',
      authorizationId: authorizationId,
      expectedVersion: expectedVersion,
      relationshipCode: 'mother',
      capabilityCodes: const {'pickup'},
      requestReason: 'Solicitação familiar',
    );

SupabaseClient _client(Future<Response> Function(Request) handler) => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient(handler),
);

Response _ok(Request request) =>
    Response('{}', 200, request: request, headers: {'content-type': 'application/json'});
