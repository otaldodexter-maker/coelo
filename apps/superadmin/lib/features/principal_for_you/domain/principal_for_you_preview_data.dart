import 'dart:collection';

import 'package:flutter/foundation.dart';

enum PrincipalForYouContentType { highlight, content, forYou }

extension PrincipalForYouContentTypeLabel on PrincipalForYouContentType {
  String get label => switch (this) {
    PrincipalForYouContentType.highlight => 'Destaque',
    PrincipalForYouContentType.content => 'Conteúdo',
    PrincipalForYouContentType.forYou => 'Para você',
  };
}

@immutable
final class PrincipalForYouHighlight {
  const PrincipalForYouHighlight({
    required this.id,
    required this.type,
    required this.priority,
    required this.eligible,
    required this.title,
    required this.body,
    required this.cta,
    required this.assetPath,
    required this.assetIndex,
  });

  final String id;
  final PrincipalForYouContentType type;
  final int priority;
  final bool eligible;
  final String title;
  final String body;
  final String cta;
  final String assetPath;
  final int assetIndex;

  PrincipalForYouHighlight copyWith({int? priority, bool? eligible}) => PrincipalForYouHighlight(
    id: id,
    type: type,
    priority: priority ?? this.priority,
    eligible: eligible ?? this.eligible,
    title: title,
    body: body,
    cta: cta,
    assetPath: assetPath,
    assetIndex: assetIndex,
  );
}

@immutable
final class PrincipalForYouShortcut {
  const PrincipalForYouShortcut(this.label, this.iconName);
  final String label;
  final String iconName;
}

@immutable
final class PrincipalForYouEditorialItem {
  const PrincipalForYouEditorialItem({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.assetPath,
    required this.assetIndex,
  });
  final String eyebrow;
  final String title;
  final String body;
  final String assetPath;
  final int assetIndex;
}

@immutable
final class PrincipalForYouDayItem {
  const PrincipalForYouDayItem(this.title, this.body, this.time, this.iconName);
  final String title;
  final String body;
  final String time;
  final String iconName;
}

@immutable
final class PrincipalForYouContext {
  const PrincipalForYouContext({
    required this.id,
    required this.label,
    required this.family,
    required this.childCount,
    this.child,
    this.institution,
    this.unit,
    this.group,
  });
  final String id;
  final String label;
  final String family;
  final int childCount;
  final String? child;
  final String? institution;
  final String? unit;
  final String? group;

  String get summary => child == null
      ? '$childCount crianças · ${institution ?? 'Contextos vinculados'}'
      : '${institution ?? ''} · ${unit ?? ''} · ${group ?? ''}';
}

@immutable
final class PrincipalForYouPreviewData {
  PrincipalForYouPreviewData({
    required List<PrincipalForYouHighlight> highlights,
    required List<PrincipalForYouShortcut> shortcuts,
    required List<PrincipalForYouEditorialItem> editorialItems,
    required List<PrincipalForYouDayItem> dayItems,
    required List<PrincipalForYouContext> contexts,
  }) : highlights = UnmodifiableListView(highlights),
       shortcuts = UnmodifiableListView(shortcuts),
       editorialItems = UnmodifiableListView(editorialItems),
       dayItems = UnmodifiableListView(dayItems),
       contexts = UnmodifiableListView(contexts);

  final List<PrincipalForYouHighlight> highlights;
  final List<PrincipalForYouShortcut> shortcuts;
  final List<PrincipalForYouEditorialItem> editorialItems;
  final List<PrincipalForYouDayItem> dayItems;
  final List<PrincipalForYouContext> contexts;

  PrincipalForYouHighlight? get primaryHighlight {
    for (final item in highlights) {
      if (item.eligible) return item;
    }
    return null;
  }

  PrincipalForYouPreviewData copyWith({List<PrincipalForYouHighlight>? highlights}) =>
      PrincipalForYouPreviewData(
        highlights: highlights ?? this.highlights,
        shortcuts: shortcuts,
        editorialItems: editorialItems,
        dayItems: dayItems,
        contexts: contexts,
      );

