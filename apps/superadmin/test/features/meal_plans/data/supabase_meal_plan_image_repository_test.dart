import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/meal_plans/data/supabase_meal_plan_image_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_image_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('upload segue prepare -> PUT assinado -> finalize pelo gateway meal-plan-media', () async {
    // R12-38 / spec 063: nada de Supabase Storage no cliente; bucket e chave
    // nunca chegam aqui, so a janela PUT assinada e o asset finalizado.
    final actions = <String>[];
    final putHeaders = <String, String>{};
    late Uint8List putBody;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/functions/v1/meal-plan-media')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          actions.add(body['action'] as String);
          if (body['action'] == 'prepare') {
            expect(body['resource_kind'], 'meal_plan');
            expect(body['resource_id'], 'meal-plan-1');
            expect(body['mime_type'], 'image/png');
            expect(body['size_bytes'], 8);
            return _json({
              'asset_id': 'asset-1',
              'storage_provider': 'r2',
              'upload_url': 'https://signed.example/tenants/x/original.png?sig=1',
              'required_headers': {'content-type': 'image/png'},
              'max_bytes': 2097152,
            });
          }
          expect(body['request_id'], 'intent-1');
          expect(body['replace_asset_id'], 'asset-0');
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
        fail('unexpected request ${request.url}');
      }),
    );
    addTearDown(client.dispose);
    final mediaClient = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(request.url.host, 'signed.example');
      putHeaders.addAll(request.headers);
      putBody = request.bodyBytes;
      return Response('', 200, request: request);
    });

    final asset = await SupabaseMealPlanImageRepository(client, mediaClient: mediaClient).upload(
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

    expect(actions, ['prepare', 'finalize']);
    expect(putHeaders['content-type'], 'image/png');
    expect(putBody, _png());
    expect(asset.id, 'asset-1');
    expect(asset.bucket, 'coelo-media-prod');
    expect(asset.revision, 1);
  });

  test('leitura devolve a URL assinada curta do gateway', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['action'], 'read');
        expect(body['asset_id'], 'asset-1');
        return _json({
          'signed_url': 'https://signed.example/read?sig=2',
          'mime_type': 'image/png',
          'expires_in': 300,
        });
      }),
    );
    addTearDown(client.dispose);

    final uri = await SupabaseMealPlanImageRepository(client).createSignedReadUrl('asset-1');
    expect(uri.host, 'signed.example');
  });

  test('cabecalho de autorizacao vindo do gateway e recusado antes do PUT', () async {
    var putCalled = false;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => _json({
          'asset_id': 'asset-1',
          'upload_url': 'https://signed.example/x',
          'required_headers': {'authorization': 'Bearer leak'},
        }),
      ),
    );
    addTearDown(client.dispose);
    final mediaClient = MockClient((request) async {
      putCalled = true;
      return Response('', 200, request: request);
    });

    await expectLater(
      SupabaseMealPlanImageRepository(client, mediaClient: mediaClient).upload(_request()),
      throwsA(isA<MealPlanImageUnavailableException>()),
    );
    expect(putCalled, isFalse);
  });

  test('falha de transporte no upload vira indisponibilidade', () async {
    final client = _client();
    addTearDown(client.dispose);

    await expectLater(
      SupabaseMealPlanImageRepository(client).upload(_request()),
      throwsA(isA<MealPlanImageUnavailableException>()),
    );
  });

  test('falha de transporte na URL assinada vira indisponibilidade', () async {
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
