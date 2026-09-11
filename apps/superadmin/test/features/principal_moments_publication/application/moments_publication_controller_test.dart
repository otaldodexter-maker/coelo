import 'dart:async';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_moments_publication/application/moments_publication_controller.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/domain/moments_publication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final operation in ['load', 'save', 'publish']) {
    test('$operation denial purges protected media and blocks late commands', () async {
      final repository = _DenyingLifecycleRepository();
      final controller = MomentsPublicationController(
        repository: repository,
        context: MomentsPublicationContext.demo,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.draft.media.single.bytes, isNotEmpty);
      repository.denied = true;
      if (operation == 'load') await controller.load();
      if (operation == 'save') await controller.saveDraft();
      if (operation == 'publish') await controller.publish();
      expect(controller.state.phase, MomentsPublicationPhase.unauthorized);
      expect(controller.state.draft.media, isEmpty);
      expect(controller.state.draft.caption, isEmpty);
      expect(controller.state.draft.id, isNull);
      expect(controller.state.draft.audiences, isEmpty);
      final calls = repository.commands;
      controller.setCaption('late');
      controller.addMedia(_protectedMedia);
      controller.removeMedia(0);
      controller.reorderMedia(0, 1);
      controller.toggleAudience(MomentsAudienceKind.families);
      controller.setSaveAsDraft(true);
      await controller.saveDraft();
      await controller.publish();
      await controller.retry();
      expect(controller.state.phase, MomentsPublicationPhase.unauthorized);
      expect(controller.state.draft.media, isEmpty);
      expect(controller.state.draft.caption, isEmpty);
      expect(repository.commands, calls);
      repository.denied = false;
      await controller.load();
      controller.setCaption('authorized');
      await controller.saveDraft();
      expect(controller.state.phase, MomentsPublicationPhase.saved);
      expect(repository.commands, calls + 1);
    });
  }
  group('MomentsPublicationController', () {
    test('keeps draft collections immutable from caller changes', () {
      final media = [MomentsMediaDraft.demo(0)];
      final audiences = {MomentsAudienceKind.families};
      final draft = MomentsDraft(media: media, audiences: audiences);

      media.add(MomentsMediaDraft.demo(1));
      audiences.add(MomentsAudienceKind.students);

      expect(draft.media, hasLength(1));
      expect(draft.audiences, {MomentsAudienceKind.families});
      expect(() => draft.media.add(MomentsMediaDraft.demo(2)), throwsUnsupportedError);
    });

    test('loads an editable draft from the repository', () async {
      final repository = InMemoryMomentsPublicationRepository(
        draft: MomentsDraft(caption: 'Um momento salvo'),
      );
      final controller = MomentsPublicationController(
        repository: repository,
        context: MomentsPublicationContext.demo,
      );

      await controller.load();

      expect(controller.state.phase, MomentsPublicationPhase.editing);
      expect(controller.state.draft.caption, 'Um momento salvo');
    });

    test('maps a draft loading failure to user-facing state', () async {
      final controller = MomentsPublicationController(
        repository: const _FailingMomentsRepository(),
        context: MomentsPublicationContext.demo,
      );

      await controller.load();

      expect(controller.state.phase, MomentsPublicationPhase.failure);
      expect(controller.state.message, 'Não foi possível carregar o rascunho.');
    });

    test('limits captions to 220 grapheme clusters', () {
      final controller = MomentsPublicationController(
        repository: InMemoryMomentsPublicationRepository(),
        context: MomentsPublicationContext.demo,
      );

      controller.setCaption('${'a' * 219}👨‍👩‍👧‍👦extra');

      expect(controller.state.draft.captionCharacters, 220);
      expect(controller.state.draft.caption.endsWith('👨‍👩‍👧‍👦'), isTrue);
    });

    test('keeps at most five media items', () {
      final controller = MomentsPublicationController(
        repository: InMemoryMomentsPublicationRepository(),
        context: MomentsPublicationContext.demo,
      );

      for (var index = 0; index < 6; index += 1) {
        controller.addMedia(MomentsMediaDraft.demo(index));
      }

      expect(controller.state.draft.media, hasLength(5));
      expect(controller.state.message, 'Você pode adicionar até 5 mídias.');
    });

    test('saves the current draft and option', () async {
      final repository = InMemoryMomentsPublicationRepository();
      final controller = MomentsPublicationController(
        repository: repository,
        context: MomentsPublicationContext.demo,
      );
      controller
        ..setCaption('Aprender juntos é crescer juntos.')
        ..setSaveAsDraft(true)
        ..toggleAudience(MomentsAudienceKind.families);

      await controller.saveDraft();

      expect(controller.state.phase, MomentsPublicationPhase.saved);
      expect(controller.state.draft.saveAsDraft, isTrue);
      expect(repository.savedDraft?.caption, contains('Aprender juntos'));
    });

    test('requires media and audience before publishing', () async {
      final controller = MomentsPublicationController(
        repository: InMemoryMomentsPublicationRepository(),
        context: MomentsPublicationContext.demo,
      );

      expect(await controller.publish(), isNull);
      expect(controller.state.message, 'Adicione pelo menos uma mídia para publicar.');

      controller.addMedia(MomentsMediaDraft.demo(0));
      expect(await controller.publish(), isNull);
      expect(controller.state.message, 'Escolha pelo menos um público.');
    });

    test('publishes an eligible moment immediately', () async {
      final repository = InMemoryMomentsPublicationRepository();
      final controller = MomentsPublicationController(
        repository: repository,
        context: MomentsPublicationContext.demo,
      );
      controller
        ..addMedia(MomentsMediaDraft.demo(0))
        ..toggleAudience(MomentsAudienceKind.families);

      final publication = await controller.publish();

      expect(publication?.status, MomentsStatus.published);
      expect(controller.state.phase, MomentsPublicationPhase.success);
      expect(repository.lastPublication?.id, publication?.id);
    });

    test('maps conflicts and authorization failures without leaking exceptions', () async {
      final conflictController =
          MomentsPublicationController(
              repository: _ThrowingMomentsRepository(MomentsPublicationConflict()),
              context: MomentsPublicationContext.demo,
            )
            ..addMedia(MomentsMediaDraft.demo(0))
            ..toggleAudience(MomentsAudienceKind.families);
      final unauthorizedController = MomentsPublicationController(
        repository: _ThrowingMomentsRepository(MomentsPublicationUnauthorized()),
        context: MomentsPublicationContext.demo,
      );

      expect(await conflictController.publish(), isNull);
      expect(conflictController.state.phase, MomentsPublicationPhase.conflict);
      expect(conflictController.state.message, 'O rascunho mudou. Recarregue e tente novamente.');

      await unauthorizedController.saveDraft();
      expect(unauthorizedController.state.phase, MomentsPublicationPhase.unauthorized);
      expect(unauthorizedController.state.message, 'Você não pode publicar neste contexto.');
    });

    test('preserves edits made during save and keeps the command single-flight', () async {
      final repository = _DeferredMomentsRepository();
      final controller = MomentsPublicationController(
        repository: repository,
        context: MomentsPublicationContext.demo,
      )..setCaption('Legenda A');

      final firstSave = controller.saveDraft();
      controller.setCaption('Legenda B');
      final duplicateSave = controller.saveDraft();

      expect(repository.saveCalls, 1);
      repository.saveCompleter.complete(
        repository.savedSnapshots.single.copyWith(id: 'moment-1', version: 1),
      );
      await Future.wait([firstSave, duplicateSave]);

      expect(controller.state.draft.caption, 'Legenda B');
      expect(controller.state.draft.id, 'moment-1');
      expect(controller.state.draft.version, 1);
      expect(controller.state.phase, MomentsPublicationPhase.editing);
    });

    test('reports a confirmed publish exactly once after an edit', () async {
      final repository = _DeferredMomentsRepository();
      final controller =
          MomentsPublicationController(
              repository: repository,
              context: MomentsPublicationContext.demo,
            )
            ..setCaption('Legenda A')
            ..addMedia(MomentsMediaDraft.demo(0))
            ..toggleAudience(MomentsAudienceKind.families);

      final firstPublish = controller.publish();
      final duplicatePublish = controller.publish();
      controller.setCaption('Legenda B');
      repository.publishCompleter.complete(
        const MomentsPublication(id: 'publication-1', status: MomentsStatus.published),
      );

      expect(await firstPublish, isNotNull);
      expect(await duplicatePublish, isNull);
      expect(repository.publishCalls, 1);
      expect(controller.state.draft.caption, 'Legenda A');
      expect(controller.state.phase, MomentsPublicationPhase.success);
    });

    test('leaves an edited draft retryable when save fails', () async {
      final repository = _DeferredErrorMomentsRepository();
      final controller = MomentsPublicationController(
        repository: repository,
        context: MomentsPublicationContext.demo,
      )..setCaption('Legenda A');

      final save = controller.saveDraft();
      controller.setCaption('Legenda B');
      repository.saveCompleter.completeError(Exception('offline'));
      await save;

      expect(controller.state.draft.caption, 'Legenda B');
      expect(controller.state.phase, MomentsPublicationPhase.failure);
      expect(controller.state.message, 'Não foi possível salvar o rascunho.');
    });

    test('keeps the published snapshot stable and retryable when publish fails', () async {
      final repository = _DeferredErrorMomentsRepository();
      final controller =
          MomentsPublicationController(
              repository: repository,
              context: MomentsPublicationContext.demo,
            )
            ..setCaption('Legenda A')
            ..addMedia(MomentsMediaDraft.demo(0))
            ..toggleAudience(MomentsAudienceKind.families);

      final publish = controller.publish();
      controller.setCaption('Legenda ignorada durante publicação');
      repository.publishCompleter.completeError(Exception('offline'));
      await publish;

      expect(controller.state.draft.caption, 'Legenda A');
      expect(controller.state.phase, MomentsPublicationPhase.failure);
      expect(controller.state.message, 'Não foi possível publicar agora.');
    });

    test('shares the single-flight lock between save and publish', () async {
      final repository = _DeferredMomentsRepository();
      final controller =
          MomentsPublicationController(
              repository: repository,
              context: MomentsPublicationContext.demo,
            )
            ..addMedia(MomentsMediaDraft.demo(0))
            ..toggleAudience(MomentsAudienceKind.families);

      final save = controller.saveDraft();
      final publish = controller.publish();

      expect(repository.saveCalls, 1);
      expect(repository.publishCalls, 0);
      expect(await publish, isNull);
      repository.saveCompleter.complete(MomentsDraft(id: 'moment-1', version: 1));
      await save;
    });

    test('does not save the empty initial draft while load is pending', () async {
      final repository = _DeferredLoadMomentsRepository();
      final controller = MomentsPublicationController(
        repository: repository,
        context: MomentsPublicationContext.demo,
      );

      final load = controller.load();
      await controller.saveDraft();

      expect(repository.saveCalls, 0);
      repository.loadCompleter.complete(
        MomentsDraft(id: 'moment-existing', caption: 'Existente', version: 3),
      );
      await load;

      expect(controller.state.draft.id, 'moment-existing');
      expect(controller.state.draft.caption, 'Existente');
      expect(controller.state.draft.version, 3);
    });

    test('ignores command completion after dispose', () async {
      final repository = _DeferredMomentsRepository();
      final controller = MomentsPublicationController(
        repository: repository,
        context: MomentsPublicationContext.demo,
      );

      final save = controller.saveDraft();
      controller.dispose();
      repository.saveCompleter.complete(MomentsDraft(id: 'moment-1', version: 1));

      await expectLater(save, completes);
    });

    test('ignores publish completion after dispose', () async {
      final repository = _DeferredMomentsRepository();
      final controller =
          MomentsPublicationController(
              repository: repository,
              context: MomentsPublicationContext.demo,
            )
            ..addMedia(MomentsMediaDraft.demo(0))
            ..toggleAudience(MomentsAudienceKind.families);

      final publish = controller.publish();
      controller.dispose();
      repository.publishCompleter.complete(
        const MomentsPublication(id: 'publication-1', status: MomentsStatus.published),
      );

      await expectLater(publish, completion(isNull));
    });
  });
}

