import 'dart:async';
import 'dart:convert';

import 'package:coelo_superadmin/features/principal_circulars/application/circular_composer_controller.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_serialization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('replays an ambiguous save instead of creating another draft', () async {
    final repository = _AmbiguousSaveRepository();
    final controller = _controller(repository);
    addTearDown(controller.dispose);

    await expectLater(controller.save(), throwsA(isA<CircularUnavailable>()));
    final recovered = await controller.save();

    expect(recovered.id, 'circular-persisted');
    expect(recovered.version, 1);
    expect(repository.creations, 1);
    expect(repository.requestIds, hasLength(2));
    expect(repository.requestIds.toSet(), hasLength(1));
    expect(controller.draft.id, recovered.id);
    expect(controller.draft.expectedVersion, recovered.version);
    expect(controller.state, CircularComposerState.saved);
  });

  test('reconciles the original snapshot before saving edits after a timeout', () async {
    final repository = _AmbiguousSaveRepository();
    final controller = _controller(repository);
    addTearDown(controller.dispose);

    await expectLater(controller.save(), throwsA(isA<CircularUnavailable>()));
    controller.updateTitle('Texto atualizado');
    final saved = await controller.save();

    expect(repository.requestIds, hasLength(3));
    expect(repository.requestIds[0], repository.requestIds[1]);
    expect(repository.requestIds[2], isNot(repository.requestIds[0]));
    expect(repository.drafts.map((draft) => draft.title), [
      'Circular',
      'Circular',
      'Texto atualizado',
    ]);
    expect(repository.drafts.last.id, 'circular-persisted');
    expect(repository.drafts.last.expectedVersion, 1);
    expect(repository.creations, 1);
    expect(saved.version, 2);
    expect(controller.draft.title, 'Texto atualizado');
  });

  test('concurrent save calls share one in-flight mutation', () async {
    final repository = _PendingSaveRepository();
    final controller = _controller(repository);
    addTearDown(controller.dispose);
    final first = controller.save();
    final second = controller.save();
    expect(repository.calls, 1);
    repository.result.complete(
      const CircularSaveResult(
        id: 'circular-persisted',
        revisionId: 'revision-1',
        version: 1,
        status: CircularStatus.draft,
      ),
    );
    expect((await first).id, (await second).id);
    expect(controller.busy, isFalse);
  });

  test('publication resumes the ambiguous draft before its distinct publish command', () async {
    final repository = _AmbiguousSaveRepository();
    final controller = _controller(repository);
    addTearDown(controller.dispose);
    controller.toggleAudience(CircularAudienceKind.families);
    await expectLater(controller.publish(), throwsA(isA<CircularUnavailable>()));
    final published = await controller.publish();
    expect(repository.creations, 1);
    expect(repository.requestIds, hasLength(2));
    expect(repository.requestIds.toSet(), hasLength(1));
    expect(repository.publishRequest, isNotNull);
    expect(repository.publishRequest, isNot(repository.requestIds.first));
    expect(published.status, CircularStatus.published);
    expect(controller.state, CircularComposerState.published);
  });

  test('deterministic rejection does not retain an ambiguous save command', () async {
    final repository = _RejectedSaveRepository();
    final controller = _controller(repository);
    addTearDown(controller.dispose);
    await expectLater(controller.save(), throwsA(isA<CircularInvalid>()));
    controller.updateTitle('Corrigida');
    await controller.save();
    expect(repository.requestIds.toSet(), hasLength(2));
    expect(controller.draft.title, 'Corrigida');
    expect(controller.state, CircularComposerState.saved);
  });

  test('builds only the approved simple question blocks', () {
    final controller = CircularComposerController(
      repository: _Repository(),
      scope: const CircularScope(institutionId: 'institution-1'),
    );
    addTearDown(controller.dispose);

    controller.updateTitle('Renovação');
    controller.updateBody('Confirme a matrícula.');
    controller.addQuestion(CircularQuestionKind.singleChoice);
    final question = controller.draft.blocks.whereType<CircularQuestionBlock>().single;

    expect(question.options, hasLength(2));
    expect(controller.draft.validate(), isEmpty);
  });

  test('never accepts more than ten questions or four files', () {
    final controller = CircularComposerController(
      repository: _Repository(),
      scope: const CircularScope(institutionId: 'institution-1'),
    );
    addTearDown(controller.dispose);

    for (var index = 0; index < 12; index++) {
      controller.addQuestion(CircularQuestionKind.multipleChoice);
      controller.addMediaAsset('asset-$index');
    }

    expect(controller.draft.blocks.whereType<CircularQuestionBlock>(), hasLength(10));
    expect(
      controller.draft.blocks.whereType<CircularMediaBlock>().expand((block) => block.assetIds),
      hasLength(4),
    );
  });

  test('saves before publishing and keeps idempotency ids distinct', () async {
    final repository = _Repository();
    final controller = CircularComposerController(
      repository: repository,
      scope: const CircularScope(institutionId: 'institution-1'),
    );
    addTearDown(controller.dispose);
    controller.updateTitle('Circular');
    controller.updateBody('Texto');
    controller.toggleAudience(CircularAudienceKind.families);

    await controller.publish();

    expect(repository.operations, ['save', 'publish']);
    expect(repository.requestIds.toSet(), hasLength(2));
  });

  test('blocks publication until an audience is selected', () async {
    final controller = CircularComposerController(
      repository: _Repository(),
      scope: const CircularScope(institutionId: 'institution-1'),
    );
    addTearDown(controller.dispose);
    controller.updateTitle('Circular');
    controller.updateBody('Texto');

    await expectLater(controller.publish(), throwsA(isA<CircularInvalid>()));
    expect(controller.errorCode, 'audienceRequired');
  });
}

