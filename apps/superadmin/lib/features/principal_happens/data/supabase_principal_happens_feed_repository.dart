import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/principal_happens_feed_repository.dart';
import '../domain/principal_happens_preview_data.dart';

final class SupabasePrincipalHappensFeedRepository implements PrincipalHappensFeedRepository {
  const SupabasePrincipalHappensFeedRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope) async {
    try {
      final response = await _client.rpc<List<dynamic>>(
        'list_visible_happens_posts',
        params: {
          'p_institution_id': scope.institutionId,
          'p_unit_id': scope.unitId,
          'p_group_id': scope.groupId,
          'p_limit': 20,
        },
      );
      return response
          .map((row) => _postFromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        throw const PrincipalHappensFeedUnauthorized();
      }
      throw const PrincipalHappensFeedUnavailable();
    } on FormatException {
      throw const PrincipalHappensFeedUnavailable();
    }
  }

  @override
  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media) async {
    try {
      final response = await _client.functions.invoke(
        'happens-media',
        body: {'action': 'read', 'read_ticket': media.readTicket},
      );
      if (response.status != 200 || response.data is! Map) {
        throw const PrincipalHappensFeedUnavailable();
      }
      final json = Map<String, dynamic>.from(response.data as Map);
      final signedUrl = json['signed_url'] as String?;
      final mimeType = json['mime_type'] as String?;
      final expiresIn = json['expires_in'] as num?;
      if (signedUrl == null || mimeType == null || expiresIn == null) {
        throw const PrincipalHappensFeedUnavailable();
      }
      return PrincipalHappensMediaRead(
        signedUrl: signedUrl,
        mimeType: mimeType,
        expiresIn: Duration(seconds: expiresIn.toInt()),
      );
    } on PrincipalHappensFeedUnavailable {
      rethrow;
    } on Object {
      throw const PrincipalHappensFeedUnavailable();
    }
  }
}

PrincipalPostPreviewItem _postFromJson(Map<String, dynamic> json) {
  final author = _requiredText(json, 'author_name');
  final initials = _requiredText(json, 'author_initials');
  final context = _requiredText(json, 'context_label');
  final publishedAt = DateTime.tryParse(json['published_at']?.toString() ?? '');
  if (publishedAt == null) throw const FormatException('invalid_published_at');
  final media =
      (json['media'] as List? ?? const [])
          .map((value) {
            final item = Map<String, dynamic>.from(value as Map);
            final displayOrder = item['display_order'] as num?;
            if (displayOrder == null) throw const FormatException('invalid_media_order');
            return PrincipalHappensMediaDescriptor(
              readTicket: _requiredText(item, 'read_ticket'),
              mimeType: _requiredText(item, 'mime_type'),
              displayOrder: displayOrder.toInt(),
            );
          })
          .toList(growable: false)
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  return PrincipalPostPreviewItem(
    author: author,
    context: context,
    time: _relativeTime(publishedAt),
    initials: initials,
    body: json['caption'] as String? ?? '',
    media: media,
  );
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = (json[key] as String?)?.trim();
  if (value == null || value.isEmpty) throw FormatException('invalid_$key');
  return value;
}

String _relativeTime(DateTime? value) {
  if (value == null) return 'Agora';
  final difference = DateTime.now().toUtc().difference(value.toUtc());
  if (difference.inMinutes < 1) return 'Agora';
  if (difference.inHours < 1) return '${difference.inMinutes} min';
  if (difference.inDays < 1) return '${difference.inHours} h';
  return '${difference.inDays} d';
}
