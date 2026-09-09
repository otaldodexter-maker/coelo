import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A leitura de Circular só abre anexo se a capacidade de mídia atravessar a
/// página de detalhe até o leitor. Sem esse repasse o leitor fica honestamente
/// fechado — o que é correto como exceção, mas não pode ser o caminho normal.
void main() {
  testWidgets('the detail page hands the media capability to the reader', (tester) async {
    final media = _FakeMedia();
    await _pumpDetail(tester, media: media);

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();

    expect(media.requested, ['asset-1'], reason: 'the reader resolved through the injected capability');
  });

  testWidgets('without the capability the attachment stays closed and asks nothing', (
    tester,
  ) async {
    final media = _FakeMedia();
    await _pumpDetail(tester, media: null);

    expect(media.requested, isEmpty);
    expect(find.byType(Image), findsNothing);
  });
}

Future<void> _pumpDetail(WidgetTester tester, {required CircularMediaRepository? media}) async {
  await tester.binding.setSurfaceSize(const Size(1024, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: PrincipalCircularDetailPage(
        circularId: 'circular-1',
        repository: _Repository(),
        responseRepository: _ResponseRepository(),
        mediaRepository: media,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _FakeMedia implements CircularMediaRepository {
  final requested = <String>[];

  @override
  Future<CircularMediaReadTicket> resolveRead(String assetId) async {
    requested.add(assetId);
    return CircularMediaReadTicket(
      assetId: assetId,
      url: Uri.parse('https://storage.example/opaque'),
      mimeType: 'application/pdf',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 2)),
      name: 'circular-agosto.pdf',
      byteSize: 2 * 1024 * 1024,
    );
  }

  @override
  Future<CircularMediaUploadIntent> prepare({
    required String requestId,
    required String institutionId,
    required String circularId,
    required String name,
    required String mimeType,
    required int byteSize,
  }) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Future<void> remove(String assetId) => throw UnimplementedError();
}

final class _Repository implements CircularRepository {
  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) async =>
      CircularDetail(
        id: 'circular-1',
        revisionId: 'revision-1',
        title: 'Renovação de matrícula',
        authorName: 'Colégio Coelo',
        contextLabel: 'Ensino Fundamental',
        publishedAt: DateTime.utc(2026, 8, 21),
        status: CircularStatus.published,
        responseState: CircularResponseState.unanswered,
        blocks: const [
          CircularTextBlock(id: 'text-1', text: 'Confirme a renovação.'),
          CircularMediaBlock(id: 'media-1', assetIds: ['asset-1']),
        ],
      );

  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) => throw UnimplementedError();
  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) => throw UnimplementedError();
  @override
  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  }) => throw UnimplementedError();
  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) => throw UnimplementedError();
  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) => throw UnimplementedError();
}

final class _ResponseRepository implements CircularResponseRepository {
  @override
  Future<CircularResponseSaveResult> saveDraft({
    required String requestId,
    required String revisionId,
    required String? childContextId,
    required Map<String, List<String>> answers,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<CircularResponseSaveResult> submit({
    required String requestId,
    required String sessionId,
    required int expectedVersion,
  }) => throw UnimplementedError();
}
