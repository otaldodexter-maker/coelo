import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/meal_plans/data/supabase_meal_plan_image_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_image_repository.dart';
import 'package:coelo_superadmin/shared/data/edge_media_bytes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('upload segue prepare -> bytes pela Edge (grava e finaliza no servidor)', () async {
    // R12-38 / spec 063 + ADR 0032: nada de Supabase Storage nem PUT assinado no
    // cliente; bucket e chave nunca chegam aqui. O envelope vai no cabeçalho e
    // os bytes no corpo de um único POST à Edge.
    final actions = <String>[];
    late Uint8List uploadBody;
    late Map<String, dynamic> envelope;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/functions/v1/meal-plan-media')) {
          final raw = request.headers[edgeMediaEnvelopeHeader];
          if (raw != null) {
            actions.add('upload');
            envelope = jsonDecode(utf8.decode(base64Url.decode(raw + '=' * ((4 - raw.length % 4) % 4))))
                as Map<String, dynamic>;
            uploadBody = request.bodyBytes;
            expect(request.headers['content-type'], startsWith('application/octet-stream'));
            return _json({
              'id': 'asset-1',
              'storage_bucket': 'coelo-media-prod',
              'storage_path': 'tenants/x/original.png',
              'mime_type': 'image/png',
              'size_bytes': 8,
              'checksum_sha256': 'a' * 64,
              'revision': 1,
              'alt_text': 'Capa',
            });
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          actions.add(body['action'] as String);
          expect(body['action'], 'prepare');
          expect(body['resource_kind'], 'meal_plan');
          expect(body['resource_id'], 'meal-plan-1');
          expect(body['mime_type'], 'image/png');
          expect(body['size_bytes'], 8);
          return _json({'asset_id': 'asset-1', 'storage_provider': 'r2', 'max_bytes': 2097152});
        }
        fail('unexpected request ${request.url}');
      }),
    );
    addTearDown(client.dispose);

    final asset = await SupabaseMealPlanImageRepository(client).upload(
      MealPlanImageUploadRequest(
        resource: const MealPlanImageResource.mealPlan('meal-plan-1'),
        fileName: 'capa.png',
        mimeType: 'image/png',
        bytes: _png(),
        requestId: 'intent-1',
        altText: 'Capa',
        replaceAssetId: 'asset-0',
      ),
    );

    expect(actions, ['prepare', 'upload']);
    expect(envelope['request_id'], 'intent-1');
    expect(envelope['replace_asset_id'], 'asset-0');
    expect(envelope['alt_text'], 'Capa');
    expect(uploadBody, _png());
    expect(asset.id, 'asset-1');
    expect(asset.bucket, 'coelo-media-prod');
    expect(asset.revision, 1);
  });

  test('leitura devolve os bytes pela Edge como URL local, sem URL assinada', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, {'action': 'read', 'asset_id': 'asset-1', 'inline': true});
        return Response.bytes(_png(), 200, headers: {'content-type': 'application/octet-stream'});
      }),
    );
    addTearDown(client.dispose);

    final uri = await SupabaseMealPlanImageRepository(client).createSignedReadUrl('asset-1');
    expect(uri.toString(), startsWith('data:image/png;base64,'));
  });

  test('recusa da Edge no upload vira erro de validacao com a mensagem do contrato', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.headers.containsKey(edgeMediaEnvelopeHeader)) {
          return Response(
            jsonEncode({'error': 'invalid_image_signature'}),
            422,
            headers: {'content-type': 'application/json'},
          );
        }
        return _json({'asset_id': 'asset-1', 'storage_provider': 'r2'});
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseMealPlanImageRepository(client).upload(_request()),
      throwsA(isA<MealPlanImageValidationException>()),
    );
  });

  test('falha de transporte no upload vira indisponibilidade', () async {
    final client = _client();
    addTearDown(client.dispose);

    await expectLater(
      SupabaseMealPlanImageRepository(client).upload(_request()),
      throwsA(isA<MealPlanImageUnavailableException>()),
    );
  });

  test('falha de transporte na leitura vira indisponibilidade', () async {
    final client = _client();
    addTearDown(client.dispose);

    await expectLater(
      SupabaseMealPlanImageRepository(client).createSignedReadUrl('asset-1'),
      throwsA(isA<MealPlanImageUnavailableException>()),
    );
  });

  test('falha de transporte na exclusao vira indisponibilidade', () async {
    final client = _client();
    addTearDown(client.dispose);

    await expectLater(
      SupabaseMealPlanImageRepository(
        client,
      ).delete(assetId: 'asset-1', requestId: 'intent-1', expectedRevision: 1),
      throwsA(isA<MealPlanImageUnavailableException>()),
    );
  });

  test('exclusao sem identificador continua sendo erro de validacao', () async {
    final client = _client();
    addTearDown(client.dispose);

    await expectLater(
      SupabaseMealPlanImageRepository(
        client,
      ).delete(assetId: '  ', requestId: 'intent-1', expectedRevision: 1),
      throwsA(isA<MealPlanImageException>()),
    );
  });

  test('exclusao envia a revisao lida pelo cliente', () async {
    String? body;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        body = request.body;
        return Response(
          'null',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);

    await SupabaseMealPlanImageRepository(
      client,
    ).delete(assetId: 'asset-1', requestId: 'intent-1', expectedRevision: 7);

    expect(body, contains('"p_expected_revision":7'));
  });

  test('revisao invalida nao chega ao banco', () async {
    var called = false;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        called = true;
        return Response(
          'null',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseMealPlanImageRepository(
        client,
      ).delete(assetId: 'asset-1', requestId: 'intent-1', expectedRevision: 0),
      throwsA(isA<MealPlanImageValidationException>()),
    );
    expect(called, isFalse);
  });
}

Response _json(Map<String, Object?> body) =>
    Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

SupabaseClient _client() => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient((request) async => throw ClientException('synthetic network failure')),
);

Uint8List _png() => Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

MealPlanImageUploadRequest _request() => MealPlanImageUploadRequest(
  resource: const MealPlanImageResource.mealPlan('meal-plan-1'),
  fileName: 'capa.png',
  mimeType: 'image/png',
  bytes: _png(),
  requestId: 'intent-1',
);
