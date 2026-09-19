/// Tour da tela Aprovações (`agenda-approvals`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const agendaApprovalsHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Aprovações de publicação',
  text:
      'Eventos aguardando decisão antes de aparecer para as famílias.',
);

/// Passo 2 — agenda-approvals.table.
const agendaApprovalsTableTourStep = CoeloTourStep(
  anchorId: 'agenda-approvals.table',
  title: 'A lista',
  text:
      'Evento, solicitação, estado e histórico. "Decidir" abre a decisão.',
);

/// Passo 3 — agenda-approvals.decide.
const agendaApprovalsDecideTourStep = CoeloTourStep(
  anchorId: 'agenda-approvals.decide',
  title: 'Decidir',
  text:
      'Aprove ou recuse com justificativa; tudo fica registrado no histórico da Agenda.',
);

const agendaApprovalsScreenTour = SuperadminScreenTour(
  destinationId: 'agenda-approvals',
  steps: [
    agendaApprovalsHeaderTourStep,
    agendaApprovalsTableTourStep,
    agendaApprovalsDecideTourStep,
  ],
);
