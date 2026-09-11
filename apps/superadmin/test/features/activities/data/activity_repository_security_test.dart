import 'dart:convert';

import 'package:coelo_superadmin/features/activities/data/supabase_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('untrusted activity values never reach a non-equivalent legacy RPC', () async {
    final requests = <Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return Response('{}', 200, request: request);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseActivityDirectoryRepository(client);

    await expectLater(
      repository.fetchPage(ActivityDirectoryQuery(search: r'a,b.c\d')),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
    await expectLater(
      repository.fetchById('tenant-a,tenant-b.eq.anything'),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
    await expectLater(
      repository.fetchFormOptions(institutionId: 'tenant-a,tenant-b.eq.anything'),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
    await expectLater(
      repository.searchProfessionals(
        institutionId: 'tenant-a,tenant-b.eq.anything',
        query: r'a,b.c\d',
      ),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );

    // Somente as RPCs v2 nominais sao chamadas. Os valores nao confiaveis
    // viajam no corpo JSON, nunca na URL ou na query, e uma resposta sem
    // envelope v2 vira indisponibilidade.
    expect(requests, hasLength(4));
    expect(requests.map((request) => request.url.path), [
      '/rest/v1/rpc/superadmin_activity_directory_v2',
      '/rest/v1/rpc/superadmin_activity_detail_v2',
      '/rest/v1/rpc/superadmin_activity_form_options_v2',
      '/rest/v1/rpc/superadmin_activity_form_options_v2',
    ]);
    expect(requests.map((request) => request.url.query), everyElement(isEmpty));
    expect((jsonDecode(requests[0].body) as Map)['p_filters']['search'], r'a,b.c\d');
    expect((jsonDecode(requests[1].body) as Map)['p_activity_id'], 'tenant-a,tenant-b.eq.anything');
    expect(
      (jsonDecode(requests[2].body) as Map)['p_institution_id'],
      'tenant-a,tenant-b.eq.anything',
    );
    final search = jsonDecode(requests[3].body) as Map;
    expect(search['p_institution_id'], 'tenant-a,tenant-b.eq.anything');
    expect(search['p_search'], r'a,b.c\d');
  });

  test('maps expired session on the internal template gateway to unauthorized', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          '{"code":"PGRST301","message":"JWT expired","details":null,"hint":null}',
          401,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseActivityDirectoryRepository(client).fetchTemplateOptions(),
      throwsA(isA<ActivityDirectoryUnauthorizedException>()),
    );
  });

  test('unavailable repository fails closed for every activity read', () async {
    const repository = UnavailableActivityDirectoryRepository();

    await expectLater(
      repository.fetchPage(ActivityDirectoryQuery()),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
    await expectLater(
      repository.fetchFilterOptions(),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
    await expectLater(
      repository.fetchFormOptions(institutionId: 'institution-1'),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
    await expectLater(
      repository.fetchById('activity-1'),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
  });
}
