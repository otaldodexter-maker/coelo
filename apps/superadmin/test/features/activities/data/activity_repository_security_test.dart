import 'dart:convert';

import 'package:coelo_superadmin/features/activities/data/supabase_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('binds untrusted activity search as one RPC parameter', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({'items': <Object?>[], 'total_count': 0}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    await SupabaseActivityDirectoryRepository(
      client,
    ).fetchPage(ActivityDirectoryQuery(search: r'a,b.c\d'));

    expect(captured!.url.path, endsWith('/rpc/superadmin_activity_directory'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_search'], r'a,b.c\d');
    expect(captured!.url.queryParameters, isEmpty);
  });

  test('binds an untrusted activity id to the authorized detail RPC', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          'null',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    await SupabaseActivityDirectoryRepository(client).fetchById('tenant-a,tenant-b.eq.anything');

    expect(captured!.url.path, endsWith('/rpc/superadmin_activity_detail'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_activity_id'], 'tenant-a,tenant-b.eq.anything');
  });

  test('maps expired-session PostgREST failures to unauthorized', () async {
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
      SupabaseActivityDirectoryRepository(client).fetchById('activity-1'),
      throwsA(isA<ActivityDirectoryUnauthorizedException>()),
    );
  });

  test('loads form options without querying people or private activity links', () async {
    final tables = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        tables.add(request.url.pathSegments.last);
        return Response(
          jsonEncode({
            'institutions': <Object?>[],
            'units': <Object?>[],
            'locations': <Object?>[],
            'groups': <Object?>[],
            'professionals': <Object?>[],
            'taxonomy': <Object?>[],
            'templates': <Object?>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final options = await SupabaseActivityDirectoryRepository(
      client,
    ).fetchFormOptions(institutionId: 'institution-1');

    expect(tables, ['superadmin_get_activity_form_options']);
    expect(options.locations, isEmpty);
    expect(options.groups, isEmpty);
    expect(options.professionals, isEmpty);
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
