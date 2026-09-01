import 'dart:convert';

import 'package:coelo_superadmin/features/principal_shared/data/supabase_principal_runtime_context_repository.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('default unavailable repository fails closed', () {
    expect(
      const UnavailablePrincipalRuntimeContextRepository().listAvailableContexts,
      throwsA(isA<PrincipalRuntimeContextUnavailable>()),
    );
  });

  test('loads only contexts derived by the authenticated-actor RPC', () async {
    late http.Request capturedRequest;
    final client = _client((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode([
          {
            'membership_id': 'membership-1',
            'person_id': 'person-1',
            'institution_id': 'institution-1',
            'institution_name': 'Colégio Coelo',
            'role_code': 'guardian',
            'scope_kind': 'group',
            'unit_id': 'unit-1',
            'unit_name': 'Unidade Centro',
            'group_id': 'group-1',
            'group_name': '3º ano A',
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    addTearDown(client.dispose);

    final contexts = await SupabasePrincipalRuntimeContextRepository(
      client,
    ).listAvailableContexts();

    expect(capturedRequest.url.path, '/rest/v1/rpc/list_my_principal_contexts');
    expect(jsonDecode(capturedRequest.body), isNull);
    expect(contexts, hasLength(1));
    expect(contexts.single.membershipId, 'membership-1');
    expect(contexts.single.institutionName, 'Colégio Coelo');
    expect(contexts.single.unitName, 'Unidade Centro');
    expect(contexts.single.groupName, '3º ano A');
  });

  test('maps authorization failures to a stable domain error', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode({'code': '42501', 'message': 'principal_context_denied'}),
        403,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);

    expect(
      SupabasePrincipalRuntimeContextRepository(client).listAvailableContexts,
      throwsA(isA<PrincipalRuntimeContextUnauthorized>()),
    );
  });

  test('fails closed when the backend projection is malformed', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode([
          {'membership_id': 'membership-1'},
        ]),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);

    expect(
      SupabasePrincipalRuntimeContextRepository(client).listAvailableContexts,
      throwsA(isA<PrincipalRuntimeContextUnavailable>()),
    );
  });
}

SupabaseClient _client(Future<http.Response> Function(http.Request request) handler) =>
    SupabaseClient('https://coelo.test', 'publishable-key', httpClient: MockClient(handler));
