import 'package:coelo_superadmin/features/principal_circulars/application/circular_composer_controller.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
