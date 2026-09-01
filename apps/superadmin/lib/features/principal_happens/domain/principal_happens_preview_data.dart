import 'package:flutter/foundation.dart';

@immutable
final class PrincipalHappensPreviewData {
  const PrincipalHappensPreviewData({
    required this.nowItems,
    required this.posts,
    required this.events,
    required this.notices,
    required this.birthdays,
  });

  final List<PrincipalNowPreviewItem> nowItems;
  final List<PrincipalPostPreviewItem> posts;
  final List<PrincipalEventPreviewItem> events;
  final List<PrincipalNoticePreviewItem> notices;
  final List<PrincipalBirthdayPreviewItem> birthdays;

  /// Production-safe baseline while each section loads from its own backend.
  /// Real routes must never inherit the visual preview fixtures.
  static const empty = PrincipalHappensPreviewData(
    nowItems: [],
    posts: [],
    events: [],
    notices: [],
    birthdays: [],
  );

  static const demo = PrincipalHappensPreviewData(
    nowItems: [
      PrincipalNowPreviewItem('Beatriz L.', '7º min', 0, .74),
      PrincipalNowPreviewItem('3º ano A', '15 min', 1, .64),
      PrincipalNowPreviewItem('Arte e Cor', '1 h', 2, .48),
      PrincipalNowPreviewItem('Festival de Leitura', '2 h', 3, .82),
      PrincipalNowPreviewItem('Música', '3 h', 4, .36),
    ],
    posts: [
      PrincipalPostPreviewItem(
        author: 'Prof. Rafael Souza',
        context: 'História · 6º ano A',
        time: '2 h',
        initials: 'RS',
        body:
            'Aula prática sobre civilizações antigas!\nExplorando o Egito Antigo de forma colaborativa.',
        mediaIndices: [0, 1, 2],
        likes: 45,
        comments: 8,
        shares: 3,
        likedBy: 'Curtido por Juliana M. e outras 44 pessoas',
      ),
      PrincipalPostPreviewItem(
        author: 'Coordenação Pedagógica',
        context: 'Comunicado · Escola',
        time: '4 h',
        initials: 'CP',
        body:
            'Lembramos que na próxima sexta-feira teremos nossa Reunião de Pais e '
            'Responsáveis às 18h30, no auditório da escola.\n\nContamos com a presença de todos!',
        mediaIndices: [],
        likes: 28,
        comments: 4,
        shares: 0,
        likedBy: 'Famílias acompanhando este comunicado',
      ),
    ],
    events: [
      PrincipalEventPreviewItem('20', 'MAI', 'Mostra Cultural', '08h00'),
      PrincipalEventPreviewItem('24', 'MAI', 'Reunião de Pais', '18h30'),
      PrincipalEventPreviewItem('28', 'MAI', 'Feira de Ciências', '13h30'),
    ],
    notices: [
      PrincipalNoticePreviewItem(
        'Comunicado: Horário especial no dia 23/05',
        'Saída dos alunos às 12h. Atividades no período da manhã.',
        'Hoje',
      ),
      PrincipalNoticePreviewItem(
        'Campanha do Agasalho',
        'Doe amor, doe calor. Até 30 de maio.',
        '2 dias',
      ),
    ],
    birthdays: [
      PrincipalBirthdayPreviewItem('Helena S.', '3º ano A', 'Hoje', 'HS'),
      PrincipalBirthdayPreviewItem('Miguel P.', '5º ano B', 'Amanhã', 'MP'),
      PrincipalBirthdayPreviewItem('Laura M.', '7º ano A', '24/05', 'LM'),
    ],
  );
}

@immutable
final class PrincipalNowPreviewItem {
  const PrincipalNowPreviewItem(this.title, this.time, this.imageIndex, this.progress);
  final String title;
  final String time;
  final int imageIndex;
  final double progress;
}

@immutable
final class PrincipalPostPreviewItem {
  const PrincipalPostPreviewItem({
    required this.author,
    required this.context,
    required this.time,
    required this.initials,
    required this.body,
    this.media = const [],
    this.mediaIndices = const [],
    this.likes,
    this.comments,
    this.shares,
    this.likedBy,
  });
  final String author;
  final String context;
  final String time;
  final String initials;
  final String body;
  final List<PrincipalHappensMediaDescriptor> media;
  final List<int> mediaIndices;
  final int? likes;
  final int? comments;
  final int? shares;
  final String? likedBy;
}

@immutable
final class PrincipalHappensMediaDescriptor {
  const PrincipalHappensMediaDescriptor({
    required this.readTicket,
    required this.mimeType,
    required this.displayOrder,
  });

  final String readTicket;
  final String mimeType;
  final int displayOrder;

  bool get isVideo => mimeType.startsWith('video/');
}

@immutable
final class PrincipalEventPreviewItem {
  const PrincipalEventPreviewItem(this.day, this.month, this.title, this.time);
  final String day;
  final String month;
  final String title;
  final String time;
}

@immutable
final class PrincipalNoticePreviewItem {
  const PrincipalNoticePreviewItem(this.title, this.body, this.time);
  final String title;
  final String body;
  final String time;
}

@immutable
final class PrincipalBirthdayPreviewItem {
  const PrincipalBirthdayPreviewItem(this.name, this.context, this.date, this.initials);
  final String name;
  final String context;
  final String date;
  final String initials;
}
