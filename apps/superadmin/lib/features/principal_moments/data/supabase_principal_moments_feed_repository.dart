import 'package:supabase_flutter/supabase_flutter.dart';

import '../../principal_shared/data/principal_signed_media_url.dart';
import '../domain/principal_moments_feed_repository.dart';
import '../domain/principal_moments_preview_data.dart';

/// Reads the Momentos feed through the authorised projection.
///
/// The scope travels as a routing hint only: the RPC re-derives actor, tenant,
/// membership, capability and audience, and excludes what the actor may not
/// see. Media arrives as opaque viewer-bound tickets, redeemed one at a time by
/// the gateway; no bucket, object key or signed URL is ever assembled here.
///
/// The contract lands with `20260908190654_superadmin_moments_feed_v2.sql`,
/// which is a local candidate awaiting replay. Until it is applied this fails
/// closed as unavailable, which is the honest state, not a silent empty feed.
final class SupabasePrincipalMomentsFeedRepository implements PrincipalMomentsFeedRepository {
  const SupabasePrincipalMomentsFeedRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PrincipalMomentPreviewItem>> listVisibleMoments(
    PrincipalMomentsFeedScope scope,
  ) async {
    try {
      final response = await _client.rpc<List<dynamic>>(
        'list_visible_moments',
        params: {
          'p_institution_id': scope.institutionId,
          'p_unit_id': scope.unitId,
          'p_group_id': scope.groupId,
          'p_limit': 20,
        },
      );
      return response
          .map((row) => _momentFromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        throw const PrincipalMomentsFeedUnauthorized();
      }
      throw const PrincipalMomentsFeedUnavailable();
    } on FormatException {
      throw const PrincipalMomentsFeedUnavailable();
    }
  }

  @override
  Future<void> removeMoment(PrincipalMomentsRemoveCommand command) async {
    // No authorised removal command exists yet. Failing closed keeps the feed
    // honest instead of hiding a moment the server still publishes.
    throw const PrincipalMomentsRemoveUnavailable();
  }

  @override
  Future<PrincipalMomentsMediaRead> resolveMedia(PrincipalMomentsMediaDescriptor media) async {
    try {
      final response = await _client.functions.invoke(
        'moments-media',
        body: {'action': 'read', 'read_ticket': media.readTicket},
      );
      if (response.status != 200 || response.data is! Map) {
        throw const PrincipalMomentsFeedUnavailable();
      }
      final json = Map<String, dynamic>.from(response.data as Map);
      final signedUrl = parsePrincipalSignedMediaUrl(json['signed_url']);
      final mimeType = json['mime_type'] as String?;
      final expiresIn = json['expires_in'] as num?;
      if (signedUrl == null ||
          mimeType == null ||
          mimeType.trim().isEmpty ||
          expiresIn == null ||
          !expiresIn.isFinite ||
          expiresIn.toInt() <= 0) {
        throw const PrincipalMomentsFeedUnavailable();
      }
      return PrincipalMomentsMediaRead(
        signedUrl: signedUrl.toString(),
        mimeType: mimeType,
        expiresIn: Duration(seconds: expiresIn.toInt()),
      );
    } on PrincipalMomentsFeedFailure {
      rethrow;
    } on Object {
      throw const PrincipalMomentsFeedUnavailable();
    }
  }
}

PrincipalMomentPreviewItem _momentFromJson(Map<String, dynamic> json) {
  final author = _requiredText(json, 'author_name');
  final context = _requiredText(json, 'context_label');
  final publishedAt = DateTime.tryParse(json['published_at']?.toString() ?? '');
  if (publishedAt == null) throw const FormatException('invalid_published_at');
  final id = (json['moment_id'] as String?)?.trim();
  if (id == null || id.isEmpty) throw const FormatException('invalid_moment_id');
  final media =
      (json['media'] as List? ?? const [])
          .map((value) {
            final item = Map<String, dynamic>.from(value as Map);
            final displayOrder = item['display_order'] as num?;
            if (displayOrder == null) throw const FormatException('invalid_media_order');
            final durationMilliseconds = item['duration_milliseconds'] as num?;
            return PrincipalMomentsMediaDescriptor(
              readTicket: _requiredText(item, 'read_ticket'),
              mimeType: _requiredText(item, 'mime_type'),
              displayOrder: displayOrder.toInt(),
              duration: durationMilliseconds == null || durationMilliseconds <= 0
                  ? null
                  : Duration(milliseconds: durationMilliseconds.toInt()),
            );
          })
          .toList(growable: false)
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  return PrincipalMomentPreviewItem(
    id: id,
    // Absent while the projection does not publish it: the affordance stays
    // hidden rather than guessing that this actor may remove anything.
    canRemove: json['can_remove'] == true,
    author: author,
    context: context,
    time: _relativeTime(publishedAt),
    caption: json['caption'] as String? ?? '',
    media: media,
    // Social counts are not part of this projection, so they stay absent
    // instead of being rendered as zero.
  );
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = (json[key] as String?)?.trim();
  if (value == null || value.isEmpty) throw FormatException('invalid_$key');
  return value;
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().toUtc().difference(value.toUtc());
  if (difference.inMinutes < 1) return 'Agora';
  if (difference.inHours < 1) return '${difference.inMinutes} min';
  if (difference.inDays < 1) return '${difference.inHours} h';
  return '${difference.inDays} d';
}
