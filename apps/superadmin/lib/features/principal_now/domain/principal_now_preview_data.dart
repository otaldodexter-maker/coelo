import 'package:flutter/foundation.dart';

@immutable
final class PrincipalNowPreviewData {
  const PrincipalNowPreviewData({required this.stories});

  final List<PrincipalNowPreviewStory> stories;

  static const demo = PrincipalNowPreviewData(
    stories: [
      PrincipalNowPreviewStory(
        author: 'Riverside School',
        timeLabel: '2 h',
        caption: 'Explorando reações na aula de ciências',
        assetPath: 'assets/principal_now/story-strip.png',
        imageIndex: 0,
      ),
      PrincipalNowPreviewStory(
        author: 'Riverside School',
        timeLabel: '2 h',
        caption: 'Conversas que aproximam escola e família',
        assetPath: 'assets/principal_now/story-strip.png',
        imageIndex: 1,
      ),
      PrincipalNowPreviewStory(
        author: 'Biblioteca Riverside',
        timeLabel: '3 h',
        caption: 'Leitura compartilhada, novas descobertas',
        assetPath: 'assets/principal_now/story-strip.png',
        imageIndex: 2,
      ),
      PrincipalNowPreviewStory(
        author: 'Riverside School',
        timeLabel: '3 h',
        caption: 'Energia de dia de jogo',
        assetPath: 'assets/principal_now/story-strip.png',
        imageIndex: 3,
      ),
      PrincipalNowPreviewStory(
        author: 'Comunidade Riverside',
        timeLabel: '4 h',
        caption: 'Encontro de famílias nesta sexta',
        assetPath: 'assets/principal_now/story-strip.png',
        imageIndex: 4,
      ),
    ],
  );
}

@immutable
final class PrincipalNowPreviewStory {
  const PrincipalNowPreviewStory({
    required this.author,
    required this.timeLabel,
    required this.caption,
    required this.assetPath,
    required this.imageIndex,
    this.duration = const Duration(seconds: 5),
  });

  final String author;
  final String timeLabel;
  final String caption;
  final String assetPath;
  final int imageIndex;
  final Duration duration;
}
