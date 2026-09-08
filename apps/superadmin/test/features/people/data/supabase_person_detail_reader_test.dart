import 'dart:convert';
import 'package:coelo_superadmin/features/people/data/supabase_person_detail_reader.dart';
import 'package:coelo_superadmin/features/people/domain/person_detail_reader.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _id = '10000000-0000-4000-8000-000000000001';
void main() {
  test('reader delegates only detail v2 and preserves strict denial', () async {
    final requests = <Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return Response(
          jsonEncode({
            'ok': false,
            'data': null,
            'error': {
              'code': 'SAI_PERMISSION_DENIED',
              'message': 'Restricted',
              'correlation_id': 'synthetic-correlation',
              'http_status': 403,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final PersonDetailReader reader = SupabasePersonDetailReader(client);
    await expectLater(
      reader.fetchDetail(_id),
      throwsA(isA<PersonDirectoryUnauthorizedException>()),
    );
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/rest/v1/rpc/superadmin_person_detail_v2');
    expect(jsonDecode(requests.single.body), {'p_person_id': _id});
    expect(reader, isNot(isA<PersonDirectoryRepository>()));
  });

  test('invalid id never reaches transport', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        calls++;
        return Response('{}', 200);
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabasePersonDetailReader(client).fetchDetail('invalid'),
      throwsA(isA<PersonDirectoryUnauthorizedException>()),
    );
    expect(calls, 0);
  });
}
