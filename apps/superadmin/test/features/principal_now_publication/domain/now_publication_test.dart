import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const context = NowPublicationContext.demo;

  test('plano-base permite vídeo de até 30 segundos', () {
    expect(context.capabilities.maxVideoDuration, const Duration(seconds: 30));
    expect(context.capabilities.accepts(const Duration(seconds: 30)), isTrue);
    expect(context.capabilities.accepts(const Duration(seconds: 31)), isFalse);
  });

  test('capacidade do plano pode ampliar o limite de vídeo', () {
    const capabilities = NowPlanCapabilities(maxVideoDuration: Duration(seconds: 90));
    expect(capabilities.accepts(const Duration(seconds: 75)), isTrue);
  });

  test('rascunho mantém uma única mídia e limita contexto a 60 caracteres', () {
    final media = NowMediaDraft.image(
      localId: 'media-1',
      name: 'foto.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    final draft = NowPublicationDraft().copyWith(
      media: media,
      caption: List.filled(61, 'a').join(),
    );

    expect(draft.media, same(media));
    expect(draft.validate(context), contains(NowPublicationIssue.captionTooLong));
  });

  test('publicação exige mídia, público e agendamento futuro', () {
    final draft = NowPublicationDraft(publishAt: DateTime(2026, 8, 20, 9));
    final issues = draft.validate(context, now: DateTime(2026, 8, 20, 10));

    expect(
      issues,
      containsAll(<NowPublicationIssue>[
        NowPublicationIssue.mediaRequired,
        NowPublicationIssue.audienceRequired,
        NowPublicationIssue.scheduleMustBeFuture,
      ]),
    );
  });

  test('vídeo exige metadado de duração verificável', () {
    final draft = NowPublicationDraft(
      media: NowMediaDraft.video(
        localId: 'video',
        name: 'agora.mp4',
        mimeType: 'video/mp4',
        bytes: Uint8List(1),
        duration: Duration.zero,
      ),
      audiences: const {NowAudience.families},
    );

    expect(draft.validate(context), contains(NowPublicationIssue.videoMetadataUnavailable));
  });

  test('áudio próprio exige confirmação de direitos', () {
    final draft = NowPublicationDraft(
      audio: NowAudioDraft(
        localId: 'audio-1',
        name: 'trilha.mp3',
        mimeType: 'audio/mpeg',
        bytes: Uint8List.fromList([1]),
      ),
    );

    expect(draft.validate(context), contains(NowPublicationIssue.audioRightsRequired));
  });

  test('um tipo de midia fora do contrato e recusado', () {
    // O Agora aceita imagem ou video. Um PDF ou um audio no lugar da midia nao
    // e "formato exotico": e conteudo que o visor nao sabe exibir e que o
    // gateway nao mediu.
    final draft = NowPublicationDraft(
      media: NowMediaDraft(
        localId: 'media-1',
        name: 'documento.pdf',
        mimeType: 'application/pdf',
        bytes: Uint8List.fromList([1]),
      ),
      audiences: const {NowAudience.families},
    );

    expect(
      draft.validate(NowPublicationContext.demo),
      contains(NowPublicationIssue.mediaTypeUnsupported),
    );
  });

  test('midia acima do limite de upload e recusada na borda', () {
    NowPublicationDraft draftWith(int bytes) => NowPublicationDraft(
      media: NowMediaDraft.image(
        localId: 'media-1',
        name: 'foto.png',
        mimeType: 'image/png',
        bytes: Uint8List(bytes),
      ),
      audiences: const {NowAudience.families},
    );

    expect(
      draftWith(nowMvpMaxUploadBytes).validate(NowPublicationContext.demo),
      isNot(contains(NowPublicationIssue.mediaTooLarge)),
    );
    expect(
      draftWith(nowMvpMaxUploadBytes + 1).validate(NowPublicationContext.demo),
      contains(NowPublicationIssue.mediaTooLarge),
      reason: 'um byte alem do limite ja recusa',
    );
  });

  test('video acima da capacidade do plano e recusado na borda', () {
    NowPublicationDraft draftWith(Duration duration) => NowPublicationDraft(
      media: NowMediaDraft.video(
        localId: 'media-1',
        name: 'clipe.mp4',
        mimeType: 'video/mp4',
        bytes: Uint8List.fromList([1]),
        duration: duration,
      ),
      audiences: const {NowAudience.families},
    );

    expect(
      draftWith(const Duration(seconds: 30)).validate(NowPublicationContext.demo),
      isNot(contains(NowPublicationIssue.videoTooLong)),
    );
    expect(
      draftWith(const Duration(seconds: 31)).validate(NowPublicationContext.demo),
      contains(NowPublicationIssue.videoTooLong),
      reason: 'o limite vem da capacidade do plano, nao de um numero fixo na tela',
    );
  });

  test('uma audiencia fora do permitido pelo contexto e recusada', () {
    // A guarda que importa aqui nao e "escolheu alguma audiencia": e "escolheu
    // uma que o contexto autorizado permite". Sem ela o cliente poderia mirar um
    // publico que o servidor nunca concedeu a este ator.
    final draft = NowPublicationDraft(
      media: NowMediaDraft.image(
        localId: 'media-1',
        name: 'foto.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1]),
      ),
      audiences: const {NowAudience.students},
    );

    expect(
      NowPublicationContext.demo.allowedAudiences.contains(NowAudience.students),
      isFalse,
      reason: 'precondicao: o contexto demo nao permite este publico',
    );
    expect(
      draft.validate(NowPublicationContext.demo),
      contains(NowPublicationIssue.audienceRequired),
    );
  });
}
