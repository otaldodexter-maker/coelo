import 'dart:async';
import 'dart:math';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import '../domain/circular.dart';
import '../domain/circular_repository.dart';

enum CircularComposerState { editing, saving, saved, publishing, published, failure, conflict }

final class CircularComposerController extends ChangeNotifier {
  CircularComposerController({
    required this.repository,
    required this.scope,
    CircularDraft? initialDraft,
    String Function()? requestIdFactory,
  }) : _draft =
           initialDraft ??
           CircularDraft(
             id: '',
             title: '',
             blocks: [CircularTextBlock(id: _uuid(), text: '')],
           ),
       _requestIdFactory = requestIdFactory ?? _uuid;

  final CircularRepository repository;
  final CircularScope scope;
  final String Function() _requestIdFactory;
  CircularDraft _draft;
  CircularComposerState _state = CircularComposerState.editing;
  String? _errorCode;
  ({String requestId, CircularDraft draft})? _pendingSave;
  Future<CircularSaveResult>? _saveInFlight;
  ({String requestId, CircularDraft draft, DateTime? publishAt})? _pendingPublish;
  Future<CircularSaveResult>? _publishInFlight;
  DateTime? _publishAtInFlight;
  var _disposed = false;

  CircularDraft get draft => _draft;
  CircularComposerState get state => _state;
  String? get errorCode => _errorCode;
  bool get busy =>
      _state == CircularComposerState.saving || _state == CircularComposerState.publishing;

  void updateTitle(String value) => _replace(title: value);

  void updateBody(String value) {
    final blocks = [..._draft.blocks];
    final index = blocks.indexWhere((block) => block is CircularTextBlock);
    final next = CircularTextBlock(
      id: index < 0 ? _uuid() : blocks[index].id,
      text: value.characters.take(CircularLimits.bodyCharacters).toString(),
    );
    if (index < 0) {
      blocks.insert(0, next);
    } else {
      blocks[index] = next;
    }
    _replace(blocks: blocks);
  }

  void addMediaAsset(String assetId) {
    final media = _draft.blocks.whereType<CircularMediaBlock>().firstOrNull;
    final ids = media?.assetIds.toList() ?? <String>[];
    if (ids.length >= CircularLimits.files || ids.contains(assetId)) return;
    ids.add(assetId);
    final blocks = [..._draft.blocks];
    if (media == null) {
      final textIndex = blocks.indexWhere((block) => block is CircularTextBlock);
      blocks.insert(
        textIndex < 0 ? 0 : textIndex + 1,
        CircularMediaBlock(id: _uuid(), assetIds: ids),
      );
    } else {
      blocks[blocks.indexOf(media)] = CircularMediaBlock(id: media.id, assetIds: ids);
    }
    _replace(blocks: blocks);
  }

  void removeMediaAsset(String assetId) {
    final blocks = [..._draft.blocks];
    final index = blocks.indexWhere((block) => block is CircularMediaBlock);
    if (index < 0) return;
    final media = blocks[index] as CircularMediaBlock;
    final ids = media.assetIds.where((id) => id != assetId).toList(growable: false);
    if (ids.isEmpty) {
      blocks.removeAt(index);
    } else {
      blocks[index] = CircularMediaBlock(id: media.id, assetIds: ids);
    }
    _replace(blocks: blocks);
  }

  void toggleAudience(CircularAudienceKind audience) {
    final audiences = {..._draft.audiences};
    if (!audiences.add(audience)) audiences.remove(audience);
    _replace(audiences: audiences);
  }

  void addQuestion(CircularQuestionKind kind) {
    if (_draft.blocks.whereType<CircularQuestionBlock>().length >= CircularLimits.questions) return;
    final questionId = _uuid();
    _replace(
      blocks: [
        ..._draft.blocks,
        CircularQuestionBlock(
          id: questionId,
          prompt: 'Nova pergunta',
          kind: kind,
          required: false,
          options: [
            CircularQuestionOption(id: _uuid(), label: 'Opção 1'),
            CircularQuestionOption(id: _uuid(), label: 'Opção 2'),
          ],
        ),
      ],
    );
  }

  void updateQuestion(
    String questionId, {
    String? prompt,
    CircularQuestionKind? kind,
    bool? required,
  }) => _mapQuestion(
    questionId,
    (question) => CircularQuestionBlock(
      id: question.id,
      prompt: prompt ?? question.prompt,
      kind: kind ?? question.kind,
      required: required ?? question.required,
      options: question.options,
    ),
  );

