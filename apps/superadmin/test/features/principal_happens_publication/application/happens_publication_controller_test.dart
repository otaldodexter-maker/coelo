import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/application/happens_publication_controller.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/domain/happens_publication.dart';

void main() {
  group('HappensPublicationController', () {
    test('limits media to six items', () {
      final controller = HappensPublicationController(
        repository: InMemoryHappensPublicationRepository(),
        context: HappensPublicationContext.demo,
      );

      for (var index = 0; index < 7; index++) {
        controller.addMedia(
          HappensMediaDraft(
            localId: 'media-$index',
            name: 'photo-$index.jpg',
            mimeType: 'image/jpeg',
            bytes: Uint8List.fromList([index]),
          ),
        );
      }

      expect(controller.state.draft.media, hasLength(6));
      expect(controller.state.message, 'Você pode adicionar até 6 mídias.');
    });

    test('autosave persists edits when enabled', () async {
      final repository = InMemoryHappensPublicationRepository();
      final controller = HappensPublicationController(
        repository: repository,
        context: HappensPublicationContext.demo,
        autosaveDelay: Duration.zero,
      );

      controller.setAutosave(true);
      controller.setCaption('Uma nova publicação');
      await Future<void>.delayed(Duration.zero);

      expect(repository.savedDraft?.caption, 'Uma nova publicação');
      expect(controller.state.phase, HappensPublicationPhase.saved);
    });

    test('disabling autosave cancels a pending save', () async {
      final repository = _FailureRepository();
      final controller = HappensPublicationController(
        repository: repository,
        context: HappensPublicationContext.demo,
        autosaveDelay: const Duration(milliseconds: 20),
      );

      controller
        ..setAutosave(true)
        ..setCaption('Ainda editando')
        ..setAutosave(false);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(repository.saveCalls, 0);
    });

    test('publishing cancels a pending autosave to avoid conflicting writes', () async {
      final repository = _FailureRepository();
      final controller = HappensPublicationController(
        repository: repository,
        context: HappensPublicationContext.demo,
        autosaveDelay: const Duration(milliseconds: 20),
      );

      controller
        ..setAutosave(true)
        ..setCaption('Legenda')
        ..toggleAudience(HappensAudienceKind.families);
      await controller.publish();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(repository.saveCalls, 1);
    });

    test('serializes save and publish while a publication is in flight', () async {
      final repository = _BlockingRepository();
      final controller =
          HappensPublicationController(
              repository: repository,
              context: HappensPublicationContext.demo,
            )
            ..setCaption('Legenda')
            ..toggleAudience(HappensAudienceKind.families);

      final firstPublish = controller.publish();
      await repository.saveStarted.future;

      expect(controller.operationInFlight, isTrue);
      expect(await controller.publish(), isNull);
      await controller.saveDraft();
      expect(repository.saveCalls, 1);

      repository.saved.complete(controller.state.draft.copyWith(id: 'draft-1', version: 1));
      expect(await firstPublish, isNotNull);
      expect(repository.publishCalls, 1);
      expect(controller.operationInFlight, isFalse);
    });

    test('publishes immediately or schedules from publishAt', () async {
      final repository = InMemoryHappensPublicationRepository();
      final controller = HappensPublicationController(
        repository: repository,
        context: HappensPublicationContext.demo,
      );
      controller.setCaption('Legenda');
      controller.toggleAudience(HappensAudienceKind.families);

      await controller.publish();
      expect(repository.lastPublication?.status, HappensPostStatus.published);

      controller.setPublishAt(DateTime.utc(2030, 1, 2, 12));
      await controller.publish();
      expect(repository.lastPublication?.status, HappensPostStatus.scheduled);
    });

    test('reorders media without mutating the exposed collection', () {
      final controller = HappensPublicationController(
        repository: InMemoryHappensPublicationRepository(),
        context: HappensPublicationContext.demo,
      );
      for (final id in ['a', 'b', 'c']) {
        controller.addMedia(
          HappensMediaDraft(
            localId: id,
            name: '$id.jpg',
            mimeType: 'image/jpeg',
            bytes: Uint8List.fromList([1]),
          ),
        );
      }

      controller.reorderMedia(0, 3);

      expect(controller.state.draft.media.map((item) => item.localId), ['b', 'c', 'a']);
      expect(
        () => controller.state.draft.media.add(controller.state.draft.media.first),
        throwsUnsupportedError,
      );
    });

    test('keeps media when remote removal fails', () async {
      final repository = _FailureRepository(failRemove: true);
      final controller = HappensPublicationController(
        repository: repository,
        context: HappensPublicationContext.demo,
      );
      controller.addMedia(_media('a', assetId: 'asset-a'));

      await controller.removeMedia(0);

      expect(controller.state.draft.media, hasLength(1));
      expect(controller.state.phase, HappensPublicationPhase.failure);
      expect(controller.state.message, 'Não foi possível remover a mídia.');
    });

    test('reports a recoverable failure when loading the draft fails', () async {
      final controller = HappensPublicationController(
        repository: _FailureRepository(failLoad: true),
        context: HappensPublicationContext.demo,
      );

      await controller.load();

      expect(controller.state.phase, HappensPublicationPhase.failure);
      expect(controller.state.message, 'Não foi possível carregar o rascunho.');
    });

    test('keeps upload receipts so retry skips completed media', () async {
      final repository = _FailureRepository(failSecondUploadOnce: true);
      final controller = HappensPublicationController(
        repository: repository,
        context: HappensPublicationContext.demo,
      );
      controller
        ..setCaption('Legenda')
        ..toggleAudience(HappensAudienceKind.families)
        ..addMedia(_media('a'))
        ..addMedia(_media('b'));

      expect(await controller.publish(), isNull);
      expect(controller.state.draft.media.first.assetId, 'asset-a');

      expect(await controller.publish(), isNotNull);
      expect(repository.prepareCalls['a'], 1);
      expect(repository.prepareCalls['b'], 2);
    });

    test('ignores a load completion after dispose', () async {
      final repository = _DeferredLoadRepository();
      final controller = HappensPublicationController(
        repository: repository,
        context: HappensPublicationContext.demo,
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      final load = controller.load();
      expect(notifications, 1);
      controller.dispose();
      repository.loaded.complete(HappensPostDraft(caption: 'stale'));

      await load;
      expect(notifications, 1);
    });

    test('blocks edits and concurrent commands while saving', () async {
      final repository = _BlockingRepository();
      final controller = HappensPublicationController(
        repository: repository,
        context: HappensPublicationContext.demo,
      )..setCaption('Legenda A');

      final save = controller.saveDraft();
      await repository.saveStarted.future;
      controller.setCaption('Legenda B');
      await controller.saveDraft();

      expect(controller.state.draft.caption, 'Legenda A');
      expect(repository.saveCalls, 1);
      repository.saved.complete(controller.state.draft.copyWith(id: 'draft-1', version: 1));
      await save;
      expect(controller.operationInFlight, isFalse);
    });

    test('rearms autosave after an async media removal', () async {
      final repository = _DeferredRemoveRepository();
      final controller =
          HappensPublicationController(
              repository: repository,
              context: HappensPublicationContext.demo,
              autosaveDelay: const Duration(milliseconds: 10),
            )
            ..setAutosave(true)
            ..addMedia(_media('a'));

      final removal = controller.removeMedia(0);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repository.saveCalls, 0);

      repository.removed.complete();
      await removal;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repository.saveCalls, 1);
      expect(repository.lastSaved?.media, isEmpty);
    });

    test('checkpoints the saved identity before a publish retry', () async {
      final repository = _FailOnceAfterSaveRepository();
      final controller =
          HappensPublicationController(
              repository: repository,
              context: HappensPublicationContext.demo,
            )
            ..setCaption('Legenda')
            ..toggleAudience(HappensAudienceKind.families);

      expect(await controller.publish(), isNull);
      expect(controller.state.draft.id, 'draft-1');
      expect(controller.state.draft.version, 1);

      expect(await controller.publish(), isNotNull);
      expect(repository.createCalls, 1);
      expect(repository.savedInputs.map((draft) => (draft.id, draft.version)), [
        (null, 0),
        ('draft-1', 1),
      ]);
    });
  });
}

