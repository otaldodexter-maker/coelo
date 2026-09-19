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
      'Calendário, eventos e respostas por contexto.',
);

/// Passo 2 — agenda.areas.
const agendaAreasTourStep = CoeloTourStep(
  anchorId: 'agenda.areas',
  title: 'Áreas da Agenda',
  text:
      'Calendário, Eventos, Solicitações, Aprovações e Permissões. Cada uma é uma tela.',
);

/// Passo 3 — agenda.month.
const agendaMonthTourStep = CoeloTourStep(
  anchorId: 'agenda.month',
  title: 'Navegar no mês',
  text:
      'Mês anterior, próximo mês e "Hoje".',
);

/// Passo 4 — agenda.search.
const agendaSearchTourStep = CoeloTourStep(
  anchorId: 'agenda.search',
  title: 'Buscar e contexto',
  text:
      'Busque eventos pelo nome e filtre pelo contexto.',
);

/// Passo 5 — agenda.view.
const agendaViewTourStep = CoeloTourStep(
  anchorId: 'agenda.view',
  title: 'Visualização',
  text:
      'Alterne entre o calendário mensal e a lista.',
);

/// Passo 6 — agenda.grid.
const agendaGridTourStep = CoeloTourStep(
  anchorId: 'agenda.grid',
  title: 'O calendário',
  text:
      'Cada dia mostra seus eventos; clique num dia para expandir o detalhe.',
);

/// Passo 7 — agenda.create.
const agendaCreateTourStep = CoeloTourStep(
  anchorId: 'agenda.create',
  title: 'Criar item',
  text:
      'Abre o formulário de um novo evento.',
);

const agendaScreenTour = SuperadminScreenTour(
  destinationId: 'agenda',
  steps: [
    agendaHeaderTourStep,
    agendaAreasTourStep,
    agendaMonthTourStep,
    agendaSearchTourStep,
    agendaViewTourStep,
    agendaGridTourStep,
    agendaCreateTourStep,
  ],
);
