import 'package:coelo_superadmin/features/principal_moments_publication/application/moments_publication_controller.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/domain/moments_publication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    test('limits captions to 2200 grapheme clusters', () {
      final controller = MomentsPublicationController(
        repository: InMemoryMomentsPublicationRepository(),
        context: MomentsPublicationContext.demo,
      );

      controller.setCaption('${'a' * 2199}👨‍👩‍👧‍👦extra');

      expect(controller.state.draft.captionCharacters, 2200);
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
        ..setCaption('Aprender juntos é crescer juntos. 🌱')
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
  });
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
