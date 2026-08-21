import 'package:supabase_flutter/supabase_flutter.dart';

import '../../principal_happens/domain/principal_happens_preview_data.dart';
import '../domain/circular.dart';
import '../domain/circular_repository.dart';
import '../domain/principal_happens_mixed_feed.dart';

final class SupabasePrincipalMixedFeedRepository implements PrincipalMixedFeedRepository {
  const SupabasePrincipalMixedFeedRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PrincipalHappensFeedPage> list(
    CircularScope scope, {
    PrincipalHappensFeedCursor? cursor,
    int limit = 20,
  }) async {
    try {
      final response = await _client.rpc<List<dynamic>>(
        'list_visible_happens_feed',
        params: {
          'p_institution_id': scope.institutionId,
          'p_unit_id': scope.unitId,
          'p_group_id': scope.groupId,
          'p_activity_id': scope.activityId,
          'p_before_at': cursor?.publishedAt.toUtc().toIso8601String(),
          'p_before_type': cursor?.itemType,
          'p_before_id': cursor?.itemId,
          'p_limit': limit,
        },
      );
      final rows = response.map((row) => Map<String, dynamic>.from(row as Map)).toList();
      final items = rows.map(_item).toList(growable: false);
      final lastRow = rows.lastOrNull;
      return PrincipalHappensFeedPage(
        items: items,
        nextCursor: rows.length < limit || lastRow == null
            ? null
            : PrincipalHappensFeedCursor(
                publishedAt: _date(lastRow, 'effective_published_at'),
                itemType: _text(lastRow, 'item_type'),
                itemId: _text(lastRow, 'item_id'),
              ),
      );
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        throw const CircularUnauthorized();
      }
      throw const CircularUnavailable();
    } on Object {
      throw const CircularUnavailable();
    }
  }
}

PrincipalHappensFeedItem _item(Map<String, dynamic> row) {
  final payload = Map<String, dynamic>.from(row['payload'] as Map);
  final id = _text(row, 'item_id');
  final publishedAt = _date(row, 'effective_published_at');
  final author = _text(payload, 'author_name');
  final context = _text(payload, 'context_label');
  return switch (row['item_type']) {
    'post' => PrincipalHappensPostItem(
      id: id,
      publishedAt: publishedAt,
      authorName: author,
      contextLabel: context,
      caption: payload['caption'] as String? ?? '',
      media: _postMedia(payload['media']),
    ),
    'circular' => PrincipalHappensCircularItem(
      id: id,
      publishedAt: publishedAt,
      authorName: author,
      contextLabel: context,
      summary: CircularSummary(
        id: id,
        title: _text(payload, 'title'),
        excerpt: payload['excerpt'] as String? ?? '',
        authorName: author,
        contextLabel: context,
        publishedAt: publishedAt,
        revisedAt: _optionalDate(payload['revised_at']),
        attachmentCount: _integer(payload, 'attachment_count'),
        questionCount: _integer(payload, 'question_count'),
        responseState: switch (payload['response_state']) {
          'partial' => CircularResponseState.partial,
          'answered' => CircularResponseState.answered,
          _ => CircularResponseState.unanswered,
        },
      ),
    ),
    _ => throw const FormatException('invalid_feed_item_type'),
  };
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) throw FormatException('invalid_$key');
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw FormatException('invalid_$key');
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = DateTime.tryParse(json[key]?.toString() ?? '');
  if (value == null) throw FormatException('invalid_$key');
  return value;
}

DateTime? _optionalDate(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());

List<PrincipalHappensMediaDescriptor> _postMedia(Object? value) {
  if (value is! List) return const [];
  final media =
      value
          .map((raw) {
            if (raw is! Map) throw const FormatException('invalid_post_media');
            final json = Map<String, dynamic>.from(raw);
            return PrincipalHappensMediaDescriptor(
              readTicket: _text(json, 'read_ticket'),
              mimeType: _text(json, 'mime_type'),
              displayOrder: _integer(json, 'display_order'),
            );
          })
          .toList(growable: false)
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  return media;
}