final _protectedMedia = MomentsMediaDraft(
  localId: 'synthetic',
  bytes: Uint8List.fromList([1, 2]),
  remoteAssetId: 'asset',
  remoteUrl: 'https://signed.test/private',
);

final class _DenyingLifecycleRepository implements MomentsPublicationRepository {
  bool denied = false;
  int commands = 0;
  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) async {
    if (denied) throw MomentsPublicationUnauthorized();
    return MomentsDraft(
      id: 'draft',
      caption: 'private',
      media: [_protectedMedia],
      audiences: {MomentsAudienceKind.families},
    );
  }

  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) async {
    commands++;
    if (denied) throw MomentsPublicationUnauthorized();
    return draft;
  }

  @override
  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft) async {
    commands++;
    if (denied) throw MomentsPublicationUnauthorized();
    return const MomentsPublication(id: 'publication', status: MomentsStatus.published);
  }
}

final class _DeferredLoadMomentsRepository implements MomentsPublicationRepository {
  final loadCompleter = Completer<MomentsDraft?>();
  var saveCalls = 0;

  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) => loadCompleter.future;

  @override
  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft) async =>
      const MomentsPublication(id: 'publication-1', status: MomentsStatus.published);

  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) async {
    saveCalls += 1;
    return draft;
  }
}

