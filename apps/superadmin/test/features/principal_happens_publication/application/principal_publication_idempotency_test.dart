import 'package:coelo_superadmin/features/principal_happens_publication/application/happens_publication_controller.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/domain/happens_publication.dart';
import 'package:coelo_superadmin/features/principal_now_publication/application/now_publication_controller.dart';
import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Chave de idempotencia de publicacao para familias.
///
/// A chave era gerada dentro do repositorio, na hora da chamada. Com isso, uma
/// nova tentativa da MESMA publicacao chegava ao servidor como uma intencao
/// diferente, e nada impedia que a mesma publicacao saisse duas vezes para as
/// familias — em atualizacao a versao esperada barra a repeticao, em publicacao
/// nao ha nada barrando. A chave passou a pertencer a intencao, retida pelo
/// controlador entre tentativas e descartada quando a intencao muda ou e aceita.
///
/// Isto nao afirma que a RPC seja nao idempotente no servidor; afirma que o
/// cliente precisa conseguir reapresentar a mesma chave.
void main() {
  group('Acontece', () {
    test('repetir a mesma publicacao apos falha reapresenta a mesma chave', () async {
      final repository = _FailingHappensRepository(failures: 1);
      final controller = HappensPublicationController(
        repository: repository,
        context: HappensPublicationContext.demo,
      );
      addTearDown(controller.dispose);
      controller.setCaption('Passeio ao parque');
      controller.toggleAudience(HappensAudienceKind.families);

      expect(await controller.publish(), isNull, reason: 'a primeira tentativa falha');
      final published = await controller.publish();

      expect(published, isNotNull);
      expect(repository.publishRequestIds, hasLength(2));
      expect(repository.publishRequestIds.first, repository.publishRequestIds.last);
    });

    test('editar o rascunho torna a publicacao uma intencao nova', () async {
      final repository = _FailingHappensRepository(failures: 1);
      final controller = HappensPublicationController(
        repository: repository,
        context: HappensPublicationContext.demo,
      );
      addTearDown(controller.dispose);
      controller.setCaption('Passeio ao parque');
      controller.toggleAudience(HappensAudienceKind.families);

      expect(await controller.publish(), isNull);
      controller.setCaption('Passeio ao parque, com fotos');
      await controller.publish();

      expect(repository.publishRequestIds, hasLength(2));
      expect(
        repository.publishRequestIds.first,
        isNot(repository.publishRequestIds.last),
        reason: 'conteudo diferente nao pode reusar a chave do conteudo anterior',
      );
    });

    test('duas publicacoes aceitas em sequencia usam chaves diferentes', () async {
      final repository = _FailingHappensRepository(failures: 0);
      final controller = HappensPublicationController(
        repository: repository,
        context: HappensPublicationContext.demo,
      );
      addTearDown(controller.dispose);
      controller.setCaption('Primeira');
      controller.toggleAudience(HappensAudienceKind.families);
      await controller.publish();
      controller.setCaption('Segunda');
      await controller.publish();

      expect(repository.publishRequestIds, hasLength(2));
      expect(repository.publishRequestIds.first, isNot(repository.publishRequestIds.last));
    });
  });

  group('Agora', () {
    test('repetir a mesma publicacao apos falha reapresenta a mesma chave', () async {
      final repository = _FailingNowRepository(failures: 1);
      final controller = NowPublicationController(
        repository: repository,
        context: NowPublicationContext.demo,
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller
        ..setMedia(
          NowMediaDraft.image(
            localId: '1',
            name: 'foto.png',
            mimeType: 'image/png',
            bytes: Uint8List.fromList([1]),
          ),
        )
        ..toggleAudience(NowAudience.families);

      await controller.publish();
      await controller.publish();

      expect(repository.publishRequestIds, hasLength(2));
      expect(repository.publishRequestIds.first, repository.publishRequestIds.last);
    });
  });
}

/// Repositorio de teste que falha um numero definido de vezes e registra a
/// chave de idempotencia de cada tentativa. Delega o resto ao repositorio em
/// memoria de producao, para exercitar o mesmo caminho que a composicao usa.
final class _FailingHappensRepository implements HappensPublicationRepository {
  _FailingHappensRepository({required this.failures});

  int failures;
  final _inner = InMemoryHappensPublicationRepository();
  final publishRequestIds = <String>[];

  @override
  Future<HappensPostDraft?> loadDraft(HappensPublicationContext context) =>
      _inner.loadDraft(context);

  @override
  Future<HappensPostDraft> saveDraft(HappensPublicationContext context, HappensPostDraft draft) =>
      _inner.saveDraft(context, draft);

  @override
  Future<HappensUploadIntent> prepareMedia(
    HappensPublicationContext context,
    String postId,
    HappensMediaDraft media,
    int displayOrder,
  ) => _inner.prepareMedia(context, postId, media, displayOrder);

  @override
  Future<HappensMediaDraft> finalizeMedia(HappensUploadIntent intent, HappensMediaDraft media) =>
      _inner.finalizeMedia(intent, media);

  @override
  Future<void> removeMedia(HappensPublicationContext context, HappensMediaDraft media) =>
      _inner.removeMedia(context, media);

  @override
  Future<HappensPublication> publish(
    HappensPublicationContext context,
    HappensPostDraft draft, {
    required String requestId,
  }) {
    publishRequestIds.add(requestId);
    if (failures > 0) {
      failures -= 1;
      return Future.error(Exception('transient'));
    }
    return _inner.publish(context, draft, requestId: requestId);
  }
}

final class _FailingNowRepository implements NowPublicationRepository {
  _FailingNowRepository({required this.failures});

  int failures;
  final _inner = InMemoryNowPublicationRepository();
  final publishRequestIds = <String>[];

  @override
  Future<NowPublicationDraft?> loadDraft(NowPublicationContext context) =>
      _inner.loadDraft(context);

  @override
  Future<NowPublicationDraft> saveDraft(
    NowPublicationContext context,
    NowPublicationDraft draft,
  ) => _inner.saveDraft(context, draft);

  @override
  Future<NowMediaDraft> uploadMedia(
    NowPublicationContext context,
    String publicationId,
    NowMediaDraft media,
  ) => _inner.uploadMedia(context, publicationId, media);

  @override
  Future<NowAudioDraft> uploadAudio(
    NowPublicationContext context,
    String publicationId,
    NowAudioDraft audio,
  ) => _inner.uploadAudio(context, publicationId, audio);

  @override
  Future<NowPublication> publish(
    NowPublicationContext context,
    NowPublicationDraft draft, {
    required String requestId,
  }) {
    publishRequestIds.add(requestId);
    if (failures > 0) {
      failures -= 1;
      return Future.error(Exception('transient'));
    }
    return _inner.publish(context, draft, requestId: requestId);
  }
}
