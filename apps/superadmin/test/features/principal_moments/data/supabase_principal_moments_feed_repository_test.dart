import 'dart:convert';

import 'package:coelo_superadmin/features/principal_moments/data/supabase_principal_moments_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _scope = PrincipalMomentsFeedScope(
  institutionId: 'institution-1',
  unitId: 'unit-1',
  groupId: 'group-1',
);

void main() {
  test('projeta apenas o contrato do feed e resolve mídia sem expor storage', () async {
    final rpcBodies = <String, Map<String, dynamic>>{};
    final edgeBodies = <Map<String, dynamic>>[];
    final client = _client((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (request.url.path.contains('/functions/v1/moments-media')) {
        edgeBodies.add(body);
        return _json({
          'signed_url': 'https://signed.example/${body['asset_id']}',
          'mime_type': 'video/mp4',
          'expires_in': 120,
        }, request);
      }
      rpcBodies[request.url.pathSegments.last] = body;
      return _json([
        {
          'publication_id': 'publication-1',
          'author_name': 'Equipe Coelo',
          'author_initials': 'EC',
          'context_label': '3º ano A',
          'caption': 'Registro autorizado.',
          'published_at': DateTime.now().toUtc().toIso8601String(),
          'can_withdraw': true,
          'media': [
            {'asset_id': 'asset-2', 'mime_type': 'video/mp4', 'display_order': 1},
            {'asset_id': 'asset-1', 'mime_type': 'image/jpeg', 'display_order': 0},
          ],
          'object_key': 'institution-1/publication-1/secret',
          'bucket_id': 'coelo-moments-private',
        },
      ], request);
    });
    addTearDown(client.dispose);

    final moments = await SupabasePrincipalMomentsFeedRepository(
      client,
    ).listVisibleMoments(_scope);

    expect(rpcBodies['list_visible_moments'], {
      'p_institution_id': 'institution-1',
      'p_unit_id': 'unit-1',
      'p_group_id': 'group-1',
      'p_limit': 20,
      'p_cursor': null,
    });
    final moment = moments.single;
    expect(moment.publicationId, 'publication-1');
    expect(moment.canWithdraw, isTrue);
    expect(moment.caption, 'Registro autorizado.');
    expect(moment.resolvedInitials, 'EC');
    expect(moment.media.map((item) => item.displayOrder), [0, 1]);
    expect(moment.media.map((item) => item.signedUrl), [
      'https://signed.example/asset-1',
      'https://signed.example/asset-2',
    ]);
    // O identificador opaco do módulo é o único dado enviado à Edge Function.
    expect(edgeBodies.map((body) => body.keys.toSet()), everyElement({'action', 'asset_id'}));
    final projected = [
      moment.author,
      moment.context,
      moment.caption,
      moment.time,
      ...moment.media.map((item) => '${item.signedUrl}${item.mimeType}'),
    ].join('|');
    expect(projected, isNot(contains('coelo-moments-private')));
    expect(projected, isNot(contains('institution-1/publication-1/secret')));
  });

  test('nega o feed quando a RPC recusa a autorização', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode({'message': 'moments_permission_denied', 'code': '42501'}),
        403,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabasePrincipalMomentsFeedRepository(client).listVisibleMoments(_scope),
      throwsA(isA<PrincipalMomentsFeedUnauthorized>()),
    );
  });

  test('trata falha da RPC como indisponibilidade, sem cair para dados demo', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode({'message': 'boom', 'code': 'XX000'}),
        500,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabasePrincipalMomentsFeedRepository(client).listVisibleMoments(_scope),
      throwsA(isA<PrincipalMomentsFeedUnavailable>()),
    );
  });

  for (final entry in {403: 'unauthorized', 500: 'unavailable'}.entries) {
    test('falha fechado quando a Edge de mídia responde ${entry.key}', () async {
      final client = _client((request) async {
        if (request.url.path.contains('/functions/v1/moments-media')) {
          return http.Response(
            jsonEncode({'error': 'media_read_denied'}),
            entry.key,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return _json([
          {
            'publication_id': 'publication-1',
            'author_name': 'Equipe Coelo',
            'author_initials': 'EC',
            'context_label': '3º ano A',
            'caption': 'Registro autorizado.',
            'published_at': DateTime.now().toUtc().toIso8601String(),
            'can_withdraw': false,
            'media': [
              {'asset_id': 'asset-1', 'mime_type': 'image/jpeg', 'display_order': 0},
            ],
          },
        ], request);
      });
      addTearDown(client.dispose);

      await expectLater(
        SupabasePrincipalMomentsFeedRepository(client).listVisibleMoments(_scope),
        throwsA(
          entry.value == 'unauthorized'
              ? isA<PrincipalMomentsFeedUnauthorized>()
              : isA<PrincipalMomentsFeedUnavailable>(),
        ),
      );
    });
  }

  test('retira a publicação por RPC com identificador de requisição próprio', () async {
    final calls = <Map<String, dynamic>>[];
    final client = _client((request) async {
      calls.add(jsonDecode(request.body) as Map<String, dynamic>);
      return _json({
        'id': 'publication-1',
        'status': 'published',
        'withdrawn_at': '2026-09-09T13:00:00Z',
        'version': 3,
      }, request);
    });
    addTearDown(client.dispose);

    await SupabasePrincipalMomentsFeedRepository(client).withdrawMoment('publication-1');

    expect(calls, hasLength(1));
    expect(calls.single['p_publication_id'], 'publication-1');
    expect(calls.single['p_request_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
  });

  test('repetir a mesma retirada reapresenta a mesma chave de idempotência', () async {
    final calls = <Map<String, dynamic>>[];
    var failNext = true;
    final client = _client((request) async {
      calls.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (failNext) {
        failNext = false;
        return http.Response('{"message":"boom"}', 500);
      }
      return _json({
        'id': 'publication-1',
        'status': 'published',
        'withdrawn_at': '2026-09-09T13:00:00Z',
        'version': 3,
      }, request);
    });
    addTearDown(client.dispose);
    final repository = SupabasePrincipalMomentsFeedRepository(client);

    await expectLater(
      repository.withdrawMoment('publication-1'),
      throwsA(isA<PrincipalMomentsWithdrawalFailure>()),
    );
    await repository.withdrawMoment('publication-1');

    expect(calls, hasLength(2));
    expect(
      calls.first['p_request_id'],
      calls.last['p_request_id'],
      reason: 'a segunda tentativa e a MESMA intencao e precisa reapresentar a chave',
    );
  });

  test('retiradas de publicações diferentes usam chaves diferentes', () async {
    final calls = <Map<String, dynamic>>[];
    final client = _client((request) async {
      calls.add(jsonDecode(request.body) as Map<String, dynamic>);
      return _json({
        'id': 'publication',
        'status': 'published',
        'withdrawn_at': '2026-09-09T13:00:00Z',
        'version': 3,
      }, request);
    });
    addTearDown(client.dispose);
    final repository = SupabasePrincipalMomentsFeedRepository(client);

    await repository.withdrawMoment('publication-1');
    await repository.withdrawMoment('publication-2');

    expect(calls, hasLength(2));
    expect(calls.first['p_request_id'], isNot(calls.last['p_request_id']));
  });

  test('mapeia negação e falha da retirada sem sucesso falso', () async {
    final denied = _client(
      (request) async => http.Response(
        jsonEncode({'message': 'moments_permission_denied', 'code': '42501'}),
        403,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(denied.dispose);
    final broken = _client(
      (request) async => http.Response(
        jsonEncode({'message': 'boom', 'code': 'XX000'}),
        500,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(broken.dispose);

    await expectLater(
      SupabasePrincipalMomentsFeedRepository(denied).withdrawMoment('publication-1'),
      throwsA(isA<PrincipalMomentsWithdrawalDenied>()),
    );
    await expectLater(
      SupabasePrincipalMomentsFeedRepository(broken).withdrawMoment('publication-1'),
      throwsA(isA<PrincipalMomentsWithdrawalUnavailable>()),
    );
  });
}

SupabaseClient _client(Future<http.Response> Function(http.Request request) handler) =>
    SupabaseClient('https://coelo.test', 'publishable-key', httpClient: MockClient(handler));

http.Response _json(Object body, http.Request request) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);