  static List<PrincipalForYouHighlight> orderHighlights(Iterable<PrincipalForYouHighlight> items) {
    final ordered = items.toList()..sort((a, b) => a.priority.compareTo(b.priority));
    return UnmodifiableListView(ordered);
  }

  static final demo = PrincipalForYouPreviewData(
    highlights: orderHighlights(const [
      PrincipalForYouHighlight(
        id: 'cultural-fair',
        type: PrincipalForYouContentType.highlight,
        priority: 10,
        eligible: true,
        title: 'Feira Cultural hoje!',
        body: 'A partir das 16h, no pátio da unidade. Participe com sua família!',
        cta: 'Ver detalhes',
        assetPath: 'assets/principal_happens/now-strip.png',
        assetIndex: 2,
      ),
      PrincipalForYouHighlight(
        id: 'agenda-guide',
        type: PrincipalForYouContentType.forYou,
        priority: 20,
        eligible: true,
        title: 'Organize a semana em família',
        body: 'Confira compromissos e atividades em um só lugar.',
        cta: 'Abrir Agenda',
        assetPath: 'assets/principal_happens/feed-strip.png',
        assetIndex: 1,
      ),
    ]),
    shortcuts: const [
      PrincipalForYouShortcut('Agenda', 'calendar'),
      PrincipalForYouShortcut('Atividades', 'activities'),
      PrincipalForYouShortcut('Mensagens', 'messages'),
      PrincipalForYouShortcut('Cardápio', 'meals'),
      PrincipalForYouShortcut('Desempenho', 'performance'),
      PrincipalForYouShortcut('Saúde', 'health'),
    ],
    editorialItems: const [
      PrincipalForYouEditorialItem(
        eyebrow: 'Para você',
        title: 'Como responder à agenda',
        body: 'Veja o passo a passo rápido e fácil.',
        assetPath: 'assets/principal_profile/highlights-strip.png',
        assetIndex: 0,
      ),
      PrincipalForYouEditorialItem(
        eyebrow: 'Você sabia?',
        title: 'Troque o contexto da criança com um clique.',
        body: 'Veja como é simples.',
        assetPath: 'assets/principal_happens/now-strip.png',
        assetIndex: 0,
      ),
      PrincipalForYouEditorialItem(
        eyebrow: 'Novidade no app',
        title: 'Novos filtros na Agenda',
        body: 'Mais praticidade para organizar o dia.',
        assetPath: 'assets/principal_profile/highlights-strip.png',
        assetIndex: 3,
      ),
      PrincipalForYouEditorialItem(
        eyebrow: 'Conteúdo útil',
        title: 'Dicas para uma rotina escolar mais leve',
        body: 'Pequenas ações que fazem diferença.',
        assetPath: 'assets/principal_happens/feed-strip.png',
        assetIndex: 1,
      ),
    ],
    dayItems: const [
      PrincipalForYouDayItem('Aniversariante do dia', 'Lucas faz 8 anos!', '08:30', 'gift'),
      PrincipalForYouDayItem(
        'Reunião de responsáveis',
        'Amanhã, às 18h na unidade.',
        '07:45',
        'bell',
      ),
      PrincipalForYouDayItem(
        'Entrega de trabalhos',
        'Ciências — maquete do sistema solar',
        'Ontem',
        'folder',
      ),
    ],
    contexts: const [
      PrincipalForYouContext(
        id: 'overview',
        label: 'Visão geral do responsável',
        family: 'Família Silva',
        childCount: 2,
        institution: 'Colégio Coelo',
        unit: 'Itaim',
      ),
      PrincipalForYouContext(
        id: 'beatriz',
        label: 'Beatriz Silva',
        family: 'Família Silva',
        childCount: 2,
        child: 'Beatriz Silva',
        institution: 'Colégio Coelo',
        unit: 'Itaim',
        group: '3º ano A',
      ),
      PrincipalForYouContext(
        id: 'lucas',
        label: 'Lucas Silva',
        family: 'Família Silva',
        childCount: 2,
        child: 'Lucas Silva',
        institution: 'Colégio Coelo',
        unit: 'Itaim',
        group: '2º ano A',
      ),
    ],
  );
}