  void updateOption(String questionId, String optionId, String label) => _mapQuestion(
    questionId,
    (question) => CircularQuestionBlock(
      id: question.id,
      prompt: question.prompt,
      kind: question.kind,
      required: question.required,
      options: [
        for (final option in question.options)
          option.id == optionId ? CircularQuestionOption(id: option.id, label: label) : option,
      ],
    ),
  );

  void addOption(String questionId) => _mapQuestion(questionId, (question) {
    if (question.options.length >= CircularLimits.maximumOptions) return question;
    return CircularQuestionBlock(
      id: question.id,
      prompt: question.prompt,
      kind: question.kind,
      required: question.required,
      options: [
        ...question.options,
        CircularQuestionOption(id: _uuid(), label: 'Opção ${question.options.length + 1}'),
      ],
    );
  });

  void removeOption(String questionId, String optionId) => _mapQuestion(questionId, (question) {
    if (question.options.length <= CircularLimits.minimumOptions) return question;
    return CircularQuestionBlock(
      id: question.id,
      prompt: question.prompt,
      kind: question.kind,
      required: question.required,
      options: question.options.where((option) => option.id != optionId).toList(growable: false),
    );
  });

  void removeQuestion(String questionId) => _replace(
    blocks: _draft.blocks.where((block) => block.id != questionId).toList(growable: false),
  );

  void duplicateQuestion(String questionId) {
    if (_draft.blocks.whereType<CircularQuestionBlock>().length >= CircularLimits.questions) return;
    final source = _draft.blocks
        .whereType<CircularQuestionBlock>()
        .where((question) => question.id == questionId)
        .firstOrNull;
    if (source == null) return;
    final index = _draft.blocks.indexOf(source);
    final blocks = [..._draft.blocks]
      ..insert(
        index + 1,
        CircularQuestionBlock(
          id: _uuid(),
          prompt: '${source.prompt} (cópia)',
          kind: source.kind,
          required: source.required,
          options: [
            for (final option in source.options)
              CircularQuestionOption(id: _uuid(), label: option.label),
          ],
        ),
      );
    _replace(blocks: blocks);
  }

  void moveQuestion(String questionId, int delta) {
    final blocks = [..._draft.blocks];
    final from = blocks.indexWhere((block) => block.id == questionId);
    if (from < 0) return;
    final to = (from + delta).clamp(0, blocks.length - 1);
    if (from == to) return;
    final block = blocks.removeAt(from);
    blocks.insert(to, block);
    _replace(blocks: blocks);
  }

  Future<CircularSaveResult> save() {
    if (_disposed) return Future.error(const CircularInvalid('contextDisposed'));
    if (_publishInFlight != null || _pendingPublish != null) {
      if (_publishInFlight == null) _setState(CircularComposerState.failure, 'publicationPending');
      return Future.error(const CircularInvalid('publicationPending'));
    }
    return _saveDraftSingleFlight();
  }

  Future<CircularSaveResult> _saveDraftSingleFlight() {
    final active = _saveInFlight;
    if (active != null) return active;
    final completion = Completer<CircularSaveResult>();
    _saveInFlight = completion.future;
    _savePendingDraft().then(
      (result) {
        _saveInFlight = null;
        completion.complete(result);
      },
      onError: (Object error, StackTrace stack) {
        _saveInFlight = null;
        completion.completeError(error, stack);
      },
    );
    return completion.future;
  }

  Future<CircularSaveResult> _savePendingDraft() async {
    _setState(CircularComposerState.saving);
    try {
      while (true) {
        final pending = _pendingSave ??= (requestId: _requestIdFactory(), draft: _draft);
        final result = await repository.saveDraft(
          requestId: pending.requestId,
          scope: scope,
          draft: pending.draft,
        );
        _checkActive();
        final hasNewEdits = !identical(_draft, pending.draft);
        _pendingSave = null;
        _draft = CircularDraft(
          id: result.id,
          title: _draft.title,
          blocks: _draft.blocks,
          status: result.status,
          responsePolicy: _draft.responsePolicy,
          audiences: _draft.audiences,
          responsesCloseAt: _draft.responsesCloseAt,
          expectedVersion: result.version,
        );
        // Reconcile an ambiguous receipt before issuing a new command for edits.
        if (hasNewEdits) continue;
        _setState(CircularComposerState.saved);
        return result;
      }
    } on CircularVersionConflict {
      _pendingSave = null;
      _setState(CircularComposerState.conflict, 'expected_version_conflict');
      rethrow;
    } on CircularFailure catch (error) {
      if (error is! CircularUnavailable) _pendingSave = null;
      _setState(CircularComposerState.failure, error.runtimeType.toString());
      rethrow;
    }
  }

