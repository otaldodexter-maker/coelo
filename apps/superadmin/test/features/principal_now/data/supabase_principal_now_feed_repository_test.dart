import 'dart:convert';

import 'package:coelo_superadmin/features/principal_now/data/supabase_principal_now_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_now/domain/principal_now_feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const scope = PrincipalNowFeedScope(
    institutionId: '00000000-0000-0000-0000-000000000001',
    unitId: '00000000-0000-0000-0000-000000000002',
    groupId: '00000000-0000-0000-0000-000000000003',
  );
  final now = DateTime.utc(2026, 8, 21, 12);

  test('lista somente itens vigentes e preserva tickets sem expor paths', () async {
    late http.Request rpcRequest;
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        rpcRequest = request;
        return http.Response(
          jsonEncode([
            _row(
              id: 'active',
              publishedAt: now.subtract(const Duration(hours: 2)),
              expiresAt: now.add(const Duration(hours: 22)),
            ),
            _row(
              id: 'expired',
              publishedAt: now.subtract(const Duration(hours: 25)),
              expiresAt: now.subtract(const Duration(minutes: 1)),
            ),
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final stories = await SupabasePrincipalNowFeedRepository(
      client,
      now: () => now,
    ).listVisibleStories(scope);

    expect(stories, hasLength(1));
    expect(stories.single.publicationId, 'active');
    expect(stories.single.timeLabel, '2 h');
    expect(stories.single.media.readTicket, 'ticket-active');
    expect(stories.single.media.mimeType, 'image/webp');
    expect(stories.single.media.kind, PrincipalNowMediaKind.media);
    expect(stories.single.audio?.readTicket, 'audio-ticket-active');
    expect(stories.single.audio?.mimeType, 'audio/mpeg');
    expect(stories.single.audio?.kind, PrincipalNowMediaKind.audio);
    expect(stories.single.cropScale, 1);
    expect(stories.single.cropX, 0);
    expect(stories.single.cropY, 0);
    expect(stories.single.coverPosition, 0);
    expect(rpcRequest.url.path, endsWith('/rpc/list_visible_now_publications'));
    expect(jsonDecode(rpcRequest.body), {
      'p_institution_id': scope.institutionId,
      'p_unit_id': scope.unitId,
      'p_group_id': scope.groupId,
      'p_limit': 20,
    });
  });

  test('resgata ticket público pela Edge e rejeita URL não HTTPS', () async {
    final requests = <Map<String, dynamic>>[];
    var secure = true;
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({
            'signed_url': secure
                ? 'https://signed.test/object?token=short-lived'
                : 'http://signed.test/object',
            'mime_type': 'image/webp',
            'expires_in': 60,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabasePrincipalNowFeedRepository(client, now: () => now);
    const media = PrincipalNowMediaDescriptor(
      readTicket: 'ticket-active',
      mimeType: 'image/webp',
      kind: PrincipalNowMediaKind.media,
    );

    final read = await repository.resolveMedia(scope: scope, publicationId: 'active', media: media);
    expect(read.signedUrl, startsWith('https://'));
    expect(read.expiresIn, const Duration(seconds: 60));
    expect(read.kind, PrincipalNowMediaKind.media);
    expect(requests.single, {'action': 'read', 'read_ticket': 'ticket-active'});

    secure = false;
    await expectLater(
      repository.resolveMedia(scope: scope, publicationId: 'active', media: media),
      throwsA(isA<PrincipalNowFeedUnavailable>()),
    );
  });

  for (final sample in <({String name, Map<String, Object?> payload})>[
    // O ativo redimido tem de ser o que o descritor declarou. Sem esta
    // conferencia, o gateway poderia devolver outro ativo — de outro tipo, de
    // outra publicacao — e o cliente renderizaria sem perceber a troca.
    (
      name: 'MIME diferente do declarado',
      payload: {
        'signed_url': 'https://signed.test/object?token=x',
        'mime_type': 'image/png',
        'expires_in': 60,
      },
    ),
    // Credenciais embutidas transformariam a URL assinada num portador de
    // segredo, que vazaria em log, referer e historico.
    (
      name: 'credenciais embutidas na URL',
      payload: {
        'signed_url': 'https://user:secret@signed.test/object',
        'mime_type': 'image/webp',
        'expires_in': 60,
      },
    ),
    // TTL nao positivo nao e "expira logo": e um contrato quebrado, e tratar
    // como valido esconderia isso do chamador.
    (
      name: 'TTL zero',
      payload: {
        'signed_url': 'https://signed.test/object',
        'mime_type': 'image/webp',
        'expires_in': 0,
      },
    ),
    (
      name: 'TTL negativo',
      payload: {
        'signed_url': 'https://signed.test/object',
        'mime_type': 'image/webp',
        'expires_in': -1,
      },
    ),
  ]) {
    test('recusa um resgate com ${sample.name}', () async {
      final client = SupabaseClient(
        'https://coelo.test',
        'publishable-key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(sample.payload),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);

      await expectLater(
        SupabasePrincipalNowFeedRepository(client, now: () => now).resolveMedia(
          scope: scope,
          publicationId: 'active',
          media: const PrincipalNowMediaDescriptor(
            readTicket: 'ticket-active',
            mimeType: 'image/webp',
            kind: PrincipalNowMediaKind.media,
          ),
        ),
        throwsA(isA<PrincipalNowFeedUnavailable>()),
      );
    });
  }

  test('uma publicacao ambigua e recusada em vez de resolvida pela primeira', () async {
    // Dois itens vigentes com o mesmo id nao sao um duplicado inofensivo: o
    // resgate teria de escolher um, e escolher em silencio significa entregar
    // midia de uma publicacao que o operador nao pediu.
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode([
            _row(
              id: 'active',
              publishedAt: now.subtract(const Duration(hours: 2)),
              expiresAt: now.add(const Duration(hours: 22)),
            ),
            _row(
              id: 'active',
              publishedAt: now.subtract(const Duration(hours: 1)),
              expiresAt: now.add(const Duration(hours: 23)),
              ticketSuffix: 'clone',
            ),
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabasePrincipalNowFeedRepository(client, now: () => now).resolveMedia(
        scope: scope,
        publicationId: 'active',
        media: const PrincipalNowMediaDescriptor(
          readTicket: 'ticket-active',
          mimeType: 'image/webp',
          kind: PrincipalNowMediaKind.media,
        ),
      ),
      throwsA(isA<PrincipalNowFeedUnavailable>()),
    );
  });

  test('falha fechado quando a RPC nega o contexto', () async {
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'code': '42501', 'message': 'not authorized'}),
          403,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabasePrincipalNowFeedRepository(client).listVisibleStories(scope),
      throwsA(isA<PrincipalNowFeedUnauthorized>()),
    );
  });

  test('mapeia negação da Edge para não autorizado', () async {
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'code': request.url.path.endsWith('/rpc/list_visible_now_publications')
                ? '42501'
                : 'media_read_ticket_invalid',
            'message': 'not authorized',
          }),
          403,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabasePrincipalNowFeedRepository(client).resolveMedia(
        scope: scope,
        publicationId: 'active',
        media: const PrincipalNowMediaDescriptor(
          readTicket: 'ticket-denied',
          mimeType: 'image/webp',
          kind: PrincipalNowMediaKind.media,
        ),
      ),
      throwsA(isA<PrincipalNowFeedUnauthorized>()),
    );
  });

  test('renova ticket antes do resgate quando o relógio ultrapassa dois minutos', () async {
    var current = now;
    var rpcCalls = 0;
    final edgeTickets = <String>[];
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rpc/list_visible_now_publications')) {
          rpcCalls += 1;
          return http.Response(
            jsonEncode([
              _row(
                id: 'active',
                publishedAt: now.subtract(const Duration(hours: 2)),
                expiresAt: now.add(const Duration(hours: 22)),
                ticketSuffix: rpcCalls == 1 ? 'old' : 'renewed',
              ),
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        edgeTickets.add(body['read_ticket'] as String);
        return http.Response(
          jsonEncode({
            'signed_url': 'https://signed.test/renewed',
            'mime_type': 'image/webp',
            'expires_in': 60,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabasePrincipalNowFeedRepository(client, now: () => current);
    final item = (await repository.listVisibleStories(scope)).single;

    current = current.add(const Duration(minutes: 2, seconds: 1));
    final read = await repository.resolveMedia(
      scope: scope,
      publicationId: item.publicationId,
      media: item.media,
    );

    expect(read.signedUrl, 'https://signed.test/renewed');
    expect(rpcCalls, 2);
    expect(edgeTickets, ['ticket-active-renewed']);
  });

  test('renova uma vez após resposta perdida sem mudar publication id ou kind', () async {
    var rpcCalls = 0;
    final edgeTickets = <String>[];
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rpc/list_visible_now_publications')) {
          rpcCalls += 1;
          return http.Response(
            jsonEncode([
              _row(
                id: 'active',
                publishedAt: now.subtract(const Duration(hours: 2)),
                expiresAt: now.add(const Duration(hours: 22)),
                ticketSuffix: rpcCalls == 1 ? 'old' : 'renewed',
              ),
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final ticket = body['read_ticket'] as String;
        edgeTickets.add(ticket);
        if (ticket.endsWith('old')) throw http.ClientException('response lost', request.url);
        return http.Response(
          jsonEncode({
            'signed_url': 'https://signed.test/recovered',
            'mime_type': 'image/webp',
            'expires_in': 60,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabasePrincipalNowFeedRepository(client, now: () => now);
    final item = (await repository.listVisibleStories(scope)).single;

    final read = await repository.resolveMedia(
      scope: scope,
      publicationId: item.publicationId,
      media: item.media,
    );

    expect(read.signedUrl, 'https://signed.test/recovered');
    expect(read.kind, PrincipalNowMediaKind.media);
    expect(rpcCalls, 2);
    expect(edgeTickets, ['ticket-active-old', 'ticket-active-renewed']);
  });

  test('renova ticket consumido uma única vez e resgata o mesmo item', () async {
    var rpcCalls = 0;
    final edgeTickets = <String>[];
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rpc/list_visible_now_publications')) {
          rpcCalls += 1;
          return http.Response(
            jsonEncode([
              _row(
                id: 'active',
                publishedAt: now.subtract(const Duration(hours: 2)),
                expiresAt: now.add(const Duration(hours: 22)),
                ticketSuffix: rpcCalls == 1 ? 'consumed' : 'renewed',
              ),
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final ticket = body['read_ticket'] as String;
        edgeTickets.add(ticket);
        if (ticket.endsWith('consumed')) {
          return http.Response(
            jsonEncode({'code': 'media_read_ticket_invalid'}),
            403,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          jsonEncode({
            'signed_url': 'https://signed.test/recovered-consumed',
            'mime_type': 'image/webp',
            'expires_in': 60,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabasePrincipalNowFeedRepository(client, now: () => now);
    final item = (await repository.listVisibleStories(scope)).single;

    final read = await repository.resolveMedia(
      scope: scope,
      publicationId: item.publicationId,
      media: item.media,
    );

    expect(read.signedUrl, 'https://signed.test/recovered-consumed');
    expect(rpcCalls, 2);
    expect(edgeTickets, ['ticket-active-consumed', 'ticket-active-renewed']);
  });

  test('expiração manual falha fechada enquanto o comando autorizado não existe', () async {
    var requests = 0;
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests++;
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabasePrincipalNowFeedRepository(client, now: () => now).expireNow(
        const PrincipalNowExpireCommand(
          publicationId: 'active',
          requestId: '00000000-0000-4000-8000-000000000001',
          reason: 'Publicado por engano',
        ),
      ),
      throwsA(isA<PrincipalNowExpireUnavailable>()),
    );
    expect(requests, 0, reason: 'nenhuma RPC de expiração pode ser inventada pelo cliente');
  });

  test('canExpire só é verdadeiro quando a projeção autorizada concede', () async {
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode([
            _row(
              id: 'omitido',
              publishedAt: now.subtract(const Duration(hours: 1)),
              expiresAt: now.add(const Duration(hours: 23)),
            ),
            {
              ..._row(
                id: 'concedido',
                publishedAt: now.subtract(const Duration(hours: 1)),
                expiresAt: now.add(const Duration(hours: 23)),
              ),
              'can_expire': true,
            },
            {
              ..._row(
                id: 'texto',
                publishedAt: now.subtract(const Duration(hours: 1)),
                expiresAt: now.add(const Duration(hours: 23)),
              ),
              'can_expire': 'true',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    final stories = await SupabasePrincipalNowFeedRepository(
      client,
      now: () => now,
    ).listVisibleStories(scope);

    expect(stories.map((story) => story.publicationId), ['omitido', 'concedido', 'texto']);
    expect(stories.map((story) => story.canExpire), [false, true, false]);
  });
}

Map<String, dynamic> _row({
  required String id,
  required DateTime publishedAt,
  required DateTime expiresAt,
  String? ticketSuffix,
}) => {
  'publication_id': id,
  'author_name': 'Colégio Coelo',
  'author_initials': 'CC',
  'context_label': 'Turma Girassol',
  'caption': 'Experimento rápido em sala',
  'overlay_text': 'Ciência em ação',
  'crop_scale': 1,
  'crop_x': 0,
  'crop_y': 0,
  'cover_position': 0,
  'published_at': publishedAt.toIso8601String(),
  'expires_at': expiresAt.toIso8601String(),
  'media': [
    {
      'read_ticket': 'ticket-$id${ticketSuffix == null ? '' : '-$ticketSuffix'}',
      'kind': 'media',
      'mime_type': 'image/webp',
    },
    {
      'read_ticket': 'audio-ticket-$id${ticketSuffix == null ? '' : '-$ticketSuffix'}',
      'kind': 'audio',
      'mime_type': 'audio/mpeg',
    },
  ],
};
