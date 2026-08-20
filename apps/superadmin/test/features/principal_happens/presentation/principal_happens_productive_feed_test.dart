import 'dart:async';

import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scope = PrincipalHappensFeedScope(institutionId: 'institution-1');

  Future<void> pumpFeed(WidgetTester tester, PrincipalHappensFeedRepository repository) async {
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalHappensPreviewPage(feedRepository: repository, feedScope: scope),
      ),
    );
  }

  testWidgets('keeps Agora visible while the productive feed loads', (tester) async {
    final completer = Completer<List<PrincipalPostPreviewItem>>();
    await pumpFeed(tester, _FeedRepository(() => completer.future));
    await tester.pump();

    expect(find.text('Agora'), findsOneWidget);
    expect(find.text('Carregando publicações'), findsOneWidget);

    completer.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('Tudo em dia por aqui'), findsOneWidget);
  });

  testWidgets('renders posts returned by the injected feed repository', (tester) async {
    await pumpFeed(
      tester,
      _FeedRepository(
        () async => const [
          PrincipalPostPreviewItem(
            author: 'Equipe Coelo',
            context: 'Colégio Horizonte',
            time: 'Agora',
            initials: 'EC',
            body: 'Publicação carregada do contexto autorizado.',
            mediaIndices: [],
            likes: 0,
            comments: 0,
            shares: 0,
            likedBy: 'Publicado para a comunidade escolar',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Publicação carregada do contexto autorizado.'), findsOneWidget);
    expect(find.text(PrincipalHappensPreviewData.demo.posts.first.body), findsNothing);
  });

  testWidgets('offers retry after a transient feed error', (tester) async {
    var attempts = 0;
    await pumpFeed(
      tester,
      _FeedRepository(() async {
        attempts++;
        if (attempts == 1) throw const PrincipalHappensFeedUnavailable();
        return const [];
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar o Acontece'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Tudo em dia por aqui'), findsOneWidget);
  });
}

final class _FeedRepository implements PrincipalHappensFeedRepository {
  const _FeedRepository(this.load);

  final Future<List<PrincipalPostPreviewItem>> Function() load;

  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope) =>
      load();
}
