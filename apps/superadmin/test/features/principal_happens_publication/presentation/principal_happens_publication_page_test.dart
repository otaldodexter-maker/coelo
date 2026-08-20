import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/domain/happens_publication.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/presentation/principal_happens_publication_page.dart';

void main() {
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
    expect(find.text('Mídia'), findsOneWidget);
    expect(find.text('Público e contexto'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pump();
    expect(find.text('Prévia do post no Acontece'), findsOneWidget);
  });

  testWidgets('publica com audiência selecionada', (tester) async {
    final repository = InMemoryHappensPublicationRepository();
    await tester.pumpWidget(
      MaterialApp(home: PrincipalHappensPublicationPage(repository: repository)),
    );
    await tester.pump();
    await tester.enterText(find.byKey(const Key('happens-caption')), 'Nossa turma floresceu.');
    await tester.tap(find.text('Famílias').first);
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

  testWidgets('autosave expõe estado e alterna pelo rótulo inteiro', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalHappensPublicationPage(repository: InMemoryHappensPublicationRepository()),
      ),
    );
    await tester.pumpAndSettle();
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
