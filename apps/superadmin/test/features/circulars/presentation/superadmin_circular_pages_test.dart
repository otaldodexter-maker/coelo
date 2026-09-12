import 'dart:async';

import 'package:coelo_superadmin/features/circulars/presentation/superadmin_circular_composer_page.dart';
import 'package:coelo_superadmin/features/circulars/presentation/superadmin_circular_detail_page.dart';
import 'package:coelo_superadmin/features/principal_circulars/application/circular_composer_controller.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('question field follows identity after removal and external prompt update', (
    tester,
  ) async {
    final controller = _composer(_ComposerRepository(), 'A');
    addTearDown(controller.dispose);
    controller.addQuestion(CircularQuestionKind.singleChoice);
    controller.addQuestion(CircularQuestionKind.singleChoice);
    final questions = controller.draft.blocks.whereType<CircularQuestionBlock>().toList();
    controller.updateQuestion(questions.first.id, prompt: 'Pergunta A');
    controller.updateQuestion(questions.last.id, prompt: 'Pergunta B');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperadminCircularComposerPage(
            controller: controller,
            onCancel: () {},
            onPickFiles: (_) async {},
          ),
        ),
      ),
    );
    expect(find.text('Pergunta A'), findsOneWidget);
    expect(find.text('Pergunta B'), findsOneWidget);
    controller.removeQuestion(questions.first.id);
    await tester.pump();
    expect(find.text('Pergunta A'), findsNothing);
    expect(find.text('Pergunta B'), findsOneWidget);
    controller.updateQuestion(questions.last.id, prompt: 'Pergunta B revisada');
    await tester.pump();
    expect(find.text('Pergunta B'), findsNothing);
    expect(find.text('Pergunta B revisada'), findsOneWidget);
  });
  for (final removePage in [false, true]) {
    testWidgets(
      'late publication cannot finish ${removePage ? 'disposed' : 'replacement'} editor',
      (tester) async {
        final repositoryA = _ComposerRepository()..pendingPublish = Completer<CircularSaveResult>();
        final repositoryB = _ComposerRepository();
        final controllerA = _composer(repositoryA, 'A');
        final controllerB = _composer(repositoryB, 'B');
        addTearDown(controllerA.dispose);
        addTearDown(controllerB.dispose);
        var finishedA = 0;
        var finishedB = 0;
        Widget page(CircularComposerController controller, VoidCallback finished) => MaterialApp(
          home: Scaffold(
            body: SuperadminCircularComposerPage(
              controller: controller,
              onCancel: () {},
              onPickFiles: (_) async {},
              onPublished: finished,
            ),
          ),
        );
        await tester.pumpWidget(page(controllerA, () => finishedA++));
        await tester.tap(find.byKey(const Key('circular-publish')));
        await tester.pumpAndSettle();
        expect(repositoryA.publishTimes, hasLength(1));
        await tester.pumpWidget(
          removePage ? const SizedBox.shrink() : page(controllerB, () => finishedB++),
        );
        repositoryA.pendingPublish!.complete(_published);
        await tester.pumpAndSettle();
        expect(finishedA, 0);
        expect(finishedB, 0);
        expect(repositoryB.publishTimes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('schedule chosen for the previous controller never schedules replacement', (
    tester,
  ) async {
    final picker = Completer<DateTime?>();
    final repositoryA = _ComposerRepository();
    final repositoryB = _ComposerRepository();
    final controllerA = _composer(repositoryA, 'A');
    final controllerB = _composer(repositoryB, 'B');
    addTearDown(controllerA.dispose);
    addTearDown(controllerB.dispose);
    Widget page(CircularComposerController controller) => MaterialApp(
      home: Scaffold(
        body: SuperadminCircularComposerPage(
          controller: controller,
          onCancel: () {},
          onPickFiles: (_) async {},
          onChooseSchedule: () => picker.future,
        ),
      ),
    );
    await tester.pumpWidget(page(controllerA));
    await tester.ensureVisible(find.byKey(const Key('circular-choose-schedule')));
    await tester.tap(find.byKey(const Key('circular-choose-schedule')));
    await tester.pumpWidget(page(controllerB));
    picker.complete(DateTime.now().add(const Duration(days: 1)));
    await tester.pumpAndSettle();
    // Rotulo da familia Publicacao: "Publicar agora" enquanto nao ha agendamento.
    expect(find.text('Publicar agora'), findsOneWidget);
    await tester.tap(find.byKey(const Key('circular-publish')));
    await tester.pumpAndSettle();
    expect(repositoryB.publishTimes, [null]);
    expect(repositoryA.publishTimes, isEmpty);
  });

  testWidgets('replacement controller owns visible fields and subsequent save', (tester) async {
    final repositoryA = _ComposerRepository();
    final repositoryB = _ComposerRepository();
    final controllerA = _composer(repositoryA, 'A');
    final controllerB = _composer(repositoryB, 'B');
    addTearDown(controllerA.dispose);
    addTearDown(controllerB.dispose);
    Widget page(CircularComposerController controller) => MaterialApp(
      home: Scaffold(
        body: SuperadminCircularComposerPage(
          controller: controller,
          onCancel: () {},
          onPickFiles: (_) async {},
        ),
      ),
    );
    await tester.pumpWidget(page(controllerA));
    await tester.pumpWidget(page(controllerB));
    String field(String key) => tester
        .widget<EditableText>(
          find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText)),
        )
        .controller
        .text;
    expect(field('circular-title'), 'Título B');
    expect(field('circular-body'), 'Texto B');
    await tester.enterText(find.byKey(const Key('circular-title')), 'B editado');
    await tester.tap(find.byKey(const Key('circular-save-draft')));
    await tester.pumpAndSettle();
    expect(repositoryB.savedDrafts.single.title, 'B editado');
    expect(controllerA.draft.title, 'Título A');
    expect(repositoryA.savedDrafts, isEmpty);
  });
  for (final swapRepository in [false, true]) {
    testWidgets('detail clears old content on ${swapRepository ? 'repository' : 'ID'} change', (
      tester,
    ) async {
      final repositoryA = _QueuedDetailRepository();
      final repositoryB = swapRepository ? _QueuedDetailRepository() : repositoryA;
      Widget page(CircularRepository repository, String id) => MaterialApp(
        home: Scaffold(
          body: SuperadminCircularDetailPage(circularId: id, repository: repository, onBack: () {}),
        ),
      );
      await tester.pumpWidget(page(repositoryA, 'a'));
      repositoryA.requests.single.complete(_detail('A'));
      await tester.pumpAndSettle();
      expect(find.text('Private A'), findsOneWidget);
      await tester.pumpWidget(page(repositoryB, swapRepository ? 'a' : 'b'));
      await tester.pump();
      expect(find.text('Private A'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repositoryB.requests.last.complete(_detail('B'));
      await tester.pumpAndSettle();
      expect(find.text('Private B'), findsOneWidget);
    });
  }

  for (final oldFailure in [false, true]) {
    testWidgets('detail ignores late ${oldFailure ? 'denial' : 'success'} from prior request', (
      tester,
    ) async {
      final repository = _QueuedDetailRepository();
      Widget page(String id) => MaterialApp(
        home: Scaffold(
          body: SuperadminCircularDetailPage(circularId: id, repository: repository, onBack: () {}),
        ),
      );
      await tester.pumpWidget(page('a'));
      await tester.pumpWidget(page('b'));
      expect(repository.ids, ['a', 'b']);
      repository.requests[1].complete(_detail('B'));
      await tester.pumpAndSettle();
      if (oldFailure) {
        repository.requests[0].completeError(const CircularUnauthorized());
      } else {
        repository.requests[0].complete(_detail('A'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Private B'), findsOneWidget);
      expect(find.text('Private A'), findsNothing);
      expect(find.text('Circular indisponível'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('admin composer follows the approved responsive form at ${width.toInt()}px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = CircularComposerController(
        repository: _Repository(),
        scope: const CircularScope(institutionId: 'institution-1'),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperadminCircularComposerPage(
              controller: controller,
              onCancel: () {},
              onPickFiles: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Publicar circular'), findsAtLeastNWidgets(1));
      expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
      expect(
        find.byKey(const Key('superadmin-circular-preview')),
        width >= 1200 ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('block header keeps its label whole at 375px with text at 200%', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 1320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = CircularComposerController(
      repository: _Repository(),
      scope: const CircularScope(institutionId: 'institution-1'),
      initialDraft: const CircularDraft(
        id: 'circular-accessible',
        title: 'Circular acessivel',
        blocks: [CircularTextBlock(id: 'text-accessible', text: 'Conteudo')],
        audiences: {CircularAudienceKind.families},
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 1320), textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SuperadminCircularComposerPage(
              controller: controller,
              onCancel: () {},
              onPickFiles: (_) async {},
            ),
          ),
        ),
      ),
    );

    final label = find.byKey(const Key('circular-block-label-text-accessible'));
    final actions = find.byKey(const Key('circular-block-actions-text-accessible'));
    expect(label, findsOneWidget);
    expect(tester.widget<Text>(label).data, 'Texto');
    expect(actions, findsOneWidget);
    expect(tester.getSize(label).height, lessThanOrEqualTo(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('productive composer and preview preserve interleaved block order', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = CircularComposerController(
      repository: _ComposerRepository(),
      scope: const CircularScope(institutionId: 'institution-1'),
      initialDraft: const CircularDraft(
        id: 'circular-ordered',
        title: 'Circular intercalada',
        blocks: [
          CircularTextBlock(id: 'text-before', text: 'Texto antes'),
          CircularMediaBlock(id: 'media-before-question', assetIds: ['antes.pdf']),
          CircularQuestionBlock(
            id: 'question-middle',
            prompt: 'Pergunta no meio?',
            kind: CircularQuestionKind.singleChoice,
            required: true,
            options: [
              CircularQuestionOption(id: 'yes', label: 'Sim'),
              CircularQuestionOption(id: 'no', label: 'Nao'),
            ],
          ),
          CircularMediaBlock(id: 'media-after-question', assetIds: ['depois.pdf']),
          CircularTextBlock(id: 'text-after', text: 'Texto depois'),
        ],
        audiences: {CircularAudienceKind.families},
      ),
    );
    addTearDown(controller.dispose);
    String? insertionAnchor;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperadminCircularComposerPage(
            controller: controller,
            onCancel: () {},
            onPickFiles: (afterBlockId) async => insertionAnchor = afterBlockId,
          ),
        ),
      ),
    );

    double top(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
    expect(
      top('circular-editor-text-before'),
      lessThan(top('circular-editor-media-before-question')),
    );
    expect(
      top('circular-editor-media-before-question'),
      lessThan(top('circular-editor-question-middle')),
    );
    expect(
      top('circular-editor-question-middle'),
      lessThan(top('circular-editor-media-after-question')),
    );
    expect(
      top('circular-editor-media-after-question'),
      lessThan(top('circular-editor-text-after')),
    );
    expect(
      top('circular-preview-text-before'),
      lessThan(top('circular-preview-media-before-question')),
    );
    expect(
      top('circular-preview-media-before-question'),
      lessThan(top('circular-preview-question-middle')),
    );
    expect(
      top('circular-preview-question-middle'),
      lessThan(top('circular-preview-media-after-question')),
    );
    expect(
      top('circular-preview-media-after-question'),
      lessThan(top('circular-preview-text-after')),
    );

    final addAfterQuestion = find.byKey(const Key('circular-pick-files-after-question-middle'));
    await tester.ensureVisible(addAfterQuestion);
    await tester.tap(addAfterQuestion);
    expect(insertionAnchor, 'question-middle');

    await tester.ensureVisible(find.byKey(const Key('circular-response-acceptDecline')));
    await tester.tap(find.byKey(const Key('circular-response-acceptDecline')));
    await tester.pump();

    expect(controller.draft.blocks.map((block) => block.id).toList(), [
      'text-before',
      'media-before-question',
      'question-middle',
      'media-after-question',
      'text-after',
    ]);
  });

  testWidgets('admin composer saves and publishes through the existing domain controller', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = CircularComposerController(
      repository: repository,
      scope: const CircularScope(institutionId: 'institution-1'),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperadminCircularComposerPage(
            controller: controller,
            onCancel: () {},
            onPickFiles: (_) async {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('circular-title')), 'Renovação 2027');
    await tester.enterText(find.byKey(const Key('circular-body')), 'Queridos responsáveis');
    await tester.ensureVisible(find.byKey(const Key('circular-audience-families')));
    await tester.tap(find.byKey(const Key('circular-audience-families')));
    await tester.ensureVisible(find.byKey(const Key('circular-save-draft')));
    await tester.tap(find.byKey(const Key('circular-save-draft')));
    await tester.pumpAndSettle();
    expect(repository.saved, isTrue);

    await tester.tap(find.byKey(const Key('circular-publish')));
    await tester.pumpAndSettle();
    expect(repository.published, isTrue);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('admin detail is responsive at ${width.toInt()}px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var edited = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperadminCircularDetailPage(
              circularId: 'circular-published',
              repository: _Repository(),
              onBack: () {},
              onEdit: () => edited = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Renovação de matrícula'), findsOneWidget);
      expect(find.text('Coordenação Pedagógica · Ensino Fundamental'), findsOneWidget);
      expect(find.text('Confirme a renovação até 30 de setembro.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('circular-detail-edit')));
      expect(edited, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('detail closes responses with the loaded management version', (tester) async {
    final repository = _Repository();
    CircularDetail? closed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperadminCircularDetailPage(
            circularId: 'circular-published',
            repository: repository,
            onBack: () {},
            onCloseResponses: (detail) async => closed = detail,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('circular-detail-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('circular-detail-confirm-action')));
    await tester.pumpAndSettle();

    expect(closed?.id, 'circular-published');
    expect(closed?.managementVersion, 7);
    expect(find.text('Respostas encerradas.'), findsOneWidget);
  });

  // P50 = B (Owner, 11/09/2026): o Superadmin tambem responde a Circular
  // publicada; a acao abre a tela de resposta. Encerrada: sem Responder.
  testWidgets('detail offers Responder only for a published open Circular', (tester) async {
    var responded = 0;
    Future<void> pump(CircularStatus status) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperadminCircularDetailPage(
              key: ValueKey(status),
              circularId: 'circular-$status',
              repository: _Repository()..visibleStatus = status,
              onBack: () {},
              onRespond: () => responded++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(CircularStatus.published);
    await tester.tap(find.byKey(const Key('circular-detail-respond')));
    await tester.pump();
    expect(responded, 1);

    await pump(CircularStatus.closed);
    expect(find.byKey(const Key('circular-detail-respond')), findsNothing);
  });

  // Rodada 4 (publicacoes-agenda): o servidor recusa editar Circular encerrada;
  // o detalhe nao oferece Editar nesse estado (achado da prova em producao).
  testWidgets('detail hides Editar when the Circular is closed', (tester) async {
    final repository = _Repository()..visibleStatus = CircularStatus.closed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperadminCircularDetailPage(
            circularId: 'circular-closed',
            repository: repository,
            onBack: () {},
            onEdit: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('circular-detail-edit')), findsNothing);
    expect(find.byKey(const Key('circular-detail-close')), findsNothing);
  });

  testWidgets('draft detail deletes only after confirmation and returns to directory', (
    tester,
  ) async {
    final repository = _Repository()..visibleStatus = CircularStatus.draft;
    CircularDetail? deleted;
    var returned = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperadminCircularDetailPage(
            circularId: 'circular-draft',
            repository: repository,
            onBack: () {},
            onDelete: (detail) async => deleted = detail,
            onDeleted: () => returned = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('circular-detail-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Excluir rascunho?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('circular-detail-confirm-action')));
    await tester.pumpAndSettle();

    expect(deleted?.managementVersion, 7);
    expect(returned, isTrue);
  });
}

CircularDetail _detail(String label) => CircularDetail(
  id: label,
  revisionId: 'revision-$label',
  title: 'Private $label',
  authorName: 'Synthetic author',
  contextLabel: 'Synthetic context',
  publishedAt: DateTime.utc(2026, 9, 7),
  status: CircularStatus.published,
  responseState: CircularResponseState.unanswered,
  blocks: const [],
);

CircularComposerController _composer(_ComposerRepository repository, String label) =>
    CircularComposerController(
      repository: repository,
      scope: CircularScope(institutionId: 'institution-$label'),
      initialDraft: CircularDraft(
        id: 'circular-$label',
        title: 'Título $label',
        blocks: [CircularTextBlock(id: 'text-$label', text: 'Texto $label')],
        audiences: const {CircularAudienceKind.families},
        expectedVersion: 1,
      ),
    );

const _published = CircularSaveResult(
  id: 'circular-A',
  revisionId: 'revision-2',
  version: 3,
  status: CircularStatus.published,
);

final class _ComposerRepository implements CircularRepository {
  final savedDrafts = <CircularDraft>[];
  final publishTimes = <DateTime?>[];
  Completer<CircularSaveResult>? pendingPublish;
  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) async {
    savedDrafts.add(draft);
    return CircularSaveResult(
      id: draft.id,
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
    publishTimes.add(publishAt);
    return pendingPublish?.future ??
        Future.value(
          CircularSaveResult(
            id: circularId,
            revisionId: 'revision-2',
            version: 3,
            status: CircularStatus.published,
          ),
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _QueuedDetailRepository implements CircularRepository {
  final ids = <String>[];
  final requests = <Completer<CircularDetail>>[];

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) {
    ids.add(circularId);
    final request = Completer<CircularDetail>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Repository implements CircularRepository {
  bool saved = false;
  bool published = false;
  CircularStatus visibleStatus = CircularStatus.published;

  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) async => null;

  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) async {
    saved = true;
    return const CircularSaveResult(
      id: 'circular-published',
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
    published = true;
    return const CircularSaveResult(
      id: 'circular-published',
      revisionId: 'revision-2',
      version: 3,
      status: CircularStatus.published,
    );
  }

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) async =>
      CircularDetail(
        id: circularId,
        revisionId: 'revision-2',
        title: 'Renovação de matrícula',
        authorName: 'Coordenação Pedagógica',
        contextLabel: 'Ensino Fundamental',
        publishedAt: DateTime.utc(2026, 8, 21),
        status: visibleStatus,
        managementVersion: 7,
        responseState: CircularResponseState.unanswered,
        blocks: const [
          CircularTextBlock(id: 'text-1', text: 'Confirme a renovação até 30 de setembro.'),
        ],
      );

  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) => throw UnimplementedError();
}
