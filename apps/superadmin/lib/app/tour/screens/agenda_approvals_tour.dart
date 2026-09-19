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
  text: 'Eventos aguardando decisão antes de aparecer para as famílias.',
);

/// Passo 2 — directory.files.
const agendaApprovalsFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text: 'Importe ou exporte as aprovações.',
);

/// Passo 3 — agenda-approvals.table.
const agendaApprovalsTableTourStep = CoeloTourStep(
  anchorId: 'agenda-approvals.table',
  title: 'A lista',
  text:
      'Evento, solicitação, estado e histórico. "Decidir" abre a decisão: aprove ou recuse com justificativa, registrada no histórico.',
);

/// Passo 4 — directory.pagination.
const agendaApprovalsPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text: 'Avance de página e escolha quantos itens ver por vez.',
);

const agendaApprovalsScreenTour = SuperadminScreenTour(
  destinationId: 'agenda-approvals',
  steps: [
    agendaApprovalsHeaderTourStep,
    agendaApprovalsFilesTourStep,
    agendaApprovalsTableTourStep,
    agendaApprovalsPaginationTourStep,
  ],
);
