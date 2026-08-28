import 'dart:async';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:coelo_superadmin/features/principal_now_publication/presentation/principal_now_publication_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('embedded publication uses only the canonical form surface', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage(
          embedded: true,
          repository: InMemoryNowPublicationRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows only progress while the initial draft is loading', (tester) async {
    final repository = _DeferredPageNowRepository();
    await tester.pumpWidget(MaterialApp(home: PrincipalNowPublicationPage(repository: repository)));
    await tester.pump();

    expect(find.byKey(const Key('now-publication-loading')), findsOneWidget);
    expect(find.byType(SuperadminFormFrame), findsNothing);
    expect(find.byType(SuperadminFormStepNavigation), findsNothing);
    expect(find.byType(SuperadminFormActionFooter), findsNothing);

    repository.loadCompleter.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('repository swap clears A and ignores its late load', (tester) async {
    final repositoryA = _DeferredPageNowRepository();
    final repositoryB = _DeferredPageNowRepository();

    await tester.pumpWidget(
      MaterialApp(home: PrincipalNowPublicationPage(repository: repositoryA)),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(home: PrincipalNowPublicationPage(repository: repositoryB)),
    );
    repositoryB.loadCompleter.complete(const NowPublicationDraft(caption: 'Contexto B'));
    await tester.pumpAndSettle();
    repositoryA.loadCompleter.complete(const NowPublicationDraft(caption: 'Contexto A'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('now-caption-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.controller.text, 'Contexto B');
    expect(find.text('Contexto A'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('full context swap reloads even when repository and scope ids match', (tester) async {
    final repository = _ContextQueueNowRepository();
    const contextA = NowPublicationContext(
      tenantId: 'tenant-a',
      institutionId: 'institution',
      unitId: 'unit',
      groupId: 'group',
      institutionName: 'Instituição A',
      unitName: 'Unidade A',
      groupName: 'Grupo A',
      allowedAudiences: {NowAudience.families},
    );
    const contextB = NowPublicationContext(
      tenantId: 'tenant-b',
      institutionId: 'institution',
      unitId: 'unit',
      groupId: 'group',
      institutionName: 'Instituição B',
      unitName: 'Unidade B',
      groupName: 'Grupo B',
      allowedAudiences: {NowAudience.schoolStaff},
      capabilities: NowPlanCapabilities(maxVideoDuration: Duration(seconds: 10)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalNowPublicationPage(repository: repository, publicationContext: contextA),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalNowPublicationPage(repository: repository, publicationContext: contextB),
      ),
    );
    expect(repository.contexts, [contextA, contextB]);
    repository.completers[1].complete(const NowPublicationDraft(caption: 'Contexto B'));
    await tester.pumpAndSettle();
    repository.completers[0].complete(const NowPublicationDraft(caption: 'Contexto A'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('now-caption-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.controller.text, 'Contexto B');
    expect(find.text('Contexto A'), findsNothing);
  });

  testWidgets('context swap dismisses owned editor and cannot mutate B', (tester) async {
    final repository = InMemoryNowPublicationRepository();
    const contextB = NowPublicationContext(
      tenantId: 'tenant-b',
      institutionId: 'institution-b',
      unitId: 'unit-b',
      groupId: 'group-b',
      institutionName: 'Instituição B',
      unitName: 'Unidade B',
      groupName: 'Grupo B',
      allowedAudiences: {NowAudience.families},
    );
    Future<NowMediaDraft?> pickMedia() async => NowMediaDraft.image(
      localId: 'media',
      name: 'foto.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList([1]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalNowPublicationPage(repository: repository, mediaPicker: pickMedia),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar mídia'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Texto'));
    await tester.tap(find.byTooltip('Texto'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('now-overlay-field')), 'Segredo A');

    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalNowPublicationPage(
          repository: repository,
          publicationContext: contextB,
          mediaPicker: pickMedia,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('now-overlay-field')), findsNothing);
    expect(find.text('Segredo A'), findsNothing);

    await tester.tap(find.text('Adicionar mídia'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Texto'));
    await tester.tap(find.byTooltip('Texto'));
    await tester.pumpAndSettle();
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('now-overlay-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.controller.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final overlay in <({String tooltip, String visibleText})>[
    (tooltip: 'Texto', visibleText: 'Texto sobre a mídia'),
    (tooltip: 'Cortar', visibleText: 'Cortar mídia'),
  ]) {
    testWidgets('context swap owns ${overlay.tooltip} route before its first build', (
      tester,
    ) async {
      final repository = _ContextQueueNowRepository();
      final media = NowMediaDraft.image(
        localId: 'media-a',
        name: 'foto-a.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1]),
      );
      const contextB = NowPublicationContext(
        tenantId: 'tenant-b',
        institutionId: 'institution-b',
        unitId: 'unit-b',
        groupId: 'group-b',
        institutionName: 'Instituição B',
        unitName: 'Unidade B',
        groupName: 'Grupo B',
        allowedAudiences: {NowAudience.families},
      );

      await tester.pumpWidget(
        MaterialApp(home: PrincipalNowPublicationPage(repository: repository)),
      );
      repository.completers.single.complete(
        NowPublicationDraft(media: media, overlayText: 'Conteúdo privado A'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(overlay.tooltip));
      await tester.pumpWidget(
        MaterialApp(
          home: PrincipalNowPublicationPage(repository: repository, publicationContext: contextB),
        ),
      );
      repository.completers[1].complete(null);
      await tester.pumpAndSettle();

      expect(find.text(overlay.visibleText), findsNothing);
      expect(find.text('Conteúdo privado A'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  Future<void> pumpPage(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage(
          repository: InMemoryNowPublicationRepository(),
          mediaPicker: () async => NowMediaDraft.image(
            localId: 'test',
            name: 'foto.png',
            mimeType: 'image/png',
            bytes: Uint8List.fromList([1]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('usa o frame, etapas e rodapé canônicos do Superadmin', (tester) async {
    await pumpPage(tester, const Size(1440, 1000));

    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.text('Mídia'), findsOneWidget);
    expect(find.text('Detalhes'), findsOneWidget);
    expect(find.byKey(const Key('now-publication-close')), findsNothing);
  });

  testWidgets('avança e retorna sem perder a mídia selecionada', (tester) async {
    await pumpPage(tester, const Size(1440, 1000));

    await tester.tap(find.text('Adicionar mídia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-caption-field')), findsOneWidget);
    expect(find.text('Publicar agora'), findsOneWidget);

    await tester.tap(find.text('Anterior'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-media-stage')), findsOneWidget);
    expect(find.text('Adicionar mídia'), findsNothing);
  });

  for (final size in <Size>[const Size(375, 900), const Size(768, 1024), const Size(1440, 1000)]) {
    testWidgets('renderiza composer sem overflow em ${size.width}', (tester) async {
      await pumpPage(tester, size);

      expect(find.text('Publicar no Agora'), findsOneWidget);
      expect(find.byKey(const Key('now-media-stage')), findsOneWidget);
      expect(find.text('Texto'), findsOneWidget);
      expect(find.text('Música'), findsOneWidget);
      expect(find.text('Cortar'), findsOneWidget);
      expect(find.text('Capa'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in <Size>[
    const Size(375, 900),
    const Size(768, 1024),
    const Size(1024, 1000),
    const Size(1440, 1000),
  ]) {
    testWidgets('suporta texto a 200% e reduced motion em ${size.width}', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2), disableAnimations: true),
            child: PrincipalNowPublicationPage(repository: InMemoryNowPublicationRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('now-media-stage')), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('now-caption-field')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('seleciona mídia e abre ferramenta de texto', (tester) async {
    await pumpPage(tester, const Size(375, 900));
    await tester.tap(find.text('Adicionar mídia'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Texto'));
    await tester.tap(find.byTooltip('Texto'));
    await tester.pumpAndSettle();

    expect(find.text('Texto sobre a mídia'), findsWidgets);
    expect(find.byKey(const Key('now-overlay-field')), findsOneWidget);
  });

  testWidgets('cancelar usa a ação terciária do rodapé canônico', (tester) async {
    await pumpPage(tester, const Size(768, 1024));

    expect(find.widgetWithText(TextButton, 'Cancelar'), findsOneWidget);
    expect(find.byKey(const Key('now-publication-footer')), findsOneWidget);
  });

  testWidgets('dialog privado usa surface e empilha todas as ações quando não cabem', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: PrincipalNowPublicationPage(
            repository: InMemoryNowPublicationRepository(),
            audioPicker: () async => NowAudioDraft(
              localId: 'audio-test',
              name: 'audio.mp3',
              mimeType: 'audio/mpeg',
              bytes: Uint8List.fromList([1]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Música'));
    await tester.tap(find.byTooltip('Música'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, CoeloTheme.light.colorScheme.surface);
    final dismiss = tester.widget<IconButton>(find.byKey(const Key('now-dialog-close')));
    expect(
      dismiss.style?.backgroundColor?.resolve(<WidgetState>{}),
      CoeloTheme.light.colorScheme.surface,
    );
    expect(
      dismiss.style?.backgroundColor?.resolve({WidgetState.hovered}),
      CoeloTheme.light.colorScheme.errorContainer,
    );
    expect(
      dismiss.style?.foregroundColor?.resolve(<WidgetState>{}),
      CoeloTheme.light.colorScheme.error,
    );
    expect(
      dismiss.style?.foregroundColor?.resolve({WidgetState.focused}),
      CoeloTheme.light.colorScheme.error,
    );
    expect(find.byKey(const Key('now-dialog-actions-stacked')), findsOneWidget);
    expect(find.byKey(const Key('now-dialog-actions-row')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('agendamento aplica uma data futura sem date picker Material', (tester) async {
    await pumpPage(tester, const Size(375, 900));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('now-schedule-toggle')));
    await tester.tap(find.byKey(const Key('now-schedule-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-schedule-field')), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('restaura o texto do rascunho carregado', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryNowPublicationRepository()
      ..savedDraft = const NowPublicationDraft(caption: 'Registro da turma');
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(find.byKey(const Key('now-caption-field')));
    expect(field.controller?.text, 'Registro da turma');
  });

  testWidgets('preview usa URL assinada do rascunho remoto', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryNowPublicationRepository()
      ..savedDraft = NowPublicationDraft(
        media: NowMediaDraft(
          localId: 'asset-1',
          name: 'foto.png',
          mimeType: 'image/png',
          bytes: Uint8List(0),
          remoteAssetId: 'asset-1',
          remoteUrl: 'https://signed.test/draft?token=short-lived',
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage(repository: repository),
      ),
    );
    await tester.pump();

    final images = tester.widgetList<Image>(find.byType(Image));
    expect(
      images.any(
        (image) =>
            image.image is NetworkImage &&
            (image.image as NetworkImage).url == 'https://signed.test/draft?token=short-lived',
      ),
      isTrue,
    );
  });

  testWidgets('toggle canônico de agendamento desabilita durante salvamento', (tester) async {
    final repository = _BlockingRepository();
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final toggleFinder = find.byKey(const Key('now-schedule-toggle'));
    expect(find.byType(CoeloAdminToggleField), findsOneWidget);
    await tester.ensureVisible(toggleFinder);
    await tester.tap(toggleFinder);
    await tester.pump();
    expect(find.byKey(const Key('now-schedule-field')), findsOneWidget);

    await tester.ensureVisible(find.text('Salvar rascunho'));
    await tester.tap(find.text('Salvar rascunho'));
    await tester.pump();
    await tester.tap(toggleFinder);
    await tester.pump();
    expect(find.byKey(const Key('now-schedule-field')), findsOneWidget);

    repository.finishSave();
    await tester.pumpAndSettle();
  });
}

final class _DeferredPageNowRepository implements NowPublicationRepository {
  final loadCompleter = Completer<NowPublicationDraft?>();

  @override
  Future<NowPublicationDraft?> loadDraft(NowPublicationContext context) => loadCompleter.future;

  @override
  Future<NowPublicationDraft> saveDraft(
    NowPublicationContext context,
    NowPublicationDraft draft,
  ) async => draft;

  @override
  Future<NowMediaDraft> uploadMedia(
    NowPublicationContext context,
    String publicationId,
    NowMediaDraft media,
  ) async => media;

  @override
  Future<NowAudioDraft> uploadAudio(
    NowPublicationContext context,
    String publicationId,
    NowAudioDraft audio,
  ) async => audio;

  @override
  Future<NowPublication> publish(NowPublicationContext context, NowPublicationDraft draft) async =>
      NowPublication(id: draft.id!, publishAt: draft.publishAt);
}

final class _ContextQueueNowRepository implements NowPublicationRepository {
  final contexts = <NowPublicationContext>[];
  final completers = <Completer<NowPublicationDraft?>>[];

  @override
  Future<NowPublicationDraft?> loadDraft(NowPublicationContext context) {
    contexts.add(context);
    final completer = Completer<NowPublicationDraft?>();
    completers.add(completer);
    return completer.future;
  }

  @override
  Future<NowPublicationDraft> saveDraft(
    NowPublicationContext context,
    NowPublicationDraft draft,
  ) async => draft;

  @override
  Future<NowMediaDraft> uploadMedia(
    NowPublicationContext context,
    String publicationId,
    NowMediaDraft media,
  ) async => media;

  @override
  Future<NowAudioDraft> uploadAudio(
    NowPublicationContext context,
    String publicationId,
    NowAudioDraft audio,
  ) async => audio;

  @override
  Future<NowPublication> publish(NowPublicationContext context, NowPublicationDraft draft) async =>
      NowPublication(id: draft.id!, publishAt: draft.publishAt);
}

final class _BlockingRepository implements NowPublicationRepository {
  final delegate = InMemoryNowPublicationRepository();
  final saveCompleter = Completer<NowPublicationDraft>();

  void finishSave() => saveCompleter.complete(const NowPublicationDraft());

  @override
  Future<NowPublicationDraft?> loadDraft(NowPublicationContext context) =>
      delegate.loadDraft(context);

  @override
  Future<NowPublicationDraft> saveDraft(NowPublicationContext context, NowPublicationDraft draft) =>
      saveCompleter.future;

  @override
  Future<NowMediaDraft> uploadMedia(
    NowPublicationContext context,
    String publicationId,
    NowMediaDraft media,
  ) => delegate.uploadMedia(context, publicationId, media);

  @override
  Future<NowAudioDraft> uploadAudio(
    NowPublicationContext context,
    String publicationId,
    NowAudioDraft audio,
  ) => delegate.uploadAudio(context, publicationId, audio);

  @override
  Future<NowPublication> publish(NowPublicationContext context, NowPublicationDraft draft) =>
      delegate.publish(context, draft);
}
