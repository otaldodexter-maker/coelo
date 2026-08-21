import 'package:flutter/foundation.dart';

import '../../principal_happens/domain/principal_happens_preview_data.dart';
import 'circular_repository.dart';

@immutable
sealed class PrincipalHappensFeedItem {
  const PrincipalHappensFeedItem({
    required this.id,
    required this.publishedAt,
    required this.authorName,
    required this.contextLabel,
  });

  final String id;
  final DateTime publishedAt;
  final String authorName;
  final String contextLabel;
}

@immutable
final class PrincipalHappensPostItem extends PrincipalHappensFeedItem {
  const PrincipalHappensPostItem({
    required super.id,
    required super.publishedAt,
    required super.authorName,
    required super.contextLabel,
    required this.caption,
    this.media = const [],
  });

  final String caption;
  final List<PrincipalHappensMediaDescriptor> media;
}

@immutable
final class PrincipalHappensCircularItem extends PrincipalHappensFeedItem {
  const PrincipalHappensCircularItem({
    required super.id,
    required super.publishedAt,
    required super.authorName,
    required super.contextLabel,
    required this.summary,
  });

  final CircularSummary summary;
}

@immutable
final class PrincipalHappensFeedCursor {
  const PrincipalHappensFeedCursor({
    required this.publishedAt,
    required this.itemType,
    required this.itemId,
  });

  final DateTime publishedAt;
  final String itemType;
  final String itemId;
}

@immutable
final class PrincipalHappensFeedPage {
  const PrincipalHappensFeedPage({required this.items, required this.nextCursor});

  final List<PrincipalHappensFeedItem> items;
  final PrincipalHappensFeedCursor? nextCursor;
}

abstract interface class PrincipalMixedFeedRepository {
  Future<PrincipalHappensFeedPage> list(
    CircularScope scope, {
    PrincipalHappensFeedCursor? cursor,
    int limit = 20,
  });
}
