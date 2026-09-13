import '../domain/circular_repository.dart';
import '../domain/principal_happens_mixed_feed.dart';

/// Combines separately authorized scopes using the server's global keyset order.
final class ContextualPrincipalMixedFeedRepository implements PrincipalMixedFeedRepository {
  const ContextualPrincipalMixedFeedRepository(this.source, this.scopes);
  final PrincipalMixedFeedRepository source;
  final List<CircularScope> scopes;

  @override
  Future<PrincipalHappensFeedPage> list(
    CircularScope scope, {
    PrincipalHappensFeedCursor? cursor,
    int limit = 20,
  }) async {
    final count = limit.clamp(1, 50);
    final pages = await Future.wait([
      for (final selected in scopes) source.list(selected, cursor: cursor, limit: count),
    ]);
    final unique = <String, PrincipalHappensFeedItem>{};
    for (final page in pages) {
      for (final item in page.items) {
        unique['${_kind(item)}:${item.id}'] = item;
      }
    }
    final items = unique.values.toList()
      ..sort((a, b) {
        final date = b.publishedAt.compareTo(a.publishedAt);
        if (date != 0) return date;
        final kind = _kind(b).compareTo(_kind(a));
        return kind != 0 ? kind : b.id.compareTo(a.id);
      });
    final visible = items.take(count).toList();
    final more = items.length > count || pages.any((page) => page.nextCursor != null);
    final last = visible.lastOrNull;
    return PrincipalHappensFeedPage(
      items: visible,
      nextCursor: !more || last == null
          ? null
          : PrincipalHappensFeedCursor(
              publishedAt: last.publishedAt,
              itemType: _kind(last),
              itemId: last.id,
            ),
    );
  }
}

String _kind(PrincipalHappensFeedItem item) =>
    item is PrincipalHappensPostItem ? 'post' : 'circular';
