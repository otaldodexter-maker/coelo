import 'dart:convert';

import 'package:coelo_superadmin/features/principal_moments/data/supabase_principal_moments_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Momentos feed adapter.
///
/// It reads through the authorised projection and never assembles a bucket, an
/// object key or a signed URL. The scope it sends is a routing hint; the RPC
/// re-derives actor, tenant, membership, capability and audience. Everything
/// below is about refusing to render what the server did not authorise.
void main() {
  const scope = PrincipalMomentsFeedScope(institutionId: 'institution-1');

  Map<String, Object?> moment({Object? canRemove, List<Object?>? media}) => {
    'moment_id': 'moment-1',
    'author_name': 'Colégio Coelo',
    'author_initials': 'CC',
    'context_label': '3º ano A',
    'caption': 'Momento autorizado.',
    'published_at': DateTime.now().toUtc().toIso8601String(),
    'media': media ?? <Object?>[],
    'can_remove': ?canRemove,
  };

  SupabaseClient clientReturning(Object? body, {int status = 200}) => _client(
    (request) async => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: request,
    ),
  );

  for (final sample in <({String name, Object? value, bool granted})>[
    (name: 'omitido', value: null, granted: false),
    (name: 'false', value: false, granted: false),
    (name: 'concedido', value: true, granted: true),
    // Qualquer valor que nao seja `true` nega: uma string vinda de um encoder
    // frouxo nao pode virar permissao de remocao.
    (name: 'string true', value: 'true', granted: false),
    (name: 'numero 1', value: 1, granted: false),
  ]) {
    test('can_remove vem da projecao autorizada (${sample.name})', () async {
      final client = clientReturning([moment(canRemove: sample.value)]);
      addTearDown(client.dispose);

      final moments = await SupabasePrincipalMomentsFeedRepository(
        client,
      ).listVisibleMoments(scope);

      expect(moments.single.canRemove, sample.granted);
    });
  }

  test('a projecao minima e mapeada e a midia sai ordenada', () async {
    late Map<String, dynamic> requestBody;
    final client = _client((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode([
          moment(
            media: [
              {'read_ticket': 'ticket-2', 'mime_type': 'video/mp4', 'display_order': 1},
              {'read_ticket': 'ticket-1', 'mime_type': 'image/jpeg', 'display_order': 0},
            ],
          ),
        ]),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    addTearDown(client.dispose);

    final moments = await SupabasePrincipalMomentsFeedRepository(client).listVisibleMoments(scope);

    expect(requestBody['p_institution_id'], 'institution-1');
    expect(moments.single.media.map((item) => item.readTicket), ['ticket-1', 'ticket-2']);
    // Descritores opacos: nenhuma coordenada de armazenamento atravessa.
    expect(jsonEncode(requestBody).contains('bucket'), isFalse);
  });

  for (final field in ['moment_id', 'author_name', 'context_label', 'published_at']) {
    test('uma linha sem $field e recusada em vez de renderizada pela metade', () async {
      final row = moment()..remove(field);
      final client = clientReturning([row]);
      addTearDown(client.dispose);

      await expectLater(
        SupabasePrincipalMomentsFeedRepository(client).listVisibleMoments(scope),
        throwsA(isA<PrincipalMomentsFeedUnavailable>()),
      );
    });
  }

  for (final blank in ['', '   ']) {
    test('um moment_id em branco (${blank.isEmpty ? 'vazio' : 'espacos'}) e recusado', () async {
      // Nao e detalhe: a afordancia de remocao so testa `id != null`, entao um
      // id vazio atravessaria o cliente e viraria um comando sem alvo.
      final client = clientReturning([moment()..['moment_id'] = blank]);
      addTearDown(client.dispose);

      await expectLater(
        SupabasePrincipalMomentsFeedRepository(client).listVisibleMoments(scope),
        throwsA(isA<PrincipalMomentsFeedUnavailable>()),
      );
    });
  }

  test('um descritor de midia sem ordem e recusado', () async {
    final client = clientReturning([
      moment(
        media: [
          {'read_ticket': 'ticket-1', 'mime_type': 'image/jpeg'},
        ],
      ),
    ]);
    addTearDown(client.dispose);

    await expectLater(
      SupabasePrincipalMomentsFeedRepository(client).listVisibleMoments(scope),
      throwsA(isA<PrincipalMomentsFeedUnavailable>()),
    );
  });

  for (final code in ['42501', 'PGRST301']) {
    test('uma consulta negada falha fechada como nao autorizada ($code)', () async {
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
        SupabasePrincipalMomentsFeedRepository(client).listVisibleMoments(scope),
        throwsA(isA<PrincipalMomentsFeedUnauthorized>()),
      );
    });
  }

  test('qualquer outra falha de banco fica indisponivel, nao nao autorizada', () async {
    final client = _client(
      (request) async => http.Response(
        jsonEncode({'code': '08006', 'message': 'connection failure'}),
        500,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabasePrincipalMomentsFeedRepository(client).listVisibleMoments(scope),
      throwsA(isA<PrincipalMomentsFeedUnavailable>()),
    );
  });

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
      SupabasePrincipalMomentsFeedRepository(client).removeMoment(
        const PrincipalMomentsRemoveCommand(
          momentId: 'moment-1',
          requestId: 'intent-1',
          reason: 'Publicado por engano',
        ),
      ),
      throwsA(isA<PrincipalMomentsRemoveUnavailable>()),
    );

    // Nenhum nome de RPC pode ser adivinhado enquanto o comando autorizado nao
    // existe: adivinhar daria 404 ou alcancaria uma superficie nao revisada.
    expect(requests, 0);
  });
}

SupabaseClient _client(Future<http.Response> Function(http.Request request) handler) =>
    SupabaseClient('https://coelo.test', 'publishable-key', httpClient: MockClient(handler));
