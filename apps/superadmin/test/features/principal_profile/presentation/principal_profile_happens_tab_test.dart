import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_happens_tab.dart';

final class _FakeFeedRepository implements PrincipalHappensFeedRepository {
  _FakeFeedRepository({this.mediaRead, this.mediaError});

  final _completers = <Completer<List<PrincipalPostPreviewItem>>>[];
  final requestedScopes = <PrincipalHappensFeedScope>[];
  final resolvedMedia = <PrincipalHappensMediaDescriptor>[];
  PrincipalHappensMediaRead? mediaRead;
  Object? mediaError;

  int get requestCount => _completers.length;

  Completer<List<PrincipalPostPreviewItem>> requestAt(int index) => _completers[index];

  Completer<List<PrincipalPostPreviewItem>> get lastRequest => _completers.last;

  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope) {
    requestedScopes.add(scope);
    final completer = Completer<List<PrincipalPostPreviewItem>>();
    _completers.add(completer);
    return completer.future;
  }

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) {
    resolvedMedia.add(media);
    final error = mediaError;
    if (error != null) return Future.error(error);
    final read = mediaRead;
    if (read == null) return Future.error(const PrincipalHappensFeedUnavailable());
    return Future.value(read);
  }
}

PrincipalPostPreviewItem _post(
  String author, {
  List<PrincipalHappensMediaDescriptor> media = const [],
}) => PrincipalPostPreviewItem(
  author: author,
  context: 'Turma A',
  time: '2 h',
  initials: 'AA',
  body: 'Corpo da publicação de $author',
  media: media,
);

const _scopeA = PrincipalHappensFeedScope(institutionId: 'inst-1', unitId: 'unit-1');
const _scopeB = PrincipalHappensFeedScope(institutionId: 'inst-1', unitId: 'unit-2');

Future<void> _pumpTab(
  WidgetTester tester, {
  required _FakeFeedRepository repository,
  required PrincipalHappensFeedScope scope,
  ValueChanged<PrincipalPostPreviewItem>? onOpenPost,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PrincipalProfileHappensTab(
          repository: repository,
          scope: scope,
          onOpenPost: onOpenPost,
        ),
      ),
    ),
  ),
);