final class _DeferredErrorMomentsRepository implements MomentsPublicationRepository {
  final saveCompleter = Completer<MomentsDraft>();
  final publishCompleter = Completer<MomentsPublication>();

  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) async => null;

  @override
  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft) =>
      publishCompleter.future;

  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) =>
      saveCompleter.future;
}

final class _DeferredMomentsRepository implements MomentsPublicationRepository {
  final saveCompleter = Completer<MomentsDraft>();
  final publishCompleter = Completer<MomentsPublication>();
  final savedSnapshots = <MomentsDraft>[];
  var saveCalls = 0;
  var publishCalls = 0;

  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) async => null;

  @override
  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft) {
    publishCalls += 1;
    return publishCompleter.future;
  }

  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) {
    saveCalls += 1;
    savedSnapshots.add(draft);
    return saveCompleter.future;
  }
}

final class _ThrowingMomentsRepository implements MomentsPublicationRepository {
  const _ThrowingMomentsRepository(this.error);

  final Exception error;

  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) => Future.error(error);

  @override
  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft) =>
      Future.error(error);

  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) =>
      Future.error(error);
}

final class _FailingMomentsRepository implements MomentsPublicationRepository {
  const _FailingMomentsRepository();

  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) =>
      Future.error(Exception('offline'));

  @override
  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft) =>
      Future.error(Exception('offline'));

  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) =>
      Future.error(Exception('offline'));
}
