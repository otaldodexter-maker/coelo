import 'dart:async';

import 'package:coelo_superadmin/features/principal_moments_publication/application/moments_publication_controller.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/domain/moments_publication.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/presentation/principal_moments_publication_page.dart';
import 'package:coelo_superadmin/features/principal_shared/presentation/principal_publication_frame.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<MomentsPublicationController> pumpPage(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    ThemeData? theme,
    VoidCallback? onAddMedia,
    VoidCallback? onEditCover,
    VoidCallback? onSelectContext,
    VoidCallback? onOpenSchedule,
    ValueChanged<MomentsDraft>? onDraftSaved,
    ValueChanged<MomentsPublication>? onPublished,
    VoidCallback? onClose,
    MomentsPublicationRepository? repository,
    bool settle = true,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = MomentsPublicationController(
      repository:
          repository ??
          InMemoryMomentsPublicationRepository(
            draft: MomentsDraft(
              caption: 'Aprender juntos é crescer juntos.',
              audiences: const {MomentsAudienceKind.families},
              media: List.generate(5, MomentsMediaDraft.demo),
            ),
          ),
      context: MomentsPublicationContext.demo,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? CoeloTheme.light,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: PrincipalMomentsPublicationPage(
            controller: controller,
            onAddMedia: onAddMedia,
            onEditCover: onEditCover,
            onSelectContext: onSelectContext,
            onOpenSchedule: onOpenSchedule,
            onDraftSaved: onDraftSaved,
            onPublished: onPublished,
            onClose: onClose,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return controller;
  }

  testWidgets('renders the approved composer anatomy on mobile', (tester) async {
    await pumpPage(tester, size: const Size(375, 900));

    expect(find.byType(PrincipalPublicationFrame), findsOneWidget);
    expect(find.byType(PrincipalPublicationStepNavigation), findsOneWidget);
    expect(find.byType(PrincipalPublicationActionFooter), findsOneWidget);
    expect(find.byKey(const Key('principal-publication-step-summary')), findsOneWidget);
    expect(find.text('Mídia'), findsOneWidget);
    expect(find.text('Legenda'), findsWidgets);
    expect(find.text('Salvar rascunho'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.byKey(const Key('moments-publication-preview')), findsNothing);
    expect(find.byType(CoeloFormTextField), findsOneWidget);
    final media = tester.widget<AspectRatio>(
      find.byKey(const Key('moments-publication-primary-media')),
    );
    expect(media.aspectRatio, 9 / 16);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders video media as an honest unavailable preview, never as an image', (
    tester,
  ) async {
    final video = MomentsMediaDraft.local(
      localId: 'video-1',
      name: 'apresentacao.mp4',
      mimeType: 'video/mp4',
      bytes: Uint8List.fromList([1, 2, 3]),
      durationMilliseconds: 12000,
    );
    await pumpPage(
      tester,
      size: const Size(375, 900),
      repository: InMemoryMomentsPublicationRepository(draft: MomentsDraft(media: [video])),
    );

    expect(find.byKey(const Key('moments-media-video-unavailable')), findsWidgets);
    expect(find.byKey(const Key('moments-media-image')), findsNothing);
    expect(find.text('Prévia de vídeo indisponível'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('demo caption avoids unsupported emoji glyphs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: CoeloTheme.light, home: const PrincipalMomentsPublicationPage.demo()),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('moments-publication-caption')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.controller.text, isNot(contains('🌱')));
  });

  testWidgets('uses the canonical wizard navigation and footer hierarchy', (tester) async {
    await pumpPage(tester, size: const Size(1440, 1000));

    expect(find.text('Conteúdo'), findsOneWidget);
    expect(find.text('Público'), findsOneWidget);
    expect(find.text('Revisão'), findsOneWidget);
    expect(find.byKey(const Key('moments-publication-cancel')), findsOneWidget);
    expect(find.byKey(const Key('moments-publication-save')), findsOneWidget);
    expect(find.byKey(const Key('moments-publication-continue')), findsOneWidget);
    expect(find.byKey(const Key('moments-publication-publish')), findsNothing);
    expect(find.text('Sua publicação'), findsOneWidget);
    expect(find.byKey(const Key('moments-publication-desktop-preview')), findsOneWidget);

    await tester.tap(find.byKey(const Key('moments-publication-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Público e contexto'), findsOneWidget);
    expect(find.text('Agendamento'), findsOneWidget);
    expect(find.text('Opções'), findsOneWidget);
    expect(find.byKey(const Key('moments-publication-previous')), findsOneWidget);

    await tester.tap(find.byKey(const Key('moments-publication-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('moments-publication-preview')), findsOneWidget);
    expect(find.byKey(const Key('moments-publication-publish')), findsOneWidget);
  });

  testWidgets('context and schedule expose real injectable actions', (tester) async {
    var contextCalls = 0;
    var scheduleCalls = 0;
    await pumpPage(
      tester,
      size: const Size(768, 1024),
      onSelectContext: () => contextCalls += 1,
      onOpenSchedule: () => scheduleCalls += 1,
    );

    await tester.tap(find.byKey(const Key('moments-publication-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moments-publication-context')));
    await tester.ensureVisible(find.byKey(const Key('moments-publication-schedule')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moments-publication-schedule')));

    expect(contextCalls, 1);
    expect(scheduleCalls, 1);
  });

  testWidgets('context action resolves Coelo hover and focus states', (tester) async {
    await pumpPage(tester, size: const Size(1440, 1000));
    await tester.tap(find.byKey(const Key('moments-publication-continue')));
    await tester.pumpAndSettle();
    final contextAction = tester.widget<OutlinedButton>(
      find.byKey(const Key('moments-publication-context')),
    );
    final colors = CoeloTheme.light.colorScheme;

    expect(
      contextAction.style?.backgroundColor?.resolve({WidgetState.hovered}),
      colors.primaryContainer,
    );
    expect(
      contextAction.style?.backgroundColor?.resolve({WidgetState.focused}),
      colors.primaryContainer,
    );
    expect(contextAction.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
  });

  testWidgets('keeps preview synchronized with caption and audience', (tester) async {
    final controller = await pumpPage(tester, size: const Size(1440, 1000));

    await tester.enterText(
      find.byKey(const Key('moments-publication-caption')),
      'Descobertas que ficam para a vida toda.',
    );
    await tester.tap(find.byKey(const Key('moments-publication-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moments-audience-students')));
    await tester.tap(find.byKey(const Key('moments-publication-continue')));
    await tester.pump();

    expect(find.byKey(const Key('moments-publication-preview')), findsOneWidget);
    expect(controller.state.draft.caption, 'Descobertas que ficam para a vida toda.');
    expect(controller.state.draft.audiences, contains(MomentsAudienceKind.students));
    expect(find.text('Descobertas que ficam para a vida toda.'), findsWidgets);
  });

  testWidgets('invokes media ports and persists draft option', (tester) async {
    var addCalls = 0;
    var coverCalls = 0;
    final controller = await pumpPage(
      tester,
      size: const Size(768, 1024),
      onAddMedia: () => addCalls += 1,
      onEditCover: () => coverCalls += 1,
    );

    await tester.ensureVisible(find.byKey(const Key('moments-publication-add-media')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moments-publication-add-media')));
    await tester.ensureVisible(find.byKey(const Key('moments-publication-edit-cover')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moments-publication-edit-cover')));
    await tester.tap(find.byKey(const Key('moments-publication-continue')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('moments-publication-save-toggle')));
    expect(find.byType(PrincipalPublicationToggleField), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moments-publication-save-toggle')));
    await tester.pump();

    expect(addCalls, 1);
    expect(coverCalls, 1);
    expect(controller.state.draft.saveAsDraft, isTrue);
  });

  testWidgets('fails closed when productive media integration is absent', (tester) async {
    final controller = await pumpPage(tester, size: const Size(768, 1024));
    final originalMedia = controller.state.draft.media;

    await tester.ensureVisible(find.byKey(const Key('moments-publication-add-media')));
    await tester.tap(find.byKey(const Key('moments-publication-add-media')));
    await tester.pumpAndSettle();

    expect(controller.state.draft.media, originalMedia);
    expect(
      find.text('Adicionar mídia está indisponível sem a integração autorizada.'),
      findsOneWidget,
    );
  });

  testWidgets('selects media and reports successful completion to the host flow', (tester) async {
    MomentsPublication? published;
    var closeCalls = 0;
    await pumpPage(
      tester,
      size: const Size(768, 1024),
      onPublished: (value) => published = value,
      onClose: () => closeCalls += 1,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('moments-media-moment-media-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('moments-media-moment-media-1')));
    await tester.pump();
    expect(find.text('2/5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('moments-publication-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moments-publication-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moments-publication-publish')));
    await tester.pumpAndSettle();

    expect(published?.status, MomentsStatus.published);
    expect(closeCalls, 1);
  });

  testWidgets('saves and publishes through the controller', (tester) async {
    final controller = await pumpPage(tester, size: const Size(375, 900));

    await tester.tap(find.byKey(const Key('moments-publication-save')));
    await tester.pumpAndSettle();
    expect(controller.state.phase, MomentsPublicationPhase.saved);

    await tester.tap(find.byKey(const Key('moments-publication-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moments-publication-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moments-publication-publish')));
    await tester.pumpAndSettle();
    expect(controller.state.phase, MomentsPublicationPhase.success);
  });

  testWidgets('does not close or overwrite an edit made while saving', (tester) async {
    final repository = _DeferredSaveMomentsRepository();
    var closeCalls = 0;
    final controller = await pumpPage(
      tester,
      size: const Size(768, 1024),
      repository: repository,
      onClose: () => closeCalls += 1,
    );

    await tester.enterText(find.byKey(const Key('moments-publication-caption')), 'Legenda A');
    await tester.tap(find.byKey(const Key('moments-publication-save')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('moments-publication-caption')), 'Legenda B');
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('moments-publication-save'))).onPressed,
      isNull,
    );
    expect(find.byType(SnackBar), findsNothing);
    repository.saveCompleter.complete(
      repository.savedSnapshot!.copyWith(id: 'moment-1', version: 1),
    );
    await tester.pumpAndSettle();

    expect(closeCalls, 0);
    expect(controller.state.phase, MomentsPublicationPhase.editing);
    expect(controller.state.draft.caption, 'Legenda B');
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'Legenda B');
  });

  testWidgets('keeps footer actions disabled while the initial load is pending', (tester) async {
    final repository = _DeferredPageLoadMomentsRepository();
    await pumpPage(tester, size: const Size(768, 1024), repository: repository, settle: false);

    expect(find.byKey(const Key('moments-publication-loading')), findsOneWidget);
    expect(find.byKey(const Key('moments-publication-caption')), findsNothing);
    expect(find.byKey(const Key('moments-publication-save')), findsNothing);
    expect(find.byKey(const Key('moments-publication-continue')), findsNothing);
    expect(repository.saveCalls, 0);

    repository.loadCompleter.complete(MomentsDraft(caption: 'Existente'));
    await tester.pumpAndSettle();
  });

  testWidgets('locks the editable body while publish is pending', (tester) async {
    final repository = _DeferredPagePublishMomentsRepository();
    var publishedCalls = 0;
    var closeCalls = 0;
    final controller = await pumpPage(
      tester,
      size: const Size(768, 1024),
      repository: repository,
      onPublished: (_) => publishedCalls += 1,
      onClose: () => closeCalls += 1,
    );

    await tester.tap(find.byKey(const Key('moments-publication-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moments-publication-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moments-publication-publish')));
    await tester.pump();

    expect(
      tester
          .widget<AbsorbPointer>(find.byKey(const Key('moments-publication-body-lock')))
          .absorbing,
      isTrue,
    );
    expect(
      tester
          .widget<ExcludeFocus>(find.byKey(const Key('moments-publication-body-focus-lock')))
          .excluding,
      isTrue,
    );
    expect(
      tester
          .widget<ExcludeFocus>(find.byKey(const Key('moments-publication-navigation-focus-lock')))
          .excluding,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    controller.setCaption('Alteração descartável');
    expect(controller.state.draft.caption, 'Legenda publicada');
    expect(controller.state.phase, MomentsPublicationPhase.publishing);

    repository.publishCompleter.complete(
      const MomentsPublication(id: 'publication-1', status: MomentsStatus.published),
    );
    await tester.pumpAndSettle();

    expect(publishedCalls, 1);
    expect(closeCalls, 1);
    expect(
      tester
          .widget<ExcludeFocus>(find.byKey(const Key('moments-publication-body-focus-lock')))
          .excluding,
      isFalse,
    );
  });

  testWidgets('renders the canonical wizard in dark theme', (tester) async {
    await pumpPage(tester, size: const Size(1440, 1000), theme: CoeloTheme.dark);

    expect(find.byType(PrincipalPublicationFrame), findsOneWidget);
    expect(find.byType(PrincipalPublicationStepNavigation), findsOneWidget);
    expect(find.byType(PrincipalPublicationActionFooter), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell completo usa o cabeçalho compartilhado do Principal', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: CoeloTheme.light, home: const PrincipalMomentsPublicationPage.demo()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-moments-publication-logo')), findsOneWidget);
    expect(find.byKey(const Key('principal-moments-publication-notifications')), findsOneWidget);
    expect(find.byKey(const Key('principal-moments-publication-context-avatar')), findsOneWidget);
  });

  testWidgets('mídia persistida usa URL assinada com cover sem distorção', (tester) async {
    final controller = MomentsPublicationController(
      repository: InMemoryMomentsPublicationRepository(
        draft: MomentsDraft(
          media: [
            MomentsMediaDraft(
              localId: 'asset-1',
              name: 'momento.png',
              remoteAssetId: 'asset-1',
              remoteUrl: 'https://signed.test/momento.png',
            ),
          ],
        ),
      ),
      context: MomentsPublicationContext.demo,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalMomentsPublicationPage(controller: controller),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byKey(const Key('moments-media-image')).first);
    expect(image.image, isA<NetworkImage>());
    expect(image.fit, BoxFit.cover);
  });

  testWidgets('rascunho produtivo vazio não injeta mídia de demonstração', (tester) async {
    await pumpPage(
      tester,
      size: const Size(1440, 1000),
      repository: InMemoryMomentsPublicationRepository(draft: MomentsDraft()),
    );

    expect(find.byKey(const Key('moments-publication-empty-media')), findsWidgets);
    expect(find.text('Adicione uma mídia para começar.'), findsWidgets);
    expect(find.text('1/1'), findsNothing);
    expect(find.byKey(const Key('moments-media-image')), findsNothing);
  });

  testWidgets('falha de carregamento mostra painel e retry preserva o fluxo', (tester) async {
    final repository = _RetryingMomentsRepository(loadFailures: 1);
    await pumpPage(tester, size: const Size(768, 1024), repository: repository);

    expect(find.byKey(const Key('moments-publication-failure')), findsOneWidget);
    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
    expect(find.byType(PrincipalPublicationFrame), findsOneWidget);
  });

  testWidgets('falha ao salvar oferece retry da operação sem descartar o rascunho', (tester) async {
    final repository = _RetryingMomentsRepository(saveFailures: 1);
    await pumpPage(tester, size: const Size(768, 1024), repository: repository);

    await tester.tap(find.byKey(const Key('moments-publication-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('moments-publication-failure')), findsOneWidget);
    expect(find.text('Não foi possível salvar o rascunho.'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 2);
    expect(find.byType(PrincipalPublicationFrame), findsOneWidget);
  });

  testWidgets('retry de publicação conclui o fluxo hospedeiro', (tester) async {
    final repository = _RetryingMomentsRepository(publishFailures: 1);
    MomentsPublication? completed;
    var closeCalls = 0;
    await pumpPage(
      tester,
      size: const Size(768, 1024),
      repository: repository,
      onPublished: (value) => completed = value,
      onClose: () => closeCalls += 1,
    );
    await tester.tap(find.byKey(const Key('moments-publication-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moments-publication-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moments-publication-publish')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('moments-publication-failure')), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.publishCalls, 2);
    expect(completed, isNotNull);
    expect(closeCalls, 1);
  });

  testWidgets('conflito exige recarregar o rascunho', (tester) async {
    final conflictRepository = _RetryingMomentsRepository(conflictOnSave: true);
    await pumpPage(tester, size: const Size(768, 1024), repository: conflictRepository);
    await tester.tap(find.byKey(const Key('moments-publication-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('moments-publication-conflict')), findsOneWidget);
    expect(find.text('Rascunho desatualizado'), findsOneWidget);
    expect(find.text('Recarregar rascunho'), findsOneWidget);
  });

  testWidgets('unauthorized bloqueia o publisher sem oferecer retry', (tester) async {
    final unauthorizedRepository = _RetryingMomentsRepository(unauthorizedOnSave: true);
    await pumpPage(tester, size: const Size(768, 1024), repository: unauthorizedRepository);
    await tester.tap(find.byKey(const Key('moments-publication-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('moments-publication-unauthorized')), findsOneWidget);
    expect(find.text('Publicação indisponível'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  for (final width in [375.0, 600.0, 768.0, 839.0, 840.0, 1024.0, 1440.0]) {
    testWidgets('has no overflow at ${width.toInt()} px with enlarged text', (tester) async {
      await pumpPage(tester, size: Size(width, 1100), textScale: 2);

      expect(find.byKey(const Key('moments-publication-scroll')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('moments-publication-continue')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('moments-publication-continue')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

final class _DeferredSaveMomentsRepository implements MomentsPublicationRepository {
  final saveCompleter = Completer<MomentsDraft>();
  MomentsDraft? savedSnapshot;

  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) async => MomentsDraft(
    caption: 'Aprender juntos é crescer juntos.',
    audiences: const {MomentsAudienceKind.families},
    media: List.generate(5, MomentsMediaDraft.demo),
  );

  @override
  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) {
    savedSnapshot = draft;
    return saveCompleter.future;
  }
}

final class _DeferredPageLoadMomentsRepository implements MomentsPublicationRepository {
  final loadCompleter = Completer<MomentsDraft?>();
  var saveCalls = 0;

  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) => loadCompleter.future;

  @override
  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) async {
    saveCalls += 1;
    return draft;
  }
}

final class _DeferredPagePublishMomentsRepository implements MomentsPublicationRepository {
  final publishCompleter = Completer<MomentsPublication>();

  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) async => MomentsDraft(
    caption: 'Legenda publicada',
    audiences: const {MomentsAudienceKind.families},
    media: [MomentsMediaDraft.demo(0)],
  );

  @override
  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft) =>
      publishCompleter.future;

  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) async =>
      draft;
}

final class _RetryingMomentsRepository implements MomentsPublicationRepository {
  _RetryingMomentsRepository({
    this.loadFailures = 0,
    this.saveFailures = 0,
    this.publishFailures = 0,
    this.conflictOnSave = false,
    this.unauthorizedOnSave = false,
  });

  final int loadFailures;
  final int saveFailures;
  final int publishFailures;
  final bool conflictOnSave;
  final bool unauthorizedOnSave;
  var loadCalls = 0;
  var saveCalls = 0;
  var publishCalls = 0;

  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) async {
    loadCalls += 1;
    if (loadCalls <= loadFailures) throw Exception('load failed');
    return MomentsDraft(
      caption: 'Rascunho preservado',
      audiences: const {MomentsAudienceKind.families},
      media: [MomentsMediaDraft.demo(0)],
    );
  }

  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) async {
    saveCalls += 1;
    if (unauthorizedOnSave) throw MomentsPublicationUnauthorized();
    if (conflictOnSave) throw MomentsPublicationConflict();
    if (saveCalls <= saveFailures) throw Exception('save failed');
    return draft.copyWith(id: 'moment-draft', version: saveCalls);
  }

  @override
  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft) async {
    publishCalls += 1;
    if (publishCalls <= publishFailures) throw Exception('publish failed');
    return const MomentsPublication(id: 'moment', status: MomentsStatus.published);
  }
}
