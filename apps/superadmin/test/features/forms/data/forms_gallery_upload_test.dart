import 'dart:async';
import 'dart:typed_data';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/data/forms_image_upload.dart';
import 'package:coelo_superadmin/features/forms/presentation/response/forms_gallery_answer_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _asset = '10000000-0000-4000-8000-000000000001';
final _now = DateTime.utc(2026, 9, 12, 14);
Uint8List _png() => Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]);

void main() {
  testWidgets(
    'anonymous gallery forwards its secret to prepare finalize and pending discard only',
    (tester) async {
      const secret = 'synthetic-anonymous-edit-secret';
      final api = _Api(ticketNow: DateTime.now(), failFinalizeOnce: true);
      final session = MediaSession();
      addTearDown(session.invalidate);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormsGalleryAnswerField(
              api: api,
              session: session,
              occurrenceId: 'occurrence',
              editSecret: secret,
              item: FormItem(id: 'item', kind: FormItemKind.gallery, label: 'Fotos', position: 0),
              assetIds: const [],
              onChanged: (_) => fail('uncertain confirmation must not enter the answer'),
              onBusyChanged: (_) {},
              pickImage: () async => _png(),
              createUploadClient: () => MockClient((request) async {
                expect(request.url.toString().contains(secret), isFalse);
                expect(request.headers.values.any((value) => value.contains(secret)), isFalse);
                expect(request.headers.containsKey('authorization'), isFalse);
                return http.Response('', 200);
              }),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Selecionar imagem'));
      await tester.pumpAndSettle();
      expect(api.prepared?.payload.editSecret, secret);
      expect(api.finalized?.payload.editSecret, secret);
      await tester.tap(find.text('Descartar envio'));
      await tester.pumpAndSettle();
      expect(api.discarded?.payload.editSecret, secret);
      expect(find.textContaining(secret), findsNothing);
    },
  );
  testWidgets('session purge while picker is open clears its late bytes and disables upload', (
    tester,
  ) async {
    final session = MediaSession();
    final picker = Completer<Uint8List?>();
    final api = _Api();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormsGalleryAnswerField(
            api: api,
            session: session,
            occurrenceId: 'occurrence',
            item: FormItem(id: 'item', kind: FormItemKind.gallery, label: 'Fotos', position: 0),
            assetIds: const [],
            onChanged: (_) => fail('late image must not enter the answer'),
            onBusyChanged: (_) {},
            pickImage: () => picker.future,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Selecionar imagem'));
    await session.invalidate();
    final bytes = _png();
    picker.complete(bytes);
    await tester.pumpAndSettle();
    expect(bytes, everyElement(0));
    expect(api.prepared, isNull);
    expect(find.text('A sessão de mídia terminou. Abra novamente o formulário.'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('forms-gallery-add-item'))).onPressed,
      isNull,
    );
  });

  test('question image uses its target for prepare and finalize with no answer API', () async {
    final api = _QuestionApi();
    final operation = FormsImageUpload.questionImage(
      api: api,
      target: _questionTarget,
      session: MediaSession(),
      requestId: 'prepare-question',
      finalizeRequestId: 'finalize-question',
      createClient: () => MockClient((request) async {
        expect(request.headers, {'content-type': 'image/png'});
        return http.Response('', 200);
      }),
    );
    final asset = await operation.upload(_png());
    expect(asset.id, _asset);
    expect(api.prepares, 1);
    expect(api.finalizedTarget, same(_questionTarget));
    expect(api.finalizeRequestId, 'finalize-question');
  });
  testWidgets('gallery UI adds only a confirmed image and removes only the answer reference', (
    tester,
  ) async {
    final api = _Api(ticketNow: DateTime.now());
    var assets = <String>[];
    final busy = <bool>[];
    final session = MediaSession();
    addTearDown(session.invalidate);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => FormsGalleryAnswerField(
              api: api,
              session: session,
              occurrenceId: 'occurrence',
              item: FormItem(
                id: 'item',
                kind: FormItemKind.gallery,
                label: 'Fotos',
                position: 0,
                config: const FormItemConfig(maxImages: 1),
              ),
              assetIds: assets,
              onChanged: (value) => update(() => assets = value),
              onBusyChanged: busy.add,
              pickImage: () async => _png(),
              createUploadClient: () => MockClient((_) async => http.Response('', 200)),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Selecionar imagem'));
    await tester.pumpAndSettle();
    expect(assets, [_asset]);
    expect(api.finalizes, 1);
    expect(busy.first, isTrue);
    expect(busy.last, isFalse);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('forms-gallery-add-item'))).onPressed,
      isNull,
    );
    await tester.tap(find.text('Remover imagem 1 da resposta'));
    await tester.pumpAndSettle();
    expect(assets, isEmpty);
    expect(api.discards, 0);
  });

  testWidgets('question UI deletes the backend binding at 375 pixels and 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _QuestionApi();
    final session = MediaSession();
    addTearDown(session.invalidate);
    var assets = <String>[_asset];
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 700), textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, update) => FormsGalleryAnswerField.questionImage(
                  api: api,
                  target: _questionTarget,
                  session: session,
                  item: FormItem(
                    id: 'item',
                    kind: FormItemKind.shortText,
                    label: 'Pergunta',
                    position: 0,
                  ),
                  assetIds: assets,
                  readyAssetIds: const {},
                  onBusyChanged: (_) {},
                  onChanged: (value) => update(() => assets = value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Imagem 1 não confirmada'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Excluir imagem 1'));
    await tester.pumpAndSettle();
    expect(api.deleted, _asset);
    expect(assets, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test('question upload applies its four MiB limit before contacting the backend', () async {
    final api = _QuestionApi();
    final bytes = Uint8List(4 * 1024 * 1024 + 1)..setRange(0, 9, _png());
    final operation = FormsImageUpload.questionImage(
      api: api,
      target: _questionTarget,
      session: MediaSession(),
      requestId: 'prepare',
      finalizeRequestId: 'finalize',
    );
    await expectLater(operation.upload(bytes), throwsA(isA<FormsImageUploadException>()));
    expect(api.prepares, 0);
    expect(bytes, everyElement(0));
  });

  test('gallery sends exact ticket headers and bytes, then accepts only finalized asset', () async {
    final events = <String>[];
    final api = _Api(events: events);
    final bytes = _png();
    final operation = _upload(
      api,
      client: MockClient((request) async {
        events.add('put');
        expect(request.method, 'PUT');
        expect(request.url, api.ticket.uploadUrl);
        expect(request.headers, {'content-type': 'image/png'});
        expect(request.followRedirects, isFalse);
        expect(request.bodyBytes, orderedEquals(_png()));
        return http.Response('', 200);
      }),
    );
    final result = await operation.upload(bytes);
    expect(result.id, _asset);
    expect(events, ['prepare', 'put', 'finalize']);
    expect(api.prepared!.payload.checksum, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(bytes, everyElement(0));
  });

  for (final invalid in ['expired', 'authorization', 'redirect-url', 'wrong-mime']) {
    test('gallery rejects $invalid ticket before PUT', () async {
      final api = _Api(ticketKind: invalid);
      var puts = 0;
      final operation = _upload(
        api,
        client: MockClient((_) async {
          puts++;
          return http.Response('', 200);
        }),
      );
      await expectLater(operation.upload(_png()), throwsA(isA<FormsImageUploadException>()));
      expect(puts, 0);
      expect(api.finalizes, 0);
    });
  }

  test('uncertain PUT keeps the asset for explicit verification without a second PUT', () async {
    final api = _Api();
    var puts = 0;
    final operation = _upload(
      api,
      client: MockClient((_) async {
        puts++;
        throw http.ClientException('synthetic private capability must never escape');
      }),
    );
    await expectLater(operation.upload(_png()), throwsA(isA<FormsImageUploadException>()));
    expect(operation.assetId, _asset);
    expect(api.finalizes, 0);
    expect((await operation.finalize()).id, _asset);
    expect(puts, 1);
    expect(api.discards, 0);
  });

  test('uncertain finalize retries its original request ID', () async {
    final api = _Api(failFinalizeOnce: true);
    final operation = _upload(api);
    await expectLater(operation.upload(_png()), throwsA(isA<FormsImageUploadException>()));
    await operation.finalize();
    expect(api.finalizeIds, ['finalize-request', 'finalize-request']);
  });

  test('mismatched finalized item cannot enter an answer', () async {
    final operation = _upload(_Api(wrongItem: true));
    await expectLater(operation.upload(_png()), throwsA(isA<FormsImageUploadException>()));
  });

  test('session invalidation during PUT clears bytes and suppresses finalize', () async {
    final session = MediaSession();
    final gate = Completer<http.Response>();
    final putStarted = Completer<void>();
    final api = _Api();
    final bytes = _png();
    final operation = _upload(
      api,
      session: session,
      client: MockClient((_) {
        putStarted.complete();
        return gate.future;
      }),
    );
    final result = operation.upload(bytes);
    final assertion = expectLater(result, throwsA(isA<FormsImageUploadException>()));
    await putStarted.future;
    await session.invalidate();
    expect(bytes, everyElement(0));
    gate.complete(http.Response('', 200));
    await assertion;
    expect(api.finalizes, 0);
  });

  test('explicit discard uses the authorized API and does not retry the PUT', () async {
    final api = _Api();
    final operation = _upload(api, client: MockClient((_) async => http.Response('', 503)));
    await expectLater(operation.upload(_png()), throwsA(isA<FormsImageUploadException>()));
    await operation.discard('discard-request');
    expect(api.discards, 1);
    expect(api.discarded!.payload.assetId, _asset);
    expect(api.discarded!.requestId, 'discard-request');
  });

  test('invalid image bytes are cleared without preparing a ticket', () async {
    final api = _Api();
    final bytes = Uint8List.fromList([1, 2, 3]);
    await expectLater(_upload(api).upload(bytes), throwsA(isA<FormsImageUploadException>()));
    expect(api.prepared, isNull);
    expect(bytes, everyElement(0));
  });
}

FormsImageUpload _upload(_Api api, {http.Client? client, MediaSession? session}) =>
    FormsImageUpload(
      api: api,
      session: session ?? MediaSession(),
      occurrenceId: 'occurrence',
      itemId: 'item',
      requestId: 'prepare-request',
      finalizeRequestId: 'finalize-request',
      now: () => _now,
      createClient: () => client ?? MockClient((_) async => http.Response('', 200)),
    );

final class _Api implements FormsApi {
  _Api({
    List<String>? events,
    this.ticketKind,
    this.wrongItem = false,
    this.failFinalizeOnce = false,
    this.ticketNow,
  }) : events = events ?? [];
  final List<String> events;
  final String? ticketKind;
  final bool wrongItem;
  bool failFinalizeOnce;
  final DateTime? ticketNow;
  int finalizes = 0;
  int discards = 0;
  final finalizeIds = <String>[];
  FormCommand<FormAssetUploadPayload>? prepared;
  FormCommand<FormAssetIdPayload>? discarded;
  FormCommand<FormAssetIdPayload>? finalized;
  FormAssetUploadTicket get ticket => FormAssetUploadTicket(
    assetId: _asset,
    uploadUrl: Uri.parse(
      ticketKind == 'redirect-url'
          ? 'http://invalid.example/image'
          : 'https://synthetic.r2.cloudflarestorage.com/image',
    ),
    requiredHeaders: {
      'content-type': ticketKind == 'wrong-mime' ? 'image/jpeg' : 'image/png',
      if (ticketKind == 'authorization') 'authorization': 'synthetic',
    },
    expiresAt: ticketKind == 'expired' ? _now : (ticketNow ?? _now).add(const Duration(minutes: 4)),
  );
  @override
  Future<FormAssetUploadTicket> prepareAssetUpload(
    FormCommand<FormAssetUploadPayload> command,
  ) async {
    events.add('prepare');
    prepared = command;
    return ticket;
  }

  @override
  Future<FormAsset> finalizeAssetUpload(FormCommand<FormAssetIdPayload> command) async {
    finalized = command;
    events.add('finalize');
    finalizes++;
    finalizeIds.add(command.requestId);
    if (failFinalizeOnce) {
      failFinalizeOnce = false;
      throw TimeoutException('synthetic');
    }
    return FormAsset(
      id: _asset,
      itemId: wrongItem ? 'another-item' : 'item',
      mimeType: 'image/png',
      byteLength: 9,
    );
  }

  @override
  Future<void> discardAsset(FormCommand<FormAssetIdPayload> command) async {
    discarded = command;
    discards++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _questionTarget = FormQuestionImageTarget(
  formId: 'form',
  formVersionId: 'version',
  itemId: 'item',
);

final class _QuestionApi implements FormsQuestionImageApi {
  int prepares = 0;
  String? deleted;
  FormQuestionImageTarget? finalizedTarget;
  String? finalizeRequestId;
  @override
  Future<FormAsset> finalizeQuestionImage(
    FormQuestionImageTarget target,
    FormCommand<FormAssetIdPayload> command,
  ) async {
    finalizedTarget = target;
    finalizeRequestId = command.requestId;
    return FormAsset(id: _asset, itemId: target.itemId, mimeType: 'image/png', byteLength: 9);
  }

  @override
  Future<FormAssetUploadTicket> prepareQuestionImage(
    FormQuestionImageTarget target, {
    required String requestId,
    required MediaUploadMetadata sourceMetadata,
  }) async {
    prepares++;
    return _Api(ticketNow: DateTime.now()).ticket;
  }

  @override
  Future<void> deleteQuestionImage(FormCommand<FormAssetIdPayload> command) async {
    deleted = command.payload.assetId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
