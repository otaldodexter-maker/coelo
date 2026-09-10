import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/principal_happens_feed_repository.dart';
import '../domain/principal_happens_preview_data.dart';

final class SupabasePrincipalHappensFeedRepository
    implements PrincipalHappensFeedRepository, PrincipalHappensPostWithdrawal {
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
  Future<void> withdrawPost({
    required String postId,
    required int expectedVersion,
    String? reason,
  }) async {
    final normalizedReason = reason?.trim();
    try {
      await _client.rpc<dynamic>(
        'withdraw_happens_post',
        params: {
          'p_request_id': _requestId(),
          'p_post_id': postId,
          'p_expected_version': expectedVersion,
          'p_reason': normalizedReason == null || normalizedReason.isEmpty
              ? null
              : normalizedReason,
        },
      );
    } on PostgrestException catch (error) {
      throw _withdrawalFailure(error);
    } on Object {
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
      if (signedUrl == null ||
          mimeType == null ||
          expiresIn == null ||
          !expiresIn.isFinite ||
          expiresIn.toInt() <= 0) {
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

/// A negativa do servidor nunca vira sucesso e nunca vaza detalhe interno.
Exception _withdrawalFailure(PostgrestException error) {
  if (error.code == '42501' || error.code == 'PGRST301') {
    return const PrincipalHappensFeedUnauthorized();
  }
  if (error.code == '40001' || error.message.contains('expected_version_conflict')) {
    return const PrincipalHappensWithdrawalConflict();
  }
  return const PrincipalHappensFeedUnavailable();
}

String _requestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
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
  final postId = (json['post_id'] as String?)?.trim();
  final managementVersion = json['management_version'] as num?;
  return PrincipalPostPreviewItem(
    author: author,
    context: context,
    time: _relativeTime(publishedAt),
    initials: initials,
    body: json['caption'] as String? ?? '',
    media: media,
    postId: postId == null || postId.isEmpty ? null : postId,
    managementVersion: managementVersion?.toInt(),
    canWithdraw: json['can_withdraw'] == true,
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
