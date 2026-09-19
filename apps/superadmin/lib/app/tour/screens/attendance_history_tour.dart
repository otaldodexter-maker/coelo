/// Tour da tela Histórico (`attendance-history`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const attendanceHistoryHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Histórico de chamadas',
  text:
      'Chamadas lançadas no seu escopo; abra uma para ver o detalhe.',
);

/// Passo 2 — directory.leading.
const attendanceHistoryLeadingTourStep = CoeloTourStep(
  anchorId: 'directory.leading',
  title: 'Chamadas ou rotina',
  text:
      '"Chamadas" lista as presenças; "Lançamentos de rotina" lista o diário do dia enviado às famílias.',
);

/// Passo 3 — directory.filters.
const attendanceHistoryFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Filtros',
  text:
      'Instituição, Unidade, Turma, Atividade e Situação.',
);

/// Passo 4 — directory.body.
const attendanceHistoryBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text:
      'Cada linha tem data, contexto e situação. "Abrir chamada" mostra participante a participante.',
);

/// Passo 5 — directory.pagination.
const attendanceHistoryPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text:
      'Avance de página e escolha quantos itens ver por vez.',
);

const attendanceHistoryScreenTour = SuperadminScreenTour(
  destinationId: 'attendance-history',
  steps: [
    attendanceHistoryHeaderTourStep,
    attendanceHistoryLeadingTourStep,
    attendanceHistoryFiltersTourStep,
    attendanceHistoryBodyTourStep,
    attendanceHistoryPaginationTourStep,
  ],
);
