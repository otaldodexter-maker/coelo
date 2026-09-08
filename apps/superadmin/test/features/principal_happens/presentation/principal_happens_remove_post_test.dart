import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Client acceptance for `acontece.remove`.
///
/// The Owner decided removal is governed by authorised profiles through
/// hierarchy and RLS, so the client never derives the permission: it renders the
/// affordance only when the authorised projection already granted it, and the
/// server revalidates the command. The authorised command does not exist yet, so
/// production keeps failing closed.
void main() {
  const scope = PrincipalHappensFeedScope(institutionId: 'institution-coelo');

  Future<void> pump(WidgetTester tester, _FeedRepository repository) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalHappensPreviewPage(feedRepository: repository, feedScope: scope),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder removeButton() => find.byKey(const Key('principal-happens-remove-post-0'));

  testWidgets('no affordance while the projection does not grant removal', (tester) async {
    await pump(tester, _FeedRepository([_post(canRemove: false)]));

    expect(removeButton(), findsNothing);
    expect(find.byTooltip('Mais opções da publicação'), findsWidgets);
  });

  testWidgets('no affordance when the projection omits the post id', (tester) async {
    await pump(tester, _FeedRepository([_post(id: null, canRemove: true)]));

    expect(removeButton(), findsNothing);
  });

  testWidgets('a granted removal requires a recorded reason', (tester) async {
    final repository = _FeedRepository([_post(canRemove: true)]);
    await pump(tester, repository);

    await tester.tap(removeButton());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-happens-remove-dialog')), findsOneWidget);
    final blocked = tester.widget<FilledButton>(
      find.byKey(const Key('principal-happens-remove-confirm')),
    );
    expect(blocked.onPressed, isNull, reason: 'audit must not depend on an optional field');

    await tester.enterText(
      find.byKey(const Key('principal-happens-remove-reason')),
      'Conteudo publicado por engano',
    );
    await tester.pump();
    final allowed = tester.widget<FilledButton>(
      find.byKey(const Key('principal-happens-remove-confirm')),
    );
    expect(allowed.onPressed, isNotNull);
  });

  testWidgets('cancelling sends nothing', (tester) async {
    final repository = _FeedRepository([_post(canRemove: true)]);
    await pump(tester, repository);

    await tester.tap(removeButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('principal-happens-remove-reason')), 'Desisti');
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-happens-remove-cancel')));
    await tester.pumpAndSettle();

    expect(repository.removals, isEmpty);
    expect(repository.loads, 1, reason: 'a cancelled removal must not reload the feed');
  });

  testWidgets('confirming sends the post id and reason, then reloads the feed', (tester) async {
    final repository = _FeedRepository([_post(canRemove: true)], removalSucceeds: true);
    await pump(tester, repository);

    await tester.tap(removeButton());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('principal-happens-remove-reason')),
      'Conteudo publicado por engano',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-happens-remove-confirm')));
    await tester.pumpAndSettle();

    expect(repository.removals.single.postId, 'post-1');
    expect(repository.removals.single.reason, 'Conteudo publicado por engano');
    expect(repository.removals.single.requestId, isNotEmpty);
    // The feed is refetched: absence is proved by the server, not by hiding the
    // row locally.
    expect(repository.loads, 2);
  });

  testWidgets('an unavailable command keeps the post and says so', (tester) async {
    final repository = _FeedRepository([_post(canRemove: true)]);
    await pump(tester, repository);

    await tester.tap(removeButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('principal-happens-remove-reason')), 'Tentativa');
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-happens-remove-confirm')));
    await tester.pumpAndSettle();

    expect(repository.loads, 1, reason: 'nothing was removed, so nothing is refetched');
    expect(find.text('Registro autorizado'), findsWidgets);
    expect(find.text('Remocao aguarda o comando autorizado.'), findsOneWidget);
  });

  testWidgets('a denied removal is reported without hiding the post', (tester) async {
    final repository = _FeedRepository([_post(canRemove: true)], denyRemoval: true);
    await pump(tester, repository);

    await tester.tap(removeButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('principal-happens-remove-reason')), 'Tentativa');
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-happens-remove-confirm')));
    await tester.pumpAndSettle();

    expect(repository.loads, 1);
    expect(find.text('Registro autorizado'), findsWidgets);
    expect(find.text('Voce nao pode remover esta publicacao.'), findsOneWidget);
  });
}

PrincipalPostPreviewItem _post({String? id = 'post-1', required bool canRemove}) =>
    PrincipalPostPreviewItem(
      id: id,
      canRemove: canRemove,
      author: 'Equipe Coelo',
      context: '3º ano A',
      time: 'Agora',
      initials: 'EC',
      body: 'Registro autorizado',
    );

final class _FeedRepository implements PrincipalHappensFeedRepository {
  _FeedRepository(this._posts, {this.removalSucceeds = false, this.denyRemoval = false});

  final List<PrincipalPostPreviewItem> _posts;
  final bool removalSucceeds;
  final bool denyRemoval;
  final List<PrincipalHappensRemoveCommand> removals = [];
  var loads = 0;

  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope) async {
    loads++;
    return _posts;
  }

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) =>
      Future<PrincipalHappensMediaRead>.error(const PrincipalHappensFeedUnavailable());

  @override
  Future<void> removePost(PrincipalHappensRemoveCommand command) async {
    removals.add(command);
    if (denyRemoval) throw const PrincipalHappensFeedUnauthorized();
    if (!removalSucceeds) throw const PrincipalHappensRemoveUnavailable();
  }
}
