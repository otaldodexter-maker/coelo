import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:coelo_superadmin/features/principal_now_publication/presentation/principal_now_publication_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The composer must survive an `Error`, not only an `Exception`.
///
/// `busy` is derived from the phase, and the surface sits under an
/// `AbsorbPointer` while busy. A throw that no catch handles leaves the phase at
/// `saving` forever, so the screen locks with even Cancel disabled: the operator
/// cannot leave the state they are stuck in. The production repository decodes
/// Supabase payloads with raw casts, so a `TypeError` there is not a remote
/// hypothesis.
void main() {
  Future<void> pump(
    WidgetTester tester,
    NowPublicationRepository repository, {
    ValueChanged<NowPublication>? onCompleted,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: repository, onCompleted: onCompleted),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an Error while loading reaches the failure panel, not a locked screen', (
    tester,
  ) async {
    await pump(tester, _ThrowingRepository(onLoad: true));

    expect(
      find.textContaining('Não foi possível'),
      findsWidgets,
      reason: 'an unhandled Error must still land on an honest failure state',
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('an Error while saving leaves the surface usable', (tester) async {
    final repository = _ThrowingRepository(onSave: true);
    await pump(tester, repository);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar rascunho'));
    await tester.pumpAndSettle();

    // The proof that the screen is not locked: the composer left the busy phase
    // and handed the operator a failure panel they can act on. While it stayed
    // locked, this surface never appeared at all.
    expect(repository.saveCalls, 1);
    expect(find.text('Não foi possível salvar o rascunho.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 2);
    expect(find.byKey(const Key('now-publication-failure')), findsNothing);
    expect(find.text('Salvar rascunho'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an Error while publishing leaves the surface usable', (tester) async {
    // Seeded so the draft is publishable: an empty one is refused by validation
    // and never reaches the repository, which would make the case vacuous.
    final repository = _ThrowingRepository(onPublish: true, publishable: true);
    NowPublication? completed;
    await pump(tester, repository, onCompleted: (value) => completed = value);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Publicar agora'));
    await tester.pumpAndSettle();

    expect(repository.publishCalls, 1);
    expect(completed, isNull);
    expect(find.text('Não foi possível publicar no Agora.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.publishCalls, 2);
    expect(completed?.id, 'publication-1');
    expect(find.byKey(const Key('now-publication-failure')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// Throws a real `Error`, the way a raw cast over an unexpected payload does.
///
/// Composed rather than subclassed: the in-memory double is a final class, and
/// delegating keeps its behaviour intact on the paths that should not throw.
final class _ThrowingRepository implements NowPublicationRepository {
  _ThrowingRepository({
    this.onLoad = false,
    this.onSave = false,
    this.onPublish = false,
    bool publishable = false,
  }) {
    if (publishable) {
      _inner.savedDraft = NowPublicationDraft(
        id: 'publication-1',
        media: NowMediaDraft.image(
          localId: 'media-1',
          name: 'agora.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList([1]),
        ),
        caption: 'Rascunho autorizado',
        audiences: const {NowAudience.families},
      );
    }
  }

  final bool onLoad;
  final bool onSave;
  final bool onPublish;
  final _inner = InMemoryNowPublicationRepository();
  var saveCalls = 0;
  var publishCalls = 0;

  @override
  Future<NowPublicationDraft?> loadDraft(NowPublicationContext context) async {
    if (onLoad) throw TypeError();
    return _inner.loadDraft(context);
  }

  @override
  Future<NowPublicationDraft> saveDraft(
    NowPublicationContext context,
    NowPublicationDraft draft,
  ) async {
    saveCalls++;
    if (onSave && saveCalls == 1) throw TypeError();
    return _inner.saveDraft(context, draft);
  }

  @override
  Future<NowPublication> publish(NowPublicationContext context, NowPublicationDraft draft) async {
    publishCalls++;
    if (onPublish && publishCalls == 1) throw TypeError();
    return _inner.publish(context, draft);
  }

  @override
  Future<NowMediaDraft> uploadMedia(
    NowPublicationContext context,
    String publicationId,
    NowMediaDraft media,
  ) => _inner.uploadMedia(context, publicationId, media);

  @override
  Future<NowAudioDraft> uploadAudio(
    NowPublicationContext context,
    String publicationId,
    NowAudioDraft audio,
  ) => _inner.uploadAudio(context, publicationId, audio);
}
