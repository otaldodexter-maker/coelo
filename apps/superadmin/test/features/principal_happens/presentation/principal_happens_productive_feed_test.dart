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
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Publicação carregada do contexto autorizado.'), findsOneWidget);
    expect(find.text(PrincipalHappensPreviewData.demo.posts.first.body), findsNothing);
    expect(find.text('Publicado para a comunidade escolar'), findsNothing);
    expect(find.text('null'), findsNothing);
  });

  testWidgets('resolves an opaque media ticket only when the post media is built', (tester) async {
    const media = PrincipalHappensMediaDescriptor(
      readTicket: 'ticket-1',
      mimeType: 'image/jpeg',
      displayOrder: 0,
    );
    final repository = _FeedRepository(
      () async => const [
        PrincipalPostPreviewItem(
          author: 'Equipe Coelo',
          context: 'Colégio Horizonte',
          time: 'Agora',
          initials: 'EC',
          body: 'Registro autorizado.',
          media: [media],
        ),
      ],
    );
    await pumpFeed(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.resolvedTickets, ['ticket-1']);
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

  testWidgets('reloads the feed to obtain a fresh ticket after media read failure', (tester) async {
    var loads = 0;
    var reads = 0;
    final repository = _FeedRepository(
      () async {
        loads++;
        return [
          PrincipalPostPreviewItem(
            author: 'Equipe Coelo',
            context: 'Colégio Horizonte',
            time: 'Agora',
            initials: 'EC',
            body: 'Registro autorizado.',
            media: [
              PrincipalHappensMediaDescriptor(
                readTicket: 'ticket-$loads',
                mimeType: 'image/jpeg',
                displayOrder: 0,
              ),
            ],
          ),
        ];
      },
      resolve: (media) async {
        reads++;
        if (reads == 1) throw const PrincipalHappensFeedUnavailable();
        return PrincipalHappensMediaRead(
          signedUrl: 'https://coelo.invalid/${media.readTicket}',
          mimeType: media.mimeType,
          expiresIn: const Duration(seconds: 60),
        );
      },
    );
    await pumpFeed(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tentar carregar a mídia novamente'));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(repository.resolvedTickets, ['ticket-1', 'ticket-2']);
  });
}

final class _FeedRepository implements PrincipalHappensFeedRepository {
  _FeedRepository(this.load, {this.resolve});

  final Future<List<PrincipalPostPreviewItem>> Function() load;
  final Future<PrincipalHappensMediaRead> Function(PrincipalHappensMediaDescriptor media)? resolve;
  final List<String> resolvedTickets = [];

  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope) =>
      load();

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) async {
    resolvedTickets.add(media.readTicket);
    if (resolve case final resolver?) return resolver(media);
    return PrincipalHappensMediaRead(
      signedUrl: 'https://coelo.invalid/${media.readTicket}',
      mimeType: media.mimeType,
      expiresIn: const Duration(seconds: 60),
    );
  }
}
