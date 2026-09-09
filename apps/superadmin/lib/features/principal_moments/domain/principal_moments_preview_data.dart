import 'package:flutter/foundation.dart';

@immutable
final class PrincipalMomentsPreviewData {
  const PrincipalMomentsPreviewData({required this.moments, required this.trending});

  final List<PrincipalMomentPreviewItem> moments;
  final List<PrincipalMomentTrendingItem> trending;

  static const demo = PrincipalMomentsPreviewData(
    moments: [
      PrincipalMomentPreviewItem(
        author: 'Colégio Coelo',
        context: 'Fundamental I',
        time: 'Há 2h',
        caption: 'Música que inspira, conexão que transforma.',
        likes: 532,
        comments: 28,
        shares: 18,
        saves: 92,
        imageIndex: 0,
      ),
      PrincipalMomentPreviewItem(
        author: 'Colégio Coelo',
        context: 'Fundamental II',
        time: 'Há 2h',
        caption: 'Ciência na prática é descoberta que fica para a vida toda.',
        likes: 532,
        comments: 28,
        shares: 18,
        saves: 92,
        imageIndex: 1,
      ),
      PrincipalMomentPreviewItem(
        author: 'Colégio Coelo',
        context: 'Esportes',
        time: 'Há 2h',
        caption: 'Superar limites juntos faz parte da nossa essência.',
        likes: 532,
        comments: 28,
        shares: 18,
        saves: 92,
        imageIndex: 2,
      ),
      PrincipalMomentPreviewItem(
        author: 'Colégio Coelo',
        context: 'Ensino Médio',
        time: 'Há 1d',
        caption: 'Nosso palco também é lugar de aprender e pertencer.',
        likes: 418,
        comments: 24,
        shares: 15,
        saves: 76,
        imageIndex: 3,
      ),
      PrincipalMomentPreviewItem(
        author: 'Colégio Coelo',
        context: 'Comunidade',
        time: 'Há 1d',
        caption: 'Família e escola juntas em cada memória que importa.',
        likes: 601,
        comments: 34,
        shares: 22,
        saves: 104,
        imageIndex: 4,
      ),
    ],
    trending: [
      PrincipalMomentTrendingItem('Apresentação de Robótica', 'Fundamental II', '0:32', 1),
      PrincipalMomentTrendingItem('Feira de Ciências', 'Fundamental I', '0:27', 1),
      PrincipalMomentTrendingItem('Mostra Cultural 2024', 'Ensino Médio', '0:29', 3),
      PrincipalMomentTrendingItem('Dia da Família Coelo', 'Infantil', '0:31', 4),
    ],
  );
}

/// A single authorized media rendition of a moment.
///
/// [signedUrl] is a short lived, server-issued read URL. The client never sees
/// the bucket, the object key or any credential.
@immutable
final class PrincipalMomentMedia {
  const PrincipalMomentMedia({
    required this.signedUrl,
    required this.mimeType,
    required this.displayOrder,
  });

  final String signedUrl;
  final String mimeType;
  final int displayOrder;
}

@immutable
final class PrincipalMomentPreviewItem {
  const PrincipalMomentPreviewItem({
    required this.author,
    required this.context,
    required this.time,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.saves,
    required this.imageIndex,
    this.publicationId,
    this.canWithdraw = false,
    this.media = const [],
    this.initials,
  });

  final String author;
  final String context;
  final String time;
  final String caption;
  final int likes;
  final int comments;
  final int shares;
  final int saves;
  final int imageIndex;

  /// Server-issued publication identifier. Null for local preview fixtures,
  /// which are never withdrawable.
  final String? publicationId;

  /// Server-computed authorship affordance. The client only renders it; the
  /// backend re-authorizes every withdrawal request.
  final bool canWithdraw;

  final List<PrincipalMomentMedia> media;

  /// Server-provided author initials. Falls back to a locally derived value.
  final String? initials;

  String get resolvedInitials {
    final provided = initials?.trim();
    if (provided != null && provided.isNotEmpty) return provided.toUpperCase();
    final words = author.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'CO';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words.first.substring(0, 1) + words.last.substring(0, 1)).toUpperCase();
  }
}

@immutable
final class PrincipalMomentTrendingItem {
  const PrincipalMomentTrendingItem(this.title, this.context, this.duration, this.imageIndex);

  final String title;
  final String context;
  final String duration;
  final int imageIndex;
}
