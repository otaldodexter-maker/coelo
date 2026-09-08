import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_moments/domain/principal_moments_preview_data.dart';
import 'package:coelo_superadmin/features/principal_moments/presentation/principal_moments_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Client acceptance for `momentos.remove`.
///
/// The Owner decided removal is governed by authorised profiles through
/// hierarchy and RLS, so the client never derives the permission: it renders the
/// affordance only when the authorised projection already granted it, and the
/// server revalidates the command. The authorised command does not exist yet, so
/// production keeps failing closed.
void main() {
  const scope = PrincipalMomentsFeedScope(institutionId: 'institution-coelo');

  Future<void> pump(WidgetTester tester, _FeedRepository repository) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalMomentsPreviewPage(feedRepository: repository, feedScope: scope),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder removeButton() => find.byKey(const Key('principal-moments-remove'));

  Future<void> confirmWithReason(WidgetTester tester, String reason) async {
    await tester.tap(removeButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('principal-moments-remove-reason')), reason);
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-moments-remove-confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets('no affordance while the projection does not grant removal', (tester) async {
    await pump(tester, _FeedRepository([_moment(canRemove: false)]));

    expect(removeButton(), findsNothing);
    expect(find.byIcon(Icons.more_horiz_rounded), findsWidgets);
  });

  testWidgets('no affordance when the projection omits the moment id', (tester) async {
    await pump(tester, _FeedRepository([_moment(id: null, canRemove: true)]));

    expect(removeButton(), findsNothing);
  });

  testWidgets('the affordance follows the moment on screen', (tester) async {
    final repository = _FeedRepository([
      _moment(canRemove: false),
      _moment(id: 'moment-2', canRemove: true, caption: 'Segundo momento.'),
    ], removalSucceeds: true);
    await pump(tester, repository);

    // The first moment was not granted, so nothing is offered for it.
    expect(removeButton(), findsNothing);

    await tester.fling(
      find.byKey(const Key('principal-moments-page-view')),
      const Offset(0, -400),
      1200,
    );
    await tester.pumpAndSettle();

    expect(removeButton(), findsOneWidget);
    await confirmWithReason(tester, 'Publicado por engano');

    // The command carries the moment the operator is looking at, never the one
    // the page opened on.
    expect(repository.removals.single.momentId, 'moment-2');
  });

  testWidgets('a granted removal requires a recorded reason', (tester) async {
    await pump(tester, _FeedRepository([_moment(canRemove: true)]));

    await tester.tap(removeButton());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-moments-remove-dialog')), findsOneWidget);
    final blocked = tester.widget<FilledButton>(
      find.byKey(const Key('principal-moments-remove-confirm')),
    );
    expect(blocked.onPressed, isNull, reason: 'audit must not depend on an optional field');

    await tester.enterText(
      find.byKey(const Key('principal-moments-remove-reason')),
      'Publicado por engano',
    );
    await tester.pump();
    final allowed = tester.widget<FilledButton>(
      find.byKey(const Key('principal-moments-remove-confirm')),
    );
    expect(allowed.onPressed, isNotNull);
  });

  testWidgets('cancelling sends nothing', (tester) async {
    final repository = _FeedRepository([_moment(canRemove: true)]);
    await pump(tester, repository);

    await tester.tap(removeButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('principal-moments-remove-reason')), 'Desisti');
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-moments-remove-cancel')));
    await tester.pumpAndSettle();

    expect(repository.removals, isEmpty);
    expect(repository.loads, 1, reason: 'a cancelled removal must not reload the feed');
  });

  testWidgets('confirming sends the moment id and reason, then reloads the feed', (tester) async {
    final repository = _FeedRepository([_moment(canRemove: true)], removalSucceeds: true);
    await pump(tester, repository);

    await confirmWithReason(tester, 'Publicado por engano');

    expect(repository.removals.single.momentId, 'moment-1');
    expect(repository.removals.single.reason, 'Publicado por engano');
    expect(repository.removals.single.requestId, isNotEmpty);
    // Absence is proved by the server on the next read, never by hiding the
    // frame locally.
    expect(repository.loads, 2);
  });

  testWidgets('an unavailable command keeps the moment and says so', (tester) async {
    final repository = _FeedRepository([_moment(canRemove: true)]);
    await pump(tester, repository);

    await confirmWithReason(tester, 'Tentativa');

    expect(repository.loads, 1, reason: 'nothing was removed, so nothing is refetched');
    expect(find.text('Momento autorizado.'), findsWidgets);
    expect(find.text('Remocao aguarda o comando autorizado.'), findsOneWidget);
  });

  testWidgets('a denied removal is reported without hiding the moment', (tester) async {
    final repository = _FeedRepository([_moment(canRemove: true)], denyRemoval: true);
    await pump(tester, repository);

    await confirmWithReason(tester, 'Tentativa');

    expect(repository.loads, 1);
    expect(find.text('Momento autorizado.'), findsWidgets);
    expect(find.text('Voce nao pode remover este momento.'), findsOneWidget);
  });

  testWidgets('a retry replays the same request id instead of removing twice', (tester) async {
    final repository = _FeedRepository([_moment(canRemove: true)]);
    await pump(tester, repository);

    await confirmWithReason(tester, 'Primeira tentativa');
    await confirmWithReason(tester, 'Segunda tentativa');

    expect(repository.removals.length, 2);
    expect(
      repository.removals.first.requestId,
      repository.removals.last.requestId,
      reason: 'the same intent must replay, not duplicate the removal',
    );
  });
}

PrincipalMomentPreviewItem _moment({
  String? id = 'moment-1',
  required bool canRemove,
  String caption = 'Momento autorizado.',
}) => PrincipalMomentPreviewItem(
  id: id,
  canRemove: canRemove,
  author: 'Colégio Coelo',
  context: '3º ano A',
  time: 'Agora',
  caption: caption,
  likes: 0,
  comments: 0,
  shares: 0,
  saves: 0,
  imageIndex: 0,
);

final class _FeedRepository implements PrincipalMomentsFeedRepository {
  _FeedRepository(this._moments, {this.removalSucceeds = false, this.denyRemoval = false});

  final List<PrincipalMomentPreviewItem> _moments;
  final bool removalSucceeds;
  final bool denyRemoval;
  final List<PrincipalMomentsRemoveCommand> removals = [];
  var loads = 0;

  @override
  Future<List<PrincipalMomentPreviewItem>> listVisibleMoments(
    PrincipalMomentsFeedScope scope,
  ) async {
    loads++;
    return _moments;
  }

  @override
  Future<PrincipalMomentsMediaRead> resolveMedia(PrincipalMomentsMediaDescriptor media) =>
      Future<PrincipalMomentsMediaRead>.error(const PrincipalMomentsFeedUnavailable());

  @override
  Future<void> removeMoment(PrincipalMomentsRemoveCommand command) async {
    removals.add(command);
    if (denyRemoval) throw const PrincipalMomentsFeedUnauthorized();
    if (!removalSucceeds) throw const PrincipalMomentsRemoveUnavailable();
  }
}
