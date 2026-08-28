import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/application/happens_publication_controller.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/domain/happens_publication.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/presentation/principal_happens_publication_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';

void main() {
  testWidgets('embedded publication uses only the canonical form surface', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalHappensPublicationPage(
          embedded: true,
          repository: InMemoryHappensPublicationRepository(),
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

  testWidgets('usa frame, etapas e rodape canonicos do wizard', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalHappensPublicationPage(repository: InMemoryHappensPublicationRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.textContaining('Etapa 1 de 4'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('mantém composer e prévia no fluxo compacto', (tester) async {
    tester.view.physicalSize = const Size(375, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalHappensPublicationPage(repository: InMemoryHappensPublicationRepository()),
      ),
    );
    await tester.pump();
    expect(find.text('Publicar no Acontece'), findsWidgets);
    expect(find.text('Mídia'), findsWidgets);
    await _continue(tester);
    expect(find.text('Legenda'), findsWidgets);
    await _continue(tester);
    expect(find.text('Público e contexto'), findsOneWidget);
    await _continue(tester);
    expect(find.text('Prévia do post no Acontece'), findsOneWidget);
  });

  testWidgets('publica com audiência selecionada', (tester) async {
    final repository = InMemoryHappensPublicationRepository();
    await tester.pumpWidget(
      MaterialApp(home: PrincipalHappensPublicationPage(repository: repository)),
    );
    await tester.pump();
    await _continue(tester);
    await tester.enterText(find.byKey(const Key('happens-caption')), 'Nossa turma floresceu.');
    await _continue(tester);
    await tester.tap(find.text('Famílias').first);
    await _continue(tester);
    await tester.ensureVisible(find.text('Publicar no Acontece').last);
    await tester.tap(find.text('Publicar no Acontece').last);
    await tester.pumpAndSettle();
    expect(repository.lastPublication, isNotNull);
  });

  testWidgets('empilha ações sem overflow na largura intermediária de 734 px', (tester) async {
    tester.view.physicalSize = const Size(734, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalHappensPublicationPage(repository: InMemoryHappensPublicationRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('preserva o wizard em 375, 768, 1024 e 1440 px com texto a 200%', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1400);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: PrincipalHappensPublicationPage(
            key: ValueKey(width),
            repository: InMemoryHappensPublicationRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'largura $width, etapa mídia');
      await _continue(tester);
      expect(tester.takeException(), isNull, reason: 'largura $width, etapa conteúdo');
      await _continue(tester);
      expect(tester.takeException(), isNull, reason: 'largura $width, etapa público');
      await _continue(tester);

      expect(tester.takeException(), isNull, reason: 'largura $width, etapa revisão');
      expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    }
  });

  testWidgets('autosave expõe estado e alterna pelo rótulo inteiro', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalHappensPublicationPage(repository: InMemoryHappensPublicationRepository()),
      ),
    );
    await tester.pumpAndSettle();
    await _continue(tester);
    await tester.ensureVisible(find.text('Salvar como rascunho').first);
    final toggle = find.bySemanticsLabel(RegExp('Salvar como rascunho'));

    expect(
      tester.getSemantics(toggle),
      matchesSemantics(
        label: 'Salvar como rascunho',
        hasEnabledState: true,
        isEnabled: true,
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.text('Salvar como rascunho').first);
    await tester.pump();
    expect(
      tester.getSemantics(toggle),
      matchesSemantics(
        label: 'Salvar como rascunho',
        hasEnabledState: true,
        isEnabled: true,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('autosave reutiliza o toggle canônico e seu hover', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalHappensPublicationPage(repository: InMemoryHappensPublicationRepository()),
      ),
    );
    await tester.pumpAndSettle();
    await _continue(tester);
    await tester.ensureVisible(find.byKey(const Key('happens-autosave-toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminToggleField), findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('happens-autosave-toggle'))));
    await tester.pumpAndSettle();
    expect(
      _autosaveColor(tester),
      Theme.of(tester.element(find.byType(Scaffold))).colorScheme.primaryContainer,
    );
  });

  testWidgets('seleciona múltiplas mídias e expõe trilha reordenável', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalHappensPublicationPage(
          repository: InMemoryHappensPublicationRepository(),
          mediaPicker: () async => [_media('a'), _media('b')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar fotos ou vídeos'));
    await tester.pump();

    expect(find.text('1/2'), findsOneWidget);
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.byTooltip('Remover mídia 1'), findsOneWidget);
    expect(find.byTooltip('Remover mídia 2'), findsOneWidget);
  });

  testWidgets('mantém ações bloqueadas quando o contexto é negado', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PrincipalHappensPublicationPage(repository: _UnauthorizedRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormFrame), findsNothing);
    expect(find.text('Publicação indisponível'), findsOneWidget);
  });

  testWidgets('troca A por B e ignora load e picker tardios de A', (tester) async {
    final repositoryA = _DeferredRepository();
    final repositoryB = InMemoryHappensPublicationRepository()
      ..savedDraft = HappensPostDraft(caption: 'Conteúdo B');

    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalHappensPublicationPage(
          repository: repositoryA,
          publicationContext: HappensPublicationContext.demo,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('happens-publication-loading')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalHappensPublicationPage(
          repository: repositoryB,
          publicationContext: const HappensPublicationContext(
            institutionId: 'institution-b',
            institutionName: 'Instituição B',
            unitId: 'unit-b',
            unitName: 'Unidade B',
            groupId: 'group-b',
            groupName: 'Grupo B',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _continue(tester);
    expect(find.text('Conteúdo B'), findsOneWidget);

    repositoryA.loaded.complete(HappensPostDraft(caption: 'Conteúdo A'));
    await tester.pumpAndSettle();

    expect(find.text('Conteúdo B'), findsOneWidget);
    expect(find.text('Conteúdo A'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('descarta picker tardio quando o contexto muda', (tester) async {
    final pickerA = Completer<List<HappensMediaDraft>>();
    final repositoryA = InMemoryHappensPublicationRepository();
    final repositoryB = InMemoryHappensPublicationRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalHappensPublicationPage(
          repository: repositoryA,
          mediaPicker: () => pickerA.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar fotos ou vídeos'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continuar')).onPressed,
      isNull,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalHappensPublicationPage(
          repository: repositoryB,
          publicationContext: const HappensPublicationContext(
            institutionId: 'institution-b',
            institutionName: 'Instituição B',
            unitId: 'unit-b',
            unitName: 'Unidade B',
            groupId: 'group-b',
            groupName: 'Grupo B',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    pickerA.complete([_media('a')]);
    await tester.pumpAndSettle();

    expect(find.text('1/1'), findsNothing);
    expect(find.byTooltip('Remover mídia 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite retry de publish após falha recuperável', (tester) async {
    final repository = _FailOncePublishRepository();
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalHappensPublicationPage(
          repository: repository,
          onCompleted: (_) => completed++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _continue(tester);
    await tester.enterText(find.byKey(const Key('happens-caption')), 'Legenda');
    await _continue(tester);
    await tester.tap(find.text('Famílias').first);
    await _continue(tester);

    await tester.tap(find.text('Publicar no Acontece').last);
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível publicar agora.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Publicar no Acontece'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Publicar no Acontece').last);
    await tester.pumpAndSettle();
    expect(repository.publishCalls, 2);
    expect(completed, 1);
  });

  testWidgets('mantém o wizard para retry de save vazio', (tester) async {
    final repository = _FailOnceSaveRepository();
    await tester.pumpWidget(
      MaterialApp(home: PrincipalHappensPublicationPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await _continue(tester);
    await _continue(tester);
    await _continue(tester);

    await tester.tap(find.text('Salvar rascunho'));
    await tester.pumpAndSettle();
    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.text('Não foi possível salvar o rascunho.'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Salvar rascunho'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Salvar rascunho'));
    await tester.pumpAndSettle();
    expect(repository.saveCalls, 2);
  });

  testWidgets('mantém corpo e foco bloqueados durante save', (tester) async {
    final repository = _DeferredRepository()..loaded.complete(null);
    await tester.pumpWidget(
      MaterialApp(home: PrincipalHappensPublicationPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await _continue(tester);
    await tester.enterText(find.byKey(const Key('happens-caption')), 'Legenda A');
    await _continue(tester);
    await tester.tap(find.text('Famílias').first);
    await _continue(tester);
    await tester.tap(find.text('Salvar rascunho'));
    await tester.pump();

    expect(
      tester
          .widget<AbsorbPointer>(find.byKey(const Key('happens-publication-body-lock')))
          .absorbing,
      isTrue,
    );
    expect(
      tester
          .widget<ExcludeFocus>(find.byKey(const Key('happens-publication-body-focus-lock')))
          .excluding,
      isTrue,
    );
    expect(repository.saveCalls, 1);

    repository.saved.complete(HappensPostDraft(id: 'draft-1', caption: 'Legenda A', version: 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Color? _autosaveColor(WidgetTester tester) =>
    (tester
                .widget<AnimatedContainer>(
                  find
                      .descendant(
                        of: find.byKey(const Key('happens-autosave-toggle')),
                        matching: find.byType(AnimatedContainer),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration?)
        ?.color;

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

HappensMediaDraft _media(String id) => HappensMediaDraft(
  localId: id,
  name: '$id.png',
  mimeType: 'image/png',
  bytes: Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  ),
);

final class _UnauthorizedRepository implements HappensPublicationRepository {
  @override
  Future<HappensPostDraft?> loadDraft(HappensPublicationContext context) =>
      throw HappensPublicationUnauthorized();

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

final class _DeferredRepository implements HappensPublicationRepository {
  final loaded = Completer<HappensPostDraft?>();
  final saved = Completer<HappensPostDraft>();
  var saveCalls = 0;

  @override
  Future<HappensPostDraft?> loadDraft(HappensPublicationContext context) => loaded.future;

  @override
  Future<HappensPostDraft> saveDraft(HappensPublicationContext context, HappensPostDraft draft) {
    saveCalls++;
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
  Future<HappensPublication> publish(HappensPublicationContext context, HappensPostDraft draft) =>
      throw UnimplementedError();
}

final class _FailOncePublishRepository implements HappensPublicationRepository {
  final delegate = InMemoryHappensPublicationRepository();
  var publishCalls = 0;

  @override
  Future<HappensPostDraft?> loadDraft(HappensPublicationContext context) =>
      delegate.loadDraft(context);

  @override
  Future<HappensPostDraft> saveDraft(HappensPublicationContext context, HappensPostDraft draft) =>
      delegate.saveDraft(context, draft);

  @override
  Future<HappensUploadIntent> prepareMedia(
    HappensPublicationContext context,
    String postId,
    HappensMediaDraft media,
    int displayOrder,
  ) => delegate.prepareMedia(context, postId, media, displayOrder);

  @override
  Future<HappensMediaDraft> finalizeMedia(HappensUploadIntent intent, HappensMediaDraft media) =>
      delegate.finalizeMedia(intent, media);

  @override
  Future<void> removeMedia(HappensPublicationContext context, HappensMediaDraft media) =>
      delegate.removeMedia(context, media);

  @override
  Future<HappensPublication> publish(HappensPublicationContext context, HappensPostDraft draft) {
    publishCalls++;
    if (publishCalls == 1) throw Exception('transient');
    return delegate.publish(context, draft);
  }
}

final class _FailOnceSaveRepository implements HappensPublicationRepository {
  var saveCalls = 0;

  @override
  Future<HappensPostDraft?> loadDraft(HappensPublicationContext context) async => null;

  @override
  Future<HappensPostDraft> saveDraft(
    HappensPublicationContext context,
    HappensPostDraft draft,
  ) async {
    saveCalls++;
    if (saveCalls == 1) throw Exception('transient');
    return draft.copyWith(id: 'draft-1', version: 1);
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
  Future<HappensPublication> publish(HappensPublicationContext context, HappensPostDraft draft) =>
      throw UnimplementedError();
}
