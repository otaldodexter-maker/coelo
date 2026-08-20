import 'package:characters/characters.dart';
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
    }
  }
}

PrincipalPostPreviewItem _postFromJson(Map<String, dynamic> json) {
  final publishedAt = DateTime.tryParse(
    (json['published_at'] ?? json['publish_at'])?.toString() ?? '',
  );
  final author = (json['author_name'] as String?)?.trim();
  final resolvedAuthor = author == null || author.isEmpty ? 'Comunidade Coelo' : author;
  final initials = (json['author_initials'] as String?)?.trim();
  return PrincipalPostPreviewItem(
    author: resolvedAuthor,
    context: (json['context_label'] as String?)?.trim().isNotEmpty == true
        ? (json['context_label'] as String).trim()
        : 'Acontece · Comunidade escolar',
    time: _relativeTime(publishedAt),
    initials: initials == null || initials.isEmpty ? _initials(resolvedAuthor) : initials,
    body: json['caption'] as String? ?? '',
    mediaIndices: const [],
    likes: (json['likes_count'] as num?)?.toInt() ?? 0,
    comments: (json['comments_count'] as num?)?.toInt() ?? 0,
    shares: (json['shares_count'] as num?)?.toInt() ?? 0,
    likedBy: json['liked_by_label'] as String? ?? 'Publicado para a comunidade escolar',
  );
}

String _initials(String value) {
  final words = value.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).take(2);
  return words.map((word) => word.characters.first.toUpperCase()).join();
}

String _relativeTime(DateTime? value) {
  if (value == null) return 'Agora';
  final difference = DateTime.now().toUtc().difference(value.toUtc());
  if (difference.inMinutes < 1) return 'Agora';
  if (difference.inHours < 1) return '${difference.inMinutes} min';
  if (difference.inDays < 1) return '${difference.inHours} h';
  return '${difference.inDays} d';
}
