import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/principal_moments_feed_repository.dart';
import '../domain/principal_moments_preview_data.dart';

/// Productive Momentos feed backed by `public.list_visible_moments`.
///
/// Authorization is entirely server-side. The scope identifiers below are
/// routing hints, never permission. Media is resolved through the private
/// `moments-media` Edge Function (`action: read`), which re-authorizes the
/// viewer and returns a short lived signed URL; the bucket, the object key and
/// every credential stay on the server.
///
/// The repository fails closed: a denial surfaces as
/// [PrincipalMomentsFeedUnauthorized], any other problem as
/// [PrincipalMomentsFeedUnavailable]. It never falls back to demo data.
final class SupabasePrincipalMomentsFeedRepository
    implements PrincipalMomentsFeedRepository, PrincipalMomentsWithdrawalRepository {
  const SupabasePrincipalMomentsFeedRepository(this._client, {this.pageSize = 20});

  final SupabaseClient _client;
  final int pageSize;

  @override
  Future<List<PrincipalMomentPreviewItem>> listVisibleMoments(
    PrincipalMomentsFeedScope scope,
  ) async {
    final List<dynamic> rows;
    try {
      rows = await _client.rpc<List<dynamic>>(
        'list_visible_moments',
        params: {
          'p_institution_id': scope.institutionId,
          'p_unit_id': scope.unitId,
          'p_group_id': scope.groupId,
          'p_limit': pageSize,
          'p_cursor': null,
        },
      );
    } on PostgrestException catch (error) {
      throw _mapFeedError(error);
    } on Object {
      throw const PrincipalMomentsFeedUnavailable();
    }

    final moments = <PrincipalMomentPreviewItem>[];
    for (var index = 0; index < rows.length; index++) {
      final row = Map<String, dynamic>.from(rows[index] as Map);
      moments.add(await _momentFromRow(row, index));
    }
    return List.unmodifiable(moments);
  }

  @override
  Future<void> withdrawMoment(String publicationId, {String? reason}) async {
    try {
      await _client.rpc<Object?>(
        'withdraw_moment',
        params: {
          'p_request_id': _uuid(),
          'p_publication_id': publicationId,
          'p_expected_version': null,
          'p_reason': reason,
        },
      );
    } on PostgrestException catch (error) {
      throw _mapWithdrawalError(error);
    } on Object {
      throw const PrincipalMomentsWithdrawalUnavailable();
    }
  }

  Future<PrincipalMomentPreviewItem> _momentFromRow(
    Map<String, dynamic> row,
    int fallbackImageIndex,
  ) async {
    final publicationId = _requiredText(row, 'publication_id');
    final author = _requiredText(row, 'author_name');
    final initials = _requiredText(row, 'author_initials');
    final context = _requiredText(row, 'context_label');
    final publishedAt = DateTime.tryParse(row['published_at']?.toString() ?? '');
    if (publishedAt == null) throw const PrincipalMomentsFeedUnavailable();

    final descriptors =
        (row['media'] as List? ?? const [])
            .map((value) => _MediaDescriptor.fromJson(Map<String, dynamic>.from(value as Map)))
            .toList(growable: false)
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final media = <PrincipalMomentMedia>[];
    for (final descriptor in descriptors) {
      media.add(await _resolveMedia(descriptor));
    }

    return PrincipalMomentPreviewItem(
      author: author,
      context: context,
      time: _relativeTime(publishedAt),
      caption: row['caption'] as String? ?? '',
      likes: 0,
      comments: 0,
      shares: 0,
      saves: 0,
      imageIndex: fallbackImageIndex,
      publicationId: publicationId,
      canWithdraw: row['can_withdraw'] == true,
      media: List.unmodifiable(media),
      initials: initials,
    );
  }

  Future<PrincipalMomentMedia> _resolveMedia(_MediaDescriptor descriptor) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'moments-media',
        body: {'action': 'read', 'asset_id': descriptor.assetId},
      );
    } on FunctionException catch (error) {
      throw error.status == 401 || error.status == 403
          ? const PrincipalMomentsFeedUnauthorized()
          : const PrincipalMomentsFeedUnavailable();
    } on Object {
      throw const PrincipalMomentsFeedUnavailable();
    }
    if (response.status == 401 || response.status == 403) {
      throw const PrincipalMomentsFeedUnauthorized();
    }
    if (response.status < 200 || response.status >= 300 || response.data is! Map) {
      throw const PrincipalMomentsFeedUnavailable();
    }
    final json = Map<String, dynamic>.from(response.data as Map);
    final signedUrl = (json['signed_url'] as String?)?.trim();
    final mimeType = (json['mime_type'] as String?)?.trim();
    if (signedUrl == null || signedUrl.isEmpty || mimeType == null || mimeType.isEmpty) {
      throw const PrincipalMomentsFeedUnavailable();
    }
    return PrincipalMomentMedia(
      signedUrl: signedUrl,
      mimeType: mimeType,
      displayOrder: descriptor.displayOrder,
    );
  }
}

final class _MediaDescriptor {
  const _MediaDescriptor({required this.assetId, required this.displayOrder});

  factory _MediaDescriptor.fromJson(Map<String, dynamic> json) {
    final assetId = (json['asset_id'] as String?)?.trim();
    final displayOrder = json['display_order'] as num?;
    if (assetId == null || assetId.isEmpty || displayOrder == null) {
      throw const PrincipalMomentsFeedUnavailable();
    }
    return _MediaDescriptor(assetId: assetId, displayOrder: displayOrder.toInt());
  }

  final String assetId;
  final int displayOrder;
}

PrincipalMomentsFeedFailure _mapFeedError(PostgrestException error) =>
    _denied(error) ? const PrincipalMomentsFeedUnauthorized() : const PrincipalMomentsFeedUnavailable();

PrincipalMomentsWithdrawalFailure _mapWithdrawalError(PostgrestException error) => _denied(error)
    ? const PrincipalMomentsWithdrawalDenied()
    : const PrincipalMomentsWithdrawalUnavailable();

bool _denied(PostgrestException error) =>
    error.code == '42501' ||
    error.code == 'PGRST301' ||
    error.message.contains('permission_denied') ||
    error.message.contains('not_authorized') ||
    error.message.contains('authentication_required');

String _requiredText(Map<String, dynamic> json, String key) {
  final value = (json[key] as String?)?.trim();
  if (value == null || value.isEmpty) throw const PrincipalMomentsFeedUnavailable();
  return value;
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().toUtc().difference(value.toUtc());
  if (difference.inMinutes < 1) return 'Agora';
  if (difference.inHours < 1) return 'Há ${difference.inMinutes} min';
  if (difference.inDays < 1) return 'Há ${difference.inHours}h';
  return 'Há ${difference.inDays}d';
}

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}'
      '-${hex.substring(16, 20)}-${hex.substring(20)}';
}
