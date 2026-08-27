import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/happens_publication.dart';

@immutable
final class HappensPublicationState {
  const HappensPublicationState({
    required this.draft,
    this.phase = HappensPublicationPhase.initial,
    this.autosave = false,
    this.message,
  });

  final HappensPostDraft draft;
  final HappensPublicationPhase phase;
  final bool autosave;
  final String? message;

  HappensPublicationState copyWith({
    HappensPostDraft? draft,
    HappensPublicationPhase? phase,
    bool? autosave,
    String? message,
    bool clearMessage = false,
  }) => HappensPublicationState(
    draft: draft ?? this.draft,
    phase: phase ?? this.phase,
    autosave: autosave ?? this.autosave,
    message: clearMessage ? null : (message ?? this.message),
  );
}

final class HappensPublicationController extends ChangeNotifier {
  HappensPublicationController({
    required this.repository,
    required this.context,
    this.autosaveDelay = const Duration(milliseconds: 500),
  }) : _state = HappensPublicationState(draft: HappensPostDraft());

  final HappensPublicationRepository repository;
  final HappensPublicationContext context;
  final Duration autosaveDelay;
  HappensPublicationState _state;
  Timer? _autosaveTimer;
  var _operationInFlight = false;

  HappensPublicationState get state => _state;
  bool get operationInFlight => _operationInFlight;

  Future<void> load() async {
    _emit(_state.copyWith(phase: HappensPublicationPhase.loading, clearMessage: true));
    try {
      final draft = await repository.loadDraft(context);
      _emit(
        _state.copyWith(draft: draft ?? HappensPostDraft(), phase: HappensPublicationPhase.editing),
      );
    } on HappensPublicationUnauthorized {
      _emit(
        _state.copyWith(
          phase: HappensPublicationPhase.unauthorized,
          message: 'Você não pode publicar neste contexto.',
        ),
      );
    } on Exception {
      _emit(
        _state.copyWith(
          phase: HappensPublicationPhase.failure,
          message: 'Não foi possível carregar o rascunho.',
        ),
      );
    }
  }

  void setCaption(String value) => _edit(_state.draft.copyWith(caption: value));

  void setAutosave(bool value) {
    if (_operationInFlight) return;
    if (!value) _autosaveTimer?.cancel();
    _emit(_state.copyWith(autosave: value, phase: HappensPublicationPhase.editing));
    if (value) _scheduleAutosave();
  }

  void toggleAudience(HappensAudienceKind kind) {
    final audiences = {..._state.draft.audiences};
    audiences.contains(kind) ? audiences.remove(kind) : audiences.add(kind);
    _edit(_state.draft.copyWith(audiences: audiences));
  }

  void setPublishAt(DateTime? value) =>
      _edit(_state.draft.copyWith(publishAt: value, clearPublishAt: value == null));

  void addMedia(HappensMediaDraft media) {
    if (_state.draft.media.length >= 6) {
      _emit(_state.copyWith(message: 'Você pode adicionar até 6 mídias.'));
      return;
    }
    _edit(_state.draft.copyWith(media: [..._state.draft.media, media]));
  }

  Future<void> removeMedia(int index) async {
    if (_operationInFlight) return;
    final media = _state.draft.media[index];
    try {
      await repository.removeMedia(context, media);
      final items = [..._state.draft.media]..removeAt(index);
      _edit(_state.draft.copyWith(media: items));
    } on Exception {
      _emit(
        _state.copyWith(
          phase: HappensPublicationPhase.failure,
          message: 'Não foi possível remover a mídia.',
        ),
      );
    }
  }

  void reorderMedia(int oldIndex, int newIndex) {
    final items = [..._state.draft.media];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    _edit(_state.draft.copyWith(media: items));
  }

