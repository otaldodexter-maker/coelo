import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import '../domain/moments_publication.dart';

@immutable
final class MomentsPublicationState {
  const MomentsPublicationState({
    required this.draft,
    this.phase = MomentsPublicationPhase.initial,
    this.message,
  });

  final MomentsDraft draft;
  final MomentsPublicationPhase phase;
  final String? message;

  MomentsPublicationState copyWith({
    MomentsDraft? draft,
    MomentsPublicationPhase? phase,
    String? message,
    bool clearMessage = false,
  }) => MomentsPublicationState(
    draft: draft ?? this.draft,
    phase: phase ?? this.phase,
    message: clearMessage ? null : (message ?? this.message),
  );
}

final class MomentsPublicationController extends ChangeNotifier {
  MomentsPublicationController({required this.repository, required this.context})
    : _state = MomentsPublicationState(draft: MomentsDraft());

  static const maxCaptionCharacters = 2200;
  static const maxMedia = 5;

  final MomentsPublicationRepository repository;
  final MomentsPublicationContext context;
  MomentsPublicationState _state;

  MomentsPublicationState get state => _state;

  Future<void> load() async {
    _emit(_state.copyWith(phase: MomentsPublicationPhase.loading, clearMessage: true));
    try {
      final draft = await repository.loadDraft(context);
      _emit(
        _state.copyWith(draft: draft ?? MomentsDraft(), phase: MomentsPublicationPhase.editing),
      );
    } on Exception {
      _emit(
        _state.copyWith(
          phase: MomentsPublicationPhase.failure,
          message: 'Não foi possível carregar o rascunho.',
        ),
      );
    }
  }

  void setCaption(String value) {
    final caption = value.characters.take(maxCaptionCharacters).toString();
    _edit(_state.draft.copyWith(caption: caption));
  }

  void toggleAudience(MomentsAudienceKind kind) {
    final audiences = {..._state.draft.audiences};
    audiences.contains(kind) ? audiences.remove(kind) : audiences.add(kind);
    _edit(_state.draft.copyWith(audiences: audiences));
  }

  void setSaveAsDraft(bool value) => _edit(_state.draft.copyWith(saveAsDraft: value));

  void addMedia(MomentsMediaDraft media) {
    if (_state.draft.media.length >= maxMedia) {
      _emit(_state.copyWith(message: 'Você pode adicionar até 5 mídias.'));
      return;
    }
    _edit(_state.draft.copyWith(media: [..._state.draft.media, media]));
  }

  void removeMedia(int index) {
    final media = [..._state.draft.media]..removeAt(index);
    _edit(_state.draft.copyWith(media: media));
  }

  void reorderMedia(int oldIndex, int newIndex) {
    final media = [..._state.draft.media];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = media.removeAt(oldIndex);
    media.insert(newIndex, item);
    _edit(_state.draft.copyWith(media: media));
  }

  Future<void> saveDraft() async {
    _emit(_state.copyWith(phase: MomentsPublicationPhase.saving, clearMessage: true));
    try {
      final saved = await repository.saveDraft(context, _state.draft);
      _emit(_state.copyWith(draft: saved, phase: MomentsPublicationPhase.saved));
    } on MomentsPublicationConflict {
      _emit(
        _state.copyWith(
          phase: MomentsPublicationPhase.conflict,
          message: 'O rascunho mudou. Recarregue e tente novamente.',
        ),
      );
    } on MomentsPublicationUnauthorized {
      _emit(
        _state.copyWith(
          phase: MomentsPublicationPhase.unauthorized,
          message: 'Você não pode publicar neste contexto.',
        ),
      );
    } on Exception {
      _emit(
        _state.copyWith(
          phase: MomentsPublicationPhase.failure,
          message: 'Não foi possível salvar o rascunho.',
        ),
      );
    }
  }

  Future<MomentsPublication?> publish() async {
    if (_state.draft.media.isEmpty) {
      _emit(_state.copyWith(message: 'Adicione pelo menos uma mídia para publicar.'));
      return null;
    }
    if (_state.draft.audiences.isEmpty) {
      _emit(_state.copyWith(message: 'Escolha pelo menos um público.'));
      return null;
    }
    _emit(_state.copyWith(phase: MomentsPublicationPhase.publishing, clearMessage: true));
    try {
      final publication = await repository.publish(context, _state.draft);
      _emit(_state.copyWith(phase: MomentsPublicationPhase.success));
      return publication;
    } on MomentsPublicationConflict {
      _emit(
        _state.copyWith(
          phase: MomentsPublicationPhase.conflict,
          message: 'O rascunho mudou. Recarregue e tente novamente.',
        ),
      );
    } on MomentsPublicationUnauthorized {
      _emit(
        _state.copyWith(
          phase: MomentsPublicationPhase.unauthorized,
          message: 'Você não pode publicar neste contexto.',
        ),
      );
    } on Exception {
      _emit(
        _state.copyWith(
          phase: MomentsPublicationPhase.failure,
          message: 'Não foi possível publicar agora.',
        ),
      );
    }
    return null;
  }

  void _edit(MomentsDraft draft) {
    _emit(
      _state.copyWith(draft: draft, phase: MomentsPublicationPhase.editing, clearMessage: true),
    );
  }

  void _emit(MomentsPublicationState state) {
    _state = state;
    notifyListeners();
  }
}