HappensMediaDraft _media(String id, {String? assetId}) => HappensMediaDraft(
  localId: id,
  name: '$id.jpg',
  mimeType: 'image/jpeg',
  bytes: Uint8List.fromList([1]),
  assetId: assetId,
  objectKey: assetId == null ? null : 'draft/$id.jpg',
);

final class _FailureRepository implements HappensPublicationRepository {
  _FailureRepository({
    this.failLoad = false,
    this.failRemove = false,
    this.failSecondUploadOnce = false,
  });

  final bool failLoad;
  final bool failRemove;
  final bool failSecondUploadOnce;
  final Map<String, int> prepareCalls = {};
  var saveCalls = 0;
  var _secondUploadFailed = false;

  @override
  Future<HappensPostDraft?> loadDraft(HappensPublicationContext context) async {
    if (failLoad) throw Exception('load_failed');
    return null;
  }

  @override
  Future<HappensPostDraft> saveDraft(
    HappensPublicationContext context,
    HappensPostDraft draft,
  ) async {
    saveCalls++;
    return draft.copyWith(id: draft.id ?? 'draft-1', version: draft.version + 1);
  }

  @override
  Future<HappensUploadIntent> prepareMedia(
    HappensPublicationContext context,
    String postId,
    HappensMediaDraft media,
    int displayOrder,
  ) async {
    prepareCalls.update(media.localId, (value) => value + 1, ifAbsent: () => 1);
    return HappensUploadIntent(
      assetId: 'asset-${media.localId}',
      institutionId: context.institutionId,
      postId: postId,
      requestId: media.localId,
      objectKey: '$displayOrder',
      token: 'token',
      displayOrder: displayOrder,
    );
  }

