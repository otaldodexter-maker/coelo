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

@immutable
final class PrincipalMomentPreviewItem {
  const PrincipalMomentPreviewItem({
    required this.author,
    required this.context,
    required this.time,
    required this.caption,
    this.likes,
    this.comments,
    this.shares,
    this.saves,
    this.imageIndex = 0,
    this.id,
    this.media = const [],
  });

  final String author;
  final String context;
  final String time;
  final String caption;

  /// Social counts are absent unless the authorised projection returned them.
  /// The client never invents a zero: a count it was not given is not shown.
  final int? likes;
  final int? comments;
  final int? shares;
  final int? saves;

  /// Fixture-only illustration index, ignored once real media arrives.
  final int imageIndex;

  /// Server identifier. It addresses, it never authorises.
  final String? id;

  /// Ordered, opaque descriptors. The URL only ever comes from the gateway.
  final List<PrincipalMomentsMediaDescriptor> media;
}

/// Opaque, viewer-bound reference to one stored asset. It carries no bucket and
/// no object key, and expires on its own.
final class PrincipalMomentsMediaDescriptor {
  const PrincipalMomentsMediaDescriptor({
    required this.readTicket,
    required this.mimeType,
    required this.displayOrder,
    this.duration,
  });

  final String readTicket;
  final String mimeType;
  final int displayOrder;
  final Duration? duration;

  bool get isVideo => mimeType.startsWith('video/');
}

@immutable
final class PrincipalMomentTrendingItem {
  const PrincipalMomentTrendingItem(this.title, this.context, this.duration, this.imageIndex);

  final String title;
  final String context;
  final String duration;
  final int imageIndex;
}