  Future<CircularSaveResult> publish({DateTime? publishAt}) {
    if (_disposed) return Future.error(const CircularInvalid('contextDisposed'));
    final active = _publishInFlight;
    if (active != null) {
      if (publishAt != _publishAtInFlight) {
        return Future.error(const CircularInvalid('publicationPending'));
      }
      return active;
    }
    final completion = Completer<CircularSaveResult>();
    _publishInFlight = completion.future;
    _publishAtInFlight = publishAt;
    _publishPendingDraft(publishAt: publishAt).then(
      (result) {
        _publishInFlight = null;
        completion.complete(result);
      },
      onError: (Object error, StackTrace stack) {
        _publishInFlight = null;
        completion.completeError(error, stack);
      },
    );
    return completion.future;
  }

  Future<CircularSaveResult> _publishPendingDraft({DateTime? publishAt}) async {
    if (_pendingPublish == null) {
      final publicationIssues = _draft.validate(requireAudience: true);
      if (publicationIssues.isNotEmpty) {
        final code = publicationIssues.first.code.name;
        _setState(CircularComposerState.failure, code);
        throw CircularInvalid(code);
      }
      await _saveDraftSingleFlight();
      _checkActive();
      _pendingPublish = (requestId: _requestIdFactory(), draft: _draft, publishAt: publishAt);
    }
    final pending = _pendingPublish!;
    _setState(CircularComposerState.publishing);
    late final CircularSaveResult result;
    late final bool hasNewIntent;
    try {
      result = await repository.publish(
        requestId: pending.requestId,
        circularId: pending.draft.id,
        expectedVersion: pending.draft.expectedVersion,
        publishAt: pending.publishAt,
      );
      _checkActive();
      hasNewIntent = !identical(_draft, pending.draft) || publishAt != pending.publishAt;
      _pendingPublish = null;
      _draft = CircularDraft(
        id: result.id,
        title: _draft.title,
        blocks: _draft.blocks,
        status: result.status,
        responsePolicy: _draft.responsePolicy,
        audiences: _draft.audiences,
        responsesCloseAt: _draft.responsesCloseAt,
        expectedVersion: result.version,
      );
    } on CircularVersionConflict {
      _pendingPublish = null;
      _setState(CircularComposerState.conflict, 'expected_version_conflict');
      rethrow;
    } on CircularFailure catch (error) {
      if (error is! CircularUnavailable) _pendingPublish = null;
      _setState(CircularComposerState.failure, error.runtimeType.toString());
      rethrow;
    }
    if (hasNewIntent) {
      // Recover the original receipt, but never label subsequent edits as sent.
      _setState(CircularComposerState.failure, 'publicationRecoveredWithChanges');
      throw const CircularInvalid('publicationRecoveredWithChanges');
    }
    _setState(CircularComposerState.published);
    return result;
  }

  void _mapQuestion(String id, CircularQuestionBlock Function(CircularQuestionBlock) transform) {
    _replace(
      blocks: [
        for (final block in _draft.blocks)
          if (block is CircularQuestionBlock && block.id == id) transform(block) else block,
      ],
    );
  }

  void _replace({
    String? title,
    List<CircularBlock>? blocks,
    Set<CircularAudienceKind>? audiences,
  }) {
    if (_disposed) return;
    _draft = CircularDraft(
      id: _draft.id,
      title: title ?? _draft.title,
      blocks: blocks ?? _draft.blocks,
      status: _draft.status,
      responsePolicy: _draft.responsePolicy,
      audiences: audiences ?? _draft.audiences,
      responsesCloseAt: _draft.responsesCloseAt,
      expectedVersion: _draft.expectedVersion,
    );
    if (_publishInFlight != null) {
      notifyListeners();
    } else {
      _setState(CircularComposerState.editing);
    }
  }

  void _setState(CircularComposerState value, [String? error]) {
    if (_disposed) return;
    _state = value;
    _errorCode = error;
    notifyListeners();
  }

  void _checkActive() {
    if (_disposed) throw const CircularInvalid('contextDisposed');
  }

  @override
  void dispose() {
    _disposed = true;
    _pendingSave = null;
    _pendingPublish = null;
    super.dispose();
  }
}

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final value = bytes.map(hex).join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-'
      '${value.substring(16, 20)}-${value.substring(20)}';
}