  @override
  Future<HappensMediaDraft> finalizeMedia(
    HappensUploadIntent intent,
    HappensMediaDraft media,
  ) async {
    if (failSecondUploadOnce && media.localId == 'b' && !_secondUploadFailed) {
      _secondUploadFailed = true;
      throw Exception('upload_failed');
    }
    return HappensMediaDraft(
      localId: media.localId,
      name: media.name,
      mimeType: media.mimeType,
      bytes: media.bytes,
      assetId: intent.assetId,
      objectKey: intent.objectKey,
    );
  }

  @override
  Future<void> removeMedia(HappensPublicationContext context, HappensMediaDraft media) async {
    if (failRemove) throw Exception('remove_failed');
  }

  @override
  Future<HappensPublication> publish(
    HappensPublicationContext context,
    HappensPostDraft draft,
  ) async => HappensPublication(
    id: draft.id!,
    status: HappensPostStatus.published,
    publishAt: DateTime.utc(2030),
  );
}

final class _BlockingRepository implements HappensPublicationRepository {
  final saveStarted = Completer<void>();
  final saved = Completer<HappensPostDraft>();
  var saveCalls = 0;
  var publishCalls = 0;

  @override
  Future<HappensPostDraft?> loadDraft(HappensPublicationContext context) async => null;

  @override
  Future<HappensPostDraft> saveDraft(HappensPublicationContext context, HappensPostDraft draft) {
    saveCalls++;
    if (!saveStarted.isCompleted) saveStarted.complete();
    return saved.future;
  }

  @override
  Future<HappensUploadIntent> prepareMedia(
    HappensPublicationContext context,
    String postId,
    HappensMediaDraft media,
    int displayOrder,
  ) => throw UnimplementedError();

  @override
  Future<HappensMediaDraft> finalizeMedia(HappensUploadIntent intent, HappensMediaDraft media) =>
      throw UnimplementedError();

  @override
  Future<void> removeMedia(HappensPublicationContext context, HappensMediaDraft media) async {}

