import 'package:flutter/foundation.dart';

import '../domain/now_publication.dart';

@immutable
final class NowPublicationState {
  const NowPublicationState({
    required this.draft,
    this.phase = NowPublicationPhase.initial,
    this.message,
  });

  final NowPublicationDraft draft;
  final NowPublicationPhase phase;
  final String? message;

  NowPublicationState copyWith({
    NowPublicationDraft? draft,
    NowPublicationPhase? phase,
    String? message,
    bool clearMessage = false,
  }) => NowPublicationState(
    draft: draft ?? this.draft,
    phase: phase ?? this.phase,
    message: clearMessage ? null : (message ?? this.message),
  );
}

final class NowPublicationController extends ChangeNotifier {
  NowPublicationController({required this.repository, required this.context})
    : _state = const NowPublicationState(draft: NowPublicationDraft());

  final NowPublicationRepository repository;
  final NowPublicationContext context;
  NowPublicationState _state;

  NowPublicationState get state => _state;

  Future<void> load() async {
    _emit(_state.copyWith(phase: NowPublicationPhase.loading, clearMessage: true));
    try {
      final draft = await repository.loadDraft(context);
      _emit(
        NowPublicationState(
          draft: draft ?? const NowPublicationDraft(),
          phase: NowPublicationPhase.editing,
        ),
      );
    } on NowPublicationUnauthorized {
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.unauthorized,
          message: 'Você não pode publicar neste contexto.',
        ),
      );
    } on Exception {
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.failure,
          message: 'Não foi possível carregar o rascunho.',
        ),
      );
    }
  }

  void setMedia(NowMediaDraft media) => _edit(_state.draft.copyWith(media: media));
  void removeMedia() => _edit(_state.draft.copyWith(clearMedia: true));
  void setAudio(NowAudioDraft audio) => _edit(_state.draft.copyWith(audio: audio));
  void removeAudio() => _edit(_state.draft.copyWith(clearAudio: true));
  void confirmAudioRights(bool confirmed) {
    final audio = _state.draft.audio;
    if (audio != null) {
      _edit(_state.draft.copyWith(audio: audio.copyWith(rightsConfirmed: confirmed)));
    }
  }

  void setCaption(String value) => _edit(_state.draft.copyWith(caption: value));
  void setOverlayText(String value) => _edit(_state.draft.copyWith(overlayText: value));
  void setCrop({required double scale, required double x, required double y}) {
    final media = _state.draft.media;
    if (media != null) {
      _edit(
        _state.draft.copyWith(
          media: media.copyWith(cropScale: scale, cropX: x, cropY: y),
        ),
      );
    }
  }

  void setCoverPosition(double value) {
    final media = _state.draft.media;
    if (media != null) {
      _edit(_state.draft.copyWith(media: media.copyWith(coverPosition: value)));
    }
  }

  void toggleAudience(NowAudience audience) {
    final audiences = {..._state.draft.audiences};
    audiences.contains(audience) ? audiences.remove(audience) : audiences.add(audience);
    _edit(_state.draft.copyWith(audiences: audiences));
  }

  void setPublishAt(DateTime? value) =>
      _edit(_state.draft.copyWith(publishAt: value, clearPublishAt: value == null));

  Future<void> saveDraft() async {
    _emit(_state.copyWith(phase: NowPublicationPhase.saving, clearMessage: true));
    try {
      var saved = await repository.saveDraft(context, _state.draft);
      final media = saved.media;
      if (media != null && media.remoteAssetId == null) {
        final publicationId = saved.id;
        if (publicationId == null) throw Exception('draft_id_required_for_upload');
        saved = saved.copyWith(media: await repository.uploadMedia(context, publicationId, media));
        _emit(NowPublicationState(draft: saved, phase: NowPublicationPhase.saving));
      }
      final audio = saved.audio;
      if (audio != null && audio.remoteAssetId == null) {
        final publicationId = saved.id;
        if (publicationId == null) throw Exception('draft_id_required_for_upload');
        saved = saved.copyWith(audio: await repository.uploadAudio(context, publicationId, audio));
        _emit(NowPublicationState(draft: saved, phase: NowPublicationPhase.saving));
      }
      _emit(NowPublicationState(draft: saved, phase: NowPublicationPhase.saved));
    } on NowPublicationConflict {
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.conflict,
          message: 'O rascunho mudou. Recarregue e tente novamente.',
        ),
      );
    } on NowPublicationUnauthorized {
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.unauthorized,
          message: 'Você não pode publicar neste contexto.',
        ),
      );
    } on Exception {
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.failure,
          message: 'Não foi possível salvar o rascunho.',
        ),
      );
    }
  }

  Future<NowPublication?> publish() async {
    final issues = _state.draft.validate(context);
    if (issues.isNotEmpty) {
      _emit(_state.copyWith(message: _messageFor(issues.first)));
      return null;
    }
    _emit(_state.copyWith(phase: NowPublicationPhase.uploading, clearMessage: true));
    try {
      var draft = _state.draft;
      if (draft.id == null) {
        draft = await repository.saveDraft(context, draft);
      }
      final publicationId = draft.id!;
      final media = draft.media!;
      if (media.remoteAssetId == null) {
        draft = draft.copyWith(media: await repository.uploadMedia(context, publicationId, media));
        _emit(NowPublicationState(draft: draft, phase: NowPublicationPhase.uploading));
      }
      final audio = draft.audio;
      if (audio != null && audio.remoteAssetId == null) {
        draft = draft.copyWith(audio: await repository.uploadAudio(context, publicationId, audio));
        _emit(NowPublicationState(draft: draft, phase: NowPublicationPhase.uploading));
      }
      _emit(NowPublicationState(draft: draft, phase: NowPublicationPhase.publishing));
      final result = await repository.publish(context, draft);
      _emit(NowPublicationState(draft: draft, phase: NowPublicationPhase.success));
      return result;
    } on NowPublicationConflict {
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.conflict,
          message: 'O rascunho mudou. Recarregue e tente novamente.',
        ),
      );
    } on NowPublicationUnauthorized {
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.unauthorized,
          message: 'Você não pode publicar neste contexto.',
        ),
      );
    } on Exception {
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.failure,
          message: 'Não foi possível publicar no Agora.',
        ),
      );
    }
    return null;
  }

  void _edit(NowPublicationDraft draft) =>
      _emit(NowPublicationState(draft: draft, phase: NowPublicationPhase.editing));

  void _emit(NowPublicationState state) {
    _state = state;
    notifyListeners();
  }
}

String _messageFor(NowPublicationIssue issue) => switch (issue) {
  NowPublicationIssue.mediaRequired => 'Adicione uma imagem ou um vídeo.',
  NowPublicationIssue.mediaTypeUnsupported => 'Escolha uma imagem ou um vídeo compatível.',
  NowPublicationIssue.videoMetadataUnavailable =>
    'Não foi possível verificar a duração deste vídeo.',
  NowPublicationIssue.videoTooLong => 'O vídeo ultrapassa o limite do seu plano.',
  NowPublicationIssue.mediaTooLarge => 'O arquivo pode ter no máximo 25 MB.',
  NowPublicationIssue.captionTooLong => 'O texto pode ter até 60 caracteres.',
  NowPublicationIssue.audienceRequired => 'Escolha o público e o contexto.',
  NowPublicationIssue.scheduleMustBeFuture => 'Escolha uma data e hora futuras.',
  NowPublicationIssue.audioRightsRequired => 'Confirme que você pode usar este áudio.',
};
