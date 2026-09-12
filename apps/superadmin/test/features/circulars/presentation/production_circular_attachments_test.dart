import 'dart:typed_data';

import 'package:coelo_superadmin/features/circulars/domain/superadmin_circular_repository.dart';
import 'package:coelo_superadmin/features/circulars/presentation/production_circular_hosts.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/application/circular_media_upload_coordinator.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('invalid type or size is refused locally without touching the backend', (
    tester,
  ) async {
    final media = _RecordingMedia();
    final transfers = <Uri>[];
    await _pumpComposer(
      tester,
      media: media,
      transfers: transfers,
      picked: [
        _file('planilha.xlsx', 'application/vnd.ms-excel', 32),
        _file('cartaz.pdf', 'application/pdf', CircularLimits.pdfBytes + 1),
        _file('capa.png', 'image/jpeg', 64),
      ],
    );

    await tester.tap(find.byKey(const Key('circular-pick-files')));
    await tester.pumpAndSettle();

    expect(media.prepared, isEmpty);
    expect(media.finalized, isEmpty);
    expect(transfers, isEmpty);
    expect(find.byKey(const Key('circular-attachment-status')), findsOneWidget);
    expect(find.textContaining('Arquivo não aceito'), findsOneWidget);
  });

  testWidgets('valid selection runs prepare, transfer and finalize once', (tester) async {
    final media = _RecordingMedia();
    final transfers = <Uri>[];
    final host = await _pumpComposer(
      tester,
      media: media,
      transfers: transfers,
      picked: [_file('circular.png', 'image/png', 2048)],
    );

    await tester.tap(find.byKey(const Key('circular-pick-files')));
    await tester.pumpAndSettle();

    expect(media.prepared, ['circular.png']);
    expect(media.finalized, ['circular.png']);
    expect(transfers, hasLength(1));
    expect(find.text('Anexo enviado.'), findsOneWidget);
    expect(host.draft.blocks.whereType<CircularMediaBlock>().single.assetIds, ['asset-1']);
    // No storage address may reach the rendered surface.
    expect(find.textContaining('upload.example'), findsNothing);
  });

  testWidgets('failure in the middle keeps accepted attachments and reports no success', (
    tester,
  ) async {
    final media = _RecordingMedia(failFinalizeFrom: 2);
    final transfers = <Uri>[];
    final host = await _pumpComposer(
      tester,
      media: media,
      transfers: transfers,
      picked: [_file('um.png', 'image/png', 512), _file('dois.png', 'image/png', 512)],
    );

    await tester.tap(find.byKey(const Key('circular-pick-files')));
    await tester.pumpAndSettle();

    expect(media.prepared, ['um.png', 'dois.png']);
    expect(find.textContaining('1 de 2 enviado(s)'), findsOneWidget);
    expect(find.text('Anexo enviado.'), findsNothing);
    expect(host.draft.blocks.whereType<CircularMediaBlock>().single.assetIds, ['asset-1']);
  });

  testWidgets('denied media capability never reports a sent attachment', (tester) async {
    final media = _RecordingMedia(denyPrepare: true);
    final transfers = <Uri>[];
    final host = await _pumpComposer(
      tester,
      media: media,
      transfers: transfers,
      picked: [_file('circular.png', 'image/png', 512)],
    );

    await tester.tap(find.byKey(const Key('circular-pick-files')));
    await tester.pumpAndSettle();

    expect(transfers, isEmpty);
    expect(find.textContaining('não tem permissão'), findsOneWidget);
    expect(host.draft.blocks.whereType<CircularMediaBlock>(), isEmpty);
  });

  testWidgets('quota of four files is respected across selections', (tester) async {
    final media = _RecordingMedia();
    final transfers = <Uri>[];
    final host = await _pumpComposer(
      tester,
      media: media,
      transfers: transfers,
      picked: [
        for (var index = 0; index < CircularLimits.files + 2; index++)
          _file('anexo$index.png', 'image/png', 256),
      ],
    );

    await tester.tap(find.byKey(const Key('circular-pick-files')));
    await tester.pumpAndSettle();

    expect(media.prepared, hasLength(CircularLimits.files));
    expect(host.draft.blocks.whereType<CircularMediaBlock>(), hasLength(CircularLimits.files));
    expect(
      host.draft.blocks.whereType<CircularMediaBlock>().expand((block) => block.assetIds),
      hasLength(CircularLimits.files),
    );
    expect(find.textContaining('acima do limite de ${CircularLimits.files}'), findsOneWidget);

    // With the quota reached the composer stops offering a new selection.
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('circular-pick-files'))).onPressed,
      isNull,
    );
    expect(media.prepared, hasLength(CircularLimits.files));
  });

  testWidgets('two uploads become separate blocks after the chosen question', (tester) async {
    final host = await _pumpComposer(
      tester,
      media: _RecordingMedia(),
      transfers: <Uri>[],
      picked: [_file('antes.png', 'image/png', 256), _file('depois.png', 'image/png', 256)],
      initialBlocks: const [
        CircularTextBlock(id: 'text-before', text: 'Antes'),
        CircularQuestionBlock(
          id: 'question-middle',
          prompt: 'Pergunta?',
          kind: CircularQuestionKind.singleChoice,
          required: true,
          options: [
            CircularQuestionOption(id: 'yes', label: 'Sim'),
            CircularQuestionOption(id: 'no', label: 'Não'),
          ],
        ),
        CircularTextBlock(id: 'text-after', text: 'Depois'),
      ],
    );

    final addAfterQuestion = find.byKey(const Key('circular-pick-files-after-question-middle'));
    await tester.ensureVisible(addAfterQuestion);
    await tester.tap(addAfterQuestion);
    await tester.pumpAndSettle();

    expect(host.draft.blocks.map((block) => block.runtimeType), [
      CircularTextBlock,
      CircularQuestionBlock,
      CircularMediaBlock,
      CircularMediaBlock,
      CircularTextBlock,
    ]);
    expect(host.draft.blocks.whereType<CircularMediaBlock>(), hasLength(2));
    expect(
      host.draft.blocks.whereType<CircularMediaBlock>().map((block) => block.assetIds.single),
      ['asset-1', 'asset-2'],
    );
  });

  testWidgets('composition without media capability stays honestly unavailable', (tester) async {
    final transfers = <Uri>[];
    await _pumpComposer(tester, media: null, transfers: transfers, picked: const []);

    await tester.tap(find.byKey(const Key('circular-pick-files')));
    await tester.pumpAndSettle();

    expect(find.text('Envio de anexos indisponível nesta composição.'), findsOneWidget);
    expect(transfers, isEmpty);
  });
}