  @override
  Future<HappensPublication> publish(
    HappensPublicationContext context,
    HappensPostDraft draft,
  ) async {
    publishCalls++;
    return HappensPublication(
      id: draft.id!,
      status: HappensPostStatus.published,
      publishAt: DateTime.utc(2030),
    );
  }
}

final class _DeferredLoadRepository implements HappensPublicationRepository {
  final loaded = Completer<HappensPostDraft?>();

  @override
  Future<HappensPostDraft?> loadDraft(HappensPublicationContext context) => loaded.future;

  @override
  Future<HappensPostDraft> saveDraft(HappensPublicationContext context, HappensPostDraft draft) =>
      throw UnimplementedError();

  @override
  Future<HappensUploadIntent> prepareMedia(
    HappensPublicationContext context,
    String postId,
    HappensMediaDraft media,
    int displayOrder,
  ) => throw UnimplementedError();

  @override
  Future<HappensMediaDraft> finalizeMedia(HappensUploadIntent intent, HappensMediaDraft media) =>
      throw UnimplementedError();

  @override
  Future<void> removeMedia(HappensPublicationContext context, HappensMediaDraft media) =>
      throw UnimplementedError();

  @override
  Future<HappensPublication> publish(HappensPublicationContext context, HappensPostDraft draft) =>
      throw UnimplementedError();
}

final class _DeferredRemoveRepository implements HappensPublicationRepository {
  final removed = Completer<void>();
  HappensPostDraft? lastSaved;
  var saveCalls = 0;

  @override
  Future<HappensPostDraft?> loadDraft(HappensPublicationContext context) async => null;

  @override
  Future<HappensPostDraft> saveDraft(
    HappensPublicationContext context,
    HappensPostDraft draft,
  ) async {
    saveCalls++;
    lastSaved = draft.copyWith(id: 'draft-1', version: draft.version + 1);
    return lastSaved!;
  }

  @override
  Future<void> removeMedia(HappensPublicationContext context, HappensMediaDraft media) =>
      removed.future;

  @override
  Future<HappensUploadIntent> prepareMedia(
    HappensPublicationContext context,
    String postId,
    HappensMediaDraft media,
    int displayOrder,
  ) => throw UnimplementedError();

  @override
  Future<HappensMediaDraft> finalizeMedia(HappensUploadIntent intent, HappensMediaDraft media) =>
      throw UnimplementedError();

  @override
  Future<HappensPublication> publish(HappensPublicationContext context, HappensPostDraft draft) =>
      throw UnimplementedError();
}

final class _FailOnceAfterSaveRepository implements HappensPublicationRepository {
  final savedInputs = <HappensPostDraft>[];
  var createCalls = 0;
  var publishCalls = 0;

  @override
  Future<HappensPostDraft?> loadDraft(HappensPublicationContext context) async => null;

  @override
  Future<HappensPostDraft> saveDraft(
    HappensPublicationContext context,
    HappensPostDraft draft,
  ) async {
    savedInputs.add(draft);
    if (draft.id == null) createCalls++;
    return draft.copyWith(id: draft.id ?? 'draft-$createCalls', version: draft.version + 1);
  }

  @override
  Future<HappensPublication> publish(
    HappensPublicationContext context,
    HappensPostDraft draft,
  ) async {
    publishCalls++;
    if (publishCalls == 1) throw Exception('response_lost');
    return HappensPublication(
      id: draft.id!,
      status: HappensPostStatus.published,
      publishAt: DateTime.utc(2030),
    );
  }

  @override
  Future<HappensUploadIntent> prepareMedia(
    HappensPublicationContext context,
    String postId,
    HappensMediaDraft media,
    int displayOrder,
  ) => throw UnimplementedError();

  @override
  Future<HappensMediaDraft> finalizeMedia(HappensUploadIntent intent, HappensMediaDraft media) =>
      throw UnimplementedError();

  @override
  Future<void> removeMedia(HappensPublicationContext context, HappensMediaDraft media) async {}
}
