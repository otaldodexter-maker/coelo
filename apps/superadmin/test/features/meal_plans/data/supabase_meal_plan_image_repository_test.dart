import 'dart:typed_data';

import 'package:coelo_superadmin/features/meal_plans/data/supabase_meal_plan_image_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_image_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('falha de transporte no upload vira indisponibilidade', () async {
    // Antes, upload capturava apenas MealPlanImageException, PostgrestException,
    // StorageException e FormatException: um ClientException escapava cru do
    // repositorio e chegava ao assistente de Cardapios como excecao nao
    // tratada, em vez de virar estado de indisponibilidade.
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
    // A validacao roda dentro do try, entao o catch alargado nao pode
    // transformar erro de argumento em indisponibilidade.
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
    // O banco expunha uma forma de dois argumentos que lia a revisao atual e a
    // usava como esperada: toda exclusao "concordava" com o estado que acabara
    // de ler e nunca via conflito. O pacote 20260910120000 removeu essa forma;
    // aqui o cliente prova que passou a mandar a revisao que leu.
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

SupabaseClient _client() => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient((request) async => throw ClientException('synthetic network failure')),
);

MealPlanImageUploadRequest _request() => MealPlanImageUploadRequest(
  resource: const MealPlanImageResource.mealPlan('meal-plan-1'),
  fileName: 'capa.png',
  mimeType: 'image/png',
  // Assinatura PNG real: o repositorio valida os magic bytes antes de qualquer
  // chamada de rede, entao um conteudo generico pararia na validacao e nunca
  // exercitaria o caminho de transporte.
  bytes: Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
  requestId: 'intent-1',
);
