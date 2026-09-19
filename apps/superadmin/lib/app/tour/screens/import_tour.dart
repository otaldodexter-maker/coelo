/// Tour da tela Importações (`import`). Texto do rascunho aprovado pelo Owner
/// em 18/09/2026 (`tour-telas-rascunho-20260918.md`); uma constante por
/// passo, na ordem. Para ajustar título ou texto, edite só este arquivo.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import '../superadmin_screen_tour.dart';

/// Passo 1 — page.header.
const importHeaderTourStep = CoeloTourStep(
  anchorId: 'page.header',
  title: 'Importações',
  text: 'Cada arquivo importado, com entidade, destino e quantidade de registros.',
);

/// Passo 2 — directory.search.
const importSearchTourStep = CoeloTourStep(
  anchorId: 'directory.search',
  title: 'Buscar por arquivo',
  text: 'Encontre uma importação pelo nome do arquivo.',
);

/// Passo 3 — directory.filters.
const importFiltersTourStep = CoeloTourStep(
  anchorId: 'directory.filters',
  title: 'Filtros',
  text: 'Entidade e tipo de arquivo.',
);

/// Passo 4 — directory.files.
const importFilesTourStep = CoeloTourStep(
  anchorId: 'directory.files',
  title: 'Importar e exportar',
  text: 'Importe um novo arquivo ou exporte o histórico.',
);

/// Passo 5 — directory.create.
const importCreateTourStep = CoeloTourStep(
  anchorId: 'directory.create',
  title: 'Nova importação',
  text: 'Abre o assistente: escolha a entidade, envie o arquivo, confira e confirme.',
);

/// Passo 6 — directory.body.
const importBodyTourStep = CoeloTourStep(
  anchorId: 'directory.body',
  title: 'A lista',
  text: 'Arquivo, entidade, destino, registros, data e responsável de cada importação.',
);

/// Passo 7 — directory.pagination.
const importPaginationTourStep = CoeloTourStep(
  anchorId: 'directory.pagination',
  title: 'Paginação',
  text: 'Avance de página e escolha quantos itens ver por vez.',
);

const importScreenTour = SuperadminScreenTour(
  destinationId: 'import',
  steps: [
    importHeaderTourStep,
    importSearchTourStep,
    importFiltersTourStep,
    importFilesTourStep,
    importCreateTourStep,
    importBodyTourStep,
    importPaginationTourStep,
  ],
);
