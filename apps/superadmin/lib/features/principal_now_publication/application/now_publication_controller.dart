import 'package:flutter/foundation.dart';

import '../domain/now_publication.dart';

enum _NowRetryAction { load, save, publish }

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
  var _loadGeneration = 0;
  var _editGeneration = 0;
  var _loadInFlight = false;
  var _commandInFlight = false;
  var _publishingIntent = false;
  var _disposed = false;
  _NowRetryAction? _retryAction;

  NowPublicationState get state => _state;

  Future<void> load() async {
    if (_disposed || _loadInFlight || _commandInFlight) return;
    final generation = ++_loadGeneration;
    _loadInFlight = true;
    _emit(_state.copyWith(phase: NowPublicationPhase.loading, clearMessage: true));
    try {
      final draft = await repository.loadDraft(context);
      if (!_isCurrentLoad(generation)) return;
      _emit(
        NowPublicationState(
          draft: draft ?? const NowPublicationDraft(),
          phase: NowPublicationPhase.editing,
        ),
      );
      _retryAction = null;
    } on NowPublicationUnauthorized {
      if (!_isCurrentLoad(generation)) return;
      _retryAction = null;
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.unauthorized,
          message: 'Você não pode publicar neste contexto.',
        ),
      );
    } on Exception {
      if (!_isCurrentLoad(generation)) return;
      _retryAction = _NowRetryAction.load;
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.failure,
          message: 'Não foi possível carregar o rascunho.',
        ),
      );
    } finally {
      _loadInFlight = false;
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
    if (_disposed || _loadInFlight || _commandInFlight) return;
    final snapshot = _state.draft;
    final generation = _editGeneration;
    _commandInFlight = true;
    _emit(_state.copyWith(phase: NowPublicationPhase.saving, clearMessage: true));
    try {
      var saved = await repository.saveDraft(context, snapshot);
      if (_disposed) return;
      _applyCheckpoint(saved, NowPublicationPhase.saving);
      final media = saved.media;
      if (media != null && media.remoteAssetId == null) {
        final publicationId = saved.id;
        if (publicationId == null) throw Exception('draft_id_required_for_upload');
        saved = saved.copyWith(media: await repository.uploadMedia(context, publicationId, media));
        if (_disposed) return;
        _applyCheckpoint(saved, NowPublicationPhase.saving);
      }
      final audio = saved.audio;
      if (audio != null && audio.remoteAssetId == null) {
        final publicationId = saved.id;
        if (publicationId == null) throw Exception('draft_id_required_for_upload');
        saved = saved.copyWith(audio: await repository.uploadAudio(context, publicationId, audio));
        if (_disposed) return;
        _applyCheckpoint(saved, NowPublicationPhase.saving);
      }
      if (generation == _editGeneration) {
        _emit(NowPublicationState(draft: saved, phase: NowPublicationPhase.saved));
      } else {
        _emit(
          NowPublicationState(
            draft: _mergeCheckpoint(_state.draft, saved),
            phase: NowPublicationPhase.editing,
          ),
        );
      }
      _retryAction = null;
    } on NowPublicationConflict {
      if (_disposed) return;
      _retryAction = _NowRetryAction.load;
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.conflict,
          message: 'O rascunho mudou. Recarregue e tente novamente.',
        ),
      );
    } on NowPublicationUnauthorized {
      if (_disposed) return;
      _retryAction = null;
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.unauthorized,
          message: 'Você não pode publicar neste contexto.',
        ),
      );
    } on Exception {
      if (_disposed) return;
      _retryAction = _NowRetryAction.save;
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.failure,
          message: 'Não foi possível salvar o rascunho.',
        ),
      );
    } finally {
      _commandInFlight = false;
    }
  }

  Future<NowPublication?> publish() async {
    if (_disposed || _loadInFlight || _commandInFlight) return null;
    final issues = _state.draft.validate(context);
    if (issues.isNotEmpty) {
      _emit(_state.copyWith(message: _messageFor(issues.first)));
      return null;
    }
    final snapshot = _state.draft;
    _commandInFlight = true;
    _publishingIntent = true;
    _emit(_state.copyWith(phase: NowPublicationPhase.uploading, clearMessage: true));
    try {
      var draft = snapshot;
      if (draft.id == null) {
        draft = await repository.saveDraft(context, draft);
        if (_disposed) return null;
        _applyCheckpoint(draft, NowPublicationPhase.uploading);
      }
      final publicationId = draft.id!;
      final media = draft.media!;
      if (media.remoteAssetId == null) {
        draft = draft.copyWith(media: await repository.uploadMedia(context, publicationId, media));
        if (_disposed) return null;
        _applyCheckpoint(draft, NowPublicationPhase.uploading);
      }
      final audio = draft.audio;
      if (audio != null && audio.remoteAssetId == null) {
        draft = draft.copyWith(audio: await repository.uploadAudio(context, publicationId, audio));
        if (_disposed) return null;
        _applyCheckpoint(draft, NowPublicationPhase.uploading);
      }
      _emit(NowPublicationState(draft: draft, phase: NowPublicationPhase.publishing));
      final result = await repository.publish(context, draft);
      if (_disposed) return null;
      _emit(NowPublicationState(draft: draft, phase: NowPublicationPhase.success));
      _retryAction = null;
      return result;
    } on NowPublicationConflict {
      if (_disposed) return null;
      _retryAction = _NowRetryAction.load;
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.conflict,
          message: 'O rascunho mudou. Recarregue e tente novamente.',
        ),
      );
    } on NowPublicationUnauthorized {
      if (_disposed) return null;
      _retryAction = null;
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.unauthorized,
          message: 'Você não pode publicar neste contexto.',
        ),
      );
    } on Exception {
      if (_disposed) return null;
      _retryAction = _NowRetryAction.publish;
      _emit(
        _state.copyWith(
          phase: NowPublicationPhase.failure,
          message: 'Não foi possível publicar no Agora.',
        ),
      );
    } finally {
      _publishingIntent = false;
      _commandInFlight = false;
    }
    return null;
  }

  Future<NowPublication?> retry() async {
    switch (_retryAction) {
      case _NowRetryAction.load:
        await load();
        return null;
      case _NowRetryAction.save:
        await saveDraft();
        return null;
      case _NowRetryAction.publish:
        return publish();
      case null:
        return null;
    }
  }

  void _edit(NowPublicationDraft draft) {
    if (_disposed || _loadInFlight || _publishingIntent) return;
    _editGeneration += 1;
    _retryAction = null;
    final phase = _commandInFlight ? _state.phase : NowPublicationPhase.editing;
    _emit(NowPublicationState(draft: draft, phase: phase));
  }

  bool _isCurrentLoad(int generation) => !_disposed && generation == _loadGeneration;

  void _applyCheckpoint(NowPublicationDraft checkpoint, NowPublicationPhase phase) {
    _emit(NowPublicationState(draft: _mergeCheckpoint(_state.draft, checkpoint), phase: phase));
  }

  NowPublicationDraft _mergeCheckpoint(
    NowPublicationDraft current,
    NowPublicationDraft checkpoint,
  ) {
    var merged = current.copyWith(id: checkpoint.id, version: checkpoint.version);
    final currentMedia = current.media;
    final checkpointMedia = checkpoint.media;
    if (currentMedia != null &&
        checkpointMedia != null &&
        currentMedia.localId == checkpointMedia.localId) {
      merged = merged.copyWith(
        media: currentMedia.copyWith(
          remoteAssetId: checkpointMedia.remoteAssetId,
          remoteUrl: checkpointMedia.remoteUrl,
        ),
      );
    }
    final currentAudio = current.audio;
    final checkpointAudio = checkpoint.audio;
    if (currentAudio != null &&
        checkpointAudio != null &&
        currentAudio.localId == checkpointAudio.localId) {
      merged = merged.copyWith(
        audio: currentAudio.copyWith(remoteAssetId: checkpointAudio.remoteAssetId),
      );
    }
    return merged;
  }

  void _emit(NowPublicationState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration += 1;
    _editGeneration += 1;
    super.dispose();
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