  Future<void> saveDraft() async {
    if (_operationInFlight || !_acceptsOperation(_state.phase)) return;
    _operationInFlight = true;
    _autosaveTimer?.cancel();
    _emit(_state.copyWith(phase: HappensPublicationPhase.autosaving, clearMessage: true));
    try {
      final saved = await repository.saveDraft(context, _state.draft);
      _emit(_state.copyWith(draft: saved, phase: HappensPublicationPhase.saved));
    } on HappensPublicationConflict {
      _emit(
        _state.copyWith(
          phase: HappensPublicationPhase.conflict,
          message: 'O rascunho mudou. Recarregue e tente novamente.',
        ),
      );
    } on HappensPublicationUnauthorized {
      _emit(
        _state.copyWith(
          phase: HappensPublicationPhase.unauthorized,
          message: 'Você não pode publicar neste contexto.',
        ),
      );
    } on Exception {
      _emit(
        _state.copyWith(
          phase: HappensPublicationPhase.failure,
          message: 'Não foi possível salvar o rascunho.',
        ),
      );
    } finally {
      _operationInFlight = false;
      notifyListeners();
    }
  }

  Future<HappensPublication?> publish() async {
    if (_operationInFlight || !_acceptsOperation(_state.phase)) return null;
    _autosaveTimer?.cancel();
    if (_state.draft.caption.trim().isEmpty && _state.draft.media.isEmpty) {
      _emit(_state.copyWith(message: 'Adicione uma legenda ou mídia para publicar.'));
      return null;
    }
    if (_state.draft.audiences.isEmpty) {
      _emit(_state.copyWith(message: 'Escolha pelo menos um público.'));
      return null;
    }
    _operationInFlight = true;
    _emit(_state.copyWith(phase: HappensPublicationPhase.publishing, clearMessage: true));
    try {
      var preparedDraft = await repository.saveDraft(context, _state.draft);
      final uploaded = [...preparedDraft.media];
      for (var index = 0; index < preparedDraft.media.length; index++) {
        final media = preparedDraft.media[index];
        if (media.assetId != null) continue;
        _emit(_state.copyWith(phase: HappensPublicationPhase.uploading));
        final intent = await repository.prepareMedia(context, preparedDraft.id!, media, index);
        uploaded[index] = await repository.finalizeMedia(intent, media);
        preparedDraft = preparedDraft.copyWith(media: uploaded);
        _emit(_state.copyWith(draft: preparedDraft, phase: HappensPublicationPhase.uploading));
      }
      final result = await repository.publish(context, preparedDraft);
      _emit(
        _state.copyWith(
          draft: preparedDraft,
          phase: result.status == HappensPostStatus.scheduled
              ? HappensPublicationPhase.scheduled
              : HappensPublicationPhase.success,
        ),
      );
      return result;
    } on HappensPublicationConflict {
      _emit(
        _state.copyWith(
          phase: HappensPublicationPhase.conflict,
          message: 'O rascunho mudou. Recarregue e tente novamente.',
        ),
      );
    } on HappensPublicationUnauthorized {
      _emit(
        _state.copyWith(
          phase: HappensPublicationPhase.unauthorized,
          message: 'Você não pode publicar neste contexto.',
        ),
      );
    } on Exception {
      _emit(
        _state.copyWith(
          phase: HappensPublicationPhase.failure,
          message: 'Não foi possível publicar agora.',
        ),
      );
    } finally {
      _operationInFlight = false;
      notifyListeners();
    }
    return null;
  }

  void _edit(HappensPostDraft draft) {
    if (_operationInFlight) return;
    _emit(
      _state.copyWith(draft: draft, phase: HappensPublicationPhase.editing, clearMessage: true),
    );
    if (_state.autosave) _scheduleAutosave();
  }

  bool _acceptsOperation(HappensPublicationPhase phase) => switch (phase) {
    HappensPublicationPhase.editing ||
    HappensPublicationPhase.saved ||
    HappensPublicationPhase.failure => true,
    _ => false,
  };

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(autosaveDelay, saveDraft);
  }

  void _emit(HappensPublicationState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }
}

final class HappensPublicationConflict implements Exception {}

final class HappensPublicationUnauthorized implements Exception {}