CircularComposerController _controller(CircularRepository repository) {
  var request = 0;
  return CircularComposerController(
      repository: repository,
      scope: const CircularScope(institutionId: 'institution-1'),
      requestIdFactory: () => 'request-${++request}',
    )
    ..updateTitle('Circular')
    ..updateBody('Texto');
}

final class _PendingSaveRepository implements CircularRepository {
  final result = Completer<CircularSaveResult>();
  var calls = 0;
  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) {
    calls++;
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _AmbiguousSaveRepository implements CircularRepository {
  final requestIds = <String>[];
  final drafts = <CircularDraft>[];
  final receipts = <String, ({String payload, CircularSaveResult result})>{};
  var creations = 0;
  var version = 0;
  String? publishRequest;

  @override
  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  }) async {
    if (circularId != 'circular-persisted' || expectedVersion != version) {
      throw const CircularVersionConflict();
    }
    publishRequest = requestId;
    return CircularSaveResult(
      id: circularId,
      revisionId: 'published',
      version: ++version,
      status: CircularStatus.published,
    );
  }

  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) async {
    requestIds.add(requestId);
    drafts.add(draft);
    final payload = jsonEncode(CircularDraftCodec.toJson(draft));
    final cached = receipts[requestId];
    if (cached != null) {
      if (cached.payload != payload) throw const CircularVersionConflict();
      return cached.result;
    }
    if (draft.id.isEmpty) {
      if (creations > 0) throw const CircularVersionConflict();
      creations++;
    } else if (draft.id != 'circular-persisted' || draft.expectedVersion != version) {
      throw const CircularVersionConflict();
    }
    final result = CircularSaveResult(
      id: 'circular-persisted',
      revisionId: 'revision-${++version}',
      version: version,
      status: CircularStatus.draft,
    );
    receipts[requestId] = (payload: payload, result: result);
    if (requestIds.length == 1) throw const CircularUnavailable();
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RejectedSaveRepository implements CircularRepository {
  final requestIds = <String>[];
  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) async {
    requestIds.add(requestId);
    if (requestIds.length == 1) throw const CircularInvalid('invalid_input');
    return const CircularSaveResult(
      id: 'circular-persisted',
      revisionId: 'revision-1',
      version: 1,
      status: CircularStatus.draft,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Repository implements CircularRepository {
  final operations = <String>[];
  final requestIds = <String>[];

  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) async => null;

  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) async {
    operations.add('save');
    requestIds.add(requestId);
    return const CircularSaveResult(
      id: 'circular-1',
      revisionId: 'revision-1',
      version: 2,
      status: CircularStatus.draft,
    );
  }

  @override
  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  }) async {
    operations.add('publish');
    requestIds.add(requestId);
    return const CircularSaveResult(
      id: 'circular-1',
      revisionId: 'revision-1',
      version: 3,
      status: CircularStatus.published,
    );
  }

  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) =>
      throw UnimplementedError();

  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) => throw UnimplementedError();
}
