/// Tour da tela Assiduidade (`attendance`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const attendanceHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Assiduidade',
  text:
      'Visão consolidada de presença e chamadas no seu escopo.',
);

/// Passo 2 — attendance.actions.
const attendanceActionsTourStep = CoeloTourStep(
  anchorId: 'attendance.actions',
  title: 'Nova chamada e exportar',
  text:
      '"Nova chamada" abre o lançamento de hoje; Exportar gera CSV ou XLSX do que está na tela.',
);

/// Passo 3 — attendance.filters.
const attendanceFiltersTourStep = CoeloTourStep(
  anchorId: 'attendance.filters',
  title: 'Granularidade e período',
  text:
      'Escolha o contexto (instituição, unidade, turma), o período e a granularidade dos indicadores.',
);

/// Passo 4 — attendance.kpis.
const attendanceKpisTourStep = CoeloTourStep(
  anchorId: 'attendance.kpis',
  title: 'Indicadores',
  text:
      'Presença geral, chamadas pendentes, faltas no período e itens em revisão.',
);

/// Passo 5 — attendance.attention.
const attendanceAttentionTourStep = CoeloTourStep(
  anchorId: 'attendance.attention',
  title: 'Atenção necessária',
  text:
      'Pendências que precisam de ação: chamadas atrasadas e correções aguardando.',
);

/// Passo 6 — attendance.ranking.
const attendanceRankingTourStep = CoeloTourStep(
  anchorId: 'attendance.ranking',
  title: 'Desempenho por contexto',
  text:
      'Ranking de presença por unidade ou turma. "Ver todos" abre a lista completa.',
);

/// Passo 7 — attendance.chart.
const attendanceChartTourStep = CoeloTourStep(
  anchorId: 'attendance.chart',
  title: 'Presença no período',
  text:
      'Gráfico do período atual comparado ao anterior.',
);

/// Passo 8 — attendance.recent.
const attendanceRecentTourStep = CoeloTourStep(
  anchorId: 'attendance.recent',
  title: 'Últimas chamadas',
  text:
      'Busque, filtre por status, ordene e abra qualquer chamada recente.',
);

const attendanceScreenTour = SuperadminScreenTour(
  destinationId: 'attendance',
  steps: [
    attendanceHeaderTourStep,
    attendanceActionsTourStep,
    attendanceFiltersTourStep,
    attendanceKpisTourStep,
    attendanceAttentionTourStep,
    attendanceRankingTourStep,
    attendanceChartTourStep,
    attendanceRecentTourStep,
  ],
);
