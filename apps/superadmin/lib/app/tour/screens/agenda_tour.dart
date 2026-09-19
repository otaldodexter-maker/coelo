/// Tour da tela Agenda (`agenda`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const agendaHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Agenda institucional',
  text:
      'Calendário, eventos e respostas por contexto. Criar evento, Solicitações e Aprovações ficam no menu.',
);

/// Passo 2 — agenda.month.
const agendaMonthTourStep = CoeloTourStep(
  anchorId: 'agenda.month',
  title: 'Navegar no mês',
  text: 'Use as setas para ir ao mês anterior ou ao próximo.',
);

/// Passo 3 — agenda.search.
const agendaSearchTourStep = CoeloTourStep(
  anchorId: 'agenda.search',
  title: 'Buscar e contexto',
  text:
      'Busque eventos pelo nome e filtre pelo contexto: instituição, unidades, turmas ou atividades.',
);

/// Passo 4 — agenda.view.
const agendaViewTourStep = CoeloTourStep(
  anchorId: 'agenda.view',
  title: 'Visualização',
  text: 'Alterne entre o calendário mensal e a lista.',
);

/// Passo 5 — agenda.grid.
const agendaGridTourStep = CoeloTourStep(
  anchorId: 'agenda.grid',
  title: 'O calendário',
  text: 'Cada dia mostra seus eventos; clique num dia para abrir o detalhe.',
);

/// Passo 6 — agenda.today.
const agendaTodayTourStep = CoeloTourStep(
  anchorId: 'agenda.today',
  title: 'Hoje',
  text: 'Volta ao mês atual.',
);

const agendaScreenTour = SuperadminScreenTour(
  destinationId: 'agenda',
  steps: [
    agendaHeaderTourStep,
    agendaMonthTourStep,
    agendaSearchTourStep,
    agendaViewTourStep,
    agendaGridTourStep,
    agendaTodayTourStep,
  ],
);