Future<_HostProbe> _pumpComposer(
  WidgetTester tester, {
  required _RecordingMedia? media,
  required List<Uri> transfers,
  required List<CircularSelectedFile> picked,
  List<CircularBlock> initialBlocks = const [CircularTextBlock(id: 'text-1', text: 'Conteúdo')],
}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repository = _DraftRepository(initialBlocks);
  final client = MockClient((request) async {
    transfers.add(request.url);
    return http.Response('', 200);
  });
  addTearDown(client.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: ProductionCircularComposerHost(
          repository: repository,
          institutionRepository: _UnusedInstitutions(),
          circularId: 'circular-1',
          onCancel: () {},
          onDone: () {},
          mediaRepository: media,
          mediaHttpClient: client,
          filePicker: () async => picked,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _HostProbe(repository);
}

final class _HostProbe {
  const _HostProbe(this.repository);
  final _DraftRepository repository;

  CircularDraft get draft => repository.lastSaved!;
}

CircularSelectedFile _file(String name, String mimeType, int bytes) => CircularSelectedFile(
  uploadRequestId: CircularMediaLimits.newRequestId(),
  name: name,
  mimeType: mimeType,
  bytes: Uint8List(bytes),
);

final class _DraftRepository implements SuperadminCircularRepository {
  _DraftRepository(this.initialBlocks);

  final List<CircularBlock> initialBlocks;
  CircularDraft? lastSaved;
  var _version = 1;

  @override
  Future<SuperadminCircularEditableDraft> loadDraftById(String circularId) async =>
      SuperadminCircularEditableDraft(
        scope: const CircularScope(institutionId: 'institution-1'),
        draft: CircularDraft(
          id: circularId,
          title: 'Circular privada',
          blocks: initialBlocks,
          expectedVersion: 1,
        ),
      );

  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) async {
    lastSaved = draft;
    return CircularSaveResult(
      id: draft.id.isEmpty ? 'circular-1' : draft.id,
      revisionId: 'revision-1',
      version: ++_version,
      status: CircularStatus.draft,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingMedia implements CircularMediaRepository {
  _RecordingMedia({this.failFinalizeFrom, this.denyPrepare = false});

  final int? failFinalizeFrom;
  final bool denyPrepare;
  final prepared = <String>[];
  final finalized = <String>[];

  @override
  Future<CircularMediaUploadIntent> prepare({
    required String requestId,
    required String institutionId,
    required String circularId,
    required String name,
    required String mimeType,
    required int byteSize,
  }) async {
    if (denyPrepare) throw const CircularUnauthorized();
    prepared.add(name);
    return CircularMediaUploadIntent(
      assetId: 'asset-${prepared.length}',
      uploadUrl: Uri.parse('https://upload.example/${prepared.length}'),
      requiredHeaders: const {},
      expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 300)),
      storageProvider: 'r2',
    );
  }

  @override
  Future<void> finalize({
    required String requestId,
    required String finalizeRequestId,
    required String institutionId,
    required String circularId,
    required CircularMediaUploadIntent intent,
    required String name,
    required String mimeType,
    required int byteSize,
    required int displayOrder,
    String? checksumSha256,
  }) async {
    if (failFinalizeFrom != null && prepared.length >= failFinalizeFrom!) {
      throw const CircularUnavailable();
    }
    finalized.add(name);
  }

  @override
  Future<CircularMediaReadTicket> resolveRead(String assetId) async =>
      throw const CircularUnavailable();

  @override
  Future<void> remove(String assetId) async {}
}

final class _UnusedInstitutions implements InstitutionDirectoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
