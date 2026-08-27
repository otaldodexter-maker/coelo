import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/domain/happens_publication.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/presentation/principal_happens_publication_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';

void main() {
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
        hint: 'Ative para salvar automaticamente.',
        isButton: true,
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
        hint: 'Ative para salvar automaticamente.',
        isButton: true,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('autosave usa tonal laranja no hover e foco', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalHappensPublicationPage(repository: InMemoryHappensPublicationRepository()),
      ),
    );
    await tester.pumpAndSettle();
    await _continue(tester);
    await tester.ensureVisible(find.byKey(const Key('happens-autosave-toggle')));
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('happens-autosave-toggle'))));
    await tester.pumpAndSettle();
    expect(
      _autosaveColor(tester),
      Theme.of(tester.element(find.byType(Scaffold))).colorScheme.primaryContainer,
    );

    await mouse.moveTo(Offset.zero);
    tester
        .widget<FocusableActionDetector>(find.byKey(const Key('happens-autosave-toggle')))
        .focusNode!
        .requestFocus();
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
}

Color? _autosaveColor(WidgetTester tester) =>
    (tester.widget<AnimatedContainer>(find.byKey(const Key('happens-autosave-surface'))).decoration
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
