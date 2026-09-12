import 'dart:async';
import 'dart:convert';

import 'package:coelo_superadmin/features/principal_circulars/application/circular_composer_controller.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_serialization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final publishing in [false, true]) {
    test(
      'disposed controller stops ${publishing ? 'publish' : 'save'} after pending save',
      () async {
        final repository = _PendingSaveRepository();
        final controller = _controller(repository)..toggleAudience(CircularAudienceKind.families);
        final operation = publishing ? controller.publish() : controller.save();
        controller.dispose();
        final assertion = expectLater(operation, throwsA(isA<CircularInvalid>()));
        repository.result.complete(
          const CircularSaveResult(
            id: 'saved',
            revisionId: 'revision',
            version: 1,
            status: CircularStatus.draft,
          ),
        );
        await assertion;
        expect(repository.calls, 1);
      },
    );
  }

  test('disposed controller ignores late publication and rejects new commands', () async {
    final repository = _PublicationRepository(loseFirstResponse: false, holdPublication: true);
    final controller = _controller(repository)..toggleAudience(CircularAudienceKind.families);
    final operation = controller.publish();
    await repository.started.future;
    controller.dispose();
    final assertion = expectLater(operation, throwsA(isA<CircularInvalid>()));
    repository.release.complete();
    await assertion;
    await expectLater(controller.save(), throwsA(isA<CircularInvalid>()));
    await expectLater(controller.publish(), throwsA(isA<CircularInvalid>()));
    expect(() => controller.updateTitle('Late edit'), returnsNormally);
    expect(repository.calls, hasLength(1));
    expect(repository.saves, 1);
  });

  for (final publishAt in [null, DateTime.utc(2026, 10, 1, 12)]) {
    test('recovers publication receipt before another save ($publishAt)', () async {
      final repository = _PublicationRepository();
      final controller = _controller(repository)..toggleAudience(CircularAudienceKind.families);
      addTearDown(controller.dispose);
      await expectLater(
        controller.publish(publishAt: publishAt),
        throwsA(isA<CircularUnavailable>()),
      );
      final result = await controller.publish(publishAt: publishAt);
      expect(repository.saves, 1);
      expect(repository.publications, 1);
      expect(repository.calls, hasLength(2));
      expect(repository.calls[0], repository.calls[1]);
      expect(
        result.status,
        publishAt == null ? CircularStatus.published : CircularStatus.scheduled,
      );
      expect(controller.draft.expectedVersion, result.version);
    });
  }

  test('recovery preserves later edits without claiming they were published', () async {
    final repository = _PublicationRepository();
    final controller = _controller(repository)..toggleAudience(CircularAudienceKind.families);
    addTearDown(controller.dispose);
    await expectLater(controller.publish(), throwsA(isA<CircularUnavailable>()));
    controller.updateTitle('Ainda não publicada');
    await expectLater(
      controller.publish(),
      throwsA(
        isA<CircularInvalid>().having(
          (error) => error.code,
          'code',
          'publicationRecoveredWithChanges',
        ),
      ),
    );
    expect(repository.saves, 1);
    expect(repository.publications, 1);
    expect(controller.draft.title, 'Ainda não publicada');
    expect(controller.draft.expectedVersion, 2);
    expect(controller.state, CircularComposerState.failure);
    expect(controller.errorCode, 'publicationRecoveredWithChanges');
    await controller.publish();
    expect(repository.publications, 2);
    expect(repository.saves, 2);
    expect(repository.calls.last.requestId, isNot(repository.calls.first.requestId));
  });

  test('recovery keeps original schedule and requires explicit changed intent', () async {
    final repository = _PublicationRepository();
    final controller = _controller(repository)..toggleAudience(CircularAudienceKind.families);
    addTearDown(controller.dispose);
    final firstAt = DateTime.utc(2026, 10, 1);
    final nextAt = DateTime.utc(2026, 10, 2);
    await expectLater(controller.publish(publishAt: firstAt), throwsA(isA<CircularUnavailable>()));
    await expectLater(controller.publish(publishAt: nextAt), throwsA(isA<CircularInvalid>()));
    expect(repository.calls[0], repository.calls[1]);
    expect(repository.calls.last.publishAt, firstAt);
    expect(controller.errorCode, 'publicationRecoveredWithChanges');
    await controller.publish(publishAt: nextAt);
    expect(repository.calls.last.publishAt, nextAt);
    expect(repository.publications, 2);
  });

  test('concurrent publication shares operation and rejects a competing save', () async {
    final repository = _PublicationRepository(loseFirstResponse: false, holdPublication: true);
    final controller = _controller(repository)..toggleAudience(CircularAudienceKind.families);
    addTearDown(controller.dispose);
    final first = controller.publish();
    final second = controller.publish();
    await repository.started.future;
    expect(repository.saves, 1);
    expect(repository.calls, hasLength(1));
    await expectLater(controller.save(), throwsA(isA<CircularInvalid>()));
    await expectLater(
      controller.publish(publishAt: DateTime.utc(2026, 10, 2)),
      throwsA(isA<CircularInvalid>()),
    );
    repository.release.complete();
    expect((await first).version, (await second).version);
    expect(repository.publications, 1);
    expect(repository.saves, 1);
    expect(controller.busy, isFalse);
  });

  test('editing while publication is in flight keeps the operation busy', () async {
    final repository = _PublicationRepository(loseFirstResponse: false, holdPublication: true);
    final controller = _controller(repository)..toggleAudience(CircularAudienceKind.families);
    addTearDown(controller.dispose);
    final result = controller.publish();
    final rejected = expectLater(result, throwsA(isA<CircularInvalid>()));
    await repository.started.future;
    controller.updateTitle('Alterada durante envio');
    final busyDuringEdit = controller.busy;
    repository.release.complete();
    await rejected;
    expect(busyDuringEdit, isTrue);
    expect(controller.draft.title, 'Alterada durante envio');
    expect(controller.errorCode, 'publicationRecoveredWithChanges');
    expect(controller.busy, isFalse);
  });

  test('ambiguous publication blocks a new save until recovery', () async {
    final repository = _PublicationRepository();
    final controller = _controller(repository)..toggleAudience(CircularAudienceKind.families);
    addTearDown(controller.dispose);
    await expectLater(controller.publish(), throwsA(isA<CircularUnavailable>()));
    await expectLater(controller.save(), throwsA(isA<CircularInvalid>()));
    expect(controller.errorCode, 'publicationPending');
    expect(repository.saves, 1);
  });

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

  test('authors interleaved blocks and enforces the shared ten-thousand character limit', () {
    final controller = CircularComposerController(
      repository: _Repository(),
      scope: const CircularScope(institutionId: 'institution-1'),
      initialDraft: const CircularDraft(
        id: '',
        title: 'Circular',
        blocks: [CircularTextBlock(id: 'before', text: 'Antes')],
      ),
    );
    addTearDown(controller.dispose);

    controller.addQuestion(CircularQuestionKind.singleChoice, afterBlockId: 'before');
    final question = controller.draft.blocks.whereType<CircularQuestionBlock>().single;
    controller.addTextBlock(afterBlockId: question.id);
    final after = controller.draft.blocks.whereType<CircularTextBlock>().last;
    controller.updateTextBlock(after.id, 'Depois');
    controller.addMediaAsset('asset-1');
    final media = controller.draft.blocks.whereType<CircularMediaBlock>().single;
    controller.moveBlock(media.id, -1);

    expect(controller.draft.blocks.map((block) => block.id), [
      'before',
      question.id,
      media.id,
      after.id,
    ]);

    controller.updateTextBlock('before', 'a' * 9998);
    controller.updateTextBlock(after.id, 'depois demais');
    expect(
      controller.draft.blocks.whereType<CircularTextBlock>().fold<int>(
        0,
        (total, block) => total + block.text.length,
      ),
      CircularLimits.bodyCharacters,
    );
    expect(controller.draft.blocks.whereType<CircularTextBlock>().last.text, 'depois');
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

final class _PublicationRepository implements CircularRepository {
  _PublicationRepository({this.loseFirstResponse = true, this.holdPublication = false});
  final bool loseFirstResponse;
  final bool holdPublication;
  final started = Completer<void>();
  final release = Completer<void>();
  final calls = <({String requestId, String circularId, int version, DateTime? publishAt})>[];
  final receipts =
      <
        String,
        ({String circularId, int version, DateTime? publishAt, CircularSaveResult result})
      >{};
  var saves = 0;
  var publications = 0;
  var version = 0;

  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) async {
    saves++;
    if (draft.expectedVersion != version) throw const CircularVersionConflict();
    return CircularSaveResult(
      id: 'circular-persisted',
      revisionId: 'revision-${++version}',
      version: version,
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
    calls.add((
      requestId: requestId,
      circularId: circularId,
      version: expectedVersion,
      publishAt: publishAt,
    ));
    if (!started.isCompleted) started.complete();
    if (holdPublication) await release.future;
    final prior = receipts[requestId];
    if (prior != null) {
      if (prior.circularId != circularId ||
          prior.version != expectedVersion ||
          prior.publishAt != publishAt) {
        throw const CircularVersionConflict();
      }
      return prior.result;
    }
    if (expectedVersion != version) throw const CircularVersionConflict();
    final result = CircularSaveResult(
      id: circularId,
      revisionId: 'published-${++version}',
      version: version,
      status: publishAt == null ? CircularStatus.published : CircularStatus.scheduled,
    );
    receipts[requestId] = (
      circularId: circularId,
      version: expectedVersion,
      publishAt: publishAt,
      result: result,
    );
    publications++;
    if (loseFirstResponse && publications == 1) throw const CircularUnavailable();
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
