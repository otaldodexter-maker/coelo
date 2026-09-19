/// Tour da tela Circulares (`circulars`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const circularsHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Circulares',
  text:
      'Comunicados formais com texto, mídia e perguntas.',
);

/// Passo 2 — directory.search.
const circularsSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar circular',
  text:
      'Encontre pelo título.',
);

/// Passo 3 — directory.filters.
const circularsFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Contexto',
  text:
      'Filtre pela instituição, unidade ou turma.',
);

/// Passo 4 — directory.files.
const circularsFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text:
      'Importe ou exporte circulares.',
);

/// Passo 5 — directory.tabs.
const circularsTabsTourStep = CoeloTourStep(
  anchorId: 'directory.tabs',
  title: 'Situação',
  text:
      'Cada aba é uma situação da circular.',
);

/// Passo 6 — directory.create.
const circularsCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Nova circular',
  text:
      'Abre o compositor.',
);

/// Passo 7 — directory.body.
const circularsBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text:
      'Título, resumo e status. Clique para abrir.',
);

/// Passo 8 — directory.pagination.
const circularsPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text:
      'Avance de página e escolha quantos itens ver por vez.',
);

const circularsScreenTour = SuperadminScreenTour(
  destinationId: 'circulars',
  steps: [
    circularsHeaderTourStep,
    circularsSearchTourStep,
    circularsFiltersTourStep,
    circularsFilesTourStep,
    circularsTabsTourStep,
    circularsCreateTourStep,
    circularsBodyTourStep,
    circularsPaginationTourStep,
  ],
);
