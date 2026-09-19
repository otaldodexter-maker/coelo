/// Tour da tela Fechamento de avaliações (`assessment-closing`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const assessmentClosingHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Fechamento de avaliações',
  text: 'Revise pendências e publique resultados autorizados.',
);

/// Passo 2 — page.actions.
const assessmentClosingActionsTourStep = CoeloTourStep(
  anchorId: 'page.actions',
  title: 'Importar e exportar',
  text: 'Exporte os fechamentos em CSV ou XLSX.',
);

/// Passo 3 — directory.search.
const assessmentClosingSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar turma ou Atividade',
  text: 'Encontre o envio pelo nome da turma ou da Atividade.',
);

/// Passo 4 — directory.body.
const assessmentClosingBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'Envios pendentes',
  text:
      'Cada linha é um envio: turma, período e quantas pendências restam. Clique para abrir e completar o que falta.',
);

/// Passo 5 — directory.pagination.
const assessmentClosingPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text: 'Avance de página e escolha quantos itens ver por vez.',
);

const assessmentClosingScreenTour = SuperadminScreenTour(
  destinationId: 'assessment-closing',
  steps: [
    assessmentClosingHeaderTourStep,
    assessmentClosingActionsTourStep,
    assessmentClosingSearchTourStep,
    assessmentClosingBodyTourStep,
    assessmentClosingPaginationTourStep,
  ],
);
