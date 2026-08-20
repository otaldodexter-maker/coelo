import 'dart:async';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:coelo_superadmin/features/principal_now_publication/presentation/principal_now_publication_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  for (final size in <Size>[const Size(375, 900), const Size(768, 1024), const Size(1440, 1000)]) {
    testWidgets('renderiza composer sem overflow em ${size.width}', (tester) async {
      await pumpPage(tester, size);

      expect(find.text('Publicar no Agora'), findsOneWidget);
      expect(find.byKey(const Key('now-media-stage')), findsOneWidget);
      expect(find.text('Texto'), findsOneWidget);
      expect(find.text('Música'), findsOneWidget);
      expect(find.text('Cortar'), findsOneWidget);
      expect(find.text('Capa'), findsOneWidget);
      expect(find.text('Público e contexto'), findsOneWidget);
      expect(find.text('Agendar publicação'), findsOneWidget);
      expect(find.text('Publicar agora'), findsOneWidget);
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

  testWidgets('agendamento aplica uma data futura sem date picker Material', (tester) async {
    await pumpPage(tester, const Size(375, 900));
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

    final field = tester.widget<TextFormField>(find.byKey(const Key('now-caption-field')));
    expect(field.controller?.text, 'Registro da turma');
  });

  testWidgets('toggle de agendamento aceita teclado e desabilita durante salvamento', (
    tester,
  ) async {
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
    final toggleFinder = find.byKey(const Key('now-schedule-toggle'));
    await tester.ensureVisible(toggleFinder);
    final actionContext = tester.element(
      find.descendant(of: toggleFinder, matching: find.byType(GestureDetector)),
    );

    Actions.invoke(actionContext, const ActivateIntent());
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
