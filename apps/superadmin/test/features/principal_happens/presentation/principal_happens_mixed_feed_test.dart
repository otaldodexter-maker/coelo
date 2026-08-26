import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/principal_happens_mixed_feed.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dispatches each sealed mixed item once and preserves post media', (tester) async {
    var openedCircular = '';
    final repository = _MixedRepository();
    await tester.binding.setSurfaceSize(const Size(768, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalHappensPreviewPage.mixed(
          mixedFeedRepository: repository,
          mixedFeedScope: const CircularScope(institutionId: 'institution-1'),
          mediaRepository: _MediaRepository(),
          onOpenCircular: (id) => openedCircular = id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(find.text('Post preservado'), findsOneWidget);
    expect(find.byKey(const ValueKey('read-ticket-1')), findsOneWidget);
    expect(find.text('Circular no Acontece'), findsOneWidget);
    expect(find.text('Post preservado'), findsOneWidget);

    await tester.tap(find.text('Ler circular'));
    expect(openedCircular, 'circular-1');
  });
}

final class _MixedRepository implements PrincipalMixedFeedRepository {
  var calls = 0;

  @override
  Future<PrincipalHappensFeedPage> list(
    CircularScope scope, {
    PrincipalHappensFeedCursor? cursor,
    int limit = 20,
  }) async {
    calls++;
    return PrincipalHappensFeedPage(
      items: [
        PrincipalHappensPostItem(
          id: 'post-1',
          publishedAt: DateTime.utc(2026, 8, 21, 12),
          authorName: 'Equipe Horizonte',
          contextLabel: 'Colégio Horizonte',
          caption: 'Post preservado',
          media: const [
            PrincipalHappensMediaDescriptor(
              readTicket: 'read-ticket-1',
              mimeType: 'image/jpeg',
              displayOrder: 0,
            ),
          ],
        ),
        PrincipalHappensCircularItem(
          id: 'circular-1',
          publishedAt: DateTime.utc(2026, 8, 21, 11),
          authorName: 'Equipe Horizonte',
          contextLabel: 'Colégio Horizonte',
          summary: CircularSummary(
            id: 'circular-1',
            title: 'Circular no Acontece',
            excerpt: 'Resumo autorizado.',
            authorName: 'Equipe Horizonte',
            contextLabel: 'Colégio Horizonte',
            publishedAt: DateTime.utc(2026, 8, 21, 11),
            attachmentCount: 0,
            questionCount: 0,
            responseState: CircularResponseState.unanswered,
          ),
        ),
      ],
      nextCursor: null,
    );
  }
}

final class _MediaRepository implements PrincipalHappensFeedRepository {
  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) async =>
      const PrincipalHappensMediaRead(
        signedUrl: 'https://example.test/media.jpg',
        mimeType: 'image/jpeg',
        expiresIn: Duration(minutes: 2),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
