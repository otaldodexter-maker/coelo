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

  Future<CircularSaveResult> save() async {
    _setState(CircularComposerState.saving);
    try {
      final result = await repository.saveDraft(
        requestId: _requestIdFactory(),
        scope: scope,
        draft: _draft,
      );
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
      _setState(CircularComposerState.saved);
      return result;
    } on CircularVersionConflict {
      _setState(CircularComposerState.conflict, 'expected_version_conflict');
      rethrow;
    } on CircularFailure catch (error) {
      _setState(CircularComposerState.failure, error.runtimeType.toString());
      rethrow;
    }
  }

  Future<CircularSaveResult> publish({DateTime? publishAt}) async {
    final publicationIssues = _draft.validate(requireAudience: true);
    if (publicationIssues.isNotEmpty) {
      final code = publicationIssues.first.code.name;
      _setState(CircularComposerState.failure, code);
      throw CircularInvalid(code);
    }
    final saved = await save();
    _setState(CircularComposerState.publishing);
    try {
      final result = await repository.publish(
        requestId: _requestIdFactory(),
        circularId: saved.id,
        expectedVersion: saved.version,
        publishAt: publishAt,
      );
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
      _setState(CircularComposerState.published);
      return result;
    } on CircularVersionConflict {
      _setState(CircularComposerState.conflict, 'expected_version_conflict');
      rethrow;
    } on CircularFailure catch (error) {
      _setState(CircularComposerState.failure, error.runtimeType.toString());
      rethrow;
    }
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
    _setState(CircularComposerState.editing);
  }

  void _setState(CircularComposerState value, [String? error]) {
    _state = value;
    _errorCode = error;
    notifyListeners();
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
