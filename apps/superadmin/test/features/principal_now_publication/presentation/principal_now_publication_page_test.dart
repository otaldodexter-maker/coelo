import 'dart:async';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:coelo_superadmin/features/principal_now_publication/presentation/principal_now_publication_page.dart';
import 'package:coelo_superadmin/features/principal_shared/presentation/principal_publication_frame.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('embedded publication uses only the canonical form surface', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(
          embedded: true,
          repository: InMemoryNowPublicationRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(PrincipalPublicationFrame), findsOneWidget);
    expect(find.byType(PrincipalPublicationStepNavigation), findsOneWidget);
    expect(find.byType(PrincipalPublicationActionFooter), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows only progress while the initial draft is loading', (tester) async {
    final repository = _DeferredPageNowRepository();
    await tester.pumpWidget(
      MaterialApp(home: PrincipalNowPublicationPage.demo(repository: repository)),
    );
    await tester.pump();

    expect(find.byKey(const Key('now-publication-loading')), findsOneWidget);
    expect(find.byType(PrincipalPublicationFrame), findsNothing);
    expect(find.byType(PrincipalPublicationStepNavigation), findsNothing);
    expect(find.byType(PrincipalPublicationActionFooter), findsNothing);

    repository.loadCompleter.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('falha de carregamento mostra painel e retry', (tester) async {
    final repository = _RetryingNowRepository(loadFailures: 1);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-publication-failure')), findsOneWidget);
    expect(find.text('Não foi possível carregar'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
    expect(find.byType(PrincipalPublicationFrame), findsOneWidget);
  });

  testWidgets('falha ao salvar oferece retry sem descartar o rascunho', (tester) async {
    final repository = _RetryingNowRepository(saveFailures: 1);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar rascunho'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-publication-failure')), findsOneWidget);
    expect(find.text('Não foi possível salvar o rascunho.'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 2);
    expect(find.byType(PrincipalPublicationFrame), findsOneWidget);
  });

  testWidgets('retry de publicação conclui o fluxo hospedeiro', (tester) async {
    final repository = _RetryingNowRepository(
      publishFailures: 1,
      draft: NowPublicationDraft(
        id: 'now-draft',
        media: NowMediaDraft(
          localId: 'video',
          name: 'agora.mp4',
          mimeType: 'video/mp4',
          bytes: Uint8List(0),
          duration: const Duration(seconds: 8),
          remoteAssetId: 'asset',
          remoteUrl: 'https://signed.test/agora.mp4',
        ),
        audiences: const {NowAudience.families},
      ),
    );
    NowPublication? completed;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(
          repository: repository,
          onCompleted: (value) => completed = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publicar agora'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-publication-failure')), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.publishCalls, 2);
    expect(completed, isNotNull);
  });

  testWidgets('conflito exige recarregar o rascunho', (tester) async {
    final repository = _RetryingNowRepository(conflictOnSave: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar rascunho'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-publication-conflict')), findsOneWidget);
    expect(find.text('Rascunho desatualizado'), findsOneWidget);
    expect(find.text('Recarregar rascunho'), findsOneWidget);
  });

  testWidgets('unauthorized bloqueia o publisher sem oferecer retry', (tester) async {
    final repository = _RetryingNowRepository(unauthorizedOnSave: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar rascunho'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-publication-unauthorized')), findsOneWidget);
    expect(find.text('Publicação indisponível'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('repository swap clears A and ignores its late load', (tester) async {
    final repositoryA = _DeferredPageNowRepository();
    final repositoryB = _DeferredPageNowRepository();

    await tester.pumpWidget(
      MaterialApp(home: PrincipalNowPublicationPage.demo(repository: repositoryA)),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(home: PrincipalNowPublicationPage.demo(repository: repositoryB)),
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
        home: PrincipalNowPublicationPage.demo(
          repository: repository,
          publicationContext: contextA,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalNowPublicationPage.demo(
          repository: repository,
          publicationContext: contextB,
        ),
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
        home: PrincipalNowPublicationPage.demo(repository: repository, mediaPicker: pickMedia),
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
        home: PrincipalNowPublicationPage.demo(
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
        MaterialApp(home: PrincipalNowPublicationPage.demo(repository: repository)),
      );
      repository.completers.single.complete(
        NowPublicationDraft(media: media, overlayText: 'Conteúdo privado A'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(overlay.tooltip));
      await tester.pumpWidget(
        MaterialApp(
          home: PrincipalNowPublicationPage.demo(
            repository: repository,
            publicationContext: contextB,
          ),
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
        home: PrincipalNowPublicationPage.demo(
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

    expect(find.byType(PrincipalPublicationFrame), findsOneWidget);
    expect(find.byType(PrincipalPublicationStepNavigation), findsOneWidget);
    expect(find.byType(PrincipalPublicationActionFooter), findsOneWidget);
    expect(find.text('Mídia'), findsOneWidget);
    expect(find.text('Detalhes'), findsOneWidget);
    expect(find.byKey(const Key('now-publication-close')), findsNothing);
    expect(find.text('Sua publicação'), findsOneWidget);
    expect(find.byKey(const Key('now-publication-desktop-preview')), findsOneWidget);
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
      expect(find.text('Sua publicação'), findsOneWidget);
      expect(
        find.byKey(const Key('now-publication-desktop-preview')),
        size.width >= 1024 ? findsOneWidget : findsNothing,
      );
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
            child: PrincipalNowPublicationPage.demo(repository: InMemoryNowPublicationRepository()),
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
          child: PrincipalNowPublicationPage.demo(
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
        home: PrincipalNowPublicationPage.demo(repository: repository),
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
          cropScale: 1.4,
          cropX: -0.25,
          cropY: 0.4,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: repository),
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
    final crop = tester.widget<Transform>(find.byKey(const Key('now-media-crop')));
    expect(crop.alignment, const Alignment(-0.25, 0.4));
  });

  testWidgets('vídeo remoto resolvido usa preview de vídeo e não indisponibilidade', (
    tester,
  ) async {
    final repository = InMemoryNowPublicationRepository()
      ..savedDraft = NowPublicationDraft(
        media: NowMediaDraft(
          localId: 'video-remote',
          name: 'agora.mp4',
          mimeType: 'video/mp4',
          bytes: Uint8List(0),
          duration: const Duration(seconds: 8),
          remoteAssetId: 'video-remote',
          remoteUrl: 'https://signed.test/agora.mp4',
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-video-preview')), findsWidgets);
    expect(find.byKey(const Key('now-media-unavailable')), findsNothing);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsWidgets);
  });

  testWidgets('bytes de imagem quebrados mostram indisponibilidade sem asset demo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryNowPublicationRepository()
      ..savedDraft = NowPublicationDraft(
        media: NowMediaDraft.image(
          localId: 'broken-bytes',
          name: 'quebrada.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-media-unavailable')), findsOneWidget);
    expect(find.text('Mídia indisponível'), findsOneWidget);
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .where(
            (image) =>
                image.image is AssetImage &&
                (image.image as AssetImage).assetName == 'assets/principal_now/story-strip.png',
          ),
      isEmpty,
    );
  });

  testWidgets('URL remota quebrada mostra indisponibilidade sem asset demo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryNowPublicationRepository()
      ..savedDraft = NowPublicationDraft(
        media: NowMediaDraft(
          localId: 'broken-remote',
          name: 'remota.png',
          mimeType: 'image/png',
          bytes: Uint8List(0),
          remoteAssetId: 'broken-remote',
          remoteUrl: 'https://invalid.test/midia-que-nao-existe.png',
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-media-unavailable')), findsOneWidget);
    expect(find.text('Mídia indisponível'), findsOneWidget);
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .where(
            (image) =>
                image.image is AssetImage &&
                (image.image as AssetImage).assetName == 'assets/principal_now/story-strip.png',
          ),
      isEmpty,
    );
  });

  testWidgets('ajuste de escala preserva o deslocamento persistido do crop', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryNowPublicationRepository()
      ..savedDraft = NowPublicationDraft(
        media: NowMediaDraft.image(
          localId: 'media-crop',
          name: 'crop.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList([1]),
        ).copyWith(cropScale: 1.2, cropX: -0.35, cropY: 0.2),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cortar'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(70, 0));
    await tester.pump();
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar rascunho'));
    await tester.pumpAndSettle();

    expect(repository.savedDraft?.media?.cropX, -0.35);
    expect(repository.savedDraft?.media?.cropY, 0.2);
  });

  testWidgets('editor de capa mantém a ação Concluir dentro da viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = InMemoryNowPublicationRepository()
      ..savedDraft = NowPublicationDraft(
        media: NowMediaDraft.video(
          localId: 'video-cover',
          name: 'video.mp4',
          mimeType: 'video/mp4',
          bytes: Uint8List.fromList([1]),
          duration: const Duration(seconds: 8),
        ).copyWith(coverPosition: .65),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Capa'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.text('Concluir'));
    expect(rect.bottom, lessThanOrEqualTo(1000));
  });

  testWidgets('shell completo usa o cabeçalho compartilhado do Principal', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: InMemoryNowPublicationRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-now-publication-logo')), findsOneWidget);
    expect(find.byKey(const Key('principal-now-publication-notifications')), findsOneWidget);
    expect(find.byKey(const Key('principal-now-publication-context-avatar')), findsOneWidget);
  });

  testWidgets('toggle canônico de agendamento desabilita durante salvamento', (tester) async {
    final repository = _BlockingRepository();
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final toggleFinder = find.byKey(const Key('now-schedule-toggle'));
    expect(find.byType(PrincipalPublicationToggleField), findsOneWidget);
    await tester.ensureVisible(toggleFinder);
    await tester.tap(toggleFinder);
    await tester.pump();
    expect(find.byKey(const Key('now-schedule-field')), findsOneWidget);

    await tester.ensureVisible(find.text('Salvar rascunho'));
    await tester.tap(find.text('Salvar rascunho'));
    await tester.pump();
    await tester.ensureVisible(toggleFinder);
    await tester.tap(toggleFinder, warnIfMissed: false);
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

final class _RetryingNowRepository implements NowPublicationRepository {
  _RetryingNowRepository({
    this.loadFailures = 0,
    this.saveFailures = 0,
    this.publishFailures = 0,
    this.conflictOnSave = false,
    this.unauthorizedOnSave = false,
    this.draft = const NowPublicationDraft(caption: 'Rascunho preservado'),
  });

  final int loadFailures;
  final int saveFailures;
  final int publishFailures;
  final bool conflictOnSave;
  final bool unauthorizedOnSave;
  final NowPublicationDraft draft;
  var loadCalls = 0;
  var saveCalls = 0;
  var publishCalls = 0;

  @override
  Future<NowPublicationDraft?> loadDraft(NowPublicationContext context) async {
    loadCalls += 1;
    if (loadCalls <= loadFailures) throw Exception('load failed');
    return draft;
  }

  @override
  Future<NowPublicationDraft> saveDraft(
    NowPublicationContext context,
    NowPublicationDraft draft,
  ) async {
    saveCalls += 1;
    if (unauthorizedOnSave) throw NowPublicationUnauthorized();
    if (conflictOnSave) throw NowPublicationConflict();
    if (saveCalls <= saveFailures) throw Exception('save failed');
    return draft.copyWith(id: 'now-draft', version: saveCalls);
  }

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
  Future<NowPublication> publish(NowPublicationContext context, NowPublicationDraft draft) async {
    publishCalls += 1;
    if (publishCalls <= publishFailures) throw Exception('publish failed');
    return NowPublication(id: draft.id ?? 'now', publishAt: draft.publishAt);
  }
}