void main() {
  const loading = Key('principal-profile-happens-loading');
  const error = Key('principal-profile-happens-error');
  const unauthorized = Key('principal-profile-happens-unauthorized');
  const empty = Key('principal-profile-happens-empty');
  const list = Key('principal-profile-happens-list');

  testWidgets('mostra estado de carregamento enquanto a projeção não responde', (tester) async {
    final repository = _FakeFeedRepository();
    await _pumpTab(tester, repository: repository, scope: _scopeA);

    expect(find.byKey(loading), findsOneWidget);
    expect(find.byKey(list), findsNothing);
    expect(repository.requestedScopes.single.unitId, 'unit-1');

    repository.lastRequest.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('renderiza a lista com os itens autorizados', (tester) async {
    final repository = _FakeFeedRepository();
    await _pumpTab(tester, repository: repository, scope: _scopeA);
    repository.lastRequest.complete([_post('Prof. Rafael'), _post('Coordenação')]);
    await tester.pumpAndSettle();

    expect(find.byKey(list), findsOneWidget);
    expect(find.text('Prof. Rafael'), findsOneWidget);
    expect(find.text('Coordenação'), findsOneWidget);
    expect(find.text('Corpo da publicação de Prof. Rafael'), findsOneWidget);
    expect(find.byKey(empty), findsNothing);
  });

  testWidgets('abre a publicação pelo callback opcional', (tester) async {
    final repository = _FakeFeedRepository();
    final opened = <String>[];
    await _pumpTab(
      tester,
      repository: repository,
      scope: _scopeA,
      onOpenPost: (item) => opened.add(item.author),
    );
    repository.lastRequest.complete([_post('Prof. Rafael')]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Prof. Rafael'));
    await tester.pump();
    expect(opened, ['Prof. Rafael']);
  });

  testWidgets('mostra o estado vazio quando a projeção não tem posts', (tester) async {
    final repository = _FakeFeedRepository();
    await _pumpTab(tester, repository: repository, scope: _scopeA);
    repository.lastRequest.complete(const []);
    await tester.pumpAndSettle();

    expect(find.byKey(empty), findsOneWidget);
    expect(find.byKey(list), findsNothing);
  });

  testWidgets('erro oferece "Tentar novamente" e recupera', (tester) async {
    final repository = _FakeFeedRepository();
    await _pumpTab(tester, repository: repository, scope: _scopeA);
    repository.lastRequest.completeError(const PrincipalHappensFeedUnavailable());
    await tester.pumpAndSettle();

    expect(find.byKey(error), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(find.byKey(loading), findsOneWidget);
    expect(repository.requestCount, 2);

    repository.lastRequest.complete([_post('Prof. Rafael')]);
    await tester.pumpAndSettle();
    expect(find.byKey(error), findsNothing);
    expect(find.text('Prof. Rafael'), findsOneWidget);
  });

  testWidgets('negado é fail-closed: sem retry e sem conteúdo anterior', (tester) async {
    final repository = _FakeFeedRepository();
    await _pumpTab(tester, repository: repository, scope: _scopeA);
    repository.lastRequest.complete([_post('Prof. Rafael')]);
    await tester.pumpAndSettle();
    expect(find.text('Prof. Rafael'), findsOneWidget);

    await _pumpTab(tester, repository: repository, scope: _scopeB);
    repository.lastRequest.completeError(const PrincipalHappensFeedUnauthorized());
    await tester.pumpAndSettle();

    expect(find.byKey(unauthorized), findsOneWidget);
    expect(find.byKey(list), findsNothing);
    expect(find.text('Prof. Rafael'), findsNothing);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('recarrega ao trocar o escopo', (tester) async {
    final repository = _FakeFeedRepository();
    await _pumpTab(tester, repository: repository, scope: _scopeA);
    repository.lastRequest.complete([_post('Turma 1')]);
    await tester.pumpAndSettle();

    await _pumpTab(tester, repository: repository, scope: _scopeB);
    await tester.pump();
    expect(find.byKey(loading), findsOneWidget);
    expect(find.text('Turma 1'), findsNothing);
    expect(repository.requestCount, 2);
    expect(repository.requestedScopes.last.unitId, 'unit-2');

    repository.lastRequest.complete([_post('Turma 2')]);
    await tester.pumpAndSettle();
    expect(find.text('Turma 2'), findsOneWidget);
  });

  testWidgets('resposta tardia da geração anterior não sobrescreve a nova', (tester) async {
    final repository = _FakeFeedRepository();
    await _pumpTab(tester, repository: repository, scope: _scopeA);

    await _pumpTab(tester, repository: repository, scope: _scopeB);
    await tester.pump();
    expect(repository.requestCount, 2);

    repository.requestAt(1).complete([_post('Turma 2')]);
    await tester.pumpAndSettle();
    expect(find.text('Turma 2'), findsOneWidget);

    repository.requestAt(0).complete([_post('Turma 1 atrasada')]);
    await tester.pumpAndSettle();
    expect(find.text('Turma 1 atrasada'), findsNothing);
    expect(find.text('Turma 2'), findsOneWidget);
  });

  testWidgets('mídia é resolvida por URL assinada e degrada sem quebrar a lista', (tester) async {
    final repository = _FakeFeedRepository(mediaError: const PrincipalHappensFeedUnavailable());
    await _pumpTab(tester, repository: repository, scope: _scopeA);
    repository.lastRequest.complete([
      _post(
        'Prof. Rafael',
        media: const [
          PrincipalHappensMediaDescriptor(
            readTicket: 'ticket-1',
            mimeType: 'image/jpeg',
            displayOrder: 0,
          ),
        ],
      ),
    ]);
    await tester.pumpAndSettle();

    expect(repository.resolvedMedia.single.readTicket, 'ticket-1');
    expect(find.byKey(const Key('principal-profile-happens-media-placeholder')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-happens-media-image')), findsNothing);
    expect(find.text('Prof. Rafael'), findsOneWidget);
  });

  testWidgets('mídia autorizada usa a URL assinada retornada pelo repositório', (tester) async {
    final repository = _FakeFeedRepository(
      mediaRead: const PrincipalHappensMediaRead(
        signedUrl: 'https://signed.example/ticket-1',
        mimeType: 'image/jpeg',
        expiresIn: Duration(minutes: 5),
      ),
    );
    await _pumpTab(tester, repository: repository, scope: _scopeA);
    repository.lastRequest.complete([
      _post(
        'Prof. Rafael',
        media: const [
          PrincipalHappensMediaDescriptor(
            readTicket: 'ticket-1',
            mimeType: 'image/jpeg',
            displayOrder: 0,
          ),
        ],
      ),
    ]);
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.byKey(const Key('principal-profile-happens-media-image')),
    );
    expect((image.image as NetworkImage).url, 'https://signed.example/ticket-1');
  });
}
