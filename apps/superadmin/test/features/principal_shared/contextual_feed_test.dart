import 'package:coelo_superadmin/features/principal_circulars/data/contextual_principal_mixed_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/principal_happens_mixed_feed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'combines authorized contexts, deduplicates and paginates without hiding seen posts',
    () async {
      final source = _Feed();
      final combined = ContextualPrincipalMixedFeedRepository(source, const [
        CircularScope(institutionId: 'a'),
        CircularScope(institutionId: 'b'),
      ]);
      const scope = CircularScope(institutionId: 'a');
      final first = await combined.list(scope, limit: 2);
      expect(first.items.map((item) => item.id), ['4', '3']);
      final second = await combined.list(scope, cursor: first.nextCursor, limit: 2);
      expect(second.items.map((item) => item.id), ['2', '1']);
      final reloaded = await combined.list(scope, limit: 2);
      expect(reloaded.items.map((item) => item.id), ['4', '3']);
      expect(source.scopes.toSet(), {'a', 'b'});
    },
  );
  test(
    'a denied selected context fails closed instead of returning a misleading partial feed',
    () async {
      final combined = ContextualPrincipalMixedFeedRepository(_Feed(), const [
        CircularScope(institutionId: 'a'),
        CircularScope(institutionId: 'denied'),
      ]);
      await expectLater(combined.list(const CircularScope(institutionId: 'a')), throwsStateError);
    },
  );
}

class _Feed implements PrincipalMixedFeedRepository {
  final scopes = <String>[];
  @override
  Future<PrincipalHappensFeedPage> list(
    CircularScope scope, {
    PrincipalHappensFeedCursor? cursor,
    int limit = 20,
  }) async {
    scopes.add(scope.institutionId);
    if (scope.institutionId == 'denied') throw StateError('denied');
    final ids = scope.institutionId == 'a' ? ['4', '2', '1'] : ['3', '2'];
    final items = ids
        .where((id) => cursor == null || id.compareTo(cursor.itemId) < 0)
        .take(limit)
        .map(
          (id) => PrincipalHappensPostItem(
            id: id,
            publishedAt: DateTime.utc(2026),
            authorName: 'QA',
            contextLabel: scope.institutionId,
            caption: 'Previously viewed publication',
          ),
        )
        .toList();
    return PrincipalHappensFeedPage(
      items: items,
      nextCursor: items.length < limit
          ? null
          : PrincipalHappensFeedCursor(
              publishedAt: items.last.publishedAt,
              itemType: 'post',
              itemId: items.last.id,
            ),
    );
  }
}
