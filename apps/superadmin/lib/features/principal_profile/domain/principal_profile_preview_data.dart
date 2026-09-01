import 'package:flutter/material.dart';

@immutable
final class PrincipalProfilePreviewData {
  const PrincipalProfilePreviewData({
    required this.name,
    required this.typeLabel,
    required this.bio,
    required this.metrics,
    required this.highlights,
    required this.links,
    required this.nextEvent,
  });

  final String name;
  final String typeLabel;
  final String bio;
  final List<PrincipalProfileMetric> metrics;
  final List<PrincipalProfileHighlight> highlights;
  final List<String> links;
  final PrincipalProfileEvent nextEvent;

  static const horizon = PrincipalProfilePreviewData(
    name: 'Colégio Horizonte',
    typeLabel: 'Instituição de Ensino',
    bio:
        'Educação que inspira, acolhe e transforma. Formamos cidadãos éticos, '
        'criativos e preparados para o futuro.',
    metrics: [
      PrincipalProfileMetric(Icons.article_outlined, '128', 'Publicações'),
      PrincipalProfileMetric(Icons.play_circle_outline_rounded, '42', 'Momentos'),
      PrincipalProfileMetric(Icons.campaign_outlined, '12', 'Circulares'),
    ],
    highlights: [
      PrincipalProfileHighlight(Icons.school_outlined, 'Aprendizagem', -1),
      PrincipalProfileHighlight(Icons.sports_basketball_outlined, 'Esportes', -.5),
      PrincipalProfileHighlight(Icons.palette_outlined, 'Artes', 0),
      PrincipalProfileHighlight(Icons.smart_toy_outlined, 'Inovação', .5),
      PrincipalProfileHighlight(Icons.diversity_3_outlined, 'Comunidade', 1),
    ],
    links: ['AM', 'BL', 'CS', 'DP', 'ER'],
    nextEvent: PrincipalProfileEvent(
      day: '17',
      month: 'MAI',
      title: 'Feira Cultural 2025',
      context: 'Unidade Centro · 09:00–14:00',
    ),
  );
}

@immutable
final class PrincipalProfileMetric {
  const PrincipalProfileMetric(this.icon, this.value, this.label);
  final IconData icon;
  final String value;
  final String label;
}

@immutable
final class PrincipalProfileHighlight {
  const PrincipalProfileHighlight(this.icon, this.label, this.alignmentX);
  final IconData icon;
  final String label;
  final double alignmentX;
}

@immutable
final class PrincipalProfileEvent {
  const PrincipalProfileEvent({
    required this.day,
    required this.month,
    required this.title,
    required this.context,
  });
  final String day;
  final String month;
  final String title;
  final String context;
}
