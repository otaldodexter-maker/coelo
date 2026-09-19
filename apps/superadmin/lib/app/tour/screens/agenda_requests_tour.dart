/// Tour da tela Solicitações (`agenda-requests`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const agendaRequestsHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Solicitações e retornos',
  text:
      'Pedidos de ciência, presença e autorização enviados às famílias e o que cada uma respondeu.',
);

/// Passo 2 — directory.files.
const agendaRequestsFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text: 'Importe ou exporte as solicitações.',
);

/// Passo 3 — agenda-requests.list.
const agendaRequestsListTourStep = CoeloTourStep(
  anchorId: 'agenda-requests.list',
  title: 'A lista',
  text:
      'Solicitação, tipo e política, estado e retorno. O primeiro retorno válido encerra a pendência dos demais.',
);

/// Passo 4 — directory.pagination.
const agendaRequestsPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text: 'Avance de página e escolha quantos itens ver por vez.',
);

const agendaRequestsScreenTour = SuperadminScreenTour(
  destinationId: 'agenda-requests',
  steps: [
    agendaRequestsHeaderTourStep,
    agendaRequestsFilesTourStep,
    agendaRequestsListTourStep,
    agendaRequestsPaginationTourStep,
  ],
);
