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
  var _loadGeneration = 0;
  var _editGeneration = 0;
  var _loadInFlight = false;
  var _commandInFlight = false;
  var _disposed = false;

  MomentsPublicationState get state => _state;

  Future<void> load() async {
    if (_disposed || _loadInFlight || _commandInFlight) return;
    final generation = ++_loadGeneration;
    _loadInFlight = true;
    _emit(_state.copyWith(phase: MomentsPublicationPhase.loading, clearMessage: true));
    try {
      final draft = await repository.loadDraft(context);
      if (!_isCurrentLoad(generation)) return;
      _emit(
        _state.copyWith(draft: draft ?? MomentsDraft(), phase: MomentsPublicationPhase.editing),
      );
    } on Exception {
      if (!_isCurrentLoad(generation)) return;
      _emit(
        _state.copyWith(
          phase: MomentsPublicationPhase.failure,
          message: 'Não foi possível carregar o rascunho.',
        ),
      );
    } finally {
      _loadInFlight = false;
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
    if (_disposed || _loadInFlight || _commandInFlight) return;
    final draft = _state.draft;
    final generation = _editGeneration;
    _commandInFlight = true;
    _emit(_state.copyWith(phase: MomentsPublicationPhase.saving, clearMessage: true));
    try {
      final saved = await repository.saveDraft(context, draft);
      if (_disposed) return;
      if (!_isCurrentCommand(generation)) {
        _emit(
          _state.copyWith(
            draft: _state.draft.copyWith(id: saved.id, version: saved.version),
            phase: MomentsPublicationPhase.editing,
            clearMessage: true,
          ),
        );
        return;
      }
      _emit(_state.copyWith(draft: saved, phase: MomentsPublicationPhase.saved));
    } on MomentsPublicationConflict {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          phase: MomentsPublicationPhase.conflict,
          message: 'O rascunho mudou. Recarregue e tente novamente.',
        ),
      );
    } on MomentsPublicationUnauthorized {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          phase: MomentsPublicationPhase.unauthorized,
          message: 'Você não pode publicar neste contexto.',
        ),
      );
    } on Exception {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          phase: MomentsPublicationPhase.failure,
          message: 'Não foi possível salvar o rascunho.',
        ),
      );
    } finally {
      _commandInFlight = false;
    }
  }

  Future<MomentsPublication?> publish() async {
    if (_disposed || _loadInFlight || _commandInFlight) return null;
    if (_state.draft.media.isEmpty) {
      _emit(_state.copyWith(message: 'Adicione pelo menos uma mídia para publicar.'));
      return null;
    }
    if (_state.draft.audiences.isEmpty) {
      _emit(_state.copyWith(message: 'Escolha pelo menos um público.'));
      return null;
    }
    final draft = _state.draft;
    _commandInFlight = true;
    _emit(_state.copyWith(phase: MomentsPublicationPhase.publishing, clearMessage: true));
    try {
      final publication = await repository.publish(context, draft);
      if (_disposed) return null;
      _emit(_state.copyWith(phase: MomentsPublicationPhase.success));
      return publication;
    } on MomentsPublicationConflict {
      if (_disposed) return null;
      _emit(
        _state.copyWith(
          phase: MomentsPublicationPhase.conflict,
          message: 'O rascunho mudou. Recarregue e tente novamente.',
        ),
      );
    } on MomentsPublicationUnauthorized {
      if (_disposed) return null;
      _emit(
        _state.copyWith(
          phase: MomentsPublicationPhase.unauthorized,
          message: 'Você não pode publicar neste contexto.',
        ),
      );
    } on Exception {
      if (_disposed) return null;
      _emit(
        _state.copyWith(
          phase: MomentsPublicationPhase.failure,
          message: 'Não foi possível publicar agora.',
        ),
      );
    } finally {
      _commandInFlight = false;
    }
    return null;
  }

  void _edit(MomentsDraft draft) {
    if (_disposed || _loadInFlight || _state.phase == MomentsPublicationPhase.publishing) {
      return;
    }
    _editGeneration += 1;
    _loadGeneration += 1;
    final phase = _commandInFlight ? _state.phase : MomentsPublicationPhase.editing;
    _emit(_state.copyWith(draft: draft, phase: phase, clearMessage: true));
  }

  bool _isCurrentLoad(int generation) => !_disposed && generation == _loadGeneration;

  bool _isCurrentCommand(int generation) => !_disposed && generation == _editGeneration;

  void _emit(MomentsPublicationState state) {
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
