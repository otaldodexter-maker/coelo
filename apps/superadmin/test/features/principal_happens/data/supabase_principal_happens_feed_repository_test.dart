import 'dart:convert';

import 'package:coelo_superadmin/features/principal_happens/data/supabase_principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final ttl in [0, -1, 0.5]) {
    test('rejects a media ticket with unusable TTL $ttl', () async {
      final client = _client(
        (request) async => http.Response(
          jsonEncode({
            'signed_url': 'https://signed.example/expired',
            'mime_type': 'image/jpeg',
            'expires_in': ttl,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabasePrincipalHappensFeedRepository(client).resolveMedia(
          const PrincipalHappensMediaDescriptor(
            readTicket: 'expired',
            mimeType: 'image/jpeg',
            displayOrder: 0,
          ),
        ),
        throwsA(isA<PrincipalHappensFeedUnavailable>()),
      );
    });
  }
  test('maps only the minimal feed projection and preserves media order', () async {
    late Map<String, dynamic> requestBody;
    final client = _client((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode([
          {
            'author_name': 'Equipe Coelo',
            'author_initials': 'EC',
            'context_label': '3º ano A',
            'caption': 'Registro autorizado.',
            'published_at': DateTime.now().toUtc().toIso8601String(),
            'media': [
              {'read_ticket': 'ticket-2', 'mime_type': 'video/mp4', 'display_order': 1},
              {'read_ticket': 'ticket-1', 'mime_type': 'image/jpeg', 'display_order': 0},
            ],
            'likes_count': 999,
            'liked_by_label': 'não faz parte do contrato',
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    addTearDown(client.dispose);
    final repository = SupabasePrincipalHappensFeedRepository(client);

    final posts = await repository.listVisiblePosts(
      const PrincipalHappensFeedScope(
        institutionId: 'institution-1',
        unitId: 'unit-1',
        groupId: 'group-1',
      ),
    );

    expect(requestBody, {
      'p_institution_id': 'institution-1',
      'p_unit_id': 'unit-1',
      'p_group_id': 'group-1',
      'p_limit': 20,
    });
    expect(posts.single.likes, isNull);
    expect(posts.single.likedBy, isNull);
    expect(posts.single.media.map((item) => item.readTicket), ['ticket-1', 'ticket-2']);
  });

  test('redeems a media ticket through action read without exposing storage paths', () async {
    late Map<String, dynamic> requestBody;
    final client = _client((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'signed_url': 'https://signed.example/media',
          'mime_type': 'image/jpeg',
          'expires_in': 60,
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    addTearDown(client.dispose);
    final repository = SupabasePrincipalHappensFeedRepository(client);

    final read = await repository.resolveMedia(
      const PrincipalHappensMediaDescriptor(
        readTicket: 'opaque-ticket',
        mimeType: 'image/jpeg',
        displayOrder: 0,
      ),
    );

    expect(requestBody, {'action': 'read', 'read_ticket': 'opaque-ticket'});
    expect(read.signedUrl, 'https://signed.example/media');
    expect(read.expiresIn, const Duration(seconds: 60));
  });
  for (final url in const [
    'http://signed.example/asset',
    'ftp://signed.example/asset',
    'signed.example/asset',
    '',
  ]) {
    test('refuses a redeemed ticket that is not an HTTPS URL: "$url"', () async {
      final client = _client(
        (request) async => http.Response(
          jsonEncode({'signed_url': url, 'mime_type': 'image/jpeg', 'expires_in': 60}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabasePrincipalHappensFeedRepository(client).resolveMedia(
          const PrincipalHappensMediaDescriptor(
            readTicket: 'ticket',
            mimeType: 'image/jpeg',
            displayOrder: 0,
          ),
        ),
        throwsA(isA<PrincipalHappensFeedUnavailable>()),
      );
    });
  }

  test('refuses a redeemed ticket without a media type', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode({
          'signed_url': 'https://signed.example/asset',
          'mime_type': '   ',
          'expires_in': 60,
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabasePrincipalHappensFeedRepository(client).resolveMedia(
        const PrincipalHappensMediaDescriptor(
          readTicket: 'ticket',
          mimeType: 'image/jpeg',
          displayOrder: 0,
        ),
      ),
      throwsA(isA<PrincipalHappensFeedUnavailable>()),
    );
  });

  for (final code in const ['42501', 'PGRST301']) {
    test('a denied feed query fails closed as unauthorized ($code)', () async {
      final client = _client(
        (request) async => http.Response(
          jsonEncode({'code': code, 'message': 'denied', 'details': null, 'hint': null}),
          403,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabasePrincipalHappensFeedRepository(
          client,
        ).listVisiblePosts(const PrincipalHappensFeedScope(institutionId: 'institution-1')),
        throwsA(isA<PrincipalHappensFeedUnauthorized>()),
      );
    });
  }

  test('any other database failure stays unavailable instead of unauthorized', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode({'code': '57014', 'message': 'timeout', 'details': null, 'hint': null}),
        500,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabasePrincipalHappensFeedRepository(
        client,
      ).listVisiblePosts(const PrincipalHappensFeedScope(institutionId: 'institution-1')),
      throwsA(isA<PrincipalHappensFeedUnavailable>()),
    );
  });

  test('a row missing a required field is refused instead of half rendered', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode([
          {
            'author_name': '  ',
            'author_initials': 'EC',
            'context_label': '3º ano A',
            'published_at': DateTime.now().toUtc().toIso8601String(),
            'media': const <Map<String, dynamic>>[],
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabasePrincipalHappensFeedRepository(
        client,
      ).listVisiblePosts(const PrincipalHappensFeedScope(institutionId: 'institution-1')),
      throwsA(isA<PrincipalHappensFeedUnavailable>()),
    );
  });
  for (final sample in <({String name, Object? value, bool granted})>[
    (name: 'omitido', value: null, granted: false),
    (name: 'false', value: false, granted: false),
    (name: 'concedido', value: true, granted: true),
    // Qualquer coisa que nao seja `true` nega. Uma string "true" vinda de um
    // encoder frouxo nao pode virar permissao.
    (name: 'string true', value: 'true', granted: false),
    (name: 'numero 1', value: 1, granted: false),
  ]) {
    test('can_remove vem da projecao autorizada (${sample.name})', () async {
      final client = _client(
        (request) async => http.Response(
          jsonEncode([
            {
              'post_id': 'post-1',
              'author_name': 'Equipe Coelo',
              'author_initials': 'EC',
              'context_label': '3º ano A',
              'caption': 'Registro autorizado.',
              'published_at': DateTime.now().toUtc().toIso8601String(),
              'media': <Object?>[],
              if (sample.value != null) 'can_remove': sample.value,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      addTearDown(client.dispose);

      final posts = await SupabasePrincipalHappensFeedRepository(
        client,
      ).listVisiblePosts(const PrincipalHappensFeedScope(institutionId: 'institution-1'));

      expect(posts.single.canRemove, sample.granted);
    });
  }

  test('a remocao falha fechada sem chegar a rede', () async {
    var requests = 0;
    final client = _client((request) async {
      requests++;
      return http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    addTearDown(client.dispose);

    await expectLater(
      SupabasePrincipalHappensFeedRepository(client).removePost(
        const PrincipalHappensRemoveCommand(
          postId: 'post-1',
          requestId: 'intent-1',
          reason: 'Publicado por engano',
        ),
      ),
      throwsA(isA<PrincipalHappensRemoveUnavailable>()),
    );

    // Nenhum nome de RPC pode ser adivinhado enquanto o comando autorizado nao
    // existe: adivinhar daria 404 ou alcancaria uma superficie nao revisada.
    expect(requests, 0);
  });
}

SupabaseClient _client(Future<http.Response> Function(http.Request request) handler) =>
    SupabaseClient('https://coelo.test', 'publishable-key', httpClient: MockClient(handler));
