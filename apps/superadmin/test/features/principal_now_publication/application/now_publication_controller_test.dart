import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_now_publication/application/now_publication_controller.dart';
import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('edita ferramentas leves sem substituir a mídia', () async {
    final controller = NowPublicationController(
      repository: InMemoryNowPublicationRepository(),
      context: NowPublicationContext.demo,
    );
    await controller.load();
    controller.setMedia(
      NowMediaDraft.image(
        localId: '1',
        name: 'foto.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1]),
      ),
    );
    controller.setOverlayText('Aprendendo juntos');
    controller.setCrop(scale: 1.2, x: .1, y: -.1);
    controller.setCoverPosition(.4);

    expect(controller.state.draft.overlayText, 'Aprendendo juntos');
    expect(controller.state.draft.media?.cropScale, 1.2);
    expect(controller.state.draft.media?.coverPosition, .4);
  });

  test('publica depois de enviar mídia válida', () async {
    final repository = InMemoryNowPublicationRepository();
    final controller = NowPublicationController(
      repository: repository,
      context: NowPublicationContext.demo,
    );
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

    final result = await controller.publish();

    expect(result, isNotNull);
    expect(controller.state.phase, NowPublicationPhase.success);
    expect(repository.lastPublication, isNotNull);
  });

  test('não publica sem público e expõe mensagem em português', () async {
    final controller = NowPublicationController(
      repository: InMemoryNowPublicationRepository(),
      context: NowPublicationContext.demo,
    );
    await controller.load();
    controller.setMedia(
      NowMediaDraft.image(
        localId: '1',
        name: 'foto.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1]),
      ),
    );

    expect(await controller.publish(), isNull);
    expect(controller.state.message, 'Escolha o público e o contexto.');
  });

  test('retry após falha do áudio não reenvia mídia finalizada', () async {
    final repository = _FailAudioOnceRepository();
    final controller = NowPublicationController(
      repository: repository,
      context: NowPublicationContext.demo,
    );
    await controller.load();
    controller
      ..setMedia(
        NowMediaDraft.image(
          localId: 'media',
          name: 'foto.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList([1]),
        ),
      )
      ..setAudio(
        NowAudioDraft(
          localId: 'audio',
          name: 'trilha.mp3',
          mimeType: 'audio/mpeg',
          bytes: Uint8List.fromList([2]),
          rightsConfirmed: true,
        ),
      )
      ..toggleAudience(NowAudience.families);

    expect(await controller.publish(), isNull);
    expect(controller.state.draft.media?.remoteAssetId, isNotNull);
    expect(await controller.publish(), isNotNull);
    expect(repository.mediaUploads, 1);
    expect(repository.audioUploads, 2);
  });

  test('salvar rascunho envia mídia e áudio locais e mantém os vínculos remotos', () async {
    final repository = _CountingRepository();
    final controller = NowPublicationController(
      repository: repository,
      context: NowPublicationContext.demo,
    );
    await controller.load();
    controller
      ..setMedia(
        NowMediaDraft.image(
          localId: 'media',
          name: 'foto.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList([1]),
        ),
      )
      ..setAudio(
        NowAudioDraft(
          localId: 'audio',
          name: 'trilha.mp3',
          mimeType: 'audio/mpeg',
          bytes: Uint8List.fromList([2]),
          rightsConfirmed: true,
        ),
      );

    await controller.saveDraft();

    expect(repository.mediaUploads, 1);
    expect(repository.audioUploads, 1);
    expect(controller.state.draft.media?.remoteAssetId, 'media-media');
    expect(controller.state.draft.audio?.remoteAssetId, 'audio-audio');
    expect(controller.state.phase, NowPublicationPhase.saved);
  });

  test('retry ao salvar após falha do áudio não reenvia mídia finalizada', () async {
    final repository = _FailAudioOnceRepository();
    final controller = NowPublicationController(
      repository: repository,
      context: NowPublicationContext.demo,
    );
    await controller.load();
    controller
      ..setMedia(
        NowMediaDraft.image(
          localId: 'media',
          name: 'foto.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList([1]),
        ),
      )
      ..setAudio(
        NowAudioDraft(
          localId: 'audio',
          name: 'trilha.mp3',
          mimeType: 'audio/mpeg',
          bytes: Uint8List.fromList([2]),
          rightsConfirmed: true,
        ),
      );

    await controller.saveDraft();
    expect(controller.state.phase, NowPublicationPhase.failure);
    expect(controller.state.draft.media?.remoteAssetId, 'media-media');

    await controller.saveDraft();

    expect(repository.mediaUploads, 1);
    expect(repository.audioUploads, 2);
    expect(controller.state.phase, NowPublicationPhase.saved);
  });
}

final class _CountingRepository implements NowPublicationRepository {
  final delegate = InMemoryNowPublicationRepository();
  var mediaUploads = 0;
  var audioUploads = 0;

  @override
  Future<NowPublicationDraft?> loadDraft(NowPublicationContext context) =>
      delegate.loadDraft(context);

  @override
  Future<NowPublicationDraft> saveDraft(NowPublicationContext context, NowPublicationDraft draft) =>
      delegate.saveDraft(context, draft);

  @override
  Future<NowMediaDraft> uploadMedia(
    NowPublicationContext context,
    String publicationId,
    NowMediaDraft media,
  ) {
    mediaUploads++;
    return delegate.uploadMedia(context, publicationId, media);
  }

  @override
  Future<NowAudioDraft> uploadAudio(
    NowPublicationContext context,
    String publicationId,
    NowAudioDraft audio,
  ) {
    audioUploads++;
    return delegate.uploadAudio(context, publicationId, audio);
  }

  @override
  Future<NowPublication> publish(NowPublicationContext context, NowPublicationDraft draft) =>
      delegate.publish(context, draft);
}

final class _FailAudioOnceRepository implements NowPublicationRepository {
  final delegate = InMemoryNowPublicationRepository();
  var mediaUploads = 0;
  var audioUploads = 0;

  @override
  Future<NowPublicationDraft?> loadDraft(NowPublicationContext context) =>
      delegate.loadDraft(context);

  @override
  Future<NowPublicationDraft> saveDraft(NowPublicationContext context, NowPublicationDraft draft) =>
      delegate.saveDraft(context, draft);

  @override
  Future<NowMediaDraft> uploadMedia(
    NowPublicationContext context,
    String publicationId,
    NowMediaDraft media,
  ) {
    mediaUploads++;
    return delegate.uploadMedia(context, publicationId, media);
  }

  @override
  Future<NowAudioDraft> uploadAudio(
    NowPublicationContext context,
    String publicationId,
    NowAudioDraft audio,
  ) {
    audioUploads++;
    if (audioUploads == 1) throw Exception('temporary_audio_failure');
    return delegate.uploadAudio(context, publicationId, audio);
  }

  @override
  Future<NowPublication> publish(NowPublicationContext context, NowPublicationDraft draft) =>
      delegate.publish(context, draft);
}
