import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/principal_now_feed_repository.dart';

typedef PrincipalNowClock = DateTime Function();

final class SupabasePrincipalNowFeedRepository implements PrincipalNowFeedRepository {
  SupabasePrincipalNowFeedRepository(this._client, {PrincipalNowClock? now})
    : _now = now ?? DateTime.now;

  final SupabaseClient _client;
  final PrincipalNowClock _now;

  @override
  Future<List<PrincipalNowFeedItem>> listVisibleStories(PrincipalNowFeedScope scope) async {
    try {
      final response = await _client.rpc<List<dynamic>>(
        'list_visible_now_publications',
        params: {
          'p_institution_id': scope.institutionId,
          'p_unit_id': scope.unitId,
          'p_group_id': scope.groupId,
          'p_limit': scope.limit,
        },
      );
      final current = _now().toUtc();
      return response
          .map((value) => _itemFromJson(Map<String, dynamic>.from(value as Map), current))
          .where((item) => item.expiresAt.toUtc().isAfter(current))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        throw const PrincipalNowFeedUnauthorized();
      }
      throw const PrincipalNowFeedUnavailable();
    } on PrincipalNowFeedFailure {
      rethrow;
    } on Object {
      throw const PrincipalNowFeedUnavailable();
    }
  }

  @override
  Future<PrincipalNowMediaRead> resolveMedia(PrincipalNowMediaDescriptor media) async {
    try {
      final response = await _client.functions.invoke(
        'now-media',
        body: {'action': 'read', 'read_ticket': media.readTicket},
      );
      if (response.status == 401 || response.status == 403) {
        throw const PrincipalNowFeedUnauthorized();
      }
      if (response.status < 200 || response.status >= 300 || response.data is! Map) {
        throw const PrincipalNowFeedUnavailable();
      }
      final json = Map<String, dynamic>.from(response.data as Map);
      final signedUrl = Uri.tryParse(json['signed_url']?.toString() ?? '');
      final mimeType = _requiredText(json, 'mime_type');
      final expiresIn = json['expires_in'] as num?;
      if (signedUrl == null ||
          signedUrl.scheme != 'https' ||
          signedUrl.host.isEmpty ||
          signedUrl.userInfo.isNotEmpty ||
          expiresIn == null ||
          expiresIn <= 0 ||
          mimeType != media.mimeType) {
        throw const PrincipalNowFeedUnavailable();
      }
      return PrincipalNowMediaRead(
        signedUrl: signedUrl.toString(),
        mimeType: mimeType,
        expiresIn: Duration(seconds: expiresIn.toInt()),
      );
    } on FunctionException catch (error) {
      if (error.status == 401 || error.status == 403) {
        throw const PrincipalNowFeedUnauthorized();
      }
      throw const PrincipalNowFeedUnavailable();
    } on PrincipalNowFeedFailure {
      rethrow;
    } on Object {
      throw const PrincipalNowFeedUnavailable();
    }
  }
}

PrincipalNowFeedItem _itemFromJson(Map<String, dynamic> json, DateTime current) {
  final publishedAt = DateTime.tryParse(json['published_at']?.toString() ?? '');
  final expiresAt = DateTime.tryParse(json['expires_at']?.toString() ?? '');
  if (publishedAt == null || expiresAt == null) {
    throw const FormatException('invalid_now_period');
  }
  final mediaItems = (json['media'] as List? ?? const [])
      .map((value) => Map<String, dynamic>.from(value as Map))
      .where((value) => value['kind'] == 'media')
      .toList(growable: false);
  if (mediaItems.length != 1) throw const FormatException('invalid_now_media');
  final media = mediaItems.single;
  final overlay = (json['overlay_text'] as String?)?.trim() ?? '';
  final caption = (json['caption'] as String?)?.trim() ?? '';
  return PrincipalNowFeedItem(
    publicationId: _requiredText(json, 'publication_id'),
    author: _requiredText(json, 'author_name'),
    authorInitials: _requiredText(json, 'author_initials'),
    contextLabel: _requiredText(json, 'context_label'),
    timeLabel: _relativeTime(publishedAt, current),
    caption: overlay.isNotEmpty ? overlay : caption,
    publishedAt: publishedAt,
    expiresAt: expiresAt,
    cropScale: _requiredNumber(json, 'crop_scale', min: 1, max: 2),
    cropX: _requiredNumber(json, 'crop_x', min: -1, max: 1),
    cropY: _requiredNumber(json, 'crop_y', min: -1, max: 1),
    coverPosition: _requiredNumber(json, 'cover_position', min: 0, max: 1),
    media: PrincipalNowMediaDescriptor(
      readTicket: _requiredText(media, 'read_ticket'),
      mimeType: _requiredText(media, 'mime_type'),
    ),
  );
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = (json[key] as String?)?.trim();
  if (value == null || value.isEmpty) throw FormatException('invalid_$key');
  return value;
}

double _requiredNumber(
  Map<String, dynamic> json,
  String key, {
  required double min,
  required double max,
}) {
  final value = (json[key] as num?)?.toDouble();
  if (value == null || !value.isFinite || value < min || value > max) {
    throw FormatException('invalid_$key');
  }
  return value;
}

String _relativeTime(DateTime publishedAt, DateTime current) {
  final difference = current.toUtc().difference(publishedAt.toUtc());
  if (difference.inMinutes < 1) return 'Agora';
  if (difference.inHours < 1) return '${difference.inMinutes} min';
  return '${difference.inHours} h';
}
